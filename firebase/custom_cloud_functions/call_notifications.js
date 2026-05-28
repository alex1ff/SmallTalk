const admin = require("firebase-admin");

const INCOMING_CALL_NOTIFICATION_TTL_SECONDS = 45;

function incomingCallNotificationId(sessionId, recipientId) {
  return `${sessionId}_${recipientId}`.replace(/[^A-Za-z0-9_-]/g, "_");
}

function incomingCallNotificationRef(db, sessionId, recipientId) {
  return db
    .collection("notifications")
    .doc(incomingCallNotificationId(sessionId, recipientId));
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

  return {
    recipientId,
    sessionId,
    type: "incoming_call",
    status: "sent",
    title: "Входящий звонок",
    message: `${studentName} хочет попрактиковать ${language}`,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    studentInfo: resolvedStudentInfo,
  };
}

function buildIncomingCallPushPayload({
  sessionId,
  sessionData = {},
  studentInfo = null,
  studentNameFallback = "Student",
} = {}) {
  const resolvedStudentInfo = normalizeStudentInfo(
    studentInfo || sessionData.studentInfo || {},
  );
  return {
    sessionId,
    studentName: resolvedStudentInfo.name || studentNameFallback,
    studentId: sessionData.studentId || "",
    studentPhoto: resolvedStudentInfo.photo || null,
    language: sessionData.language || "",
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
  now,
}) {
  const notificationRef = incomingCallNotificationRef(
    db,
    sessionId,
    recipientId,
  );
  const notificationData = buildIncomingCallNotificationData({
    recipientId,
    sessionId,
    sessionData,
    studentInfo,
    studentNameFallback,
    now,
  });
  transaction.set(notificationRef, notificationData);
  return {
    notificationId: notificationRef.id,
    notificationData,
    notificationRef,
    pushPayload: buildIncomingCallPushPayload({
      sessionId,
      sessionData,
      studentInfo,
      studentNameFallback,
    }),
  };
}

module.exports = {
  INCOMING_CALL_NOTIFICATION_TTL_SECONDS,
  buildIncomingCallNotificationData,
  buildIncomingCallPushPayload,
  createIncomingCallNotificationInTransaction,
  incomingCallNotificationId,
  incomingCallNotificationRef,
  normalizeStudentInfo,
};
