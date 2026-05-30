import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/components/chat_call_event_card.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ru'),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    setupFirebaseCoreMocks();
    await FFLocalizations.initialize();
    await Firebase.initializeApp();
  });

  testWidgets('chat call event card renders title, details, and tap action',
      (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      _buildTestApp(
        ChatCallEventCard(
          title: 'Видео-звонок',
          details: 'Сегодня, 18:30 • 12 мин',
          onTap: () {
            tapped = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Видео-звонок'), findsOneWidget);
    expect(find.text('Сегодня, 18:30 • 12 мин'), findsOneWidget);
    expect(find.byIcon(Icons.phone_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    await tester.tap(find.byType(ChatCallEventCard));
    await tester.pump();

    expect(tapped, isTrue);
  });

  test('chat call event card does not expose icon color overrides', () {
    final source =
        File('lib/components/chat_call_event_card.dart').readAsStringSync();

    expect(source, contains('ChatCallEventTone'));
    expect(source, isNot(contains('iconColor')));
    expect(source, contains('boxShadow'));
  });
}
