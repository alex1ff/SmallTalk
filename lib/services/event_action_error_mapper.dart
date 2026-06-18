import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '/flutter_flow/internationalization.dart';

enum EventActionFailureKind {
  authRequired,
  validation,
  dailyLimitReached,
  createRequestConflict,
  eventNotFound,
  permissionDenied,
  notOrganizer,
  eventNotEditable,
  eventNotCancelable,
  eventNotJoinable,
  eventNotLeaveable,
  eventFull,
  alreadyJoined,
  organizerCannotLeave,
  notActiveParticipant,
  profileRequired,
  capacityBelowParticipants,
  chatUnavailable,
  staleEventState,
  unavailable,
  unknown,
}

class EventActionFailure {
  const EventActionFailure({
    required this.kind,
    this.firebaseCode,
    this.domainCode,
    this.reason,
    this.dailyLimit,
    this.retryable = false,
  });

  final EventActionFailureKind kind;
  final String? firebaseCode;
  final String? domainCode;
  final String? reason;
  final EventDailyLimitContext? dailyLimit;
  final bool retryable;
}

class EventDailyLimitContext {
  const EventDailyLimitContext({
    required this.resetAtUtc,
    required this.dayKeyUtc,
    required this.count,
    required this.limit,
  });

  final DateTime? resetAtUtc;
  final String? dayKeyUtc;
  final int? count;
  final int? limit;
}

EventActionFailure mapEventActionFailure(Object error) {
  if (error is FirebaseFunctionsException) {
    final details = _detailsMap(error.details);
    final domainCode = _stringValue(details['domainCode']);
    final reason = _stringValue(details['reason']);
    final failure = _failureFromDomainCode(
      domainCode: domainCode,
      reason: reason,
      firebaseCode: error.code,
      details: details,
    );
    if (failure != null) {
      return failure;
    }
    return _failureFromFirebaseCode(
      firebaseCode: error.code,
      domainCode: domainCode,
      reason: reason,
    );
  }

  if (error is FirebaseException) {
    return _failureFromFirebaseCode(
      firebaseCode: error.code,
      domainCode: null,
      reason: null,
    );
  }

  return _unknownFailure();
}

String eventActionFailureMessage(BuildContext context, Object error) =>
    eventActionFailureMessageForLocalizations(
      FFLocalizations.of(context),
      mapEventActionFailure(error),
    );

String eventActionFailureMessageForLocalizations(
  FFLocalizations localizations,
  EventActionFailure failure,
) {
  switch (failure.kind) {
    case EventActionFailureKind.authRequired:
      return localizations.getVariableText(
        ruText: 'Войдите в аккаунт, чтобы продолжить.',
        enText: 'Sign in to continue.',
      );
    case EventActionFailureKind.validation:
      return localizations.getVariableText(
        ruText: 'Проверьте данные события и попробуйте снова.',
        enText: 'Check the event details and try again.',
      );
    case EventActionFailureKind.dailyLimitReached:
      return localizations.getVariableText(
        ruText: 'Сегодня можно создать не больше 5 событий. Попробуйте завтра.',
        enText: 'You can create up to 5 events per day. Try again tomorrow.',
      );
    case EventActionFailureKind.createRequestConflict:
      return localizations.getVariableText(
        ruText:
            'Не удалось создать событие из-за повторной отправки формы. Обновите экран и попробуйте снова.',
        enText:
            'We could not create the event because the form was submitted again. Refresh and try again.',
      );
    case EventActionFailureKind.eventNotFound:
      return localizations.getVariableText(
        ruText: 'Событие не найдено или уже недоступно.',
        enText: 'The event was not found or is no longer available.',
      );
    case EventActionFailureKind.permissionDenied:
      return localizations.getVariableText(
        ruText: 'Недостаточно прав для этого действия.',
        enText: 'You do not have permission to do this.',
      );
    case EventActionFailureKind.notOrganizer:
      return localizations.getVariableText(
        ruText: 'Это действие доступно только организатору события.',
        enText: 'Only the event organizer can do this.',
      );
    case EventActionFailureKind.eventNotEditable:
      if (failure.reason == 'past_event') {
        return localizations.getVariableText(
          ruText: 'Событие уже началось, редактировать его нельзя.',
          enText: 'This event has already started and cannot be edited.',
        );
      }
      return localizations.getVariableText(
        ruText: 'Событие больше нельзя редактировать.',
        enText: 'This event can no longer be edited.',
      );
    case EventActionFailureKind.eventNotCancelable:
      return localizations.getVariableText(
        ruText: 'Событие больше нельзя отменить.',
        enText: 'This event can no longer be canceled.',
      );
    case EventActionFailureKind.eventNotJoinable:
      if (failure.reason == 'past_event') {
        return localizations.getVariableText(
          ruText: 'Событие уже началось, присоединиться нельзя.',
          enText: 'This event has already started, so you cannot join it.',
        );
      }
      return localizations.getVariableText(
        ruText: 'К этому событию больше нельзя присоединиться.',
        enText: 'You can no longer join this event.',
      );
    case EventActionFailureKind.eventNotLeaveable:
      if (failure.reason == 'event_started') {
        return localizations.getVariableText(
          ruText: 'Событие уже началось, выйти из него нельзя.',
          enText: 'This event has already started, so you cannot leave it.',
        );
      }
      return localizations.getVariableText(
        ruText: 'Из этого события больше нельзя выйти.',
        enText: 'You can no longer leave this event.',
      );
    case EventActionFailureKind.eventFull:
      return localizations.getVariableText(
        ruText: 'В этом событии уже нет свободных мест.',
        enText: 'There are no free spots left in this event.',
      );
    case EventActionFailureKind.alreadyJoined:
      return localizations.getVariableText(
        ruText: 'Вы уже присоединились к этому событию.',
        enText: 'You have already joined this event.',
      );
    case EventActionFailureKind.organizerCannotLeave:
      return localizations.getVariableText(
        ruText: 'Организатор не может выйти из своего события.',
        enText: 'The organizer cannot leave their own event.',
      );
    case EventActionFailureKind.notActiveParticipant:
      return localizations.getVariableText(
        ruText: 'Это действие доступно только участникам события.',
        enText: 'Only event participants can do this.',
      );
    case EventActionFailureKind.profileRequired:
      return localizations.getVariableText(
        ruText: 'Заполните имя и фото профиля, чтобы продолжить с событиями.',
        enText: 'Add your profile name and photo to continue with events.',
      );
    case EventActionFailureKind.capacityBelowParticipants:
      return localizations.getVariableText(
        ruText: 'Лимит мест не может быть меньше текущего числа участников.',
        enText:
            'The capacity cannot be lower than the current number of participants.',
      );
    case EventActionFailureKind.chatUnavailable:
      return localizations.getVariableText(
        ruText: 'Чат события сейчас недоступен. Попробуйте позже.',
        enText: 'The event chat is unavailable right now. Try again later.',
      );
    case EventActionFailureKind.staleEventState:
      return localizations.getVariableText(
        ruText: 'Данные события изменились. Обновите экран и попробуйте снова.',
        enText: 'The event data has changed. Refresh the screen and try again.',
      );
    case EventActionFailureKind.unavailable:
      return localizations.getVariableText(
        ruText: 'Проверьте подключение и попробуйте снова.',
        enText: 'Check your connection and try again.',
      );
    case EventActionFailureKind.unknown:
      return localizations.getVariableText(
        ruText: 'Не удалось выполнить действие. Попробуйте снова.',
        enText: 'Could not complete the action. Please try again.',
      );
  }
}

EventActionFailure? _failureFromDomainCode({
  required String? domainCode,
  required String? reason,
  required String firebaseCode,
  required Map<String, dynamic> details,
}) {
  switch (domainCode) {
    case 'auth_required':
      return _failure(
        kind: EventActionFailureKind.authRequired,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'invalid_create_request':
    case 'invalid_edit_request':
    case 'invalid_cancel_request':
    case 'invalid_join_request':
    case 'invalid_leave_request':
    case 'invalid_event_chat_message_request':
    case 'invalid_city_catalog':
      return _failure(
        kind: EventActionFailureKind.validation,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'daily_limit_reached':
      return _failure(
        kind: EventActionFailureKind.dailyLimitReached,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
        dailyLimit: _dailyLimitContext(details),
      );
    case 'create_request_conflict':
      return _failure(
        kind: EventActionFailureKind.createRequestConflict,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'event_not_found':
      return _failure(
        kind: EventActionFailureKind.eventNotFound,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'not_event_organizer':
      return _failure(
        kind: EventActionFailureKind.notOrganizer,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'event_not_editable':
      return _failure(
        kind: EventActionFailureKind.eventNotEditable,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'event_not_cancelable':
      return _failure(
        kind: EventActionFailureKind.eventNotCancelable,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'event_not_joinable':
      return _failure(
        kind: EventActionFailureKind.eventNotJoinable,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'event_not_leaveable':
      return _failure(
        kind: EventActionFailureKind.eventNotLeaveable,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'event_full':
      return _failure(
        kind: EventActionFailureKind.eventFull,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'already_joined':
      return _failure(
        kind: EventActionFailureKind.alreadyJoined,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'organizer_cannot_leave':
      return _failure(
        kind: EventActionFailureKind.organizerCannotLeave,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'not_active_participant':
      return _failure(
        kind: EventActionFailureKind.notActiveParticipant,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'organizer_profile_required':
    case 'participant_profile_required':
    case 'sender_profile_required':
    case 'sender_profile_invalid':
      return _failure(
        kind: EventActionFailureKind.profileRequired,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'capacity_below_participants_count':
      return _failure(
        kind: EventActionFailureKind.capacityBelowParticipants,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'event_chat_metadata_invalid':
    case 'event_chat_writes_blocked':
      return _failure(
        kind: EventActionFailureKind.chatUnavailable,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'create_request_marker_inconsistent':
    case 'create_request_marker_missing':
    case 'event_creation_counter_inconsistent':
    case 'event_cancellation_inconsistent':
    case 'event_participant_state_inconsistent':
    case 'participant_membership_inconsistent':
      return _failure(
        kind: EventActionFailureKind.staleEventState,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
  }

  return null;
}

EventActionFailure _failureFromFirebaseCode({
  required String firebaseCode,
  required String? domainCode,
  required String? reason,
}) {
  switch (firebaseCode) {
    case 'unauthenticated':
      return _failure(
        kind: EventActionFailureKind.authRequired,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'invalid-argument':
      return _failure(
        kind: EventActionFailureKind.validation,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'not-found':
      return _failure(
        kind: EventActionFailureKind.eventNotFound,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'permission-denied':
      return _failure(
        kind: EventActionFailureKind.permissionDenied,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
    case 'unavailable':
    case 'deadline-exceeded':
      return _failure(
        kind: EventActionFailureKind.unavailable,
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
        retryable: true,
      );
    default:
      return _unknownFailure(
        firebaseCode: firebaseCode,
        domainCode: domainCode,
        reason: reason,
      );
  }
}

EventActionFailure _failure({
  required EventActionFailureKind kind,
  required String? firebaseCode,
  required String? domainCode,
  required String? reason,
  EventDailyLimitContext? dailyLimit,
  bool retryable = false,
}) =>
    EventActionFailure(
      kind: kind,
      firebaseCode: firebaseCode,
      domainCode: domainCode,
      reason: reason,
      dailyLimit: dailyLimit,
      retryable: retryable,
    );

EventActionFailure _unknownFailure({
  String? firebaseCode,
  String? domainCode,
  String? reason,
}) =>
    _failure(
      kind: EventActionFailureKind.unknown,
      firebaseCode: firebaseCode,
      domainCode: domainCode,
      reason: reason,
    );

Map<String, dynamic> _detailsMap(Object? details) {
  if (details is! Map) {
    return const <String, dynamic>{};
  }
  return details.map(
    (key, value) => MapEntry(key.toString(), value),
  );
}

String? _stringValue(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

EventDailyLimitContext _dailyLimitContext(Map<String, dynamic> details) =>
    EventDailyLimitContext(
      resetAtUtc: _dateTimeValue(details['resetAtUtc']),
      dayKeyUtc: _stringValue(details['dayKeyUtc']),
      count: _intValue(details['count']),
      limit: _intValue(details['limit']),
    );

DateTime? _dateTimeValue(Object? value) {
  final stringValue = _stringValue(value);
  if (stringValue == null) {
    return null;
  }
  final parsed = DateTime.tryParse(stringValue);
  if (parsed == null) {
    return null;
  }
  return parsed.toUtc();
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  return null;
}
