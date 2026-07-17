const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { sendApnsVoip } = require("./apns_voip");
const {
  createDailyRoom,
  createMeetingToken,
} = require("./daily_room");
const { evaluateTutorAvailabilityWindow } = require("./availability");
const { buildSessionParticipantIds } = require("./session_participants");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const matchDebugSampleRateRaw = Number.parseFloat(
  process.env.MATCH_DEBUG_SAMPLE_RATE || "0.1",
);
const MATCH_DEBUG_SAMPLE_RATE = Number.isFinite(matchDebugSampleRateRaw)
  ? Math.min(Math.max(matchDebugSampleRateRaw, 0), 1)
  : 0.1;
const MAX_TUTOR_DEBUG_SAMPLES = 8;

/*
ОБНОВЛЁННАЯ ФУНКЦИЯ: createVideoSession
Теперь учитывает предпочтения студента по нативному языку и локации преподавателя
*/

exports.createVideoSession = functions
  .runWith({ secrets: [...apnsSecrets, ...dailySecrets] })
  .https.onCall(async (data, context) => {
    console.log("📹 createVideoSession started");

    try {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated",
        );
      }

      const studentId = context.auth.uid;

      // Получаем параметры из вызова функции
      const {
        language,
        preferredNativeLanguage,
        preferredCountry,
        directTutorId: rawDirectTutorId,
      } = data;

      if (!language) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Language is required",
        );
      }

      const normalizedLanguage = String(language).trim().toLowerCase();
      const directTutorId =
        typeof rawDirectTutorId === "string" ? rawDirectTutorId.trim() : "";
      const isDirectTutorCall = directTutorId.length > 0;
      const tutorRoles = ["tutor", "native_speaker"];
      const shouldSampleTutorDebug = Math.random() < MATCH_DEBUG_SAMPLE_RATE;
      const tutorDebugSamples = [];
      const tutorFilterStats = {
        totalCandidates: 0,
        blockedByStudent: 0,
        blockedByTutor: 0,
        availableAfterInFuture: 0,
        unavailableOrInCall: 0,
        missingInstructionCode: 0,
        instructionLanguageMismatch: 0,
        missingNativeLanguage: 0,
        nativeLanguageMismatch: 0,
        missingCountry: 0,
        countryMismatch: 0,
        matched: 0,
      };
      const addTutorSample = (payload) => {
        if (!shouldSampleTutorDebug) return;
        if (tutorDebugSamples.length >= MAX_TUTOR_DEBUG_SAMPLES) return;
        tutorDebugSamples.push(payload);
      };

      console.log("📹 createVideoSession params", {
        studentId,
        requestedLanguage: normalizedLanguage,
        matchMode: isDirectTutorCall ? "direct" : "filtered",
        directTutorId: isDirectTutorCall ? directTutorId : null,
        preferredNativeLanguage: preferredNativeLanguage || "any",
        preferredCountry: preferredCountry || "any",
      });

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

      const extractBlockedIds = (blockedUsers = []) =>
        blockedUsers
        .map((ref) => {
          if (ref && ref.id) return ref.id;
          if (typeof ref === "string") return ref;
          return null;
        })
        .filter((id) => id !== null);

      const studentBlockedUsers = studentData.blockedUsers || [];
      const studentBlockedIds = extractBlockedIds(studentBlockedUsers);

      const availableTutors = [];
      const tutorDetails = {};
      let tutorsQuery = null;
      let directTutorInfo = null;

      if (isDirectTutorCall) {
        const directTutorDoc = await admin
          .firestore()
          .collection("users")
          .doc(directTutorId)
          .get();

        tutorFilterStats.totalCandidates = 1;

        if (!directTutorDoc.exists) {
          console.log("📹 createVideoSession direct tutor not found", {
            studentId,
            directTutorId,
          });
          return {
            status: "no_tutors_available",
            message: "Selected tutor is not available right now",
          };
        }

        const tutorData = directTutorDoc.data() || {};
        if (!tutorRoles.includes(tutorData.role)) {
          console.log("📹 createVideoSession direct tutor has invalid role", {
            studentId,
            directTutorId,
            role: tutorData.role || null,
          });
          return {
            status: "no_tutors_available",
            message: "Selected tutor is not available right now",
          };
        }

        if (studentBlockedIds.includes(directTutorId)) {
          tutorFilterStats.blockedByStudent += 1;
          addTutorSample({
            tutorId: directTutorId,
            outcome: "skip",
            reason: "blocked_by_student",
          });
          return {
            status: "no_tutors_available",
            message: "Selected tutor is not available right now",
          };
        }

        const tutorBlockedIds = extractBlockedIds(tutorData.blockedUsers || []);
        if (tutorBlockedIds.includes(studentId)) {
          tutorFilterStats.blockedByTutor += 1;
          addTutorSample({
            tutorId: directTutorId,
            outcome: "skip",
            reason: "blocked_by_tutor",
          });
          return {
            status: "no_tutors_available",
            message: "Selected tutor is not available right now",
          };
        }

        if (
          tutorData.availableAfter &&
          tutorData.availableAfter.toDate() > new Date()
        ) {
          tutorFilterStats.availableAfterInFuture += 1;
          addTutorSample({
            tutorId: directTutorId,
            outcome: "skip",
            reason: "available_after_in_future",
          });
          return {
            status: "no_tutors_available",
            message: "Selected tutor is not available right now",
          };
        }

        const availabilityCheck = evaluateTutorAvailabilityWindow(tutorData);
        const isAvailable = availabilityCheck.isAvailable;

        if (!isAvailable || tutorData.isInCall) {
          tutorFilterStats.unavailableOrInCall += 1;
          addTutorSample({
            tutorId: directTutorId,
            outcome: "skip",
            reason: "unavailable_or_in_call",
            isAvailable: !!isAvailable,
            isInCall: !!tutorData.isInCall,
            availabilityReason: availabilityCheck.reason,
            tutorLocalTime: availabilityCheck.localTime || null,
            timezoneOffsetMinutes: availabilityCheck.timezoneOffsetMinutes ?? null,
          });
          return {
            status: "no_tutors_available",
            message: "Selected tutor is not available right now",
          };
        }

        availableTutors.push(directTutorId);
        tutorFilterStats.matched = 1;
        tutorDetails[directTutorId] = {
          nativeLanguage: tutorData.native_language_NS?.code || "unknown",
          country: tutorData.Country_NS?.code || "unknown",
          rating: tutorData.rating || 0,
          priorityScore: tutorData.priorityScore || 50,
          name: tutorData.display_name || "Tutor",
        };
        directTutorInfo = {
          name: tutorData.display_name || "Tutor",
          photo: tutorData.photo_url || null,
        };
        addTutorSample({
          tutorId: directTutorId,
          outcome: "match",
          direct: true,
        });
      } else {
        const tutorBaseQuery = admin
          .firestore()
          .collection("users")
          .where("role", "in", tutorRoles);

        tutorsQuery = await tutorBaseQuery.get().catch((queryError) => {
          console.error(
            "❌ Tutor query failed (no collection-scan fallback):",
            queryError.message,
          );
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Tutor query failed. Ensure required Firestore indexes are deployed.",
          );
        });

        if (tutorsQuery.empty) {
          console.log("📹 createVideoSession no tutors for roles", {
            roles: tutorRoles,
          });
          return {
            status: "no_tutors_available",
            message: "No tutors available for this language right now",
          };
        }

        for (const doc of tutorsQuery.docs) {
          tutorFilterStats.totalCandidates += 1;
          const tutorData = doc.data();
          const tutorId = doc.id;

          // === ПРОВЕРКА ЧЕРНЫХ СПИСКОВ (КРИТИЧНО!) ===

          // 1. Проверяем, не заблокировал ли студент этого преподавателя
          if (studentBlockedIds.includes(tutorId)) {
            tutorFilterStats.blockedByStudent += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "blocked_by_student",
            });
            continue;
          }

          // 2. Проверяем, не заблокировал ли преподаватель этого студента
          const tutorBlockedIds = extractBlockedIds(tutorData.blockedUsers || []);

          if (tutorBlockedIds.includes(studentId)) {
            tutorFilterStats.blockedByTutor += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "blocked_by_tutor",
            });
            continue;
          }

          // === БАЗОВАЯ ПРОВЕРКА ДОСТУПНОСТИ ===

          if (
            tutorData.availableAfter &&
            tutorData.availableAfter.toDate() > new Date()
          ) {
            tutorFilterStats.availableAfterInFuture += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "available_after_in_future",
            });
            continue;
          }

          const availabilityCheck = evaluateTutorAvailabilityWindow(tutorData);
          const isAvailable = availabilityCheck.isAvailable;

          if (!isAvailable || tutorData.isInCall) {
            tutorFilterStats.unavailableOrInCall += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "unavailable_or_in_call",
              isAvailable: !!isAvailable,
              isInCall: !!tutorData.isInCall,
              availabilityReason: availabilityCheck.reason,
              tutorLocalTime: availabilityCheck.localTime || null,
              timezoneOffsetMinutes:
                availabilityCheck.timezoneOffsetMinutes ?? null,
            });
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
            tutorFilterStats.missingInstructionCode += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "missing_instruction_language_code",
            });
            continue;
          }

          if (instructionCode !== normalizedLanguage) {
            tutorFilterStats.instructionLanguageMismatch += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "instruction_language_mismatch",
              instructionCode,
            });
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
              if (!nativeLanguageMatch) {
                tutorFilterStats.nativeLanguageMismatch += 1;
                addTutorSample({
                  tutorId,
                  outcome: "skip",
                  reason: "native_language_mismatch",
                  tutorNativeLanguage: nativeLanguageCode,
                });
              }
            } else {
              tutorFilterStats.missingNativeLanguage += 1;
              addTutorSample({
                tutorId,
                outcome: "skip",
                reason: "missing_native_language",
              });
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
              if (!countryMatch) {
                tutorFilterStats.countryMismatch += 1;
                addTutorSample({
                  tutorId,
                  outcome: "skip",
                  reason: "country_mismatch",
                  tutorCountry: countryCode,
                });
              }
            } else {
              tutorFilterStats.missingCountry += 1;
              addTutorSample({
                tutorId,
                outcome: "skip",
                reason: "missing_country",
              });
            }
          } else {
            // Если студент не указал предпочтение, любая страна подходит
            countryMatch = true;
          }

          // Если оба фильтра совпали (или не были указаны), добавляем преподавателя
          if (nativeLanguageMatch && countryMatch) {
            availableTutors.push(tutorId);
            tutorFilterStats.matched += 1;

            // Сохраняем детали для потенциальной приоритизации
            tutorDetails[tutorId] = {
              nativeLanguage: tutorData.native_language_NS?.code || "unknown",
              country: tutorData.Country_NS?.code || "unknown",
              rating: tutorData.rating || 0,
              priorityScore: tutorData.priorityScore || 50,
              name: tutorData.display_name || "Tutor",
            };
            addTutorSample({
              tutorId,
              outcome: "match",
              priorityScore: tutorDetails[tutorId].priorityScore,
            });
          } else {
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "preference_mismatch",
              nativeLanguageMatch,
              countryMatch,
            });
          }
        }
      }

      const totalTutorsQueried = isDirectTutorCall ? 1 : tutorsQuery.size;
      const filteringSummary = {
        studentId,
        requestedLanguage: normalizedLanguage,
        matchMode: isDirectTutorCall ? "direct" : "filtered",
        directTutorId: isDirectTutorCall ? directTutorId : null,
        preferredNativeLanguage: isDirectTutorCall
          ? "skipped_for_direct_call"
          : (preferredNativeLanguage || "any"),
        preferredCountry: isDirectTutorCall
          ? "skipped_for_direct_call"
          : (preferredCountry || "any"),
        totalTutorsQueried,
        totalCandidatesChecked: tutorFilterStats.totalCandidates,
        matchedTutors: tutorFilterStats.matched,
        rejected: {
          blockedByStudent: tutorFilterStats.blockedByStudent,
          blockedByTutor: tutorFilterStats.blockedByTutor,
          availableAfterInFuture: tutorFilterStats.availableAfterInFuture,
          unavailableOrInCall: tutorFilterStats.unavailableOrInCall,
          missingInstructionCode: tutorFilterStats.missingInstructionCode,
          instructionLanguageMismatch:
            tutorFilterStats.instructionLanguageMismatch,
          missingNativeLanguage: tutorFilterStats.missingNativeLanguage,
          nativeLanguageMismatch: tutorFilterStats.nativeLanguageMismatch,
          missingCountry: tutorFilterStats.missingCountry,
          countryMismatch: tutorFilterStats.countryMismatch,
        },
        sampledDebugEnabled: shouldSampleTutorDebug,
      };
      if (shouldSampleTutorDebug && tutorDebugSamples.length > 0) {
        filteringSummary.sample = tutorDebugSamples;
      }
      console.log("📊 Tutor filtering summary", filteringSummary);

      if (availableTutors.length === 0) {
        console.log("📹 createVideoSession no matching tutors after filtering", {
          studentId,
          requestedLanguage: normalizedLanguage,
          matchMode: isDirectTutorCall ? "direct" : "filtered",
          directTutorId: isDirectTutorCall ? directTutorId : null,
          preferredNativeLanguage: preferredNativeLanguage || "any",
          preferredCountry: preferredCountry || "any",
        });
        return {
          status: "no_tutors_available",
          message: isDirectTutorCall
            ? "Selected tutor is not available right now"
            : "No tutors available matching your preferences. Try adjusting your filters.",
        };
      }

      if (!isDirectTutorCall) {
        availableTutors.sort((a, b) => {
          const scoreA = tutorDetails[a].priorityScore;
          const scoreB = tutorDetails[b].priorityScore;
          return scoreA - scoreB;
        });
        console.log("📊 Matched tutors after sorting", {
          count: availableTutors.length,
          topTutorPreview: availableTutors.slice(0, 3).map((id) => ({
            tutorId: id,
            priorityScore: tutorDetails[id].priorityScore,
          })),
        });
      }

      // Создаем videoSession
      const expiresAt = new Date();
      expiresAt.setMinutes(expiresAt.getMinutes() + 5);

      let precreatedRoomUrl = null;
      let precreatedRoomName = null;
      let precreatedMeetingToken = null;
      let precreatedRoomCreatedAt = null;
      let precreatedRoomOk = false;

      try {
        const dailyRoom = await createDailyRoom({
          language: normalizedLanguage,
          studentId,
          tutorId: null,
          studentName: studentData.display_name || "Student",
          tutorName: "Tutor",
          expSeconds: 15 * 60,
        });

        precreatedRoomUrl = dailyRoom.url;
        precreatedRoomName = dailyRoom.name;
        precreatedRoomCreatedAt = Date.now();
        precreatedMeetingToken = await createMeetingToken({
          roomName: dailyRoom.name,
          expSeconds: 60 * 60,
          isOwner: true,
          userId: studentId,
          userName: studentData.display_name || "Student",
        });
        precreatedRoomOk = !!(precreatedRoomUrl && precreatedMeetingToken);

        console.log("✅ Precreated Daily room for session", {
          roomName: precreatedRoomName,
          roomUrl: precreatedRoomUrl,
          hasToken: !!precreatedMeetingToken,
        });
      } catch (roomError) {
        console.error("⚠️ Failed to precreate Daily room:", roomError.message);
      }

      const sessionData = {
        studentId,
        tutorId: null,
        participantIds: buildSessionParticipantIds(studentId),
        language,
        status: "searching",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),

        // Предпочтения студента (для логов и аналитики)
        studentPreferences: {
          nativeLanguage: preferredNativeLanguage || null,
          country: preferredCountry || null,
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
        dailyRoomUrl: precreatedRoomUrl,
        dailyRoomName: precreatedRoomName,
        acceptedAt: null,
        startedAt: null,
        endedAt: null,
        duration: null,
        tutorInfo: directTutorInfo,

        // Метаданные для отладки
        sessionMetadata: {
          matchMode: isDirectTutorCall ? "direct" : "filtered",
          directTutorId: isDirectTutorCall ? directTutorId : null,
          totalTutorsFound: totalTutorsQueried,
          filteredTutorsCount: availableTutors.length,
          studentBlockedCount: studentBlockedIds.length,
          filtersApplied: {
            language: language,
            nativeLanguage: isDirectTutorCall
              ? "skipped_for_direct_call"
              : (preferredNativeLanguage || "any"),
            country: isDirectTutorCall
              ? "skipped_for_direct_call"
              : (preferredCountry || "any"),
            blocklistEnabled: true,
          },
          roomPrecreated: precreatedRoomOk,
          roomCreatedAt: precreatedRoomCreatedAt,
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
        message: isDirectTutorCall
          ? "Calling selected tutor..."
          : "Searching for available tutor...",
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

async function sendNotificationToNextTutor(sessionId, fallbackSessionData = {}) {
  try {
    const sessionRef = admin
      .firestore()
      .collection("videoSessions")
      .doc(sessionId);

    const assignment = await admin.firestore().runTransaction(
      async (transaction) => {
        const freshSessionSnap = await transaction.get(sessionRef);
        if (!freshSessionSnap.exists) {
          return {
            shouldNotify: false,
            skipReason: "session_not_found",
          };
        }

        const freshSessionData = freshSessionSnap.data() || {};
        const status = freshSessionData.status || "unknown";
        if (status !== "searching") {
          return {
            shouldNotify: false,
            skipReason: `status_${status}`,
          };
        }

        if (freshSessionData.currentTutorId) {
          return {
            shouldNotify: false,
            skipReason: `tutor_already_assigned_${freshSessionData.currentTutorId}`,
          };
        }

        const availableTutors = freshSessionData.availableTutors || [];
        const triedTutors = freshSessionData.triedTutors || [];
        const nextTutor = availableTutors.find(
          (tutorId) => !triedTutors.includes(tutorId),
        );

        if (!nextTutor) {
          transaction.update(sessionRef, {
            status: "no_tutors_available",
            sessionMetadata: {
              ...(freshSessionData.sessionMetadata || {}),
              noTutorsReason: "All available tutors have been tried",
              finalizedAt: Date.now(),
              skipReason: "no_available_tutors",
            },
          });
          return {
            shouldNotify: false,
            skipReason: "no_available_tutors",
          };
        }

        transaction.update(sessionRef, {
          currentTutorId: nextTutor,
          sessionMetadata: {
            ...(freshSessionData.sessionMetadata || {}),
            lastNotifiedTutorId: nextTutor,
            lastNotifiedAt: Date.now(),
          },
        });

        return {
          shouldNotify: true,
          nextTutor,
          sessionData: freshSessionData,
        };
      },
    );

    if (!assignment || !assignment.shouldNotify) {
      console.log(
        "⏭️ Skipping tutor notification for session",
        sessionId,
        "reason:",
        assignment?.skipReason || "unknown",
      );
      return;
    }

    const nextTutor = assignment.nextTutor;
    const sessionData = assignment.sessionData || fallbackSessionData || {};
    const studentInfo = sessionData.studentInfo || fallbackSessionData.studentInfo || {};
    const studentName = studentInfo.name || "Student";
    const studentPhoto = studentInfo.photo || null;
    const studentId = sessionData.studentId || fallbackSessionData.studentId || "";
    const language = sessionData.language || fallbackSessionData.language || "";

    const freshValidationSnap = await sessionRef.get();
    if (!freshValidationSnap.exists) {
      console.log(
        "⏭️ Skipping tutor notification. Session disappeared:",
        sessionId,
      );
      return;
    }

    const freshValidation = freshValidationSnap.data() || {};
    if (
      freshValidation.status !== "searching" ||
      freshValidation.currentTutorId !== nextTutor
    ) {
      console.log(
        "⏭️ Skipping tutor notification after validation. reason:",
        `status_${freshValidation.status || "unknown"}`,
        `currentTutor_${freshValidation.currentTutorId || "none"}`,
      );
      return;
    }

    // Создаём уведомление в Firestore
    const expiresAt = new Date();
    expiresAt.setSeconds(expiresAt.getSeconds() + 45);

    const notificationData = {
      recipientId: nextTutor,
      sessionId,
      type: "incoming_call",
      status: "sent",
      title: "Входящий звонок",
      message: `${studentName} хочет попрактиковать ${language}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      studentInfo,
    };

    await admin.firestore().collection("notifications").add(notificationData);
    console.log("✅ Firestore notification created for tutor:", nextTutor);

    // 🔔 Отправляем VoIP push преподавателю
    console.log("📲 Sending VoIP push to tutor...");
    try {
      await sendVoipPushToTutor(nextTutor, {
        sessionId: sessionId,
        studentName: studentName,
        studentId: studentId,
        studentPhoto: studentPhoto,
        language: language,
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
