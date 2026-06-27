const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

const {
  isSessionParticipant,
} = require("./video_sessions_shared.js");

const DEFAULT_CALL_HISTORY_LIMIT = 100;
const MAX_CALL_HISTORY_LIMIT = 200;
const CALL_HISTORY_BRANCH_PAGE_SIZE = 300;
const GET_CALL_HISTORY_KEYS = Object.freeze(["limit"]);
const GET_CALL_HISTORY_KEY_SET = new Set(GET_CALL_HISTORY_KEYS);

const CALL_HISTORY_QUERY_BRANCHES = Object.freeze([
  {field: "participantIds", operator: "array-contains"},
  {field: "requesterId", operator: "=="},
  {field: "responderId", operator: "=="},
  {field: "currentResponderId", operator: "=="},
  {field: "matchContext.requesterId", operator: "=="},
  {field: "matchContext.acceptedResponderId", operator: "=="},
  {field: "matchContext.responderId", operator: "=="},
  {field: "matchContext.currentResponderId", operator: "=="},
  {field: "studentId", operator: "=="},
  {field: "tutorId", operator: "=="},
  {field: "currentTutorId", operator: "=="},
]);

function throwCallHistoryError(code, message, details) {
  throw new functions.https.HttpsError(code, message, details);
}

function throwInvalidCallHistoryRequest(field, reason) {
  throwCallHistoryError(
      "invalid-argument",
      "Invalid call history request",
      {
        domainCode: "invalid_call_history_request",
        field,
        reason,
      },
  );
}

function validateExactGetCallHistoryKeys(data) {
  if (data === undefined || data === null) {
    return;
  }
  if (typeof data !== "object" || Array.isArray(data)) {
    throwInvalidCallHistoryRequest("payload", "invalid_type");
  }
  for (const key of Object.keys(data)) {
    if (!GET_CALL_HISTORY_KEY_SET.has(key)) {
      throwInvalidCallHistoryRequest(key, "unknown_key");
    }
  }
}

function normalizeHistoryLimit(value) {
  if (value === undefined || value === null) {
    return DEFAULT_CALL_HISTORY_LIMIT;
  }
  if (!Number.isInteger(value)) {
    throwInvalidCallHistoryRequest("limit", "invalid_type");
  }
  if (value < 1 || value > MAX_CALL_HISTORY_LIMIT) {
    throwInvalidCallHistoryRequest("limit", "out_of_range");
  }
  return value;
}

function normalizeGetCallHistoryPayload(data) {
  validateExactGetCallHistoryKeys(data);
  return {
    limit: normalizeHistoryLimit(data && data.limit),
  };
}

function timestampToMillis(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toMillis === "function") {
    try {
      const millis = Number(value.toMillis());
      return Number.isFinite(millis) ? millis : null;
    } catch (_) {
      return null;
    }
  }
  if (typeof value.toDate === "function") {
    try {
      const date = value.toDate();
      return date instanceof Date && Number.isFinite(date.getTime()) ?
        date.getTime() :
        null;
    } catch (_) {
      return null;
    }
  }
  if (value instanceof Date) {
    const millis = value.getTime();
    return Number.isFinite(millis) ? millis : null;
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value === "string") {
    const numericMillis = Number.parseInt(value.trim(), 10);
    if (Number.isFinite(numericMillis) && String(numericMillis) === value.trim()) {
      return numericMillis;
    }
    const millis = Date.parse(value);
    return Number.isFinite(millis) ? millis : null;
  }
  return null;
}

function resolveSessionStartedAtMillis(sessionData = {}) {
  const sessionMetadata =
    sessionData.sessionMetadata &&
    typeof sessionData.sessionMetadata === "object" &&
    !Array.isArray(sessionData.sessionMetadata) ?
      sessionData.sessionMetadata :
      {};
  for (const value of [
    sessionMetadata.callConnectedAt,
    sessionMetadata.callConnectedAtTimestamp,
    sessionMetadata.dailyWebhookConnectedAt,
    sessionData.callConnectedAt,
    sessionData.callConnectedAtTimestamp,
    sessionData.dailyWebhookConnectedAt,
    sessionData.startedAt,
    sessionData.createdAt,
  ]) {
    const millis = timestampToMillis(value);
    if (millis !== null) {
      return millis;
    }
  }
  return 0;
}

function canIncludeCallHistorySession(sessionData = {}, uid) {
  return sessionData.status === "ended" &&
    isSessionParticipant(sessionData, uid);
}

function selectCallHistoryPathEntries(docs, uid, limit) {
  const sessionsByPath = new Map();

  for (const doc of docs) {
    if (!doc || !doc.ref || typeof doc.ref.path !== "string") {
      continue;
    }
    const sessionData = typeof doc.data === "function" ? doc.data() || {} : {};
    if (!canIncludeCallHistorySession(sessionData, uid)) {
      continue;
    }
    if (!sessionsByPath.has(doc.ref.path)) {
      sessionsByPath.set(doc.ref.path, {
        path: doc.ref.path,
        startedAtMillis: resolveSessionStartedAtMillis(sessionData),
      });
    }
  }

  return Array.from(sessionsByPath.values())
      .sort((left, right) => {
        const byStartedAt = right.startedAtMillis - left.startedAtMillis;
        if (byStartedAt !== 0) {
          return byStartedAt;
        }
        return right.path.localeCompare(left.path);
      })
      .slice(0, limit);
}

async function collectCallHistoryPaths({db, uid, limit}) {
  const branchSnapshots = await Promise.all(
      CALL_HISTORY_QUERY_BRANCHES.map((branch) =>
        collectCallHistoryBranchDocs({db, uid, branch}),
      ),
  );
  const docs = [];
  for (const snapshot of branchSnapshots) {
    docs.push(...snapshot);
  }
  return selectCallHistoryPathEntries(docs, uid, limit)
      .map((entry) => entry.path);
}

async function collectCallHistoryBranchDocs({db, uid, branch}) {
  const docs = [];
  let query = buildCallHistoryBranchQuery({db, uid, branch});

  while (true) {
    const snapshot = await query.limit(CALL_HISTORY_BRANCH_PAGE_SIZE).get();
    docs.push(...snapshot.docs);

    if (snapshot.docs.length < CALL_HISTORY_BRANCH_PAGE_SIZE) {
      return docs;
    }

    query = buildCallHistoryBranchQuery({
      db,
      uid,
      branch,
      afterDoc: snapshot.docs[snapshot.docs.length - 1],
    });
  }
}

function buildCallHistoryBranchQuery({db, uid, branch, afterDoc}) {
  let query = db.collection("videoSessions")
      .where(branch.field, branch.operator, uid)
      .orderBy(admin.firestore.FieldPath.documentId());
  if (afterDoc) {
    query = query.startAfter(afterDoc);
  }
  return query;
}

const getCallHistory = functions
    .region("europe-west1")
    .runWith({
      timeoutSeconds: 30,
      memory: "256MB",
    })
    .https.onCall(async (data, context) => {
      if (!context.auth || !context.auth.uid) {
        throwCallHistoryError(
            "unauthenticated",
            "Authentication required",
            {domainCode: "auth_required"},
        );
      }

      const request = normalizeGetCallHistoryPayload(data);
      const paths = await collectCallHistoryPaths({
        db: admin.firestore(),
        uid: context.auth.uid,
        limit: request.limit,
      });

      return {
        paths,
        limit: request.limit,
        generatedAt: new Date().toISOString(),
      };
    });

module.exports = {
  CALL_HISTORY_QUERY_BRANCHES,
  CALL_HISTORY_BRANCH_PAGE_SIZE,
  DEFAULT_CALL_HISTORY_LIMIT,
  MAX_CALL_HISTORY_LIMIT,
  canIncludeCallHistorySession,
  collectCallHistoryBranchDocs,
  collectCallHistoryPaths,
  getCallHistory,
  normalizeGetCallHistoryPayload,
  resolveSessionStartedAtMillis,
  selectCallHistoryPathEntries,
};
