const crypto = require("node:crypto");
const admin = require("firebase-admin");

const SEARCH_CANCELLATION_INTENT_COLLECTION = "searchCancellationIntents";
const SEARCH_CANCELLATION_INTENT_TTL_MS = 10 * 60 * 1000;

function normalizeSearchLifecycleRequestId(value) {
  const normalized = typeof value === "string" ? value.trim() : "";
  if (
    !normalized ||
    normalized.length > 512 ||
    normalized.includes("/") ||
    normalized === "." ||
    normalized === ".." ||
    /^__.*__$/.test(normalized)
  ) {
    return "";
  }
  return normalized;
}

function buildSearchCancellationIntentId(userId, requestId) {
  const normalizedUserId = normalizeSearchLifecycleRequestId(userId);
  const normalizedRequestId = normalizeSearchLifecycleRequestId(requestId);
  if (!normalizedUserId || !normalizedRequestId) return "";
  return crypto.createHash("sha256")
    .update(`${normalizedUserId}:${normalizedRequestId}`)
    .digest("hex");
}

function searchCancellationIntentRef(db, userId, requestId) {
  const intentId = buildSearchCancellationIntentId(userId, requestId);
  if (!intentId) return null;
  return db.collection(SEARCH_CANCELLATION_INTENT_COLLECTION).doc(intentId);
}

function buildSearchCancellationIntentData({
  userId,
  requestId,
  nowMillis = Date.now(),
  serverTimestamp = admin.firestore.FieldValue.serverTimestamp(),
} = {}) {
  return {
    userId,
    requestId,
    status: "pending",
    createdAt: serverTimestamp,
    updatedAt: serverTimestamp,
    expiresAt: admin.firestore.Timestamp.fromMillis(
      nowMillis + SEARCH_CANCELLATION_INTENT_TTL_MS,
    ),
  };
}

function timestampToMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return Number(value.toMillis());
  if (typeof value.toDate === "function") return value.toDate().getTime();
  const millis = Number(value);
  return Number.isFinite(millis) ? millis : null;
}

function isSearchCancellationIntentActive({
  intentData = {},
  userId,
  requestId,
  nowMillis = Date.now(),
} = {}) {
  return intentData.userId === userId &&
    intentData.requestId === requestId &&
    ["pending", "consumed"].includes(intentData.status) &&
    (timestampToMillis(intentData.expiresAt) || 0) > nowMillis;
}

module.exports = {
  SEARCH_CANCELLATION_INTENT_COLLECTION,
  SEARCH_CANCELLATION_INTENT_TTL_MS,
  buildSearchCancellationIntentData,
  buildSearchCancellationIntentId,
  isSearchCancellationIntentActive,
  normalizeSearchLifecycleRequestId,
  searchCancellationIntentRef,
};
