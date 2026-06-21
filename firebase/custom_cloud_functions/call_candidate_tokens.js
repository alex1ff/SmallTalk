const {
  normalizeRole,
  readLanguageCode,
  supportsConversationLanguage,
} = require("./video_sessions_shared");
const { buildReadOnlyVoipTokenState } = require("./voip_tokens");

const USER_COLLECTION = "users";
const PRIVATE_TOKEN_COLLECTION = "userPrivateTokens";

function normalizeCandidateId(value) {
  return typeof value === "string" ? value.trim() : "";
}

function hasUsableCallTokenState(tokenState = {}) {
  return tokenState.hasUsableToken === true &&
    (
      tokenState.hasFcmToken === true ||
      tokenState.hasVoipPushToken === true
    );
}

async function readCandidateCallabilityInTransaction({
  db,
  transaction,
  candidateId,
  language = "",
}) {
  const userId = normalizeCandidateId(candidateId);
  if (!userId) {
    return {callable: false, reason: "missing_candidate_id"};
  }

  const userSnap = await transaction.get(
    db.collection(USER_COLLECTION).doc(userId),
  );
  if (!userSnap.exists) {
    return {callable: false, reason: "missing_user"};
  }

  const userData = userSnap.data() || {};
  const role = normalizeRole(userData.role);
  const normalizedLanguage = readLanguageCode(language);
  if (!normalizedLanguage) {
    return {callable: false, reason: "missing_language", role};
  }
  if (!supportsConversationLanguage(userData, normalizedLanguage)) {
    return {callable: false, reason: "language_mismatch", role};
  }

  if (role !== "native_speaker") {
    return {callable: true, reason: "token_not_required", role};
  }

  const privateTokenSnap = await transaction.get(
    db.collection(PRIVATE_TOKEN_COLLECTION).doc(userId),
  );
  const privateData = privateTokenSnap.exists ?
    privateTokenSnap.data() || {} :
    {};
  const tokenState = buildReadOnlyVoipTokenState({
    privateData,
    legacyUserData: userData,
  });

  return {
    callable: hasUsableCallTokenState(tokenState),
    reason: hasUsableCallTokenState(tokenState) ?
      "has_call_token" :
      "missing_call_token",
    role,
    tokenState,
  };
}

async function findNextCallableCandidateInTransaction({
  db,
  transaction,
  candidateIds = [],
  triedCandidateIds = [],
  language = "",
}) {
  const triedSet = new Set(
    triedCandidateIds.map(normalizeCandidateId).filter(Boolean),
  );
  const skippedCandidateIds = [];

  for (const rawCandidateId of candidateIds) {
    const candidateId = normalizeCandidateId(rawCandidateId);
    if (!candidateId || triedSet.has(candidateId)) {
      continue;
    }

    const callability = await readCandidateCallabilityInTransaction({
      db,
      transaction,
      candidateId,
      language,
    });
    if (callability.callable) {
      return {
        candidateId,
        triedCandidateIds: Array.from(triedSet),
        skippedCandidateIds,
      };
    }

    triedSet.add(candidateId);
    skippedCandidateIds.push(candidateId);
  }

  return {
    candidateId: null,
    triedCandidateIds: Array.from(triedSet),
    skippedCandidateIds,
  };
}

module.exports = {
  findNextCallableCandidateInTransaction,
  hasUsableCallTokenState,
  readCandidateCallabilityInTransaction,
};
