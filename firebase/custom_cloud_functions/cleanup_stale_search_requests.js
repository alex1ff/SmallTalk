const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_STATUS,
  SEARCH_REQUEST_TIMING,
} = require("./search_requests");

const STALE_CLEANUP_STATUSES = Object.freeze([
  SEARCH_REQUEST_STATUS.ACTIVE,
  SEARCH_REQUEST_STATUS.MATCHING,
  SEARCH_REQUEST_STATUS.LEGACY_SEARCHING,
]);

const EXPIRED_CLEANUP_STATUSES = Object.freeze([
  SEARCH_REQUEST_STATUS.ACTIVE,
  SEARCH_REQUEST_STATUS.MATCHING,
  SEARCH_REQUEST_STATUS.LEGACY_SEARCHING,
]);

const STALE_SEARCH_CLEANUP_LIMIT = 200;
const STALE_SEARCH_FALLBACK_CLEANUP_LIMIT = 200;
const EXPIRED_SEARCH_CLEANUP_LIMIT = 200;

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function timestampToMillis(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : null;
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  const millis = Number(value);
  return Number.isFinite(millis) ? millis : null;
}

function staleCutoffMillisFor(nowMillis = Date.now()) {
  return nowMillis - SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS * 1000;
}

function isStaleSearchRequest(requestData = {}, nowMillis = Date.now()) {
  const status = normalizeString(requestData.status);
  if (!STALE_CLEANUP_STATUSES.includes(status)) {
    return false;
  }

  const heartbeatAtMillis = timestampToMillis(requestData.heartbeatAt);
  return heartbeatAtMillis === null ||
    heartbeatAtMillis < staleCutoffMillisFor(nowMillis);
}

function isExpiredUnmatchedSearchRequest(
  requestData = {},
  nowMillis = Date.now(),
) {
  const status = normalizeString(requestData.status);
  if (!EXPIRED_CLEANUP_STATUSES.includes(status)) {
    return false;
  }

  const expiresAtMillis = timestampToMillis(requestData.expiresAt);
  return expiresAtMillis !== null && expiresAtMillis <= nowMillis;
}

function buildSearchRequestCleanupUpdate({
  stopReason,
  errorMessage,
  serverTimestamp,
  fieldDelete,
}) {
  return {
    status: SEARCH_REQUEST_STATUS.EXPIRED,
    updatedAt: serverTimestamp,
    stoppedAt: serverTimestamp,
    stopReason,
    currentSessionId: null,
    matchedUserId: null,
    matchedRole: null,
    pairAttemptId: null,
    attemptExcludedCandidateIds: [],
    lockOwner: null,
    lockExpiresAt: null,
    lastError: {
      code: stopReason,
      message: errorMessage,
    },
    activeSessionId: fieldDelete,
    matchedSessionId: fieldDelete,
    matchedResponderId: fieldDelete,
  };
}

function buildStaleSearchRequestCleanupUpdate({
  serverTimestamp,
  fieldDelete,
}) {
  return buildSearchRequestCleanupUpdate({
    stopReason: "heartbeat_stale",
    errorMessage: "Search request heartbeat is stale",
    serverTimestamp,
    fieldDelete,
  });
}

function buildExpiredSearchRequestCleanupUpdate({
  serverTimestamp,
  fieldDelete,
}) {
  return buildSearchRequestCleanupUpdate({
    stopReason: "search_timeout",
    errorMessage: "Search request expired without a match",
    serverTimestamp,
    fieldDelete,
  });
}

function queueStaleSearchRequestCleanup({
  writer,
  doc,
  nowMillis = Date.now(),
  serverTimestamp,
  fieldDelete,
}) {
  const requestData = doc.data() || {};
  if (!isStaleSearchRequest(requestData, nowMillis)) {
    return {
      cleaned: false,
      requestId: normalizeString(requestData.requestId) || null,
    };
  }

  writer.update(doc.ref, buildStaleSearchRequestCleanupUpdate({
    requestData,
    serverTimestamp,
    fieldDelete,
  }));

  return {
    cleaned: true,
    requestId: normalizeString(requestData.requestId) || null,
  };
}

function queueExpiredSearchRequestCleanup({
  writer,
  doc,
  nowMillis = Date.now(),
  serverTimestamp,
  fieldDelete,
}) {
  const requestData = doc.data() || {};
  if (!isExpiredUnmatchedSearchRequest(requestData, nowMillis)) {
    return {
      cleaned: false,
      requestId: normalizeString(requestData.requestId) || null,
    };
  }

  writer.update(doc.ref, buildExpiredSearchRequestCleanupUpdate({
    requestData,
    serverTimestamp,
    fieldDelete,
  }));

  return {
    cleaned: true,
    requestId: normalizeString(requestData.requestId) || null,
  };
}

function docKey(doc = {}) {
  return normalizeString(doc.ref && doc.ref.path) || normalizeString(doc.id);
}

async function cleanupSearchRequestDocs({
  db,
  docs = [],
  nowMillis,
  serverTimestamp,
  fieldDelete,
  queueCleanup,
  seenDocKeys = new Set(),
}) {
  let cleanedCount = 0;

  for (const doc of docs) {
    const key = docKey(doc);
    if (key && seenDocKeys.has(key)) {
      continue;
    }
    if (key) {
      seenDocKeys.add(key);
    }

    const result = await db.runTransaction(async (transaction) => {
      const freshSnap = await transaction.get(doc.ref);
      if (!freshSnap.exists) {
        return {cleaned: false};
      }

      return queueCleanup({
        writer: transaction,
        doc: {
          id: doc.id,
          ref: doc.ref,
          data: () => freshSnap.data() || {},
        },
        nowMillis,
        serverTimestamp,
        fieldDelete,
      });
    });

    if (result.cleaned) {
      cleanedCount += 1;
    }
  }

  return cleanedCount;
}

async function cleanupStaleSearchRequestDocs(options) {
  return await cleanupSearchRequestDocs({
    ...options,
    queueCleanup: queueStaleSearchRequestCleanup,
  });
}

async function cleanupExpiredSearchRequestDocs(options) {
  return await cleanupSearchRequestDocs({
    ...options,
    queueCleanup: queueExpiredSearchRequestCleanup,
  });
}

exports.cleanupStaleSearchRequests = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async () => {
    console.log("🧹 Cleaning up stale search requests...");

    try {
      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();
      const nowMillis = now.toMillis();
      const staleCutoff = admin.firestore.Timestamp.fromMillis(
        staleCutoffMillisFor(nowMillis),
      );
      const expiresCutoff = now;
      const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
      const fieldDelete = admin.firestore.FieldValue.delete();
      const staleQuery = await db
        .collection(SEARCH_REQUEST_COLLECTION)
        .where("status", "in", STALE_CLEANUP_STATUSES)
        .where("heartbeatAt", "<", staleCutoff)
        .orderBy("heartbeatAt")
        .limit(STALE_SEARCH_CLEANUP_LIMIT)
        .get();
      const staleFallbackQuery = await db
        .collection(SEARCH_REQUEST_COLLECTION)
        .where("status", "in", STALE_CLEANUP_STATUSES)
        .where("updatedAt", "<", staleCutoff)
        .orderBy("updatedAt")
        .limit(STALE_SEARCH_FALLBACK_CLEANUP_LIMIT)
        .get();
      const expiredQuery = await db
        .collection(SEARCH_REQUEST_COLLECTION)
        .where("status", "in", EXPIRED_CLEANUP_STATUSES)
        .where("expiresAt", "<=", expiresCutoff)
        .orderBy("expiresAt")
        .limit(EXPIRED_SEARCH_CLEANUP_LIMIT)
        .get();

      if (staleQuery.empty && staleFallbackQuery.empty && expiredQuery.empty) {
        console.log("📭 No stale search requests found");
        return null;
      }

      const seenDocKeys = new Set();
      const cleanedByHeartbeat = await cleanupStaleSearchRequestDocs({
        db,
        docs: staleQuery.docs,
        nowMillis,
        serverTimestamp,
        fieldDelete,
        seenDocKeys,
      });
      const cleanedByFallback = await cleanupStaleSearchRequestDocs({
        db,
        docs: staleFallbackQuery.docs,
        nowMillis,
        serverTimestamp,
        fieldDelete,
        seenDocKeys,
      });
      const cleanedByExpiry = await cleanupExpiredSearchRequestDocs({
        db,
        docs: expiredQuery.docs,
        nowMillis,
        serverTimestamp,
        fieldDelete,
        seenDocKeys,
      });
      const cleanedCount =
        cleanedByHeartbeat + cleanedByFallback + cleanedByExpiry;

      console.log(`✅ Search requests marked expired: ${cleanedCount}`);
      return null;
    } catch (error) {
      console.error("❌ Error cleaning up stale search requests:", error);
      return null;
    }
  });

exports.__private__ = {
  EXPIRED_CLEANUP_STATUSES,
  EXPIRED_SEARCH_CLEANUP_LIMIT,
  STALE_CLEANUP_STATUSES,
  STALE_SEARCH_FALLBACK_CLEANUP_LIMIT,
  STALE_SEARCH_CLEANUP_LIMIT,
  buildExpiredSearchRequestCleanupUpdate,
  buildSearchRequestCleanupUpdate,
  buildStaleSearchRequestCleanupUpdate,
  cleanupExpiredSearchRequestDocs,
  cleanupSearchRequestDocs,
  cleanupStaleSearchRequestDocs,
  isExpiredUnmatchedSearchRequest,
  isStaleSearchRequest,
  queueExpiredSearchRequestCleanup,
  queueStaleSearchRequestCleanup,
  staleCutoffMillisFor,
  timestampToMillis,
};
