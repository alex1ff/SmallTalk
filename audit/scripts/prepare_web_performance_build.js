#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const {createHash, randomUUID} = require("node:crypto");
const {execFileSync, spawnSync} = require("node:child_process");

const SOURCE_PATHS = ["lib", "web", "assets", "pubspec.yaml", "pubspec.lock"];
const BUILD_ROOT = "build/web";

function command(root, executable, args) {
  return execFileSync(executable, args, {cwd: root, encoding: "utf8"}).trim();
}

function hashFile(file) {
  return createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function walkFiles(directory) {
  const files = [];
  for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...walkFiles(file));
    else if (entry.isFile()) files.push(file);
    else throw new Error(`unsupported build artifact: ${file}`);
  }
  return files.sort();
}

function runtimeSourceSnapshot(root) {
  const names = execFileSync("git", [
    "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", ...SOURCE_PATHS,
  ], {cwd: root, encoding: "utf8"}).split("\0").filter(Boolean).sort();
  const digest = createHash("sha256");
  for (const name of names) {
    const file = path.join(root, name);
    digest.update(JSON.stringify(name));
    digest.update(fs.readFileSync(file));
    digest.update("\0");
  }
  return {
    fingerprint: digest.digest("hex"),
    status: command(root, "git", ["status", "--porcelain=v1", "--", ...SOURCE_PATHS]),
  };
}

function buildArtifacts(root) {
  const artifacts = {};
  const buildRoot = path.join(root, BUILD_ROOT);
  for (const file of walkFiles(buildRoot)) {
    const relativePath = path.relative(root, file);
    const value = {bytes: fs.statSync(file).size, sha256: hashFile(file)};
    artifacts[relativePath] = value;
  }
  return {fingerprint: buildFingerprintFromFiles(artifacts), files: artifacts};
}

function buildFingerprintFromFiles(files) {
  const digest = createHash("sha256");
  for (const name of Object.keys(files).sort()) {
    digest.update(JSON.stringify([name, files[name]]));
  }
  return digest.digest("hex");
}

function computeRunId(manifest) {
  const {collectorEvidenceSha256: _collectorEvidenceSha256, ...collectionContract} =
    manifest.collectionContract;
  const identity = {
    nonce: manifest.runNonce,
    source: manifest.source,
    environment: manifest.environment,
    build: manifest.build,
    collectionContract,
  };
  return createHash("sha256").update(JSON.stringify(identity)).digest("hex");
}

function verifyManifestIntegrity(manifest) {
  const errors = [];
  if (!manifest?.build?.files || typeof manifest.build.files !== "object") {
    errors.push("build manifest file map is missing");
  } else if (buildFingerprintFromFiles(manifest.build.files) !== manifest.build.fingerprint) {
    errors.push("build manifest file map does not match its fingerprint");
  }
  if (computeRunId(manifest) !== manifest.runId) {
    errors.push("build manifest run ID is invalid");
  }
  if (errors.length > 0) throw new Error(errors.join("; "));
}

function hostEnvironment(root) {
  const flutter = JSON.parse(command(root, "flutter", ["--version", "--machine"]));
  const hardware = command(root, "system_profiler", ["SPHardwareDataType"]);
  const value = name => hardware.match(new RegExp(`${name}:\\s*(.+)`))?.[1]?.trim();
  const model = value("Model Identifier");
  const chip = value("Chip");
  const memory = value("Memory");
  if (!model || !chip || !memory) throw new Error("could not identify host hardware");
  const productVersion = command(root, "sw_vers", ["-productVersion"]);
  const buildVersion = command(root, "sw_vers", ["-buildVersion"]);
  return {
    flutterVersion: flutter.frameworkVersion,
    dartVersion: flutter.dartSdkVersion,
    buildMode: "profile",
    hostModel: `${model} / ${chip} / ${memory}`,
    osVersion: `macOS ${productVersion} (${buildVersion})`,
    deviceKind: "browser",
    refreshRateHz: "not_applicable",
  };
}

function createManifest(root, source) {
  const collectorPath = path.join(root, "audit", "scripts", "collect_web_startup.playwright.js");
  const manifest = {
    schemaVersion: 1,
    createdAt: new Date().toISOString(),
    source: {
      commit: command(root, "git", ["rev-parse", "HEAD"]),
      dirtyState: command(root, "git", ["status", "--porcelain=v1"]) ? "dirty" : "clean",
      runtimeStatus: source.status,
      runtimeFingerprint: source.fingerprint,
    },
    environment: hostEnvironment(root),
    build: buildArtifacts(root),
    collectionContract: {
      scenarioVersion: "web-onboarding-startup-v1",
      playwrightCliVersion: "0.1.19",
      viewport: "390x844@1x",
      locale: "ru-RU",
      network: "127.0.0.1 local HTTP server; CDP latency 0; throughput unlimited",
      authState: "signed out; onboarding",
      cacheState: "cold; fresh context; service workers blocked; HTTP cache disabled",
      collectorSha256: hashFile(collectorPath),
      collectorEvidenceSha256: null,
      collectorPath: path.relative(root, collectorPath),
    },
    runNonce: randomUUID(),
  };
  manifest.runId = computeRunId(manifest);
  return manifest;
}

function verifyManifest(root, manifest) {
  const source = runtimeSourceSnapshot(root);
  const artifacts = buildArtifacts(root);
  const environment = hostEnvironment(root);
  const collectorPath = path.join(root, manifest.collectionContract.collectorPath);
  const errors = [];
  if (source.fingerprint !== manifest.source.runtimeFingerprint ||
      source.status !== manifest.source.runtimeStatus) {
    errors.push("runtime source changed after the measured build");
  }
  if (artifacts.fingerprint !== manifest.build.fingerprint) {
    errors.push("build artifacts changed after manifest creation");
  }
  if (JSON.stringify(artifacts.files) !== JSON.stringify(manifest.build.files)) {
    errors.push("build artifact file map changed after manifest creation");
  }
  if (hashFile(collectorPath) !== manifest.collectionContract.collectorSha256) {
    errors.push("collector changed after manifest creation");
  }
  if (JSON.stringify(environment) !== JSON.stringify(manifest.environment)) {
    errors.push("host environment changed after manifest creation");
  }
  try {
    verifyManifestIntegrity(manifest);
  } catch (error) {
    errors.push(error.message);
  }
  if (errors.length > 0) throw new Error(errors.join("; "));
}

function main() {
  const [manifestPath] = process.argv.slice(2);
  if (!manifestPath) {
    console.error("Usage: prepare_web_performance_build.js <manifest.json>");
    process.exitCode = 2;
    return;
  }
  const root = path.resolve(__dirname, "..", "..");
  const before = runtimeSourceSnapshot(root);
  const build = spawnSync("flutter", ["build", "web", "--profile", "--source-maps"], {
    cwd: root,
    stdio: "inherit",
  });
  if (build.status !== 0) process.exit(build.status ?? 1);
  const after = runtimeSourceSnapshot(root);
  if (before.fingerprint !== after.fingerprint || before.status !== after.status) {
    throw new Error("runtime source changed during build");
  }
  const manifest = createManifest(root, after);
  const output = path.resolve(manifestPath);
  fs.mkdirSync(path.dirname(output), {recursive: true});
  fs.writeFileSync(output, `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`Performance build manifest: ${output}`);
}

if (require.main === module) main();

module.exports = {
  buildArtifacts,
  buildFingerprintFromFiles,
  computeRunId,
  createManifest,
  hashFile,
  hostEnvironment,
  runtimeSourceSnapshot,
  verifyManifest,
  verifyManifestIntegrity,
};
