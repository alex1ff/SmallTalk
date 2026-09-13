const http2 = require("http2");
const crypto = require("crypto");

const APNS_PROD_HOST = "api.push.apple.com";
const APNS_SANDBOX_HOST = "api.sandbox.push.apple.com";

let cachedJwt = null;
let cachedJwtIssuedAt = 0;

function base64Url(input) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function normalizeKey(raw) {
  if (!raw) return null;
  let key = String(raw).trim();
  if (key.includes("\\n")) {
    key = key.replace(/\\n/g, "\n");
  }
  if (key.includes("-----BEGIN")) {
    return key;
  }
  if (/^[A-Za-z0-9+/=]+$/.test(key)) {
    try {
      const decoded = Buffer.from(key, "base64").toString("utf8");
      if (decoded.includes("-----BEGIN")) {
        return decoded;
      }
    } catch (error) {
      // ignore base64 decode errors
    }
  }
  return `-----BEGIN PRIVATE KEY-----\n${key}\n-----END PRIVATE KEY-----`;
}

function getApnsJwt() {
  const key = normalizeKey(process.env.APNS_KEY_P8 || process.env.APNS_KEY);
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;

  if (!key || !keyId || !teamId) {
    throw new Error(
      "APNs credentials are missing. Set APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID.",
    );
  }

  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwtIssuedAt < 50 * 60) {
    return cachedJwt;
  }

  const header = base64Url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const payload = base64Url(JSON.stringify({ iss: teamId, iat: now }));
  const unsignedToken = `${header}.${payload}`;

  const signature = crypto.sign("sha256", Buffer.from(unsignedToken), {
    key,
    dsaEncoding: "ieee-p1363",
  });

  cachedJwt = `${unsignedToken}.${base64Url(signature)}`;
  cachedJwtIssuedAt = now;
  return cachedJwt;
}

function normalizeDeviceToken(token) {
  if (!token || typeof token !== "string") return "";
  return token.replace(/[<>\s]/g, "");
}

function getApnsHost() {
  const env = (process.env.APNS_ENV || "production").toLowerCase();
  return env === "sandbox" ? APNS_SANDBOX_HOST : APNS_PROD_HOST;
}

async function sendApnsVoip({
  deviceToken,
  topic,
  payload,
  pushType = "voip",
  priority = "10",
  expiration = null,
  collapseId = "",
  signal = null,
}) {
  const token = normalizeDeviceToken(deviceToken);
  if (!token) {
    throw new Error("APNs device token is empty");
  }
  if (!topic) {
    throw new Error("APNs topic is missing");
  }

  const jwt = getApnsJwt();
  const host = getApnsHost();

  const client = http2.connect(`https://${host}`);

  return new Promise((resolve, reject) => {
    let responseData = "";
    let statusCode = 0;
    let settled = false;
    let request = null;

    const readAbortError = () => {
      if (signal?.reason instanceof Error) {
        return signal.reason;
      }
      return new Error("APNs request aborted");
    };
    const cleanup = () => {
      signal?.removeEventListener?.("abort", abortRequest);
    };
    const settle = (callback, value) => {
      if (settled) {
        return;
      }
      settled = true;
      cleanup();
      client.close();
      callback(value);
    };
    const abortRequest = () => {
      const abortError = readAbortError();
      request?.destroy?.(abortError);
      client.destroy?.(abortError);
      settle(reject, abortError);
    };

    client.on("error", (error) => {
      settle(reject, error);
    });

    if (signal?.aborted) {
      abortRequest();
      return;
    }
    signal?.addEventListener?.("abort", abortRequest, {once: true});

    const headers = {
      ":method": "POST",
      ":path": `/3/device/${token}`,
      authorization: `bearer ${jwt}`,
      "apns-topic": topic,
      "apns-push-type": pushType,
      "apns-priority": priority,
      "content-type": "application/json",
    };
    const normalizedExpiration = Number(expiration);
    if (Number.isInteger(normalizedExpiration) && normalizedExpiration >= 0) {
      headers["apns-expiration"] = String(normalizedExpiration);
    }
    const normalizedCollapseId = typeof collapseId === "string" ?
      collapseId.trim().slice(0, 64) :
      "";
    if (normalizedCollapseId) {
      headers["apns-collapse-id"] = normalizedCollapseId;
    }
    request = client.request(headers);

    request.setEncoding("utf8");

    request.on("response", (headers) => {
      statusCode = headers[":status"] || 0;
    });

    request.on("data", (chunk) => {
      responseData += chunk;
    });

    request.on("end", () => {
      if (statusCode >= 200 && statusCode < 300) {
        settle(resolve, { statusCode, responseData });
        return;
      }
      settle(reject, new Error(`APNs error ${statusCode}: ${responseData}`));
    });

    request.on("error", (error) => {
      settle(reject, error);
    });

    request.end(JSON.stringify(payload || {}));
  });
}

module.exports = {
  sendApnsVoip,
};
