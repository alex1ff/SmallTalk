const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {spawnSync} = require("node:child_process");
const {
  comparePerformanceSnapshots,
  validatePerformanceSnapshot,
} = require("../../audit/performance_budget");

function snapshot(overrides = {}) {
  return {
    schemaVersion: 1,
    metadata: {
      commit: "abc",
      dirtyState: "clean",
      flutterVersion: "3.35.3",
      dartVersion: "3.9.2",
      buildMode: "profile",
      deviceModel: "Pixel 8",
      osVersion: "Android 15",
      deviceKind: "physical",
      refreshRateHz: 120,
      scenarioVersion: "startup-v1",
      collectionMethod: "driver-v1",
    },
    metrics: {
      startup: {
        status: "measured",
        unit: "ms",
        direction: "lower_is_better",
        samples: [100, 110, 90],
        budget: {maxRegressionPercent: 10},
      },
      join: {
        status: "blocked",
        unit: "percent",
        direction: "higher_is_better",
        samples: [],
        reason: "no device",
      },
    },
    ...overrides,
  };
}

test("validates measured, blocked and not_collected metrics", () => {
  assert.deepEqual(validatePerformanceSnapshot(snapshot()), []);
  assert.deepEqual(validatePerformanceSnapshot(snapshot({metrics: {
    startup: {status: "measured", unit: "ms", direction: "lower_is_better", samples: []},
  }})).length, 1);
});

test("rejects invalid status, direction, NaN and missing blocked reason", () => {
  const errors = validatePerformanceSnapshot(snapshot({metrics: {
    badStatus: {status: "pass", unit: "ms", direction: "lower_is_better", samples: []},
    badDirection: {status: "measured", unit: "ms", direction: "sideways", samples: [1]},
    nanSample: {status: "measured", unit: "ms", direction: "lower_is_better", samples: [NaN]},
    blocked: {status: "blocked", unit: "ms", direction: "lower_is_better", samples: []},
  }}));
  assert.ok(errors.some((error) => error.includes("badStatus.status")));
  assert.ok(errors.some((error) => error.includes("badDirection.direction")));
  assert.ok(errors.some((error) => error.includes("nanSample.measured samples")));
  assert.ok(errors.some((error) => error.includes("blocked.blocked requires reason")));
  assert.ok(validatePerformanceSnapshot(snapshot({metrics: {
    infinity: {status: "measured", unit: "ms", direction: "lower_is_better", samples: [Infinity]},
  }})).some((error) => error.includes("infinity.measured samples")));
});

test("incompatible fingerprints never compare as pass", () => {
  const candidate = snapshot({metadata: {...snapshot().metadata, deviceModel: "iPhone"}});
  assert.equal(comparePerformanceSnapshots(snapshot(), candidate).status, "incompatible");
});

test("different commits remain comparable while device fingerprints must match", () => {
  const candidate = snapshot({metadata: {...snapshot().metadata, commit: "def"}});
  assert.equal(comparePerformanceSnapshots(snapshot(), candidate).status, "compared");
});

test("rejects debug/server metadata and non-string provenance", () => {
  const errors = validatePerformanceSnapshot(snapshot({metadata: {
    ...snapshot().metadata,
    buildMode: "debug",
    deviceKind: "server",
    scenarioVersion: 1,
  }}));
  assert.ok(errors.some((error) => error.includes("buildMode")));
  assert.ok(errors.some((error) => error.includes("deviceKind")));
  assert.ok(errors.some((error) => error.includes("scenarioVersion")));
});

test("compares lower-is-better values against explicit budget", () => {
  const candidate = snapshot({metrics: {
    startup: {...snapshot().metrics.startup, samples: [115, 115, 115]},
    join: snapshot().metrics.join,
  }});
  const result = comparePerformanceSnapshots(snapshot(), candidate);
  assert.equal(result.metrics.startup.status, "regression");
});

test("compares higher-is-better values with inverse direction", () => {
  const base = snapshot({metrics: {rate: {
    status: "measured", unit: "percent", direction: "higher_is_better", samples: [100], budget: {maxRegressionPercent: 5},
  }}});
  const candidate = snapshot({metrics: {rate: {
    status: "measured", unit: "percent", direction: "higher_is_better", samples: [98], budget: {maxRegressionPercent: 5},
  }}});
  assert.equal(comparePerformanceSnapshots(base, candidate).metrics.rate.status, "pass");
});

test("keeps unavailable metrics blocked instead of treating them as zero", () => {
  const candidate = snapshot({metrics: {startup: {
    status: "not_collected", unit: "ms", direction: "lower_is_better", samples: [], reason: "blocked",
  }}});
  assert.equal(comparePerformanceSnapshots(snapshot(), candidate).metrics.startup.status, "not_collected");
});

test("rejects metric unit and direction changes", () => {
  const base = snapshot();
  const candidate = snapshot({metrics: {
    startup: {...snapshot().metrics.startup, unit: "seconds"},
  }});
  assert.equal(comparePerformanceSnapshots(base, candidate).metrics.startup.status, "incompatible");
  const flipped = snapshot({metrics: {
    startup: {...snapshot().metrics.startup, direction: "higher_is_better"},
  }});
  assert.equal(comparePerformanceSnapshots(base, flipped).metrics.startup.status, "incompatible");
});

test("does not invent a budget when no explicit threshold exists", () => {
  const base = snapshot({metrics: {startup: {
    status: "measured", unit: "ms", direction: "lower_is_better", samples: [100],
  }}});
  const candidate = snapshot({metrics: {startup: {
    status: "measured", unit: "ms", direction: "lower_is_better", samples: [1000],
  }}});
  assert.equal(comparePerformanceSnapshots(base, candidate).metrics.startup.status, "unbudgeted");
});

test("baseline zero is handled without Infinity becoming a false pass", () => {
  const base = snapshot({metrics: {startup: {
    status: "measured", unit: "ms", direction: "lower_is_better", samples: [0], budget: {maxRegressionPercent: 0},
  }}});
  const candidate = snapshot({metrics: {startup: {
    status: "measured", unit: "ms", direction: "lower_is_better", samples: [1], budget: {maxRegressionPercent: 0},
  }}});
  assert.equal(comparePerformanceSnapshots(base, candidate).metrics.startup.status, "regression");
});

test("CLI rejects incompatible comparisons", () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "smalltalk-perf-"));
  try {
    const baselinePath = path.join(tempDir, "baseline.json");
    const candidatePath = path.join(tempDir, "candidate.json");
    fs.writeFileSync(baselinePath, JSON.stringify(snapshot()));
    fs.writeFileSync(candidatePath, JSON.stringify(snapshot({
      metadata: {...snapshot().metadata, deviceModel: "iPhone"},
    })));
    const result = spawnSync(
      process.execPath,
      [path.join(__dirname, "..", "..", "audit/scripts/validate_performance_budget.js"), baselinePath, candidatePath],
      {encoding: "utf8"},
    );
    assert.notEqual(result.status, 0);
  } finally {
    fs.rmSync(tempDir, {recursive: true, force: true});
  }
});

test("CLI rejects metric-level incompatibility", () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "smalltalk-perf-"));
  try {
    const baselinePath = path.join(tempDir, "baseline.json");
    const candidatePath = path.join(tempDir, "candidate.json");
    fs.writeFileSync(baselinePath, JSON.stringify(snapshot()));
    fs.writeFileSync(candidatePath, JSON.stringify(snapshot({metrics: {
      startup: {...snapshot().metrics.startup, unit: "seconds"},
    }})));
    const result = spawnSync(
      process.execPath,
      [path.join(__dirname, "..", "..", "audit/scripts/validate_performance_budget.js"), baselinePath, candidatePath],
      {encoding: "utf8"},
    );
    assert.notEqual(result.status, 0);
  } finally {
    fs.rmSync(tempDir, {recursive: true, force: true});
  }
});

test("CLI rejects metric direction incompatibility", () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "smalltalk-perf-"));
  try {
    const baselinePath = path.join(tempDir, "baseline.json");
    const candidatePath = path.join(tempDir, "candidate.json");
    fs.writeFileSync(baselinePath, JSON.stringify(snapshot()));
    fs.writeFileSync(candidatePath, JSON.stringify(snapshot({metrics: {
      startup: {...snapshot().metrics.startup, direction: "higher_is_better"},
    }})));
    const result = spawnSync(
      process.execPath,
      [path.join(__dirname, "..", "..", "audit/scripts/validate_performance_budget.js"), baselinePath, candidatePath],
      {encoding: "utf8"},
    );
    assert.notEqual(result.status, 0);
  } finally {
    fs.rmSync(tempDir, {recursive: true, force: true});
  }
});
