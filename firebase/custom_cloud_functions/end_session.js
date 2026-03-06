const functions = require("firebase-functions");
const admin = require("firebase-admin");

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

      if (sessionData.studentId !== userId && sessionData.tutorId !== userId) {
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

      const endedBy = userId;
      const endedByRole = sessionData.studentId === userId ? "student" : "tutor";
      const callConnectedAt =
        toMillis(sessionData.sessionMetadata?.callConnectedAtTimestamp);
      const startedAt = toMillis(sessionData.startedAt);
      const acceptedAt =
        toMillis(sessionData.acceptedAt) ||
        toMillis(sessionData.sessionMetadata?.acceptedAt);
      const startTime =
        callConnectedAt || startedAt || acceptedAt || requestTimestamp;
      const duration = Math.max(0, Math.floor((requestTimestamp - startTime) / 1000));
      const tutorDurationMinutes = parseFloat((duration / 60).toFixed(4));
      const tutorEarning = parseFloat(
        (tutorDurationMinutes * TUTOR_RATE_PER_MINUTE).toFixed(2),
      );
      const formattedDuration = formatDuration(duration);

      const studentDocRef = db.collection("users").doc(sessionData.studentId);
      const studentDoc = await transaction.get(studentDocRef);
      const studentData = studentDoc.exists ? studentDoc.data() : {};
      const currentMinutes = Number(studentData?.balanceST?.minutes || 0);
      const currentSmallTalks = Number(studentData?.balanceST?.smallTalks || 0);

      // Free minute: first 60 seconds free when student has positive balance
      const freeMinuteApplied = currentMinutes > 0 || currentSmallTalks > 0;
      const billableDuration = freeMinuteApplied ? Math.max(0, duration - 60) : duration;
      const billableMinutes = parseFloat((billableDuration / 60).toFixed(4));
      const amountST = parseFloat((billableMinutes / 10).toFixed(4));

      const newMinutes = parseFloat(
        Math.max(0, currentMinutes - billableMinutes).toFixed(4),
      );
      const newSmallTalks = parseFloat((newMinutes / 10).toFixed(2));

      console.log(
        "⏱️ Session duration:",
        duration,
        "seconds /",
        tutorDurationMinutes,
        "tutor-minutes /",
        formattedDuration,
      );
      console.log("👤 Ended by:", endedByRole, endedBy);
      console.log("💰 Tutor earning:", tutorEarning, "RUB");
      console.log(
        "🎁 Free minute applied:",
        freeMinuteApplied,
        "| Billable:",
        billableDuration,
        "s /",
        billableMinutes,
        "min",
      );
      console.log(
        "📉 Student balance:",
        currentMinutes,
        "→",
        newMinutes,
        "minutes,",
        newSmallTalks,
        "ST",
      );

      const idempotencyKey = `end_session:${sessionId}`;
      transaction.update(sessionRef, {
        status: "ended",
        endedAt: admin.firestore.FieldValue.serverTimestamp(),
        duration: duration,
        durationMinutes: tutorDurationMinutes,
        freeMinuteApplied: freeMinuteApplied,
        tutorNavigationTriggered: false,
        studentNavigationTriggered: false,
        sessionMetadata: {
          ...sessionData.sessionMetadata,
          endedBy: endedBy,
          endedByRole: endedByRole,
          endReason: endReason || "manual",
          endedAtTimestamp: requestTimestamp,
          finalDuration: duration,
          billing: {
            idempotencyKey,
            amountST,
            tutorEarning,
            freeMinuteApplied,
            processedBy: userId,
            processedAtTimestamp: requestTimestamp,
          },
        },
      });

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

      transaction.update(studentDocRef, {
        "balanceST.minutes": newMinutes,
        "balanceST.smallTalks": newSmallTalks,
      });

      console.log(
        "✅ Transaction completed - session ended, tutor released, student charged",
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
        tutorDurationMinutes,
        tutorEarning,
        formattedDuration,
        studentId: sessionData.studentId,
        tutorId: sessionData.tutorId || null,
      };
    });

    if (txResult.status === "already_ended") {
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

    // ─── BACKGROUND OPERATIONS (non-blocking for UX) ──────────────────────
    console.log("📊 Running background billing, stats & notifications...");

    const studentRef = db.collection("users").doc(txResult.studentId);
    const tutorRef = txResult.tutorId
      ? db.collection("users").doc(txResult.tutorId)
      : null;
    const todayStr = new Date().toISOString().slice(0, 10); // "2026-02-15"

    const backgroundTasks = [];

    // a) Student transaction document
    backgroundTasks.push(
      db.collection("transactions").add({
        userId: studentRef,
        type: "call_charge",
        status: "completed",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        amount_ST: Number(txResult.amountST),
        callDuration: txResult.formattedDuration,
        sessionId: sessionId,
        freeMinuteApplied: txResult.freeMinuteApplied,
      }).catch((e) => console.error("❌ Student transaction doc failed:", e))
    );

    // b) Tutor balance update + c) Tutor transaction document
    if (tutorRef) {
      // b) Increment tutor balance
      backgroundTasks.push(
        tutorRef.update({
          balance_NS: admin.firestore.FieldValue.increment(txResult.tutorEarning),
        }).catch((e) => console.error("❌ Tutor balance update failed:", e))
      );

      // c) Tutor transaction document
      backgroundTasks.push(
        db.collection("transactions").add({
          userId: tutorRef,
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
        totalTransactions: admin.firestore.FieldValue.increment(tutorRef ? 2 : 1),
        totalDurationMinutes: admin.firestore.FieldValue.increment(
          txResult.tutorDurationMinutes,
        ),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true }).catch((e) => console.error("❌ Analytics summary failed:", e))
    );

    // e) Student stats (all-time + today)
    backgroundTasks.push(
      db.runTransaction(async (t) => {
        const ref = studentRef.collection("stats").doc("allTime");
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
        const ref = studentRef.collection("stats").doc(todayStr);
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

    // f) Tutor stats (all-time + today)
    if (tutorRef) {
      backgroundTasks.push(
        db.runTransaction(async (t) => {
          const ref = tutorRef.collection("stats").doc("allTime");
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
          const ref = tutorRef.collection("stats").doc(todayStr);
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
