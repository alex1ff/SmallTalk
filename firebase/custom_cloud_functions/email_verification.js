const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const axios = require("axios");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "email_verification"});

const RESEND_SEND_EMAIL_URL = "https://api.resend.com/emails";
const RESEND_TIMEOUT_MS = 10000;
const DEFAULT_EMAIL_ACTION_HANDLER_URL =
  "https://smalltalk-2109b.firebaseapp.com/auth/action";
const DEFAULT_APP_DEEP_LINK =
  "smalltalk://smalltalk.com/?emailVerified=1";
const BRAND_NAME = "Expatlio";
const resendSecrets = ["RESEND_API_KEY"];

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function escapeHtml(value) {
  return normalizeString(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function resolveEmailConfig(env = process.env) {
  return {
    resendApiKey: normalizeString(env.RESEND_API_KEY),
    emailFrom: normalizeString(env.EMAIL_FROM),
    emailReplyTo: normalizeString(env.EMAIL_REPLY_TO),
    emailActionHandlerUrl:
      normalizeString(env.EMAIL_ACTION_HANDLER_URL) ||
      DEFAULT_EMAIL_ACTION_HANDLER_URL,
    appDeepLink: normalizeString(env.APP_DEEP_LINK) || DEFAULT_APP_DEEP_LINK,
  };
}

function formatSenderAddress(emailFrom) {
  if (!emailFrom) {
    return "";
  }

  return emailFrom.includes("<") ? emailFrom : `${BRAND_NAME} <${emailFrom}>`;
}

function assertEmailConfig(config) {
  if (!config.resendApiKey || !config.emailFrom) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Custom email sender is not configured.",
      {
        reason: "missing_resend_config",
      },
    );
  }
}

function normalizeLocale(value) {
  const locale = normalizeString(value).toLowerCase();
  return locale.startsWith("en") ? "en" : "ru";
}

function buildEmailActionHandlerLink({
  firebaseLink,
  locale,
  handlerUrl,
  appDeepLink,
}) {
  const sourceUrl = new URL(firebaseLink);
  const actionUrl = new URL(handlerUrl);

  for (const key of ["mode", "oobCode", "apiKey"]) {
    const value = sourceUrl.searchParams.get(key);
    if (value) {
      actionUrl.searchParams.set(key, value);
    }
  }

  actionUrl.searchParams.set("lang", normalizeLocale(locale));
  actionUrl.searchParams.set("continueUrl", appDeepLink);

  return actionUrl.toString();
}

function buildVerificationEmailText({
  displayName = "",
  verificationLink,
  locale = "ru",
}) {
  if (normalizeLocale(locale) === "en") {
    const greeting = displayName ? `Hi ${displayName},` : "Hi,";

    return [
      greeting,
      "",
      `Confirm your email to finish setting up ${BRAND_NAME} and keep your account secure.`,
      "",
      `Verification link: ${verificationLink}`,
      "",
      `If you did not create a ${BRAND_NAME} account, you can ignore this email.`,
      "",
      BRAND_NAME,
    ].join("\n");
  }

  const greeting = displayName ? `${displayName}, здравствуйте!` : "Здравствуйте!";

  return [
    greeting,
    "",
    `Подтвердите email, чтобы завершить настройку ${BRAND_NAME} и защитить аккаунт.`,
    "",
    `Ссылка для подтверждения: ${verificationLink}`,
    "",
    `Если вы не создавали аккаунт в ${BRAND_NAME}, просто проигнорируйте это письмо.`,
    "",
    BRAND_NAME,
  ].join("\n");
}

function buildVerificationEmailHtml({
  displayName = "",
  verificationLink,
  locale = "ru",
}) {
  const safeDisplayName = escapeHtml(displayName);
  const safeLink = escapeHtml(verificationLink);
  const isEnglish = normalizeLocale(locale) === "en";
  const greeting = isEnglish ?
    (safeDisplayName ? `Hi ${safeDisplayName}, confirm your email` :
      "Confirm your email") :
    (safeDisplayName ? `${safeDisplayName}, подтвердите email` :
      "Подтвердите email");
  const title = isEnglish ?
    `Confirm your email for ${BRAND_NAME}` :
    `Подтвердите email в ${BRAND_NAME}`;
  const body = isEnglish ?
    `One tap confirms your address and helps keep your ${BRAND_NAME} account secure.` :
    `Один клик подтвердит адрес и поможет защитить ваш аккаунт ${BRAND_NAME}.`;
  const button = isEnglish ? "Confirm email" : "Подтвердить email";
  const fallbackIntro = isEnglish ?
    "If the button does not work, open this link manually:" :
    "Если кнопка не работает, откройте ссылку вручную:";
  const footer = isEnglish ?
    `If you did not create a ${BRAND_NAME} account, you can ignore this email.` :
    `Если вы не создавали аккаунт в ${BRAND_NAME}, просто проигнорируйте это письмо.`;
  const preheader = isEnglish ?
    `Confirm your ${BRAND_NAME} email in one tap.` :
    `Подтвердите email в ${BRAND_NAME} одним нажатием.`;

  return `<!doctype html>
<html lang="${isEnglish ? "en" : "ru"}">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="color-scheme" content="light">
    <title>${title}</title>
  </head>
  <body style="margin:0;background:#f2f2f7;color:#000000;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;">
    <div style="display:none;max-height:0;overflow:hidden;opacity:0;">
      ${preheader}
    </div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f2f2f7;padding:28px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:20px;overflow:hidden;border:1px solid #e5e5ea;">
            <tr>
              <td style="padding:30px 28px 8px;">
                <table role="presentation" cellspacing="0" cellpadding="0">
                  <tr>
                    <td style="width:42px;height:42px;border-radius:14px;background:#7430e8;color:#ffffff;text-align:center;font-size:23px;line-height:42px;font-weight:800;">E</td>
                    <td style="padding-left:12px;font-size:18px;line-height:1.2;color:#000000;font-weight:800;">${BRAND_NAME}</td>
                  </tr>
                </table>
                <h1 style="margin:24px 0 10px;font-size:30px;line-height:1.12;color:#000000;font-weight:800;">${greeting}</h1>
                <p style="margin:0;color:#6b6b73;font-size:16px;line-height:1.55;">
                  ${body}
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:18px 28px 8px;">
                <a href="${safeLink}" style="display:inline-block;background:#7430e8;color:#ffffff;text-decoration:none;border-radius:16px;padding:15px 22px;font-size:16px;font-weight:700;">
                  ${button}
                </a>
              </td>
            </tr>
            <tr>
              <td style="padding:18px 28px 28px;">
                <p style="margin:0 0 10px;color:#6b6b73;font-size:13px;line-height:1.5;">
                  ${fallbackIntro}
                </p>
                <p style="margin:0;word-break:break-all;color:#000000;font-size:13px;line-height:1.5;">
                  <a href="${safeLink}" style="color:#7430e8;">${safeLink}</a>
                </p>
              </td>
            </tr>
            <tr>
              <td style="background:#f8f8fb;padding:18px 28px;color:#6b6b73;font-size:13px;line-height:1.5;border-top:1px solid #e5e5ea;">
                ${footer}
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

async function sendEmailWithResend({
  email,
  displayName,
  verificationLink,
  locale,
  config,
  resendClient = axios,
}) {
  assertEmailConfig(config);

  const payload = {
    from: formatSenderAddress(config.emailFrom),
    to: [email],
    subject: normalizeLocale(locale) === "en" ?
      `Confirm your email for ${BRAND_NAME}` :
      `Подтвердите email в ${BRAND_NAME}`,
    html: buildVerificationEmailHtml({
      displayName,
      verificationLink,
      locale,
    }),
    text: buildVerificationEmailText({
      displayName,
      verificationLink,
      locale,
    }),
  };

  if (config.emailReplyTo) {
    payload.reply_to = config.emailReplyTo;
  }

  const response = await resendClient.post(
    RESEND_SEND_EMAIL_URL,
    payload,
    {
      timeout: RESEND_TIMEOUT_MS,
      headers: {
        Authorization: `Bearer ${config.resendApiKey}`,
        "Content-Type": "application/json",
      },
    },
  );

  return {
    id: response?.data?.id || null,
  };
}

async function sendCustomEmailVerificationHandler(data, context, deps = {}) {
  const uid = normalizeString(context?.auth?.uid);
  const locale = normalizeLocale(data?.locale);
  if (!uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  const authClient = deps.authClient || admin.auth();
  const user = await authClient.getUser(uid);
  const email = normalizeString(user.email);
  if (!email) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "User does not have an email address.",
      {
        reason: "missing_email",
      },
    );
  }

  if (user.emailVerified) {
    return {
      sent: false,
      alreadyVerified: true,
    };
  }

  const config = resolveEmailConfig(deps.env || process.env);
  assertEmailConfig(config);
  const firebaseVerificationLink =
    await authClient.generateEmailVerificationLink(email);
  const verificationLink = buildEmailActionHandlerLink({
    firebaseLink: firebaseVerificationLink,
    locale,
    handlerUrl: config.emailActionHandlerUrl,
    appDeepLink: config.appDeepLink,
  });

  try {
    const sendResult = await sendEmailWithResend({
      email,
      displayName: user.displayName || "",
      verificationLink,
      locale,
      config,
      resendClient: deps.resendClient || axios,
    });

    return {
      sent: true,
      alreadyVerified: false,
      providerMessageId: sendResult.id,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    safeLog.error("verification_email_failed", {
      uid,
      errorCode: error?.code,
      error,
    });

    throw new functions.https.HttpsError(
      "unavailable",
      "Could not send verification email.",
      {
        reason: "resend_send_failed",
      },
    );
  }
}

exports.sendCustomEmailVerification = functions
  .runWith({secrets: resendSecrets})
  .https.onCall(sendCustomEmailVerificationHandler);

exports.__private__ = {
  buildEmailActionHandlerLink,
  buildVerificationEmailHtml,
  buildVerificationEmailText,
  formatSenderAddress,
  normalizeLocale,
  resolveEmailConfig,
  sendCustomEmailVerificationHandler,
  sendEmailWithResend,
};
