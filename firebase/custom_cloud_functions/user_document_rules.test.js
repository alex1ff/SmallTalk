const test = require("node:test");
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

let testEnv;

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
    const db = context.firestore();
    await db.doc("users/student-a").set({
      display_name: "Student A",
      uid: "student-a",
      role: "student",
      balance_NS: 24,
    });
    await db.doc("users/teacher-a").set({
      display_name: "Teacher A",
      uid: "teacher-a",
      role: "native_speaker",
      teacherAccreditationStatus: "approved",
      balance_NS: 120,
    });
    await db.doc("users/legacy-student-profile").set({
      display_name: "Legacy Student A",
      uid: "student-a",
      role: "student",
    });
    await db.doc("users/teacher-a/cards/card-a").set({
      num: "Visa",
      pan: "**** 4242",
    });
    await db.doc("userPublicProfiles/teacher-a").set({
      userId: "teacher-a",
      display_name: "Teacher A",
      photo_url: "https://cdn.example.com/teacher-a.jpg",
      role: "native_speaker",
      isProfileComplete: true,
      language_instruction_NS: {code: "en"},
      Country_NS: {code: "US"},
      level: "Fluent",
    });
  });
});

test("user can update ordinary profile fields", async () => {
  const user = testEnv.authenticatedContext("student-a");

  await assertSucceeds(
    user.firestore().doc("users/student-a").update({
      display_name: "Updated Student",
    }),
  );
});

test("users collection reads are scoped to self, admin, or legacy uid lookup", async () => {
  const user = testEnv.authenticatedContext("student-a");
  const admin = testEnv.authenticatedContext("admin-user", {admin: true});
  const db = user.firestore();

  await assertSucceeds(db.doc("users/student-a").get());
  await assertSucceeds(db.doc("users/legacy-student-profile").get());
  await assertFails(db.doc("users/teacher-a").get());
  await assertSucceeds(
    db.collection("users").where("uid", "==", "student-a").limit(2).get(),
  );
  await assertFails(db.collection("users").get());
  await assertFails(
    db.collection("users").where("role", "==", "native_speaker").get(),
  );
  await assertSucceeds(admin.firestore().collection("users").get());
});

test("user create requires own uid and blocks client lifecycle fields", async () => {
  const validUser = testEnv.authenticatedContext("student-b");
  const spoofedUidUser = testEnv.authenticatedContext("student-c");

  await assertSucceeds(
    validUser.firestore().doc("users/student-b").set({
      display_name: "Student B",
      uid: "student-b",
      role: "student",
    }),
  );

  await assertFails(
    spoofedUidUser.firestore().doc("users/student-c").set({
      display_name: "Student C",
      uid: "teacher-a",
      role: "student",
    }),
  );

  const lifecycleFieldSamples = {
    isInCall: false,
    currentSessionId: "session-a",
    isAvailable: true,
    availableAfter: new Date("2026-05-26T10:00:00.000Z"),
    lastCallEndedAt: new Date("2026-05-26T10:00:00.000Z"),
  };

  let lifecycleUserIndex = 0;
  for (const [field, value] of Object.entries(lifecycleFieldSamples)) {
    lifecycleUserIndex += 1;
    const uid = `student-lifecycle-${lifecycleUserIndex}`;
    const lifecycleUser = testEnv.authenticatedContext(uid);

    await assertFails(
      lifecycleUser.firestore().doc(`users/${uid}`).set({
        display_name: "Lifecycle Student",
        uid,
        role: "student",
        [field]: value,
      }),
    );
  }
});

test("user cannot directly mutate role outside allowed onboarding paths", async () => {
  const user = testEnv.authenticatedContext("student-a");
  const db = user.firestore();

  await assertFails(
    db.doc("users/student-a").update({
      role: "native_speaker",
    }),
  );

  await assertSucceeds(
    db.doc("users/student-a").update({
      role: "native_speaker",
      teacherAccreditationStatus: "pending",
      verif_NS: false,
    }),
  );

  await assertSucceeds(
    db.doc("users/student-a").update({
      role: "student",
    }),
  );
});

test("user cannot directly mutate live lifecycle fields", async () => {
  const user = testEnv.authenticatedContext("student-a");
  const db = user.firestore();

  await assertSucceeds(
    db.doc("users/student-a").update({
      availabilityToday: {
        enabled: true,
        intervals: [],
      },
    }),
  );

  for (const field of [
    "isInCall",
    "currentSessionId",
    "isAvailable",
    "availableAfter",
    "lastCallEndedAt",
  ]) {
    await assertFails(
      db.doc("users/student-a").update({
        [field]: field === "isInCall" || field === "isAvailable" ? false : "",
      }),
    );
  }
});

test("user can update own lastSeenAt only to request time", async () => {
  const user = testEnv.authenticatedContext("student-a");
  const db = user.firestore();

  await assertSucceeds(
    db.doc("users/student-a").update({
      lastSeenAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    }),
  );

  await assertFails(
    db.doc("users/student-a").update({
      lastSeenAt: new Date("2026-05-30T09:41:00.000Z"),
    }),
  );

  await assertFails(
    testEnv.authenticatedContext("student-b").firestore()
      .doc("users/student-a")
      .update({
        lastSeenAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
      }),
  );
});

test("user cannot create server-owned trial or balance fields", async () => {
  const user = testEnv.authenticatedContext("student-b");

  await assertFails(
    user.firestore().doc("users/student-b").set({
      display_name: "Student B",
      role: "student",
      giftMinutes: {
        minutes: 999,
        source: "registration",
      },
    }),
  );

  await assertFails(
    user.firestore().doc("users/student-b").set({
      display_name: "Student B",
      role: "student",
      balance_NS: 999,
    }),
  );

  await assertFails(
    user.firestore().doc("users/student-b").set({
      display_name: "Student B",
      role: "student",
      balanceST: {
        minutes: 999,
        smallTalks: 999,
      },
    }),
  );
});

test("user cannot update server-owned user fields", async () => {
  const user = testEnv.authenticatedContext("student-a");

  await assertFails(
    user.firestore().doc("users/student-a").update({
      giftMinutes: {
        minutes: 999,
        source: "registration",
      },
    }),
  );

  await assertFails(
    user.firestore().doc("users/student-a").update({
      subscription: {
        status: "active",
      },
    }),
  );

  await assertFails(
    user.firestore().doc("users/student-a").update({
      rating: {
        average: 5,
        totalReviews: 999,
      },
    }),
  );

  await assertFails(
    user.firestore().doc("users/student-a").update({
      priorityScore: 999,
    }),
  );

  await assertFails(
    user.firestore().doc("users/student-a").update({
      earnings: {
        available: 999,
      },
    }),
  );
});

test("user cannot directly set or clear balance_NS", async () => {
  const user = testEnv.authenticatedContext("student-a");

  await assertFails(
    user.firestore().doc("users/student-a").update({
      balance_NS: 999,
    }),
  );

  await assertFails(
    user.firestore().doc("users/student-a").update({
      balance_NS: firebaseCompat.firestore.FieldValue.delete(),
    }),
  );
});

test("admin can update server-owned user fields", async () => {
  const admin = testEnv.authenticatedContext("admin-user", {admin: true});

  await assertSucceeds(
    admin.firestore().doc("users/student-a").update({
      giftMinutes: {
        minutes: 10,
        source: "admin_grant",
      },
      subscription: {
        status: "active",
      },
      balance_NS: 10,
      rating: {
        average: 5,
        totalReviews: 1,
      },
      isInCall: false,
      currentSessionId: "session-a",
      isAvailable: true,
    }),
  );
});

test("client cannot directly create withdrawal transactions", async () => {
  const teacher = testEnv.authenticatedContext("teacher-a");
  const db = teacher.firestore();

  await assertFails(
    db.doc("transactions/withdrawal-without-clear").set({
      userId: db.doc("users/teacher-a"),
      createdAt: new Date("2026-05-26T10:00:00.000Z"),
      type: "withdrawal",
      status: "pending",
      amount: 120,
      card: db.doc("users/teacher-a/cards/card-a"),
    }),
  );
});

test("client can no longer create bonus transactions directly", async () => {
  const user = testEnv.authenticatedContext("student-a");
  const db = user.firestore();

  await assertFails(
    db.doc("transactions/client-bonus").set({
      userId: db.doc("users/student-a"),
      createdAt: new Date("2026-05-26T10:00:00.000Z"),
      type: "bonus",
      status: "completed",
      amount_ST: 0,
    }),
  );
});

test("registration gift claim docs are admin-only", async () => {
  const user = testEnv.authenticatedContext("student-a");

  await assertFails(
    user.firestore().doc("registrationGiftClaims/student-a").set({
      status: "granted",
    }),
  );

  await assertFails(
    user.firestore().doc("registrationGiftClaims/student-a").get(),
  );
});

test("signed-in users can query but not write public user profiles", async () => {
  const user = testEnv.authenticatedContext("student-a");
  const db = user.firestore();

  await assertSucceeds(db.doc("userPublicProfiles/teacher-a").get());

  await assertSucceeds(
    db
      .collection("userPublicProfiles")
      .where("role", "==", "native_speaker")
      .where("isProfileComplete", "==", true)
      .get(),
  );

  await assertFails(
    db.doc("userPublicProfiles/student-a").set({
      userId: "student-a",
      display_name: "Forged Public Profile",
      role: "native_speaker",
      isProfileComplete: true,
    }),
  );

  await assertFails(
    db.doc("userPublicProfiles/teacher-a").update({
      display_name: "Tampered Teacher",
    }),
  );
});

test("unauthenticated users cannot read public user profiles", async () => {
  const unauthenticated = testEnv.unauthenticatedContext();

  await assertFails(
    unauthenticated.firestore().doc("userPublicProfiles/teacher-a").get(),
  );
});
