import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/call_history/call_history_utils.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [
      Locale('ru'),
      Locale('en'),
    ],
    localizationsDelegates: const [
      FFLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FallbackMaterialLocalizationDelegate(),
      FallbackCupertinoLocalizationDelegate(),
    ],
    home: Scaffold(body: child),
  );
}

Future<T> _readWithContext<T>(
  WidgetTester tester,
  T Function(BuildContext context) read,
) async {
  late T result;
  await tester.pumpWidget(
    _buildTestApp(
      Builder(
        builder: (context) {
          result = read(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return result;
}

VideoSessionsRecord _session(
  String id,
  Map<String, dynamic> data,
) {
  return VideoSessionsRecord.getDocumentFromData(
    data,
    VideoSessionsRecord.collection.doc(id),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    setupFirebaseCoreMocks();
    await FFLocalizations.initialize();
    await Firebase.initializeApp();
  });

  group('call history utils', () {
    testWidgets('formats current-day session time as Today plus time',
        (tester) async {
      final now = DateTime(2026, 5, 12, 9);
      final startedAt = DateTime(2026, 5, 12, 12, 34);

      final label = await _readWithContext(
        tester,
        (context) => formatSessionStartedAtFromDateTime(
          context,
          startedAt,
          now: now,
        ),
      );

      expect(label, startsWith('Today, '));
      expect(label, contains('12:34'));
    });

    testWidgets('formats previous-day session time as Yesterday plus time',
        (tester) async {
      final label = await _readWithContext(
        tester,
        (context) => formatSessionStartedAtFromDateTime(
          context,
          DateTime(2026, 5, 11, 8, 15),
          now: DateTime(2026, 5, 12, 9),
        ),
      );

      expect(label, startsWith('Yesterday, '));
      expect(label, contains('8:15'));
    });

    testWidgets('formats older session time as short date plus time',
        (tester) async {
      final label = await _readWithContext(
        tester,
        (context) => formatSessionStartedAtFromDateTime(
          context,
          DateTime(2026, 5, 1, 7),
          now: DateTime(2026, 5, 12, 9),
        ),
      );

      expect(label, startsWith('5/1/26, '));
      expect(label, contains('7:00'));
    });

    testWidgets('formats missing session time as dash', (tester) async {
      final label = await _readWithContext(
        tester,
        (context) => formatSessionStartedAtFromDateTime(context, null),
      );

      expect(label, '-');
    });

    test('parses connected-at metadata from legacy storage shapes', () {
      final connectedAt = DateTime.utc(2026, 5, 12, 9, 30);
      final millis = connectedAt.millisecondsSinceEpoch;

      expect(resolveCallConnectedAtMetadata(connectedAt), connectedAt);
      expect(
        resolveCallConnectedAtMetadata(Timestamp.fromDate(connectedAt)),
        connectedAt.toLocal(),
      );
      expect(
        resolveCallConnectedAtMetadata(millis),
        DateTime.fromMillisecondsSinceEpoch(millis),
      );
      expect(
        resolveCallConnectedAtMetadata('$millis'),
        DateTime.fromMillisecondsSinceEpoch(millis),
      );
      expect(
        resolveCallConnectedAtMetadata(connectedAt.toIso8601String()),
        connectedAt,
      );
      expect(resolveCallConnectedAtMetadata('connected'), isNull);
    });

    test('AI feedback eligibility excludes unconnected terminal sessions', () {
      expect(
        isCallFeedbackEligibleSession(_session('ended', {'status': 'ended'})),
        isTrue,
      );
      expect(
        isCallFeedbackEligibleSession(
          _session('cancelled', {'status': 'cancelled'}),
        ),
        isFalse,
      );
      expect(
        isCallFeedbackEligibleSession(
          _session('expired', {'status': 'expired'}),
        ),
        isFalse,
      );
      expect(
        isCallFeedbackEligibleSession(
          _session('connected-expired', {
            'status': 'expired',
            'sessionMetadata': {
              'dailyWebhookConnectedAt': DateTime.utc(2026, 5, 12, 9),
            },
          }),
        ),
        isTrue,
      );
      expect(
        isCallFeedbackEligibleSession(
          _session('active', {'status': 'active'}),
        ),
        isFalse,
      );
    });

    test('history participant filter ignores stale legacy participant fields',
        () {
      expect(
        callHistorySessionDataIncludesUser(
          {
            'studentId': 'stale-student',
            'tutorId': 'stale-teacher',
            'requesterId': 'actual-requester',
            'responderId': 'actual-responder',
          },
          'stale-student',
        ),
        isFalse,
      );
      expect(
        callHistorySessionDataIncludesUser(
          {
            'studentId': 'legacy-student',
            'tutorId': 'legacy-teacher',
          },
          'legacy-student',
        ),
        isTrue,
      );
      expect(
        callHistorySessionDataIncludesUser(
          {
            'participantIds': ['user-a', 'user-b'],
            'studentId': 'stale-student',
            'tutorId': 'stale-teacher',
          },
          'stale-student',
        ),
        isFalse,
      );
      expect(
        callHistorySessionDataIncludesUser(
          {
            'participantIds': ['requester-only'],
            'matchContext': {
              'requesterId': 'requester-only',
              'acceptedResponderId': 'nested-responder',
            },
          },
          'nested-responder',
        ),
        isTrue,
      );
    });

    test('merges only user-owned ended sessions across history branches', () {
      final newerNestedSession = _session(
        'newer-nested-session',
        {
          'status': 'ended',
          'participantIds': ['requester-only'],
          'matchContext': {
            'requesterId': 'requester-only',
            'acceptedResponderId': 'current-user',
          },
          'sessionMetadata': {
            'callConnectedAt': DateTime.utc(2026, 5, 13, 12),
          },
          'startedAt': DateTime.utc(2026, 5, 13, 11),
        },
      );
      final olderCanonicalSession = _session(
        'older-canonical-session',
        {
          'status': 'ended',
          'participantIds': ['current-user', 'peer-user'],
          'requesterId': 'current-user',
          'responderId': 'peer-user',
          'startedAt': DateTime.utc(2026, 5, 12, 10),
        },
      );
      final staleLegacySession = _session(
        'stale-legacy-session',
        {
          'status': 'ended',
          'participantIds': ['actual-requester', 'actual-responder'],
          'studentId': 'current-user',
          'tutorId': 'stale-teacher',
          'requesterId': 'actual-requester',
          'responderId': 'actual-responder',
          'startedAt': DateTime.utc(2026, 5, 14, 10),
        },
      );
      final activeSession = _session(
        'active-session',
        {
          'status': 'active',
          'participantIds': ['current-user', 'active-peer'],
          'requesterId': 'current-user',
          'responderId': 'active-peer',
          'startedAt': DateTime.utc(2026, 5, 15, 10),
        },
      );

      final merged = mergeCallHistorySessionsForUser(
        [
          [olderCanonicalSession, staleLegacySession],
          [newerNestedSession, olderCanonicalSession, activeSession],
        ],
        'current-user',
      );

      expect(
        merged.map((session) => session.reference.id),
        [
          'newer-nested-session',
          'older-canonical-session',
        ],
      );
    });
  });
}
