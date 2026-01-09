const admin = require("firebase-admin/app");
admin.initializeApp();

const createVideoSession = require("./create_video_session.js");
exports.createVideoSession = createVideoSession.createVideoSession;
exports.createCallRequest = createVideoSession.createVideoSession;
const acceptCall = require("./accept_call.js");
exports.acceptCall = acceptCall.acceptCall;
const declineCall = require("./decline_call.js");
exports.declineCall = declineCall.declineCall;
const cancelCall = require("./cancel_call.js");
exports.cancelCall = cancelCall.cancelCall;
exports.cancelCallRequest = cancelCall.cancelCall;
const processExpiredNotifications = require("./process_expired_notifications.js");
exports.processExpiredNotifications =
  processExpiredNotifications.processExpiredNotifications;
const endSession = require("./end_session.js");
exports.endSession = endSession.endSession;
exports.endCall = endSession.endSession;
const getSessionTokens = require("./get_session_tokens.js");
exports.getSessionTokens = getSessionTokens.getSessionTokens;
const cleanupExpiredSessions = require("./cleanup_expired_sessions.js");
exports.cleanupExpiredSessions = cleanupExpiredSessions.cleanupExpiredSessions;
