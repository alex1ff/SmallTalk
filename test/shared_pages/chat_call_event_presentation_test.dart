import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/components/chat_call_event_card.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/chat_call_event_presentation.dart';

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

MessagesRecord _callMessage({
  required String outcome,
  required String callerId,
  DateTime? createdAt,
  DateTime? callStartedAt,
  DateTime? callEndedAt,
  int? callDurationSeconds,
}) {
  final conversationRef = ConversationsRecord.collection.doc('student_teacher');
  final messageRef = MessagesRecord.createDoc(
    conversationRef,
    id: 'call_${outcome}_$callerId',
  );

  return MessagesRecord.getDocumentFromData(
    {
      'type': kConversationMessageTypeCallEvent,
      'callOutcome': outcome,
      'callerId': callerId,
      'callStartedAt': callStartedAt,
      'callEndedAt': callEndedAt,
      'callDurationSeconds': callDurationSeconds,
      'createdAt': createdAt,
    },
    messageRef,
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

  group('chat call event presentation', () {
    testWidgets('formats outgoing completed calls', (tester) async {
      final now = DateTime(2026, 5, 30, 10);
      final presentation = await _readWithContext(
        tester,
        (context) => buildChatCallEventPresentation(
          context,
          message: _callMessage(
            outcome: kConversationCallOutcomeCompleted,
            callerId: 'student',
            callEndedAt: DateTime(2026, 5, 30, 9, 42),
            callDurationSeconds: 750,
          ),
          currentUserUid: 'student',
          now: now,
        ),
      );

      expect(presentation.title, 'Outgoing call');
      expect(presentation.details, startsWith('Today, '));
      expect(presentation.details, contains('12:30 min'));
      expect(presentation.icon, Icons.call_made_rounded);
      expect(presentation.tone, ChatCallEventTone.normal);
    });

    testWidgets('uses call timestamps when stored duration is missing',
        (tester) async {
      final now = DateTime(2026, 5, 30, 10);
      final presentation = await _readWithContext(
        tester,
        (context) => buildChatCallEventPresentation(
          context,
          message: _callMessage(
            outcome: kConversationCallOutcomeCompleted,
            callerId: 'student',
            callStartedAt: DateTime(2026, 5, 30, 9, 40, 58),
            callEndedAt: DateTime(2026, 5, 30, 9, 42),
            callDurationSeconds: 0,
          ),
          currentUserUid: 'student',
          now: now,
        ),
      );

      expect(presentation.details, contains('1:02 min'));
    });

    testWidgets('formats inbound missed calls as alerts', (tester) async {
      final now = DateTime(2026, 5, 30, 10);
      final presentation = await _readWithContext(
        tester,
        (context) => buildChatCallEventPresentation(
          context,
          message: _callMessage(
            outcome: kConversationCallOutcomeMissed,
            callerId: 'teacher',
            createdAt: DateTime(2026, 5, 30, 9, 42),
          ),
          currentUserUid: 'student',
          now: now,
        ),
      );

      expect(presentation.title, 'Missed call');
      expect(presentation.details, contains('—'));
      expect(presentation.icon, Icons.phone_missed_rounded);
      expect(presentation.tone, ChatCallEventTone.alert);
    });

    testWidgets('keeps caller-specific missed and cancelled labels',
        (tester) async {
      final now = DateTime(2026, 5, 30, 10);
      final values = await _readWithContext(
        tester,
        (context) => (
          noAnswer: formatChatCallEventTitle(
            context,
            outcome: kConversationCallOutcomeMissed,
            callerId: 'student',
            currentUserUid: 'student',
          ),
          cancelled: buildChatCallEventPresentation(
            context,
            message: _callMessage(
              outcome: kConversationCallOutcomeCancelled,
              callerId: 'student',
              createdAt: DateTime(2026, 5, 30, 9, 42),
              callDurationSeconds: 0,
            ),
            currentUserUid: 'student',
            now: now,
          ),
        ),
      );

      expect(values.noAnswer, 'No answer');
      expect(values.cancelled.title, 'Cancelled call');
      expect(values.cancelled.details, contains('0 sec.'));
      expect(values.cancelled.icon, Icons.phone_callback_rounded);
      expect(values.cancelled.tone, ChatCallEventTone.alert);
    });
  });
}
