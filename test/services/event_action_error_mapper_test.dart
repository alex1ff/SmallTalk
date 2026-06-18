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
        'organizer_profile_required': EventActionFailureKind.profileRequired,
        'participant_profile_required': EventActionFailureKind.profileRequired,
        'sender_profile_required': EventActionFailureKind.profileRequired,
        'sender_profile_invalid': EventActionFailureKind.profileRequired,
        'capacity_below_participants_count':
            EventActionFailureKind.capacityBelowParticipants,
        'event_chat_metadata_invalid': EventActionFailureKind.chatUnavailable,
        'event_chat_writes_blocked': EventActionFailureKind.chatUnavailable,
        'create_request_marker_inconsistent':
            EventActionFailureKind.staleEventState,
        'create_request_marker_missing': EventActionFailureKind.staleEventState,
        'event_creation_counter_inconsistent':
            EventActionFailureKind.staleEventState,
        'event_cancellation_inconsistent':
            EventActionFailureKind.staleEventState,
        'event_participant_state_inconsistent':
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
            'resetAtUtc': '2026-06-15T00:00:00.000Z',
          },
        ),
      );

      expect(failure.kind, EventActionFailureKind.dailyLimitReached);
      expect(failure.firebaseCode, 'resource-exhausted');
      expect(failure.domainCode, 'daily_limit_reached');
      expect(failure.retryable, isFalse);
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
      expect(leaveFailure.kind, EventActionFailureKind.eventNotLeaveable);
      expect(leaveFailure.reason, 'event_started');
    });

    test('keeps invariant backend state failures non-retryable', () {
      for (final domainCode in <String>[
        'create_request_marker_inconsistent',
        'create_request_marker_missing',
        'event_creation_counter_inconsistent',
        'event_cancellation_inconsistent',
        'event_participant_state_inconsistent',
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
