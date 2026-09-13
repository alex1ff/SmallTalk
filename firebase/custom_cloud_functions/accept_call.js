const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { sendApnsVoip } = require("./apns_voip");
const { getUserVoipTokens } = require("./voip_tokens");
const {
  ACCEPT_LOCK_WINDOW_MS,
  assertAcceptAttemptCanFinalizeOrThrow,
  assertAcceptLockOwnedByAttemptOrThrow,
  assertAcceptLockOwnedByResponderOrThrow,
} = require("./accept_lock_policy");
const {
  createDailyRoom,
  createMeetingToken,
  DAILY_ROOM_CONFIG_VERSION,
  deleteDailyRoom,
  getDailyRoom,
  getRoomNameFromUrl,
  isDailyRoomConfigCompatible,
} = require("./daily_room");
const { evaluateTutorAvailabilityWindow } = require("./availability");
const {
  buildAcceptedSessionPolicyState,
  buildSessionUserInfo,
  getCredentialTtlSeconds,
  getRequesterId,
  isApprovedTeacher,
  isCredentialSessionJoinable,
  isSupportedSessionRole,
  normalizeRole,
  readLanguageCode,
  supportsConversationLanguage,
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  buildCallKitIdForSession,
} = require("./call_notifications");
const {
  logCallLifecycleError,
  logCallLifecycleEvent,
} = require("./call_lifecycle_logs");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "accept_call"});
const {
  MATCH_PROTOCOL_VERSION,
  MATCH_STAGE,
  allParticipantsReadyForFinalization,
} = require("./match_protocol_v2");
const {
  CALLKIT_RESPONSE_WINDOW_MS,
  buildCallKitLifecycleEscalation,
  findInAppParticipantsNeedingCallKitEscalation,
} = require("./match_delivery_v2");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const PRECREATED_ROOM_VALIDATION_WINDOW_MS = 60 * 1000;
const ROOM_JOIN_TIMEOUT_MS = 60 * 1000;
const ACCEPTABLE_PENDING_SESSION_STATUSES = new Set([
  VIDEO_SESSION_STATUS.SEARCHING,
  VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
]);
const ACCEPTED_SESSION_STATUSES = new Set([
  VIDEO_SESSION_STATUS.CONNECTING,
  VIDEO_SESSION_STATUS.ACTIVE,
]);

function buildAcceptCallPolicyUpdateFields(
  sessionData = {},
  nowMillis = Date.now(),
) {
  const policyState = buildAcceptedSessionPolicyState(sessionData, nowMillis);
  const sessionUpdateFields = {
    expiresAt: admin.firestore.Timestamp.fromDate(policyState.expiresAt),
  };
  if (policyState.sessionPolicy) {
    sessionUpdateFields.sessionPolicy = policyState.sessionPolicy;
  }
  return {
    policyState,
    sessionUpdateFields,
  };
}

function buildAcceptedRoomJoinTimeoutFields({
  nowMillis = Date.now(),
  serverTimestamp,
} = {}) {
  const normalizedNowMillis = Number.isFinite(Number(nowMillis)) ?
    Number(nowMillis) :
    Date.now();
  const startedAt =
    serverTimestamp || admin.firestore.Timestamp.fromMillis(normalizedNowMillis);
  return {
    joinDeadlineAt: admin.firestore.Timestamp.fromMillis(
      normalizedNowMillis + ROOM_JOIN_TIMEOUT_MS,
    ),
    "sessionMetadata.joinTimeoutStartedAt": startedAt,
    "sessionMetadata.joinTimeoutMs": ROOM_JOIN_TIMEOUT_MS,
  };
}

function buildAcceptCallResponseSessionData(sessionData = {}) {
  return {
    language: sessionData.language,
    startedAt:
      sessionData.startedAt?.toMillis?.() ||
      sessionData.startedAt ||
      null,
    maxDuration:
      buildAcceptedSessionPolicyState(sessionData).maxDurationMs,
  };
}

function buildAcceptedParticipantUserUpdate({
  sessionId,
  serverTimestamp = admin.firestore.FieldValue.serverTimestamp(),
}) {
  return {
    isInCall: true,
    currentSessionId: sessionId,
    updatedAt: serverTimestamp,
  };
}

function normalizeSessionId(value) {
  return typeof value === "string" ? value.trim() : "";
}

function assertUserCanJoinAcceptedSessionOrThrow(
  userData = {},
  userId = "",
  sessionId = "",
) {
  const normalizedSessionId = normalizeSessionId(sessionId);
  const currentSessionId = normalizeSessionId(userData.currentSessionId);
  if (currentSessionId && currentSessionId !== normalizedSessionId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      `User ${userId} is assigned to another session`,
    );
  }
  if (userData.isInCall === true && currentSessionId !== normalizedSessionId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      `User ${userId} is already in a call`,
    );
  }
}

function assertUserIsInAcceptedSessionOrThrow(
  userData = {},
  userId = "",
  sessionId = "",
) {
  const normalizedSessionId = normalizeSessionId(sessionId);
  const currentSessionId = normalizeSessionId(userData.currentSessionId);
  if (currentSessionId !== normalizedSessionId || userData.isInCall !== true) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      `User ${userId} is not in the accepted session`,
    );
  }
}

function assertAcceptedSessionStillCurrentOrThrow({
  sessionData = {},
  requesterData = {},
  responderData = {},
  requesterId = "",
  responderId = "",
  sessionId = "",
} = {}) {
  const normalizedResponderId = normalizeSessionId(responderId);
  const acceptedResponderId = normalizeSessionId(
    sessionData.tutorId ||
      sessionData.matchContext?.acceptedResponderId,
  );
  if (
    !ACCEPTED_SESSION_STATUSES.has(sessionData.status) ||
    acceptedResponderId !== normalizedResponderId ||
    !sessionData.dailyRoomUrl
  ) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Accepted session changed before response",
    );
  }
  assertUserIsInAcceptedSessionOrThrow(requesterData, requesterId, sessionId);
  assertUserIsInAcceptedSessionOrThrow(responderData, responderId, sessionId);
}

async function readAcceptedSessionStillCurrentOrThrow({
  db,
  sessionRef,
  sessionId,
  requesterId,
  responderId,
}) {
  const usersCollection = db.collection("users");
  const [sessionSnap, requesterSnap, responderSnap] = await Promise.all([
    sessionRef.get(),
    usersCollection.doc(requesterId).get(),
    usersCollection.doc(responderId).get(),
  ]);
  if (!sessionSnap.exists || !requesterSnap.exists || !responderSnap.exists) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Accepted session validation failed",
    );
  }
  const sessionData = sessionSnap.data() || {};
  assertAcceptedSessionStillCurrentOrThrow({
    sessionData,
    requesterData: requesterSnap.data() || {},
    responderData: responderSnap.data() || {},
    requesterId,
    responderId,
    sessionId,
  });
  return sessionData;
}

function getDailyCredentialTtlOrThrow(sessionData = {}) {
  if (!isCredentialSessionJoinable(sessionData)) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      `Session is not joinable (status: ${sessionData.status || "unknown"})`,
    );
  }
  const credentialTtlSeconds = getCredentialTtlSeconds(sessionData, 60 * 60);
  if (credentialTtlSeconds < 1) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Session credential window has expired",
    );
  }
  return credentialTtlSeconds;
}

function timestampToMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : null;
  }
  if (typeof value.toDate === "function") {
    const millis = value.toDate().getTime();
    return Number.isFinite(millis) ? millis : null;
  }
  if (value instanceof Date) {
    const millis = value.getTime();
    return Number.isFinite(millis) ? millis : null;
  }
  const millis = Number(value);
  return Number.isFinite(millis) ? millis : null;
}

function assertAcceptWindowOpenOrThrow(sessionData = {}, nowMillis = Date.now()) {
  const responseDeadlineMillis = timestampToMillis(
    sessionData.responseExpiresAt || sessionData.confirmationExpiresAt,
  );
  if (responseDeadlineMillis !== null && responseDeadlineMillis <= nowMillis) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Session response window has expired",
    );
  }

  const sessionExpiresAtMillis = timestampToMillis(sessionData.expiresAt);
  if (sessionExpiresAtMillis !== null && sessionExpiresAtMillis <= nowMillis) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Session has expired",
    );
  }
}

function validateResponderLanguageOrThrow(
  tutorId,
  tutorData = {},
  sessionData = {},
) {
  const sessionLanguage = readLanguageCode(sessionData.language);
  if (
    !sessionLanguage ||
    !supportsConversationLanguage(tutorData, sessionLanguage)
  ) {
    safeLog.warn("responder_language_mismatch", {
      tutorId,
      requestedLanguage: sessionData.language || "unknown",
    });
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Responder cannot accept this language",
    );
  }
}

function getPendingAssignedResponderId(sessionData = {}) {
  return normalizeSessionId(
    normalizeSessionId(sessionData.currentResponderId) ||
      normalizeSessionId(sessionData.currentTutorId),
  ) || null;
}

function isPendingSessionAssignedToResponder(
  sessionData = {},
  responderId = "",
) {
  return getPendingAssignedResponderId(sessionData) ===
    normalizeSessionId(responderId);
}

function shouldIssueAcceptResponseMeetingToken(internalOptions = {}) {
  return internalOptions.protocolV2Finalization !== true;
}

async function acceptCallCallable(data, context, internalOptions = {}) {
    safeLog.log("accept_handler_started");

    let tutorId = null;
    let sessionRef = null;
    let sessionId = null;
    let acceptAttemptId = null;
    let lockAcquired = false;
    let transientDailyRoomName = null;
    try {
      // === 1. АУТЕНТИФИКАЦИЯ И ВАЛИДАЦИЯ ===
      if (!context.auth) {
        safeLog.warn("accept_unauthenticated");
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated",
        );
      }

      tutorId = normalizeSessionId(internalOptions.responderId) ||
        context.auth.uid;
      ({ sessionId } = data || {});

      safeLog.log("accept_attempt", {
        sessionId,
        responderId: tutorId,
      });
      logCallLifecycleEvent({
        event: "accept_attempt",
        source: "acceptCall",
        sessionId,
        responderId: tutorId,
      });

      if (!sessionId) {
        safeLog.warn("accept_session_id_missing");
        throw new functions.https.HttpsError(
          "invalid-argument",
          "sessionId is required",
        );
      }

      sessionRef = admin
        .firestore()
        .collection("videoSessions")
        .doc(sessionId);
      acceptAttemptId = admin
        .firestore()
        .collection("acceptAttempts")
        .doc().id;
      const acceptLockWindowMs = ACCEPT_LOCK_WINDOW_MS;
      const initialSessionState = await admin
        .firestore()
        .runTransaction(async (transaction) => {
        const freshSnap = await transaction.get(sessionRef);
        if (!freshSnap.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "Video session not found",
          );
        }
        const fresh = freshSnap.data() || {};
        const nowMs = Date.now();
        const isProtocolV2 =
          Number(fresh.matchProtocolVersion) >= MATCH_PROTOCOL_VERSION;
        if (isProtocolV2) {
          const expectedPairAttemptId = normalizeSessionId(
            fresh.pairAttemptId,
          );
          const suppliedPairAttemptId = normalizeSessionId(
            data?.pairAttemptId,
          );
          if (
            !suppliedPairAttemptId ||
            suppliedPairAttemptId !== expectedPairAttemptId
          ) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "Protocol v2 acceptance requires the current pairAttemptId",
            );
          }
          if (!allParticipantsReadyForFinalization(
            fresh.participantStates || {},
            fresh.participantIds || [],
          )) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "All participants must accept before finalization",
            );
          }
        }
        if (ACCEPTED_SESSION_STATUSES.has(fresh.status)) {
          if (fresh.tutorId === tutorId && fresh.dailyRoomUrl) {
            return {
              alreadyAccepted: true,
              session: fresh,
            };
          }
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Session is already active",
          );
        }
        if (!ACCEPTABLE_PENDING_SESSION_STATUSES.has(fresh.status)) {
          throw new functions.https.HttpsError(
            "invalid-argument",
            "Session is not available for acceptance",
          );
        }
        if (!isPendingSessionAssignedToResponder(fresh, tutorId)) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "This session is not assigned to you",
          );
        }
        if (!(isProtocolV2 &&
          internalOptions.protocolV2Finalization === true)) {
          assertAcceptWindowOpenOrThrow(fresh, nowMs);
        }
        if (isProtocolV2) {
          const searchEntries = await Promise.all((fresh.participantIds || [])
            .map(normalizeSessionId)
            .filter(Boolean)
            .map(async (participantId) => {
              const snapshot = await transaction.get(admin.firestore()
                .collection("searchRequests")
                .doc(participantId));
              return [
                participantId,
                snapshot.exists ? snapshot.data() || {} : {},
              ];
            }));
          const escalationParticipantIds =
            findInAppParticipantsNeedingCallKitEscalation({
              sessionData: {
                ...fresh,
                sessionId,
              },
              searchDataByParticipantId: Object.fromEntries(searchEntries),
              nowMillis: nowMs,
            });
          if (escalationParticipantIds.length > 0) {
            const responseExpiresAt = admin.firestore.Timestamp.fromMillis(
              nowMs + CALLKIT_RESPONSE_WINDOW_MS,
            );
            const participantStates = buildCallKitLifecycleEscalation({
              sessionData: {...fresh, sessionId},
              participantIds: escalationParticipantIds,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            transaction.update(sessionRef, {
              participantStates,
              responseExpiresAt,
              confirmationExpiresAt: responseExpiresAt,
              "matchLock.expiresAt": responseExpiresAt,
              matchStage: MATCH_STAGE.AWAITING_INITIAL_DISPATCH,
              lifecycleEscalation: {
                revision:
                  Math.max(
                    0,
                    Number(fresh.lifecycleEscalation?.revision) || 0,
                  ) + 1,
                participantIds: escalationParticipantIds,
                requestedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            return {
              alreadyAccepted: false,
              finalizationDeferred: true,
              session: {...fresh, participantStates},
            };
          }
        }
        const acceptingTutorId = fresh.acceptingTutorId || null;
        const acceptingAtMs = timestampToMillis(fresh.acceptingAt);
        const acceptingAt = admin.firestore.Timestamp.fromMillis(nowMs);
        const isActiveAcceptLock =
          acceptingTutorId &&
          acceptingAtMs !== null &&
          nowMs - acceptingAtMs <= acceptLockWindowMs;
        if (!isActiveAcceptLock) {
          transaction.update(sessionRef, {
            acceptingTutorId: tutorId,
            acceptingAt,
            acceptAttemptId,
          });
          lockAcquired = true;
          return {
            alreadyAccepted: false,
            session: fresh,
          };
        }
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Session is already being accepted",
        );
      });

      if (initialSessionState.finalizationDeferred) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Participant lifecycle requires CallKit confirmation",
          {reason: "lifecycle_escalation_pending"},
        );
      }

      const sessionData = initialSessionState.session || {};
      safeLog.log("session_loaded", {
        sessionId,
        status: sessionData.status,
        responderId:
          sessionData.currentResponderId || sessionData.currentTutorId,
        studentId: sessionData.studentId,
        language: sessionData.language,
      });

      const requesterId = getRequesterId(sessionData);
      if (!requesterId) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Session requester is missing",
        );
      }

      const usersCollection = admin.firestore().collection("users");
      const [tutorDoc, studentDoc] = await Promise.all([
        usersCollection.doc(tutorId).get(),
        initialSessionState.alreadyAccepted ?
          Promise.resolve(null) :
          usersCollection.doc(requesterId).get(),
      ]);
      if (!tutorDoc.exists) {
        safeLog.warn("tutor_not_found", {tutorId});
        throw new functions.https.HttpsError("not-found", "Tutor not found");
      }
      const tutorData = tutorDoc.data();
      validateResponderLanguageOrThrow(tutorId, tutorData, sessionData);

      if (initialSessionState.alreadyAccepted) {
        safeLog.log("session_already_active", {sessionId, responderId: tutorId});
        let existingRoomName =
          sessionData.dailyRoomName || getRoomNameFromUrl(sessionData.dailyRoomUrl);
        let existingMeetingToken = null;
        if (
          existingRoomName &&
          shouldIssueAcceptResponseMeetingToken(internalOptions)
        ) {
          const existingCredentialTtlSeconds =
            getDailyCredentialTtlOrThrow(sessionData);
          try {
            existingMeetingToken = await createMeetingToken({
              roomName: existingRoomName,
              expSeconds: existingCredentialTtlSeconds,
              isOwner: false,
              userId: tutorId,
              userName:
                sessionData.tutorInfo?.name ||
                sessionData.tutorName ||
                tutorData.display_name ||
                "Partner",
            });
          } catch (tokenError) {
            safeLog.error("meeting_token_create_failed", {
              sessionId,
              responderId: tutorId,
              error: tokenError,
            });
          }
        }
        await readAcceptedSessionStillCurrentOrThrow({
          db: admin.firestore(),
          sessionRef,
          sessionId,
          requesterId,
          responderId: tutorId,
        });
        logCallLifecycleEvent({
          event: "accept_idempotent_existing",
          source: "acceptCall",
          sessionId,
          requesterId,
          responderId: tutorId,
          statusBefore: sessionData.status,
          statusAfter: sessionData.status,
          result: "connected",
        });

        return {
          status: "connected",
          sessionId: sessionId,
          roomUrl: sessionData.dailyRoomUrl,
          roomName: existingRoomName || null,
          meetingToken: existingMeetingToken || null,
          studentInfo: sessionData.studentInfo || null,
          sessionData: buildAcceptCallResponseSessionData(sessionData),
        };
      }

      if (!isSupportedSessionRole(tutorData.role)) {
        safeLog.warn("responder_role_invalid", {
          responderId: tutorId,
          role: tutorData.role,
        });
        throw new functions.https.HttpsError(
          "permission-denied",
          "This user role cannot accept calls",
        );
      }

      const tutorRole = normalizeRole(tutorData.role);
      const availabilityCheck = tutorRole === "native_speaker" ?
        evaluateTutorAvailabilityWindow(tutorData) :
        {
          isAvailable: true,
          reason: "active_search_responder",
          localTime: null,
          timezoneOffsetMinutes: null,
        };
      const isAvailable = availabilityCheck.isAvailable;

      safeLog.log("tutor_availability_checked", {
        tutorId,
        role: tutorData.role,
        isAvailable,
        availabilityReason: availabilityCheck.reason,
        reasonCode: availabilityCheck.reason,
      });

      if (tutorRole === "native_speaker" && !isApprovedTeacher(tutorData)) {
        safeLog.warn("tutor_approval_pending", {tutorId});
        throw new functions.https.HttpsError(
          "permission-denied",
          "Teacher verification is pending",
        );
      }

      if (!isAvailable) {
        safeLog.warn("responder_unavailable", {responderId: tutorId});
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Tutor is not available",
        );
      }

      if (tutorData.isInCall) {
        safeLog.warn("responder_already_in_call", {responderId: tutorId});
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Tutor is already in a call",
        );
      }

      if (!studentDoc || !studentDoc.exists) {
        safeLog.warn("requester_not_found", {requesterId});
        throw new functions.https.HttpsError("not-found", "Requester not found");
      }

      const studentData = studentDoc.data();
      safeLog.log("requester_loaded", {requesterId, role: studentData.role});

      // === 5. ПОЛУЧЕНИЕ ИЛИ СОЗДАНИЕ КОМНАТЫ DAILY.CO ===
      safeLog.log("daily_room_resolve_started", {sessionId});
      const activePolicyUpdate =
        buildAcceptCallPolicyUpdateFields(sessionData);
      const acceptedSessionRoomData = {
        status: VIDEO_SESSION_STATUS.ACTIVE,
        expiresAt: activePolicyUpdate.sessionUpdateFields.expiresAt,
      };
      const readAcceptedRoomTtlSeconds = () =>
        getDailyCredentialTtlOrThrow(acceptedSessionRoomData);

      let roomUrl = sessionData.dailyRoomUrl || null;
      let roomName =
        sessionData.dailyRoomName || getRoomNameFromUrl(sessionData.dailyRoomUrl);
      if (roomUrl) {
        const derivedName = getRoomNameFromUrl(roomUrl);
        if (derivedName) {
          if (!roomName || roomName !== derivedName) {
            safeLog.warn("room_name_mismatch", {sessionId});
            roomName = derivedName;
          }
        }
      }
      let meetingToken = null;
      let roomCreatedAt = sessionData.sessionMetadata?.roomCreatedAt || null;

      if (roomUrl) {
        safeLog.log("using_precreated_room", {
          sessionId,
          hasToken: !!meetingToken,
        });
        if (!roomName) {
          roomName = getRoomNameFromUrl(roomUrl);
        }
        if (roomName) {
          const roomAgeMs = roomCreatedAt ? Date.now() - roomCreatedAt : Infinity;
          const hasCurrentRoomConfig =
            sessionData.sessionMetadata?.dailyRoomConfigVersion ===
            DAILY_ROOM_CONFIG_VERSION;
          if (!hasCurrentRoomConfig ||
              roomAgeMs > PRECREATED_ROOM_VALIDATION_WINDOW_MS) {
            const existingRoom = await getDailyRoom(roomName);
            if (!existingRoom || !isDailyRoomConfigCompatible(existingRoom)) {
              safeLog.warn("daily_room_recreate_required", {sessionId});
              roomUrl = null;
              roomName = null;
              roomCreatedAt = null;
            }
          } else {
            safeLog.log("daily_room_validation_skipped", {sessionId});
          }
        } else {
          roomUrl = null;
          roomCreatedAt = null;
        }
      }

      if (!roomUrl) {
        const roomExpSeconds = readAcceptedRoomTtlSeconds();
        try {
          const studentName =
            sessionData.studentInfo?.name ||
            studentData.display_name ||
            "Caller";
          const dailyRoom = await createDailyRoom({
            language: sessionData.language,
            studentId: requesterId,
            tutorId,
            studentName,
            tutorName: tutorData.display_name || "Partner",
            expSeconds: roomExpSeconds,
          });
          roomUrl = dailyRoom.url;
          roomName = dailyRoom.name;
          transientDailyRoomName = dailyRoom.name;
          roomCreatedAt = Date.now();
        } catch (roomError) {
          safeLog.error("daily_room_create_failed", {sessionId, error: roomError});
          throw new functions.https.HttpsError(
            "internal",
            "Failed to create video room",
          );
        }
      }

      // === 6. ОБНОВЛЕНИЕ СЕССИИ В ТРАНЗАКЦИИ ===
      safeLog.log("accept_transaction_started", {sessionId});
      const txnResult = await admin
        .firestore()
        .runTransaction(async (transaction) => {
          const freshSnap = await transaction.get(sessionRef);
          if (!freshSnap.exists) {
            throw new functions.https.HttpsError(
              "not-found",
              "Video session not found",
            );
          }
          const fresh = freshSnap.data();
          if (
            !ACCEPTABLE_PENDING_SESSION_STATUSES.has(fresh.status) ||
            !isPendingSessionAssignedToResponder(fresh, tutorId)
          ) {
            if (
              ACCEPTED_SESSION_STATUSES.has(fresh.status) &&
              fresh.tutorId === tutorId &&
              fresh.dailyRoomUrl
            ) {
              return { alreadyAccepted: true, session: fresh };
            }
            throw new functions.https.HttpsError(
              "invalid-argument",
              "Session is already active",
            );
          }
          assertAcceptAttemptCanFinalizeOrThrow({
            sessionData: fresh,
            responderId: tutorId,
            acceptAttemptId,
            skipResponseDeadline:
              Number(fresh.matchProtocolVersion) >= MATCH_PROTOCOL_VERSION &&
              internalOptions.protocolV2Finalization === true,
          });
          if (Number(fresh.matchProtocolVersion) >= MATCH_PROTOCOL_VERSION) {
            if (!allParticipantsReadyForFinalization(
              fresh.participantStates || {},
              fresh.participantIds || [],
            )) {
              throw new functions.https.HttpsError(
                "failed-precondition",
                "All participants must accept before finalization",
              );
            }
            const nowMs = Date.now();
            const searchEntries = await Promise.all((fresh.participantIds || [])
              .map(normalizeSessionId)
              .filter(Boolean)
              .map(async (participantId) => {
                const snapshot = await transaction.get(admin.firestore()
                  .collection("searchRequests")
                  .doc(participantId));
                return [
                  participantId,
                  snapshot.exists ? snapshot.data() || {} : {},
                ];
              }));
            const escalationParticipantIds =
              findInAppParticipantsNeedingCallKitEscalation({
                sessionData: {...fresh, sessionId},
                searchDataByParticipantId: Object.fromEntries(searchEntries),
                nowMillis: nowMs,
              });
            if (escalationParticipantIds.length > 0) {
              const responseExpiresAt = admin.firestore.Timestamp.fromMillis(
                nowMs + CALLKIT_RESPONSE_WINDOW_MS,
              );
              const participantStates = buildCallKitLifecycleEscalation({
                sessionData: {...fresh, sessionId},
                participantIds: escalationParticipantIds,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              transaction.update(sessionRef, {
                participantStates,
                responseExpiresAt,
                confirmationExpiresAt: responseExpiresAt,
                "matchLock.expiresAt": responseExpiresAt,
                matchStage: MATCH_STAGE.AWAITING_INITIAL_DISPATCH,
                lifecycleEscalation: {
                  revision:
                    Math.max(
                      0,
                      Number(fresh.lifecycleEscalation?.revision) || 0,
                    ) + 1,
                  participantIds: escalationParticipantIds,
                  requestedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                acceptingTutorId: admin.firestore.FieldValue.delete(),
                acceptingAt: admin.firestore.FieldValue.delete(),
                acceptAttemptId: admin.firestore.FieldValue.delete(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              return {
                alreadyAccepted: false,
                finalizationDeferred: true,
              };
            }
          }
          const usersCollection = admin.firestore().collection("users");
          const requesterUserRef = usersCollection.doc(requesterId);
          const responderUserRef = usersCollection.doc(tutorId);
          const [requesterUserSnap, responderUserSnap] =
            await transaction.getAll(requesterUserRef, responderUserRef);
          if (!requesterUserSnap.exists) {
            throw new functions.https.HttpsError(
              "not-found",
              "Requester not found",
            );
          }
          if (!responderUserSnap.exists) {
            throw new functions.https.HttpsError(
              "not-found",
              "Responder not found",
            );
          }
          assertUserCanJoinAcceptedSessionOrThrow(
            requesterUserSnap.data() || {},
            requesterId,
            sessionId,
          );
          assertUserCanJoinAcceptedSessionOrThrow(
            responderUserSnap.data() || {},
            tutorId,
            sessionId,
          );
          const roomJoinTimeoutFields = buildAcceptedRoomJoinTimeoutFields();

          // Обновляем сессию - добавляем данные для активной сессии
          const sessionUpdate = {
            // Обновляем основные поля
            tutorId: tutorId,
            status: VIDEO_SESSION_STATUS.CONNECTING,
            acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
            ...roomJoinTimeoutFields,

            // Добавляем данные Daily.co
            dailyRoomUrl: roomUrl,
            dailyRoomName: roomName,
            expiresAt: activePolicyUpdate.sessionUpdateFields.expiresAt,
            acceptingTutorId: admin.firestore.FieldValue.delete(),
            acceptingAt: admin.firestore.FieldValue.delete(),
            acceptAttemptId: admin.firestore.FieldValue.delete(),

            // Добавляем информацию о преподавателе
            tutorInfo: {
              name: tutorData.display_name || "Partner",
              photo: tutorData.photo_url || null,
            },
            participantIds: [requesterId, tutorId].sort(),

            // Очищаем поля поиска (уже не нужны)
            currentTutorId: admin.firestore.FieldValue.delete(),
            currentResponderId: admin.firestore.FieldValue.delete(),
            currentResponderRole: admin.firestore.FieldValue.delete(),
            tutorNavigationTriggered: false,
            studentNavigationTriggered: false,
            "sessionMetadata.roomCreatedAt": roomCreatedAt || Date.now(),
            "sessionMetadata.dailyRoomConfigVersion": DAILY_ROOM_CONFIG_VERSION,
            "matchContext.acceptedResponderId": tutorId,
            "matchContext.acceptedResponderRole": normalizeRole(tutorData.role),
            "matchContext.acceptedResponderInfo": buildSessionUserInfo(
              tutorData,
              "Partner",
            ),
          };
          if (activePolicyUpdate.sessionUpdateFields.sessionPolicy) {
            sessionUpdate.sessionPolicy =
              activePolicyUpdate.sessionUpdateFields.sessionPolicy;
          }
          if (Number(fresh.matchProtocolVersion) >= MATCH_PROTOCOL_VERSION) {
            sessionUpdate.matchStage = MATCH_STAGE.CONNECTING;
            sessionUpdate.matchFinalization = {
              ...(fresh.matchFinalization || {}),
              status: "completed",
              pairAttemptId: fresh.pairAttemptId,
              completedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
          }

          transaction.update(sessionRef, sessionUpdate);

          const participantUserUpdate = buildAcceptedParticipantUserUpdate({
            sessionId,
            serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Обновляем статус участников подтвержденного звонка
          transaction.update(requesterUserRef, participantUserUpdate);
          transaction.update(responderUserRef, participantUserUpdate);

          safeLog.log("accept_transaction_completed", {sessionId});
          return { alreadyAccepted: false };
        });

      if (txnResult?.finalizationDeferred) {
        lockAcquired = false;
        if (transientDailyRoomName) {
          await deleteDailyRoom(transientDailyRoomName);
          transientDailyRoomName = null;
        }
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Participant lifecycle requires CallKit confirmation",
          {reason: "lifecycle_escalation_pending"},
        );
      }

      if (txnResult?.alreadyAccepted) {
        if (transientDailyRoomName) {
          await deleteDailyRoom(transientDailyRoomName);
          transientDailyRoomName = null;
        }
        safeLog.log("session_already_active", {sessionId, responderId: tutorId});
        const existing = txnResult.session || {};
        const existingRoomUrl = existing.dailyRoomUrl;
        const existingRoomName =
          existing.dailyRoomName || getRoomNameFromUrl(existingRoomUrl);
        let existingMeetingToken = null;
        if (
          existingRoomName &&
          shouldIssueAcceptResponseMeetingToken(internalOptions)
        ) {
          const existingCredentialTtlSeconds =
            getDailyCredentialTtlOrThrow(existing);
          try {
            existingMeetingToken = await createMeetingToken({
              roomName: existingRoomName,
              expSeconds: existingCredentialTtlSeconds,
              isOwner: false,
              userId: tutorId,
              userName: tutorData.display_name || "Partner",
            });
          } catch (tokenError) {
            safeLog.error("meeting_token_create_failed", {
              sessionId,
              responderId: tutorId,
              error: tokenError,
            });
          }
        }
        await readAcceptedSessionStillCurrentOrThrow({
          db: admin.firestore(),
          sessionRef,
          sessionId,
          requesterId,
          responderId: tutorId,
        });
        logCallLifecycleEvent({
          event: "accept_idempotent_existing",
          source: "acceptCall",
          sessionId,
          requesterId,
          responderId: tutorId,
          scenario: existing.scenario || sessionData.scenario,
          statusBefore: sessionData.status,
          statusAfter: existing.status,
          result: "connected",
        });

        return {
          status: "connected",
          sessionId: sessionId,
          roomUrl: existingRoomUrl,
          roomName: existingRoomName || null,
          meetingToken: existingMeetingToken || null,
          studentInfo: existing.studentInfo || null,
          sessionData: buildAcceptCallResponseSessionData(existing),
        };
      }

      transientDailyRoomName = null;
      const acceptedLiveSession =
        await readAcceptedSessionStillCurrentOrThrow({
          db: admin.firestore(),
          sessionRef,
          sessionId,
          requesterId,
          responderId: tutorId,
        });
      roomUrl = acceptedLiveSession.dailyRoomUrl || roomUrl;
      roomName =
        acceptedLiveSession.dailyRoomName ||
        getRoomNameFromUrl(roomUrl) ||
        roomName;
      if (!roomUrl || !roomName) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Accepted room is not ready",
        );
      }
      if (shouldIssueAcceptResponseMeetingToken(internalOptions)) {
        const acceptedCredentialTtlSeconds =
          getDailyCredentialTtlOrThrow(acceptedLiveSession);
        try {
          meetingToken = await createMeetingToken({
            roomName,
            expSeconds: acceptedCredentialTtlSeconds,
            isOwner: false,
            userId: tutorId,
            userName: tutorData.display_name || "Partner",
          });
        } catch (tokenError) {
          safeLog.error("meeting_token_create_failed", {
            sessionId,
            responderId: tutorId,
            error: tokenError,
          });
        }
      }

      // 🔔 === ОТПРАВКА PUSH + ОБНОВЛЕНИЕ УВЕДОМЛЕНИЙ (ПАРАЛЛЕЛЬНО) ===
      safeLog.log("accept_post_tasks_started", {sessionId});
      const postAcceptTasks = [
        updateNotificationStatus(sessionId, tutorId, "accepted"),
        cancelOtherNotifications(sessionId, tutorId),
      ];
      if (Number(acceptedLiveSession.matchProtocolVersion) < 2) {
        postAcceptTasks.push(sendVoipPushToStudent(requesterId, {
          sessionId: sessionId,
          callerName: tutorData.display_name || "Собеседник",
          callerId: tutorId,
          callerPhoto: tutorData.photo_url || null,
          scenario:
            acceptedLiveSession.scenario ||
            sessionData.scenario ||
            "student_teacher",
          requesterId,
          responderId: tutorId,
          requesterRole:
            acceptedLiveSession.requesterRole ||
            sessionData.requesterRole ||
            "student",
          responderRole:
            acceptedLiveSession.responderRole ||
            sessionData.responderRole ||
            "native_speaker",
          navRole: "student",
          acceptMode: "open_session",
          callKitId: buildCallKitIdForSession(sessionId),
          notificationId: "",
          searchRequestId:
            normalizeSessionId(
              acceptedLiveSession.searchRequestIds?.requester,
            ) ||
            normalizeSessionId(sessionData.searchRequestIds?.requester),
          expiresAt: "",
          roomUrl: roomUrl,
          meetingToken: "",
          roomName: roomName || "",
          tokenStrategy: "payload_room",
        }).catch((pushError) => {
          safeLog.error("voip_push_failed", {sessionId, responderId: tutorId, error: pushError});
        }));
      }
      await Promise.all(postAcceptTasks);
      safeLog.log("accept_post_tasks_completed", {sessionId});

      // === 8. ПОДГОТОВКА ОТВЕТА ===
      safeLog.log("accept_response_preparing", {sessionId});
      logCallLifecycleEvent({
        event: "accept_connected",
        source: "acceptCall",
        sessionId,
        requesterId,
        responderId: tutorId,
        scenario: acceptedLiveSession.scenario || sessionData.scenario,
        searchRequestId:
          normalizeSessionId(acceptedLiveSession.searchRequestIds?.requester) ||
          normalizeSessionId(sessionData.searchRequestIds?.requester),
        pairAttemptId:
          normalizeSessionId(acceptedLiveSession.matchContext?.pairAttemptId) ||
          normalizeSessionId(sessionData.matchContext?.pairAttemptId),
        statusBefore: sessionData.status,
        statusAfter: acceptedLiveSession.status,
        result: "connected",
      });

      const response = {
        status: "connected",
        sessionId: sessionId,
        roomUrl: roomUrl,
        roomName: roomName,
        meetingToken: meetingToken,
        studentInfo: {
          name:
            sessionData.studentInfo?.name ||
            studentData.display_name ||
            "Caller",
          photo:
            sessionData.studentInfo?.photo || studentData.photo_url || null,
        },
        sessionData: buildAcceptCallResponseSessionData({
          language: acceptedLiveSession.language || sessionData.language,
          startedAt: acceptedLiveSession.startedAt || null,
          sessionPolicy: activePolicyUpdate.policyState.sessionPolicy,
        }),
      };

      safeLog.log("accept_response", {
        status: response.status,
        sessionId: response.sessionId,
        hasRoomUrl: !!response.roomUrl,
        hasToken: !!response.meetingToken,
      });

      return response;
    } catch (error) {
      safeLog.error("accept_failed", {
        sessionId,
        responderId: tutorId,
        error,
      });
      logCallLifecycleError({
        event: "accept_failed",
        source: "acceptCall",
        sessionId,
        responderId: tutorId,
        errorCode: error.code || error.name,
        reason: error.message,
      });

      if (lockAcquired) {
        try {
          await admin.firestore().runTransaction(async (transaction) => {
            const snap = await transaction.get(sessionRef);
            if (!snap.exists) return;
            const data = snap.data();
            if (
              data.acceptingTutorId === tutorId &&
              data.acceptAttemptId === acceptAttemptId
            ) {
              transaction.update(sessionRef, {
                acceptingTutorId: admin.firestore.FieldValue.delete(),
                acceptingAt: admin.firestore.FieldValue.delete(),
                acceptAttemptId: admin.firestore.FieldValue.delete(),
              });
            }
          });
        } catch (lockError) {
          safeLog.error("accept_lock_release_failed", {
            sessionId,
            error: lockError,
          });
        }
      }

      if (transientDailyRoomName) {
        await deleteDailyRoom(transientDailyRoomName);
      }

      if (error.code && error.message) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        "Unable to accept the call right now. Please try again.",
      );
    }
}

exports.acceptCall = functions
  .runWith({ secrets: [...apnsSecrets, ...dailySecrets] })
  .https.onCall(acceptCallCallable);

// === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===

// 🔔 ОТПРАВКА VOIP PUSH NOTIFICATION (НОВАЯ ФУНКЦИЯ)
async function sendVoipPushToStudent(studentId, callData) {
  try {
    safeLog.log("voip_push_prepare", {studentId});

    // Получаем данные студента из Firestore
    const studentDoc = await admin
      .firestore()
      .collection("users")
      .doc(studentId)
      .get();

    if (!studentDoc.exists) {
      safeLog.warn("voip_push_recipient_not_found", {studentId});
      return;
    }

    const studentData = studentDoc.data();
    // Legacy teacher acceptance must not open a native surface for the student.
    if (normalizeRole(studentData?.role) === "student") return;

    const bundleId = process.env.IOS_BUNDLE_ID || "com.appwave.expatlio";
    const voipTopic =
      process.env.IOS_VOIP_TOPIC ||
      (bundleId.endsWith(".voip") ? bundleId : `${bundleId}.voip`);
    const { voipPushToken, voipToken: fcmToken } =
      await getUserVoipTokens(studentId, studentData);

    if (!voipPushToken && !fcmToken) {
      safeLog.warn("voip_push_tokens_missing", {studentId});
      return;
    }

    if (voipPushToken) {
      const apnsPayload = {
        aps: { "content-available": 1 },
        type: "incoming_call",
        sessionId: callData.sessionId,
        recipientId: callData.recipientId || studentId,
        callerName: callData.callerName,
        callerId: callData.callerId,
        callerPhoto: callData.callerPhoto || "",
        scenario: callData.scenario || "",
        requesterId: callData.requesterId || "",
        responderId: callData.responderId || "",
        requesterRole: callData.requesterRole || "",
        responderRole: callData.responderRole || "",
        navRole: callData.navRole || "student",
        acceptMode: callData.acceptMode || "open_session",
        callKitId:
          callData.callKitId || buildCallKitIdForSession(callData.sessionId),
        notificationId: callData.notificationId || "",
        searchRequestId: callData.searchRequestId || "",
        expiresAt: callData.expiresAt || "",
        roomUrl: callData.roomUrl || "",
        meetingToken: callData.meetingToken || "",
        roomName: callData.roomName || "",
        tokenStrategy: callData.tokenStrategy || "payload_room",
      };

      try {
        await sendApnsVoip({
          deviceToken: voipPushToken,
          topic: voipTopic,
          payload: apnsPayload,
        });
        safeLog.log("voip_apns_push_sent", {studentId});
        return;
      } catch (error) {
        safeLog.error("voip_apns_push_failed", {studentId, error});
      }
    }

    if (!fcmToken) {
      safeLog.warn("voip_fcm_token_missing", {studentId});
      return;
    }

    safeLog.log("voip_fcm_fallback", {studentId, platform: "ios"});

    const message = {
      token: fcmToken,
      data: {
        type: "incoming_call",
        sessionId: callData.sessionId,
        recipientId: callData.recipientId || studentId,
        callerName: callData.callerName,
        callerId: callData.callerId,
        callerPhoto: callData.callerPhoto || "",
        scenario: callData.scenario || "",
        requesterId: callData.requesterId || "",
        responderId: callData.responderId || "",
        requesterRole: callData.requesterRole || "",
        responderRole: callData.responderRole || "",
        navRole: callData.navRole || "student",
        acceptMode: callData.acceptMode || "open_session",
        callKitId:
          callData.callKitId || buildCallKitIdForSession(callData.sessionId),
        notificationId: callData.notificationId || "",
        searchRequestId: callData.searchRequestId || "",
        expiresAt: callData.expiresAt || "",
        roomUrl: callData.roomUrl || "",
        meetingToken: callData.meetingToken || "",
        roomName: callData.roomName || "",
        tokenStrategy: callData.tokenStrategy || "payload_room",
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
              body: `${callData.callerName} звонит вам`,
            },
            sound: "default",
          },
        },
      },
      android: {
        priority: "high",
      },
    };

    safeLog.log("voip_fcm_push_started", {studentId});

    const response = await admin.messaging().send(message);

    safeLog.log("voip_fcm_push_sent", {studentId});

    return response;
  } catch (error) {
    safeLog.error("voip_push_failed", {studentId, error});

    // Бросаем ошибку дальше, чтобы она была залогирована
    throw error;
  }
}

// Daily room helpers moved to daily_room.js

// ОБНОВЛЕНИЕ СТАТУСА УВЕДОМЛЕНИЯ
async function updateNotificationStatus(sessionId, tutorId, status) {
  try {
    safeLog.log("notification_status_update_started", {
      status,
      sessionId,
      responderId: tutorId,
    });

    const notificationsQuery = await admin
      .firestore()
      .collection("notifications")
      .where("sessionId", "==", sessionId)
      .where("recipientId", "==", tutorId)
      .where("status", "==", "sent")
      .get();

    if (!notificationsQuery.empty) {
      const batch = admin.firestore().batch();

      notificationsQuery.forEach((doc) => {
        batch.update(doc.ref, {
          status: status,
          [`${status}At`]: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();
      safeLog.log("notification_status_updated", {
        status,
        counts: {updated: notificationsQuery.size},
      });
    } else {
      safeLog.log("notification_status_update_empty", {status});
    }
  } catch (error) {
    safeLog.error("notification_status_update_failed", {
      sessionId,
      responderId: tutorId,
      error,
    });
  }
}

// ОТМЕНА ДРУГИХ УВЕДОМЛЕНИЙ
async function cancelOtherNotifications(sessionId, acceptedTutorId) {
  try {
    safeLog.log("other_notifications_cancel_started", {
      sessionId,
      responderId: acceptedTutorId,
    });

    const otherNotificationsQuery = await admin
      .firestore()
      .collection("notifications")
      .where("sessionId", "==", sessionId)
      .where("status", "==", "sent")
      .get();

    if (!otherNotificationsQuery.empty) {
      const batch = admin.firestore().batch();
      let canceledCount = 0;

      otherNotificationsQuery.forEach((doc) => {
        const notificationData = doc.data();
        if (notificationData.recipientId !== acceptedTutorId) {
          batch.update(doc.ref, {
            status: "cancelled",
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
            cancelReason: "call_accepted_by_other_tutor",
          });
          canceledCount++;
        }
      });

      if (canceledCount > 0) {
        await batch.commit();
        safeLog.log("other_notifications_cancelled", {
          counts: {cancelled: canceledCount},
        });
      }
    }
  } catch (error) {
    safeLog.error("other_notifications_cancel_failed", {
      sessionId,
      responderId: acceptedTutorId,
      error,
    });
  }
}

exports.__private__ = {
  acceptCallCallable,
  assertAcceptAttemptCanFinalizeOrThrow,
  assertAcceptLockOwnedByAttemptOrThrow,
  assertAcceptLockOwnedByResponderOrThrow,
  assertAcceptWindowOpenOrThrow,
  assertAcceptedSessionStillCurrentOrThrow,
  assertUserCanJoinAcceptedSessionOrThrow,
  assertUserIsInAcceptedSessionOrThrow,
  buildAcceptedParticipantUserUpdate,
  buildAcceptCallPolicyUpdateFields,
  buildAcceptCallResponseSessionData,
  buildAcceptedRoomJoinTimeoutFields,
  getPendingAssignedResponderId,
  isPendingSessionAssignedToResponder,
  normalizeSessionId,
  readAcceptedSessionStillCurrentOrThrow,
  shouldIssueAcceptResponseMeetingToken,
  timestampToMillis,
};
