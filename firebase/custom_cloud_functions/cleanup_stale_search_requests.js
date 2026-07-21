const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_STATUS,
  SEARCH_REQUEST_TIMING,
} = require("./search_requests");
const {
  logCallLifecycleError,
  logCallLifecycleEvent,
} = require("./call_lifecycle_logs");
const {
  SEARCH_CANCELLATION_INTENT_COLLECTION,
} = require("./search_cancellation_intents");

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

const BACKGROUND_EXPIRED_CLEANUP_STATUSES = Object.freeze([
  SEARCH_REQUEST_STATUS.ACTIVE,
  SEARCH_REQUEST_STATUS.MATCHING,
  SEARCH_REQUEST_STATUS.LEGACY_SEARCHING,
]);

const STALE_SEARCH_CLEANUP_LIMIT = 200;
const STALE_SEARCH_FALLBACK_CLEANUP_LIMIT = 200;
const EXPIRED_SEARCH_CLEANUP_LIMIT = 200;
const BACKGROUND_EXPIRED_SEARCH_CLEANUP_LIMIT = 200;
const EXPIRED_CANCELLATION_INTENT_CLEANUP_LIMIT = 200;

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

function hasBackgroundSearchDeadline(requestData = {}) {
  return normalizeString(requestData.appState) ===
      SEARCH_REQUEST_APP_STATE.BACKGROUND &&
    timestampToMillis(requestData.backgroundExpiresAt) !== null;
}

function hasSessionBinding(requestData = {}) {
  return [
    requestData.currentSessionId,
    requestData.activeSessionId,
    requestData.matchedSessionId,
  ].some((value) => Boolean(normalizeString(value)));
}

function isSessionBoundMatchingSearchRequest(requestData = {}) {
  return normalizeString(requestData.status) === SEARCH_REQUEST_STATUS.MATCHING &&
    hasSessionBinding(requestData);
}

function isStaleSearchRequest(requestData = {}, nowMillis = Date.now()) {
  const status = normalizeString(requestData.status);
  if (!STALE_CLEANUP_STATUSES.includes(status)) {
    return false;
  }
  if (isSessionBoundMatchingSearchRequest(requestData)) {
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
  if (isSessionBoundMatchingSearchRequest(requestData)) {
    return false;
  }

  const expiresAtMillis = timestampToMillis(requestData.expiresAt);
  return expiresAtMillis !== null && expiresAtMillis <= nowMillis;
}

function isBackgroundExpiredSearchRequest(
  requestData = {},
  nowMillis = Date.now(),
) {
  const status = normalizeString(requestData.status);
  if (!BACKGROUND_EXPIRED_CLEANUP_STATUSES.includes(status)) {
    return false;
  }
  if (isSessionBoundMatchingSearchRequest(requestData)) {
    return false;
  }
  if (
    normalizeString(requestData.appState) !==
      SEARCH_REQUEST_APP_STATE.BACKGROUND
  ) {
    return false;
  }

  const backgroundExpiresAtMillis = timestampToMillis(
    requestData.backgroundExpiresAt,
  );
  return backgroundExpiresAtMillis !== null &&
    backgroundExpiresAtMillis <= nowMillis;
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

function buildBackgroundExpiredSearchRequestCleanupUpdate({
  serverTimestamp,
  fieldDelete,
}) {
  return buildSearchRequestCleanupUpdate({
    stopReason: "background_timeout",
    errorMessage: "Search request expired in background",
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

function queueBackgroundExpiredSearchRequestCleanup({
  writer,
  doc,
  nowMillis = Date.now(),
  serverTimestamp,
  fieldDelete,
}) {
  const requestData = doc.data() || {};
  if (!isBackgroundExpiredSearchRequest(requestData, nowMillis)) {
    return {
      cleaned: false,
      requestId: normalizeString(requestData.requestId) || null,
    };
  }

  writer.update(doc.ref, buildBackgroundExpiredSearchRequestCleanupUpdate({
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
      if (key) {
        seenDocKeys.add(key);
      }
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

async function cleanupBackgroundExpiredSearchRequestDocs(options) {
  return await cleanupSearchRequestDocs({
    ...options,
    queueCleanup: queueBackgroundExpiredSearchRequestCleanup,
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
      const backgroundExpiredQuery = await db
        .collection(SEARCH_REQUEST_COLLECTION)
        .where("status", "in", BACKGROUND_EXPIRED_CLEANUP_STATUSES)
        .where("appState", "==", SEARCH_REQUEST_APP_STATE.BACKGROUND)
        .where("backgroundExpiresAt", "<=", expiresCutoff)
        .orderBy("backgroundExpiresAt")
        .limit(BACKGROUND_EXPIRED_SEARCH_CLEANUP_LIMIT)
        .get();
      const expiredCancellationIntentQuery = await db
        .collection(SEARCH_CANCELLATION_INTENT_COLLECTION)
        .where("expiresAt", "<=", expiresCutoff)
        .orderBy("expiresAt")
        .limit(EXPIRED_CANCELLATION_INTENT_CLEANUP_LIMIT)
        .get();

      if (
        staleQuery.empty &&
        staleFallbackQuery.empty &&
        expiredQuery.empty &&
        backgroundExpiredQuery.empty &&
        expiredCancellationIntentQuery.empty
      ) {
        console.log("📭 No stale search requests found");
        logCallLifecycleEvent({
          event: "cleanup_search_requests_completed",
          source: "cleanupStaleSearchRequests",
          result: "noop",
          counts: {
            staleFound: 0,
            staleFallbackFound: 0,
            backgroundExpiredFound: 0,
            expiredFound: 0,
            expiredCancellationIntentsFound: 0,
            cleaned: 0,
          },
        });
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
      const cleanedByBackgroundExpiry =
        await cleanupBackgroundExpiredSearchRequestDocs({
          db,
          docs: backgroundExpiredQuery.docs,
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
        cleanedByHeartbeat +
        cleanedByFallback +
        cleanedByBackgroundExpiry +
        cleanedByExpiry;
      if (!expiredCancellationIntentQuery.empty) {
        const intentBatch = db.batch();
        expiredCancellationIntentQuery.docs.forEach((doc) =>
          intentBatch.delete(doc.ref));
        await intentBatch.commit();
      }

      console.log(`✅ Search requests marked expired: ${cleanedCount}`);
      logCallLifecycleEvent({
        event: "cleanup_search_requests_completed",
        source: "cleanupStaleSearchRequests",
        result: "completed",
        counts: {
          staleFound: staleQuery.size,
          staleFallbackFound: staleFallbackQuery.size,
          backgroundExpiredFound: backgroundExpiredQuery.size,
          expiredFound: expiredQuery.size,
          staleCleaned: cleanedByHeartbeat,
          staleFallbackCleaned: cleanedByFallback,
          backgroundExpiredCleaned: cleanedByBackgroundExpiry,
          expiredCleaned: cleanedByExpiry,
          cancellationIntentsDeleted: expiredCancellationIntentQuery.size,
          cleaned: cleanedCount,
        },
      });
      return null;
    } catch (error) {
      console.error("❌ Error cleaning up stale search requests:", error);
      logCallLifecycleError({
        event: "cleanup_search_requests_failed",
        source: "cleanupStaleSearchRequests",
        errorCode: error.code || error.name,
        reason: error.message,
      });
      return null;
    }
  });

exports.__private__ = {
  BACKGROUND_EXPIRED_CLEANUP_STATUSES,
  BACKGROUND_EXPIRED_SEARCH_CLEANUP_LIMIT,
  EXPIRED_CLEANUP_STATUSES,
  EXPIRED_SEARCH_CLEANUP_LIMIT,
  EXPIRED_CANCELLATION_INTENT_CLEANUP_LIMIT,
  STALE_CLEANUP_STATUSES,
  STALE_SEARCH_FALLBACK_CLEANUP_LIMIT,
  STALE_SEARCH_CLEANUP_LIMIT,
  buildBackgroundExpiredSearchRequestCleanupUpdate,
  buildExpiredSearchRequestCleanupUpdate,
  buildSearchRequestCleanupUpdate,
  buildStaleSearchRequestCleanupUpdate,
  cleanupBackgroundExpiredSearchRequestDocs,
  cleanupExpiredSearchRequestDocs,
  cleanupSearchRequestDocs,
  cleanupStaleSearchRequestDocs,
  hasBackgroundSearchDeadline,
  hasSessionBinding,
  isBackgroundExpiredSearchRequest,
  isExpiredUnmatchedSearchRequest,
  isSessionBoundMatchingSearchRequest,
  isStaleSearchRequest,
  queueBackgroundExpiredSearchRequestCleanup,
  queueExpiredSearchRequestCleanup,
  queueStaleSearchRequestCleanup,
  staleCutoffMillisFor,
  timestampToMillis,
};
