const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  buildUnlockEventPayload,
  ensureConversationCallEventForSession,
  getUnlockEligibility,
} = require("./chats_shared");
const {
  buildCompletedPairHistoryWrite,
} = require("./match_repeat_prevention");
const {
  getRequesterId,
  isSessionParticipant,
  normalizeRole,
} = require("./video_sessions_shared");

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

function buildStudentCallCharge({
  userId,
  currentMinutes,
  currentSmallTalks,
  duration,
  formattedDuration,
}) {
  const safeCurrentMinutes = Number(currentMinutes || 0);
  const safeCurrentSmallTalks = Number(currentSmallTalks || 0);
  const freeMinuteApplied = safeCurrentMinutes > 0 || safeCurrentSmallTalks > 0;
  const billableDuration = freeMinuteApplied ?
    Math.max(0, duration - 60) :
    duration;
  const billableMinutes = parseFloat((billableDuration / 60).toFixed(4));
  const amountST = parseFloat((billableMinutes / 10).toFixed(4));
  const newMinutes = parseFloat(
    Math.max(0, safeCurrentMinutes - billableMinutes).toFixed(4),
  );
  const newSmallTalks = parseFloat((newMinutes / 10).toFixed(2));

  return {
    userId,
    currentMinutes: safeCurrentMinutes,
    currentSmallTalks: safeCurrentSmallTalks,
    freeMinuteApplied,
    billableDuration,
    billableMinutes,
    amountST,
    newMinutes,
    newSmallTalks,
    formattedDuration,
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

exports.endSession = functions.https.onCall(async (data, context) => {
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
    // connecting|active -> ended. This makes endSession idempotent under races.
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

      if (!isSessionParticipant(sessionData, userId)) {
        console.log("❌ Permission denied - user is not a participant");
        throw new functions.https.HttpsError(
          "permission-denied",
          "You are not a participant of this session",
        );
      }

      if (sessionData.status === "ended") {
        return {
          status: "already_ended",
          message: "Session was already ended",
          endedAt:
            sessionData.endedAt?.toMillis?.() ||
            sessionData.sessionMetadata?.endedAtTimestamp ||
            null,
        };
      }

      if (!["connecting", "active"].includes(sessionData.status)) {
        console.log(
          "❌ Session cannot be ended, current status:",
          sessionData.status,
        );
        throw new functions.https.HttpsError(
          "invalid-argument",
          `Session cannot be ended. Current status: ${sessionData.status}`,
        );
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
      const callConnectedAt =
        toMillis(sessionData.sessionMetadata?.callConnectedAt);
      const legacyCallConnectedAt =
        toMillis(sessionData.sessionMetadata?.callConnectedAtTimestamp);
      const startedAt = toMillis(sessionData.startedAt);
      const acceptedAt =
        toMillis(sessionData.acceptedAt) ||
        toMillis(sessionData.sessionMetadata?.acceptedAt);
      const serverConnectedAt =
        startedAt > 0 && (acceptedAt === 0 || startedAt - acceptedAt > 1000)
          ? startedAt
          : 0;
      const startTime =
        callConnectedAt || legacyCallConnectedAt || serverConnectedAt || 0;
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
      const chargeRecords = [];
      if (requesterRole === "student") {
        chargeRecords.push(buildStudentCallCharge({
          userId: sessionData.studentId,
          currentMinutes: requesterData?.balanceST?.minutes,
          currentSmallTalks: requesterData?.balanceST?.smallTalks,
          duration,
          formattedDuration,
        }));
      }
      if (
        acceptedResponderRole === "student" &&
        sessionData.tutorId &&
        sessionData.tutorId !== sessionData.studentId
      ) {
        chargeRecords.push(buildStudentCallCharge({
          userId: sessionData.tutorId,
          currentMinutes: responderData?.balanceST?.minutes,
          currentSmallTalks: responderData?.balanceST?.smallTalks,
          duration,
          formattedDuration,
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
      const freeMinuteApplied = chargeRecords.some(
        (charge) => charge.freeMinuteApplied,
      );

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
          currentMinutes: charge.currentMinutes,
          newMinutes: charge.newMinutes,
          billableMinutes: charge.billableMinutes,
          amountST: charge.amountST,
          freeMinuteApplied: charge.freeMinuteApplied,
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
        status: "ended",
        endedAt: admin.firestore.FieldValue.serverTimestamp(),
        duration: duration,
        durationMinutes: tutorDurationMinutes,
        freeMinuteApplied: freeMinuteApplied,
        chargedParticipantIds: chargeRecords.map((charge) => charge.userId),
        tutorNavigationTriggered: false,
        studentNavigationTriggered: false,
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

      transaction.update(sessionRef, sessionUpdates);
      if (pairHistoryWrite) {
        transaction.set(pairHistoryWrite.ref, pairHistoryWrite.data, {
          merge: true,
        });
      }

      if (sessionData.tutorId) {
        console.log("👨‍🏫 Releasing tutor:", sessionData.tutorId);
        transaction.update(db.collection("users").doc(sessionData.tutorId), {
          isInCall: false,
          isAvailable: true,
          currentSessionId: admin.firestore.FieldValue.delete(),
          lastCallEndedAt: admin.firestore.FieldValue.serverTimestamp(),
          availableAfter: admin.firestore.FieldValue.delete(),
        });
      }

      chargeRecords.forEach((charge) => {
        transaction.update(db.collection("users").doc(charge.userId), {
          "balanceST.minutes": charge.newMinutes,
          "balanceST.smallTalks": charge.newSmallTalks,
        });
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
        teacherEarningUserId,
        teacherEligibleForPayout,
        responderEligibleForPayout,
      };
    });

    if (txResult.status === "already_ended") {
      return txResult;
    }

    if (txResult.status !== "ended") {
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

    // a) Student transaction documents. Student-student sessions charge both
    // participants but do not create any earning transaction.
    for (const charge of txResult.chargeRecords || []) {
      const chargedUserRef = db.collection("users").doc(charge.userId);
      backgroundTasks.push(
        db.collection("transactions").add({
          userId: chargedUserRef,
          type: "call_charge",
          status: "completed",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          amount_ST: Number(charge.amountST),
          callDuration: charge.formattedDuration,
          sessionId: sessionId,
          freeMinuteApplied: charge.freeMinuteApplied,
        }).catch((e) => console.error("❌ Student transaction doc failed:", e))
      );
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

    // g) Cancel notifications
    backgroundTasks.push(
      cancelAllSessionNotifications(sessionId)
    );

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
  buildStudentCallCharge,
  resolveTeacherEarningUserId,
  shouldProcessExpiredEndReason,
  toMillis,
};
