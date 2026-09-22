const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {__private__: {joinPassiveSearchCallable: join, leavePassiveSearchCallable: leave,
  connectPassiveSearchCallable: connect}} = require("./passive_search");
const {__private__: {fanoutPassiveSearch: fanout}} = require("./passive_search_notifications");
const {__private__: {startSearchCallable: start}} = require("./start_search");
const {operationId} = require("./passive_search_policy");
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Firestore emulator required");
if (!admin.apps.length) admin.initializeApp({projectId: "demo-smalltalk"});
const db = admin.firestore();
const stamp = admin.firestore.Timestamp.fromMillis;
let nowMillis; let prefix; let count = 0;
const ctx = (uid) => ({auth: {uid}});
const options = () => ({db, now: () => nowMillis});
const ref = (collection, uid) => db.collection(collection).doc(uid);
const consent = (uid) => `consent-${uid}`;
test.beforeEach(() => { nowMillis = Date.now(); prefix = `passive-${nowMillis}-${++count}`; });
async function seed(suffix, active = false, overrides = {}) {
  const uid = `${prefix}-${suffix}`;
  await ref("users", uid).set({role: "student", display_name: suffix, learningLanguage: {code: "en"},
    level: {value: "B1"}, subscription: {productId: "expatlio_1_Month", periodType: "NORMAL",
      expiresAt: stamp(nowMillis + 86400000)}, ...overrides});
  await ref("searchRequests", uid).set({userId: uid, requestId: `search-${uid}`, role: "student",
    language: prefix, filters: {}, status: "active", appState: "foreground", matchProtocolVersion: 2,
    createdAt: stamp(nowMillis - (active ? 1000 : 121000)),
    expiresAt: stamp(nowMillis + (active ? 119000 : -1000)), heartbeatAt: stamp(nowMillis),
    appStateUpdatedAt: stamp(nowMillis), passiveBroadcastReady: true});
  await ref("userPrivateTokens", uid).set({voipToken: `fcm-${uid}`, voipTokenUpdatedAt: stamp(nowMillis)});
  return uid;
}
async function enroll(uid) {
  return join({searchRequestId: `search-${uid}`, requestId: consent(uid), duration: "30", locale: "en"}, ctx(uid), options());
}
const target = (uid, active) => ({requestId: consent(uid), activeUserId: active, activeRequestId: `search-${active}`});
async function realLanguage(...uids) {
  await Promise.all(uids.map((uid) => ref("searchRequests", uid).update({language: "en"})));
}
test("queue survives no heartbeat and duplicate join, stop tombstone blocks late joins", async () => {
  const uid = await seed("waiting"); const first = await enroll(uid);
  nowMillis += 60000; assert.deepEqual(await enroll(uid), first);
  await leave({requestId: consent(uid)}, ctx(uid), options());
  await assert.rejects(enroll(uid), /consent_closed/);
  const other = await seed("early-stop");
  await leave({requestId: consent(other)}, ctx(other), options());
  await assert.rejects(enroll(other), /consent_closed/);
});
test("join rejects early, manual, missing FCM, access denied and foreign source", async () => {
  const early = await seed("early", true); await assert.rejects(enroll(early), /source_search_not_completed/);
  const manual = await seed("manual"); await ref("searchRequests", manual).update({status: "stopped", stopReason: "manual"});
  await assert.rejects(enroll(manual), /source_search_not_completed/);
  const noToken = await seed("token"); await ref("userPrivateTokens", noToken).set({voipPushToken: "pushkit"});
  await assert.rejects(enroll(noToken), /fcm_token_required/);
  const noAccess = await seed("access", false, {subscription: null}); await assert.rejects(enroll(noAccess), /call_access_required/);
  const foreign = await seed("foreign"); await ref("searchRequests", foreign).update({userId: early});
  await assert.rejects(enroll(foreign), /source_search_not_completed/);
});
test("concurrent recipients create one pair; duplicate taps and late stop keep same result", async () => {
  const a = await seed("a"); const b = await seed("b"); const active = await seed("active", true);
  await realLanguage(a, b, active); await enroll(a); await enroll(b);
  const results = await Promise.all([connect(target(a, active), ctx(a), options()), connect(target(b, active), ctx(b), options())]);
  assert.equal(results.filter((r) => r.status === "matched").length, 1);
  assert.equal(results.filter((r) => r.status === "unavailable").length, 1);
  const win = results[0].status === "matched" ? a : b; const lose = win === a ? b : a;
  const result = results.find((r) => r.status === "matched");
  assert.deepEqual(await connect(target(win, active), ctx(win), options()), result);
  assert.equal((await ref("passiveSearches", lose).get()).data().status, "waiting");
  const session = (await ref("videoSessions", result.sessionId).get()).data();
  assert.equal(session.matchProtocolVersion, 2);
  assert.equal(session.participantStates[win].decision, "accepted");
  assert.equal(session.participantStates[active].decision, "accepted");
  assert.equal((await leave({requestId: consent(win)}, ctx(win), options())).sessionId, result.sessionId);
  await assert.rejects(connect(target(win, active), ctx(win), options()), /consent_expired_or_stopped/);
  await leave({requestId: consent(lose)}, ctx(lose), options());
});
test("join/leave and connect/leave races cannot revive consent", async () => {
  const uid = await seed("race");
  await Promise.allSettled([enroll(uid), leave({requestId: consent(uid)}, ctx(uid), options())]);
  assert.equal((await ref("passiveSearchOperations", operationId(uid, consent(uid))).get()).data().status, "stopped");
  const next = await seed("connect-race"); const active = await seed("active", true);
  await realLanguage(next, active); await enroll(next);
  const results = await Promise.allSettled([connect(target(next, active), ctx(next), options()), leave({requestId: consent(next)}, ctx(next), options())]);
  assert.equal(results[1].status, "fulfilled");
  assert.equal((await ref("passiveSearches", next).get()).data().status, "stopped");
  if (results[0].status === "fulfilled" && results[0].value.status === "matched") {
    assert.equal(results[1].value.sessionId, results[0].value.sessionId);
  }
});
test("changed, background, filtered, blocked, expired and foreign targets cannot consume queue", async () => {
  const uid = await seed("waiting"); const active = await seed("active", true);
  await realLanguage(uid, active); await enroll(uid);
  const unavailable = async () => assert.deepEqual(await connect(target(uid, active), ctx(uid), options()), {status: "unavailable"});
  await ref("searchRequests", active).update({appState: "background"}); await unavailable();
  await ref("searchRequests", active).update({appState: "foreground", requestId: "other"}); await unavailable();
  await ref("searchRequests", active).update({requestId: `search-${active}`, filters: {preferredLevel: "C2"}}); await unavailable();
  await ref("searchRequests", active).update({filters: {}});
  await ref("users", uid).update({blockedUsers: [active]}); await unavailable();
  await ref("users", uid).update({blockedUsers: []}); nowMillis += 120000; await unavailable();
  await assert.rejects(connect(target(uid, active), ctx(active), options()), /invalid_target/);
  assert.equal((await ref("passiveSearches", uid).get()).data().status, "waiting");
  await leave({requestId: consent(uid)}, ctx(uid), options());
});
test("fanout paginates all recipients, retries failure and deduplicates before expiry", async () => {
  const active = await seed("active", true); await realLanguage(active); const recipients = [];
  for (let n = 0; n < 5; n++) { const uid = await seed(`waiting-${n}`); await realLanguage(uid); await enroll(uid); recipients.push(uid); }
  const sent = []; let failed = false;
  const dispatch = (send) => fanout({db, activeUserId: active, activeRequestId: `search-${active}`, pageSize: 2, now: () => nowMillis, send});
  await assert.rejects(dispatch(async (message) => { if (!failed) { failed = true; throw new Error("fcm_unavailable"); } sent.push(message); }), /fcm_unavailable/);
  await dispatch(async (message) => sent.push(message));
  assert.equal(sent.length, 5); assert.equal(new Set(sent.map((m) => m.data.recipientId)).size, 5);
  await dispatch(async (message) => sent.push(message)); assert.equal(sent.length, 5);
  assert.ok(sent.every((m) => m.data.type === "partner_available" && m.notification && !m.data.sessionId));
  nowMillis += 120000; await dispatch(async (message) => sent.push(message)); assert.equal(sent.length, 5);
  await Promise.all(recipients.map((uid) => leave({requestId: consent(uid)}, ctx(uid), options())));
});
test("new active attempt cancels passive consent atomically", async () => {
  const uid = await seed("restart"); await realLanguage(uid); await enroll(uid);
  await start({requestId: `new-${uid}`, language: "en", appState: "foreground", platform: "ios", matchProtocolVersion: 2}, ctx(uid), {db});
  assert.equal((await ref("passiveSearches", uid).get()).data().status, "stopped");
  await assert.rejects(enroll(uid), /consent_closed|call_access_required/);
});

test("TTL deletion and stale queue joins cannot reuse the completed source consent", async () => {
  const uid = await seed("ttl"); await enroll(uid);
  assert.equal((await ref("searchRequests", uid).get()).data().passiveConsentRequestId, consent(uid));
  await ref("passiveSearches", uid).delete();
  await assert.rejects(join({searchRequestId: `search-${uid}`, requestId: `new-consent-${uid}`,
    duration: "60", locale: "en"}, ctx(uid), options()), /source_search_not_completed/);
});

test("consent created after active attempt gets an ordinary push exactly once", async () => {
  const {notifyExistingActiveSearches} = require("./passive_search_notifications").__private__;
  const uid = await seed("late-consent"); const active = await seed("active-first", true);
  await realLanguage(uid, active); await enroll(uid);
  const sent = [];
  const result = await notifyExistingActiveSearches({db, recipientId: uid, consentId: consent(uid),
    pageSize: 2, now: () => nowMillis, send: async (message) => sent.push(message)});
  assert.ok(result.sent >= 1);
  assert.equal(sent.filter((m) => m.data.activeUserId === active).length, 1);
  await fanout({db, activeUserId: active, activeRequestId: `search-${active}`,
    now: () => nowMillis, send: async (message) => sent.push(message)});
  assert.equal(sent.filter((m) => m.data.activeUserId === active && m.data.recipientId === uid).length, 1);
  await leave({requestId: consent(uid)}, ctx(uid), options());
});

test("expired consent, cleared token and manual source stop prevent fanout and connect", async () => {
  const uid = await seed("expired-consent"); const active = await seed("active", true);
  await realLanguage(uid, active); await enroll(uid);
  await ref("passiveSearches", uid).update({expiresAt: stamp(nowMillis)});
  await assert.rejects(connect(target(uid, active), ctx(uid), options()), /consent_expired_or_stopped/);
  const sent = [];
  await fanout({db, activeUserId: active, activeRequestId: `search-${active}`, now: () => nowMillis,
    send: async (message) => sent.push(message)});
  assert.equal(sent.some((m) => m.data.recipientId === uid), false);
  await ref("passiveSearches", uid).update({expiresAt: stamp(nowMillis + 100000)});
  await ref("searchRequests", uid).update({status: "stopped", stopReason: "manual"});
  await fanout({db, activeUserId: active, activeRequestId: `search-${active}`, now: () => nowMillis,
    send: async (message) => sent.push(message)});
  assert.equal(sent.some((m) => m.data.recipientId === uid), false);
});
