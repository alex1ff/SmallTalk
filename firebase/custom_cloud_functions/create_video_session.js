const functions = require("firebase-functions");
const admin = require("firebase-admin");

/*
ФУНКЦИЯ НЕ ТРЕБУЕТ ДОП. ПАКЕТОВ
Только firebase-functions и firebase-admin
*/

exports.createVideoSession = functions.https.onCall(async (data, context) => {
  console.log("📹 Creating video session...");

  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
      );
    }

    const studentId = context.auth.uid;
    const { language } = data;

    console.log("👨‍🎓 Student ID:", studentId);
    console.log("🌍 Requested language:", language);

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

    // Ищем доступных преподавателей
    let tutorsQuery;
    try {
      tutorsQuery = await admin
        .firestore()
        .collection("users")
        .where("role", "==", "tutor")
        .where("teachingLanguages", "array-contains", language)
        .where("isAvailable", "==", true)
        .where("isInCall", "!=", true)
        .get();
    } catch (queryError) {
      console.error("❌ Tutor query failed, fallback:", queryError.message);
      tutorsQuery = await admin
        .firestore()
        .collection("users")
        .where("role", "==", "tutor")
        .where("teachingLanguages", "array-contains", language)
        .where("isAvailable", "==", true)
        .get();
    }

    if (tutorsQuery.empty) {
      return {
        status: "no_tutors_available",
        message: "No tutors available for this language right now",
      };
    }

    // Фильтруем доступных преподов
    const availableTutors = [];
    tutorsQuery.forEach((doc) => {
      const tutorData = doc.data();
      if (
        tutorData.availableAfter &&
        tutorData.availableAfter.toDate() > new Date()
      )
        return;

      const teachingLangs = tutorData.teachingLanguages || [];
      if (
        teachingLangs.includes(language) &&
        tutorData.isAvailable &&
        !tutorData.isInCall
      ) {
        availableTutors.push(doc.id);
      }
    });

    if (availableTutors.length === 0) {
      return {
        status: "no_tutors_available",
        message: "No tutors available right now, try again later",
      };
    }

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

      // для поиска
      currentTutorId: null,
      triedTutors: [],
      availableTutors,
      studentInfo: {
        name: studentData.display_name || "Student",
        photo: studentData.photo_url || null,
      },

      // активная сессия (пока null)
      dailyRoomUrl: null,
      dailyRoomName: null,
      meetingToken: null,
      acceptedAt: null,
      startedAt: null,
      endedAt: null,
      duration: null,
      tutorInfo: null,
    };

    const sessionRef = await admin
      .firestore()
      .collection("videoSessions")
      .add(sessionData);
    console.log("✅ Video session created:", sessionRef.id);

    // Уведомляем первого препода
    await sendNotificationToNextTutor(sessionRef.id, sessionData);

    return {
      status: "searching",
      sessionId: sessionRef.id,
      message: "Searching for available tutor...",
    };
  } catch (error) {
    console.error("❌ Error creating video session:", error);
    if (error.code) throw error;
    throw new functions.https.HttpsError("internal", error.message);
  }
});

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

    // Обновляем текущего препода
    await admin.firestore().collection("videoSessions").doc(sessionId).update({
      currentTutorId: nextTutor,
    });

    // Создаём уведомление
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
    console.log("✅ Notification sent to tutor:", nextTutor);
  } catch (error) {
    console.error("❌ Error sending notification:", error);
  }
}
