import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/services/event_action_error_mapper.dart';

void main() {
  group('mapEventActionFailure', () {
    test('maps every backend event domainCode to a stable failure kind', () {
      const expectedKinds = <String, EventActionFailureKind>{
        'auth_required': EventActionFailureKind.authRequired,
        'invalid_create_request': EventActionFailureKind.validation,
        'invalid_edit_request': EventActionFailureKind.validation,
        'invalid_cancel_request': EventActionFailureKind.validation,
        'invalid_join_request': EventActionFailureKind.validation,
        'invalid_leave_request': EventActionFailureKind.validation,
        'invalid_event_chat_message_request': EventActionFailureKind.validation,
        'invalid_report_event_request': EventActionFailureKind.validation,
        'invalid_report_event_chat_message_request':
            EventActionFailureKind.validation,
        'invalid_city_catalog': EventActionFailureKind.validation,
        'daily_limit_reached': EventActionFailureKind.dailyLimitReached,
        'create_request_conflict': EventActionFailureKind.createRequestConflict,
        'event_not_found': EventActionFailureKind.eventNotFound,
        'not_event_organizer': EventActionFailureKind.notOrganizer,
        'event_not_editable': EventActionFailureKind.eventNotEditable,
        'event_not_cancelable': EventActionFailureKind.eventNotCancelable,
        'event_not_joinable': EventActionFailureKind.eventNotJoinable,
        'event_not_leaveable': EventActionFailureKind.eventNotLeaveable,
        'event_full': EventActionFailureKind.eventFull,
        'already_joined': EventActionFailureKind.alreadyJoined,
        'organizer_cannot_leave': EventActionFailureKind.organizerCannotLeave,
        'not_active_participant': EventActionFailureKind.notActiveParticipant,
        'event_report_self': EventActionFailureKind.eventReportSelf,
        'event_not_reportable': EventActionFailureKind.eventNotReportable,
        'event_chat_message_not_found':
            EventActionFailureKind.chatMessageNotFound,
        'event_chat_message_report_self':
            EventActionFailureKind.chatMessageReportSelf,
        'event_chat_message_not_reportable':
            EventActionFailureKind.chatMessageNotReportable,
        'organizer_profile_required': EventActionFailureKind.profileRequired,
        'participant_profile_required': EventActionFailureKind.profileRequired,
        'sender_profile_required': EventActionFailureKind.profileRequired,
        'sender_profile_invalid': EventActionFailureKind.profileRequired,
        'capacity_below_participants_count':
            EventActionFailureKind.capacityBelowParticipants,
        'event_chat_metadata_invalid': EventActionFailureKind.chatUnavailable,
        'event_chat_access_denied': EventActionFailureKind.chatUnavailable,
        'event_chat_writes_blocked': EventActionFailureKind.chatUnavailable,
        'event_chat_message_invalid': EventActionFailureKind.chatUnavailable,
        'create_request_marker_inconsistent':
            EventActionFailureKind.staleEventState,
        'create_request_marker_missing': EventActionFailureKind.staleEventState,
        'event_creation_counter_inconsistent':
            EventActionFailureKind.staleEventState,
        'event_cancellation_inconsistent':
            EventActionFailureKind.staleEventState,
        'event_participant_state_inconsistent':
            EventActionFailureKind.staleEventState,
        'event_report_state_inconsistent':
            EventActionFailureKind.staleEventState,
        'participant_membership_inconsistent':
            EventActionFailureKind.staleEventState,
      };

      for (final entry in expectedKinds.entries) {
        final failure = mapEventActionFailure(_domainError(entry.key));

        expect(
          failure.kind,
          entry.value,
          reason: 'Unexpected kind for ${entry.key}',
        );
        expect(failure.domainCode, entry.key);
      }
    });

    test('maps daily limit without exposing server text', () {
      final failure = mapEventActionFailure(
        _TestFirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'Raw backend message',
          details: <String, dynamic>{
            'domainCode': 'daily_limit_reached',
            'limit': 5,
            'count': 5,
            'dayKeyUtc': '2026-06-14',
            'resetAtUtc': '2026-06-15T00:00:00.000Z',
          },
        ),
      );

      expect(failure.kind, EventActionFailureKind.dailyLimitReached);
      expect(failure.firebaseCode, 'resource-exhausted');
      expect(failure.domainCode, 'daily_limit_reached');
      expect(failure.retryable, isFalse);
      expect(failure.dailyLimit?.limit, 5);
      expect(failure.dailyLimit?.count, 5);
      expect(failure.dailyLimit?.dayKeyUtc, '2026-06-14');
      expect(
        failure.dailyLimit?.resetAtUtc,
        DateTime.parse('2026-06-15T00:00:00.000Z'),
      );
    });

    test('ignores malformed daily limit support context safely', () {
      final failure = mapEventActionFailure(
        _TestFirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'Raw backend message',
          details: <String, dynamic>{
            'domainCode': 'daily_limit_reached',
            'limit': '5',
            'count': 5.5,
            'dayKeyUtc': '',
            'resetAtUtc': 'tomorrow',
          },
        ),
      );

      expect(failure.kind, EventActionFailureKind.dailyLimitReached);
      expect(failure.dailyLimit?.limit, isNull);
      expect(failure.dailyLimit?.count, isNull);
      expect(failure.dailyLimit?.dayKeyUtc, isNull);
      expect(failure.dailyLimit?.resetAtUtc, isNull);
    });

    test('maps create request conflict support context safely', () {
      final failure = mapEventActionFailure(
        _domainError(
          'create_request_conflict',
          code: 'already-exists',
          details: <String, dynamic>{
            'eventId': 'event-1',
            'createRequestId': '550e8400-e29b-41d4-a716-446655440000',
            'dayKeyUtc': '2026-06-14',
          },
        ),
      );

      expect(failure.kind, EventActionFailureKind.createRequestConflict);
      expect(failure.firebaseCode, 'already-exists');
      expect(failure.domainCode, 'create_request_conflict');
      expect(failure.retryable, isFalse);
      expect(failure.dailyLimit, isNull);
      expect(failure.createRequestConflict?.eventId, 'event-1');
      expect(
        failure.createRequestConflict?.createRequestId,
        '550e8400-e29b-41d4-a716-446655440000',
      );
      expect(failure.createRequestConflict?.dayKeyUtc, '2026-06-14');
    });

    test('ignores malformed create request conflict context safely', () {
      final failure = mapEventActionFailure(
        _domainError(
          'create_request_conflict',
          code: 'already-exists',
          details: <String, dynamic>{
            'eventId': '',
            'createRequestId': 42,
            'dayKeyUtc': '   ',
          },
        ),
      );

      expect(failure.kind, EventActionFailureKind.createRequestConflict);
      expect(failure.createRequestConflict?.eventId, isNull);
      expect(failure.createRequestConflict?.createRequestId, isNull);
      expect(failure.createRequestConflict?.dayKeyUtc, isNull);
    });

    test('preserves reason for temporal join and leave failures', () {
      final joinFailure = mapEventActionFailure(
        _domainError(
          'event_not_joinable',
          details: <String, dynamic>{'reason': 'past_event'},
        ),
      );
      final leaveFailure = mapEventActionFailure(
        _domainError(
          'event_not_leaveable',
          details: <String, dynamic>{'reason': 'event_started'},
        ),
      );

      expect(joinFailure.kind, EventActionFailureKind.eventNotJoinable);
      expect(joinFailure.reason, 'past_event');
      expect(joinFailure.dailyLimit, isNull);
      expect(joinFailure.createRequestConflict, isNull);
      expect(leaveFailure.kind, EventActionFailureKind.eventNotLeaveable);
      expect(leaveFailure.reason, 'event_started');
      expect(leaveFailure.dailyLimit, isNull);
      expect(leaveFailure.createRequestConflict, isNull);
    });

    test('keeps invariant backend state failures non-retryable', () {
      for (final domainCode in <String>[
        'create_request_marker_inconsistent',
        'create_request_marker_missing',
        'event_creation_counter_inconsistent',
        'event_cancellation_inconsistent',
        'event_participant_state_inconsistent',
        'event_report_state_inconsistent',
        'participant_membership_inconsistent',
      ]) {
        expect(
          mapEventActionFailure(_domainError(domainCode)).retryable,
          isFalse,
          reason: domainCode,
        );
      }
    });

    test('falls back to Firebase code when domain details are unavailable', () {
      expect(
        mapEventActionFailure(
          _TestFirebaseFunctionsException(
            code: 'unauthenticated',
            message: 'Auth required',
            details: 'not a map',
          ),
        ).kind,
        EventActionFailureKind.authRequired,
      );

      final unavailable = mapEventActionFailure(
        _TestFirebaseFunctionsException(
          code: 'unavailable',
          message: 'Network unavailable',
        ),
      );

      expect(unavailable.kind, EventActionFailureKind.unavailable);
      expect(unavailable.retryable, isTrue);

      final permissionDenied = mapEventActionFailure(
        _TestFirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Denied',
        ),
      );
      expect(permissionDenied.kind, EventActionFailureKind.permissionDenied);
      expect(permissionDenied.domainCode, isNull);

      final plainFirebase = mapEventActionFailure(
        FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
      );
      expect(plainFirebase.kind, EventActionFailureKind.eventNotFound);

      expect(
        mapEventActionFailure(
          _TestFirebaseFunctionsException(
            code: 'invalid-argument',
            message: 'Invalid',
          ),
        ).kind,
        EventActionFailureKind.validation,
      );
      expect(
        mapEventActionFailure(
          _TestFirebaseFunctionsException(
            code: 'deadline-exceeded',
            message: 'Timeout',
          ),
        ).retryable,
        isTrue,
      );
      expect(
        mapEventActionFailure(
          _TestFirebaseFunctionsException(
            code: 'internal',
            message: 'Internal',
          ),
        ).kind,
        EventActionFailureKind.unknown,
      );
    });

    test('uses safe unknown fallback for unknown Firebase failures', () {
      final failure = mapEventActionFailure(
        _TestFirebaseFunctionsException(
          code: 'internal',
          message: 'Stack trace: details',
          details: <String, dynamic>{'domainCode': 'new_backend_code'},
        ),
      );

      expect(failure.kind, EventActionFailureKind.unknown);
      expect(failure.domainCode, 'new_backend_code');
      expect(failure.retryable, isFalse);
    });

    testWidgets('resolves messages through FFLocalizations without raw backend',
        (tester) async {
      final error = _TestFirebaseFunctionsException(
        code: 'internal',
        message: 'Stack trace: details',
        details: <String, dynamic>{'domainCode': 'daily_limit_reached'},
      );

      final ruMessage = await _localizedMessage(
        tester,
        locale: const Locale('ru'),
        error: error,
      );
      final enMessage = await _localizedMessage(
        tester,
        locale: const Locale('en'),
        error: error,
      );

      expect(ruMessage, contains('5 событий'));
      expect(enMessage, contains('5 events'));
      expect(ruMessage, isNot(contains('Stack trace')));
      expect(enMessage, isNot(contains('Stack trace')));

      final regionalRuMessage = eventActionFailureMessageForLocalizations(
        FFLocalizations(const Locale('ru', 'RU')),
        mapEventActionFailure(error),
      );
      expect(regionalRuMessage, contains('5 событий'));
    });

    testWidgets('resolves clear join failure messages without raw backend',
        (tester) async {
      for (final scenario in [
        (
          error: _domainError('event_full'),
          ruMessage: 'В этом событии уже нет свободных мест.',
          enMessage: 'There are no free spots left in this event.',
        ),
        (
          error: _domainError(
            'event_not_joinable',
            details: <String, dynamic>{'reason': 'not_active'},
          ),
          ruMessage: 'Событие отменено, присоединиться нельзя.',
          enMessage: 'This event was canceled, so you cannot join it.',
        ),
        (
          error: _domainError(
            'event_not_joinable',
            details: <String, dynamic>{'reason': 'past_event'},
          ),
          ruMessage: 'Событие уже началось, присоединиться нельзя.',
          enMessage: 'This event has already started, so you cannot join it.',
        ),
        (
          error: _domainError('already_joined'),
          ruMessage: 'Вы уже присоединились к этому событию.',
          enMessage: 'You have already joined this event.',
        ),
      ]) {
        final ruMessage = await _localizedMessage(
          tester,
          locale: const Locale('ru'),
          error: scenario.error,
        );
        final enMessage = await _localizedMessage(
          tester,
          locale: const Locale('en'),
          error: scenario.error,
        );

        expect(ruMessage, scenario.ruMessage);
        expect(enMessage, scenario.enMessage);
        expect(ruMessage, isNot(contains('Raw backend message')));
        expect(enMessage, isNot(contains('Raw backend message')));
      }
    });

    testWidgets('resolves clear leave race message without raw backend',
        (tester) async {
      final error = _domainError(
        'event_not_leaveable',
        details: <String, dynamic>{'reason': 'event_started'},
      );

      final ruMessage = await _localizedMessage(
        tester,
        locale: const Locale('ru'),
        error: error,
      );
      final enMessage = await _localizedMessage(
        tester,
        locale: const Locale('en'),
        error: error,
      );

      expect(ruMessage, 'Событие уже началось, выйти из него нельзя.');
      expect(
        enMessage,
        'This event has already started, so you cannot leave it.',
      );
      expect(ruMessage, isNot(contains('Raw backend message')));
      expect(enMessage, isNot(contains('Raw backend message')));
    });

    testWidgets('resolves clear report failure messages without raw backend',
        (tester) async {
      for (final scenario in [
        (
          error: _domainError('event_report_self'),
          ruMessage: 'Нельзя пожаловаться на своё событие.',
          enMessage: 'You cannot report your own event.',
        ),
        (
          error: _domainError('event_not_reportable'),
          ruMessage: 'На это событие больше нельзя пожаловаться.',
          enMessage: 'This event can no longer be reported.',
        ),
        (
          error: _domainError('event_chat_message_report_self'),
          ruMessage: 'Нельзя пожаловаться на своё сообщение.',
          enMessage: 'You cannot report your own message.',
        ),
        (
          error: _domainError('event_chat_message_not_reportable'),
          ruMessage: 'На это сообщение больше нельзя пожаловаться.',
          enMessage: 'This message can no longer be reported.',
        ),
        (
          error: _domainError('event_chat_message_not_found'),
          ruMessage: 'Сообщение уже недоступно.',
          enMessage: 'This message is no longer available.',
        ),
      ]) {
        final ruMessage = await _localizedMessage(
          tester,
          locale: const Locale('ru'),
          error: scenario.error,
        );
        final enMessage = await _localizedMessage(
          tester,
          locale: const Locale('en'),
          error: scenario.error,
        );

        expect(ruMessage, scenario.ruMessage);
        expect(enMessage, scenario.enMessage);
        expect(ruMessage, isNot(contains('Raw backend message')));
        expect(enMessage, isNot(contains('Raw backend message')));
      }
    });
  });
}

FirebaseFunctionsException _domainError(
  String domainCode, {
  Map<String, dynamic> details = const <String, dynamic>{},
  String code = 'failed-precondition',
}) =>
    _TestFirebaseFunctionsException(
      code: code,
      message: 'Raw backend message',
      details: <String, dynamic>{
        'domainCode': domainCode,
        ...details,
      },
    );

class _TestFirebaseFunctionsException extends FirebaseFunctionsException {
  _TestFirebaseFunctionsException({
    required super.code,
    required super.message,
    super.details,
  });
}

Future<String> _localizedMessage(
  WidgetTester tester, {
  required Locale locale,
  required Object error,
}) async {
  late String message;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const <Locale>[
        Locale('ru'),
        Locale('en'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        FFLocalizationsDelegate(),
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
      ],
      home: Builder(
        builder: (context) {
          message = eventActionFailureMessage(context, error);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return message;
}
