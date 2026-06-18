import 'dart:io';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/flutter_flow/custom_icons.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/events/event_create_widget.dart';
import 'package:small_talk/shared_pages/events/event_list_widget.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
import 'package:small_talk/services/event_selected_city_state.dart';

const _supportedLocales = [
  Locale('ru'),
  Locale('en'),
];

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  FFLocalizationsDelegate(),
  FallbackMaterialLocalizationDelegate(),
  FallbackCupertinoLocalizationDelegate(),
];

Widget _buildTestApp({Widget home = const EventListWidget()}) {
  return MaterialApp(
    locale: Locale('ru'),
    supportedLocales: _supportedLocales,
    localizationsDelegates: _localizationsDelegates,
    home: home,
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
  });

  testWidgets('shows the events screen header title', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    final title = find.text('События');

    expect(title, findsOneWidget);

    final titleText = tester.widget<Text>(title);
    expect(titleText.style?.fontSize, 34);
    expect(titleText.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('shows the create event button in the header', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    expect(find.byKey(eventListCreateButtonKey), findsOneWidget);
    expect(find.byIcon(Icons.add_sharp), findsOneWidget);
  });

  testWidgets('shows a city selector placeholder below the header',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());

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

    expect(find.text('Москва · Россия'), findsOneWidget);
    expect(find.textContaining('RU:moscow'), findsNothing);
  });

  testWidgets('shows resolved profile city as the default selector value',
      (tester) async {
    currentUserDocument = _userFixture(
      uid: 'profile-city-user',
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
        home: EventListWidget(cityCatalogOverride: _catalog),
      ),
    );
    await tester.pump();

    expect(find.text('Москва · Россия'), findsOneWidget);
    expect(find.textContaining('Stored city'), findsNothing);
    expect(find.textContaining('Stored context'), findsNothing);
    expect(find.text('Выберите город'), findsNothing);
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
    await tester.pump();

    expect(find.text('Выберите город'), findsOneWidget);
    expect(find.text('Москва · Россия'), findsNothing);
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
      await tester.pump();

      expect(find.text('Выберите город'), findsOneWidget);
      expect(find.text('Москва · Россия'), findsNothing);
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
    await tester.pump();

    expect(find.text('Нью-Йорк · United States'), findsOneWidget);
    expect(find.text('Москва · Россия'), findsNothing);
  });

  testWidgets('city selector delegates taps when a callback is provided',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          onCitySelectorPressed: () => taps += 1,
        ),
      ),
    );

    await tester.tap(find.byKey(eventListCitySelectorKey));

    expect(taps, 1);
  });

  testWidgets('opens event create as a pushed screen from the header',
      (tester) async {
    final router = GoRouter(
      initialLocation: EventListWidget.routePath,
      routes: [
        GoRoute(
          name: EventListWidget.routeName,
          path: EventListWidget.routePath,
          builder: (context, state) => const EventListWidget(),
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

    expect(router.routeInformationProvider.value.uri.path, '/events/create');
    expect(find.byType(EventCreateWidget), findsOneWidget);

    await tester.tap(find.byIcon(FFIcons.kchevronLeft));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/events');
    expect(find.byType(EventListWidget), findsOneWidget);
  });

  test('event list city selector state avoids loading event data early', () {
    final source = File('lib/shared_pages/events/event_list_widget.dart')
        .readAsStringSync();

    expect(source, isNot(contains('EventListRepository')));
    expect(source, isNot(contains('EventsRecord')));
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
  ],
);

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
