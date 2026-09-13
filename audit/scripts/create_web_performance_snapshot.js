#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const {
  REQUIRED_METADATA,
  validatePerformanceSnapshot,
} = require("../performance_budget");
const {
  hashFile,
  verifyManifest,
  verifyManifestIntegrity,
} = require("./prepare_web_performance_build");

const BYTES_PER_MIB = 1024 * 1024;

function parseCollectorOutput(text) {
  const envelope = JSON.parse(text);
  const collected = typeof envelope.result === "string"
    ? JSON.parse(envelope.result)
    : (envelope.result ?? envelope);
  if (!collected || collected.schemaVersion !== 1 || !Array.isArray(collected.samples)) {
    throw new Error("collector output must contain a schemaVersion=1 samples array");
  }
  if (collected.samples.length < 5) {
    throw new Error("collector output must contain at least 5 samples");
  }
  if (!collected.environment || typeof collected.environment !== "object") {
    throw new Error("collector output must contain observed environment");
  }
  return collected;
}

function buildCandidate({baseline, manifest, collected, rawEvidence}) {
  verifyManifestIntegrity(manifest);
  const contract = manifest.collectionContract;
  const observed = collected.environment;
  if (typeof collected.manifestRunId !== "string" ||
      collected.manifestRunId !== manifest.runId) {
    throw new Error("collector evidence does not belong to this build manifest");
  }
  const expected = {
    scenarioVersion: contract.scenarioVersion,
    playwrightCliVersion: contract.playwrightCliVersion,
    viewport: contract.viewport,
    locale: contract.locale,
    network: contract.network,
    authState: contract.authState,
    cacheState: contract.cacheState,
  };
  const actual = {
    scenarioVersion: collected.scenarioVersion,
    playwrightCliVersion: observed.playwrightCliVersion,
    viewport: observed.viewport,
    locale: observed.locale,
    network: observed.network,
    authState: observed.authState,
    cacheState: observed.cacheState,
  };
  for (const [field, expectedValue] of Object.entries(expected)) {
    if (typeof actual[field] !== "string" || actual[field].length === 0 ||
        actual[field] !== expectedValue) {
      throw new Error(`${field} does not match the measured build contract`);
    }
  }
  if (typeof observed.browserVersion !== "string" ||
      !/^\d+\.\d+\.\d+\.\d+$/.test(observed.browserVersion)) {
    throw new Error("collector must report an exact non-empty browser version");
  }
  if (typeof observed.measuredRefreshRateHz !== "number" ||
      !Number.isFinite(observed.measuredRefreshRateHz) || observed.measuredRefreshRateHz <= 0) {
    throw new Error("collector must report a positive diagnostic frame cadence");
  }
  const requiredSampleFields = [
    "surfaceReadyMs",
    "firstInteractiveMs",
    "transferredBytes",
    "resourceCount",
    "usedJsHeapBytes",
  ];
  for (const [index, sample] of collected.samples.entries()) {
    for (const field of requiredSampleFields) {
      if (typeof sample[field] !== "number" || !Number.isFinite(sample[field])) {
        throw new Error(`sample ${index} has invalid ${field}`);
      }
    }
  }

  const values = (field, divisor = 1) => collected.samples.map((sample) =>
    Number((sample[field] / divisor).toFixed(6)));
  const measuredSamples = {
    cold_start_flutter_surface_ready_ms: values("surfaceReadyMs"),
    cold_start_first_interactive_ms: values("firstInteractiveMs"),
    cold_start_network_transfer_mib: values("transferredBytes", BYTES_PER_MIB),
    cold_start_resource_count: values("resourceCount"),
    cold_start_used_js_heap_mib: values("usedJsHeapBytes", BYTES_PER_MIB),
    main_dart_js_mib: [Number((
      manifest.build.files["build/web/main.dart.js"].bytes / BYTES_PER_MIB
    ).toFixed(6))],
  };
  const metrics = {};
  for (const [name, baseMetric] of Object.entries(baseline.metrics)) {
    if (measuredSamples[name]) {
      metrics[name] = {...baseMetric, samples: measuredSamples[name]};
    } else if (baseMetric.status === "measured") {
      metrics[name] = {
        status: "not_collected",
        unit: baseMetric.unit,
        direction: baseMetric.direction,
        samples: [],
        reason: "web startup collector has no mapping for this baseline metric",
      };
    } else {
      metrics[name] = JSON.parse(JSON.stringify(baseMetric));
    }
  }
  const candidate = {
    schemaVersion: baseline.schemaVersion,
    metadata: {
      commit: manifest.source.commit,
      dirtyState: manifest.source.dirtyState,
      flutterVersion: manifest.environment.flutterVersion,
      dartVersion: manifest.environment.dartVersion,
      buildMode: manifest.environment.buildMode,
      deviceModel: `Headless Chrome ${observed.browserVersion} on ${manifest.environment.hostModel}`,
      osVersion: manifest.environment.osVersion,
      deviceKind: manifest.environment.deviceKind,
      refreshRateHz: manifest.environment.refreshRateHz,
      scenarioVersion: collected.scenarioVersion,
      collectionMethod: `Playwright CLI ${observed.playwrightCliVersion}; collector sha256 ${contract.collectorSha256}; one batch of ${collected.samples.length} fresh ${observed.viewport} contexts; service workers blocked; HTTP cache disabled`,
      network: observed.network,
      authState: observed.authState,
      cacheState: observed.cacheState,
      sourceFingerprint: manifest.source.runtimeFingerprint,
      buildFingerprint: manifest.build.fingerprint,
      rawEvidence,
      rawEvidenceSha256: contract.collectorEvidenceSha256,
    },
    metrics,
  };
  const errors = validatePerformanceSnapshot(candidate);
  if (errors.length > 0) throw new Error(`candidate is invalid: ${errors.join("; ")}`);
  return candidate;
}

function verifyCollectorEvidenceHash(manifest, collectorPath) {
  const expected = manifest?.collectionContract?.collectorEvidenceSha256;
  if (typeof expected !== "string" || !/^[a-f0-9]{64}$/.test(expected)) {
    throw new Error("build manifest collector evidence hash is missing or invalid");
  }
  if (hashFile(collectorPath) !== expected) {
    throw new Error("collector evidence hash does not match the build manifest");
  }
}

function evidenceSnapshot(snapshot) {
  const metadataFields = [
    ...REQUIRED_METADATA,
    "sourceFingerprint",
    "buildFingerprint",
    "rawEvidence",
    "rawEvidenceSha256",
  ];
  return {
    schemaVersion: snapshot.schemaVersion,
    metadata: Object.fromEntries(metadataFields.map((field) => [
      field,
      snapshot.metadata[field],
    ])),
    metrics: snapshot.metrics,
  };
}

function assertArchivedSnapshotMatches(baseline, reconstructed) {
  const expected = JSON.stringify(evidenceSnapshot(baseline));
  const actual = JSON.stringify(evidenceSnapshot(reconstructed));
  if (actual !== expected) {
    throw new Error("archived evidence does not exactly reconstruct the promoted baseline");
  }
}

function main() {
  const args = process.argv.slice(2);
  const verifyArchived = args[0] === "--verify-archived";
  const [baselinePath, manifestPath, collectorOutputPath, candidatePath] = verifyArchived
    ? args.slice(1)
    : args;
  if (!baselinePath || !manifestPath || !collectorOutputPath || !candidatePath) {
    console.error("Usage: create_web_performance_snapshot.js [--verify-archived] <baseline.json> <build-manifest.json> <collector-output.json> <candidate.json>");
    process.exitCode = 2;
    return;
  }
  const root = path.resolve(__dirname, "..", "..");
  const baseline = JSON.parse(fs.readFileSync(path.resolve(baselinePath), "utf8"));
  const manifest = JSON.parse(fs.readFileSync(path.resolve(manifestPath), "utf8"));
  if (verifyArchived) verifyManifestIntegrity(manifest);
  else verifyManifest(root, manifest);
  verifyCollectorEvidenceHash(manifest, path.resolve(collectorOutputPath));
  const collected = parseCollectorOutput(fs.readFileSync(path.resolve(collectorOutputPath), "utf8"));
  const candidate = buildCandidate({
    baseline,
    manifest,
    collected,
    rawEvidence: path.relative(root, path.resolve(collectorOutputPath)),
  });
  if (verifyArchived) assertArchivedSnapshotMatches(baseline, candidate);
  fs.writeFileSync(path.resolve(candidatePath), `${JSON.stringify(candidate, null, 2)}\n`);
}

if (require.main === module) main();

module.exports = {
  assertArchivedSnapshotMatches,
  buildCandidate,
  evidenceSnapshot,
  parseCollectorOutput,
  verifyCollectorEvidenceHash,
};
