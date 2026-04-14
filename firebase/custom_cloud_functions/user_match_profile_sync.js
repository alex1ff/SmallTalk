const functions = require("firebase-functions/v1");

const {
  buildStoredMatchProfile,
  hasLegacyMatchProfileSource,
} = require("./video_sessions_shared");

function sortObject(value) {
  if (Array.isArray(value)) {
    return value.map((entry) => sortObject(entry));
  }

  if (value && typeof value === "object") {
    return Object.keys(value)
      .sort()
      .reduce((acc, key) => {
        acc[key] = sortObject(value[key]);
        return acc;
      }, {});
  }

  return value;
}

function areEqual(left, right) {
  return JSON.stringify(sortObject(left)) === JSON.stringify(sortObject(right));
}

exports.syncUserMatchProfile = functions.firestore
  .document("users/{userId}")
  .onWrite(async (change, context) => {
    if (!change.after.exists) {
      return null;
    }

    const beforeData = change.before.exists ? (change.before.data() || {}) : {};
    const afterData = change.after.data() || {};
    const preserveStoredValues =
      !hasLegacyMatchProfileSource(beforeData) &&
      !hasLegacyMatchProfileSource(afterData) &&
      !!afterData.matchProfile;
    const desiredMatchProfile = buildStoredMatchProfile(
      context.params.userId,
      afterData,
      {preserveStoredValues},
    );

    if (areEqual(afterData.matchProfile || null, desiredMatchProfile)) {
      return null;
    }

    await change.after.ref.set(
      {
        matchProfile: desiredMatchProfile,
      },
      {merge: true},
    );

    return null;
  });
