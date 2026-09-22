const assert = require("assert");
const admin = require("firebase-admin");
const functionsTestFactory = require("firebase-functions-test");

const getSessionTokensModule = require("./get_session_tokens");
const getDeepgramTokenModule = require("./get_deepgram_token");
const endSessionModule = require("./end_session");
const submitReviewModule = require("./submit_review");

const functionsTest = functionsTestFactory({ projectId: "demo-smalltalk" });

function makeSessionSnap(sessionData) {
  return {
    exists: true,
    data: () => sessionData,
    ref: {
      update: async () => {},
    },
  };
}

function installFirestoreMock(sessionData) {
  const mockDb = {
    collection: (collectionPath) => ({
      doc: (documentId) => ({
        path: `${collectionPath}/${documentId}`,
        get: async () => makeSessionSnap(sessionData),
      }),
    }),
    runTransaction: async (callback) =>
      callback({
        get: async () => makeSessionSnap(sessionData),
      }),
  };

  Object.defineProperty(admin, "firestore", {
    configurable: true,
    value: () => mockDb,
  });
}

async function expectErrorCode(promiseFactory, expectedCode) {
  try {
    await promiseFactory();
    assert.fail(`Expected error code ${expectedCode}`);
  } catch (error) {
    const code = error?.code || String(error);
    assert.ok(
      String(code).includes(expectedCode),
      `Expected ${expectedCode}, received ${code}`,
    );
  }
}

async function main() {
  const originalFirestoreDescriptor = Object.getOwnPropertyDescriptor(
    admin,
    "firestore",
  );

  const wrappedGetSessionTokens = functionsTest.wrap(
    getSessionTokensModule.getSessionTokens,
  );
  const wrappedGetDeepgramToken = functionsTest.wrap(
    getDeepgramTokenModule.getDeepgramToken,
  );
  const wrappedEndSession = functionsTest.wrap(endSessionModule.endSession);
  const wrappedSubmitReview = functionsTest.wrap(submitReviewModule.submitReview);

  try {
    installFirestoreMock({
      participantIds: ["student-1", "tutor-1"],
      studentId: "student-1",
      tutorId: "tutor-1",
      status: "active",
    });
    await expectErrorCode(
      () =>
        wrappedGetSessionTokens(
          { sessionId: "session-1" },
          { auth: { uid: "tutor-1" } },
        ),
      "failed-precondition",
    );

    installFirestoreMock({
      studentId: "student-1",
      tutorId: "tutor-1",
      status: "active",
    });
    await expectErrorCode(
      () =>
        wrappedGetSessionTokens(
          { sessionId: "session-legacy" },
          { auth: { uid: "tutor-1" } },
        ),
      "failed-precondition",
    );

    installFirestoreMock({
      studentId: "student-1",
      currentTutorId: "tutor-pending",
      status: "searching",
    });
    await expectErrorCode(
      () =>
        wrappedGetSessionTokens(
          { sessionId: "session-pending" },
          { auth: { uid: "tutor-pending" } },
        ),
      "permission-denied",
    );

    installFirestoreMock({
      participantIds: ["student-1", "tutor-1"],
      studentId: "student-1",
      tutorId: "tutor-1",
      status: "active",
    });
    await expectErrorCode(
      () =>
        wrappedGetDeepgramToken(
          { sessionId: "session-2" },
          { auth: { uid: "tutor-1" } },
        ),
      "failed-precondition",
    );

    installFirestoreMock({
      studentId: "student-1",
      currentTutorId: "tutor-pending",
      status: "searching",
    });
    await expectErrorCode(
      () =>
        wrappedGetDeepgramToken(
          { sessionId: "session-pending-2" },
          { auth: { uid: "tutor-pending" } },
        ),
      "permission-denied",
    );

    installFirestoreMock({
      participantIds: ["student-1", "tutor-1"],
      studentId: "student-1",
      tutorId: "tutor-1",
      status: "ended",
    });
    const endSessionResult = await wrappedEndSession(
      { sessionId: "session-ended" },
      { auth: { uid: "tutor-1" } },
    );
    assert.strictEqual(endSessionResult.status, "already_ended");

    installFirestoreMock({
      participantIds: ["student-1"],
      studentId: "student-1",
      tutorId: "",
      status: "ended",
    });
    await expectErrorCode(
      () =>
        wrappedSubmitReview(
          {
            sessionId: "session-review",
            rating: 5,
            comment: "ok",
          },
          { auth: { uid: "student-1" } },
        ),
      "failed-precondition",
    );
  } finally {
    if (originalFirestoreDescriptor) {
      Object.defineProperty(admin, "firestore", originalFirestoreDescriptor);
    } else {
      delete admin.firestore;
    }
    await functionsTest.cleanup();
  }

  console.log("session_callable_auth tests passed");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
