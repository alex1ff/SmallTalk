import 'dart:io';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/flutter_flow/custom_icons.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
import 'package:small_talk/shared_pages/events/event_create_widget.dart';
import 'package:small_talk/shared_pages/events/event_list_widget.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_chip_source.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
import 'package:small_talk/services/event_selected_city_state.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';
import 'package:small_talk/services/event_level_helper.dart';

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
    home: home ?? const EventListWidget(cityCatalogOverride: _catalog),
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
    setupFirebaseCoreMocks();
    await FFLocalizations.initialize();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _TestFirebaseAuthPlatform();
  });

  tearDown(() {
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

  testWidgets('shows a city selector placeholder below the header',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCitySelectorKey), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.byIcon(FFIcons.kchevronDown), findsOneWidget);
    expect(find.text('Выберите город'), findsOneWidget);
  });

  testWidgets('shows selected city display name without identity',
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Москва · Россия'), findsOneWidget);
    expect(find.textContaining('RU:moscow'), findsNothing);
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
    expect(currentUserDocument!.hasProfileCity(), isFalse);
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
    expect(currentUserDocument!.hasProfileCity(), isFalse);
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

int _widgetIndex(WidgetTester tester, Finder finder) {
  final element = tester.element(finder);
  return tester.allElements.toList(growable: false).indexOf(element);
}

Finder _citySelectorText(String text) => find.descendant(
      of: find.byKey(eventListCitySelectorKey),
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
