#!/usr/bin/env node

const {spawnSync} = require("node:child_process");
const {
  REQUIRED_FUNCTIONS,
} = require("./validate_deployment_readiness");

const DEFAULT_PROJECT_ID = "smalltalk-2109b";
const DEFAULT_FIREBASE_CONFIG = "firebase/firebase.json";
const DEFAULT_COMMAND_ATTEMPTS = 3;
const DEFAULT_COMMAND_TIMEOUT_MS = 30000;

const REQUIRED_SECRETS = Object.freeze(
  [...new Set(
    REQUIRED_FUNCTIONS
      .flatMap((required) => required.secrets || [])
      .filter(Boolean),
  )].sort(),
);

function parseArgs(argv = process.argv.slice(2)) {
  const options = {
    configPath: DEFAULT_FIREBASE_CONFIG,
    firebaseBin: "firebase",
    json: false,
    projectId: DEFAULT_PROJECT_ID,
    commandAttempts: DEFAULT_COMMAND_ATTEMPTS,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--config") {
      options.configPath = argv[index + 1] || "";
      index += 1;
    } else if (arg === "--firebase-bin") {
      options.firebaseBin = argv[index + 1] || "";
      index += 1;
    } else if (arg === "--json") {
      options.json = true;
    } else if (arg === "--project") {
      options.projectId = argv[index + 1] || "";
      index += 1;
    } else if (arg === "--attempts") {
      options.commandAttempts =
        Number(argv[index + 1]) || DEFAULT_COMMAND_ATTEMPTS;
      index += 1;
    }
  }

  return options;
}

function parseFirebaseJson(rawOutput) {
  const raw = String(rawOutput || "").trim();
  const jsonStart = raw.indexOf("{");
  if (jsonStart < 0) {
    return null;
  }

  try {
    return JSON.parse(raw.slice(jsonStart));
  } catch (_error) {
    return null;
  }
}

function secretVersionsFromMetadata(metadata) {
  if (!metadata || typeof metadata !== "object") {
    return [];
  }
  if (Array.isArray(metadata.result?.secrets)) {
    return metadata.result.secrets;
  }
  if (Array.isArray(metadata.secrets)) {
    return metadata.secrets;
  }
  if (Array.isArray(metadata.result)) {
    return metadata.result;
  }
  return [];
}

function analyzeSecretMetadata(secretName, metadata) {
  if (!metadata || metadata.status === "error") {
    return {
      ok: false,
      reason: "missing_secret",
      message: `${secretName} secret is missing or inaccessible`,
    };
  }

  const versions = secretVersionsFromMetadata(metadata);
  if (versions.length === 0) {
    return {
      ok: false,
      reason: "missing_enabled_version",
      message: `${secretName} has no enabled secret version`,
    };
  }

  const hasEnabledVersion = versions.some((version) =>
    String(version.state || "").toUpperCase() === "ENABLED",
  );
  if (!hasEnabledVersion) {
    return {
      ok: false,
      reason: "missing_enabled_version",
      message: `${secretName} has no enabled secret version`,
    };
  }

  return {ok: true};
}

function readSecretMetadataWithRetry({
  configPath,
  firebaseBin,
  projectId,
  runCommand,
  secretName,
  timeoutMs,
  commandAttempts = DEFAULT_COMMAND_ATTEMPTS,
}) {
  const attempts = Math.max(1, commandAttempts);
  let lastErrorMetadata = null;

  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const result = runCommand(firebaseBin, [
      "functions:secrets:get",
      secretName,
      "--project",
      projectId,
      "--config",
      configPath,
      "--json",
    ], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
      timeout: timeoutMs,
    });

    if (result.error) {
      continue;
    }

    const metadata = parseFirebaseJson(result.stdout);
    if (metadata) {
      if (metadata.status === "error") {
        lastErrorMetadata = metadata;
        continue;
      }
      return {metadata};
    }
  }

  if (lastErrorMetadata) {
    return {metadata: lastErrorMetadata};
  }

  return {
    failure: {
      id: secretName,
      reason: "metadata_check_failed",
      message: `${secretName} secret metadata check failed`,
    },
  };
}

function checkSecretReadiness({
  commandAttempts = DEFAULT_COMMAND_ATTEMPTS,
  configPath = DEFAULT_FIREBASE_CONFIG,
  firebaseBin = "firebase",
  projectId = DEFAULT_PROJECT_ID,
  requiredSecrets = REQUIRED_SECRETS,
  runCommand = spawnSync,
  timeoutMs = DEFAULT_COMMAND_TIMEOUT_MS,
} = {}) {
  const failures = [];

  for (const secretName of requiredSecrets) {
    if (!/^[A-Z0-9_]+$/.test(secretName)) {
      failures.push({
        id: secretName,
        reason: "invalid_secret_name",
        message: `${secretName} is not a valid Firebase secret name`,
      });
      continue;
    }

    const {failure, metadata} = readSecretMetadataWithRetry({
      commandAttempts,
      configPath,
      firebaseBin,
      projectId,
      runCommand,
      secretName,
      timeoutMs,
    });
    if (failure) {
      failures.push(failure);
      continue;
    }

    const analysis = analyzeSecretMetadata(secretName, metadata);
    if (!analysis.ok) {
      failures.push({
        id: secretName,
        reason: analysis.reason,
        message: analysis.message,
      });
    }
  }

  return {
    ok: failures.length === 0,
    projectId,
    checkedSecrets: requiredSecrets.length,
    failures,
  };
}

function formatSecretReadinessReport(report) {
  const lines = [
    `Firebase secret readiness for ${report.projectId}: ${
      report.ok ? "PASS" : "FAIL"
    }`,
    `checked=${report.checkedSecrets}`,
  ];

  for (const failure of report.failures) {
    lines.push(`FAIL ${failure.id}: ${failure.message}`);
  }

  return lines.join("\n");
}

function main() {
  const options = parseArgs();
  const report = checkSecretReadiness({
    configPath: options.configPath || DEFAULT_FIREBASE_CONFIG,
    commandAttempts: options.commandAttempts || DEFAULT_COMMAND_ATTEMPTS,
    firebaseBin: options.firebaseBin || "firebase",
    projectId: options.projectId || DEFAULT_PROJECT_ID,
  });

  if (options.json) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } else {
    process.stdout.write(`${formatSecretReadinessReport(report)}\n`);
  }

  process.exitCode = report.ok ? 0 : 1;
}

if (require.main === module) {
  main();
}

module.exports = {
  DEFAULT_COMMAND_TIMEOUT_MS,
  DEFAULT_COMMAND_ATTEMPTS,
  DEFAULT_FIREBASE_CONFIG,
  REQUIRED_SECRETS,
  analyzeSecretMetadata,
  checkSecretReadiness,
  formatSecretReadinessReport,
  parseFirebaseJson,
  readSecretMetadataWithRetry,
};
