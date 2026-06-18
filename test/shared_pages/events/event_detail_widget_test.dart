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

  testWidgets('shows title and full multiline description', (tester) async {
    const description = 'Неформальная встреча для разговорной практики.\n\n'
        'Приходите сами и приводите друзей. Обсудим путешествия, работу '
        'и повседневные темы без строгой программы.';

    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          title: '  Разговорный клуб: кофе и английский  ',
          description: description,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byKey(eventDetailTitleKey), findsOneWidget);
    expect(find.text('Разговорный клуб: кофе и английский'), findsOneWidget);
    expect(find.byKey(eventDetailDescriptionKey), findsOneWidget);
    expect(find.text(description), findsOneWidget);

    final titleWidget = tester.widget<Text>(find.byKey(eventDetailTitleKey));
    expect(titleWidget.maxLines, isNull);
    expect(titleWidget.overflow, isNull);

    final descriptionWidget =
        tester.widget<Text>(find.byKey(eventDetailDescriptionKey));
    expect(descriptionWidget.maxLines, isNull);
    expect(descriptionWidget.overflow, isNull);
    expect(descriptionWidget.softWrap, isTrue);
  });

  testWidgets('falls back to untitled and hides blank description',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          title: ' ',
          description: '   ',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailTitleKey), findsOneWidget);
    expect(find.text('Без названия'), findsOneWidget);
    expect(find.byKey(eventDetailDescriptionKey), findsNothing);
  });

  testWidgets('title and description fit narrow large-text layouts',
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
            title: 'Очень длинное название события для проверки переноса',
            description:
                'Очень длинное описание события с несколькими предложениями, '
                'которое должно переноситься на узком экране и оставаться '
                'доступным для чтения без обрезки и layout overflow.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailTitleKey), findsOneWidget);
    expect(find.byKey(eventDetailDescriptionKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows organizer card with label, avatar fallback, and subtitle',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          organizerDisplayName: '  Анастасия Иванова  ',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailOrganizerCardKey), findsOneWidget);
    expect(find.byKey(eventDetailOrganizerAvatarKey), findsOneWidget);
    expect(find.byKey(eventDetailOrganizerNameKey), findsOneWidget);
    expect(find.text('Организатор'), findsOneWidget);
    expect(find.text('Анастасия Иванова'), findsOneWidget);
    expect(find.text('Ведущий встречи'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(eventDetailOrganizerAvatarKey),
        matching: find.text('АИ'),
      ),
      findsOneWidget,
    );

    final cardSemantics =
        tester.widget<Semantics>(find.byKey(eventDetailOrganizerCardKey));
    expect(
      cardSemantics.properties.label,
      'Организатор: Анастасия Иванова. Ведущий встречи',
    );
  });

  testWidgets('hides organizer card when organizer name is blank',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          organizerDisplayName: '   ',
          organizerPhotoUrl: 'https://example.com/avatar.png',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailOrganizerCardKey), findsNothing);
    expect(find.byKey(eventDetailOrganizerAvatarKey), findsNothing);
  });

  testWidgets('organizer avatar falls back when image url is broken',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          organizerDisplayName: 'Marco',
          organizerPhotoUrl: 'https://invalid.example/avatar.png',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailOrganizerCardKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(eventDetailOrganizerAvatarKey),
        matching: find.text('MA'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('organizer card fits narrow large-text layouts', (tester) async {
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
            organizerDisplayName:
                'Очень длинное имя организатора встречи для переноса',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailOrganizerCardKey), findsOneWidget);
    expect(find.byKey(eventDetailOrganizerNameKey), findsOneWidget);
    expect(tester.takeException(), isNull);
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
      of: find.byType(ListView),
      matching: find.byKey(eventDetailTitleKey),
    );
