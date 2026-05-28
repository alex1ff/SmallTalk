const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  buildIncomingCallNotificationData,
  buildIncomingCallPushPayload,
  createIncomingCallNotificationInTransaction,
  incomingCallNotificationId,
} = require("./call_notifications");

function readFunctionSource(fileName) {
  return fs.readFileSync(path.join(__dirname, fileName), "utf8");
}

test("incoming call notification helper builds stable outbox documents", () => {
  const now = new Date("2026-05-26T10:00:00.000Z");
  const data = buildIncomingCallNotificationData({
    recipientId: "teacher/one",
    sessionId: "session/one",
    sessionData: {
      language: "English",
      studentId: "student-a",
      studentInfo: {
        name: "Ana",
        photo: "photo-url",
      },
    },
    now,
  });

  assert.equal(incomingCallNotificationId("session/one", "teacher/one"), "session_one_teacher_one");
  assert.equal(data.recipientId, "teacher/one");
  assert.equal(data.sessionId, "session/one");
  assert.equal(data.type, "incoming_call");
  assert.equal(data.status, "sent");
  assert.equal(data.message, "Ana хочет попрактиковать English");
  assert.deepEqual(data.studentInfo, {
    name: "Ana",
    photo: "photo-url",
  });
  assert.equal(data.expiresAt.toDate().getTime(), now.getTime() + 45_000);
  assert.ok(data.createdAt);
});

test("incoming call notification helper keeps only public student identity fields", () => {
  const data = buildIncomingCallNotificationData({
    recipientId: "teacher-a",
    sessionId: "session-a",
    sessionData: {
      language: "English",
      studentInfo: {
        name: "Ana",
        photo: "photo-url",
        email: "ana@example.test",
        balanceST: 99,
      },
    },
  });

  assert.deepEqual(data.studentInfo, {
    name: "Ana",
    photo: "photo-url",
  });
  assert.equal(data.message, "Ana хочет попрактиковать English");
});

test("incoming call push payload reuses notification identity data", () => {
  assert.deepEqual(
    buildIncomingCallPushPayload({
      sessionId: "session-a",
      sessionData: {
        language: "Spanish",
        studentId: "student-a",
        studentInfo: {
          name: "Ana",
          photo: "photo-url",
        },
      },
    }),
    {
      sessionId: "session-a",
      studentName: "Ana",
      studentId: "student-a",
      studentPhoto: "photo-url",
      language: "Spanish",
    },
  );
});

test("incoming call notification is written through the provided transaction", () => {
  const writes = [];
  const db = {
    collection(collectionName) {
      assert.equal(collectionName, "notifications");
      return {
        doc(documentId) {
          return {
            id: documentId,
            path: `${collectionName}/${documentId}`,
          };
        },
      };
    },
  };
  const transaction = {
    set(ref, data) {
      writes.push({ ref, data });
    },
  };

  const result = createIncomingCallNotificationInTransaction({
    db,
    transaction,
    sessionId: "session-a",
    recipientId: "teacher-a",
    sessionData: {
      language: "German",
      studentId: "student-a",
      studentInfo: { name: "Ana" },
    },
    now: new Date("2026-05-26T10:00:00.000Z"),
  });

  assert.equal(result.notificationId, "session-a_teacher-a");
  assert.equal(writes.length, 1);
  assert.equal(writes[0].ref.path, "notifications/session-a_teacher-a");
  assert.equal(writes[0].data.recipientId, "teacher-a");
  assert.equal(result.pushPayload.studentName, "Ana");
});

test("tutor assignment paths create notification docs in the assignment transaction", () => {
  const sources = {
    createVideoSession: readFunctionSource("create_video_session.js"),
    declineCall: readFunctionSource("decline_call.js"),
    processExpiredNotifications: readFunctionSource("process_expired_notifications.js"),
  };

  for (const [name, source] of Object.entries(sources)) {
    assert.match(source, /createIncomingCallNotificationInTransaction/);
    assert.doesNotMatch(source, /collection\("notifications"\)\.add/);

    const helperIndex = source.indexOf(
      "createIncomingCallNotificationInTransaction({",
    );
    const assignmentIndex = source.indexOf(
      "transaction.update(sessionRef",
      helperIndex,
    );
    const pushIndex = source.indexOf("sendVoipPushToTutor", helperIndex);

    assert.notEqual(helperIndex, -1, `${name} missing notification helper`);
    assert.ok(
      assignmentIndex > helperIndex,
      `${name} must create notification before assigning next tutor`,
    );
    assert.ok(
      pushIndex > assignmentIndex,
      `${name} must send push only after transactional notification assignment`,
    );
  }
});

test("expired notification handoff reads session state before transaction writes", () => {
  const source = readFunctionSource("process_expired_notifications.js");
  const sessionReadIndex = source.indexOf(
    "const freshSessionSnap = await transaction.get(sessionRef);",
  );
  const expireAfterSessionReadIndex = source.indexOf(
    "transaction.update(notificationDoc.ref, expireNotificationUpdate);",
    sessionReadIndex,
  );
  const sessionUpdateIndex = source.indexOf(
    "transaction.update(sessionRef",
    expireAfterSessionReadIndex,
  );

  assert.notEqual(sessionReadIndex, -1);
  assert.ok(
    expireAfterSessionReadIndex > sessionReadIndex,
    "processExpiredNotifications must read session state before expiring the old notification",
  );
  assert.ok(
    sessionUpdateIndex > expireAfterSessionReadIndex,
    "processExpiredNotifications must expire the old notification before mutating session assignment",
  );
});

test("expired notification handoff validates assignment before push", () => {
  const source = readFunctionSource("process_expired_notifications.js");
  const shouldNotifyIndex = source.indexOf("if (transition.shouldNotify) {");
  const validationIndex = source.indexOf(
    "const freshValidationSnap = await sessionRef.get();",
    shouldNotifyIndex,
  );
  const pushIndex = source.indexOf("await sendVoipPushToTutor", shouldNotifyIndex);

  assert.notEqual(shouldNotifyIndex, -1);
  assert.ok(
    validationIndex > shouldNotifyIndex,
    "processExpiredNotifications must re-read the session before sending push",
  );
  assert.ok(
    pushIndex > validationIndex,
    "processExpiredNotifications must send push only after fresh validation",
  );
});
