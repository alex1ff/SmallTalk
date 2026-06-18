import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/events/event_detail_widget.dart';

const _supportedLocales = [
  Locale('ru'),
  Locale('en'),
];

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  FFLocalizationsDelegate(),
  FallbackMaterialLocalizationDelegate(),
  FallbackCupertinoLocalizationDelegate(),
];

Widget _buildTestApp({required Widget home}) {
  return MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: _supportedLocales,
    localizationsDelegates: _localizationsDelegates,
    home: home,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FFLocalizations.initialize();
  });

  testWidgets('renders event detail top bar with back and share actions',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(eventId: 'event-123'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailTopBarKey), findsOneWidget);
    expect(find.byKey(eventDetailBackButtonKey), findsOneWidget);
    expect(find.byKey(eventDetailShareButtonKey), findsOneWidget);
    expect(find.text('Событие'), findsWidgets);
    expect(find.byTooltip('Назад'), findsOneWidget);
    expect(find.byTooltip('Поделиться событием'), findsOneWidget);

    final backSemantics = tester.widget<Semantics>(
      find.byKey(eventDetailBackButtonKey),
    );
    expect(backSemantics.properties.label, 'Назад');
    expect(backSemantics.properties.button, isTrue);
    expect(backSemantics.properties.onTap, isNotNull);

    final shareSemantics = tester.widget<Semantics>(
      find.byKey(eventDetailShareButtonKey),
    );
    expect(shareSemantics.properties.label, 'Поделиться событием');
    expect(shareSemantics.properties.button, isTrue);
    expect(shareSemantics.properties.enabled, isFalse);

    final titleCenter = tester.getCenter(
      find.descendant(
        of: find.byKey(eventDetailTopBarKey),
        matching: find.text('Событие').first,
      ),
    );
    final topBarCenter = tester.getCenter(find.byKey(eventDetailTopBarKey));
    expect((titleCenter.dx - topBarCenter.dx).abs(), lessThan(1.0));
  });

  testWidgets('share action calls the injected callback once', (tester) async {
    var shareTapCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          onSharePressed: () => shareTapCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shareSemantics = tester.widget<Semantics>(
      find.byKey(eventDetailShareButtonKey),
    );
    expect(shareSemantics.properties.enabled, isTrue);
    expect(shareSemantics.properties.onTap, isNotNull);

    await tester.tap(find.byKey(eventDetailShareButtonKey));
    await tester.pumpAndSettle();

    expect(shareTapCount, 1);
  });

  testWidgets('back action pops the detail route when possible',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('ru'),
        supportedLocales: _supportedLocales,
        localizationsDelegates: _localizationsDelegates,
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const _StackRoot(),
            ),
            GoRoute(
              path: EventDetailWidget.routePath,
              builder: (context, state) => EventDetailWidget(
                eventId: state.pathParameters['eventId']!,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();

    expect(find.byType(EventDetailWidget), findsOneWidget);

    await tester.tap(find.byKey(eventDetailBackButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(EventDetailWidget), findsNothing);
    expect(find.text('Open detail'), findsOneWidget);
  });
}

class _StackRoot extends StatelessWidget {
  const _StackRoot();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () {
            context.push('/events/event-123');
          },
          child: const Text('Open detail'),
        ),
      ),
    );
  }
}
