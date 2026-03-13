#!/usr/bin/env node

const admin = require("firebase-admin");

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function parseArgs(argv) {
  const args = {
    uid: "",
    projectId: normalizeString(
      process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT,
    ),
    remove: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--remove") {
      args.remove = true;
      continue;
    }
    if (arg === "--uid" && argv[index + 1]) {
      args.uid = normalizeString(argv[index + 1]);
      index += 1;
      continue;
    }
    if (arg.startsWith("--uid=")) {
      args.uid = normalizeString(arg.split("=").slice(1).join("="));
      continue;
    }
    if (arg === "--project" && argv[index + 1]) {
      args.projectId = normalizeString(argv[index + 1]);
      index += 1;
      continue;
    }
    if (arg.startsWith("--project=")) {
      args.projectId = normalizeString(arg.split("=").slice(1).join("="));
    }
  }

  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.uid) {
    throw new Error("Missing required --uid argument.");
  }

  const appConfig = {};
  if (args.projectId) {
    appConfig.projectId = args.projectId;
  }
  if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    appConfig.credential = admin.credential.applicationDefault();
  }

  admin.initializeApp(appConfig);

  const auth = admin.auth();
  const userRecord = await auth.getUser(args.uid);
  const nextClaims = {
    ...(userRecord.customClaims || {}),
  };

  if (args.remove) {
    delete nextClaims.admin;
  } else {
    nextClaims.admin = true;
  }

  await auth.setCustomUserClaims(args.uid, nextClaims);

  console.log(
    JSON.stringify({
      uid: args.uid,
      email: userRecord.email || null,
      projectId: args.projectId || null,
      admin: !args.remove,
      customClaims: nextClaims,
    }, null, 2),
  );
}

main().catch((error) => {
  console.error("Failed to update admin claim:", error);
  process.exitCode = 1;
});
