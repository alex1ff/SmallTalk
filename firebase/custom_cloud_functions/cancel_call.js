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
const {
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");
const {
  releaseSessionPairLocksInTransaction,
} = require("./match_pair_lock");
const {
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const CANCELLABLE_SESSION_STATUSES = new Set([
  VIDEO_SESSION_STATUS.SEARCHING,
  VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
  VIDEO_SESSION_STATUS.CONNECTING,
]);

function buildCancelCallPairLockReleaseOptions({
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
    searchRequestStatus: SEARCH_REQUEST_STATUS.CANCELLED,
    stopReason: "call_cancelled",
    releaseCallState: true,
    restoreLegacyAvailability: true,
  };
}

function buildCancelCallSessionUpdate({
  cancelledBy,
  serverTimestamp,
  fieldDelete,
}) {
  return {
    status: VIDEO_SESSION_STATUS.CANCELLED,
    endedAt: serverTimestamp,
    cancelledAt: serverTimestamp,
    cancelledBy,
    cancelReason: "cancelled_by_student",
    currentTutorId: fieldDelete,
    currentResponderId: fieldDelete,
    currentResponderRole: fieldDelete,
    acceptingTutorId: fieldDelete,
    acceptingAt: fieldDelete,
    acceptAttemptId: fieldDelete,
    tutorNavigationTriggered: false,
    studentNavigationTriggered: false,
  };
}

function normalizeUserId(value) {
  return typeof value === "string" ? value.trim() : "";
}

function resolveCancelCallEventPartnerId(sessionData = {}) {
  return normalizeUserId(sessionData.currentResponderId) ||
    normalizeUserId(sessionData.currentTutorId);
}

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
      if (!CANCELLABLE_SESSION_STATUSES.has(sessionData.status)) {
        console.log(
          "❌ Session cannot be cancelled, current status:",
          sessionData.status,
        );
        throw new functions.https.HttpsError(
          "invalid-argument",
          `Session cannot be cancelled. Current status: ${sessionData.status}`,
        );
      }

      await releaseSessionPairLocksInTransaction(
        buildCancelCallPairLockReleaseOptions({
          db,
          transaction,
          sessionId,
          sessionData,
          serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
          fieldDelete: admin.firestore.FieldValue.delete(),
        }),
      );

      transaction.update(sessionRef, buildCancelCallSessionUpdate({
        cancelledBy: studentId,
        serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
        fieldDelete: admin.firestore.FieldValue.delete(),
      }));

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
        partnerId: resolveCancelCallEventPartnerId(txResult.sessionData),
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

exports.__private__ = {
  buildCancelCallPairLockReleaseOptions,
  buildCancelCallSessionUpdate,
  resolveCancelCallEventPartnerId,
};
