const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    compareCandidateDetails,
    getTeacherBoostScore,
    isTeacherBoostTargetLevel,
  },
} = require("./create_video_session");
const {
  buildMatchProfile,
  isSupportedSessionRole,
  normalizeRole,
} = require("./video_sessions_shared");

test("supported session roles keep the all-to-all matrix open", () => {
  assert.equal(normalizeRole("student"), "student");
  assert.equal(normalizeRole("native_speaker"), "native_speaker");
  assert.equal(normalizeRole("teacher"), "native_speaker");
  assert.equal(normalizeRole("Tutor"), "native_speaker");

  assert.equal(isSupportedSessionRole("student"), true);
  assert.equal(isSupportedSessionRole("native_speaker"), true);
  assert.equal(isSupportedSessionRole("teacher"), true);
  assert.equal(isSupportedSessionRole("tutor"), true);
  assert.equal(isSupportedSessionRole("admin"), false);
});

test("buildMatchProfile preserves requester/candidate role variants and teacher approval", () => {
  const studentProfile = buildMatchProfile(
    "student-a",
    {
      role: "student",
      learningLanguage: { code: "en" },
      Country_NS: "RU",
      level: "Fluent",
      rating: { average: 4.1, totalReviews: 3 },
    },
    "en",
  );
  const approvedNativeSpeakerProfile = buildMatchProfile(
    "teacher-b",
    {
      role: "teacher",
      native_language_NS: { code: "en" },
      Country_NS: "US",
      level: "Fluent",
      teacherAccreditationStatus: "approved",
      rating: { average: 4.7, totalReviews: 8 },
    },
    "en",
  );

  assert.equal(studentProfile.role, "student");
  assert.equal(studentProfile.approvedTeacher, false);
  assert.equal(studentProfile.activeLanguage, "en");
  assert.equal(approvedNativeSpeakerProfile.role, "native_speaker");
  assert.equal(approvedNativeSpeakerProfile.approvedTeacher, true);
  assert.equal(approvedNativeSpeakerProfile.activeLanguage, "en");
});

test("teacher boost applies only for Fluent approved-teacher ranking", () => {
  assert.equal(isTeacherBoostTargetLevel("Fluent"), true);
  assert.equal(isTeacherBoostTargetLevel("Advanced"), false);
  assert.equal(isTeacherBoostTargetLevel(""), false);

  assert.equal(
    getTeacherBoostScore({ approvedTeacher: true }, true),
    1,
  );
  assert.equal(
    getTeacherBoostScore({ approvedTeacher: false }, true),
    0,
  );
  assert.equal(
    getTeacherBoostScore({ approvedTeacher: true }, false),
    0,
  );
});

test("compareCandidateDetails prioritizes location, teacher boost, ratings, and tie-breakers", () => {
  const detailsById = {
    locationMatched: {
      locationMatch: true,
      teacherBoostScore: 0,
      ratingAverage: 4.0,
      ratingCount: 5,
      legacyPriorityScore: 10,
    },
    locationMismatched: {
      locationMatch: false,
      teacherBoostScore: 1,
      ratingAverage: 5.0,
      ratingCount: 100,
      legacyPriorityScore: 0,
    },
    boostedTeacher: {
      locationMatch: true,
      teacherBoostScore: 1,
      ratingAverage: 4.2,
      ratingCount: 10,
      legacyPriorityScore: 50,
    },
    higherRatedPeer: {
      locationMatch: true,
      teacherBoostScore: 0,
      ratingAverage: 4.9,
      ratingCount: 80,
      legacyPriorityScore: 1,
    },
    higherRated: {
      locationMatch: true,
      teacherBoostScore: 0,
      ratingAverage: 4.9,
      ratingCount: 1,
      legacyPriorityScore: 50,
    },
    moreReviewed: {
      locationMatch: true,
      teacherBoostScore: 0,
      ratingAverage: 4.5,
      ratingCount: 20,
      legacyPriorityScore: 1,
    },
    fewerReviewed: {
      locationMatch: true,
      teacherBoostScore: 0,
      ratingAverage: 4.5,
      ratingCount: 2,
      legacyPriorityScore: 0,
    },
    lowerLegacyPriority: {
      locationMatch: true,
      teacherBoostScore: 0,
      ratingAverage: 4.5,
      ratingCount: 2,
      legacyPriorityScore: 1,
    },
    higherLegacyPriority: {
      locationMatch: true,
      teacherBoostScore: 0,
      ratingAverage: 4.5,
      ratingCount: 2,
      legacyPriorityScore: 5,
    },
  };

  assert.ok(
    compareCandidateDetails(
      "locationMatched",
      "locationMismatched",
      detailsById,
    ) < 0,
  );
  assert.ok(
    compareCandidateDetails(
      "boostedTeacher",
      "higherRatedPeer",
      detailsById,
    ) < 0,
  );
  assert.ok(
    compareCandidateDetails(
      "higherRated",
      "moreReviewed",
      detailsById,
    ) < 0,
  );
  assert.ok(
    compareCandidateDetails(
      "moreReviewed",
      "fewerReviewed",
      detailsById,
    ) < 0,
  );
  assert.ok(
    compareCandidateDetails(
      "lowerLegacyPriority",
      "higherLegacyPriority",
      detailsById,
    ) < 0,
  );
});

test(
  "createVideoSession source still references expected ranking and repeat/policy hooks",
  () => {
  const source = fs.readFileSync(
    path.join(__dirname, "create_video_session.js"),
    "utf8",
  );

  assert.match(source, /if \(!isSupportedSessionRole\(requesterRole\)\)/);
  assert.match(source, /if \(!isSupportedSessionRole\(tutorRole\)/);
  assert.match(source, /teacherBoostRankingApplied = isTeacherBoostTargetLevel/);
  assert.match(
    source,
    /availableTutors\.sort\(\(a, b\) => compareCandidateDetails\(a, b, tutorDetails\)\)/,
  );
  assert.match(source, /loadSameDayRepeatCandidateIds\(\s*db,\s*requesterId,/);
  assert.match(source, /const sessionPolicyFields = buildCreateSessionPolicyFields\(\);/);
  },
);
