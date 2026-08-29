const EVENT_PREVIEW_COLLECTION = "events_public";
const EVENT_PREVIEW_DESCRIPTION_MAX_LENGTH = 160;

function normalizeText(value) {
  return typeof value === "string" ? value.trim() : "";
}

function shortEventDescription(value) {
  const text = normalizeText(value);
  return text.length <= EVENT_PREVIEW_DESCRIPTION_MAX_LENGTH ?
    text : `${text.slice(0, EVENT_PREVIEW_DESCRIPTION_MAX_LENGTH).trim()}…`;
}

function eventPreviewRef(db, eventId) {
  return db.collection(EVENT_PREVIEW_COLLECTION).doc(eventId);
}

function buildEventPreviewData(eventData = {}, {sourceUpdateTime = null} = {}) {
  const preview = {
    title: normalizeText(eventData.title),
    description: shortEventDescription(eventData.description),
    languageCode: normalizeText(eventData.languageCode),
    languageNameEn: normalizeText(eventData.languageNameEn),
    languageNameRu: normalizeText(eventData.languageNameRu),
    levelMin: normalizeText(eventData.levelMin),
    levelMax: normalizeText(eventData.levelMax),
    countryCode: normalizeText(eventData.countryCode),
    cityKey: normalizeText(eventData.cityKey),
    cityNameRu: normalizeText(eventData.cityNameRu),
    cityNameEn: normalizeText(eventData.cityNameEn),
    cityDisplayContext: normalizeText(eventData.cityDisplayContext),
    startsAt: eventData.startsAt || null,
    timeZoneId: normalizeText(eventData.timeZoneId),
    capacity: Number.isInteger(eventData.capacity) ? eventData.capacity : null,
    participantsCount: Number.isInteger(eventData.participantsCount) ?
      eventData.participantsCount : null,
    organizerId: normalizeText(eventData.organizerId),
    organizerDisplayName: normalizeText(eventData.organizerDisplayName),
    organizerPhotoUrl: normalizeText(eventData.organizerPhotoUrl) || null,
    status: normalizeText(eventData.status),
    createdAt: eventData.createdAt || null,
    updatedAt: eventData.updatedAt || null,
    canceledAt: eventData.canceledAt || null,
  };
  if (sourceUpdateTime != null) preview.sourceUpdateTime = sourceUpdateTime;
  return preview;
}

function writeEventPreview({tx, previewDoc, previewRef, eventData}) {
  // Direct callable transactions keep the projection atomically aligned with
  // the source document, but they do not have access to the committed
  // DocumentSnapshot.updateTime. Only the trigger/repair paths may write the
  // server-owned source revision.
  const previewData = buildEventPreviewData(eventData);
  if (previewDoc.exists) {
    tx.update(previewRef, previewData);
  } else {
    tx.create(previewRef, previewData);
  }
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const millis = Number(value);
  return Number.isFinite(millis) && millis > 0 ? millis : null;
}

function shouldReplaceEventPreview(currentData, incomingData) {
  const currentSourceAt = timestampMillis(currentData?.sourceUpdateTime);
  const incomingSourceAt = timestampMillis(incomingData?.sourceUpdateTime);
  if (currentSourceAt != null && incomingSourceAt != null) {
    return incomingSourceAt > currentSourceAt;
  }
  if (currentSourceAt != null && incomingSourceAt == null) return false;
  if (currentSourceAt == null && incomingSourceAt != null) return true;

  const currentAt = timestampMillis(currentData?.updatedAt);
  const incomingAt = timestampMillis(incomingData?.updatedAt);
  if (currentAt == null || incomingAt == null) return true;
  return incomingAt > currentAt;
}

module.exports = {
  EVENT_PREVIEW_COLLECTION,
  EVENT_PREVIEW_DESCRIPTION_MAX_LENGTH,
  buildEventPreviewData,
  eventPreviewRef,
  shortEventDescription,
  shouldReplaceEventPreview,
  timestampMillis,
  writeEventPreview,
};
