const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {
  DEFAULT_COMMAND_TIMEOUT_MS,
  DEFAULT_COMMAND_ATTEMPTS,
  DEFAULT_FIREBASE_CONFIG,
  REQUIRED_SECRETS,
  analyzeSecretMetadata,
  checkSecretReadiness,
  formatSecretReadinessReport,
  parseFirebaseJson,
} = require("./scripts/validate_secret_readiness");
const {
  REQUIRED_FUNCTIONS,
} = require("./scripts/validate_deployment_readiness");

function successMetadata(secretName) {
  return {
    status: "success",
    result: {
      secrets: [{
        secret: {name: secretName},
        versionId: "1",
        state: "ENABLED",
      }],
    },
  };
}

test("secret readiness derives required secret names from deployment gate", () => {
  assert.deepEqual(REQUIRED_SECRETS, [
    "APNS_KEY_ID",
    "APNS_KEY_P8",
    "APNS_TEAM_ID",
    "DAILY_API_KEY",
    "DAILY_DOMAIN",
    "DAILY_WEBHOOK_SECRET",
    "DEEPGRAM_API_KEY",
    "RESEND_API_KEY",
    "REVENUECAT_SECRET_API_KEY",
    "REVENUECAT_WEBHOOK_SECRET",
  ]);
});

test("secret readiness accepts enabled secret metadata", () => {
  const analysis = analyzeSecretMetadata(
    "DAILY_API_KEY",
    successMetadata("DAILY_API_KEY"),
  );

  assert.equal(analysis.ok, true);
});

test("secret readiness rejects missing or disabled secrets", () => {
  const missing = analyzeSecretMetadata("DAILY_WEBHOOK_SECRET", {
    status: "error",
    error: "not found",
  });
  const disabled = analyzeSecretMetadata("APNS_KEY_P8", {
    status: "success",
    result: {
      secrets: [{state: "DISABLED"}],
    },
  });

  assert.equal(missing.ok, false);
  assert.equal(missing.reason, "missing_secret");
  assert.equal(disabled.ok, false);
  assert.equal(disabled.reason, "missing_enabled_version");
});

test("secret readiness report does not include secret values", () => {
  const secretValue = "raw secret value must not be printed";
  const runCommand = (_bin, args) => {
    const secretName = args[1];
    return {
      stdout: JSON.stringify({
        status: secretName === "DAILY_WEBHOOK_SECRET" ? "error" : "success",
        result: successMetadata(secretName).result,
        value: secretValue,
      }),
    };
  };

  const report = checkSecretReadiness({
    requiredSecrets: ["DAILY_API_KEY", "DAILY_WEBHOOK_SECRET"],
    runCommand,
  });
  const output = formatSecretReadinessReport(report);

  assert.equal(report.ok, false);
  assert.match(output, /DAILY_WEBHOOK_SECRET/);
  assert.doesNotMatch(output, /raw secret value/);
  assert.doesNotMatch(JSON.stringify(report.failures), /raw secret value/);
});

test("secret readiness invokes firebase metadata checks without access", () => {
  const calls = [];
  const runCommand = (bin, args, options) => {
    calls.push({bin, args, options});
    return {stdout: JSON.stringify(successMetadata(args[1]))};
  };

  const report = checkSecretReadiness({
    configPath: "firebase/firebase.json",
    firebaseBin: "firebase",
    projectId: "smalltalk-2109b",
    requiredSecrets: ["DAILY_API_KEY"],
    runCommand,
  });

  assert.equal(report.ok, true);
  assert.deepEqual(calls[0].args, [
    "functions:secrets:get",
    "DAILY_API_KEY",
    "--project",
    "smalltalk-2109b",
    "--config",
    "firebase/firebase.json",
    "--json",
  ]);
  assert.equal(calls[0].options.stdio[0], "ignore");
  assert.equal(calls[0].options.timeout, DEFAULT_COMMAND_TIMEOUT_MS);
});

test("secret readiness retries transient metadata command failures", () => {
  const calls = [];
  const runCommand = (bin, args, options) => {
    calls.push({bin, args, options});
    if (calls.length === 1) {
      return {error: new Error("timeout")};
    }
    return {stdout: JSON.stringify(successMetadata(args[1]))};
  };

  const report = checkSecretReadiness({
    commandAttempts: DEFAULT_COMMAND_ATTEMPTS,
    requiredSecrets: ["REVENUECAT_WEBHOOK_SECRET"],
    runCommand,
  });

  assert.equal(report.ok, true);
  assert.equal(calls.length, 2);
});

test("secret readiness retries transient firebase json error output", () => {
  const calls = [];
  const runCommand = (bin, args, options) => {
    calls.push({bin, args, options});
    if (calls.length === 1) {
      return {
        status: 1,
        stdout: JSON.stringify({
          status: "error",
          error: "transient metadata read failed",
        }),
      };
    }
    return {stdout: JSON.stringify(successMetadata(args[1]))};
  };

  const report = checkSecretReadiness({
    commandAttempts: DEFAULT_COMMAND_ATTEMPTS,
    requiredSecrets: ["RESEND_API_KEY"],
    runCommand,
  });

  assert.equal(report.ok, true);
  assert.equal(calls.length, 2);
});

test("secret readiness reports metadata command failures without values", () => {
  const report = checkSecretReadiness({
    commandAttempts: 2,
    requiredSecrets: ["DAILY_API_KEY"],
    runCommand: () => ({
      error: new Error("raw command failure with no secret value"),
      stdout: "raw command output",
    }),
  });
  const output = formatSecretReadinessReport(report);

  assert.equal(report.ok, false);
  assert.equal(report.failures[0].reason, "metadata_check_failed");
  assert.match(output, /DAILY_API_KEY/);
  assert.doesNotMatch(output, /raw command/);
});

test("package script points at firebase config from the package cwd", () => {
  const packageJson = JSON.parse(fs.readFileSync(
    `${__dirname}/package.json`,
    "utf8",
  ));

  assert.equal(DEFAULT_FIREBASE_CONFIG, "firebase/firebase.json");
  assert.match(
    packageJson.scripts["validate:secret-readiness"],
    /--config \.\.\/firebase\.json/,
  );
});

test("package deploy script is scoped to readiness-gate functions", () => {
  const packageJson = JSON.parse(fs.readFileSync(
    `${__dirname}/package.json`,
    "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];

  assert.equal(packageJson.scripts.deploy, "npm run deploy:readiness-functions");
  assert.match(deployScript, /--project smalltalk-2109b/);
  assert.match(deployScript, /--config \.\.\/firebase\.json/);
  assert.doesNotMatch(deployScript, /--only functions( |$)/);
  for (const required of REQUIRED_FUNCTIONS) {
    assert.match(
      deployScript,
      new RegExp(`functions:custom_cloud_functions:${required.id}(,|$)`),
    );
  }
});

test("secret readiness parses copied firebase json output", () => {
  const parsed = parseFirebaseJson(`
warning can be copied here
{"status":"success","result":{"secrets":[{"state":"ENABLED"}]}}
`);

  assert.equal(parsed.status, "success");
});
