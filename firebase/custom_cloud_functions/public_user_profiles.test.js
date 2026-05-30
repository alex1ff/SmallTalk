const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    PUBLIC_PROFILE_PRIVATE_FIELDS,
    PUBLIC_USER_PROFILE_COLLECTION,
    buildPublicUserProfile,
  },
} = require("./public_user_profiles");

function readSource(relativePath) {
  return fs.readFileSync(path.join(__dirname, "..", "..", relativePath), "utf8");
}

function readFunctionSource(fileName) {
  return fs.readFileSync(path.join(__dirname, fileName), "utf8");
}

test("public profile projection exposes only non-private matching fields", () => {
  const profile = buildPublicUserProfile(
    "teacher-a",
    {
      display_name: " Teacher A ",
      photo_url: " https://example.com/avatar.jpg ",
      role: "teacher",
      isProfileComplete: true,
      aboutMe: " Public teacher bio ",
      language_instruction_NS: {
        code: "EN",
        nameEn: "English",
        nameRu: "Angliyskiy",
        ss: "https://example.com/en.svg",
      },
      native_language_NS: {
        code: "ES",
        nameEn: "Spanish",
        nameRu: "Ispanskiy",
      },
      Country_NS: {
        code: "US",
        nameEn: "United States",
        nameRu: "SShA",
        flag: "us",
      },
      level: "Fluent",
      rating: {
        average: 4.7,
        totalReviews: 11,
      },
      teacherAccreditationStatus: "approved",
      email: "teacher@example.com",
      phone_number: "+15550000000",
      balance_NS: 120,
      giftMinutes: {minutes: 999},
      subscription: {status: "active"},
      currentSessionId: "session-a",
      isInCall: true,
      isAvailable: true,
      availableAfter: "later",
      lastCallEndedAt: "later",
      availabilityToday: {enabled: true},
      timezoneOffsetMinutes: -300,
      friends: ["users/student-a"],
      blockedUsers: ["users/bad"],
      lastSeenAt: "last-seen",
    },
    {updatedAt: "fixed"},
  );

  assert.deepEqual(profile, {
    version: "v1",
    userId: "teacher-a",
    display_name: "Teacher A",
    photo_url: "https://example.com/avatar.jpg",
    role: "native_speaker",
    isProfileComplete: true,
    aboutMe: "Public teacher bio",
    language_instruction_NS: {
      code: "en",
      nameEn: "English",
      nameRu: "Angliyskiy",
      ss: "https://example.com/en.svg",
    },
    native_language_NS: {
      code: "es",
      nameEn: "Spanish",
      nameRu: "Ispanskiy",
    },
    Country_NS: {
      code: "US",
      nameEn: "United States",
      nameRu: "SShA",
      flag: "us",
    },
    level: "Fluent",
    ratingAverage: 4.7,
    ratingCount: 11,
    approvedTeacher: true,
    lastSeenAt: "last-seen",
    updatedAt: "fixed",
  });

  for (const privateField of PUBLIC_PROFILE_PRIVATE_FIELDS) {
    assert.equal(profile[privateField], undefined);
  }
});

test("public profile sync is exported and has a backfill script", () => {
  const indexSource = readFunctionSource("index.js");
  const backfillSource = readFunctionSource(
    "scripts/backfill_user_public_profiles.js",
  );

  assert.match(indexSource, /exports\.syncUserPublicProfile/);
  assert.match(backfillSource, /backfillUserPublicProfiles/);
  assert.match(backfillSource, /bulkWriter\(\)/);
  assert.equal(PUBLIC_USER_PROFILE_COLLECTION, "userPublicProfiles");
  assert.match(backfillSource, /PUBLIC_USER_PROFILE_COLLECTION/);
});

test("public profile backfill writes only safe public projections", async () => {
  const writes = [];
  let writerClosed = false;
  const users = [
    {
      id: "teacher-a",
      data: () => ({
        display_name: " Teacher A ",
        photo_url: "https://example.com/teacher-a.jpg",
        role: "teacher",
        isProfileComplete: true,
        teacherAccreditationStatus: "approved",
        email: "teacher@example.com",
        phone_number: "+15550000000",
        balance_NS: 100,
        voipToken: "private-fcm",
        currentSessionId: "session-a",
        isInCall: true,
      }),
    },
    {
      id: "student-a",
      data: () => ({
        display_name: " Student A ",
        role: "student",
        email: "student@example.com",
        giftMinutes: {minutes: 10},
      }),
    },
  ];
  const db = {
    collection(collectionName) {
      if (collectionName === "users") {
        return {
          async get() {
            return {
              forEach(callback) {
                users.forEach(callback);
              },
            };
          },
        };
      }
      if (collectionName === "userPublicProfiles") {
        return {
          doc(id) {
            return {collectionName, id};
          },
        };
      }
      throw new Error(`Unexpected collection ${collectionName}`);
    },
    bulkWriter() {
      return {
        set(ref, data) {
          writes.push({ref, data});
        },
        async close() {
          writerClosed = true;
        },
      };
    },
  };
  const {
    backfillUserPublicProfiles,
  } = require("./scripts/backfill_user_public_profiles");

  const result = await backfillUserPublicProfiles({db});

  assert.equal(result.queued, 2);
  assert.equal(writerClosed, true);
  assert.deepEqual(
    writes.map((write) => `${write.ref.collectionName}/${write.ref.id}`),
    ["userPublicProfiles/teacher-a", "userPublicProfiles/student-a"],
  );
  for (const write of writes) {
    for (const privateField of PUBLIC_PROFILE_PRIVATE_FIELDS) {
      assert.equal(write.data[privateField], undefined);
    }
  }
  assert.equal(writes[0].data.display_name, "Teacher A");
  assert.equal(writes[0].data.approvedTeacher, true);
  assert.equal(writes[1].data.display_name, "Student A");
});

test("public profile backfill closes writer for empty user collection", async () => {
  let writerClosed = false;
  const db = {
    collection(collectionName) {
      assert.equal(collectionName, "users");
      return {
        async get() {
          return {
            forEach(_callback) {},
          };
        },
      };
    },
    bulkWriter() {
      return {
        set() {
          assert.fail("empty backfill should not queue writes");
        },
        async close() {
          writerClosed = true;
        },
      };
    },
  };
  const {
    backfillUserPublicProfiles,
  } = require("./scripts/backfill_user_public_profiles");

  const result = await backfillUserPublicProfiles({db});

  assert.equal(result.queued, 0);
  assert.equal(writerClosed, true);
});

test("student dashboard partner count reads public profiles", () => {
  const dashboardSource = readSource(
    "lib/students_pages/students_dashboard/students_dashboard_widget.dart",
  );
  const chatThreadSource = readSource(
    "lib/shared_pages/chat_thread/chat_thread_widget.dart",
  );
  const callDetailsSource = readSource(
    "lib/shared_pages/call_details/call_details_widget.dart",
  );
  const callSummarySource = readSource(
    "lib/shared_pages/call_summary/call_summary_widget.dart",
  );
  const callSummaryModelSource = readSource(
    "lib/shared_pages/call_summary/call_summary_model.dart",
  );
  const reviewCardSource = readSource(
    "lib/components/review_card/review_card_widget.dart",
  );
  const favSource = readSource(
    "lib/components/fav_widget.dart",
  );
  const favoriteSource = readSource(
    "lib/students_pages/favorite/favorite_widget.dart",
  );
  const blackListSource = readSource(
    "lib/shared_pages/black_list/black_list_widget.dart",
  );
  const nativeSpeakerSource = readSource(
    "lib/students_pages/native_speaker_page/native_speaker_page_widget.dart",
  );
  const publicProfileRecordSource = readSource(
    "lib/backend/schema/user_public_profiles_record.dart",
  );

  assert.match(dashboardSource, /collection\('userPublicProfiles'\)/);
  assert.match(dashboardSource, /'language_instruction_NS\.code'/);
  assert.match(dashboardSource, /'Country_NS\.code'/);
  assert.doesNotMatch(
    dashboardSource,
    /UsersRecord\.collection\s*\.where\('role'/,
  );
  assert.match(chatThreadSource, /UserPublicProfilesRecord\.maybeGetDocument/);
  assert.match(callDetailsSource, /UserPublicProfilesRecord\.collection/);
  assert.match(callSummarySource, /FutureBuilder<UserPublicProfilesRecord\?>/);
  assert.match(callSummarySource, /Future\.value\(null\)/);
  assert.match(
    callSummarySource,
    /UserPublicProfilesRecord\.collection\.doc\(userRef\.id\)/,
  );
  assert.match(
    callSummaryModelSource,
    /Future<UserPublicProfilesRecord\?>\? userFuture/,
  );
  assert.doesNotMatch(
    callSummarySource,
    /UsersRecord\.getDocumentOnce\(widget\.userRef!\)/,
  );
  assert.match(reviewCardSource, /Future<UserPublicProfilesRecord\?>/);
  assert.match(
    reviewCardSource,
    /UserPublicProfilesRecord\.collection\.doc\(authorRef\.id\)/,
  );
  assert.doesNotMatch(reviewCardSource, /UsersRecord\.getDocumentOnce\(authorRef\)/);
  assert.match(favSource, /Future<UserPublicProfilesRecord\?>/);
  assert.match(
    favSource,
    /UserPublicProfilesRecord\.collection\.doc\(userRef\.id\)/,
  );
  assert.doesNotMatch(
    favSource,
    /UsersRecord\.getDocumentOnce\(widget\.nsUser!\)/,
  );
  assert.match(favoriteSource, /Future<UserPublicProfilesRecord\?>/);
  assert.match(
    favoriteSource,
    /UserPublicProfilesRecord\.collection\.doc\(ref\.id\)/,
  );
  assert.doesNotMatch(
    favoriteSource,
    /UsersRecord\.getDocumentOnce\(ref\)/,
  );
  assert.match(blackListSource, /Future<UserPublicProfilesRecord\?>/);
  assert.match(
    blackListSource,
    /UserPublicProfilesRecord\.collection\.doc\(ref\.id\)/,
  );
  assert.match(blackListSource, /FieldValue\.arrayRemove\(\[/);
  assert.match(blackListSource, /listItem/);
  assert.doesNotMatch(
    blackListSource,
    /UsersRecord\.getDocumentOnce\(ref\)/,
  );
  assert.match(nativeSpeakerSource, /StreamBuilder<UserPublicProfilesRecord\?>/);
  assert.match(nativeSpeakerSource, /_nativeSpeakerPublicProfileStream/);
  assert.match(
    nativeSpeakerSource,
    /UserPublicProfilesRecord\.collection\.doc\(targetRef\.id\)/,
  );
  assert.match(nativeSpeakerSource, /httpsCallable\('getDirectCallStatus'\)/);
  assert.match(nativeSpeakerSource, /_ensureDirectCallStatus/);
  assert.match(nativeSpeakerSource, /canStartCall\(currentUserDocument\)/);
  assert.doesNotMatch(
    nativeSpeakerSource,
    /UsersRecord\.getDocument\(widget\.nsUserDocRef!\)/,
  );
  assert.doesNotMatch(nativeSpeakerSource, /availabilityToday/);
  assert.doesNotMatch(nativeSpeakerSource, /snapshotData\['timezoneOffsetMinutes'\]/);
  assert.doesNotMatch(nativeSpeakerSource, /isInCall/);
  assert.match(publicProfileRecordSource, /snapshotData\['display_name'\]/);
  assert.match(publicProfileRecordSource, /snapshotData\['photo_url'\]/);
  assert.match(publicProfileRecordSource, /snapshotData\['aboutMe'\]/);
  assert.match(publicProfileRecordSource, /nativeLanguageNS/);
  assert.match(publicProfileRecordSource, /CountryStruct/);
});

test("Firestore rules make public profiles readable but server-owned", () => {
  const rules = readSource("firebase/firestore.rules");
  const indexes = readSource("firebase/firestore.indexes.json");

  assert.match(rules, /match \/userPublicProfiles\/\{userId\}/);
  assert.match(rules, /allow read: if isSignedIn\(\);/);
  assert.match(rules, /allow write: if false;/);
  assert.match(indexes, /"collectionGroup": "userPublicProfiles"/);
  assert.match(indexes, /"fieldPath": "isProfileComplete"/);
});
