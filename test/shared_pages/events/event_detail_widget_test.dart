import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/events/event_detail_widget.dart';
import 'package:small_talk/services/event_language_catalog.dart';

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

  testWidgets('shows normalized level range badge', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          levelMin: ' b1 ',
          levelMax: ' c1 ',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailLevelRangeBadgeKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(eventDetailLevelRangeBadgeKey),
        matching: find.text('B1-C1'),
      ),
      findsOneWidget,
    );

    final badgeSemantics = tester.widget<Semantics>(
      find.byKey(eventDetailLevelRangeBadgeKey),
    );
    expect(badgeSemantics.properties.label, 'Уровень B1-C1');
  });

  testWidgets('shows same-level range as a single level', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          levelMin: 'B1',
          levelMax: 'B1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(eventDetailLevelRangeBadgeKey),
        matching: find.text('B1'),
      ),
      findsOneWidget,
    );
    expect(find.text('B1-B1'), findsNothing);
  });

  testWidgets('hides level range badge when range is missing or invalid',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          levelMin: 'C1',
          levelMax: 'B1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailLevelRangeBadgeKey), findsNothing);
    final invalidRangeTitleDy = tester.getCenter(_detailBodyTitle()).dy;

    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          levelMin: 'B1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailLevelRangeBadgeKey), findsNothing);
    final missingRangeTitleDy = tester.getCenter(_detailBodyTitle()).dy;
    expect((invalidRangeTitleDy - missingRangeTitleDy).abs(), lessThan(1.0));
  });

  testWidgets('level range badge fits narrow large-text layouts',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: _buildTestApp(
          home: const EventDetailWidget(
            eventId: 'event-123',
            levelMin: 'B1',
            levelMax: 'C1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailLevelRangeBadgeKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows localized language badge from catalog', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          languageCode: ' EN-us ',
          languageCatalog: _languageCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailLanguageBadgeKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(eventDetailLanguageBadgeKey),
        matching: find.text('Английский'),
      ),
      findsOneWidget,
    );

    final badgeSemantics = tester.widget<Semantics>(
      find.byKey(eventDetailLanguageBadgeKey),
    );
    expect(badgeSemantics.properties.label, 'Язык Английский');
  });

  testWidgets('language badge falls back to denormalized name and raw code',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          languageCode: 'unknown',
          languageNameEn: 'Fallback English',
          languageNameRu: 'Фолбэк русский',
          languageCatalog: _languageCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(eventDetailLanguageBadgeKey),
        matching: find.text('Фолбэк русский'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          languageCode: ' custom-code ',
          languageNameEn: ' ',
          languageCatalog: _languageCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(eventDetailLanguageBadgeKey),
        matching: find.text('custom-code'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hides language badge for blank language data', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          languageCode: ' ',
          languageNameEn: '',
          languageNameRu: null,
          languageCatalog: _languageCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailLanguageBadgeKey), findsNothing);
  });

  testWidgets('language and level badges fit narrow large-text layouts',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: _buildTestApp(
          home: EventDetailWidget(
            eventId: 'event-123',
            levelMin: 'B1',
            levelMax: 'C1',
            languageCode: 'en',
            languageCatalog: _languageCatalog,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailLevelRangeBadgeKey), findsOneWidget);
    expect(find.byKey(eventDetailLanguageBadgeKey), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  test('event detail level badge stays presentation-only', () {
    final source = File('lib/shared_pages/events/event_detail_widget.dart')
        .readAsStringSync();

    expect(source, isNot(contains('EventDetailRepository')));
    expect(source, isNot(contains('watchEventDetail')));
    expect(source, isNot(contains('EventsRecord')));
  });
}

final _languageCatalog = EventLanguageCatalog(
  languages: [
    EventLanguage(
      code: 'en',
      alternateCodes: const ['en', 'en-US'],
      nameEn: 'English',
      nameRu: 'Английский',
      model: 'nova-3',
      isPopular: true,
      iconUrl: 'https://example.com/english.png',
    ),
    EventLanguage(
      code: 'es',
      alternateCodes: const ['es', 'es-419'],
      nameEn: 'Spanish',
      nameRu: 'Испанский',
      model: 'nova-3',
      isPopular: true,
      iconUrl: 'https://example.com/spanish.png',
    ),
  ],
);

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

Finder _detailBodyTitle() => find.descendant(
      of: find.byType(Center),
      matching: find.text('Событие'),
    );
