const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildCallKitIdForSession,
  buildIncomingCallNotificationData,
  buildIncomingCallPushPayload,
  buildTeacherIncomingCallApnsPayload,
  buildTeacherIncomingCallFcmMessage,
  buildTeacherIncomingCallPushData,
} = require("./call_notifications");

function timestampFromMillis(millis) {
  return {
    toMillis: () => millis,
    toDate: () => new Date(millis),
  };
}

function expectedTeacherMetadata(overrides = {}) {
  return {
    scenario: "student_teacher",
    requesterId: "student-a",
    responderId: "",
    requesterRole: "student",
    responderRole: "native_speaker",
    navRole: "tutor",
    acceptMode: "responder_accepts",
    callKitId: buildCallKitIdForSession("session-a"),
    notificationId: "",
    searchRequestId: "",
    expiresAt: "",
    roomUrl: "",
    roomName: "",
    tokenStrategy: "accept_call",
    ...overrides,
  };
}

test("teacher incoming call push data uses CallKit-compatible fields", () => {
  assert.deepEqual(
    buildTeacherIncomingCallPushData({
      sessionId: "session-a",
      studentName: "Ana",
      studentId: "student-a",
      studentPhoto: "photo-url",
      language: "English",
    }),
    {
      type: "incoming_call",
      sessionId: "session-a",
      callerName: "Ana",
      callerId: "student-a",
      callerPhoto: "photo-url",
      language: "English",
      ...expectedTeacherMetadata(),
    },
  );
});

test("teacher incoming call APNs payload carries the same call identity", () => {
  const payload = buildTeacherIncomingCallApnsPayload({
    sessionId: "session-a",
    studentName: "Ana",
    studentId: "student-a",
    studentPhoto: "photo-url",
    language: "English",
  });

  assert.deepEqual(payload, {
    aps: {"content-available": 1},
    type: "incoming_call",
    sessionId: "session-a",
    callerName: "Ana",
    callerId: "student-a",
    callerPhoto: "photo-url",
    language: "English",
    ...expectedTeacherMetadata(),
  });
});

test("teacher incoming call FCM fallback keeps APNs and Android call surfaces", () => {
  const message = buildTeacherIncomingCallFcmMessage({
    token: "fcm-token",
    bundleId: "com.example.app",
    callData: {
      sessionId: "session-a",
      studentName: "Ana",
      studentId: "student-a",
      studentPhoto: "photo-url",
      language: "English",
    },
  });

  assert.equal(message.token, "fcm-token");
  assert.deepEqual(message.data, {
    type: "incoming_call",
    sessionId: "session-a",
    callerName: "Ana",
    callerId: "student-a",
    callerPhoto: "photo-url",
    language: "English",
    ...expectedTeacherMetadata(),
  });
  assert.deepEqual(message.apns.headers, {
    "apns-priority": "10",
    "apns-push-type": "alert",
    "apns-topic": "com.example.app",
  });
  assert.deepEqual(message.apns.payload.aps, {
    "content-available": 1,
    alert: {
      title: "Входящий звонок",
      body: "Ana хочет попрактиковать English",
    },
    sound: "default",
  });
  assert.deepEqual(message.android, {priority: "high"});
});

test("incoming call push payload carries routing metadata without room token", () => {
  const expiresAtMillis = Date.parse("2026-06-21T10:00:45.000Z");
  const payload = buildIncomingCallPushPayload({
    recipientId: "teacher-a",
    sessionId: "session-a",
    notificationId: "session-a_teacher-a",
    sessionData: {
      requesterId: "student-a",
      responderId: "teacher-a",
      currentResponderId: "teacher-a",
      currentTutorId: "teacher-a",
      requesterRole: "student",
      responderRole: "native_speaker",
      currentResponderRole: "native_speaker",
      scenario: "student_teacher",
      studentId: "student-a",
      language: "English",
      dailyRoomUrl: "https://daily.test/session-a",
      dailyRoomName: "room-a",
      responseExpiresAt: timestampFromMillis(expiresAtMillis),
      searchRequestIds: {
        requester: "student-search",
        responder: "teacher-search",
      },
    },
    studentInfo: {
      name: "Ana",
      photo: "photo-url",
    },
  });

  assert.deepEqual(payload, {
    sessionId: "session-a",
    studentName: "Ana",
    studentId: "student-a",
    studentPhoto: "photo-url",
    language: "English",
    scenario: "student_teacher",
    requesterId: "student-a",
    responderId: "teacher-a",
    requesterRole: "student",
    responderRole: "native_speaker",
    navRole: "tutor",
    acceptMode: "responder_accepts",
    callKitId: buildCallKitIdForSession("session-a"),
    notificationId: "session-a_teacher-a",
    searchRequestId: "teacher-search",
    expiresAt: "2026-06-21T10:00:45.000Z",
    roomUrl: "",
    roomName: "room-a",
    tokenStrategy: "accept_call",
  });
  assert.equal(Object.hasOwn(payload, "meetingToken"), false);
});

test("incoming call notification data keeps metadata for Firestore fallback", () => {
  const notificationData = buildIncomingCallNotificationData({
    recipientId: "student-b",
    sessionId: "session-b",
    notificationId: "session-b_student-b",
    sessionData: {
      requesterId: "student-a",
      responderId: "student-b",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      requesterRole: "student",
      responderRole: "student",
      currentResponderRole: "student",
      scenario: "student_student",
      studentId: "student-a",
      language: "English",
      searchRequestIds: {
        requester: "student-a-search",
        responder: "student-b-search",
      },
    },
    studentInfo: {
      name: "Ana",
    },
    now: new Date("2026-06-21T10:00:00.000Z"),
  });

  assert.equal(notificationData.notificationId, "session-b_student-b");
  assert.equal(notificationData.scenario, "student_student");
  assert.equal(notificationData.requesterId, "student-a");
  assert.equal(notificationData.responderId, "student-b");
  assert.equal(notificationData.requesterRole, "student");
  assert.equal(notificationData.responderRole, "student");
  assert.equal(notificationData.navRole, "student");
  assert.equal(notificationData.acceptMode, "responder_accepts");
  assert.equal(notificationData.callKitId, buildCallKitIdForSession("session-b"));
  assert.equal(notificationData.searchRequestId, "student-b-search");
  assert.equal(notificationData.payloadExpiresAt, "2026-06-21T10:00:45.000Z");
  assert.equal(notificationData.roomUrl, "");
  assert.equal(notificationData.roomName, "");
  assert.equal(notificationData.tokenStrategy, "accept_call");
});
