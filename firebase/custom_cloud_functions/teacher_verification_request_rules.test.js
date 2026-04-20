const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const firebaseCompat = require("firebase/compat/app");

require("firebase/compat/firestore");

const projectId = process.env.GCLOUD_PROJECT || "demo-smalltalk";
const firestoreHostRaw = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const [firestoreHost, firestorePortStr] = firestoreHostRaw.split(":");
const firestorePort = Number.parseInt(firestorePortStr || "8080", 10);
const firestoreRules = fs.readFileSync(
  path.join(__dirname, "..", "firestore.rules"),
  "utf8",
);

function serverTimestamp() {
  return firebaseCompat.firestore.FieldValue.serverTimestamp();
}

let testEnv;

async function seedUser(context, userId) {
  await context.firestore().doc(`users/${userId}`).set({
    display_name: userId,
  });
}

function buildRequestData({
  userId,
  userRef,
  createdAt,
  status,
  updatedAt,
  accreditation,
  extra = {},
}) {
  return {
    userId,
    userRef,
    status,
    displayName: "Teacher Request User",
    photoUrl: "https://example.com/avatar.jpg",
    languageInstruction: {code: "en"},
    nativeLanguage: {code: "ru"},
    country: {code: "US"},
    aboutMe: "Request bio",
    accreditation,
    createdAt,
    updatedAt,
    ...extra,
  };
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: firestoreHost,
      port: firestorePort,
      rules: firestoreRules,
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await seedUser(context, "teacherRequestUser");
    await seedUser(context, "approvedTeacherUser");
  });
});

test("rejected request can be resubmitted and clears stale review metadata", async () => {
  const createdAt = new Date("2026-04-18T00:00:00.000Z");
  const previousReviewedAt = new Date("2026-04-18T01:00:00.000Z");

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context
      .firestore()
      .doc("teacherVerificationRequests/teacherRequestUser")
      .set(
        buildRequestData({
          userId: "teacherRequestUser",
          userRef: context.firestore().doc("users/teacherRequestUser"),
          createdAt,
          status: "rejected",
          updatedAt: previousReviewedAt,
          accreditation: {
            teachingExperience: "0_1_year",
            qualificationProof: "other",
            teachingFormats: ["conversation"],
          },
          extra: {
            reviewComment: "Denied previously",
            reviewedBy: "adminUser",
            reviewedAt: previousReviewedAt,
          },
        }),
      );
  });

  const user = testEnv.authenticatedContext("teacherRequestUser");
  const requestRef = user
    .firestore()
    .doc("teacherVerificationRequests/teacherRequestUser");

  await assertSucceeds(
    requestRef.set(
      buildRequestData({
        userId: "teacherRequestUser",
        userRef: user.firestore().doc("users/teacherRequestUser"),
        createdAt,
        status: "pending",
        updatedAt: serverTimestamp(),
        accreditation: {
          teachingExperience: "1_3_years",
          qualificationProof: "degree",
        },
      }),
    ),
  );

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const snapshot = await context
      .firestore()
      .doc("teacherVerificationRequests/teacherRequestUser")
      .get();
    const data = snapshot.data();

    assert.equal(data.status, "pending");
    assert.equal(data.createdAt.toDate().toISOString(), createdAt.toISOString());
    assert.equal(data.reviewComment, undefined);
    assert.equal(data.reviewedBy, undefined);
    assert.equal(data.reviewedAt, undefined);
    assert.deepEqual(data.accreditation, {
      teachingExperience: "1_3_years",
      qualificationProof: "degree",
    });
  });
});

test("approved request cannot be overwritten by the user", async () => {
  const createdAt = new Date("2026-04-18T00:00:00.000Z");
  const reviewedAt = new Date("2026-04-18T01:00:00.000Z");

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context
      .firestore()
      .doc("teacherVerificationRequests/approvedTeacherUser")
      .set(
        buildRequestData({
          userId: "approvedTeacherUser",
          userRef: context.firestore().doc("users/approvedTeacherUser"),
          createdAt,
          status: "approved",
          updatedAt: reviewedAt,
          accreditation: {
            teachingExperience: "3_5_years",
            qualificationProof: "degree",
          },
          extra: {
            reviewedBy: "adminUser",
            reviewedAt,
          },
        }),
      );
  });

  const user = testEnv.authenticatedContext("approvedTeacherUser");

  await assertFails(
    user
      .firestore()
      .doc("teacherVerificationRequests/approvedTeacherUser")
      .set(
        buildRequestData({
          userId: "approvedTeacherUser",
          userRef: user.firestore().doc("users/approvedTeacherUser"),
          createdAt,
          status: "pending",
          updatedAt: serverTimestamp(),
          accreditation: {
            teachingExperience: "5_plus_years",
            qualificationProof: "degree",
          },
        }),
      ),
  );
});

test("qualification evidence files must use owned storage paths", async () => {
  const user = testEnv.authenticatedContext("teacherRequestUser");
  const requestRef = user
    .firestore()
    .doc("teacherVerificationRequests/teacherRequestUser");

  await assertSucceeds(
    requestRef.set(
      buildRequestData({
        userId: "teacherRequestUser",
        userRef: user.firestore().doc("users/teacherRequestUser"),
        createdAt: serverTimestamp(),
        status: "pending",
        updatedAt: serverTimestamp(),
        accreditation: {
          teachingExperience: "1_3_years",
          qualificationProof: "degree",
          qualificationProofs: ["degree", "certificate"],
          qualificationProofFiles: [
            {
              name: "Diploma.pdf",
              storagePath:
                "users/teacherRequestUser/teacher_verification/qualification_proofs/Diploma.pdf",
            },
          ],
        },
      }),
    ),
  );
});

test("qualification evidence files reject legacy download URLs", async () => {
  const user = testEnv.authenticatedContext("teacherRequestUser");

  await assertFails(
    user
      .firestore()
      .doc("teacherVerificationRequests/teacherRequestUser")
      .set(
        buildRequestData({
          userId: "teacherRequestUser",
          userRef: user.firestore().doc("users/teacherRequestUser"),
          createdAt: serverTimestamp(),
          status: "pending",
          updatedAt: serverTimestamp(),
          accreditation: {
            teachingExperience: "1_3_years",
            qualificationProof: "degree",
            qualificationProofFiles: [
              {
                name: "Diploma.pdf",
                url: "https://firebasestorage.googleapis.com/v0/b/demo/o/users%2FteacherRequestUser%2Fteacher_verification%2Fqualification_proofs%2FDiploma.pdf?alt=media&token=secret",
              },
            ],
          },
        }),
      ),
  );
});

test("qualification evidence files reject paths outside the user folder", async () => {
  const user = testEnv.authenticatedContext("teacherRequestUser");

  await assertFails(
    user
      .firestore()
      .doc("teacherVerificationRequests/teacherRequestUser")
      .set(
        buildRequestData({
          userId: "teacherRequestUser",
          userRef: user.firestore().doc("users/teacherRequestUser"),
          createdAt: serverTimestamp(),
          status: "pending",
          updatedAt: serverTimestamp(),
          accreditation: {
            teachingExperience: "1_3_years",
            qualificationProof: "degree",
            qualificationProofFiles: [
              {
                name: "Diploma.pdf",
                storagePath:
                  "users/approvedTeacherUser/teacher_verification/qualification_proofs/Diploma.pdf",
              },
            ],
          },
        }),
      ),
  );
});

test("approved teacher cannot self-downgrade the canonical user status", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("users/approvedTeacherUser").set({
      teacherAccreditationStatus: "approved",
      verif_NS: true,
      teacherVerificationRequestRef: context
        .firestore()
        .doc("teacherVerificationRequests/approvedTeacherUser"),
      matchProfile: {
        teacherAccreditationStatus: "approved",
        approvedTeacher: true,
      },
    }, {merge: true});
  });

  const user = testEnv.authenticatedContext("approvedTeacherUser");

  await assertFails(
    user.firestore().doc("users/approvedTeacherUser").update({
      teacherAccreditationStatus: "pending",
      verif_NS: false,
    }),
  );
});

test("rejected teacher can self-set canonical status back to pending", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("users/teacherRequestUser").set({
      teacherAccreditationStatus: "rejected",
      verif_NS: false,
      teacherVerificationRequestRef: context
        .firestore()
        .doc("teacherVerificationRequests/teacherRequestUser"),
    }, {merge: true});
  });

  const user = testEnv.authenticatedContext("teacherRequestUser");

  await assertSucceeds(
    user.firestore().doc("users/teacherRequestUser").update({
      teacherAccreditationStatus: "pending",
      verif_NS: false,
    }),
  );
});
