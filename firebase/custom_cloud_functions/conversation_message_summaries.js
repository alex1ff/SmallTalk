const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {FieldPath, FieldValue} = require("firebase-admin/firestore");
const {
  getChatsRolloutTimestamp,
  getMaintenanceCursorState,
  getMaintenanceJobRef,
  getMessageTuple,
  getRepairPageSize,
  isNewerMessageTuple,
  toMillis,
} = require("./chats_shared");

const SUMMARY_REPAIR_JOB_NAME = "repairConversationMessageSummaries";

exports.updateConversationMessageSummary = functions.firestore
  .document("conversations/{pairId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const messageData = snap.data() || {};
    const serverCreatedAt = snap.createTime || snap.updateTime || null;
    if (String(messageData.type || "") !== "text") {
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

      if (
        !Array.isArray(conversationData.participantIds) ||
        !conversationData.participantIds.includes(messageData.senderId)
      ) {
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
      transaction.update(conversationRef, {
        lastMessageAt: messageData.createdAt,
        lastMessageServerCreatedAt: serverCreatedAt,
        lastMessageText: messageData.text,
        lastMessageSenderId: messageData.senderId,
        lastMessageId: context.params.messageId,
        updatedAt: FieldValue.serverTimestamp(),
      });

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
      conversationData.lastMessageId === newestMessageDoc.id &&
      conversationData.lastMessageText === newestMessageData.text &&
      conversationData.lastMessageSenderId === newestMessageData.senderId
    ) {
      return null;
    }

    if (!newestMessageData.serverCreatedAt && newestServerCreatedAt) {
      transaction.update(newestMessageDoc.ref, {
        serverCreatedAt: newestServerCreatedAt,
      });
    }
    transaction.update(conversationRef, {
      lastMessageAt: newestMessageData.createdAt,
      lastMessageServerCreatedAt: newestServerCreatedAt,
      lastMessageText: newestMessageData.text,
      lastMessageSenderId: newestMessageData.senderId,
      lastMessageId: newestMessageDoc.id,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return null;
  });
}
