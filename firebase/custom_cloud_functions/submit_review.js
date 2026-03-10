const functions = require("firebase-functions");
const admin = require("firebase-admin");

const MAX_COMMENT_LENGTH = 1000;
const RECENT_SESSION_LOOKUP_WINDOW_MS = 1000 * 60 * 60 * 24 * 14;
const REVIEWABLE_SESSION_STATUSES = new Set([
  "connected",
  "connecting",
  "active",
  "ended",
  "cancelled",
  "completed",
]);

function normalizeSessionId(rawSessionId) {
  if (typeof rawSessionId !== "string") {
    return "";
  }
  return rawSessionId.trim();
}

function normalizeSessionPath(rawSessionPath) {
  if (typeof rawSessionPath !== "string") {
    return "";
  }
  return rawSessionPath.trim().replace(/^\/+|\/+$/g, "");
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

function sessionActivityMillis(sessionData) {
  return Math.max(
    toMillis(sessionData?.endedAt),
    toMillis(sessionData?.sessionMetadata?.endedAtTimestamp),
    toMillis(sessionData?.startedAt),
    toMillis(sessionData?.acceptedAt),
    toMillis(sessionData?.createdAt),
  );
}

function isDocumentPath(path) {
  if (!path || path.includes("|")) {
    return false;
  }
  const segments = path.split("/").filter(Boolean);
  return segments.length > 0 && segments.length % 2 === 0;
}

function addCandidateRef(candidateRefs, seenPaths, ref) {
  if (!ref || !ref.path || seenPaths.has(ref.path)) {
    return;
  }
  seenPaths.add(ref.path);
  candidateRefs.push(ref);
}

function buildSessionCandidateRefs(db, sessionId, sessionPath) {
  const candidateRefs = [];
  const seenPaths = new Set();

  if (sessionId) {
    addCandidateRef(
      candidateRefs,
      seenPaths,
      db.collection("videoSessions").doc(sessionId),
    );
  }

  if (sessionPath && isDocumentPath(sessionPath)) {
    addCandidateRef(candidateRefs, seenPaths, db.doc(sessionPath));

    const pathSegments = sessionPath.split("/").filter(Boolean);
    const videoSessionsIndex = pathSegments.lastIndexOf("videoSessions");
    const nestedSessionId =
      videoSessionsIndex >= 0 && pathSegments.length > videoSessionsIndex + 1
        ? pathSegments[videoSessionsIndex + 1]
        : "";
    if (nestedSessionId) {
      addCandidateRef(
        candidateRefs,
        seenPaths,
        db.collection("videoSessions").doc(nestedSessionId),
      );
    }
  }

  if (sessionId && isDocumentPath(sessionId)) {
    addCandidateRef(candidateRefs, seenPaths, db.doc(sessionId));
  }

  return candidateRefs;
}

async function findRecentMutualSessionRef(db, userId, otherUserId) {
  if (!otherUserId) {
    return null;
  }

  const [asStudentSnap, asTutorSnap] = await Promise.all([
    db.collection("videoSessions").where("studentId", "==", userId).get(),
    db.collection("videoSessions").where("tutorId", "==", userId).get(),
  ]);

  const candidateSessions = new Map();
  const nowMs = Date.now();

  for (const doc of [...asStudentSnap.docs, ...asTutorSnap.docs]) {
    const sessionData = doc.data() || {};
    const studentId =
      typeof sessionData.studentId === "string" ?
        sessionData.studentId.trim() :
        "";
    const tutorId =
      typeof sessionData.tutorId === "string" ?
        sessionData.tutorId.trim() :
        "";
    const isParticipantMatch =
      (studentId === userId && tutorId === otherUserId) ||
      (studentId === otherUserId && tutorId === userId);
    if (!isParticipantMatch) {
      continue;
    }

    const status = String(sessionData.status || "").trim().toLowerCase();
    if (!REVIEWABLE_SESSION_STATUSES.has(status)) {
      continue;
    }

    const activityMs = sessionActivityMillis(sessionData) || nowMs;
    if (nowMs - activityMs > RECENT_SESSION_LOOKUP_WINDOW_MS) {
      continue;
    }

    const existingCandidate = candidateSessions.get(doc.id);
    if (!existingCandidate || activityMs > existingCandidate.activityMs) {
      candidateSessions.set(doc.id, {
        ref: doc.ref,
        activityMs,
      });
    }
  }

  const [latestSession] = [...candidateSessions.values()].sort(
    (left, right) => right.activityMs - left.activityMs,
  );
  return latestSession?.ref ?? null;
}

async function resolveSessionRef({
  db,
  sessionId,
  sessionPath,
  userId,
  requestedToUserId,
}) {
  const candidateRefs = buildSessionCandidateRefs(db, sessionId, sessionPath);

  for (const candidateRef of candidateRefs) {
    const candidateSnap = await candidateRef.get();
    if (candidateSnap.exists) {
      return candidateRef;
    }
  }

  return await findRecentMutualSessionRef(db, userId, requestedToUserId);
}

exports.submitReview = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  const userId = context.auth.uid;
  const requestedSessionId = normalizeSessionId(data?.sessionId);
  const requestedSessionPath = normalizeSessionPath(data?.sessionPath);
  const requestedToUserId = normalizeToUserId(data?.toUserId);
  const rating = normalizeRating(data?.rating);
  const comment = normalizeComment(data?.comment);

  if (!requestedSessionId && !requestedSessionPath && !requestedToUserId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "sessionId, sessionPath, or toUserId is required",
    );
  }

  const db = admin.firestore();
  const callerRef = db.collection("users").doc(userId);
  let resolvedSessionRef = null;

  try {
    resolvedSessionRef = await resolveSessionRef({
      db,
      sessionId: requestedSessionId,
      sessionPath: requestedSessionPath,
      userId,
      requestedToUserId,
    });

    if (!resolvedSessionRef) {
      throw new functions.https.HttpsError("not-found", "Session not found");
    }

    const result = await db.runTransaction(async (transaction) => {
      const sessionSnap = await transaction.get(resolvedSessionRef);
      if (!sessionSnap.exists) {
        throw new functions.https.HttpsError("not-found", "Session not found");
      }

      const sessionData = sessionSnap.data() || {};
      const isStudent = sessionData.studentId === userId;
      const isTutor = sessionData.tutorId === userId;
      if (!isStudent && !isTutor) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "You are not a participant of this session",
        );
      }

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
      const reviewId = `${resolvedSessionRef.id}_${userId}_${targetUserId}`;
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
        sessionId: resolvedSessionRef,
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
      requestedSessionId: requestedSessionId || null,
      requestedSessionPath: requestedSessionPath || null,
      resolvedSessionId: resolvedSessionRef?.id || null,
      toUserId: requestedToUserId || null,
      message: error?.message,
    });
    throw new functions.https.HttpsError(
      "internal",
      "Failed to submit review",
    );
  }
});
