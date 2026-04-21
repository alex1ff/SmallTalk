const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const axios = require("axios");

const RESEND_SEND_EMAIL_URL = "https://api.resend.com/emails";
const RESEND_TIMEOUT_MS = 10000;

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
  };
}

function formatSenderAddress(emailFrom) {
  if (!emailFrom) {
    return "";
  }

  return emailFrom.includes("<") ? emailFrom : `SmallTalk <${emailFrom}>`;
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

function buildVerificationEmailText({
  displayName = "",
  verificationLink,
}) {
  const greeting = displayName ? `${displayName}, здравствуйте!` : "Здравствуйте!";

  return [
    greeting,
    "",
    "Подтвердите email для SmallTalk, чтобы мы могли присылать важные уведомления и помочь восстановить аккаунт при необходимости.",
    "",
    `Ссылка для подтверждения: ${verificationLink}`,
    "",
    "Если вы не создавали аккаунт в SmallTalk, просто проигнорируйте это письмо.",
    "",
    "SmallTalk",
  ].join("\n");
}

function buildVerificationEmailHtml({
  displayName = "",
  verificationLink,
}) {
  const safeDisplayName = escapeHtml(displayName);
  const safeLink = escapeHtml(verificationLink);
  const greeting = safeDisplayName ?
    `${safeDisplayName}, подтвердите email` :
    "Подтвердите email";

  return `<!doctype html>
<html lang="ru">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="color-scheme" content="light">
    <title>Подтвердите email для SmallTalk</title>
  </head>
  <body style="margin:0;background:#f4f1ea;color:#161616;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;">
    <div style="display:none;max-height:0;overflow:hidden;opacity:0;">
      Один клик, чтобы подтвердить адрес и защитить аккаунт SmallTalk.
    </div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f1ea;padding:28px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#fffdf8;border-radius:30px;overflow:hidden;border:1px solid #e8dfcf;">
            <tr>
              <td style="padding:30px 28px 10px;">
                <div style="font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:#8a6b43;font-weight:700;">SmallTalk</div>
                <h1 style="margin:18px 0 10px;font-size:32px;line-height:1.05;color:#141414;font-weight:800;">${greeting}</h1>
                <p style="margin:0;color:#5f5a51;font-size:16px;line-height:1.55;">
                  Подтвердите адрес, чтобы получать важные уведомления, безопасно восстанавливать аккаунт и не пропустить сообщения от собеседников.
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:18px 28px 8px;">
                <a href="${safeLink}" style="display:inline-block;background:#141414;color:#ffffff;text-decoration:none;border-radius:999px;padding:15px 24px;font-size:16px;font-weight:700;">
                  Подтвердить email
                </a>
              </td>
            </tr>
            <tr>
              <td style="padding:18px 28px 28px;">
                <p style="margin:0 0 10px;color:#7b756b;font-size:13px;line-height:1.5;">
                  Если кнопка не работает, откройте ссылку вручную:
                </p>
                <p style="margin:0;word-break:break-all;color:#141414;font-size:13px;line-height:1.5;">
                  <a href="${safeLink}" style="color:#141414;">${safeLink}</a>
                </p>
              </td>
            </tr>
            <tr>
              <td style="background:#191919;padding:20px 28px;color:#f6efe2;font-size:13px;line-height:1.5;">
                Если вы не создавали аккаунт в SmallTalk, просто проигнорируйте это письмо.
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
  config,
  resendClient = axios,
}) {
  assertEmailConfig(config);

  const payload = {
    from: formatSenderAddress(config.emailFrom),
    to: [email],
    subject: "Подтвердите email для SmallTalk",
    html: buildVerificationEmailHtml({
      displayName,
      verificationLink,
    }),
    text: buildVerificationEmailText({
      displayName,
      verificationLink,
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
  const verificationLink =
    await authClient.generateEmailVerificationLink(email);

  try {
    const sendResult = await sendEmailWithResend({
      email,
      displayName: user.displayName || "",
      verificationLink,
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

    console.error("sendCustomEmailVerification failed", {
      uid,
      code: error?.code || null,
      response: error?.response?.data || null,
      message: error?.message || "Unknown error",
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

exports.sendCustomEmailVerification = functions.https.onCall(
  sendCustomEmailVerificationHandler,
);

exports.__private__ = {
  buildVerificationEmailHtml,
  buildVerificationEmailText,
  formatSenderAddress,
  resolveEmailConfig,
  sendCustomEmailVerificationHandler,
  sendEmailWithResend,
};
