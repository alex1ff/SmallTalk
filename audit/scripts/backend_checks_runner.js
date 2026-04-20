#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const assert = require('node:assert/strict');
const { createRequire } = require('module');

const repoRoot = path.resolve(__dirname, '..', '..');
const projectId = process.env.GCLOUD_PROJECT || 'demo-smalltalk';
const ccfRequire = createRequire(
  path.join(repoRoot, 'firebase', 'custom_cloud_functions', 'package.json'),
);
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = ccfRequire('@firebase/rules-unit-testing');
const firebaseCompat = ccfRequire('firebase/compat/app');
ccfRequire('firebase/compat/firestore');

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

const admin = ccfRequire('firebase-admin');
const adminApp = ccfRequire('firebase-admin/app');
const functionsTestFactory = ccfRequire('firebase-functions-test');
const {
  buildPairId,
  buildUnlockEventPayload,
  getUnlockParticipants,
} = ccfRequire('./chats_shared.js');
const {
  getDailyPairCompletionRef,
  getUtcDayKey,
} = ccfRequire('./match_repeat_prevention.js');
const endSessionModule = ccfRequire('./end_session.js');
const createVideoSessionModule = ccfRequire('./create_video_session.js');
const conversationUnlockEventsModule = ccfRequire('./conversation_unlock_events.js');
const userMatchProfileSyncModule = ccfRequire('./user_match_profile_sync.js');
const teacherVerificationRequestsModule = ccfRequire('./teacher_verification_requests.js');

function serverTimestamp() {
  return firebaseCompat.firestore.FieldValue.serverTimestamp();
}

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
    timeoutMs = 5000,
    retryTimeoutMs = 10000,
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
      await db.collection('users').doc('userC').set({ display_name: 'User C' });
      await db.collection('users').doc('pendingTeacher').set({
        display_name: 'Pending Teacher',
        role: 'native_speaker',
        teacherAccreditationStatus: 'pending',
      });
      await db.collection('users').doc('approvedTeacher').set({
        display_name: 'Approved Teacher',
        role: 'native_speaker',
        teacherAccreditationStatus: 'approved',
      });
      await db.collection('videoSessions').doc('sessionParticipantIds').set({
        studentId: 'userA',
        tutorId: 'legacyResponder',
        participantIds: ['userA', 'userB'],
        status: 'active',
        studentNavigationTriggered: true,
        tutorNavigationTriggered: true,
        createdAt: new Date('2026-04-13T10:00:00.000Z'),
      });
      await db.collection('videoSessions').doc('sessionLegacy').set({
        studentId: 'userA',
        currentTutorId: 'userB',
        status: 'searching',
        studentNavigationTriggered: true,
        tutorNavigationTriggered: true,
        createdAt: new Date('2026-04-13T10:00:00.000Z'),
      });
      await db
        .collection('videoSessions')
        .doc('sessionParticipantIds')
        .collection('captionLogs')
        .doc('seedCaption')
        .set({
          writerId: 'userA',
          speakerId: 'userA',
          source: 'local_deepgram_final',
          text: 'Existing caption',
          createdAt: new Date('2026-04-13T10:01:00.000Z'),
        });
      await db.collection('transactions').doc('txB').set({
        userId: db.doc('users/userB'),
        type: 'call_charge',
        status: 'completed',
        amount_ST: 1,
      });
      await db.collection('conversations').doc('userA_userB').set({
        pairId: 'userA_userB',
        participantIds: ['userA', 'userB'],
        participantRefs: [db.doc('users/userA'), db.doc('users/userB')],
        isUnlocked: true,
        unlockedAt: new Date('2026-04-13T10:00:00.000Z'),
        unlockedBySessionRef: db.doc('videoSessions/sessionUnlocked'),
        createdAt: new Date('2026-04-13T10:00:00.000Z'),
        updatedAt: new Date('2026-04-13T10:00:00.000Z'),
        lastReadAtByUserId: {},
      });
      await db.collection('conversations').doc('userA_userC').set({
        pairId: 'userA_userC',
        participantIds: ['userA', 'userC'],
        participantRefs: [db.doc('users/userA'), db.doc('users/userC')],
        isUnlocked: false,
        unlockedAt: null,
        unlockedBySessionRef: null,
        createdAt: new Date('2026-04-13T10:05:00.000Z'),
        updatedAt: new Date('2026-04-13T10:05:00.000Z'),
        lastReadAtByUserId: {},
      });
      await db
        .collection('conversations')
        .doc('userA_userB')
        .collection('messages')
        .doc('seedMessage')
        .set({
          senderId: 'userA',
          senderRef: db.doc('users/userA'),
          type: 'text',
          text: 'Hello from A',
          createdAt: new Date('2026-04-13T10:01:00.000Z'),
          serverCreatedAt: new Date('2026-04-13T10:01:00.500Z'),
        });
    });

    const unauth = testEnv.unauthenticatedContext();
    const userA = testEnv.authenticatedContext('userA');
    const userB = testEnv.authenticatedContext('userB');
    const userC = testEnv.authenticatedContext('userC');
    const userD = testEnv.authenticatedContext('userD');
    const pendingTeacher = testEnv.authenticatedContext('pendingTeacher');
    const approvedTeacher = testEnv.authenticatedContext('approvedTeacher');
    const adminUser = testEnv.authenticatedContext('adminUser', {
      admin: true,
    });

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

    await check('Firestore pending teacher withdrawal create denied', async () => {
      await assertFails(
        pendingTeacher.firestore().doc('transactions/withdrawPendingTeacher').set({
          userId: pendingTeacher.firestore().doc('users/pendingTeacher'),
          type: 'withdrawal',
          status: 'pending',
          amount: 10,
        }),
      );
    });

    await check('Firestore approved teacher withdrawal create allowed', async () => {
      await assertSucceeds(
        approvedTeacher.firestore().doc('transactions/withdrawApprovedTeacher').set({
          userId: approvedTeacher.firestore().doc('users/approvedTeacher'),
          type: 'withdrawal',
          status: 'pending',
          amount: 10,
        }),
      );
    });

    await check('Firestore self profile update allowed', async () => {
      await assertSucceeds(
        userA.firestore().doc('users/userA').update({ display_name: 'User A2' }),
      );
    });

    await check('Firestore self user create without protected teacher status allowed', async () => {
      await assertSucceeds(
        userD.firestore().doc('users/userD').set({ display_name: 'User D' }),
      );
    });

    await check('Firestore self user create with teacher status denied', async () => {
      await assertFails(
        testEnv
          .authenticatedContext('userE')
          .firestore()
          .doc('users/userE')
          .set({
            display_name: 'User E',
            teacherAccreditationStatus: 'approved',
          }),
      );
    });

    await check('Firestore self teacher status update denied', async () => {
      await assertFails(
        userA.firestore().doc('users/userA').update({
          teacherAccreditationStatus: 'approved',
        }),
      );
    });

    await check('Firestore self teacher pending status update allowed', async () => {
      await assertSucceeds(
        userA.firestore().doc('users/userA').update({
          teacherAccreditationStatus: 'pending',
          verif_NS: false,
        }),
      );
    });

    await check('Firestore self legacy teacher verification update denied', async () => {
      await assertFails(
        userA.firestore().doc('users/userA').update({
          verif_NS: true,
        }),
      );
    });

    await check('Firestore self matchProfile teacher approval update denied', async () => {
      await assertFails(
        userA.firestore().doc('users/userA').update({
          'matchProfile.approvedTeacher': true,
        }),
      );
    });

    await check('Firestore admin teacher status update allowed', async () => {
      await assertSucceeds(
        adminUser.firestore().doc('users/userA').update({
          teacherAccreditationStatus: 'approved',
        }),
      );
    });

    const teacherRequestUser = testEnv.authenticatedContext('teacherRequestUser');
    const teacherRequestRef = teacherRequestUser
      .firestore()
      .doc('teacherVerificationRequests/teacherRequestUser');

    await check('Firestore self teacher verification request create pending allowed', async () => {
      await assertSucceeds(
        teacherRequestRef.set({
          userId: 'teacherRequestUser',
          userRef: teacherRequestUser.firestore().doc('users/teacherRequestUser'),
          status: 'pending',
          displayName: 'Teacher Request User',
          photoUrl: 'https://example.com/avatar.jpg',
          languageInstruction: { code: 'en' },
          nativeLanguage: { code: 'ru' },
          country: { code: 'US' },
          aboutMe: 'Request bio',
          accreditation: {
            teachingExperience: '1_3_years',
            teachingFormats: ['conversation', 'grammar'],
            qualificationProof: 'certificate',
            teachingMethod: 'Short method description',
            acceptedTeacherRules: true,
          },
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }),
      );
    });

    await check('Firestore self teacher verification request update pending allowed', async () => {
      await assertSucceeds(
        teacherRequestRef.update({
          aboutMe: 'Updated request bio',
          updatedAt: serverTimestamp(),
        }),
      );
    });

    await check('Firestore self teacher verification request review fields denied', async () => {
      await assertFails(
        teacherRequestRef.update({
          reviewComment: 'Looks good',
          updatedAt: serverTimestamp(),
        }),
      );
    });

    await check('Firestore self teacher verification request approve denied', async () => {
      await assertFails(
        teacherRequestRef.update({
          status: 'approved',
          updatedAt: serverTimestamp(),
        }),
      );
    });

    await check('Firestore self teacher verification request create approved denied', async () => {
      await assertFails(
        testEnv
          .authenticatedContext('teacherRequestApprovedUser')
          .firestore()
          .doc('teacherVerificationRequests/teacherRequestApprovedUser')
          .set({
            userId: 'teacherRequestApprovedUser',
            userRef: testEnv
              .authenticatedContext('teacherRequestApprovedUser')
              .firestore()
              .doc('users/teacherRequestApprovedUser'),
            status: 'approved',
            createdAt: serverTimestamp(),
            updatedAt: serverTimestamp(),
          }),
      );
    });

    await check('Firestore cross-user teacher verification request read denied', async () => {
      await assertFails(
        userA.firestore().doc('teacherVerificationRequests/teacherRequestUser').get(),
      );
    });

    await check('Firestore admin teacher verification request approve allowed', async () => {
      await assertSucceeds(
        adminUser.firestore().doc('teacherVerificationRequests/teacherRequestUser').update({
          status: 'approved',
          reviewedBy: 'adminUser',
          reviewedAt: serverTimestamp(),
        }),
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

    await check('Session client create denied even with participantIds', async () => {
      await assertFails(
        userA.firestore().doc('videoSessions/clientCreateWithParticipantIds').set({
          studentId: 'userA',
          participantIds: ['userA'],
          status: 'searching',
          createdAt: serverTimestamp(),
        }),
      );
    });

    await check('Session create without participantIds denied', async () => {
      await assertFails(
        userA.firestore().doc('videoSessions/clientCreateLegacyOnly').set({
          studentId: 'userA',
          status: 'searching',
          createdAt: serverTimestamp(),
        }),
      );
    });

    await check('Session create with extra participantIds denied', async () => {
      await assertFails(
        userA.firestore().doc('videoSessions/clientCreateExtraParticipant').set({
          studentId: 'userA',
          participantIds: ['userA', 'userB'],
          status: 'searching',
          createdAt: serverTimestamp(),
        }),
      );
    });

    await check('Session participantIds read allowed', async () => {
      await assertSucceeds(
        userA.firestore().doc('videoSessions/sessionParticipantIds').get(),
      );
    });

    await check('Session legacy participant read still allowed', async () => {
      await assertSucceeds(
        userB.firestore().doc('videoSessions/sessionLegacy').get(),
      );
    });

    await check('Session non-participant read denied', async () => {
      await assertFails(
        userC.firestore().doc('videoSessions/sessionParticipantIds').get(),
      );
    });

    await check('Session requester navigation update allowed', async () => {
      await assertSucceeds(
        userA.firestore().doc('videoSessions/sessionParticipantIds').update({
          studentNavigationTriggered: false,
          navigationCompletedAt: serverTimestamp(),
        }),
      );
    });

    await check('Session responder navigation update allowed via participantIds', async () => {
      await assertSucceeds(
        userB.firestore().doc('videoSessions/sessionParticipantIds').update({
          tutorNavigationTriggered: false,
          navigationTimestamp: serverTimestamp(),
        }),
      );
    });

    await check('Session participantIds tamper denied', async () => {
      await assertFails(
        userA.firestore().doc('videoSessions/sessionParticipantIds').update({
          participantIds: ['userA', 'userB', 'userC'],
        }),
      );
    });

    await check('Session non-navigation update denied for participant', async () => {
      await assertFails(
        userA.firestore().doc('videoSessions/sessionParticipantIds').update({
          status: 'ended',
        }),
      );
    });

    await check('Caption read allowed via participantIds session membership', async () => {
      await assertSucceeds(
        userB
          .firestore()
          .doc('videoSessions/sessionParticipantIds/captionLogs/seedCaption')
          .get(),
      );
    });

    await check('Caption write denied for non-participant', async () => {
      await assertFails(
        userC
          .firestore()
          .doc('videoSessions/sessionParticipantIds/captionLogs/badCaption')
          .set({
            writerId: 'userC',
            speakerId: 'userC',
            source: 'local_deepgram_final',
          }),
      );
    });

    await check('Caption peer legacy write allowed for participant writer', async () => {
      await assertSucceeds(
        userA
          .firestore()
          .doc('videoSessions/sessionParticipantIds/captionLogs/peerCaption')
          .set({
            writerId: 'userA',
            speakerId: 'daily_remote_userB',
            source: 'peer_legacy_final',
          }),
      );
    });

    await check('Chat unauth conversation read denied', async () => {
      await assertFails(unauth.firestore().doc('conversations/userA_userB').get());
    });

    await check('Chat participant conversation read allowed', async () => {
      await assertSucceeds(userA.firestore().doc('conversations/userA_userB').get());
    });

    await check('Chat missing conversation get returns not found for signed-in user', async () => {
      const snapshot = await assertSucceeds(
        userA.firestore().doc('conversations/userA_userD').get(),
      );
      assert.equal(snapshot.exists, false);
    });

    await check('Chat conversations collection query denied', async () => {
      await assertFails(
        userA
          .firestore()
          .collection('conversations')
          .where('participantIds', 'array-contains', 'userA')
          .get(),
      );
    });

    await check('Chat conversations collection scan denied', async () => {
      await assertFails(userA.firestore().collection('conversations').get());
    });

    await check('Chat conversations query for another participant denied', async () => {
      await assertFails(
        userA
          .firestore()
          .collection('conversations')
          .where('participantIds', 'array-contains', 'userB')
          .get(),
      );
    });

    await check('Chat non-participant conversation read denied', async () => {
      await assertFails(userC.firestore().doc('conversations/userA_userB').get());
    });

    await check('Chat client conversation create denied', async () => {
      await assertFails(
        userA.firestore().doc('conversations/userA_userD').set({
          pairId: 'userA_userD',
          participantIds: ['userA', 'userD'],
          participantRefs: [
            userA.firestore().doc('users/userA'),
            userA.firestore().doc('users/userD'),
          ],
          isUnlocked: true,
        }),
      );
    });

    await check('Chat unlock event access denied to clients', async () => {
      await assertFails(
        userA.firestore().doc('conversationUnlockEvents/fakeSession').get(),
      );
    });

    await check('Chat unlocked messages read allowed for participant', async () => {
      await assertSucceeds(
        userB
          .firestore()
          .doc('conversations/userA_userB/messages/seedMessage')
          .get(),
      );
    });

    await check('Chat unlocked messages read denied for non-participant', async () => {
      await assertFails(
        userC
          .firestore()
          .doc('conversations/userA_userB/messages/seedMessage')
          .get(),
      );
    });

    await check('Chat locked messages read denied before unlock', async () => {
      await assertFails(
        userA
          .firestore()
          .doc('conversations/userA_userC/messages/lockedMessage')
          .get(),
      );
    });

    await check('Chat locked messages create denied before unlock', async () => {
      await assertFails(
        userA
          .firestore()
          .doc('conversations/userA_userC/messages/newMessage')
          .set({
            senderId: 'userA',
            senderRef: userA.firestore().doc('users/userA'),
            type: 'text',
            text: 'Should fail while locked',
            createdAt: serverTimestamp(),
          }),
      );
    });

    await check('Chat participant message create allowed after unlock', async () => {
      await assertSucceeds(
        userA
          .firestore()
          .doc('conversations/userA_userB/messages/newMessage')
          .set({
            senderId: 'userA',
            senderRef: userA.firestore().doc('users/userA'),
            type: 'text',
            text: 'Allowed message',
            createdAt: serverTimestamp(),
          }),
      );
    });

    await check('Chat message create denied for wrong senderRef', async () => {
      await assertFails(
        userA
          .firestore()
          .doc('conversations/userA_userB/messages/badSenderRef')
          .set({
            senderId: 'userA',
            senderRef: userA.firestore().doc('users/userB'),
            type: 'text',
            text: 'Wrong sender ref',
            createdAt: serverTimestamp(),
          }),
      );
    });

    await check('Chat message create denied for extra fields', async () => {
      await assertFails(
        userA
          .firestore()
          .doc('conversations/userA_userB/messages/extraField')
          .set({
            senderId: 'userA',
            senderRef: userA.firestore().doc('users/userA'),
            type: 'text',
            text: 'Extra field',
            createdAt: serverTimestamp(),
            serverCreatedAt: serverTimestamp(),
          }),
      );
    });

    await check('Chat participant read marker update allowed on own key only', async () => {
      await assertSucceeds(
        userA.firestore().doc('conversations/userA_userB').update({
          'lastReadAtByUserId.userA': serverTimestamp(),
        }),
      );
    });

    await check('Chat read marker update denied for another participant key', async () => {
      await assertFails(
        userA.firestore().doc('conversations/userA_userB').update({
          'lastReadAtByUserId.userB': serverTimestamp(),
        }),
      );
    });

    await check('Chat read marker update denied for non-read fields', async () => {
      await assertFails(
        userA.firestore().doc('conversations/userA_userB').update({
          lastMessageText: 'tamper',
        }),
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
    const unlockEventAfter = await db
      .collection('conversationUnlockEvents')
      .doc(sessionId)
      .get();
    result.unlockEventCreated = unlockEventAfter.exists;

    result.pass =
      callChargeCount === 1 &&
      earningCount === 1 &&
      result.sessionStatusAfter === 'ended' &&
      result.unlockEventCreated === true &&
      result.studentBalanceMinutesAfter !== null &&
      result.studentBalanceMinutesAfter < result.studentBalanceMinutesBefore;

    if (!result.pass) {
      result.failure =
        'Expected exactly one call_charge + one earning, ended status, unlock event creation, and reduced student balance.';
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

async function runCreateVideoSessionMatrixCheck() {
  const result = {
    pass: false,
    failure: null,
    scenario:
      "student and native_speaker requesters can build all-to-all candidate pools",
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

    await db.collection("users").doc(requesterId).set(requesterData);

    const batch = db.batch();
    batch.set(db.collection("users").doc(studentCandidateId), studentCandidateData);
    batch.set(db.collection("users").doc(speakerCandidateId), speakerCandidateData);
    batch.set(
      db.collection("users").doc(offLanguageCandidateId),
      offLanguageCandidateData,
    );
    await batch.commit();

    const response = await wrappedCreateVideoSession(
      {
        language: languageCode,
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
    const hasExpectedParticipants =
      participantIds.length === 1 && participantIds[0] === requesterId;
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

    await db.collection("users").doc(requesterId).set(requesterData);

    const batch = db.batch();
    batch.set(
      db.collection("users").doc(matchingCandidateId),
      matchingCandidateData,
    );
    batch.set(
      db.collection("users").doc(offLanguageCandidateId),
      offLanguageCandidateData,
    );
    await batch.commit();

    const response = await wrappedCreateVideoSession(
      {
        language: languageCode,
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
    const hasExpectedParticipants =
      participantIds.length === 1 && participantIds[0] === requesterId;
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
    result.scenarios.nativeSpeakerRequester = await runScenario({
      scenarioKey: "native_requester",
      scenarioDescription:
        "native_speaker requester can build all-to-all candidate pool",
      languageCode: "en",
      requesterData: {
        role: "native_speaker",
        display_name: "Matrix Requester",
        blockedUsers: [],
        learningLanguage: { code: "en" },
        native_language_NS: { code: "ru" },
        language_instruction_NS: { code: "en" },
        teacherAccreditationStatus: "approved",
        rating: { average: 4.7, totalReviews: 12 },
      },
      studentCandidateData: {
        role: "student",
        display_name: "Matrix Student",
        blockedUsers: [],
        learningLanguage: { code: "en" },
        rating: { average: 4.1, totalReviews: 3 },
        availabilityToday: { enabled: true },
        Country_NS: { code: "DE" },
      },
      speakerCandidateData: {
        role: "native_speaker",
        display_name: "Matrix Speaker",
        blockedUsers: [],
        learningLanguage: { code: "es" },
        language_instruction_NS: { code: "en" },
        native_language_NS: { code: "en" },
        teacherAccreditationStatus: "approved",
        rating: { average: 4.9, totalReviews: 24 },
        availabilityToday: { enabled: true },
        Country_NS: { code: "US" },
      },
      offLanguageCandidateData: {
        role: "native_speaker",
        display_name: "Matrix Other",
        blockedUsers: [],
        language_instruction_NS: { code: "it" },
        native_language_NS: { code: "it" },
        teacherAccreditationStatus: "approved",
        availabilityToday: { enabled: true },
      },
      expectedRequesterRole: "native_speaker",
    });

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

    result.scenarios.nativeSpeakerNativeSpeakerPair = await runPairScenario({
      scenarioKey: "native_native_pair",
      scenarioDescription:
        "native_speaker requester can match an explicit native_speaker-native_speaker pair",
      languageCode: "ja",
      requesterData: {
        role: "native_speaker",
        display_name: "Matrix Native Native Requester",
        blockedUsers: [],
        learningLanguage: { code: "ja" },
        native_language_NS: { code: "ru" },
        language_instruction_NS: { code: "ja" },
        teacherAccreditationStatus: "approved",
        rating: { average: 4.4, totalReviews: 11 },
      },
      matchingCandidateKey: "speaker",
      matchingCandidateData: {
        role: "native_speaker",
        display_name: "Matrix Native Native Speaker",
        blockedUsers: [],
        language_instruction_NS: { code: "ja" },
        native_language_NS: { code: "ja" },
        teacherAccreditationStatus: "approved",
        rating: { average: 4.9, totalReviews: 18 },
        availabilityToday: { enabled: true },
        Country_NS: { code: "JP" },
      },
      offLanguageCandidateData: {
        role: "student",
        display_name: "Matrix Native Native Other",
        blockedUsers: [],
        learningLanguage: { code: "it" },
        availabilityToday: { enabled: true },
        Country_NS: { code: "IT" },
      },
      expectedRequesterRole: "native_speaker",
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

async function runSameDayRepeatPreventionCheck() {
  const result = {
    pass: false,
    failure: null,
    scenarios: {
      completedConnectedExcluded: {
        pass: false,
        sessionId: null,
        historyCreated: false,
        directStatus: null,
        poolExcludedCompletedCandidate: false,
        poolIncludesFreshCandidate: false,
        failure: null,
      },
      neverConnectedDoesNotCount: {
        pass: false,
        sessionId: null,
        historyCreated: false,
        directStatus: null,
        failure: null,
      },
      cancelledDoesNotCount: {
        pass: false,
        sessionId: null,
        historyCreated: false,
        directStatus: null,
        failure: null,
      },
      testerBypass: {
        pass: false,
        directStatus: null,
        failure: null,
      },
    },
  };

  if (!adminApp.getApps().length) {
    adminApp.initializeApp({ projectId });
  }

  const db = admin.firestore();
  const functionsTest = functionsTestFactory({ projectId });
  const wrappedCreateVideoSession = functionsTest.wrap(
    createVideoSessionModule.createVideoSession,
  );
  const wrappedEndSession = functionsTest.wrap(endSessionModule.endSession);
  const previousBypassUserIds = process.env.MATCH_REPEAT_BYPASS_USER_IDS;
  const runId = Date.now();
  const requesterId = `repeat_requester_${runId}`;
  const completedCandidateId = `repeat_completed_${runId}`;
  const freshCandidateId = `repeat_fresh_${runId}`;
  const neverConnectedCandidateId = `repeat_never_${runId}`;
  const cancelledCandidateId = `repeat_cancelled_${runId}`;

  async function seedMatchUser(userId, role) {
    await db.collection('users').doc(userId).set({
      role,
      display_name: userId,
      blockedUsers: [],
      learningLanguage: { code: 'en' },
      language_instruction_NS: { code: 'en' },
      native_language_NS: { code: 'en' },
      ...(role === 'native_speaker'
        ? { teacherAccreditationStatus: 'approved' }
        : {}),
      availabilityToday: { enabled: true },
      isInCall: false,
      isAvailable: true,
      balanceST: {
        minutes: 50,
        smallTalks: 5,
      },
    }, { merge: true });
  }

  function pairHistoryRefFor(candidateId) {
    const pairId = buildPairId(requesterId, candidateId);
    return getDailyPairCompletionRef(db, pairId, getUtcDayKey());
  }

  async function createSessionAndEnd({
    sessionId,
    candidateId,
    connected,
  }) {
    const nowMillis = Date.now();
    const sessionData = {
      studentId: requesterId,
      tutorId: candidateId,
      participantIds: [requesterId, candidateId].sort(),
      status: 'active',
      createdAt: admin.firestore.Timestamp.fromMillis(
        nowMillis - 8 * 60 * 1000,
      ),
      acceptedAt: admin.firestore.Timestamp.fromMillis(
        nowMillis - 7 * 60 * 1000,
      ),
      matchContext: {
        requesterId,
        acceptedResponderId: candidateId,
        acceptedResponderRole: 'native_speaker',
      },
    };

    if (connected) {
      sessionData.startedAt = admin.firestore.Timestamp.fromMillis(
        nowMillis - 6 * 60 * 1000,
      );
      sessionData.sessionMetadata = {
        callConnectedAt: admin.firestore.Timestamp.fromMillis(
          nowMillis - 6 * 60 * 1000,
        ),
      };
    }

    await db.collection('videoSessions').doc(sessionId).set(sessionData);
    await wrappedEndSession(
      { sessionId, endReason: 'same_day_repeat_prevention_check' },
      { auth: { uid: requesterId } },
    );
  }

  try {
    process.env.MATCH_REPEAT_BYPASS_USER_IDS = '';

    await seedMatchUser(requesterId, 'student');
    await seedMatchUser(completedCandidateId, 'native_speaker');
    await seedMatchUser(freshCandidateId, 'native_speaker');
    await seedMatchUser(neverConnectedCandidateId, 'native_speaker');
    await seedMatchUser(cancelledCandidateId, 'native_speaker');

    const completedSessionId = `repeat_completed_session_${runId}`;
    result.scenarios.completedConnectedExcluded.sessionId = completedSessionId;
    await createSessionAndEnd({
      sessionId: completedSessionId,
      candidateId: completedCandidateId,
      connected: true,
    });

    const completedHistorySnap = await pairHistoryRefFor(
      completedCandidateId,
    ).get();
    result.scenarios.completedConnectedExcluded.historyCreated =
      completedHistorySnap.exists;

    const blockedDirectResponse = await wrappedCreateVideoSession(
      {
        language: 'en',
        directUserId: completedCandidateId,
      },
      { auth: { uid: requesterId } },
    );
    result.scenarios.completedConnectedExcluded.directStatus =
      blockedDirectResponse?.status || null;

    const poolResponse = await wrappedCreateVideoSession(
      { language: 'en' },
      { auth: { uid: requesterId } },
    );
    const poolSessionSnap = poolResponse?.sessionId
      ? await db.collection('videoSessions').doc(poolResponse.sessionId).get()
      : null;
    const poolCandidates = poolSessionSnap?.data()?.availableTutors || [];
    result.scenarios.completedConnectedExcluded.poolExcludedCompletedCandidate =
      !poolCandidates.includes(completedCandidateId);
    result.scenarios.completedConnectedExcluded.poolIncludesFreshCandidate =
      poolCandidates.includes(freshCandidateId);
    result.scenarios.completedConnectedExcluded.pass =
      completedHistorySnap.exists &&
      blockedDirectResponse?.status === 'no_tutors_available' &&
      result.scenarios.completedConnectedExcluded.poolExcludedCompletedCandidate &&
      result.scenarios.completedConnectedExcluded.poolIncludesFreshCandidate;
    if (!result.scenarios.completedConnectedExcluded.pass) {
      result.scenarios.completedConnectedExcluded.failure =
        'Completed connected pair was not excluded from same-day matching.';
    }

    const neverConnectedSessionId = `repeat_never_session_${runId}`;
    result.scenarios.neverConnectedDoesNotCount.sessionId =
      neverConnectedSessionId;
    await createSessionAndEnd({
      sessionId: neverConnectedSessionId,
      candidateId: neverConnectedCandidateId,
      connected: false,
    });
    const neverHistorySnap = await pairHistoryRefFor(
      neverConnectedCandidateId,
    ).get();
    result.scenarios.neverConnectedDoesNotCount.historyCreated =
      neverHistorySnap.exists;
    const neverDirectResponse = await wrappedCreateVideoSession(
      {
        language: 'en',
        directUserId: neverConnectedCandidateId,
      },
      { auth: { uid: requesterId } },
    );
    result.scenarios.neverConnectedDoesNotCount.directStatus =
      neverDirectResponse?.status || null;
    result.scenarios.neverConnectedDoesNotCount.pass =
      !neverHistorySnap.exists &&
      neverDirectResponse?.status === 'searching' &&
      !!neverDirectResponse?.sessionId;
    if (!result.scenarios.neverConnectedDoesNotCount.pass) {
      result.scenarios.neverConnectedDoesNotCount.failure =
        'Never-connected session incorrectly counted as a completed repeat.';
    }

    const cancelledSessionId = `repeat_cancelled_session_${runId}`;
    result.scenarios.cancelledDoesNotCount.sessionId = cancelledSessionId;
    await db.collection('videoSessions').doc(cancelledSessionId).set({
      studentId: requesterId,
      tutorId: cancelledCandidateId,
      participantIds: [requesterId, cancelledCandidateId].sort(),
      status: 'cancelled',
      createdAt: admin.firestore.Timestamp.fromMillis(Date.now() - 60000),
      sessionMetadata: {
        callConnectedAt: admin.firestore.Timestamp.fromMillis(Date.now() - 30000),
      },
    });
    const cancelledHistorySnap = await pairHistoryRefFor(
      cancelledCandidateId,
    ).get();
    result.scenarios.cancelledDoesNotCount.historyCreated =
      cancelledHistorySnap.exists;
    const cancelledDirectResponse = await wrappedCreateVideoSession(
      {
        language: 'en',
        directUserId: cancelledCandidateId,
      },
      { auth: { uid: requesterId } },
    );
    result.scenarios.cancelledDoesNotCount.directStatus =
      cancelledDirectResponse?.status || null;
    result.scenarios.cancelledDoesNotCount.pass =
      !cancelledHistorySnap.exists &&
      cancelledDirectResponse?.status === 'searching' &&
      !!cancelledDirectResponse?.sessionId;
    if (!result.scenarios.cancelledDoesNotCount.pass) {
      result.scenarios.cancelledDoesNotCount.failure =
        'Cancelled session incorrectly counted as a completed repeat.';
    }

    process.env.MATCH_REPEAT_BYPASS_USER_IDS = requesterId;
    const bypassResponse = await wrappedCreateVideoSession(
      {
        language: 'en',
        directUserId: completedCandidateId,
      },
      { auth: { uid: requesterId } },
    );
    result.scenarios.testerBypass.directStatus = bypassResponse?.status || null;
    result.scenarios.testerBypass.pass =
      bypassResponse?.status === 'searching' && !!bypassResponse?.sessionId;
    if (!result.scenarios.testerBypass.pass) {
      result.scenarios.testerBypass.failure =
        'Tester allow-list did not bypass same-day repeat prevention.';
    }

    result.pass = Object.values(result.scenarios).every(
      (scenario) => scenario.pass,
    );
    if (!result.pass) {
      result.failure = 'One or more same-day repeat scenarios failed.';
    }
  } catch (error) {
    result.failure = String(error);
  } finally {
    if (previousBypassUserIds === undefined) {
      delete process.env.MATCH_REPEAT_BYPASS_USER_IDS;
    } else {
      process.env.MATCH_REPEAT_BYPASS_USER_IDS = previousBypassUserIds;
    }
    await functionsTest.cleanup();
  }

  return result;
}

async function runPartnerLevelFilterCheck() {
  const result = {
    pass: false,
    failure: null,
    scenario: 'preferred partner level filters pool and direct calls',
    poolSessionId: null,
    poolCandidateIds: [],
    directMismatchStatus: null,
    directMatchStatus: null,
    directMatchSessionId: null,
    matchContextFilters: null,
    directMatchContextFilters: null,
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
      blockedUsers: [],
      learningLanguage: { code: 'en' },
      level: 'Basic',
      balanceST: {
        minutes: 50,
        smallTalks: 5,
      },
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

    const poolResponse = await wrappedCreateVideoSession(
      {
        language: 'en',
        preferredPartnerLevel: 'Fluent',
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

    const directMismatchResponse = await wrappedCreateVideoSession(
      {
        language: 'en',
        preferredPartnerLevel: 'Fluent',
        directUserId: basicCandidateId,
      },
      { auth: { uid: requesterId } },
    );
    result.directMismatchStatus = directMismatchResponse?.status || null;

    const directMatchResponse = await wrappedCreateVideoSession(
      {
        language: 'en',
        preferredPartnerLevel: 'Fluent',
        directUserId: fluentCandidateId,
      },
      { auth: { uid: requesterId } },
    );
    result.directMatchStatus = directMatchResponse?.status || null;
    result.directMatchSessionId = directMatchResponse?.sessionId || null;
    const directMatchSessionSnap = directMatchResponse?.sessionId
      ? await db
          .collection('videoSessions')
          .doc(directMatchResponse.sessionId)
          .get()
      : null;
    const directMatchSessionData = directMatchSessionSnap?.data() || {};
    result.directMatchContextFilters =
      directMatchSessionData.matchContext?.filters || null;

    result.pass =
      poolResponse?.status === 'searching' &&
      result.poolCandidateIds.includes(fluentCandidateId) &&
      !result.poolCandidateIds.includes(basicCandidateId) &&
      poolSessionData.matchContext?.filters?.preferredPartnerLevel === 'Fluent' &&
      poolSessionData.matchContext?.ranking?.levelApplied === true &&
      directMismatchResponse?.status === 'no_tutors_available' &&
      directMatchResponse?.status === 'searching' &&
      !!directMatchResponse?.sessionId &&
      directMatchSessionData.matchContext?.filters?.preferredPartnerLevel ===
        'Fluent' &&
      directMatchSessionData.matchContext?.ranking?.levelApplied === true &&
      directMatchSessionData.matchContext?.directCandidateId === fluentCandidateId &&
      Array.isArray(directMatchSessionData.availableTutors) &&
      directMatchSessionData.availableTutors.length === 1 &&
      directMatchSessionData.availableTutors[0] === fluentCandidateId;

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

async function runTeacherBoostRankingCheck() {
  const result = {
    pass: false,
    failure: null,
    scenario: 'approved teacher boost ranks Fluent approved teachers first',
    sessionId: null,
    candidateIds: [],
    ranking: null,
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
  const requesterId = `teacher_boost_requester_${runId}`;
  const approvedTeacherId = `teacher_boost_approved_${runId}`;
  const pendingTeacherId = `teacher_boost_pending_${runId}`;
  const rejectedTeacherId = `teacher_boost_rejected_${runId}`;
  const studentPeerId = `teacher_boost_student_${runId}`;

  function fluentCandidateData(displayName, status, ratingAverage) {
    return {
      role: 'native_speaker',
      display_name: displayName,
      blockedUsers: [],
      language_instruction_NS: { code: 'en' },
      native_language_NS: { code: 'en' },
      availabilityToday: { enabled: true },
      level: 'Fluent',
      rating: { average: ratingAverage, totalReviews: 20 },
      teacherAccreditationStatus: status,
      isInCall: false,
    };
  }

  try {
    await db.collection('users').doc(requesterId).set({
      role: 'student',
      display_name: 'Teacher Boost Requester',
      blockedUsers: [],
      learningLanguage: { code: 'en' },
      level: 'Intermediate',
      balanceST: {
        minutes: 50,
        smallTalks: 5,
      },
    });
    await db
      .collection('users')
      .doc(approvedTeacherId)
      .set(fluentCandidateData('Approved Teacher', 'approved', 3.5));
    await db
      .collection('users')
      .doc(pendingTeacherId)
      .set(fluentCandidateData('Pending Teacher', 'pending', 5.0));
    await db
      .collection('users')
      .doc(rejectedTeacherId)
      .set(fluentCandidateData('Rejected Teacher', 'rejected', 4.9));
    await db.collection('users').doc(studentPeerId).set({
      role: 'student',
      display_name: 'Fluent Student Peer',
      blockedUsers: [],
      learningLanguage: { code: 'en' },
      availabilityToday: { enabled: true },
      level: 'Fluent',
      rating: { average: 5.0, totalReviews: 20 },
      isInCall: false,
    });

    const response = await wrappedCreateVideoSession(
      {
        language: 'en',
        preferredPartnerLevel: 'Fluent',
      },
      { auth: { uid: requesterId } },
    );
    result.sessionId = response?.sessionId || null;
    const sessionSnap = response?.sessionId
      ? await db.collection('videoSessions').doc(response.sessionId).get()
      : null;
    const sessionData = sessionSnap?.data() || {};
    result.candidateIds = Array.isArray(sessionData.availableTutors)
      ? sessionData.availableTutors
      : [];
    result.ranking = sessionData.matchContext?.ranking || null;

    result.pass =
      response?.status === 'searching' &&
      result.candidateIds[0] === approvedTeacherId &&
      result.candidateIds.includes(studentPeerId) &&
      !result.candidateIds.includes(pendingTeacherId) &&
      !result.candidateIds.includes(rejectedTeacherId) &&
      sessionData.matchContext?.ranking?.teacherBoostApplied === true &&
      sessionData.matchContext?.ranking?.levelApplied === true;
    if (!result.pass) {
      result.failure =
        'Approved Fluent teacher did not rank first or unapproved teachers were not excluded.';
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
      storage: `${storageHost}:${storagePort}`,
    },
    checks: {},
  };

  output.checks.rules = await runRulesChecks();
  output.checks.endSessionConcurrency = await runConcurrentEndSessionCheck();
  output.checks.unlockProcessorIntegration =
    await runUnlockProcessorIntegrationCheck();
  output.checks.createVideoSessionMatrix =
    await runCreateVideoSessionMatrixCheck();
  output.checks.sameDayRepeatPrevention =
    await runSameDayRepeatPreventionCheck();
  output.checks.partnerLevelFilter =
    await runPartnerLevelFilterCheck();
  output.checks.teacherBoostRanking =
    await runTeacherBoostRankingCheck();
  output.checks.teacherVerificationRequestFlow =
    await runTeacherVerificationRequestFlowCheck();
  output.checks.userMatchProfileSync =
    await runUserMatchProfileSyncCheck();
  output.checks.createVideoSessionLoad = await runCreateVideoSessionLoadTest();

  output.finishedAt = new Date().toISOString();

  const outPath = path.join(repoRoot, 'audit', 'backend_checks_results.json');
  fs.writeFileSync(outPath, `${JSON.stringify(output, null, 2)}\n`, 'utf8');

  const allPass =
    output.checks.rules.pass &&
    output.checks.endSessionConcurrency.pass &&
    output.checks.unlockProcessorIntegration.pass &&
    output.checks.createVideoSessionMatrix.pass &&
    output.checks.sameDayRepeatPrevention.pass &&
    output.checks.partnerLevelFilter.pass &&
    output.checks.teacherBoostRanking.pass &&
    output.checks.teacherVerificationRequestFlow.pass &&
    output.checks.userMatchProfileSync.pass &&
    output.checks.createVideoSessionLoad.pass;
  const triggerDeliveryPass =
    output.checks.unlockProcessorIntegration.deliveryPass &&
    output.checks.teacherVerificationRequestFlow.deliveryPass &&
    output.checks.userMatchProfileSync.deliveryPass;

  console.log(JSON.stringify({
    outPath,
    rulesPass: output.checks.rules.pass,
    endSessionPass: output.checks.endSessionConcurrency.pass,
    unlockProcessorPass: output.checks.unlockProcessorIntegration.pass,
    matrixPass: output.checks.createVideoSessionMatrix.pass,
    sameDayRepeatPass: output.checks.sameDayRepeatPrevention.pass,
    partnerLevelPass: output.checks.partnerLevelFilter.pass,
    teacherBoostPass: output.checks.teacherBoostRanking.pass,
    teacherVerificationPass: output.checks.teacherVerificationRequestFlow.pass,
    teacherVerificationDeliveryPass:
      output.checks.teacherVerificationRequestFlow.deliveryPass,
    userMatchProfilePass: output.checks.userMatchProfileSync.pass,
    userMatchProfileDeliveryPass:
      output.checks.userMatchProfileSync.deliveryPass,
    loadPass: output.checks.createVideoSessionLoad.pass,
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
