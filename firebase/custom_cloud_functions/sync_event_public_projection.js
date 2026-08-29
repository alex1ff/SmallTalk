const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {isDeepStrictEqual} = require("node:util");
const {
  buildEventPreviewData,
  eventPreviewRef,
  shouldReplaceEventPreview,
} = require("./event_public_projection");

const REPAIR_PAGE_SIZE = 200;
const REPAIR_STATE_PATH = "maintenance/eventPublicProjectionRepair";

function sourceRevisionData(snapshot) {
  return snapshot?.updateTime ? {sourceUpdateTime: snapshot.updateTime} : {};
}

function repairCursorValue(value) {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function nextRepairCursor(page, pageSize) {
  if (!page || page.empty || page.size < pageSize) return null;
  return page.docs[page.docs.length - 1].id;
}

function triggerProjectionAction({sourceExists, currentData, incomingData}) {
  if (!sourceExists) return "delete";
  if (currentData && !shouldReplaceEventPreview(currentData, incomingData)) {
    return "noop";
  }
  return "set";
}

function shouldRepairEventPreview(currentData, incomingData) {
  return !isDeepStrictEqual(currentData || {}, incomingData || {});
}

function repairPassMatches(currentPassId, workerPassId) {
  return !currentPassId || currentPassId === workerPassId;
}

exports.syncEventPublicProjection = functions.region("europe-west1").firestore
    .document("events/{eventId}")
    .onWrite(async (change, context) => {
      const eventRef = admin.firestore().collection("events")
          .doc(context.params.eventId);
      const previewRef = eventPreviewRef(admin.firestore(), context.params.eventId);
      await admin.firestore().runTransaction(async (transaction) => {
        // Re-read the source in the transaction. A delayed trigger must
        // project the document's current revision, not stale change.after data.
        const eventSnapshot = await transaction.get(eventRef);
        const previewSnapshot = await transaction.get(previewRef);
        const sourceData = eventSnapshot.exists ? eventSnapshot.data() || {} : {};
        const sourceRevision = sourceRevisionData(eventSnapshot);
        const currentData = previewSnapshot.exists ? previewSnapshot.data() || {} : null;
        const previewData = eventSnapshot.exists ?
          buildEventPreviewData(sourceData, sourceRevision) : null;
        const action = triggerProjectionAction({
          sourceExists: eventSnapshot.exists,
          currentData,
          incomingData: previewData,
        });
        if (action === "delete") {
          // The authoritative source was re-read in this transaction. Delete
          // unconditionally; a concurrent recreate changes the read version
          // and makes Firestore retry the transaction.
          transaction.delete(previewRef);
          return;
        }
        if (action === "noop") return;
        transaction.set(previewRef, previewData, {merge: false});
      });
      return null;
    });

async function repairEventPublicProjections({
  db = admin.firestore(),
  pageSize = REPAIR_PAGE_SIZE,
} = {}) {
  if (!Number.isInteger(pageSize) || pageSize <= 0 || pageSize > 500) {
    throw new RangeError("pageSize must be between 1 and 500");
  }
  const stateRef = db.doc(REPAIR_STATE_PATH);
  const stateSnapshot = await stateRef.get();
  const state = stateSnapshot.exists ? stateSnapshot.data() || {} : {};
  const passId = typeof state.passId === "string" && state.passId.length > 0 ?
    state.passId : "legacy";
  let eventCursor = repairCursorValue(state.eventCursorId);
  let projectionCursor = repairCursorValue(state.projectionCursorId);
  let eventPassComplete = state.eventPassComplete === true;
  let projectionPassComplete = state.projectionPassComplete === true;
  if (eventPassComplete && projectionPassComplete) {
    eventCursor = null;
    projectionCursor = null;
    eventPassComplete = false;
    projectionPassComplete = false;
  }
  let repaired = 0;
  let removedOrphans = 0;

  let eventPage = null;
  if (!eventPassComplete) {
    let eventQuery = db.collection("events")
        .orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (eventCursor) eventQuery = eventQuery.startAfter(eventCursor);
    eventPage = await eventQuery.get();
  }
  for (const doc of eventPage?.docs || []) {
      const previewRef = eventPreviewRef(db, doc.id);
      const didRepair = await db.runTransaction(async (transaction) => {
        const eventSnapshot = await transaction.get(doc.ref);
        const previewSnapshot = await transaction.get(previewRef);
        if (!eventSnapshot.exists) {
          if (previewSnapshot.exists) {
            transaction.delete(previewRef);
            return true;
          }
          return false;
        }
        const previewData = buildEventPreviewData(
          eventSnapshot.data() || {},
          sourceRevisionData(eventSnapshot),
        );
        // Repair is authoritative and must also replace poisoned/corrupt
        // revision markers. A concurrent source change retries the transaction.
        if (previewSnapshot.exists && !shouldRepairEventPreview(
            previewSnapshot.data() || {}, previewData)) return false;
        transaction.set(previewRef, previewData, {merge: false});
        return true;
      });
      if (didRepair) repaired++;
  }

  let projectionPage = null;
  if (!projectionPassComplete) {
    let projectionQuery = db.collection("events_public")
        .orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (projectionCursor) {
      projectionQuery = projectionQuery.startAfter(projectionCursor);
    }
    projectionPage = await projectionQuery.get();
  }
  for (const projectionDoc of projectionPage?.docs || []) {
    const eventRef = db.collection("events").doc(projectionDoc.id);
    const removed = await db.runTransaction(async (transaction) => {
      const eventSnapshot = await transaction.get(eventRef);
      const projectionSnapshot = await transaction.get(projectionDoc.ref);
      if (!eventSnapshot.exists && projectionSnapshot.exists) {
        transaction.delete(projectionDoc.ref);
        return true;
      }
      return false;
    });
    if (removed) removedOrphans++;
  }

  if (eventPage) {
    eventCursor = nextRepairCursor(eventPage, pageSize);
    eventPassComplete = eventCursor == null;
  }
  if (projectionPage) {
    projectionCursor = nextRepairCursor(projectionPage, pageSize);
    projectionPassComplete = projectionCursor == null;
  }
  const passComplete = eventPassComplete && projectionPassComplete;
  const stateCommitted = await db.runTransaction(async (transaction) => {
    const currentStateSnapshot = await transaction.get(stateRef);
    const currentPassId = currentStateSnapshot.exists ?
      currentStateSnapshot.data()?.passId : null;
    if (!repairPassMatches(currentPassId, passId)) return false;
    transaction.set(stateRef, {
      passId,
      eventCursorId: eventCursor,
      projectionCursorId: projectionCursor,
      eventPassComplete,
      projectionPassComplete,
      passCompletedAt: passComplete ?
        admin.firestore.FieldValue.serverTimestamp() : null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
  console.log("✅ Event public projections repaired", {
    repaired,
    removedOrphans,
    eventCursor,
    projectionCursor,
    eventPassComplete,
    projectionPassComplete,
    passId,
    stateCommitted,
  });
  return {
    repaired,
    removedOrphans,
    eventCursor,
    projectionCursor,
    eventPassComplete,
    projectionPassComplete,
    passComplete,
    passId,
    stateCommitted,
  };
}

exports.repairEventPublicProjections = functions
    .runWith({timeoutSeconds: 540, memory: "512MB"})
    .pubsub
    .schedule("every day 04:00")
    .onRun(repairEventPublicProjections);

exports.__private__ = {
  REPAIR_PAGE_SIZE,
  REPAIR_STATE_PATH,
  nextRepairCursor,
  repairCursorValue,
  repairPassMatches,
  repairEventPublicProjections,
  shouldRepairEventPreview,
  sourceRevisionData,
  triggerProjectionAction,
};
