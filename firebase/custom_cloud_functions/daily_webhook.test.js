const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    buildDailyWebhookSessionUpdate,
    computeDailyWebhookSignature,
    findCandidateSessionDoc,
    isValidDailyWebhookSignature,
    isDailyWebhookVerificationRequest,
    maybeHandleDailyWebhookVerificationRequest,
    parseDailyWebhookEvent,
  },
} = require("./daily_webhook");

const NOW_MILLIS = Date.parse("2026-05-26T12:00:00.000Z");
const NOW_SECONDS = Math.floor(NOW_MILLIS / 1000);
const SECRET = Buffer.from("daily-webhook-secret").toString("base64");
const futureExpiresAt = {
  toMillis: () => NOW_MILLIS + 5 * 60 * 1000,
};

function dailyEvent(overrides = {}) {
  return {
    version: "1.0.0",
    type: "participant.joined",
    id: "ptcpt-join-event-a",
    payload: {
      room: "session_room_a",
      user_id: "student-a",
      user_name: "Student A",
      session_id: "daily-session-a",
      joined_at: NOW_SECONDS + 1,
      owner: true,
    },
    event_ts: NOW_SECONDS + 1,
    ...overrides,
    payload: {
      room: "session_room_a",
      user_id: "student-a",
      user_name: "Student A",
      session_id: "daily-session-a",
      joined_at: NOW_SECONDS + 1,
      owner: true,
      ...(overrides.payload || {}),
    },
  };
}

function activeSession(overrides = {}) {
  return {
    status: "active",
    dailyRoomName: "session_room_a",
    expiresAt: futureExpiresAt,
    requesterId: "student-a",
    tutorId: "teacher-b",
    participantIds: ["student-a", "teacher-b"],
    sessionMetadata: {},
    ...overrides,
  };
}

function twoPartyPresence() {
  return {
    roomName: "session_room_a",
    participants: [
      {user_id: "student-a"},
      {user_id: "teacher-b"},
    ],
    count: 2,
  };
}

function makeDoc(id, data) {
  return {
    id,
    ref: {path: `videoSessions/${id}`},
    data: () => data,
  };
}

function makeSnapshot(docs) {
  return {
    forEach(callback) {
      docs.forEach(callback);
    },
  };
}

test("daily webhook signatures use Daily timestamp/event HMAC contract", () => {
  const event = dailyEvent();
  const signature = computeDailyWebhookSignature({
    event,
    secret: SECRET,
    timestampHeader: String(NOW_SECONDS),
  });

  assert.equal(
    isValidDailyWebhookSignature({
      event,
      secret: SECRET,
      signatureHeader: signature,
      timestampHeader: String(NOW_SECONDS),
      nowMillis: NOW_MILLIS,
    }),
    true,
  );
  assert.equal(
    isValidDailyWebhookSignature({
      event,
      secret: SECRET,
      signatureHeader: "bad-signature",
      timestampHeader: String(NOW_SECONDS),
      nowMillis: NOW_MILLIS,
    }),
    false,
  );
  assert.equal(
    isValidDailyWebhookSignature({
      event,
      secret: SECRET,
      signatureHeader: signature,
      timestampHeader: String(NOW_SECONDS - 60 * 60),
      nowMillis: NOW_MILLIS,
    }),
    false,
  );
});

test("daily webhook accepts Daily create verification body", () => {
  assert.equal(isDailyWebhookVerificationRequest({test: "test"}), true);
  assert.equal(isDailyWebhookVerificationRequest({test: "no"}), false);
  assert.equal(isDailyWebhookVerificationRequest({}), false);
  assert.equal(isDailyWebhookVerificationRequest(null), null);
});

test("daily webhook verification body returns 200 through response helper", () => {
  const response = {
    statusCode: null,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    send(body) {
      this.body = body;
      return this;
    },
  };

  assert.equal(
    maybeHandleDailyWebhookVerificationRequest(
      {body: {test: "test"}},
      response,
    ),
    true,
  );
  assert.equal(response.statusCode, 200);
  assert.equal(response.body, "OK");
});

test("daily participant.joined events are parsed to the minimal contract", () => {
  const parsed = parseDailyWebhookEvent(dailyEvent());

  assert.equal(parsed.type, "participant.joined");
  assert.equal(parsed.eventId, "ptcpt-join-event-a");
  assert.equal(parsed.roomName, "session_room_a");
  assert.equal(parsed.userId, "student-a");
  assert.equal(parsed.dailySessionId, "daily-session-a");
  assert.equal(parsed.joinedAtMillis, (NOW_SECONDS + 1) * 1000);
  assert.equal(parsed.eventTsMillis, (NOW_SECONDS + 1) * 1000);
  assert.equal(parsed.owner, true);
  assert.equal(parseDailyWebhookEvent({type: "participant.joined"}), null);
});

test("first Daily participant signal does not mark connected billing state", () => {
  const receivedAt = Symbol("receivedAt");
  const decision = buildDailyWebhookSessionUpdate({
    event: parseDailyWebhookEvent(dailyEvent()),
    sessionData: activeSession(),
    nowMillis: NOW_MILLIS,
    receivedAt,
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.reason, "daily_signal_recorded");
  assert.equal(decision.connectedMarked, false);
  assert.equal(Object.hasOwn(decision.update, "startedAt"), false);
  assert.equal(decision.update.sessionMetadata.callConnectedAt, undefined);
  assert.deepEqual(
    decision.update.sessionMetadata.dailyWebhookParticipantSignals["student-a"],
    {
      eventId: "ptcpt-join-event-a",
      dailySessionId: "daily-session-a",
      joinedAt: decision
        .update
        .sessionMetadata
        .dailyWebhookParticipantSignals["student-a"]
        .joinedAt,
      eventTs: decision
        .update
        .sessionMetadata
        .dailyWebhookParticipantSignals["student-a"]
        .eventTs,
      owner: true,
      source: "dailyWebhook",
      receivedAt,
    },
  );
});

test("second Daily participant signal marks server-verified connected state", () => {
  const event = parseDailyWebhookEvent(dailyEvent({
    id: "ptcpt-join-event-b",
    payload: {
      user_id: "teacher-b",
      user_name: "Teacher B",
      session_id: "daily-session-b",
      joined_at: NOW_SECONDS + 8,
      owner: false,
    },
    event_ts: NOW_SECONDS + 8,
  }));
  const firstJoinedAt = {
    toMillis: () => (NOW_SECONDS + 1) * 1000,
  };
  const decision = buildDailyWebhookSessionUpdate({
    event,
    sessionData: activeSession({
      sessionMetadata: {
        dailyWebhookParticipantSignals: {
          "student-a": {
            eventId: "ptcpt-join-event-a",
            dailySessionId: "daily-session-a",
            joinedAt: firstJoinedAt,
            source: "dailyWebhook",
          },
        },
      },
    }),
    presenceData: twoPartyPresence(),
    nowMillis: NOW_MILLIS,
    receivedAt: Symbol("receivedAt"),
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.reason, "daily_connected_marked");
  assert.equal(decision.connectedMarked, true);
  assert.equal(decision.update.status, "active");
  assert.equal(decision.update.startedAt.toMillis(), (NOW_SECONDS + 8) * 1000);
  assert.equal(
    decision.update.sessionMetadata.callConnectedAt.toMillis(),
    (NOW_SECONDS + 8) * 1000,
  );
  assert.equal(
    decision.update.sessionMetadata.callConnectedAtSource,
    "dailyWebhookTwoParty",
  );
  assert.deepEqual(
    decision.update.sessionMetadata.dailyWebhookConnectedParticipantIds,
    ["student-a", "teacher-b"],
  );
  assert.deepEqual(
    decision.update.sessionMetadata.dailyWebhookConnectedEventIds,
    ["ptcpt-join-event-a", "ptcpt-join-event-b"],
  );
});

test("Daily webhook promotes connecting sessions to active after both join", () => {
  const event = parseDailyWebhookEvent(dailyEvent({
    id: "ptcpt-join-event-b",
    payload: {
      user_id: "teacher-b",
      session_id: "daily-session-b",
      joined_at: NOW_SECONDS + 8,
    },
    event_ts: NOW_SECONDS + 8,
  }));
  const decision = buildDailyWebhookSessionUpdate({
    event,
    sessionData: activeSession({
      status: "connecting",
      sessionMetadata: {
        dailyWebhookParticipantSignals: {
          "student-a": {
            eventId: "ptcpt-join-event-a",
            joinedAt: {
              toMillis: () => (NOW_SECONDS + 1) * 1000,
            },
            source: "dailyWebhook",
          },
        },
      },
    }),
    presenceData: twoPartyPresence(),
    nowMillis: NOW_MILLIS,
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update.status, "active");
  assert.equal(decision.connectedMarked, true);
});

test("second Daily participant signal stays advisory without current presence", () => {
  const event = parseDailyWebhookEvent(dailyEvent({
    id: "ptcpt-join-event-b",
    payload: {
      user_id: "teacher-b",
      user_name: "Teacher B",
      session_id: "daily-session-b",
      joined_at: NOW_SECONDS + 8,
      owner: false,
    },
    event_ts: NOW_SECONDS + 8,
  }));
  const decision = buildDailyWebhookSessionUpdate({
    event,
    sessionData: activeSession({
      sessionMetadata: {
        dailyWebhookParticipantSignals: {
          "student-a": {
            eventId: "ptcpt-join-event-a",
            dailySessionId: "daily-session-a",
            joinedAt: {
              toMillis: () => (NOW_SECONDS + 1) * 1000,
            },
            source: "dailyWebhook",
          },
        },
      },
    }),
    presenceData: {
      roomName: "session_room_a",
      participants: [{user_id: "teacher-b"}],
      count: 1,
    },
    nowMillis: NOW_MILLIS,
    receivedAt: Symbol("receivedAt"),
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.reason, "daily_signal_recorded_presence_required");
  assert.equal(decision.connectedMarked, false);
  assert.equal(Object.hasOwn(decision.update, "startedAt"), false);
  assert.equal(decision.update.sessionMetadata.callConnectedAt, undefined);
  assert.equal(
    decision.update.sessionMetadata.dailyWebhookConnectedAt,
    undefined,
  );
});

test("Daily webhook evidence never overwrites existing connected marker", () => {
  const existingConnectedAt = {
    toMillis: () => NOW_MILLIS - 1000,
  };
  const decision = buildDailyWebhookSessionUpdate({
    event: parseDailyWebhookEvent(dailyEvent({
      payload: {
        user_id: "teacher-b",
        session_id: "daily-session-b",
      },
    })),
    sessionData: activeSession({
      startedAt: existingConnectedAt,
      sessionMetadata: {
        callConnectedAt: existingConnectedAt,
        callConnectedAtSource: "dailyPresenceTwoParty",
        dailyWebhookParticipantSignals: {
          "student-a": {
            eventId: "ptcpt-join-event-a",
            joinedAt: {
              toMillis: () => NOW_MILLIS,
            },
          },
        },
      },
    }),
    presenceData: twoPartyPresence(),
    nowMillis: NOW_MILLIS,
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.connectedMarked, false);
  assert.equal(Object.hasOwn(decision.update, "startedAt"), false);
  assert.equal(
    decision.update.sessionMetadata.callConnectedAt,
    existingConnectedAt,
  );
  assert.equal(
    decision.update.sessionMetadata.callConnectedAtSource,
    "dailyPresenceTwoParty",
  );
  assert.ok(decision.update.sessionMetadata.dailyWebhookConnectedAt);
});

test("Daily webhook update rejects nonparticipants and non-joinable sessions", () => {
  const event = parseDailyWebhookEvent(dailyEvent());

  assert.deepEqual(
    buildDailyWebhookSessionUpdate({
      event: parseDailyWebhookEvent(dailyEvent({
        payload: {user_id: "stranger"},
      })),
      sessionData: activeSession(),
      nowMillis: NOW_MILLIS,
    }),
    {
      ok: false,
      reason: "not_session_participant",
      update: null,
    },
  );
  assert.deepEqual(
    buildDailyWebhookSessionUpdate({
      event,
      sessionData: activeSession({status: "ended"}),
      nowMillis: NOW_MILLIS,
    }),
    {
      ok: false,
      reason: "session_not_joinable",
      update: null,
    },
  );
  assert.equal(
    buildDailyWebhookSessionUpdate({
      event,
      sessionData: activeSession({
        tutorId: null,
        participantIds: ["student-a"],
      }),
      nowMillis: NOW_MILLIS,
    }).reason,
    "accepted_participants_incomplete",
  );
});

test("Daily webhook session lookup requires exactly one matching candidate", () => {
  const event = parseDailyWebhookEvent(dailyEvent());
  const validDoc = makeDoc("session-a", activeSession());
  const invalidDoc = makeDoc("session-b", activeSession({status: "ended"}));

  assert.equal(
    findCandidateSessionDoc(makeSnapshot([validDoc, invalidDoc]), event),
    validDoc,
  );
  assert.equal(
    findCandidateSessionDoc(makeSnapshot([validDoc, validDoc]), event),
    null,
  );
  assert.equal(
    findCandidateSessionDoc(makeSnapshot([invalidDoc]), event),
    null,
  );
});

test("daily webhook receiver keeps a strict private webhook contract", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "daily_webhook.js"),
    "utf8",
  );
  const indexSource = fs.readFileSync(
    path.join(__dirname, "index.js"),
    "utf8",
  );

  assert.match(source, /defineSecret\("DAILY_WEBHOOK_SECRET"\)/);
  assert.match(source, /x-webhook-timestamp/);
  assert.match(source, /x-webhook-signature/);
  assert.match(source, /crypto\.timingSafeEqual/);
  assert.match(source, /"participant\.joined"/);
  const verificationHandlerIndex = source.indexOf(
    "if (maybeHandleDailyWebhookVerificationRequest(req, res))",
  );
  const secretReadIndex = source.indexOf("dailyWebhookSecret.value()");
  assert.notEqual(verificationHandlerIndex, -1);
  assert.notEqual(secretReadIndex, -1);
  assert.ok(verificationHandlerIndex < secretReadIndex);
  assert.match(source, /getDailyRoomPresence/);
  assert.match(source, /dailyPresenceHasAcceptedParticipants/);
  assert.match(source, /where\("dailyRoomName",\s*"==",\s*event\.roomName\)/);
  assert.match(source, /isAcceptedSessionCredentialParticipant/);
  assert.match(source, /isCredentialSessionJoinable/);
  assert.match(source, /callConnectedAtSource\s*=\s*"dailyWebhookTwoParty"/);
  assert.match(indexSource, /exports\.dailyWebhook\s*=/);
});
