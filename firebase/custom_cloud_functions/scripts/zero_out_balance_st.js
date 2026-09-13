#!/usr/bin/env node

// zero_out_balance_st.js
//
// One-shot migration script for the subscription cutover.
//
// Goal: set users/{uid}.balanceST.minutes = 0 and .smallTalks = 0 for every
// user, while leaving balance_NS (tutor earnings) untouched. After this
// runs, the legacy pre-paid credit model is dead — student gating switches
// entirely to the subscription state mirrored from RevenueCat.
//
// Idempotent: a user with `subscription_migration_zeroed_at` set is
// skipped on repeat runs.
//
// Safety:
// - Defaults to dry-run; pass --commit to actually write.
// - Pass --project <id> to target a specific Firebase project (defaults to
//   GCLOUD_PROJECT / GOOGLE_CLOUD_PROJECT env vars).
// - Batched in chunks of BATCH_WRITE_LIMIT to stay within Firestore's
//   500-write-per-batch ceiling.
//
// Usage:
//   node scripts/zero_out_balance_st.js                       # dry run
//   node scripts/zero_out_balance_st.js --commit              # apply
//   node scripts/zero_out_balance_st.js --project smalltalk-2109b --commit
//
// Prerequisites: gcloud / Firebase admin credentials must already be set
// (e.g. `gcloud auth application-default login`).

const admin = require("firebase-admin");

const BATCH_WRITE_LIMIT = 400;
const MIGRATION_MARKER_FIELD = "subscription_migration_zeroed_at";

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

function needsZero(userData) {
  if (!userData) return false;
  if (userData[MIGRATION_MARKER_FIELD]) {
    return false; // already migrated
  }
  const minutes = Number(userData.balanceST?.minutes);
  const smallTalks = Number(userData.balanceST?.smallTalks);
  // Touch the doc even when both are already zero (or missing) so we set
  // the marker once and never need to revisit. The dot-notation write is
  // cheap; the savings come from skipping repeat runs.
  return Number.isFinite(minutes) || Number.isFinite(smallTalks) || true;
}

async function collectPatches(db) {
  const usersSnap = await db.collection("users").get();
  const stats = {
    totalUsers: usersSnap.size,
    alreadyMigrated: 0,
    zeroedFresh: 0,
    pendingWrites: 0,
  };
  const patches = [];

  usersSnap.docs.forEach((doc) => {
    const userData = doc.data() || {};
    if (userData[MIGRATION_MARKER_FIELD]) {
      stats.alreadyMigrated += 1;
      return;
    }
    if (!needsZero(userData)) {
      return;
    }
    stats.zeroedFresh += 1;
    patches.push({
      ref: doc.ref,
      data: {
        "balanceST.minutes": 0,
        "balanceST.smallTalks": 0,
        [MIGRATION_MARKER_FIELD]: admin.firestore.FieldValue.serverTimestamp(),
      },
      // Snapshot of the pre-migration balance for the audit log.
      previous: {
        minutes: userData.balanceST?.minutes ?? null,
        smallTalks: userData.balanceST?.smallTalks ?? null,
      },
      uid: doc.id,
    });
  });

  stats.pendingWrites = patches.length;
  return {patches, stats};
}

async function commitPatches(db, patches, dryRun) {
  if (dryRun || patches.length === 0) {
    return {
      committedBatches: 0,
      committedWrites: 0,
    };
  }

  let batch = db.batch();
  let batchSize = 0;
  let committedBatches = 0;
  let committedWrites = 0;

  for (const patch of patches) {
    batch.update(patch.ref, patch.data);
    batchSize += 1;

    if (batchSize >= BATCH_WRITE_LIMIT) {
      await batch.commit();
      committedBatches += 1;
      committedWrites += batchSize;
      batch = db.batch();
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
    admin.initializeApp(
        args.projectId ? {projectId: args.projectId} : undefined,
    );
  }

  const db = admin.firestore();
  const {patches, stats} = await collectPatches(db);
  const commitStats = await commitPatches(db, patches, args.dryRun);

  console.log(JSON.stringify({
    dryRun: args.dryRun,
    projectId: args.projectId || null,
    ...stats,
    ...commitStats,
    sample: patches.slice(0, 5).map((p) => ({
      uid: p.uid,
      previous: p.previous,
    })),
  }, null, 2));
}

main().catch((error) => {
  console.error("zero_out_balance_st failed:", error);
  process.exit(1);
});
