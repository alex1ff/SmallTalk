const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildTeacherIncomingCallApnsPayload,
  buildTeacherIncomingCallFcmMessage,
  buildTeacherIncomingCallPushData,
} = require("./call_notifications");

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
