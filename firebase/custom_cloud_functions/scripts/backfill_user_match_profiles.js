#!/usr/bin/env node

const admin = require("firebase-admin");

const {
  buildStoredMatchProfile,
  hasLegacyMatchProfileSource,
} = require("../video_sessions_shared");

const BATCH_WRITE_LIMIT = 400;

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function parseArgs(argv) {
  const args = {
    dryRun: true,
    projectId: normalizeString(
      process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT,
    ),
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--commit") {
      args.dryRun = false;
      continue;
    }
    if (arg === "--dry-run") {
      args.dryRun = true;
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

function sortObject(value) {
  if (Array.isArray(value)) {
    return value.map((entry) => sortObject(entry));
  }

  if (value && typeof value === "object") {
    return Object.keys(value)
      .sort()
      .reduce((acc, key) => {
        acc[key] = sortObject(value[key]);
        return acc;
      }, {});
  }

  return value;
}

function areEqual(left, right) {
  return JSON.stringify(sortObject(left)) === JSON.stringify(sortObject(right));
}

async function collectPatches(db) {
  const usersSnap = await db.collection("users").get();
  const patches = [];
  const stats = {
    totalUsers: usersSnap.size,
    missingMatchProfile: 0,
    staleMatchProfile: 0,
    unchangedUsers: 0,
    pendingWrites: 0,
  };

  usersSnap.docs.forEach((doc) => {
    const userData = doc.data() || {};
    const preserveStoredValues =
      !hasLegacyMatchProfileSource(userData) && !!userData.matchProfile;
    const desiredMatchProfile = buildStoredMatchProfile(
      doc.id,
      userData,
      {preserveStoredValues},
    );
    const existingMatchProfile = userData.matchProfile || null;

    if (areEqual(existingMatchProfile, desiredMatchProfile)) {
      stats.unchangedUsers += 1;
      return;
    }

    if (existingMatchProfile == null) {
      stats.missingMatchProfile += 1;
    } else {
      stats.staleMatchProfile += 1;
    }

    patches.push({
      ref: doc.ref,
      data: {
        matchProfile: desiredMatchProfile,
      },
    });
  });

  stats.pendingWrites = patches.length;
  return {patches, stats};
}

async function commitPatches(patches, dryRun) {
  if (dryRun || patches.length === 0) {
    return {
      committedBatches: 0,
      committedWrites: 0,
    };
  }

  let batch = admin.firestore().batch();
  let batchSize = 0;
  let committedBatches = 0;
  let committedWrites = 0;

  for (const patch of patches) {
    batch.set(patch.ref, patch.data, {merge: true});
    batchSize += 1;

    if (batchSize >= BATCH_WRITE_LIMIT) {
      await batch.commit();
      committedBatches += 1;
      committedWrites += batchSize;
      batch = admin.firestore().batch();
      batchSize = 0;
    }
  }

  if (batchSize > 0) {
    await batch.commit();
    committedBatches += 1;
    committedWrites += batchSize;
  }

  return {
    committedBatches,
    committedWrites,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!admin.apps.length) {
    admin.initializeApp(args.projectId ? {projectId: args.projectId} : undefined);
  }

  const db = admin.firestore();
  const {patches, stats} = await collectPatches(db);
  const commitStats = await commitPatches(patches, args.dryRun);

  console.log(JSON.stringify({
    dryRun: args.dryRun,
    projectId: args.projectId || null,
    ...stats,
    ...commitStats,
  }, null, 2));
}

main().catch((error) => {
  console.error("backfill_user_match_profiles failed:", error);
  process.exit(1);
});
