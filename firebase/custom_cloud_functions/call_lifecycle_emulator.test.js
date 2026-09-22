const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {
  reserveMatchPairInTransaction,
} = require("./match_pair_lock");
const {
  reconcileSessionTrialCallsInTransaction,
  reconcileTrialCallInTransaction,
  reserveTrialCallInTransaction,
} = require("./trial_access");
const {
  __private__: dailyPrivate,
} = require("./daily_webhook");
const {
  __private__: markPrivate,
} = require("./mark_session_connected");
const {cancelCall} = require("./cancel_call");
const {cleanupExpiredSessions} = require("./cleanup_expired_sessions");
const {endSession} = require("./end_session");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error(
      "FIRESTORE_EMULATOR_HOST is required for call lifecycle emulator tests",
  );
}

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: process.env.GCLOUD_PROJECT || "demo-smalltalk",
  });
}

const db = admin.firestore();
const runId = `lifecycle_${Date.now()}_${process.pid}`;
const touchedRefs = [];
const nowMillis = Date.now();

function timestamp(millis) {
  return admin.firestore.Timestamp.fromMillis(millis);
}

function trialSubscription(expiresAt) {
  return {
    productId: "expatlio_trial_1_Month",
    periodType: "TRIAL",
    expiresAt,
  };
}

function trialData({status = "eligible", callId = null, leaseAt = null} = {}) {
  return {
    trialCallStatus: status,
    trialCallId: callId,
    trialCallWindowExpiresAt: timestamp(nowMillis + 30 * 60 * 1000),
    reservationLeaseExpiresAt: leaseAt,
    attemptCount: status === "eligible" ? 0 : 1,
    technicalRetryCount: 0,
  };
}

function searchRequest(userId, sessionId = null) {
  return {
    requestId: `request-${userId}`,
    userId,
    role: "student",
    language: "en",
    filters: {},
    status: sessionId ? "matched" : "active",
    appState: "foreground",
    appStateUpdatedAt: timestamp(nowMillis),
    heartbeatAt: timestamp(nowMillis),
    expiresAt: timestamp(nowMillis + 10 * 60 * 1000),
    backgroundExpiresAt: null,
    currentSessionId: sessionId,
    activeSessionId: sessionId,
    matchedSessionId: sessionId,
    matchedUserId: sessionId ? "student-b" : null,
    matchedResponderId: sessionId ? "student-b" : null,
    matchedRole: sessionId ? "student" : null,
    pairAttemptId: sessionId ? `pair-${sessionId}` : null,
    lockOwner: sessionId ? `pair-${sessionId}` : null,
    lockExpiresAt: sessionId ? timestamp(nowMillis + 45 * 1000) : null,
    excludedCandidateIds: [],
    attemptExcludedCandidateIds: [],
    version: 1,
  };
}

async function setDoc(collection, id, data) {
  const ref = db.collection(collection).doc(id);
  await ref.set(data);
  touchedRefs.push(ref);
  return ref;
}

function trialRef(userId) {
  return db.collection("users").doc(userId)
      .collection("trialAccess").doc("current");
}

async function seedTrialUser(userId, overrides = {}) {
  const expiresAt = timestamp(nowMillis + 3 * 24 * 60 * 60 * 1000);
  await setDoc("users", userId, {
    role: "student",
    isInCall: false,
    currentSessionId: "",
    subscription: trialSubscription(expiresAt),
    ...overrides,
  });
  const ref = trialRef(userId);
  await ref.set(trialData());
  touchedRefs.push(ref);
}

async function seedConnectionSession(sessionId, trialUserIds) {
  const [studentId, tutorId] = trialUserIds;
  for (const userId of trialUserIds) {
    await setDoc("users", userId, {
      role: "student",
      isInCall: true,
      currentSessionId: sessionId,
      subscription: trialSubscription(
          timestamp(nowMillis + 3 * 24 * 60 * 60 * 1000),
      ),
    });
    const ref = trialRef(userId);
    await ref.set(trialData({status: "inProgress", callId: sessionId}));
    touchedRefs.push(ref);
    await setDoc("searchRequests", userId, searchRequest(userId, sessionId));
  }
  const sessionRef = db.collection("videoSessions").doc(sessionId);
  await sessionRef.set({
    status: "connecting",
    dailyRoomName: sessionId,
    expiresAt: timestamp(nowMillis + 5 * 60 * 1000),
    joinDeadlineAt: timestamp(nowMillis + 60 * 1000),
    requesterId: studentId,
    requesterRole: "student",
    studentId,
    tutorId,
    responderId: tutorId,
    currentTutorId: tutorId,
    currentResponderId: tutorId,
    currentResponderRole: "student",
    responderRole: "student",
    participantIds: trialUserIds,
    participantRoles: {
      [studentId]: "student",
      [tutorId]: "student",
    },
    searchRequestIds: {
      requester: `request-${studentId}`,
      responder: `request-${tutorId}`,
    },
    matchContext: {
      requesterId: studentId,
      requesterRole: "student",
      acceptedResponderId: tutorId,
      acceptedResponderRole: "student",
    },
    sessionMetadata: {},
    trialCallIdsByUserId: {
      [studentId]: sessionId,
      [tutorId]: sessionId,
    },
  });
  touchedRefs.push(sessionRef);
  return sessionRef;
}

async function cleanup() {
  for (const ref of [...touchedRefs].reverse()) {
    await ref.delete();
  }
}

test.after(async () => {
  await cleanup();
  await admin.app().delete();
});

test("concurrent trial reservations allow exactly one caller", async () => {
  const userId = `${runId}_reserve`;
  await seedTrialUser(userId);
  const ref = trialRef(userId);
  const outcomes = await Promise.all([
    "request-a",
    "request-b",
  ].map((requestId) => db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    return reserveTrialCallInTransaction({
      transaction,
      trialRef: ref,
      trialSnap: snapshot,
      requestId,
      nowMillis,
    });
  })));

  assert.equal(outcomes.filter((outcome) => outcome.allowed).length, 1);
  const finalData = await requesterRefData(userId);
  assert.equal(finalData.trialCallStatus, "inProgress");
  assert.equal(finalData.attemptCount, 1);
});

test("pair lock keeps both trial reservations unchanged when responder fails", async () => {
  const requesterId = `${runId}_partial_requester`;
  const responderId = `${runId}_partial_responder`;
  await seedTrialUser(requesterId);
  await seedTrialUser(responderId);
  const responderRef = trialRef(responderId);
  await responderRef.set(trialData({
    status: "inProgress",
    callId: "stale-session",
    leaseAt: timestamp(nowMillis - 1),
  }));
  const requesterSearchRef = db.collection("searchRequests").doc(requesterId);
  const responderSearchRef = db.collection("searchRequests").doc(responderId);
  await requesterSearchRef.set(searchRequest(requesterId));
  await responderSearchRef.set(searchRequest(responderId));
  touchedRefs.push(requesterSearchRef, responderSearchRef);

  const partialSessionId = `${runId}_partial_session`;
  const result = await db.runTransaction((transaction) =>
    reserveMatchPairInTransaction({
      db,
      transaction,
      requesterId,
      responderId,
      responderRole: "student",
      requesterSearchRequestId: `request-${requesterId}`,
      responderSearchRequestId: `request-${responderId}`,
      expectedLanguage: "en",
      sessionRef: db.collection("videoSessions").doc(partialSessionId),
      sessionData: {language: "en"},
      nowMillis,
      serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      lockExpiresAt: timestamp(nowMillis + 45 * 1000),
      finalizationExpiresAt: timestamp(nowMillis + 90 * 1000),
    }));

  assert.deepEqual(result, {
    locked: false,
    reason: "responder_retry_cooldown",
  });
  assert.equal(
      await db.collection("videoSessions").doc(partialSessionId).get()
          .then((snapshot) => snapshot.exists),
      false,
  );
  assert.equal((await requesterRefData(requesterId)).trialCallStatus, "eligible");
  const responderAfter = await requesterRefData(responderId);
  assert.equal(responderAfter.trialCallStatus, "inProgress");
  assert.equal(responderAfter.trialCallId, "stale-session");
  assert.equal(responderAfter.technicalRetryCount, 0);
});

async function requesterRefData(userId) {
  const snapshot = await trialRef(userId).get();
  return snapshot.data() || {};
}

test("technical failure before connection retries, qualified call consumes once", async () => {
  const userId = `${runId}_reconcile`;
  await seedTrialUser(userId);
  const ref = trialRef(userId);
  await ref.set(trialData({status: "inProgress", callId: "reconcile-session"}));
  touchedRefs.push(ref);

  const retry = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    return reconcileTrialCallInTransaction({
      transaction,
      trialRef: ref,
      trialSnap: snapshot,
      trialCallId: "reconcile-session",
      technicalFailure: true,
      durationSeconds: 0,
      nowMillis,
    });
  });
  assert.equal(retry.status, "eligible");
  assert.equal((await requesterRefData(userId)).trialCallStatus, "eligible");

  await ref.set(trialData({status: "inProgress", callId: "qualified-session"}));
  const qualified = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    return reconcileTrialCallInTransaction({
      transaction,
      trialRef: ref,
      trialSnap: snapshot,
      trialCallId: "qualified-session",
      durationSeconds: 120,
      nowMillis,
    });
  });
  assert.equal(qualified.status, "consumed");
  const consumedAt = (await requesterRefData(userId)).qualifiedAt.toMillis();
  const repeated = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    return reconcileTrialCallInTransaction({
      transaction,
      trialRef: ref,
      trialSnap: snapshot,
      trialCallId: "qualified-session",
      durationSeconds: 120,
      nowMillis: nowMillis + 1000,
    });
  });
  assert.equal(repeated.updated, false);
  assert.equal((await requesterRefData(userId)).qualifiedAt.toMillis(), consumedAt);
});

test("two trial participants reconcile independently and idempotently", async () => {
  const sessionId = `${runId}_both_trial`;
  const userIds = [`${runId}_both_a`, `${runId}_both_b`];
  const sessionRef = await seedConnectionSession(sessionId, userIds);
  await db.runTransaction((transaction) =>
    reconcileSessionTrialCallsInTransaction({
      db,
      transaction,
      sessionId,
      sessionData: {
        trialCallIdsByUserId: {
          [userIds[0]]: sessionId,
          [userIds[1]]: sessionId,
        },
      },
      durationSeconds: 120,
      nowMillis,
    }));
  for (const userId of userIds) {
    assert.equal((await requesterRefData(userId)).trialCallStatus, "consumed");
  }
  await db.runTransaction((transaction) =>
    reconcileSessionTrialCallsInTransaction({
      db,
      transaction,
      sessionId,
      sessionData: {
        trialCallIdsByUserId: {
          [userIds[0]]: sessionId,
          [userIds[1]]: sessionId,
        },
      },
      durationSeconds: 120,
      nowMillis: nowMillis + 1000,
    }));
  assert.equal((await sessionRef.get()).data().status, "connecting");
});

function dailyJoinEvent(userId, eventId, roomName) {
  return {
    type: "participant.joined",
    eventId,
    roomName,
    userId,
    dailySessionId: `daily-${userId}`,
    eventTsMillis: nowMillis + 8000,
    joinedAtMillis: nowMillis + 8000,
    owner: true,
  };
}

function presenceFor(roomName, userIds) {
  return {
    roomName,
    count: userIds.length,
    participants: userIds.map((user_id) => ({user_id})),
  };
}

async function applyDailyOwner({sessionRef, sessionId, event, presenceData}) {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(sessionRef);
    const sessionData = snapshot.data() || {};
    const decision = dailyPrivate.buildDailyWebhookSessionUpdate({
      event,
      sessionData,
      presenceData,
      nowMillis,
    });
    assert.equal(decision.ok, true);
    await dailyPrivate.applyDailyWebhookSessionUpdateWritesInTransaction({
      db,
      transaction,
      sessionRef,
      sessionId,
      sessionData,
      decision,
    });
    return decision;
  });
}

async function applyMarkPresenceOwner({
  sessionRef,
  sessionId,
  userId,
  presenceData,
}) {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(sessionRef);
    const sessionData = snapshot.data() || {};
    const decision = markPrivate.buildDailyPresenceConnectedDecision({
      sessionData,
      presenceData,
      userId,
      nowMillis,
      serverTimestamp: timestamp(nowMillis + 9000),
    });
    assert.equal(decision.ok, true);
    await markPrivate.applyVerifiedConnectedSessionWritesInTransaction({
      db,
      transaction,
      sessionRef,
      sessionId,
      sessionData,
      decision,
    });
    return decision;
  });
}

async function applyMarkSignalOwner({sessionRef, sessionId, userId}) {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(sessionRef);
    const sessionData = snapshot.data() || {};
    const decision = markPrivate.buildMarkSessionConnectedDecision({
      sessionData,
      userId,
      nowMillis,
      serverTimestamp: timestamp(nowMillis + 5000),
    });
    assert.equal(decision.ok, true);
    await markPrivate.applyVerifiedConnectedSessionWritesInTransaction({
      db,
      transaction,
      sessionRef,
      sessionId,
      sessionData,
      decision,
    });
    return decision;
  });
}

async function endConnectedCallThroughOwner(sessionRef, sessionId, userId) {
  await sessionRef.update({
    dailyRoomName: admin.firestore.FieldValue.delete(),
  });
  const response = await endSession.run(
      {sessionId, endReason: "user_ended"},
      {auth: {uid: userId}},
  );
  assert.equal(response.status, "ended");
  assert.equal((await sessionRef.get()).data().status, "ended");
}

async function assertTrialsConsumed(userIds) {
  for (const userId of userIds) {
    assert.equal((await requesterRefData(userId)).trialCallStatus, "consumed");
  }
}

test("Daily-wins then mark loser preserves first marker and consumes trials", async () => {
  const dailySessionId = `${runId}_daily_wins`;
  const dailyUsers = [`${runId}_daily_a`, `${runId}_daily_b`];
  const dailyRef = await seedConnectionSession(dailySessionId, dailyUsers);
  const dailyPresence = presenceFor(dailySessionId, dailyUsers);
  await applyDailyOwner({
    sessionRef: dailyRef,
    sessionId: dailySessionId,
    event: dailyJoinEvent(
        dailyUsers[0],
        `${runId}_daily_first`,
        dailySessionId,
    ),
    presenceData: dailyPresence,
  });
  const winner = await applyDailyOwner({
    sessionRef: dailyRef,
    sessionId: dailySessionId,
    event: dailyJoinEvent(
        dailyUsers[1],
        `${runId}_daily_second`,
        dailySessionId,
    ),
    presenceData: dailyPresence,
  });
  assert.equal(winner.connectedMarked, true);
  const dailyAfter = (await dailyRef.get()).data();
  assert.equal(dailyAfter.status, "active");
  const firstMarker = dailyAfter.sessionMetadata.callConnectedAt.toMillis();
  for (const userId of dailyUsers) {
    assert.ok((await requesterRefData(userId)).bothJoinedAt);
  }
  const loser = await applyMarkPresenceOwner({
    sessionRef: dailyRef,
    sessionId: dailySessionId,
    userId: dailyUsers[1],
    presenceData: dailyPresence,
  });
  assert.equal(loser.response.status, "already_marked");
  assert.equal(
      (await dailyRef.get()).data().sessionMetadata.callConnectedAt.toMillis(),
      firstMarker,
  );
  await endConnectedCallThroughOwner(
      dailyRef,
      dailySessionId,
      dailyUsers[0],
  );
  await assertTrialsConsumed(dailyUsers);
});

test("mark-wins then Daily loser preserves first marker and consumes trials", async () => {
  const markSessionId = `${runId}_mark_wins`;
  const markUsers = [`${runId}_mark_a`, `${runId}_mark_b`];
  const markRef = await seedConnectionSession(markSessionId, markUsers);
  for (const userId of markUsers) {
    const signal = await applyMarkSignalOwner({
      sessionRef: markRef,
      sessionId: markSessionId,
      userId,
    });
    assert.equal(signal.response.status, "signal_recorded");
  }
  const markPresence = presenceFor(markSessionId, markUsers);
  const winner = await applyMarkPresenceOwner({
    sessionRef: markRef,
    sessionId: markSessionId,
    userId: markUsers[1],
    presenceData: markPresence,
  });
  assert.equal(winner.response.status, "marked");
  const markAfter = (await markRef.get()).data();
  assert.equal(markAfter.status, "active");
  const firstMarker = markAfter.sessionMetadata.callConnectedAt.toMillis();
  for (const userId of markUsers) {
    assert.ok((await requesterRefData(userId)).bothJoinedAt);
  }
  await applyDailyOwner({
    sessionRef: markRef,
    sessionId: markSessionId,
    event: dailyJoinEvent(
        markUsers[0],
        `${runId}_mark_daily_first`,
        markSessionId,
    ),
    presenceData: markPresence,
  });
  const loser = await applyDailyOwner({
    sessionRef: markRef,
    sessionId: markSessionId,
    event: dailyJoinEvent(
        markUsers[1],
        `${runId}_mark_daily_second`,
        markSessionId,
    ),
    presenceData: markPresence,
  });
  assert.equal(loser.connectedMarked, false);
  assert.equal(
      (await markRef.get()).data().sessionMetadata.callConnectedAt.toMillis(),
      firstMarker,
  );
  await endConnectedCallThroughOwner(markRef, markSessionId, markUsers[0]);
  await assertTrialsConsumed(markUsers);
});

test("cancel owner returns both pre-connect trial participants to retry", async () => {
  const sessionId = `${runId}_cancel_owner`;
  const userIds = [`${runId}_cancel_a`, `${runId}_cancel_b`];
  const sessionRef = await seedConnectionSession(sessionId, userIds);
  await sessionRef.update({
    dailyRoomName: admin.firestore.FieldValue.delete(),
  });

  const response = await cancelCall.run(
      {sessionId},
      {auth: {uid: userIds[0]}},
  );

  assert.equal(response.status, "cancelled");
  assert.equal((await sessionRef.get()).data().status, "cancelled");
  for (const userId of userIds) {
    const trial = await requesterRefData(userId);
    assert.equal(trial.trialCallStatus, "eligible");
    assert.equal(trial.technicalRetryCount, 1);
  }
});

test("expiry owner reconciles a no-responder trial session", async () => {
  const sessionId = `${runId}_expiry_owner`;
  const userIds = [`${runId}_expiry_a`, `${runId}_expiry_b`];
  const sessionRef = await seedConnectionSession(sessionId, userIds);
  await sessionRef.update({
    status: "pending_confirmation",
    responseExpiresAt: timestamp(Date.now() - 1000),
    dailyRoomName: admin.firestore.FieldValue.delete(),
  });

  await cleanupExpiredSessions.run();

  assert.equal((await sessionRef.get()).data().status, "expired");
  for (const userId of userIds) {
    const trial = await requesterRefData(userId);
    assert.equal(trial.trialCallStatus, "eligible");
    assert.equal(trial.technicalRetryCount, 1);
  }
});

test("Daily owner ignores stale trial ids and preserves existing evidence", async () => {
  const sessionId = `${runId}_stale_evidence`;
  const userIds = [`${runId}_stale_a`, `${runId}_stale_b`];
  const sessionRef = await seedConnectionSession(sessionId, userIds);
  const preservedMarker = timestamp(nowMillis - 1000);
  await trialRef(userIds[0]).update({trialCallId: "newer-session"});
  await trialRef(userIds[1]).update({bothJoinedAt: preservedMarker});
  const presence = presenceFor(sessionId, userIds);
  await applyDailyOwner({
    sessionRef,
    sessionId,
    event: dailyJoinEvent(userIds[0], `${runId}_stale_first`, sessionId),
    presenceData: presence,
  });
  await applyDailyOwner({
    sessionRef,
    sessionId,
    event: dailyJoinEvent(userIds[1], `${runId}_stale_second`, sessionId),
    presenceData: presence,
  });
  assert.equal((await requesterRefData(userIds[0])).bothJoinedAt, undefined);
  assert.equal(
      (await requesterRefData(userIds[1])).bothJoinedAt.toMillis(),
      preservedMarker.toMillis(),
  );
});
