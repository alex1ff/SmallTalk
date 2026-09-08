#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const {hashFile, computeRunId} = require("./prepare_web_performance_build");

function main() {
  const [manifestPath, evidencePath] = process.argv.slice(2);
  if (!manifestPath || !evidencePath) {
    console.error("Usage: record_web_performance_evidence.js <manifest.json> <collector-output.json>");
    process.exitCode = 2;
    return;
  }
  const manifestFile = path.resolve(manifestPath);
  const manifest = JSON.parse(fs.readFileSync(manifestFile, "utf8"));
  manifest.collectionContract.collectorEvidenceSha256 = hashFile(path.resolve(evidencePath));
  if (computeRunId(manifest) !== manifest.runId) {
    throw new Error("recording evidence changed the build manifest run ID");
  }
  fs.writeFileSync(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`);
}

if (require.main === module) main();

module.exports = {main};
