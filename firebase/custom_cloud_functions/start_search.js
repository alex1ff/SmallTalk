const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { sendApnsVoip } = require("./apns_voip");
const { hasActiveAcceptLockForResponder } = require("./accept_lock_policy");
const {
  createIncomingCallNotificationInTransaction,
} = require("./call_notifications");
const {
  usageDocRef,
} = require("./subscription_usage_shared");
const {
  getUserVoipTokens,
} = require("./voip_tokens");
const {
  buildStudentCallAccessDecision,
} = require("./call_access");
const {
  buildInitialSessionPolicyState,
  isSupportedSessionRole,
  normalizeRole,
  readCountryCode,
  readLevelValue,
  resolveActiveConversationLanguage,
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  SEARCH_REQUEST_ACTIVE_STATUSES,
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_FIELD,
  SEARCH_REQUEST_STATUS,
  SEARCH_REQUEST_TIMING,
  buildInitialSearchRequestData,
  normalizeAppState,
  normalizeSearchRequestFilters,
} = require("./search_requests");
const {
  MATCH_CANDIDATE_SOURCE,
  collectMatchCandidatePool,
} = require("./match_candidate_pool");
const {
  reserveMatchPair,
} = require("./match_pair_lock");

const STUDENT_REVIEW_FLAG_FIELD = "studentHasReviewed";
const TUTOR_REVIEW_FLAG_FIELD = "tutorHasReviewed";
const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const BACKGROUND_STUDENT_RESPONDER_PUSH_TIMEOUT_MS = 3 * 1000;
const BACKGROUND_STUDENT_RESPONDER_APNS_TIMEOUT_MS = 2 * 1000;

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function readErrorMessage(error, fallback = "") {
  if (error && typeof error === "object") {
    try {
      return normalizeString(error.message) || fallback;
    } catch (readError) {
      return fallback;
    }
  }
  try {
    return normalizeString(String(error)) || fallback;
  } catch (stringifyError) {
    return fallback;
  }
}

function throwIfAborted(signal) {
  if (!signal?.aborted) {
    return;
  }
  if (signal.reason instanceof Error) {
    throw signal.reason;
  }
  throw new Error("push_aborted");
}

function waitForAbortable(promise, signal) {
  if (!signal) {
    return promise;
  }
  throwIfAborted(signal);
  return new Promise((resolve, reject) => {
    const abort = () => {
      reject(signal.reason instanceof Error ?
        signal.reason :
        new Error("push_aborted"));
    };
    signal.addEventListener?.("abort", abort, {once: true});
    Promise.resolve(promise).then(
      (value) => {
        signal.removeEventListener?.("abort", abort);
        resolve(value);
      },
      (error) => {
        signal.removeEventListener?.("abort", abort);
        reject(error);
      },
    );
  });
}

function buildChildAbortController({
  parentSignal = null,
  timeoutMs = 0,
  timeoutError = new Error("operation_timeout"),
} = {}) {
  const controller = new AbortController();
  let timeout = null;
  const abortFromParent = () => {
    controller.abort(parentSignal?.reason instanceof Error ?
      parentSignal.reason :
      new Error("push_aborted"));
  };
  if (parentSignal?.aborted) {
    abortFromParent();
  } else {
    parentSignal?.addEventListener?.("abort", abortFromParent, {once: true});
  }
  if (Number.isFinite(timeoutMs) && timeoutMs > 0) {
    timeout = setTimeout(() => {
      controller.abort(timeoutError);
    }, timeoutMs);
  }
  return {
    signal: controller.signal,
    cleanup: () => {
      if (timeout) {
        clearTimeout(timeout);
      }
      parentSignal?.removeEventListener?.("abort", abortFromParent);
    },
  };
}

function calculateApnsFallbackTimeoutMs(totalTimeoutMs) {
  if (!Number.isFinite(totalTimeoutMs) || totalTimeoutMs <= 1) {
    return BACKGROUND_STUDENT_RESPONDER_APNS_TIMEOUT_MS;
  }
  return Math.max(
    1,
    Math.min(
      BACKGROUND_STUDENT_RESPONDER_APNS_TIMEOUT_MS,
      Math.floor(totalTimeoutMs * 0.7),
    ),
  );
}

function readCallableData(data) {
  return data && typeof data === "object" && !Array.isArray(data) ? data : {};
}

function readNestedObject(value) {
  return value && typeof value === "object" && !Array.isArray(value) ?
    value :
    {};
}

function readCityKey(value) {
  if (!value) {
    return "";
  }

  if (typeof value === "string") {
    return normalizeString(value);
  }

  if (typeof value === "object") {
    return normalizeString(value.key || value.cityKey || value.value || "");
  }

  return "";
}

function hasDirectCallTarget(payload = {}) {
  return [
    payload.directTutorId,
    payload.directUserId,
    payload.targetUserId,
  ].some((value) => normalizeString(value));
}

function normalizeStartSearchInput(data) {
  const payload = readCallableData(data);
  if (hasDirectCallTarget(payload)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Direct calls must use direct-call endpoints",
      {reason: "direct_call_not_supported"},
    );
  }

  const filters = readNestedObject(payload.filters);
  return {
    language: normalizeString(payload.language || payload.languageCode),
    preferredPartnerLevel: normalizeString(
      payload.preferredPartnerLevel ||
        payload.preferredLevel ||
        filters.preferredLevel ||
        filters.level,
    ),
    preferredCountry: normalizeString(
      payload.preferredCountry ||
        payload.countryCode ||
        filters.countryCode,
    ),
    cityKey: normalizeString(payload.cityKey || filters.cityKey),
    appState: normalizeAppState(payload.appState),
    platform: normalizeString(payload.platform),
  };
}

function buildStartSearchAccessDecision({
  requesterRole,
  requesterData = {},
  usageData = null,
  nowMillis = Date.now(),
}) {
  return buildStudentCallAccessDecision({
    userRole: requesterRole,
    userData: requesterData,
    usageData,
    nowMillis,
  });
}

function throwAccessDecision(decision) {
  if (decision.allowed) {
    return;
  }

  throw new functions.https.HttpsError(
    decision.code,
    decision.message,
    {reason: decision.reason},
  );
}

function buildStartSearchFilters({
  input = {},
  requesterData = {},
}) {
  const storedProfile = readNestedObject(requesterData.matchProfile);
  return normalizeSearchRequestFilters({
    preferredLevel:
      input.preferredPartnerLevel ||
      readLevelValue(requesterData.level) ||
      readLevelValue(storedProfile.level),
    countryCode:
      input.preferredCountry ||
      readCountryCode(requesterData.Country_NS) ||
      readCountryCode(storedProfile.country),
    cityKey:
      input.cityKey ||
      readCityKey(requesterData.profileCity) ||
      readCityKey(storedProfile.city),
  });
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

function readReferenceId(value) {
  return value && typeof value.id === "string" ? value.id.trim() : "";
}

function searchRequestBelongsToUser(requestData = {}, userId) {
  const normalizedUserId = normalizeString(userId);
  const explicitUserIds = [
    requestData.userId,
    requestData.studentId,
    requestData.requesterId,
  ].map(normalizeString).filter(Boolean);
  const referencedUserIds = [
    requestData.userRef,
    requestData.studentRef,
    requestData.requesterRef,
  ].map(readReferenceId).filter(Boolean);
  const ownerIds = [...explicitUserIds, ...referencedUserIds];

  return ownerIds.length === 0 ||
    ownerIds.every((ownerId) => ownerId === normalizedUserId);
}

function isReusableSearchRequest(requestData = {}, nowMillis = Date.now()) {
  const status = normalizeString(requestData.status);
  if (!SEARCH_REQUEST_ACTIVE_STATUSES.includes(status)) {
    return false;
  }

  const expiresAtMillis = timestampToMillis(requestData.expiresAt);
  if (expiresAtMillis === null || expiresAtMillis <= nowMillis) {
    return false;
  }

  if (status === SEARCH_REQUEST_STATUS.MATCHED) {
    return true;
  }

  const isBackgroundSearch =
    normalizeAppState(requestData.appState) ===
      SEARCH_REQUEST_APP_STATE.BACKGROUND;
  const backgroundExpiresAtMillis = timestampToMillis(
    requestData.backgroundExpiresAt,
  );
  if (
    isBackgroundSearch &&
    backgroundExpiresAtMillis !== null &&
    backgroundExpiresAtMillis <= nowMillis
  ) {
    return false;
  }
  if (
    isBackgroundSearch &&
    backgroundExpiresAtMillis !== null &&
    backgroundExpiresAtMillis > nowMillis
  ) {
    return true;
  }

  const heartbeatAtMillis = timestampToMillis(requestData.heartbeatAt);
  const staleCutoffMillis =
    nowMillis - SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS * 1000;

  return heartbeatAtMillis !== null && heartbeatAtMillis >= staleCutoffMillis;
}

function canReuseSearchRequestForUser({
  requestData = {},
  userId,
  nowMillis = Date.now(),
}) {
  return searchRequestBelongsToUser(requestData, userId) &&
    isReusableSearchRequest(requestData, nowMillis);
}

function buildStartSearchResponse({
  userId,
  requestData = {},
  reused = false,
}) {
  return {
    status: normalizeString(requestData.status) || "active",
    searchRequestId: userId,
    requestId: normalizeString(requestData.requestId) || null,
    sessionId:
      normalizeString(requestData.currentSessionId) ||
      normalizeString(requestData.activeSessionId) ||
      normalizeString(requestData.matchedSessionId) ||
      null,
    pairAttemptId: normalizeString(requestData.pairAttemptId) || null,
    expiresAt: timestampToIsoString(requestData.expiresAt),
    errorCode: null,
    reused,
  };
}

function canAttemptStudentPairForSearchRequest(requestData = {}) {
  return [
    SEARCH_REQUEST_STATUS.ACTIVE,
  ].includes(normalizeString(requestData.status));
}

function buildMatchedStartSearchResponse({
  userId,
  requestData = {},
  matchResult = {},
  reused = false,
}) {
  return {
    ...buildStartSearchResponse({
      userId,
      requestData: {
        ...requestData,
        status: SEARCH_REQUEST_STATUS.MATCHED,
        currentSessionId: matchResult.sessionId,
        matchedSessionId: matchResult.sessionId,
        pairAttemptId: matchResult.pairAttemptId,
      },
      reused,
    }),
    matchedUserId: normalizeString(matchResult.responderId) || null,
    matchedRole: normalizeString(matchResult.responderRole) || null,
    scenario: "student_student",
  };
}

function buildCurrentMatchedStartSearchResponse({
  userId,
  requestData = {},
  reused = false,
}) {
  const matchedRole = normalizeString(requestData.matchedRole);
  const scenario = matchedRole === "student" ?
    "student_student" :
    (matchedRole === "native_speaker" || matchedRole === "teacher" ?
      "student_teacher" :
      null);
  return {
    ...buildStartSearchResponse({
      userId,
      requestData,
      reused,
    }),
    matchedUserId:
      normalizeString(requestData.matchedUserId) ||
      normalizeString(requestData.matchedResponderId) ||
      null,
    matchedRole: matchedRole || null,
    scenario,
  };
}

function hasCurrentMatchedSession(requestData = {}) {
  return normalizeString(requestData.status) ===
      SEARCH_REQUEST_STATUS.MATCHED &&
    Boolean(
      normalizeString(requestData.currentSessionId) ||
      normalizeString(requestData.matchedSessionId) ||
      normalizeString(requestData.activeSessionId),
    );
}

async function tryReadCurrentMatchedStartSearchResponse({
  db,
  userId,
  reused = false,
}) {
  const searchRequestSnapshot = await db
    .collection(SEARCH_REQUEST_COLLECTION)
    .doc(userId)
    .get();
  const requestData = searchRequestSnapshot.exists ?
    searchRequestSnapshot.data() || {} :
    {};

  if (
    !searchRequestSnapshot.exists ||
    !searchRequestBelongsToUser(requestData, userId) ||
    !hasCurrentMatchedSession(requestData)
  ) {
    return null;
  }

  return buildCurrentMatchedStartSearchResponse({
    userId,
    requestData,
    reused,
  });
}

function buildStudentPairSessionData({
  requesterId = "",
  requestData = {},
  selectedCandidate = {},
  studentCandidates = [],
  candidateStats = {},
  nowMillis = Date.now(),
  timestampFromDate = admin.firestore.Timestamp.fromDate,
}) {
  const candidateIds = studentCandidates
    .map((candidate) => normalizeString(candidate.userId))
    .filter(Boolean);
  const selectedResponderId = normalizeString(selectedCandidate.userId);
  const sessionPolicyState = buildInitialSessionPolicyState(nowMillis);
  return {
    language: normalizeString(requestData.language),
    expiresAt: timestampFromDate(sessionPolicyState.expiresAt),
    sessionPolicy: sessionPolicyState.sessionPolicy,
    [STUDENT_REVIEW_FLAG_FIELD]: false,
    [TUTOR_REVIEW_FLAG_FIELD]: false,
    availableTutors: candidateIds,
    triedTutors: selectedResponderId ? [selectedResponderId] : [],
    matchContext: {
      requesterId,
      requesterRole: "student",
      requestedLanguage: normalizeString(requestData.language),
      filters: readNestedObject(requestData.filters),
      matcher: "startSearch",
      candidatePoolSize: candidateIds.length,
      candidateIds,
      candidateStats,
      selectedResponderId,
      selectedResponderRole: "student",
      selectedResponderSource:
        normalizeString(selectedCandidate.source) || null,
      selectedResponderSearchRequestId:
        normalizeString(selectedCandidate.searchRequestId) || null,
    },
  };
}

function buildStudentPairResponderCallData({
  sessionId = "",
  pushPayload = {},
} = {}) {
  return {
    sessionId: normalizeString(sessionId),
    callerName: normalizeString(pushPayload.studentName) || "Student",
    callerId: normalizeString(pushPayload.studentId),
    callerPhoto: normalizeString(pushPayload.studentPhoto),
    language: normalizeString(pushPayload.language),
  };
}

function buildStudentPairResponderPushPayload(callData = {}) {
  return {
    type: "incoming_call",
    sessionId: normalizeString(callData.sessionId),
    callerName: normalizeString(callData.callerName) || "Student",
    callerId: normalizeString(callData.callerId),
    callerPhoto: normalizeString(callData.callerPhoto),
    language: normalizeString(callData.language),
  };
}

function buildStudentPairResponderFcmMessage({
  fcmToken = "",
  payload = {},
  bundleId = "com.appwave.smalltalk",
} = {}) {
  return {
    token: normalizeString(fcmToken),
    data: payload,
    android: {
      priority: "high",
    },
    apns: {
      headers: {
        "apns-priority": "10",
        "apns-push-type": "alert",
        "apns-topic": bundleId,
      },
      payload: {
        aps: {
          "content-available": 1,
          alert: {
            title: "Входящий звонок",
            body: `${payload.callerName} хочет попрактиковать ${payload.language}`,
          },
          sound: "default",
          badge: 1,
        },
      },
    },
  };
}

function isFreshBackgroundSearchRequest(
  requestData = {},
  nowMillis = Date.now(),
) {
  if (
    normalizeString(requestData[SEARCH_REQUEST_FIELD.STATUS]) !==
    SEARCH_REQUEST_STATUS.MATCHED
  ) {
    return false;
  }
  if (
    normalizeAppState(requestData[SEARCH_REQUEST_FIELD.APP_STATE]) !==
    SEARCH_REQUEST_APP_STATE.BACKGROUND
  ) {
    return false;
  }
  const backgroundExpiresAtMillis = timestampToMillis(
    requestData[SEARCH_REQUEST_FIELD.BACKGROUND_EXPIRES_AT],
  );
  return backgroundExpiresAtMillis !== null &&
    backgroundExpiresAtMillis > nowMillis;
}

function readSessionResponseDeadlineMillis(sessionData = {}) {
  const deadlines = [
    timestampToMillis(sessionData.responseExpiresAt),
    timestampToMillis(sessionData.confirmationExpiresAt),
  ].filter((deadline) => deadline !== null);
  return deadlines.length ? Math.min(...deadlines) : null;
}

function isSessionResponseWindowOpen(
  sessionData = {},
  nowMillis = Date.now(),
) {
  const responseDeadlineMillis = readSessionResponseDeadlineMillis(sessionData);
  return responseDeadlineMillis !== null &&
    responseDeadlineMillis > nowMillis;
}

function searchRequestMatchesSession(requestData = {}, sessionId = "") {
  const normalizedSessionId = normalizeString(sessionId);
  if (!normalizedSessionId) {
    return false;
  }
  const linkedSessionIds = [
    requestData[SEARCH_REQUEST_FIELD.CURRENT_SESSION_ID],
    requestData[SEARCH_REQUEST_FIELD.MATCHED_SESSION_ID],
    requestData[SEARCH_REQUEST_FIELD.ACTIVE_SESSION_ID],
  ].map(normalizeString).filter(Boolean);
  return linkedSessionIds.includes(normalizedSessionId);
}

function searchRequestBelongsToResponder(requestData = {}, responderId = "") {
  const normalizedResponderId = normalizeString(responderId);
  if (!normalizedResponderId) {
    return false;
  }
  const ownerIds = [
    requestData[SEARCH_REQUEST_FIELD.USER_ID],
    readReferenceId(requestData[SEARCH_REQUEST_FIELD.USER_REF]),
  ].map(normalizeString).filter(Boolean);
  return ownerIds.length > 0 &&
    ownerIds.every((ownerId) => ownerId === normalizedResponderId);
}

function isStudentResponderSession(sessionData = {}, responderId = "") {
  const normalizedResponderId = normalizeString(responderId);
  const participantRoles = readNestedObject(sessionData.participantRoles);
  const responderRoles = [
    sessionData.currentResponderRole,
    sessionData.responderRole,
    participantRoles[normalizedResponderId],
  ].map(normalizeRole);
  const scenario = normalizeString(sessionData.scenario);
  return responderRoles.every((role) => role === "student") &&
    scenario === "student_student";
}

function shouldCreateBackgroundStudentResponderIncomingCall({
  sessionData = {},
  sessionId = "",
  responderId = "",
  responderSearchRequestData = {},
  nowMillis = Date.now(),
}) {
  const normalizedResponderId = normalizeString(responderId);
  if (!normalizedResponderId) {
    return {shouldNotify: false, reason: "missing_responder"};
  }
  const sessionStatus = normalizeString(sessionData.status);
  if (
    sessionStatus === VIDEO_SESSION_STATUS.CONNECTING ||
    sessionStatus === VIDEO_SESSION_STATUS.ACTIVE
  ) {
    return {shouldNotify: false, reason: `session_${sessionStatus}`};
  }
  if (
    sessionStatus !== VIDEO_SESSION_STATUS.PENDING_CONFIRMATION
  ) {
    return {shouldNotify: false, reason: "session_not_pending"};
  }
  const assignedResponderId =
    normalizeString(sessionData.currentResponderId) ||
    normalizeString(sessionData.currentTutorId);
  if (assignedResponderId !== normalizedResponderId) {
    return {shouldNotify: false, reason: "responder_mismatch"};
  }
  if (!isStudentResponderSession(sessionData, normalizedResponderId)) {
    return {shouldNotify: false, reason: "responder_not_student"};
  }
  if (!isSessionResponseWindowOpen(sessionData, nowMillis)) {
    return {shouldNotify: false, reason: "response_window_closed"};
  }
  if (
    hasActiveAcceptLockForResponder({
      sessionData,
      responderId: normalizedResponderId,
      nowMillis,
    })
  ) {
    return {shouldNotify: false, reason: "accept_in_progress"};
  }
  if (!isFreshBackgroundSearchRequest(responderSearchRequestData, nowMillis)) {
    return {shouldNotify: false, reason: "responder_not_background"};
  }
  if (
    !searchRequestBelongsToResponder(
      responderSearchRequestData,
      normalizedResponderId,
    )
  ) {
    return {shouldNotify: false, reason: "search_request_owner_mismatch"};
  }
  if (!searchRequestMatchesSession(responderSearchRequestData, sessionId)) {
    return {shouldNotify: false, reason: "search_request_session_mismatch"};
  }
  return {shouldNotify: true, reason: "background_responder"};
}

function shouldLeaveBackgroundNotificationForAccept({
  decision = {},
  sessionData = {},
} = {}) {
  const status = normalizeString(sessionData.status);
  return decision.reason === "accept_in_progress" ||
    status === VIDEO_SESSION_STATUS.CONNECTING ||
    status === VIDEO_SESSION_STATUS.ACTIVE;
}

function buildStudentPairRequesterInfo(requesterData = {}) {
  return {
    name:
      normalizeString(requesterData.display_name) ||
      normalizeString(requesterData.displayName) ||
      "Student",
    photo:
      normalizeString(requesterData.photo_url) ||
      normalizeString(requesterData.photoUrl),
  };
}

async function createBackgroundStudentResponderIncomingCall({
  db,
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  requesterData = {},
  nowMillis = Date.now(),
}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (!normalizedSessionId || !normalizedResponderId || !searchDocId) {
    return {shouldNotify: false, reason: "missing_ids"};
  }

  return db.runTransaction(async (transaction) => {
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const responderSearchRef = db
      .collection(SEARCH_REQUEST_COLLECTION)
      .doc(searchDocId);
    const [sessionSnap, responderSearchSnap] = await Promise.all([
      transaction.get(sessionRef),
      transaction.get(responderSearchRef),
    ]);
    if (!sessionSnap.exists) {
      return {shouldNotify: false, reason: "session_missing"};
    }
    if (!responderSearchSnap.exists) {
      return {shouldNotify: false, reason: "responder_search_missing"};
    }

    const sessionData = sessionSnap.data() || {};
    const responderSearchRequestData = responderSearchSnap.data() || {};
    const decision = shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData,
      sessionId: normalizedSessionId,
      responderId: normalizedResponderId,
      responderSearchRequestData,
      nowMillis,
    });
    if (!decision.shouldNotify) {
      return decision;
    }

    const notification = createIncomingCallNotificationInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      recipientId: normalizedResponderId,
      sessionData,
      studentInfo: buildStudentPairRequesterInfo(requesterData),
      studentNameFallback: "Student",
      now: new Date(nowMillis),
    });

    return {
      shouldNotify: true,
      reason: decision.reason,
      notificationId: notification.notificationId,
      pushPayload: notification.pushPayload,
    };
  });
}

async function backgroundStudentResponderPushStillCurrent({
  db,
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  notificationId = "",
  nowMillis = Date.now(),
}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (!normalizedSessionId || !normalizedResponderId || !searchDocId) {
    return {stillCurrent: false, reason: "missing_ids", leaveForAccept: false};
  }

  const reads = [
    db.collection("videoSessions").doc(normalizedSessionId).get(),
    db.collection(SEARCH_REQUEST_COLLECTION).doc(searchDocId).get(),
  ];
  if (notificationId) {
    reads.push(db.collection("notifications").doc(notificationId).get());
  }
  const [sessionSnap, responderSearchSnap, notificationSnap] =
    await Promise.all(reads);
  if (!sessionSnap.exists || !responderSearchSnap.exists) {
    return {
      stillCurrent: false,
      reason: "session_or_search_missing",
      leaveForAccept: false,
    };
  }
  const sessionData = sessionSnap.data() || {};

  const decision = shouldCreateBackgroundStudentResponderIncomingCall({
    sessionData,
    sessionId: normalizedSessionId,
    responderId: normalizedResponderId,
    responderSearchRequestData: responderSearchSnap.data() || {},
    nowMillis,
  });
  if (!decision.shouldNotify) {
    return {
      stillCurrent: false,
      reason: decision.reason,
      leaveForAccept: shouldLeaveBackgroundNotificationForAccept({
        decision,
        sessionData,
      }),
    };
  }

  if (notificationId) {
    const notificationData = notificationSnap?.data?.() || {};
    if (
      !notificationSnap?.exists ||
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        stillCurrent: false,
        reason: "notification_not_current",
        leaveForAccept: false,
      };
    }
  }

  return {
    stillCurrent: true,
    reason: decision.reason,
    leaveForAccept: false,
  };
}

async function cancelBackgroundStudentResponderNotification({
  db,
  notificationId = "",
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  reason = "stale_before_push",
  pushResult = null,
  nowMillis = Date.now(),
}) {
  const normalizedNotificationId = normalizeString(notificationId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (
    !normalizedNotificationId ||
    !normalizedSessionId ||
    !normalizedResponderId ||
    !searchDocId
  ) {
    return {cancelled: false, reason: "missing_ids", leaveForAccept: false};
  }

  return db.runTransaction(async (transaction) => {
    const notificationRef = db
      .collection("notifications")
      .doc(normalizedNotificationId);
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const responderSearchRef = db
      .collection(SEARCH_REQUEST_COLLECTION)
      .doc(searchDocId);
    const [sessionSnap, responderSearchSnap, notificationSnap] =
      await Promise.all([
        transaction.get(sessionRef),
        transaction.get(responderSearchRef),
        transaction.get(notificationRef),
      ]);
    if (!notificationSnap.exists) {
      return {
        cancelled: false,
        reason: "notification_missing",
        leaveForAccept: false,
      };
    }

    const notificationData = notificationSnap.data() || {};
    if (
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        cancelled: false,
        reason: "notification_not_current",
        leaveForAccept: false,
      };
    }

    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    const decision = sessionSnap.exists && responderSearchSnap.exists ?
      shouldCreateBackgroundStudentResponderIncomingCall({
        sessionData,
        sessionId: normalizedSessionId,
        responderId: normalizedResponderId,
        responderSearchRequestData: responderSearchSnap.data() || {},
        nowMillis,
      }) :
      {shouldNotify: false, reason: "session_or_search_missing"};
    if (
      shouldLeaveBackgroundNotificationForAccept({
        decision,
        sessionData,
      })
    ) {
      return {
        cancelled: false,
        reason: "accept_finalization_in_progress",
        staleReason: decision.reason,
        leaveForAccept: true,
      };
    }

    const update = {
      status: "cancelled",
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelReason: normalizeString(reason) || "stale_before_push",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (pushResult && pushResult.sent === true) {
      update.pushSentAt = admin.firestore.FieldValue.serverTimestamp();
      update.pushChannel = normalizeString(pushResult.channel) || "unknown";
    }
    transaction.update(notificationRef, update);
    return {
      cancelled: true,
      reason: normalizeString(reason) || "stale_before_push",
      staleReason: decision.reason,
      leaveForAccept: false,
    };
  });
}

async function recordBackgroundStudentResponderPushFailure({
  db,
  notificationId = "",
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  error,
  nowMillis = Date.now(),
}) {
  const normalizedNotificationId = normalizeString(notificationId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (
    !normalizedNotificationId ||
    !normalizedSessionId ||
    !normalizedResponderId ||
    !searchDocId
  ) {
    return {stillCurrent: false, reason: "missing_ids", updated: false};
  }

  return db.runTransaction(async (transaction) => {
    const notificationRef = db
      .collection("notifications")
      .doc(normalizedNotificationId);
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const responderSearchRef = db
      .collection(SEARCH_REQUEST_COLLECTION)
      .doc(searchDocId);
    const [sessionSnap, responderSearchSnap, notificationSnap] =
      await Promise.all([
        transaction.get(sessionRef),
        transaction.get(responderSearchRef),
        transaction.get(notificationRef),
      ]);
    if (!notificationSnap.exists) {
      return {
        stillCurrent: false,
        reason: "notification_missing",
        updated: false,
      };
    }

    const notificationData = notificationSnap.data() || {};
    if (
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        stillCurrent: false,
        reason: "notification_not_current",
        updated: false,
      };
    }

    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    const decision = sessionSnap.exists && responderSearchSnap.exists ?
      shouldCreateBackgroundStudentResponderIncomingCall({
        sessionData,
        sessionId: normalizedSessionId,
        responderId: normalizedResponderId,
        responderSearchRequestData: responderSearchSnap.data() || {},
        nowMillis,
      }) :
      {shouldNotify: false, reason: "session_or_search_missing"};

    if (!decision.shouldNotify) {
      if (shouldLeaveBackgroundNotificationForAccept({decision, sessionData})) {
        return {
          stillCurrent: false,
          reason: "accept_finalization_in_progress",
          staleReason: decision.reason,
          updated: false,
        };
      }
      transaction.update(notificationRef, {
        status: "cancelled",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelReason: "stale_after_push",
        staleReason: decision.reason,
        lastPushError: readErrorMessage(error, "push_failed"),
        lastPushFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        stillCurrent: false,
        reason: "stale_after_push",
        staleReason: decision.reason,
        updated: true,
      };
    }

    transaction.update(notificationRef, {
      lastPushError: readErrorMessage(error, "push_failed"),
      lastPushFailedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
      stillCurrent: true,
      reason: decision.reason,
      updated: true,
    };
  });
}

async function recordBackgroundStudentResponderPushSuccess({
  db,
  notificationId = "",
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  pushResult = {},
  nowMillis = Date.now(),
}) {
  const normalizedNotificationId = normalizeString(notificationId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (
    !normalizedNotificationId ||
    !normalizedSessionId ||
    !normalizedResponderId ||
    !searchDocId
  ) {
    return {stillCurrent: false, reason: "missing_ids", updated: false};
  }

  return db.runTransaction(async (transaction) => {
    const notificationRef = db
      .collection("notifications")
      .doc(normalizedNotificationId);
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const responderSearchRef = db
      .collection(SEARCH_REQUEST_COLLECTION)
      .doc(searchDocId);
    const [sessionSnap, responderSearchSnap, notificationSnap] =
      await Promise.all([
        transaction.get(sessionRef),
        transaction.get(responderSearchRef),
        transaction.get(notificationRef),
      ]);
    if (!notificationSnap.exists) {
      return {
        stillCurrent: false,
        reason: "notification_missing",
        updated: false,
      };
    }

    const notificationData = notificationSnap.data() || {};
    if (
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        stillCurrent: false,
        reason: "notification_not_current",
        updated: false,
      };
    }

    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    const decision = sessionSnap.exists && responderSearchSnap.exists ?
      shouldCreateBackgroundStudentResponderIncomingCall({
        sessionData,
        sessionId: normalizedSessionId,
        responderId: normalizedResponderId,
        responderSearchRequestData: responderSearchSnap.data() || {},
        nowMillis,
      }) :
      {shouldNotify: false, reason: "session_or_search_missing"};

    if (!decision.shouldNotify) {
      if (shouldLeaveBackgroundNotificationForAccept({decision, sessionData})) {
        return {
          stillCurrent: false,
          reason: "accept_finalization_in_progress",
          staleReason: decision.reason,
          updated: false,
        };
      }
      transaction.update(notificationRef, {
        status: "cancelled",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelReason: "stale_after_push",
        staleReason: decision.reason,
        pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
        pushChannel: normalizeString(pushResult.channel) || "unknown",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        stillCurrent: false,
        reason: "stale_after_push",
        staleReason: decision.reason,
        updated: true,
      };
    }

    transaction.update(notificationRef, {
      pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
      pushChannel: normalizeString(pushResult.channel) || "unknown",
      lastPushError: admin.firestore.FieldValue.delete(),
      lastPushFailedAt: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
      stillCurrent: true,
      reason: decision.reason,
      updated: true,
    };
  });
}

async function sendVoipPushToStudentResponder(
  responderId,
  callData = {},
  dependencies = {},
) {
  const normalizedResponderId = normalizeString(responderId);
  if (!normalizedResponderId) {
    return {sent: false, reason: "missing_responder"};
  }

  const firestore = dependencies.firestore || admin.firestore();
  const getTokens = dependencies.getUserVoipTokens || getUserVoipTokens;
  const sendApns = dependencies.sendApnsVoip || sendApnsVoip;
  const messaging = dependencies.messaging || admin.messaging();
  const logger = dependencies.logger || console;
  const signal = dependencies.signal || null;
  const apnsTimeoutMs = Number.isFinite(dependencies.apnsTimeoutMs) &&
    dependencies.apnsTimeoutMs > 0 ?
    dependencies.apnsTimeoutMs :
    BACKGROUND_STUDENT_RESPONDER_APNS_TIMEOUT_MS;
  throwIfAborted(signal);
  const responderDoc = await firestore
    .collection("users")
    .doc(normalizedResponderId)
    .get();
  throwIfAborted(signal);
  if (!responderDoc.exists) {
    return {sent: false, reason: "responder_missing"};
  }

  const responderData = responderDoc.data() || {};
  const bundleId = process.env.IOS_BUNDLE_ID || "com.appwave.smalltalk";
  const voipTopic =
    process.env.IOS_VOIP_TOPIC ||
    (bundleId.endsWith(".voip") ? bundleId : `${bundleId}.voip`);
  const {voipPushToken, voipToken: fcmToken} =
    await getTokens(normalizedResponderId, responderData);
  throwIfAborted(signal);
  if (!voipPushToken && !fcmToken) {
    return {sent: false, reason: "missing_tokens"};
  }

  const payload = buildStudentPairResponderPushPayload(callData);
  let apnsErrorMessage = "";

  if (voipPushToken) {
    const apnsAbort = buildChildAbortController({
      parentSignal: signal,
      timeoutMs: apnsTimeoutMs,
      timeoutError: new Error("apns_voip_timeout"),
    });
    try {
      await sendApns({
        deviceToken: voipPushToken,
        topic: voipTopic,
        signal: apnsAbort.signal,
        payload: {
          aps: {"content-available": 1},
          ...payload,
        },
      });
      return {sent: true, channel: "apns_voip"};
    } catch (error) {
      apnsErrorMessage =
        readErrorMessage(error, "apns_voip_failed");
      logger.error(
        "Failed to send APNs VoIP push to background student:",
        readErrorMessage(error, "apns_voip_failed"),
      );
    } finally {
      apnsAbort.cleanup();
    }
  }

  if (!fcmToken) {
    return {
      sent: false,
      reason: "missing_fcm_token",
      error: apnsErrorMessage || "missing_fcm_token",
    };
  }

  try {
    throwIfAborted(signal);
    await waitForAbortable(
      messaging.send(buildStudentPairResponderFcmMessage({
        fcmToken,
        payload,
        bundleId,
      })),
      signal,
    );
  } catch (error) {
    const fcmErrorMessage =
      readErrorMessage(error, "fcm_failed");
    return {
      sent: false,
      reason: "fcm_failed",
      error: apnsErrorMessage ?
        `apns: ${apnsErrorMessage}; fcm: ${fcmErrorMessage}` :
        fcmErrorMessage,
    };
  }
  return {sent: true, channel: "fcm"};
}

async function runBackgroundStudentResponderPushSender({
  pushSender,
  responderId = "",
  callData = {},
  timeoutMs = BACKGROUND_STUDENT_RESPONDER_PUSH_TIMEOUT_MS,
}) {
  const controller = new AbortController();
  const normalizedTimeoutMs = Number.isFinite(timeoutMs) && timeoutMs > 0 ?
    timeoutMs :
    BACKGROUND_STUDENT_RESPONDER_PUSH_TIMEOUT_MS;
  const timeoutError = new Error("push_timeout");
  let timeout = null;
  const pushPromise = Promise.resolve()
    .then(() => pushSender(responderId, callData, {
      apnsTimeoutMs: calculateApnsFallbackTimeoutMs(normalizedTimeoutMs),
      signal: controller.signal,
    }));
  const timeoutPromise = new Promise((resolve, reject) => {
    timeout = setTimeout(() => {
      controller.abort(timeoutError);
      reject(timeoutError);
    }, normalizedTimeoutMs);
  });

  try {
    return await Promise.race([pushPromise, timeoutPromise]);
  } finally {
    clearTimeout(timeout);
    pushPromise.catch(() => {});
  }
}

async function maybeNotifyBackgroundStudentResponder({
  db,
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  requesterData = {},
  pushSender = sendVoipPushToStudentResponder,
  pushTimeoutMs = BACKGROUND_STUDENT_RESPONDER_PUSH_TIMEOUT_MS,
}) {
  const nowMillis = Date.now();
  const notification = await createBackgroundStudentResponderIncomingCall({
    db,
    sessionId,
    responderId,
    responderSearchRequestDocId,
    requesterData,
    nowMillis,
  });
  if (!notification.shouldNotify) {
    return notification;
  }

  const prePushState = await backgroundStudentResponderPushStillCurrent({
    db,
    sessionId,
    responderId,
    responderSearchRequestDocId,
    notificationId: notification.notificationId,
    nowMillis: Date.now(),
  });
  if (!prePushState.stillCurrent) {
    let cancelResult = null;
    if (!prePushState.leaveForAccept) {
      try {
        cancelResult = await cancelBackgroundStudentResponderNotification({
          db,
          notificationId: notification.notificationId,
          sessionId,
          responderId,
          responderSearchRequestDocId,
          reason: "stale_before_push",
          nowMillis: Date.now(),
        });
      } catch (error) {
        console.error(
          "Failed to cancel stale background student notification",
          {
            sessionId,
            responderId,
            notificationId: notification.notificationId,
            error: readErrorMessage(error, "cancel_failed"),
          },
        );
      }
    }
    return {
      ...notification,
      shouldNotify: false,
      reason: prePushState.leaveForAccept || cancelResult?.leaveForAccept ?
        "accept_finalization_in_progress" :
        "stale_before_push",
      staleReason: cancelResult?.staleReason ||
        cancelResult?.reason ||
        prePushState.reason,
    };
  }

  const callData = buildStudentPairResponderCallData({
    sessionId,
    pushPayload: notification.pushPayload,
  });
  let pushResult;
  try {
    pushResult = await runBackgroundStudentResponderPushSender({
      pushSender,
      responderId,
      callData,
      timeoutMs: pushTimeoutMs,
    });
  } catch (error) {
    pushResult = {
      sent: false,
      reason: "push_failed",
      error: readErrorMessage(error, "push_failed"),
    };
  }
  if (!pushResult || pushResult.sent !== true) {
    pushResult = {
      ...(pushResult && typeof pushResult === "object" ? pushResult : {}),
      sent: false,
      reason:
        normalizeString(pushResult?.reason) ||
        "push_failed",
      error:
        normalizeString(pushResult?.error) ||
        normalizeString(pushResult?.reason) ||
        "push_failed",
    };
  }
  if (pushResult && pushResult.sent === false) {
    const failureFinalization =
      await recordBackgroundStudentResponderPushFailure({
        db,
        notificationId: notification.notificationId,
        sessionId,
        responderId,
        responderSearchRequestDocId,
        error: {
          message:
            normalizeString(pushResult.error) ||
            normalizeString(pushResult.reason) ||
            "push_failed",
        },
        nowMillis: Date.now(),
      });
    if (!failureFinalization.stillCurrent) {
      return {
        ...notification,
        shouldNotify: false,
        reason: failureFinalization.reason,
        staleReason: failureFinalization.staleReason ||
          failureFinalization.reason,
        callData,
        pushResult,
      };
    }
  } else if (pushResult && pushResult.sent === true) {
    const successFinalization =
      await recordBackgroundStudentResponderPushSuccess({
        db,
        notificationId: notification.notificationId,
        sessionId,
        responderId,
        responderSearchRequestDocId,
        pushResult,
        nowMillis: Date.now(),
      });
    if (!successFinalization.stillCurrent) {
      return {
        ...notification,
        shouldNotify: false,
        reason: successFinalization.reason,
        staleReason: successFinalization.staleReason ||
          successFinalization.reason,
        callData,
        pushResult,
      };
    }
  }
  return {
    ...notification,
    callData,
    pushResult,
  };
}

async function tryCreateStudentPairForSearchRequest({
  db,
  userId,
  requesterData = {},
  requestData = {},
  reused = false,
}) {
  if (!canAttemptStudentPairForSearchRequest(requestData)) {
    return {
      matched: false,
      response: null,
    };
  }

  const candidatePool = await collectMatchCandidatePool({
    db,
    requesterId: userId,
    requesterEmail: normalizeString(requesterData.email),
    language: requestData.language,
    requesterFilters: requestData.filters || {},
    requesterLevel: readLevelValue(requesterData.level),
    now: new Date(),
    nowMillis: Date.now(),
    includeTeachers: false,
  });
  const studentCandidates = candidatePool.candidates.filter((candidate) =>
    candidate.source === MATCH_CANDIDATE_SOURCE.ACTIVE_STUDENT_QUEUE &&
      normalizeString(candidate.role) === "student" &&
      normalizeString(candidate.userId) !== normalizeString(userId),
  );

  for (const candidate of studentCandidates) {
    const lockNowMillis = Date.now();
    const lockResult = await reserveMatchPair({
      db,
      requesterId: userId,
      responderId: candidate.userId,
      responderRole: "student",
      requesterSearchRequestId: requestData.requestId,
      responderSearchRequestId: candidate.searchRequestId,
      expectedLanguage: requestData.language,
      sessionData: buildStudentPairSessionData({
        requesterId: userId,
        requestData,
        selectedCandidate: candidate,
        studentCandidates,
        candidateStats: candidatePool.stats,
        nowMillis: lockNowMillis,
      }),
      nowMillis: lockNowMillis,
    });

    if (lockResult.locked) {
      if (
        normalizeRole(lockResult.responderRole) === "student" &&
        normalizeString(candidate.source) ===
          MATCH_CANDIDATE_SOURCE.ACTIVE_STUDENT_QUEUE
      ) {
        try {
          await maybeNotifyBackgroundStudentResponder({
            db,
            sessionId: lockResult.sessionId,
            responderId: lockResult.responderId,
            responderSearchRequestDocId: candidate.searchRequestDocId,
            requesterData,
          });
        } catch (error) {
          console.error(
            "Failed to notify background student responder",
            {
              sessionId: lockResult.sessionId,
              responderId: lockResult.responderId,
              error: readErrorMessage(error, "notify_failed"),
            },
          );
        }
      }

      return {
        matched: true,
        response: buildMatchedStartSearchResponse({
          userId,
          requestData,
          matchResult: lockResult,
          reused,
        }),
        lockResult,
      };
    }

    if (String(lockResult.reason || "").startsWith("requester_")) {
      const currentMatchedResponse =
        await tryReadCurrentMatchedStartSearchResponse({
          db,
          userId,
          reused,
        });
      if (currentMatchedResponse) {
        return {
          matched: true,
          response: currentMatchedResponse,
          lockResult,
        };
      }
      break;
    }
  }

  return {
    matched: false,
    response: null,
  };
}

function buildStartSearchRequestData({
  userId,
  userRef,
  requestId,
  requesterData = {},
  input = {},
  nowMillis = Date.now(),
  serverTimestamp,
  timestampFromMillis = admin.firestore.Timestamp.fromMillis,
}) {
  const resolvedLanguage = resolveActiveConversationLanguage(
    requesterData,
    input.language,
  );
  if (!resolvedLanguage.code) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Language is required",
      {reason: "language_required"},
    );
  }

  const expiresAt = timestampFromMillis(
    nowMillis + SEARCH_REQUEST_TIMING.MAX_SEARCH_SECONDS * 1000,
  );
  const backgroundExpiresAt =
    input.appState === SEARCH_REQUEST_APP_STATE.BACKGROUND ?
      timestampFromMillis(
        nowMillis +
          SEARCH_REQUEST_TIMING.BACKGROUND_MAX_SEARCH_SECONDS * 1000,
      ) :
      null;

  return buildInitialSearchRequestData({
    userId,
    userRef,
    requestId,
    role: "student",
    language: resolvedLanguage.code,
    filters: buildStartSearchFilters({input, requesterData}),
    appState: input.appState,
    platform: input.platform,
    serverTimestamp,
    expiresAt,
    backgroundExpiresAt,
  });
}

async function startSearchCallable(data, context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  const input = normalizeStartSearchInput(data);
  const db = admin.firestore();
  const userId = context.auth.uid;
  const userRef = db.collection("users").doc(userId);
  const searchRequestRef = db
    .collection(SEARCH_REQUEST_COLLECTION)
    .doc(userId);
  const usageRef = usageDocRef(db, userId);
  const requestId = db.collection(SEARCH_REQUEST_COLLECTION).doc().id;
  const nowMillis = Date.now();
  const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();

  const startResult = await db.runTransaction(async (transaction) => {
    const requesterSnapshot = await transaction.get(userRef);
    if (!requesterSnapshot.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Requester not found",
      );
    }

    const usageSnapshot = await transaction.get(usageRef);
    const searchRequestSnapshot = await transaction.get(searchRequestRef);
    const requesterData = requesterSnapshot.data() || {};
    const requesterRole = normalizeRole(requesterData.role);
    if (!isSupportedSessionRole(requesterRole)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "This user role cannot start search",
        {reason: "unsupported_role"},
      );
    }

    const existingRequestData = searchRequestSnapshot.exists ?
      searchRequestSnapshot.data() || {} :
      null;
    const accessDecision = buildStartSearchAccessDecision({
      requesterRole,
      requesterData,
      usageData: usageSnapshot.exists ? usageSnapshot.data() : null,
      nowMillis,
    });

    if (
      existingRequestData &&
      canReuseSearchRequestForUser({
        requestData: existingRequestData,
        userId,
        nowMillis,
      })
    ) {
      const response = hasCurrentMatchedSession(existingRequestData) ?
        buildCurrentMatchedStartSearchResponse({
          userId,
          requestData: existingRequestData,
          reused: true,
        }) :
        buildStartSearchResponse({
          userId,
          requestData: existingRequestData,
          reused: true,
        });

      return {
        response,
        requestData: existingRequestData,
        requesterData,
        reused: true,
        shouldTryStudentPair:
          accessDecision.allowed &&
          canAttemptStudentPairForSearchRequest(existingRequestData),
      };
    }

    throwAccessDecision(accessDecision);

    const nextRequestData = buildStartSearchRequestData({
      userId,
      userRef,
      requestId,
      requesterData,
      input,
      nowMillis,
      serverTimestamp,
    });
    transaction.set(searchRequestRef, nextRequestData);

    return {
      response: buildStartSearchResponse({
        userId,
        requestData: nextRequestData,
        reused: false,
      }),
      requestData: nextRequestData,
      requesterData,
      reused: false,
      shouldTryStudentPair: true,
    };
  });

  if (startResult.shouldTryStudentPair) {
    const matchResult = await tryCreateStudentPairForSearchRequest({
      db,
      userId,
      requesterData: startResult.requesterData,
      requestData: startResult.requestData,
      reused: startResult.reused,
    });
    if (matchResult.matched) {
      return matchResult.response;
    }
  }

  return startResult.response;
}

exports.startSearch = functions
  .runWith({secrets: apnsSecrets})
  .https.onCall(startSearchCallable);

exports.__private__ = {
  buildStudentPairRequesterInfo,
  buildStudentPairResponderCallData,
  buildStudentPairResponderFcmMessage,
  buildStudentPairResponderPushPayload,
  buildStartSearchAccessDecision,
  buildStartSearchFilters,
  buildCurrentMatchedStartSearchResponse,
  buildMatchedStartSearchResponse,
  buildStartSearchRequestData,
  buildStartSearchResponse,
  buildStudentPairSessionData,
  canAttemptStudentPairForSearchRequest,
  cancelBackgroundStudentResponderNotification,
  recordBackgroundStudentResponderPushFailure,
  recordBackgroundStudentResponderPushSuccess,
  readErrorMessage,
  runBackgroundStudentResponderPushSender,
  sendVoipPushToStudentResponder,
  isFreshBackgroundSearchRequest,
  isSessionResponseWindowOpen,
  isStudentResponderSession,
  hasCurrentMatchedSession,
  maybeNotifyBackgroundStudentResponder,
  searchRequestMatchesSession,
  searchRequestBelongsToResponder,
  canReuseSearchRequestForUser,
  isReusableSearchRequest,
  normalizeStartSearchInput,
  searchRequestBelongsToUser,
  shouldCreateBackgroundStudentResponderIncomingCall,
  timestampToMillis,
  tryReadCurrentMatchedStartSearchResponse,
  tryCreateStudentPairForSearchRequest,
};
