import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/authorization/login/login_widget.dart';
import 'package:small_talk/components/button/button_widget.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FFLocalizations.initialize();
  });

  testWidgets('keyboard and CTA share one email sign-in operation',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final signInCompleter = Completer<void>();
    var signInCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          FFLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: LoginWidget(
          emailSignInOverride: (_, __, ___) async {
            signInCalls++;
            await signInCompleter.future;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'user@example.com');
    await tester.enterText(fields.at(1), 'secret-password');
    await tester.tap(fields.at(1));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(signInCalls, 1);
    expect(find.text('Signing in...'), findsOneWidget);
    final busyButton = tester.getSemantics(find.byType(ButtonWidget));
    expect(busyButton.flagsCollection.isEnabled, isFalse);
    for (final key in [loginAppleButtonKey, loginGoogleButtonKey]) {
      final socialButton = tester.getSemantics(find.byKey(key));
      expect(socialButton.flagsCollection.isButton, isTrue);
      expect(socialButton.flagsCollection.isEnabled, isFalse);
      expect(
        socialButton.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
    }

    await tester.tap(find.byType(ButtonWidget), warnIfMissed: false);
    await tester.pump();
    expect(signInCalls, 1);

    signInCompleter.complete();
    await tester.pumpAndSettle();
    expect(find.text('Next'), findsOneWidget);
    for (final key in [loginAppleButtonKey, loginGoogleButtonKey]) {
      expect(
        tester.getSemantics(find.byKey(key)).flagsCollection.isEnabled,
        isTrue,
      );
    }
    semantics.dispose();
  });
}
