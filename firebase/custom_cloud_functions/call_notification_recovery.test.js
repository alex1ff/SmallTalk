const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  buildCallKitIdForSession,
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
  assert.equal(data.payloadExpiresAt, "2026-05-26T10:00:45.000Z");
  assert.equal(data.scenario, "student_teacher");
  assert.equal(data.requesterId, "student-a");
  assert.equal(data.responderId, "teacher/one");
  assert.equal(data.requesterRole, "student");
  assert.equal(data.responderRole, "native_speaker");
  assert.equal(data.navRole, "tutor");
  assert.equal(data.acceptMode, "responder_accepts");
  assert.equal(data.callKitId, buildCallKitIdForSession("session/one"));
  assert.equal(data.searchRequestId, "");
  assert.equal(data.roomUrl, "");
  assert.equal(data.roomName, "");
  assert.equal(data.tokenStrategy, "accept_call");
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
      recipientId: "teacher-a",
      sessionId: "session-a",
      notificationId: "session-a_teacher-a",
      sessionData: {
        language: "Spanish",
        studentId: "student-a",
        requesterId: "student-a",
        responderId: "teacher-a",
        currentResponderId: "teacher-a",
        currentResponderRole: "native_speaker",
        responderRole: "native_speaker",
        requesterRole: "student",
        scenario: "student_teacher",
        studentInfo: {
          name: "Ana",
          photo: "photo-url",
        },
        searchRequestIds: {
          requester: "student-search",
          responder: "teacher-search",
        },
      },
    }),
    {
      sessionId: "session-a",
      studentName: "Ana",
      studentId: "student-a",
      studentPhoto: "photo-url",
      language: "Spanish",
      recipientId: "teacher-a",
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
      expiresAt: "",
      roomUrl: "",
      roomName: "",
      tokenStrategy: "accept_call",
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
  assert.equal(writes[0].data.notificationId, "session-a_teacher-a");
  assert.equal(result.pushPayload.studentName, "Ana");
  assert.equal(result.pushPayload.notificationId, "session-a_teacher-a");
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
    assert.match(source, /findNextCallableCandidateInTransaction/);
    const candidateHelperIndex = source.indexOf(
      "findNextCallableCandidateInTransaction({",
    );
    assert.notEqual(candidateHelperIndex, -1);
    const candidateHelperEnd = source.indexOf("});", candidateHelperIndex);
    assert.notEqual(candidateHelperEnd, -1);
    assert.match(
      source.slice(candidateHelperIndex, candidateHelperEnd),
      /language:/,
    );

    const helperIndex = source.indexOf(
      "createIncomingCallNotificationInTransaction({",
    );
    const sessionUpdateIndex = source.indexOf(
      "transaction.update(sessionRef",
      helperIndex,
    );
    const preparedLockApplyIndex = source.indexOf(
      "applyPreparedPairLockWrites",
      helperIndex,
    );
    const assignmentAfterHelperIndex = [
      sessionUpdateIndex,
      preparedLockApplyIndex,
    ].filter((index) => index !== -1).sort((a, b) => a - b)[0] ?? -1;
    const reserveBeforeHelperIndex = source.lastIndexOf(
      "reserveMatchPairInTransaction({",
      helperIndex,
    );
    const directReserveBeforeHelperIndex = source.lastIndexOf(
      "reserveDirectPairInTransaction({",
      helperIndex,
    );
    const sendVoipPushIndex = source.indexOf("sendVoipPushToTutor", helperIndex);
    const sendVoipOrFcmIndex = source.indexOf("sendVoipOrFcm", helperIndex);
    const pushIndex = Math.max(sendVoipPushIndex, sendVoipOrFcmIndex);
    const reserveAssignmentIndex = Math.max(
      reserveBeforeHelperIndex,
      directReserveBeforeHelperIndex,
    );
    const assignmentIndex = reserveAssignmentIndex !== -1 ?
      reserveAssignmentIndex :
      assignmentAfterHelperIndex;

    assert.notEqual(helperIndex, -1, `${name} missing notification helper`);
    assert.ok(
      assignmentIndex !== -1,
      `${name} must assign the recipient in the transaction`,
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
    "const validationReads = [sessionRef.get()];",
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

test("incoming call push validation accepts pending confirmation sessions", () => {
  const sources = {
    createVideoSession: readFunctionSource("create_video_session.js"),
    processExpiredNotifications: readFunctionSource("process_expired_notifications.js"),
  };

  for (const [name, source] of Object.entries(sources)) {
    assert.match(
      source,
      /PENDING_RESPONSE_SESSION_STATUSES\.has\(freshValidation(?:Data)?\.status\)/,
      `${name} must not require legacy searching status before push`,
    );
  }
  assert.match(
    sources.createVideoSession,
    /status:\s*VIDEO_SESSION_STATUS\.PENDING_CONFIRMATION/,
  );
});

test("acceptCall validates responder language before room credentials", () => {
  const source = readFunctionSource("accept_call.js");
  const languageIndex = source.indexOf(
    "validateResponderLanguageOrThrow(tutorId, tutorData, sessionData);",
  );
  const credentialIndex = source.indexOf("createMeetingToken({");

  assert.notEqual(languageIndex, -1);
  assert.notEqual(credentialIndex, -1);
  assert.ok(languageIndex < credentialIndex);
});
