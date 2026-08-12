#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const DEFAULT_PROJECT_ID = "smalltalk-2109b";
const APNS_SECRETS = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const DAILY_SECRETS = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const DEEPGRAM_SECRETS = ["DEEPGRAM_API_KEY"];
const IOS_PUSH_ENVIRONMENT = {
  IOS_BUNDLE_ID: "com.appwave.expatlio",
  IOS_VOIP_TOPIC: "com.appwave.expatlio.voip",
};
const REQUIRED_DEPLOY_TARGETS = ["firestore:rules", "firestore:indexes"];

const REQUIRED_FUNCTIONS = [
  {id: "cleanupUserCallIntegrationsOnDelete", trigger: "auth"},
  {
    id: "createVideoSession",
    trigger: "callable",
    secrets: [...APNS_SECRETS, ...DAILY_SECRETS],
    environment: IOS_PUSH_ENVIRONMENT,
  },
  {
    id: "acceptCall",
    trigger: "callable",
    secrets: [...APNS_SECRETS, ...DAILY_SECRETS],
    environment: IOS_PUSH_ENVIRONMENT,
  },
  {
    id: "declineCall",
    trigger: "callable",
    secrets: [...APNS_SECRETS, ...DAILY_SECRETS],
    environment: IOS_PUSH_ENVIRONMENT,
  },
  {
    id: "cancelCall",
    trigger: "callable",
    secrets: DAILY_SECRETS,
  },
  {
    id: "startSearch",
    trigger: "callable",
    secrets: APNS_SECRETS,
    environment: IOS_PUSH_ENVIRONMENT,
  },
  {
    id: "respondToMatch",
    trigger: "callable",
    secrets: [...APNS_SECRETS, ...DAILY_SECRETS],
    environment: IOS_PUSH_ENVIRONMENT,
  },
  {
    id: "processMatchProtocolV2State",
    trigger: "firestore",
    secrets: [...APNS_SECRETS, ...DAILY_SECRETS],
    environment: IOS_PUSH_ENVIRONMENT,
  },
  {
    id: "recoverMatchProtocolV2State",
    trigger: "scheduled",
    secrets: [...APNS_SECRETS, ...DAILY_SECRETS],
    environment: IOS_PUSH_ENVIRONMENT,
  },
  {
    id: "stopSearch",
    trigger: "callable",
    secrets: [...APNS_SECRETS, ...DAILY_SECRETS],
    environment: IOS_PUSH_ENVIRONMENT,
  },
  {id: "heartbeatSearch", trigger: "callable"},
  {id: "cleanupStaleSearchRequests", trigger: "scheduled"},
  {
    id: "endSession",
    trigger: "callable",
    secrets: [...APNS_SECRETS, ...DAILY_SECRETS],
    environment: IOS_PUSH_ENVIRONMENT,
  },
  {
    id: "cleanupExpiredSessions",
    trigger: "scheduled",
    secrets: [...APNS_SECRETS, ...DAILY_SECRETS],
    environment: IOS_PUSH_ENVIRONMENT,
  },
  {
    id: "processExpiredNotifications",
    trigger: "scheduled",
    secrets: [...APNS_SECRETS, ...DAILY_SECRETS],
    environment: IOS_PUSH_ENVIRONMENT,
  },
  {
    id: "getSessionTokens",
    trigger: "callable",
    secrets: DAILY_SECRETS,
  },
  {
    id: "getDeepgramToken",
    trigger: "callable",
    secrets: DEEPGRAM_SECRETS,
  },
  {
    id: "translateTerm",
    trigger: "callable",
    environment: {ENABLE_CALL_TRANSLATION: "true"},
  },
  {
    id: "saveTranslatedTerm",
    trigger: "callable",
    environment: {ENABLE_CALL_TRANSLATION: "true"},
  },
  {
    id: "generateCallFeedback",
    trigger: "callable",
    environment: {ENABLE_CALL_FEEDBACK: "true"},
  },
  {id: "requestSessionExtension", trigger: "callable"},
  {id: "persistCallChat", trigger: "callable"},
  {
    id: "dailyWebhook",
    trigger: "https",
    secrets: ["DAILY_WEBHOOK_SECRET", ...DAILY_SECRETS],
  },
  {
    id: "cleanupFailedDailyRoomDeletes",
    trigger: "scheduled",
    secrets: DAILY_SECRETS,
  },
  {id: "getDirectCallStatus", trigger: "callable"},
  {
    id: "markSessionConnected",
    trigger: "callable",
    secrets: DAILY_SECRETS,
  },
  {id: "registerVoipToken", trigger: "callable"},
  {id: "migrateLegacyVoipTokens", trigger: "callable"},
  {id: "scheduledLegacyVoipTokenMigration", trigger: "scheduled"},
  {id: "claimRegistrationGift", trigger: "callable"},
  {id: "createEvent", trigger: "callable"},
  {id: "editEvent", trigger: "callable"},
  {id: "cancelEvent", trigger: "callable"},
  {id: "joinEvent", trigger: "callable"},
  {id: "leaveEvent", trigger: "callable"},
  {id: "sendEventChatMessage", trigger: "callable"},
  {id: "getEventChatAccessState", trigger: "callable"},
  {id: "reportEvent", trigger: "callable"},
  {id: "reportEventChatMessage", trigger: "callable"},
  {id: "getEventHistory", trigger: "callable"},
  {id: "getCallHistory", trigger: "callable"},
  {id: "requestWithdrawal", trigger: "callable"},
  {id: "syncUserPublicProfile", trigger: "firestore"},
  {
    id: "revenueCatWebhook",
    trigger: "https",
    secrets: ["REVENUECAT_WEBHOOK_SECRET"],
  },
  {
    id: "grantPromoEntitlement",
    trigger: "callable",
    secrets: ["REVENUECAT_SECRET_KEY"],
  },
  {id: "redeemPromoCode", trigger: "callable"},
  {
    id: "sendCustomEmailVerification",
    trigger: "callable",
    secrets: ["RESEND_API_KEY"],
  },
  {id: "submitReview", trigger: "callable"},
];

const SECRET_ENV_KEYS = [
  "APNS_KEY",
  "APNS_KEY_ID",
  "APNS_KEY_P8",
  "APNS_TEAM_ID",
  "DAILY_API_KEY",
  "DAILY_DOMAIN",
  "DAILY_WEBHOOK_SECRET",
  "DEEPGRAM_API_KEY",
  "REVENUECAT_SECRET_KEY",
  "REVENUECAT_AUTH_HEADER",
  "REVENUECAT_WEBHOOK_SECRET",
  "RESEND_API_KEY",
];

function parseArgs(argv = process.argv.slice(2)) {
  const options = {
    json: false,
    projectId: DEFAULT_PROJECT_ID,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--json") {
      options.json = true;
    } else if (arg === "--project") {
      options.projectId = argv[index + 1] || "";
      index += 1;
    }
  }

  return options;
}

function parseFunctionsListJson(rawInput) {
  const raw = String(rawInput || "").trim();
  const jsonStart = raw.indexOf("{");
  if (jsonStart < 0) {
    throw new Error("Expected firebase functions:list --json input");
  }

  const parsed = JSON.parse(raw.slice(jsonStart));
  if (Array.isArray(parsed)) {
    return parsed;
  }
  if (Array.isArray(parsed.result)) {
    return parsed.result;
  }

  throw new Error("Expected a JSON result array from firebase functions:list");
}

function readSecretKeys(fn = {}) {
  return new Set(
    Array.isArray(fn.secretEnvironmentVariables) ?
      fn.secretEnvironmentVariables
        .map((secret) => secret && String(secret.key || "").trim())
        .filter(Boolean) :
      [],
  );
}

function hasTrigger(fn = {}, expectedTrigger) {
  if (expectedTrigger === "callable") {
    return Boolean(fn.callableTrigger);
  }
  if (expectedTrigger === "https") {
    return Boolean(fn.httpsTrigger);
  }
  if (expectedTrigger === "scheduled") {
    return Boolean(fn.scheduleTrigger);
  }
  if (expectedTrigger === "firestore") {
    return Boolean(fn.eventTrigger) &&
      String(fn.eventTrigger.eventType || "").includes("firestore");
  }
  if (expectedTrigger === "auth") {
    return Boolean(fn.eventTrigger) &&
      String(fn.eventTrigger.eventType || "").includes("user.delete");
  }
  return true;
}

function analyzeFunctionsDeployment(functionsList, {
  projectId = DEFAULT_PROJECT_ID,
  requiredFunctions = REQUIRED_FUNCTIONS,
  secretEnvKeys = SECRET_ENV_KEYS,
} = {}) {
  const deployedById = new Map(
    functionsList.map((fn) => [String(fn.id || ""), fn]),
  );
  const failures = [];
  const warnings = [];

  for (const required of requiredFunctions) {
    const deployed = deployedById.get(required.id);
    if (!deployed) {
      failures.push({
        id: required.id,
        reason: "missing_function",
        message: `${required.id} is not deployed`,
      });
      continue;
    }

    if (deployed.project && deployed.project !== projectId) {
      failures.push({
        id: required.id,
        reason: "wrong_project",
        message: `${required.id} is deployed to ${deployed.project}`,
      });
    }

    if (deployed.state && deployed.state !== "ACTIVE") {
      failures.push({
        id: required.id,
        reason: "inactive_function",
        message: `${required.id} state is ${deployed.state}`,
      });
    }

    const expectedCodebase = required.codebase || "custom_cloud_functions";
    if (deployed.codebase !== expectedCodebase) {
      failures.push({
        id: required.id,
        reason: "wrong_codebase",
        message: `${required.id} codebase is ${deployed.codebase || "unset"}`,
      });
    }

    if (!hasTrigger(deployed, required.trigger)) {
      failures.push({
        id: required.id,
        reason: "wrong_trigger",
        message: `${required.id} is not deployed as ${required.trigger}`,
      });
    }

    const deployedSecrets = readSecretKeys(deployed);
    for (const secretKey of required.secrets || []) {
      if (!deployedSecrets.has(secretKey)) {
        failures.push({
          id: required.id,
          reason: "missing_secret_binding",
          message: `${required.id} is missing ${secretKey} secret binding`,
        });
      }
    }

    const environment = deployed.environmentVariables || {};
    for (const [key, expectedValue] of Object.entries(
      required.environment || {},
    )) {
      if (String(environment[key] || "") !== expectedValue) {
        failures.push({
          id: required.id,
          reason: "missing_required_environment",
          message: `${required.id} requires ${key}=${expectedValue}`,
        });
      }
    }
  }

  for (const fn of functionsList) {
    const env = fn.environmentVariables || {};
    for (const secretKey of secretEnvKeys) {
      if (Object.prototype.hasOwnProperty.call(env, secretKey)) {
        failures.push({
          id: fn.id || "unknown",
          reason: "plaintext_secret_environment_variable",
          message: `${fn.id} exposes ${secretKey} as a plain env variable`,
        });
      }
    }
  }

  return {
    ok: failures.length === 0,
    projectId,
    checkedFunctions: requiredFunctions.length,
    deployedFunctions: functionsList.length,
    failures,
    warnings,
  };
}

function analyzeReadinessDeployCommand(
  deployCommand,
  requiredTargets = REQUIRED_DEPLOY_TARGETS,
) {
  const onlyMatch = String(deployCommand || "").match(/--only\s+([^\s]+)/);
  const targets = new Set(
    (onlyMatch?.[1] || "").split(",").map((value) => value.trim()),
  );
  const failures = requiredTargets
    .filter((target) => !targets.has(target))
    .map((target) => ({
      id: "deploy:readiness-functions",
      reason: "missing_deploy_target",
      message: `deploy:readiness-functions is missing ${target}`,
    }));
  return {ok: failures.length === 0, failures};
}

function formatReport(report) {
  const lines = [
    `Firebase deployment readiness for ${report.projectId}: ${
      report.ok ? "PASS" : "FAIL"
    }`,
    `checked=${report.checkedFunctions} deployed=${report.deployedFunctions}`,
  ];

  for (const failure of report.failures) {
    lines.push(`FAIL ${failure.id}: ${failure.message}`);
  }
  for (const warning of report.warnings) {
    lines.push(`WARN ${warning.id}: ${warning.message}`);
  }

  return lines.join("\n");
}

async function readStdin() {
  return await new Promise((resolve, reject) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => {
      data += chunk;
    });
    process.stdin.on("end", () => resolve(data));
    process.stdin.on("error", reject);
  });
}

async function main() {
  const options = parseArgs();
  const input = await readStdin();
  const functionsList = parseFunctionsListJson(input);
  const report = analyzeFunctionsDeployment(functionsList, {
    projectId: options.projectId || DEFAULT_PROJECT_ID,
  });
  const packageJson = JSON.parse(fs.readFileSync(
    path.join(__dirname, "..", "package.json"),
    "utf8",
  ));
  const deployReport = analyzeReadinessDeployCommand(
    packageJson.scripts?.["deploy:readiness-functions"],
  );
  report.failures.push(...deployReport.failures);
  report.ok = report.failures.length === 0;

  if (options.json) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } else {
    process.stdout.write(`${formatReport(report)}\n`);
  }

  process.exitCode = report.ok ? 0 : 1;
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`validate_deployment_readiness failed: ${error.message}`);
    process.exitCode = 1;
  });
}

module.exports = {
  REQUIRED_FUNCTIONS,
  REQUIRED_DEPLOY_TARGETS,
  SECRET_ENV_KEYS,
  analyzeFunctionsDeployment,
  analyzeReadinessDeployCommand,
  formatReport,
  parseFunctionsListJson,
};
