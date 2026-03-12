#!/usr/bin/env node

const admin = require("firebase-admin");

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

function encodePairReviewComponent(value) {
  return encodeURIComponent(String(value || "").trim()).replace(/_/g, "%5F");
}

function buildPairReviewId(fromUserId, toUserId) {
  const normalizedFromUserId = String(fromUserId || "").trim();
  const normalizedToUserId = String(toUserId || "").trim();
  if (!normalizedFromUserId || !normalizedToUserId) {
    return "";
  }

  return `${encodePairReviewComponent(normalizedFromUserId)}__${encodePairReviewComponent(normalizedToUserId)}`;
}

function toMillis(value) {
  if (!value) {
    return 0;
  }
  if (typeof value?.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }

  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : 0;
}

function compareReviewEntries(left, right) {
  const leftCreatedAt = toMillis(left.data.createdAt);
  const rightCreatedAt = toMillis(right.data.createdAt);
  if (leftCreatedAt !== rightCreatedAt) {
    return rightCreatedAt - leftCreatedAt;
  }

  return right.ref.path.localeCompare(left.ref.path);
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

async function loadReviewGroups(db) {
  const reviewsSnap = await db.collection("reviews").get();
  const groupsByKey = new Map();
  const stats = {
    totalReviews: reviewsSnap.size,
    invalidReviews: 0,
  };

  for (const reviewDoc of reviewsSnap.docs) {
    const reviewData = reviewDoc.data() || {};
    const fromUserPath = normalizeDocumentPath(reviewData.fromUserId);
    const toUserPath = normalizeDocumentPath(reviewData.toUserId);
    const fromUserId = getDocumentId(reviewData.fromUserId);
    const toUserId = getDocumentId(reviewData.toUserId);
    const canonicalReviewId = buildPairReviewId(fromUserId, toUserId);

    if (!fromUserPath || !toUserPath || !canonicalReviewId) {
      stats.invalidReviews += 1;
      console.warn(
        "Skipping review with invalid pair references:",
        reviewDoc.ref.path,
      );
      continue;
    }

    const groupKey = `${fromUserPath}|${toUserPath}`;
    const existingGroup = groupsByKey.get(groupKey) || {
      fromUserId,
      fromUserPath,
      toUserId,
      toUserPath,
      canonicalReviewId,
      docs: [],
    };

    existingGroup.docs.push({
      ref: reviewDoc.ref,
      data: reviewData,
    });
    groupsByKey.set(groupKey, existingGroup);
  }

  return {
    groupsByKey,
    stats,
  };
}

function buildMigrationOperations(db, groupsByKey) {
  const operations = [];
  const ratingStatsByTargetPath = new Map();
  const stats = {
    pairGroups: groupsByKey.size,
    duplicatePairGroups: 0,
    canonicalUpserts: 0,
    reviewDeletes: 0,
    affectedUsers: 0,
    invalidRatings: 0,
  };

  for (const group of groupsByKey.values()) {
    const sortedDocs = [...group.docs].sort(compareReviewEntries);
    if (sortedDocs.length > 1) {
      stats.duplicatePairGroups += 1;
    }

    const latestReview = sortedDocs[0];
    const canonicalReviewRef = db
      .collection("reviews")
      .doc(group.canonicalReviewId);
    operations.push({
      type: "set",
      ref: canonicalReviewRef,
      data: latestReview.data,
      merge: false,
    });
    stats.canonicalUpserts += 1;

    for (const reviewEntry of sortedDocs) {
      if (reviewEntry.ref.path === canonicalReviewRef.path) {
        continue;
      }

      operations.push({
        type: "delete",
        ref: reviewEntry.ref,
      });
      stats.reviewDeletes += 1;
    }

    const targetRatingStats = ratingStatsByTargetPath.get(group.toUserPath) || {
      ref: db.doc(group.toUserPath),
      total: 0,
      sum: 0,
    };
    const rating = Number(latestReview.data.rating);
    if (Number.isFinite(rating) && rating >= 1 && rating <= 5) {
      targetRatingStats.total += 1;
      targetRatingStats.sum += rating;
    } else {
      stats.invalidRatings += 1;
      console.warn(
        "Skipping invalid rating during aggregation:",
        latestReview.ref.path,
        latestReview.data.rating,
      );
    }
    ratingStatsByTargetPath.set(group.toUserPath, targetRatingStats);
  }

  stats.affectedUsers = ratingStatsByTargetPath.size;

  for (const targetRatingStats of ratingStatsByTargetPath.values()) {
    const average = targetRatingStats.total > 0 ?
      Number((targetRatingStats.sum / targetRatingStats.total).toFixed(4)) :
      0;
    operations.push({
      type: "set",
      ref: targetRatingStats.ref,
      data: {
        rating: {
          average,
          totalReviews: targetRatingStats.total,
        },
      },
      merge: true,
    });
  }

  return {
    operations,
    stats,
  };
}

async function commitOperations(operations, dryRun) {
  if (dryRun || operations.length === 0) {
    return {
      committedBatches: 0,
      committedWrites: 0,
    };
  }

  const db = admin.firestore();
  let batch = db.batch();
  let batchSize = 0;
  let committedBatches = 0;
  let committedWrites = 0;

  for (const operation of operations) {
    if (operation.type === "delete") {
      batch.delete(operation.ref);
    } else {
      batch.set(operation.ref, operation.data, {merge: operation.merge});
    }
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
    `Starting pair review migration in ${
      args.dryRun ? "dry-run" : "commit"
    } mode...`,
  );
  if (args.projectId) {
    console.log(`Using project: ${args.projectId}`);
  }

  const loadedReviews = await loadReviewGroups(db);
  const migrationPlan = buildMigrationOperations(
    db,
    loadedReviews.groupsByKey,
  );
  const commitStats = await commitOperations(
    migrationPlan.operations,
    args.dryRun,
  );

  console.log("Pair review migration summary:", {
    mode: args.dryRun ? "dry-run" : "commit",
    totalReviews: loadedReviews.stats.totalReviews,
    invalidReviews: loadedReviews.stats.invalidReviews,
    pairGroups: migrationPlan.stats.pairGroups,
    duplicatePairGroups: migrationPlan.stats.duplicatePairGroups,
    canonicalUpserts: migrationPlan.stats.canonicalUpserts,
    reviewDeletes: migrationPlan.stats.reviewDeletes,
    affectedUsers: migrationPlan.stats.affectedUsers,
    invalidRatings: migrationPlan.stats.invalidRatings,
    pendingOperations: migrationPlan.operations.length,
    committedBatches: commitStats.committedBatches,
    committedWrites: commitStats.committedWrites,
  });

  if (args.dryRun) {
    console.log("Dry run complete. Re-run with --commit to apply changes.");
  }
}

main().catch((error) => {
  console.error("Pair review migration failed:", error);
  process.exitCode = 1;
});
