const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {buildStudentCallAccessDecision} = require("./call_access");
const {trialAccessRef} = require("./trial_access");
const {reserveMatchPairInTransaction} = require("./match_pair_lock");
const {loadSameDayRepeatCandidateIdsForTransaction} = require("./match_repeat_prevention");
const {buildStudentPairSessionData} = require("./start_search_matcher");
const {operationId, validId, passiveExpiryMillis, isWaiting, sourceAllowsPassive,
  syntheticPassiveSearch, compatiblePair, normalFcmToken} = require("./passive_search_policy");

function fail(reason, code = "failed-precondition") {
  throw new functions.https.HttpsError(code, reason, {reason});
}
function caller(context, data = {}) {
  if (!context?.auth?.uid) fail("authentication_required", "unauthenticated");
  if (!data || !validId(data.requestId) || validId(data.requestId) !== data.requestId) fail("invalid_request_id", "invalid-argument");
  return context.auth.uid;
}
function refs(db, uid, requestId) {
  return {queue: db.collection("passiveSearches").doc(uid),
    op: db.collection("passiveSearchOperations").doc(operationId(uid, requestId)),
    user: db.collection("users").doc(uid),
    search: db.collection("searchRequests").doc(uid),
    trial: trialAccessRef(db, uid),
    token: db.collection("userPrivateTokens").doc(uid)};
}
function requireAccess(user, trial, nowMillis) {
  const decision = buildStudentCallAccessDecision({userRole: user.role,
    userData: user, trialData: trial, nowMillis});
  if (user.role !== "student" || !decision.allowed) {
    fail("call_access_required", "permission-denied");
  }
}
async function joinPassiveSearchCallable(data, context, {db = admin.firestore(),
  now = Date.now} = {}) {
  const uid = caller(context, data);
  if (!validId(data.searchRequestId) || !["ru", "en"].includes(data.locale)) {
    fail("invalid_passive_search", "invalid-argument");
  }
  let expiresMillis;
  try { expiresMillis = passiveExpiryMillis({...data, nowMillis: now()}); }
  catch (_) { fail("invalid_duration_or_timezone", "invalid-argument"); }
  const r = refs(db, uid, data.requestId);
  return db.runTransaction(async (tx) => {
    const [queue, op, user, search, trial, token] = await Promise.all(
      [r.queue, r.op, r.user, r.search, r.trial, r.token].map((ref) => tx.get(ref)));
    const current = queue.data() || {};
    const nowMillis = now();
    requireAccess(user.data() || {}, trial.data() || null, nowMillis);
    if (op.exists) {
      if (op.data().status === "waiting" && current.requestId === data.requestId &&
          isWaiting(current, nowMillis)) {
        return {status: "waiting", requestId: data.requestId,
          expiresAt: current.expiresAt.toDate().toISOString()};
      }
      fail("consent_closed");
    }
    if (!sourceAllowsPassive(search.data(), data.searchRequestId, nowMillis) ||
        search.data()?.userId !== uid || search.data()?.passiveConsentRequestId ||
        user.data()?.currentSessionId) {
      fail("source_search_not_completed");
    }
    if (!normalFcmToken(token.data(), user.data(), nowMillis)) fail("fcm_token_required");
    if (isWaiting(current, nowMillis)) fail("passive_search_already_waiting");
    if (expiresMillis <= nowMillis) fail("consent_expired");
    const source = search.data();
    const next = {userId: uid, requestId: data.requestId,
      sourceSearchRequestId: data.searchRequestId, language: source.language,
      filters: source.filters || {}, locale: data.locale, status: "waiting",
      excludedCandidateIds: source.excludedCandidateIds || [],
      attemptExcludedCandidateIds: source.attemptExcludedCandidateIds || [],
      expiresAt: admin.firestore.Timestamp.fromMillis(expiresMillis),
      createdAt: admin.firestore.FieldValue.serverTimestamp()};
    tx.update(r.search, {passiveConsentRequestId: data.requestId});
    tx.set(r.queue, next);
    // Durable per-operation records also prevent delayed requests from older
    // consent versions reviving a queue after its owner has moved on.
    tx.set(r.op, {userId: uid, requestId: data.requestId, status: "waiting",
      sourceSearchRequestId: data.searchRequestId, createdAt: next.createdAt});
    return {status: "waiting", requestId: data.requestId,
      expiresAt: new Date(expiresMillis).toISOString()};
  });
}
async function leavePassiveSearchCallable(data, context, {db = admin.firestore()} = {}) {
  const uid = caller(context, data);
  const r = refs(db, uid, data.requestId);
  return db.runTransaction(async (tx) => {
    const [queue, op] = await Promise.all([tx.get(r.queue), tx.get(r.op)]);
    const current = queue.data() || {};
    const sessionId = op.data()?.sessionId ||
      (current.requestId === data.requestId ? current.sessionId : null);
    const update = {userId: uid, requestId: data.requestId, status: "stopped",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(sessionId ? {sessionId} : {})};
    tx.set(r.op, update, {merge: true});
    if (current.requestId === data.requestId) tx.set(r.queue, update, {merge: true});
    return {status: "stopped", requestId: data.requestId,
      ...(sessionId ? {sessionId} : {})};
  });
}
async function connectPassiveSearchCallable(data, context, {db = admin.firestore(),
  now = Date.now} = {}) {
  const uid = caller(context, data);
  if (!validId(data.activeUserId) || !validId(data.activeRequestId) ||
      data.activeUserId === uid) fail("invalid_target", "invalid-argument");
  const r = refs(db, uid, data.requestId);
  const target = refs(db, data.activeUserId, data.activeRequestId);
  const sessionRef = db.collection("videoSessions").doc();
  return db.runTransaction(async (tx) => {
    const [queue, op, user, trial, activeSearch, activeUser, activeTrial, source] =
      await Promise.all([r.queue, r.op, r.user, r.trial, target.search,
        target.user, target.trial, r.search].map((ref) => tx.get(ref)));
    const operation = op.data() || {};
    if (operation.status === "matched" &&
        operation.activeUserId === data.activeUserId &&
        operation.activeRequestId === data.activeRequestId) return operation.result;
    const passive = queue.data() || {};
    const nowMillis = now();
    if (operation.status !== "waiting" || passive.requestId !== data.requestId ||
        !isWaiting(passive, nowMillis)) fail("consent_expired_or_stopped");
    requireAccess(user.data() || {}, trial.data() || null, nowMillis);
    const active = activeSearch.data() || {};
    if (active.requestId !== data.activeRequestId ||
        !sourceAllowsPassive(source.data(), passive.sourceSearchRequestId, nowMillis) ||
        !compatiblePair({activeId: data.activeUserId, active,
          activeUser: activeUser.data() || {}, activeTrial: activeTrial.data() || null,
          passiveId: uid, passive, passiveUser: user.data() || {},
          passiveTrial: trial.data() || null, nowMillis})) return {status: "unavailable"};
    const repeat = await loadSameDayRepeatCandidateIdsForTransaction(tx, db,
      data.activeUserId, [uid], {requesterEmail: activeUser.data()?.email,
        userEmailsById: {[uid]: user.data()?.email}});
    if (repeat.excludedCandidateIds.has(uid)) return {status: "unavailable"};
    const requestData = syntheticPassiveSearch(passive, nowMillis,
      admin.firestore.Timestamp.fromMillis);
    const lock = await reserveMatchPairInTransaction({db, transaction: tx, now,
      requesterId: data.activeUserId, responderId: uid, responderRole: "student",
      requesterSearchRequestId: data.activeRequestId,
      responderSearchRequestId: data.requestId, expectedLanguage: passive.language,
      sessionRef, sessionData: buildStudentPairSessionData({
        requesterId: data.activeUserId, requestData: active,
        selectedCandidate: {userId: uid, role: "student",
          searchRequestId: data.requestId}, nowMillis}),
      nowMillis, serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      lockExpiresAt: admin.firestore.Timestamp.fromMillis(nowMillis + 45000),
      finalizationExpiresAt: admin.firestore.Timestamp.fromMillis(nowMillis + 90000),
      passiveResponder: {sourceSearchRequestId: passive.sourceSearchRequestId, requestData},
    });
    if (!lock.locked) return {status: "unavailable"};
    const result = {status: "matched", sessionId: lock.sessionId,
      pairAttemptId: lock.pairAttemptId, matchProtocolVersion: 2};
    const update = {...result, activeUserId: data.activeUserId,
      activeRequestId: data.activeRequestId, result,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()};
    tx.set(r.queue, update, {merge: true});
    tx.set(r.op, update, {merge: true});
    return result;
  });
}
exports.joinPassiveSearch = functions.https.onCall(joinPassiveSearchCallable);
exports.leavePassiveSearch = functions.https.onCall(leavePassiveSearchCallable);
exports.connectPassiveSearch = functions.https.onCall(connectPassiveSearchCallable);
exports.__private__ = {joinPassiveSearchCallable, leavePassiveSearchCallable,
  connectPassiveSearchCallable};
