import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FFLocalizations.initialize();
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
  });
}
