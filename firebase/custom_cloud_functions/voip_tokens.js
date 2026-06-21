const admin = require("firebase-admin");

const TOKEN_COLLECTION = "userPrivateTokens";
const DEFAULT_MIGRATION_LIMIT = 250;
const LEGACY_USER_TOKEN_DELETE_FIELDS = {
  voipToken: admin.firestore.FieldValue.delete(),
  voipTokenUpdatedAt: admin.firestore.FieldValue.delete(),
  voipPushToken: admin.firestore.FieldValue.delete(),
  voipPushTokenUpdatedAt: admin.firestore.FieldValue.delete(),
};
const PRIVATE_TOKEN_CLEAR_FIELDS = {
  voipToken: admin.firestore.FieldValue.delete(),
  voipTokenUpdatedAt: admin.firestore.FieldValue.delete(),
  voipPushToken: admin.firestore.FieldValue.delete(),
  voipPushTokenUpdatedAt: admin.firestore.FieldValue.delete(),
};

function normalizeVoipToken(value) {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim();
}

function normalizeVoipTokenType(value) {
  const normalized = normalizeVoipToken(value).toLowerCase();
  if (["fcm", "firebase", "firebase_messaging"].includes(normalized)) {
    return "fcm";
  }
  if (["pushkit", "voip", "apns_voip"].includes(normalized)) {
    return "pushkit";
  }
  return "";
}

function buildVoipTokenUpdate(tokenType, token) {
  const normalizedType = normalizeVoipTokenType(tokenType);
  const normalizedToken = normalizeVoipToken(token);
  if (!normalizedType || !normalizedToken || normalizedToken.length > 4096) {
    return null;
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  if (normalizedType === "fcm") {
    return {
      voipToken: normalizedToken,
      voipTokenUpdatedAt: now,
      updatedAt: now,
    };
  }

  return {
    voipPushToken: normalizedToken,
    voipPushTokenUpdatedAt: now,
    updatedAt: now,
  };
}

function privateTokenRef(userId, firestore = admin.firestore()) {
  return firestore.collection(TOKEN_COLLECTION).doc(userId);
}

function userRef(userId, firestore = admin.firestore()) {
  return firestore.collection("users").doc(userId);
}

function hasLegacyVoipTokens(userData = {}) {
  return Boolean(
    normalizeVoipToken(userData.voipToken) ||
      normalizeVoipToken(userData.voipPushToken),
  );
}

function hasPrivateVoipTokens(privateData = {}) {
  return Boolean(
    normalizeVoipToken(privateData.voipToken) ||
      normalizeVoipToken(privateData.voipPushToken),
  );
}

function hasVoipTokensCleared(privateData = {}) {
  return Boolean(privateData.voipTokensClearedAt);
}

function isVoipTokenFallbackDisabled(privateData = {}) {
  return hasVoipTokensCleared(privateData) &&
    !hasPrivateVoipTokens(privateData);
}

function buildReadOnlyVoipTokenState({
  privateData = {},
  legacyUserData = {},
} = {}) {
  if (isVoipTokenFallbackDisabled(privateData)) {
    return {
      hasUsableToken: false,
      source: "cleared",
      hasFcmToken: false,
      hasVoipPushToken: false,
    };
  }

  const privatePushToken = normalizeVoipToken(privateData.voipPushToken);
  const privateFcmToken = normalizeVoipToken(privateData.voipToken);
  const legacyAllowed = !hasVoipTokensCleared(privateData);
  const legacyPushToken = legacyAllowed ?
    normalizeVoipToken(legacyUserData.voipPushToken) :
    "";
  const legacyFcmToken = legacyAllowed ?
    normalizeVoipToken(legacyUserData.voipToken) :
    "";
  const hasVoipPushToken = Boolean(privatePushToken || legacyPushToken);
  const hasFcmToken = Boolean(privateFcmToken || legacyFcmToken);
  const hasPrivateToken = Boolean(privatePushToken || privateFcmToken);
  const hasLegacyToken = Boolean(legacyPushToken || legacyFcmToken);

  return {
    hasUsableToken: Boolean(hasFcmToken || hasVoipPushToken),
    source: hasPrivateToken ? "private" : hasLegacyToken ? "legacy" : "none",
    hasFcmToken,
    hasVoipPushToken,
  };
}

function buildPrivateTokenDataFromLegacy(legacyData = {}) {
  const update = {};
  const legacyFcmToken = normalizeVoipToken(legacyData.voipToken);
  const legacyPushToken = normalizeVoipToken(legacyData.voipPushToken);

  if (legacyFcmToken) {
    update.voipToken = legacyFcmToken;
    update.voipTokenUpdatedAt =
      legacyData.voipTokenUpdatedAt ||
      admin.firestore.FieldValue.serverTimestamp();
  }
  if (legacyPushToken) {
    update.voipPushToken = legacyPushToken;
    update.voipPushTokenUpdatedAt =
      legacyData.voipPushTokenUpdatedAt ||
      admin.firestore.FieldValue.serverTimestamp();
  }
  if (Object.keys(update).length > 0) {
    update.updatedAt = admin.firestore.FieldValue.serverTimestamp();
  }

  return update;
}

function preserveLegacyCompanionToken(
  update,
  legacyData = {},
  privateData = {},
) {
  if (hasVoipTokensCleared(privateData)) {
    return;
  }
  if (update.voipToken && !update.voipPushToken) {
    const legacyPushToken = normalizeVoipToken(legacyData.voipPushToken);
    if (legacyPushToken) {
      update.voipPushToken = legacyPushToken;
      update.voipPushTokenUpdatedAt =
        legacyData.voipPushTokenUpdatedAt || update.updatedAt;
    }
  }
  if (update.voipPushToken && !update.voipToken) {
    const legacyFcmToken = normalizeVoipToken(legacyData.voipToken);
    if (legacyFcmToken) {
      update.voipToken = legacyFcmToken;
      update.voipTokenUpdatedAt = legacyData.voipTokenUpdatedAt || update.updatedAt;
    }
  }
}

async function deleteLegacyUserVoipTokenFields(userId) {
  try {
    await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .update(LEGACY_USER_TOKEN_DELETE_FIELDS);
  } catch (error) {
    if (error?.code === 5 || error?.code === "not-found") {
      return;
    }
    throw error;
  }
}

async function saveUserVoipToken(userId, tokenType, token) {
  const baseUpdate = buildVoipTokenUpdate(tokenType, token);
  if (!baseUpdate) {
    return false;
  }

  const firestore = admin.firestore();
  await firestore.runTransaction(async (transaction) => {
    const update = {...baseUpdate};
    const legacyUserRef = userRef(userId, firestore);
    const privateRef = privateTokenRef(userId, firestore);
    const legacyUserSnap = await transaction.get(legacyUserRef);
    const privateSnap = await transaction.get(privateRef);
    preserveLegacyCompanionToken(
      update,
      legacyUserSnap.exists ? legacyUserSnap.data() || {} : {},
      privateSnap.exists ? privateSnap.data() || {} : {},
    );
    update.voipTokensClearedAt = admin.firestore.FieldValue.delete();
    transaction.set(privateRef, update, { merge: true });
    if (legacyUserSnap.exists) {
      transaction.update(legacyUserRef, LEGACY_USER_TOKEN_DELETE_FIELDS);
    }
  });
  return true;
}

async function clearUserVoipTokens(userId) {
  const firestore = admin.firestore();
  await firestore.runTransaction(async (transaction) => {
    const legacyUserRef = userRef(userId, firestore);
    const legacyUserSnap = await transaction.get(legacyUserRef);
    transaction.set(
      privateTokenRef(userId, firestore),
      {
        ...PRIVATE_TOKEN_CLEAR_FIELDS,
        voipTokensClearedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    if (legacyUserSnap.exists) {
      transaction.update(legacyUserRef, LEGACY_USER_TOKEN_DELETE_FIELDS);
    }
  });
}

async function migrateLegacyVoipTokensForUser(
  userId,
  legacyUserData = {},
  _privateData = null,
) {
  if (!hasLegacyVoipTokens(legacyUserData)) {
    return false;
  }

  const firestore = admin.firestore();
  let migrated = false;

  await firestore.runTransaction(async (transaction) => {
    const legacyUserRef = userRef(userId, firestore);
    const privateRef = privateTokenRef(userId, firestore);
    const privateSnap = await transaction.get(privateRef);
    const legacyUserSnap = await transaction.get(legacyUserRef);
    const currentLegacyData = legacyUserSnap.exists
      ? legacyUserSnap.data() || {}
      : {};
    if (!hasLegacyVoipTokens(currentLegacyData)) {
      return;
    }

    const existingPrivateData = privateSnap.exists
      ? privateSnap.data() || {}
      : {};
    const shouldPreservePrivateTokens =
      isVoipTokenFallbackDisabled(existingPrivateData) ||
      hasPrivateVoipTokens(existingPrivateData);
    const update = shouldPreservePrivateTokens
      ? {}
      : buildPrivateTokenDataFromLegacy(currentLegacyData);
    if (Object.keys(update).length > 0) {
      transaction.set(privateRef, update, { merge: true });
    }
    transaction.update(legacyUserRef, LEGACY_USER_TOKEN_DELETE_FIELDS);
    migrated = true;
  });

  return migrated;
}

async function getUserVoipTokens(userId, legacyUserData = {}) {
  const privateSnap = await privateTokenRef(userId).get();
  const privateData = privateSnap.exists ? privateSnap.data() || {} : {};
  const legacyAllowed = !hasVoipTokensCleared(privateData);
  if (isVoipTokenFallbackDisabled(privateData)) {
    if (hasLegacyVoipTokens(legacyUserData)) {
      await deleteLegacyUserVoipTokenFields(userId);
    }
    return {
      voipPushToken: "",
      voipToken: "",
    };
  }

  if (
    legacyAllowed &&
    hasLegacyVoipTokens(legacyUserData) &&
    !hasPrivateVoipTokens(privateData)
  ) {
    await migrateLegacyVoipTokensForUser(userId, legacyUserData, privateData);
  }

  return {
    voipPushToken:
      normalizeVoipToken(privateData.voipPushToken) ||
      (legacyAllowed ? normalizeVoipToken(legacyUserData.voipPushToken) : ""),
    voipToken:
      normalizeVoipToken(privateData.voipToken) ||
      (legacyAllowed ? normalizeVoipToken(legacyUserData.voipToken) : ""),
  };
}

async function getReadOnlyUserVoipTokenState(
  userId,
  legacyUserData = {},
  firestore = admin.firestore(),
) {
  const privateSnap = await privateTokenRef(userId, firestore).get();
  const privateData = privateSnap.exists ? privateSnap.data() || {} : {};

  return buildReadOnlyVoipTokenState({
    privateData,
    legacyUserData,
  });
}

async function migrateLegacyVoipTokensBatch(limit = DEFAULT_MIGRATION_LIMIT) {
  const firestore = admin.firestore();
  const safeLimit = Math.max(
    1,
    Math.min(Number(limit) || DEFAULT_MIGRATION_LIMIT, 500),
  );
  const seenUserIds = new Set();
  const users = [];

  for (const fieldName of ["voipToken", "voipPushToken"]) {
    const snapshot = await firestore
      .collection("users")
      .where(fieldName, "!=", null)
      .limit(safeLimit)
      .get();

    snapshot.docs.forEach((doc) => {
      if (!seenUserIds.has(doc.id)) {
        seenUserIds.add(doc.id);
        users.push({ id: doc.id, data: doc.data() || {} });
      }
    });
  }

  let migratedCount = 0;
  for (const user of users.slice(0, safeLimit)) {
    if (await migrateLegacyVoipTokensForUser(user.id, user.data)) {
      migratedCount += 1;
    }
  }

  return {
    migratedCount,
    scannedCount: users.length,
  };
}

module.exports = {
  buildReadOnlyVoipTokenState,
  buildVoipTokenUpdate,
  clearUserVoipTokens,
  getReadOnlyUserVoipTokenState,
  getUserVoipTokens,
  migrateLegacyVoipTokensBatch,
  migrateLegacyVoipTokensForUser,
  normalizeVoipToken,
  normalizeVoipTokenType,
  preserveLegacyCompanionToken,
  saveUserVoipToken,
};
