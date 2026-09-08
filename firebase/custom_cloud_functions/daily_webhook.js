const crypto = require("crypto");
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {defineSecret} = require("firebase-functions/params");
const {
  buildAcceptedSessionPolicyState,
  getAcceptedSessionCredentialParticipantIds,
  isAcceptedSessionCredentialParticipant,
  isCredentialSessionStatus,
  isCredentialSessionUnexpired,
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  getDailyRoomPresence,
  __private__: {
    dailyPresenceHasAcceptedParticipants,
  },
} = require("./daily_room");
const {
  stopSessionSearchRequestsInTransaction,
} = require("./match_pair_lock");
const {
  markSessionTrialCallContextsConnectedInTransaction,
  readSessionTrialCallContextsInTransaction,
} = require("./trial_access");
const {
  buildRoomJoinParticipantMetadata,
} = require("./room_join_signals");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "daily_webhook"});

const dailyWebhookSecret = defineSecret("DAILY_WEBHOOK_SECRET");
const dailyApiSecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const DAILY_WEBHOOK_REPLAY_WINDOW_MS = 5 * 60 * 1000;
const DAILY_WEBHOOK_SUPPORTED_EVENT_TYPES = new Set([
  "participant.joined",
]);

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function readHeader(req, name) {
  const value = req?.headers?.[name.toLowerCase()];
  if (Array.isArray(value)) {
    return normalizeString(value[0]);
  }
  return normalizeString(value);
}

function parseUnixSecondsToMillis(value) {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) {
    return null;
  }
  return Math.floor(number * 1000);
}

function parseDailyWebhookEvent(rawBody) {
  if (!rawBody || typeof rawBody !== "object" || Array.isArray(rawBody)) {
    return null;
  }

  const type = normalizeString(rawBody.type);
  const eventId = normalizeString(rawBody.id);
  const payload =
    rawBody.payload && typeof rawBody.payload === "object" ?
      rawBody.payload :
      null;
  if (!type || !eventId || !payload) {
    return null;
  }

  const roomName = normalizeString(payload.room);
  const userId = normalizeString(payload.user_id);
  const dailySessionId = normalizeString(payload.session_id);
  const eventTsMillis = parseUnixSecondsToMillis(rawBody.event_ts);
  const joinedAtMillis = parseUnixSecondsToMillis(payload.joined_at);

  return {
    type,
    eventId,
    roomName,
    userId,
    dailySessionId,
    eventTsMillis,
    joinedAtMillis,
    owner: payload.owner === true,
  };
}

function isDailyWebhookVerificationRequest(rawBody) {
  return rawBody &&
    typeof rawBody === "object" &&
    !Array.isArray(rawBody) &&
    rawBody.test === "test";
}

function maybeHandleDailyWebhookVerificationRequest(req, res) {
  if (!isDailyWebhookVerificationRequest(req.body)) {
    return false;
  }

  res.status(200).send("OK");
  return true;
}

function isFreshDailyWebhookTimestamp(timestampHeader, nowMillis = Date.now()) {
  const timestampSeconds = Number(timestampHeader);
  if (!Number.isFinite(timestampSeconds) || timestampSeconds <= 0) {
    return false;
  }

  const timestampMillis = Math.floor(timestampSeconds * 1000);
  return Math.abs(nowMillis - timestampMillis) <=
    DAILY_WEBHOOK_REPLAY_WINDOW_MS;
}

function computeDailyWebhookSignature({
  event,
  secret,
  timestampHeader,
}) {
  const normalizedSecret = normalizeString(secret);
  const normalizedTimestamp = normalizeString(timestampHeader);
  if (!event || !normalizedSecret || !normalizedTimestamp) {
    return "";
  }

  const decodedSecret = Buffer.from(normalizedSecret, "base64");
  return crypto
    .createHmac("sha256", decodedSecret)
    .update(`${normalizedTimestamp}.${JSON.stringify(event)}`)
    .digest("base64");
}

function timingSafeEqualStrings(left, right) {
  const leftBuffer = Buffer.from(normalizeString(left));
  const rightBuffer = Buffer.from(normalizeString(right));
  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }
  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function isValidDailyWebhookSignature({
  event,
  secret,
  signatureHeader,
  timestampHeader,
  nowMillis = Date.now(),
}) {
  if (!isFreshDailyWebhookTimestamp(timestampHeader, nowMillis)) {
    return false;
  }

  const expectedSignature = computeDailyWebhookSignature({
    event,
    secret,
    timestampHeader,
  });
  if (!expectedSignature) {
    return false;
  }

  return timingSafeEqualStrings(expectedSignature, signatureHeader);
}

function readSessionMetadata(sessionData = {}) {
  const metadata = sessionData.sessionMetadata;
  if (!metadata || typeof metadata !== "object" || Array.isArray(metadata)) {
    return {};
  }
  return metadata;
}

function readDailyWebhookParticipantSignals(sessionMetadata = {}) {
  const signals = sessionMetadata.dailyWebhookParticipantSignals;
  if (!signals || typeof signals !== "object" || Array.isArray(signals)) {
    return {};
  }
  return signals;
}

function timestampToMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : null;
  }
  if (value instanceof Date) {
    const millis = value.getTime();
    return Number.isFinite(millis) ? millis : null;
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }
  return null;
}

function pickEarlierTimestamp(left, right) {
  const leftMillis = timestampToMillis(left);
  const rightMillis = timestampToMillis(right);
  if (
    leftMillis !== null &&
    (rightMillis === null || leftMillis <= rightMillis)
  ) {
    return left;
  }
  return right || left || null;
}

function getDailyWebhookSignalJoinMillis(signal = {}) {
  return timestampToMillis(signal.joinedAt) ?? timestampToMillis(signal.eventTs);
}

function buildDailyWebhookParticipantSignal({
  existingSignal = {},
  event = {},
  eventJoinedAt = null,
  eventTs = null,
  receivedAt,
}) {
  const normalizedExisting =
    existingSignal && typeof existingSignal === "object" &&
    !Array.isArray(existingSignal) ?
      existingSignal :
      {};

  return {
    eventId: event.eventId,
    dailySessionId: event.dailySessionId || null,
    joinedAt: pickEarlierTimestamp(normalizedExisting.joinedAt, eventJoinedAt),
    eventTs: pickEarlierTimestamp(normalizedExisting.eventTs, eventTs),
    owner: event.owner === true,
    source: "dailyWebhook",
    receivedAt,
  };
}

function areAcceptedDailyWebhookJoinsBeforeDeadline({
  sessionData = {},
  participantIds = [],
  signals = {},
}) {
  if (sessionData.status !== VIDEO_SESSION_STATUS.CONNECTING) {
    return true;
  }
  const joinDeadlineMillis = timestampToMillis(sessionData.joinDeadlineAt);
  if (joinDeadlineMillis === null) {
    return false;
  }
  return participantIds.every((participantId) => {
    const joinMillis = getDailyWebhookSignalJoinMillis(signals[participantId]);
    return joinMillis !== null && joinMillis < joinDeadlineMillis;
  });
}

function isDailyWebhookSessionCurrentForProcessing(
  sessionData = {},
  nowMillis = Date.now(),
) {
  if (!isCredentialSessionStatus(sessionData.status) ||
      !isCredentialSessionUnexpired(sessionData, nowMillis)) {
    return false;
  }
  if (sessionData.status !== VIDEO_SESSION_STATUS.CONNECTING) {
    return true;
  }
  return timestampToMillis(sessionData.joinDeadlineAt) !== null;
}

function buildDailyWebhookRejectedDecision(reason) {
  return {
    ok: false,
    reason,
    update: null,
  };
}

function buildDailyWebhookSessionUpdate({
  event,
  sessionData = {},
  presenceData = null,
  nowMillis = Date.now(),
  receivedAt = admin.firestore.FieldValue.serverTimestamp(),
}) {
  if (!event || event.type !== "participant.joined") {
    return buildDailyWebhookRejectedDecision("unsupported_event_type");
  }

  if (!event.roomName || !event.userId || !event.eventId) {
    return buildDailyWebhookRejectedDecision("malformed_event");
  }

  if (event.roomName !== normalizeString(sessionData.dailyRoomName)) {
    return buildDailyWebhookRejectedDecision("room_mismatch");
  }

  if (!isAcceptedSessionCredentialParticipant(sessionData, event.userId)) {
    return buildDailyWebhookRejectedDecision("not_session_participant");
  }

  if (!isDailyWebhookSessionCurrentForProcessing(sessionData, nowMillis)) {
    return buildDailyWebhookRejectedDecision("session_not_joinable");
  }
  const eventMillis = event.joinedAtMillis || event.eventTsMillis || nowMillis;

  const participantIds =
    getAcceptedSessionCredentialParticipantIds(sessionData);
  if (participantIds.length < 2) {
    return buildDailyWebhookRejectedDecision(
      "accepted_participants_incomplete",
    );
  }

  const sessionMetadata = readSessionMetadata(sessionData);
  const existingSignals =
    readDailyWebhookParticipantSignals(sessionMetadata);
  const eventJoinedAt =
    event.joinedAtMillis ?
      admin.firestore.Timestamp.fromMillis(event.joinedAtMillis) :
      null;
  const eventTs =
    event.eventTsMillis ?
      admin.firestore.Timestamp.fromMillis(event.eventTsMillis) :
      null;
  const nextSignals = {
    ...existingSignals,
    [event.userId]: buildDailyWebhookParticipantSignal({
      existingSignal: existingSignals[event.userId],
      event,
      eventJoinedAt,
      eventTs,
      receivedAt,
    }),
  };
  const hasAllParticipantSignals =
    participantIds.every((participantId) => Boolean(nextSignals[participantId]));
  const allParticipantJoinsBeforeDeadline =
    hasAllParticipantSignals &&
    areAcceptedDailyWebhookJoinsBeforeDeadline({
      sessionData,
      participantIds,
      signals: nextSignals,
    });
  const hasVerifiedDailyPresence =
    hasAllParticipantSignals &&
    allParticipantJoinsBeforeDeadline &&
    dailyPresenceHasAcceptedParticipants({
      presenceData,
      roomName: event.roomName,
      participantIds,
    });
  const connectedAtMillis = Math.max(
    ...participantIds
      .map((participantId) => {
        const joinedAt = nextSignals[participantId]?.joinedAt;
        return joinedAt && typeof joinedAt.toMillis === "function" ?
          joinedAt.toMillis() :
          0;
      })
      .filter((millis) => millis > 0),
    eventMillis,
  );
  const connectedAt =
    admin.firestore.Timestamp.fromMillis(connectedAtMillis);
  const roomJoinMetadata = buildRoomJoinParticipantMetadata({
    sessionMetadata,
    participantIds,
    userId: event.userId,
    signal: {
      eventId: event.eventId,
      dailySessionId: event.dailySessionId || null,
      joinedAt: eventJoinedAt || eventTs || connectedAt,
      eventTs,
      owner: event.owner === true,
      source: "dailyWebhook",
      receivedAt,
      lastSeenAt: receivedAt,
    },
  });
  const nextMetadata = {
    ...sessionMetadata,
    ...roomJoinMetadata,
    dailyWebhookParticipantSignals: nextSignals,
    dailyWebhookLastEventId: event.eventId,
    dailyWebhookLastEventType: event.type,
    dailyWebhookLastEventAt: receivedAt,
    dailyWebhookRoomName: event.roomName,
  };

  if (hasVerifiedDailyPresence) {
    nextMetadata.dailyWebhookConnectedAt = connectedAt;
    nextMetadata.dailyWebhookConnectedParticipantIds = participantIds;
    nextMetadata.dailyWebhookConnectedEventIds = participantIds
      .map((participantId) => nextSignals[participantId]?.eventId)
      .filter(Boolean);

    if (!sessionMetadata.callConnectedAt) {
      nextMetadata.callConnectedAt = connectedAt;
      nextMetadata.callConnectedAtSource = "dailyWebhookTwoParty";
      nextMetadata.callConnectedBy = event.userId;
      nextMetadata.callConnectedSignalParticipantIds = participantIds;
    }
  }

  const isFirstConnectedMarker =
    hasVerifiedDailyPresence && !sessionMetadata.callConnectedAt;
  const activePolicyState = isFirstConnectedMarker ?
    buildAcceptedSessionPolicyState(sessionData, connectedAtMillis) :
    null;
  const update = {
    sessionMetadata: nextMetadata,
  };
  if (hasVerifiedDailyPresence) {
    update.status = VIDEO_SESSION_STATUS.ACTIVE;
  }
  if (isFirstConnectedMarker) {
    update.expiresAt = admin.firestore.Timestamp.fromDate(
      activePolicyState.expiresAt,
    );
    if (activePolicyState.sessionPolicy) {
      update.sessionPolicy = activePolicyState.sessionPolicy;
    }
  }
  if (hasVerifiedDailyPresence && !sessionData.startedAt) {
    update.startedAt = connectedAt;
  }

  return {
    ok: true,
    reason: hasVerifiedDailyPresence ?
      "daily_connected_marked" :
      hasAllParticipantSignals ?
        allParticipantJoinsBeforeDeadline ?
          "daily_signal_recorded_presence_required" :
          "daily_signal_recorded_after_join_deadline" :
        "daily_signal_recorded",
    update,
    connectedMarked:
      hasVerifiedDailyPresence && !sessionMetadata.callConnectedAt,
  };
}

function findCandidateSessionDoc(querySnapshot, event, nowMillis = Date.now()) {
  const candidates = [];
  querySnapshot.forEach((doc) => {
    const sessionData = doc.data() || {};
    const decision = buildDailyWebhookSessionUpdate({
      event,
      sessionData,
      nowMillis,
    });
    if (decision.ok) {
      candidates.push(doc);
    }
  });

  return candidates.length === 1 ? candidates[0] : null;
}

async function applyDailyWebhookSessionUpdateWritesInTransaction({
  db,
  transaction,
  sessionRef,
  sessionId,
  sessionData = {},
  decision = {},
  serverTimestamp = admin.firestore.FieldValue.serverTimestamp(),
  fieldDelete = admin.firestore.FieldValue.delete(),
  stopSearchRequests = stopSessionSearchRequestsInTransaction,
}) {
  const shouldStopSearchRequests =
    decision.update?.status === VIDEO_SESSION_STATUS.ACTIVE;
  const trialContexts = decision.connectedMarked === true ?
    await readSessionTrialCallContextsInTransaction({
      db,
      transaction,
      sessionId,
      sessionData,
    }) : [];
  if (shouldStopSearchRequests) {
    await stopSearchRequests({
      db,
      transaction,
      sessionId,
      sessionData,
      serverTimestamp,
      fieldDelete,
      stopReason: "call_started",
    });
  }

  transaction.update(sessionRef, decision.update);
  if (trialContexts.length > 0) {
    markSessionTrialCallContextsConnectedInTransaction({
      transaction,
      contexts: trialContexts,
    });
  }

  return {
    stoppedSearchRequests: shouldStopSearchRequests,
    updatedSession: true,
  };
}

exports.dailyWebhook = functions
  .runWith({
    secrets: [dailyWebhookSecret, ...dailyApiSecrets],
    timeoutSeconds: 30,
    memory: "256MB",
  })
  .https.onRequest(async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    if (maybeHandleDailyWebhookVerificationRequest(req, res)) {
      return;
    }

    const expectedSecret = dailyWebhookSecret.value();
    if (!expectedSecret) {
      safeLog.error("daily_webhook_secret_missing");
      res.status(500).send("Server not configured");
      return;
    }

    const timestampHeader = readHeader(req, "x-webhook-timestamp");
    const signatureHeader = readHeader(req, "x-webhook-signature");
    if (!isValidDailyWebhookSignature({
      event: req.body,
      secret: expectedSecret,
      signatureHeader,
      timestampHeader,
    })) {
      safeLog.warn("daily_webhook_signature_invalid");
      res.status(401).send("Unauthorized");
      return;
    }

    const event = parseDailyWebhookEvent(req.body);
    if (!event) {
      res.status(400).send("Malformed event");
      return;
    }

    if (!DAILY_WEBHOOK_SUPPORTED_EVENT_TYPES.has(event.type)) {
      res.status(200).send("Ignored");
      return;
    }

    if (!event.roomName || !event.userId) {
      res.status(400).send("Malformed event");
      return;
    }

    const db = admin.firestore();
    try {
      const querySnapshot = await db
        .collection("videoSessions")
        .where("dailyRoomName", "==", event.roomName)
        .limit(5)
        .get();
      const candidate = findCandidateSessionDoc(querySnapshot, event);
      if (!candidate) {
        safeLog.warn("daily_webhook_session_ambiguous", {
          eventId: event.eventId,
          roomName: event.roomName,
        });
        res.status(200).send("Ignored");
        return;
      }

      let presenceData = null;
      try {
        presenceData = await getDailyRoomPresence(event.roomName);
      } catch (error) {
        safeLog.error("daily_presence_check_failed", {
          eventId: event.eventId,
          roomName: event.roomName,
          error,
        });
      }

      const result = await db.runTransaction(async (transaction) => {
        const freshSnapshot = await transaction.get(candidate.ref);
        if (!freshSnapshot.exists) {
          return {updated: false, reason: "session_missing"};
        }

        const freshData = freshSnapshot.data() || {};
        const decision = buildDailyWebhookSessionUpdate({
          event,
          sessionData: freshData,
          presenceData,
        });
        if (!decision.ok) {
          return {updated: false, reason: decision.reason};
        }

        await applyDailyWebhookSessionUpdateWritesInTransaction({
          db,
          transaction,
          sessionRef: candidate.ref,
          sessionId: candidate.id,
          sessionData: freshData,
          decision,
        });
        return {
          updated: true,
          reason: decision.reason,
          connectedMarked: decision.connectedMarked,
        };
      });

      safeLog.log("daily_webhook_processed", {
        eventId: event.eventId,
        updated: result.updated,
        reason: result.reason,
        connectedMarked: result.connectedMarked === true,
      });
      res.status(200).send("OK");
    } catch (error) {
      safeLog.error("daily_webhook_failed", {
        eventId: event.eventId,
        error,
      });
      res.status(500).send("Internal error");
    }
  });

exports.__private__ = {
  DAILY_WEBHOOK_REPLAY_WINDOW_MS,
  applyDailyWebhookSessionUpdateWritesInTransaction,
  buildDailyWebhookSessionUpdate,
  areAcceptedDailyWebhookJoinsBeforeDeadline,
  computeDailyWebhookSignature,
  findCandidateSessionDoc,
  getDailyWebhookSignalJoinMillis,
  isDailyWebhookSessionCurrentForProcessing,
  isFreshDailyWebhookTimestamp,
  isDailyWebhookVerificationRequest,
  isValidDailyWebhookSignature,
  maybeHandleDailyWebhookVerificationRequest,
  parseDailyWebhookEvent,
  readDailyWebhookParticipantSignals,
  readHeader,
  readSessionMetadata,
};
