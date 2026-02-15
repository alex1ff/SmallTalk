const functions = require("firebase-functions");
const admin = require("firebase-admin");

// ─── Pricing ────────────────────────────────────────────────────────────────
// Student pays ~45-50 RUB/min (10 SmallTalks = 4990₽, 20 SmallTalks = 8900₽)
// 1 SmallTalk = 10 minutes
const TUTOR_RATE_PER_MINUTE = 15; // 15 RUB/min paid to tutor
// Platform margin: ~30-35 RUB/min

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

    // Получаем данные сессии
    const sessionDoc = await admin
      .firestore()
      .collection("videoSessions")
      .doc(sessionId)
      .get();

    if (!sessionDoc.exists) {
      console.log("❌ Video session not found:", sessionId);
      throw new functions.https.HttpsError(
        "not-found",
        "Video session not found",
      );
    }

    const sessionData = sessionDoc.data();
    console.log("📋 Current session status:", sessionData.status);

    // Проверяем права доступа
    if (sessionData.studentId !== userId && sessionData.tutorId !== userId) {
      console.log("❌ Permission denied - user is not a participant");
      throw new functions.https.HttpsError(
        "permission-denied",
        "You are not a participant of this session",
      );
    }

    // Проверяем, что сессия может быть завершена
    if (!["connecting", "active"].includes(sessionData.status)) {
      console.log(
        "❌ Session cannot be ended, current status:",
        sessionData.status,
      );

      if (sessionData.status === "ended") {
        return {
          status: "already_ended",
          message: "Session was already ended",
          endedAt: sessionData.endedAt?.toMillis() || null,
        };
      }

      throw new functions.https.HttpsError(
        "invalid-argument",
        `Session cannot be ended. Current status: ${sessionData.status}`,
      );
    }

    // Определяем, кто завершил сессию
    const endedBy = userId;
    const endedByRole = sessionData.studentId === userId ? "student" : "tutor";
    const now = Date.now();

    // Вычисляем длительность сессии
    const startTime =
      sessionData.startedAt?.toMillis() ||
      sessionData.createdAt?.toMillis() ||
      now;
    const duration = Math.max(0, Math.floor((now - startTime) / 1000)); // в секундах
    const durationMinutes = Math.max(1, Math.ceil(duration / 60)); // в минутах, минимум 1
    const tutorEarning = parseFloat((durationMinutes * TUTOR_RATE_PER_MINUTE).toFixed(2));
    const amountST = parseFloat((durationMinutes / 10).toFixed(2)); // в SmallTalks

    console.log("⏱️ Session duration:", duration, "seconds /", durationMinutes, "minutes");
    console.log("👤 Ended by:", endedByRole, endedBy);
    console.log("💰 Tutor earning:", tutorEarning, "RUB | Student charge:", amountST, "ST");

    // ─── MAIN TRANSACTION (fast, affects UX) ────────────────────────────────
    // 1. Set session status = ended
    // 2. Release tutor
    // 3. Deduct student balance (atomic with session end to prevent double-charge)
    await admin.firestore().runTransaction(async (transaction) => {
      // Read student doc inside transaction for consistent balance read
      const studentDocRef = admin.firestore().collection("users").doc(sessionData.studentId);
      const studentDoc = await transaction.get(studentDocRef);
      const studentData = studentDoc.exists ? studentDoc.data() : {};
      const currentMinutes = studentData?.balanceST?.minutes || 0;
      const newMinutes = Math.max(0, currentMinutes - durationMinutes);
      const newSmallTalks = Math.floor(newMinutes / 10);

      console.log("📉 Student balance: ", currentMinutes, "→", newMinutes, "minutes,", newSmallTalks, "ST");

      // 1. Update session status
      transaction.update(
        admin.firestore().collection("videoSessions").doc(sessionId),
        {
          status: "ended",
          endedAt: admin.firestore.FieldValue.serverTimestamp(),
          duration: duration,
          durationMinutes: durationMinutes,
          tutorNavigationTriggered: false,
          studentNavigationTriggered: false,
          sessionMetadata: {
            ...sessionData.sessionMetadata,
            endedBy: endedBy,
            endedByRole: endedByRole,
            endReason: endReason || "manual",
            endedAtTimestamp: now,
            finalDuration: duration,
          },
        },
      );

      // 2. Release tutor
      if (sessionData.tutorId) {
        console.log("👨‍🏫 Releasing tutor:", sessionData.tutorId);
        transaction.update(
          admin.firestore().collection("users").doc(sessionData.tutorId),
          {
            isInCall: false,
            isAvailable: true,
            currentSessionId: admin.firestore.FieldValue.delete(),
            lastCallEndedAt: admin.firestore.FieldValue.serverTimestamp(),
            availableAfter: admin.firestore.FieldValue.delete(),
          },
        );
      }

      // 3. Deduct student balance
      transaction.update(studentDocRef, {
        "balanceST.minutes": newMinutes,
        "balanceST.smallTalks": newSmallTalks,
      });

      console.log("✅ Transaction completed - session ended, tutor released, student charged");
    });

    // Return response to client IMMEDIATELY — all remaining writes are background
    const response = {
      status: "ended",
      message: "Session ended successfully",
      sessionId: sessionId,
      duration: duration,
      endedBy: endedByRole,
      endedAt: now,
    };

    // ─── BACKGROUND OPERATIONS (non-blocking for UX) ──────────────────────
    // These run in parallel after the response is conceptually ready.
    // We still await them on the server so Cloud Functions doesn't terminate early.
    console.log("📊 Running background billing, stats & notifications...");

    const db = admin.firestore();
    const studentRef = db.collection("users").doc(sessionData.studentId);
    const tutorRef = sessionData.tutorId
      ? db.collection("users").doc(sessionData.tutorId)
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
        amount_ST: amountST,
        callDuration: durationMinutes,
        sessionId: sessionId,
      }).catch((e) => console.error("❌ Student transaction doc failed:", e))
    );

    // b) Tutor balance update + c) Tutor transaction document
    if (tutorRef) {
      // b) Increment tutor balance
      backgroundTasks.push(
        tutorRef.update({
          balance_NS: admin.firestore.FieldValue.increment(tutorEarning),
        }).catch((e) => console.error("❌ Tutor balance update failed:", e))
      );

      // c) Tutor transaction document
      backgroundTasks.push(
        db.collection("transactions").add({
          userId: tutorRef,
          type: "earning",
          status: "completed",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          amount: tutorEarning,
          callDuration: durationMinutes,
          sessionId: sessionId,
        }).catch((e) => console.error("❌ Tutor transaction doc failed:", e))
      );
    }

    // d) Analytics summary (single document, atomic increments)
    backgroundTasks.push(
      db.collection("analytics").doc("summary").set({
        totalCalls: admin.firestore.FieldValue.increment(1),
        totalTransactions: admin.firestore.FieldValue.increment(tutorRef ? 2 : 1),
        totalDurationMinutes: admin.firestore.FieldValue.increment(durationMinutes),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true }).catch((e) => console.error("❌ Analytics summary failed:", e))
    );

    // e) Student stats (all-time + today)
    backgroundTasks.push(
      studentRef.collection("stats").doc("allTime").set({
        totalCalls: admin.firestore.FieldValue.increment(1),
        totalMinutes: admin.firestore.FieldValue.increment(durationMinutes),
        isAllTime: true,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true }).catch((e) => console.error("❌ Student allTime stats failed:", e))
    );

    backgroundTasks.push(
      studentRef.collection("stats").doc(todayStr).set({
        callsToday: admin.firestore.FieldValue.increment(1),
        minutesToday: admin.firestore.FieldValue.increment(durationMinutes),
        date: new Date(todayStr + "T00:00:00Z"),
        isAllTime: false,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true }).catch((e) => console.error("❌ Student today stats failed:", e))
    );

    // f) Tutor stats (all-time + today)
    if (tutorRef) {
      backgroundTasks.push(
        tutorRef.collection("stats").doc("allTime").set({
          totalCalls: admin.firestore.FieldValue.increment(1),
          totalMinutes: admin.firestore.FieldValue.increment(durationMinutes),
          totalEarned: admin.firestore.FieldValue.increment(tutorEarning),
          isAllTime: true,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true }).catch((e) => console.error("❌ Tutor allTime stats failed:", e))
      );

      backgroundTasks.push(
        tutorRef.collection("stats").doc(todayStr).set({
          callsToday: admin.firestore.FieldValue.increment(1),
          minutesToday: admin.firestore.FieldValue.increment(durationMinutes),
          earnedToday: admin.firestore.FieldValue.increment(tutorEarning),
          date: new Date(todayStr + "T00:00:00Z"),
          isAllTime: false,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true }).catch((e) => console.error("❌ Tutor today stats failed:", e))
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
