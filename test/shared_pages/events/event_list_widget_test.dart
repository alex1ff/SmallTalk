import 'dart:io';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/flutter_flow/custom_icons.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
import 'package:small_talk/shared_pages/events/event_create_widget.dart';
import 'package:small_talk/shared_pages/events/event_group_chat_widget.dart';
import 'package:small_talk/shared_pages/events/event_list_widget.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_chip_source.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
import 'package:small_talk/services/event_selected_city_state.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';
import 'package:small_talk/services/event_level_helper.dart';
import 'package:small_talk/services/event_language_catalog.dart';
import 'package:small_talk/services/events_analytics_service.dart';

const _supportedLocales = [
  Locale('ru'),
  Locale('en'),
];

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  FFLocalizationsDelegate(),
  FallbackMaterialLocalizationDelegate(),
  FallbackCupertinoLocalizationDelegate(),
];

Widget _buildTestApp({Widget? home}) {
  return MaterialApp(
    locale: Locale('ru'),
    supportedLocales: _supportedLocales,
    localizationsDelegates: _localizationsDelegates,
    home: home ??
        EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
        ),
  );
}

Widget _buildRouterTestApp(GoRouter router) {
  return MaterialApp.router(
    locale: const Locale('ru'),
    supportedLocales: _supportedLocales,
    localizationsDelegates: _localizationsDelegates,
    routerConfig: router,
  );
}

class _TestFirebaseAuthPlatform extends FirebaseAuthPlatform {
  _TestFirebaseAuthPlatform({FirebaseApp? app}) : super(appInstance: app);

  UserPlatform? _currentUser;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) {
    return _TestFirebaseAuthPlatform(app: app).._currentUser = _currentUser;
  }

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) {
    this.languageCode = languageCode;
    return this;
  }

  @override
  UserPlatform? get currentUser => _currentUser;

  @override
  set currentUser(UserPlatform? userPlatform) {
    _currentUser = userPlatform;
  }

  @override
  String? languageCode;

  @override
  Stream<UserPlatform?> authStateChanges() =>
      const Stream<UserPlatform?>.empty();

  @override
  Stream<UserPlatform?> idTokenChanges() => const Stream<UserPlatform?>.empty();

  @override
  Stream<UserPlatform?> userChanges() => const Stream<UserPlatform?>.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    initializeEventListTimeZones();
    await initializeDateFormatting('ru');
    setupFirebaseCoreMocks();
    await FFLocalizations.initialize();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _TestFirebaseAuthPlatform();
  });

  setUp(() {
    EventsAnalyticsService.defaultTracker = const _NoopEventsAnalyticsTracker();
  });

  tearDown(() {
    EventsAnalyticsService.defaultTracker = EventsAnalyticsService.instance;
    currentUser = null;
    currentUserDocument = null;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the events screen header title', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    final title = find.text('События');

    expect(title, findsOneWidget);

    final titleText = tester.widget<Text>(title);
    expect(titleText.style?.fontSize, 34);
    expect(titleText.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('shows the create event button in the header', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCreateButtonKey), findsOneWidget);
    expect(find.byIcon(Icons.add_sharp), findsOneWidget);
  });

  testWidgets('shows date filter chips with today selected by default',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('Завтра'), findsOneWidget);
    expect(find.text('На этой неделе'), findsOneWidget);
    expect(find.text('В этом месяце'), findsOneWidget);
    expect(_dateFilterChip(tester, EventListDateFilter.today).selected, isTrue);
    expect(_dateFilterChip(tester, EventListDateFilter.tomorrow).selected,
        isFalse);
    expect(_dateFilterChip(tester, EventListDateFilter.currentWeek).selected,
        isFalse);
    expect(_dateFilterChip(tester, EventListDateFilter.currentMonth).selected,
        isFalse);
  });

  testWidgets('changes selected date filter when a date chip is tapped',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(_dateFilterFinder(EventListDateFilter.tomorrow));
    await tester.pumpAndSettle();

    expect(
        _dateFilterChip(tester, EventListDateFilter.today).selected, isFalse);
    expect(
        _dateFilterChip(tester, EventListDateFilter.tomorrow).selected, isTrue);

    await tester.tap(_dateFilterFinder(EventListDateFilter.currentMonth));
    await tester.pumpAndSettle();

    expect(_dateFilterChip(tester, EventListDateFilter.tomorrow).selected,
        isFalse);
    expect(_dateFilterChip(tester, EventListDateFilter.currentMonth).selected,
        isTrue);
  });

  testWidgets('tracks date filter selection only on user changes',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          analyticsTracker: analyticsTracker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(analyticsTracker.payloadsFor('date_filter_selected'), isEmpty);

    await tester.tap(_dateFilterFinder(EventListDateFilter.tomorrow));
    await tester.pumpAndSettle();
    await tester.tap(_dateFilterFinder(EventListDateFilter.currentMonth));
    await tester.pumpAndSettle();
    await tester.tap(_dateFilterFinder(EventListDateFilter.currentMonth));
    await tester.pumpAndSettle();
    await tester.tap(_dateFilterFinder(EventListDateFilter.today));
    await tester.pumpAndSettle();

    expect(analyticsTracker.payloadsFor('date_filter_selected'), [
      <String, String>{'dateFilter': 'tomorrow'},
      <String, String>{'dateFilter': 'current_month'},
      <String, String>{'dateFilter': 'today'},
    ]);
  });

  testWidgets('shows level filter chips with no level selected by default',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Уровень:'), findsOneWidget);
    expect(find.byIcon(Icons.school_outlined), findsOneWidget);
    expect(
      _widgetIndex(
        tester,
        find.text('Уровень:'),
      ),
      greaterThan(
        _widgetIndex(
          tester,
          _dateFilterFinder(EventListDateFilter.currentMonth),
        ),
      ),
    );
    for (final level in eventLevelRanks.keys) {
      expect(find.text(level), findsOneWidget);
      expect(_levelFilterChip(tester, level).selected, isFalse);
    }
  });

  testWidgets('level filter chips select switch and clear one level',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(_levelFilterFinder('B2'));
    await tester.pumpAndSettle();

    expect(_levelFilterChip(tester, 'B2').selected, isTrue);
    expect(_levelFilterChip(tester, 'B1').selected, isFalse);
    expect(_levelFilterChip(tester, 'C1').selected, isFalse);

    await tester.tap(_levelFilterFinder('C1'));
    await tester.pumpAndSettle();

    expect(_levelFilterChip(tester, 'B2').selected, isFalse);
    expect(_levelFilterChip(tester, 'C1').selected, isTrue);

    await tester.tap(_levelFilterFinder('C1'));
    await tester.pumpAndSettle();

    for (final level in eventLevelRanks.keys) {
      expect(_levelFilterChip(tester, level).selected, isFalse);
    }
  });

  testWidgets('tracks level filter selection and clear on user changes',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          analyticsTracker: analyticsTracker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(analyticsTracker.payloadsFor('level_filter_selected'), isEmpty);

    await tester.tap(_levelFilterFinder('B2'));
    await tester.pumpAndSettle();
    await tester.tap(_levelFilterFinder('C1'));
    await tester.pumpAndSettle();
    await tester.tap(_levelFilterFinder('C1'));
    await tester.pumpAndSettle();

    expect(analyticsTracker.payloadsFor('level_filter_selected'), [
      <String, String>{'levelFilter': 'B2'},
      <String, String>{'levelFilter': 'C1'},
      <String, String>{'levelFilter': 'none'},
    ]);
  });

  testWidgets('shows a city selector placeholder below the header',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCitySelectorKey), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.byIcon(FFIcons.kchevronDown), findsOneWidget);
    expect(find.text('Выберите город'), findsOneWidget);
  });

  testWidgets('does not show event card layout before city is selected',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCardShellKey), findsNothing);
    expect(find.byKey(eventListCardHeaderKey), findsNothing);
    expect(find.byKey(eventListCardActionsKey), findsNothing);
  });

  testWidgets('does not show event card layout in missing-city flows',
      (tester) async {
    for (final fixture in <Map<String, dynamic>>[
      const {},
      {
        'Country_NS': {'code': 'RU'},
      },
      {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: 'old-version',
        ).toMap(),
      },
    ]) {
      currentUserDocument = _userFixture(
        uid: 'missing-card-user',
        data: fixture,
      );

      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(cityCatalogOverride: _catalog),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(eventListCardShellKey), findsNothing);
    }
  });

  testWidgets('shows selected city display name without identity',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Москва · Россия'), findsOneWidget);
    expect(find.textContaining('RU:moscow'), findsNothing);
  });

  testWidgets('shows event card layout shell after city is selected',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(eventListCardShellKey);
    expect(card, findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.byKey(eventListCardHeaderKey), findsOneWidget);
    expect(find.byKey(eventListCardBodyKey), findsOneWidget);
    expect(find.byKey(eventListCardMetaKey), findsOneWidget);
    expect(find.byKey(eventListCardFooterKey), findsOneWidget);
    expect(find.byKey(eventListCardActionsKey), findsOneWidget);
    expect(find.byKey(eventListCardChatCtaKey), findsNothing);
    expect(find.text('Чат'), findsNothing);
    expect(
      _widgetIndex(tester, card),
      greaterThan(_widgetIndex(tester, find.byKey(eventListCitySelectorKey))),
    );
  });

  testWidgets('shows explicit loading state after city is selected',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: const [],
          isLoadingEvents: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.byKey(eventListCardShellKey), findsOneWidget);
    expect(find.byKey(eventListCardActionsKey), findsOneWidget);
    expect(find.byKey(eventListCardChatCtaKey), findsNothing);

    final loadingSemantics = tester.widget<Semantics>(
      find.byKey(eventListLoadingStateKey),
    );
    expect(loadingSemantics.properties.label, 'Загружаем события');
    expect(loadingSemantics.properties.liveRegion, isTrue);
    expect(loadingSemantics.container, isTrue);
  });

  testWidgets('does not show loading state before city is selected',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          isLoadingEvents: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(find.byKey(eventListCardShellKey), findsNothing);
  });

  testWidgets('loading state takes priority over provided event cards',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: [_eventCardFixture(title: 'Реальное событие')],
          isLoadingEvents: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.byKey(eventListCardShellKey), findsOneWidget);
    expect(find.text('Реальное событие'), findsNothing);
  });

  testWidgets('shows error state with retry after city is selected',
      (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventListErrorMessage: 'События временно недоступны.',
          onRetryEventsPressed: () => retryCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListErrorStateKey), findsOneWidget);
    expect(find.byKey(eventListErrorRetryButtonKey), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.byKey(eventListCardShellKey), findsNothing);
    expect(find.text('Не удалось загрузить события'), findsOneWidget);
    expect(find.text('События временно недоступны.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    final errorSemantics = tester.widget<Semantics>(
      find.byKey(eventListErrorStateKey),
    );
    expect(
      errorSemantics.properties.label,
      'Не удалось загрузить события. События временно недоступны.',
    );
    expect(errorSemantics.properties.liveRegion, isTrue);
    expect(errorSemantics.container, isTrue);
    expect(errorSemantics.explicitChildNodes, isTrue);

    final retrySemantics = tester.widget<Semantics>(
      find.byKey(eventListErrorRetryButtonKey),
    );
    expect(
      retrySemantics.properties.label,
      'Повторить загрузку событий',
    );
    expect(retrySemantics.container, isTrue);
    expect(retrySemantics.properties.button, isTrue);
    expect(retrySemantics.properties.enabled, isTrue);

    await tester.tap(find.byKey(eventListErrorRetryButtonKey));
    await tester.pumpAndSettle();

    expect(retryCount, 1);
  });

  testWidgets('does not show error state before city is selected',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          eventCardsOverride: const [],
          eventListErrorMessage: 'События временно недоступны.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListErrorStateKey), findsNothing);
    expect(find.byKey(eventListErrorRetryButtonKey), findsNothing);
    expect(find.byKey(eventListCardShellKey), findsNothing);
  });

  testWidgets('loading state takes priority over error state', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: const [],
          isLoadingEvents: true,
          eventListErrorMessage: 'События временно недоступны.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.byKey(eventListErrorStateKey), findsNothing);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
  });

  testWidgets('error state takes priority over empty event cards',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: const [],
          eventListErrorMessage: 'События временно недоступны.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListErrorStateKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.byKey(eventListCardShellKey), findsNothing);
  });

  testWidgets('error state takes priority over provided event cards',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: [_eventCardFixture(title: 'Реальное событие')],
          eventListErrorMessage: 'События временно недоступны.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListErrorStateKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.byKey(eventListCardShellKey), findsNothing);
    expect(find.text('Реальное событие'), findsNothing);
  });

  testWidgets('shows empty state when selected city has no event cards',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(find.byKey(eventListCardShellKey), findsNothing);
    expect(find.text('Пока нет событий'), findsOneWidget);
    expect(
        find.text('Выберите другой день, уровень или город.'), findsOneWidget);

    final emptySemantics = tester.widget<Semantics>(
      find.byKey(eventListEmptyStateKey),
    );
    expect(
      emptySemantics.properties.label,
      'Пока нет событий. Выберите другой день, уровень или город.',
    );
    expect(emptySemantics.properties.liveRegion, isTrue);
    expect(emptySemantics.container, isTrue);
  });

  testWidgets('does not show empty state before city is selected',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          eventCardsOverride: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.byKey(eventListCardShellKey), findsNothing);
  });

  testWidgets('loading state takes priority over empty event cards',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: const [],
          isLoadingEvents: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.byKey(eventListCardShellKey), findsOneWidget);
  });

  testWidgets('hides loading state when event cards are available',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: [_eventCardFixture(title: 'Реальное событие')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.byKey(eventListErrorStateKey), findsNothing);
    expect(find.text('Реальное событие'), findsOneWidget);
    expect(find.byKey(eventListCardPrimaryCtaKey), findsOneWidget);
    expect(find.byKey(eventListCardChatCtaKey), findsOneWidget);
  });

  testWidgets('shows organizer avatar fallback and name in event card header',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(
              organizerDisplayName: 'Анастасия Иванова',
              organizerPhotoUrl: '',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCardOrganizerAvatarKey), findsOneWidget);
    expect(find.byKey(eventListCardOrganizerNameKey), findsOneWidget);
    expect(find.text('Организатор'), findsOneWidget);
    expect(find.text('Анастасия Иванова'), findsOneWidget);
    expect(find.text('АИ'), findsOneWidget);
  });

  testWidgets('organizer avatar handles broken photo url with fallback',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(
              organizerDisplayName: 'Alex',
              organizerPhotoUrl: 'not-a-valid-url',
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(eventListCardOrganizerAvatarKey), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('AL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'shows event card title description level date time and place in event timezone',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'US',
              cityKey: 'new_york',
              cityNameRu: 'Нью-Йорк',
              cityNameEn: 'New York',
              cityDisplayContext: 'United States',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(
              title: 'Разговорный клуб: кофе и английский',
              description:
                  'Неформальная встреча для практики разговорного английского.',
              levelMin: ' b1 ',
              levelMax: ' c1 ',
              startsAt: DateTime.utc(2035, 6, 15, 2, 30),
              timeZoneId: 'America/New_York',
              locationName: 'Starbucks, ул. Арбат, 5',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCardTitleKey), findsOneWidget);
    expect(find.byKey(eventListCardDescriptionKey), findsOneWidget);
    expect(find.byKey(eventListCardLevelRangeKey), findsOneWidget);
    expect(find.byKey(eventListCardDateKey), findsOneWidget);
    expect(find.byKey(eventListCardTimeKey), findsOneWidget);
    expect(find.byKey(eventListCardPlaceKey), findsOneWidget);
    expect(find.text('Разговорный клуб: кофе и английский'), findsOneWidget);
    expect(
      find.text('Неформальная встреча для практики разговорного английского.'),
      findsOneWidget,
    );
    expect(_textInsideKey(eventListCardLevelRangeKey, 'B1-C1'), findsOneWidget);
    expect(_textInsideKey(eventListCardDateKey, '14 июн.'), findsOneWidget);
    expect(_textInsideKey(eventListCardTimeKey, '22:30'), findsOneWidget);
    expect(find.text('Starbucks, ул. Арбат, 5'), findsOneWidget);
  });

  testWidgets('shows same-level event range as a single level', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(
              levelMin: 'B1',
              levelMax: 'B1',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_textInsideKey(eventListCardLevelRangeKey, 'B1'), findsOneWidget);
    expect(_textInsideKey(eventListCardLevelRangeKey, 'B1-B1'), findsNothing);
  });

  testWidgets('shows localized language badge from language code',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(languageCode: ' EN-us '),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCardLanguageBadgeKey), findsOneWidget);
    expect(find.byIcon(Icons.translate), findsOneWidget);
    expect(
      _textInsideKey(eventListCardLanguageBadgeKey, 'Английский'),
      findsOneWidget,
    );
  });

  testWidgets('language badge falls back to denormalized name and raw code',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(
              languageCode: 'unknown',
              languageNameEn: 'Fallback English',
              languageNameRu: 'Фолбэк русский',
            ),
            _eventCardFixture(
              languageCode: ' custom-code ',
              languageNameEn: ' ',
              languageNameRu: null,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _textInsideKey(eventListCardLanguageBadgeKey, 'Фолбэк русский'),
      findsOneWidget,
    );
    expect(
      _textInsideKey(eventListCardLanguageBadgeKey, 'custom-code'),
      findsOneWidget,
    );
  });

  testWidgets('does not render language badge for blank language code',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(
              languageCode: ' ',
              languageNameEn: '',
              languageNameRu: null,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCardLanguageBadgeKey), findsNothing);
    expect(find.byKey(eventListCardDateKey), findsOneWidget);
    expect(find.byKey(eventListCardTimeKey), findsOneWidget);
  });

  testWidgets('shows participant avatar stack with overflow count',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(
              participants: const [
                EventListParticipantViewModel(displayName: 'Marco Rossi'),
                EventListParticipantViewModel(displayName: 'Лиза'),
                EventListParticipantViewModel(displayName: 'Kenzhi'),
                EventListParticipantViewModel(displayName: 'Alex'),
                EventListParticipantViewModel(displayName: 'Olga'),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCardFooterKey), findsOneWidget);
    expect(find.byKey(eventListParticipantAvatarStackKey), findsOneWidget);
    expect(_participantAvatarFinder(0), findsOneWidget);
    expect(_participantAvatarFinder(1), findsOneWidget);
    expect(_participantAvatarFinder(2), findsOneWidget);
    expect(_participantAvatarFinder(3), findsNothing);
    expect(find.byKey(eventListParticipantOverflowKey), findsOneWidget);
    expect(find.text('MR'), findsOneWidget);
    expect(find.text('ЛИ'), findsOneWidget);
    expect(find.text('KE'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('participant avatar handles broken photo url with fallback',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(
              participants: const [
                EventListParticipantViewModel(
                  displayName: 'Broken Photo',
                  photoUrl: 'not-a-valid-url',
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(eventListParticipantAvatarStackKey), findsOneWidget);
    expect(_participantAvatarFinder(0), findsOneWidget);
    expect(find.text('BP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('participant stack uses participants count beyond preview',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(
              participantsCount: 4,
              participants: const [
                EventListParticipantViewModel(displayName: 'Marco Rossi'),
                EventListParticipantViewModel(displayName: 'Лиза'),
                EventListParticipantViewModel(displayName: 'Kenzhi'),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_participantAvatarFinder(0), findsOneWidget);
    expect(_participantAvatarFinder(1), findsOneWidget);
    expect(_participantAvatarFinder(2), findsOneWidget);
    expect(_participantAvatarFinder(3), findsNothing);
    expect(find.byKey(eventListParticipantOverflowKey), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('participant stack shows count-only overflow badge',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(participantsCount: 2),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCardFooterKey), findsOneWidget);
    expect(find.byKey(eventListParticipantAvatarStackKey), findsOneWidget);
    expect(_participantAvatarFinder(0), findsNothing);
    expect(find.byKey(eventListParticipantOverflowKey), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('shows event occupancy beside participant avatars',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(
              participantsCount: 5,
              capacity: 10,
              participants: const [
                EventListParticipantViewModel(displayName: 'Marco Rossi'),
                EventListParticipantViewModel(displayName: 'Лиза'),
                EventListParticipantViewModel(displayName: 'Kenzhi'),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCardFooterKey), findsOneWidget);
    expect(find.byKey(eventListParticipantAvatarStackKey), findsOneWidget);
    expect(find.byKey(eventListCardOccupancyKey), findsOneWidget);
    expect(find.text('5/10 мест'), findsOneWidget);
  });

  testWidgets('shows zero occupancy without empty avatar stack',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(
              participantsCount: 0,
              capacity: 10,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCardFooterKey), findsOneWidget);
    expect(find.byKey(eventListParticipantAvatarStackKey), findsNothing);
    expect(find.byKey(eventListCardOccupancyKey), findsOneWidget);
    expect(find.text('0/10 мест'), findsOneWidget);
  });

  testWidgets('occupancy uses max known participants and does not clamp',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(
              participantsCount: 1,
              capacity: 2,
              participants: const [
                EventListParticipantViewModel(displayName: 'Marco Rossi'),
                EventListParticipantViewModel(displayName: 'Лиза'),
                EventListParticipantViewModel(displayName: 'Kenzhi'),
              ],
            ),
            _eventCardFixture(
              participantsCount: 12,
              capacity: 10,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3/2 мест'), findsOneWidget);
    expect(find.text('12/10 мест'), findsOneWidget);
  });

  testWidgets('hides occupancy when capacity is absent', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(
              participants: const [
                EventListParticipantViewModel(displayName: 'Marco Rossi'),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListParticipantAvatarStackKey), findsOneWidget);
    expect(find.byKey(eventListCardOccupancyKey), findsNothing);
  });

  testWidgets('shows join CTA state as enabled primary action', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(joinCtaState: EventListJoinCtaState.join),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCardPrimaryCtaKey), findsOneWidget);
    expect(find.text('Присоединиться'), findsOneWidget);
    final semantics =
        tester.getSemantics(find.byKey(eventListCardPrimaryCtaKey));
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isEnabled, isTrue);
  });

  testWidgets('shows joined full canceled and past CTA disabled states',
      (tester) async {
    for (final entry in <MapEntry<EventListJoinCtaState, String>>[
      const MapEntry(EventListJoinCtaState.joined, 'Вы участвуете'),
      const MapEntry(EventListJoinCtaState.full, 'Мест нет'),
      const MapEntry(EventListJoinCtaState.canceled, 'Отменено'),
      const MapEntry(EventListJoinCtaState.past, 'Уже началось'),
    ]) {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: EventSelectedCity(
              city: _cityFixture(
                countryCode: 'RU',
                cityKey: 'moscow',
                cityNameRu: 'Москва',
                cityNameEn: 'Moscow',
                cityDisplayContext: 'Россия',
              ),
              source: EventCitySelectionSource.manual,
            ),
            eventCardsOverride: [
              _eventCardFixture(joinCtaState: entry.key),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(eventListCardPrimaryCtaKey), findsOneWidget);
      expect(find.text(entry.value), findsOneWidget);
      final semantics =
          tester.getSemantics(find.byKey(eventListCardPrimaryCtaKey));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isEnabled, isFalse);
    }
  });

  testWidgets('shows enabled chat CTA for participants', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(chatCtaState: EventListChatCtaState.enabled),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCardChatCtaKey), findsOneWidget);
    expect(find.text('Чат'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    final semantics = tester.getSemantics(find.byKey(eventListCardChatCtaKey));
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isEnabled, isTrue);
  });

  testWidgets('shows disabled chat CTA for non-participants by default',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCardChatCtaKey), findsOneWidget);
    expect(find.text('Чат'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    final semantics = tester.getSemantics(find.byKey(eventListCardChatCtaKey));
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isEnabled, isFalse);
    expect(semantics.label, contains('Чат доступен только участникам'));
  });

  testWidgets('opens event chat from participant card CTA', (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    final router = GoRouter(
      initialLocation: EventListWidget.routePath,
      routes: [
        GoRoute(
          name: EventListWidget.routeName,
          path: EventListWidget.routePath,
          builder: (context, state) => EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            analyticsTracker: analyticsTracker,
            eventCardsOverride: [
              _eventCardFixture(
                eventId: 'event-123',
                countryCode: ' ru ',
                cityKey: ' moscow ',
                chatCtaState: EventListChatCtaState.enabled,
              ),
            ],
          ),
        ),
        GoRoute(
          name: EventGroupChatWidget.routeName,
          path: EventGroupChatWidget.routePath,
          builder: (context, state) => EventGroupChatWidget(
            eventId: state.pathParameters['eventId']!,
            messagesStream: (_) =>
                Stream.value(const <EventChatMessagesRecord>[]),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await Scrollable.ensureVisible(
      tester.element(find.byKey(eventListCardChatCtaKey)),
      alignment: 0.5,
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.tap(find.text('Чат'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(router.getCurrentLocation(), '/events/event-123/chat');
    expect(find.byType(EventGroupChatWidget), findsOneWidget);
    expect(find.text('Чат события'), findsOneWidget);
    expect(
      analyticsTracker.payloadsFor(
        EventsAnalyticsService.eventChatOpenedEventName,
      ),
      [
        <String, String>{
          'countryCode': 'RU',
          'cityKey': 'moscow',
          'citySource': 'manual',
        },
      ],
    );
  });

  testWidgets('does not open event chat from non-participant card CTA',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    final router = GoRouter(
      initialLocation: EventListWidget.routePath,
      routes: [
        GoRoute(
          name: EventListWidget.routeName,
          path: EventListWidget.routePath,
          builder: (context, state) => EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            analyticsTracker: analyticsTracker,
            eventCardsOverride: [
              _eventCardFixture(eventId: 'event-123'),
            ],
          ),
        ),
        GoRoute(
          name: EventGroupChatWidget.routeName,
          path: EventGroupChatWidget.routePath,
          builder: (context, state) => EventGroupChatWidget(
            eventId: state.pathParameters['eventId']!,
            messagesStream: (_) =>
                Stream.value(const <EventChatMessagesRecord>[]),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await Scrollable.ensureVisible(
      tester.element(find.byKey(eventListCardChatCtaKey)),
      alignment: 0.5,
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.tap(find.text('Чат'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/events');
    expect(
      find.byKey(eventListChatParticipantRequiredSnackBarKey),
      findsOneWidget,
    );
    expect(find.text('Сначала присоединитесь к событию'), findsOneWidget);
    expect(find.byType(EventListWidget), findsOneWidget);
    expect(find.byType(EventGroupChatWidget), findsNothing);
    expect(
      analyticsTracker.payloadsFor(
        EventsAnalyticsService.eventChatOpenedEventName,
      ),
      isEmpty,
    );
  });

  testWidgets('event list chat analytics failure does not block navigation',
      (tester) async {
    final router = GoRouter(
      initialLocation: EventListWidget.routePath,
      routes: [
        GoRoute(
          name: EventListWidget.routeName,
          path: EventListWidget.routePath,
          builder: (context, state) => EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            analyticsTracker: const _ThrowingEventChatOpenedAnalyticsTracker(),
            eventCardsOverride: [
              _eventCardFixture(
                eventId: 'event-123',
                chatCtaState: EventListChatCtaState.enabled,
              ),
            ],
          ),
        ),
        GoRoute(
          name: EventGroupChatWidget.routeName,
          path: EventGroupChatWidget.routePath,
          builder: (context, state) => EventGroupChatWidget(
            eventId: state.pathParameters['eventId']!,
            messagesStream: (_) =>
                Stream.value(const <EventChatMessagesRecord>[]),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await Scrollable.ensureVisible(
      tester.element(find.byKey(eventListCardChatCtaKey)),
      alignment: 0.5,
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.tap(find.text('Чат'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(router.getCurrentLocation(), '/events/event-123/chat');
    expect(find.byType(EventGroupChatWidget), findsOneWidget);
  });

  testWidgets('hides participant avatar stack for empty participants',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListParticipantAvatarStackKey), findsNothing);
    expect(find.byKey(eventListParticipantOverflowKey), findsNothing);
    expect(find.byKey(eventListCardActionsKey), findsOneWidget);
  });

  testWidgets('shows resolved profile city as the default selector value',
      (tester) async {
    currentUserDocument = _userFixture(
      uid: 'profile-city-user',
      data: {
        'Country_NS': {'code': 'US'},
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(cityCatalogOverride: _catalog),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Москва · Россия'), findsOneWidget);
    expect(find.textContaining('Stored city'), findsNothing);
    expect(find.textContaining('Stored context'), findsNothing);
    expect(find.text('Выберите город'), findsNothing);
    expect(find.text('Выберите город, чтобы увидеть события.'), findsNothing);
    expect(find.byKey(const ValueKey<String>('event_city_chip_RU_moscow')),
        findsNothing);
  });

  testWidgets('tracks event list opened once for resolved profile city',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    currentUserDocument = _userFixture(
      uid: 'profile-city-analytics-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          analyticsTracker: analyticsTracker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(analyticsTracker.payloadsFor('event_list_opened'), [
      <String, String>{
        'countryCode': 'RU',
        'cityKey': 'moscow',
        'citySource': 'profile',
      },
    ]);
    expect(analyticsTracker.payloadsFor('city_selected'), [
      <String, String>{
        'countryCode': 'RU',
        'cityKey': 'moscow',
        'citySource': 'profile',
      },
    ]);

    await tester.tap(_dateFilterFinder(EventListDateFilter.tomorrow));
    await tester.pumpAndSettle();

    expect(analyticsTracker.payloadsFor('event_list_opened'), hasLength(1));
    expect(analyticsTracker.payloadsFor('city_selected'), hasLength(1));
  });

  testWidgets('does not select a city from country-only profile data',
      (tester) async {
    currentUserDocument = _userFixture(
      uid: 'country-only-user',
      data: {
        'Country_NS': {'code': 'RU'},
      },
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(cityCatalogOverride: _catalog),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Выберите город'), findsOneWidget);
    expect(find.text('Выберите город, чтобы увидеть события.'), findsOneWidget);
    expect(find.text('Выберите город заново'), findsNothing);
    expect(find.textContaining('Сохранённый город больше недоступен'),
        findsNothing);
    expect(_citySelectorText('Москва · Россия'), findsNothing);
  });

  testWidgets('does not track event list opened before city is selected',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    currentUserDocument = _userFixture(
      uid: 'missing-profile-city-analytics-user',
      data: {},
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          analyticsTracker: analyticsTracker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(analyticsTracker.events, isEmpty);
  });

  testWidgets(
      'shows location prompt when profile city is missing without country hint',
      (tester) async {
    currentUserDocument = _userFixture(
      uid: 'missing-profile-city-user',
      data: {},
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(cityCatalogOverride: _catalog),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCitySelectorKey), findsOneWidget);
    expect(find.text('Выберите город'), findsOneWidget);
    expect(find.text('Выберите город, чтобы увидеть события.'), findsOneWidget);
    expect(find.text('Выберите город заново'), findsNothing);
    expect(find.textContaining('Сохранённый город больше недоступен'),
        findsNothing);
    expect(_citySelectorText('Москва · Россия'), findsNothing);
  });

  testWidgets(
      'shows missing-location city chips with recent before country-hinted static cities',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      eventRecentCitySelectionsPrefsKey: const <String>[
        '{"countryCode":"IT","cityKey":"rome"}',
      ],
    });
    currentUserDocument = _userFixture(
      uid: 'missing-city-chips-user',
      data: {
        'Country_NS': {'code': 'US'},
      },
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(cityCatalogOverride: _catalog),
      ),
    );
    await tester.pumpAndSettle();

    final rome = find.byKey(const ValueKey<String>('event_city_chip_IT_rome'));
    final newYork =
        find.byKey(const ValueKey<String>('event_city_chip_US_new_york'));
    final moscow =
        find.byKey(const ValueKey<String>('event_city_chip_RU_moscow'));

    expect(find.text('Выберите город'), findsOneWidget);
    expect(find.text('Выберите город, чтобы увидеть события.'), findsOneWidget);
    expect(rome, findsOneWidget);
    expect(newYork, findsOneWidget);
    expect(moscow, findsOneWidget);
    expect(_widgetIndex(tester, rome), lessThan(_widgetIndex(tester, newYork)));
    expect(
      _widgetIndex(tester, newYork),
      lessThan(_widgetIndex(tester, moscow)),
    );
    expect(find.text('recent'), findsNothing);
    expect(find.text('static'), findsNothing);
  });

  testWidgets(
      'chip city selection unlocks events city state without profile save',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      eventRecentCitySelectionsPrefsKey: const <String>[
        '{"countryCode":"IT","cityKey":"rome"}',
      ],
    });
    currentUserDocument = _userFixture(
      uid: 'chip-selection-user',
      data: {},
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(cityCatalogOverride: _catalog),
      ),
    );
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey<String>('event_city_chip_IT_rome')));
    await tester.pumpAndSettle();

    expect(_citySelectorText('Рим · Italy'), findsOneWidget);
    expect(find.text('Выберите город, чтобы увидеть события.'), findsNothing);
    expect(find.byKey(const ValueKey<String>('event_city_chip_IT_rome')),
        findsNothing);
    expect(find.byKey(eventListCardShellKey), findsOneWidget);
    expect(currentUserDocument!.hasProfileCity(), isFalse);
  });

  testWidgets('tracks analytics after recent city chip selection',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    SharedPreferences.setMockInitialValues({
      eventRecentCitySelectionsPrefsKey: const <String>[
        '{"countryCode":"IT","cityKey":"rome"}',
      ],
    });
    currentUserDocument = _userFixture(
      uid: 'chip-selection-analytics-user',
      data: {},
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          analyticsTracker: analyticsTracker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(analyticsTracker.events, isEmpty);

    await tester
        .tap(find.byKey(const ValueKey<String>('event_city_chip_IT_rome')));
    await tester.pumpAndSettle();

    expect(analyticsTracker.payloadsFor('city_selected'), [
      <String, String>{
        'countryCode': 'IT',
        'cityKey': 'rome',
        'citySource': 'recent',
      },
    ]);
    expect(analyticsTracker.payloadsFor('event_list_opened'), [
      <String, String>{
        'countryCode': 'IT',
        'cityKey': 'rome',
        'citySource': 'recent',
      },
    ]);
  });

  testWidgets('tracks city selected from static city chip', (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    SharedPreferences.setMockInitialValues({});
    currentUserDocument = _userFixture(
      uid: 'static-chip-analytics-user',
      data: {},
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          analyticsTracker: analyticsTracker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey<String>('event_city_chip_RU_moscow')));
    await tester.pumpAndSettle();

    expect(analyticsTracker.payloadsFor('city_selected'), [
      <String, String>{
        'countryCode': 'RU',
        'cityKey': 'moscow',
        'citySource': 'static',
      },
    ]);
  });

  testWidgets(
      'opens manual city picker from selector without injected callback',
      (tester) async {
    final fullCatalog = EventCityCatalog.fromJsonString(
      File(eventCityCatalogAssetPath).readAsStringSync(),
    );
    currentUserDocument = _userFixture(
      uid: 'manual-city-picker-user',
      data: {},
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(cityCatalogOverride: fullCatalog),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('event_city_chip_GE_tbilisi')),
        findsNothing);

    await tester.tap(find.byKey(eventListCitySelectorKey));
    await tester.pumpAndSettle();

    final searchField =
        find.byKey(const ValueKey<String>('event_manual_city_search_field'));
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'Тбилиси');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('event_manual_city_option_GE_tbilisi')),
      findsOneWidget,
    );
    expect(find.text('Тбилиси · საქართველო'), findsOneWidget);
    expect(_citySelectorText('Тбилиси · საქართველო'), findsNothing);
  });

  testWidgets(
      'manual city selection unlocks events city state without profile save',
      (tester) async {
    currentUserDocument = _userFixture(
      uid: 'manual-selection-user',
      data: {},
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(cityCatalogOverride: _catalog),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventListCitySelectorKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
          const ValueKey<String>('event_manual_city_option_US_new_york')),
    );
    await tester.pumpAndSettle();

    expect(_citySelectorText('Нью-Йорк · United States'), findsOneWidget);
    expect(find.byKey(eventManualCitySearchFieldKey), findsNothing);
    expect(find.text('Выберите город, чтобы увидеть события.'), findsNothing);
    expect(find.byKey(eventListCardShellKey), findsOneWidget);
    expect(currentUserDocument!.hasProfileCity(), isFalse);
  });

  testWidgets('tracks city selected from manual picker as manual source',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    currentUserDocument = _userFixture(
      uid: 'manual-selection-analytics-user',
      data: {},
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          analyticsTracker: analyticsTracker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventListCitySelectorKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
          const ValueKey<String>('event_manual_city_option_US_new_york')),
    );
    await tester.pumpAndSettle();

    expect(analyticsTracker.payloadsFor('city_selected'), [
      <String, String>{
        'countryCode': 'US',
        'cityKey': 'new_york',
        'citySource': 'manual',
      },
    ]);
  });

  testWidgets('event card layout shell stays bounded on a narrow viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
          eventCardsOverride: [
            _eventCardFixture(
              organizerDisplayName: 'Анастасия Иванова',
              organizerPhotoUrl: '',
              title:
                  'Очень длинное название встречи для проверки карточки на узком экране',
              description:
                  'Длинное описание события должно оставаться внутри карточки и не ломать раскладку.',
              languageCode: 'unknown',
              languageNameRu:
                  'Очень длинное название языка для проверки переноса бейджа',
              locationName:
                  'Очень длинный адрес, который должен корректно переноситься',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCardShellKey), findsOneWidget);
    expect(find.text('Анастасия Иванова'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaves stale malformed and unknown profile cities unselected',
      (tester) async {
    for (final fixture in <Map<String, dynamic>>[
      {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: 'old-version',
        ).toMap(),
        'Country_NS': {'code': 'RU'},
      },
      {
        'profileCity': _profileCityFixture(
          countryCode: 'Russia',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
      {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'unknown_city',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    ]) {
      currentUserDocument = _userFixture(
        uid: 'unresolved-profile-city-user',
        data: fixture,
      );

      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(cityCatalogOverride: _catalog),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Выберите город заново'), findsOneWidget);
      expect(
        find.text(
          'Сохранённый город больше недоступен. Выберите актуальный город, чтобы увидеть события.',
        ),
        findsOneWidget,
      );
      expect(find.text('Выберите город'), findsNothing);
      expect(_citySelectorText('Москва · Россия'), findsNothing);
      expect(find.byKey(const ValueKey<String>('event_city_chip_RU_moscow')),
          findsNothing);
    }
  });

  testWidgets('keeps explicit selected city ahead of profile default',
      (tester) async {
    currentUserDocument = _userFixture(
      uid: 'profile-city-override-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'US',
              cityKey: 'new_york',
              cityNameRu: 'Нью-Йорк',
              cityNameEn: 'New York',
              cityDisplayContext: 'United States',
            ),
            source: EventCitySelectionSource.manual,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Нью-Йорк · United States'), findsOneWidget);
    expect(find.text('Москва · Россия'), findsNothing);
    expect(find.text('Выберите город, чтобы увидеть события.'), findsNothing);
    expect(find.byKey(const ValueKey<String>('event_city_chip_RU_moscow')),
        findsNothing);
  });

  testWidgets('city selector delegates taps when a callback is provided',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          onCitySelectorPressed: () => taps += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventListCitySelectorKey));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(find.byKey(eventManualCitySearchFieldKey), findsNothing);
  });

  testWidgets('opens event create as a pushed screen from the header',
      (tester) async {
    final router = GoRouter(
      initialLocation: EventListWidget.routePath,
      routes: [
        GoRoute(
          name: EventListWidget.routeName,
          path: EventListWidget.routePath,
          builder: (context, state) =>
              const EventListWidget(cityCatalogOverride: _catalog),
        ),
        GoRoute(
          name: EventCreateWidget.routeName,
          path: EventCreateWidget.routePath,
          builder: (context, state) => const EventCreateWidget(),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventListCreateButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/events/create');
    expect(find.byType(EventCreateWidget), findsOneWidget);

    await tester.tap(find.byIcon(FFIcons.kchevronLeft));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/events');
    expect(find.byType(EventListWidget), findsOneWidget);
  });

  test('event list city selector state avoids loading event data early', () {
    final source = File('lib/shared_pages/events/event_list_widget.dart')
        .readAsStringSync();

    expect(source, isNot(contains('EventListRepository')));
    expect(source, isNot(contains('EventsRecord')));
    expect(source, isNot(contains('ProfileCitySaveService')));
    expect(source, isNot(contains('queryEventsRecord')));
  });
}

const _catalog = EventCityCatalog(
  catalogVersion: 'test-catalog',
  cities: [
    EventCity(
      countryCode: 'RU',
      cityKey: 'moscow',
      cityNameRu: 'Москва',
      cityNameEn: 'Moscow',
      regionCode: null,
      regionNameRu: null,
      regionNameEn: null,
      timeZoneId: 'Europe/Moscow',
      cityDisplayContext: 'Россия',
      aliases: [],
      transliterations: [],
      priority: 100,
    ),
    EventCity(
      countryCode: 'US',
      cityKey: 'new_york',
      cityNameRu: 'Нью-Йорк',
      cityNameEn: 'New York',
      regionCode: 'NY',
      regionNameRu: 'Нью-Йорк',
      regionNameEn: 'New York',
      timeZoneId: 'America/New_York',
      cityDisplayContext: 'United States',
      aliases: [],
      transliterations: [],
      priority: 90,
    ),
    EventCity(
      countryCode: 'IT',
      cityKey: 'rome',
      cityNameRu: 'Рим',
      cityNameEn: 'Rome',
      regionCode: null,
      regionNameRu: null,
      regionNameEn: null,
      timeZoneId: 'Europe/Rome',
      cityDisplayContext: 'Italy',
      aliases: [],
      transliterations: [],
      priority: 95,
    ),
  ],
);

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

int _widgetIndex(WidgetTester tester, Finder finder) {
  final element = tester.element(finder);
  return tester.allElements.toList(growable: false).indexOf(element);
}

Finder _citySelectorText(String text) => find.descendant(
      of: find.byKey(eventListCitySelectorKey),
      matching: find.text(text),
    );

Finder _textInsideKey(ValueKey<String> key, String text) => find.descendant(
      of: find.byKey(key),
      matching: find.text(text),
    );

Finder _dateFilterFinder(EventListDateFilter filter) =>
    find.byKey(ValueKey<String>('event_date_filter_${filter.name}'));

ChoiceChip _dateFilterChip(
  WidgetTester tester,
  EventListDateFilter filter,
) =>
    tester.widget<ChoiceChip>(_dateFilterFinder(filter));

Finder _levelFilterFinder(String level) =>
    find.byKey(ValueKey<String>('event_level_filter_$level'));

ChoiceChip _levelFilterChip(
  WidgetTester tester,
  String level,
) =>
    tester.widget<ChoiceChip>(_levelFilterFinder(level));

Finder _participantAvatarFinder(int index) =>
    find.byKey(ValueKey<String>('event_list_participant_avatar_$index'));

EventSelectedCity _selectedCityFixture() {
  return EventSelectedCity(
    city: _cityFixture(
      countryCode: 'RU',
      cityKey: 'moscow',
      cityNameRu: 'Москва',
      cityNameEn: 'Moscow',
      cityDisplayContext: 'Россия',
    ),
    source: EventCitySelectionSource.manual,
  );
}

EventListCardViewModel _eventCardFixture({
  String eventId = 'event-1',
  String countryCode = 'RU',
  String cityKey = 'moscow',
  String organizerDisplayName = 'Анастасия Иванова',
  String? organizerPhotoUrl = '',
  String languageCode = 'en',
  String? languageNameEn,
  String? languageNameRu,
  String title = 'Разговорный клуб: кофе и английский',
  String description =
      'Неформальная встреча для практики разговорного английского.',
  String levelMin = 'B1',
  String levelMax = 'C1',
  DateTime? startsAt,
  String timeZoneId = 'Europe/Moscow',
  String locationName = 'Starbucks, ул. Арбат, 5',
  List<EventListParticipantViewModel> participants =
      const <EventListParticipantViewModel>[],
  int? participantsCount,
  int? capacity,
  EventListJoinCtaState joinCtaState = EventListJoinCtaState.join,
  EventListChatCtaState chatCtaState = EventListChatCtaState.participantOnly,
}) {
  return EventListCardViewModel(
    eventId: eventId,
    countryCode: countryCode,
    cityKey: cityKey,
    organizerDisplayName: organizerDisplayName,
    organizerPhotoUrl: organizerPhotoUrl,
    participants: participants,
    participantsCount: participantsCount,
    capacity: capacity,
    joinCtaState: joinCtaState,
    chatCtaState: chatCtaState,
    languageCode: languageCode,
    languageNameEn: languageNameEn,
    languageNameRu: languageNameRu,
    title: title,
    description: description,
    levelMin: levelMin,
    levelMax: levelMax,
    startsAt: startsAt ?? DateTime.utc(2035, 6, 14, 15),
    timeZoneId: timeZoneId,
    locationName: locationName,
  );
}

EventCity _cityFixture({
  required String countryCode,
  required String cityKey,
  required String cityNameRu,
  required String cityNameEn,
  required String cityDisplayContext,
}) {
  return EventCity(
    countryCode: countryCode,
    cityKey: cityKey,
    cityNameRu: cityNameRu,
    cityNameEn: cityNameEn,
    regionCode: null,
    regionNameRu: null,
    regionNameEn: null,
    timeZoneId: 'Europe/Moscow',
    cityDisplayContext: cityDisplayContext,
    aliases: const [],
    transliterations: const [],
    priority: 100,
  );
}

ProfileCityStruct _profileCityFixture({
  required String countryCode,
  required String cityKey,
  required String catalogVersion,
}) {
  return ProfileCityStruct(
    countryCode: countryCode,
    cityKey: cityKey,
    cityNameRu: 'Stored city',
    cityNameEn: 'Stored city',
    cityDisplayContext: 'Stored context',
    catalogVersion: catalogVersion,
  );
}

UsersRecord _userFixture({
  required String uid,
  required Map<String, dynamic> data,
}) {
  return UsersRecord.getDocumentFromData(
    {
      'uid': uid,
      ...data,
    },
    UsersRecord.collection.doc(uid),
  );
}

class _RecordingEventsAnalyticsTracker implements EventsAnalyticsTracker {
  final List<_RecordedAnalyticsEvent> events = <_RecordedAnalyticsEvent>[];

  List<Map<String, String>> payloadsFor(String name) => events
      .where((event) => event.name == name)
      .map((event) => event.payload)
      .toList(growable: false);

  @override
  Future<void> trackEventListOpened(EventSelectedCity selectedCity) async {
    events.add(
      _RecordedAnalyticsEvent(
        name: EventsAnalyticsService.eventListOpenedEventName,
        payload: selectedCity.analyticsPayload,
      ),
    );
  }

  @override
  Future<void> trackCitySelected(EventSelectedCity selectedCity) async {
    events.add(
      _RecordedAnalyticsEvent(
        name: EventsAnalyticsService.citySelectedEventName,
        payload: selectedCity.analyticsPayload,
      ),
    );
  }

  @override
  Future<void> trackDateFilterSelected(EventListDateFilter dateFilter) async {
    events.add(
      _RecordedAnalyticsEvent(
        name: EventsAnalyticsService.dateFilterSelectedEventName,
        payload: <String, String>{
          'dateFilter': dateFilter.analyticsValue,
        },
      ),
    );
  }

  @override
  Future<void> trackLevelFilterSelected(String? selectedLevel) async {
    events.add(
      _RecordedAnalyticsEvent(
        name: EventsAnalyticsService.levelFilterSelectedEventName,
        payload: <String, String>{
          'levelFilter': eventLevelFilterAnalyticsValue(selectedLevel),
        },
      ),
    );
  }

  @override
  Future<void> trackEventDetailOpened(
    EventsRecord event, {
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventCreated({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventEdited({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventJoined(
    EventsRecord event, {
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventLeft(
    EventsRecord event, {
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventChatOpened({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) async {
    final payload = eventCityAnalyticsPayload(
      countryCode: countryCode,
      cityKey: cityKey,
      citySource: citySource,
    );
    if (payload == null) {
      return;
    }
    events.add(
      _RecordedAnalyticsEvent(
        name: EventsAnalyticsService.eventChatOpenedEventName,
        payload: payload.cast<String, String>(),
      ),
    );
  }

  @override
  Future<void> trackEventCanceled(
    EventsRecord event, {
    String? citySource,
  }) async {}
}

class _NoopEventsAnalyticsTracker implements EventsAnalyticsTracker {
  const _NoopEventsAnalyticsTracker();

  @override
  Future<void> trackEventListOpened(EventSelectedCity selectedCity) async {}

  @override
  Future<void> trackCitySelected(EventSelectedCity selectedCity) async {}

  @override
  Future<void> trackDateFilterSelected(EventListDateFilter dateFilter) async {}

  @override
  Future<void> trackLevelFilterSelected(String? selectedLevel) async {}

  @override
  Future<void> trackEventDetailOpened(
    EventsRecord event, {
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventCreated({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventEdited({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventJoined(
    EventsRecord event, {
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventLeft(
    EventsRecord event, {
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventChatOpened({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventCanceled(
    EventsRecord event, {
    String? citySource,
  }) async {}
}

class _ThrowingEventChatOpenedAnalyticsTracker
    extends _NoopEventsAnalyticsTracker {
  const _ThrowingEventChatOpenedAnalyticsTracker();

  @override
  Future<void> trackEventChatOpened({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) {
    throw StateError('analytics failed');
  }
}

class _RecordedAnalyticsEvent {
  const _RecordedAnalyticsEvent({
    required this.name,
    required this.payload,
  });

  final String name;
  final Map<String, String> payload;
}
