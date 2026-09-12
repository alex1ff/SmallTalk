const crypto = require("node:crypto");
const admin = require("firebase-admin");
const {
  MATCH_PROTOCOL_VERSION,
} = require("./match_protocol_v2");

const MATCH_RECOVERY_STATUS = Object.freeze({
  PENDING: "pending",
  PROCESSING: "processing",
  COMPLETED: "completed",
  COMPLETED_WITH_FAILURES: "completed_with_failures",
});
const MATCH_RECOVERY_MAX_ATTEMPTS = 3;
const MATCH_RECOVERY_LEASE_MS = 90 * 1000;
const MATCH_RECOVERY_RETRY_DELAY_MS = 60 * 1000;

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function timestampToMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return Number(value.toMillis());
  if (typeof value.toDate === "function") return value.toDate().getTime();
  const millis = Number(value);
  return Number.isFinite(millis) ? millis : null;
}

async function claimProtocolV2MatchRecovery({
  db,
  sessionId,
  pairAttemptId,
  ownerId = crypto.randomUUID(),
  nowMillis = Date.now(),
}) {
  return db.runTransaction(async (transaction) => {
    const sessionRef = db.collection("videoSessions").doc(sessionId);
    const sessionSnap = await transaction.get(sessionRef);
    if (!sessionSnap.exists) {
      return {claimed: false, reason: "session_missing"};
    }
    const sessionData = sessionSnap.data() || {};
    const recovery = sessionData.matchRecovery || {};
    if (
      Number(sessionData.matchProtocolVersion) !== MATCH_PROTOCOL_VERSION ||
      normalizeString(sessionData.pairAttemptId) !== pairAttemptId ||
      normalizeString(recovery.pairAttemptId) !== pairAttemptId
    ) {
      return {claimed: false, reason: "pair_attempt_mismatch"};
    }

    const status = normalizeString(recovery.status);
    if (status === MATCH_RECOVERY_STATUS.PROCESSING) {
      const leaseExpiresAtMillis = timestampToMillis(recovery.leaseExpiresAt);
      if (leaseExpiresAtMillis !== null && leaseExpiresAtMillis > nowMillis) {
        return {claimed: false, reason: "recovery_in_progress"};
      }
    } else if (status === MATCH_RECOVERY_STATUS.PENDING) {
      const nextRetryAtMillis = timestampToMillis(recovery.nextRetryAt);
      if (nextRetryAtMillis !== null && nextRetryAtMillis > nowMillis) {
        return {claimed: false, reason: "recovery_backoff"};
      }
    } else {
      return {claimed: false, reason: "recovery_not_pending"};
    }

    const attempts = Math.max(0, Number(recovery.attempts) || 0) + 1;
    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
    if (attempts > MATCH_RECOVERY_MAX_ATTEMPTS) {
      transaction.update(sessionRef, {
        matchRecovery: {
          ...recovery,
          status: MATCH_RECOVERY_STATUS.COMPLETED_WITH_FAILURES,
          attempts: MATCH_RECOVERY_MAX_ATTEMPTS,
          processingOwner: null,
          leaseExpiresAt: null,
          completedAt: serverTimestamp,
          lastFailure: normalizeString(recovery.lastFailure) ||
            "recovery_attempts_exhausted",
        },
        updatedAt: serverTimestamp,
      });
      return {claimed: false, reason: "recovery_attempts_exhausted"};
    }

    const leaseExpiresAt = admin.firestore.Timestamp.fromMillis(
      nowMillis + MATCH_RECOVERY_LEASE_MS,
    );
    const claimedRecovery = {
      ...recovery,
      status: MATCH_RECOVERY_STATUS.PROCESSING,
      attempts,
      processingOwner: ownerId,
      leaseExpiresAt,
      lastAttemptAt: serverTimestamp,
      nextRetryAt: null,
    };
    transaction.update(sessionRef, {
      matchRecovery: claimedRecovery,
      updatedAt: serverTimestamp,
    });
    return {
      claimed: true,
      reason: status === MATCH_RECOVERY_STATUS.PROCESSING ?
        "stale_lease_reclaimed" :
        "recovery_claimed",
      ownerId,
      attempts,
      sessionData: {
        ...sessionData,
        matchRecovery: claimedRecovery,
      },
    };
  });
}

async function finishProtocolV2MatchRecovery({
  db,
  sessionId,
  pairAttemptId,
  ownerId,
  succeeded,
  failureReason = "terminal_side_effects_failed",
  nowMillis = Date.now(),
}) {
  return db.runTransaction(async (transaction) => {
    const sessionRef = db.collection("videoSessions").doc(sessionId);
    const sessionSnap = await transaction.get(sessionRef);
    if (!sessionSnap.exists) {
      return {finished: false, reason: "session_missing"};
    }
    const sessionData = sessionSnap.data() || {};
    const recovery = sessionData.matchRecovery || {};
    if (
      normalizeString(sessionData.pairAttemptId) !== pairAttemptId ||
      normalizeString(recovery.pairAttemptId) !== pairAttemptId ||
      normalizeString(recovery.status) !== MATCH_RECOVERY_STATUS.PROCESSING ||
      normalizeString(recovery.processingOwner) !== ownerId
    ) {
      return {finished: false, reason: "recovery_claim_lost"};
    }

    const attempts = Math.max(1, Number(recovery.attempts) || 1);
    const exhausted = !succeeded && attempts >= MATCH_RECOVERY_MAX_ATTEMPTS;
    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
    const status = succeeded ?
      MATCH_RECOVERY_STATUS.COMPLETED :
      (exhausted ?
        MATCH_RECOVERY_STATUS.COMPLETED_WITH_FAILURES :
        MATCH_RECOVERY_STATUS.PENDING);
    transaction.update(sessionRef, {
      matchRecovery: {
        ...recovery,
        status,
        processingOwner: null,
        leaseExpiresAt: null,
        nextRetryAt: succeeded || exhausted ?
          null :
          admin.firestore.Timestamp.fromMillis(
            nowMillis + MATCH_RECOVERY_RETRY_DELAY_MS,
          ),
        ...(succeeded ? {
          completedAt: serverTimestamp,
        } : {
          lastFailure: normalizeString(failureReason) ||
            "terminal_side_effects_failed",
          lastFailedAt: serverTimestamp,
          ...(exhausted ? {completedAt: serverTimestamp} : {}),
        }),
      },
      updatedAt: serverTimestamp,
    });
    return {
      finished: true,
      reason: succeeded ?
        "recovery_completed" :
        (exhausted ? "recovery_completed_with_failures" : "recovery_retry_scheduled"),
      status,
      attempts,
      exhausted,
    };
  });
}

function isSettledResumeResult(result = {}) {
  return result.resumed === true || result.settled === true;
}

async function reconcileProtocolV2TerminalSideEffects({
  db,
  sessionId,
  pairAttemptId,
  cancelSurfaces,
  resumeSearch,
  ownerId = crypto.randomUUID(),
  nowMillis = Date.now(),
}) {
  const claim = await claimProtocolV2MatchRecovery({
    db,
    sessionId,
    pairAttemptId,
    ownerId,
    nowMillis,
  });
  if (!claim.claimed) {
    return {processed: false, reason: claim.reason};
  }

  const sessionData = claim.sessionData || {};
  const recovery = sessionData.matchRecovery || {};
  const restoreParticipantIds = Array.from(new Set(
    (recovery.restoreParticipantIds || []).map(normalizeString).filter(Boolean),
  ));
  const effects = await Promise.allSettled([
    cancelSurfaces({
      db,
      sessionId,
      pairAttemptId,
      participantStates: sessionData.participantStates || {},
      reason: normalizeString(recovery.reason) || "match_cancelled",
    }),
    ...restoreParticipantIds.map((participantId) => resumeSearch({
      db,
      participantId,
      sessionId,
      pairAttemptId,
    })),
  ]);

  const cancellationEffect = effects[0];
  const resumeEffects = effects.slice(1);
  const failureReasons = [];
  if (cancellationEffect.status === "rejected") {
    failureReasons.push("callkit_cancellation_failed");
  } else if (Number(cancellationEffect.value?.deliveryFailures) > 0) {
    failureReasons.push("callkit_cancellation_delivery_failed");
  }
  resumeEffects.forEach((effect, index) => {
    if (
      effect.status === "rejected" ||
      !isSettledResumeResult(effect.value)
    ) {
      failureReasons.push(
        `resume_failed:${restoreParticipantIds[index] || "unknown"}`,
      );
    }
  });

  if (failureReasons.length > 0) {
    const failureReason = failureReasons.join(",");
    const finish = await finishProtocolV2MatchRecovery({
      db,
      sessionId,
      pairAttemptId,
      ownerId,
      succeeded: false,
      failureReason,
      nowMillis,
    });
    if (finish.exhausted) {
      return {
        processed: true,
        reason: "terminal_side_effects_completed_with_failures",
        failureReason,
      };
    }
    if (!finish.finished) {
      return {processed: false, reason: finish.reason};
    }
    const error = new Error(failureReason);
    error.code = "match-recovery-retry";
    throw error;
  }

  const finish = await finishProtocolV2MatchRecovery({
    db,
    sessionId,
    pairAttemptId,
    ownerId,
    succeeded: true,
    nowMillis,
  });
  return {
    processed: finish.finished,
    reason: finish.finished ?
      "terminal_side_effects_reconciled" :
      finish.reason,
  };
}

module.exports = {
  MATCH_RECOVERY_LEASE_MS,
  MATCH_RECOVERY_MAX_ATTEMPTS,
  MATCH_RECOVERY_RETRY_DELAY_MS,
  MATCH_RECOVERY_STATUS,
  claimProtocolV2MatchRecovery,
  finishProtocolV2MatchRecovery,
  isSettledResumeResult,
  reconcileProtocolV2TerminalSideEffects,
  timestampToMillis,
};
