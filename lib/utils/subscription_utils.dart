// Subscription helpers — pure functions used by widgets and services
// for client-side gating, formatting, and state derivation.
//
// Server-side mirror: firebase/custom_cloud_functions/subscription_usage_shared.js
// has an equivalent `hasActiveSubscription` for Cloud Functions. Keep
// semantics aligned across the two.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '/backend/schema/users_record.dart';
import '/backend/schema/structs/gift_minutes_struct.dart';
import '/backend/schema/structs/subscription_struct.dart';

/// True if [user] has a subscription whose `expiresAt` is in the future.
/// Trial subscriptions (productId == "trial") count as active.
/// Pass [now] in tests to bypass the system clock; defaults to `DateTime.now()`.
bool hasActiveSubscription(UsersRecord? user, {DateTime? now}) {
  final subscription = user?.subscription;
  return _isActive(subscription, now: now);
}

/// True if [subscription] (a struct read directly, not via UsersRecord)
/// is currently active. Convenience for screens that hold a SubscriptionStruct
/// instance.
bool isSubscriptionActive(SubscriptionStruct? subscription, {DateTime? now}) =>
    _isActive(subscription, now: now);

bool _isActive(SubscriptionStruct? subscription, {DateTime? now}) {
  final expiresAt = subscription?.expiresAt;
  if (expiresAt == null) return false;
  final reference = now ?? DateTime.now();
  return expiresAt.isAfter(reference);
}

/// Whole days remaining until the subscription expires. Returns 0 when
/// expired or absent. Useful for "Expires in N days" copy.
int daysUntilExpiry(UsersRecord? user, {DateTime? now}) {
  final expiresAt = user?.subscription?.expiresAt;
  if (expiresAt == null) return 0;
  final reference = now ?? DateTime.now();
  final diff = expiresAt.difference(reference);
  if (diff.isNegative) return 0;
  // Round up so "12h left" shows as "1 day" not "0 days".
  return diff.inHours <= 0 ? 0 : ((diff.inHours + 23) ~/ 24);
}

/// True if the subscription expires within [threshold] (default: 3 days).
bool isSubscriptionExpiringSoon(
  UsersRecord? user, {
  Duration threshold = const Duration(days: 3),
  DateTime? now,
}) {
  if (!hasActiveSubscription(user, now: now)) return false;
  final expiresAt = user!.subscription!.expiresAt!;
  final reference = now ?? DateTime.now();
  return expiresAt.difference(reference) <= threshold;
}

/// True if this is a free trial subscription (Apple/Google intro offer or
/// app-level fallback). Both surface `periodType: "TRIAL"` from RC, and
/// the Firestore-fallback trial uses `productId == "trial"`.
bool isTrialSubscription(UsersRecord? user) {
  final subscription = user?.subscription;
  if (subscription == null) return false;
  return subscription.productId == 'trial' ||
      subscription.periodType.toUpperCase() == 'TRIAL';
}

/// Format an expiry date as `DD.MM.YYYY` for display copy
/// (e.g. "Подписка активна до 14.08.2026"). Locale-agnostic — uses ISO
/// digit order with dots as the project's Russian UI expects.
String formatExpiryDate(DateTime? expiresAt) {
  if (expiresAt == null) return '';
  final d = expiresAt.day.toString().padLeft(2, '0');
  final m = expiresAt.month.toString().padLeft(2, '0');
  final y = expiresAt.year.toString();
  return '$d.$m.$y';
}

/// Convenience: read the expiry timestamp directly from a UsersRecord
/// (or null if no subscription). Useful for stream-based UI that wants
/// the raw value for formatting.
DateTime? subscriptionExpiresAt(UsersRecord? user) =>
    user?.subscription?.expiresAt;

/// Convenience: read willRenew, defaulting to false when no subscription.
bool subscriptionWillRenew(UsersRecord? user) =>
    user?.subscription?.willRenew ?? false;

/// Live stream of [hasActiveSubscription] for the currently authenticated
/// user, derived from a UsersRecord stream. Callers can listen and rebuild
/// gated UI without recomputing the check inline.
Stream<bool> hasActiveSubscriptionStream(
  Stream<UsersRecord> userStream,
) =>
    userStream.map((user) => hasActiveSubscription(user));

/// Convenience builder for reading the current user document by reference.
/// Returns a stream that emits `false` until the doc exists. Useful when
/// the caller has a DocumentReference but not a record stream.
Stream<bool> hasActiveSubscriptionByRef(DocumentReference userRef) =>
    UsersRecord.getDocument(userRef).map(hasActiveSubscription);

// ─── Gift minutes ───────────────────────────────────────────────────────
// Mirror of firebase/custom_cloud_functions/gift_minutes_shared.js. Used
// by the dashboard / no_balance widget to display the remaining trial /
// promo bucket alongside the subscription state.

/// True if [user] has gift minutes left and they haven't expired.
bool hasUsableGiftMinutes(UsersRecord? user, {DateTime? now}) =>
    isGiftMinutesActive(user?.giftMinutes, now: now);

/// Struct-level variant. Tests target this version to avoid mocking
/// UsersRecord.
bool isGiftMinutesActive(GiftMinutesStruct? gift, {DateTime? now}) {
  if (gift == null) return false;
  if (gift.minutes <= 0) return false;
  final expiresAt = gift.expiresAt;
  if (expiresAt == null) return false;
  final reference = now ?? DateTime.now();
  return expiresAt.isAfter(reference);
}

/// Convenience: pull the remaining gift minutes, treating expired
/// or absent buckets as zero.
double remainingGiftMinutes(UsersRecord? user, {DateTime? now}) {
  if (!hasUsableGiftMinutes(user, now: now)) return 0;
  return user!.giftMinutes!.minutes;
}

/// When the gift bucket expires (null when no active bucket).
DateTime? giftMinutesExpiresAt(UsersRecord? user, {DateTime? now}) {
  if (!hasUsableGiftMinutes(user, now: now)) return null;
  return user!.giftMinutes!.expiresAt;
}

/// True if the user can start a call right now — i.e. has either an
/// active subscription or unexpired gift minutes. The single source of
/// truth for client-side gating; server enforces the same predicate
/// in create_video_session.js.
bool canStartCall(UsersRecord? user, {DateTime? now}) =>
    hasActiveSubscription(user, now: now) ||
    hasUsableGiftMinutes(user, now: now);

/// Format a remaining-minutes count for UI. Drops trailing zeros so
/// "10.0" → "10" but "7.5" stays "7.5".
String formatGiftMinutes(double minutes) {
  if (minutes <= 0) return '0';
  if (minutes == minutes.roundToDouble()) {
    return minutes.toStringAsFixed(0);
  }
  return minutes.toStringAsFixed(1);
}

@visibleForTesting
int calendarDayDifference(DateTime from, DateTime to) {
  final fromDay = DateTime.utc(from.year, from.month, from.day);
  final toDay = DateTime.utc(to.year, to.month, to.day);
  return toDay.difference(fromDay).inDays;
}

/// Short localized relative time-of-day.
/// Useful for the gift-expiry badge on the dashboard.
String formatGiftExpiry(
  DateTime? expiresAt, {
  DateTime? now,
  String languageCode = 'ru',
}) {
  if (expiresAt == null) return '';
  final reference = (now ?? DateTime.now()).toLocal();
  final local = expiresAt.toLocal();
  final dayDiff = calendarDayDifference(reference, local);
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  final isEnglish = languageCode.trim().toLowerCase().startsWith('en');
  final at = isEnglish ? 'at' : 'в';
  if (dayDiff == 0) return '${isEnglish ? 'today' : 'сегодня'} $at $h:$m';
  if (dayDiff == 1) return '${isEnglish ? 'tomorrow' : 'завтра'} $at $h:$m';
  final d = local.day.toString().padLeft(2, '0');
  final mo = local.month.toString().padLeft(2, '0');
  return '$d.$mo $at $h:$m';
}

/// Read-only snapshot of the gift bucket (or null if absent / expired).
/// Use this when a widget needs both the minutes and the expiry together.
GiftMinutesStruct? activeGiftMinutes(UsersRecord? user, {DateTime? now}) {
  return hasUsableGiftMinutes(user, now: now) ? user!.giftMinutes : null;
}
