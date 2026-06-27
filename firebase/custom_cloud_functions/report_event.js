const crypto = require("node:crypto");
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

const REQUEST_TIMEOUT_SECONDS = 30;
const EVENT_REPORTS_COLLECTION = "eventReports";
const EVENT_STATUS_ACTIVE = "active";
const REPORT_EVENT_KEYS = Object.freeze(["eventId", "reasonCode", "details"]);
const REPORT_EVENT_REQUIRED_KEYS = Object.freeze(["eventId", "reasonCode"]);
const REPORT_EVENT_KEY_SET = new Set(REPORT_EVENT_KEYS);
const EVENT_REPORT_REASON_CODES = Object.freeze([
  "spam",
  "offensive",
  "unsafe",
  "other",
]);
const EVENT_REPORT_REASON_CODE_SET = new Set(EVENT_REPORT_REASON_CODES);
const EVENT_REPORT_DETAILS_MAX_LENGTH = 500;

function throwReportEventError(code, message, details) {
  throw new functions.https.HttpsError(code, message, details);
}

function throwInvalidReportEventRequest(field, reason, message) {
  throwReportEventError(
      "invalid-argument",
      message || "Invalid report event request",
      {domainCode: "invalid_report_event_request", field, reason},
  );
}

function validateExactReportEventKeys(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throwInvalidReportEventRequest("payload", "invalid_type");
  }
  for (const key of Object.keys(data)) {
    if (!REPORT_EVENT_KEY_SET.has(key)) {
      throwInvalidReportEventRequest(key, "unknown_key");
    }
  }
  for (const key of REPORT_EVENT_REQUIRED_KEYS) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) {
      throwInvalidReportEventRequest(key, "missing");
    }
  }
}

function normalizeEventId(value) {
  if (typeof value !== "string") {
    throwInvalidReportEventRequest("eventId", "invalid_type");
  }
  const eventId = value.trim();
  if (
    !eventId ||
    eventId === "." ||
    eventId === ".." ||
    eventId.includes("/") ||
    Buffer.byteLength(eventId, "utf8") > 1500
  ) {
    throwInvalidReportEventRequest("eventId", "invalid_format");
  }
  return eventId;
}

function normalizeReasonCode(value) {
  if (typeof value !== "string") {
    throwInvalidReportEventRequest("reasonCode", "invalid_type");
  }
  const reasonCode = value.trim().toLowerCase();
  if (!EVENT_REPORT_REASON_CODE_SET.has(reasonCode)) {
    throwInvalidReportEventRequest("reasonCode", "unsupported");
  }
  return reasonCode;
}

function normalizeDetails(value) {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value !== "string") {
    throwInvalidReportEventRequest("details", "invalid_type");
  }
  const details = value.normalize("NFC").trim();
  if (!details) {
    return null;
  }
  if ([...details].length > EVENT_REPORT_DETAILS_MAX_LENGTH) {
    throwInvalidReportEventRequest("details", "too_long");
  }
  return details;
}

function normalizeReportEventPayload(data) {
  validateExactReportEventKeys(data);
  return {
    eventId: normalizeEventId(data.eventId),
    reasonCode: normalizeReasonCode(data.reasonCode),
    details: normalizeDetails(data.details),
  };
}

function normalizeUserId(value) {
  return typeof value === "string" ? value.trim() : "";
}

function isValidPathSegment(value) {
  return typeof value === "string" &&
    value.length > 0 &&
    value !== "." &&
    value !== ".." &&
    !value.includes("/") &&
    Buffer.byteLength(value, "utf8") <= 1500;
}

function buildEventReportId({eventId, reporterId}) {
  return crypto
      .createHash("sha256")
      .update(`${reporterId}:${eventId}`)
      .digest("hex");
}

function normalizeSnapshotString(value) {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.normalize("NFC").trim();
  return normalized || null;
}

function eventReportSnapshot(eventData = {}) {
  return {
    title: normalizeSnapshotString(eventData.title),
    status: normalizeSnapshotString(eventData.status),
    startsAt: eventData.startsAt || null,
    countryCode: normalizeSnapshotString(eventData.countryCode),
    cityKey: normalizeSnapshotString(eventData.cityKey),
    organizerId: normalizeSnapshotString(eventData.organizerId),
  };
}

function timestampToIso(value) {
  if (value && typeof value.toDate === "function") {
    const date = value.toDate();
    if (date instanceof Date && Number.isFinite(date.getTime())) {
      return date.toISOString();
    }
  }
  if (value instanceof Date && Number.isFinite(value.getTime())) {
    return value.toISOString();
  }
  return null;
}

function eventReportDocument({
  db,
  eventRef,
  eventData,
  eventId,
  reporterId,
  reportTimestamp,
  reasonCode,
  details,
}) {
  const organizerId = normalizeSnapshotString(eventData.organizerId);
  return {
    eventId,
    eventRef,
    eventPath: eventRef.path,
    reporterId,
    reporterRef: db.collection("users").doc(reporterId),
    organizerId,
    organizerRef: isValidPathSegment(organizerId) ?
      db.collection("users").doc(organizerId) :
      null,
    reasonCode,
    details,
    status: "open",
    eventSnapshot: eventReportSnapshot(eventData),
    createdAt: reportTimestamp,
    updatedAt: reportTimestamp,
  };
}

function reportableEventOrganizerId(eventData = {}) {
  const organizerId = normalizeSnapshotString(eventData.organizerId);
  if (!isValidPathSegment(organizerId)) {
    throwReportEventError(
        "failed-precondition",
        "Event report state is inconsistent.",
        {
          domainCode: "event_report_state_inconsistent",
          reason: "organizer_invalid",
        },
    );
  }

  const status = normalizeSnapshotString(eventData.status);
  if (status !== EVENT_STATUS_ACTIVE || eventData.canceledAt !== null) {
    throwReportEventError(
        "failed-precondition",
        "Event is not reportable.",
        {
          domainCode: "event_not_reportable",
          reason: eventData.canceledAt !== null ?
            "event_canceled" :
            "not_active",
        },
    );
  }

  return organizerId;
}

async function executeReportEventTransaction({
  db,
  eventId,
  reporterId,
  reasonCode,
  details = null,
  reportDate = new Date(),
  reportTimestamp = admin.firestore.FieldValue.serverTimestamp(),
}) {
  const normalizedReporterId = normalizeUserId(reporterId);
  if (!isValidPathSegment(normalizedReporterId)) {
    throwReportEventError(
        "unauthenticated",
        "User must be authenticated.",
        {domainCode: "auth_required"},
    );
  }

  const eventRef = db.collection("events").doc(eventId);
  const reportId = buildEventReportId({
    eventId,
    reporterId: normalizedReporterId,
  });
  const reportRef = db.collection(EVENT_REPORTS_COLLECTION).doc(reportId);

  return db.runTransaction(async (transaction) => {
    const eventSnap = await transaction.get(eventRef);
    const reportSnap = await transaction.get(reportRef);

    if (!eventSnap.exists) {
      throwReportEventError(
          "not-found",
          "Event not found.",
          {domainCode: "event_not_found"},
      );
    }

    const eventData = eventSnap.data() || {};
    const organizerId = reportableEventOrganizerId(eventData);
    if (organizerId === normalizedReporterId) {
      throwReportEventError(
          "failed-precondition",
          "Organizer cannot report their own event.",
          {domainCode: "event_report_self"},
      );
    }

    if (reportSnap.exists) {
      const existingReport = reportSnap.data() || {};
      return {
        eventId,
        reportId,
        status: "already_submitted",
        reportedAt: timestampToIso(existingReport.createdAt) ||
          reportDate.toISOString(),
      };
    }

    transaction.create(
        reportRef,
        eventReportDocument({
          db,
          eventRef,
          eventData,
          eventId,
          reporterId: normalizedReporterId,
          reportTimestamp,
          reasonCode,
          details,
        }),
    );

    return {
      eventId,
      reportId,
      status: "submitted",
      reportedAt: reportDate.toISOString(),
    };
  });
}

async function reportEventHandler(data, context, options = {}) {
  if (!context.auth) {
    throwReportEventError(
        "unauthenticated",
        "User must be authenticated.",
        {domainCode: "auth_required"},
    );
  }

  const payload = normalizeReportEventPayload(data);
  const db = options.db || admin.firestore();
  return executeReportEventTransaction({
    db,
    eventId: payload.eventId,
    reporterId: context.auth.uid,
    reasonCode: payload.reasonCode,
    details: payload.details,
    reportDate: options.reportDate || new Date(),
    reportTimestamp: options.reportTimestamp ||
      admin.firestore.FieldValue.serverTimestamp(),
  });
}

exports.reportEvent = functions
    .runWith({timeoutSeconds: REQUEST_TIMEOUT_SECONDS})
    .https.onCall((data, context) => reportEventHandler(data, context));

exports.__private__ = {
  EVENT_REPORTS_COLLECTION,
  EVENT_REPORT_REASON_CODES,
  EVENT_REPORT_DETAILS_MAX_LENGTH,
  buildEventReportId,
  executeReportEventTransaction,
  normalizeReportEventPayload,
  reportableEventOrganizerId,
  reportEventHandler,
};
