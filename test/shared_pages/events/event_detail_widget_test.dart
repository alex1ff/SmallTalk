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

Widget _buildTestApp({
  required Widget home,
  Locale locale = const Locale('ru'),
}) {
  return MaterialApp(
    locale: locale,
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

  testWidgets('renders sticky bottom action bar with disabled defaults',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: const EventDetailWidget(eventId: 'event-123'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(eventDetailBottomActionBarKey), findsOneWidget);
      expect(find.byKey(eventDetailPrimaryCtaKey), findsOneWidget);
      expect(find.byKey(eventDetailChatCtaKey), findsOneWidget);
      expect(find.text('Присоединиться'), findsOneWidget);
      expect(find.text('Чат'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      final primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isButton, isTrue);
      expect(primarySemantics.flagsCollection.isEnabled, isFalse);
      expect(primarySemantics.label, 'Присоединиться');

      final chatSemantics =
          tester.getSemantics(find.byKey(eventDetailChatCtaKey));
      expect(chatSemantics.flagsCollection.isButton, isTrue);
      expect(chatSemantics.flagsCollection.isEnabled, isFalse);
      expect(chatSemantics.label, contains('Чат доступен только участникам'));
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('bottom action bar callbacks fire once', (tester) async {
    var joinTapCount = 0;
    var chatTapCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          joinCtaState: EventDetailJoinCtaState.join,
          onPrimaryCtaPressed: () => joinTapCount += 1,
          onChatPressed: () => chatTapCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventDetailChatCtaKey));
    await tester.pumpAndSettle();

    expect(joinTapCount, 1);
    expect(chatTapCount, 1);
  });

  testWidgets('bottom action bar shows English labels', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          locale: const Locale('en'),
          home: const EventDetailWidget(eventId: 'event-123'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Join'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      final chatSemantics =
          tester.getSemantics(find.byKey(eventDetailChatCtaKey));
      expect(
        chatSemantics.label,
        contains('Chat is available to participants only'),
      );
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('join CTA state keeps chat disabled for non-participants',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    var joinTapCount = 0;

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventDetailWidget(
            eventId: 'event-123',
            joinCtaState: EventDetailJoinCtaState.join,
            onPrimaryCtaPressed: () => joinTapCount += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Присоединиться'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      final primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isButton, isTrue);
      expect(primarySemantics.flagsCollection.isEnabled, isTrue);
      expect(primarySemantics.label, 'Присоединиться');

      final chatSemantics =
          tester.getSemantics(find.byKey(eventDetailChatCtaKey));
      expect(chatSemantics.flagsCollection.isButton, isTrue);
      expect(chatSemantics.flagsCollection.isEnabled, isFalse);
      expect(chatSemantics.label, contains('Чат доступен только участникам'));

      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pumpAndSettle();

      expect(joinTapCount, 1);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('joined CTA state shows leave action for participants',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    var leaveTapCount = 0;

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventDetailWidget(
            eventId: 'event-123',
            joinCtaState: EventDetailJoinCtaState.joined,
            onPrimaryCtaPressed: () => leaveTapCount += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Покинуть'), findsOneWidget);

      final primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isButton, isTrue);
      expect(primarySemantics.flagsCollection.isEnabled, isTrue);
      expect(primarySemantics.label, contains('Вы участвуете'));
      expect(primarySemantics.label, contains('Покинуть событие'));

      final primaryButton = tester.widget<TextButton>(
        find.descendant(
          of: find.byKey(eventDetailPrimaryCtaKey),
          matching: find.byType(TextButton),
        ),
      );
      expect(
        primaryButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        const Color(0xFFB42318),
      );
      final leaveText = tester.widget<Text>(find.text('Покинуть'));
      expect(leaveText.style?.color, Colors.white);

      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pumpAndSettle();

      expect(leaveTapCount, 1);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('joined CTA state shows English leave label', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          locale: const Locale('en'),
          home: const EventDetailWidget(
            eventId: 'event-123',
            joinCtaState: EventDetailJoinCtaState.joined,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Leave'), findsOneWidget);
      final primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isButton, isTrue);
      expect(primarySemantics.flagsCollection.isEnabled, isFalse);
      expect(primarySemantics.label, contains('Joined'));
      expect(primarySemantics.label, contains('Leave event'));
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('joined participants can open chat when callback is provided',
      (tester) async {
    var chatTapCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          joinCtaState: EventDetailJoinCtaState.joined,
          onChatPressed: () => chatTapCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);

    await tester.tap(find.byKey(eventDetailChatCtaKey));
    await tester.pumpAndSettle();

    expect(chatTapCount, 1);
  });

  testWidgets('joined CTA state disables leave and chat without callbacks',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: const EventDetailWidget(
            eventId: 'event-123',
            joinCtaState: EventDetailJoinCtaState.joined,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      final primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isButton, isTrue);
      expect(primarySemantics.flagsCollection.isEnabled, isFalse);
      expect(primarySemantics.label, contains('Вы участвуете'));

      final chatSemantics =
          tester.getSemantics(find.byKey(eventDetailChatCtaKey));
      expect(chatSemantics.flagsCollection.isButton, isTrue);
      expect(chatSemantics.flagsCollection.isEnabled, isFalse);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('full canceled and past CTA states stay disabled',
      (tester) async {
    final cases =
        <({EventDetailJoinCtaState state, String label, String reason})>[
      (
        state: EventDetailJoinCtaState.full,
        label: 'Мест нет',
        reason: 'Мест нет',
      ),
      (
        state: EventDetailJoinCtaState.canceled,
        label: 'Отменено',
        reason: 'Событие отменено',
      ),
      (
        state: EventDetailJoinCtaState.past,
        label: 'Уже началось',
        reason: 'Событие уже началось',
      ),
    ];

    for (final testCase in cases) {
      final semanticsHandle = tester.ensureSemantics();
      var primaryTapCount = 0;

      try {
        await tester.pumpWidget(
          _buildTestApp(
            home: EventDetailWidget(
              eventId: 'event-123',
              joinCtaState: testCase.state,
              onPrimaryCtaPressed: () => primaryTapCount += 1,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(testCase.label), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);

        final primarySemantics =
            tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
        expect(primarySemantics.flagsCollection.isButton, isTrue);
        expect(primarySemantics.flagsCollection.isEnabled, isFalse);
        expect(primarySemantics.label, contains(testCase.reason));

        await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
        await tester.pumpAndSettle();

        expect(primaryTapCount, 0);
      } finally {
        semanticsHandle.dispose();
      }
    }
  });

  testWidgets('full canceled and past CTA states show English labels',
      (tester) async {
    final cases =
        <({EventDetailJoinCtaState state, String label, String reason})>[
      (
        state: EventDetailJoinCtaState.full,
        label: 'Full',
        reason: 'Event is full',
      ),
      (
        state: EventDetailJoinCtaState.canceled,
        label: 'Canceled',
        reason: 'Event canceled',
      ),
      (
        state: EventDetailJoinCtaState.past,
        label: 'Already started',
        reason: 'Event already started',
      ),
    ];

    for (final testCase in cases) {
      final semanticsHandle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          _buildTestApp(
            locale: const Locale('en'),
            home: EventDetailWidget(
              eventId: 'event-123',
              joinCtaState: testCase.state,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(testCase.label), findsOneWidget);
        final primarySemantics =
            tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
        expect(primarySemantics.flagsCollection.isButton, isTrue);
        expect(primarySemantics.flagsCollection.isEnabled, isFalse);
        expect(primarySemantics.label, contains(testCase.reason));
      } finally {
        semanticsHandle.dispose();
      }
    }
  });

  testWidgets('disabled primary states keep chat callback independent',
      (tester) async {
    var chatTapCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          joinCtaState: EventDetailJoinCtaState.full,
          onChatPressed: () => chatTapCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Мест нет'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);

    await tester.tap(find.byKey(eventDetailChatCtaKey));
    await tester.pumpAndSettle();

    expect(chatTapCount, 1);
  });

  testWidgets('canceled state shows direct-link banner and disabled CTA',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    var primaryTapCount = 0;

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventDetailWidget(
            eventId: 'event-123',
            title: 'Разговорный клуб',
            startsAt: DateTime.utc(2026, 6, 14, 15),
            timeZoneId: 'Europe/Moscow',
            locationName: 'Starbucks, ул. Арбат, 5',
            participantsCount: 5,
            capacity: 10,
            joinCtaState: EventDetailJoinCtaState.canceled,
            onPrimaryCtaPressed: () => primaryTapCount += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(eventDetailCanceledBannerKey), findsOneWidget);
      expect(find.text('Событие отменено'), findsOneWidget);
      expect(
        find.text('Присоединение и новые действия недоступны.'),
        findsOneWidget,
      );
      expect(find.byKey(eventDetailTitleKey), findsOneWidget);
      expect(find.byKey(eventDetailDetailsBlockKey), findsOneWidget);
      expect(find.byKey(eventDetailOccupancyKey), findsOneWidget);

      final bannerSemantics =
          tester.getSemantics(find.byKey(eventDetailCanceledBannerKey));
      expect(bannerSemantics.label, contains('Событие отменено'));
      expect(
        bannerSemantics.label,
        contains('Присоединение и новые действия недоступны.'),
      );

      final primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isButton, isTrue);
      expect(primarySemantics.flagsCollection.isEnabled, isFalse);
      expect(primarySemantics.label, contains('Событие отменено'));

      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pumpAndSettle();

      expect(primaryTapCount, 0);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('canceled banner is hidden for active states', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          joinCtaState: EventDetailJoinCtaState.join,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailCanceledBannerKey), findsNothing);
    expect(find.text('Событие отменено'), findsNothing);
  });

  testWidgets('canceled state shows English banner', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          locale: const Locale('en'),
          home: const EventDetailWidget(
            eventId: 'event-123',
            joinCtaState: EventDetailJoinCtaState.canceled,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(eventDetailCanceledBannerKey), findsOneWidget);
      expect(find.text('Event canceled'), findsOneWidget);
      expect(
        find.text('Joining and new actions are unavailable.'),
        findsOneWidget,
      );
      final bannerSemantics =
          tester.getSemantics(find.byKey(eventDetailCanceledBannerKey));
      expect(bannerSemantics.label, contains('Event canceled'));
      expect(
        bannerSemantics.label,
        contains('Joining and new actions are unavailable.'),
      );
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('canceled state keeps chat callback independent', (tester) async {
    var chatTapCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          joinCtaState: EventDetailJoinCtaState.canceled,
          onChatPressed: () => chatTapCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailCanceledBannerKey), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);

    await tester.tap(find.byKey(eventDetailChatCtaKey));
    await tester.pumpAndSettle();

    expect(chatTapCount, 1);
  });

  testWidgets('bottom action bar stays outside scrollable content',
      (tester) async {
    var joinTapCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailWidget(
          eventId: 'event-123',
          title: 'Разговорный клуб',
          description: List.filled(20, 'Длинное описание события.').join(' '),
          participantsCount: 8,
          capacity: 10,
          participants: const [
            EventDetailParticipantViewModel(displayName: 'Marco Rossi'),
            EventDetailParticipantViewModel(displayName: 'Лиза'),
            EventDetailParticipantViewModel(displayName: 'Kenzhi'),
            EventDetailParticipantViewModel(displayName: 'Alex'),
            EventDetailParticipantViewModel(displayName: 'Olga'),
          ],
          onPrimaryCtaPressed: () => joinTapCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byKey(eventDetailBottomActionBarKey),
      ),
      findsNothing,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailBottomActionBarKey), findsOneWidget);
    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(joinTapCount, 1);
  });

  testWidgets('bottom action bar fits narrow large-text layouts',
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
            joinCtaState: EventDetailJoinCtaState.canceled,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailBottomActionBarKey), findsOneWidget);
    expect(find.byKey(eventDetailCanceledBannerKey), findsOneWidget);
    expect(find.byKey(eventDetailPrimaryCtaKey), findsOneWidget);
    expect(find.byKey(eventDetailChatCtaKey), findsOneWidget);
    expect(find.text('Событие отменено'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('hides organizer controls by default', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          organizerDisplayName: 'Анастасия Иванова',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailOrganizerControlsKey), findsNothing);
    expect(find.byKey(eventDetailOrganizerEditButtonKey), findsNothing);
    expect(find.byKey(eventDetailOrganizerCancelButtonKey), findsNothing);
  });

  testWidgets('organizer controls confirm before cancel callback',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    var editTapCount = 0;
    var cancelTapCount = 0;

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventDetailWidget(
            eventId: 'event-123',
            organizerDisplayName: 'Анастасия Иванова',
            showOrganizerControls: true,
            onOrganizerEditPressed: () => editTapCount += 1,
            onOrganizerCancelPressed: () => cancelTapCount += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(eventDetailOrganizerControlsKey), findsOneWidget);
      expect(find.text('Редактировать'), findsOneWidget);
      expect(find.text('Отменить'), findsOneWidget);

      final editSemantics =
          tester.getSemantics(find.byKey(eventDetailOrganizerEditButtonKey));
      expect(editSemantics.flagsCollection.isButton, isTrue);
      expect(editSemantics.flagsCollection.isEnabled, isTrue);
      expect(editSemantics.label, 'Редактировать событие');

      final cancelSemantics =
          tester.getSemantics(find.byKey(eventDetailOrganizerCancelButtonKey));
      expect(cancelSemantics.flagsCollection.isButton, isTrue);
      expect(cancelSemantics.flagsCollection.isEnabled, isTrue);
      expect(cancelSemantics.label, 'Отменить событие');

      await tester.tap(find.byKey(eventDetailOrganizerEditButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventDetailOrganizerCancelButtonKey));
      await tester.pumpAndSettle();

      expect(editTapCount, 1);
      expect(cancelTapCount, 0);
      expect(find.byKey(eventDetailCancelDialogKey), findsOneWidget);
      expect(find.text('Отменить событие?'), findsOneWidget);
      expect(
        find.text(
          'Участники больше не смогут присоединиться. Событие останется доступно по прямой ссылке.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(eventDetailCancelDialogDismissButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(eventDetailCancelDialogKey), findsNothing);
      expect(cancelTapCount, 0);

      await tester.tap(find.byKey(eventDetailOrganizerCancelButtonKey));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();

      expect(find.byKey(eventDetailCancelDialogKey), findsNothing);
      expect(cancelTapCount, 0);

      await tester.tap(find.byKey(eventDetailOrganizerCancelButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventDetailCancelDialogConfirmButtonKey));
      await tester.pumpAndSettle();

      expect(cancelTapCount, 1);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('organizer controls are disabled without callbacks',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: const EventDetailWidget(
            eventId: 'event-123',
            showOrganizerControls: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(eventDetailOrganizerControlsKey), findsOneWidget);
      expect(find.byKey(eventDetailOrganizerCardKey), findsNothing);

      final editSemantics =
          tester.getSemantics(find.byKey(eventDetailOrganizerEditButtonKey));
      expect(editSemantics.flagsCollection.isButton, isTrue);
      expect(editSemantics.flagsCollection.isEnabled, isFalse);
      expect(editSemantics.label, 'Редактировать событие');

      final cancelSemantics =
          tester.getSemantics(find.byKey(eventDetailOrganizerCancelButtonKey));
      expect(cancelSemantics.flagsCollection.isButton, isTrue);
      expect(cancelSemantics.flagsCollection.isEnabled, isFalse);
      expect(cancelSemantics.label, 'Отменить событие');
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('organizer controls show English labels', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          locale: const Locale('en'),
          home: const EventDetailWidget(
            eventId: 'event-123',
            showOrganizerControls: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      final editSemantics =
          tester.getSemantics(find.byKey(eventDetailOrganizerEditButtonKey));
      expect(editSemantics.label, 'Edit event');

      final cancelSemantics =
          tester.getSemantics(find.byKey(eventDetailOrganizerCancelButtonKey));
      expect(cancelSemantics.label, 'Cancel event');

      await tester.tap(find.byKey(eventDetailOrganizerCancelButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(eventDetailCancelDialogKey), findsNothing);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('cancel confirmation dialog is localized in English',
      (tester) async {
    var cancelTapCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        locale: const Locale('en'),
        home: EventDetailWidget(
          eventId: 'event-123',
          showOrganizerControls: true,
          onOrganizerCancelPressed: () => cancelTapCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailOrganizerCancelButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailCancelDialogKey), findsOneWidget);
    expect(find.text('Cancel event?'), findsOneWidget);
    expect(
      find.text(
        'Participants will no longer be able to join. The event will remain available by direct link.',
      ),
      findsOneWidget,
    );
    expect(find.text('Keep event'), findsOneWidget);
    expect(find.text('Cancel event'), findsOneWidget);
    expect(cancelTapCount, 0);

    await tester.tap(find.byKey(eventDetailCancelDialogConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(cancelTapCount, 1);
  });

  testWidgets('organizer controls do not expose permanent delete actions',
      (tester) async {
    var cancelTapCount = 0;

    for (final joinState in <EventDetailJoinCtaState>[
      EventDetailJoinCtaState.join,
      EventDetailJoinCtaState.canceled,
    ]) {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventDetailWidget(
            eventId: 'event-123',
            showOrganizerControls: true,
            joinCtaState: joinState,
            onOrganizerCancelPressed: () => cancelTapCount += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(eventDetailOrganizerControlsKey), findsOneWidget);
      expect(find.byKey(eventDetailOrganizerEditButtonKey), findsOneWidget);
      expect(find.byKey(eventDetailOrganizerCancelButtonKey), findsOneWidget);
      expect(find.text('Редактировать'), findsOneWidget);
      expect(find.text('Отменить'), findsOneWidget);

      final cancelSemantics =
          tester.getSemantics(find.byKey(eventDetailOrganizerCancelButtonKey));
      expect(cancelSemantics.flagsCollection.isButton, isTrue);
      expect(cancelSemantics.flagsCollection.isEnabled, isTrue);
      await tester.tap(find.byKey(eventDetailOrganizerCancelButtonKey));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(RegExp(r'удал', caseSensitive: false)),
        findsNothing,
      );
      expect(
        find.textContaining(RegExp(r'delete', caseSensitive: false)),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.toLowerCase().contains('delete') ??
                  false),
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.toLowerCase().contains('удал') ??
                  false),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.delete_rounded), findsNothing);
      expect(find.byIcon(Icons.delete_forever), findsNothing);
      expect(find.byIcon(Icons.delete_forever_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_forever_rounded), findsNothing);
      expect(find.byIcon(Icons.delete_sweep), findsNothing);
      expect(find.byIcon(Icons.delete_sweep_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_sweep_rounded), findsNothing);

      await tester.tap(find.byKey(eventDetailCancelDialogDismissButtonKey));
      await tester.pumpAndSettle();
    }

    expect(cancelTapCount, 0);
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
            showOrganizerControls: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailOrganizerCardKey), findsOneWidget);
    expect(find.byKey(eventDetailOrganizerControlsKey), findsOneWidget);
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
            participantsCount: 3,
            capacity: 10,
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
    expect(find.byKey(eventDetailOccupancyKey), findsOneWidget);
    expect(find.byKey(eventDetailParticipantTileKey(0)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows occupancy in participants section header', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: const EventDetailWidget(
            eventId: 'event-123',
            participantsCount: 5,
            capacity: 10,
            participants: [
              EventDetailParticipantViewModel(displayName: 'Marco Rossi'),
              EventDetailParticipantViewModel(displayName: 'Лиза'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(eventDetailParticipantsSectionKey), findsOneWidget);
      expect(find.byKey(eventDetailOccupancyKey), findsOneWidget);
      expect(find.text('5/10 мест'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Заполненность: 5/10 мест')),
        findsOneWidget,
      );
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('shows English occupancy suffix', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          locale: const Locale('en'),
          home: const EventDetailWidget(
            eventId: 'event-123',
            participantsCount: 5,
            capacity: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Participants'), findsOneWidget);
      expect(find.byKey(eventDetailOccupancyKey), findsOneWidget);
      expect(find.text('5/10 spots'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Occupancy: 5/10 spots')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _buildTestApp(
          locale: const Locale('en'),
          home: const EventDetailWidget(
            eventId: 'event-123',
            participantsCount: 1,
            capacity: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5/10 spots'), findsNothing);
      expect(find.text('1/1 spot'), findsOneWidget);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('shows zero occupancy without participant tiles', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          participantsCount: 0,
          capacity: 10,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailParticipantsSectionKey), findsOneWidget);
    expect(find.byKey(eventDetailOccupancyKey), findsOneWidget);
    expect(find.byKey(eventDetailParticipantTileKey(0)), findsNothing);
    expect(find.text('0/10 мест'), findsOneWidget);
  });

  testWidgets('occupancy uses max known participants and does not clamp',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          participantsCount: 1,
          capacity: 2,
          participants: [
            EventDetailParticipantViewModel(displayName: 'Marco Rossi'),
            EventDetailParticipantViewModel(displayName: 'Лиза'),
            EventDetailParticipantViewModel(displayName: 'Kenzhi'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3/2 мест'), findsOneWidget);

    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          participantsCount: 12,
          capacity: 10,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3/2 мест'), findsNothing);
    expect(find.text('12/10 мест'), findsOneWidget);
  });

  testWidgets('occupancy normalizes negative counts', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          participantsCount: -4,
          capacity: 10,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('-4/10 мест'), findsNothing);
    expect(find.text('0/10 мест'), findsOneWidget);
  });

  testWidgets('hides occupancy when capacity is absent or invalid',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          participants: [
            EventDetailParticipantViewModel(displayName: 'Marco Rossi'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailParticipantsSectionKey), findsOneWidget);
    expect(find.byKey(eventDetailOccupancyKey), findsNothing);

    await tester.pumpWidget(
      _buildTestApp(
        home: const EventDetailWidget(
          eventId: 'event-123',
          participantsCount: 1,
          capacity: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailParticipantsSectionKey), findsNothing);
    expect(find.byKey(eventDetailOccupancyKey), findsNothing);
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

  testWidgets('direct detail route can render canceled presentation state',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        MaterialApp.router(
          locale: const Locale('ru'),
          supportedLocales: _supportedLocales,
          localizationsDelegates: _localizationsDelegates,
          routerConfig: GoRouter(
            initialLocation: '/events/event-123',
            routes: [
              GoRoute(
                path: EventDetailWidget.routePath,
                builder: (context, state) => EventDetailWidget(
                  eventId: state.pathParameters['eventId']!,
                  title: 'Разговорный клуб',
                  startsAt: DateTime.utc(2026, 6, 14, 15),
                  timeZoneId: 'Europe/Moscow',
                  locationName: 'Starbucks, ул. Арбат, 5',
                  participantsCount: 5,
                  capacity: 10,
                  joinCtaState: EventDetailJoinCtaState.canceled,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EventDetailWidget), findsOneWidget);
      expect(find.text('event-123'), findsNothing);
      expect(find.byKey(eventDetailCanceledBannerKey), findsOneWidget);
      expect(find.text('Событие отменено'), findsOneWidget);
      expect(find.byKey(eventDetailTitleKey), findsOneWidget);
      expect(find.byKey(eventDetailDetailsBlockKey), findsOneWidget);
      expect(find.byKey(eventDetailOccupancyKey), findsOneWidget);

      final primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isEnabled, isFalse);
      expect(primarySemantics.label, contains('Событие отменено'));
    } finally {
      semanticsHandle.dispose();
    }
  });

  test('event detail stays presentation-only before data binding phase', () {
    final source = File('lib/shared_pages/events/event_detail_widget.dart')
        .readAsStringSync();

    expect(source, isNot(contains('EventDetailRepository')));
    expect(source, isNot(contains('EventActionsRepository')));
    expect(source, isNot(contains('EventEditableFields')));
    expect(source, isNot(contains('watchEventDetail')));
    expect(source, isNot(contains('EventsRecord')));
    expect(source, isNot(contains('openChatThread')));
    expect(source, isNot(contains('ChatThreadWidget')));
    expect(source, isNot(contains('EventGroupChatWidget')));
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
