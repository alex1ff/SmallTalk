#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const {
  comparePerformanceSnapshots,
  validatePerformanceSnapshot,
} = require("../performance_budget");

function readJson(file) {
  return JSON.parse(fs.readFileSync(path.resolve(process.cwd(), file), "utf8"));
}

const [baselinePath, candidatePath] = process.argv.slice(2);
if (!baselinePath) {
  console.error("Usage: node audit/scripts/validate_performance_budget.js <snapshot> [candidate]");
  process.exit(2);
}
const baseline = readJson(baselinePath);
if (!candidatePath) {
  const errors = validatePerformanceSnapshot(baseline);
  console.log(JSON.stringify({status: errors.length === 0 ? "valid" : "invalid", errors}, null, 2));
  process.exit(errors.length === 0 ? 0 : 1);
}
const result = comparePerformanceSnapshots(baseline, readJson(candidatePath));
console.log(JSON.stringify(result, null, 2));
process.exit(result.status === "invalid" || result.status === "incompatible" ||
  Object.values(result.metrics ?? {}).some((metric) =>
    metric.status === "regression" || metric.status === "incompatible",
  ) ? 1 : 0);
