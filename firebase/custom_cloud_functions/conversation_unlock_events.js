const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {FieldPath, FieldValue} = require("firebase-admin/firestore");
const {
  buildCallEventMessageId,
  buildCallEventMessagePayload,
  buildConversationSeed,
  buildUnlockEventPayload,
  conversationMatchesUnlockParticipants,
  getChatsRolloutTimestamp,
  getMaintenanceCursorState,
  getMaintenanceJobRef,
  getRepairPageSize,
  isEligibleCallEventSession,
  getUnlockEligibility,
  getUnlockParticipants,
  isStaleUnlockPending,
  isStaleUnlockProcessing,
} = require("./chats_shared");

const UNLOCK_REPAIR_JOB_NAME = "repairMissingConversationUnlockEvents";

exports.processConversationUnlockEvents = functions.firestore
  .document("conversationUnlockEvents/{sessionId}")
  .onWrite(async (change, context) => {
    const eventRef = change.after.ref;
    const eventData = change.after.exists ? change.after.data() || {} : null;

    if (!eventData || String(eventData.status || "") !== "pending") {
      return null;
    }

    return processPendingUnlockEvent(eventRef, context.params.sessionId);
  });

exports.repairMissingConversationUnlockEvents = functions
  .pubsub.schedule("every 5 minutes")
  .onRun(async () => {
    const db = admin.firestore();
    const rolloutTimestamp = getChatsRolloutTimestamp();
    const pageSize = getRepairPageSize();
    const stateRef = getMaintenanceJobRef(UNLOCK_REPAIR_JOB_NAME);
    const stateSnap = await stateRef.get();
    const cursorState = getMaintenanceCursorState(stateSnap);

    // Scan by endedAt so long-running calls are only cursor-advanced
    // after they have actually reached a terminal state.
    let query = db
      .collection("videoSessions")
      .where("endedAt", ">=", rolloutTimestamp)
      .orderBy("endedAt", "asc")
      .orderBy(FieldPath.documentId(), "asc")
      .limit(pageSize);

    if (cursorState) {
      query = query.startAfter(cursorState.cursorCreatedAt, cursorState.cursorDocumentId);
    }

    const pageSnap = await query.get();
    if (pageSnap.empty) {
      await stateRef.set(
        {
          cursorCreatedAt: null,
          cursorDocumentId: null,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return null;
    }

    for (const sessionDoc of pageSnap.docs) {
      const sessionData = sessionDoc.data() || {};
      const repairOutcome = await repairUnlockEventForSession(
        sessionDoc.ref,
        sessionData,
      );
      if (repairOutcome?.shouldEnsureCallEvent) {
        await maybeWriteCallEventForProcessedOutcome({
          db,
          eventRef: repairOutcome.eventRef,
          sessionId: sessionDoc.id,
          sessionRef: sessionDoc.ref,
          sessionData,
          conversationRef: repairOutcome.conversationRef,
        });
      }
    }

    const lastDoc = pageSnap.docs[pageSnap.docs.length - 1];
    await stateRef.set(
      {
        cursorCreatedAt: lastDoc.get("endedAt") || null,
        cursorDocumentId: lastDoc.id,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return null;
  });

async function processPendingUnlockEvent(eventRef, sessionId) {
  const db = admin.firestore();
  const claimed = await db.runTransaction(async (transaction) => {
    const eventSnap = await transaction.get(eventRef);
    if (!eventSnap.exists) {
      return null;
    }

    const eventData = eventSnap.data() || {};
    if (String(eventData.status || "") !== "pending") {
      return null;
    }

    const attemptCount = Number(eventData.attemptCount || 0) + 1;
    transaction.update(eventRef, {
      status: "processing",
      attemptCount,
      processingStartedAt: FieldValue.serverTimestamp(),
      errorCode: FieldValue.delete(),
      errorMessage: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      attemptCount,
      eventData,
    };
  });

  if (!claimed) {
    return null;
  }

  try {
    const outcome = await db.runTransaction(async (transaction) => {
      const eventSnap = await transaction.get(eventRef);
      if (!eventSnap.exists) {
        return null;
      }

      const currentEvent = eventSnap.data() || {};
      if (
        String(currentEvent.status || "") !== "processing" ||
        Number(currentEvent.attemptCount || 0) !== claimed.attemptCount
      ) {
        return null;
      }

      const sessionRef = db.collection("videoSessions").doc(sessionId);
      const sessionSnap = await transaction.get(sessionRef);
      if (!sessionSnap.exists) {
        transaction.update(eventRef, {
          status: "failed",
          reason: "failed_exception",
          processedAt: FieldValue.serverTimestamp(),
          conversationRef: FieldValue.delete(),
          errorCode: "session_not_found",
          errorMessage: "video session does not exist",
          updatedAt: FieldValue.serverTimestamp(),
        });
        return { status: "failed" };
      }

      const sessionData = sessionSnap.data() || {};
      const eligibility = getUnlockEligibility(sessionData);
      if (!eligibility.eligible) {
        transaction.update(eventRef, {
          status: "ignored",
          reason: eligibility.reason,
          processedAt: FieldValue.serverTimestamp(),
          conversationRef: FieldValue.delete(),
          errorCode: FieldValue.delete(),
          errorMessage: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return { status: "ignored", reason: eligibility.reason };
      }

      const participants = getUnlockParticipants(sessionData);
      const conversationRef = db.collection("conversations").doc(
        eligibility.pairId,
      );
      const conversationSnap = await transaction.get(conversationRef);
      const conversationData = conversationSnap.data() || {};
      const conversationAlreadyUnlocked =
        conversationSnap.exists && conversationData.isUnlocked === true;

      if (!conversationSnap.exists) {
        transaction.set(
          conversationRef,
          buildConversationSeed({
            participants,
            sessionRef,
          }),
        );
      } else {
        const updates = {
          isUnlocked: true,
          updatedAt: FieldValue.serverTimestamp(),
        };

        if (!conversationData.isUnlocked) {
          updates.unlockedAt = FieldValue.serverTimestamp();
          updates.unlockedBySessionRef = sessionRef;
        }

        transaction.set(conversationRef, updates, { merge: true });
      }

      transaction.update(eventRef, {
        status: "processed",
        reason: conversationAlreadyUnlocked
          ? "processed_existing_conversation"
          : "processed_unlocked",
        processedAt: FieldValue.serverTimestamp(),
        conversationRef,
        errorCode: FieldValue.delete(),
        errorMessage: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      return {
        status: "processed",
        conversationRef,
        sessionRef,
        sessionData,
      };
    });

    if (!outcome) {
      return null;
    }

    if (outcome.status === "processed") {
      await maybeWriteCallEventForProcessedOutcome({
        db,
        eventRef,
        sessionId,
        sessionRef: outcome.sessionRef,
        sessionData: outcome.sessionData,
        conversationRef: outcome.conversationRef,
      });
    }

    return outcome;
  } catch (error) {
    await markUnlockEventFailedIfCurrent(eventRef, claimed.attemptCount, error);
    console.error("❌ Error processing unlock event:", {
      sessionId,
      message: error.message,
    });
    return null;
  }
}

async function markUnlockEventFailedIfCurrent(eventRef, attemptCount, error) {
  return admin.firestore().runTransaction(async (transaction) => {
    const eventSnap = await transaction.get(eventRef);
    if (!eventSnap.exists) {
      return null;
    }

    const eventData = eventSnap.data() || {};
    if (
      String(eventData.status || "") !== "processing" ||
      Number(eventData.attemptCount || 0) !== attemptCount
    ) {
      return null;
    }

    transaction.update(eventRef, {
      status: "failed",
      reason: "failed_exception",
      processedAt: FieldValue.serverTimestamp(),
      errorCode: error?.code || "internal",
      errorMessage: error?.message || "Unknown error",
      updatedAt: FieldValue.serverTimestamp(),
    });

    return null;
  });
}

async function repairUnlockEventForSession(sessionRef, sessionData) {
  const db = admin.firestore();
  const sessionId = sessionRef.id;
  const eligibility = getUnlockEligibility(sessionData);
  if (!eligibility.eligible) {
    return null;
  }

  const eventRef = db.collection("conversationUnlockEvents").doc(sessionId);
  return db.runTransaction(async (transaction) => {
    const eventSnap = await transaction.get(eventRef);
    if (!eventSnap.exists) {
      transaction.set(
        eventRef,
        buildUnlockEventPayload({
          sessionId,
          sessionRef,
          participants: eligibility,
          source: "repairMissingConversationUnlockEvents",
        }),
      );
      return { action: "created" };
    }

    const eventData = eventSnap.data() || {};
    if (
      String(eventData.status || "") === "processing" &&
      isStaleUnlockProcessing(eventData)
    ) {
      transaction.update(eventRef, {
        status: "pending",
        source: "repairMissingConversationUnlockEvents",
        processingStartedAt: FieldValue.delete(),
        processedAt: FieldValue.delete(),
        reason: FieldValue.delete(),
        errorCode: FieldValue.delete(),
        errorMessage: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { action: "reset_stale_processing" };
    }

    if (
      String(eventData.status || "") === "pending" &&
      isStaleUnlockPending(eventData)
    ) {
      transaction.update(eventRef, {
        source: "repairMissingConversationUnlockEvents",
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { action: "nudge_pending" };
    }

    if (String(eventData.status || "") === "failed") {
      transaction.update(eventRef, {
        status: "pending",
        source: "repairMissingConversationUnlockEvents",
        processingStartedAt: FieldValue.delete(),
        processedAt: FieldValue.delete(),
        reason: FieldValue.delete(),
        errorCode: FieldValue.delete(),
        errorMessage: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { action: "reset_failed" };
    }

    return {
      action: "noop",
      status: eventData.status || "unknown",
      shouldEnsureCallEvent:
        String(eventData.status || "") === "processed" &&
        !eventData.callEventWrittenAt &&
        !eventData.callEventSkipReason &&
        !!eventData.conversationRef,
      eventRef,
      conversationRef: eventData.conversationRef || null,
    };
  });
}

async function ensureCallEventMessageForProcessedConversation({
  db,
  eventRef,
  sessionId,
  sessionRef,
  sessionData,
  conversationRef,
}) {
  const eligibility = getUnlockEligibility(sessionData);
  if (!eligibility.eligible) {
    return { status: "skipped_ineligible_session", reason: eligibility.reason };
  }

  const messageRef = conversationRef
    .collection("messages")
    .doc(buildCallEventMessageId(sessionId));
  const messagePayload = buildCallEventMessagePayload({
    sessionId,
    sessionRef,
    sessionData,
  });

  return db.runTransaction(async (transaction) => {
    const conversationSnap = await transaction.get(conversationRef);
    if (!conversationSnap.exists || conversationSnap.data()?.isUnlocked !== true) {
      return { status: "skipped_missing_conversation" };
    }

    const conversationData = conversationSnap.data() || {};
    const conversationMatchesSession =
      conversationRef.id === eligibility.pairId &&
      conversationMatchesUnlockParticipants(
        {
          ...conversationData,
          pairId: conversationData.pairId || conversationRef.id,
        },
        eligibility,
      );
    if (!conversationMatchesSession) {
      transaction.set(
        eventRef,
        {
          callEventSkipReason: "conversation_pair_mismatch",
          callEventErrorCode: FieldValue.delete(),
          callEventErrorMessage: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return { status: "skipped_conversation_pair_mismatch" };
    }

    const messageSnap = await transaction.get(messageRef);
    if (!messageSnap.exists) {
      transaction.set(messageRef, messagePayload);
    }

    transaction.set(
      eventRef,
      {
        callEventMessageRef: messageRef,
        callEventWrittenAt: FieldValue.serverTimestamp(),
        callEventSkipReason: FieldValue.delete(),
        callEventErrorCode: FieldValue.delete(),
        callEventErrorMessage: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      status: messageSnap.exists ? "already_exists" : "created",
      messageRef,
    };
  });
}

async function maybeWriteCallEventForProcessedOutcome({
  db,
  eventRef,
  sessionId,
  sessionRef,
  sessionData,
  conversationRef,
}) {
  if (!conversationRef) {
    return { status: "skipped_missing_conversation_ref" };
  }

  if (!isEligibleCallEventSession(sessionData)) {
    await eventRef.set(
      {
        callEventSkipReason: "ignored_pre_call_event_rollout",
        callEventErrorCode: FieldValue.delete(),
        callEventErrorMessage: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { status: "skipped_pre_call_event_rollout" };
  }

  try {
    return await ensureCallEventMessageForProcessedConversation({
      db,
      eventRef,
      sessionId,
      sessionRef,
      sessionData,
      conversationRef,
    });
  } catch (error) {
    await eventRef.set(
      {
        callEventErrorCode: error?.code || "internal",
        callEventErrorMessage: error?.message || "Unknown error",
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    console.error("❌ Error creating conversation call event:", {
      sessionId,
      message: error?.message || "Unknown error",
    });
    return { status: "failed" };
  }
}

exports.__private__ = {
  ensureCallEventMessageForProcessedConversation,
  maybeWriteCallEventForProcessedOutcome,
  processPendingUnlockEvent,
  repairUnlockEventForSession,
};
