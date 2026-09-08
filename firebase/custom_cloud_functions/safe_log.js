const crypto = require("node:crypto");
const functionsLogger = require("firebase-functions/logger");

const SAFE_EVENT_NAME = "backend_event";
const CORRELATION_PREFIX = "expatlio-log-v1:";

// Event names are code-owned. Unknown strings are collapsed so user/provider
// identifiers can never become searchable production metadata.
const SAFE_EVENT_NAMES = new Set([
  "accept_attempt", "accept_connected", "accept_failed", "accept_handler_started",
  "accept_idempotent_existing",
  "accept_lock_release_failed", "accept_post_tasks_completed",
  "accept_post_tasks_started", "accept_response", "accept_response_preparing",
  "accept_session_id_missing", "accept_transaction_completed",
  "accept_transaction_started", "accept_unauthenticated",
  "analytics_summary_failed", "background_billing_started",
  "background_student_notification_failed",
  "call_access_blocked", "call_lifecycle_event", "call_without_access",
  "cancel_attempt", "cancel_completed", "cancel_event_write_failed",
  "cancel_failed", "cancel_participant_mismatch", "cancel_started",
  "cancel_transaction_started", "candidate_query_failed",
  "chat_unlock_not_eligible", "chat_unlock_session_missing",
  "chat_unlock_write_failed", "chat_unlock_written",
  "cancel_event_failed", "create_event_failed", "edit_event_failed",
  "cleanup_active_session_expiring", "cleanup_call_event_write_failed",
  "cleanup_expired_gifts_completed", "cleanup_expired_gifts_empty",
  "cleanup_expired_gifts_failed", "cleanup_expired_gifts_started",
  "cleanup_failed_daily_room_deletes_completed",
  "cleanup_failed_daily_room_deletes_empty",
  "cleanup_failed_daily_room_deletes_failed",
  "cleanup_failed_daily_room_deletes_started",
  "cleanup_pending_session_expiring",
  "cleanup_search_requests_completed", "cleanup_search_requests_failed",
  "cleanup_sessions_completed", "cleanup_sessions_failed",
  "conversation_event_write_failed", "create_video_session_params",
  "daily_presence_check_failed", "daily_presence_verification_failed",
  "daily_room_already_deleted", "daily_room_cleanup_status_failed",
  "daily_room_create_failed", "daily_room_create_started", "daily_room_created",
  "daily_room_delete_failed", "daily_room_deleted",
  "daily_room_precreate_failed", "daily_room_precreated",
  "daily_room_recreate_required", "daily_room_resolve_started",
  "daily_room_validation_skipped", "daily_webhook_failed",
  "daily_webhook_processed", "daily_webhook_secret_missing",
  "daily_webhook_session_ambiguous", "daily_webhook_signature_invalid",
  "decline_attempt", "decline_completed", "decline_failed",
  "decline_handler_started", "decline_handoff_notification_created",
  "decline_handoff_started", "decline_notification_update_started",
  "decline_notification_updated", "decline_processing_started",
  "decline_responder_pool_failed", "declined_call_event_write_failed",
  "daily_room_delete_retry_failed", "daily_room_delete_retry_quarantine_failed",
  "daily_room_delete_retry_skipped",
  "deepgram_grant_forbidden", "deepgram_token_failed",
  "direct_tutor_invalid_role", "direct_tutor_not_found", "end_attempt",
  "end_completed", "end_failed", "end_participant_mismatch", "end_started",
  "end_transaction_completed", "expired_notification_completed",
  "event_chat_access_state_failed", "event_history_failed",
  "event_history_index_missing", "event_public_projection_repaired",
  "expired_notification_failed", "expired_notification_skipped",
  "expired_notification_started", "expired_notifications_empty",
  "expired_notifications_found", "expired_notifications_run_completed",
  "expired_notifications_run_failed", "expired_notifications_run_started",
  "feedback_provider_failed", "handoff_assignment_changed",
  "handoff_notification_changed", "handoff_notification_failed",
  "handoff_responder_busy", "handoff_session_missing",
  "legacy_notification_skipped", "locked_candidates_skipped",
  "join_event_failed", "leave_event_failed",
  "meeting_token_create_failed", "meeting_token_created",
  "missed_call_event_write_failed", "next_tutor_notification_skipped",
  "no_call_candidates", "no_matching_tutors",
  "non_callable_candidates_skipped", "notification_status_update_empty",
  "notification_status_update_failed", "notification_status_update_started",
  "notification_status_updated", "other_notifications_cancel_failed",
  "other_notifications_cancel_started", "other_notifications_cancelled",
  "password_reset_delivery_failed", "payment_failure_persist_failed",
  "payment_session_created", "payment_session_failed", "payment_session_started",
  "pre_active_surface_close_failed", "promo_grant_failed",
  "promo_code_redeem_failed", "promo_code_redeem_started",
  "promo_code_redeem_succeeded",
  "protocol_v2_finalization_retry_failed",
  "protocol_v2_terminal_recovery_deferred",
  "promo_grant_non_admin", "promo_grant_requested", "promo_grant_started",
  "promo_grant_succeeded", "recovered_room_update_failed",
  "repeat_guard_blocked", "requester_loaded", "requester_not_found",
  "request_withdrawal_failed",
  "responder_already_in_call", "responder_language_mismatch",
  "responder_role_invalid", "responder_unavailable",
  "revenuecat_secret_missing", "room_name_mismatch", "room_name_update_failed",
  "revenuecat_transfer_retry_completed", "registration_gift_claim_failed",
  "session_already_active", "session_billing_completed", "session_loaded",
  "session_not_cancellable", "session_not_declinable", "session_not_endable",
  "session_not_found", "session_notifications_cancel_failed",
  "session_notifications_cancel_started", "session_notifications_cancelled",
  "session_notifications_empty", "session_notifications_found",
  "session_responder_mismatch", "student_all_time_stats_failed",
  "student_today_stats_failed", "subscription_usage_increment_failed",
  "subscription_usage_daily_threshold_reached",
  "subscription_usage_weekly_threshold_reached",
  "start_search_failure_cleanup_failed", "start_search_index_unavailable",
  "start_search_matching_failed",
  "stop_search_apns_cancellation_failed",
  "stop_search_callkit_cancellation_failed",
  "stop_search_daily_room_cleanup_failed",
  "stop_search_notification_cleanup_failed",
  "timed_out_responder_reroute", "timeout_completed", "timeout_failed",
  "timeout_handoff_notification_created", "timeout_processing_started",
  "timeout_push_failed", "timeout_push_skipped", "timeout_skipped",
  "timeout_push_assignment_changed", "timeout_push_notification_changed",
  "timeout_push_responder_busy", "timeout_push_session_missing",
  "timeout_responder_pool_failed", "timeout_voip_push_failed",
  "timeout_voip_push_sent", "timeout_voip_push_skipped",
  "teacher_notification_cancel_failed", "teacher_notification_failed",
  "teacher_notification_validation_failed", "teacher_push_result_record_failed",
  "teacher_verification_status_ignored", "teacher_verification_user_missing",
  "translation_provider_failed", "tried_tutors_updated",
  "tutor_all_time_stats_failed", "tutor_approval_pending",
  "tutor_availability_checked", "tutor_balance_update_failed",
  "tutor_filtering_summary", "tutor_not_found",
  "tutor_notification_assignment_changed", "tutor_notification_created",
  "tutor_notification_failed", "tutor_notification_session_missing",
  "tutor_notification_skipped", "tutor_today_stats_failed",
  "tutor_transaction_write_failed", "tutors_sorted", "using_precreated_room",
  "verification_email_failed", "video_session_create_failed",
  "video_session_created", "video_session_start_requested",
  "send_event_chat_message_failed", "submit_review_failed",
  "voip_apns_push_failed", "voip_apns_push_sent", "voip_fcm_fallback",
  "voip_fcm_push_sent", "voip_fcm_push_started", "voip_fcm_token_missing",
  "voip_push_failed", "voip_push_prepare", "voip_push_recipient_not_found",
  "voip_push_send_started", "voip_push_sent", "voip_push_tokens_missing",
  "webhook_applied", "webhook_apply_failed", "webhook_auth_failed",
  "webhook_duplicate", "webhook_event", "webhook_event_ignored",
  "webhook_event_not_allowlisted", "webhook_lifecycle_malformed",
  "webhook_payload_malformed", "webhook_received", "webhook_secret_missing",
  "webhook_transfer_failed", "webhook_trial_malformed",
  "webhook_trial_ownership_mismatch", "webhook_user_not_found",
  "user_call_integrations_cleanup_completed",
]);

const SAFE_ERROR_CODES = new Set([
  "Error", "TypeError", "RangeError", "StateError",
  "unknown", "internal", "invalid-argument", "permission-denied",
  "unauthenticated", "not-found", "unavailable", "failed-precondition",
  "aborted", "cancelled", "deadline-exceeded", "resource-exhausted",
  "already-exists", "out-of-range", "unimplemented", "data-loss",
  "provider_unavailable", "delivery_failed", "gateway_timeout",
  "feedback_generation_failed", "ECONNRESET", "ETIMEDOUT", "EPIPE",
  "EAI_AGAIN", "ENETDOWN", "ENETUNREACH", "ENOTFOUND", "ECONNREFUSED",
  "UND_ERR_BODY_TIMEOUT", "UND_ERR_CONNECT_TIMEOUT",
  "UND_ERR_HEADERS_TIMEOUT", "UND_ERR_SOCKET",
]);

const SAFE_SOURCE_NAMES = new Set([
  "accept_call", "backend", "call_feedback", "call_lifecycle", "cancel_call",
  "cancel_event", "create_event", "edit_event", "get_event_chat_access_state",
  "get_event_history", "join_event", "leave_event", "request_withdrawal",
  "claim_registration_gift", "cleanup_expired_gifts",
  "cleanup_failed_daily_room_deletes", "cleanup_user_call_integrations",
  "cleanup_expired_sessions", "conversation_unlock_events",
  "create_payment_session", "create_video_session", "daily_room",
  "daily_room_cleanup", "daily_webhook", "decline_call",
  "email_verification", "end_session", "get_deepgram_token",
  "get_session_tokens", "grant_promo_entitlement", "mark_session_connected",
  "password_reset", "process_expired_notifications",
  "process_match_protocol_v2_state", "respond_to_match",
  "redeem_promo_code", "retry_pending_revenuecat_transfers",
  "revenue_cat_webhook", "start_search", "start_search_delivery",
  "start_search_matcher", "stop_search", "translate_term",
  "subscription_usage", "send_event_chat_message", "submit_review",
  "sync_event_public_projection", "teacher_verification_requests",
]);

const SAFE_HASH_FIELDS = Object.freeze({
  sessionHash: 64,
  userHash: 16,
  callerHash: 16,
  targetHash: 16,
  studentHash: 16,
  tutorHash: 16,
  requesterHash: 16,
  responderHash: 16,
  nextResponderHash: 16,
  notificationHash: 16,
  searchRequestHash: 16,
  pairAttemptHash: 16,
  requestHash: 16,
  transactionHash: 16,
  paymentHash: 16,
  eventHash: 16,
  appUserHash: 16,
  roomHash: 16,
  originalTransactionHash: 16,
});

const CORRELATION_FIELDS = Object.freeze({
  uid: "userHash",
  userId: "userHash",
  callerUid: "callerHash",
  targetUid: "targetHash",
  studentId: "studentHash",
  tutorId: "tutorHash",
  requesterId: "requesterHash",
  responderId: "responderHash",
  nextResponderId: "nextResponderHash",
  sessionId: "sessionHash",
  notificationId: "notificationHash",
  searchRequestId: "searchRequestHash",
  pairAttemptId: "pairAttemptHash",
  requestId: "requestHash",
  transactionId: "transactionHash",
  paymentId: "paymentHash",
  eventId: "eventHash",
  eventCursorId: "eventCursorHash",
  projectionCursorId: "projectionCursorHash",
  passId: "passHash",
  toUserId: "targetHash",
  appUserId: "appUserHash",
  roomName: "roomHash",
  directTutorId: "tutorHash",
  packageId: "packageHash",
  originalTransactionId: "originalTransactionHash",
});

// Metadata values are also code-owned. A character-pattern check is not
// sufficient because secrets and user identifiers are commonly token-shaped.
const SAFE_ENUM_FIELDS = Object.freeze({
  bodyType: new Set(["array", "null", "object", "string", "undefined"]),
  disposition: new Set(["fail", "retry"]),
  duration: new Set([
    "custom", "daily", "three_day", "weekly", "monthly", "two_month",
    "three_month", "six_month", "yearly", "lifetime",
  ]),
  environment: new Set(["PRODUCTION", "SANDBOX"]),
  finishReason: new Set([
    "STOP", "MAX_TOKENS", "SAFETY", "RECITATION", "OTHER", "UNKNOWN",
  ]),
  matchMode: new Set(["direct", "filtered"]),
  method: new Set(["DELETE", "GET", "PATCH", "POST", "PUT"]),
  platform: new Set([
    "android", "app_store", "ios", "play_store", "promotional", "stripe",
  ]),
  productId: new Set([
    "expatlio_1_Month", "expatlio_3_Month", "expatlio_trial_1_Month",
    "revenuecat_promotional",
  ]),
  provider: new Set(["google_cloud_translation_v3"]),
  result: new Set([
    "connected", "error", "handoff", "no_payout", "payout_eligible",
    "sent", "skipped", "terminal",
  ]),
  role: new Set(["admin", "learner", "native_speaker", "student", "tutor"]),
  requesterRole: new Set(["native_speaker", "student", "tutor"]),
  scenario: new Set(["student_native", "student_teacher"]),
  status: new Set([
    "active", "already_marked", "calling", "cancelled", "completed",
    "connected", "connecting", "daily_presence_not_verified", "declined",
    "ended", "expired", "failed", "failed_terminal", "granted", "ignored",
    "ignored_expired_end", "insufficient_text", "marked",
    "no_tutors_available", "ok", "pending", "pending_confirmation",
    "processing", "queued", "ready", "retry", "searching", "sent",
    "signal_recorded",
  ]),
  statusAfter: new Set([
    "active", "cancelled", "connected", "connecting", "ended", "expired",
    "pending_confirmation", "searching",
  ]),
  statusBefore: new Set([
    "active", "cancelled", "connected", "connecting", "ended", "expired",
    "pending_confirmation", "searching",
  ]),
  type: new Set([
    "BILLING_ISSUE", "CANCELLATION", "EXPIRATION", "INITIAL_PURCHASE",
    "NON_RENEWING_PURCHASE", "PRODUCT_CHANGE", "REFUND_REVERSED", "RENEWAL",
    "SUBSCRIPTION_EXTENDED", "SUBSCRIPTION_PAUSED", "TEST", "TRANSFER",
    "UNCANCELLATION", "earning", "incoming_call", "promotional_grant",
    "purchase", "subscription_cancellation", "subscription_expiration",
    "subscription_purchase", "subscription_renewal",
  ]),
});

const SAFE_LANGUAGE_CODES = new Set(["en", "ru"]);

const SAFE_REASON_CODES = new Set([
  "accepted_participants_incomplete",
  "accept_lock_active", "active_search_responder", "apns_failed_no_fcm",
  "assignment_changed_after_transaction", "available_after_in_future",
  "blocked_by_student", "blocked_by_tutor", "callkit_surface_not_active",
  "callkit_timeout", "country_mismatch", "direct_call_declined",
  "daily_connected_marked", "daily_signal_recorded",
  "daily_signal_recorded_after_join_deadline",
  "daily_signal_recorded_presence_required", "direct_call_timeout", "expired",
  "language_mismatch", "malformed_event", "missing_app_user_id",
  "missing_event_timestamp", "missing_expiration_timestamp",
  "missing_period_type", "missing_product_id", "missing_purchase_timestamp",
  "missing_revenuecat_app_allowlist", "missing_transfer_identity",
  "level_mismatch", "lifecycle_escalation_pending", "match_timeout",
  "missing_call_token", "missing_country", "missing_current_responder",
  "missing_level", "missing_session_id", "missing_student_search_request_id",
  "no_assigned_tutor", "no_available_tutors", "no_callable_candidates",
  "no_fcm_token", "no_push_tokens", "notification_changed_after_assignment",
  "notification_not_found", "pair_lock_failed", "protocol_v2_attempt_stale",
  "push_send_failed", "request_id_required", "same_day_repeat",
  "room_mismatch", "self_excluded", "session_missing",
  "session_missing_after_assignment", "session_not_found",
  "session_not_joinable", "not_session_participant",
  "student_native_disabled", "student_not_in_active_queue_for_language",
  "tutor_not_found", "unapproved_teacher", "unavailable_or_in_call",
  "unexpected_entitlement", "unexpected_new_product", "unexpected_product",
  "unexpected_revenuecat_app", "unknown", "unsupported_event_type",
  "unsupported_role", "user_ended",
]);

const SAFE_COUNT_KEYS = new Set([
  "active", "attempted", "availableAfterInFuture", "backgroundExpiredCleaned",
  "backgroundExpiredFound", "blockedByStudent", "blockedByTutor", "cancelled",
  "cancellationIntentsDeleted", "cleaned", "countryMismatch", "deleted",
  "deletedDocuments", "expired",
  "expiredCancellationIntentsFound", "expiredCleaned", "expiredFound", "found",
  "failed", "languageMismatch", "levelMismatch", "missingCallToken", "missingCountry",
  "minutesGifted", "missingLevel", "quarantined", "resolved",
  "sameDayRepeat", "scanned",
  "selfExcluded", "skipped", "staleCleaned",
  "staleFallbackCleaned", "staleFallbackFound", "staleFound", "total",
  "unapprovedTeacher", "unavailableOrInCall", "unsupportedRole", "updated",
]);

const SAFE_NUMBER_FIELDS = new Set([
  "attemptCount",
  "canceledCount",
  "customDays",
  "durationSeconds",
  "dayDurationSeconds",
  "excludedCount",
  "providerAttempt",
  "providerStatus",
  "removedOrphans",
  "repaired",
  "responseCharacterCount",
  "statusCode",
  "totalTutorsQueried",
  "totalCandidatesChecked",
  "matchedTutors",
  "limitSeconds",
  "count",
  "ttlSeconds",
  "weekDurationSeconds",
]);

const SAFE_BOOLEAN_FIELDS = new Set([
  "duplicate",
  "hasAuth",
  "hasEvent",
  "hasRoomUrl",
  "hasToken",
  "isAvailable",
  "pending",
  "connectedMarked",
  "eventPassComplete",
  "projectionPassComplete",
  "sameDayRepeatPrevention",
  "stateCommitted",
  "updated",
]);

function normalizeEventName(value) {
  if (typeof value !== "string") {
    return "unknown";
  }
  const eventName = value.trim();
  return SAFE_EVENT_NAMES.has(eventName) ? eventName : "unknown";
}

function normalizeSourceName(value) {
  const source = typeof value === "string" ? value.trim() : "";
  return SAFE_SOURCE_NAMES.has(source) ? source : "";
}

function normalizeLanguageCode(value) {
  const language = typeof value === "string" ? value.trim().toLowerCase() : "";
  return SAFE_LANGUAGE_CODES.has(language) ? language : "";
}

function normalizeReasonCode(value) {
  const reason = typeof value === "string" ? value.trim() : "";
  if (SAFE_REASON_CODES.has(reason)) return reason;
  if (reason.startsWith("current_responder_changed_")) {
    return "current_responder_changed";
  }
  if (reason.startsWith("notification_status_")) {
    return "notification_status_changed";
  }
  if (reason.startsWith("status_")) return "session_status_changed";
  if (reason.startsWith("tutor_already_assigned_")) {
    return "tutor_already_assigned";
  }
  return "unknown";
}

function normalizeErrorCode(value) {
  const code = typeof value === "string" ? value.trim() : "";
  if (SAFE_ERROR_CODES.has(code)) return code;
  if (/^http_[1-5][0-9]{2}$/u.test(code)) return code;
  if (/^(auth|messaging|functions)\//u.test(code)) {
    return `${code.split("/", 1)[0]}_error`;
  }
  return "unknown";
}

function normalizeErrorType(value) {
  const type = typeof value === "string" ? value.trim() : "";
  return ["Error", "TypeError", "RangeError", "StateError"].includes(type) ?
    type : "Error";
}

function correlationHash(value, {canonicalSession = false} = {}) {
  const normalized = typeof value === "string" ? value.trim() : "";
  if (!normalized) {
    return "";
  }
  if (canonicalSession) {
    return crypto.createHash("sha256").update(normalized).digest("hex");
  }
  return crypto
    .createHash("sha256")
    .update(`${CORRELATION_PREFIX}${normalized}`)
    .digest("hex")
    .slice(0, 16);
}

function safeErrorCode(error, fallback = "unknown") {
  let candidates;
  try {
    candidates = [
      error?.code,
      error?.name,
      error?.response?.data?.errorCode,
      error?.response?.data?.err_code,
    ];
  } catch (_) {
    return normalizeErrorCode(String(fallback || ""));
  }
  for (const candidate of candidates) {
    const normalized = normalizeErrorCode(String(candidate || ""));
    if (normalized !== "unknown") {
      return normalized;
    }
  }
  return normalizeErrorCode(String(fallback || ""));
}

function sanitizeCounts(counts) {
  if (!counts || typeof counts !== "object" || Array.isArray(counts)) {
    return null;
  }
  const result = {};
  for (const [key, value] of Object.entries(counts)) {
    const numericValue = Number(value);
    if (SAFE_COUNT_KEYS.has(key) && Number.isFinite(numericValue)) {
      result[key] = numericValue;
    }
  }
  return Object.keys(result).length > 0 ? result : null;
}

function buildSafeLogPayloadUnsafe(input = {}) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    return {};
  }

  const result = {};
  for (const [field, value] of Object.entries(input)) {
    const hashLength = SAFE_HASH_FIELDS[field];
    if (hashLength) {
      const hash = typeof value === "string" ? value.trim().toLowerCase() : "";
      if (new RegExp(`^[a-f0-9]{${hashLength}}$`, "u").test(hash)) {
        result[field] = hash;
      }
      continue;
    }
    const hashField = CORRELATION_FIELDS[field];
    if (hashField) {
      const hash = correlationHash(value, {canonicalSession: field === "sessionId"});
      if (hash) result[hashField] = hash;
      continue;
    }
    if (field === "event" || field === "operation") {
      result[field] = normalizeEventName(value);
      continue;
    }
    if (field === "source") {
      const source = normalizeSourceName(value);
      if (source) result.source = source;
      continue;
    }
    if (field === "errorCode" || field === "providerCode" || field === "code") {
      const errorCode = normalizeErrorCode(String(value || ""));
      if (errorCode !== "unknown" || value) result[field] = errorCode;
      continue;
    }
    if (field === "errorType") {
      result.errorType = normalizeErrorType(value);
      continue;
    }
    if (field === "reason" || field === "reasonCode" || field === "skipReason") {
      result[field] = normalizeReasonCode(value);
      continue;
    }
    if (["language", "normalizedLanguage", "requestedLanguage"].includes(field)) {
      const language = normalizeLanguageCode(value);
      if (language) result[field] = language;
      continue;
    }
    if (field === "duration" && typeof value === "number") {
      if (Number.isFinite(value)) result.duration = value;
      continue;
    }
    const allowedValues = SAFE_ENUM_FIELDS[field];
    if (allowedValues) {
      const token = typeof value === "string" ? value.trim() : "";
      if (allowedValues.has(token)) result[field] = token;
      continue;
    }
    if (SAFE_NUMBER_FIELDS.has(field)) {
      const numberValue = Number(value);
      if (Number.isFinite(numberValue)) result[field] = numberValue;
      continue;
    }
    if (SAFE_BOOLEAN_FIELDS.has(field) && typeof value === "boolean") {
      result[field] = value;
      continue;
    }
    if (field === "counts") {
      const counts = sanitizeCounts(value);
      if (counts) result.counts = counts;
    }
  }
  return result;
}

function buildSafeLogPayload(input = {}) {
  try {
    return buildSafeLogPayloadUnsafe(input);
  } catch (_) {
    return {};
  }
}

function mergeSafeArguments(args) {
  const fields = {};
  for (const argument of args) {
    try {
      if (argument instanceof Error) {
        fields.errorType = normalizeErrorType(argument.name);
        fields.errorCode = safeErrorCode(argument);
      } else if (
        argument &&
        typeof argument === "object" &&
        !Array.isArray(argument)
      ) {
        Object.assign(fields, buildSafeLogPayload(argument));
        if (argument.error instanceof Error || argument.err instanceof Error) {
          const error = argument.error || argument.err;
          fields.errorType = normalizeErrorType(error.name);
          fields.errorCode = safeErrorCode(error);
        }
      }
    } catch (_) {
      // Malformed diagnostics must not affect the application path.
    }
  }
  return fields;
}

function createSafeConsole({source, logger = functionsLogger} = {}) {
  const safeSource = normalizeSourceName(source) || "backend";

  function write(level, args) {
    const [message, ...details] = args;
    let safeDetails = {};
    try {
      safeDetails = mergeSafeArguments(details);
    } catch (_) {
      // Preserve a minimal envelope even for hostile diagnostic objects.
    }
    const payload = {
      ...safeDetails,
      source: safeSource,
      event: normalizeEventName(message),
    };
    const method = level === "error" ? "error" :
      level === "warn" ? "warn" : "log";
    let sink;
    try {
      sink = typeof logger?.[method] === "function" ?
        logger[method].bind(logger) :
        typeof logger?.log === "function" ? logger.log.bind(logger) : null;
    } catch (_) {
      return payload;
    }
    if (sink) {
      try {
        sink(SAFE_EVENT_NAME, payload);
      } catch (_) {
        // Logging must never replace the application error path.
      }
    }
    return payload;
  }

  return Object.freeze({
    log: (...args) => write("info", args),
    info: (...args) => write("info", args),
    warn: (...args) => write("warn", args),
    error: (...args) => write("error", args),
  });
}

module.exports = {
  SAFE_EVENT_NAME,
  buildSafeLogPayload,
  correlationHash,
  createSafeConsole,
  normalizeEventName,
  normalizeErrorCode,
  safeErrorCode,
  sanitizeCounts,
};
