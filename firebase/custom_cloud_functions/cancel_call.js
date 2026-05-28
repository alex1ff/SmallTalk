const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  resolveDailyRoomName,
} = require("./daily_room");
const {
  deleteDailyRoomForSession,
} = require("./daily_room_cleanup");
const {
  CALL_EVENT_OUTCOME_CANCELLED,
  ensureConversationCallEventForSession,
} = require("./chats_shared");
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
exports.cancelCall = functions
  .runWith({ secrets: dailySecrets })
  .https.onCall(async (data, context) => {
  console.log("❌ Cancelling video session (updated version)...");

  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
      );
    }

    const studentId = context.auth.uid;
    const { sessionId } = data; // Изменено с callId на sessionId

    console.log("👨‍🎓 Student ID:", studentId);
    console.log("📺 Session ID:", sessionId);

    if (!sessionId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Session ID is required",
      );
    }

    console.log("🔄 Updating session status to cancelled...");

    const db = admin.firestore();
    const sessionRef = admin
      .firestore()
      .collection("videoSessions")
      .doc(sessionId);
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
      console.log("📋 Session data status:", sessionData.status);
      console.log("👤 Session student ID:", sessionData.studentId);

      // Проверяем, что это сессия этого студента
      if (sessionData.studentId !== studentId) {
        console.log("❌ Permission denied - wrong student");
        throw new functions.https.HttpsError(
          "permission-denied",
          "You can only cancel your own sessions",
        );
      }

      // Проверяем, что сессию можно отменить
      if (!["searching", "connecting"].includes(sessionData.status)) {
        console.log(
          "❌ Session cannot be cancelled, current status:",
          sessionData.status,
        );
        throw new functions.https.HttpsError(
          "invalid-argument",
          `Session cannot be cancelled. Current status: ${sessionData.status}`,
        );
      }

      transaction.update(sessionRef, {
        status: "cancelled",
        endedAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelledBy: studentId,
        cancelReason: "cancelled_by_student",
        currentTutorId: admin.firestore.FieldValue.delete(),
        acceptingTutorId: admin.firestore.FieldValue.delete(),
        acceptingAt: admin.firestore.FieldValue.delete(),
        tutorNavigationTriggered: false,
        studentNavigationTriggered: false,
      });

      return {
        dailyRoomName: resolveDailyRoomName(sessionData),
        sessionData,
      };
    });

    try {
      await ensureConversationCallEventForSession({
        db,
        sessionId,
        sessionRef,
        sessionData: {
          ...txResult.sessionData,
          status: "cancelled",
        },
        callOutcome: CALL_EVENT_OUTCOME_CANCELLED,
        eventMillis: Date.now(),
        partnerId: txResult.sessionData.currentTutorId,
      });
    } catch (error) {
      console.error("⚠️ Failed to create cancelled call event:", error);
    }

    if (txResult.dailyRoomName) {
      await deleteDailyRoomForSession({
        db,
        sessionId,
        roomName: txResult.dailyRoomName,
        source: "cancelCall",
      });
    }

    console.log("🔔 Cancelling active notifications...");

    // Находим и отменяем все активные уведомления для этой сессии
    const activeNotificationsQuery = await admin
      .firestore()
      .collection("notifications")
      .where("sessionId", "==", sessionId) // Изменено с callRequestId
      .where("status", "==", "sent")
      .get();

    if (!activeNotificationsQuery.empty) {
      console.log(
        `📨 Found ${activeNotificationsQuery.size} active notifications to cancel`,
      );

      const batch = admin.firestore().batch();
      activeNotificationsQuery.forEach((doc) => {
        batch.update(doc.ref, {
          status: "cancelled",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();

      console.log("✅ Active notifications cancelled");
    } else {
      console.log("📭 No active notifications found");
    }

    // Если есть текущий преподаватель, освобождаем его
    if (txResult.sessionData.currentTutorId) {
      console.log(
        "👨‍🏫 Releasing current tutor:",
        txResult.sessionData.currentTutorId,
      );
      try {
        await admin
          .firestore()
          .collection("users")
          .doc(txResult.sessionData.currentTutorId)
          .update({
            currentSessionId: admin.firestore.FieldValue.delete(),
          });
      } catch (tutorUpdateError) {
        console.log(
          "⚠️ Could not update tutor status (non-critical):",
          tutorUpdateError.message,
        );
      }
    }

    console.log("✅ Video session successfully cancelled");

    return {
      status: "cancelled",
      message: "Video session cancelled successfully",
      sessionId: sessionId,
    };
  } catch (error) {
    console.error("❌ Error cancelling video session:", error);

    if (error.code) {
      throw error;
    }

    throw new functions.https.HttpsError("internal", error.message);
  }
  });
