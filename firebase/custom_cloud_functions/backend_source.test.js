const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {spawnSync} = require("node:child_process");
const {
  readExports,
  validateBackendSource,
  validateProductionInventory,
} = require("./scripts/validate_backend_source");

const repoRoot = path.resolve(__dirname, "..", "..");
const config = JSON.parse(fs.readFileSync(
    path.join(repoRoot, "firebase", "firebase.json"),
    "utf8",
));
const manifest = JSON.parse(fs.readFileSync(
    path.join(repoRoot, "firebase", "backend_sources.json"),
    "utf8",
));

test("backend source manifest tracks every configured Firebase codebase", () => {
  const report = validateBackendSource({config, manifest, repoRoot});

  assert.equal(report.ok, true);
  assert.equal(report.canonicalCodebase, "custom_cloud_functions");
  assert.deepEqual(report.configuredCodebases, [
    "custom_cloud_functions:custom_cloud_functions",
  ]);
  assert.equal(report.warnings.length, 0);
});

test("retired legacy source is documented and no longer configured", () => {
  assert.deepEqual(manifest.retired, [
    {
      codebase: "functions",
      source: "functions",
      status: "retired",
      production: "deleted",
      knownExports: ["onUserDeleted"],
      reason: "The only export was a deployed no-op auth deletion trigger. The canonical cleanupUserCallIntegrationsOnDelete trigger remains active.",
    },
  ]);
  assert.equal(fs.existsSync(path.join(
      repoRoot,
      "firebase",
      "functions",
      "index.js",
  )), false);
  assert.equal(fs.existsSync(path.join(
      repoRoot,
      "firebase",
      "functions",
      "package.json",
  )), false);
});

test("production inventory fails for retired and unknown codebases", () => {
  const report = validateProductionInventory([
    {id: "createVideoSession", codebase: "custom_cloud_functions"},
    {id: "onUserDeleted", codebase: "functions"},
    {id: "unexpected", codebase: "another_source"},
  ]);

  assert.equal(report.ok, false);
  assert.ok(report.failures.some((failure) =>
    failure.reason === "production_noncanonical_codebase",
  ));
  assert.ok(report.failures.some((failure) =>
    failure.reason === "production_unknown_codebase",
  ));
});

test("production inventory accepts canonical functions only", () => {
  const report = validateProductionInventory([
    {id: "createVideoSession", codebase: "custom_cloud_functions"},
  ]);

  assert.equal(report.ok, true);
  assert.equal(report.warnings.length, 0);
});

test("production inventory fails closed when codebase metadata is absent", () => {
  const report = validateProductionInventory([{id: "createVideoSession"}]);

  assert.equal(report.ok, false);
  assert.ok(report.failures.some((failure) =>
    failure.reason === "production_codebase_missing",
  ));
});

test("local validation rejects config that differs from canonical source", () => {
  const report = validateBackendSource({
    config: {
      ...config,
      functions: [{
        codebase: "wrong",
        source: "custom_cloud_functions",
      }],
    },
    manifest: {
      ...manifest,
      configured: [{
        codebase: "wrong",
        source: "custom_cloud_functions",
        status: "canonical",
        production: "active",
      }],
    },
    repoRoot,
  });

  assert.equal(report.ok, false);
  assert.ok(report.failures.some((failure) =>
    failure.reason === "firebase_canonical_config_mismatch",
  ));
});

test("production inventory rejects retired ids in the canonical codebase", () => {
  const report = validateProductionInventory([
    {id: "onUserDeleted", codebase: "custom_cloud_functions"},
  ], {retiredFunctionIds: ["onUserDeleted"]});

  assert.equal(report.ok, false);
  assert.ok(report.failures.some((failure) =>
    failure.reason === "production_retired_function",
  ));
});

test("production inventory rejects empty, partial and malformed lists", () => {
  const expectedFunctionIds = ["createVideoSession", "endSession"];
  const empty = validateProductionInventory([], {expectedFunctionIds});
  const partial = validateProductionInventory([
    {id: "createVideoSession", codebase: "custom_cloud_functions"},
  ], {expectedFunctionIds});
  const malformed = validateProductionInventory([
    {codebase: "custom_cloud_functions"},
  ], {expectedFunctionIds: []});

  assert.equal(empty.ok, false);
  assert.equal(partial.ok, false);
  assert.equal(malformed.ok, false);
  assert.ok(empty.failures.some((failure) =>
    failure.reason === "production_function_missing",
  ));
  assert.ok(partial.failures.some((failure) =>
    failure.id === "endSession" &&
      failure.reason === "production_function_missing",
  ));
  assert.ok(malformed.failures.some((failure) =>
    failure.reason === "production_function_id_missing",
  ));
});

test("production inventory requires the exact canonical export set", () => {
  const expectedFunctionIds = ["createVideoSession", "endSession"];
  const report = validateProductionInventory([
    {id: "createVideoSession", codebase: "custom_cloud_functions"},
    {id: "endSession", codebase: "custom_cloud_functions"},
  ], {expectedFunctionIds});

  assert.equal(report.ok, true);
  assert.equal(report.failures.length, 0);
});

test("production inventory rejects an empty canonical export set", () => {
  const report = validateProductionInventory([], {expectedFunctionIds: []});

  assert.equal(report.ok, false);
  assert.ok(report.failures.some((failure) =>
    failure.reason === "canonical_export_set_empty",
  ));
});

test("production inventory preserves sanitized deployment metadata", () => {
  const report = validateProductionInventory([
    {
      id: "createVideoSession",
      codebase: "custom_cloud_functions",
      region: "us-central1",
      platform: "gcfv1",
      runtime: "nodejs22",
      state: "ACTIVE",
      hash: "source-hash",
      serviceAccount: "functions@example.iam.gserviceaccount.com",
      callableTrigger: {},
      environmentVariables: {SECRET_VALUE: "must-not-be-copied"},
    },
  ], {expectedFunctionIds: ["createVideoSession"]});

  assert.equal(report.ok, true);
  assert.deepEqual(report.inventory, [{
    id: "createVideoSession",
    codebase: "custom_cloud_functions",
    region: "us-central1",
    platform: "gcfv1",
    runtime: "nodejs22",
    state: "ACTIVE",
    hash: "source-hash",
    serviceAccount: "functions@example.iam.gserviceaccount.com",
    trigger: "callable",
  }]);
  assert.doesNotMatch(JSON.stringify(report), /must-not-be-copied/);
});

test("production inventory command fails closed across the Firebase pipeline", () => {
  const script = fs.readFileSync(path.join(
      repoRoot,
      "firebase",
      "custom_cloud_functions",
      "scripts",
      "inventory_backend_source.sh",
  ), "utf8");

  assert.match(script, /set -euo pipefail/);
  assert.match(script, /node_modules\/\.bin\/firebase/);
  assert.match(script, /functions:list/);
  assert.match(script, /--production-json/);
  assert.match(script, /MAX_ATTEMPTS=3/);
  assert.match(script, /mktemp/);
  assert.match(script, /failed after/);
});

test("inventory shell retries transient Firebase failures and fails closed", () => {
  const tempDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "source-inventory-"));
  const fakeFirebase = path.join(tempDirectory, "firebase");
  const attemptFile = path.join(tempDirectory, "attempts");
  const inventoryFile = path.join(tempDirectory, "inventory.json");
  const canonicalExports = readExports(path.join(
      repoRoot,
      "firebase",
      "custom_cloud_functions",
      "index.js",
  ));
  fs.writeFileSync(inventoryFile, JSON.stringify({
    status: "success",
    result: canonicalExports.map((id) => ({
      id,
      codebase: "custom_cloud_functions",
    })),
  }));
  fs.writeFileSync(fakeFirebase, `#!/usr/bin/env bash
set -euo pipefail
attempt=0
if [[ -f "\${FAKE_ATTEMPT_FILE}" ]]; then
  attempt="$(cat "\${FAKE_ATTEMPT_FILE}")"
fi
attempt=$((attempt + 1))
printf '%s' "\${attempt}" >"\${FAKE_ATTEMPT_FILE}"
if [[ "\${attempt}" -lt "\${FAKE_SUCCEED_AT:-3}" ]]; then
  printf '%s\\n' '{"status":"error","error":"transient"}'
  exit 1
fi
cat "\${FAKE_INVENTORY_JSON}"
`);
  fs.chmodSync(fakeFirebase, 0o755);

  const scriptPath = path.join(
      repoRoot,
      "firebase",
      "custom_cloud_functions",
      "scripts",
      "inventory_backend_source.sh",
  );
  const baseEnvironment = {
    ...process.env,
    FIREBASE_BIN: fakeFirebase,
    FAKE_ATTEMPT_FILE: attemptFile,
    FAKE_INVENTORY_JSON: inventoryFile,
    INVENTORY_RETRY_SLEEP_SECONDS: "0",
  };

  const recovered = spawnSync("bash", [scriptPath, "--json"], {
    cwd: repoRoot,
    env: baseEnvironment,
    encoding: "utf8",
  });
  assert.equal(recovered.status, 0, recovered.stderr);
  assert.equal(fs.readFileSync(attemptFile, "utf8"), "3");
  assert.match(recovered.stdout, /"inspectedFunctions": 63/);

  fs.rmSync(attemptFile);
  const failed = spawnSync("bash", [scriptPath, "--json"], {
    cwd: repoRoot,
    env: {...baseEnvironment, FAKE_SUCCEED_AT: "99"},
    encoding: "utf8",
  });
  assert.equal(failed.status, 1);
  assert.equal(fs.readFileSync(attemptFile, "utf8"), "3");
  assert.match(failed.stderr, /failed after 3 attempts/);

  fs.rmSync(tempDirectory, {recursive: true, force: true});
});
