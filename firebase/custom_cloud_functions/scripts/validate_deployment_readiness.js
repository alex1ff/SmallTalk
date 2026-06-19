#!/usr/bin/env node

const DEFAULT_PROJECT_ID = "smalltalk-2109b";
const APNS_SECRETS = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const DAILY_SECRETS = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const DEEPGRAM_SECRETS = ["DEEPGRAM_API_KEY"];

const REQUIRED_FUNCTIONS = [
  {
    id: "createVideoSession",
    trigger: "callable",
    secrets: [...APNS_SECRETS, ...DAILY_SECRETS],
  },
  {
    id: "acceptCall",
    trigger: "callable",
    secrets: [...APNS_SECRETS, ...DAILY_SECRETS],
  },
  {
    id: "declineCall",
    trigger: "callable",
    secrets: [...APNS_SECRETS, ...DAILY_SECRETS],
  },
  {
    id: "cancelCall",
    trigger: "callable",
    secrets: DAILY_SECRETS,
  },
  {
    id: "endSession",
    trigger: "callable",
    secrets: DAILY_SECRETS,
  },
  {
    id: "cleanupExpiredSessions",
    trigger: "scheduled",
    secrets: DAILY_SECRETS,
  },
  {
    id: "processExpiredNotifications",
    trigger: "scheduled",
    secrets: [...APNS_SECRETS, ...DAILY_SECRETS],
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

    if (deployed.codebase !== "custom_cloud_functions") {
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
  SECRET_ENV_KEYS,
  analyzeFunctionsDeployment,
  formatReport,
  parseFunctionsListJson,
};
