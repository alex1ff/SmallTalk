const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {buildEventPreviewData} = require("./event_public_projection");
const {isPaidPremium} = require("./trial_access");

function normalizeEventId(value) {
  const eventId = typeof value === "string" ? value.trim() : "";
  return eventId && !eventId.includes("/") ? eventId : "";
}

function timestampMillis(value) {
  return value && typeof value.toMillis === "function" ? value.toMillis() : null;
}

function canReturnEventDetail(eventData, fullAccess) {
  return eventData.status === "active" || fullAccess === true;
}

function hasFullEventAccess(eventData, {
  uid,
  userData = {},
  participantData = {},
  isAdmin = false,
  now = Date.now(),
} = {}) {
  const privilegedAccess = eventData.organizerId === uid ||
    participantData.status === "active" || isAdmin;
  return privilegedAccess ||
    (eventData.status === "active" && isPaidPremium(userData, now));
}

function serializeEventData(data = {}, {full = false} = {}) {
  const source = full ? data : buildEventPreviewData(data);
  return {
    title: source.title || "",
    description: source.description || "",
    languageCode: source.languageCode || "",
    languageNameEn: source.languageNameEn || "",
    languageNameRu: source.languageNameRu || "",
    levelMin: source.levelMin || "",
    levelMax: source.levelMax || "",
    countryCode: source.countryCode || "",
    cityKey: source.cityKey || "",
    cityNameRu: source.cityNameRu || "",
    cityNameEn: source.cityNameEn || "",
    cityDisplayContext: source.cityDisplayContext || "",
    startsAtMs: timestampMillis(source.startsAt),
    timeZoneId: source.timeZoneId || "",
    capacity: Number.isInteger(source.capacity) ? source.capacity : null,
    participantsCount: Number.isInteger(source.participantsCount) ?
      source.participantsCount : null,
    organizerId: source.organizerId || "",
    organizerDisplayName: source.organizerDisplayName || "",
    organizerPhotoUrl: source.organizerPhotoUrl || null,
    status: source.status || "",
    createdAtMs: timestampMillis(source.createdAt),
    updatedAtMs: timestampMillis(source.updatedAt),
    canceledAtMs: timestampMillis(source.canceledAt),
    ...(full ? {
      locationName: data.locationName || "",
      locationGeoPoint: data.locationGeoPoint ? {
        latitude: data.locationGeoPoint.latitude,
        longitude: data.locationGeoPoint.longitude,
      } : null,
      chatId: data.chatId || "",
    } : {}),
  };
}

exports.getEventDetails = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
        {domainCode: "auth_required"},
    );
  }
  const eventId = normalizeEventId(data?.eventId);
  if (!eventId || Object.keys(data || {}).some((key) => key !== "eventId")) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid event id",
        {domainCode: "invalid_event_request"},
    );
  }
  const uid = context.auth.uid;
  const db = admin.firestore();
  const eventRef = db.collection("events").doc(eventId);
  const userRef = db.collection("users").doc(uid);
  const participantRef = eventRef.collection("participants").doc(uid);
  const [eventSnap, userSnap, participantSnap] = await Promise.all([
    eventRef.get(),
    userRef.get(),
    participantRef.get(),
  ]);
  if (!eventSnap.exists) {
    throw new functions.https.HttpsError(
        "not-found",
        "Event not found",
        {domainCode: "event_not_found"},
    );
  }
  const eventData = eventSnap.data() || {};
  const userData = userSnap.exists ? userSnap.data() || {} : {};
  const participantData = participantSnap.exists ? participantSnap.data() || {} : {};
  const fullAccess = hasFullEventAccess(eventData, {
    uid,
    userData,
    participantData,
    isAdmin: context.auth.token.admin === true,
  });
  if (!canReturnEventDetail(eventData, fullAccess)) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Event details are not available",
        {domainCode: "event_detail_access_denied"},
    );
  }
  return {
    eventId,
    access: fullAccess ? "full" : "preview",
    event: serializeEventData(eventData, {full: fullAccess}),
  };
});

exports.__private__ = {
  normalizeEventId,
  canReturnEventDetail,
  hasFullEventAccess,
  serializeEventData,
};
