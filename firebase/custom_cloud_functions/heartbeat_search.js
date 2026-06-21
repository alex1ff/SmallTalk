const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_STATUS,
  SEARCH_REQUEST_TERMINAL_STATUSES,
  SEARCH_REQUEST_TIMING,
  normalizeAppState,
} = require("./search_requests");

const HEARTBEAT_WRITABLE_STATUSES = new Set([
  SEARCH_REQUEST_STATUS.ACTIVE,
  SEARCH_REQUEST_STATUS.MATCHING,
  SEARCH_REQUEST_STATUS.LEGACY_SEARCHING,
]);

const HEARTBEAT_TERMINAL_STATUSES = new Set(
  SEARCH_REQUEST_TERMINAL_STATUSES,
);

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeDocumentId(value) {
  const documentId = normalizeString(value);
  if (!documentId ||
      documentId.includes("/") ||
      documentId === "." ||
      documentId === ".." ||
      /^__.*__$/.test(documentId)) {
    return "";
  }

  return documentId;
}

function normalizeRequestId(value) {
  return normalizeDocumentId(value);
}

function readCallableData(data) {
  return data && typeof data === "object" && !Array.isArray(data) ? data : {};
}

function normalizeHeartbeatInput(data) {
  const payload = readCallableData(data);
  const requestId = normalizeRequestId(payload.requestId);
  if (!requestId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "requestId is required",
      {reason: "request_id_required"},
    );
  }

  return {
    requestId,
    appState: normalizeAppState(payload.appState),
  };
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

function timestampToIsoString(value) {
  const millis = timestampToMillis(value);
  return millis === null ? null : new Date(millis).toISOString();
}

function readRequestSessionId(requestData = {}) {
  return normalizeString(requestData.currentSessionId) ||
    normalizeString(requestData.activeSessionId) ||
    normalizeString(requestData.matchedSessionId) ||
    null;
}

function buildHeartbeatResponse({
  userId,
  requestData = {},
  heartbeat = false,
  reason = "",
}) {
  return {
    status: normalizeString(requestData.status) || "noop",
    searchRequestId: userId,
    requestId: normalizeString(requestData.requestId) || null,
    sessionId: readRequestSessionId(requestData),
    pairAttemptId: normalizeString(requestData.pairAttemptId) || null,
    expiresAt: timestampToIsoString(requestData.expiresAt),
    errorCode: null,
    heartbeat,
    reason,
  };
}

function buildNoopDecision({
  userId,
  requestData = {},
  reason,
  errorCode = null,
}) {
  return {
    ok: true,
    update: null,
    response: {
      ...buildHeartbeatResponse({
        userId,
        requestData,
        heartbeat: false,
        reason,
      }),
      errorCode,
    },
  };
}

function buildHeartbeatSearchDecision({
  requestExists,
  requestData = {},
  userId,
  requestId,
  appState,
  nowMillis = Date.now(),
  serverTimestamp,
  timestampFromMillis = admin.firestore.Timestamp.fromMillis,
}) {
  if (!requestExists) {
    return buildNoopDecision({
      userId,
      requestData: {},
      reason: "not_found",
      errorCode: "not_found",
    });
  }

  if (normalizeString(requestData.userId) !== userId) {
    return {
      ok: false,
      code: "permission-denied",
      message: "You can only heartbeat your own search request",
    };
  }

  if (normalizeString(requestData.requestId) !== requestId) {
    return buildNoopDecision({
      userId,
      requestData,
      reason: "request_mismatch",
      errorCode: "request_mismatch",
    });
  }

  const status = normalizeString(requestData.status);
  if (HEARTBEAT_TERMINAL_STATUSES.has(status)) {
    return buildNoopDecision({
      userId,
      requestData,
      reason: "inactive",
      errorCode: "inactive",
    });
  }

  if (status === SEARCH_REQUEST_STATUS.MATCHED) {
    return buildNoopDecision({
      userId,
      requestData,
      reason: "matched",
    });
  }

  if (!HEARTBEAT_WRITABLE_STATUSES.has(status)) {
    return buildNoopDecision({
      userId,
      requestData,
      reason: "unsupported_status",
      errorCode: "unsupported_status",
    });
  }

  const expiresAtMillis = timestampToMillis(requestData.expiresAt);
  if (expiresAtMillis === null || expiresAtMillis <= nowMillis) {
    return buildNoopDecision({
      userId,
      requestData,
      reason: "expired",
      errorCode: "expired",
    });
  }

  const heartbeatAtMillis = timestampToMillis(requestData.heartbeatAt);
  const staleCutoffMillis =
    nowMillis - SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS * 1000;
  if (heartbeatAtMillis === null || heartbeatAtMillis < staleCutoffMillis) {
    return buildNoopDecision({
      userId,
      requestData,
      reason: "stale",
      errorCode: "stale",
    });
  }

  const backgroundExpiresAtMillis = timestampToMillis(
    requestData.backgroundExpiresAt,
  );
  if (
    backgroundExpiresAtMillis !== null &&
    backgroundExpiresAtMillis <= nowMillis
  ) {
    return buildNoopDecision({
      userId,
      requestData,
      reason: "background_expired",
      errorCode: "background_expired",
    });
  }

  const nextAppState = normalizeAppState(appState);
  const backgroundExpiresAt =
    nextAppState === SEARCH_REQUEST_APP_STATE.FOREGROUND ?
      null :
      timestampFromMillis(
        nowMillis +
          SEARCH_REQUEST_TIMING.BACKGROUND_MAX_SEARCH_SECONDS * 1000,
      );
  const update = {
    heartbeatAt: serverTimestamp,
    updatedAt: serverTimestamp,
    appState: nextAppState,
    appStateUpdatedAt: serverTimestamp,
    backgroundExpiresAt,
  };

  return {
    ok: true,
    update,
    response: buildHeartbeatResponse({
      userId,
      requestData,
      heartbeat: true,
      reason: "updated",
    }),
  };
}

function throwCallableError(decision) {
  throw new functions.https.HttpsError(decision.code, decision.message);
}

exports.heartbeatSearch = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  const input = normalizeHeartbeatInput(data);
  const db = admin.firestore();
  const userId = context.auth.uid;
  const searchRequestRef = db
    .collection(SEARCH_REQUEST_COLLECTION)
    .doc(userId);
  const nowMillis = Date.now();
  const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();

  return db.runTransaction(async (transaction) => {
    const searchRequestSnapshot = await transaction.get(searchRequestRef);
    const requestData = searchRequestSnapshot.exists ?
      searchRequestSnapshot.data() || {} :
      {};
    const decision = buildHeartbeatSearchDecision({
      requestExists: searchRequestSnapshot.exists,
      requestData,
      userId,
      requestId: input.requestId,
      appState: input.appState,
      nowMillis,
      serverTimestamp,
    });

    if (!decision.ok) {
      throwCallableError(decision);
    }
    if (decision.update) {
      transaction.update(searchRequestRef, decision.update);
    }

    return decision.response;
  });
});

exports.__private__ = {
  HEARTBEAT_TERMINAL_STATUSES,
  HEARTBEAT_WRITABLE_STATUSES,
  buildHeartbeatResponse,
  buildHeartbeatSearchDecision,
  normalizeHeartbeatInput,
  normalizeRequestId,
  timestampToMillis,
};
