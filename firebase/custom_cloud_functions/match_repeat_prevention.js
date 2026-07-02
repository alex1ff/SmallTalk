const admin = require("firebase-admin");
const {
  buildPairId,
  getConnectedCallStartMillis,
  getUnlockParticipants,
} = require("./chats_shared");

const DAILY_COMPLETIONS_COLLECTION = "matchPairDailyCompletions";
const MATCH_REPEAT_BYPASS_USER_IDS_ENV = "MATCH_REPEAT_BYPASS_USER_IDS";
const MAX_GET_ALL_CHUNK_SIZE = 300;
const DEFAULT_REPEAT_BYPASS_USER_ID_PAIRS = [
  [
    "XkRxUdqHTiM1MNDTJG4zb0wooay2",
    "CI0E2yJBw1P0TicAWVLhHhLX6Yl2",
  ],
];
const DEFAULT_REPEAT_BYPASS_EMAIL_PAIRS = [
  ["elena.alpatkina@gmail.com", "nsk.muratov@gmail.com"],
  ["elena.alpatkina@gmail.com", "nak.muratov@gmail.com"],
];
const DEFAULT_REPEAT_BYPASS_USER_ID_PAIR_KEYS = new Set(
  DEFAULT_REPEAT_BYPASS_USER_ID_PAIRS
    .map(([leftUserId, rightUserId]) =>
      buildUserIdPairKey(leftUserId, rightUserId))
    .filter(Boolean),
);
const DEFAULT_REPEAT_BYPASS_EMAIL_PAIR_KEYS = new Set(
  DEFAULT_REPEAT_BYPASS_EMAIL_PAIRS
    .map(([leftEmail, rightEmail]) => buildEmailPairKey(leftEmail, rightEmail))
    .filter(Boolean),
);

function normalizeUserId(value) {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim();
}

function buildUserIdPairKey(leftUserId, rightUserId) {
  const normalizedUserIds = [
    normalizeUserId(leftUserId),
    normalizeUserId(rightUserId),
  ].filter(Boolean);

  if (normalizedUserIds.length !== 2) {
    return "";
  }

  return normalizedUserIds.sort().join("\n");
}

function normalizeEmail(value) {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim().toLowerCase();
}

function buildEmailPairKey(leftEmail, rightEmail) {
  const normalizedEmails = [
    normalizeEmail(leftEmail),
    normalizeEmail(rightEmail),
  ].filter(Boolean);

  if (normalizedEmails.length !== 2) {
    return "";
  }

  return normalizedEmails.sort().join("\n");
}

function readUserEmailById(userEmailsById, userId) {
  if (!userEmailsById || !userId) {
    return "";
  }

  if (userEmailsById instanceof Map) {
    return normalizeEmail(userEmailsById.get(userId));
  }

  return normalizeEmail(userEmailsById[userId]);
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

function shouldBypassRepeatForUserIdPair(
  requesterId,
  candidateId,
  bypassUserIdPairKeys = DEFAULT_REPEAT_BYPASS_USER_ID_PAIR_KEYS,
) {
  const pairKey = buildUserIdPairKey(requesterId, candidateId);
  return pairKey ? bypassUserIdPairKeys.has(pairKey) : false;
}

function shouldBypassRepeatForEmailPair(
  requesterEmail,
  candidateEmail,
  bypassEmailPairKeys = DEFAULT_REPEAT_BYPASS_EMAIL_PAIR_KEYS,
) {
  const pairKey = buildEmailPairKey(requesterEmail, candidateEmail);
  return pairKey ? bypassEmailPairKeys.has(pairKey) : false;
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
    bypassUserIdPairKeys = DEFAULT_REPEAT_BYPASS_USER_ID_PAIR_KEYS,
    bypassEmailPairKeys = DEFAULT_REPEAT_BYPASS_EMAIL_PAIR_KEYS,
    requesterEmail = "",
    userEmailsById = {},
  } = {},
) {
  const normalizedRequesterId = normalizeUserId(requesterId);
  const normalizedRequesterEmail =
    normalizeEmail(requesterEmail) ||
    readUserEmailById(userEmailsById, normalizedRequesterId);
  const uniqueCandidateIds = Array.from(
    new Set(candidateIds.map((value) => normalizeUserId(value)).filter(Boolean)),
  );

  if (!normalizedRequesterId) {
    return {
      dayKey,
      requesterBypassApplied: false,
      testerBypassCandidateCount: 0,
      userIdPairBypassCandidateCount: 0,
      emailPairBypassCandidateCount: 0,
      refs: [],
      refCandidateIds: [],
    };
  }

  if (hasRepeatBypass(normalizedRequesterId, bypassUserIds)) {
    return {
      dayKey,
      requesterBypassApplied: true,
      testerBypassCandidateCount: uniqueCandidateIds.length,
      userIdPairBypassCandidateCount: 0,
      emailPairBypassCandidateCount: 0,
      refs: [],
      refCandidateIds: [],
    };
  }

  const refs = [];
  const refCandidateIds = [];
  let testerBypassCandidateCount = 0;
  let userIdPairBypassCandidateCount = 0;
  let emailPairBypassCandidateCount = 0;

  uniqueCandidateIds.forEach((candidateId) => {
    const userIdBypassApplied = shouldBypassRepeatForPair(
      normalizedRequesterId,
      candidateId,
      bypassUserIds,
    );
    const userIdPairBypassApplied = shouldBypassRepeatForUserIdPair(
      normalizedRequesterId,
      candidateId,
      bypassUserIdPairKeys,
    );
    const emailPairBypassApplied = shouldBypassRepeatForEmailPair(
      normalizedRequesterEmail,
      readUserEmailById(userEmailsById, candidateId),
      bypassEmailPairKeys,
    );

    if (
      candidateId === normalizedRequesterId ||
      userIdBypassApplied ||
      userIdPairBypassApplied ||
      emailPairBypassApplied
    ) {
      if (candidateId !== normalizedRequesterId) {
        if (userIdBypassApplied) {
          testerBypassCandidateCount += 1;
        }
        if (userIdPairBypassApplied) {
          userIdPairBypassCandidateCount += 1;
        }
        if (emailPairBypassApplied) {
          emailPairBypassCandidateCount += 1;
        }
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
    userIdPairBypassCandidateCount,
    emailPairBypassCandidateCount,
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
    userIdPairBypassCandidateCount: plan.userIdPairBypassCandidateCount,
    emailPairBypassCandidateCount: plan.emailPairBypassCandidateCount,
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
    userIdPairBypassCandidateCount:
      repeatPreventionContext.userIdPairBypassCandidateCount,
    emailPairBypassCandidateCount:
      repeatPreventionContext.emailPairBypassCandidateCount,
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
  shouldBypassRepeatForEmailPair,
  shouldBypassRepeatForUserIdPair,
  shouldBypassRepeatForPair,
};
