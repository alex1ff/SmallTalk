const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { isSessionParticipant } = require("./session_participants");

const MAX_COMMENT_LENGTH = 1000;

function normalizeSessionId(rawSessionId) {
  if (typeof rawSessionId !== "string") {
    return "";
  }
  return rawSessionId.trim();
}

function normalizeToUserId(rawToUserId) {
  if (rawToUserId == null) {
    return "";
  }
  if (typeof rawToUserId !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "toUserId must be a string",
    );
  }
  return rawToUserId.trim();
}

function normalizeRating(rawRating) {
  const rating = Number(rawRating);
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "rating must be an integer between 1 and 5",
    );
  }
  return rating;
}

function normalizeComment(rawComment) {
  if (rawComment == null) {
    return "";
  }
  if (typeof rawComment !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "comment must be a string",
    );
  }
  const comment = rawComment.trim();
  if (comment.length > MAX_COMMENT_LENGTH) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `comment must be at most ${MAX_COMMENT_LENGTH} characters`,
    );
  }
  return comment;
}

exports.submitReview = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  const userId = context.auth.uid;
  const sessionId = normalizeSessionId(data?.sessionId);
  const requestedToUserId = normalizeToUserId(data?.toUserId);
  const rating = normalizeRating(data?.rating);
  const comment = normalizeComment(data?.comment);

  if (!sessionId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "sessionId is required",
    );
  }

  const db = admin.firestore();
  const sessionRef = db.collection("videoSessions").doc(sessionId);
  const callerRef = db.collection("users").doc(userId);

  try {
    const result = await db.runTransaction(async (transaction) => {
      const sessionSnap = await transaction.get(sessionRef);
      if (!sessionSnap.exists) {
        throw new functions.https.HttpsError("not-found", "Session not found");
      }

      const sessionData = sessionSnap.data() || {};
      if (!isSessionParticipant(sessionData, userId)) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "You are not a participant of this session",
        );
      }

      const isStudent = sessionData.studentId === userId;
      const isTutor = sessionData.tutorId === userId;

      const targetUserId = isStudent ? sessionData.tutorId : sessionData.studentId;
      if (!targetUserId || typeof targetUserId !== "string") {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Session does not have a valid review target",
        );
      }
      if (targetUserId === userId) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Cannot review yourself",
        );
      }
      if (requestedToUserId && requestedToUserId !== targetUserId) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "toUserId does not match session participant",
        );
      }

      const targetUserRef = db.collection("users").doc(targetUserId);
      const reviewId = `${sessionId}_${userId}_${targetUserId}`;
      const reviewRef = db.collection("reviews").doc(reviewId);

      const targetUserSnap = await transaction.get(targetUserRef);
      if (!targetUserSnap.exists) {
        throw new functions.https.HttpsError("not-found", "Target user not found");
      }

      const reviewSnap = await transaction.get(reviewRef);
      const targetUserData = targetUserSnap.data() || {};
      const targetRating = targetUserData.rating || {};
      const currentTotal = Number(targetRating.totalReviews || 0);
      const currentAverage = Number(targetRating.average || 0);

      if (reviewSnap.exists) {
        return {
          reviewStatus: "already_submitted",
          reviewId,
          toUserId: targetUserId,
          average: currentAverage,
          totalReviews: currentTotal,
        };
      }

      const newTotal = currentTotal + 1;
      const newAverage = Number(
        (((currentAverage * currentTotal) + rating) / newTotal).toFixed(4),
      );

      const reviewData = {
        sessionId: sessionRef,
        fromUserId: callerRef,
        toUserId: targetUserRef,
        rating,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (comment) {
        reviewData.comment = comment;
      }

      transaction.set(reviewRef, reviewData);
      transaction.set(targetUserRef, {
        rating: {
          average: newAverage,
          totalReviews: newTotal,
        },
      }, {merge: true});

      return {
        reviewStatus: "created",
        reviewId,
        toUserId: targetUserId,
        average: newAverage,
        totalReviews: newTotal,
      };
    });

    return {
      status: "ok",
      ...result,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    console.error("❌ submitReview failed:", {
      userId,
      sessionId,
      toUserId: requestedToUserId || null,
      message: error?.message,
    });
    throw new functions.https.HttpsError(
      "internal",
      "Failed to submit review",
    );
  }
});
