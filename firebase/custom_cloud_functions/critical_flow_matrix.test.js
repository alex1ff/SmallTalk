const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.join(__dirname, "..", "..");
const matrix = JSON.parse(fs.readFileSync(
  path.join(repoRoot, "audit", "critical_flow_matrix.json"),
  "utf8",
));

test("critical flow matrix is versioned and separates evidence levels", () => {
  assert.equal(matrix.schemaVersion, 1);
  assert.ok(Array.isArray(matrix.matrix) && matrix.matrix.length >= 5);
  const ids = new Set();
  for (const flow of matrix.matrix) {
    assert.equal(ids.has(flow.id), false);
    ids.add(flow.id);
    for (const field of ["level", "preconditions", "actions", "postconditions", "cleanup", "command", "status"]) {
      assert.ok(flow[field], `${flow.id} missing ${field}`);
    }
  }
  const routing = matrix.matrix.filter((flow) => flow.level === "routing-characterization");
  assert.ok(routing.length >= 3);
  assert.ok(routing.every((flow) => flow.status === "pr"));
  assert.ok(matrix.matrix.filter((flow) => flow.level === "real-emulator").every((flow) => flow.status !== "pr"));
  assert.ok(matrix.matrix.filter((flow) => flow.level === "device-sandbox").every((flow) => flow.status !== "pr"));
});
