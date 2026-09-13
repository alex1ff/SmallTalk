const crypto = require("node:crypto");

const axios = require("axios");
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "password_reset"});

const {
  buildEmailActionHandlerLink,
  formatSenderAddress,
  normalizeLocale,
  resolveEmailConfig,
} = require("./email_verification.js").__private__;

const RESEND_SEND_EMAIL_URL = "https://api.resend.com/emails";
const PASSWORD_RESET_REQUESTS = "passwordResetRequests";
const PASSWORD_RESET_RATE_LIMITS = "passwordResetRateLimits";
const PASSWORD_RESET_HMAC_SECRET = "PASSWORD_RESET_RATE_LIMIT_HMAC_KEY";
const REQUEST_TTL_MS = 12 * 60 * 60 * 1000;
const RATE_LIMIT_TTL_MS = 2 * 24 * 60 * 60 * 1000;
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const MAX_EMAIL_REQUESTS_PER_WINDOW = 3;
const MAX_IP_REQUESTS_PER_WINDOW = 12;
const MAX_DELIVERY_ATTEMPTS = 4;
const DELIVERY_LEASE_MS = 2 * 60 * 1000;
const RESEND_TIMEOUT_MS = 10000;
const BRAND_NAME = "Expatlio";
const DEFAULT_PASSWORD_RESET_APP_LINK =
  "smalltalk://smalltalk.com/?passwordReset=1";

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeEmail(value) {
  const email = normalizeString(value).toLowerCase();
  if (
    !email ||
    email.length > 254 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/u.test(email)
  ) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "A valid email is required.",
    );
  }
  return email;
}

function validateRequestKeys(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid request payload.",
    );
  }
  const allowed = new Set(["email", "locale"]);
  if (Object.keys(data).some((key) => !allowed.has(key))) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid request payload.",
    );
  }
}

function clientIpAddress(context) {
  const request = context && context.rawRequest;
  return normalizeString(
      request && (request.ip || request.socket?.remoteAddress),
  ) || "unknown";
}

function hmacIdentity(value, key) {
  return crypto
      .createHmac("sha256", key)
      .update(String(value), "utf8")
      .digest("hex");
}

function buildRateLimitDecision(emailCount, ipCount) {
  return {
    allowed:
      emailCount < MAX_EMAIL_REQUESTS_PER_WINDOW &&
      ipCount < MAX_IP_REQUESTS_PER_WINDOW,
    incrementEmail: emailCount < MAX_EMAIL_REQUESTS_PER_WINDOW,
    incrementIp: ipCount < MAX_IP_REQUESTS_PER_WINDOW,
  };
}

function timestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const millis = Number(value);
  return Number.isFinite(millis) ? millis : 0;
}

function buildLeaseDecision(data, nowMillis) {
  const status = normalizeString(data && data.status) || "queued";
  if (["sent", "discarded"].includes(status)) {
    return {action: "terminal"};
  }

  const expiresAtMillis = timestampMillis(data && data.expiresAt);
  const attemptCount = Number(data && data.attemptCount) || 0;
  if (expiresAtMillis <= nowMillis || attemptCount >= MAX_DELIVERY_ATTEMPTS) {
    return {
      action: "discard",
      reason: expiresAtMillis <= nowMillis ? "expired" : "max_attempts",
    };
  }

  const leaseExpiresAtMillis = timestampMillis(data && data.leaseExpiresAt);
  if (status === "processing" && leaseExpiresAtMillis > nowMillis) {
    return {action: "leased"};
  }
  const retryAtMillis = timestampMillis(data && data.retryAt);
  if (status === "retry" && retryAtMillis > nowMillis) {
    return {action: "retry_wait"};
  }

  return {
    action: "acquire",
    attemptCount: attemptCount + 1,
  };
}

async function enqueuePasswordResetRequest({
  db,
  email,
  locale,
  ipAddress,
  hmacKey,
  now,
}) {
  if (!normalizeString(hmacKey)) {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "Password reset delivery is not configured.",
    );
  }

  const nowMillis = now.getTime();
  const windowKey = Math.floor(nowMillis / RATE_LIMIT_WINDOW_MS);
  const emailHash = hmacIdentity(email, hmacKey);
  const ipHash = hmacIdentity(ipAddress, hmacKey);
  const emailLimitRef = db
      .collection(PASSWORD_RESET_RATE_LIMITS)
      .doc(`email_${windowKey}_${emailHash}`);
  const ipLimitRef = db
      .collection(PASSWORD_RESET_RATE_LIMITS)
      .doc(`ip_${windowKey}_${ipHash}`);
  const requestRef = db.collection(PASSWORD_RESET_REQUESTS).doc();
  const expiresAt = new Date(nowMillis + REQUEST_TTL_MS);
  const rateLimitExpiresAt = new Date(nowMillis + RATE_LIMIT_TTL_MS);

  return db.runTransaction(async (transaction) => {
    const [emailLimit, ipLimit] = await Promise.all([
      transaction.get(emailLimitRef),
      transaction.get(ipLimitRef),
    ]);
    const emailCount = Number(emailLimit.data()?.count) || 0;
    const ipCount = Number(ipLimit.data()?.count) || 0;
    const decision = buildRateLimitDecision(emailCount, ipCount);

    if (decision.incrementEmail) {
      transaction.set(emailLimitRef, {
        count: emailCount + 1,
        expiresAt: rateLimitExpiresAt,
      });
    }
    if (decision.incrementIp) {
      transaction.set(ipLimitRef, {
        count: ipCount + 1,
        expiresAt: rateLimitExpiresAt,
      });
    }

    if (decision.allowed) {
      transaction.create(requestRef, {
        email,
        locale,
        status: "queued",
        attemptCount: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt,
      });
    }

    return {queued: decision.allowed};
  });
}

async function requestPasswordResetHandler(data, context, deps = {}) {
  if (!context || !context.app) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "App Check is required.",
    );
  }
  validateRequestKeys(data);
  const email = normalizeEmail(data.email);
  const locale = normalizeLocale(data.locale);
  const now = deps.now || new Date();

  await (deps.enqueueRequest || enqueuePasswordResetRequest)({
    db: deps.db || admin.firestore(),
    email,
    locale,
    ipAddress: deps.ipAddress || clientIpAddress(context),
    hmacKey: normalizeString(
        deps.hmacKey || process.env[PASSWORD_RESET_HMAC_SECRET],
    ),
    now,
  });

  return {accepted: true};
}

async function acquireDeliveryLease({db, requestRef, now, leaseId}) {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(requestRef);
    if (!snapshot.exists) return {action: "missing"};
    const data = snapshot.data() || {};
    const decision = buildLeaseDecision(data, now.getTime());
    if (decision.action === "discard") {
      transaction.update(requestRef, {
        status: "discarded",
        discardReason: decision.reason,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        email: admin.firestore.FieldValue.delete(),
        leaseId: admin.firestore.FieldValue.delete(),
        leaseExpiresAt: admin.firestore.FieldValue.delete(),
      });
      return decision;
    }
    if (decision.action !== "acquire") return decision;

    transaction.update(requestRef, {
      status: "processing",
      attemptCount: decision.attemptCount,
      lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      leaseId,
      leaseExpiresAt: new Date(now.getTime() + DELIVERY_LEASE_MS),
      retryAt: admin.firestore.FieldValue.delete(),
    });
    return {
      ...decision,
      request: {
        email: normalizeString(data.email),
        locale: normalizeLocale(data.locale),
      },
    };
  });
}

async function updateIfLeaseMatches({db, requestRef, leaseId, update}) {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(requestRef);
    if (!snapshot.exists || snapshot.data()?.leaseId !== leaseId) return false;
    transaction.update(requestRef, update);
    return true;
  });
}

function passwordResetEmailText({resetLink, locale}) {
  if (normalizeLocale(locale) === "en") {
    return [
      `Reset your ${BRAND_NAME} password`,
      "",
      `Open this link to choose a new password: ${resetLink}`,
      "",
      "If you did not request this, you can ignore this email.",
      "",
      BRAND_NAME,
    ].join("\n");
  }
  return [
    `Сброс пароля ${BRAND_NAME}`,
    "",
    `Откройте ссылку и задайте новый пароль: ${resetLink}`,
    "",
    "Если вы не запрашивали сброс пароля, просто проигнорируйте письмо.",
    "",
    BRAND_NAME,
  ].join("\n");
}

function escapeHtml(value) {
  return normalizeString(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
}

function passwordResetEmailHtml({resetLink, locale}) {
  const isEnglish = normalizeLocale(locale) === "en";
  const safeLink = escapeHtml(resetLink);
  const title = isEnglish ? "Reset your password" : "Сбросьте пароль";
  const body = isEnglish ?
    `Choose a new password for your ${BRAND_NAME} account.` :
    `Задайте новый пароль для аккаунта ${BRAND_NAME}.`;
  const button = isEnglish ? "Choose new password" : "Задать новый пароль";
  const footer = isEnglish ?
    "If you did not request this, you can ignore this email." :
    "Если вы не запрашивали сброс, просто проигнорируйте письмо.";

  return `<!doctype html>
<html lang="${isEnglish ? "en" : "ru"}">
  <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title></head>
  <body style="margin:0;background:#f2f2f7;color:#000;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="padding:28px 12px;background:#f2f2f7;"><tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#fff;border:1px solid #e5e5ea;border-radius:20px;overflow:hidden;">
        <tr><td style="padding:30px 28px 8px;"><strong style="font-size:19px;">${BRAND_NAME}</strong><h1 style="font-size:30px;margin:24px 0 10px;">${title}</h1><p style="color:#6b6b73;font-size:16px;line-height:1.55;">${body}</p></td></tr>
        <tr><td style="padding:18px 28px;"><a href="${safeLink}" style="display:inline-block;background:#7430e8;color:#fff;text-decoration:none;border-radius:16px;padding:15px 22px;font-size:16px;font-weight:700;">${button}</a></td></tr>
        <tr><td style="padding:12px 28px 28px;word-break:break-all;font-size:13px;"><a href="${safeLink}" style="color:#7430e8;">${safeLink}</a></td></tr>
        <tr><td style="padding:18px 28px;background:#f8f8fb;color:#6b6b73;font-size:13px;border-top:1px solid #e5e5ea;">${footer}</td></tr>
      </table>
    </td></tr></table>
  </body>
</html>`;
}

async function sendPasswordResetEmail({
  email,
  resetLink,
  locale,
  requestId,
  config,
  resendClient = axios,
}) {
  if (!config.resendApiKey || !config.emailFrom) {
    const error = new Error("Password reset email sender is not configured");
    error.code = "password_reset_not_configured";
    throw error;
  }
  const payload = {
    from: formatSenderAddress(config.emailFrom),
    to: [email],
    subject: normalizeLocale(locale) === "en" ?
      `Reset your ${BRAND_NAME} password` :
      `Сброс пароля в ${BRAND_NAME}`,
    html: passwordResetEmailHtml({resetLink, locale}),
    text: passwordResetEmailText({resetLink, locale}),
  };
  if (config.emailReplyTo) payload.reply_to = config.emailReplyTo;

  const response = await resendClient.post(RESEND_SEND_EMAIL_URL, payload, {
    timeout: RESEND_TIMEOUT_MS,
    headers: {
      Authorization: `Bearer ${config.resendApiKey}`,
      "Content-Type": "application/json",
      "Idempotency-Key": requestId,
    },
  });
  return {id: response?.data?.id || null};
}

function isMissingUserError(error) {
  const code = normalizeString(error && error.code).toLowerCase();
  return code === "auth/user-not-found" || code === "user-not-found";
}

function normalizedDeliveryErrorCode(error) {
  const explicitCode = normalizeString(error && error.code).toLowerCase();
  if (explicitCode) return explicitCode.slice(0, 96);
  const status = Number(error?.response?.status);
  if (Number.isInteger(status)) return `http_${status}`;
  return "delivery_failed";
}

function deliveryErrorDisposition(error) {
  const code = normalizedDeliveryErrorCode(error);
  const status = Number(error?.response?.status);
  const permanentCodes = new Set([
    "password_reset_not_configured",
    "auth/insufficient-permission",
    "auth/invalid-credential",
    "auth/invalid-email",
    "auth/operation-not-allowed",
  ]);
  if (permanentCodes.has(code)) {
    return {action: "fail", code};
  }
  if (Number.isInteger(status) && status >= 400 && status < 500 &&
      ![408, 409, 425, 429].includes(status)) {
    return {action: "fail", code};
  }
  return {action: "retry", code};
}

function retryDelayMillis(attemptCount) {
  const boundedAttempt = Math.max(1, Math.min(5, Number(attemptCount) || 1));
  return Math.min(15 * 60 * 1000, 60 * 1000 * (2 ** (boundedAttempt - 1)));
}

async function processPasswordResetRequestHandler(snapshot, context, deps = {}) {
  const requestId = normalizeString(context?.params?.requestId || snapshot?.id);
  const requestRef = snapshot.ref;
  const db = deps.db || admin.firestore();
  const now = deps.now || new Date();
  const leaseId = (deps.randomId || crypto.randomUUID)();
  const acquireLease = deps.acquireLease || acquireDeliveryLease;
  const lease = await acquireLease({db, requestRef, now, leaseId});
  if (["leased", "retry_wait"].includes(lease.action)) {
    // A duplicate delivery may be running, or the previous invocation may
    // have crashed. Throwing keeps platform retries alive until that worker
    // reaches a terminal state or its bounded lease expires.
    const error = new Error("Password reset delivery lease is active");
    error.code = lease.action === "retry_wait" ?
      "delivery_retry_not_due" :
      "delivery_lease_active";
    throw error;
  }
  if (lease.action !== "acquire") return null;

  const email = lease.request.email;
  const locale = lease.request.locale;
  const authClient = deps.authClient || admin.auth();

  try {
    await authClient.getUserByEmail(email);
    const firebaseResetLink = await authClient.generatePasswordResetLink(email);
    const config = resolveEmailConfig(deps.env || process.env);
    const resetLink = buildEmailActionHandlerLink({
      firebaseLink: firebaseResetLink,
      locale,
      handlerUrl: config.emailActionHandlerUrl,
      appDeepLink: normalizeString(
          deps.passwordResetAppDeepLink ||
          process.env.PASSWORD_RESET_APP_DEEP_LINK,
      ) || DEFAULT_PASSWORD_RESET_APP_LINK,
    });
    const result = await (deps.sendEmail || sendPasswordResetEmail)({
      email,
      resetLink,
      locale,
      requestId,
      config,
      resendClient: deps.resendClient || axios,
    });
    await (deps.updateLease || updateIfLeaseMatches)({
      db,
      requestRef,
      leaseId,
      update: {
        status: "sent",
        providerMessageId: result.id,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        email: admin.firestore.FieldValue.delete(),
        leaseId: admin.firestore.FieldValue.delete(),
        leaseExpiresAt: admin.firestore.FieldValue.delete(),
      },
    });
    return null;
  } catch (error) {
    if (isMissingUserError(error)) {
      await (deps.updateLease || updateIfLeaseMatches)({
        db,
        requestRef,
        leaseId,
        update: {
          status: "discarded",
          discardReason: "account_not_found",
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          email: admin.firestore.FieldValue.delete(),
          leaseId: admin.firestore.FieldValue.delete(),
          leaseExpiresAt: admin.firestore.FieldValue.delete(),
        },
      });
      return null;
    }
    const disposition = deliveryErrorDisposition(error);
    safeLog.error("password_reset_delivery_failed", {
      requestId,
      attemptCount: lease.attemptCount,
      errorCode: disposition.code,
      disposition: disposition.action,
    });
    if (disposition.action === "fail") {
      await (deps.updateLease || updateIfLeaseMatches)({
        db,
        requestRef,
        leaseId,
        update: {
          status: "discarded",
          discardReason: `permanent_${disposition.code}`,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          email: admin.firestore.FieldValue.delete(),
          leaseId: admin.firestore.FieldValue.delete(),
          leaseExpiresAt: admin.firestore.FieldValue.delete(),
        },
      });
      return null;
    }
    await (deps.updateLease || updateIfLeaseMatches)({
      db,
      requestRef,
      leaseId,
      update: {
        status: "retry",
        lastErrorCode: disposition.code,
        retryAt: new Date(
            now.getTime() + retryDelayMillis(lease.attemptCount),
        ),
        leaseId: admin.firestore.FieldValue.delete(),
        leaseExpiresAt: admin.firestore.FieldValue.delete(),
      },
    });
    const retryError = new Error("Password reset delivery will be retried");
    retryError.code = disposition.code;
    throw retryError;
  }
}

exports.requestPasswordReset = functions
    .runWith({
      enforceAppCheck: true,
      memory: "256MB",
      secrets: [PASSWORD_RESET_HMAC_SECRET],
      timeoutSeconds: 15,
    })
    .https.onCall(requestPasswordResetHandler);

exports.processPasswordResetRequest = functions
    .runWith({
      failurePolicy: true,
      memory: "256MB",
      secrets: ["RESEND_API_KEY"],
      timeoutSeconds: 60,
    })
    .firestore.document(`${PASSWORD_RESET_REQUESTS}/{requestId}`)
    .onCreate(processPasswordResetRequestHandler);

exports.__private__ = {
  MAX_DELIVERY_ATTEMPTS,
  acquireDeliveryLease,
  buildLeaseDecision,
  buildRateLimitDecision,
  deliveryErrorDisposition,
  enqueuePasswordResetRequest,
  hmacIdentity,
  normalizeEmail,
  passwordResetEmailHtml,
  passwordResetEmailText,
  processPasswordResetRequestHandler,
  retryDelayMillis,
  requestPasswordResetHandler,
  sendPasswordResetEmail,
  updateIfLeaseMatches,
};
