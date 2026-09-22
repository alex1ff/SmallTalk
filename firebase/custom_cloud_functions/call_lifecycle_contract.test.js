const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  __private__: {
    buildDailyWebhookSessionUpdate,
  },
} = require("./daily_webhook");
const {
  __private__: {
    buildDailyPresenceConnectedDecision,
    buildMarkSessionConnectedDecision,
  },
} = require("./mark_session_connected");
const {
  __private__: {
    buildCancelCallSessionUpdate,
  },
} = require("./cancel_call");
const {
  __private__: {
    buildNoAvailableResponderSessionUpdate,
  },
} = require("./create_video_session");
const {
  __private__: {
    buildExpiredSessionCleanupPayload,
    buildPendingResponseTimeoutSessionUpdate,
  },
} = require("./cleanup_expired_sessions");

const ABSENT = "ABSENT";
const TERMINAL_STATUSES = new Set([
  VIDEO_SESSION_STATUS.CANCELLED,
  VIDEO_SESSION_STATUS.EXPIRED,
  VIDEO_SESSION_STATUS.ENDED,
]);
const SESSION_TRANSITIONS = Object.freeze([
  [ABSENT, VIDEO_SESSION_STATUS.PENDING_CONFIRMATION],
  [ABSENT, VIDEO_SESSION_STATUS.SEARCHING],
  [VIDEO_SESSION_STATUS.SEARCHING, VIDEO_SESSION_STATUS.PENDING_CONFIRMATION],
  [VIDEO_SESSION_STATUS.SEARCHING, VIDEO_SESSION_STATUS.CONNECTING],
  [VIDEO_SESSION_STATUS.SEARCHING, VIDEO_SESSION_STATUS.CANCELLED],
  [VIDEO_SESSION_STATUS.SEARCHING, VIDEO_SESSION_STATUS.EXPIRED],
  [VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
    VIDEO_SESSION_STATUS.PENDING_CONFIRMATION],
  [VIDEO_SESSION_STATUS.PENDING_CONFIRMATION, VIDEO_SESSION_STATUS.CONNECTING],
  [VIDEO_SESSION_STATUS.PENDING_CONFIRMATION, VIDEO_SESSION_STATUS.CANCELLED],
  [VIDEO_SESSION_STATUS.PENDING_CONFIRMATION, VIDEO_SESSION_STATUS.EXPIRED],
  [VIDEO_SESSION_STATUS.CONNECTING, VIDEO_SESSION_STATUS.ACTIVE],
  [VIDEO_SESSION_STATUS.CONNECTING, VIDEO_SESSION_STATUS.CANCELLED],
  [VIDEO_SESSION_STATUS.CONNECTING, VIDEO_SESSION_STATUS.EXPIRED],
  [VIDEO_SESSION_STATUS.CONNECTING, VIDEO_SESSION_STATUS.ENDED],
  [VIDEO_SESSION_STATUS.ACTIVE, VIDEO_SESSION_STATUS.ENDED],
]);
const USER_VISIBLE_RESULTS = new Map([
  [`${ABSENT}->${VIDEO_SESSION_STATUS.PENDING_CONFIRMATION}`, "found"],
  [`${ABSENT}->${VIDEO_SESSION_STATUS.SEARCHING}`, "searching"],
  [`${VIDEO_SESSION_STATUS.SEARCHING}->${VIDEO_SESSION_STATUS.PENDING_CONFIRMATION}`, "found"],
  [`${VIDEO_SESSION_STATUS.SEARCHING}->${VIDEO_SESSION_STATUS.CONNECTING}`, "connecting"],
  [`${VIDEO_SESSION_STATUS.SEARCHING}->${VIDEO_SESSION_STATUS.CANCELLED}`, "stopped"],
  [`${VIDEO_SESSION_STATUS.SEARCHING}->${VIDEO_SESSION_STATUS.EXPIRED}`, "retry"],
  [`${VIDEO_SESSION_STATUS.PENDING_CONFIRMATION}->${VIDEO_SESSION_STATUS.PENDING_CONFIRMATION}`, "next"],
  [`${VIDEO_SESSION_STATUS.PENDING_CONFIRMATION}->${VIDEO_SESSION_STATUS.CONNECTING}`, "connecting"],
  [`${VIDEO_SESSION_STATUS.PENDING_CONFIRMATION}->${VIDEO_SESSION_STATUS.CANCELLED}`, "cancelled"],
  [`${VIDEO_SESSION_STATUS.PENDING_CONFIRMATION}->${VIDEO_SESSION_STATUS.EXPIRED}`, "expired"],
  [`${VIDEO_SESSION_STATUS.CONNECTING}->${VIDEO_SESSION_STATUS.ACTIVE}`, "call"],
  [`${VIDEO_SESSION_STATUS.CONNECTING}->${VIDEO_SESSION_STATUS.CANCELLED}`, "retry"],
  [`${VIDEO_SESSION_STATUS.CONNECTING}->${VIDEO_SESSION_STATUS.EXPIRED}`, "retry"],
  [`${VIDEO_SESSION_STATUS.CONNECTING}->${VIDEO_SESSION_STATUS.ENDED}`, "summary"],
  [`${VIDEO_SESSION_STATUS.ACTIVE}->${VIDEO_SESSION_STATUS.ENDED}`, "summary"],
]);

function transitionKey(from, to) {
  return `${from}->${to}`;
}

function isAllowedTransition(from, to) {
  return SESSION_TRANSITIONS.some(([source, target]) =>
    source === from && target === to,
  );
}

function dailyEvent(userId = "student-a") {
  return {
    type: "participant.joined",
    eventId: `event-${userId}`,
    roomName: "room-a",
    userId,
    dailySessionId: `daily-${userId}`,
    eventTsMillis: Date.parse("2026-05-26T12:00:08Z"),
    joinedAtMillis: Date.parse("2026-05-26T12:00:08Z"),
    owner: true,
  };
}

test("lifecycle matrix has a single source of session status truth", () => {
  const statuses = new Set(Object.values(VIDEO_SESSION_STATUS));
  for (const [from, to] of SESSION_TRANSITIONS) {
    assert.equal(
        from === ABSENT || statuses.has(from),
        true,
        `unknown source status ${from}`,
    );
    assert.equal(statuses.has(to), true, `unknown target status ${to}`);
    assert.equal(USER_VISIBLE_RESULTS.has(transitionKey(from, to)), true);
  }
  assert.equal(USER_VISIBLE_RESULTS.size, SESSION_TRANSITIONS.length);
});

test("lifecycle matrix allows only characterized transitions", () => {
  assert.equal(
      isAllowedTransition(
          VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
          VIDEO_SESSION_STATUS.CONNECTING,
      ),
      true,
  );
  assert.equal(
      isAllowedTransition(
          VIDEO_SESSION_STATUS.ACTIVE,
          VIDEO_SESSION_STATUS.CONNECTING,
      ),
      false,
  );
  assert.equal(
      isAllowedTransition(
          VIDEO_SESSION_STATUS.ENDED,
          VIDEO_SESSION_STATUS.ACTIVE,
      ),
      false,
  );
  for (const terminal of TERMINAL_STATUSES) {
    for (const status of Object.values(VIDEO_SESSION_STATUS)) {
      if (status !== terminal) {
        assert.equal(isAllowedTransition(terminal, status), false);
      }
    }
  }
});

test("Daily and callable connection owners share server-truth contracts", () => {
  const dailyDecision = buildDailyWebhookSessionUpdate({
    event: dailyEvent(),
    sessionData: {
      status: VIDEO_SESSION_STATUS.CONNECTING,
      dailyRoomName: "room-a",
      expiresAt: {toMillis: () => Date.parse("2026-05-26T12:05:00Z")},
      joinDeadlineAt: {toMillis: () => Date.parse("2026-05-26T12:01:00Z")},
      requesterId: "student-a",
      tutorId: "teacher-b",
      participantIds: ["student-a", "teacher-b"],
      sessionMetadata: {},
    },
    nowMillis: Date.parse("2026-05-26T12:00:00Z"),
  });
  assert.equal(dailyDecision.ok, true);
  assert.equal(dailyDecision.update.status, undefined);
  assert.equal(dailyDecision.update.sessionMetadata.callConnectedAt, undefined);

  const markDecision = buildMarkSessionConnectedDecision({
    sessionData: {
      status: VIDEO_SESSION_STATUS.ACTIVE,
      expiresAt: {toMillis: () => Date.parse("2026-05-26T12:05:00Z")},
      requesterId: "student-a",
      tutorId: "teacher-b",
      participantIds: ["student-a", "teacher-b"],
      sessionMetadata: {},
    },
    userId: "teacher-b",
    nowMillis: Date.parse("2026-05-26T12:00:00Z"),
    serverTimestamp: Symbol("serverTimestamp"),
  });
  assert.equal(markDecision.ok, true);
  assert.equal(markDecision.response.status, "signal_recorded");
  assert.equal(markDecision.response.connectedMarked, false);
});

test("production owner decisions emit characterized terminal transitions", () => {
  const marker = Symbol("serverTimestamp");
  assert.equal(
      buildCancelCallSessionUpdate({
        cancelledBy: "student-a",
        serverTimestamp: marker,
        fieldDelete: Symbol("delete"),
      }).status,
      VIDEO_SESSION_STATUS.CANCELLED,
  );
  assert.equal(
      buildNoAvailableResponderSessionUpdate([]).status,
      VIDEO_SESSION_STATUS.CANCELLED,
  );
  assert.equal(
      buildPendingResponseTimeoutSessionUpdate({
        endedAtMillis: Date.parse("2026-05-26T12:01:00Z"),
      }).status,
      VIDEO_SESSION_STATUS.EXPIRED,
  );
  const ended = buildExpiredSessionCleanupPayload({
    db: null,
    sessionId: "session-a",
    sessionRef: {path: "videoSessions/session-a"},
    sessionData: {
      status: VIDEO_SESSION_STATUS.ACTIVE,
      startedAt: {toMillis: () => Date.parse("2026-05-26T12:00:00Z")},
      sessionMetadata: {
        callConnectedAt: {toMillis: () => Date.parse("2026-05-26T12:00:00Z")},
      },
    },
    endedAtMillis: Date.parse("2026-05-26T12:01:00Z"),
  });
  assert.equal(ended.sessionUpdate.status, VIDEO_SESSION_STATUS.ENDED);

  const active = buildDailyPresenceConnectedDecision({
    sessionData: {
      status: VIDEO_SESSION_STATUS.CONNECTING,
      dailyRoomName: "room-a",
      expiresAt: {toMillis: () => Date.parse("2026-05-26T12:05:00Z")},
      joinDeadlineAt: {toMillis: () => Date.parse("2026-05-26T12:01:00Z")},
      requesterId: "student-a",
      tutorId: "teacher-b",
      participantIds: ["student-a", "teacher-b"],
      sessionMetadata: {},
    },
    presenceData: {
      roomName: "room-a",
      count: 2,
      participants: [{user_id: "student-a"}, {user_id: "teacher-b"}],
    },
    userId: "teacher-b",
    nowMillis: Date.parse("2026-05-26T12:00:00Z"),
    serverTimestamp: marker,
  });
  assert.equal(active.ok, true);
  assert.equal(active.update.status, VIDEO_SESSION_STATUS.ACTIVE);
});

test("connection owners wire the shared trial evidence helper", () => {
  const dailySource = fs.readFileSync(
      path.join(__dirname, "daily_webhook.js"),
      "utf8",
  );
  const markSource = fs.readFileSync(
      path.join(__dirname, "mark_session_connected.js"),
      "utf8",
  );
  for (const source of [dailySource, markSource]) {
    assert.match(source, /markSessionTrialCallContextsConnectedInTransaction/);
  }
  assert.match(
      dailySource,
      /decision\.connectedMarked === true[\s\S]*markSessionTrialCallContextsConnectedInTransaction/,
  );
  assert.match(
      markSource,
      /shouldMarkTrialConnection[\s\S]*markSessionTrialCallContextsConnectedInTransaction/,
  );
});

test("acceptCall keeps connected as a response, not a session status", () => {
  const acceptSource = fs.readFileSync(
      path.join(__dirname, "accept_call.js"),
      "utf8",
  );
  assert.match(acceptSource, /return \{[\s\S]*status: "connected"/);
  assert.equal(
      Object.values(VIDEO_SESSION_STATUS).includes("connected"),
      false,
  );
});

test("Flutter timer wiring uses the tested server-status gate", () => {
  const policySource = fs.readFileSync(
      path.join(__dirname, "../../lib/custom_code/widgets/session_limit_ui.dart"),
      "utf8",
  );
  const widgetSource = fs.readFileSync(
      path.join(__dirname, "../../lib/custom_code/widgets/minimal_daily_widget.dart"),
      "utf8",
  );
  const pageSource = fs.readFileSync(
      path.join(
          __dirname,
          "../../lib/shared_pages/video_call_page/video_call_page_widget.dart",
      ),
      "utf8",
  );
  assert.match(policySource, /bool shouldRunCallDurationTimer\(/);
  assert.match(policySource, /toLowerCase\(\) == 'active'/);
  assert.match(policySource, /isDailyConnected/);
  assert.match(policySource, /hasRemoteParticipant/);
  assert.match(policySource, /hasServerConnectedAt/);
  assert.match(policySource, /resolveAuthoritativeCallDurationSeconds\(/);
  assert.ok(
      (widgetSource.match(/shouldRunCallDurationTimer\(/g)?.length || 0) >= 3,
  );
  assert.match(widgetSource, /sessionConnectedAt/);
  assert.match(widgetSource, /_authoritativeCallDurationSeconds\(\)/);
  assert.match(pageSource, /sessionConnectedAt:\s*_connectedCallStartedAt\(/);
  assert.doesNotMatch(
      widgetSource,
      /if \(_state\.connectionState == ConnectionState\.connected\)\s*Positioned\([\s\S]{0,160}_buildCallDurationBadge/,
  );
  assert.match(
      widgetSource,
      /_isTerminalSessionStatus\(widget\.sessionStatus\)[\s\S]*_stopDurationTimer\(\)/,
  );
});
