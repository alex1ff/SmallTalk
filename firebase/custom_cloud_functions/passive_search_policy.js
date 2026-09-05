const crypto = require("node:crypto");
const {isVoipTokenFresh} = require("./voip_tokens");
const {ACTIVE_SEARCH_MS, activeSearchDeadlineMillis} = require("./active_search_deadline");
const {normalizeSearchLifecycleRequestId} = require("./search_cancellation_intents");
const {timestampToMillis} = require("./start_search_request_policy");
const {buildStudentQueueCandidateFromDocs, readPreferredLevelRank,
  readPreferredLocation, readBlockedUserIds,
  readSearchRequestExcludedCandidateIds} = require("./match_candidate_pool");

function operationId(userId, requestId) {
  return crypto.createHash("sha256").update(JSON.stringify([userId, requestId])).digest("hex");
}
function validId(value) { return normalizeSearchLifecycleRequestId(value); }
function passiveExpiryMillis({duration, timeZone, nowMillis = Date.now()}) {
  if (duration === "30" || duration === "60") {
    return nowMillis + Number(duration) * 60000;
  }
  if (duration !== "day" || typeof timeZone !== "string" || !timeZone.trim()) {
    throw new Error("invalid_duration_or_timezone");
  }
  // Search the next local date boundary. This handles 23/25-hour days and zones
  // with a midnight DST transition without guessing the current UTC offset.
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone, year: "numeric", month: "2-digit", day: "2-digit",
  });
  const today = formatter.format(nowMillis);
  let low = Math.floor(nowMillis / 1000);
  let high = low + 48 * 3600;
  while (low + 1 < high) {
    const mid = Math.floor((low + high) / 2);
    if (formatter.format(mid * 1000) === today) low = mid;
    else high = mid;
  }
  return high * 1000;
}
function isWaiting(queue = {}, nowMillis = Date.now()) {
  return queue.status === "waiting" && Boolean(validId(queue.requestId)) &&
    (timestampToMillis(queue.expiresAt) || 0) > nowMillis;
}
function sourceAllowsPassive(source = {}, searchRequestId, nowMillis) {
  const deadline = activeSearchDeadlineMillis(source);
  return source.requestId === searchRequestId && deadline !== null &&
    deadline <= nowMillis && !source.currentSessionId &&
    !source.activeSessionId && !source.matchedSessionId &&
    ["active", "searching", "expired"].includes(source.status) &&
    [undefined, null, "", "search_timeout", "heartbeat_stale", "background_timeout"].includes(source.stopReason);
}
function syntheticPassiveSearch(queue, nowMillis, timestampFromMillis) {
  return {
    ...queue, role: "student", status: "active", matchProtocolVersion: 2,
    appState: "foreground", appStateUpdatedAt: timestampFromMillis(nowMillis),
    heartbeatAt: timestampFromMillis(nowMillis), createdAt: timestampFromMillis(nowMillis),
    expiresAt: timestampFromMillis(nowMillis + ACTIVE_SEARCH_MS),
  };
}
function compatiblePair({activeId, active, activeUser, activeTrial,
  passiveId, passive, passiveUser, passiveTrial, nowMillis}) {
  if (active.passiveBroadcastReady !== true || activeId === passiveId || !isWaiting(passive, nowMillis) ||
      passive.userId !== passiveId || active.userId !== activeId ||
      Number(active.matchProtocolVersion) < 2 ||
      activeUser.currentSessionId || passiveUser.currentSessionId) return false;
  const fake = syntheticPassiveSearch(passive, nowMillis, (value) => value);
  const doc = (id, data) => ({id, exists: true, data: () => data});
  const candidate = (id, request, user, trial, otherId, other, otherUser) =>
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc(id, request), userDoc: doc(id, user),
      language: other.language, nowMillis, trialData: trial,
      preferredLevelRank: readPreferredLevelRank(other.filters || {}),
      preferredLocation: readPreferredLocation(other.filters || {}),
      requesterId: otherId, requesterBlockedIds: readBlockedUserIds(otherUser),
      requesterExcludedCandidateIds: readSearchRequestExcludedCandidateIds(other),
    });
  return Boolean(candidate(activeId, active, activeUser, activeTrial,
    passiveId, fake, passiveUser) &&
    candidate(passiveId, fake, passiveUser, passiveTrial,
      activeId, active, activeUser));
}
function normalFcmToken(privateData = {}, userData = {}, nowMillis = Date.now()) {
  if (privateData.voipTokensClearedAt) return "";
  if (typeof privateData.voipToken === "string" &&
      isVoipTokenFresh(privateData.voipTokenUpdatedAt, nowMillis)) {
    return privateData.voipToken.trim();
  }
  if (typeof userData.voipToken === "string" &&
      isVoipTokenFresh(userData.voipTokenUpdatedAt, nowMillis)) {
    return userData.voipToken.trim();
  }
  return "";
}

function buildPartnerAvailableMessage({token, recipientId, passive,
  activeUserId, active, activeUser, nowMillis}) {
  const expiry = Math.min(activeSearchDeadlineMillis(active),
    timestampToMillis(passive.expiresAt));
  const ru = passive.locale === "ru";
  const name = String(activeUser.display_name || activeUser.displayName ||
    activeUser.name || (ru ? "Собеседник" : "A partner")).slice(0, 80);
  const cityValue = activeUser.profileCity?.label || activeUser.profileCity?.name ||
    activeUser.cityName || activeUser.city ||
    activeUser.location?.cityName || activeUser.location?.city;
  const city = typeof cityValue === "string" ? cityValue.trim().slice(0, 80) : "";
  const who = city ? `${name} ${ru ? "из" : "from"} ${city}` : name;
  return {
    token,
    notification: {
      title: ru ? "Собеседник найден" : "A partner is available",
      body: ru ? `${who} ждет собеседника. Подключитесь прямо сейчас` :
        `${who} is waiting for a partner. Connect now`,
    },
    data: {type: "partner_available", recipientId,
      requestId: passive.requestId, activeUserId,
      activeRequestId: active.requestId, expiresAt: new Date(expiry).toISOString()},
    android: {ttl: Math.max(0, expiry - nowMillis),
      collapseKey: operationId(recipientId, passive.requestId)},
    apns: {headers: {"apns-push-type": "alert", "apns-priority": "10",
      "apns-expiration": String(Math.floor(expiry / 1000)),
      "apns-collapse-id": operationId(recipientId, passive.requestId)},
    payload: {aps: {sound: "default"}}},
  };
}
module.exports = {operationId, validId, passiveExpiryMillis, isWaiting,
  sourceAllowsPassive, syntheticPassiveSearch, compatiblePair, normalFcmToken,
  buildPartnerAvailableMessage};
