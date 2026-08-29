const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  buildUnlockEventPayload,
  ensureConversationCallEventForSession,
  getConnectedCallStartMillis,
  getUnlockEligibility,
} = require("./chats_shared");
const {
  buildCompletedPairHistoryWrite,
} = require("./match_repeat_prevention");
const {
  getRequesterId,
  isSessionParticipant,
  normalizeRole,
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  incrementUsageInTransaction,
} = require("./subscription_usage_shared");
const {
  remainingGiftMinutes,
} = require("./gift_minutes_shared");
const {
  resolveDailyRoomName,
} = require("./daily_room");
const {
  deleteDailyRoomForSession,
} = require("./daily_room_cleanup");
const {
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");
const {
  releaseSessionPairLocksInTransaction,
} = require("./match_pair_lock");
const {
  cancelProtocolV2NotificationsInTransaction,
} = require("./call_notifications");
const {
  cancelProtocolV2NativeSurfaces,
} = require("./match_delivery_v2");
const {
  reconcileTrialCallInTransaction,
  trialAccessRef,
} = require("./trial_access");

const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];

// ─── Pricing ────────────────────────────────────────────────────────────────
// Student pays ~45-50 RUB/min (10 SmallTalks = 4990₽, 20 SmallTalks = 8900₽)
// 1 SmallTalk = 10 minutes
const TUTOR_RATE_PER_MINUTE = 15; // 15 RUB/min paid to tutor
// Platform margin: ~30-35 RUB/min

function toMillis(value) {
  if (!value) return 0;
  if (typeof value?.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : 0;
}

function shouldProcessExpiredEndReason({
  sessionData = {},
  endReason,
  requestTimestamp = Date.now(),
  clockSkewGraceMs = 2000,
}) {
  if (String(endReason || "").trim() !== "expired") {
    return true;
  }

  const sessionPolicy = sessionData.sessionPolicy;
  if (
    !sessionPolicy ||
    typeof sessionPolicy !== "object" ||
    Array.isArray(sessionPolicy)
  ) {
    return true;
  }

  const expiresAtMillis = toMillis(sessionData.expiresAt);
  if (expiresAtMillis <= 0) {
    return true;
  }

  return requestTimestamp + clockSkewGraceMs >= expiresAtMillis;
}

function hasConnectedCallEvidence(sessionData = {}) {
  return getConnectedCallStartMillis(sessionData) > 0;
}

function isExpiredEndReason(endReason) {
  return String(endReason || "").trim() === "expired";
}

function buildPreActiveSessionPairLockReleaseOptions({
  db,
  transaction,
  sessionId,
  sessionData = {},
  serverTimestamp,
  fieldDelete,
  searchRequestStatus,
  stopReason,
}) {
  return {
    db,
    transaction,
    sessionId,
    sessionData,
    serverTimestamp,
    fieldDelete,
    searchRequestStatus,
    stopReason,
    releaseCallState: true,
    restoreLegacyAvailability: true,
  };
}

function buildEndedSessionPairLockReleaseOptions({
  db,
  transaction,
  sessionId,
  sessionData = {},
  serverTimestamp,
  fieldDelete,
}) {
  return {
    db,
    transaction,
    sessionId,
    sessionData,
    serverTimestamp,
    fieldDelete,
    searchRequestStatus: SEARCH_REQUEST_STATUS.STOPPED,
    stopReason: "session_ended",
    releaseCallState: true,
    restoreLegacyAvailability: true,
  };
}

// Returns true if the user has a flat-rate subscription that is still active
// at `nowMillis`. Subscribers are not debited from balanceST — billing flips
// from per-minute to flat-rate for the duration of the subscription.
function hasActiveSubscription(userData, nowMillis) {
  const expiresAt = userData?.subscription?.expiresAt;
  if (!expiresAt) {
    return false;
  }
  const expiresMillis = toMillis(expiresAt);
  return expiresMillis > nowMillis;
}

function buildStudentCallCharge({
  userId,
  duration,
  formattedDuration,
  subscriptionActive = false,
  giftRemainingMinutes = 0,
}) {
  // Active-subscription branch: produce a zero-charge record so downstream
  // bookkeeping (chargedParticipantIds, teacher payout eligibility) still
  // treats the participant as billable, but the gift minutes / balanceST
  // and the `call_charge` transaction writes are skipped.
  if (subscriptionActive) {
    return {
      userId,
      duration,
      billableMinutes: 0,
      amountST: 0,
      formattedDuration,
      subscriptionActive: true,
      giftMinutesUsed: 0,
      newGiftMinutes: giftRemainingMinutes,
      giftCovered: false,
    };
  }

  // No subscription → fall back to gift minutes. The legacy
  // "first minute free + balanceST debit" branch is gone; balanceST is
  // zeroed by the migration script and is no longer credited.
  const callMinutes = parseFloat((duration / 60).toFixed(4));
  const safeGiftRemaining = Number(giftRemainingMinutes || 0);
  const giftMinutesUsed = Math.min(
      Math.max(safeGiftRemaining, 0),
      callMinutes,
  );
  const newGiftMinutes = parseFloat(
      Math.max(0, safeGiftRemaining - callMinutes).toFixed(4),
  );

  return {
    userId,
    duration,
    billableMinutes: callMinutes,
    amountST: 0,
    formattedDuration,
    subscriptionActive: false,
    giftMinutesUsed: parseFloat(giftMinutesUsed.toFixed(4)),
    newGiftMinutes,
    giftCovered: giftMinutesUsed > 0,
  };
}

function resolveTeacherEarningUserId({
  requesterId,
  requesterRole,
  responderId,
  acceptedResponderRole,
}) {
  if (normalizeRole(requesterRole) === "native_speaker") {
    return requesterId || null;
  }
  if (normalizeRole(acceptedResponderRole) === "native_speaker") {
    return responderId || null;
  }
  return null;
}

/*
endSession
Завершает активную видео сессию, списывает баланс студента,
начисляет заработок преподавателю, создаёт транзакции и обновляет статистику.
*/

exports.endSession = functions
  .runWith({secrets: [...apnsSecrets, ...dailySecrets]})
  .https.onCall(async (data, context) => {
  console.log("🔚 Ending video session...");

  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
      );
    }

    const userId = context.auth.uid;
    const { sessionId, endReason } = data;

    console.log("👤 User ID:", userId);
    console.log("📺 Session ID:", sessionId);
    console.log("📝 End reason:", endReason || "not_specified");

    if (!sessionId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Session ID is required",
      );
    }

    const db = admin.firestore();
    const sessionRef = db.collection("videoSessions").doc(sessionId);
    const requestTimestamp = Date.now();

    // ─── MAIN TRANSACTION (CAS + billing guard) ─────────────────────────────
      // Read session INSIDE transaction and only allow transition:
      // connecting|active -> terminal. This makes endSession idempotent under races.
    const txResult = await db.runTransaction(async (transaction) => {
      const sessionDoc = await transaction.get(sessionRef);
      if (!sessionDoc.exists) {
        console.log("❌ Video session not found:", sessionId);
        throw new functions.https.HttpsError(
          "not-found",
          "Video session not found",
        );
      }

      const sessionData = sessionDoc.data() || {};
      console.log("📋 Current session status:", sessionData.status);
      const storedTrialCallIds =
        sessionData.trialCallIdsByUserId &&
        typeof sessionData.trialCallIdsByUserId === "object" ?
          sessionData.trialCallIdsByUserId : {};
      const trialCallIdsByUserId = Object.keys(storedTrialCallIds).length > 0 ?
        storedTrialCallIds :
        sessionData.accessMode === "trial" && sessionData.studentId ? {
          [sessionData.studentId]: sessionData.trialCallId || sessionId,
        } : {};
      const trialContexts = await Promise.all(
          Object.entries(trialCallIdsByUserId)
              .filter(([participantId, trialCallId]) =>
                typeof participantId === "string" &&
                participantId.length > 0 &&
                !participantId.includes("/") &&
                typeof trialCallId === "string" &&
                trialCallId.length > 0,
              )
              .map(async ([participantId, trialCallId]) => {
                const ref = trialAccessRef(db, participantId);
                return {
                  participantId,
                  trialCallId,
                  ref,
                  snap: await transaction.get(ref),
                };
              }),
      );

      if (!isSessionParticipant(sessionData, userId)) {
        console.log("❌ Permission denied - user is not a participant");
        throw new functions.https.HttpsError(
          "permission-denied",
          "You are not a participant of this session",
        );
      }

      if ([
        VIDEO_SESSION_STATUS.ENDED,
        VIDEO_SESSION_STATUS.CANCELLED,
        VIDEO_SESSION_STATUS.EXPIRED,
      ].includes(sessionData.status)) {
        return {
          status: sessionData.status === VIDEO_SESSION_STATUS.ENDED ?
            "already_ended" :
            `already_${sessionData.status}`,
          message: "Session was already terminal",
          dailyRoomName: resolveDailyRoomName(sessionData),
          endedAt:
            sessionData.endedAt?.toMillis?.() ||
            sessionData.sessionMetadata?.endedAtTimestamp ||
            null,
        };
      }

      if (![
        VIDEO_SESSION_STATUS.CONNECTING,
        VIDEO_SESSION_STATUS.ACTIVE,
      ].includes(sessionData.status)) {
        console.log(
          "❌ Session cannot be ended, current status:",
          sessionData.status,
        );
        throw new functions.https.HttpsError(
          "invalid-argument",
          `Session cannot be ended. Current status: ${sessionData.status}`,
        );
      }

      const isPreActiveConnecting =
        sessionData.status === VIDEO_SESSION_STATUS.CONNECTING &&
        !hasConnectedCallEvidence(sessionData);
      if (isPreActiveConnecting) {
        const terminalStatus = isExpiredEndReason(endReason) ?
          VIDEO_SESSION_STATUS.EXPIRED :
          VIDEO_SESSION_STATUS.CANCELLED;
        const searchRequestStatus =
          terminalStatus === VIDEO_SESSION_STATUS.EXPIRED ?
            SEARCH_REQUEST_STATUS.EXPIRED :
            SEARCH_REQUEST_STATUS.CANCELLED;
        const stopReason =
          terminalStatus === VIDEO_SESSION_STATUS.EXPIRED ?
            "pre_active_expired" :
            "pre_active_cancelled";
        const sessionUpdates = {
          status: terminalStatus,
          endedAt: admin.firestore.FieldValue.serverTimestamp(),
          tutorNavigationTriggered: false,
          studentNavigationTriggered: false,
          acceptingTutorId: admin.firestore.FieldValue.delete(),
          acceptingAt: admin.firestore.FieldValue.delete(),
          acceptAttemptId: admin.firestore.FieldValue.delete(),
          "sessionMetadata.endReason": stopReason,
          "sessionMetadata.endedAtTimestamp": requestTimestamp,
        };
        const isProtocolV2 =
          Number(sessionData.matchProtocolVersion) >= 2 &&
          Boolean(String(sessionData.pairAttemptId || "").trim());
        if (terminalStatus === VIDEO_SESSION_STATUS.EXPIRED) {
          sessionUpdates.expiredAt =
            admin.firestore.FieldValue.serverTimestamp();
          sessionUpdates.expireReason = stopReason;
        } else {
          sessionUpdates.cancelledAt =
            admin.firestore.FieldValue.serverTimestamp();
          sessionUpdates.cancelledBy = userId;
          sessionUpdates.cancelReason = stopReason;
        }

        await releaseSessionPairLocksInTransaction(
          buildPreActiveSessionPairLockReleaseOptions({
            db,
            transaction,
            sessionId,
            sessionData,
            serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
            fieldDelete: admin.firestore.FieldValue.delete(),
            searchRequestStatus,
            stopReason,
          }),
        );
        for (const trialContext of trialContexts) {
          reconcileTrialCallInTransaction({
            transaction,
            trialRef: trialContext.ref,
            trialSnap: trialContext.snap,
            trialCallId: trialContext.trialCallId,
            durationSeconds: 0,
            technicalFailure: true,
            nowMillis: requestTimestamp,
          });
        }
        if (isProtocolV2) {
          const serverTimestamp =
            admin.firestore.FieldValue.serverTimestamp();
          cancelProtocolV2NotificationsInTransaction({
            db,
            transaction,
            sessionId,
            pairAttemptId: sessionData.pairAttemptId,
            participantStates: sessionData.participantStates || {},
            cancelReason: stopReason,
            serverTimestamp,
          });
          sessionUpdates.matchRecovery = {
            status: "pending",
            attempts: 0,
            pairAttemptId: sessionData.pairAttemptId,
            reason: stopReason,
            restoreParticipantIds: [],
            requestedAt: serverTimestamp,
          };
        }
        transaction.update(sessionRef, sessionUpdates);

        return {
          status: terminalStatus,
          message: "Pre-active session closed",
          sessionId,
          endedAt: requestTimestamp,
          dailyRoomName: resolveDailyRoomName(sessionData),
          matchProtocolVersion: sessionData.matchProtocolVersion || 1,
          pairAttemptId: sessionData.pairAttemptId || null,
          participantStates: sessionData.participantStates || {},
          cancelReason: stopReason,
        };
      }

      if (
        !shouldProcessExpiredEndReason({
          sessionData,
          endReason,
          requestTimestamp,
        })
      ) {
        return {
          status: "ignored_expired_end",
          message: "Session limit has not been reached",
          sessionId,
        };
      }

      const requesterId = getRequesterId(sessionData);
      const endedBy = userId;
      const endedByRole = requesterId === userId ? "requester" : "responder";
      const startTime = getConnectedCallStartMillis(sessionData);
      const duration = startTime > 0
        ? Math.max(0, Math.floor((requestTimestamp - startTime) / 1000))
        : 0;
      const tutorDurationMinutes = parseFloat((duration / 60).toFixed(4));
      const analyticsDurationMinutes = parseFloat(
        tutorDurationMinutes.toFixed(1),
      );
      const formattedDuration = formatDuration(duration);

      const requesterDocRef = db.collection("users").doc(sessionData.studentId);
      const requesterDoc = await transaction.get(requesterDocRef);
      const requesterData = requesterDoc.exists ? requesterDoc.data() : {};
      const responderDocRef = sessionData.tutorId ?
        db.collection("users").doc(sessionData.tutorId) :
        null;
      const responderDoc = responderDocRef ?
        await transaction.get(responderDocRef) :
        null;
      const responderData = responderDoc?.exists ? responderDoc.data() : {};
      const requesterRole =
        normalizeRole(sessionData.matchContext?.requesterRole) ||
        normalizeRole(requesterData.role);
      const acceptedResponderRole =
        normalizeRole(sessionData.matchContext?.acceptedResponderRole) ||
        normalizeRole(responderData.role);
      const tutorEarning = parseFloat(
        (tutorDurationMinutes * TUTOR_RATE_PER_MINUTE).toFixed(2),
      );
      const teacherEarningUserId = resolveTeacherEarningUserId({
        requesterId: sessionData.studentId,
        requesterRole,
        responderId: sessionData.tutorId || null,
        acceptedResponderRole,
      });
      const requesterSubscriptionActive = hasActiveSubscription(
        requesterData,
        requestTimestamp,
      );
      const responderSubscriptionActive = hasActiveSubscription(
        responderData,
        requestTimestamp,
      );
      // ─── GIFT MINUTES ──────────────────────────────────────────────
      // Read the unexpired remaining gift bucket for each participant.
      // Subscribers get a zero passed in (subscriptionActive wins anyway).
      const requesterGiftRemaining = requesterSubscriptionActive ?
        0 :
        remainingGiftMinutes(requesterData, requestTimestamp);
      const responderGiftRemaining = responderSubscriptionActive ?
        0 :
        remainingGiftMinutes(responderData, requestTimestamp);
      // ──────────────────────────────────────────────────────────────

      const chargeRecords = [];
      if (requesterRole === "student") {
        chargeRecords.push(buildStudentCallCharge({
          userId: sessionData.studentId,
          duration,
          formattedDuration,
          subscriptionActive: requesterSubscriptionActive,
          giftRemainingMinutes: requesterGiftRemaining,
        }));
      }
      if (
        acceptedResponderRole === "student" &&
        sessionData.tutorId &&
        sessionData.tutorId !== sessionData.studentId
      ) {
        chargeRecords.push(buildStudentCallCharge({
          userId: sessionData.tutorId,
          duration,
          formattedDuration,
          subscriptionActive: responderSubscriptionActive,
          giftRemainingMinutes: responderGiftRemaining,
        }));
      }
      const teacherEligibleForPayout =
        !!teacherEarningUserId && chargeRecords.length > 0;
      const responderEligibleForPayout =
        teacherEligibleForPayout && acceptedResponderRole === "native_speaker";
      const amountST = parseFloat(
        chargeRecords
          .reduce((total, charge) => total + charge.amountST, 0)
          .toFixed(4),
      );
      // Legacy field kept for back-compat with consumers of videoSession;
      // the "first minute free" mechanic was removed in the gift-minutes
      // refactor — the field is now always `false`.
      const freeMinuteApplied = false;

      console.log(
        "⏱️ Session duration:",
        duration,
        "seconds /",
        tutorDurationMinutes,
        "tutor-minutes /",
        formattedDuration,
      );
      console.log("👤 Ended by:", endedByRole, endedBy);
      console.log(
        "💰 Teacher earning:",
        teacherEligibleForPayout ? tutorEarning : 0,
        "RUB",
      );
      console.log(
        "📉 Student charges:",
        chargeRecords.map((charge) => ({
          userId: charge.userId,
          billableMinutes: charge.billableMinutes,
          subscriptionActive: charge.subscriptionActive,
          giftCovered: charge.giftCovered,
          giftMinutesUsed: charge.giftMinutesUsed,
          newGiftMinutes: charge.newGiftMinutes,
        })),
      );

      const pairHistoryWrite = buildCompletedPairHistoryWrite({
        db,
        sessionId,
        sessionRef,
        sessionData,
        completedAtMillis: requestTimestamp,
      });
      const sessionUpdates = {
        status: VIDEO_SESSION_STATUS.ENDED,
        endedAt: admin.firestore.FieldValue.serverTimestamp(),
        duration: duration,
        durationMinutes: tutorDurationMinutes,
        freeMinuteApplied: freeMinuteApplied,
        chargedParticipantIds: chargeRecords
            .filter((charge) => !charge.subscriptionActive)
            .map((charge) => charge.userId),
        subscriptionCoveredParticipantIds: chargeRecords
            .filter((charge) => charge.subscriptionActive)
            .map((charge) => charge.userId),
        tutorNavigationTriggered: false,
        studentNavigationTriggered: false,
        acceptingTutorId: admin.firestore.FieldValue.delete(),
        acceptingAt: admin.firestore.FieldValue.delete(),
        acceptAttemptId: admin.firestore.FieldValue.delete(),
        "matchContext.teacherEarningUserId": teacherEarningUserId,
        "matchContext.teacherEligibleForPayout": teacherEligibleForPayout,
        "matchContext.responderEligibleForPayout": responderEligibleForPayout,
      };

      if (pairHistoryWrite) {
        sessionUpdates["matchContext.completedPairId"] =
          pairHistoryWrite.pairId;
        sessionUpdates["matchContext.completedDayKey"] =
          pairHistoryWrite.dayKey;
        sessionUpdates["matchContext.completedPairHistoryRef"] =
          pairHistoryWrite.ref;
      }

      await releaseSessionPairLocksInTransaction(
        buildEndedSessionPairLockReleaseOptions({
          db,
          transaction,
          sessionId,
          sessionData,
          serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
          fieldDelete: admin.firestore.FieldValue.delete(),
        }),
      );

      for (const trialContext of trialContexts) {
        reconcileTrialCallInTransaction({
          transaction,
          trialRef: trialContext.ref,
          trialSnap: trialContext.snap,
          trialCallId: trialContext.trialCallId,
          durationSeconds: duration,
          technicalFailure: false,
          nowMillis: requestTimestamp,
        });
      }

      transaction.update(sessionRef, sessionUpdates);
      if (pairHistoryWrite) {
        transaction.set(pairHistoryWrite.ref, pairHistoryWrite.data, {
          merge: true,
        });
      }

      chargeRecords.forEach((charge) => {
        if (charge.subscriptionActive) {
          // Active subscription — no debit. Subscription lifecycle is
          // tracked by the RevenueCat webhook.
          return;
        }
        if (charge.giftCovered) {
          // Gift bucket covered (some of) the call — decrement the
          // remaining minutes. balanceST is no longer touched (legacy
          // pre-paid balance is being phased out by the migration).
          transaction.update(db.collection("users").doc(charge.userId), {
            "giftMinutes.minutes": charge.newGiftMinutes,
          });
        }
      });

      console.log(
        "✅ Transaction completed - session ended and participant balances updated",
      );
      return {
        status: "ended",
        message: "Session ended successfully",
        sessionId,
        duration,
        endedBy: endedByRole,
        endedAt: requestTimestamp,
        amountST,
        freeMinuteApplied,
        analyticsDurationMinutes,
        tutorDurationMinutes,
        tutorEarning: teacherEligibleForPayout ? tutorEarning : 0,
        formattedDuration,
        studentId: sessionData.studentId,
        tutorId: sessionData.tutorId || null,
        requesterRole,
        acceptedResponderRole,
        chargeRecords,
        dailyRoomName: resolveDailyRoomName(sessionData),
        teacherEarningUserId,
        teacherEligibleForPayout,
        responderEligibleForPayout,
      };
    });

    if (txResult.status === "already_ended") {
      if (txResult.dailyRoomName) {
        await deleteDailyRoomForSession({
          db,
          sessionId,
          roomName: txResult.dailyRoomName,
          source: "endSession_already_ended",
        });
      }
      return txResult;
    }

    if ([
      VIDEO_SESSION_STATUS.CANCELLED,
      VIDEO_SESSION_STATUS.EXPIRED,
    ].includes(txResult.status)) {
      const terminalSideEffects = [cancelAllSessionNotifications(sessionId)];
      if (
        Number(txResult.matchProtocolVersion) >= 2 &&
        txResult.pairAttemptId
      ) {
        terminalSideEffects.push(cancelProtocolV2NativeSurfaces({
          db,
          sessionId,
          pairAttemptId: txResult.pairAttemptId,
          participantStates: txResult.participantStates,
          reason: txResult.cancelReason || "pre_active_cancelled",
        }));
      }
      const terminalResults = await Promise.allSettled(terminalSideEffects);
      terminalResults.forEach((result) => {
        if (result.status === "rejected") {
          console.error(
            "⚠️ Failed to close pre-active native call surface:",
            result.reason,
          );
        }
      });
      if (txResult.dailyRoomName) {
        await deleteDailyRoomForSession({
          db,
          sessionId,
          roomName: txResult.dailyRoomName,
          source: "endSession_pre_active_terminal",
        });
      }
      const {
        matchProtocolVersion: _matchProtocolVersion,
        pairAttemptId: _pairAttemptId,
        participantStates: _participantStates,
        cancelReason: _cancelReason,
        ...response
      } = txResult;
      return response;
    }

    if (txResult.status !== VIDEO_SESSION_STATUS.ENDED) {
      return txResult;
    }

    const response = {
      status: txResult.status,
      message: txResult.message,
      sessionId: txResult.sessionId,
      duration: txResult.duration,
      endedBy: txResult.endedBy,
      endedAt: txResult.endedAt,
    };

    await attemptConversationUnlockEventWrite(db, sessionId);
    try {
      const endedSessionRef = db.collection("videoSessions").doc(sessionId);
      const endedSessionSnap = await endedSessionRef.get();
      if (endedSessionSnap.exists) {
        await ensureConversationCallEventForSession({
          db,
          sessionId,
          sessionRef: endedSessionRef,
          sessionData: endedSessionSnap.data() || {},
        });
      }
    } catch (error) {
      console.error("⚠️ Failed to create conversation call event:", error);
    }

    // ─── BACKGROUND OPERATIONS (non-blocking for UX) ──────────────────────
    console.log("📊 Running background billing, stats & notifications...");

    const teacherEarningRef = txResult.teacherEarningUserId
      ? db.collection("users").doc(txResult.teacherEarningUserId)
      : null;
    const todayStr = new Date().toISOString().slice(0, 10); // "2026-02-15"

    const backgroundTasks = [];

    // a) Student transaction documents.
    // After the gift-minutes refactor, students NEVER incur a paid
    // call_charge — they are either:
    //   • subscribed (audit in subscription_* events from RC webhook), or
    //   • on gift minutes (audit captured by giftMinutes.minutes diff).
    // No call_charge transaction is written in either case. Block kept
    // for structural parity; if a future model reintroduces per-call
    // billing this is the place to add it.
    for (const charge of txResult.chargeRecords || []) {
      if (charge.subscriptionActive || charge.giftCovered) {
        continue;
      }
      // Defensive: an unsubscribed user with no gift minutes shouldn't
      // have been able to start the call (gate in create_video_session).
      // If we ever land here, just log — don't charge.
      console.warn("⚠️ end_session: call with no subscription and no gift", {
        userId: charge.userId,
        sessionId,
      });
    }

    // b) Teacher balance update + c) teacher transaction document
    if (teacherEarningRef && txResult.teacherEligibleForPayout) {
      // b) Increment tutor balance
      backgroundTasks.push(
        teacherEarningRef.update({
          balance_NS: admin.firestore.FieldValue.increment(txResult.tutorEarning),
        }).catch((e) => console.error("❌ Tutor balance update failed:", e))
      );

      // c) Tutor transaction document
      backgroundTasks.push(
        db.collection("transactions").add({
          userId: teacherEarningRef,
          type: "earning",
          status: "completed",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          amount: txResult.tutorEarning,
          callDuration: txResult.formattedDuration,
          sessionId: sessionId,
        }).catch((e) => console.error("❌ Tutor transaction doc failed:", e))
      );
    }

    // d) Analytics summary (single document, atomic increments)
    backgroundTasks.push(
      db.collection("analytics").doc("summary").set({
        totalCalls: admin.firestore.FieldValue.increment(1),
        totalDurationMinutes: admin.firestore.FieldValue.increment(
          txResult.analyticsDurationMinutes,
        ),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true }).catch((e) => console.error("❌ Analytics summary failed:", e))
    );

    // e) Student stats (all-time + today)
    for (const charge of txResult.chargeRecords || []) {
      const chargedUserRef = db.collection("users").doc(charge.userId);
      backgroundTasks.push(
        db.runTransaction(async (t) => {
          const ref = chargedUserRef.collection("stats").doc("allTime");
          const snap = await t.get(ref);
          const d = snap.exists ? snap.data() : {};
          const newSec = (d.totalDurationSeconds || 0) + txResult.duration;
          t.set(ref, {
            totalCalls: (d.totalCalls || 0) + 1,
            totalDurationSeconds: newSec,
            totalMinutes: formatSecondsToMinStr(newSec),
            isAllTime: true,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }).catch((e) => console.error("❌ Student allTime stats failed:", e))
      );

      backgroundTasks.push(
        db.runTransaction(async (t) => {
          const ref = chargedUserRef.collection("stats").doc(todayStr);
          const snap = await t.get(ref);
          const d = snap.exists ? snap.data() : {};
          const newSec = (d.durationSecondsToday || 0) + txResult.duration;
          t.set(ref, {
            callsToday: (d.callsToday || 0) + 1,
            durationSecondsToday: newSec,
            minutesToday: formatSecondsToMinStr(newSec),
            date: new Date(todayStr + "T00:00:00Z"),
            isAllTime: false,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }).catch((e) => console.error("❌ Student today stats failed:", e))
      );
    }

    // f) Teacher stats (all-time + today)
    if (teacherEarningRef && txResult.teacherEligibleForPayout) {
      backgroundTasks.push(
        db.runTransaction(async (t) => {
          const ref = teacherEarningRef.collection("stats").doc("allTime");
          const snap = await t.get(ref);
          const d = snap.exists ? snap.data() : {};
          const newSec = (d.totalDurationSeconds || 0) + txResult.duration;
          t.set(ref, {
            totalCalls: (d.totalCalls || 0) + 1,
            totalDurationSeconds: newSec,
            totalMinutes: formatSecondsToMinStr(newSec),
            totalEarned: (d.totalEarned || 0) + txResult.tutorEarning,
            isAllTime: true,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }).catch((e) => console.error("❌ Tutor allTime stats failed:", e))
      );

      backgroundTasks.push(
        db.runTransaction(async (t) => {
          const ref = teacherEarningRef.collection("stats").doc(todayStr);
          const snap = await t.get(ref);
          const d = snap.exists ? snap.data() : {};
          const newSec = (d.durationSecondsToday || 0) + txResult.duration;
          const newEarned = (d.earnedTodayNumeric || 0) + txResult.tutorEarning;
          t.set(ref, {
            callsToday: (d.callsToday || 0) + 1,
            durationSecondsToday: newSec,
            minutesToday: formatSecondsToMinStr(newSec),
            earnedTodayNumeric: newEarned,
            earnedToday: `${newEarned} ₽`,
            date: new Date(todayStr + "T00:00:00Z"),
            isAllTime: false,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }).catch((e) => console.error("❌ Tutor today stats failed:", e))
      );
    }

    // g) Subscription usage tracking — only for subscription-covered
    // participants. The increment runs in its own Firestore transaction
    // and auto-resets day/week counters when the corresponding window
    // has rolled over. Awaited via Promise.all so the next call this
    // user starts will see the updated counters.
    for (const charge of txResult.chargeRecords || []) {
      if (!charge.subscriptionActive) continue;
      backgroundTasks.push(
        db.runTransaction(async (t) => {
          await incrementUsageInTransaction(
            t,
            db,
            charge.userId,
            txResult.duration,
          );
        }).catch((e) =>
          console.error("❌ Subscription usage increment failed:", e)
        )
      );
    }

    // h) Cancel notifications
    backgroundTasks.push(
      cancelAllSessionNotifications(sessionId)
    );

    if (txResult.dailyRoomName) {
      backgroundTasks.push(deleteDailyRoomForSession({
        db,
        sessionId,
        roomName: txResult.dailyRoomName,
        source: "endSession",
      }));
    }

    await Promise.all(backgroundTasks);
    console.log("🎉 Session ended successfully with billing complete");

    return response;
  } catch (error) {
    console.error("❌ Error ending session:", error);

    if (error.code) {
      throw error;
    }

    throw new functions.https.HttpsError("internal", error.message);
  }
  });

function formatDuration(totalSeconds) {
  const mins = Math.floor(totalSeconds / 60);
  const secs = totalSeconds % 60;
  return `${mins}:${secs.toString().padStart(2, "0")}`;
}

function formatSecondsToMinStr(totalSeconds) {
  const mins = Math.floor(totalSeconds / 60);
  const secs = totalSeconds % 60;
  return `${mins}:${secs.toString().padStart(2, "0")} мин`;
}

async function attemptConversationUnlockEventWrite(db, sessionId) {
  try {
    const sessionRef = db.collection("videoSessions").doc(sessionId);
    const sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists) {
      console.log("⚠️ Skipping chat unlock event - session missing:", sessionId);
      return;
    }

    const sessionData = sessionSnap.data() || {};
    const eligibility = getUnlockEligibility(sessionData);
    if (!eligibility.eligible) {
      console.log(
        "ℹ️ Skipping chat unlock event - session is not eligible:",
        sessionId,
        eligibility.reason,
      );
      return;
    }

    const eventRef = db.collection("conversationUnlockEvents").doc(sessionId);
    await db.runTransaction(async (transaction) => {
      const eventSnap = await transaction.get(eventRef);
      if (eventSnap.exists) {
        return null;
      }

      transaction.set(
        eventRef,
        buildUnlockEventPayload({
          sessionId,
          sessionRef,
          participants: eligibility,
          source: "endSession",
        }),
      );

      return null;
    });

    console.log("✅ Conversation unlock event written:", sessionId);
  } catch (error) {
    console.error("❌ Failed to write conversation unlock event:", {
      sessionId,
      error: error.message,
    });
  }
}

// ОТМЕНА ВСЕХ УВЕДОМЛЕНИЙ ДЛЯ СЕССИИ
async function cancelAllSessionNotifications(sessionId) {
  try {
    console.log("🚫 Canceling all notifications for session:", sessionId);

    const activeNotificationsQuery = await admin
      .firestore()
      .collection("notifications")
      .where("sessionId", "==", sessionId)
      .where("status", "==", "sent")
      .get();

    if (!activeNotificationsQuery.empty) {
      const batch = admin.firestore().batch();

      activeNotificationsQuery.forEach((doc) => {
        batch.update(doc.ref, {
          status: "cancelled",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelReason: "session_ended",
        });
      });

      await batch.commit();
      console.log(
        `✅ Canceled ${activeNotificationsQuery.size} notification(s)`,
      );
    }
  } catch (error) {
    console.error("❌ Error canceling session notifications:", error);
  }
}

exports.__private__ = {
  buildEndedSessionPairLockReleaseOptions,
  buildPreActiveSessionPairLockReleaseOptions,
  buildStudentCallCharge,
  hasConnectedCallEvidence,
  hasActiveSubscription,
  isExpiredEndReason,
  remainingGiftMinutes,
  resolveTeacherEarningUserId,
  shouldProcessExpiredEndReason,
  toMillis,
};
