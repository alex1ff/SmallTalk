const admin = require("firebase-admin");
const {
  buildPairId,
  getConnectedCallStartMillis,
  getUnlockParticipants,
} = require("./chats_shared");

const DAILY_COMPLETIONS_COLLECTION = "matchPairDailyCompletions";
const MATCH_REPEAT_BYPASS_USER_IDS_ENV = "MATCH_REPEAT_BYPASS_USER_IDS";
const MAX_GET_ALL_CHUNK_SIZE = 300;

function normalizeUserId(value) {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim();
}

function getUtcDayKey(millis = Date.now()) {
  const numericMillis = Number(millis);
  const safeMillis = Number.isFinite(numericMillis) ? numericMillis : Date.now();
  return new Date(safeMillis).toISOString().slice(0, 10);
}

function getRepeatBypassUserIds() {
  const rawValue = process.env[MATCH_REPEAT_BYPASS_USER_IDS_ENV] || "";
  return new Set(
    String(rawValue)
      .split(/[,\s]+/)
      .map((value) => normalizeUserId(value))
      .filter(Boolean),
  );
}

function hasRepeatBypass(userId, bypassUserIds = getRepeatBypassUserIds()) {
  return bypassUserIds.has(normalizeUserId(userId));
}

function shouldBypassRepeatForPair(
  requesterId,
  candidateId,
  bypassUserIds = getRepeatBypassUserIds(),
) {
  return hasRepeatBypass(requesterId, bypassUserIds) ||
    hasRepeatBypass(candidateId, bypassUserIds);
}

function buildDailyPairCompletionId(pairId, dayKey) {
  if (!pairId || !dayKey) {
    return null;
  }
  return `${dayKey}_${pairId}`;
}

function getDailyPairCompletionRef(db, pairId, dayKey) {
  const docId = buildDailyPairCompletionId(pairId, dayKey);
  if (!docId) {
    return null;
  }
  return db.collection(DAILY_COMPLETIONS_COLLECTION).doc(docId);
}

async function getAllRefs(db, refs) {
  if (refs.length === 0) {
    return [];
  }

  if (typeof db.getAll !== "function") {
    return Promise.all(refs.map((ref) => ref.get()));
  }

  const snapshots = [];
  for (let index = 0; index < refs.length; index += MAX_GET_ALL_CHUNK_SIZE) {
    const chunk = refs.slice(index, index + MAX_GET_ALL_CHUNK_SIZE);
    snapshots.push(...await db.getAll(...chunk));
  }
  return snapshots;
}

function buildSameDayRepeatLookupPlan(
  db,
  requesterId,
  candidateIds = [],
  {
    dayKey = getUtcDayKey(),
    bypassUserIds = getRepeatBypassUserIds(),
  } = {},
) {
  const normalizedRequesterId = normalizeUserId(requesterId);
  const uniqueCandidateIds = Array.from(
    new Set(candidateIds.map((value) => normalizeUserId(value)).filter(Boolean)),
  );

  if (!normalizedRequesterId) {
    return {
      dayKey,
      requesterBypassApplied: false,
      testerBypassCandidateCount: 0,
      refs: [],
      refCandidateIds: [],
    };
  }

  if (hasRepeatBypass(normalizedRequesterId, bypassUserIds)) {
    return {
      dayKey,
      requesterBypassApplied: true,
      testerBypassCandidateCount: uniqueCandidateIds.length,
      refs: [],
      refCandidateIds: [],
    };
  }

  const refs = [];
  const refCandidateIds = [];
  let testerBypassCandidateCount = 0;

  uniqueCandidateIds.forEach((candidateId) => {
    if (
      candidateId === normalizedRequesterId ||
      shouldBypassRepeatForPair(
        normalizedRequesterId,
        candidateId,
        bypassUserIds,
      )
    ) {
      if (candidateId !== normalizedRequesterId) {
        testerBypassCandidateCount += 1;
      }
      return;
    }

    const pairId = buildPairId(normalizedRequesterId, candidateId);
    const ref = getDailyPairCompletionRef(db, pairId, dayKey);
    if (!ref) {
      return;
    }

    refs.push(ref);
    refCandidateIds.push(candidateId);
  });

  return {
    dayKey,
    requesterBypassApplied: false,
    testerBypassCandidateCount,
    refs,
    refCandidateIds,
  };
}

function buildRepeatResultFromSnapshots(plan, snapshots) {
  const excludedCandidateIds = new Set();
  snapshots.forEach((snapshot, index) => {
    if (snapshot.exists) {
      excludedCandidateIds.add(plan.refCandidateIds[index]);
    }
  });

  return {
    dayKey: plan.dayKey,
    excludedCandidateIds,
    requesterBypassApplied: plan.requesterBypassApplied,
    testerBypassCandidateCount: plan.testerBypassCandidateCount,
  };
}

async function loadSameDayRepeatCandidateIds(
  db,
  requesterId,
  candidateIds = [],
  options = {},
) {
  const plan = buildSameDayRepeatLookupPlan(
    db,
    requesterId,
    candidateIds,
    options,
  );
  const snapshots = await getAllRefs(db, plan.refs);
  return buildRepeatResultFromSnapshots(plan, snapshots);
}

async function loadSameDayRepeatCandidateIdsForTransaction(
  transaction,
  db,
  requesterId,
  candidateIds = [],
  options = {},
) {
  const plan = buildSameDayRepeatLookupPlan(
    db,
    requesterId,
    candidateIds,
    options,
  );
  const snapshots = [];
  for (const ref of plan.refs) {
    snapshots.push(await transaction.get(ref));
  }

  return buildRepeatResultFromSnapshots(plan, snapshots);
}

function filterRepeatCandidates(candidateIds, repeatPreventionContext) {
  const excludedCandidateIds =
    repeatPreventionContext?.excludedCandidateIds || new Set();
  return candidateIds.filter((candidateId) => !excludedCandidateIds.has(candidateId));
}

function buildCandidateRoleCounts(candidateIds, candidateDetails = {}) {
  return candidateIds.reduce((acc, candidateId) => {
    const role = candidateDetails[candidateId]?.role || "unknown";
    acc[role] = (acc[role] || 0) + 1;
    return acc;
  }, {});
}

function countExcludedRepeatCandidates(repeatPreventionContext) {
  return repeatPreventionContext?.excludedCandidateIds?.size || 0;
}

function buildRepeatPreventionLogContext(repeatPreventionContext) {
  if (!repeatPreventionContext) {
    return null;
  }

  return {
    dayKey: repeatPreventionContext.dayKey,
    requesterBypassApplied: repeatPreventionContext.requesterBypassApplied,
    testerBypassCandidateCount:
      repeatPreventionContext.testerBypassCandidateCount,
  };
}

function buildCompletedPairHistoryWrite({
  db,
  sessionId,
  sessionRef,
  sessionData = {},
  completedAtMillis = Date.now(),
}) {
  const connectedAtMillis = getConnectedCallStartMillis(sessionData);
  if (connectedAtMillis <= 0) {
    return null;
  }

  const participants = getUnlockParticipants(sessionData);
  if (!participants) {
    return null;
  }

  const dayKey = getUtcDayKey(completedAtMillis);
  const ref = getDailyPairCompletionRef(db, participants.pairId, dayKey);
  if (!ref) {
    return null;
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  return {
    ref,
    pairId: participants.pairId,
    dayKey,
    data: {
      pairId: participants.pairId,
      dayKey,
      participantIds: participants.participantIds,
      participantRefs: participants.participantRefs,
      sessionIds: admin.firestore.FieldValue.arrayUnion(sessionId),
      latestSessionId: sessionId,
      latestSessionRef: sessionRef,
      latestConnectedAtMillis: connectedAtMillis,
      latestCompletedAtMillis: completedAtMillis,
      completionCount: admin.firestore.FieldValue.increment(1),
      updatedAt: now,
    },
  };
}

module.exports = {
  DAILY_COMPLETIONS_COLLECTION,
  MATCH_REPEAT_BYPASS_USER_IDS_ENV,
  buildCandidateRoleCounts,
  buildCompletedPairHistoryWrite,
  buildDailyPairCompletionId,
  buildRepeatPreventionLogContext,
  countExcludedRepeatCandidates,
  filterRepeatCandidates,
  getDailyPairCompletionRef,
  getRepeatBypassUserIds,
  getUtcDayKey,
  loadSameDayRepeatCandidateIds,
  loadSameDayRepeatCandidateIdsForTransaction,
  shouldBypassRepeatForPair,
};
