const axios = require("axios");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "daily_room"});

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

function resolveDailyRoomName(sessionData = {}) {
  const roomName = sessionData.dailyRoomName
    ? String(sessionData.dailyRoomName).trim()
    : "";
  return roomName || getRoomNameFromUrl(sessionData.dailyRoomUrl);
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

async function getDailyRoomPresence(roomName) {
  if (!roomName) {
    return { participants: [], count: 0 };
  }

  const { apiKey } = getDailyEnv();

  const response = await axios.get(
    "https://api.daily.co/v1/presence",
    {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "User-Agent": "SmallTalk-App/1.0",
      },
      timeout: 5000,
    },
  );
  const participants = readDailyPresenceParticipants(
    response.data || {},
    roomName,
  );
  return {
    roomName,
    participants,
    count: participants.length,
  };
}

function readDailyPresenceParticipants(presenceData = {}, roomName = "") {
  if (!presenceData || typeof presenceData !== "object") {
    return [];
  }
  if (Array.isArray(presenceData)) {
    return presenceData.filter((participant) => {
      return participant && typeof participant === "object";
    });
  }
  const normalizedRoomName = typeof roomName === "string" ? roomName.trim() : "";
  if (
    normalizedRoomName &&
    Array.isArray(presenceData[normalizedRoomName])
  ) {
    return readDailyPresenceParticipants(presenceData[normalizedRoomName]);
  }
  return Array.isArray(presenceData.participants)
    ? presenceData.participants.filter((participant) => {
      return participant && typeof participant === "object";
    })
    : [];
}

function dailyPresenceHasUser(presenceData = {}, userId, roomName = "") {
  const normalizedUserId = typeof userId === "string" ? userId.trim() : "";
  if (!normalizedUserId) {
    return false;
  }

  return readDailyPresenceParticipants(presenceData, roomName)
    .some((participant) => {
    const candidateIds = [
      participant.user_id,
      participant.userId,
      participant.userID,
    ];
    return candidateIds.some((candidate) => {
      return typeof candidate === "string" && candidate.trim() === normalizedUserId;
    });
  });
}

function dailyPresenceHasAcceptedParticipants({
  presenceData = {},
  roomName = "",
  participantIds = [],
}) {
  const normalizedParticipantIds = Array.isArray(participantIds)
    ? participantIds
      .map((participantId) => {
        return typeof participantId === "string" ? participantId.trim() : "";
      })
      .filter(Boolean)
    : [];
  if (normalizedParticipantIds.length < 2) {
    return false;
  }

  return normalizedParticipantIds.every((participantId) => {
    return dailyPresenceHasUser(presenceData, participantId, roomName);
  });
}

async function isDailyUserPresentInRoom({ roomName, userId }) {
  const presence = await getDailyRoomPresence(roomName);
  return dailyPresenceHasUser(presence, userId);
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
      geo: "eu-central-1",
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
  expSeconds = 3600,
}) {
  const { apiKey } = getDailyEnv();

  const timestamp = Date.now();
  const randomStr = Math.random().toString(36).substr(2, 9);
  const roomName = `session_${timestamp}_${randomStr}`;

  safeLog.log("daily_room_create_started", {
    roomName,
    studentId,
    tutorId,
    requestedLanguage: language,
    ttlSeconds: expSeconds,
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
  safeLog.log("daily_room_created", {roomName: room.name});

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
  safeLog.log("meeting_token_created", {roomName, userId});
  return token;
}

function isDailyRoomAlreadyDeletedError(error) {
  if (!error || !error.response) return false;
  return error.response.status === 404 || error.response.data?.deleted === true;
}

async function deleteDailyRoom(roomName) {
  if (!roomName) return null;

  try {
    const { apiKey } = getDailyEnv();
    await axios.delete(
      `https://api.daily.co/v1/rooms/${encodeURIComponent(roomName)}`,
      {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        timeout: 5000,
      },
    );
    safeLog.log("daily_room_deleted", {roomName});
    return true;
  } catch (error) {
    if (isDailyRoomAlreadyDeletedError(error)) {
      safeLog.log("daily_room_already_deleted", {roomName});
      return true;
    }
    safeLog.error("daily_room_delete_failed", {roomName, error});
    return false;
  }
}

module.exports = {
  createDailyRoom,
  createMeetingToken,
  deleteDailyRoom,
  getDailyRoom,
  getDailyRoomPresence,
  getRoomNameFromUrl,
  isDailyUserPresentInRoom,
  resolveDailyRoomName,
  isDailyRoomConfigCompatible,
  DAILY_ROOM_CONFIG_VERSION,
  __private__: {
    DAILY_ROOM_CONFIG_VERSION,
    DAILY_ROOM_ENFORCE_UNIQUE_USER_IDS,
    DAILY_ROOM_MAX_PARTICIPANTS,
    buildRoomConfig,
    dailyPresenceHasAcceptedParticipants,
    dailyPresenceHasUser,
    isDailyRoomAlreadyDeletedError,
    isDailyRoomConfigCompatible,
    readDailyPresenceParticipants,
    resolveDailyRoomName,
  },
};
