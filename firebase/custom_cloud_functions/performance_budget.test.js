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
const {
  assertArchivedSnapshotMatches,
  buildCandidate,
  parseCollectorOutput,
  verifyCollectorEvidenceHash,
} = require("../../audit/scripts/create_web_performance_snapshot");
const {
  buildArtifacts,
  buildFingerprintFromFiles,
  computeRunId,
  hashFile,
  hostEnvironment,
  runtimeSourceSnapshot,
  verifyManifest,
  verifyManifestIntegrity,
} = require("../../audit/scripts/prepare_web_performance_build");

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
      network: "wifi-unthrottled",
      authState: "signed-out",
      cacheState: "cold",
    },
    metrics: {
      startup: {
        status: "measured",
        unit: "ms",
        direction: "lower_is_better",
        measurementType: "runtime",
        samples: [100, 110, 90, 105, 95],
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

function webManifest(baseline, overrides = {}) {
  const devicePrefix = "Headless Chrome 145.0.7632.160 on ";
  const buildFiles = {
    "build/web/main.dart.js": {
      bytes: overrides.mainDartJsBytes ?? 20332401,
      sha256: overrides.mainDartJsSha256 ?? "main-def",
    },
  };
  const manifest = {
    schemaVersion: 1,
    source: {
      commit: "def",
      dirtyState: "clean",
      runtimeStatus: "",
      runtimeFingerprint: "source-def",
    },
    environment: {
      flutterVersion: baseline.metadata.flutterVersion,
      dartVersion: baseline.metadata.dartVersion,
      buildMode: baseline.metadata.buildMode,
      hostModel: baseline.metadata.deviceModel.slice(devicePrefix.length),
      osVersion: baseline.metadata.osVersion,
      deviceKind: baseline.metadata.deviceKind,
      refreshRateHz: baseline.metadata.refreshRateHz,
    },
    build: {
      fingerprint: buildFingerprintFromFiles(buildFiles),
      files: buildFiles,
    },
    collectionContract: {
      scenarioVersion: baseline.metadata.scenarioVersion,
      playwrightCliVersion: "0.1.19",
      viewport: "390x844@1x",
      locale: "ru-RU",
      network: baseline.metadata.network,
      authState: baseline.metadata.authState,
      cacheState: baseline.metadata.cacheState,
      collectorSha256: "eca5ab067e79ddea4e92349cbffdf399502dca18243b54b5a5f975a0d1c41d11",
      collectorEvidenceSha256: "d".repeat(64),
      collectorPath: "audit/scripts/collect_web_startup.playwright.js",
    },
    runNonce: overrides.runNonce ?? "run-one",
  };
  manifest.runId = computeRunId(manifest);
  return manifest;
}

test("validates measured, blocked and not_collected metrics", () => {
  assert.deepEqual(validatePerformanceSnapshot(snapshot()), []);
  assert.deepEqual(validatePerformanceSnapshot(snapshot({metrics: {
    startup: {status: "measured", unit: "ms", direction: "lower_is_better", measurementType: "runtime", samples: []},
  }})).length, 1);
});

test("runtime metrics require five samples and static metrics require exactly one", () => {
  for (const count of [1, 4]) {
    const errors = validatePerformanceSnapshot(snapshot({metrics: {runtime: {
      status: "measured",
      unit: "ms",
      direction: "lower_is_better",
      measurementType: "runtime",
      samples: Array(count).fill(100),
    }}}));
    assert.ok(errors.some((error) => error.includes("at least 5 samples")));
  }
  assert.deepEqual(validatePerformanceSnapshot(snapshot({metrics: {runtime: {
    status: "measured",
    unit: "ms",
    direction: "lower_is_better",
    measurementType: "runtime",
    samples: Array(5).fill(100),
  }}})), []);
  assert.ok(validatePerformanceSnapshot(snapshot({metrics: {buildSize: {
    status: "measured",
    unit: "MiB",
    direction: "lower_is_better",
    measurementType: "static",
    samples: [1, 1],
  }}})).some((error) => error.includes("exactly 1 sample")));
});

test("web collector output becomes a valid comparable candidate", () => {
  const baseline = JSON.parse(fs.readFileSync(path.join(
    __dirname,
    "..",
    "..",
    "audit",
    "performance_baselines",
    "web-profile-2026-09-07.json",
  ), "utf8"));
  const sample = {
    surfaceReadyMs: 1200,
    firstInteractiveMs: 1500,
    transferredBytes: 23000000,
    resourceCount: 36,
    usedJsHeapBytes: 90000000,
  };
  const collected = parseCollectorOutput(JSON.stringify({result: JSON.stringify({
    schemaVersion: 1,
    manifestRunId: webManifest(baseline).runId,
    scenarioVersion: baseline.metadata.scenarioVersion,
    environment: {
      browserVersion: "145.0.7632.160",
      playwrightCliVersion: "0.1.19",
      viewport: "390x844@1x",
      locale: "ru-RU",
      measuredRefreshRateHz: 80,
      refreshRateHz: 120,
      network: baseline.metadata.network,
      authState: baseline.metadata.authState,
      cacheState: baseline.metadata.cacheState,
    },
    samples: Array(10).fill(sample),
  })}));
  const candidate = buildCandidate({
    baseline,
    manifest: webManifest(baseline),
    collected,
    rawEvidence: "output/playwright/web-startup.json",
  });
  assert.deepEqual(validatePerformanceSnapshot(candidate), []);
  assert.equal(comparePerformanceSnapshots(baseline, candidate).status, "compared");
  assert.equal(candidate.metadata.commit, "def");
  assert.equal(candidate.metadata.dirtyState, "clean");
  assert.equal(candidate.metrics.cold_start_first_interactive_ms.samples.length, 10);
});

test("web candidate never inherits an uncollected measured baseline metric", () => {
  const baseline = JSON.parse(fs.readFileSync(path.join(
    __dirname,
    "..",
    "..",
    "audit",
    "performance_baselines",
    "web-profile-2026-09-07.json",
  ), "utf8"));
  baseline.metrics.future_budgeted_metric = {
    status: "measured",
    unit: "ms",
    direction: "lower_is_better",
    measurementType: "runtime",
    samples: Array(5).fill(100),
    budget: {maxRegressionPercent: 0},
  };
  const manifest = webManifest(baseline);
  const sample = {
    surfaceReadyMs: 1200,
    firstInteractiveMs: 1500,
    transferredBytes: 23000000,
    resourceCount: 36,
    usedJsHeapBytes: 90000000,
  };
  const collected = {
    schemaVersion: 1,
    manifestRunId: manifest.runId,
    scenarioVersion: baseline.metadata.scenarioVersion,
    environment: {
      browserVersion: "145.0.7632.160",
      playwrightCliVersion: manifest.collectionContract.playwrightCliVersion,
      viewport: manifest.collectionContract.viewport,
      locale: manifest.collectionContract.locale,
      measuredRefreshRateHz: 80,
      refreshRateHz: 120,
      network: manifest.collectionContract.network,
      authState: manifest.collectionContract.authState,
      cacheState: manifest.collectionContract.cacheState,
    },
    samples: Array(10).fill(sample),
  };
  const candidate = buildCandidate({
    baseline,
    manifest,
    collected,
    rawEvidence: "raw.json",
  });
  assert.equal(candidate.metrics.future_budgeted_metric.status, "not_collected");
  assert.equal(
    comparePerformanceSnapshots(baseline, candidate).metrics.future_budgeted_metric.status,
    "incomplete",
  );
});

test("web candidate rejects declared environment drift", () => {
  const baseline = JSON.parse(fs.readFileSync(path.join(
    __dirname,
    "..",
    "..",
    "audit",
    "performance_baselines",
    "web-profile-2026-09-07.json",
  ), "utf8"));
  const manifest = webManifest(baseline);
  const collected = {
    schemaVersion: 1,
    manifestRunId: manifest.runId,
    scenarioVersion: baseline.metadata.scenarioVersion,
    environment: {
      browserVersion: "145.0.7632.160",
      playwrightCliVersion: manifest.collectionContract.playwrightCliVersion,
      viewport: manifest.collectionContract.viewport,
      locale: manifest.collectionContract.locale,
      measuredRefreshRateHz: 80,
      refreshRateHz: 120,
      network: "remote LTE",
      authState: manifest.collectionContract.authState,
      cacheState: manifest.collectionContract.cacheState,
    },
    samples: Array(10).fill({
      surfaceReadyMs: 1200,
      firstInteractiveMs: 1500,
      transferredBytes: 23000000,
      resourceCount: 36,
      usedJsHeapBytes: 90000000,
    }),
  };
  assert.throws(() => buildCandidate({
    baseline,
    manifest,
    collected,
    rawEvidence: "raw.json",
  }), /network does not match/);
});

test("collector evidence cannot be reused for another build manifest", () => {
  const baseline = JSON.parse(fs.readFileSync(path.join(
    __dirname,
    "..",
    "..",
    "audit",
    "performance_baselines",
    "web-profile-2026-09-07.json",
  ), "utf8"));
  const firstManifest = webManifest(baseline);
  const secondManifest = webManifest(baseline, {
    runNonce: "run-two",
    mainDartJsBytes: 20332402,
  });
  const collected = {
    schemaVersion: 1,
    manifestRunId: firstManifest.runId,
    scenarioVersion: baseline.metadata.scenarioVersion,
    environment: {
      browserVersion: "145.0.7632.160",
      playwrightCliVersion: firstManifest.collectionContract.playwrightCliVersion,
      viewport: firstManifest.collectionContract.viewport,
      locale: firstManifest.collectionContract.locale,
      measuredRefreshRateHz: 80,
      network: firstManifest.collectionContract.network,
      authState: firstManifest.collectionContract.authState,
      cacheState: firstManifest.collectionContract.cacheState,
    },
    samples: Array(10).fill({
      surfaceReadyMs: 1200,
      firstInteractiveMs: 1500,
      transferredBytes: 23000000,
      resourceCount: 36,
      usedJsHeapBytes: 90000000,
    }),
  };
  assert.throws(() => buildCandidate({
    baseline,
    manifest: secondManifest,
    collected,
    rawEvidence: "stale.json",
  }), /does not belong to this build manifest/);
});

test("web snapshot builder rejects insufficient samples and environment drift", () => {
  assert.throws(() => parseCollectorOutput(JSON.stringify({result: JSON.stringify({
    schemaVersion: 1,
    samples: Array(4).fill({}),
  })})), /at least 5 samples/);
  const baseline = JSON.parse(fs.readFileSync(path.join(
    __dirname,
    "..",
    "..",
    "audit",
    "performance_baselines",
    "web-profile-2026-09-07.json",
  ), "utf8"));
  const manifest = webManifest(baseline);
  assert.throws(() => buildCandidate({
    baseline,
    manifest,
    collected: {
      schemaVersion: 1,
      manifestRunId: manifest.runId,
      scenarioVersion: baseline.metadata.scenarioVersion,
      environment: {
        browserVersion: "",
        playwrightCliVersion: manifest.collectionContract.playwrightCliVersion,
      viewport: manifest.collectionContract.viewport,
      locale: manifest.collectionContract.locale,
      measuredRefreshRateHz: 80,
      refreshRateHz: 120,
        network: manifest.collectionContract.network,
        authState: manifest.collectionContract.authState,
        cacheState: manifest.collectionContract.cacheState,
      },
      samples: Array(5).fill({}),
    },
    rawEvidence: "raw.json",
  }), /exact non-empty browser version/);
});

test("build manifest detects stale source, artifacts and collector", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "smalltalk-perf-manifest-"));
  const write = (name, contents) => {
    const file = path.join(root, name);
    fs.mkdirSync(path.dirname(file), {recursive: true});
    fs.writeFileSync(file, contents);
  };
  try {
    write("lib/main.dart", "void main() {}\n");
    write("web/index.html", "<html></html>\n");
    write("assets/readme.txt", "asset\n");
    write("pubspec.yaml", "name: fixture\n");
    write("pubspec.lock", "packages: {}\n");
    write("build/web/main.dart.js", "main\n");
    write("build/web/canvaskit/canvaskit.wasm", "wasm\n");
    write("build/web/flutter.js", "flutter\n");
    write("build/web/index.html", "built\n");
    write("audit/scripts/collector.js", "collector\n");
    assert.equal(spawnSync("git", ["init", "-q"], {cwd: root}).status, 0);
    assert.equal(spawnSync("git", ["add", "lib", "web", "assets", "pubspec.yaml", "pubspec.lock"], {
      cwd: root,
    }).status, 0);
    const source = runtimeSourceSnapshot(root);
    const artifacts = buildArtifacts(root);
    const manifest = {
      source: {runtimeFingerprint: source.fingerprint, runtimeStatus: source.status},
      environment: hostEnvironment(root),
      build: artifacts,
      collectionContract: {
        collectorPath: "audit/scripts/collector.js",
        collectorSha256: hashFile(path.join(root, "audit/scripts/collector.js")),
      },
      runNonce: "fixture-run",
    };
    manifest.runId = computeRunId(manifest);
    assert.doesNotThrow(() => verifyManifest(root, manifest));
    const tamperedManifest = JSON.parse(JSON.stringify(manifest));
    tamperedManifest.build.files["build/web/main.dart.js"].bytes = 1;
    assert.throws(() => verifyManifestIntegrity(tamperedManifest), /file map|run ID/);
    assert.throws(() => verifyManifest(root, tamperedManifest), /file map|run ID/);
    write("lib/main.dart", "void main() { print('changed'); }\n");
    assert.throws(() => verifyManifest(root, manifest), /runtime source changed/);
    write("lib/main.dart", "void main() {}\n");
    write("build/web/main.dart.js", "changed build\n");
    assert.throws(() => verifyManifest(root, manifest), /build artifacts changed/);
    write("build/web/main.dart.js", "main\n");
    write("build/web/assets/AssetManifest.bin", "added asset\n");
    assert.throws(() => verifyManifest(root, manifest), /build artifacts changed/);
    fs.rmSync(path.join(root, "build/web/assets"), {recursive: true, force: true});
    fs.rmSync(path.join(root, "build/web/flutter.js"));
    assert.throws(() => verifyManifest(root, manifest), /build artifacts changed/);
    write("build/web/flutter.js", "flutter\n");
    write("audit/scripts/collector.js", "changed collector\n");
    assert.throws(() => verifyManifest(root, manifest), /collector changed/);
  } finally {
    fs.rmSync(root, {recursive: true, force: true});
  }
});

test("archived manifest and collector evidence reconstruct the promoted baseline", () => {
  const baselineDir = path.join(__dirname, "..", "..", "audit", "performance_baselines");
  const baseline = JSON.parse(fs.readFileSync(
    path.join(baselineDir, "web-profile-2026-09-07.json"),
    "utf8",
  ));
  const manifest = JSON.parse(fs.readFileSync(
    path.join(baselineDir, "web-profile-2026-09-07.manifest.json"),
    "utf8",
  ));
  const collected = parseCollectorOutput(fs.readFileSync(
    path.join(baselineDir, "web-profile-2026-09-07.collector.json"),
    "utf8",
  ));
  assert.doesNotThrow(() => verifyManifestIntegrity(manifest));
  const reconstructed = buildCandidate({
    baseline,
    manifest,
    collected,
    rawEvidence: baseline.metadata.rawEvidence,
  });
  assert.deepEqual(reconstructed.metrics, baseline.metrics);
  assert.doesNotThrow(() => assertArchivedSnapshotMatches(baseline, reconstructed));
  const comparison = comparePerformanceSnapshots(baseline, reconstructed);
  assert.equal(comparison.status, "compared");
  for (const metric of Object.values(comparison.metrics)) {
    if (metric.budgetSource === "baseline") assert.equal(metric.status, "pass");
  }
});

test("archived verification rejects any sample drift, even within budget", () => {
  const baselineDir = path.join(__dirname, "..", "..", "audit", "performance_baselines");
  const baseline = JSON.parse(fs.readFileSync(
    path.join(baselineDir, "web-profile-2026-09-07.json"),
    "utf8",
  ));
  const manifest = JSON.parse(fs.readFileSync(
    path.join(baselineDir, "web-profile-2026-09-07.manifest.json"),
    "utf8",
  ));
  const collected = parseCollectorOutput(fs.readFileSync(
    path.join(baselineDir, "web-profile-2026-09-07.collector.json"),
    "utf8",
  ));
  for (const mutate of [
    (value) => { value.samples[0].firstInteractiveMs += 1; },
    (value) => { value.samples[0].transferredBytes += 1; },
  ]) {
    const changed = JSON.parse(JSON.stringify(collected));
    mutate(changed);
    const reconstructed = buildCandidate({
      baseline,
      manifest,
      collected: changed,
      rawEvidence: baseline.metadata.rawEvidence,
    });
    assert.throws(
      () => assertArchivedSnapshotMatches(baseline, reconstructed),
      /does not exactly reconstruct/,
    );
  }
});

test("archived verification rejects evidence file tampering outside derived fields", () => {
  const manifest = webManifest(JSON.parse(fs.readFileSync(path.join(
    __dirname,
    "..",
    "..",
    "audit",
    "performance_baselines",
    "web-profile-2026-09-07.json",
  ), "utf8")));
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "smalltalk-perf-evidence-"));
  const evidencePath = path.join(tempDir, "collector.json");
  try {
    fs.writeFileSync(evidencePath, JSON.stringify({environment: {userAgent: "original"}}));
    manifest.collectionContract.collectorEvidenceSha256 = hashFile(evidencePath);
    assert.doesNotThrow(() => verifyCollectorEvidenceHash(manifest, evidencePath));
    fs.writeFileSync(evidencePath, JSON.stringify({environment: {userAgent: "tampered"}}));
    assert.throws(() => verifyCollectorEvidenceHash(manifest, evidencePath), /hash does not match/);
  } finally {
    fs.rmSync(tempDir, {recursive: true, force: true});
  }
});

test("rejects invalid status, direction, NaN and missing blocked reason", () => {
  const errors = validatePerformanceSnapshot(snapshot({metrics: {
    badStatus: {status: "pass", unit: "ms", direction: "lower_is_better", samples: []},
    badDirection: {status: "measured", unit: "ms", direction: "sideways", measurementType: "static", samples: [1]},
    nanSample: {status: "measured", unit: "ms", direction: "lower_is_better", measurementType: "static", samples: [NaN]},
    blocked: {status: "blocked", unit: "ms", direction: "lower_is_better", samples: []},
  }}));
  assert.ok(errors.some((error) => error.includes("badStatus.status")));
  assert.ok(errors.some((error) => error.includes("badDirection.direction")));
  assert.ok(errors.some((error) => error.includes("nanSample.measured samples")));
  assert.ok(errors.some((error) => error.includes("blocked.blocked requires reason")));
  assert.ok(validatePerformanceSnapshot(snapshot({metrics: {
    infinity: {status: "measured", unit: "ms", direction: "lower_is_better", measurementType: "static", samples: [Infinity]},
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

test("dirty state is provenance and does not make the runtime environment incompatible", () => {
  const candidate = snapshot({metadata: {...snapshot().metadata, dirtyState: "dirty"}});
  assert.equal(comparePerformanceSnapshots(snapshot(), candidate).status, "compared");
});

for (const field of ["network", "authState", "cacheState"]) {
  test(`${field} is required and participates in compatibility`, () => {
    const metadata = {...snapshot().metadata};
    delete metadata[field];
    assert.ok(validatePerformanceSnapshot(snapshot({metadata})).some((error) =>
      error.includes(`metadata.${field}`)));
    const changed = snapshot({metadata: {...snapshot().metadata, [field]: "different"}});
    assert.equal(comparePerformanceSnapshots(snapshot(), changed).status, "incompatible");
  });
}

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

test("accepts a declared browser profile without calling it an emulator", () => {
  const browserSnapshot = snapshot({metadata: {
    ...snapshot().metadata,
    deviceKind: "browser",
    deviceModel: "Headless Chrome 145 on MacBook Pro",
    osVersion: "macOS 26.5.2",
    refreshRateHz: "not_applicable",
  }});
  assert.deepEqual(validatePerformanceSnapshot(browserSnapshot), []);
});

test("compares lower-is-better values against explicit budget", () => {
  const candidate = snapshot({metrics: {
    startup: {...snapshot().metrics.startup, samples: [115, 115, 115, 115, 115]},
    join: snapshot().metrics.join,
  }});
  const result = comparePerformanceSnapshots(snapshot(), candidate);
  assert.equal(result.metrics.startup.status, "regression");
  assert.equal(result.metrics.startup.budgetSource, "baseline");
});

test("candidate cannot weaken or remove the baseline budget", () => {
  const regressed = {...snapshot().metrics.startup, samples: Array(5).fill(5000)};
  const weakened = snapshot({metrics: {
    startup: {...regressed, budget: {maxRegressionPercent: 1000}},
  }});
  const removed = snapshot({metrics: {
    startup: {...regressed, budget: undefined},
  }});
  assert.equal(comparePerformanceSnapshots(snapshot(), weakened).metrics.startup.status, "regression");
  assert.equal(comparePerformanceSnapshots(snapshot(), removed).metrics.startup.status, "regression");
});

test("missing budgeted candidate metric is incomplete", () => {
  const candidate = snapshot({metrics: {join: snapshot().metrics.join}});
  assert.equal(comparePerformanceSnapshots(snapshot(), candidate).metrics.startup.status, "incomplete");
});

test("compares higher-is-better values with inverse direction", () => {
  const base = snapshot({metrics: {rate: {
    status: "measured", unit: "percent", direction: "higher_is_better", samples: [100], budget: {maxRegressionPercent: 5},
    measurementType: "static",
  }}});
  const candidate = snapshot({metrics: {rate: {
    status: "measured", unit: "percent", direction: "higher_is_better", samples: [98], budget: {maxRegressionPercent: 5},
    measurementType: "static",
  }}});
  assert.equal(comparePerformanceSnapshots(base, candidate).metrics.rate.status, "pass");
});

test("keeps unavailable metrics blocked instead of treating them as zero", () => {
  const baseline = snapshot({metrics: {startup: {
    ...snapshot().metrics.startup,
    budget: undefined,
  }}});
  const candidate = snapshot({metrics: {startup: {
    status: "not_collected", unit: "ms", direction: "lower_is_better", samples: [], reason: "blocked",
  }}});
  assert.equal(comparePerformanceSnapshots(baseline, candidate).metrics.startup.status, "not_collected");
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
  const changedMeasurement = snapshot({metrics: {
    startup: {
      ...snapshot().metrics.startup,
      measurementType: "static",
      samples: [100],
    },
  }});
  assert.equal(comparePerformanceSnapshots(base, changedMeasurement).metrics.startup.status, "incompatible");
});

test("does not invent a budget when no explicit threshold exists", () => {
  const base = snapshot({metrics: {startup: {
    status: "measured", unit: "ms", direction: "lower_is_better", measurementType: "static", samples: [100],
  }}});
  const candidate = snapshot({metrics: {startup: {
    status: "measured", unit: "ms", direction: "lower_is_better", measurementType: "static", samples: [1000],
  }}});
  assert.equal(comparePerformanceSnapshots(base, candidate).metrics.startup.status, "unbudgeted");
});

test("baseline zero is handled without Infinity becoming a false pass", () => {
  const base = snapshot({metrics: {startup: {
    status: "measured", unit: "ms", direction: "lower_is_better", measurementType: "static", samples: [0], budget: {maxRegressionPercent: 0},
  }}});
  const candidate = snapshot({metrics: {startup: {
    status: "measured", unit: "ms", direction: "lower_is_better", measurementType: "static", samples: [1], budget: {maxRegressionPercent: 0},
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

test("CLI rejects an incomplete budgeted candidate", () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "smalltalk-perf-"));
  try {
    const baselinePath = path.join(tempDir, "baseline.json");
    const candidatePath = path.join(tempDir, "candidate.json");
    fs.writeFileSync(baselinePath, JSON.stringify(snapshot()));
    fs.writeFileSync(candidatePath, JSON.stringify(snapshot({metrics: {
      join: snapshot().metrics.join,
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
