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
    await db.doc("users/legacy-teacher-a").set({
      display_name: "Legacy Teacher A",
      uid: "legacy-teacher-a",
      role: "teacher",
      availabilityToday: {
        enabled: false,
        intervals: [],
      },
    });
    await db.doc("users/downgrade-teacher-a").set({
      display_name: "Downgrade Teacher A",
      uid: "downgrade-teacher-a",
      role: "native_speaker",
      availabilityToday: {
        enabled: true,
        intervals: [],
      },
    });
    await db.doc("users/downgrade-teacher-b").set({
      display_name: "Downgrade Teacher B",
      uid: "downgrade-teacher-b",
      role: "native_speaker",
      availabilityToday: {
        enabled: true,
        intervals: [],
      },
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
  const availabilityStudentUser =
    testEnv.authenticatedContext("student-b-availability");
  const spoofedUidUser = testEnv.authenticatedContext("student-c");
  const nativeSpeakerUser = testEnv.authenticatedContext("teacher-b");

  await assertSucceeds(
    validUser.firestore().doc("users/student-b").set({
      display_name: "Student B",
      uid: "student-b",
      role: "student",
    }),
  );

  await assertSucceeds(
    testEnv
      .authenticatedContext("roleless-user")
      .firestore()
      .doc("users/roleless-user")
      .set({
        display_name: "Roleless User",
        uid: "roleless-user",
      }),
  );

  await assertFails(
    spoofedUidUser.firestore().doc("users/student-c").set({
      display_name: "Student C",
      uid: "teacher-a",
      role: "student",
    }),
  );

  await assertFails(
    availabilityStudentUser
      .firestore()
      .doc("users/student-b-availability")
      .set({
        display_name: "Student B Availability",
        uid: "student-b-availability",
        role: "student",
        availabilityToday: {
          enabled: true,
          intervals: [],
        },
      }),
  );

  await assertSucceeds(
    nativeSpeakerUser.firestore().doc("users/teacher-b").set({
      display_name: "Teacher B",
      uid: "teacher-b",
      role: "native_speaker",
      availabilityToday: {
        enabled: false,
        intervals: [],
      },
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

test("user cannot directly mutate live lifecycle fields or student availability", async () => {
  const user = testEnv.authenticatedContext("student-a");
  const teacher = testEnv.authenticatedContext("teacher-a");
  const legacyTeacher = testEnv.authenticatedContext("legacy-teacher-a");
  const downgradeTeacherA =
    testEnv.authenticatedContext("downgrade-teacher-a");
  const downgradeTeacherB =
    testEnv.authenticatedContext("downgrade-teacher-b");
  const db = user.firestore();

  await assertFails(
    db.doc("users/student-a").update({
      availabilityToday: {
        enabled: true,
        intervals: [],
      },
    }),
  );

  await assertSucceeds(
    teacher.firestore().doc("users/teacher-a").update({
      availabilityToday: {
        enabled: true,
        intervals: [],
      },
    }),
  );

  await assertSucceeds(
    legacyTeacher.firestore().doc("users/legacy-teacher-a").update({
      availabilityToday: {
        enabled: true,
        intervals: [],
      },
    }),
  );

  await assertSucceeds(
    db.doc("users/student-a").update({
      role: "native_speaker",
      teacherAccreditationStatus: "pending",
      verif_NS: false,
      availabilityToday: {
        enabled: false,
        intervals: [],
      },
    }),
  );

  await assertFails(
    downgradeTeacherA.firestore().doc("users/downgrade-teacher-a").update({
      role: "student",
    }),
  );

  await assertSucceeds(
    downgradeTeacherB.firestore().doc("users/downgrade-teacher-b").update({
      role: "student",
      availabilityToday: firebaseCompat.firestore.FieldValue.delete(),
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

test("video session navigation cleanup follows participant roles", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("videoSessions/navigation-cleanup-main").set({
      studentId: "student-a",
      tutorId: "teacher-a",
      participantIds: ["student-a", "teacher-a"],
      status: "connecting",
      studentNavigationTriggered: true,
      tutorNavigationTriggered: true,
    });
    await db.doc("videoSessions/navigation-cleanup-foreign").set({
      studentId: "student-a",
      tutorId: "teacher-a",
      participantIds: ["student-a", "teacher-a"],
      status: "connecting",
      studentNavigationTriggered: false,
      tutorNavigationTriggered: true,
    });
    await db.doc("videoSessions/navigation-cleanup-explicit-responder").set({
      studentId: "student-a",
      responderId: "teacher-a",
      participantIds: ["student-a", "teacher-a"],
      status: "connecting",
      studentNavigationTriggered: false,
      tutorNavigationTriggered: true,
    });
    await db.doc("videoSessions/navigation-cleanup-ambiguous-participant").set({
      studentId: "student-a",
      participantIds: ["student-a", "teacher-a"],
      status: "connecting",
      studentNavigationTriggered: false,
      tutorNavigationTriggered: true,
    });
  });

  const student = testEnv.authenticatedContext("student-a");
  const teacher = testEnv.authenticatedContext("teacher-a");
  const outsider = testEnv.authenticatedContext("student-b");
  const studentMainRef = student
    .firestore()
    .doc("videoSessions/navigation-cleanup-main");
  const teacherMainRef = teacher
    .firestore()
    .doc("videoSessions/navigation-cleanup-main");
  const studentForeignRef = student
    .firestore()
    .doc("videoSessions/navigation-cleanup-foreign");
  const teacherExplicitResponderRef = teacher
    .firestore()
    .doc("videoSessions/navigation-cleanup-explicit-responder");
  const teacherAmbiguousParticipantRef = teacher
    .firestore()
    .doc("videoSessions/navigation-cleanup-ambiguous-participant");
  const outsiderMainRef = outsider
    .firestore()
    .doc("videoSessions/navigation-cleanup-main");

  await assertSucceeds(studentMainRef.update({
    studentNavigationTriggered: false,
    navigationCompletedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));
  await assertSucceeds(teacherMainRef.update({
    tutorNavigationTriggered: false,
    navigationCompletedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));
  await assertSucceeds(teacherExplicitResponderRef.update({
    tutorNavigationTriggered: false,
    navigationCompletedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));

  await assertFails(studentForeignRef.update({
    tutorNavigationTriggered: false,
    navigationCompletedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));
  await assertFails(teacherAmbiguousParticipantRef.update({
    tutorNavigationTriggered: false,
    navigationCompletedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));
  await assertFails(outsiderMainRef.update({
    navigationCompletedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));
});

test("session participants can write only safe caption diagnostics", async () => {
  const sessionId = "caption-diagnostic-session";
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(`videoSessions/${sessionId}`).set({
      studentId: "student-a",
      tutorId: "teacher-a",
      participantIds: ["student-a", "teacher-a"],
      status: "in_call",
    });
  });

  const participant = testEnv.authenticatedContext("student-a");
  const otherParticipant = testEnv.authenticatedContext("teacher-a");
  const outsider = testEnv.authenticatedContext("student-b");
  const captionLogRef = participant
    .firestore()
    .doc(`videoSessions/${sessionId}/captionLogs/system_student-a_caption_token_unavailable`);
  const otherParticipantCaptionLogRef = otherParticipant
    .firestore()
    .doc(`videoSessions/${sessionId}/captionLogs/system_teacher-a_caption_token_unavailable`);

  const diagnosticData = (overrides = {}) => ({
    speakerId: "system",
    speakerName: "SmallTalk",
    speakerRole: "system",
    utteranceId: 0,
    text: "Субтитры временно недоступны: не удалось получить токен распознавания.",
    language: "ru",
    source: "caption_runtime_diagnostic",
    diagnosticCode: "caption_token_unavailable",
    capturedAtClient: new Date("2026-06-12T09:00:00.000Z"),
    createdAtServer: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    writerId: "student-a",
    ...overrides,
  });

  await assertSucceeds(captionLogRef.set(diagnosticData()));
  await assertSucceeds(
    participant
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/system_student-a_deepgram_token_grant_forbidden`)
      .set(diagnosticData({
        diagnosticCode: "deepgram_token_grant_forbidden",
        text: "Субтитры временно недоступны: сервис распознавания требует настройки.",
      })),
  );
  await assertSucceeds(captionLogRef.set(diagnosticData()));
  await assertSucceeds(
    otherParticipantCaptionLogRef.set(diagnosticData({
      writerId: "teacher-a",
    })),
  );

  await assertFails(
    captionLogRef.set(diagnosticData({
      text: "Deepgram 401 raw provider error",
    })),
  );

  await assertFails(
    otherParticipant
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/system_student-a_caption_token_unavailable`)
      .set(diagnosticData({
        writerId: "teacher-a",
      })),
  );

  await assertFails(
    participant
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/system_student-a_deepgram_websocket_error`)
      .set(diagnosticData({
        speakerId: "student-a",
        speakerName: "Student A",
        speakerRole: "student",
        diagnosticCode: "deepgram_websocket_error",
        text: "Deepgram 401 raw provider error",
      })),
  );

  await assertFails(
    participant
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/system_student-a_deepgram_websocket_error`)
      .set(diagnosticData({
        diagnosticCode: "deepgram_websocket_error",
      })),
  );

  await assertFails(
    participant
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/system_student-a_deepgram_token_grant_forbidden`)
      .set(diagnosticData({
        diagnosticCode: "deepgram_token_grant_forbidden",
      })),
  );

  await assertFails(
    participant
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/system_raw_error`)
      .set(diagnosticData({
        text: "Deepgram 401 raw provider error",
      })),
  );

  await assertFails(
    participant
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/system_teacher-a_caption_token_unavailable`)
      .set({
        speakerId: "system",
        speakerName: "SmallTalk",
        speakerRole: "system",
        utteranceId: 1,
        text: "Deepgram 401 raw provider error",
        language: "ru",
        source: "peer_legacy_final",
        capturedAtClient: new Date("2026-06-12T09:01:00.000Z"),
        createdAtServer: firebaseCompat.firestore.FieldValue.serverTimestamp(),
        writerId: "student-a",
      }),
  );

  await assertFails(
    participant
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/system_teacher-a_caption_token_unavailable`)
      .set({
        speakerId: "student-a",
        speakerName: "Student A",
        speakerRole: "student",
        utteranceId: 1,
        text: "Self caption in reserved id",
        language: "ru",
        source: "local_deepgram_final",
        capturedAtClient: new Date("2026-06-12T09:01:00.000Z"),
        createdAtServer: firebaseCompat.firestore.FieldValue.serverTimestamp(),
        writerId: "student-a",
      }),
  );

  await assertFails(
    participant
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/system_spoofed`)
      .set(diagnosticData({
        speakerId: "teacher-a",
      })),
  );

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/teacher-a_1`)
      .set({
        speakerId: "teacher-a",
        speakerName: "Teacher A",
        speakerRole: "tutor",
        utteranceId: 1,
        text: "Existing peer caption",
        language: "ru",
        source: "peer_legacy_final",
        capturedAtClient: new Date("2026-06-12T08:59:00.000Z"),
        createdAtServer: new Date("2026-06-12T08:59:00.000Z"),
        writerId: "student-a",
      });
  });

  await assertFails(
    participant
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/teacher-a_1`)
      .set(diagnosticData()),
  );

  await assertFails(
    participant
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/teacher-a_1`)
      .set({
        speakerId: "teacher-a",
        speakerName: "Changed Teacher",
        speakerRole: "tutor",
        utteranceId: 1,
        text: "Existing peer caption",
        language: "ru",
        source: "peer_legacy_final",
        capturedAtClient: new Date("2026-06-12T09:01:00.000Z"),
        createdAtServer: firebaseCompat.firestore.FieldValue.serverTimestamp(),
        writerId: "student-a",
      }),
  );

  await assertFails(
    outsider
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/system_student-b_caption_token_unavailable`)
      .set(diagnosticData({
        writerId: "student-b",
      })),
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

test("session participants can write bounded normal caption logs only for call participants", async () => {
  const sessionId = "caption-normal-session";
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(`videoSessions/${sessionId}`).set({
      studentId: "student-a",
      tutorId: "teacher-a",
      participantIds: ["student-a", "teacher-a"],
      status: "in_call",
    });
  });

  const participant = testEnv.authenticatedContext("student-a");
  const outsider = testEnv.authenticatedContext("student-b");
  const localCaptionLogRef = participant
    .firestore()
    .doc(`videoSessions/${sessionId}/captionLogs/student-a_1`);
  const peerCaptionLogRef = participant
    .firestore()
    .doc(`videoSessions/${sessionId}/captionLogs/teacher-a_2`);

  const normalCaptionData = (overrides = {}) => ({
    speakerId: "student-a",
    speakerName: "Student A",
    speakerRole: "student",
    utteranceId: 1,
    text: "Привет, это финальный локальный субтитр.",
    language: "ru",
    source: "local_deepgram_final",
    capturedAtClient: new Date("2026-06-12T09:05:00.000Z"),
    createdAtServer: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    writerId: "student-a",
    confidence: 0.91,
    ...overrides,
  });

  await assertSucceeds(localCaptionLogRef.set(normalCaptionData()));
  await assertSucceeds(localCaptionLogRef.set(normalCaptionData({
    text: "Обновленный финальный локальный субтитр.",
    confidence: 0.86,
  })));
  await assertSucceeds(peerCaptionLogRef.set(normalCaptionData({
    speakerId: "teacher-a",
    speakerName: "Teacher A",
    speakerRole: "tutor",
    utteranceId: 2,
    text: "Peer transcript from legacy app message.",
    source: "peer_legacy_final",
  })));
  await assertSucceeds(peerCaptionLogRef.set(normalCaptionData({
    speakerId: "teacher-a",
    speakerName: "Teacher A",
    speakerRole: "tutor",
    utteranceId: 2,
    text: "Updated peer transcript from legacy app message.",
    source: "peer_legacy_final",
  })));

  await assertFails(
    participant
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/student-a_999`)
      .set(normalCaptionData()),
  );
  await assertFails(localCaptionLogRef.set(normalCaptionData({
    utteranceId: 2,
  })));
  await assertFails(localCaptionLogRef.set(normalCaptionData({
    speakerName: "Changed Student",
  })));
  await assertFails(
    participant
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/student-a_2`)
      .set(normalCaptionData({
        speakerId: "teacher-a",
        speakerName: "Teacher A",
        speakerRole: "tutor",
        utteranceId: 2,
        source: "peer_legacy_final",
      })),
  );
  await assertFails(
    participant
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/student-b_3`)
      .set(normalCaptionData({
        speakerId: "student-b",
        speakerName: "Student B",
        speakerRole: "student",
        utteranceId: 3,
        source: "peer_legacy_final",
      })),
  );
  await assertFails(peerCaptionLogRef.set(normalCaptionData({
    speakerId: "student-a",
    speakerName: "Student A",
    speakerRole: "student",
    utteranceId: 2,
    source: "peer_legacy_final",
  })));
  await assertFails(localCaptionLogRef.set(normalCaptionData({
    source: "caption_runtime_diagnostic",
  })));
  await assertFails(localCaptionLogRef.set(normalCaptionData({
    debugRawError: "Deepgram 401 raw provider error",
  })));
  await assertFails(localCaptionLogRef.set(normalCaptionData({
    text: "",
  })));
  await assertFails(
    outsider
      .firestore()
      .doc(`videoSessions/${sessionId}/captionLogs/student-b_1`)
      .set(normalCaptionData({
        speakerId: "student-b",
        writerId: "student-b",
      })),
  );
});

test("unauthenticated users cannot read public user profiles", async () => {
  const unauthenticated = testEnv.unauthenticatedContext();

  await assertFails(
    unauthenticated.firestore().doc("userPublicProfiles/teacher-a").get(),
  );
});
