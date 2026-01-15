const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { sendApnsVoip } = require("./apns_voip");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];

/*
ОБНОВЛЁННАЯ ФУНКЦИЯ: createVideoSession
Теперь учитывает предпочтения студента по нативному языку и локации преподавателя
*/

exports.createVideoSession = functions
  .runWith({ secrets: apnsSecrets })
  .https.onCall(async (data, context) => {
    console.log("📹 Creating video session with filters...");

    try {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated",
        );
      }

      const studentId = context.auth.uid;

      // Получаем параметры из вызова функции
      const { language, preferredNativeLanguage, preferredCountry } = data;

      console.log("👨‍🎓 Student ID:", studentId);
      console.log("🌍 Requested language:", language);
      console.log("🎯 Filters:");
      console.log(
        "   - Preferred native language:",
        preferredNativeLanguage || "Not specified",
      );
      console.log(
        "   - Preferred country:",
        preferredCountry || "Not specified",
      );

      if (!language) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Language is required",
        );
      }

      // Получаем данные студента
      const studentDoc = await admin
        .firestore()
        .collection("users")
        .doc(studentId)
        .get();
      if (!studentDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Student not found");
      }

      const studentData = studentDoc.data();
      if (studentData.role !== "student") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only students can create video sessions",
        );
      }

      const normalizedLanguage = String(language).trim().toLowerCase();
      const tutorRoles = ["tutor", "native_speaker"];

      // Базовый запрос: ищем преподавателей по роли (фильтруем языки в коде)
      console.log("🔍 Searching for tutors with roles:", tutorRoles.join(", "));

      const tutorBaseQuery = admin
        .firestore()
        .collection("users")
        .where("role", "in", tutorRoles);

      let tutorsQuery;
      try {
        tutorsQuery = await tutorBaseQuery.get();
      } catch (queryError) {
        console.error(
          "❌ Tutor query failed, fallback to all users:",
          queryError.message,
        );
        tutorsQuery = await admin.firestore().collection("users").get();
      }

      if (tutorsQuery.empty) {
        console.log("❌ No tutors found for roles:", tutorRoles.join(", "));
        return {
          status: "no_tutors_available",
          message: "No tutors available for this language right now",
        };
      }

      console.log(`📊 Found ${tutorsQuery.size} potential tutors`);

      // Получаем черные списки для фильтрации
      const studentBlockedUsers = studentData.blockedUsers || [];
      const studentBlockedIds = studentBlockedUsers
        .map((ref) => {
          // Если это DocumentReference, извлекаем ID
          if (ref && ref.id) return ref.id;
          // Если это строка, возвращаем как есть
          if (typeof ref === "string") return ref;
          return null;
        })
        .filter((id) => id !== null);

      console.log("🚫 Student blocked users:", studentBlockedIds);

      // Фильтруем преподавателей по всем критериям
      const availableTutors = [];
      const tutorDetails = {}; // Для отладки и приоритизации

      for (const doc of tutorsQuery.docs) {
        const tutorData = doc.data();
        const tutorId = doc.id;

        // === ПРОВЕРКА ЧЕРНЫХ СПИСКОВ (КРИТИЧНО!) ===

        // 1. Проверяем, не заблокировал ли студент этого преподавателя
        if (studentBlockedIds.includes(tutorId)) {
          console.log(`🚫 Tutor ${tutorId} is blocked by student - SKIP`);
          continue;
        }

        // 2. Проверяем, не заблокировал ли преподаватель этого студента
        const tutorBlockedUsers = tutorData.blockedUsers || [];
        const tutorBlockedIds = tutorBlockedUsers
          .map((ref) => {
            if (ref && ref.id) return ref.id;
            if (typeof ref === "string") return ref;
            return null;
          })
          .filter((id) => id !== null);

        if (tutorBlockedIds.includes(studentId)) {
          console.log(`🚫 Student is blocked by tutor ${tutorId} - SKIP`);
          continue;
        }

        console.log(`✅ Tutor ${tutorId} passed blocklist check`);

        // === БАЗОВАЯ ПРОВЕРКА ДОСТУПНОСТИ ===

        if (
          tutorData.availableAfter &&
          tutorData.availableAfter.toDate() > new Date()
        ) {
          console.log(
            `⏭️ Tutor ${tutorId} not available yet (availableAfter in future)`,
          );
          continue;
        }

        const availabilityToday = tutorData.availabilityToday;
        const isAvailable =
          tutorData.isAvailable !== undefined
            ? tutorData.isAvailable
            : (availabilityToday?.enabled ?? true);

        if (!isAvailable || tutorData.isInCall) {
          console.log(`⏭️ Tutor ${tutorId} is not available or in call`);
          continue;
        }

        const instructionLang = tutorData.language_instruction_NS;
        const instructionCode =
          instructionLang && typeof instructionLang === "object"
            ? String(instructionLang.code || "")
                .trim()
                .toLowerCase()
            : "";

        if (!instructionCode) {
          console.log(
            `⚠️ Tutor ${tutorId} has no language_instruction_NS.code`,
          );
          continue;
        }

        if (instructionCode !== normalizedLanguage) {
          console.log(
            `⏭️ Tutor ${tutorId} doesn't match instruction code: ${instructionCode}`,
          );
          continue;
        }

        // Проверяем соответствие нативному языку (если указан)
        let nativeLanguageMatch = false;
        if (preferredNativeLanguage) {
          // Получаем код нативного языка преподавателя
          const tutorNativeLanguage = tutorData.native_language_NS;

          if (tutorNativeLanguage && typeof tutorNativeLanguage === "object") {
            const nativeLanguageCode = String(tutorNativeLanguage.code || "")
              .trim()
              .toLowerCase();
            const preferredNative = String(preferredNativeLanguage)
              .trim()
              .toLowerCase();
            nativeLanguageMatch = nativeLanguageCode === preferredNative;

            console.log(
              `🔤 Tutor ${tutorId} native language: ${nativeLanguageCode} (match: ${nativeLanguageMatch})`,
            );
          } else {
            console.log(`⚠️ Tutor ${tutorId} has no native_language_NS set`);
          }
        } else {
          // Если студент не указал предпочтение, любой язык подходит
          nativeLanguageMatch = true;
        }

        // Проверяем соответствие локации/стране (если указана)
        let countryMatch = false;
        if (preferredCountry) {
          // Получаем код страны преподавателя
          const tutorCountry = tutorData.Country_NS;

          if (tutorCountry && typeof tutorCountry === "object") {
            const countryCode = tutorCountry.code;
            countryMatch = countryCode === preferredCountry;

            console.log(
              `🌍 Tutor ${tutorId} country: ${countryCode} (match: ${countryMatch})`,
            );
          } else {
            console.log(`⚠️ Tutor ${tutorId} has no Country_NS set`);
          }
        } else {
          // Если студент не указал предпочтение, любая страна подходит
          countryMatch = true;
        }

        // Если оба фильтра совпали (или не были указаны), добавляем преподавателя
        if (nativeLanguageMatch && countryMatch) {
          availableTutors.push(tutorId);

          // Сохраняем детали для потенциальной приоритизации
          tutorDetails[tutorId] = {
            nativeLanguage: tutorData.native_language_NS?.code || "unknown",
            country: tutorData.Country_NS?.code || "unknown",
            rating: tutorData.rating || 0,
            priorityScore: tutorData.priorityScore || 50, // из ТЗ: 100-балльная система
            name: tutorData.display_name || "Tutor",
          };

          console.log(`✅ Tutor ${tutorId} matches all criteria`);
        } else {
          console.log(
            `⏭️ Tutor ${tutorId} doesn't match preferences (lang: ${nativeLanguageMatch}, country: ${countryMatch})`,
          );
        }
      }

      if (availableTutors.length === 0) {
        console.log("❌ No tutors match the student preferences");
        return {
          status: "no_tutors_available",
          message:
            "No tutors available matching your preferences. Try adjusting your filters.",
        };
      }

      console.log(
        `✅ Found ${availableTutors.length} tutors matching all criteria`,
      );
      console.log("👥 Available tutors:", availableTutors);

      // ОПЦИОНАЛЬНО: Сортируем преподавателей по приоритету (из ТЗ)
      // Чем ниже priorityScore, тем выше в очереди
      availableTutors.sort((a, b) => {
        const scoreA = tutorDetails[a].priorityScore;
        const scoreB = tutorDetails[b].priorityScore;
        return scoreA - scoreB; // по возрастанию (меньше = выше приоритет)
      });

      console.log(
        "📊 Tutors sorted by priority:",
        availableTutors.map(
          (id) => `${id} (score: ${tutorDetails[id].priorityScore})`,
        ),
      );

      // Создаем videoSession
      const expiresAt = new Date();
      expiresAt.setMinutes(expiresAt.getMinutes() + 5);

      const sessionData = {
        studentId,
        tutorId: null,
        language,
        status: "searching",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),

        // Предпочтения студента (для логов и аналитики)
        studentPreferences: {
          nativeLanguage: preferredNativeLanguage,
          country: preferredCountry,
        },

        // Для поиска
        currentTutorId: null,
        triedTutors: [],
        availableTutors, // Уже отсортированный массив
        studentInfo: {
          name: studentData.display_name || "Student",
          photo: studentData.photo_url || null,
        },

        // Активная сессия (пока null)
        dailyRoomUrl: null,
        dailyRoomName: null,
        meetingToken: null,
        acceptedAt: null,
        startedAt: null,
        endedAt: null,
        duration: null,
        tutorInfo: null,

        // Метаданные для отладки
        sessionMetadata: {
          totalTutorsFound: tutorsQuery.size,
          filteredTutorsCount: availableTutors.length,
          studentBlockedCount: studentBlockedIds.length,
          filtersApplied: {
            language: language,
            nativeLanguage: preferredNativeLanguage || "any",
            country: preferredCountry || "any",
            blocklistEnabled: true,
          },
        },
      };

      const sessionRef = await admin
        .firestore()
        .collection("videoSessions")
        .add(sessionData);
      console.log("✅ Video session created:", sessionRef.id);

      // Уведомляем первого преподавателя
      await sendNotificationToNextTutor(sessionRef.id, sessionData);

      return {
        status: "searching",
        sessionId: sessionRef.id,
        message: "Searching for available tutor...",
        matchedTutors: availableTutors.length,
      };
    } catch (error) {
      console.error("❌ Error creating video session:", error);
      if (error.code) throw error;
      throw new functions.https.HttpsError("internal", error.message);
    }
  });

// 🔔 ОТПРАВКА VOIP PUSH ПРЕПОДАВАТЕЛЮ
async function sendVoipPushToTutor(tutorId, callData) {
  try {
    console.log("📲 Preparing VoIP push for tutor:", tutorId);

    const tutorDoc = await admin
      .firestore()
      .collection("users")
      .doc(tutorId)
      .get();

    if (!tutorDoc.exists) {
      console.log("⚠️ Tutor document not found:", tutorId);
      return;
    }

    const tutorData = tutorDoc.data();
    const bundleId = process.env.IOS_BUNDLE_ID || "com.appwave.smalltalk";
    const voipTopic =
      process.env.IOS_VOIP_TOPIC ||
      (bundleId.endsWith(".voip") ? bundleId : `${bundleId}.voip`);
    const voipPushToken = tutorData.voipPushToken;
    const fcmToken = tutorData.voipToken;

    if (!voipPushToken && !fcmToken) {
      console.log("⚠️ Tutor has no push tokens saved");
      return;
    }

    if (voipPushToken) {
      const apnsPayload = {
        aps: { "content-available": 1 },
        type: "incoming_call",
        sessionId: callData.sessionId,
        callerName: callData.studentName,
        callerId: callData.studentId,
        callerPhoto: callData.studentPhoto || "",
        language: callData.language || "",
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
        callerName: callData.studentName,
        callerId: callData.studentId,
        callerPhoto: callData.studentPhoto || "",
        language: callData.language || "",
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
              body: `${callData.studentName} хочет попрактиковать ${callData.language}`,
            },
            sound: "default",
          },
        },
      },
      android: {
        priority: "high",
      },
    };

    const response = await admin.messaging().send(message);
    console.log("✅ FCM push sent successfully. Message ID:", response);

    return response;
  } catch (error) {
    console.error("❌ Error sending VoIP push to tutor:", error);
    return null;
  }
}

async function sendNotificationToNextTutor(sessionId, sessionData) {
  try {
    const availableTutors = sessionData.availableTutors || [];
    const triedTutors = sessionData.triedTutors || [];

    const nextTutor = availableTutors.find(
      (tutorId) => !triedTutors.includes(tutorId),
    );
    if (!nextTutor) {
      await admin
        .firestore()
        .collection("videoSessions")
        .doc(sessionId)
        .update({
          status: "no_tutors_available",
        });
      return;
    }

    // Обновляем текущего преподавателя
    await admin.firestore().collection("videoSessions").doc(sessionId).update({
      currentTutorId: nextTutor,
    });

    // Создаём уведомление в Firestore
    const expiresAt = new Date();
    expiresAt.setSeconds(expiresAt.getSeconds() + 45);

    const notificationData = {
      recipientId: nextTutor,
      sessionId,
      type: "incoming_call",
      status: "sent",
      title: "Входящий звонок",
      message: `${sessionData.studentInfo.name} хочет попрактиковать ${sessionData.language}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      studentInfo: sessionData.studentInfo,
    };

    await admin.firestore().collection("notifications").add(notificationData);
    console.log("✅ Firestore notification created for tutor:", nextTutor);

    // 🔔 Отправляем VoIP push преподавателю
    console.log("📲 Sending VoIP push to tutor...");
    try {
      await sendVoipPushToTutor(nextTutor, {
        sessionId: sessionId,
        studentName: sessionData.studentInfo.name,
        studentId: sessionData.studentId,
        studentPhoto: sessionData.studentInfo.photo,
        language: sessionData.language,
      });
      console.log("✅ VoIP push sent to tutor");
    } catch (pushError) {
      console.error(
        "⚠️ Failed to send VoIP push (non-critical):",
        pushError.message,
      );
    }
  } catch (error) {
    console.error("❌ Error sending notification:", error);
  }
}
