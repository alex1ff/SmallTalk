const admin = require("firebase-admin/app");
admin.initializeApp();

const createVideoSession = require("./create_video_session.js");
exports.createVideoSession = createVideoSession.createVideoSession;
const directCallStatus = require("./direct_call_status.js");
exports.getDirectCallStatus = directCallStatus.getDirectCallStatus;
const acceptCall = require("./accept_call.js");
exports.acceptCall = acceptCall.acceptCall;
const declineCall = require("./decline_call.js");
exports.declineCall = declineCall.declineCall;
const cancelCall = require("./cancel_call.js");
exports.cancelCall = cancelCall.cancelCall;
const startSearch = require("./start_search.js");
exports.startSearch = startSearch.startSearch;
const stopSearch = require("./stop_search.js");
exports.stopSearch = stopSearch.stopSearch;
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
const failedDailyRoomDeleteCleanup = require(
  "./cleanup_failed_daily_room_deletes.js",
);
exports.cleanupFailedDailyRoomDeletes =
  failedDailyRoomDeleteCleanup.cleanupFailedDailyRoomDeletes;
const getSessionTokens = require("./get_session_tokens.js");
exports.getSessionTokens = getSessionTokens.getSessionTokens;
const markSessionConnected = require("./mark_session_connected.js");
exports.markSessionConnected = markSessionConnected.markSessionConnected;
const dailyWebhook = require("./daily_webhook.js");
exports.dailyWebhook = dailyWebhook.dailyWebhook;
const getDeepgramToken = require("./get_deepgram_token.js");
exports.getDeepgramToken = getDeepgramToken.getDeepgramToken;
const registerVoipToken = require("./register_voip_token.js");
exports.registerVoipToken = registerVoipToken.registerVoipToken;
const legacyVoipTokenMigration = require("./migrate_legacy_voip_tokens.js");
exports.migrateLegacyVoipTokens =
  legacyVoipTokenMigration.migrateLegacyVoipTokens;
exports.scheduledLegacyVoipTokenMigration =
  legacyVoipTokenMigration.scheduledLegacyVoipTokenMigration;
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
const publicUserProfiles = require("./public_user_profiles.js");
exports.syncUserPublicProfile = publicUserProfiles.syncUserPublicProfile;
const teacherVerificationRequests = require("./teacher_verification_requests.js");
exports.syncTeacherVerificationRequest =
  teacherVerificationRequests.syncTeacherVerificationRequest;
const emailVerification = require("./email_verification.js");
exports.sendCustomEmailVerification =
  emailVerification.sendCustomEmailVerification;
const persistCallChat = require("./persist_call_chat.js");
exports.persistCallChat = persistCallChat.persistCallChat;
const revenueCatWebhook = require("./revenue_cat_webhook.js");
exports.revenueCatWebhook = revenueCatWebhook.revenueCatWebhook;
const grantPromoEntitlement = require("./grant_promo_entitlement.js");
exports.grantPromoEntitlement = grantPromoEntitlement.grantPromoEntitlement;
const redeemPromoCode = require("./redeem_promo_code.js");
exports.redeemPromoCode = redeemPromoCode.redeemPromoCode;
const claimRegistrationGift = require("./claim_registration_gift.js");
exports.claimRegistrationGift = claimRegistrationGift.claimRegistrationGift;
const createEvent = require("./create_event.js");
exports.createEvent = createEvent.createEvent;
const editEvent = require("./edit_event.js");
exports.editEvent = editEvent.editEvent;
const cancelEvent = require("./cancel_event.js");
exports.cancelEvent = cancelEvent.cancelEvent;
const joinEvent = require("./join_event.js");
exports.joinEvent = joinEvent.joinEvent;
const leaveEvent = require("./leave_event.js");
exports.leaveEvent = leaveEvent.leaveEvent;
const sendEventChatMessage = require("./send_event_chat_message.js");
exports.sendEventChatMessage = sendEventChatMessage.sendEventChatMessage;
const getEventChatAccessState = require("./get_event_chat_access_state.js");
exports.getEventChatAccessState =
  getEventChatAccessState.getEventChatAccessState;
const requestWithdrawal = require("./request_withdrawal.js");
exports.requestWithdrawal = requestWithdrawal.requestWithdrawal;
const cleanupExpiredGifts = require("./cleanup_expired_gifts.js");
exports.cleanupExpiredGifts = cleanupExpiredGifts.cleanupExpiredGifts;
