const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");
const {
  __private__: {
    buildDeclineNextResponderPairLockInput,
    buildDeclineResponderFailureRouting,
    getPendingAssignedResponderId,
    isPendingSessionAssignedToResponder,
    readRequesterIdForResponderFailure,
  },
} = require("./decline_call");

test("declineCall authorizes currentResponderId student assignments", () => {
  assert.equal(
    getPendingAssignedResponderId({
      currentResponderId: " student-b ",
      currentTutorId: "teacher-a",
    }),
    "student-b",
  );
  assert.equal(
    getPendingAssignedResponderId({
      currentResponderId: " ",
      currentTutorId: " teacher-a ",
    }),
    "teacher-a",
  );
  assert.equal(
    isPendingSessionAssignedToResponder(
      {currentResponderId: "student-b", currentTutorId: "teacher-a"},
      "student-b",
    ),
    true,
  );
  assert.equal(
    isPendingSessionAssignedToResponder(
      {currentResponderId: "student-b", currentTutorId: "teacher-a"},
      "teacher-a",
    ),
    false,
  );
  assert.equal(
    isPendingSessionAssignedToResponder(
      {currentTutorId: "teacher-a"},
      "teacher-a",
    ),
    true,
  );
});

test("declineCall routes student-student failure to requester restore", () => {
  const sessionData = {
    scenario: "student_student",
    studentId: "student-a",
    requesterId: "student-a",
    currentTutorId: "student-b",
    currentResponderId: "student-b",
    currentResponderRole: "student",
    participantRoles: {
      "student-a": "student",
      "student-b": "student",
    },
    availableTutors: ["student-b", "student-c", "teacher-a"],
  };

  const routing = buildDeclineResponderFailureRouting({
    sessionData,
    responderId: "student-b",
  });

  assert.equal(readRequesterIdForResponderFailure(sessionData), "student-a");
  assert.deepEqual(routing.availableTutors, []);
  assert.equal(routing.terminalStopReason, "student_pair_declined");
  assert.deepEqual(routing.restoreSearchParticipantIds, ["student-a"]);
  assert.deepEqual(
    routing.restoreSearchExcludedCandidateIdsByParticipantId,
    {"student-a": ["student-b"]},
  );
});

test("declineCall blocks fresh accept-lock races before handoff", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "decline_call.js"),
    "utf8",
  );
  const assignmentGuardIndex = source.indexOf(
    "isPendingSessionAssignedToResponder(sessionData, responderId)",
  );
  const acceptLockGuardIndex = source.indexOf(
    "assertNoActiveAcceptLockForResponderOrThrow({",
    assignmentGuardIndex,
  );
  const triedTutorsIndex = source.indexOf(
    "const triedTutors = Array.from",
    acceptLockGuardIndex,
  );
  const acceptAttemptDeleteIndex = source.indexOf(
    "acceptAttemptId: admin.firestore.FieldValue.delete()",
    acceptLockGuardIndex,
  );

  assert.ok(acceptLockGuardIndex > assignmentGuardIndex);
  assert.ok(triedTutorsIndex > acceptLockGuardIndex);
  assert.ok(acceptAttemptDeleteIndex > acceptLockGuardIndex);
  assert.doesNotMatch(source, /sessionData\.currentTutorId !== responderId/);
});

test("declineCall validates next assignment before sending push", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "decline_call.js"),
    "utf8",
  );
  const helperIndex = source.indexOf(
    "async function sendNotificationToNextTutor",
  );
  const sessionReadIndex = source.indexOf(
    'db.collection("videoSessions").doc(sessionId).get()',
    helperIndex,
  );
  const statusGuardIndex = source.indexOf(
    "!DECLINABLE_SESSION_STATUSES.has(validationSessionData.status)",
    sessionReadIndex,
  );
  const assignmentGuardIndex = source.indexOf(
    "getPendingAssignedResponderId(validationSessionData) !== nextTutor",
    statusGuardIndex,
  );
  const notificationStatusIndex = source.indexOf(
    'notificationData.status !== "sent"',
    assignmentGuardIndex,
  );
  const activeAcceptLockIndex = source.indexOf(
    "hasActiveAcceptLockForResponder({",
    assignmentGuardIndex,
  );
  const pushIndex = source.indexOf(
    "await sendVoipPushToTutor(nextTutor",
    notificationStatusIndex,
  );

  assert.ok(sessionReadIndex > helperIndex);
  assert.ok(statusGuardIndex > sessionReadIndex);
  assert.ok(assignmentGuardIndex > statusGuardIndex);
  assert.ok(activeAcceptLockIndex > assignmentGuardIndex);
  assert.ok(notificationStatusIndex > assignmentGuardIndex);
  assert.ok(pushIndex > notificationStatusIndex);
});

test("declineCall clears pending responder fields on terminal decline", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "decline_call.js"),
    "utf8",
  );

  const sessionUpdateIndex = source.indexOf("const sessionUpdate = {");
  const legacyDeleteIndex = source.indexOf(
    "currentTutorId: nextTutor || admin.firestore.FieldValue.delete()",
    sessionUpdateIndex,
  );
  const responderDeleteIndex = source.indexOf(
    "currentResponderId: nextTutor || admin.firestore.FieldValue.delete()",
    legacyDeleteIndex,
  );
  const responderRoleDeleteIndex = source.indexOf(
    "currentResponderRole: admin.firestore.FieldValue.delete()",
    responderDeleteIndex,
  );

  assert.ok(legacyDeleteIndex > sessionUpdateIndex);
  assert.ok(responderDeleteIndex > legacyDeleteIndex);
  assert.ok(responderRoleDeleteIndex > responderDeleteIndex);
});

test("declineCall excludes declined responder during teacher handoff", () => {
  const lockInput = buildDeclineNextResponderPairLockInput({
    db: "db",
    transaction: "transaction",
    sessionId: "session-a",
    sessionData: {language: "en"},
    responderId: "teacher-a",
    nextCandidate: {
      candidateId: "teacher-b",
      role: "native_speaker",
      triedCandidateIds: ["teacher-a", "teacher-b"],
    },
    serverTimestamp: "serverTimestamp",
    lockExpiresAt: "lockExpiresAt",
    fieldDelete: "fieldDelete",
  });

  assert.equal(lockInput.db, "db");
  assert.equal(lockInput.transaction, "transaction");
  assert.equal(lockInput.sessionId, "session-a");
  assert.equal(lockInput.currentResponderId, "teacher-a");
  assert.equal(lockInput.responderId, "teacher-b");
  assert.equal(lockInput.responderRole, "native_speaker");
  assert.equal(lockInput.expectedLanguage, "en");
  assert.deepEqual(lockInput.triedTutors, ["teacher-a", "teacher-b"]);
  assert.equal(
    lockInput.currentResponderSearchRequestStatus,
    SEARCH_REQUEST_STATUS.CANCELLED,
  );
  assert.equal(lockInput.currentResponderStopReason, "declined");
  assert.deepEqual(lockInput.requesterExcludedCandidateIds, ["teacher-a"]);
});

test("declineCall keeps teacher handoff candidates", () => {
  const routing = buildDeclineResponderFailureRouting({
    sessionData: {
      scenario: "student_teacher",
      studentId: "student-a",
      currentTutorId: "teacher-a",
      currentResponderRole: "native_speaker",
      availableTutors: ["teacher-a", "teacher-b"],
    },
    responderId: "teacher-a",
  });

  assert.deepEqual(routing.availableTutors, ["teacher-a", "teacher-b"]);
  assert.equal(
    routing.terminalStopReason,
    "no_available_responder_after_decline",
  );
  assert.deepEqual(routing.restoreSearchParticipantIds, ["student-a"]);
  assert.deepEqual(
    routing.restoreSearchExcludedCandidateIdsByParticipantId,
    {"student-a": ["teacher-a"]},
  );
});
