#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { createRequire } = require('module');

const repoRoot = path.resolve(__dirname, '..', '..');
const projectId = process.env.GCLOUD_PROJECT || 'demo-smalltalk';
const ccfRequire = createRequire(
  path.join(repoRoot, 'firebase', 'custom_cloud_functions', 'package.json'),
);
const firestoreHostRaw = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const [firestoreHost, firestorePortStr] = firestoreHostRaw.split(':');
const firestorePort = Number.parseInt(firestorePortStr || '8080', 10);

const admin = ccfRequire('firebase-admin');
const adminApp = ccfRequire('firebase-admin/app');
const functionsTestFactory = ccfRequire('firebase-functions-test');
const {
  buildPairId,
  buildUnlockEventPayload,
  getUnlockParticipants,
} = ccfRequire('./chats_shared.js');
const endSessionModule = ccfRequire('./end_session.js');
const createVideoSessionModule = ccfRequire('./create_video_session.js');
const conversationUnlockEventsModule = ccfRequire('./conversation_unlock_events.js');
const userMatchProfileSyncModule = ccfRequire('./user_match_profile_sync.js');
const teacherVerificationRequestsModule = ccfRequire('./teacher_verification_requests.js');

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForSnapshot(
  docRef,
  predicate,
  { timeoutMs = 15000, intervalMs = 250, description = docRef.path } = {},
) {
  const startedAt = Date.now();
  while (Date.now() - startedAt <= timeoutMs) {
    const snap = await docRef.get();
    if (predicate(snap)) {
      return snap;
    }
    await sleep(intervalMs);
  }

  throw new Error(`Timed out waiting for ${description}`);
}

function buildSnapshotStub(ref, data) {
  return {
    exists: data != null,
    data: () => data,
    ref,
  };
}

async function waitForSnapshotWithManualFallback(
  docRef,
  predicate,
  {
    timeoutMs = 15000,
    retryTimeoutMs = 20000,
    intervalMs = 250,
    description = docRef.path,
    manualRun,
  } = {},
) {
  try {
    const snapshot = await waitForSnapshot(
      docRef,
      predicate,
      { timeoutMs, intervalMs, description },
    );
    snapshot.__manualFallbackUsed = false;
    return snapshot;
  } catch (error) {
    if (!manualRun) {
      throw error;
    }

    await manualRun();
    const snapshot = await waitForSnapshot(
      docRef,
      predicate,
      {
        timeoutMs: retryTimeoutMs,
        intervalMs,
        description: `${description} after manual fallback`,
      },
    );
    snapshot.__manualFallbackUsed = true;
    return snapshot;
  }
}

async function runUserMatchProfileSyncManually({
  userRef,
  beforeData = null,
}) {
  const afterSnap = await userRef.get();
  const afterData = afterSnap.exists ? afterSnap.data() || {} : null;
  await userMatchProfileSyncModule.syncUserMatchProfile.run(
    {
      before: buildSnapshotStub(userRef, beforeData),
      after: buildSnapshotStub(userRef, afterData),
    },
    { params: { userId: userRef.id } },
  );
}

async function runTeacherVerificationRequestCascadeManually({
  requestRef,
  userRef,
  beforeRequestData = null,
  beforeUserData = null,
}) {
  const afterRequestSnap = await requestRef.get();
  const afterRequestData = afterRequestSnap.exists ?
    afterRequestSnap.data() || {} :
    null;
  await teacherVerificationRequestsModule.syncTeacherVerificationRequest.run(
    {
      before: buildSnapshotStub(requestRef, beforeRequestData),
      after: buildSnapshotStub(requestRef, afterRequestData),
    },
    { params: { userId: requestRef.id } },
  );
  await runUserMatchProfileSyncManually({
    userRef,
    beforeData: beforeUserData,
  });
}

async function runConversationUnlockEventManually({
  eventRef,
  sessionId,
  beforeEventData = null,
}) {
  const afterEventSnap = await eventRef.get();
  const afterEventData = afterEventSnap.exists ? afterEventSnap.data() || {} : null;
  await conversationUnlockEventsModule.processConversationUnlockEvents.run(
    {
      before: buildSnapshotStub(eventRef, beforeEventData),
      after: buildSnapshotStub(eventRef, afterEventData),
    },
    { params: { sessionId } },
  );
}

function percentile(values, p) {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.min(
    sorted.length - 1,
    Math.max(0, Math.ceil((p / 100) * sorted.length) - 1),
  );
  return sorted[idx];
}

function activePaidSubscription() {
  return {
    productId: 'expatlio_1_Month',
    periodType: 'NORMAL',
    expiresAt: admin.firestore.Timestamp.fromMillis(
      Date.now() + 24 * 60 * 60 * 1000,
    ),
  };
}

function activeSearchRequestData({userId, language, requestId}) {
  const nowMillis = Date.now();
  return {
    requestId,
    userId,
    userRef: admin.firestore().collection('users').doc(userId),
    role: 'student',
    language,
    filters: {},
    status: 'active',
    appState: 'foreground',
    createdAt: admin.firestore.Timestamp.fromMillis(nowMillis - 1000),
    heartbeatAt: admin.firestore.Timestamp.fromMillis(nowMillis),
    expiresAt: admin.firestore.Timestamp.fromMillis(nowMillis + 8 * 60 * 1000),
    backgroundExpiresAt: null,
    currentSessionId: null,
    matchedUserId: null,
    matchedResponderId: null,
    matchedSessionId: null,
    matchedRole: null,
    pairAttemptId: null,
    lockOwner: null,
  };
}

async function seedActiveSearchRequest(db, {userId, language, requestId}) {
  await db.collection('searchRequests').doc(userId).set(
    activeSearchRequestData({userId, language, requestId}),
  );
}

async function seedCallableToken(db, userId) {
  await db.collection('userPrivateTokens').doc(userId).set({
    voipToken: `audit-fcm-${userId}`,
    voipTokenUpdatedAt: admin.firestore.Timestamp.now(),
  });
}

function runCallLifecycleEmulatorCheck() {
  const testPath = path.join(
    repoRoot,
    'firebase',
    'custom_cloud_functions',
    'call_lifecycle_emulator.test.js',
  );
  const child = spawnSync(
    process.execPath,
    ['--test', testPath],
    {
      cwd: repoRoot,
      env: process.env,
      encoding: 'utf8',
      maxBuffer: 8 * 1024 * 1024,
    },
  );
  const output = `${child.stdout || ''}${child.stderr || ''}`.trim();
  return {
    pass: child.status === 0,
    exitCode: child.status,
    signal: child.signal,
    output: output.slice(-12000),
  };
}

async function runConcurrentEndSessionCheck() {
  const result = {
    pass: false,
    sessionId: null,
    invocation: [],
    transactionCounts: {
      total: 0,
      call_charge: 0,
      earning: 0,
    },
    studentBalanceMinutesBefore: 50,
    studentBalanceMinutesAfter: null,
    sessionStatusAfter: null,
    unlockEventCreated: false,
    failure: null,
  };

  if (!adminApp.getApps().length) {
    adminApp.initializeApp({ projectId });
  }

  const db = admin.firestore();
  const functionsTest = functionsTestFactory({ projectId });
  const wrappedEndSession = functionsTest.wrap(endSessionModule.endSession);

  const runId = Date.now();
  const studentId = `audit_student_${runId}`;
  const tutorId = `audit_tutor_${runId}`;
  const sessionId = `audit_session_${runId}`;
  result.sessionId = sessionId;

  try {
    const startMillis = Date.now() - 10 * 60 * 1000;

    await db.collection('users').doc(studentId).set({
      role: 'student',
      balanceST: {
        minutes: 50,
        smallTalks: 5,
      },
      isInCall: true,
      currentSessionId: sessionId,
    });

    await db.collection('users').doc(tutorId).set({
      role: 'tutor',
      isInCall: true,
      isAvailable: false,
      currentSessionId: sessionId,
      balance_NS: 0,
    });

    await db.collection('videoSessions').doc(sessionId).set({
      studentId,
      tutorId,
      status: 'active',
      language: 'en',
      createdAt: admin.firestore.Timestamp.fromMillis(startMillis - 30 * 1000),
      startedAt: admin.firestore.Timestamp.fromMillis(startMillis),
      sessionMetadata: {
        callConnectedAt: admin.firestore.Timestamp.fromMillis(startMillis),
      },
    });

    const calls = await Promise.allSettled([
      wrappedEndSession(
        { sessionId, endReason: 'concurrent_test_student' },
        { auth: { uid: studentId } },
      ),
      wrappedEndSession(
        { sessionId, endReason: 'concurrent_test_tutor' },
        { auth: { uid: tutorId } },
      ),
    ]);

    result.invocation = calls.map((entry, idx) => {
      if (entry.status === 'fulfilled') {
        return {
          caller: idx === 0 ? 'student' : 'tutor',
          status: 'fulfilled',
          responseStatus: entry.value?.status || null,
          message: entry.value?.message || null,
        };
      }
      return {
        caller: idx === 0 ? 'student' : 'tutor',
        status: 'rejected',
        error: String(entry.reason),
      };
    });

    // Give background tasks a short window to flush transaction docs.
    await new Promise((resolve) => setTimeout(resolve, 1500));

    const txSnap = await db
      .collection('transactions')
      .where('sessionId', '==', sessionId)
      .get();

    let callChargeCount = 0;
    let earningCount = 0;
    txSnap.docs.forEach((docSnap) => {
      const data = docSnap.data() || {};
      if (data.type === 'call_charge') callChargeCount += 1;
      if (data.type === 'earning') earningCount += 1;
    });

    result.transactionCounts = {
      total: txSnap.size,
      call_charge: callChargeCount,
      earning: earningCount,
    };

    const studentAfter = await db.collection('users').doc(studentId).get();
    result.studentBalanceMinutesAfter = Number(
      studentAfter.data()?.balanceST?.minutes ?? null,
    );

    const sessionAfter = await db.collection('videoSessions').doc(sessionId).get();
    result.sessionStatusAfter = sessionAfter.data()?.status || null;
    const unlockEventAfter = await db
      .collection('conversationUnlockEvents')
      .doc(sessionId)
      .get();
    result.unlockEventCreated = unlockEventAfter.exists;

    result.pass =
      callChargeCount === 0 &&
      earningCount === 1 &&
      result.sessionStatusAfter === 'ended' &&
      result.unlockEventCreated === true &&
      result.studentBalanceMinutesAfter !== null &&
      result.studentBalanceMinutesAfter === result.studentBalanceMinutesBefore;

    if (!result.pass) {
      result.failure =
        'Expected one earning, no legacy call_charge, ended status, unlock event creation, and unchanged legacy balance.';
    }
  } catch (error) {
    result.failure = String(error);
  } finally {
    await functionsTest.cleanup();
  }

  return result;
}

async function runUnlockProcessorIntegrationCheck() {
  const result = {
    pass: false,
    deliveryPass: true,
    scenarios: {
      eligibleProcessed: {
        pass: false,
        manualFallbackUsed: false,
        sessionId: null,
        pairId: null,
        eventStatus: null,
        eventReason: null,
        conversationPath: null,
        failure: null,
      },
      existingConversationReuse: {
        pass: false,
        manualFallbackUsed: false,
        sessionId: null,
        pairId: null,
        eventStatus: null,
        eventReason: null,
        unlockRefPreserved: false,
        failure: null,
      },
      ignoredIneligible: {
        pass: false,
        manualFallbackUsed: false,
        sessionId: null,
        pairId: null,
        eventStatus: null,
        eventReason: null,
        conversationCreated: false,
        failure: null,
      },
      missingSessionFailed: {
        pass: false,
        manualFallbackUsed: false,
        sessionId: null,
        pairId: null,
        eventStatus: null,
        eventReason: null,
        conversationCreated: false,
        failure: null,
      },
    },
    failure: null,
  };

  if (!adminApp.getApps().length) {
    adminApp.initializeApp({ projectId });
  }

  const db = admin.firestore();
  const runId = Date.now();

  try {
    // Scenario 1: eligible pending event becomes processed and creates a conversation.
    {
      const studentId = `unlock_student_${runId}`;
      const tutorId = `unlock_tutor_${runId}`;
      const sessionId = `unlock_session_${runId}`;
      const sessionRef = db.collection('videoSessions').doc(sessionId);
      const nowMillis = Date.now();
      const sessionData = {
        studentId,
        tutorId,
        status: 'ended',
        createdAt: admin.firestore.Timestamp.fromMillis(nowMillis - 10 * 60 * 1000),
        startedAt: admin.firestore.Timestamp.fromMillis(nowMillis - 8 * 60 * 1000),
        endedAt: admin.firestore.Timestamp.fromMillis(nowMillis),
        sessionMetadata: {
          callConnectedAt: admin.firestore.Timestamp.fromMillis(
            nowMillis - 8 * 60 * 1000,
          ),
        },
      };
      const participants = getUnlockParticipants(sessionData);
      const pairId = participants?.pairId || buildPairId(studentId, tutorId);
      const eventRef = db.collection('conversationUnlockEvents').doc(sessionId);
      result.scenarios.eligibleProcessed.sessionId = sessionId;
      result.scenarios.eligibleProcessed.pairId = pairId;

      await db.collection('users').doc(studentId).set({ role: 'student' }, { merge: true });
      await db
        .collection('users')
        .doc(tutorId)
        .set({ role: 'native_speaker' }, { merge: true });
      await sessionRef.set(sessionData);
      await eventRef.set(
        buildUnlockEventPayload({
          sessionId,
          sessionRef,
          participants,
          source: 'auditUnlockProcessorIntegration',
        }),
      );

      const eventSnap = await waitForSnapshotWithManualFallback(
        eventRef,
        (snap) => ['processed', 'ignored', 'failed'].includes(snap.data()?.status),
        {
          description: `processed unlock event ${sessionId}`,
          manualRun: async () => runConversationUnlockEventManually({
            eventRef,
            sessionId,
          }),
        },
      );
      const eventData = eventSnap.data() || {};
      result.scenarios.eligibleProcessed.manualFallbackUsed =
        Boolean(eventSnap.__manualFallbackUsed);
      result.scenarios.eligibleProcessed.eventStatus = eventData.status || null;
      result.scenarios.eligibleProcessed.eventReason = eventData.reason || null;

      const conversationSnap = await waitForSnapshot(
        db.collection('conversations').doc(pairId),
        (snap) => snap.exists && snap.data()?.isUnlocked === true,
        { description: `conversation ${pairId}` },
      );
      const conversationData = conversationSnap.data() || {};
      result.scenarios.eligibleProcessed.conversationPath = conversationSnap.ref.path;

      result.scenarios.eligibleProcessed.pass =
        eventData.status === 'processed' &&
        typeof eventData.processedAt?.toMillis === 'function' &&
        !eventData.errorCode &&
        !eventData.errorMessage &&
        eventData.conversationRef?.path === conversationSnap.ref.path &&
        conversationData.pairId === pairId &&
        conversationData.isUnlocked === true &&
        Array.isArray(conversationData.participantIds) &&
        conversationData.participantIds.join(',') === [studentId, tutorId].sort().join(',') &&
        Array.isArray(conversationData.participantRefs) &&
        conversationData.participantRefs.map((ref) => ref.path).join(',') ===
          [studentId, tutorId]
            .sort()
            .map((uid) => `users/${uid}`)
            .join(',') &&
        conversationData.unlockedBySessionRef?.path === sessionRef.path;

      if (!result.scenarios.eligibleProcessed.pass) {
        result.scenarios.eligibleProcessed.failure =
          'Eligible pending unlock event did not materialize the expected unlocked conversation.';
      }
    }

    // Scenario 2: existing unlocked conversation is reused without overwriting first-unlock metadata.
    {
      const studentId = `reuse_student_${runId}`;
      const tutorId = `reuse_tutor_${runId}`;
      const originalSessionId = `reuse_original_session_${runId}`;
      const sessionId = `reuse_session_${runId}`;
      const originalSessionRef = db.collection('videoSessions').doc(originalSessionId);
      const sessionRef = db.collection('videoSessions').doc(sessionId);
      const pairId = buildPairId(studentId, tutorId);
      const nowMillis = Date.now();
      const sessionData = {
        studentId,
        tutorId,
        status: 'ended',
        createdAt: admin.firestore.Timestamp.fromMillis(nowMillis - 9 * 60 * 1000),
        startedAt: admin.firestore.Timestamp.fromMillis(nowMillis - 7 * 60 * 1000),
        endedAt: admin.firestore.Timestamp.fromMillis(nowMillis - 1000),
        sessionMetadata: {
          callConnectedAt: admin.firestore.Timestamp.fromMillis(
            nowMillis - 7 * 60 * 1000,
          ),
        },
      };
      const participants = getUnlockParticipants(sessionData);
      const eventRef = db.collection('conversationUnlockEvents').doc(sessionId);
      result.scenarios.existingConversationReuse.sessionId = sessionId;
      result.scenarios.existingConversationReuse.pairId = pairId;

      await db.collection('users').doc(studentId).set({ role: 'student' }, { merge: true });
      await db
        .collection('users')
        .doc(tutorId)
        .set({ role: 'native_speaker' }, { merge: true });
      await originalSessionRef.set({
        studentId,
        tutorId,
        status: 'ended',
        createdAt: admin.firestore.Timestamp.fromMillis(nowMillis - 20 * 60 * 1000),
        endedAt: admin.firestore.Timestamp.fromMillis(nowMillis - 19 * 60 * 1000),
      });
      await db.collection('conversations').doc(pairId).set({
        pairId,
        participantIds: [studentId, tutorId].sort(),
        participantRefs: [studentId, tutorId]
          .sort()
          .map((uid) => db.collection('users').doc(uid)),
        isUnlocked: true,
        unlockedAt: admin.firestore.Timestamp.fromMillis(nowMillis - 18 * 60 * 1000),
        unlockedBySessionRef: originalSessionRef,
        createdAt: admin.firestore.Timestamp.fromMillis(nowMillis - 18 * 60 * 1000),
        updatedAt: admin.firestore.Timestamp.fromMillis(nowMillis - 18 * 60 * 1000),
        lastReadAtByUserId: {},
      });
      await sessionRef.set(sessionData);
      await eventRef.set(
        buildUnlockEventPayload({
          sessionId,
          sessionRef,
          participants,
          source: 'auditUnlockProcessorReuse',
        }),
      );

      const eventSnap = await waitForSnapshotWithManualFallback(
        eventRef,
        (snap) => ['processed', 'ignored', 'failed'].includes(snap.data()?.status),
        {
          description: `existing conversation reuse event ${sessionId}`,
          manualRun: async () => runConversationUnlockEventManually({
            eventRef,
            sessionId,
          }),
        },
      );
      const eventData = eventSnap.data() || {};
      const conversationSnap = await waitForSnapshot(
        db.collection('conversations').doc(pairId),
        (snap) => snap.exists,
        { description: `reused conversation ${pairId}` },
      );
      const conversationData = conversationSnap.data() || {};

      result.scenarios.existingConversationReuse.manualFallbackUsed =
        Boolean(eventSnap.__manualFallbackUsed);
      result.scenarios.existingConversationReuse.eventStatus = eventData.status || null;
      result.scenarios.existingConversationReuse.eventReason = eventData.reason || null;
      result.scenarios.existingConversationReuse.unlockRefPreserved =
        conversationData.unlockedBySessionRef?.path === originalSessionRef.path;
      result.scenarios.existingConversationReuse.pass =
        eventData.status === 'processed' &&
        eventData.reason === 'processed_existing_conversation' &&
        conversationData.isUnlocked === true &&
        conversationData.unlockedBySessionRef?.path === originalSessionRef.path;

      if (!result.scenarios.existingConversationReuse.pass) {
        result.scenarios.existingConversationReuse.failure =
          'Processor did not safely reuse the already-unlocked conversation.';
      }
    }

    // Scenario 3: ineligible session is ignored and no conversation is created.
    {
      const studentId = `ignored_student_${runId}`;
      const tutorId = `ignored_tutor_${runId}`;
      const sessionId = `ignored_session_${runId}`;
      const sessionRef = db.collection('videoSessions').doc(sessionId);
      const pairId = buildPairId(studentId, tutorId);
      const nowMillis = Date.now();
      const sessionData = {
        studentId,
        tutorId,
        status: 'ended',
        createdAt: admin.firestore.Timestamp.fromMillis(nowMillis - 5 * 60 * 1000),
        endedAt: admin.firestore.Timestamp.fromMillis(nowMillis - 4 * 60 * 1000),
        sessionMetadata: {},
      };
      const participants = getUnlockParticipants(sessionData);
      const eventRef = db.collection('conversationUnlockEvents').doc(sessionId);
      result.scenarios.ignoredIneligible.sessionId = sessionId;
      result.scenarios.ignoredIneligible.pairId = pairId;

      await sessionRef.set(sessionData);
      await eventRef.set(
        buildUnlockEventPayload({
          sessionId,
          sessionRef,
          participants,
          source: 'auditUnlockProcessorIgnored',
        }),
      );

      const eventSnap = await waitForSnapshotWithManualFallback(
        eventRef,
        (snap) => ['processed', 'ignored', 'failed'].includes(snap.data()?.status),
        {
          description: `ignored unlock event ${sessionId}`,
          manualRun: async () => runConversationUnlockEventManually({
            eventRef,
            sessionId,
          }),
        },
      );
      const eventData = eventSnap.data() || {};
      const conversationSnap = await db.collection('conversations').doc(pairId).get();

      result.scenarios.ignoredIneligible.manualFallbackUsed =
        Boolean(eventSnap.__manualFallbackUsed);
      result.scenarios.ignoredIneligible.eventStatus = eventData.status || null;
      result.scenarios.ignoredIneligible.eventReason = eventData.reason || null;
      result.scenarios.ignoredIneligible.conversationCreated = conversationSnap.exists;
      result.scenarios.ignoredIneligible.pass =
        eventData.status === 'ignored' &&
        eventData.reason === 'ignored_not_connected' &&
        !eventData.conversationRef &&
        !conversationSnap.exists;

      if (!result.scenarios.ignoredIneligible.pass) {
        result.scenarios.ignoredIneligible.failure =
          'Ineligible ended session was not ignored cleanly.';
      }
    }

    // Scenario 4: missing session fails cleanly and does not create a conversation.
    {
      const studentId = `missing_student_${runId}`;
      const tutorId = `missing_tutor_${runId}`;
      const sessionId = `missing_session_${runId}`;
      const sessionRef = db.collection('videoSessions').doc(sessionId);
      const pairId = buildPairId(studentId, tutorId);
      const participantIds = [studentId, tutorId].sort();
      const eventRef = db.collection('conversationUnlockEvents').doc(sessionId);
      const participants = {
        pairId,
        participantIds,
        participantRefs: participantIds.map((uid) => db.collection('users').doc(uid)),
      };
      result.scenarios.missingSessionFailed.sessionId = sessionId;
      result.scenarios.missingSessionFailed.pairId = pairId;

      await eventRef.set(
        buildUnlockEventPayload({
          sessionId,
          sessionRef,
          participants,
          source: 'auditUnlockProcessorMissingSession',
        }),
      );

      const eventSnap = await waitForSnapshotWithManualFallback(
        eventRef,
        (snap) => ['processed', 'ignored', 'failed'].includes(snap.data()?.status),
        {
          description: `failed unlock event ${sessionId}`,
          manualRun: async () => runConversationUnlockEventManually({
            eventRef,
            sessionId,
          }),
        },
      );
      const eventData = eventSnap.data() || {};
      const conversationSnap = await db.collection('conversations').doc(pairId).get();

      result.scenarios.missingSessionFailed.manualFallbackUsed =
        Boolean(eventSnap.__manualFallbackUsed);
      result.scenarios.missingSessionFailed.eventStatus = eventData.status || null;
      result.scenarios.missingSessionFailed.eventReason = eventData.reason || null;
      result.scenarios.missingSessionFailed.conversationCreated = conversationSnap.exists;
      result.scenarios.missingSessionFailed.pass =
        eventData.status === 'failed' &&
        eventData.reason === 'failed_exception' &&
        eventData.errorCode === 'session_not_found' &&
        !conversationSnap.exists;

      if (!result.scenarios.missingSessionFailed.pass) {
        result.scenarios.missingSessionFailed.failure =
          'Missing session did not fail cleanly in the unlock processor.';
      }
    }

    result.pass = Object.values(result.scenarios).every((scenario) => scenario.pass);
    result.deliveryPass = Object.values(result.scenarios)
      .every((scenario) => !scenario.manualFallbackUsed);
    if (!result.pass) {
      result.failure = 'One or more unlock processor integration scenarios failed.';
    }
  } catch (error) {
    result.failure = String(error);
  }

  return result;
}

async function runCreateVideoSessionLoadTest() {
  const result = {
    pass: false,
    requests: 20,
    concurrency: 5,
    successCount: 0,
    errorCount: 0,
    p50_ms: null,
    p95_ms: null,
    max_ms: null,
    avg_ms: null,
    logLines: 0,
    errorLines: 0,
    responseStatuses: {},
    failure: null,
  };

  if (!adminApp.getApps().length) {
    adminApp.initializeApp({ projectId });
  }

  const db = admin.firestore();
  const functionsTest = functionsTestFactory({ projectId });
  const wrappedCreateVideoSession = functionsTest.wrap(
    createVideoSessionModule.createVideoSession,
  );

  const runId = Date.now();
  const requesterPrefix = `audit_load_student_${runId}_`;
  const tutorPrefix = `audit_load_tutor_${runId}_`;

  try {
    const fixtureBatch = db.batch();
    for (let i = 0; i < result.requests; i += 1) {
      const requesterId = `${requesterPrefix}${i}`;
      const requestId = `audit-load-${runId}-${i}`;
      fixtureBatch.set(db.collection('users').doc(requesterId), {
        role: 'student',
        display_name: `Load Student ${i}`,
        email: `${requesterId}@example.test`,
        blockedUsers: [],
        learningLanguage: { code: 'en' },
        subscription: activePaidSubscription(),
      });
      fixtureBatch.set(
        db.collection('searchRequests').doc(requesterId),
        activeSearchRequestData({
          userId: requesterId,
          language: 'en',
          requestId,
        }),
      );
    }
    for (let i = 0; i < 30; i += 1) {
      const tutorId = `${tutorPrefix}${i}`;
      fixtureBatch.set(db.collection('users').doc(tutorId), {
        role: 'native_speaker',
        display_name: `Load Tutor ${i}`,
        blockedUsers: [],
        isAvailable: true,
        isInCall: false,
        availabilityToday: { enabled: true },
        language_instruction_NS: { code: 'en' },
        native_language_NS: { code: 'es' },
        Country_NS: { code: 'MX' },
        teacherAccreditationStatus: 'approved',
        priorityScore: i + 1,
      });
      fixtureBatch.set(db.collection('userPrivateTokens').doc(tutorId), {
        voipToken: `audit-fcm-${tutorId}`,
        voipTokenUpdatedAt: admin.firestore.Timestamp.now(),
      });
    }
    await fixtureBatch.commit();

    const durations = [];

    const originalLog = console.log;
    const originalError = console.error;
    let logLines = 0;
    let errorLines = 0;

    console.log = (...args) => {
      logLines += 1;
      if (process.env.AUDIT_VERBOSE_LOAD_LOGS === '1') {
        originalLog(...args);
      }
    };
    console.error = (...args) => {
      errorLines += 1;
      if (process.env.AUDIT_VERBOSE_LOAD_LOGS === '1') {
        originalError(...args);
      }
    };

    try {
      const queue = Array.from({ length: result.requests }, (_, i) => i);
      const workers = Array.from({ length: result.concurrency }, async () => {
        while (queue.length > 0) {
          const idx = queue.shift();
          if (idx === undefined) break;
          const requesterId = `${requesterPrefix}${idx}`;

          const start = Date.now();
          try {
            const response = await wrappedCreateVideoSession(
              {
                language: 'en',
                preferredNativeLanguage: 'es',
                preferredCountry: 'MX',
                requestId: `audit-load-${runId}-${idx}`,
              },
              { auth: { uid: requesterId } },
            );
            const elapsed = Date.now() - start;
            durations.push(elapsed);
            result.successCount += 1;

            const status = response?.status || 'unknown';
            result.responseStatuses[status] = (result.responseStatuses[status] || 0) + 1;
          } catch (error) {
            const elapsed = Date.now() - start;
            durations.push(elapsed);
            result.errorCount += 1;
            result.responseStatuses.error = (result.responseStatuses.error || 0) + 1;
          }
        }
      });

      await Promise.all(workers);
    } finally {
      console.log = originalLog;
      console.error = originalError;
    }

    result.logLines = logLines;
    result.errorLines = errorLines;
    result.p50_ms = percentile(durations, 50);
    result.p95_ms = percentile(durations, 95);
    result.max_ms = durations.length ? Math.max(...durations) : null;
    result.avg_ms = durations.length
      ? Number(
          (durations.reduce((sum, value) => sum + value, 0) / durations.length).toFixed(2),
        )
      : null;

    result.pass = result.errorCount === 0;
    if (!result.pass) {
      result.failure = 'Some load-test invocations returned errors.';
    }
  } catch (error) {
    result.failure = String(error);
  } finally {
    await functionsTest.cleanup();
  }

  return result;
}

async function runCreateVideoSessionMatrixCheck() {
  const result = {
    pass: false,
    failure: null,
    scenario:
      "student search requests build the active all-to-all candidate pool",
    scenarios: {},
  };

  if (!adminApp.getApps().length) {
    adminApp.initializeApp({ projectId });
  }

  const db = admin.firestore();
  const functionsTest = functionsTestFactory({ projectId });
  const wrappedCreateVideoSession = functionsTest.wrap(
    createVideoSessionModule.createVideoSession,
  );

  const runId = Date.now();

  async function runScenario({
    scenarioKey,
    scenarioDescription,
    languageCode,
    requesterData,
    studentCandidateData,
    speakerCandidateData,
    offLanguageCandidateData,
    expectedRequesterRole,
  }) {
    const requesterId = `audit_matrix_${scenarioKey}_requester_${runId}`;
    const studentCandidateId = `audit_matrix_${scenarioKey}_student_${runId}`;
    const speakerCandidateId = `audit_matrix_${scenarioKey}_speaker_${runId}`;
    const offLanguageCandidateId = `audit_matrix_${scenarioKey}_other_${runId}`;
    const requestId = `audit-matrix-${scenarioKey}-${runId}`;
    const scenarioResult = {
      pass: false,
      failure: null,
      scenario: scenarioDescription,
      responseStatus: null,
      sessionId: null,
      participantIds: [],
      candidateIds: [],
      candidateRoleCounts: {},
    };

    await db.collection("users").doc(requesterId).set({
      ...requesterData,
      email: requesterData.email || `${requesterId}@example.test`,
      ...(requesterData.role === "student" ? {
        subscription: activePaidSubscription(),
      } : {}),
    });
    await seedActiveSearchRequest(db, {
      userId: requesterId,
      language: languageCode,
      requestId,
    });

    const batch = db.batch();
    batch.set(db.collection("users").doc(studentCandidateId), {
      ...studentCandidateData,
      subscription: activePaidSubscription(),
    });
    batch.set(db.collection("users").doc(speakerCandidateId), speakerCandidateData);
    batch.set(
      db.collection("users").doc(offLanguageCandidateId),
      offLanguageCandidateData,
    );
    await batch.commit();
    await seedActiveSearchRequest(db, {
      userId: studentCandidateId,
      language: languageCode,
      requestId: `audit-candidate-${studentCandidateId}`,
    });
    await seedCallableToken(db, speakerCandidateId);
    if (offLanguageCandidateData.role === "native_speaker") {
      await seedCallableToken(db, offLanguageCandidateId);
    }

    const response = await wrappedCreateVideoSession(
      {
        language: languageCode,
        requestId,
      },
      { auth: { uid: requesterId } },
    );

    scenarioResult.responseStatus = response?.status || null;
    scenarioResult.sessionId = response?.sessionId || null;
    if (!response?.sessionId) {
      scenarioResult.failure = "createVideoSession did not return a sessionId.";
      return scenarioResult;
    }

    const sessionSnap = await db
      .collection("videoSessions")
      .doc(response.sessionId)
      .get();
    if (!sessionSnap.exists) {
      scenarioResult.failure = "Session document was not created.";
      return scenarioResult;
    }

    const sessionData = sessionSnap.data() || {};
    const participantIds = Array.isArray(sessionData.participantIds)
      ? sessionData.participantIds
      : [];
    const candidateIds = Array.isArray(sessionData.availableTutors)
      ? sessionData.availableTutors
      : [];
    const matchContext = sessionData.matchContext || {};

    scenarioResult.participantIds = participantIds;
    scenarioResult.candidateIds = candidateIds;
    scenarioResult.candidateRoleCounts = matchContext.candidateRoleCounts || {};

    const hasExpectedCandidates =
      candidateIds.includes(studentCandidateId) &&
      candidateIds.includes(speakerCandidateId) &&
      !candidateIds.includes(offLanguageCandidateId);
    const selectedResponderId = matchContext.selectedResponderId;
    const hasExpectedParticipants =
      participantIds.length === 2 &&
      participantIds.includes(requesterId) &&
      participantIds.includes(selectedResponderId);
    const hasExpectedContext =
      sessionData.studentId === requesterId &&
      matchContext.version === "v2_all_to_all" &&
      matchContext.requesterRole === expectedRequesterRole &&
      matchContext.requestedLanguage === languageCode &&
      Array.isArray(matchContext.candidateIds) &&
      matchContext.candidateIds.includes(studentCandidateId) &&
      matchContext.candidateIds.includes(speakerCandidateId) &&
      matchContext.candidateRoleCounts?.student === 1 &&
      matchContext.candidateRoleCounts?.native_speaker === 1;
    const hasExpectedSessionPolicy =
      sessionData.sessionPolicy?.baseLimitSeconds === 300 &&
      sessionData.sessionPolicy?.warningLeadSeconds === 60 &&
      sessionData.sessionPolicy?.maxExtensionCount === 1 &&
      sessionData.sessionPolicy?.extensionSeconds === 300 &&
      sessionData.sessionPolicy?.effectiveLimitSeconds === 300 &&
      typeof sessionData.expiresAt?.toDate === "function";

    scenarioResult.pass =
      response.status === "searching" &&
      hasExpectedParticipants &&
      hasExpectedCandidates &&
      hasExpectedContext &&
      hasExpectedSessionPolicy;

    if (!scenarioResult.pass) {
      scenarioResult.failure =
        "All-to-all matchmaking session participantIds/context did not match expectations.";
    }

    return scenarioResult;
  }

  async function runPairScenario({
    scenarioKey,
    scenarioDescription,
    languageCode,
    requesterData,
    matchingCandidateKey,
    matchingCandidateData,
    offLanguageCandidateData,
    expectedRequesterRole,
    expectedCandidateRole,
  }) {
    const requesterId = `audit_matrix_${scenarioKey}_requester_${runId}`;
    const matchingCandidateId =
      `audit_matrix_${scenarioKey}_${matchingCandidateKey}_${runId}`;
    const offLanguageCandidateId = `audit_matrix_${scenarioKey}_other_${runId}`;
    const requestId = `audit-matrix-${scenarioKey}-${runId}`;
    const scenarioResult = {
      pass: false,
      failure: null,
      scenario: scenarioDescription,
      responseStatus: null,
      sessionId: null,
      participantIds: [],
      candidateIds: [],
      candidateRoleCounts: {},
    };

    await db.collection("users").doc(requesterId).set({
      ...requesterData,
      email: requesterData.email || `${requesterId}@example.test`,
      ...(requesterData.role === "student" ? {
        subscription: activePaidSubscription(),
      } : {}),
    });
    await seedActiveSearchRequest(db, {
      userId: requesterId,
      language: languageCode,
      requestId,
    });

    const batch = db.batch();
    batch.set(
      db.collection("users").doc(matchingCandidateId),
      {
        ...matchingCandidateData,
        ...(matchingCandidateData.role === "student" ? {
          subscription: activePaidSubscription(),
        } : {}),
      },
    );
    batch.set(
      db.collection("users").doc(offLanguageCandidateId),
      offLanguageCandidateData,
    );
    await batch.commit();
    if (matchingCandidateData.role === "student") {
      await seedActiveSearchRequest(db, {
        userId: matchingCandidateId,
        language: languageCode,
        requestId: `audit-candidate-${matchingCandidateId}`,
      });
    } else if (matchingCandidateData.role === "native_speaker") {
      await seedCallableToken(db, matchingCandidateId);
    }
    if (offLanguageCandidateData.role === "native_speaker") {
      await seedCallableToken(db, offLanguageCandidateId);
    }

    const response = await wrappedCreateVideoSession(
      {
        language: languageCode,
        requestId,
      },
      { auth: { uid: requesterId } },
    );

    scenarioResult.responseStatus = response?.status || null;
    scenarioResult.sessionId = response?.sessionId || null;
    if (!response?.sessionId) {
      scenarioResult.failure = "createVideoSession did not return a sessionId.";
      return scenarioResult;
    }

    const sessionSnap = await db
      .collection("videoSessions")
      .doc(response.sessionId)
      .get();
    if (!sessionSnap.exists) {
      scenarioResult.failure = "Session document was not created.";
      return scenarioResult;
    }

    const sessionData = sessionSnap.data() || {};
    const participantIds = Array.isArray(sessionData.participantIds)
      ? sessionData.participantIds
      : [];
    const candidateIds = Array.isArray(sessionData.availableTutors)
      ? sessionData.availableTutors
      : [];
    const matchContext = sessionData.matchContext || {};
    const candidateRoleCounts = matchContext.candidateRoleCounts || {};

    scenarioResult.participantIds = participantIds;
    scenarioResult.candidateIds = candidateIds;
    scenarioResult.candidateRoleCounts = candidateRoleCounts;

    const hasExpectedCandidates =
      candidateIds.length === 1 &&
      candidateIds[0] === matchingCandidateId &&
      !candidateIds.includes(offLanguageCandidateId);
    const selectedResponderId = matchContext.selectedResponderId;
    const hasExpectedParticipants =
      participantIds.length === 2 &&
      participantIds.includes(requesterId) &&
      participantIds.includes(selectedResponderId);
    const hasExpectedContext =
      sessionData.studentId === requesterId &&
      matchContext.version === "v2_all_to_all" &&
      matchContext.requesterRole === expectedRequesterRole &&
      matchContext.requestedLanguage === languageCode &&
      Array.isArray(matchContext.candidateIds) &&
      matchContext.candidateIds.length === 1 &&
      matchContext.candidateIds[0] === matchingCandidateId &&
      candidateRoleCounts?.[expectedCandidateRole] === 1 &&
      Object.keys(candidateRoleCounts).length === 1;
    const hasExpectedSessionPolicy =
      sessionData.sessionPolicy?.baseLimitSeconds === 300 &&
      sessionData.sessionPolicy?.warningLeadSeconds === 60 &&
      sessionData.sessionPolicy?.maxExtensionCount === 1 &&
      sessionData.sessionPolicy?.extensionSeconds === 300 &&
      sessionData.sessionPolicy?.effectiveLimitSeconds === 300 &&
      typeof sessionData.expiresAt?.toDate === "function";

    scenarioResult.pass =
      response.status === "searching" &&
      hasExpectedParticipants &&
      hasExpectedCandidates &&
      hasExpectedContext &&
      hasExpectedSessionPolicy;

    if (!scenarioResult.pass) {
      scenarioResult.failure =
        "Pairwise matchmaking session participantIds/context did not match expectations.";
    }

    return scenarioResult;
  }

  try {
    result.scenarios.studentRequester = await runScenario({
      scenarioKey: "student_requester",
      scenarioDescription:
        "student requester can build all-to-all candidate pool",
      languageCode: "fr",
      requesterData: {
        role: "student",
        display_name: "Matrix Student Requester",
        blockedUsers: [],
        learningLanguage: { code: "fr" },
        native_language_NS: { code: "ru" },
        rating: { average: 4.5, totalReviews: 8 },
      },
      studentCandidateData: {
        role: "student",
        display_name: "Matrix Student Peer",
        blockedUsers: [],
        learningLanguage: { code: "fr" },
        rating: { average: 4.2, totalReviews: 4 },
        availabilityToday: { enabled: true },
        Country_NS: { code: "DE" },
      },
      speakerCandidateData: {
        role: "native_speaker",
        display_name: "Matrix Student Speaker",
        blockedUsers: [],
        language_instruction_NS: { code: "fr" },
        native_language_NS: { code: "fr" },
        teacherAccreditationStatus: "approved",
        rating: { average: 4.8, totalReviews: 19 },
        availabilityToday: { enabled: true },
        Country_NS: { code: "CA" },
      },
      offLanguageCandidateData: {
        role: "native_speaker",
        display_name: "Matrix Student Other",
        blockedUsers: [],
        language_instruction_NS: { code: "it" },
        native_language_NS: { code: "it" },
        teacherAccreditationStatus: "approved",
        availabilityToday: { enabled: true },
      },
      expectedRequesterRole: "student",
    });

    result.scenarios.studentStudentPair = await runPairScenario({
      scenarioKey: "student_student_pair",
      scenarioDescription:
        "student requester can match an explicit student-student pair",
      languageCode: "de",
      requesterData: {
        role: "student",
        display_name: "Matrix Student Student Requester",
        blockedUsers: [],
        learningLanguage: { code: "de" },
        native_language_NS: { code: "ru" },
        rating: { average: 4.0, totalReviews: 6 },
      },
      matchingCandidateKey: "student",
      matchingCandidateData: {
        role: "student",
        display_name: "Matrix Student Student Peer",
        blockedUsers: [],
        learningLanguage: { code: "de" },
        rating: { average: 4.3, totalReviews: 5 },
        availabilityToday: { enabled: true },
        Country_NS: { code: "DE" },
      },
      offLanguageCandidateData: {
        role: "native_speaker",
        display_name: "Matrix Student Student Other",
        blockedUsers: [],
        language_instruction_NS: { code: "it" },
        native_language_NS: { code: "it" },
        teacherAccreditationStatus: "approved",
        availabilityToday: { enabled: true },
      },
      expectedRequesterRole: "student",
      expectedCandidateRole: "student",
    });

    result.scenarios.studentNativeSpeakerPair = await runPairScenario({
      scenarioKey: "student_native_pair",
      scenarioDescription:
        "student requester can match an explicit student-native_speaker pair",
      languageCode: "pt",
      requesterData: {
        role: "student",
        display_name: "Matrix Student Native Requester",
        blockedUsers: [],
        learningLanguage: { code: "pt" },
        native_language_NS: { code: "ru" },
        rating: { average: 4.1, totalReviews: 7 },
      },
      matchingCandidateKey: "speaker",
      matchingCandidateData: {
        role: "native_speaker",
        display_name: "Matrix Student Native Speaker",
        blockedUsers: [],
        language_instruction_NS: { code: "pt" },
        native_language_NS: { code: "pt" },
        teacherAccreditationStatus: "approved",
        rating: { average: 4.6, totalReviews: 14 },
        availabilityToday: { enabled: true },
        Country_NS: { code: "BR" },
      },
      offLanguageCandidateData: {
        role: "native_speaker",
        display_name: "Matrix Student Native Other",
        blockedUsers: [],
        language_instruction_NS: { code: "it" },
        native_language_NS: { code: "it" },
        teacherAccreditationStatus: "approved",
        availabilityToday: { enabled: true },
      },
      expectedRequesterRole: "student",
      expectedCandidateRole: "native_speaker",
    });

    result.pass = Object.values(result.scenarios).every(
      (scenario) => scenario?.pass === true,
    );
    if (!result.pass) {
      const failedScenario = Object.values(result.scenarios).find(
        (scenario) => scenario?.pass !== true,
      );
      result.failure =
        failedScenario?.failure ||
        "One or more createVideoSession matrix scenarios failed.";
    }
  } catch (error) {
    result.failure = String(error);
  } finally {
    await functionsTest.cleanup();
  }

  return result;
}

async function runPartnerLevelFilterCheck() {
  const result = {
    pass: false,
    failure: null,
    scenario: 'preferred partner level filters the discovery pool',
    poolSessionId: null,
    poolCandidateIds: [],
    matchContextFilters: null,
  };

  if (!adminApp.getApps().length) {
    adminApp.initializeApp({ projectId });
  }

  const db = admin.firestore();
  const functionsTest = functionsTestFactory({ projectId });
  const wrappedCreateVideoSession = functionsTest.wrap(
    createVideoSessionModule.createVideoSession,
  );
  const runId = Date.now();
  const requesterId = `level_requester_${runId}`;
  const basicCandidateId = `level_basic_${runId}`;
  const fluentCandidateId = `level_fluent_${runId}`;

  try {
    await db.collection('users').doc(requesterId).set({
      role: 'student',
      display_name: 'Level Requester',
      email: `${requesterId}@example.test`,
      blockedUsers: [],
      learningLanguage: { code: 'en' },
      level: 'Basic',
      balanceST: {
        minutes: 50,
        smallTalks: 5,
      },
      subscription: activePaidSubscription(),
    });
    await db.collection('users').doc(basicCandidateId).set({
      role: 'native_speaker',
      display_name: 'Basic Candidate',
      blockedUsers: [],
      language_instruction_NS: { code: 'en' },
      native_language_NS: { code: 'en' },
      teacherAccreditationStatus: 'approved',
      availabilityToday: { enabled: true },
      level: 'Basic',
      isInCall: false,
    });
    await db.collection('users').doc(fluentCandidateId).set({
      role: 'native_speaker',
      display_name: 'Fluent Candidate',
      blockedUsers: [],
      language_instruction_NS: { code: 'en' },
      native_language_NS: { code: 'en' },
      teacherAccreditationStatus: 'approved',
      availabilityToday: { enabled: true },
      level: 'Fluent',
      isInCall: false,
    });

    await Promise.all([
      seedCallableToken(db, basicCandidateId),
      seedCallableToken(db, fluentCandidateId),
      seedActiveSearchRequest(db, {
        userId: requesterId,
        language: 'en',
        requestId: `audit-level-${runId}`,
      }),
    ]);

    const poolResponse = await wrappedCreateVideoSession(
      {
        language: 'en',
        preferredPartnerLevel: 'Fluent',
        requestId: `audit-level-${runId}`,
      },
      { auth: { uid: requesterId } },
    );
    result.poolSessionId = poolResponse?.sessionId || null;
    const poolSessionSnap = poolResponse?.sessionId
      ? await db.collection('videoSessions').doc(poolResponse.sessionId).get()
      : null;
    const poolSessionData = poolSessionSnap?.data() || {};
    result.poolCandidateIds = Array.isArray(poolSessionData.availableTutors)
      ? poolSessionData.availableTutors
      : [];
    result.matchContextFilters = poolSessionData.matchContext?.filters || null;

    result.pass =
      poolResponse?.status === 'searching' &&
      result.poolCandidateIds.includes(fluentCandidateId) &&
      !result.poolCandidateIds.includes(basicCandidateId) &&
      poolSessionData.matchContext?.filters?.preferredPartnerLevel === 'Fluent' &&
      poolSessionData.matchContext?.ranking?.levelApplied === true;

    if (!result.pass) {
      result.failure = 'Preferred partner level filter did not match expectations.';
    }
  } catch (error) {
    result.failure = String(error);
  } finally {
    await functionsTest.cleanup();
  }

  return result;
}

async function runTeacherVerificationRequestFlowCheck() {
  const result = {
    pass: false,
    deliveryPass: true,
    failure: null,
    scenarios: {
      approvedRequest: {
        pass: false,
        manualFallbackUsed: false,
        userId: null,
        userStatus: null,
        verifNS: null,
        matchProfile: null,
        failure: null,
      },
      rejectedRequestClearsLegacy: {
        pass: false,
        manualFallbackUsed: false,
        userId: null,
        userStatus: null,
        verifNS: null,
        matchProfile: null,
        failure: null,
      },
    },
  };

  if (!adminApp.getApps().length) {
    adminApp.initializeApp({ projectId });
  }

  const db = admin.firestore();
  const runId = Date.now();

  try {
    {
      const userId = `audit_teacher_request_approved_${runId}`;
      const userRef = db.collection("users").doc(userId);
      const requestRef = db.collection("teacherVerificationRequests").doc(userId);
      const initialUserData = {
        role: "native_speaker",
        language_instruction_NS: { code: "en" },
        native_language_NS: { code: "ru" },
        Country_NS: { code: "US" },
        verif_NS: true,
      };
      result.scenarios.approvedRequest.userId = userId;

      await userRef.set(initialUserData);

      await requestRef.set({
        userId,
        userRef,
        status: "pending",
        displayName: "Pending Teacher",
        languageInstruction: { code: "en" },
        nativeLanguage: { code: "ru" },
        country: { code: "US" },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const pendingSnap = await waitForSnapshotWithManualFallback(
        userRef,
        (snap) => {
          const data = snap.data() || {};
          const matchProfile = data.matchProfile || {};
          return data.teacherAccreditationStatus === "pending" &&
            data.verif_NS === false &&
            matchProfile.teacherAccreditationStatus === "pending" &&
            matchProfile.approvedTeacher === false;
        },
        {
          description: `pending teacher verification request for ${userId}`,
          manualRun: async () => runTeacherVerificationRequestCascadeManually({
            requestRef,
            userRef,
            beforeRequestData: null,
            beforeUserData: initialUserData,
          }),
        },
      );
      result.scenarios.approvedRequest.manualFallbackUsed =
        Boolean(pendingSnap.__manualFallbackUsed);

      const beforeApprovalRequestData = (await requestRef.get()).data() || null;
      const beforeApprovalUserData = (await userRef.get()).data() || null;
      await requestRef.update({
        status: "approved",
        reviewedBy: "auditAdmin",
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const approvedSnap = await waitForSnapshotWithManualFallback(
        userRef,
        (snap) => {
          const data = snap.data() || {};
          const matchProfile = data.matchProfile || {};
          return data.teacherAccreditationStatus === "approved" &&
            data.verif_NS === true &&
            matchProfile.teacherAccreditationStatus === "approved" &&
            matchProfile.approvedTeacher === true;
        },
        {
          description: `approved teacher verification request for ${userId}`,
          manualRun: async () => runTeacherVerificationRequestCascadeManually({
            requestRef,
            userRef,
            beforeRequestData: beforeApprovalRequestData,
            beforeUserData: beforeApprovalUserData,
          }),
        },
      );

      const approvedData = approvedSnap.data() || {};
      result.scenarios.approvedRequest.manualFallbackUsed =
        result.scenarios.approvedRequest.manualFallbackUsed ||
        Boolean(approvedSnap.__manualFallbackUsed);
      result.scenarios.approvedRequest.pass = true;
      result.scenarios.approvedRequest.userStatus =
        approvedData.teacherAccreditationStatus || null;
      result.scenarios.approvedRequest.verifNS = approvedData.verif_NS ?? null;
      result.scenarios.approvedRequest.matchProfile =
        approvedData.matchProfile || null;
    }

    {
      const userId = `audit_teacher_request_rejected_${runId}`;
      const userRef = db.collection("users").doc(userId);
      const requestRef = db.collection("teacherVerificationRequests").doc(userId);
      const initialUserData = {
        role: "native_speaker",
        language_instruction_NS: { code: "en" },
        verif_NS: true,
      };
      result.scenarios.rejectedRequestClearsLegacy.userId = userId;

      await userRef.set(initialUserData);

      await requestRef.set({
        userId,
        userRef,
        status: "rejected",
        displayName: "Rejected Teacher",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const rejectedSnap = await waitForSnapshotWithManualFallback(
        userRef,
        (snap) => {
          const data = snap.data() || {};
          const matchProfile = data.matchProfile || {};
          return data.teacherAccreditationStatus === "rejected" &&
            data.verif_NS === false &&
            matchProfile.teacherAccreditationStatus === "rejected" &&
            matchProfile.approvedTeacher === false;
        },
        {
          description: `rejected teacher verification request for ${userId}`,
          manualRun: async () => runTeacherVerificationRequestCascadeManually({
            requestRef,
            userRef,
            beforeRequestData: null,
            beforeUserData: initialUserData,
          }),
        },
      );

      const rejectedData = rejectedSnap.data() || {};
      result.scenarios.rejectedRequestClearsLegacy.manualFallbackUsed =
        Boolean(rejectedSnap.__manualFallbackUsed);
      result.scenarios.rejectedRequestClearsLegacy.pass = true;
      result.scenarios.rejectedRequestClearsLegacy.userStatus =
        rejectedData.teacherAccreditationStatus || null;
      result.scenarios.rejectedRequestClearsLegacy.verifNS =
        rejectedData.verif_NS ?? null;
      result.scenarios.rejectedRequestClearsLegacy.matchProfile =
        rejectedData.matchProfile || null;
    }

    result.pass =
      result.scenarios.approvedRequest.pass &&
      result.scenarios.rejectedRequestClearsLegacy.pass;
    result.deliveryPass =
      !result.scenarios.approvedRequest.manualFallbackUsed &&
      !result.scenarios.rejectedRequestClearsLegacy.manualFallbackUsed;
    if (!result.pass) {
      result.failure = "One or more teacher verification request scenarios failed.";
    }
  } catch (error) {
    result.failure = String(error);
  }

  return result;
}

async function runUserMatchProfileSyncCheck() {
  const result = {
    pass: false,
    deliveryPass: true,
    failure: null,
    scenarios: {
      studentProfile: {
        pass: false,
        manualFallbackUsed: false,
        userId: null,
        matchProfile: null,
        failure: null,
      },
      nativeSpeakerProfile: {
        pass: false,
        manualFallbackUsed: false,
        userId: null,
        matchProfile: null,
        failure: null,
      },
      rejectedTeacherProfile: {
        pass: false,
        manualFallbackUsed: false,
        userId: null,
        matchProfile: null,
        failure: null,
      },
      storedOnlyProfile: {
        pass: false,
        manualFallbackUsed: false,
        userId: null,
        matchProfile: null,
        failure: null,
      },
    },
  };

  if (!adminApp.getApps().length) {
    adminApp.initializeApp({ projectId });
  }

  const db = admin.firestore();
  const runId = Date.now();

  try {
    {
      const userId = `audit_match_student_${runId}`;
      const userRef = db.collection("users").doc(userId);
      const initialUserData = {
        role: "student",
        learningLanguage: { code: "en" },
        level: "Intermediate",
        Country_NS: { code: "BR" },
        rating: { average: 4.25, totalReviews: 8 },
      };
      result.scenarios.studentProfile.userId = userId;

      await userRef.set(initialUserData);

      const initialStudentSnap = await waitForSnapshotWithManualFallback(
        userRef,
        (snap) => {
          const matchProfile = snap.data()?.matchProfile || {};
          return matchProfile.activeLanguage === "en" &&
            matchProfile.country === "BR" &&
            matchProfile.level === "Intermediate" &&
            Number(matchProfile.ratingAverage) === 4.25 &&
            Number(matchProfile.ratingCount) === 8;
        },
        {
          description: `student matchProfile sync for ${userId}`,
          manualRun: async () => runUserMatchProfileSyncManually({
            userRef,
            beforeData: null,
          }),
        },
      );
      result.scenarios.studentProfile.manualFallbackUsed =
        Boolean(initialStudentSnap.__manualFallbackUsed);

      const beforeStudentResyncData = (await userRef.get()).data() || initialUserData;
      await userRef.update({
        learningLanguage: { code: "es" },
        rating: { average: 4.8, totalReviews: 9 },
      });

      const updatedSnap = await waitForSnapshotWithManualFallback(
        userRef,
        (snap) => {
          const matchProfile = snap.data()?.matchProfile || {};
          return matchProfile.activeLanguage === "es" &&
            Number(matchProfile.ratingAverage) === 4.8 &&
            Number(matchProfile.ratingCount) === 9;
        },
        {
          description: `student matchProfile resync for ${userId}`,
          manualRun: async () => runUserMatchProfileSyncManually({
            userRef,
            beforeData: beforeStudentResyncData,
          }),
        },
      );

      result.scenarios.studentProfile.manualFallbackUsed =
        result.scenarios.studentProfile.manualFallbackUsed ||
        Boolean(updatedSnap.__manualFallbackUsed);
      result.scenarios.studentProfile.pass = true;
      result.scenarios.studentProfile.matchProfile =
        updatedSnap.data()?.matchProfile || null;
    }

    {
      const userId = `audit_match_native_${runId}`;
      const userRef = db.collection("users").doc(userId);
      const initialUserData = {
        role: "native_speaker",
        language_instruction_NS: { code: "en" },
        native_language_NS: { code: "ru" },
        Country_NS: { code: "US" },
        rating: { average: 4.7, totalReviews: 11 },
        verif_NS: true,
      };
      result.scenarios.nativeSpeakerProfile.userId = userId;

      await userRef.set(initialUserData);

      const syncedSnap = await waitForSnapshotWithManualFallback(
        userRef,
        (snap) => {
          const matchProfile = snap.data()?.matchProfile || {};
          return matchProfile.activeLanguage === "en" &&
            matchProfile.country === "US" &&
            Number(matchProfile.ratingAverage) === 4.7 &&
            Number(matchProfile.ratingCount) === 11 &&
            matchProfile.teacherAccreditationStatus === "approved" &&
            matchProfile.approvedTeacher === true;
        },
        {
          description: `native_speaker matchProfile sync for ${userId}`,
          manualRun: async () => runUserMatchProfileSyncManually({
            userRef,
            beforeData: null,
          }),
        },
      );

      result.scenarios.nativeSpeakerProfile.manualFallbackUsed =
        Boolean(syncedSnap.__manualFallbackUsed);
      result.scenarios.nativeSpeakerProfile.pass = true;
      result.scenarios.nativeSpeakerProfile.matchProfile =
        syncedSnap.data()?.matchProfile || null;
    }

    {
      const userId = `audit_match_rejected_teacher_${runId}`;
      const userRef = db.collection("users").doc(userId);
      const initialUserData = {
        role: "native_speaker",
        language_instruction_NS: { code: "en" },
        teacherAccreditationStatus: "rejected",
        verif_NS: true,
      };
      result.scenarios.rejectedTeacherProfile.userId = userId;

      await userRef.set(initialUserData);

      const syncedSnap = await waitForSnapshotWithManualFallback(
        userRef,
        (snap) => {
          const matchProfile = snap.data()?.matchProfile || {};
          return matchProfile.activeLanguage === "en" &&
            matchProfile.teacherAccreditationStatus === "rejected" &&
            matchProfile.approvedTeacher === false;
        },
        {
          description: `rejected teacher matchProfile sync for ${userId}`,
          manualRun: async () => runUserMatchProfileSyncManually({
            userRef,
            beforeData: null,
          }),
        },
      );

      result.scenarios.rejectedTeacherProfile.manualFallbackUsed =
        Boolean(syncedSnap.__manualFallbackUsed);
      result.scenarios.rejectedTeacherProfile.pass = true;
      result.scenarios.rejectedTeacherProfile.matchProfile =
        syncedSnap.data()?.matchProfile || null;
    }

    {
      const userId = `audit_match_stored_only_${runId}`;
      const userRef = db.collection("users").doc(userId);
      result.scenarios.storedOnlyProfile.userId = userId;

      await userRef.set({
        display_name: "Stored Only",
        matchProfile: {
          version: "v1",
          role: "native_speaker",
          activeLanguage: "fr",
          activeLanguageSource: "match_profile",
          supportedLanguages: ["fr"],
          country: "CA",
          level: "Fluent",
          ratingAverage: 4.6,
          ratingCount: 14,
          teacherAccreditationStatus: "approved",
          approvedTeacher: true,
          legacyPriorityScore: 7,
        },
      });

      const preservedSnap = await waitForSnapshot(
        userRef,
        (snap) => {
          const matchProfile = snap.data()?.matchProfile || {};
          return matchProfile.activeLanguage === "fr" &&
            matchProfile.country === "CA" &&
            matchProfile.ratingAverage === 4.6 &&
            matchProfile.teacherAccreditationStatus === "approved" &&
            matchProfile.legacyPriorityScore === 7;
        },
        { description: `stored-only matchProfile preservation for ${userId}` },
      );

      await userRef.update({
        aboutMe: "Unrelated update should not wipe stored-only matchProfile",
      });

      const afterUpdateSnap = await waitForSnapshot(
        userRef,
        (snap) => {
          const matchProfile = snap.data()?.matchProfile || {};
          return matchProfile.activeLanguage === "fr" &&
            matchProfile.country === "CA" &&
            matchProfile.ratingAverage === 4.6 &&
            matchProfile.teacherAccreditationStatus === "approved" &&
            matchProfile.legacyPriorityScore === 7;
        },
        { description: `stored-only matchProfile after unrelated update for ${userId}` },
      );

      result.scenarios.storedOnlyProfile.pass = true;
      result.scenarios.storedOnlyProfile.manualFallbackUsed = false;
      result.scenarios.storedOnlyProfile.matchProfile =
        afterUpdateSnap.data()?.matchProfile || null;
    }

    result.pass =
      result.scenarios.studentProfile.pass &&
      result.scenarios.nativeSpeakerProfile.pass &&
      result.scenarios.rejectedTeacherProfile.pass &&
      result.scenarios.storedOnlyProfile.pass;
    result.deliveryPass = Object.values(result.scenarios)
      .every((scenario) => !scenario.manualFallbackUsed);
    if (!result.pass) {
      result.failure = "One or more matchProfile sync scenarios failed.";
    }
  } catch (error) {
    result.failure = String(error);
  }

  return result;
}

async function main() {
  const startedAt = new Date().toISOString();

  const output = {
    startedAt,
    projectId,
    emulators: {
      firestore: `${firestoreHost}:${firestorePort}`,
      functions: process.env.FUNCTIONS_EMULATOR || '127.0.0.1:5001',
    },
    checks: {},
  };

  output.checks.endSessionConcurrency = await runConcurrentEndSessionCheck();
  output.checks.unlockProcessorIntegration =
    await runUnlockProcessorIntegrationCheck();
  output.checks.createVideoSessionMatrix =
    await runCreateVideoSessionMatrixCheck();
  output.checks.partnerLevelFilter =
    await runPartnerLevelFilterCheck();
  output.checks.teacherVerificationRequestFlow =
    await runTeacherVerificationRequestFlowCheck();
  output.checks.userMatchProfileSync =
    await runUserMatchProfileSyncCheck();
  output.checks.createVideoSessionLoad = await runCreateVideoSessionLoadTest();
  output.checks.callLifecycleEmulator = runCallLifecycleEmulatorCheck();

  output.finishedAt = new Date().toISOString();

  const outPath = path.join(repoRoot, 'audit', 'backend_checks_results.json');
  fs.writeFileSync(outPath, `${JSON.stringify(output, null, 2)}\n`, 'utf8');

  const triggerDeliveryPass =
    output.checks.unlockProcessorIntegration.deliveryPass &&
    output.checks.teacherVerificationRequestFlow.deliveryPass &&
    output.checks.userMatchProfileSync.deliveryPass;
  const allPass =
    output.checks.endSessionConcurrency.pass &&
    output.checks.unlockProcessorIntegration.pass &&
    output.checks.createVideoSessionMatrix.pass &&
    output.checks.partnerLevelFilter.pass &&
    output.checks.teacherVerificationRequestFlow.pass &&
    output.checks.userMatchProfileSync.pass &&
    output.checks.createVideoSessionLoad.pass &&
    output.checks.callLifecycleEmulator.pass &&
    triggerDeliveryPass;

  console.log(JSON.stringify({
    outPath,
    endSessionPass: output.checks.endSessionConcurrency.pass,
    unlockProcessorPass: output.checks.unlockProcessorIntegration.pass,
    matrixPass: output.checks.createVideoSessionMatrix.pass,
    partnerLevelPass: output.checks.partnerLevelFilter.pass,
    teacherVerificationPass: output.checks.teacherVerificationRequestFlow.pass,
    teacherVerificationDeliveryPass:
      output.checks.teacherVerificationRequestFlow.deliveryPass,
    userMatchProfilePass: output.checks.userMatchProfileSync.pass,
    userMatchProfileDeliveryPass:
      output.checks.userMatchProfileSync.deliveryPass,
    loadPass: output.checks.createVideoSessionLoad.pass,
    callLifecycleEmulatorPass: output.checks.callLifecycleEmulator.pass,
    unlockProcessorDeliveryPass:
      output.checks.unlockProcessorIntegration.deliveryPass,
    triggerDeliveryPass,
    allPass,
  }, null, 2));

  if (!allPass) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error('backend_checks_runner failed:', error);
  process.exit(1);
});
