const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_FIELD,
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

function isBackgroundGraceActive(requestData = {}, nowMillis = Date.now()) {
  if (
    normalizeAppState(requestData.appState) !==
      SEARCH_REQUEST_APP_STATE.BACKGROUND
  ) {
    return false;
  }

  const backgroundExpiresAtMillis = timestampToMillis(
    requestData.backgroundExpiresAt,
  );
  return backgroundExpiresAtMillis !== null &&
    backgroundExpiresAtMillis > nowMillis;
}

function isBackgroundExpired(requestData = {}, nowMillis = Date.now()) {
  if (
    normalizeAppState(requestData.appState) !==
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

function resolveBackgroundExpiresAt({
  requestData = {},
  nextAppState,
  nowMillis = Date.now(),
  timestampFromMillis = admin.firestore.Timestamp.fromMillis,
}) {
  if (nextAppState === SEARCH_REQUEST_APP_STATE.FOREGROUND) {
    return null;
  }

  if (isBackgroundGraceActive(requestData, nowMillis)) {
    return requestData.backgroundExpiresAt;
  }

  return timestampFromMillis(
    nowMillis + SEARCH_REQUEST_TIMING.BACKGROUND_MAX_SEARCH_SECONDS * 1000,
  );
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

function hasHeartbeatSessionBinding(requestData = {}) {
  return Boolean(readRequestSessionId(requestData));
}

function buildHeartbeatTerminalUpdate({
  stopReason,
  errorMessage,
  serverTimestamp,
  fieldDelete,
}) {
  return {
    [SEARCH_REQUEST_FIELD.STATUS]: SEARCH_REQUEST_STATUS.EXPIRED,
    [SEARCH_REQUEST_FIELD.UPDATED_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.STOPPED_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.STOP_REASON]: stopReason,
    [SEARCH_REQUEST_FIELD.CURRENT_SESSION_ID]: null,
    [SEARCH_REQUEST_FIELD.MATCHED_USER_ID]: null,
    [SEARCH_REQUEST_FIELD.MATCHED_ROLE]: null,
    [SEARCH_REQUEST_FIELD.PAIR_ATTEMPT_ID]: null,
    [SEARCH_REQUEST_FIELD.ATTEMPT_EXCLUDED_CANDIDATE_IDS]: [],
    [SEARCH_REQUEST_FIELD.LOCK_OWNER]: null,
    [SEARCH_REQUEST_FIELD.LOCK_EXPIRES_AT]: null,
    [SEARCH_REQUEST_FIELD.LAST_ERROR]: {
      code: stopReason,
      message: errorMessage,
    },
    [SEARCH_REQUEST_FIELD.ACTIVE_SESSION_ID]: fieldDelete,
    [SEARCH_REQUEST_FIELD.MATCHED_SESSION_ID]: fieldDelete,
    [SEARCH_REQUEST_FIELD.MATCHED_RESPONDER_ID]: fieldDelete,
  };
}

function buildHeartbeatTerminalDecision({
  userId,
  requestData = {},
  reason,
  stopReason,
  errorMessage,
  serverTimestamp,
  fieldDelete,
}) {
  if (hasHeartbeatSessionBinding(requestData)) {
    return buildNoopDecision({
      userId,
      requestData,
      reason,
      errorCode: reason,
    });
  }

  return {
    ok: true,
    update: buildHeartbeatTerminalUpdate({
      stopReason,
      errorMessage,
      serverTimestamp,
      fieldDelete,
    }),
    response: {
      ...buildHeartbeatResponse({
        userId,
        requestData: {
          ...requestData,
          status: SEARCH_REQUEST_STATUS.EXPIRED,
          currentSessionId: null,
          activeSessionId: null,
          matchedSessionId: null,
        },
        heartbeat: false,
        reason,
      }),
      errorCode: reason,
    },
  };
}

function buildHeartbeatSearchDecision({
  requestExists,
  requestData = {},
  userId,
  requestId,
  appState,
  sessionExists = false,
  sessionData = {},
  nowMillis = Date.now(),
  serverTimestamp,
  fieldDelete = admin.firestore.FieldValue.delete(),
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
    const sessionId = readRequestSessionId(requestData);
    const pairAttemptId = normalizeString(requestData.pairAttemptId);
    const exactProtocolV2Binding =
      Number(requestData.matchProtocolVersion) >= 2 &&
      Boolean(sessionId) &&
      Boolean(pairAttemptId) &&
      sessionExists &&
      Number(sessionData.matchProtocolVersion) >= 2 &&
      normalizeString(sessionData.pairAttemptId) === pairAttemptId &&
      (sessionData.participantIds || []).includes(userId);
    if (exactProtocolV2Binding) {
      const nextAppState = normalizeAppState(appState);
      return {
        ok: true,
        update: {
          heartbeatAt: serverTimestamp,
          appState: nextAppState,
          appStateUpdatedAt: serverTimestamp,
        },
        response: buildHeartbeatResponse({
          userId,
          requestData,
          heartbeat: true,
          reason: "matched_liveness_updated",
        }),
      };
    }
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
    return buildHeartbeatTerminalDecision({
      userId,
      requestData,
      reason: "expired",
      stopReason: "search_timeout",
      errorMessage: "Search request expired without a match",
      serverTimestamp,
      fieldDelete,
    });
  }

  if (isBackgroundExpired(requestData, nowMillis)) {
    return buildHeartbeatTerminalDecision({
      userId,
      requestData,
      reason: "background_expired",
      stopReason: "background_timeout",
      errorMessage: "Search request expired in background",
      serverTimestamp,
      fieldDelete,
    });
  }

  const heartbeatAtMillis = timestampToMillis(requestData.heartbeatAt);
  const staleCutoffMillis =
    nowMillis - SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS * 1000;
  if (heartbeatAtMillis === null || heartbeatAtMillis < staleCutoffMillis) {
    return buildHeartbeatTerminalDecision({
      userId,
      requestData,
      reason: "stale",
      stopReason: "heartbeat_stale",
      errorMessage: "Search request heartbeat is stale",
      serverTimestamp,
      fieldDelete,
    });
  }

  const nextAppState = normalizeAppState(appState);
  const backgroundExpiresAt = resolveBackgroundExpiresAt({
    requestData,
    nextAppState,
    nowMillis,
    timestampFromMillis,
  });
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
    const matchedSessionId =
      normalizeString(requestData.status) === SEARCH_REQUEST_STATUS.MATCHED &&
      Number(requestData.matchProtocolVersion) >= 2 ?
        readRequestSessionId(requestData) :
        null;
    const sessionSnapshot = matchedSessionId ?
      await transaction.get(
        db.collection("videoSessions").doc(matchedSessionId),
      ) :
      null;
    const decision = buildHeartbeatSearchDecision({
      requestExists: searchRequestSnapshot.exists,
      requestData,
      userId,
      requestId: input.requestId,
      appState: input.appState,
      sessionExists: sessionSnapshot?.exists === true,
      sessionData: sessionSnapshot?.exists ? sessionSnapshot.data() || {} : {},
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
  buildHeartbeatTerminalDecision,
  buildHeartbeatTerminalUpdate,
  hasHeartbeatSessionBinding,
  isBackgroundExpired,
  isBackgroundGraceActive,
  normalizeHeartbeatInput,
  normalizeRequestId,
  resolveBackgroundExpiresAt,
  timestampToMillis,
};
