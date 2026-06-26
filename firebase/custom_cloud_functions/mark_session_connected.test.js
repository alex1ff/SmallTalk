const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    applyVerifiedConnectedSessionWritesInTransaction,
    buildDailyPresenceConnectedDecision,
    buildMarkSessionConnectedDecision,
    dailyPresenceHasAcceptedParticipants,
    normalizeSessionId,
    readSessionMetadata,
    readConnectedSignals,
    readRoomJoinSignals,
    hasRoomJoinSignalForParticipant,
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

test("readRoomJoinSignals only returns map-like room join metadata", () => {
  assert.deepEqual(
    readRoomJoinSignals({
      roomJoinParticipantSignals: {"student-a": {source: "test"}},
    }),
    {"student-a": {source: "test"}},
  );
  assert.deepEqual(
    readRoomJoinSignals({roomJoinParticipantSignals: ["bad"]}),
    {},
  );
  assert.deepEqual(
    readRoomJoinSignals({roomJoinParticipantSignals: "bad"}),
    {},
  );
});

test("hasRoomJoinSignalForParticipant requires signal and joined id", () => {
  assert.equal(
    hasRoomJoinSignalForParticipant({
      roomJoinParticipantSignals: {"student-a": {source: "test"}},
      roomJoinedParticipantIds: ["student-a"],
    }, "student-a"),
    true,
  );
  assert.equal(
    hasRoomJoinSignalForParticipant({
      roomJoinParticipantSignals: {"student-a": {source: "test"}},
      roomJoinedParticipantIds: [],
    }, "student-a"),
    false,
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
    roomJoinParticipantSignals: {
      "teacher-b": {
        joinedAt: serverTimestamp,
        lastSeenAt: serverTimestamp,
        source: "markSessionConnected",
      },
    },
    roomJoinedParticipantIds: ["teacher-b"],
    roomJoinSignalsComplete: false,
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
    roomJoinParticipantSignals: {
      "teacher-b": {
        markedAt: existingTeacherSignal.markedAt,
        joinedAt: existingTeacherSignal.markedAt,
        lastSeenAt: existingTeacherSignal.markedAt,
        source: "markSessionConnected",
      },
      "student-a": {
        joinedAt: serverTimestamp,
        lastSeenAt: serverTimestamp,
        source: "markSessionConnected",
      },
    },
    roomJoinedParticipantIds: ["student-a", "teacher-b"],
    roomJoinSignalsComplete: true,
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

test("existing connected marker records missing room join only", () => {
  const existingConnectedAt = {
    toMillis: () => Date.parse("2026-05-26T10:01:00Z"),
  };
  const serverTimestamp = Symbol("serverTimestamp");
  const decision = buildMarkSessionConnectedDecision({
    sessionData: acceptedSession({
      sessionMetadata: {
        callConnectedAt: existingConnectedAt,
      },
    }),
    userId: "student-a",
    nowMillis,
    serverTimestamp,
  });

  assert.equal(decision.ok, true);
  assert.deepEqual(decision.response, {
    status: "already_marked",
    updated: true,
  });
  assert.equal(decision.update.sessionMetadata.callConnectedAt,
    existingConnectedAt);
  assert.equal(decision.update.sessionMetadata.roomJoinParticipantSignals[
    "student-a"
  ].joinedAt, serverTimestamp);
  assert.equal(Object.hasOwn(decision.update, "startedAt"), false);
});

test("existing connected marker is idempotent when room join exists", () => {
  const existingConnectedAt = {
    toMillis: () => Date.parse("2026-05-26T10:01:00Z"),
  };
  const existingJoinedAt = {
    toMillis: () => Date.parse("2026-05-26T10:00:50Z"),
  };
  const decision = buildMarkSessionConnectedDecision({
    sessionData: acceptedSession({
      sessionMetadata: {
        callConnectedAt: existingConnectedAt,
        roomJoinParticipantSignals: {
          "student-a": {
            joinedAt: existingJoinedAt,
            source: "dailyWebhook",
          },
        },
        roomJoinedParticipantIds: ["student-a"],
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

test("webhook join remains canonical when callable signals later", () => {
  const dailyJoinedAt = {
    toMillis: () => nowMillis - 2000,
  };
  const serverTimestamp = Symbol("serverTimestamp");
  const firstDecision = buildMarkSessionConnectedDecision({
    sessionData: acceptedSession({
      sessionMetadata: {
        dailyWebhookParticipantSignals: {
          "student-a": {
            eventId: "daily-event-a",
            joinedAt: dailyJoinedAt,
            source: "dailyWebhook",
          },
        },
        roomJoinParticipantSignals: {
          "student-a": {
            eventId: "daily-event-a",
            joinedAt: dailyJoinedAt,
            dailyJoinedAt,
            source: "dailyWebhook",
          },
        },
        roomJoinedParticipantIds: ["student-a"],
      },
    }),
    userId: "student-a",
    nowMillis,
    serverTimestamp,
  });

  assert.equal(firstDecision.ok, true);
  assert.equal(firstDecision.update.sessionMetadata.callConnectedAt, undefined);
  assert.equal(Object.hasOwn(firstDecision.update, "startedAt"), false);
  assert.equal(
    firstDecision.update.sessionMetadata.roomJoinParticipantSignals[
      "student-a"
    ].joinedAt,
    dailyJoinedAt,
  );
  assert.equal(
    firstDecision.update.sessionMetadata.roomJoinParticipantSignals[
      "student-a"
    ].source,
    "dailyWebhook",
  );

  const secondDecision = buildMarkSessionConnectedDecision({
    sessionData: acceptedSession({
      sessionMetadata: firstDecision.update.sessionMetadata,
    }),
    userId: "teacher-b",
    nowMillis,
    serverTimestamp,
  });

  assert.equal(secondDecision.ok, true);
  assert.equal(secondDecision.update.sessionMetadata.callConnectedAt, undefined);
  assert.equal(Object.hasOwn(secondDecision.update, "startedAt"), false);
  assert.deepEqual(
    secondDecision.update.sessionMetadata.roomJoinedParticipantIds,
    ["student-a", "teacher-b"],
  );
  assert.equal(
    secondDecision.update.sessionMetadata.roomJoinParticipantSignals[
      "student-a"
    ].joinedAt,
    dailyJoinedAt,
  );
  assert.equal(
    secondDecision.update.sessionMetadata.roomJoinParticipantSignals[
      "teacher-b"
    ].source,
    "markSessionConnected",
  );
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
  assert.equal(decision.update.status, "active");
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

test("Daily verified presence promotes connecting sessions to active", () => {
  const serverTimestamp = Symbol("serverTimestamp");
  const decision = buildDailyPresenceConnectedDecision({
    sessionData: acceptedSession({
      status: "connecting",
      dailyRoomName: "room-a",
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
  assert.equal(decision.update.status, "active");
  assert.equal(decision.update.startedAt, serverTimestamp);
  assert.equal(decision.response.connectedMarked, true);
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
  const roomJoinSource = fs.readFileSync(
    path.join(__dirname, "room_join_signals.js"),
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
  assert.match(source, /buildRoomJoinParticipantMetadata/);
  assert.match(roomJoinSource, /roomJoinParticipantSignals/);
  assert.match(roomJoinSource, /roomJoinedParticipantIds/);
  assert.doesNotMatch(source, /isSessionParticipant\(sessionData,\s*userId\)/);
  assert.doesNotMatch(source, /HttpsError\("not-found",\s*"Session not found"/);
});

test("connected write helper stops search only for Daily verified start", async () => {
  const writes = [];
  const stopCalls = [];
  const sessionRef = {path: "videoSessions/session-a"};
  const transaction = {
    update(ref, data) {
      writes.push({ref, data});
    },
  };
  const activeDecision = {
    update: {status: "active"},
    response: {status: "marked"},
  };

  const activeResult =
    await applyVerifiedConnectedSessionWritesInTransaction({
      db: {},
      transaction,
      sessionRef,
      sessionId: "session-a",
      sessionData: acceptedSession(),
      decision: activeDecision,
      serverTimestamp: "serverTimestamp",
      fieldDelete: "fieldDelete",
      stopSearchRequests: async (args) => {
        stopCalls.push(args);
      },
    });

  assert.deepEqual(activeResult, {
    stoppedSearchRequests: true,
    updatedSession: true,
  });
  assert.equal(stopCalls.length, 1);
  assert.equal(stopCalls[0].sessionId, "session-a");
  assert.equal(stopCalls[0].stopReason, "call_started");
  assert.deepEqual(writes, [{ref: sessionRef, data: activeDecision.update}]);

  writes.length = 0;
  stopCalls.length = 0;
  const signalDecision = {
    update: {sessionMetadata: {connectedParticipantSignals: {}}},
    response: {status: "signal_recorded"},
  };
  const signalResult =
    await applyVerifiedConnectedSessionWritesInTransaction({
      db: {},
      transaction,
      sessionRef,
      sessionId: "session-a",
      sessionData: acceptedSession(),
      decision: signalDecision,
      stopSearchRequests: async (args) => {
        stopCalls.push(args);
      },
    });

  assert.deepEqual(signalResult, {
    stoppedSearchRequests: false,
    updatedSession: true,
  });
  assert.equal(stopCalls.length, 0);
  assert.deepEqual(writes, [{ref: sessionRef, data: signalDecision.update}]);

  writes.length = 0;
  stopCalls.length = 0;
  const alreadyMarkedDecision = {
    update: null,
    response: {status: "already_marked"},
  };
  const alreadyMarkedResult =
    await applyVerifiedConnectedSessionWritesInTransaction({
      db: {},
      transaction,
      sessionRef,
      sessionId: "session-a",
      sessionData: acceptedSession(),
      decision: alreadyMarkedDecision,
      stopSearchRequests: async (args) => {
        stopCalls.push(args);
      },
    });

  assert.deepEqual(alreadyMarkedResult, {
    stoppedSearchRequests: true,
    updatedSession: false,
  });
  assert.equal(stopCalls.length, 1);
  assert.equal(stopCalls[0].sessionId, "session-a");
  assert.deepEqual(writes, []);
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
