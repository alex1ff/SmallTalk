const admin = require("firebase-admin");
const {sendApnsVoip} = require("./apns_voip");
const {getUserVoipTokens} = require("./voip_tokens");

const BACKGROUND_STUDENT_RESPONDER_PUSH_TIMEOUT_MS = 3 * 1000;
const BACKGROUND_STUDENT_RESPONDER_APNS_TIMEOUT_MS = 2 * 1000;

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

function classifyApnsDeliveryFailure(error) {
  const message = readErrorMessage(error, "").toLowerCase();
  return [
    "baddevicetoken",
    "unregistered",
    "devicetokennotfortopic",
  ].some((reason) => message.includes(reason)) ?
    "definitive" :
    "unknown";
}

function throwIfAborted(signal) {
  if (!signal?.aborted) {
    return;
  }
  if (signal.reason instanceof Error) {
    throw signal.reason;
  }
  throw new Error("push_aborted");
}

function waitForAbortable(promise, signal) {
  if (!signal) {
    return promise;
  }
  throwIfAborted(signal);
  return new Promise((resolve, reject) => {
    const abort = () => {
      reject(signal.reason instanceof Error ?
        signal.reason :
        new Error("push_aborted"));
    };
    signal.addEventListener?.("abort", abort, {once: true});
    Promise.resolve(promise).then(
        (value) => {
          signal.removeEventListener?.("abort", abort);
          resolve(value);
        },
        (error) => {
          signal.removeEventListener?.("abort", abort);
          reject(error);
        },
    );
  });
}

function buildChildAbortController({
  parentSignal = null,
  timeoutMs = 0,
  timeoutError = new Error("operation_timeout"),
} = {}) {
  const controller = new AbortController();
  let timeout = null;
  const abortFromParent = () => {
    controller.abort(parentSignal?.reason instanceof Error ?
      parentSignal.reason :
      new Error("push_aborted"));
  };
  if (parentSignal?.aborted) {
    abortFromParent();
  } else {
    parentSignal?.addEventListener?.("abort", abortFromParent, {once: true});
  }
  if (Number.isFinite(timeoutMs) && timeoutMs > 0) {
    timeout = setTimeout(() => {
      controller.abort(timeoutError);
    }, timeoutMs);
  }
  return {
    signal: controller.signal,
    cleanup: () => {
      if (timeout) {
        clearTimeout(timeout);
      }
      parentSignal?.removeEventListener?.("abort", abortFromParent);
    },
  };
}

function calculateApnsFallbackTimeoutMs(totalTimeoutMs) {
  if (!Number.isFinite(totalTimeoutMs) || totalTimeoutMs <= 1) {
    return BACKGROUND_STUDENT_RESPONDER_APNS_TIMEOUT_MS;
  }
  return Math.max(
      1,
      Math.min(
          BACKGROUND_STUDENT_RESPONDER_APNS_TIMEOUT_MS,
          Math.floor(totalTimeoutMs * 0.7),
      ),
  );
}

function buildStudentPairResponderCallData({
  sessionId = "",
  pushPayload = {},
} = {}) {
  return {
    sessionId: normalizeString(sessionId),
    callerName: normalizeString(pushPayload.studentName) || "Student",
    callerId: normalizeString(pushPayload.studentId),
    callerPhoto: normalizeString(pushPayload.studentPhoto),
    language: normalizeString(pushPayload.language),
    scenario: normalizeString(pushPayload.scenario),
    recipientId:
      normalizeString(pushPayload.recipientId) ||
      normalizeString(pushPayload.responderId),
    requesterId: normalizeString(pushPayload.requesterId),
    responderId: normalizeString(pushPayload.responderId),
    requesterRole: normalizeString(pushPayload.requesterRole),
    responderRole: normalizeString(pushPayload.responderRole),
    navRole: normalizeString(pushPayload.navRole) || "student",
    acceptMode:
      normalizeString(pushPayload.acceptMode) || "responder_accepts",
    callKitId: normalizeString(pushPayload.callKitId),
    notificationId: normalizeString(pushPayload.notificationId),
    searchRequestId: normalizeString(pushPayload.searchRequestId),
    expiresAt: normalizeString(pushPayload.expiresAt),
    roomUrl: "",
    roomName: normalizeString(pushPayload.roomName),
    tokenStrategy: normalizeString(pushPayload.tokenStrategy) || "accept_call",
    ...(normalizeString(pushPayload.matchProtocolVersion) === "2" ? {
      matchProtocolVersion: "2",
      pairAttemptId: normalizeString(pushPayload.pairAttemptId),
      surface: normalizeString(pushPayload.surface) || "callkit",
    } : {}),
  };
}

function buildStudentPairResponderPushPayload(callData = {}) {
  return {
    type: "incoming_call",
    sessionId: normalizeString(callData.sessionId),
    callerName: normalizeString(callData.callerName) || "Student",
    callerId: normalizeString(callData.callerId),
    callerPhoto: normalizeString(callData.callerPhoto),
    language: normalizeString(callData.language),
    scenario: normalizeString(callData.scenario),
    recipientId:
      normalizeString(callData.recipientId) ||
      normalizeString(callData.responderId),
    requesterId: normalizeString(callData.requesterId),
    responderId: normalizeString(callData.responderId),
    requesterRole: normalizeString(callData.requesterRole),
    responderRole: normalizeString(callData.responderRole),
    navRole: normalizeString(callData.navRole) || "student",
    acceptMode:
      normalizeString(callData.acceptMode) || "responder_accepts",
    callKitId: normalizeString(callData.callKitId),
    notificationId: normalizeString(callData.notificationId),
    searchRequestId: normalizeString(callData.searchRequestId),
    expiresAt: normalizeString(callData.expiresAt),
    roomUrl: "",
    roomName: normalizeString(callData.roomName),
    tokenStrategy: normalizeString(callData.tokenStrategy) || "accept_call",
    ...(normalizeString(callData.matchProtocolVersion) === "2" ? {
      matchProtocolVersion: "2",
      pairAttemptId: normalizeString(callData.pairAttemptId),
      surface: normalizeString(callData.surface) || "callkit",
    } : {}),
  };
}

function buildStudentPairResponderFcmMessage({
  fcmToken = "",
  payload = {},
  bundleId = "com.appwave.expatlio",
} = {}) {
  return {
    token: normalizeString(fcmToken),
    data: payload,
    android: {priority: "high"},
    apns: {
      headers: {
        "apns-priority": "10",
        "apns-push-type": "alert",
        "apns-topic": bundleId,
      },
      payload: {
        aps: {
          "content-available": 1,
          alert: {
            title: "Входящий звонок",
            body: `${payload.callerName} хочет попрактиковать ${payload.language}`,
          },
          sound: "default",
          badge: 1,
        },
      },
    },
  };
}

async function sendVoipPushToStudentResponder(
    responderId,
    callData = {},
    dependencies = {},
) {
  const normalizedResponderId = normalizeString(responderId);
  if (!normalizedResponderId) {
    return {sent: false, reason: "missing_responder"};
  }

  const firestore = dependencies.firestore || admin.firestore();
  const getTokens = dependencies.getUserVoipTokens || getUserVoipTokens;
  const sendApns = dependencies.sendApnsVoip || sendApnsVoip;
  const messaging = dependencies.messaging || admin.messaging();
  const logger = dependencies.logger || console;
  const signal = dependencies.signal || null;
  const apnsTimeoutMs = Number.isFinite(dependencies.apnsTimeoutMs) &&
    dependencies.apnsTimeoutMs > 0 ?
    dependencies.apnsTimeoutMs :
    BACKGROUND_STUDENT_RESPONDER_APNS_TIMEOUT_MS;
  throwIfAborted(signal);
  const responderDoc = await firestore
      .collection("users")
      .doc(normalizedResponderId)
      .get();
  throwIfAborted(signal);
  if (!responderDoc.exists) {
    return {sent: false, reason: "responder_missing"};
  }

  const responderData = responderDoc.data() || {};
  const callExpiresAtMillis = Date.parse(normalizeString(callData.expiresAt));
  if (Number.isFinite(callExpiresAtMillis) &&
      callExpiresAtMillis <= Date.now()) {
    return {sent: false, reason: "response_window_closed"};
  }
  const apnsExpiration = Number.isFinite(callExpiresAtMillis) ?
    Math.floor(callExpiresAtMillis / 1000) :
    null;
  const bundleId = process.env.IOS_BUNDLE_ID || "com.appwave.expatlio";
  const voipTopic =
    process.env.IOS_VOIP_TOPIC ||
    (bundleId.endsWith(".voip") ? bundleId : `${bundleId}.voip`);
  const {voipPushToken, voipToken: fcmToken} =
    await getTokens(normalizedResponderId, responderData);
  throwIfAborted(signal);
  if (!voipPushToken && !fcmToken) {
    return {sent: false, reason: "missing_tokens"};
  }

  const payload = buildStudentPairResponderPushPayload(callData);
  let apnsErrorMessage = "";
  let apnsFailureKind = null;
  if (voipPushToken) {
    const apnsAbort = buildChildAbortController({
      parentSignal: signal,
      timeoutMs: apnsTimeoutMs,
      timeoutError: new Error("apns_voip_timeout"),
    });
    try {
      await sendApns({
        deviceToken: voipPushToken,
        topic: voipTopic,
        expiration: apnsExpiration,
        collapseId: normalizeString(callData.callKitId),
        signal: apnsAbort.signal,
        payload: {
          aps: {"content-available": 1},
          ...payload,
        },
      });
      return {sent: true, channel: "apns_voip"};
    } catch (error) {
      apnsErrorMessage = readErrorMessage(error, "apns_voip_failed");
      apnsFailureKind = classifyApnsDeliveryFailure(error);
      logger.error(
          "Failed to send APNs VoIP push to background student:",
          readErrorMessage(error, "apns_voip_failed"),
      );
    } finally {
      apnsAbort.cleanup();
    }
  }

  if (!fcmToken) {
    return {
      sent: false,
      reason: "missing_fcm_token",
      error: apnsErrorMessage || "missing_fcm_token",
      attemptedChannels: ["apns_voip"],
      apnsFailureKind: apnsFailureKind || "unknown",
    };
  }

  try {
    throwIfAborted(signal);
    await waitForAbortable(
        messaging.send(buildStudentPairResponderFcmMessage({
          fcmToken,
          payload,
          bundleId,
        })),
        signal,
    );
  } catch (error) {
    const fcmErrorMessage = readErrorMessage(error, "fcm_failed");
    return {
      sent: false,
      reason: "fcm_failed",
      error: apnsErrorMessage ?
        `apns: ${apnsErrorMessage}; fcm: ${fcmErrorMessage}` :
        fcmErrorMessage,
    };
  }
  const requiresApnsVoipDelivery =
    normalizeString(responderData.matchProtocolPlatform) === "ios" ||
    Boolean(voipPushToken);
  if (requiresApnsVoipDelivery) {
    return {
      sent: false,
      reason: voipPushToken ?
        "ios_fcm_wake_not_native" :
        "missing_voip_push_token",
      error: apnsErrorMessage || "ios_fcm_wake_not_native",
      fcmWakeSent: true,
      attemptedChannels: voipPushToken ? ["apns_voip", "fcm"] : ["fcm"],
      apnsFailureKind: voipPushToken ?
        (apnsFailureKind || "unknown") :
        "definitive",
    };
  }
  return {sent: true, channel: "fcm"};
}

async function runBackgroundStudentResponderPushSender({
  pushSender,
  responderId = "",
  callData = {},
  timeoutMs = BACKGROUND_STUDENT_RESPONDER_PUSH_TIMEOUT_MS,
}) {
  const controller = new AbortController();
  const normalizedTimeoutMs = Number.isFinite(timeoutMs) && timeoutMs > 0 ?
    timeoutMs :
    BACKGROUND_STUDENT_RESPONDER_PUSH_TIMEOUT_MS;
  const timeoutError = new Error("push_timeout");
  let timeout = null;
  const pushPromise = Promise.resolve()
      .then(() => pushSender(responderId, callData, {
        apnsTimeoutMs: calculateApnsFallbackTimeoutMs(normalizedTimeoutMs),
        signal: controller.signal,
      }));
  const timeoutPromise = new Promise((resolve, reject) => {
    timeout = setTimeout(() => {
      controller.abort(timeoutError);
      reject(timeoutError);
    }, normalizedTimeoutMs);
  });

  try {
    return await Promise.race([pushPromise, timeoutPromise]);
  } finally {
    clearTimeout(timeout);
    pushPromise.catch(() => {});
  }
}

module.exports = {
  BACKGROUND_STUDENT_RESPONDER_PUSH_TIMEOUT_MS,
  buildStudentPairResponderCallData,
  buildStudentPairResponderFcmMessage,
  buildStudentPairResponderPushPayload,
  classifyApnsDeliveryFailure,
  runBackgroundStudentResponderPushSender,
  sendVoipPushToStudentResponder,
};
