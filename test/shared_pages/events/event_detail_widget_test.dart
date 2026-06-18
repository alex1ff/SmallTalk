import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/events/event_detail_widget.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';
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
    initializeEventListTimeZones();
    await initializeDateFormatting('ru');
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

  testWidgets('shows date, time, and place block in event timezone',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          startsAt: DateTime.utc(2035, 6, 15, 2, 30),
          timeZoneId: 'America/New_York',
          locationName: '  Starbucks, ул. Арбат, 5  ',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailDetailsBlockKey), findsOneWidget);
    expect(find.byKey(eventDetailDateRowKey), findsOneWidget);
    expect(find.byKey(eventDetailTimeRowKey), findsOneWidget);
    expect(find.byKey(eventDetailPlaceRowKey), findsOneWidget);
    expect(find.text('Дата'), findsOneWidget);
    expect(find.text('Время'), findsOneWidget);
    expect(find.text('Место'), findsOneWidget);
    expect(find.text('14 июн.'), findsOneWidget);
    expect(find.text('22:30'), findsOneWidget);
    expect(find.text('Starbucks, ул. Арбат, 5'), findsOneWidget);
    expect(
      _semanticsLabelsInsideKey(tester, eventDetailDateRowKey),
      contains('Дата: 14 июн.'),
    );
    expect(
      _semanticsLabelsInsideKey(tester, eventDetailTimeRowKey),
      contains('Время: 22:30'),
    );
    expect(
      _semanticsLabelsInsideKey(tester, eventDetailPlaceRowKey),
      contains('Место: Starbucks, ул. Арбат, 5'),
    );
  });

  testWidgets('details block shows place fallback when date is present',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          startsAt: DateTime.utc(2035, 6, 15, 2, 30),
          timeZoneId: 'America/New_York',
          locationName: '   ',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailDetailsBlockKey), findsOneWidget);
    expect(find.byKey(eventDetailPlaceRowKey), findsOneWidget);
    expect(find.text('Место не указано'), findsOneWidget);
    expect(
      _semanticsLabelsInsideKey(tester, eventDetailPlaceRowKey),
      contains('Место: Место не указано'),
    );
  });

  testWidgets(
      'details block preserves event timezone wall time across DST gaps',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          startsAt: DateTime.utc(2026, 3, 28, 21, 30),
          timeZoneId: 'Asia/Yekaterinburg',
          locationName: 'Лофт на Ленина',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailDetailsBlockKey), findsOneWidget);
    expect(find.text('29 мар.'), findsOneWidget);
    expect(find.text('02:30'), findsOneWidget);
    expect(
      _semanticsLabelsInsideKey(tester, eventDetailTimeRowKey),
      contains('Время: 02:30'),
    );
  });

  testWidgets('details block handles invalid time zone without crashing',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          startsAt: DateTime.utc(2035, 6, 15, 2, 30),
          timeZoneId: 'Unknown/City',
          locationName: 'Starbucks',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailDetailsBlockKey), findsOneWidget);
    expect(find.byKey(eventDetailDateRowKey), findsOneWidget);
    expect(find.byKey(eventDetailTimeRowKey), findsOneWidget);
    expect(find.byKey(eventDetailPlaceRowKey), findsOneWidget);
    expect(find.text('Starbucks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides details block when date and place are absent',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(eventId: 'event-123'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailDetailsBlockKey), findsNothing);
    expect(find.byKey(eventDetailDateRowKey), findsNothing);
    expect(find.byKey(eventDetailTimeRowKey), findsNothing);
    expect(find.byKey(eventDetailPlaceRowKey), findsNothing);
  });

  testWidgets('details block fits narrow large-text layouts', (tester) async {
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
            startsAt: DateTime.utc(2035, 6, 15, 2, 30),
            timeZoneId: 'America/New_York',
            locationName:
                'Очень длинное название места встречи с адресом и ориентиром',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailDetailsBlockKey), findsOneWidget);
    expect(find.byKey(eventDetailPlaceRowKey), findsOneWidget);
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
    expect(
      find.bySemanticsLabel('Организатор: Анастасия Иванова. Ведущий встречи'),
      findsOneWidget,
    );
    expect(find.byKey(eventDetailOrganizerMessageButtonKey), findsOneWidget);
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
    expect(find.byKey(eventDetailOrganizerMessageButtonKey), findsNothing);
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

  testWidgets('organizer message action calls injected callback once',
      (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          organizerDisplayName: 'Анастасия Иванова',
          onOrganizerMessagePressed: () => tapCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailOrganizerMessageButtonKey), findsOneWidget);
    expect(find.text('Написать'), findsOneWidget);

    final buttonSemantics = tester.widget<Semantics>(
      find.byKey(eventDetailOrganizerMessageButtonKey),
    );
    expect(buttonSemantics.properties.button, isTrue);
    expect(buttonSemantics.properties.enabled, isTrue);
    expect(
      buttonSemantics.properties.label,
      'Написать организатору Анастасия Иванова',
    );
    expect(buttonSemantics.properties.onTap, isNotNull);

    await tester.tap(find.byKey(eventDetailOrganizerMessageButtonKey));
    await tester.pumpAndSettle();

    expect(tapCount, 1);
  });

  testWidgets(
      'organizer message action is visible but disabled without callback',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          organizerDisplayName: 'Анастасия Иванова',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buttonSemantics = tester.widget<Semantics>(
      find.byKey(eventDetailOrganizerMessageButtonKey),
    );
    expect(buttonSemantics.properties.button, isTrue);
    expect(buttonSemantics.properties.enabled, isFalse);
    expect(buttonSemantics.properties.onTap, isNull);
    expect(find.text('Написать'), findsOneWidget);
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

  testWidgets('shows participant list with names and fallback initials',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          participants: [
            EventDetailParticipantViewModel(displayName: 'Marco Rossi'),
            EventDetailParticipantViewModel(displayName: 'Лиза'),
            EventDetailParticipantViewModel(displayName: '  '),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailParticipantsSectionKey), findsOneWidget);
    expect(find.byKey(eventDetailParticipantsTitleKey), findsOneWidget);
    expect(find.text('Участники'), findsOneWidget);
    expect(find.byKey(eventDetailParticipantTileKey(0)), findsOneWidget);
    expect(find.byKey(eventDetailParticipantTileKey(1)), findsOneWidget);
    expect(find.byKey(eventDetailParticipantTileKey(2)), findsOneWidget);
    expect(find.text('Marco Rossi'), findsOneWidget);
    expect(find.text('Лиза'), findsOneWidget);
    expect(find.text('Участник'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(eventDetailParticipantTileKey(0)),
        matching: find.text('MR'),
      ),
      findsOneWidget,
    );
    final titleSemantics =
        tester.getSemantics(find.byKey(eventDetailParticipantsTitleKey));
    expect(titleSemantics.flagsCollection.isHeader, isTrue);
    expect(find.bySemanticsLabel(RegExp('Участники')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Участник: Marco Rossi')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Участник: Участник')),
      findsOneWidget,
    );
    semanticsHandle.dispose();
  });

  testWidgets('hides participant section for an empty participant list',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          participants: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailParticipantsSectionKey), findsNothing);
    expect(find.byKey(eventDetailParticipantsTitleKey), findsNothing);
    expect(find.text('Участники'), findsNothing);
  });

  testWidgets('participant avatar falls back when photo url is broken',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          participants: [
            EventDetailParticipantViewModel(
              displayName: 'Alex',
              photoUrl: 'https://invalid.example/avatar.png',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailParticipantsSectionKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(eventDetailParticipantTileKey(0)),
        matching: find.text('AL'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('participant list fits narrow large-text layouts',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3)),
        child: _buildTestApp(
          home: const EventDetailWidget(
            eventId: 'event-123',
            participants: [
              EventDetailParticipantViewModel(
                displayName: 'Очень длинное имя участника события',
              ),
              EventDetailParticipantViewModel(displayName: 'Лиза'),
              EventDetailParticipantViewModel(displayName: 'Kenzhi'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailParticipantsSectionKey), findsOneWidget);
    expect(find.byKey(eventDetailParticipantTileKey(0)), findsOneWidget);
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
    expect(source, isNot(contains('openChatThread')));
    expect(source, isNot(contains('ChatThreadWidget')));
    expect(source, isNot(contains('ConversationsRecord')));
    expect(source, isNot(contains('MessagesRecord')));
    expect(source, isNot(contains('EventParticipantsRecord')));
    expect(source, isNot(contains('FirebaseFirestore')));
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

List<String> _semanticsLabelsInsideKey(
  WidgetTester tester,
  Key key,
) {
  return tester
      .widgetList<Semantics>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Semantics),
        ),
      )
      .map((semantics) => semantics.properties.label)
      .whereType<String>()
      .where((label) => label.isNotEmpty)
      .toList(growable: false);
}
