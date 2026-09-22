const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {FieldPath, FieldValue} = require("firebase-admin/firestore");
const {
  CONVERSATION_MESSAGE_TYPE_CALL_EVENT,
  buildConversationParticipantMap,
  buildConversationSummaryUpdate,
  canMessageUpdateConversationSummary,
  conversationMatchesUnlockParticipants,
  getChatsRolloutTimestamp,
  getUnlockEligibility,
  getMaintenanceCursorState,
  getMaintenanceJobRef,
  getMessageTuple,
  getRepairPageSize,
  isSupportedConversationMessageType,
  isNewerMessageTuple,
  toMillis,
} = require("./chats_shared");

const SUMMARY_REPAIR_JOB_NAME = "repairConversationMessageSummaries";

function mapsEqual(left = {}, right = {}) {
  const leftKeys = Object.keys(left || {}).sort();
  const rightKeys = Object.keys(right || {}).sort();
  if (leftKeys.length !== rightKeys.length) {
    return false;
  }
  return leftKeys.every((key, index) =>
    key === rightKeys[index] && left[key] === right[key]);
}

function buildParticipantMapRepair(conversationData = {}) {
  if (!Array.isArray(conversationData.participantIds) ||
      conversationData.participantIds.length === 0) {
    return null;
  }
  const participantMap =
    buildConversationParticipantMap(conversationData.participantIds);
  if (mapsEqual(conversationData.participantMap, participantMap)) {
    return null;
  }
  return participantMap;
}

exports.updateConversationMessageSummary = functions.firestore
  .document("conversations/{pairId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const messageData = snap.data() || {};
    const serverCreatedAt = snap.createTime || snap.updateTime || null;
    if (!isSupportedConversationMessageType(messageData.type)) {
      return null;
    }

    const messageTuple = getMessageTuple(context.params.messageId, {
      ...messageData,
      serverCreatedAt,
    });
    if (toMillis(messageTuple.createdAt) <= 0) {
      return null;
    }

    const conversationRef = snap.ref.parent.parent;
    if (!conversationRef) {
      return null;
    }

    await admin.firestore().runTransaction(async (transaction) => {
      const conversationSnap = await transaction.get(conversationRef);
      if (!conversationSnap.exists) {
        return null;
      }

      const conversationData = conversationSnap.data() || {};
      if (!conversationData.isUnlocked) {
        return null;
      }
      const repairedParticipantMap =
        buildParticipantMapRepair(conversationData);
      if (repairedParticipantMap) {
        transaction.set(
          conversationRef,
          {participantMap: repairedParticipantMap},
          {merge: true},
        );
      }

      const messageCanUpdateSummary =
        await messageCanUpdateConversationSummary({
          transaction,
          messageData,
          conversationData,
          pairId: context.params.pairId,
        });
      if (!messageCanUpdateSummary) {
        return null;
      }

      const currentTuple = {
        createdAt: conversationData.lastMessageAt || null,
        serverCreatedAt: conversationData.lastMessageServerCreatedAt || null,
        messageId: conversationData.lastMessageId || "",
      };

      if (!isNewerMessageTuple(messageTuple, currentTuple)) {
        return null;
      }

      transaction.update(snap.ref, {
        serverCreatedAt,
      });
      transaction.update(
        conversationRef,
        buildConversationSummaryUpdate({
          messageId: context.params.messageId,
          messageData,
          serverCreatedAt,
        }),
      );

      return null;
    });

    return null;
  });

exports.repairConversationMessageSummaries = functions
  .pubsub.schedule("every 10 minutes")
  .onRun(async () => {
    const db = admin.firestore();
    const rolloutTimestamp = getChatsRolloutTimestamp();
    const pageSize = getRepairPageSize();
    const stateRef = getMaintenanceJobRef(SUMMARY_REPAIR_JOB_NAME);
    const stateSnap = await stateRef.get();
    const cursorState = getMaintenanceCursorState(stateSnap);

    let query = db
      .collection("conversations")
      .where("updatedAt", ">=", rolloutTimestamp)
      .orderBy("updatedAt", "asc")
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

    for (const conversationDoc of pageSnap.docs) {
      await repairConversationSummary(conversationDoc.ref);
    }

    const lastDoc = pageSnap.docs[pageSnap.docs.length - 1];
    await stateRef.set(
      {
        cursorCreatedAt: lastDoc.get("updatedAt") || null,
        cursorDocumentId: lastDoc.id,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return null;
  });

async function repairConversationSummary(conversationRef) {
  const db = admin.firestore();

  return db.runTransaction(async (transaction) => {
    const conversationSnap = await transaction.get(conversationRef);
    if (!conversationSnap.exists) {
      return null;
    }

    const conversationData = conversationSnap.data() || {};
    if (!conversationData.isUnlocked) {
      return null;
    }
    const repairedParticipantMap =
      buildParticipantMapRepair(conversationData);
    if (repairedParticipantMap) {
      transaction.set(
        conversationRef,
        {participantMap: repairedParticipantMap},
        {merge: true},
      );
    }

    let newestMessageSnap = await transaction.get(
        conversationRef
          .collection("messages")
          .orderBy("createdAt", "desc")
          .orderBy("serverCreatedAt", "desc")
          .orderBy(FieldPath.documentId(), "desc")
          .limit(1),
    );
    if (newestMessageSnap.empty) {
      newestMessageSnap = await transaction.get(
        conversationRef
          .collection("messages")
          .orderBy("createdAt", "desc")
          .orderBy(FieldPath.documentId(), "desc")
          .limit(1),
      );
    }
    if (newestMessageSnap.empty) {
      return null;
    }

    const newestMessageDoc = newestMessageSnap.docs[0];
    const newestMessageData = newestMessageDoc.data() || {};
    const newestServerCreatedAt =
      newestMessageData.serverCreatedAt || newestMessageDoc.createTime || null;
    if (
      !isSupportedConversationMessageType(newestMessageData.type)
    ) {
      return null;
    }
    const messageCanUpdateSummary =
      await messageCanUpdateConversationSummary({
        transaction,
        messageData: newestMessageData,
        conversationData,
        pairId: conversationRef.id,
      });
    if (!messageCanUpdateSummary) {
      return null;
    }
    const newestTuple = getMessageTuple(newestMessageDoc.id, {
      ...newestMessageData,
      serverCreatedAt: newestServerCreatedAt,
    });
    const currentTuple = {
      createdAt: conversationData.lastMessageAt || null,
      serverCreatedAt: conversationData.lastMessageServerCreatedAt || null,
      messageId: conversationData.lastMessageId || "",
    };

    if (!isNewerMessageTuple(newestTuple, currentTuple)) {
      return null;
    }

    if (
      toMillis(conversationData.lastMessageAt) === toMillis(newestMessageData.createdAt) &&
      toMillis(conversationData.lastMessageServerCreatedAt) ===
        toMillis(newestServerCreatedAt) &&
      conversationData.lastMessageType === newestMessageData.type &&
      conversationData.lastMessageId === newestMessageDoc.id &&
      conversationData.lastMessageText === newestMessageData.text &&
      conversationData.lastMessageSenderId === newestMessageData.senderId &&
      conversationData.lastCallOutcome === newestMessageData.callOutcome &&
      conversationData.lastCallCallerId === newestMessageData.callerId &&
      conversationData.lastCallRecipientId === newestMessageData.recipientId
    ) {
      return null;
    }

    if (!newestMessageData.serverCreatedAt && newestServerCreatedAt) {
      transaction.update(newestMessageDoc.ref, {
        serverCreatedAt: newestServerCreatedAt,
      });
    }
    transaction.update(
      conversationRef,
      buildConversationSummaryUpdate({
        messageId: newestMessageDoc.id,
        messageData: newestMessageData,
        serverCreatedAt: newestServerCreatedAt,
      }),
    );

    return null;
  });
}

async function messageCanUpdateConversationSummary({
  transaction,
  messageData = {},
  conversationData = {},
  pairId = "",
}) {
  if (!canMessageUpdateConversationSummary(messageData, conversationData)) {
    return false;
  }

  if (messageData.type !== CONVERSATION_MESSAGE_TYPE_CALL_EVENT) {
    return true;
  }

  const sessionRef = messageData.sessionRef || null;
  if (!sessionRef || typeof sessionRef.path !== "string") {
    return false;
  }

  const sessionSnap = await transaction.get(sessionRef);
  if (!sessionSnap.exists) {
    return false;
  }

  const eligibility = getUnlockEligibility(sessionSnap.data() || {});
  if (!eligibility.eligible || eligibility.pairId !== pairId) {
    return false;
  }

  return conversationMatchesUnlockParticipants(
    {
      ...conversationData,
      pairId: conversationData.pairId || pairId,
    },
    eligibility,
  );
}
