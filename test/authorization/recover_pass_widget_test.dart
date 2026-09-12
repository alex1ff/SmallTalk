import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/authorization/recover_pass/recover_pass_widget.dart';
import 'package:small_talk/components/send_widget.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FFLocalizations.initialize();
  });

  testWidgets('shows neutral confirmation only after server acceptance',
      (tester) async {
    await tester.pumpWidget(_app(
      invoker: (_) async => {'accepted': true},
    ));
    await tester.enterText(
      find.byType(TextFormField),
      'user@example.com',
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SendWidget), findsOneWidget);
    expect(
      find.text(
        'If an account with this email exists, check your inbox shortly.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('does not claim delivery when callable fails', (tester) async {
    await tester.pumpWidget(_app(
      invoker: (_) async => throw Exception('network unavailable'),
    ));
    await tester.enterText(
      find.byType(TextFormField),
      'user@example.com',
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SendWidget), findsNothing);
    expect(
        find.text(
          'Could not submit the request. Check your connection and try again.',
        ),
        findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('localizes invalid email validation in English', (tester) async {
    await tester.pumpWidget(_app(invoker: (_) async => {'accepted': true}));
    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Send'));
    await tester.pump();

    expect(find.text('Invalid email address'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}

Widget _app({required Future<Object?> Function(Map<String, dynamic>) invoker}) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      FFLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: RecoverPassWidget(passwordResetInvoker: invoker),
  );
}
