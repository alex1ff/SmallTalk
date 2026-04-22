const axios = require("axios");

const DAILY_ROOM_CONFIG_VERSION = 2;
const DAILY_ROOM_MAX_PARTICIPANTS = 4;
const DAILY_ROOM_ENFORCE_UNIQUE_USER_IDS = true;

function getDailyEnv() {
  const apiKey = process.env.DAILY_API_KEY
    ? String(process.env.DAILY_API_KEY).trim()
    : "";
  const domain = process.env.DAILY_DOMAIN
    ? String(process.env.DAILY_DOMAIN).trim()
    : "";
  if (!apiKey) {
    throw new Error("DAILY_API_KEY environment variable not set");
  }
  if (!domain) {
    throw new Error("DAILY_DOMAIN environment variable not set");
  }
  return { apiKey, domain };
}

function getRoomNameFromUrl(roomUrl) {
  try {
    if (!roomUrl) return null;
    const uri = new URL(roomUrl);
    const segments = uri.pathname.split("/").filter(Boolean);
    return segments.length > 0 ? segments[segments.length - 1] : null;
  } catch (e) {
    return null;
  }
}

async function getDailyRoom(roomName) {
  if (!roomName) return null;
  const { apiKey } = getDailyEnv();
  try {
    const response = await axios.get(
      `https://api.daily.co/v1/rooms/${roomName}`,
      {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
          "User-Agent": "SmallTalk-App/1.0",
        },
        timeout: 5000,
      },
    );
    return response.data;
  } catch (error) {
    if (error?.response?.status === 404) {
      return null;
    }
    throw error;
  }
}

function decodeTokenClaims(token) {
  if (!token || typeof token !== "string") return null;
  try {
    const parts = token.split(".");
    if (parts.length < 2) return null;
    const payload = parts[1]
      .replace(/-/g, "+")
      .replace(/_/g, "/")
      .padEnd(Math.ceil(parts[1].length / 4) * 4, "=");
    const decoded = Buffer.from(payload, "base64").toString("utf8");
    return JSON.parse(decoded);
  } catch (e) {
    return null;
  }
}

function getDailyRoomConfig(room) {
  if (!room || typeof room !== "object") return {};
  const config = room.config || room.properties || {};
  return config && typeof config === "object" ? config : {};
}

function isDailyRoomConfigCompatible(room) {
  const config = getDailyRoomConfig(room);
  return Number(config.max_participants || 0) >= DAILY_ROOM_MAX_PARTICIPANTS &&
    config.enforce_unique_user_ids === DAILY_ROOM_ENFORCE_UNIQUE_USER_IDS;
}

function buildRoomConfig({ name, language, expSeconds }) {
  const exp = Math.floor(Date.now() / 1000) + expSeconds;
  return {
    name,
    privacy: "private",
    properties: {
      // Keep 1:1 authorization in server-issued meeting tokens, but leave
      // headroom for Daily's own reconnect/ghost-participant cleanup window.
      max_participants: DAILY_ROOM_MAX_PARTICIPANTS,
      // Daily ejects stale reconnects with the same token user_id instead of
      // counting ghost participants against the room limit.
      enforce_unique_user_ids: DAILY_ROOM_ENFORCE_UNIQUE_USER_IDS,
      enable_chat: false,
      enable_screenshare: true,
      enable_recording: false,
      start_audio_off: false,
      start_video_off: false,
      exp,
      enable_knocking: false,
      enable_prejoin_ui: false,
      enable_people_ui: false,
      enable_pip_ui: false,
      enable_network_ui: false,
      enable_noise_cancellation_ui: true,
      lang: language,
      enable_dialin: false,
      enable_dialout: false,
      enable_terse_logging: false,
      signaling_impl: "ws",
      geo: "auto",
      sfu_switchover: 0.5,
      enable_adaptive_simulcast: true,
      enable_multiparty_adaptive_simulcast: false,
    },
  };
}

async function createDailyRoom({
  language,
  studentId,
  tutorId,
  studentName,
  tutorName,
  expSeconds = 3600,
}) {
  const { apiKey } = getDailyEnv();

  const timestamp = Date.now();
  const randomStr = Math.random().toString(36).substr(2, 9);
  const roomName = `session_${timestamp}_${randomStr}`;

  console.log("🏠 Creating Daily room:", {
    name: roomName,
    language,
    participants: [studentName, tutorName],
    studentId,
    tutorId,
    expSeconds,
  });

  const roomConfig = buildRoomConfig({ name: roomName, language, expSeconds });

  const response = await axios.post(
    "https://api.daily.co/v1/rooms",
    roomConfig,
    {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "User-Agent": "SmallTalk-App/1.0",
      },
      timeout: 10000,
    },
  );

  const room = response.data;
  console.log("✅ Daily room created:", {
    name: room.name,
    url: room.url,
    privacy: room.privacy,
    created_at: room.created_at,
  });

  return {
    name: room.name,
    url: room.url,
    config: room.config,
    configVersion: DAILY_ROOM_CONFIG_VERSION,
    created_at: room.created_at,
  };
}

async function createMeetingToken({
  roomName,
  expSeconds = 3600,
  isOwner = false,
  userId = null,
  userName = null,
}) {
  if (!roomName) {
    throw new Error("roomName is required for meeting token");
  }
  const { apiKey } = getDailyEnv();

  const tokenConfig = {
    properties: {
      room_name: roomName,
      is_owner: !!isOwner,
      exp: Math.floor(Date.now() / 1000) + expSeconds,
      enable_screenshare: true,
      enable_recording: false,
    },
  };

  if (userId) {
    tokenConfig.properties.user_id = String(userId);
  }
  if (userName) {
    tokenConfig.properties.user_name = String(userName);
  }

  const response = await axios.post(
    "https://api.daily.co/v1/meeting-tokens",
    tokenConfig,
    {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      timeout: 5000,
    },
  );

  const token = response.data.token;
  const claims = decodeTokenClaims(token);
  if (claims) {
    console.log("🔎 Meeting token claims", {
      room: claims.r,
      isOwner: claims.o,
      exp: claims.exp,
      userId: claims.ud,
    });
  } else {
    console.log("🔎 Meeting token created (claims decode failed)", {
      roomName,
      isOwner: !!isOwner,
      hasUser: !!userId,
    });
  }
  return token;
}

async function deleteDailyRoom(roomName) {
  if (!roomName) return null;

  try {
    const { apiKey } = getDailyEnv();
    await axios.delete(`https://api.daily.co/v1/rooms/${roomName}`, {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      timeout: 5000,
    });
    console.log("🧹 Daily room deleted:", roomName);
    return true;
  } catch (error) {
    console.error(
      "⚠️ Failed to delete Daily room (non-critical):",
      roomName,
      error.response?.data || error.message,
    );
    return false;
  }
}

module.exports = {
  createDailyRoom,
  createMeetingToken,
  deleteDailyRoom,
  getDailyRoom,
  getRoomNameFromUrl,
  isDailyRoomConfigCompatible,
  DAILY_ROOM_CONFIG_VERSION,
  __private__: {
    DAILY_ROOM_CONFIG_VERSION,
    DAILY_ROOM_ENFORCE_UNIQUE_USER_IDS,
    DAILY_ROOM_MAX_PARTICIPANTS,
    buildRoomConfig,
    isDailyRoomConfigCompatible,
  },
};
