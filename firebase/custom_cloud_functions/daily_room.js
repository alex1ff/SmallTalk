const axios = require("axios");

function getDailyEnv() {
  const apiKey = process.env.DAILY_API_KEY;
  const domain = process.env.DAILY_DOMAIN;
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

function buildRoomConfig({ name, language, expSeconds }) {
  const exp = Math.floor(Date.now() / 1000) + expSeconds;
  return {
    name,
    privacy: "private",
    properties: {
      max_participants: 2,
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
    created_at: room.created_at,
  };
}

async function createMeetingToken({ roomName, expSeconds = 3600 }) {
  if (!roomName) {
    throw new Error("roomName is required for meeting token");
  }
  const { apiKey } = getDailyEnv();

  const tokenConfig = {
    properties: {
      room_name: roomName,
      is_owner: false,
      exp: Math.floor(Date.now() / 1000) + expSeconds,
      enable_screenshare: true,
      enable_recording: false,
    },
  };

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

  console.log("✅ Meeting token created");
  return response.data.token;
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
  getRoomNameFromUrl,
};
