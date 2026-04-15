const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { sendApnsVoip } = require("./apns_voip");
const {
  createDailyRoom,
  createMeetingToken,
  getDailyRoom,
  getRoomNameFromUrl,
} = require("./daily_room");
const { evaluateTutorAvailabilityWindow } = require("./availability");
const {
  buildAcceptedSessionPolicyState,
  buildSessionUserInfo,
  getRequesterId,
  isSupportedSessionRole,
  normalizeRole,
} = require("./video_sessions_shared");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const PRECREATED_ROOM_VALIDATION_WINDOW_MS = 60 * 1000;

function buildAcceptCallPolicyUpdateFields(
  sessionData = {},
  nowMillis = Date.now(),
) {
  const policyState = buildAcceptedSessionPolicyState(sessionData, nowMillis);
  const sessionUpdateFields = {
    expiresAt: admin.firestore.Timestamp.fromDate(policyState.expiresAt),
  };
  if (policyState.sessionPolicy) {
    sessionUpdateFields.sessionPolicy = policyState.sessionPolicy;
  }
  return {
    policyState,
    sessionUpdateFields,
  };
}

function buildAcceptCallResponseSessionData(sessionData = {}) {
  return {
    language: sessionData.language,
    startedAt:
      sessionData.startedAt?.toMillis?.() ||
      sessionData.startedAt ||
      null,
    maxDuration:
      buildAcceptedSessionPolicyState(sessionData).maxDurationMs,
  };
}

exports.acceptCall = functions
  .runWith({ secrets: [...apnsSecrets, ...dailySecrets] })
  .https.onCall(async (data, context) => {
    console.log("✅ Tutor accepting call (updated version)...");

    let tutorId = null;
    let sessionRef = null;
    let lockAcquired = false;
    try {
      // === 1. АУТЕНТИФИКАЦИЯ И ВАЛИДАЦИЯ ===
      if (!context.auth) {
        console.log("❌ User not authenticated");
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated",
        );
      }

      tutorId = context.auth.uid;
      const { sessionId } = data;

      console.log("👨‍🏫 Tutor ID:", tutorId);
      console.log("📺 Session ID:", sessionId);

      if (!sessionId) {
        console.log("❌ Missing sessionId parameter");
        throw new functions.https.HttpsError(
          "invalid-argument",
          "sessionId is required",
        );
      }

      sessionRef = admin
        .firestore()
        .collection("videoSessions")
        .doc(sessionId);
      const acceptLockWindowMs = 30 * 1000;
      const initialSessionState = await admin
        .firestore()
        .runTransaction(async (transaction) => {
        const freshSnap = await transaction.get(sessionRef);
        if (!freshSnap.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "Video session not found",
          );
        }
        const fresh = freshSnap.data() || {};
        if (["active", "connecting"].includes(fresh.status)) {
          if (fresh.tutorId === tutorId && fresh.dailyRoomUrl) {
            return {
              alreadyAccepted: true,
              session: fresh,
            };
          }
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Session is already active",
          );
        }
        if (fresh.status !== "searching") {
          throw new functions.https.HttpsError(
            "invalid-argument",
            "Session is not available for acceptance",
          );
        }
        if (fresh.currentTutorId !== tutorId) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "This session is not assigned to you",
          );
        }
        if (fresh.expiresAt && fresh.expiresAt.toDate() < new Date()) {
          throw new functions.https.HttpsError(
            "invalid-argument",
            "Session has expired",
          );
        }
        const acceptingTutorId = fresh.acceptingTutorId || null;
        const acceptingAtMs = fresh.acceptingAt?.toMillis?.() || 0;
        const nowMs = Date.now();
        if (
          !acceptingTutorId ||
          nowMs - acceptingAtMs > acceptLockWindowMs
        ) {
          transaction.update(sessionRef, {
            acceptingTutorId: tutorId,
            acceptingAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          lockAcquired = true;
          return {
            alreadyAccepted: false,
            session: fresh,
          };
        }
        if (acceptingTutorId === tutorId) {
          transaction.update(sessionRef, {
            acceptingAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          lockAcquired = true;
          return {
            alreadyAccepted: false,
            session: fresh,
          };
        }
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Session is already being accepted",
        );
      });

      const sessionData = initialSessionState.session || {};
      console.log("📋 Session data:", {
        status: sessionData.status,
        currentTutorId: sessionData.currentTutorId,
        studentId: sessionData.studentId,
        language: sessionData.language,
      });

      if (initialSessionState.alreadyAccepted) {
        console.log(
          "ℹ️ Session already active for this tutor, returning existing room",
        );
        let existingRoomName =
          sessionData.dailyRoomName || getRoomNameFromUrl(sessionData.dailyRoomUrl);
        let existingMeetingToken = null;

        if (existingRoomName) {
          try {
            existingMeetingToken = await createMeetingToken({
              roomName: existingRoomName,
              expSeconds: 3600,
              isOwner: false,
              userId: tutorId,
              userName:
                sessionData.tutorInfo?.name ||
                sessionData.tutorName ||
                "Partner",
            });
          } catch (tokenError) {
            console.error(
              "⚠️ Failed to create meeting token for existing room:",
              tokenError.message,
            );
          }
        }

        return {
          status: "connected",
          sessionId: sessionId,
          roomUrl: sessionData.dailyRoomUrl,
          roomName: existingRoomName || null,
          meetingToken: existingMeetingToken || null,
          studentInfo: sessionData.studentInfo || null,
          sessionData: buildAcceptCallResponseSessionData(sessionData),
        };
      }

      const requesterId = getRequesterId(sessionData);
      if (!requesterId) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Session requester is missing",
        );
      }

      // === 3. ПОЛУЧЕНИЕ ДАННЫХ РЕСПОНДЕРА И ИНИЦИАТОРА (ПАРАЛЛЕЛЬНО) ===
      console.log("👥 Fetching responder and requester data in parallel...");
      const [tutorDoc, studentDoc] = await Promise.all([
        admin.firestore().collection("users").doc(tutorId).get(),
        admin.firestore().collection("users").doc(requesterId).get(),
      ]);

      if (!tutorDoc.exists) {
        console.log("❌ Tutor not found:", tutorId);
        throw new functions.https.HttpsError("not-found", "Tutor not found");
      }

      const tutorData = tutorDoc.data();
      const availabilityCheck = evaluateTutorAvailabilityWindow(tutorData);
      const isAvailable = availabilityCheck.isAvailable;

      console.log("👨‍🏫 Tutor data:", {
        display_name: tutorData.display_name,
        role: tutorData.role,
        isAvailable: tutorData.isAvailable,
        availabilityTodayEnabled: tutorData.availabilityToday?.enabled,
        isInCall: tutorData.isInCall,
        availabilityReason: availabilityCheck.reason,
        tutorLocalTime: availabilityCheck.localTime || null,
        timezoneOffsetMinutes: availabilityCheck.timezoneOffsetMinutes ?? null,
      });

      if (!isSupportedSessionRole(tutorData.role)) {
        console.log("❌ User role cannot accept calls:", tutorData.role);
        throw new functions.https.HttpsError(
          "permission-denied",
          "This user role cannot accept calls",
        );
      }

      if (!isAvailable) {
        console.log("❌ Tutor is not available");
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Tutor is not available",
        );
      }

      if (tutorData.isInCall) {
        console.log("❌ Tutor is already in a call");
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Tutor is already in a call",
        );
      }

      if (!studentDoc.exists) {
        console.log("❌ Requester not found:", requesterId);
        throw new functions.https.HttpsError("not-found", "Requester not found");
      }

      const studentData = studentDoc.data();
      console.log("👤 Requester data:", {
        display_name: studentData.display_name,
        role: studentData.role,
      });

      // === 5. ПОЛУЧЕНИЕ ИЛИ СОЗДАНИЕ КОМНАТЫ DAILY.CO ===
      console.log("🏠 Resolving Daily.co room...");

      let roomUrl = sessionData.dailyRoomUrl || null;
      let roomName =
        sessionData.dailyRoomName || getRoomNameFromUrl(sessionData.dailyRoomUrl);
      if (roomUrl) {
        const derivedName = getRoomNameFromUrl(roomUrl);
        if (derivedName) {
          if (!roomName || roomName !== derivedName) {
            console.log("⚠️ Room name mismatch, using name from URL", {
              roomName,
              derivedName,
            });
            roomName = derivedName;
          }
        }
      }
      let meetingToken = null;
      let roomCreatedAt = sessionData.sessionMetadata?.roomCreatedAt || null;

      if (roomUrl) {
        console.log("♻️ Using precreated Daily room:", {
          roomName,
          roomUrl,
          hasToken: !!meetingToken,
        });
        if (!roomName) {
          roomName = getRoomNameFromUrl(roomUrl);
        }
        if (roomName) {
          // Skip Daily API validation if room was created recently (< 60s)
          const roomAgeMs = roomCreatedAt ? Date.now() - roomCreatedAt : Infinity;
          if (roomAgeMs > PRECREATED_ROOM_VALIDATION_WINDOW_MS) {
            const existingRoom = await getDailyRoom(roomName);
            if (!existingRoom) {
              console.warn(
                "⚠️ Precreated room not found in Daily, recreating room",
              );
              roomUrl = null;
              roomName = null;
              roomCreatedAt = null;
            }
          } else {
            console.log("⚡ Skipping room validation - room is fresh (" + roomAgeMs + "ms old)");
          }
        } else {
          roomUrl = null;
          roomCreatedAt = null;
        }
      }

      let studentMeetingToken = null;

      if (roomUrl && roomName) {
        // Create tutor and student tokens in parallel
        try {
          const studentName =
            sessionData.studentInfo?.name ||
            studentData.display_name ||
            "Caller";
          const [tutorToken, studentToken] = await Promise.all([
            createMeetingToken({
              roomName,
              expSeconds: 3600,
              isOwner: false,
              userId: tutorId,
              userName: tutorData.display_name || "Partner",
            }),
            createMeetingToken({
              roomName,
              expSeconds: 3600,
              isOwner: true,
              userId: requesterId,
              userName: studentName,
            }),
          ]);
          meetingToken = tutorToken;
          studentMeetingToken = studentToken;
        } catch (tokenError) {
          console.error(
            "❌ Failed to create meeting tokens for precreated room:",
            tokenError.message,
          );
        }
        if (!meetingToken) {
          console.error(
            "⚠️ Precreated room has no valid meeting token, recreating room",
          );
          roomUrl = null;
          roomName = null;
          roomCreatedAt = null;
          studentMeetingToken = null;
        }
      }

      if (!roomUrl) {
        try {
          const studentName =
            sessionData.studentInfo?.name ||
            studentData.display_name ||
            "Caller";
          const dailyRoom = await createDailyRoom({
            language: sessionData.language,
            studentId: requesterId,
            tutorId,
            studentName,
            tutorName: tutorData.display_name || "Partner",
            expSeconds: 3600,
          });
          roomUrl = dailyRoom.url;
          roomName = dailyRoom.name;
          roomCreatedAt = Date.now();

          // Create tutor and student tokens in parallel
          const [tutorToken, studentToken] = await Promise.all([
            createMeetingToken({
              roomName,
              expSeconds: 3600,
              isOwner: false,
              userId: tutorId,
              userName: tutorData.display_name || "Partner",
            }),
            createMeetingToken({
              roomName,
              expSeconds: 3600,
              isOwner: true,
              userId: requesterId,
              userName: studentName,
            }),
          ]);
          meetingToken = tutorToken;
          studentMeetingToken = studentToken;
        } catch (roomError) {
          console.error("❌ Failed to create Daily room:", roomError);
          throw new functions.https.HttpsError(
            "internal",
            "Failed to create video room",
          );
        }
      }

      if (!meetingToken) {
        console.error("❌ Daily meeting token creation failed");
        throw new functions.https.HttpsError(
          "internal",
          "Failed to create meeting token",
        );
      }

      // === 6. ОБНОВЛЕНИЕ СЕССИИ В ТРАНЗАКЦИИ ===
      console.log("🔄 Updating session and user statuses in transaction...");
      const activePolicyUpdate =
        buildAcceptCallPolicyUpdateFields(sessionData);
      const txnResult = await admin
        .firestore()
        .runTransaction(async (transaction) => {
          const freshSnap = await transaction.get(sessionRef);
          if (!freshSnap.exists) {
            throw new functions.https.HttpsError(
              "not-found",
              "Video session not found",
            );
          }
          const fresh = freshSnap.data();
          if (
            fresh.status !== "searching" ||
            fresh.currentTutorId !== tutorId
          ) {
            if (
              ["active", "connecting"].includes(fresh.status) &&
              fresh.tutorId === tutorId &&
              fresh.dailyRoomUrl
            ) {
              return { alreadyAccepted: true, session: fresh };
            }
            throw new functions.https.HttpsError(
              "invalid-argument",
              "Session is already active",
            );
          }

          // Обновляем сессию - добавляем данные для активной сессии
          const sessionUpdate = {
            // Обновляем основные поля
            tutorId: tutorId,
            status: "active",
            acceptedAt: admin.firestore.FieldValue.serverTimestamp(),

            // Добавляем данные Daily.co
            dailyRoomUrl: roomUrl,
            dailyRoomName: roomName,
            expiresAt: activePolicyUpdate.sessionUpdateFields.expiresAt,
            acceptingTutorId: admin.firestore.FieldValue.delete(),
            acceptingAt: admin.firestore.FieldValue.delete(),

            // Добавляем информацию о преподавателе
            tutorInfo: {
              name: tutorData.display_name || "Partner",
              photo: tutorData.photo_url || null,
            },
            participantIds: [requesterId, tutorId].sort(),

            // Очищаем поля поиска (уже не нужны)
            currentTutorId: admin.firestore.FieldValue.delete(),
            tutorNavigationTriggered: false,
            studentNavigationTriggered: false,
            "sessionMetadata.roomCreatedAt": roomCreatedAt || Date.now(),
            "matchContext.acceptedResponderId": tutorId,
            "matchContext.acceptedResponderRole": normalizeRole(tutorData.role),
            "matchContext.acceptedResponderInfo": buildSessionUserInfo(
              tutorData,
              "Partner",
            ),
          };
          if (activePolicyUpdate.sessionUpdateFields.sessionPolicy) {
            sessionUpdate.sessionPolicy =
              activePolicyUpdate.sessionUpdateFields.sessionPolicy;
          }

          // Store student meeting token in session for faster student join
          if (studentMeetingToken) {
            sessionUpdate.studentMeetingToken = studentMeetingToken;
          }

          transaction.update(sessionRef, sessionUpdate);

          // Обновляем статус преподавателя
          transaction.update(
            admin.firestore().collection("users").doc(tutorId),
            {
              isInCall: true,
              currentSessionId: sessionId,
            },
          );

          console.log("✅ Transaction completed successfully");
          return { alreadyAccepted: false };
        });

      if (txnResult?.alreadyAccepted) {
        console.log(
          "ℹ️ Session already active for this tutor (txn), returning existing room",
        );
        const existing = txnResult.session || {};
        const existingRoomUrl = existing.dailyRoomUrl;
        const existingRoomName =
          existing.dailyRoomName || getRoomNameFromUrl(existingRoomUrl);
        let existingMeetingToken = null;
        if (existingRoomName) {
          try {
            existingMeetingToken = await createMeetingToken({
              roomName: existingRoomName,
              expSeconds: 3600,
              isOwner: false,
              userId: tutorId,
              userName: tutorData.display_name || "Partner",
            });
          } catch (tokenError) {
            console.error(
              "⚠️ Failed to create meeting token for existing room:",
              tokenError.message,
            );
          }
        }

        return {
          status: "connected",
          sessionId: sessionId,
          roomUrl: existingRoomUrl,
          roomName: existingRoomName || null,
          meetingToken: existingMeetingToken || null,
          studentInfo: existing.studentInfo || null,
          sessionData: buildAcceptCallResponseSessionData(existing),
        };
      }

      // 🔔 === ОТПРАВКА PUSH + ОБНОВЛЕНИЕ УВЕДОМЛЕНИЙ (ПАРАЛЛЕЛЬНО) ===
      console.log("📲 Sending push + updating notifications in parallel...");
      await Promise.all([
        sendVoipPushToStudent(requesterId, {
          sessionId: sessionId,
          callerName: tutorData.display_name || "Собеседник",
          callerId: tutorId,
          callerPhoto: tutorData.photo_url || null,
          roomUrl: roomUrl,
          meetingToken: studentMeetingToken || "",
          roomName: roomName || "",
        }).catch((pushError) => {
          console.error(
            "⚠️ Failed to send VoIP push (non-critical):",
            pushError.message,
          );
        }),
        updateNotificationStatus(sessionId, tutorId, "accepted"),
        cancelOtherNotifications(sessionId, tutorId),
      ]);
      console.log("✅ Push + notifications completed");

      // === 8. ПОДГОТОВКА ОТВЕТА ===
      console.log("🎉 Call accepted successfully, preparing response...");

      const response = {
        status: "connected",
        sessionId: sessionId,
        roomUrl: roomUrl,
        roomName: roomName,
        meetingToken: meetingToken,
        studentInfo: {
          name:
            sessionData.studentInfo?.name ||
            studentData.display_name ||
            "Caller",
          photo:
            sessionData.studentInfo?.photo || studentData.photo_url || null,
        },
        sessionData: buildAcceptCallResponseSessionData({
          language: sessionData.language,
          startedAt: null,
          sessionPolicy: activePolicyUpdate.policyState.sessionPolicy,
        }),
      };

      console.log("📤 Returning response:", {
        status: response.status,
        sessionId: response.sessionId,
        hasRoomUrl: !!response.roomUrl,
        hasToken: !!response.meetingToken,
        studentName: response.studentInfo.name,
      });

      return response;
    } catch (error) {
      console.error("❌ Error in acceptCall function:", error);

      if (lockAcquired) {
        try {
          await admin.firestore().runTransaction(async (transaction) => {
            const snap = await transaction.get(sessionRef);
            if (!snap.exists) return;
            const data = snap.data();
            if (data.acceptingTutorId === tutorId) {
              transaction.update(sessionRef, {
                acceptingTutorId: admin.firestore.FieldValue.delete(),
                acceptingAt: admin.firestore.FieldValue.delete(),
              });
            }
          });
        } catch (lockError) {
          console.error("⚠️ Failed to release accept lock:", lockError.message);
        }
      }

      if (error.code && error.message) {
        throw error;
      }

      console.error("❌ Unexpected error details:", {
        message: error.message,
        stack: error.stack,
        name: error.name,
      });

      throw new functions.https.HttpsError(
        "internal",
        `Internal server error: ${error.message}`,
      );
    }
  });

// === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===

// 🔔 ОТПРАВКА VOIP PUSH NOTIFICATION (НОВАЯ ФУНКЦИЯ)
async function sendVoipPushToStudent(studentId, callData) {
  try {
    console.log("📲 Preparing VoIP push for student:", studentId);

    // Получаем данные студента из Firestore
    const studentDoc = await admin
      .firestore()
      .collection("users")
      .doc(studentId)
      .get();

    if (!studentDoc.exists) {
      console.log("⚠️ Student document not found:", studentId);
      return;
    }

    const studentData = studentDoc.data();
    const bundleId = process.env.IOS_BUNDLE_ID || "com.appwave.smalltalk";
    const voipTopic =
      process.env.IOS_VOIP_TOPIC ||
      (bundleId.endsWith(".voip") ? bundleId : `${bundleId}.voip`);
    const voipPushToken = studentData.voipPushToken;
    const fcmToken = studentData.voipToken;

    if (!voipPushToken && !fcmToken) {
      console.log("⚠️ Student has no push tokens saved.");
      console.log("⚠️ Student data keys:", Object.keys(studentData));
      return;
    }

    if (voipPushToken) {
      const apnsPayload = {
        aps: { "content-available": 1 },
        type: "incoming_call",
        sessionId: callData.sessionId,
        callerName: callData.callerName,
        callerId: callData.callerId,
        callerPhoto: callData.callerPhoto || "",
        roomUrl: callData.roomUrl || "",
        meetingToken: callData.meetingToken || "",
        roomName: callData.roomName || "",
      };

      try {
        await sendApnsVoip({
          deviceToken: voipPushToken,
          topic: voipTopic,
          payload: apnsPayload,
        });
        console.log("✅ APNs VoIP push sent successfully");
        return;
      } catch (error) {
        console.error("❌ Error sending APNs VoIP push:", error.message);
      }
    }

    if (!fcmToken) {
      console.log("⚠️ No FCM token available for fallback");
      return;
    }

    console.log("📱 FCM token found:", fcmToken.substring(0, 20) + "...");
    console.log("📦 Using apns-topic for FCM fallback:", bundleId);

    const message = {
      token: fcmToken,
      data: {
        type: "incoming_call",
        sessionId: callData.sessionId,
        callerName: callData.callerName,
        callerId: callData.callerId,
        callerPhoto: callData.callerPhoto || "",
        roomUrl: callData.roomUrl || "",
        meetingToken: callData.meetingToken || "",
        roomName: callData.roomName || "",
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
          "apns-topic": bundleId,
        },
        payload: {
          aps: {
            "content-available": 1,
            alert: {
              title: "Входящий звонок",
              body: `${callData.callerName} звонит вам`,
            },
            sound: "default",
          },
        },
      },
      android: {
        priority: "high",
      },
    };

    console.log("📤 Sending VoIP push via FCM...");

    const response = await admin.messaging().send(message);

    console.log("✅ FCM push sent successfully. Message ID:", response);

    return response;
  } catch (error) {
    console.error("❌ Error sending VoIP push:", error);

    // Логируем детали ошибки
    if (error.code) {
      console.error("❌ Error code:", error.code);
    }
    if (error.message) {
      console.error("❌ Error message:", error.message);
    }
    if (error.errorInfo) {
      console.error("❌ Error info:", JSON.stringify(error.errorInfo));
    }

    // Бросаем ошибку дальше, чтобы она была залогирована
    throw error;
  }
}

// Daily room helpers moved to daily_room.js

// ОБНОВЛЕНИЕ СТАТУСА УВЕДОМЛЕНИЯ
async function updateNotificationStatus(sessionId, tutorId, status) {
  try {
    console.log(`🔔 Updating notification status to ${status}...`);

    const notificationsQuery = await admin
      .firestore()
      .collection("notifications")
      .where("sessionId", "==", sessionId)
      .where("recipientId", "==", tutorId)
      .where("status", "==", "sent")
      .get();

    if (!notificationsQuery.empty) {
      const batch = admin.firestore().batch();

      notificationsQuery.forEach((doc) => {
        batch.update(doc.ref, {
          status: status,
          [`${status}At`]: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();
      console.log(
        `✅ Updated ${notificationsQuery.size} notification(s) to ${status}`,
      );
    } else {
      console.log("📭 No notifications found to update");
    }
  } catch (error) {
    console.error("❌ Error updating notification status:", error);
  }
}

// ОТМЕНА ДРУГИХ УВЕДОМЛЕНИЙ
async function cancelOtherNotifications(sessionId, acceptedTutorId) {
  try {
    console.log("🚫 Canceling other active notifications...");

    const otherNotificationsQuery = await admin
      .firestore()
      .collection("notifications")
      .where("sessionId", "==", sessionId)
      .where("status", "==", "sent")
      .get();

    if (!otherNotificationsQuery.empty) {
      const batch = admin.firestore().batch();
      let canceledCount = 0;

      otherNotificationsQuery.forEach((doc) => {
        const notificationData = doc.data();
        if (notificationData.recipientId !== acceptedTutorId) {
          batch.update(doc.ref, {
            status: "cancelled",
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
            cancelReason: "call_accepted_by_other_tutor",
          });
          canceledCount++;
        }
      });

      if (canceledCount > 0) {
        await batch.commit();
        console.log(`✅ Canceled ${canceledCount} other notification(s)`);
      }
    }
  } catch (error) {
    console.error("❌ Error canceling other notifications:", error);
  }
}

exports.__private__ = {
  buildAcceptCallPolicyUpdateFields,
  buildAcceptCallResponseSessionData,
};
