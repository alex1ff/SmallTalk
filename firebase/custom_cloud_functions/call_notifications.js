const admin = require("firebase-admin");
const crypto = require("crypto");

const INCOMING_CALL_NOTIFICATION_TTL_SECONDS = 45;
const UUID_PATTERN =
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function timestampToIsoString(value) {
  if (!value) return "";
  if (value instanceof Date) return value.toISOString();
  if (typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }
  if (typeof value.toMillis === "function") {
    return new Date(value.toMillis()).toISOString();
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return new Date(value).toISOString();
  }
  if (typeof value === "string") return value.trim();
  return "";
}

function buildCallKitIdForSession(sessionId = "") {
  const normalizedSessionId = normalizeString(sessionId);
  if (!normalizedSessionId) return "";
  if (UUID_PATTERN.test(normalizedSessionId)) {
    return normalizedSessionId.toLowerCase();
  }

  const bytes = Array.from(
    crypto
      .createHash("md5")
      .update(`smalltalk-call:${normalizedSessionId}`)
      .digest(),
  );
  bytes[6] = (bytes[6] & 0x0f) | 0x30;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.map((byte) => byte.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-` +
    `${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

function buildCallKitIdForMatchParticipant({
  sessionId = "",
  pairAttemptId = "",
  participantId = "",
} = {}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedPairAttemptId = normalizeString(pairAttemptId);
  const normalizedParticipantId = normalizeString(participantId);
  if (
    !normalizedSessionId ||
    !normalizedPairAttemptId ||
    !normalizedParticipantId
  ) {
    return buildCallKitIdForSession(normalizedSessionId);
  }
  return buildCallKitIdForSession(
    `${normalizedSessionId}:${normalizedPairAttemptId}:` +
      normalizedParticipantId,
  );
}

function readParticipantRole(sessionData = {}, participantId = "") {
  const normalizedParticipantId = normalizeString(participantId);
  if (!normalizedParticipantId) return "";
  const participantRoles = sessionData.participantRoles || {};
  return normalizeString(participantRoles[normalizedParticipantId]);
}

function readRequesterId(sessionData = {}) {
  return normalizeString(sessionData.requesterId) ||
    normalizeString(sessionData.studentId) ||
    normalizeString(sessionData.matchContext?.requesterId);
}

function readResponderId(sessionData = {}, recipientId = "") {
  const requesterId = readRequesterId(sessionData);
  const assignedResponderId =
    normalizeString(sessionData.currentResponderId) ||
    normalizeString(sessionData.currentTutorId) ||
    normalizeString(sessionData.responderId) ||
    normalizeString(sessionData.tutorId) ||
    normalizeString(sessionData.matchContext?.selectedResponderId) ||
    normalizeString(sessionData.matchContext?.acceptedResponderId);
  if (assignedResponderId) return assignedResponderId;
  const normalizedRecipientId = normalizeString(recipientId);
  return normalizedRecipientId && normalizedRecipientId !== requesterId ?
    normalizedRecipientId :
    "";
}

function readRequesterRole(sessionData = {}, requesterId = "") {
  return normalizeString(sessionData.requesterRole) ||
    normalizeString(sessionData.matchContext?.requesterRole) ||
    readParticipantRole(sessionData, requesterId) ||
    "student";
}

function readResponderRole(sessionData = {}, responderId = "") {
  return normalizeString(sessionData.currentResponderRole) ||
    normalizeString(sessionData.responderRole) ||
    readParticipantRole(sessionData, responderId) ||
    (normalizeString(sessionData.tutorId) ? "native_speaker" : "");
}

function roleToNavRole(role = "") {
  const normalizedRole = normalizeString(role);
  return normalizedRole === "native_speaker" || normalizedRole === "teacher" ?
    "tutor" :
    "student";
}

function readSearchRequestId({
  sessionData = {},
  recipientId = "",
  requesterId = "",
  responderId = "",
} = {}) {
  const searchRequestIds = sessionData.searchRequestIds || {};
  const normalizedRecipientId = normalizeString(recipientId);
  if (normalizedRecipientId && normalizedRecipientId === requesterId) {
    return normalizeString(searchRequestIds.requester);
  }
  if (normalizedRecipientId && normalizedRecipientId === responderId) {
    return normalizeString(searchRequestIds.responder);
  }
  return normalizeString(searchRequestIds.responder) ||
    normalizeString(searchRequestIds.requester) ||
    normalizeString(sessionData.searchRequestId) ||
    normalizeString(sessionData.requestId);
}

function readCallExpiresAt(sessionData = {}, fallbackExpiresAt = null) {
  return timestampToIsoString(sessionData.responseExpiresAt) ||
    timestampToIsoString(sessionData.confirmationExpiresAt) ||
    timestampToIsoString(sessionData.expiresAt) ||
    timestampToIsoString(fallbackExpiresAt);
}

function buildIncomingCallPayloadMetadata({
  recipientId = "",
  sessionId = "",
  sessionData = {},
  notificationId = "",
  expiresAt = null,
} = {}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedRecipientId = normalizeString(recipientId);
  const requesterId = readRequesterId(sessionData);
  const responderId = readResponderId(sessionData, normalizedRecipientId);
  const requesterRole = readRequesterRole(sessionData, requesterId);
  const initialResponderRole = readResponderRole(sessionData, responderId);
  const scenario = normalizeString(sessionData.scenario) ||
    (initialResponderRole === "student" ?
      "student_student" :
      "student_teacher");
  const responderRole = initialResponderRole ||
    (scenario === "student_student" ? "student" : "native_speaker");
  const recipientRole = normalizedRecipientId === requesterId ?
    requesterRole :
    responderRole;
  const requestedProtocolV2 = Number(sessionData.matchProtocolVersion) >= 2;
  const matchProtocolVersion = requestedProtocolV2 ?
    "2" :
    "1";
  const pairAttemptId = normalizeString(sessionData.pairAttemptId);
  if (requestedProtocolV2 && !pairAttemptId) {
    throw new Error("match protocol v2 requires pairAttemptId");
  }
  const participantState =
    sessionData.participantStates?.[normalizedRecipientId] || {};
  const isMatchProtocolV2 =
    matchProtocolVersion === "2" && Boolean(pairAttemptId);

  return {
    recipientId: normalizedRecipientId,
    scenario,
    requesterId,
    responderId,
    requesterRole,
    responderRole,
    navRole: roleToNavRole(recipientRole),
    acceptMode: isMatchProtocolV2 ?
      "respond_to_match" :
      "responder_accepts",
    callKitId:
      normalizeString(participantState.callKitId) ||
      (isMatchProtocolV2 ?
        buildCallKitIdForMatchParticipant({
          sessionId: normalizedSessionId,
          pairAttemptId,
          participantId: normalizedRecipientId,
        }) :
        buildCallKitIdForSession(normalizedSessionId)),
    notificationId: normalizeString(notificationId),
    searchRequestId: readSearchRequestId({
      sessionData,
      recipientId: normalizedRecipientId,
      requesterId,
      responderId,
    }),
    expiresAt: readCallExpiresAt(sessionData, expiresAt),
    roomUrl: "",
    roomName:
      normalizeString(sessionData.dailyRoomName) ||
      normalizeString(sessionData.roomName),
    tokenStrategy: "accept_call",
    ...(isMatchProtocolV2 ? {
      matchProtocolVersion,
      pairAttemptId,
      surface: "callkit",
    } : {}),
  };
}

function incomingCallNotificationId(
  sessionId,
  recipientId,
  pairAttemptId = "",
) {
  return [sessionId, pairAttemptId, recipientId]
    .map(normalizeString)
    .filter(Boolean)
    .join("_")
    .replace(/[^A-Za-z0-9_-]/g, "_");
}

function incomingCallNotificationRef(
  db,
  sessionId,
  recipientId,
  pairAttemptId = "",
) {
  return db
    .collection("notifications")
    .doc(incomingCallNotificationId(
      sessionId,
      recipientId,
      pairAttemptId,
    ));
}

function cancelProtocolV2NotificationsInTransaction({
  db,
  transaction,
  sessionId,
  pairAttemptId,
  participantStates = {},
  cancelReason = "match_cancelled",
  serverTimestamp = admin.firestore.FieldValue.serverTimestamp(),
} = {}) {
  let cancelledCount = 0;
  Object.entries(participantStates || {}).forEach(
    ([participantId, participantState]) => {
      if (
        normalizeString(participantState?.surface) !== "callkit" ||
        !normalizeString(participantState?.callKitId)
      ) {
        return;
      }
      transaction.set(incomingCallNotificationRef(
        db,
        sessionId,
        participantId,
        pairAttemptId,
      ), {
        type: "incoming_call",
        sessionId,
        recipientId: participantId,
        pairAttemptId,
        matchProtocolVersion: 2,
        callKitId: participantState.callKitId,
        status: "cancelled",
        cancelledAt: serverTimestamp,
        cancelReason,
        updatedAt: serverTimestamp,
      }, {merge: true});
      cancelledCount += 1;
    },
  );
  return cancelledCount;
}

function normalizeStudentInfo(studentInfo = {}) {
  const normalized = {};
  if (typeof studentInfo.name === "string" && studentInfo.name) {
    normalized.name = studentInfo.name;
  }
  if (typeof studentInfo.photo === "string" && studentInfo.photo) {
    normalized.photo = studentInfo.photo;
  }
  return normalized;
}

function buildIncomingCallNotificationData({
  recipientId,
  sessionId,
  sessionData = {},
  studentInfo = null,
  studentNameFallback = "Student",
  notificationId = "",
  status = "sent",
  now = new Date(),
} = {}) {
  const resolvedStudentInfo = normalizeStudentInfo(
    studentInfo || sessionData.studentInfo || {},
  );
  const studentName = resolvedStudentInfo.name || studentNameFallback;
  const language = sessionData.language || "";
  const expiresAt = new Date(now.getTime());
  expiresAt.setSeconds(
    expiresAt.getSeconds() + INCOMING_CALL_NOTIFICATION_TTL_SECONDS,
  );
  const payloadMetadata = buildIncomingCallPayloadMetadata({
    recipientId,
    sessionId,
    sessionData,
    notificationId,
    expiresAt,
  });

  return {
    recipientId,
    sessionId,
    notificationId: payloadMetadata.notificationId,
    type: "incoming_call",
    status: normalizeString(status) || "sent",
    title: "Входящий звонок",
    message: `${studentName} хочет попрактиковать ${language}`,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    payloadExpiresAt: payloadMetadata.expiresAt,
    studentInfo: resolvedStudentInfo,
    scenario: payloadMetadata.scenario,
    requesterId: payloadMetadata.requesterId,
    responderId: payloadMetadata.responderId,
    requesterRole: payloadMetadata.requesterRole,
    responderRole: payloadMetadata.responderRole,
    navRole: payloadMetadata.navRole,
    acceptMode: payloadMetadata.acceptMode,
    callKitId: payloadMetadata.callKitId,
    searchRequestId: payloadMetadata.searchRequestId,
    roomUrl: payloadMetadata.roomUrl,
    roomName: payloadMetadata.roomName,
    tokenStrategy: payloadMetadata.tokenStrategy,
    ...(payloadMetadata.matchProtocolVersion === "2" ? {
      matchProtocolVersion: payloadMetadata.matchProtocolVersion,
      pairAttemptId: payloadMetadata.pairAttemptId,
      surface: payloadMetadata.surface,
    } : {}),
  };
}

function buildIncomingCallPushPayload({
  recipientId = "",
  sessionId,
  sessionData = {},
  studentInfo = null,
  studentNameFallback = "Student",
  notificationId = "",
  expiresAt = null,
} = {}) {
  const resolvedStudentInfo = normalizeStudentInfo(
    studentInfo || sessionData.studentInfo || {},
  );
  const payloadMetadata = buildIncomingCallPayloadMetadata({
    recipientId,
    sessionId,
    sessionData,
    notificationId,
    expiresAt,
  });
  return {
    sessionId,
    studentName: resolvedStudentInfo.name || studentNameFallback,
    studentId: sessionData.studentId || "",
    studentPhoto: resolvedStudentInfo.photo || null,
    language: sessionData.language || "",
    ...payloadMetadata,
  };
}

function buildTeacherIncomingCallPushData(callData = {}) {
  const sessionId = normalizeString(callData.sessionId);
  const studentName =
    normalizeString(callData.studentName) ||
    normalizeString(callData.callerName) ||
    "Student";
  const callerId =
    normalizeString(callData.studentId) ||
    normalizeString(callData.callerId);
  const language = normalizeString(callData.language);
  const responderRole =
    normalizeString(callData.responderRole) || "native_speaker";
  return {
    type: "incoming_call",
    sessionId,
    recipientId:
      normalizeString(callData.recipientId) ||
      normalizeString(callData.responderId),
    callerName: studentName,
    callerId,
    callerPhoto:
      normalizeString(callData.studentPhoto) ||
      normalizeString(callData.callerPhoto),
    language,
    scenario: normalizeString(callData.scenario) || "student_teacher",
    requesterId: normalizeString(callData.requesterId) || callerId,
    responderId: normalizeString(callData.responderId),
    requesterRole: normalizeString(callData.requesterRole) || "student",
    responderRole,
    navRole: normalizeString(callData.navRole) || roleToNavRole(responderRole),
    acceptMode: normalizeString(callData.acceptMode) || "responder_accepts",
    callKitId:
      normalizeString(callData.callKitId) || buildCallKitIdForSession(sessionId),
    notificationId: normalizeString(callData.notificationId),
    searchRequestId: normalizeString(callData.searchRequestId),
    expiresAt: timestampToIsoString(callData.expiresAt),
    roomUrl: normalizeString(callData.roomUrl),
    roomName: normalizeString(callData.roomName),
    tokenStrategy: normalizeString(callData.tokenStrategy) || "accept_call",
    ...(normalizeString(callData.matchProtocolVersion) === "2" ? {
      matchProtocolVersion: "2",
      pairAttemptId: normalizeString(callData.pairAttemptId),
      surface: normalizeString(callData.surface) || "callkit",
    } : {}),
  };
}

function buildTeacherIncomingCallApnsPayload(callData = {}) {
  return {
    aps: { "content-available": 1 },
    ...buildTeacherIncomingCallPushData(callData),
  };
}

function buildTeacherIncomingCallFcmMessage({
  token,
  callData = {},
  bundleId = "com.appwave.expatlio",
} = {}) {
  const data = buildTeacherIncomingCallPushData(callData);
  return {
    token,
    data,
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
            body: `${data.callerName} хочет попрактиковать ${data.language}`,
          },
          sound: "default",
        },
      },
    },
    android: {
      priority: "high",
    },
  };
}

function createIncomingCallNotificationInTransaction({
  db,
  transaction,
  sessionId,
  recipientId,
  sessionData = {},
  studentInfo = null,
  studentNameFallback = "Student",
  status = "sent",
  now,
}) {
  const notificationRef = incomingCallNotificationRef(
    db,
    sessionId,
    recipientId,
    Number(sessionData.matchProtocolVersion) >= 2 ?
      sessionData.pairAttemptId :
      "",
  );
  const notificationId = notificationRef.id;
  const notificationData = buildIncomingCallNotificationData({
    recipientId,
    sessionId,
    sessionData,
    studentInfo,
    studentNameFallback,
    notificationId,
    status,
    now,
  });
  transaction.set(notificationRef, notificationData);
  return {
    notificationId,
    notificationData,
    notificationRef,
    pushPayload: buildIncomingCallPushPayload({
      recipientId,
      sessionId,
      sessionData,
      studentInfo,
      studentNameFallback,
      notificationId,
      expiresAt: notificationData.payloadExpiresAt,
    }),
  };
}

module.exports = {
  INCOMING_CALL_NOTIFICATION_TTL_SECONDS,
  buildCallKitIdForSession,
  buildCallKitIdForMatchParticipant,
  buildIncomingCallNotificationData,
  buildIncomingCallPayloadMetadata,
  buildIncomingCallPushPayload,
  buildTeacherIncomingCallApnsPayload,
  buildTeacherIncomingCallFcmMessage,
  buildTeacherIncomingCallPushData,
  cancelProtocolV2NotificationsInTransaction,
  createIncomingCallNotificationInTransaction,
  incomingCallNotificationId,
  incomingCallNotificationRef,
  normalizeStudentInfo,
};
