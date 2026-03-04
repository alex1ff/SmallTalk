#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const repoRoot = path.resolve(__dirname, '..', '..');
const projectId = process.env.GCLOUD_PROJECT || 'demo-smalltalk';

const firestoreHostRaw = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const storageHostRaw = process.env.FIREBASE_STORAGE_EMULATOR_HOST || '127.0.0.1:9199';

const [firestoreHost, firestorePortStr] = firestoreHostRaw.split(':');
const [storageHost, storagePortStr] = storageHostRaw.split(':');
const firestorePort = Number.parseInt(firestorePortStr || '8080', 10);
const storagePort = Number.parseInt(storagePortStr || '9199', 10);

const firestoreRules = fs.readFileSync(
  path.join(repoRoot, 'firebase', 'firestore.rules'),
  'utf8',
);
const storageRules = fs.readFileSync(
  path.join(repoRoot, 'firebase', 'storage.rules'),
  'utf8',
);

const ccfRequire = createRequire(
  path.join(repoRoot, 'firebase', 'custom_cloud_functions', 'package.json'),
);
const admin = ccfRequire('firebase-admin');
const adminApp = ccfRequire('firebase-admin/app');
const functionsTestFactory = ccfRequire('firebase-functions-test');
const endSessionModule = ccfRequire('./end_session.js');
const createVideoSessionModule = ccfRequire('./create_video_session.js');

function percentile(values, p) {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.min(
    sorted.length - 1,
    Math.max(0, Math.ceil((p / 100) * sorted.length) - 1),
  );
  return sorted[idx];
}

async function runRulesChecks() {
  const result = {
    pass: false,
    checks: [],
    failures: [],
  };

  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: firestoreHost,
      port: firestorePort,
      rules: firestoreRules,
    },
    storage: {
      host: storageHost,
      port: storagePort,
      rules: storageRules,
    },
  });

  async function check(label, action) {
    try {
      await action();
      result.checks.push({ label, status: 'pass' });
    } catch (error) {
      result.checks.push({ label, status: 'fail', error: String(error) });
      result.failures.push(`${label}: ${error}`);
    }
  }

  try {
    await testEnv.clearFirestore();
    await testEnv.clearStorage();

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc('userA').set({ display_name: 'User A' });
      await db.collection('users').doc('userB').set({ display_name: 'User B' });
      await db.collection('transactions').doc('txB').set({
        userId: db.doc('users/userB'),
        type: 'call_charge',
        status: 'completed',
        amount_ST: 1,
      });
    });

    const unauth = testEnv.unauthenticatedContext();
    const userA = testEnv.authenticatedContext('userA');
    const userB = testEnv.authenticatedContext('userB');

    await check('Firestore unauth read users denied', async () => {
      await assertFails(unauth.firestore().doc('users/userA').get());
    });

    await check('Firestore cross-user profile update denied', async () => {
      await assertFails(
        userA.firestore().doc('users/userB').update({ display_name: 'Hacked' }),
      );
    });

    await check('Firestore cross-user transaction read denied', async () => {
      await assertFails(userA.firestore().doc('transactions/txB').get());
    });

    await check('Firestore self profile update allowed', async () => {
      await assertSucceeds(
        userA.firestore().doc('users/userA').update({ display_name: 'User A2' }),
      );
    });

    await check('Storage cross-user write denied', async () => {
      await assertFails(
        userA.storage().ref('users/userB/private.txt').putString('forbidden'),
      );
    });

    await check('Storage unauth write denied', async () => {
      await assertFails(
        unauth.storage().ref('users/userA/unauth.txt').putString('forbidden'),
      );
    });

    await check('Storage self write allowed', async () => {
      await assertSucceeds(
        userB.storage().ref('users/userB/own.txt').putString('allowed'),
      );
    });
  } finally {
    await testEnv.cleanup();
  }

  result.pass = result.failures.length === 0;
  return result;
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
      sessionMetadata: {},
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

    result.pass =
      callChargeCount === 1 &&
      earningCount === 1 &&
      result.sessionStatusAfter === 'ended' &&
      result.studentBalanceMinutesAfter !== null &&
      result.studentBalanceMinutesAfter < result.studentBalanceMinutesBefore;

    if (!result.pass) {
      result.failure =
        'Expected exactly one call_charge + one earning, ended status, and reduced student balance.';
    }
  } catch (error) {
    result.failure = String(error);
  } finally {
    await functionsTest.cleanup();
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
  const studentId = `audit_load_student_${runId}`;
  const tutorPrefix = `audit_load_tutor_${runId}_`;

  try {
    await db.collection('users').doc(studentId).set({
      role: 'student',
      display_name: 'Load Student',
      blockedUsers: [],
    });

    const tutorBatch = db.batch();
    for (let i = 0; i < 30; i += 1) {
      const tutorId = `${tutorPrefix}${i}`;
      tutorBatch.set(db.collection('users').doc(tutorId), {
        role: i % 2 === 0 ? 'tutor' : 'native_speaker',
        display_name: `Load Tutor ${i}`,
        blockedUsers: [],
        isAvailable: true,
        isInCall: false,
        availabilityToday: { enabled: true },
        language_instruction_NS: { code: 'en' },
        native_language_NS: { code: 'es' },
        Country_NS: { code: 'MX' },
        priorityScore: i + 1,
      });
    }
    await tutorBatch.commit();

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

          const start = Date.now();
          try {
            const response = await wrappedCreateVideoSession(
              {
                language: 'en',
                preferredNativeLanguage: 'es',
                preferredCountry: 'MX',
              },
              { auth: { uid: studentId } },
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

async function main() {
  const startedAt = new Date().toISOString();

  const output = {
    startedAt,
    projectId,
    emulators: {
      firestore: `${firestoreHost}:${firestorePort}`,
      storage: `${storageHost}:${storagePort}`,
    },
    checks: {},
  };

  output.checks.rules = await runRulesChecks();
  output.checks.endSessionConcurrency = await runConcurrentEndSessionCheck();
  output.checks.createVideoSessionLoad = await runCreateVideoSessionLoadTest();

  output.finishedAt = new Date().toISOString();

  const outPath = path.join(repoRoot, 'audit', 'backend_checks_results.json');
  fs.writeFileSync(outPath, `${JSON.stringify(output, null, 2)}\n`, 'utf8');

  const allPass =
    output.checks.rules.pass &&
    output.checks.endSessionConcurrency.pass &&
    output.checks.createVideoSessionLoad.pass;

  console.log(JSON.stringify({
    outPath,
    rulesPass: output.checks.rules.pass,
    endSessionPass: output.checks.endSessionConcurrency.pass,
    loadPass: output.checks.createVideoSessionLoad.pass,
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
