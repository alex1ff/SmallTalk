const admin = require("firebase-admin/app");
admin.initializeApp();

const createVideoSession = require("./create_video_session.js");
exports.createVideoSession = createVideoSession.createVideoSession;
const acceptCall = require("./accept_call.js");
exports.acceptCall = acceptCall.acceptCall;
const declineCall = require("./decline_call.js");
exports.declineCall = declineCall.declineCall;
const cancelCall = require("./cancel_call.js");
exports.cancelCall = cancelCall.cancelCall;
const processExpiredNotifications = require("./process_expired_notifications.js");
exports.processExpiredNotifications =
  processExpiredNotifications.processExpiredNotifications;
const endSession = require("./end_session.js");
exports.endSession = endSession.endSession;
const requestSessionExtension = require("./request_session_extension.js");
exports.requestSessionExtension =
  requestSessionExtension.requestSessionExtension;
const cleanupExpiredSessions = require("./cleanup_expired_sessions.js");
exports.cleanupExpiredSessions = cleanupExpiredSessions.cleanupExpiredSessions;
const getSessionTokens = require("./get_session_tokens.js");
exports.getSessionTokens = getSessionTokens.getSessionTokens;
const getDeepgramToken = require("./get_deepgram_token.js");
exports.getDeepgramToken = getDeepgramToken.getDeepgramToken;
const submitReview = require("./submit_review.js");
exports.submitReview = submitReview.submitReview;
const createPaymentSession = require("./create_payment_session.js");
exports.createPaymentSession = createPaymentSession.createPaymentSession;
const conversationUnlockEvents = require("./conversation_unlock_events.js");
exports.processConversationUnlockEvents =
  conversationUnlockEvents.processConversationUnlockEvents;
exports.repairMissingConversationUnlockEvents =
  conversationUnlockEvents.repairMissingConversationUnlockEvents;
const conversationMessageSummaries = require("./conversation_message_summaries.js");
exports.updateConversationMessageSummary =
  conversationMessageSummaries.updateConversationMessageSummary;
exports.repairConversationMessageSummaries =
  conversationMessageSummaries.repairConversationMessageSummaries;
const userMatchProfileSync = require("./user_match_profile_sync.js");
exports.syncUserMatchProfile = userMatchProfileSync.syncUserMatchProfile;
const teacherVerificationRequests = require("./teacher_verification_requests.js");
exports.syncTeacherVerificationRequest =
  teacherVerificationRequests.syncTeacherVerificationRequest;
