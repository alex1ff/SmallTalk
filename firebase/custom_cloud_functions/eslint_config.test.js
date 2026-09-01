const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const {ESLint} = require("eslint");

const lint = new ESLint({cwd: path.resolve(__dirname)});
const fixturePath = path.join(__dirname, "lint_contract_fixture.js");

test("ESLint flat config preserves required backend guardrails", async () => {
  const config = await lint.calculateConfigForFile(fixturePath);

  assert.equal(config.languageOptions.sourceType, "commonjs");
  assert.equal(config.linterOptions.reportUnusedDisableDirectives, 2);
  for (const ruleId of [
    "no-undef",
    "no-unused-vars",
    "no-promise-executor-return",
  ]) {
    assert.equal(config.rules[ruleId][0], 2, `${ruleId} must remain an error`);
  }
});

test("ESLint flat config rejects core correctness violations", async () => {
  const [result] = await lint.lintText(
      "const unused = 1;\nmissingGlobal();\n",
      {filePath: fixturePath},
  );
  const ruleIds = new Set(result.messages.map((message) => message.ruleId));

  assert.equal(result.errorCount, 2);
  assert.equal(ruleIds.has("no-unused-vars"), true);
  assert.equal(ruleIds.has("no-undef"), true);
});

test("ESLint flat config rejects implicit Promise executor returns", async () => {
  const [result] = await lint.lintText(
      "module.exports = new Promise((resolve) => setTimeout(resolve, 1));\n",
      {filePath: fixturePath},
  );

  assert.equal(result.errorCount, 1);
  assert.equal(result.messages[0].ruleId, "no-promise-executor-return");
});

test("ESLint flat config accepts Node CommonJS and safe Promise executors", async () => {
  const [result] = await lint.lintText(
      [
        "const fs = require(\"node:fs\");",
        "function wait(delayMs) {",
        "  return new Promise((resolve) => {",
        "    setTimeout(resolve, delayMs);",
        "  });",
        "}",
        "module.exports = {fs, wait};",
        "",
      ].join("\n"),
      {filePath: fixturePath},
  );

  assert.deepEqual(result.messages, []);
});
