const admin = require("firebase-admin");
const {
  createIncomingCallNotificationInTransaction,
} = require("./call_notifications");
const {
  buildReadOnlyVoipTokenState,
  getReadOnlyUserVoipTokenState,
} = require("./voip_tokens");
const {
  SEARCH_REQUEST_COLLECTION,
} = require("./search_requests");
const {
  shouldCreateBackgroundStudentResponderIncomingCall,
  shouldCreateTeacherResponderIncomingCall,
  shouldLeaveBackgroundNotificationForAccept,
  shouldUseTeacherResponderForIncomingCall,
} = require("./start_search_responder_policy");

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function readErrorMessage(error, fallback = "") {
  if (error && typeof error === "object") {
    try {
      return normalizeString(error.message) || fallback;
    } catch (readError) {
      return fallback;
    }
  }
  try {
    return normalizeString(String(error)) || fallback;
  } catch (stringifyError) {
    return fallback;
  }
}

function buildStudentPairRequesterInfo(requesterData = {}) {
  return {
    name:
      normalizeString(requesterData.display_name) ||
      normalizeString(requesterData.displayName) ||
      "Student",
    photo:
      normalizeString(requesterData.photo_url) ||
      normalizeString(requesterData.photoUrl),
  };
}

async function createBackgroundStudentResponderIncomingCall({
  db,
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  requesterData = {},
  nowMillis = Date.now(),
}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (!normalizedSessionId || !normalizedResponderId || !searchDocId) {
    return {shouldNotify: false, reason: "missing_ids"};
  }

  return db.runTransaction(async (transaction) => {
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const responderSearchRef = db
      .collection(SEARCH_REQUEST_COLLECTION)
      .doc(searchDocId);
    const [sessionSnap, responderSearchSnap] = await Promise.all([
      transaction.get(sessionRef),
      transaction.get(responderSearchRef),
    ]);
    if (!sessionSnap.exists) {
      return {shouldNotify: false, reason: "session_missing"};
    }
    if (!responderSearchSnap.exists) {
      return {shouldNotify: false, reason: "responder_search_missing"};
    }

    const sessionData = sessionSnap.data() || {};
    const responderSearchRequestData = responderSearchSnap.data() || {};
    const decision = shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData,
      sessionId: normalizedSessionId,
      responderId: normalizedResponderId,
      responderSearchRequestData,
      nowMillis,
    });
    if (!decision.shouldNotify) {
      return decision;
    }

    const notification = createIncomingCallNotificationInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      recipientId: normalizedResponderId,
      sessionData,
      studentInfo: buildStudentPairRequesterInfo(requesterData),
      studentNameFallback: "Student",
      now: new Date(nowMillis),
    });

    return {
      shouldNotify: true,
      reason: decision.reason,
      notificationId: notification.notificationId,
      pushPayload: notification.pushPayload,
    };
  });
}

async function createTeacherResponderIncomingCall({
  db,
  sessionId = "",
  responderId = "",
  requesterData = {},
  nowMillis = Date.now(),
}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  if (!normalizedSessionId || !normalizedResponderId) {
    return {shouldNotify: false, reason: "missing_ids"};
  }

  return db.runTransaction(async (transaction) => {
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const sessionSnap = await transaction.get(sessionRef);
    if (!sessionSnap.exists) {
      return {shouldNotify: false, reason: "session_missing"};
    }

    const sessionData = sessionSnap.data() || {};
    const assignedResponderId =
      normalizeString(sessionData.currentResponderId) ||
      normalizeString(sessionData.currentTutorId);
    if (
      assignedResponderId &&
      assignedResponderId !== normalizedResponderId
    ) {
      return {shouldNotify: false, reason: "responder_mismatch"};
    }
    const decision = shouldCreateTeacherResponderIncomingCall({
      sessionData,
      responderId: normalizedResponderId,
      nowMillis,
    });
    if (!decision.shouldNotify) {
      return decision;
    }

    const notification = createIncomingCallNotificationInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      recipientId: normalizedResponderId,
      sessionData,
      studentInfo: buildStudentPairRequesterInfo(requesterData),
      studentNameFallback: "Student",
      now: new Date(nowMillis),
    });

    return {
      shouldNotify: true,
      reason: decision.reason,
      notificationId: notification.notificationId,
      pushPayload: notification.pushPayload,
    };
  });
}

async function backgroundStudentResponderPushStillCurrent({
  db,
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  notificationId = "",
  nowMillis = Date.now(),
}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (!normalizedSessionId || !normalizedResponderId || !searchDocId) {
    return {stillCurrent: false, reason: "missing_ids", leaveForAccept: false};
  }

  const reads = [
    db.collection("videoSessions").doc(normalizedSessionId).get(),
    db.collection(SEARCH_REQUEST_COLLECTION).doc(searchDocId).get(),
  ];
  if (notificationId) {
    reads.push(db.collection("notifications").doc(notificationId).get());
  }
  const [sessionSnap, responderSearchSnap, notificationSnap] =
    await Promise.all(reads);
  if (!sessionSnap.exists || !responderSearchSnap.exists) {
    return {
      stillCurrent: false,
      reason: "session_or_search_missing",
      leaveForAccept: false,
    };
  }
  const sessionData = sessionSnap.data() || {};

  const decision = shouldCreateBackgroundStudentResponderIncomingCall({
    sessionData,
    sessionId: normalizedSessionId,
    responderId: normalizedResponderId,
    responderSearchRequestData: responderSearchSnap.data() || {},
    nowMillis,
  });
  if (!decision.shouldNotify) {
    return {
      stillCurrent: false,
      reason: decision.reason,
      leaveForAccept: shouldLeaveBackgroundNotificationForAccept({
        decision,
        sessionData,
      }),
    };
  }

  if (notificationId) {
    const notificationData = notificationSnap?.data?.() || {};
    if (
      !notificationSnap?.exists ||
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        stillCurrent: false,
        reason: "notification_not_current",
        leaveForAccept: false,
      };
    }
  }

  return {
    stillCurrent: true,
    reason: decision.reason,
    leaveForAccept: false,
  };
}

async function teacherResponderPushStillCurrent({
  db,
  sessionId = "",
  responderId = "",
  notificationId = "",
  nowMillis = Date.now(),
  tokenReader = getReadOnlyUserVoipTokenState,
}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const normalizedNotificationId = normalizeString(notificationId);
  if (
    !normalizedSessionId ||
    !normalizedResponderId ||
    !normalizedNotificationId
  ) {
    return {stillCurrent: false, reason: "missing_ids", leaveForAccept: false};
  }

  const [sessionSnap, notificationSnap, teacherSnap] = await Promise.all([
    db.collection("videoSessions").doc(normalizedSessionId).get(),
    db.collection("notifications").doc(normalizedNotificationId).get(),
    db.collection("users").doc(normalizedResponderId).get(),
  ]);
  if (!sessionSnap.exists) {
    return {stillCurrent: false, reason: "session_missing", leaveForAccept: false};
  }
  if (!notificationSnap.exists) {
    return {
      stillCurrent: false,
      reason: "notification_missing",
      leaveForAccept: false,
    };
  }
  if (!teacherSnap.exists) {
    return {stillCurrent: false, reason: "teacher_missing", leaveForAccept: false};
  }

  const sessionData = sessionSnap.data() || {};
  const decision = shouldCreateTeacherResponderIncomingCall({
    sessionData,
    responderId: normalizedResponderId,
    nowMillis,
  });
  if (!decision.shouldNotify) {
    return {
      stillCurrent: false,
      reason: decision.reason,
      leaveForAccept: shouldLeaveBackgroundNotificationForAccept({
        decision,
        sessionData,
      }),
    };
  }

  const notificationData = notificationSnap.data() || {};
  if (
    notificationData.status !== "sent" ||
    notificationData.sessionId !== normalizedSessionId ||
    notificationData.recipientId !== normalizedResponderId
  ) {
    return {
      stillCurrent: false,
      reason: "notification_not_current",
      leaveForAccept: false,
    };
  }

  const teacherData = teacherSnap.data() || {};
  const tokenState = await tokenReader(
    normalizedResponderId,
    teacherData,
    db,
  );
  const teacherDecision = shouldUseTeacherResponderForIncomingCall({
    teacherData,
    responderId: normalizedResponderId,
    sessionId: normalizedSessionId,
    sessionData,
    tokenState,
    now: new Date(nowMillis),
  });
  if (!teacherDecision.valid) {
    return {
      stillCurrent: false,
      reason: teacherDecision.reason,
      leaveForAccept: false,
    };
  }

  return {
    stillCurrent: true,
    reason: teacherDecision.reason,
    leaveForAccept: false,
  };
}

async function cancelBackgroundStudentResponderNotification({
  db,
  notificationId = "",
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  reason = "stale_before_push",
  pushResult = null,
  nowMillis = Date.now(),
}) {
  const normalizedNotificationId = normalizeString(notificationId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (
    !normalizedNotificationId ||
    !normalizedSessionId ||
    !normalizedResponderId ||
    !searchDocId
  ) {
    return {cancelled: false, reason: "missing_ids", leaveForAccept: false};
  }

  return db.runTransaction(async (transaction) => {
    const notificationRef = db
      .collection("notifications")
      .doc(normalizedNotificationId);
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const responderSearchRef = db
      .collection(SEARCH_REQUEST_COLLECTION)
      .doc(searchDocId);
    const [sessionSnap, responderSearchSnap, notificationSnap] =
      await Promise.all([
        transaction.get(sessionRef),
        transaction.get(responderSearchRef),
        transaction.get(notificationRef),
      ]);
    if (!notificationSnap.exists) {
      return {
        cancelled: false,
        reason: "notification_missing",
        leaveForAccept: false,
      };
    }

    const notificationData = notificationSnap.data() || {};
    if (
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        cancelled: false,
        reason: "notification_not_current",
        leaveForAccept: false,
      };
    }

    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    const decision = sessionSnap.exists && responderSearchSnap.exists ?
      shouldCreateBackgroundStudentResponderIncomingCall({
        sessionData,
        sessionId: normalizedSessionId,
        responderId: normalizedResponderId,
        responderSearchRequestData: responderSearchSnap.data() || {},
        nowMillis,
      }) :
      {shouldNotify: false, reason: "session_or_search_missing"};
    if (
      shouldLeaveBackgroundNotificationForAccept({
        decision,
        sessionData,
      })
    ) {
      return {
        cancelled: false,
        reason: "accept_finalization_in_progress",
        staleReason: decision.reason,
        leaveForAccept: true,
      };
    }

    const update = {
      status: "cancelled",
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelReason: normalizeString(reason) || "stale_before_push",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (pushResult && pushResult.sent === true) {
      update.pushSentAt = admin.firestore.FieldValue.serverTimestamp();
      update.pushChannel = normalizeString(pushResult.channel) || "unknown";
    }
    transaction.update(notificationRef, update);
    return {
      cancelled: true,
      reason: normalizeString(reason) || "stale_before_push",
      staleReason: decision.reason,
      leaveForAccept: false,
    };
  });
}

async function cancelTeacherResponderNotification({
  db,
  notificationId = "",
  sessionId = "",
  responderId = "",
  reason = "stale_before_push",
  staleReason = "",
  nowMillis = Date.now(),
}) {
  const normalizedNotificationId = normalizeString(notificationId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  if (
    !normalizedNotificationId ||
    !normalizedSessionId ||
    !normalizedResponderId
  ) {
    return {cancelled: false, reason: "missing_ids", leaveForAccept: false};
  }

  return db.runTransaction(async (transaction) => {
    const notificationRef = db
      .collection("notifications")
      .doc(normalizedNotificationId);
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const [sessionSnap, notificationSnap] = await Promise.all([
      transaction.get(sessionRef),
      transaction.get(notificationRef),
    ]);
    if (!notificationSnap.exists) {
      return {
        cancelled: false,
        reason: "notification_missing",
        leaveForAccept: false,
      };
    }

    const notificationData = notificationSnap.data() || {};
    if (
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        cancelled: false,
        reason: "notification_not_current",
        leaveForAccept: false,
      };
    }

    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    const decision = sessionSnap.exists ?
      shouldCreateTeacherResponderIncomingCall({
        sessionData,
        responderId: normalizedResponderId,
        nowMillis,
      }) :
      {shouldNotify: false, reason: "session_missing"};
    if (shouldLeaveBackgroundNotificationForAccept({decision, sessionData})) {
      return {
        cancelled: false,
        reason: "accept_finalization_in_progress",
        staleReason: decision.reason,
        leaveForAccept: true,
      };
    }

    transaction.update(notificationRef, {
      status: "cancelled",
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelReason: normalizeString(reason) || "stale_before_push",
      staleReason:
        normalizeString(staleReason) ||
        normalizeString(decision.reason) ||
        "stale_before_push",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
      cancelled: true,
      reason: normalizeString(reason) || "stale_before_push",
      staleReason:
        normalizeString(staleReason) ||
        normalizeString(decision.reason) ||
        "stale_before_push",
      leaveForAccept: false,
    };
  });
}

async function recordBackgroundStudentResponderPushFailure({
  db,
  notificationId = "",
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  error,
  nowMillis = Date.now(),
}) {
  const normalizedNotificationId = normalizeString(notificationId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (
    !normalizedNotificationId ||
    !normalizedSessionId ||
    !normalizedResponderId ||
    !searchDocId
  ) {
    return {stillCurrent: false, reason: "missing_ids", updated: false};
  }

  return db.runTransaction(async (transaction) => {
    const notificationRef = db
      .collection("notifications")
      .doc(normalizedNotificationId);
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const responderSearchRef = db
      .collection(SEARCH_REQUEST_COLLECTION)
      .doc(searchDocId);
    const [sessionSnap, responderSearchSnap, notificationSnap] =
      await Promise.all([
        transaction.get(sessionRef),
        transaction.get(responderSearchRef),
        transaction.get(notificationRef),
      ]);
    if (!notificationSnap.exists) {
      return {
        stillCurrent: false,
        reason: "notification_missing",
        updated: false,
      };
    }

    const notificationData = notificationSnap.data() || {};
    if (
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        stillCurrent: false,
        reason: "notification_not_current",
        updated: false,
      };
    }

    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    const decision = sessionSnap.exists && responderSearchSnap.exists ?
      shouldCreateBackgroundStudentResponderIncomingCall({
        sessionData,
        sessionId: normalizedSessionId,
        responderId: normalizedResponderId,
        responderSearchRequestData: responderSearchSnap.data() || {},
        nowMillis,
      }) :
      {shouldNotify: false, reason: "session_or_search_missing"};

    if (!decision.shouldNotify) {
      if (shouldLeaveBackgroundNotificationForAccept({decision, sessionData})) {
        return {
          stillCurrent: false,
          reason: "accept_finalization_in_progress",
          staleReason: decision.reason,
          updated: false,
        };
      }
      transaction.update(notificationRef, {
        status: "cancelled",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelReason: "stale_after_push",
        staleReason: decision.reason,
        lastPushError: readErrorMessage(error, "push_failed"),
        lastPushFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        stillCurrent: false,
        reason: "stale_after_push",
        staleReason: decision.reason,
        updated: true,
      };
    }

    transaction.update(notificationRef, {
      lastPushError: readErrorMessage(error, "push_failed"),
      lastPushFailedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
      stillCurrent: true,
      reason: decision.reason,
      updated: true,
    };
  });
}

async function recordBackgroundStudentResponderPushSuccess({
  db,
  notificationId = "",
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  pushResult = {},
  nowMillis = Date.now(),
}) {
  const normalizedNotificationId = normalizeString(notificationId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (
    !normalizedNotificationId ||
    !normalizedSessionId ||
    !normalizedResponderId ||
    !searchDocId
  ) {
    return {stillCurrent: false, reason: "missing_ids", updated: false};
  }

  return db.runTransaction(async (transaction) => {
    const notificationRef = db
      .collection("notifications")
      .doc(normalizedNotificationId);
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const responderSearchRef = db
      .collection(SEARCH_REQUEST_COLLECTION)
      .doc(searchDocId);
    const [sessionSnap, responderSearchSnap, notificationSnap] =
      await Promise.all([
        transaction.get(sessionRef),
        transaction.get(responderSearchRef),
        transaction.get(notificationRef),
      ]);
    if (!notificationSnap.exists) {
      return {
        stillCurrent: false,
        reason: "notification_missing",
        updated: false,
      };
    }

    const notificationData = notificationSnap.data() || {};
    if (
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        stillCurrent: false,
        reason: "notification_not_current",
        updated: false,
      };
    }

    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    const decision = sessionSnap.exists && responderSearchSnap.exists ?
      shouldCreateBackgroundStudentResponderIncomingCall({
        sessionData,
        sessionId: normalizedSessionId,
        responderId: normalizedResponderId,
        responderSearchRequestData: responderSearchSnap.data() || {},
        nowMillis,
      }) :
      {shouldNotify: false, reason: "session_or_search_missing"};

    if (!decision.shouldNotify) {
      if (shouldLeaveBackgroundNotificationForAccept({decision, sessionData})) {
        return {
          stillCurrent: false,
          reason: "accept_finalization_in_progress",
          staleReason: decision.reason,
          updated: false,
        };
      }
      transaction.update(notificationRef, {
        status: "cancelled",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelReason: "stale_after_push",
        staleReason: decision.reason,
        pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
        pushChannel: normalizeString(pushResult.channel) || "unknown",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        stillCurrent: false,
        reason: "stale_after_push",
        staleReason: decision.reason,
        updated: true,
      };
    }

    transaction.update(notificationRef, {
      pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
      pushChannel: normalizeString(pushResult.channel) || "unknown",
      lastPushError: admin.firestore.FieldValue.delete(),
      lastPushFailedAt: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
      stillCurrent: true,
      reason: decision.reason,
      updated: true,
    };
  });
}

async function recordTeacherResponderPushResult({
  db,
  notificationId = "",
  sessionId = "",
  responderId = "",
  pushResult = {},
  nowMillis = Date.now(),
}) {
  const normalizedNotificationId = normalizeString(notificationId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  if (
    !normalizedNotificationId ||
    !normalizedSessionId ||
    !normalizedResponderId
  ) {
    return {stillCurrent: false, reason: "missing_ids", updated: false};
  }

  return db.runTransaction(async (transaction) => {
    const notificationRef = db
      .collection("notifications")
      .doc(normalizedNotificationId);
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const teacherRef = db.collection("users").doc(normalizedResponderId);
    const privateTokenRef = db
      .collection("userPrivateTokens")
      .doc(normalizedResponderId);
    const [sessionSnap, notificationSnap, teacherSnap, privateTokenSnap] =
      await Promise.all([
      transaction.get(sessionRef),
      transaction.get(notificationRef),
      transaction.get(teacherRef),
      transaction.get(privateTokenRef),
    ]);
    if (!notificationSnap.exists) {
      return {
        stillCurrent: false,
        reason: "notification_missing",
        updated: false,
      };
    }

    const notificationData = notificationSnap.data() || {};
    if (
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        stillCurrent: false,
        reason: "notification_not_current",
        updated: false,
      };
    }

    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    const decision = sessionSnap.exists ?
      shouldCreateTeacherResponderIncomingCall({
        sessionData,
        responderId: normalizedResponderId,
        nowMillis,
      }) :
      {shouldNotify: false, reason: "session_missing"};
    const teacherData = teacherSnap.exists ? teacherSnap.data() || {} : {};
    const tokenState = buildReadOnlyVoipTokenState({
      privateData: privateTokenSnap.exists ?
        privateTokenSnap.data() || {} :
        {},
      legacyUserData: teacherData,
    });
    const teacherDecision = decision.shouldNotify ?
      shouldUseTeacherResponderForIncomingCall({
        teacherData,
        responderId: normalizedResponderId,
        sessionId: normalizedSessionId,
        sessionData,
        tokenState,
        now: new Date(nowMillis),
      }) :
      {valid: false, reason: decision.reason};
    const finalDecision = teacherDecision.valid ?
      decision :
      {shouldNotify: false, reason: teacherDecision.reason};
    const pushSent = pushResult?.sent === true;
    const pushErrorMessage =
      normalizeString(pushResult?.error) ||
      normalizeString(pushResult?.reason) ||
      "push_failed";

    if (!finalDecision.shouldNotify) {
      if (
        shouldLeaveBackgroundNotificationForAccept({
          decision: finalDecision,
          sessionData,
        })
      ) {
        return {
          stillCurrent: false,
          reason: "accept_finalization_in_progress",
          staleReason: finalDecision.reason,
          updated: false,
        };
      }
      const staleUpdate = {
        status: "cancelled",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelReason: "stale_after_push",
        staleReason: finalDecision.reason,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (pushSent) {
        staleUpdate.pushSentAt =
          admin.firestore.FieldValue.serverTimestamp();
        staleUpdate.pushChannel =
          normalizeString(pushResult.channel) || "unknown";
      } else {
        staleUpdate.lastPushError = pushErrorMessage;
        staleUpdate.lastPushFailedAt =
          admin.firestore.FieldValue.serverTimestamp();
      }
      transaction.update(notificationRef, staleUpdate);
      return {
        stillCurrent: false,
        reason: "stale_after_push",
        staleReason: finalDecision.reason,
        updated: true,
      };
    }

    if (pushSent) {
      transaction.update(notificationRef, {
        pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
        pushChannel: normalizeString(pushResult.channel) || "unknown",
        lastPushError: admin.firestore.FieldValue.delete(),
        lastPushFailedAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      transaction.update(notificationRef, {
        lastPushError: pushErrorMessage,
        lastPushFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return {
      stillCurrent: true,
      reason: teacherDecision.reason,
      updated: true,
    };
  });
}

module.exports = {
  buildStudentPairRequesterInfo,
  createBackgroundStudentResponderIncomingCall,
  createTeacherResponderIncomingCall,
  backgroundStudentResponderPushStillCurrent,
  teacherResponderPushStillCurrent,
  cancelBackgroundStudentResponderNotification,
  cancelTeacherResponderNotification,
  recordBackgroundStudentResponderPushFailure,
  recordBackgroundStudentResponderPushSuccess,
  recordTeacherResponderPushResult,
};
