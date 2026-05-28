const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    buildDailyPresenceConnectedDecision,
    buildMarkSessionConnectedDecision,
    dailyPresenceHasAcceptedParticipants,
    normalizeSessionId,
    readSessionMetadata,
    readConnectedSignals,
  },
} = require("./mark_session_connected");

const nowMillis = Date.parse("2026-05-26T10:00:00Z");
const futureExpiresAt = {
  toMillis: () => Date.parse("2026-05-26T10:05:00Z"),
};

function acceptedSession(overrides = {}) {
  return {
    status: "active",
    expiresAt: futureExpiresAt,
    requesterId: "student-a",
    tutorId: "teacher-b",
    participantIds: ["student-a", "teacher-b"],
    ...overrides,
  };
}

test("normalizeSessionId trims strings and rejects non-strings", () => {
  assert.equal(normalizeSessionId("  session-1  "), "session-1");
  assert.equal(normalizeSessionId(123), "");
  assert.equal(normalizeSessionId(null), "");
  assert.equal(normalizeSessionId("videoSessions/session-1"), "");
  assert.equal(normalizeSessionId("session-1/nested"), "");
  assert.equal(normalizeSessionId("__session__"), "");
  assert.equal(normalizeSessionId("."), "");
  assert.equal(normalizeSessionId(".."), "");
});

test("readSessionMetadata only returns map-like metadata", () => {
  assert.deepEqual(
    readSessionMetadata({ sessionMetadata: { locale: "en" } }),
    { locale: "en" },
  );
  assert.deepEqual(readSessionMetadata({ sessionMetadata: ["bad"] }), {});
  assert.deepEqual(readSessionMetadata({ sessionMetadata: "bad" }), {});
});

test("readConnectedSignals only returns map-like signal metadata", () => {
  assert.deepEqual(
    readConnectedSignals({ connectedParticipantSignals: { "student-a": {} } }),
    { "student-a": {} },
  );
  assert.deepEqual(
    readConnectedSignals({ connectedParticipantSignals: ["bad"] }),
    {},
  );
  assert.deepEqual(
    readConnectedSignals({ connectedParticipantSignals: "bad" }),
    {},
  );
});

test("first accepted participant records a signal without starting billing", () => {
  const serverTimestamp = Symbol("serverTimestamp");
  const decision = buildMarkSessionConnectedDecision({
    sessionData: acceptedSession({
      sessionMetadata: {
        dailyRoomName: "room-a",
      },
    }),
    userId: "teacher-b",
    nowMillis,
    serverTimestamp,
  });

  assert.equal(decision.ok, true);
  assert.deepEqual(decision.response, {
    status: "signal_recorded",
    updated: true,
    connectedMarked: false,
    dailyPresenceVerificationRequired: false,
  });
  assert.equal(Object.hasOwn(decision.update, "startedAt"), false);
  assert.deepEqual(decision.update.sessionMetadata, {
    dailyRoomName: "room-a",
    connectedParticipantSignals: {
      "teacher-b": {
        markedAt: serverTimestamp,
        source: "markSessionConnected",
      },
    },
    callConnectedSignalParticipantIds: ["student-a", "teacher-b"],
    connectedParticipantSignalsComplete: false,
  });
});

test("second accepted participant waits for Daily verified connected update", () => {
  const serverTimestamp = Symbol("serverTimestamp");
  const existingTeacherSignal = {
    markedAt: { toMillis: () => nowMillis - 1000 },
    source: "markSessionConnected",
  };
  const decision = buildMarkSessionConnectedDecision({
    sessionData: acceptedSession({
      sessionMetadata: {
        dailyRoomName: "room-a",
        connectedParticipantSignals: {
          "teacher-b": existingTeacherSignal,
        },
      },
    }),
    userId: "student-a",
    nowMillis,
    serverTimestamp,
  });

  assert.equal(decision.ok, true);
  assert.deepEqual(decision.response, {
    status: "signal_recorded",
    updated: true,
    connectedMarked: false,
    dailyPresenceVerificationRequired: true,
  });
  assert.equal(Object.hasOwn(decision.update, "startedAt"), false);
  assert.deepEqual(decision.update.sessionMetadata, {
    dailyRoomName: "room-a",
    connectedParticipantSignals: {
      "teacher-b": existingTeacherSignal,
      "student-a": {
        markedAt: serverTimestamp,
        source: "markSessionConnected",
      },
    },
    callConnectedSignalParticipantIds: ["student-a", "teacher-b"],
    connectedParticipantSignalsComplete: true,
  });
});

test("existing connected marker is idempotent and not overwritten", () => {
  const existingConnectedAt = {
    toMillis: () => Date.parse("2026-05-26T10:01:00Z"),
  };
  const decision = buildMarkSessionConnectedDecision({
    sessionData: acceptedSession({
      sessionMetadata: {
        callConnectedAt: existingConnectedAt,
      },
    }),
    userId: "student-a",
    nowMillis,
    serverTimestamp: Symbol("serverTimestamp"),
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update, null);
  assert.deepEqual(decision.response, {
    status: "already_marked",
    updated: false,
  });
});

test("client signals never promote startedAt to connected state", () => {
  const startedAt = {
    toMillis: () => Date.parse("2026-05-26T10:00:30Z"),
  };
  const decision = buildMarkSessionConnectedDecision({
    sessionData: acceptedSession({
      startedAt,
      sessionMetadata: {
        connectedParticipantSignals: {
          "teacher-b": {
            markedAt: { toMillis: () => nowMillis - 1000 },
            source: "markSessionConnected",
          },
        },
      },
    }),
    userId: "student-a",
    nowMillis,
    serverTimestamp: Symbol("serverTimestamp"),
  });

  assert.equal(decision.ok, true);
  assert.equal(Object.hasOwn(decision.update, "startedAt"), false);
  assert.equal(decision.update.sessionMetadata.callConnectedAt, undefined);
  assert.equal(decision.response.connectedMarked, false);
  assert.equal(decision.response.dailyPresenceVerificationRequired, true);
});

test("Daily presence verification requires both accepted participants", () => {
  assert.equal(
    dailyPresenceHasAcceptedParticipants({
      presenceData: {
        "room-a": [
          {user_id: "student-a"},
          {userId: "teacher-b"},
          {user_id: "observer-c"},
        ],
      },
      roomName: "room-a",
      participantIds: ["student-a", "teacher-b"],
    }),
    true,
  );
  assert.equal(
    dailyPresenceHasAcceptedParticipants({
      presenceData: {participants: [{user_id: "student-a"}]},
      roomName: "room-a",
      participantIds: ["student-a", "teacher-b"],
    }),
    false,
  );
});

test("Daily verified presence writes the connected marker", () => {
  const serverTimestamp = Symbol("serverTimestamp");
  const decision = buildDailyPresenceConnectedDecision({
    sessionData: acceptedSession({
      dailyRoomName: "room-a",
      sessionMetadata: {
        connectedParticipantSignalsComplete: true,
      },
    }),
    presenceData: {
      "room-a": [
        {user_id: "student-a"},
        {userId: "teacher-b"},
      ],
    },
    userId: "student-a",
    nowMillis,
    serverTimestamp,
  });

  assert.equal(decision.ok, true);
  assert.deepEqual(decision.response, {
    status: "marked",
    updated: true,
    connectedMarked: true,
    startedAtMarked: true,
  });
  assert.equal(decision.update.startedAt, serverTimestamp);
  assert.equal(decision.update.sessionMetadata.callConnectedAt, serverTimestamp);
  assert.equal(
    decision.update.sessionMetadata.callConnectedAtSource,
    "dailyPresenceTwoParty",
  );
  assert.deepEqual(
    decision.update.sessionMetadata.dailyPresenceConnectedParticipantIds,
    ["student-a", "teacher-b"],
  );
  assert.equal(decision.update.sessionMetadata.dailyPresenceRoomName, "room-a");
});

test("Daily presence miss remains fail-closed", () => {
  const decision = buildDailyPresenceConnectedDecision({
    sessionData: acceptedSession({dailyRoomName: "room-a"}),
    presenceData: {"room-a": [{user_id: "student-a"}]},
    userId: "student-a",
    nowMillis,
    serverTimestamp: Symbol("serverTimestamp"),
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update, null);
  assert.deepEqual(decision.response, {
    status: "daily_presence_not_verified",
    updated: false,
    connectedMarked: false,
  });
});

test("nonparticipant cannot mark a session connected", () => {
  const decision = buildMarkSessionConnectedDecision({
    sessionData: acceptedSession(),
    userId: "stranger",
    nowMillis,
  });

  assert.equal(decision.ok, false);
  assert.equal(decision.code, "permission-denied");
});

test("non-joinable sessions cannot be marked connected", () => {
  const endedDecision = buildMarkSessionConnectedDecision({
    sessionData: acceptedSession({ status: "ended" }),
    userId: "student-a",
    nowMillis,
  });
  const expiredDecision = buildMarkSessionConnectedDecision({
    sessionData: acceptedSession({
      expiresAt: {
        toMillis: () => Date.parse("2026-05-26T09:59:00Z"),
      },
    }),
    userId: "student-a",
    nowMillis,
  });

  assert.equal(endedDecision.ok, false);
  assert.equal(endedDecision.code, "failed-precondition");
  assert.equal(expiredDecision.ok, false);
  assert.equal(expiredDecision.code, "failed-precondition");
});

test("sessions without two accepted participants cannot be marked connected", () => {
  const decision = buildMarkSessionConnectedDecision({
    sessionData: acceptedSession({
      tutorId: null,
      participantIds: ["student-a"],
      matchContext: {},
    }),
    userId: "student-a",
    nowMillis,
  });

  assert.equal(decision.ok, false);
  assert.equal(decision.code, "failed-precondition");
});

test("markSessionConnected source keeps strict callable contract", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "mark_session_connected.js"),
    "utf8",
  );

  assert.match(source, /\.runWith\(\{\s*secrets:\s*dailySecrets\s*\}\)/);
  assert.match(source, /\.https\s*\.onCall/);
  assert.match(source, /context\.auth/);
  assert.match(source, /getAcceptedSessionCredentialParticipantIds/);
  assert.match(source, /isAcceptedSessionCredentialParticipant/);
  assert.match(source, /isCredentialSessionJoinable/);
  assert.match(source, /getDailyRoomPresence/);
  assert.match(source, /runTransaction\(async \(transaction\) => \{/);
  assert.match(source, /callConnectedAtSource:\s*"dailyPresenceTwoParty"/);
  assert.doesNotMatch(
    source,
    /callConnectedAtSource:\s*"markSessionConnectedTwoParty"/,
  );
  assert.match(source, /connectedParticipantSignals/);
  assert.match(source, /connectedParticipantSignalsComplete/);
  assert.doesNotMatch(source, /isSessionParticipant\(sessionData,\s*userId\)/);
  assert.doesNotMatch(source, /HttpsError\("not-found",\s*"Session not found"/);
});

test("index exports markSessionConnected callable", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "index.js"),
    "utf8",
  );

  assert.match(
    source,
    /const markSessionConnected = require\("\.\/mark_session_connected\.js"\);/,
  );
  assert.match(
    source,
    /exports\.markSessionConnected = markSessionConnected\.markSessionConnected;/,
  );
});
