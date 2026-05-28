const test = require("node:test");
const assert = require("node:assert/strict");

const hasRequiredEmulators =
  Boolean(process.env.FIRESTORE_EMULATOR_HOST) &&
  Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST);

if (!hasRequiredEmulators) {
  test(
    "callable entitlement coverage requires Firestore/Auth emulators",
    {skip: "run with firebase emulators:exec --only firestore,auth"},
    () => {},
  );
} else {
  const admin = require("firebase-admin");
  const functionsTest = require("firebase-functions-test");

  const projectId =
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    "demo-smalltalk";
  process.env.GCLOUD_PROJECT = projectId;
  process.env.GOOGLE_CLOUD_PROJECT = projectId;

  if (!admin.apps.length) {
    admin.initializeApp({projectId});
  }

  const testEnv = functionsTest({projectId});
  const db = admin.firestore();
  const {
    getDirectCallStatus,
  } = require("./direct_call_status");
  const {
    claimRegistrationGift,
  } = require("./claim_registration_gift");
  const {
    requestWithdrawal,
  } = require("./request_withdrawal");
  const {
    migrateLegacyVoipTokens,
  } = require("./migrate_legacy_voip_tokens");
  const {
    registerVoipToken,
  } = require("./register_voip_token");
  const {
    markSessionConnected,
  } = require("./mark_session_connected");
  const {
    migrateLegacyVoipTokensBatch,
  } = require("./voip_tokens");

  const wrappedDirectCallStatus = testEnv.wrap(getDirectCallStatus);
  const wrappedClaimRegistrationGift = testEnv.wrap(claimRegistrationGift);
  const wrappedRequestWithdrawal = testEnv.wrap(requestWithdrawal);
  const wrappedMigrateLegacyVoipTokens =
    testEnv.wrap(migrateLegacyVoipTokens);
  const wrappedRegisterVoipToken = testEnv.wrap(registerVoipToken);
  const wrappedMarkSessionConnected = testEnv.wrap(markSessionConnected);
  let uidCounter = 0;

  test.after(() => {
    testEnv.cleanup();
  });

  function uniqueId(prefix) {
    uidCounter += 1;
    return [
      prefix,
      process.pid,
      Date.now(),
      uidCounter,
    ].join("-");
  }

  function authContext(uid) {
    return {
      auth: {
        uid,
        token: {
          firebase: {
            sign_in_provider: "custom",
          },
        },
      },
    };
  }

  async function expectHttpsError(action, expectedCode) {
    try {
      await action();
    } catch (error) {
      assert.equal(error.code, expectedCode);
      return error;
    }

    assert.fail(`Expected HttpsError ${expectedCode}`);
  }

  function userRef(uid) {
    return db.collection("users").doc(uid);
  }

  function futureTimestamp(minutes = 60) {
    return admin.firestore.Timestamp.fromMillis(
      Date.now() + minutes * 60 * 1000,
    );
  }

  function giftMinutes(minutes = 10) {
    return {
      minutes,
      grantedAt: admin.firestore.Timestamp.now(),
      expiresAt: futureTimestamp(60),
      source: "registration",
      totalGranted: minutes,
    };
  }

  function availableNativeSpeaker() {
    return {
      uid: "teacher",
      role: "native_speaker",
      display_name: "Teacher",
      language_instruction_NS: {code: "en"},
      teacherAccreditationStatus: "approved",
      blockedUsers: [],
      availabilityToday: {enabled: true},
      isInCall: false,
    };
  }

  function directCallStatusResponseKeys(response) {
    return Object.keys(response).sort();
  }

  test(
    "getDirectCallStatus rejects unauthenticated callers",
    async () => {
      await expectHttpsError(
        () => wrappedDirectCallStatus({targetUserId: "teacher-a"}),
        "unauthenticated",
      );
    },
  );

  test("getDirectCallStatus rejects non-student callers", async () => {
    const teacherId = uniqueId("teacher");
    await userRef(teacherId).set({
      ...availableNativeSpeaker(),
      uid: teacherId,
    });

    await expectHttpsError(
      () => wrappedDirectCallStatus(
        {targetUserId: uniqueId("target")},
        authContext(teacherId),
      ),
      "permission-denied",
    );
  });

  test("getDirectCallStatus returns requires_access before target state", async () => {
    const studentId = uniqueId("student");
    const teacherId = uniqueId("teacher");
    await userRef(studentId).set({
      uid: studentId,
      role: "student",
      learningLanguage: {code: "en"},
      blockedUsers: [],
    });
    await userRef(teacherId).set({
      ...availableNativeSpeaker(),
      uid: teacherId,
      isInCall: true,
    });

    const response = await wrappedDirectCallStatus(
      {targetUserId: teacherId, language: "en"},
      authContext(studentId),
    );

    assert.equal(response.status, "ok");
    assert.deepEqual(directCallStatusResponseKeys(response), [
      "callability",
      "canStartDirectCall",
      "checkedAtMillis",
      "reason",
      "status",
      "targetUserId",
      "ttlSeconds",
    ]);
    assert.equal(response.targetUserId, teacherId);
    assert.equal(response.canStartDirectCall, false);
    assert.equal(response.callability, "requires_access");
    assert.equal(response.reason, "requires_access");
    assert.equal(response.currentSessionId, undefined);
    assert.equal(response.availabilityToday, undefined);
  });

  test("getDirectCallStatus allows an entitled student and approved tutor", async () => {
    const studentId = uniqueId("student");
    const teacherId = uniqueId("teacher");
    await userRef(studentId).set({
      uid: studentId,
      role: "student",
      learningLanguage: {code: "en"},
      blockedUsers: [],
      giftMinutes: giftMinutes(),
    });
    await userRef(teacherId).set({
      ...availableNativeSpeaker(),
      uid: teacherId,
    });

    const response = await wrappedDirectCallStatus(
      {targetUserId: teacherId, language: "en"},
      authContext(studentId),
    );

    assert.equal(response.status, "ok");
    assert.deepEqual(directCallStatusResponseKeys(response), [
      "callability",
      "canStartDirectCall",
      "checkedAtMillis",
      "reason",
      "status",
      "targetUserId",
      "ttlSeconds",
    ]);
    assert.equal(response.canStartDirectCall, true);
    assert.equal(response.callability, "callable");
    assert.equal(response.reason, "ready");
    assert.equal(response.currentSessionId, undefined);
    assert.equal(response.availabilityToday, undefined);
    assert.equal(response.blockedUsers, undefined);
  });

  test("claimRegistrationGift rejects unauthenticated callers", async () => {
    await expectHttpsError(
      () => wrappedClaimRegistrationGift({}),
      "unauthenticated",
    );
  });

  test("claimRegistrationGift grants once using auth creation time", async () => {
    const studentId = uniqueId("student");
    await admin.auth().createUser({uid: studentId});
    await userRef(studentId).set({
      uid: studentId,
      display_name: "Student",
    });

    const response = await wrappedClaimRegistrationGift(
      {},
      authContext(studentId),
    );

    assert.equal(response.status, "granted");
    assert.equal(response.updated, true);
    assert.equal(response.roleUpdated, true);
    assert.equal(response.minutesGranted, 10);

    const [userDoc, claimDoc, transactionDoc] = await Promise.all([
      userRef(studentId).get(),
      db.collection("registrationGiftClaims").doc(studentId).get(),
      db.collection("transactions")
        .doc(`registration_gift_${studentId}`)
        .get(),
    ]);
    const userData = userDoc.data();
    assert.equal(userData.role, "student");
    assert.equal(userData.giftMinutes.minutes, 10);
    assert.equal(claimDoc.data().status, "granted");
    assert.equal(claimDoc.data().minutesGranted, 10);
    assert.equal(transactionDoc.data().type, "bonus");
    assert.equal(transactionDoc.data().source, "registration");

    const secondResponse = await wrappedClaimRegistrationGift(
      {},
      authContext(studentId),
    );
    assert.equal(secondResponse.status, "already_claimed");
    assert.equal(secondResponse.updated, false);
  });

  test("requestWithdrawal rejects unauthenticated callers", async () => {
    await expectHttpsError(
      () => wrappedRequestWithdrawal({cardId: "card-a"}),
      "unauthenticated",
    );
  });

  test("requestWithdrawal creates pending withdrawal for owned card", async () => {
    const teacherId = uniqueId("teacher");
    const balance = 731 + uidCounter;
    await userRef(teacherId).set({
      uid: teacherId,
      role: "native_speaker",
      teacherAccreditationStatus: "approved",
      balance_NS: balance,
    });
    await userRef(teacherId).collection("cards").doc("card-a").set({
      pan: "**** 4242",
    });

    const response = await wrappedRequestWithdrawal(
      {cardId: "card-a"},
      authContext(teacherId),
    );

    assert.equal(response.status, "created");
    assert.equal(response.amount, balance);
    assert.equal(typeof response.transactionId, "string");

    const [userDoc, transactionDoc] = await Promise.all([
      userRef(teacherId).get(),
      db.collection("transactions").doc(response.transactionId).get(),
    ]);
    const transactionData = transactionDoc.data();
    assert.equal(userDoc.data().balance_NS, undefined);
    assert.equal(transactionData.type, "withdrawal");
    assert.equal(transactionData.status, "pending");
    assert.equal(transactionData.amount, balance);
    assert.equal(transactionData.userId.path, `users/${teacherId}`);
    assert.equal(
      transactionData.card.path,
      `users/${teacherId}/cards/card-a`,
    );
  });

  test("requestWithdrawal rejects path-shaped card ids", async () => {
    const teacherId = uniqueId("teacher");
    await userRef(teacherId).set({
      uid: teacherId,
      role: "native_speaker",
      teacherAccreditationStatus: "approved",
      balance_NS: 100,
    });

    await expectHttpsError(
      () => wrappedRequestWithdrawal(
        {cardId: "users/other/cards/card-a"},
        authContext(teacherId),
      ),
      "invalid-argument",
    );

    const transactions = await db.collection("transactions")
      .where("userId", "==", userRef(teacherId))
      .get();
    assert.equal(transactions.empty, true);
  });

  test("requestWithdrawal rejects pending teachers", async () => {
    const teacherId = uniqueId("teacher");
    await userRef(teacherId).set({
      uid: teacherId,
      role: "native_speaker",
      teacherAccreditationStatus: "pending",
      balance_NS: 100,
    });
    await userRef(teacherId).collection("cards").doc("card-a").set({
      pan: "**** 4242",
    });

    await expectHttpsError(
      () => wrappedRequestWithdrawal(
        {cardId: "card-a"},
        authContext(teacherId),
      ),
      "permission-denied",
    );
  });

  test("registerVoipToken writes private tokens and clears legacy fields", async () => {
    const studentId = uniqueId("student");
    await userRef(studentId).set({
      uid: studentId,
      role: "student",
      voipToken: "legacy-fcm",
      voipPushToken: "legacy-push",
    });

    const response = await wrappedRegisterVoipToken(
      {tokenType: "fcm", token: " private-fcm "},
      authContext(studentId),
    );

    assert.equal(response.status, "ok");

    const [userDoc, privateDoc] = await Promise.all([
      userRef(studentId).get(),
      db.collection("userPrivateTokens").doc(studentId).get(),
    ]);
    const userData = userDoc.data();
    const privateData = privateDoc.data();

    assert.equal(userData.voipToken, undefined);
    assert.equal(userData.voipPushToken, undefined);
    assert.equal(privateData.voipToken, "private-fcm");
    assert.equal(privateData.voipPushToken, "legacy-push");
  });

  test("registerVoipToken clearAll tombstones legacy fallback", async () => {
    const studentId = uniqueId("student");
    await userRef(studentId).set({
      uid: studentId,
      role: "student",
      voipToken: "legacy-fcm",
      voipPushToken: "legacy-push",
    });

    const response = await wrappedRegisterVoipToken(
      {clearAll: true},
      authContext(studentId),
    );

    assert.equal(response.status, "cleared");

    const [userDoc, privateDoc] = await Promise.all([
      userRef(studentId).get(),
      db.collection("userPrivateTokens").doc(studentId).get(),
    ]);
    const userData = userDoc.data();
    const privateData = privateDoc.data();

    assert.equal(userData.voipToken, undefined);
    assert.equal(userData.voipPushToken, undefined);
    assert.equal(privateData.voipToken, undefined);
    assert.equal(privateData.voipPushToken, undefined);
    assert.ok(privateData.voipTokensClearedAt);
  });

  test("migrateLegacyVoipTokens requires admin access", async () => {
    await expectHttpsError(
      () => wrappedMigrateLegacyVoipTokens(
        {limit: 1},
        authContext(uniqueId("student")),
      ),
      "permission-denied",
    );
  });

  test("migrateLegacyVoipTokensBatch moves legacy tokens privately", async () => {
    const studentId = uniqueId("student");
    await userRef(studentId).set({
      uid: studentId,
      role: "student",
      voipToken: "legacy-fcm",
      voipTokenUpdatedAt: admin.firestore.Timestamp.now(),
      voipPushToken: "legacy-push",
      voipPushTokenUpdatedAt: admin.firestore.Timestamp.now(),
    });

    const result = await migrateLegacyVoipTokensBatch(10);

    assert.ok(result.migratedCount >= 1);
    const [userDoc, privateDoc] = await Promise.all([
      userRef(studentId).get(),
      db.collection("userPrivateTokens").doc(studentId).get(),
    ]);
    const userData = userDoc.data();
    const privateData = privateDoc.data();

    assert.equal(userData.voipToken, undefined);
    assert.equal(userData.voipPushToken, undefined);
    assert.equal(privateData.voipToken, "legacy-fcm");
    assert.equal(privateData.voipPushToken, "legacy-push");
  });

  test("migrateLegacyVoipTokensBatch preserves tombstones and private tokens", async () => {
    const clearedId = uniqueId("cleared");
    const privateId = uniqueId("private");
    await Promise.all([
      userRef(clearedId).set({
        uid: clearedId,
        role: "student",
        voipToken: "stale-cleared-fcm",
        voipPushToken: "stale-cleared-push",
      }),
      db.collection("userPrivateTokens").doc(clearedId).set({
        voipTokensClearedAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      }),
      userRef(privateId).set({
        uid: privateId,
        role: "student",
        voipToken: "stale-private-fcm",
        voipPushToken: "stale-private-push",
      }),
      db.collection("userPrivateTokens").doc(privateId).set({
        voipToken: "current-private-fcm",
        voipPushToken: "current-private-push",
        updatedAt: admin.firestore.Timestamp.now(),
      }),
    ]);

    await migrateLegacyVoipTokensBatch(10);

    const [clearedUser, clearedPrivate, privateUser, privatePrivate] =
      await Promise.all([
        userRef(clearedId).get(),
        db.collection("userPrivateTokens").doc(clearedId).get(),
        userRef(privateId).get(),
        db.collection("userPrivateTokens").doc(privateId).get(),
      ]);
    const clearedPrivateData = clearedPrivate.data();
    const privatePrivateData = privatePrivate.data();

    assert.equal(clearedUser.data().voipToken, undefined);
    assert.equal(clearedUser.data().voipPushToken, undefined);
    assert.equal(clearedPrivateData.voipToken, undefined);
    assert.equal(clearedPrivateData.voipPushToken, undefined);
    assert.ok(clearedPrivateData.voipTokensClearedAt);
    assert.equal(privateUser.data().voipToken, undefined);
    assert.equal(privateUser.data().voipPushToken, undefined);
    assert.equal(privatePrivateData.voipToken, "current-private-fcm");
    assert.equal(privatePrivateData.voipPushToken, "current-private-push");
  });

  test("markSessionConnected rejects unauthenticated callers", async () => {
    await expectHttpsError(
      () => wrappedMarkSessionConnected({sessionId: "session-a"}),
      "unauthenticated",
    );
  });

  test("markSessionConnected rejects path-shaped session ids", async () => {
    await expectHttpsError(
      () => wrappedMarkSessionConnected(
        {sessionId: "videoSessions/session-a"},
        authContext(uniqueId("student")),
      ),
      "invalid-argument",
    );
  });

  test("markSessionConnected keeps first participant signal advisory", async () => {
    const studentId = uniqueId("student");
    const teacherId = uniqueId("teacher");
    const sessionId = uniqueId("session");
    await db.collection("videoSessions").doc(sessionId).set({
      status: "active",
      requesterId: studentId,
      studentId,
      tutorId: teacherId,
      participantIds: [studentId, teacherId],
      dailyRoomName: `room-${sessionId}`,
      expiresAt: futureTimestamp(5),
      sessionMetadata: {},
    });

    const response = await wrappedMarkSessionConnected(
      {sessionId},
      authContext(studentId),
    );

    assert.equal(response.status, "signal_recorded");
    assert.equal(response.updated, true);
    assert.equal(response.connectedMarked, false);

    const sessionDoc = await db.collection("videoSessions").doc(sessionId).get();
    const sessionData = sessionDoc.data();
    assert.equal(sessionData.startedAt, undefined);
    assert.equal(sessionData.sessionMetadata.callConnectedAt, undefined);
    assert.equal(
      sessionData.sessionMetadata.connectedParticipantSignals[studentId].source,
      "markSessionConnected",
    );
  });

  test(
    "markSessionConnected keeps two client signals fail-closed without Daily room",
    async () => {
      const studentId = uniqueId("student");
      const teacherId = uniqueId("teacher");
      const sessionId = uniqueId("session");
      await db.collection("videoSessions").doc(sessionId).set({
        status: "active",
        requesterId: studentId,
        studentId,
        tutorId: teacherId,
        participantIds: [studentId, teacherId],
        expiresAt: futureTimestamp(5),
        sessionMetadata: {
          connectedParticipantSignals: {
            [studentId]: {
              markedAt: admin.firestore.Timestamp.now(),
              source: "markSessionConnected",
            },
          },
        },
      });

      const response = await wrappedMarkSessionConnected(
        {sessionId},
        authContext(teacherId),
      );

      assert.equal(response.status, "signal_recorded");
      assert.equal(response.connectedMarked, false);
      assert.equal(response.dailyPresenceVerificationRequired, true);
      assert.equal(response.dailyPresenceVerificationStatus, undefined);

      const sessionDoc =
        await db.collection("videoSessions").doc(sessionId).get();
      const sessionData = sessionDoc.data();
      assert.equal(sessionData.startedAt, undefined);
      assert.equal(sessionData.sessionMetadata.callConnectedAt, undefined);
      assert.equal(
        sessionData.sessionMetadata.connectedParticipantSignalsComplete,
        true,
      );
      assert.equal(
        sessionData.sessionMetadata.connectedParticipantSignals[teacherId]
          .source,
        "markSessionConnected",
      );
    },
  );

  test("markSessionConnected rejects nonparticipants", async () => {
    const studentId = uniqueId("student");
    const teacherId = uniqueId("teacher");
    const sessionId = uniqueId("session");
    await db.collection("videoSessions").doc(sessionId).set({
      status: "active",
      requesterId: studentId,
      studentId,
      tutorId: teacherId,
      participantIds: [studentId, teacherId],
      expiresAt: futureTimestamp(5),
      sessionMetadata: {},
    });

    await expectHttpsError(
      () => wrappedMarkSessionConnected(
        {sessionId},
        authContext(uniqueId("stranger")),
      ),
      "permission-denied",
    );
  });
}
