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
    console.log("❌ Responder cannot accept this language:", {
      tutorId,
      sessionLanguage: sessionData.language || null,
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

exports.acceptCall = functions
  .runWith({ secrets: [...apnsSecrets, ...dailySecrets] })
  .https.onCall(async (data, context) => {
    console.log("✅ Tutor accepting call (updated version)...");

    let tutorId = null;
    let sessionRef = null;
    let sessionId = null;
    let acceptAttemptId = null;
    let lockAcquired = false;
    let transientDailyRoomName = null;
    try {
      // === 1. АУТЕНТИФИКАЦИЯ И ВАЛИДАЦИЯ ===
      if (!context.auth) {
        console.log("❌ User not authenticated");
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated",
        );
      }

      tutorId = context.auth.uid;
      ({ sessionId } = data || {});

      console.log("👨‍🏫 Tutor ID:", tutorId);
      console.log("📺 Session ID:", sessionId);
      logCallLifecycleEvent({
        event: "accept_attempt",
        source: "acceptCall",
        sessionId,
        responderId: tutorId,
      });

      if (!sessionId) {
        console.log("❌ Missing sessionId parameter");
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
        const nowMs = Date.now();
        assertAcceptWindowOpenOrThrow(fresh, nowMs);
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

      const sessionData = initialSessionState.session || {};
      console.log("📋 Session data:", {
        status: sessionData.status,
        currentResponderId: sessionData.currentResponderId,
        currentTutorId: sessionData.currentTutorId,
        studentId: sessionData.studentId,
        language: sessionData.language,
      });

      const tutorDoc = await admin
        .firestore()
        .collection("users")
        .doc(tutorId)
        .get();
      if (!tutorDoc.exists) {
        console.log("❌ Tutor not found:", tutorId);
        throw new functions.https.HttpsError("not-found", "Tutor not found");
      }
      const tutorData = tutorDoc.data();
      validateResponderLanguageOrThrow(tutorId, tutorData, sessionData);

      const requesterId = getRequesterId(sessionData);
      if (!requesterId) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Session requester is missing",
        );
      }

      if (initialSessionState.alreadyAccepted) {
        console.log(
          "ℹ️ Session already active for this tutor, returning existing room",
        );
        let existingRoomName =
          sessionData.dailyRoomName || getRoomNameFromUrl(sessionData.dailyRoomUrl);
        let existingMeetingToken = null;
        const existingCredentialTtlSeconds =
          getDailyCredentialTtlOrThrow(sessionData);

        if (existingRoomName) {
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
            console.error(
              "⚠️ Failed to create meeting token for existing room:",
              tokenError.message,
            );
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

      // === 3. ПОЛУЧЕНИЕ ДАННЫХ РЕСПОНДЕРА И ИНИЦИАТОРА (ПАРАЛЛЕЛЬНО) ===
      console.log("👥 Fetching requester data...");
      const studentDoc = await admin
        .firestore()
        .collection("users")
        .doc(requesterId)
        .get();

      if (!isSupportedSessionRole(tutorData.role)) {
        console.log("❌ User role cannot accept calls:", tutorData.role);
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

      console.log("👨‍🏫 Tutor data:", {
        display_name: tutorData.display_name,
        role: tutorData.role,
        isAvailable: tutorData.isAvailable,
        availabilityTodayEnabled: tutorData.availabilityToday?.enabled,
        isInCall: tutorData.isInCall,
        availabilityReason: availabilityCheck.reason,
        tutorLocalTime: availabilityCheck.localTime || null,
        timezoneOffsetMinutes: availabilityCheck.timezoneOffsetMinutes ?? null,
      });

      if (tutorRole === "native_speaker" && !isApprovedTeacher(tutorData)) {
        console.log("❌ Teacher cannot accept calls before approval:", tutorId);
        throw new functions.https.HttpsError(
          "permission-denied",
          "Teacher verification is pending",
        );
      }

      if (!isAvailable) {
        console.log("❌ Tutor is not available");
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Tutor is not available",
        );
      }

      if (tutorData.isInCall) {
        console.log("❌ Tutor is already in a call");
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Tutor is already in a call",
        );
      }

      if (!studentDoc.exists) {
        console.log("❌ Requester not found:", requesterId);
        throw new functions.https.HttpsError("not-found", "Requester not found");
      }

      const studentData = studentDoc.data();
      console.log("👤 Requester data:", {
        display_name: studentData.display_name,
        role: studentData.role,
      });

      // === 5. ПОЛУЧЕНИЕ ИЛИ СОЗДАНИЕ КОМНАТЫ DAILY.CO ===
      console.log("🏠 Resolving Daily.co room...");
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
            console.log("⚠️ Room name mismatch, using name from URL", {
              roomName,
              derivedName,
            });
            roomName = derivedName;
          }
        }
      }
      let meetingToken = null;
      let roomCreatedAt = sessionData.sessionMetadata?.roomCreatedAt || null;

      if (roomUrl) {
        console.log("♻️ Using precreated Daily room:", {
          roomName,
          roomUrl,
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
              console.warn(
                existingRoom
                  ? "⚠️ Precreated Daily room uses legacy config, recreating room"
                  : "⚠️ Precreated room not found in Daily, recreating room",
              );
              roomUrl = null;
              roomName = null;
              roomCreatedAt = null;
            }
          } else {
            console.log(
              "⚡ Skipping room validation - room is fresh/current (" +
                roomAgeMs +
                "ms old)",
            );
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
          console.error("❌ Failed to create Daily room:", roomError);
          throw new functions.https.HttpsError(
            "internal",
            "Failed to create video room",
          );
        }
      }

      // === 6. ОБНОВЛЕНИЕ СЕССИИ В ТРАНЗАКЦИИ ===
      console.log("🔄 Updating session and user statuses in transaction...");
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
          });
          const usersCollection = admin.firestore().collection("users");
          const requesterUserRef = usersCollection.doc(requesterId);
          const responderUserRef = usersCollection.doc(tutorId);
          const requesterUserSnap = await transaction.get(requesterUserRef);
          const responderUserSnap = await transaction.get(responderUserRef);
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

          transaction.update(sessionRef, sessionUpdate);

          const participantUserUpdate = buildAcceptedParticipantUserUpdate({
            sessionId,
            serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Обновляем статус участников подтвержденного звонка
          transaction.update(requesterUserRef, participantUserUpdate);
          transaction.update(responderUserRef, participantUserUpdate);

          console.log("✅ Transaction completed successfully");
          return { alreadyAccepted: false };
        });

      if (txnResult?.alreadyAccepted) {
        if (transientDailyRoomName) {
          await deleteDailyRoom(transientDailyRoomName);
          transientDailyRoomName = null;
        }
        console.log(
          "ℹ️ Session already active for this tutor (txn), returning existing room",
        );
        const existing = txnResult.session || {};
        const existingRoomUrl = existing.dailyRoomUrl;
        const existingRoomName =
          existing.dailyRoomName || getRoomNameFromUrl(existingRoomUrl);
        let existingMeetingToken = null;
        const existingCredentialTtlSeconds =
          getDailyCredentialTtlOrThrow(existing);
        if (existingRoomName) {
          try {
            existingMeetingToken = await createMeetingToken({
              roomName: existingRoomName,
              expSeconds: existingCredentialTtlSeconds,
              isOwner: false,
              userId: tutorId,
              userName: tutorData.display_name || "Partner",
            });
          } catch (tokenError) {
            console.error(
              "⚠️ Failed to create meeting token for existing room:",
              tokenError.message,
            );
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
        console.error(
          "⚠️ Failed to create meeting token for accepted room:",
          tokenError.message,
        );
      }

      // 🔔 === ОТПРАВКА PUSH + ОБНОВЛЕНИЕ УВЕДОМЛЕНИЙ (ПАРАЛЛЕЛЬНО) ===
      console.log("📲 Sending push + updating notifications in parallel...");
      await Promise.all([
        sendVoipPushToStudent(requesterId, {
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
          console.error(
            "⚠️ Failed to send VoIP push (non-critical):",
            pushError.message,
          );
        }),
        updateNotificationStatus(sessionId, tutorId, "accepted"),
        cancelOtherNotifications(sessionId, tutorId),
      ]);
      console.log("✅ Push + notifications completed");

      // === 8. ПОДГОТОВКА ОТВЕТА ===
      console.log("🎉 Call accepted successfully, preparing response...");
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

      console.log("📤 Returning response:", {
        status: response.status,
        sessionId: response.sessionId,
        hasRoomUrl: !!response.roomUrl,
        hasToken: !!response.meetingToken,
        studentName: response.studentInfo.name,
      });

      return response;
    } catch (error) {
      console.error("❌ Error in acceptCall function:", error);
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
          console.error("⚠️ Failed to release accept lock:", lockError.message);
        }
      }

      if (transientDailyRoomName) {
        await deleteDailyRoom(transientDailyRoomName);
        transientDailyRoomName = null;
      }

      if (error.code && error.message) {
        throw error;
      }

      console.error("❌ Unexpected error details:", {
        message: error.message,
        stack: error.stack,
        name: error.name,
      });

      throw new functions.https.HttpsError(
        "internal",
        `Internal server error: ${error.message}`,
      );
    }
  });

// === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===

// 🔔 ОТПРАВКА VOIP PUSH NOTIFICATION (НОВАЯ ФУНКЦИЯ)
async function sendVoipPushToStudent(studentId, callData) {
  try {
    console.log("📲 Preparing VoIP push for student:", studentId);

    // Получаем данные студента из Firestore
    const studentDoc = await admin
      .firestore()
      .collection("users")
      .doc(studentId)
      .get();

    if (!studentDoc.exists) {
      console.log("⚠️ Student document not found:", studentId);
      return;
    }

    const studentData = studentDoc.data();
    const bundleId = process.env.IOS_BUNDLE_ID || "com.appwave.smalltalk";
    const voipTopic =
      process.env.IOS_VOIP_TOPIC ||
      (bundleId.endsWith(".voip") ? bundleId : `${bundleId}.voip`);
    const { voipPushToken, voipToken: fcmToken } =
      await getUserVoipTokens(studentId, studentData);

    if (!voipPushToken && !fcmToken) {
      console.log("⚠️ Student has no push tokens saved.");
      console.log("⚠️ Student data keys:", Object.keys(studentData));
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
        console.log("✅ APNs VoIP push sent successfully");
        return;
      } catch (error) {
        console.error("❌ Error sending APNs VoIP push:", error.message);
      }
    }

    if (!fcmToken) {
      console.log("⚠️ No FCM token available for fallback");
      return;
    }

    console.log("📱 FCM token found");
    console.log("📦 Using apns-topic for FCM fallback:", bundleId);

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

    console.log("📤 Sending VoIP push via FCM...");

    const response = await admin.messaging().send(message);

    console.log("✅ FCM push sent successfully. Message ID:", response);

    return response;
  } catch (error) {
    console.error("❌ Error sending VoIP push:", error);

    // Логируем детали ошибки
    if (error.code) {
      console.error("❌ Error code:", error.code);
    }
    if (error.message) {
      console.error("❌ Error message:", error.message);
    }
    if (error.errorInfo) {
      console.error("❌ Error info:", JSON.stringify(error.errorInfo));
    }

    // Бросаем ошибку дальше, чтобы она была залогирована
    throw error;
  }
}

// Daily room helpers moved to daily_room.js

// ОБНОВЛЕНИЕ СТАТУСА УВЕДОМЛЕНИЯ
async function updateNotificationStatus(sessionId, tutorId, status) {
  try {
    console.log(`🔔 Updating notification status to ${status}...`);

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
      console.log(
        `✅ Updated ${notificationsQuery.size} notification(s) to ${status}`,
      );
    } else {
      console.log("📭 No notifications found to update");
    }
  } catch (error) {
    console.error("❌ Error updating notification status:", error);
  }
}

// ОТМЕНА ДРУГИХ УВЕДОМЛЕНИЙ
async function cancelOtherNotifications(sessionId, acceptedTutorId) {
  try {
    console.log("🚫 Canceling other active notifications...");

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
        console.log(`✅ Canceled ${canceledCount} other notification(s)`);
      }
    }
  } catch (error) {
    console.error("❌ Error canceling other notifications:", error);
  }
}

exports.__private__ = {
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
  timestampToMillis,
};
