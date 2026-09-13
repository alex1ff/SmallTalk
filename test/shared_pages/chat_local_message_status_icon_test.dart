import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/chat_local_message_status.dart';
import 'package:small_talk/shared_pages/chat_local_message_status_icon.dart';

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  FFLocalizationsDelegate(),
  FallbackMaterialLocalizationDelegate(),
  FallbackCupertinoLocalizationDelegate(),
];

Widget _buildTestApp({
  required ChatLocalMessageStatus status,
  Locale locale = const Locale('ru'),
}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: _localizationsDelegates,
      home: Scaffold(
        body: Center(
          child: ChatLocalMessageStatusIcon(status: status),
        ),
      ),
    );

void main() {
  testWidgets('renders local message status icons and Russian labels',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _buildTestApp(status: ChatLocalMessageStatus.sending),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Отправляется'), findsOneWidget);

      await tester.pumpWidget(
        _buildTestApp(status: ChatLocalMessageStatus.sent),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Отправлено'), findsOneWidget);

      await tester.pumpWidget(
        _buildTestApp(status: ChatLocalMessageStatus.failed),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Не отправлено'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('renders English labels for local message statuses',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _buildTestApp(
          status: ChatLocalMessageStatus.sending,
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Sending'), findsOneWidget);

      await tester.pumpWidget(
        _buildTestApp(
          status: ChatLocalMessageStatus.sent,
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Sent'), findsOneWidget);

      await tester.pumpWidget(
        _buildTestApp(
          status: ChatLocalMessageStatus.failed,
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Not sent'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
