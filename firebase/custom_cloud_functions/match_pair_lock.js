const admin = require("firebase-admin");
const {
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_FIELD,
  SEARCH_REQUEST_STATUS,
  SEARCH_REQUEST_TIMING,
} = require("./search_requests");
const {
  readLanguageCode,
  normalizeRole,
} = require("./video_sessions_shared");

const USER_COLLECTION = "users";
const VIDEO_SESSION_COLLECTION = "videoSessions";
const MATCH_PAIR_LOCK_TTL_SECONDS = 45;

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

function timestampToMillis(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : null;
  }
  if (typeof value.toDate === "function") {
    const millis = value.toDate().getTime();
    return Number.isFinite(millis) ? millis : null;
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  const millis = Number(value);
  return Number.isFinite(millis) ? millis : null;
}

function readReferenceId(value) {
  return value && typeof value.id === "string" ? value.id.trim() : "";
}

function searchRequestBelongsToUser(requestData = {}, userId = "") {
  const normalizedUserId = normalizeDocumentId(userId);
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

function hasSearchRequestSessionState(requestData = {}) {
  return [
    requestData.activeSessionId,
    requestData.currentSessionId,
    requestData.matchedSessionId,
  ].some((value) => Boolean(normalizeString(value)));
}

function hasLiveSearchRequestLock(requestData = {}, nowMillis = Date.now()) {
  const lockOwner = normalizeString(requestData.lockOwner);
  if (!lockOwner) {
    return false;
  }

  const lockExpiresAtMillis = timestampToMillis(requestData.lockExpiresAt);
  return lockExpiresAtMillis !== null && lockExpiresAtMillis > nowMillis;
}

function isSearchRequestFreshForPairLock(
  requestData = {},
  nowMillis = Date.now(),
) {
  const heartbeatAtMillis = timestampToMillis(
    requestData[SEARCH_REQUEST_FIELD.HEARTBEAT_AT],
  );
  const staleCutoffMillis =
    nowMillis - SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS * 1000;
  if (heartbeatAtMillis === null || heartbeatAtMillis < staleCutoffMillis) {
    return false;
  }

  const expiresAtMillis = timestampToMillis(
    requestData[SEARCH_REQUEST_FIELD.EXPIRES_AT],
  );
  if (expiresAtMillis === null || expiresAtMillis <= nowMillis) {
    return false;
  }

  const appState = normalizeString(requestData[SEARCH_REQUEST_FIELD.APP_STATE]);
  const backgroundExpiresAtMillis = timestampToMillis(
    requestData[SEARCH_REQUEST_FIELD.BACKGROUND_EXPIRES_AT],
  );
  if (appState === SEARCH_REQUEST_APP_STATE.BACKGROUND) {
    if (
      backgroundExpiresAtMillis === null ||
      backgroundExpiresAtMillis <= nowMillis
    ) {
      return false;
    }
  }

  return true;
}

function validateSearchRequestForPairLock({
  requestExists = false,
  requestData = {},
  userId = "",
  requestId = "",
  expectedLanguage = "",
  requireRequestId = false,
  nowMillis = Date.now(),
  participantKey = "requester",
}) {
  if (!requestExists) {
    return {ok: false, reason: `${participantKey}_search_request_missing`};
  }
  if (!searchRequestBelongsToUser(requestData, userId)) {
    return {ok: false, reason: `${participantKey}_search_owner_mismatch`};
  }

  const rawRequestId = normalizeString(requestId);
  const normalizedRequestId = normalizeDocumentId(requestId);
  if (requireRequestId && !rawRequestId) {
    return {ok: false, reason: `${participantKey}_search_request_id_required`};
  }
  if (rawRequestId && !normalizedRequestId) {
    return {ok: false, reason: `${participantKey}_search_request_mismatch`};
  }
  if (
    normalizedRequestId &&
    normalizeString(requestData[SEARCH_REQUEST_FIELD.REQUEST_ID]) !==
      normalizedRequestId
  ) {
    return {ok: false, reason: `${participantKey}_search_request_mismatch`};
  }
  const normalizedExpectedLanguage = readLanguageCode(expectedLanguage);
  if (
    normalizedExpectedLanguage &&
    readLanguageCode(requestData[SEARCH_REQUEST_FIELD.LANGUAGE]) !==
      normalizedExpectedLanguage
  ) {
    return {ok: false, reason: `${participantKey}_search_language_mismatch`};
  }

  if (hasSearchRequestSessionState(requestData)) {
    return {ok: false, reason: `${participantKey}_search_in_session`};
  }
  if (hasLiveSearchRequestLock(requestData, nowMillis)) {
    return {ok: false, reason: `${participantKey}_search_locked`};
  }

  const status = normalizeString(requestData[SEARCH_REQUEST_FIELD.STATUS]);
  const canReserveStatus = [
    SEARCH_REQUEST_STATUS.ACTIVE,
    SEARCH_REQUEST_STATUS.LEGACY_SEARCHING,
  ].includes(status) ||
    (
      status === SEARCH_REQUEST_STATUS.MATCHING &&
      !hasLiveSearchRequestLock(requestData, nowMillis)
    );
  if (!canReserveStatus) {
    return {
      ok: false,
      reason: `${participantKey}_search_status_${status || "missing"}`,
    };
  }
  if (!isSearchRequestFreshForPairLock(requestData, nowMillis)) {
    return {ok: false, reason: `${participantKey}_search_stale`};
  }

  return {ok: true, reason: "ready"};
}

function validateUserForPairLock({
  userExists = false,
  userData = {},
  expectedRole = "",
  participantKey = "requester",
}) {
  if (!userExists) {
    return {ok: false, reason: `${participantKey}_user_missing`};
  }
  if (userData.isInCall === true) {
    return {ok: false, reason: `${participantKey}_in_call`};
  }
  if (normalizeString(userData.currentSessionId)) {
    return {ok: false, reason: `${participantKey}_in_session`};
  }

  const normalizedExpectedRole = normalizeRole(expectedRole);
  const normalizedUserRole = normalizeRole(userData.role);
  if (
    normalizedExpectedRole &&
    normalizedUserRole !== normalizedExpectedRole
  ) {
    return {ok: false, reason: `${participantKey}_role_mismatch`};
  }

  return {ok: true, reason: "ready"};
}

function buildPairAttemptId({
  sessionId = "",
  requesterId = "",
  responderId = "",
}) {
  return [
    "pair",
    normalizeDocumentId(sessionId),
    normalizeDocumentId(requesterId),
    normalizeDocumentId(responderId),
  ].filter(Boolean).join("_");
}

function buildParticipantIds(requesterId, responderId) {
  return Array.from(new Set([
    normalizeDocumentId(requesterId),
    normalizeDocumentId(responderId),
  ].filter(Boolean))).sort();
}

function buildParticipantInfo(userData = {}) {
  return {
    displayName:
      normalizeString(userData.display_name) ||
      normalizeString(userData.displayName) ||
      null,
    photoUrl:
      normalizeString(userData.photo_url) ||
      normalizeString(userData.photoUrl) ||
      null,
  };
}

function buildSearchRequestPairLockUpdate({
  sessionId,
  pairAttemptId,
  otherUserId,
  otherRole,
  matchedResponderId,
  serverTimestamp,
  lockExpiresAt,
}) {
  return {
    [SEARCH_REQUEST_FIELD.STATUS]: SEARCH_REQUEST_STATUS.MATCHING,
    [SEARCH_REQUEST_FIELD.UPDATED_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.CURRENT_SESSION_ID]: sessionId,
    [SEARCH_REQUEST_FIELD.MATCHED_SESSION_ID]: sessionId,
    [SEARCH_REQUEST_FIELD.MATCHED_USER_ID]: otherUserId,
    [SEARCH_REQUEST_FIELD.MATCHED_RESPONDER_ID]: matchedResponderId,
    [SEARCH_REQUEST_FIELD.MATCHED_ROLE]: otherRole,
    [SEARCH_REQUEST_FIELD.PAIR_ATTEMPT_ID]: pairAttemptId,
    [SEARCH_REQUEST_FIELD.LOCK_OWNER]: pairAttemptId,
    [SEARCH_REQUEST_FIELD.LOCK_EXPIRES_AT]: lockExpiresAt,
    [SEARCH_REQUEST_FIELD.LAST_ERROR]: null,
  };
}

function buildVideoSessionPairLockData({
  sessionData = {},
  requesterId,
  responderId,
  requesterRole = "student",
  responderRole,
  sessionId,
  pairAttemptId,
  requesterSearchRequestId = "",
  responderSearchRequestId = "",
  participantInfos = {},
  serverTimestamp,
  lockExpiresAt,
}) {
  const participantIds = buildParticipantIds(requesterId, responderId);
  const scenario = responderRole === "student" ?
    "student_student" :
    "student_teacher";
  const sessionStatus = normalizeString(sessionData.status) || "searching";
  const triedTutors = Array.isArray(sessionData.triedTutors) ?
    sessionData.triedTutors :
    [];
  const availableTutors = Array.isArray(sessionData.availableTutors) ?
    sessionData.availableTutors :
    [responderId];

  return {
    ...sessionData,
    status: sessionStatus,
    pairStatus: "pending_confirmation",
    sessionId,
    requesterId,
    responderId,
    currentResponderId: responderId,
    currentResponderRole: responderRole,
    currentTutorId: responderId,
    requesterRole,
    responderRole,
    participantIds,
    participantRoles: {
      [requesterId]: requesterRole,
      [responderId]: responderRole,
    },
    participantInfos,
    studentId: requesterId,
    tutorId: responderRole === "native_speaker" ? responderId : null,
    scenario,
    pairAttemptId,
    responseExpiresAt: lockExpiresAt,
    confirmationExpiresAt: lockExpiresAt,
    searchRequestIds: {
      requester: normalizeString(requesterSearchRequestId) || null,
      responder: normalizeString(responderSearchRequestId) || null,
    },
    triedTutors,
    availableTutors,
    createdAt: serverTimestamp,
    updatedAt: serverTimestamp,
    matchLock: {
      owner: pairAttemptId,
      expiresAt: lockExpiresAt,
      participantIds,
    },
  };
}

function buildPairLockFailure(reason) {
  return {
    locked: false,
    reason,
  };
}

function readSessionRequesterId(sessionData = {}) {
  return normalizeDocumentId(sessionData.requesterId) ||
    normalizeDocumentId(sessionData.studentId) ||
    normalizeDocumentId(sessionData.matchContext?.requesterId);
}

function readSessionSearchRequestId(sessionData = {}, participantKey = "") {
  return normalizeString(sessionData.searchRequestIds?.[participantKey]);
}

function getSessionParticipantIds(sessionData = {}) {
  return Array.from(new Set([
    ...(Array.isArray(sessionData.participantIds) ?
      sessionData.participantIds :
      []),
    sessionData.studentId,
    sessionData.requesterId,
    sessionData.currentTutorId,
    sessionData.currentResponderId,
    sessionData.responderId,
    sessionData.tutorId,
  ].map(normalizeDocumentId).filter(Boolean))).sort();
}

function searchRequestMatchesSession(requestData = {}, sessionId = "") {
  const normalizedSessionId = normalizeDocumentId(sessionId);
  return [
    requestData.activeSessionId,
    requestData.currentSessionId,
    requestData.matchedSessionId,
    requestData.sessionId,
    requestData.videoSessionId,
  ].map(normalizeString).includes(normalizedSessionId);
}

function validateRequesterSearchForExistingSessionPairLock({
  requestExists = false,
  requestData = {},
  userId = "",
  requestId = "",
  sessionId = "",
  expectedLanguage = "",
  nowMillis = Date.now(),
}) {
  if (!requestExists) {
    return {ok: false, reason: "requester_search_request_missing"};
  }
  if (!searchRequestBelongsToUser(requestData, userId)) {
    return {ok: false, reason: "requester_search_owner_mismatch"};
  }

  const rawRequestId = normalizeString(requestId);
  const normalizedRequestId = normalizeDocumentId(requestId);
  if (!rawRequestId) {
    return {ok: false, reason: "requester_search_request_id_required"};
  }
  if (!normalizedRequestId) {
    return {ok: false, reason: "requester_search_request_mismatch"};
  }
  if (
    normalizeString(requestData[SEARCH_REQUEST_FIELD.REQUEST_ID]) !==
      normalizedRequestId
  ) {
    return {ok: false, reason: "requester_search_request_mismatch"};
  }
  const normalizedExpectedLanguage = readLanguageCode(expectedLanguage);
  if (
    normalizedExpectedLanguage &&
    readLanguageCode(requestData[SEARCH_REQUEST_FIELD.LANGUAGE]) !==
      normalizedExpectedLanguage
  ) {
    return {ok: false, reason: "requester_search_language_mismatch"};
  }

  const sessionIds = [
    requestData.activeSessionId,
    requestData.currentSessionId,
    requestData.matchedSessionId,
  ].map(normalizeString).filter(Boolean);
  if (
    sessionIds.length > 0 &&
    !sessionIds.every((requestSessionId) => requestSessionId === sessionId)
  ) {
    return {ok: false, reason: "requester_search_in_other_session"};
  }

  const status = normalizeString(requestData[SEARCH_REQUEST_FIELD.STATUS]);
  if (
    ![
      SEARCH_REQUEST_STATUS.ACTIVE,
      SEARCH_REQUEST_STATUS.MATCHING,
      SEARCH_REQUEST_STATUS.LEGACY_SEARCHING,
    ].includes(status)
  ) {
    return {
      ok: false,
      reason: `requester_search_status_${status || "missing"}`,
    };
  }
  if (!isSearchRequestFreshForPairLock(requestData, nowMillis)) {
    return {ok: false, reason: "requester_search_stale"};
  }

  return {ok: true, reason: "ready"};
}

function validateRequesterUserForExistingSessionPairLock({
  userExists = false,
  userData = {},
  sessionId = "",
}) {
  if (!userExists) {
    return {ok: false, reason: "requester_user_missing"};
  }
  if (userData.isInCall === true) {
    return {ok: false, reason: "requester_in_call"};
  }

  const currentSessionId = normalizeString(userData.currentSessionId);
  if (currentSessionId && currentSessionId !== sessionId) {
    return {ok: false, reason: "requester_in_other_session"};
  }

  const normalizedUserRole = normalizeRole(userData.role);
  if (normalizedUserRole !== "student") {
    return {ok: false, reason: "requester_role_mismatch"};
  }

  return {ok: true, reason: "ready"};
}

function buildSearchRequestPairLockReleaseUpdate({
  status = SEARCH_REQUEST_STATUS.STOPPED,
  stopReason = "session_finished",
  serverTimestamp,
  fieldDelete,
}) {
  return {
    [SEARCH_REQUEST_FIELD.STATUS]: status,
    [SEARCH_REQUEST_FIELD.STOP_REASON]: stopReason,
    [SEARCH_REQUEST_FIELD.STOPPED_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.UPDATED_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.ACTIVE_SESSION_ID]: fieldDelete,
    [SEARCH_REQUEST_FIELD.CURRENT_SESSION_ID]: null,
    [SEARCH_REQUEST_FIELD.MATCHED_SESSION_ID]: fieldDelete,
    [SEARCH_REQUEST_FIELD.MATCHED_USER_ID]: null,
    [SEARCH_REQUEST_FIELD.MATCHED_RESPONDER_ID]: fieldDelete,
    [SEARCH_REQUEST_FIELD.MATCHED_ROLE]: null,
    [SEARCH_REQUEST_FIELD.PAIR_ATTEMPT_ID]: null,
    [SEARCH_REQUEST_FIELD.ATTEMPT_EXCLUDED_CANDIDATE_IDS]: [],
    [SEARCH_REQUEST_FIELD.LOCK_OWNER]: null,
    [SEARCH_REQUEST_FIELD.LOCK_EXPIRES_AT]: null,
    [SEARCH_REQUEST_FIELD.LAST_ERROR]: null,
    [SEARCH_REQUEST_FIELD.ERROR_CODE]: fieldDelete,
    [SEARCH_REQUEST_FIELD.ERROR_MESSAGE]: fieldDelete,
  };
}

function buildUserPairLockReleaseUpdate({
  serverTimestamp,
  fieldDelete,
  releaseCallState = false,
  restoreLegacyAvailability = false,
}) {
  const update = {
    currentSessionId: fieldDelete,
    updatedAt: serverTimestamp,
  };
  if (releaseCallState) {
    update.isInCall = false;
    update.availableAfter = fieldDelete;
    update.lastCallEndedAt = serverTimestamp;
  }
  if (restoreLegacyAvailability) {
    update.isAvailable = true;
  }
  return update;
}

async function readPairLockReleaseTargetsInTransaction({
  db,
  transaction,
  sessionId,
  sessionData = {},
  participantIds = [],
}) {
  const ids = Array.from(new Set([
    ...getSessionParticipantIds(sessionData),
    ...participantIds.map(normalizeDocumentId).filter(Boolean),
  ])).sort();
  const refs = ids.map((participantId) => ({
    participantId,
    userRef: db.collection(USER_COLLECTION).doc(participantId),
    searchRef: db.collection(SEARCH_REQUEST_COLLECTION).doc(participantId),
  }));
  const snapshots = await Promise.all(refs.map(async (target) => ({
    ...target,
    userSnap: await transaction.get(target.userRef),
    searchSnap: await transaction.get(target.searchRef),
  })));

  return snapshots.map((target) => ({
    ...target,
    userData: target.userSnap.exists ? target.userSnap.data() || {} : {},
    searchData: target.searchSnap.exists ?
      target.searchSnap.data() || {} :
      {},
    sessionId,
  }));
}

function applyPairLockReleaseWrites({
  transaction,
  targets = [],
  sessionId,
  serverTimestamp,
  fieldDelete,
  searchRequestStatus = SEARCH_REQUEST_STATUS.STOPPED,
  stopReason = "session_finished",
  releaseCallState = false,
  restoreLegacyAvailability = false,
}) {
  for (const target of targets) {
    if (
      target.userSnap.exists &&
      normalizeString(target.userData.currentSessionId) === sessionId
    ) {
      transaction.update(target.userRef, buildUserPairLockReleaseUpdate({
        serverTimestamp,
        fieldDelete,
        releaseCallState,
        restoreLegacyAvailability,
      }));
    }

    if (
      target.searchSnap.exists &&
      searchRequestMatchesSession(target.searchData, sessionId)
    ) {
      transaction.update(target.searchRef, buildSearchRequestPairLockReleaseUpdate({
        status: searchRequestStatus,
        stopReason,
        serverTimestamp,
        fieldDelete,
      }));
    }
  }
}

async function releaseSessionPairLocksInTransaction({
  db,
  transaction,
  sessionId,
  sessionData = {},
  participantIds = [],
  serverTimestamp,
  fieldDelete = admin.firestore.FieldValue.delete(),
  searchRequestStatus = SEARCH_REQUEST_STATUS.STOPPED,
  stopReason = "session_finished",
  releaseCallState = false,
  restoreLegacyAvailability = false,
}) {
  const normalizedSessionId = normalizeDocumentId(sessionId);
  if (!normalizedSessionId) {
    return {released: false, reason: "invalid_session_id"};
  }

  const targets = await readPairLockReleaseTargetsInTransaction({
    db,
    transaction,
    sessionId: normalizedSessionId,
    sessionData,
    participantIds,
  });
  applyPairLockReleaseWrites({
    transaction,
    targets,
    sessionId: normalizedSessionId,
    serverTimestamp,
    fieldDelete,
    searchRequestStatus,
    stopReason,
    releaseCallState,
    restoreLegacyAvailability,
  });
  return {
    released: true,
    reason: "released",
    participantIds: targets.map((target) => target.participantId),
  };
}

async function prepareExistingSessionNextResponderPairLockInTransaction({
  db,
  transaction,
  sessionId,
  sessionData = {},
  currentResponderId = "",
  responderId,
  responderRole,
  requesterSearchRequestId = "",
  responderSearchRequestId = "",
  expectedLanguage = "",
  triedTutors = [],
  nowMillis = Date.now(),
  serverTimestamp,
  lockExpiresAt,
  fieldDelete = admin.firestore.FieldValue.delete(),
  currentResponderSearchRequestStatus = SEARCH_REQUEST_STATUS.STOPPED,
  currentResponderStopReason = "responder_skipped",
  pairAttemptId = "",
}) {
  const normalizedSessionId = normalizeDocumentId(sessionId);
  const normalizedRequesterId = readSessionRequesterId(sessionData);
  const normalizedCurrentResponderId = normalizeDocumentId(currentResponderId);
  const normalizedResponderId = normalizeDocumentId(responderId);
  const normalizedResponderRole = normalizeRole(responderRole);
  const normalizedRequesterSearchRequestId =
    normalizeString(requesterSearchRequestId) ||
    readSessionSearchRequestId(sessionData, "requester");
  const normalizedExpectedLanguage =
    readLanguageCode(expectedLanguage) || readLanguageCode(sessionData.language);

  if (
    !normalizedSessionId ||
    !normalizedRequesterId ||
    !normalizedResponderId ||
    normalizedRequesterId === normalizedResponderId ||
    normalizedCurrentResponderId === normalizedResponderId ||
    !["student", "native_speaker"].includes(normalizedResponderRole)
  ) {
    return buildPairLockFailure("invalid_pair_lock_input");
  }
  if (normalizeString(pairAttemptId) && !normalizeDocumentId(pairAttemptId)) {
    return buildPairLockFailure("invalid_pair_lock_input");
  }

  const requesterUserRef = db
    .collection(USER_COLLECTION)
    .doc(normalizedRequesterId);
  const responderUserRef = db
    .collection(USER_COLLECTION)
    .doc(normalizedResponderId);
  const requesterSearchRef = db
    .collection(SEARCH_REQUEST_COLLECTION)
    .doc(normalizedRequesterId);
  const responderSearchRef = normalizedResponderRole === "student" ?
    db.collection(SEARCH_REQUEST_COLLECTION).doc(normalizedResponderId) :
    null;
  const currentResponderReleaseTargets = normalizedCurrentResponderId ?
    await readPairLockReleaseTargetsInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      sessionData: {},
      participantIds: [normalizedCurrentResponderId],
    }) :
    [];

  const [
    requesterUserSnapshot,
    responderUserSnapshot,
    requesterSearchSnapshot,
    responderSearchSnapshot,
  ] = await Promise.all([
    transaction.get(requesterUserRef),
    transaction.get(responderUserRef),
    transaction.get(requesterSearchRef),
    responderSearchRef ? transaction.get(responderSearchRef) : null,
  ]);

  const requesterUserData = requesterUserSnapshot.exists ?
    requesterUserSnapshot.data() || {} :
    {};
  const responderUserData = responderUserSnapshot.exists ?
    responderUserSnapshot.data() || {} :
    {};
  const requesterUserValidation =
    validateRequesterUserForExistingSessionPairLock({
      userExists: requesterUserSnapshot.exists,
      userData: requesterUserData,
      sessionId: normalizedSessionId,
    });
  if (!requesterUserValidation.ok) {
    return buildPairLockFailure(requesterUserValidation.reason);
  }

  const responderUserValidation = validateUserForPairLock({
    userExists: responderUserSnapshot.exists,
    userData: responderUserData,
    expectedRole: normalizedResponderRole,
    participantKey: "responder",
  });
  if (!responderUserValidation.ok) {
    return buildPairLockFailure(responderUserValidation.reason);
  }

  const requesterSearchValidation =
    validateRequesterSearchForExistingSessionPairLock({
      requestExists: requesterSearchSnapshot.exists,
      requestData: requesterSearchSnapshot.exists ?
        requesterSearchSnapshot.data() || {} :
        {},
      userId: normalizedRequesterId,
      requestId: normalizedRequesterSearchRequestId,
      sessionId: normalizedSessionId,
      expectedLanguage: normalizedExpectedLanguage,
      nowMillis,
    });
  if (!requesterSearchValidation.ok) {
    return buildPairLockFailure(requesterSearchValidation.reason);
  }

  let finalResponderSearchRequestId = "";
  if (responderSearchRef) {
    finalResponderSearchRequestId = normalizeString(
      responderSearchRequestId ||
        responderSearchSnapshot?.data()?.[SEARCH_REQUEST_FIELD.REQUEST_ID],
    );
    const responderSearchValidation = validateSearchRequestForPairLock({
      requestExists: responderSearchSnapshot.exists,
      requestData: responderSearchSnapshot.exists ?
        responderSearchSnapshot.data() || {} :
        {},
      userId: normalizedResponderId,
      requestId: finalResponderSearchRequestId,
      expectedLanguage: normalizedExpectedLanguage,
      requireRequestId: true,
      nowMillis,
      participantKey: "responder",
    });
    if (!responderSearchValidation.ok) {
      return buildPairLockFailure(responderSearchValidation.reason);
    }
  }

  const finalPairAttemptId = normalizeDocumentId(pairAttemptId) ||
    buildPairAttemptId({
      sessionId: normalizedSessionId,
      requesterId: normalizedRequesterId,
      responderId: normalizedResponderId,
    });
  const participantIds = buildParticipantIds(
    normalizedRequesterId,
    normalizedResponderId,
  );
  const participantInfos = {
    ...(sessionData.participantInfos || {}),
    [normalizedRequesterId]: buildParticipantInfo(requesterUserData),
    [normalizedResponderId]: buildParticipantInfo(responderUserData),
  };
  const participantRoles = {
    ...(sessionData.participantRoles || {}),
    [normalizedRequesterId]: "student",
    [normalizedResponderId]: normalizedResponderRole,
  };
  const scenario = normalizedResponderRole === "student" ?
    "student_student" :
    "student_teacher";
  const sessionUpdate = {
    status: "searching",
    pairStatus: "pending_confirmation",
    requesterId: normalizedRequesterId,
    requesterRole: "student",
    responderId: normalizedResponderId,
    responderRole: normalizedResponderRole,
    currentResponderId: normalizedResponderId,
    currentResponderRole: normalizedResponderRole,
    currentTutorId: normalizedResponderId,
    participantIds,
    participantRoles,
    participantInfos,
    tutorId: normalizedResponderRole === "native_speaker" ?
      normalizedResponderId :
      null,
    scenario,
    pairAttemptId: finalPairAttemptId,
    responseExpiresAt: lockExpiresAt,
    confirmationExpiresAt: lockExpiresAt,
    searchRequestIds: {
      requester: normalizedRequesterSearchRequestId,
      responder: finalResponderSearchRequestId || null,
    },
    triedTutors,
    updatedAt: serverTimestamp,
    matchLock: {
      owner: finalPairAttemptId,
      expiresAt: lockExpiresAt,
      participantIds,
    },
    "matchContext.selectedResponderId": normalizedResponderId,
    "matchContext.selectedResponderRole": normalizedResponderRole,
  };
  const requesterLockUpdate = buildSearchRequestPairLockUpdate({
    sessionId: normalizedSessionId,
    pairAttemptId: finalPairAttemptId,
    otherUserId: normalizedResponderId,
    otherRole: normalizedResponderRole,
    matchedResponderId: normalizedResponderId,
    serverTimestamp,
    lockExpiresAt,
  });
  const responderLockUpdate = responderSearchRef ?
    buildSearchRequestPairLockUpdate({
      sessionId: normalizedSessionId,
      pairAttemptId: finalPairAttemptId,
      otherUserId: normalizedRequesterId,
      otherRole: "student",
      matchedResponderId: normalizedResponderId,
      serverTimestamp,
      lockExpiresAt,
    }) :
    null;

  return {
    locked: true,
    reason: "locked",
    sessionId: normalizedSessionId,
    pairAttemptId: finalPairAttemptId,
    requesterId: normalizedRequesterId,
    responderId: normalizedResponderId,
    responderRole: normalizedResponderRole,
    writes: {
      sessionRef: db
        .collection(VIDEO_SESSION_COLLECTION)
        .doc(normalizedSessionId),
      sessionUpdate,
      requesterSearchRef,
      requesterLockUpdate,
      requesterUserRef,
      requesterUserUpdate: {
        currentSessionId: normalizedSessionId,
        updatedAt: serverTimestamp,
      },
      responderUserRef,
      responderUserUpdate: {
        currentSessionId: normalizedSessionId,
        updatedAt: serverTimestamp,
      },
      responderSearchRef,
      responderLockUpdate,
      currentResponderReleaseTargets,
      currentResponderReleaseOptions: {
        sessionId: normalizedSessionId,
        serverTimestamp,
        fieldDelete,
        searchRequestStatus: currentResponderSearchRequestStatus,
        stopReason: currentResponderStopReason,
        releaseCallState: false,
      },
    },
  };
}

function applyPreparedPairLockWrites(transaction, preparedLock) {
  if (!preparedLock?.locked || !preparedLock.writes) {
    return;
  }

  const writes = preparedLock.writes;
  applyPairLockReleaseWrites({
    transaction,
    targets: writes.currentResponderReleaseTargets,
    ...writes.currentResponderReleaseOptions,
  });
  transaction.update(writes.sessionRef, writes.sessionUpdate);
  transaction.update(writes.requesterSearchRef, writes.requesterLockUpdate);
  transaction.update(writes.requesterUserRef, writes.requesterUserUpdate);
  transaction.update(writes.responderUserRef, writes.responderUserUpdate);
  if (writes.responderSearchRef && writes.responderLockUpdate) {
    transaction.update(writes.responderSearchRef, writes.responderLockUpdate);
  }
}

async function reserveMatchPairInTransaction({
  db,
  transaction,
  requesterId,
  responderId,
  responderRole,
  requesterSearchRequestId = "",
  responderSearchRequestId = "",
  expectedLanguage = "",
  sessionRef,
  sessionData = {},
  nowMillis = Date.now(),
  serverTimestamp,
  lockExpiresAt,
  pairAttemptId = "",
}) {
  const normalizedRequesterId = normalizeDocumentId(requesterId);
  const normalizedResponderId = normalizeDocumentId(responderId);
  const normalizedResponderRole = normalizeRole(responderRole);
  const normalizedExpectedLanguage =
    readLanguageCode(expectedLanguage) || readLanguageCode(sessionData.language);

  if (
    !normalizedRequesterId ||
    !normalizedResponderId ||
    normalizedRequesterId === normalizedResponderId ||
    !["student", "native_speaker"].includes(normalizedResponderRole)
  ) {
    return buildPairLockFailure("invalid_pair_lock_input");
  }
  if (normalizeString(pairAttemptId) && !normalizeDocumentId(pairAttemptId)) {
    return buildPairLockFailure("invalid_pair_lock_input");
  }

  const requesterUserRef = db
    .collection(USER_COLLECTION)
    .doc(normalizedRequesterId);
  const responderUserRef = db
    .collection(USER_COLLECTION)
    .doc(normalizedResponderId);
  const requesterSearchRef = db
    .collection(SEARCH_REQUEST_COLLECTION)
    .doc(normalizedRequesterId);
  const responderSearchRef = normalizedResponderRole === "student" ?
    db.collection(SEARCH_REQUEST_COLLECTION).doc(normalizedResponderId) :
    null;

  const [
    sessionSnapshot,
    requesterUserSnapshot,
    responderUserSnapshot,
    requesterSearchSnapshot,
    responderSearchSnapshot,
  ] = await Promise.all([
    transaction.get(sessionRef),
    transaction.get(requesterUserRef),
    transaction.get(responderUserRef),
    transaction.get(requesterSearchRef),
    responderSearchRef ? transaction.get(responderSearchRef) : null,
  ]);

  if (sessionSnapshot.exists) {
    return buildPairLockFailure("session_already_exists");
  }

  const requesterUserData = requesterUserSnapshot.exists ?
    requesterUserSnapshot.data() || {} :
    {};
  const responderUserData = responderUserSnapshot.exists ?
    responderUserSnapshot.data() || {} :
    {};
  const requesterUserValidation = validateUserForPairLock({
    userExists: requesterUserSnapshot.exists,
    userData: requesterUserData,
    expectedRole: "student",
    participantKey: "requester",
  });
  if (!requesterUserValidation.ok) {
    return buildPairLockFailure(requesterUserValidation.reason);
  }

  const responderUserValidation = validateUserForPairLock({
    userExists: responderUserSnapshot.exists,
    userData: responderUserData,
    expectedRole: normalizedResponderRole,
    participantKey: "responder",
  });
  if (!responderUserValidation.ok) {
    return buildPairLockFailure(responderUserValidation.reason);
  }

  const requesterSearchValidation = validateSearchRequestForPairLock({
    requestExists: requesterSearchSnapshot.exists,
    requestData: requesterSearchSnapshot.exists ?
      requesterSearchSnapshot.data() || {} :
      {},
    userId: normalizedRequesterId,
    requestId: requesterSearchRequestId,
    expectedLanguage: normalizedExpectedLanguage,
    requireRequestId: true,
    nowMillis,
    participantKey: "requester",
  });
  if (!requesterSearchValidation.ok) {
    return buildPairLockFailure(requesterSearchValidation.reason);
  }

  if (responderSearchRef) {
    const responderSearchValidation = validateSearchRequestForPairLock({
      requestExists: responderSearchSnapshot.exists,
      requestData: responderSearchSnapshot.exists ?
        responderSearchSnapshot.data() || {} :
        {},
      userId: normalizedResponderId,
      requestId: responderSearchRequestId,
      expectedLanguage: normalizedExpectedLanguage,
      requireRequestId: true,
      nowMillis,
      participantKey: "responder",
    });
    if (!responderSearchValidation.ok) {
      return buildPairLockFailure(responderSearchValidation.reason);
    }
  }

  const sessionId = sessionRef.id;
  const finalPairAttemptId = normalizeDocumentId(pairAttemptId) ||
    buildPairAttemptId({
      sessionId,
      requesterId: normalizedRequesterId,
      responderId: normalizedResponderId,
    });
  const sessionLockData = buildVideoSessionPairLockData({
    sessionData,
    requesterId: normalizedRequesterId,
    responderId: normalizedResponderId,
    requesterRole: "student",
    responderRole: normalizedResponderRole,
    sessionId,
    pairAttemptId: finalPairAttemptId,
    requesterSearchRequestId: normalizeString(
      requesterSearchRequestId ||
        requesterSearchSnapshot.data()?.[SEARCH_REQUEST_FIELD.REQUEST_ID],
    ),
    responderSearchRequestId: responderSearchSnapshot ?
      normalizeString(
        responderSearchRequestId ||
          responderSearchSnapshot.data()?.[SEARCH_REQUEST_FIELD.REQUEST_ID],
      ) :
      "",
    participantInfos: {
      [normalizedRequesterId]: buildParticipantInfo(requesterUserData),
      [normalizedResponderId]: buildParticipantInfo(responderUserData),
    },
    serverTimestamp,
    lockExpiresAt,
  });
  const requesterLockUpdate = buildSearchRequestPairLockUpdate({
    sessionId,
    pairAttemptId: finalPairAttemptId,
    otherUserId: normalizedResponderId,
    otherRole: normalizedResponderRole,
    matchedResponderId: normalizedResponderId,
    serverTimestamp,
    lockExpiresAt,
  });

  transaction.create(sessionRef, sessionLockData);
  transaction.update(requesterSearchRef, requesterLockUpdate);
  transaction.update(requesterUserRef, {
    currentSessionId: sessionId,
    updatedAt: serverTimestamp,
  });
  transaction.update(responderUserRef, {
    currentSessionId: sessionId,
    updatedAt: serverTimestamp,
  });

  if (responderSearchRef) {
    transaction.update(responderSearchRef, buildSearchRequestPairLockUpdate({
      sessionId,
      pairAttemptId: finalPairAttemptId,
      otherUserId: normalizedRequesterId,
      otherRole: "student",
      matchedResponderId: normalizedResponderId,
      serverTimestamp,
      lockExpiresAt,
    }));
  }

  return {
    locked: true,
    reason: "locked",
    sessionId,
    pairAttemptId: finalPairAttemptId,
    requesterId: normalizedRequesterId,
    responderId: normalizedResponderId,
    responderRole: normalizedResponderRole,
  };
}

async function reserveDirectPairInTransaction({
  db,
  transaction,
  requesterId,
  responderId,
  responderRole,
  sessionRef,
  sessionData = {},
  nowMillis = Date.now(),
  serverTimestamp,
  lockExpiresAt,
  pairAttemptId = "",
}) {
  const normalizedRequesterId = normalizeDocumentId(requesterId);
  const normalizedResponderId = normalizeDocumentId(responderId);
  const normalizedResponderRole = normalizeRole(responderRole);

  if (
    !normalizedRequesterId ||
    !normalizedResponderId ||
    normalizedRequesterId === normalizedResponderId ||
    !["student", "native_speaker"].includes(normalizedResponderRole)
  ) {
    return buildPairLockFailure("invalid_pair_lock_input");
  }
  if (normalizeString(pairAttemptId) && !normalizeDocumentId(pairAttemptId)) {
    return buildPairLockFailure("invalid_pair_lock_input");
  }

  const requesterUserRef = db
    .collection(USER_COLLECTION)
    .doc(normalizedRequesterId);
  const responderUserRef = db
    .collection(USER_COLLECTION)
    .doc(normalizedResponderId);
  const [
    sessionSnapshot,
    requesterUserSnapshot,
    responderUserSnapshot,
  ] = await Promise.all([
    transaction.get(sessionRef),
    transaction.get(requesterUserRef),
    transaction.get(responderUserRef),
  ]);

  if (sessionSnapshot.exists) {
    return buildPairLockFailure("session_already_exists");
  }

  const requesterUserData = requesterUserSnapshot.exists ?
    requesterUserSnapshot.data() || {} :
    {};
  const responderUserData = responderUserSnapshot.exists ?
    responderUserSnapshot.data() || {} :
    {};
  const requesterUserValidation = validateUserForPairLock({
    userExists: requesterUserSnapshot.exists,
    userData: requesterUserData,
    expectedRole: "student",
    participantKey: "requester",
  });
  if (!requesterUserValidation.ok) {
    return buildPairLockFailure(requesterUserValidation.reason);
  }

  const responderUserValidation = validateUserForPairLock({
    userExists: responderUserSnapshot.exists,
    userData: responderUserData,
    expectedRole: normalizedResponderRole,
    participantKey: "responder",
  });
  if (!responderUserValidation.ok) {
    return buildPairLockFailure(responderUserValidation.reason);
  }

  const sessionId = sessionRef.id;
  const finalPairAttemptId = normalizeDocumentId(pairAttemptId) ||
    buildPairAttemptId({
      sessionId,
      requesterId: normalizedRequesterId,
      responderId: normalizedResponderId,
    });
  const sessionLockData = buildVideoSessionPairLockData({
    sessionData,
    requesterId: normalizedRequesterId,
    responderId: normalizedResponderId,
    requesterRole: "student",
    responderRole: normalizedResponderRole,
    sessionId,
    pairAttemptId: finalPairAttemptId,
    participantInfos: {
      [normalizedRequesterId]: buildParticipantInfo(requesterUserData),
      [normalizedResponderId]: buildParticipantInfo(responderUserData),
    },
    serverTimestamp,
    lockExpiresAt,
  });

  transaction.create(sessionRef, sessionLockData);
  transaction.update(requesterUserRef, {
    currentSessionId: sessionId,
    updatedAt: serverTimestamp,
  });
  transaction.update(responderUserRef, {
    currentSessionId: sessionId,
    updatedAt: serverTimestamp,
  });

  return {
    locked: true,
    reason: "locked",
    sessionId,
    pairAttemptId: finalPairAttemptId,
    requesterId: normalizedRequesterId,
    responderId: normalizedResponderId,
    responderRole: normalizedResponderRole,
  };
}

async function reserveMatchPair({
  db = admin.firestore(),
  requesterId,
  responderId,
  responderRole,
  requesterSearchRequestId = "",
  responderSearchRequestId = "",
  expectedLanguage = "",
  sessionId = "",
  pairAttemptId = "",
  sessionData = {},
  nowMillis = Date.now(),
  lockTtlSeconds = MATCH_PAIR_LOCK_TTL_SECONDS,
  serverTimestamp = admin.firestore.FieldValue.serverTimestamp(),
  timestampFromMillis = admin.firestore.Timestamp.fromMillis,
}) {
  const rawSessionId = normalizeString(sessionId);
  const normalizedSessionId = normalizeDocumentId(sessionId);
  if (rawSessionId && !normalizedSessionId) {
    return buildPairLockFailure("invalid_pair_lock_input");
  }

  const sessionRef = db
    .collection(VIDEO_SESSION_COLLECTION)
    .doc(normalizedSessionId || undefined);
  const lockExpiresAt = timestampFromMillis(
    nowMillis + lockTtlSeconds * 1000,
  );

  return db.runTransaction((transaction) => reserveMatchPairInTransaction({
    db,
    transaction,
    requesterId,
    responderId,
    responderRole,
    requesterSearchRequestId,
    responderSearchRequestId,
    expectedLanguage,
    sessionRef,
    sessionData,
    nowMillis,
    serverTimestamp,
    lockExpiresAt,
    pairAttemptId,
  }));
}

module.exports = {
  MATCH_PAIR_LOCK_TTL_SECONDS,
  applyPreparedPairLockWrites,
  buildPairAttemptId,
  buildSearchRequestPairLockUpdate,
  buildVideoSessionPairLockData,
  hasLiveSearchRequestLock,
  isSearchRequestFreshForPairLock,
  prepareExistingSessionNextResponderPairLockInTransaction,
  releaseSessionPairLocksInTransaction,
  reserveDirectPairInTransaction,
  reserveMatchPair,
  reserveMatchPairInTransaction,
  validateSearchRequestForPairLock,
  validateUserForPairLock,
};
