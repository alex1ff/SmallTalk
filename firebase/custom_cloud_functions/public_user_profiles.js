const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");
const {
  normalizeRole,
  readCountryCode,
  readLanguageCode,
  readLevelValue,
  readMatchRatingAverage,
  readMatchRatingCount,
  readTeacherAccreditationStatus,
} = require("./video_sessions_shared");

const PUBLIC_USER_PROFILE_COLLECTION = "userPublicProfiles";
const PUBLIC_PROFILE_PRIVATE_FIELDS = Object.freeze([
  "email",
  "phone_number",
  "balanceST",
  "balance_NS",
  "earnings",
  "giftMinutes",
  "subscription",
  "voipToken",
  "voipPushToken",
  "currentSessionId",
  "isInCall",
  "isAvailable",
  "availableAfter",
  "lastCallEndedAt",
  "availabilityToday",
  "timezoneOffsetMinutes",
  "teacherAccreditationStatus",
  "friends",
  "favoriteNativeSpeakers",
  "blockedUsers",
]);

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function compactPublicData(data) {
  return Object.entries(data).reduce((acc, [key, value]) => {
    if (value === undefined || value === null || value === "") {
      return acc;
    }
    acc[key] = value;
    return acc;
  }, {});
}

function readNestedPublicString(value, key) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return "";
  }

  return normalizeString(value[key]);
}

function languageProjection(value) {
  const data = compactPublicData({
    code: readLanguageCode(value),
    nameEn: readNestedPublicString(value, "nameEn"),
    nameRu: readNestedPublicString(value, "nameRu"),
    ss: readNestedPublicString(value, "ss"),
  });
  return Object.keys(data).length > 0 ? data : null;
}

function countryProjection(value) {
  const data = compactPublicData({
    code: readCountryCode(value),
    nameEn: readNestedPublicString(value, "nameEn"),
    nameRu: readNestedPublicString(value, "nameRu"),
    flag: readNestedPublicString(value, "flag"),
  });
  return Object.keys(data).length > 0 ? data : null;
}

function matchProfileData(userData = {}) {
  return userData.matchProfile &&
    typeof userData.matchProfile === "object" &&
    !Array.isArray(userData.matchProfile) ?
    userData.matchProfile :
    {};
}

function assertNoPrivatePublicProfileFields(profileData) {
  const leakedFields = PUBLIC_PROFILE_PRIVATE_FIELDS.filter((field) =>
    Object.prototype.hasOwnProperty.call(profileData, field),
  );
  if (leakedFields.length > 0) {
    throw new Error(
      `Public user profile includes private fields: ${leakedFields.join(",")}`,
    );
  }
}

function buildPublicUserProfile(userId, userData = {}, options = {}) {
  const storedMatchProfile = matchProfileData(userData);
  const teacherAccreditationStatus = readTeacherAccreditationStatus(userData);
  const profileData = compactPublicData({
    version: "v1",
    userId: normalizeString(userId),
    display_name: normalizeString(userData.display_name),
    photo_url: normalizeString(userData.photo_url),
    role: normalizeRole(userData.role) || normalizeRole(storedMatchProfile.role),
    isProfileComplete: userData.isProfileComplete === true,
    aboutMe: normalizeString(userData.aboutMe),
    language_instruction_NS: languageProjection(userData.language_instruction_NS),
    native_language_NS: languageProjection(userData.native_language_NS),
    Country_NS: countryProjection(userData.Country_NS),
    level: readLevelValue(userData.level),
    ratingAverage: readMatchRatingAverage(userData),
    ratingCount: readMatchRatingCount(userData),
    approvedTeacher: teacherAccreditationStatus === "approved",
    lastSeenAt: userData.lastSeenAt,
    updatedAt: options.updatedAt ?? FieldValue.serverTimestamp(),
  });

  assertNoPrivatePublicProfileFields(profileData);
  return profileData;
}

exports.syncUserPublicProfile = functions.firestore
  .document("users/{userId}")
  .onWrite(async (change, context) => {
    const db = admin.firestore();
    const publicProfileRef = db
      .collection(PUBLIC_USER_PROFILE_COLLECTION)
      .doc(context.params.userId);

    if (!change.after.exists) {
      await publicProfileRef.delete();
      return null;
    }

    const publicProfile = buildPublicUserProfile(
      context.params.userId,
      change.after.data() || {},
    );
    await publicProfileRef.set(publicProfile);
    return null;
  });

exports.__private__ = {
  PUBLIC_PROFILE_PRIVATE_FIELDS,
  PUBLIC_USER_PROFILE_COLLECTION,
  assertNoPrivatePublicProfileFields,
  buildPublicUserProfile,
  compactPublicData,
  matchProfileData,
};
