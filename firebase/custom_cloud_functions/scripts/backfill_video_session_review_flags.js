#!/usr/bin/env node

const admin = require("firebase-admin");

const STUDENT_REVIEW_FLAG_FIELD = "studentHasReviewed";
const TUTOR_REVIEW_FLAG_FIELD = "tutorHasReviewed";
const BATCH_WRITE_LIMIT = 400;

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeDocumentPath(value) {
  if (typeof value === "string") {
    return value.trim().replace(/^\/+|\/+$/g, "");
  }
  if (value && typeof value.path === "string") {
    return value.path.trim().replace(/^\/+|\/+$/g, "");
  }
  return "";
}

function getDocumentId(value) {
  const path = normalizeDocumentPath(value);
  if (!path) {
    return "";
  }
  const segments = path.split("/").filter(Boolean);
  return segments.length > 0 ? segments[segments.length - 1] : "";
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

function createSessionInfo(ref, sessionData) {
  return {
    ref,
    studentId: normalizeString(sessionData.studentId),
    tutorId: normalizeString(sessionData.tutorId),
    studentHasReviewed: sessionData[STUDENT_REVIEW_FLAG_FIELD] === true,
    tutorHasReviewed: sessionData[TUTOR_REVIEW_FLAG_FIELD] === true,
  };
}

function queuePatch(patchesByPath, ref, data) {
  if (!ref || !ref.path || !data || Object.keys(data).length === 0) {
    return;
  }

  const existing = patchesByPath.get(ref.path) || {
    ref,
    data: {},
  };
  existing.data = {
    ...existing.data,
    ...data,
  };
  patchesByPath.set(ref.path, existing);
}

async function loadSessionInfos(db) {
  const sessionsSnap = await db.collection("videoSessions").get();
  const sessionsByPath = new Map();
  const patchesByPath = new Map();
  let sessionsMissingFlags = 0;

  sessionsSnap.docs.forEach((doc) => {
    const sessionData = doc.data() || {};
    const sessionInfo = createSessionInfo(doc.ref, sessionData);
    sessionsByPath.set(doc.ref.path, sessionInfo);

    const defaultPatch = {};
    if (typeof sessionData[STUDENT_REVIEW_FLAG_FIELD] !== "boolean") {
      defaultPatch[STUDENT_REVIEW_FLAG_FIELD] = false;
    }
    if (typeof sessionData[TUTOR_REVIEW_FLAG_FIELD] !== "boolean") {
      defaultPatch[TUTOR_REVIEW_FLAG_FIELD] = false;
    }

    if (Object.keys(defaultPatch).length > 0) {
      sessionsMissingFlags += 1;
      queuePatch(patchesByPath, doc.ref, defaultPatch);
    }
  });

  return {
    sessionsByPath,
    patchesByPath,
    totalSessions: sessionsSnap.size,
    sessionsMissingFlags,
  };
}

async function getOrLoadSessionInfo(db, sessionsByPath, sessionPath) {
  const cached = sessionsByPath.get(sessionPath);
  if (cached) {
    return cached;
  }

  const sessionRef = db.doc(sessionPath);
  const sessionSnap = await sessionRef.get();
  if (!sessionSnap.exists) {
    return null;
  }

  const sessionInfo = createSessionInfo(sessionRef, sessionSnap.data() || {});
  sessionsByPath.set(sessionPath, sessionInfo);
  return sessionInfo;
}

async function buildReviewPatches(db, sessionsByPath, patchesByPath) {
  const reviewsSnap = await db.collection("reviews").get();
  const stats = {
    totalReviews: reviewsSnap.size,
    studentReviewMatches: 0,
    tutorReviewMatches: 0,
    skippedInvalidReferences: 0,
    skippedMissingSessions: 0,
    skippedInconsistentParticipants: 0,
  };

  for (const reviewDoc of reviewsSnap.docs) {
    const reviewData = reviewDoc.data() || {};
    const sessionPath = normalizeDocumentPath(reviewData.sessionId);
    const authorPath = normalizeDocumentPath(reviewData.fromUserId);
    const authorId = getDocumentId(reviewData.fromUserId);

    if (!sessionPath || !authorPath || !authorId) {
      stats.skippedInvalidReferences += 1;
      console.warn("Skipping review with invalid references:", reviewDoc.id);
      continue;
    }

    const sessionInfo = await getOrLoadSessionInfo(
      db,
      sessionsByPath,
      sessionPath,
    );
    if (!sessionInfo) {
      stats.skippedMissingSessions += 1;
      console.warn(
        "Skipping review with missing session:",
        reviewDoc.id,
        sessionPath,
      );
      continue;
    }

    if (authorId === sessionInfo.studentId) {
      stats.studentReviewMatches += 1;
      sessionInfo.studentHasReviewed = true;
      queuePatch(patchesByPath, sessionInfo.ref, {
        [STUDENT_REVIEW_FLAG_FIELD]: true,
      });
      continue;
    }

    if (authorId === sessionInfo.tutorId) {
      stats.tutorReviewMatches += 1;
      sessionInfo.tutorHasReviewed = true;
      queuePatch(patchesByPath, sessionInfo.ref, {
        [TUTOR_REVIEW_FLAG_FIELD]: true,
      });
      continue;
    }

    stats.skippedInconsistentParticipants += 1;
    console.warn(
      "Skipping review with inconsistent participants:",
      reviewDoc.id,
      sessionPath,
      authorPath,
    );
  }

  return stats;
}

async function commitPatches(db, patchesByPath, dryRun) {
  const patches = [...patchesByPath.values()];
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
    batch.set(patch.ref, patch.data, {merge: true});
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
  const appConfig = {};

  if (args.projectId) {
    appConfig.projectId = args.projectId;
  }
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    appConfig.credential = admin.credential.applicationDefault();
  }

  admin.initializeApp(appConfig);
  const db = admin.firestore();

  console.log(
    `Starting videoSessions review flag backfill in ${
      args.dryRun ? "dry-run" : "commit"
    } mode...`,
  );
  if (args.projectId) {
    console.log(`Using project: ${args.projectId}`);
  }

  const sessionStats = await loadSessionInfos(db);
  const reviewStats = await buildReviewPatches(
    db,
    sessionStats.sessionsByPath,
    sessionStats.patchesByPath,
  );
  const commitStats = await commitPatches(
    db,
    sessionStats.patchesByPath,
    args.dryRun,
  );

  console.log("Backfill summary:", {
    mode: args.dryRun ? "dry-run" : "commit",
    totalSessions: sessionStats.totalSessions,
    sessionsMissingFlags: sessionStats.sessionsMissingFlags,
    totalReviews: reviewStats.totalReviews,
    studentReviewMatches: reviewStats.studentReviewMatches,
    tutorReviewMatches: reviewStats.tutorReviewMatches,
    skippedInvalidReferences: reviewStats.skippedInvalidReferences,
    skippedMissingSessions: reviewStats.skippedMissingSessions,
    skippedInconsistentParticipants:
      reviewStats.skippedInconsistentParticipants,
    pendingSessionWrites: sessionStats.patchesByPath.size,
    committedBatches: commitStats.committedBatches,
    committedWrites: commitStats.committedWrites,
  });

  if (args.dryRun) {
    console.log("Dry run complete. Re-run with --commit to apply changes.");
  }
}

main().catch((error) => {
  console.error("Backfill failed:", error);
  process.exitCode = 1;
});
