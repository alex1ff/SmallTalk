const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const crypto = require("node:crypto");
const {trialAccessRef} = require("./trial_access");
const {validateActiveStudentSearchRequest} = require("./match_candidate_pool");
const {loadSameDayRepeatCandidateIdsForTransaction} = require("./match_repeat_prevention");
const {operationId, compatiblePair, normalFcmToken, isWaiting, sourceAllowsPassive,
  buildPartnerAvailableMessage} = require("./passive_search_policy");

async function readEligiblePair(tx, db, activeId, activeRequestId, recipientId,
  consentId, nowMillis) {
  const [active, passive, activeUser, passiveUser, activeTrial, passiveTrial, token, source] =
    await Promise.all([
      db.collection("searchRequests").doc(activeId),
      db.collection("passiveSearches").doc(recipientId),
      db.collection("users").doc(activeId), db.collection("users").doc(recipientId),
      trialAccessRef(db, activeId), trialAccessRef(db, recipientId),
      db.collection("userPrivateTokens").doc(recipientId),
      db.collection("searchRequests").doc(recipientId),
    ].map((ref) => tx.get(ref)));
  const pair = {activeId, active: active.data() || {},
    passiveId: recipientId, passive: passive.data() || {},
    activeUser: activeUser.data() || {}, passiveUser: passiveUser.data() || {},
    activeTrial: activeTrial.data() || null, passiveTrial: passiveTrial.data() || null,
    nowMillis};
  if (pair.active.passiveBroadcastReady !== true || pair.active.requestId !== activeRequestId || pair.passive.requestId !== consentId ||
      !sourceAllowsPassive(source.data(), pair.passive.sourceSearchRequestId, nowMillis) ||
      !compatiblePair(pair)) return null;
  const fcmToken = normalFcmToken(token.data(), pair.passiveUser, nowMillis);
  if (!fcmToken) return null;
  const repeat = await loadSameDayRepeatCandidateIdsForTransaction(tx, db,
    activeId, [recipientId], {requesterEmail: pair.activeUser.email,
      userEmailsById: {[recipientId]: pair.passiveUser.email}});
  return repeat.excludedCandidateIds.has(recipientId) ? null : {...pair, token: fcmToken};
}
async function notifyRecipient({db, activeId, activeRequestId, recipientId,
  consentId, send, now}) {
  const deliveryId = operationId(operationId(recipientId, consentId),
    operationId(activeId, activeRequestId));
  const ref = db.collection("passiveSearchDeliveries").doc(deliveryId);
  const dispatchId = crypto.randomUUID();
  const claimed = await db.runTransaction(async (tx) => {
    const prior = await tx.get(ref);
    const value = prior.data() || {};
    const nowMillis = now();
    if (value.status === "sent") return false;
    if (value.status === "dispatching" && value.leaseExpiresAt.toMillis() > nowMillis) {
      // Retry the event after a crashed sender's lease, even with no heartbeat.
      throw new Error("passive_dispatch_in_progress");
    }
    const pair = await readEligiblePair(tx, db, activeId, activeRequestId,
      recipientId, consentId, nowMillis);
    if (!pair) return false;
    tx.set(ref, {recipientId, consentId, activeId, activeRequestId, dispatchId,
      status: "dispatching", leaseExpiresAt: admin.firestore.Timestamp.fromMillis(nowMillis + 30000),
      attempts: (value.attempts || 0) + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()});
    return true;
  });
  if (!claimed) return false;
  try {
    // Re-read versions, access, availability and both deadlines immediately
    // before the external send; TTL cleanup is never an authorization check.
    const pair = await db.runTransaction(async (tx) => {
      const delivery = await tx.get(ref);
      if (delivery.data()?.dispatchId !== dispatchId) return null;
      return readEligiblePair(tx, db, activeId, activeRequestId, recipientId, consentId, now());
    });
    if (!pair) {
      await db.runTransaction(async (tx) => {
        const latest = await tx.get(ref);
        if (latest.data()?.dispatchId === dispatchId) tx.update(ref, {status: "obsolete"});
      });
      return false;
    }
    const message = buildPartnerAvailableMessage({token: pair.token, recipientId,
      passive: pair.passive, activeUserId: activeId,
      active: pair.active, activeUser: pair.activeUser, nowMillis: now()});
    if (message.android.ttl <= 0) {
      await db.runTransaction(async (tx) => {
        const latest = await tx.get(ref);
        if (latest.data()?.dispatchId === dispatchId) tx.update(ref, {status: "obsolete"});
      });
      return false;
    }
    await send(message);
    await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      if (snapshot.data()?.dispatchId === dispatchId) tx.update(ref, {
        status: "sent", sentAt: admin.firestore.FieldValue.serverTimestamp()});
    });
    return true;
  } catch (error) {
    await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      if (snapshot.data()?.dispatchId === dispatchId) tx.update(ref, {
        status: "failed", updatedAt: admin.firestore.FieldValue.serverTimestamp()});
    });
    throw error;
  }
}
async function fanoutPassiveSearch({db = admin.firestore(), activeUserId,
  activeRequestId, now = Date.now, pageSize = 100,
  send = (message) => admin.messaging().send(message)}) {
  const active = await db.collection("searchRequests").doc(activeUserId).get();
  const data = active.data() || {};
  if (data.passiveBroadcastReady !== true || data.requestId !== activeRequestId ||
      !validateActiveStudentSearchRequest(data, now()).valid) return {sent: 0};
  const query = db.collection("passiveSearches").where("status", "==", "waiting")
    .where("language", "==", data.language).orderBy(admin.firestore.FieldPath.documentId());
  let cursor = null;
  let sent = 0;
  let failure = null;
  while (true) {
    const page = await (cursor ? query.startAfter(cursor) : query).limit(pageSize).get();
    if (page.empty) break;
    for (const recipient of page.docs) {
      try {
        if (await notifyRecipient({db, activeId: activeUserId, activeRequestId,
          recipientId: recipient.id, consentId: recipient.data().requestId, send, now})) sent++;
      } catch (error) { failure = error; }
    }
    cursor = page.docs[page.docs.length - 1];
    if (page.size < pageSize) break;
  }
  if (failure) throw failure; // Firestore retries failed delivery records safely.
  return {sent};
}
exports.notifyPassiveSearchPartners = functions.runWith({timeoutSeconds: 540,
  failurePolicy: true}).firestore.document("searchRequests/{userId}")
  .onWrite((change, context) => {
    if (!change.after.exists) return null;
    return fanoutPassiveSearch({activeUserId: context.params.userId,
      activeRequestId: change.after.data().requestId});
  });
async function notifyExistingActiveSearches({db = admin.firestore(), recipientId,
  consentId, now = Date.now, pageSize = 100,
  send = (message) => admin.messaging().send(message)}) {
  const snapshot = await db.collection("passiveSearches").doc(recipientId).get();
  const passive = snapshot.data() || {};
  if (passive.requestId !== consentId || !isWaiting(passive, now())) return {sent: 0};
  // A consent written concurrently with an active search cannot miss that
  // already-created attempt. Both triggers share the same delivery key.
  const query = db.collection("searchRequests").where("status", "==", "active")
    .where("role", "==", "student").where("language", "==", passive.language)
    .orderBy("createdAt", "asc");
  let cursor = null;
  let sent = 0;
  let failure = null;
  while (true) {
    const page = await (cursor ? query.startAfter(cursor) : query).limit(pageSize).get();
    if (page.empty) break;
    for (const active of page.docs) {
      try {
        if (await notifyRecipient({db, activeId: active.id,
          activeRequestId: active.data().requestId, recipientId, consentId, now, send})) sent++;
      } catch (error) { failure = error; }
    }
    cursor = page.docs[page.docs.length - 1];
    if (page.size < pageSize) break;
  }
  if (failure) throw failure;
  return {sent};
}
exports.notifyPassiveSearchOnJoin = functions.runWith({timeoutSeconds: 540,
  failurePolicy: true}).firestore.document("passiveSearches/{userId}")
  .onWrite((change, context) => {
    if (!change.after.exists) return null;
    const after = change.after.data();
    const before = change.before.data() || {};
    if (after.status !== "waiting" ||
        (before.status === "waiting" && before.requestId === after.requestId)) return null;
    return notifyExistingActiveSearches({recipientId: context.params.userId,
      consentId: after.requestId});
  });
exports.__private__ = {fanoutPassiveSearch, notifyRecipient, notifyExistingActiveSearches};
