import 'dart:async';
import 'dart:io';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/flutter_flow/custom_icons.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
import 'package:small_talk/shared_pages/events/event_create_widget.dart';
import 'package:small_talk/shared_pages/events/event_detail_widget.dart';
import 'package:small_talk/shared_pages/events/event_group_chat_widget.dart';
import 'package:small_talk/shared_pages/events/event_list_widget.dart';
import 'package:small_talk/shared_pages/design/expatlio_design.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_chip_source.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
import 'package:small_talk/services/event_selected_city_state.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';
import 'package:small_talk/services/event_list_repository.dart';
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

Widget _buildTestApp({
  Widget? home,
  Locale locale = const Locale('ru'),
}) {
  return MaterialApp(
    locale: locale,
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

class _TestAuthUser extends BaseAuthUser {
  _TestAuthUser(this._uid);

  final String _uid;

  @override
  bool get loggedIn => true;

  @override
  bool get emailVerified => true;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(uid: _uid);

  @override
  Future<void> delete() async {}

  @override
  Future<void> updateEmail(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> sendEmailVerification() async {}
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
    debugClearEventListCache();
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
    expect(titleText.style?.fontSize, 18);
    expect(titleText.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('uses the app page background color', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

    expect(scaffold.backgroundColor, ExpatlioDesign.background);
  });

  testWidgets('shows the create event button in the header', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCreateButtonKey), findsOneWidget);
    expect(find.byIcon(Icons.add_sharp), findsOneWidget);
    expect(
      tester.getSize(find.byKey(eventListCreateButtonKey)),
      const Size.square(36),
    );
  });

  testWidgets('shows date filter chips with no date selected by default',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('Завтра'), findsOneWidget);
    expect(find.text('На этой неделе'), findsOneWidget);
    expect(find.text('В этом месяце'), findsOneWidget);
    expect(_isDateFilterSelected(tester, EventListDateFilter.today), isFalse);
    expect(
        _isDateFilterSelected(tester, EventListDateFilter.tomorrow), isFalse);
    expect(_isDateFilterSelected(tester, EventListDateFilter.currentWeek),
        isFalse);
    expect(_isDateFilterSelected(tester, EventListDateFilter.currentMonth),
        isFalse);
    expect(
      _filterChipBackgroundColor(
        tester,
        _dateFilterFinder(EventListDateFilter.today),
      ),
      ExpatlioDesign.card,
    );
  });

  testWidgets('date filter chips select switch and clear one date',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(_dateFilterFinder(EventListDateFilter.tomorrow));
    await tester.pumpAndSettle();

    expect(_isDateFilterSelected(tester, EventListDateFilter.today), isFalse);
    expect(_isDateFilterSelected(tester, EventListDateFilter.tomorrow), isTrue);
    expect(
      _filterChipTextColor(
        tester,
        _dateFilterFinder(EventListDateFilter.tomorrow),
      ),
      Colors.white,
    );
    expect(
      _filterChipBackgroundColor(
        tester,
        _dateFilterFinder(EventListDateFilter.tomorrow),
      ),
      ExpatlioDesign.primary,
    );

    await tester.tap(_dateFilterFinder(EventListDateFilter.currentMonth));
    await tester.pumpAndSettle();

    expect(
        _isDateFilterSelected(tester, EventListDateFilter.tomorrow), isFalse);
    expect(_isDateFilterSelected(tester, EventListDateFilter.currentMonth),
        isTrue);

    await tester.tap(_dateFilterFinder(EventListDateFilter.currentMonth));
    await tester.pumpAndSettle();

    for (final filter in EventListDateFilter.values) {
      expect(_isDateFilterSelected(tester, filter), isFalse);
    }
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
      expect(_isLevelFilterSelected(tester, level), isFalse);
    }
    expect(
      _filterChipBackgroundColor(tester, _levelFilterFinder('A1')),
      ExpatlioDesign.card,
    );
  });

  testWidgets('level filter chips select switch and clear one level',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(_levelFilterFinder('B2'));
    await tester.pumpAndSettle();

    expect(_isLevelFilterSelected(tester, 'B2'), isTrue);
    expect(_isLevelFilterSelected(tester, 'B1'), isFalse);
    expect(_isLevelFilterSelected(tester, 'C1'), isFalse);

    await tester.tap(_levelFilterFinder('C1'));
    await tester.pumpAndSettle();

    expect(_isLevelFilterSelected(tester, 'B2'), isFalse);
    expect(_isLevelFilterSelected(tester, 'C1'), isTrue);

    await tester.tap(_levelFilterFinder('C1'));
    await tester.pumpAndSettle();

    for (final level in eventLevelRanks.keys) {
      expect(_isLevelFilterSelected(tester, level), isFalse);
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
        'Country_NS': {'code': 'NL'},
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
          eventCardsOverride: const [],
          isLoadingEvents: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListCitySelectorKey), findsNothing);
    expect(find.text('Москва · Россия'), findsNothing);
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
          eventCardsOverride: const [],
          isLoadingEvents: true,
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
    expect(find.byKey(eventListCitySelectorKey), findsNothing);
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

  testWidgets('loads event cards from repository when city is resolved',
      (tester) async {
    var calls = 0;
    int? capturedPageSize;
    bool? capturedIsStream;
    Query Function(Query)? capturedQueryBuilder;
    currentUserDocument = _userFixture(
      uid: 'profile-city-loader-user',
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
          languageCatalogOverride: _languageCatalog,
          nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
          eventPageLoader: (
            collection,
            recordBuilder, {
            queryBuilder,
            nextPageMarker,
            required pageSize,
            required isStream,
          }) async {
            calls += 1;
            capturedPageSize = pageSize;
            capturedIsStream = isStream;
            capturedQueryBuilder = queryBuilder;
            return FFFirestorePage<EventsRecord>(
              [
                _eventsRecordFixture(
                  'loaded-event',
                  title: 'Live loaded event',
                  startsAt: DateTime.utc(2035, 6, 14, 15),
                ),
              ],
              null,
              null,
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(capturedPageSize, 20);
    expect(capturedIsStream, isFalse);
    expect(capturedQueryBuilder, isNotNull);
    final delegatedQuery = capturedQueryBuilder!(EventsRecord.collection);
    final where = delegatedQuery.parameters['where'] as List<dynamic>;
    _expectWhereCondition(
        where, 'startsAt', '>=', DateTime.utc(2035, 6, 14, 9));
    _expectWhereCondition(
      where,
      'startsAt',
      '<',
      DateTime.utc(9999, 12, 31),
    );
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.text('Live loaded event'), findsOneWidget);
    expect(find.byKey(eventListCitySelectorKey), findsNothing);
  });

  testWidgets('keeps loaded event cards visible when refresh fails',
      (tester) async {
    var calls = 0;
    currentUserDocument = _userFixture(
      uid: 'profile-city-refresh-error-user',
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
          languageCatalogOverride: _languageCatalog,
          nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
          eventPageLoader: (
            collection,
            recordBuilder, {
            queryBuilder,
            nextPageMarker,
            required pageSize,
            required isStream,
          }) async {
            calls += 1;
            if (calls == 2) {
              throw StateError('network');
            }
            return FFFirestorePage<EventsRecord>(
              [
                _eventsRecordFixture(
                  calls == 1 ? 'loaded-before-refresh' : 'loaded-after-retry',
                  title: calls == 1
                      ? 'Loaded before refresh'
                      : 'Loaded after retry',
                  startsAt: DateTime.utc(2035, 6, 14, 15),
                ),
              ],
              null,
              null,
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Loaded before refresh'), findsOneWidget);

    await tester.tap(_dateFilterFinder(EventListDateFilter.today));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(eventListErrorStateKey), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(find.text('Loaded before refresh'), findsOneWidget);

    await tester.tap(find.byKey(eventListErrorRetryButtonKey));
    await tester.pumpAndSettle();

    expect(calls, 3);
    expect(find.byKey(eventListErrorStateKey), findsNothing);
    expect(find.text('Loaded after retry'), findsOneWidget);
  });

  testWidgets('keeps loaded event cards visible while refresh is pending',
      (tester) async {
    var calls = 0;
    final refreshCompleter = Completer<FFFirestorePage<EventsRecord>>();
    addTearDown(() {
      if (!refreshCompleter.isCompleted) {
        refreshCompleter.complete(FFFirestorePage<EventsRecord>(
          const [],
          null,
          null,
        ));
      }
    });
    currentUserDocument = _userFixture(
      uid: 'profile-city-pending-refresh-user',
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
          languageCatalogOverride: _languageCatalog,
          nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
          eventPageLoader: (
            collection,
            recordBuilder, {
            queryBuilder,
            nextPageMarker,
            required pageSize,
            required isStream,
          }) async {
            calls += 1;
            if (calls == 2) {
              return refreshCompleter.future;
            }
            return FFFirestorePage<EventsRecord>(
              [
                _eventsRecordFixture(
                  calls == 1 ? 'loaded-before-pending' : 'loaded-after-pending',
                  title: calls == 1
                      ? 'Loaded before pending'
                      : 'Loaded after pending',
                  startsAt: DateTime.utc(2035, 6, 14, 15),
                ),
              ],
              null,
              null,
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Loaded before pending'), findsOneWidget);

    await tester.tap(_dateFilterFinder(EventListDateFilter.today));
    await tester.pump();

    expect(calls, 2);
    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.text('Loaded before pending'), findsOneWidget);

    refreshCompleter.complete(FFFirestorePage<EventsRecord>(
      [
        _eventsRecordFixture(
          'loaded-after-pending',
          title: 'Loaded after pending',
          startsAt: DateTime.utc(2035, 6, 14, 15),
        ),
      ],
      null,
      null,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Loaded after pending'), findsOneWidget);
    expect(find.text('Loaded before pending'), findsNothing);
  });

  testWidgets('keeps confirmed empty events visible when refresh fails',
      (tester) async {
    var calls = 0;
    currentUser = _TestAuthUser('events-empty-refresh-error-user');

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
          eventPageLoader: (
            collection,
            recordBuilder, {
            queryBuilder,
            nextPageMarker,
            required pageSize,
            required isStream,
          }) async {
            calls += 1;
            if (calls > 1) {
              throw StateError('network');
            }
            return FFFirestorePage<EventsRecord>(const [], null, null);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);

    await tester.tap(_dateFilterFinder(EventListDateFilter.today));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(eventListErrorStateKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
  });

  testWidgets('reloads real event cards after injected cards are removed',
      (tester) async {
    var calls = 0;
    currentUser = _TestAuthUser('events-source-boundary-user');
    currentUserDocument = _userFixture(
      uid: 'events-source-boundary-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) async {
      calls += 1;
      return FFFirestorePage<EventsRecord>(
        [
          _eventsRecordFixture(
            'source-boundary-event-$calls',
            title: 'Real loaded event $calls',
            startsAt: DateTime.utc(2035, 6, 14, 15),
          ),
        ],
        null,
        null,
      );
    };

    Widget buildList({
      List<EventListCardViewModel>? eventCardsOverride,
    }) =>
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: (_, __) async => null,
            eventCardsOverride: eventCardsOverride,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Real loaded event 1'), findsOneWidget);

    await tester.pumpWidget(
      buildList(
        eventCardsOverride: [
          _eventCardFixture(title: 'Injected event'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Injected event'), findsOneWidget);
    expect(find.text('Real loaded event 1'), findsNothing);

    await tester.pumpWidget(buildList());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Real loaded event 2'), findsOneWidget);
    expect(find.text('Injected event'), findsNothing);
    expect(find.text('Real loaded event 1'), findsNothing);
  });

  testWidgets('reuses cached event cards when page is reopened',
      (tester) async {
    var calls = 0;
    currentUserDocument = _userFixture(
      uid: 'profile-city-cache-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final nowUtc = DateTime.utc(2035, 6, 14, 9);
    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) async {
      calls += 1;
      return FFFirestorePage<EventsRecord>(
        [
          _eventsRecordFixture(
            'cached-event',
            title: 'Cached loaded event',
            startsAt: DateTime.utc(2035, 6, 14, 15),
          ),
        ],
        null,
        null,
      );
    };
    final EventListCurrentUserParticipantLoader currentUserParticipantLoader =
        (_, __) async => null;
    final EventListActiveParticipantsLoader activeParticipantsLoader =
        (_) async => const <EventParticipantsRecord>[];

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => nowUtc,
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: currentUserParticipantLoader,
            activeParticipantsLoader: activeParticipantsLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Cached loaded event'), findsOneWidget);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());

    expect(calls, 1);
    expect(find.text('Cached loaded event'), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
  });

  testWidgets('reuses cached event cards for an authenticated user',
      (tester) async {
    var calls = 0;
    currentUser = _TestAuthUser('authenticated-event-cache-user');
    currentUserDocument = _userFixture(
      uid: 'authenticated-event-cache-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final nowUtc = DateTime.utc(2035, 6, 14, 9);
    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) async {
      calls += 1;
      return FFFirestorePage<EventsRecord>(
        [
          _eventsRecordFixture(
            'authenticated-cached-event',
            title: 'Authenticated cached event',
            startsAt: DateTime.utc(2035, 6, 14, 15),
          ),
        ],
        null,
        null,
      );
    };
    final EventListCurrentUserParticipantLoader currentUserParticipantLoader =
        (_, __) async => null;
    final EventListActiveParticipantsLoader activeParticipantsLoader =
        (_) async => const <EventParticipantsRecord>[];

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => nowUtc,
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: currentUserParticipantLoader,
            activeParticipantsLoader: activeParticipantsLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Authenticated cached event'), findsOneWidget);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());

    expect(calls, 1);
    expect(find.text('Authenticated cached event'), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
  });

  testWidgets('refreshes authenticated event cache after returning from detail',
      (tester) async {
    const joinAndReturnButtonKey = ValueKey<String>('join_and_return');
    var calls = 0;
    var joined = false;
    currentUser = _TestAuthUser('authenticated-detail-return-user');
    final nowUtc = DateTime.utc(2035, 6, 14, 9);
    final secondPageCompleter = Completer<FFFirestorePage<EventsRecord>>();

    EventParticipantsRecord currentParticipant(DocumentReference eventRef) {
      return EventParticipantsRecord.getDocumentFromData(
        createEventParticipantsRecordData(
          userId: 'authenticated-detail-return-user',
          displayName: 'Student',
          status: eventStatusActive,
          joinedAt: DateTime.utc(2035, 6, 14, 10),
        ),
        EventParticipantsRecord.createDoc(
          eventRef,
          id: 'authenticated-detail-return-user',
        ),
      );
    }

    FFFirestorePage<EventsRecord> eventPage() {
      return FFFirestorePage<EventsRecord>(
        [
          _eventsRecordFixture(
            'detail-return-cache-event',
            title: 'Detail return cache event',
            startsAt: DateTime.utc(2035, 6, 14, 15),
          ),
        ],
        null,
        null,
      );
    }

    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) async {
      calls += 1;
      if (calls == 2) {
        return secondPageCompleter.future;
      }
      return eventPage();
    };
    final EventListCurrentUserParticipantLoader currentUserParticipantLoader =
        (eventRef, userId) async {
      return joined ? currentParticipant(eventRef) : null;
    };
    final EventListActiveParticipantsLoader activeParticipantsLoader =
        (eventRef) async {
      return joined
          ? <EventParticipantsRecord>[currentParticipant(eventRef)]
          : const <EventParticipantsRecord>[];
    };

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
            nowUtcProvider: () => nowUtc,
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: currentUserParticipantLoader,
            activeParticipantsLoader: activeParticipantsLoader,
          ),
        ),
        GoRoute(
          name: EventDetailWidget.routeName,
          path: EventDetailWidget.routePath,
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                key: joinAndReturnButtonKey,
                onPressed: () {
                  joined = true;
                  context.pop();
                },
                child: const Text('Join and return'),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Detail return cache event'), findsOneWidget);
    expect(find.text('Присоединиться'), findsOneWidget);

    await tester.tap(find.text('Detail return cache event'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(joinAndReturnButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(calls, 2);
    expect(find.text('Присоединиться'), findsNothing);
    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);

    secondPageCompleter.complete(eventPage());
    await tester.pumpAndSettle();

    expect(find.text('Detail return cache event'), findsOneWidget);
    expect(find.text('Вы участвуете'), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
  });

  testWidgets('uses current cache data when returning to a cached filter',
      (tester) async {
    var calls = 0;
    currentUserDocument = _userFixture(
      uid: 'profile-city-cache-filter-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final nowUtc = DateTime.utc(2035, 6, 14, 9);
    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) async {
      calls += 1;
      return FFFirestorePage<EventsRecord>(
        [
          _eventsRecordFixture(
            'cached-filter-event-$calls',
            title: calls == 1
                ? 'Default cached filter event'
                : 'Today loaded filter event',
            startsAt: DateTime.utc(2035, 6, 14, 15),
          ),
        ],
        null,
        null,
      );
    };
    final EventListCurrentUserParticipantLoader currentUserParticipantLoader =
        (_, __) async => null;
    final EventListActiveParticipantsLoader activeParticipantsLoader =
        (_) async => const <EventParticipantsRecord>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          nowUtcProvider: () => nowUtc,
          eventPageLoader: pageLoader,
          currentUserParticipantLoader: currentUserParticipantLoader,
          activeParticipantsLoader: activeParticipantsLoader,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Default cached filter event'), findsOneWidget);

    await tester.tap(_dateFilterFinder(EventListDateFilter.today));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Today loaded filter event'), findsOneWidget);

    await tester.tap(_dateFilterFinder(EventListDateFilter.today));
    await tester.pump();

    expect(calls, 2);
    expect(find.text('Default cached filter event'), findsOneWidget);
    expect(find.text('Today loaded filter event'), findsNothing);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
  });

  testWidgets('keeps event cache entries separate by level filter',
      (tester) async {
    var calls = 0;
    currentUser = _TestAuthUser('authenticated-level-cache-user');
    currentUserDocument = _userFixture(
      uid: 'authenticated-level-cache-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final nowUtc = DateTime.utc(2035, 6, 14, 9);
    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) async {
      calls += 1;
      return FFFirestorePage<EventsRecord>(
        [
          _eventsRecordFixture(
            'level-cache-event-$calls',
            title: calls == 1
                ? 'Default level cache event'
                : 'B2 level cache event',
            startsAt: DateTime.utc(2035, 6, 14, 15),
          ),
        ],
        null,
        null,
      );
    };
    final EventListCurrentUserParticipantLoader currentUserParticipantLoader =
        (_, __) async => null;
    final EventListActiveParticipantsLoader activeParticipantsLoader =
        (_) async => const <EventParticipantsRecord>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          nowUtcProvider: () => nowUtc,
          eventPageLoader: pageLoader,
          currentUserParticipantLoader: currentUserParticipantLoader,
          activeParticipantsLoader: activeParticipantsLoader,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Default level cache event'), findsOneWidget);

    await tester.tap(_levelFilterFinder('B2'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('B2 level cache event'), findsOneWidget);

    await tester.tap(_levelFilterFinder('B2'));
    await tester.pump();

    expect(calls, 2);
    expect(find.text('Default level cache event'), findsOneWidget);
    expect(find.text('B2 level cache event'), findsNothing);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
  });

  testWidgets('keeps event cache entries separate by city', (tester) async {
    var calls = 0;
    final nowUtc = DateTime.utc(2035, 6, 14, 9);
    final moscowCity = _selectedCityFixture();
    final parisCity = EventSelectedCity(
      city: _cityFixture(
        countryCode: 'FR',
        cityKey: 'paris',
        cityNameRu: 'Париж',
        cityNameEn: 'Paris',
        cityDisplayContext: 'France',
      ),
      source: EventCitySelectionSource.manual,
    );
    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) async {
      calls += 1;
      return FFFirestorePage<EventsRecord>(
        [
          _eventsRecordFixture(
            'city-cache-event-$calls',
            title: calls == 1
                ? 'Moscow cached city event'
                : 'Paris loaded city event',
            startsAt: DateTime.utc(2035, 6, 14, 15),
          ),
        ],
        null,
        null,
      );
    };

    Widget buildList(EventSelectedCity selectedCity) => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: selectedCity,
            nowUtcProvider: () => nowUtc,
            eventPageLoader: pageLoader,
          ),
        );

    await tester.pumpWidget(buildList(moscowCity));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Moscow cached city event'), findsOneWidget);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList(parisCity));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Paris loaded city event'), findsOneWidget);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList(moscowCity));
    await tester.pump();

    expect(calls, 2);
    expect(find.text('Moscow cached city event'), findsOneWidget);
    expect(find.text('Paris loaded city event'), findsNothing);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
  });

  testWidgets('does not cache empty event list for default filters',
      (tester) async {
    var calls = 0;
    currentUserDocument = _userFixture(
      uid: 'profile-city-empty-cache-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final nowUtc = DateTime.utc(2035, 6, 14, 9);
    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) async {
      calls += 1;
      if (calls == 1) {
        return FFFirestorePage<EventsRecord>(const [], null, null);
      }

      return FFFirestorePage<EventsRecord>(
        [
          _eventsRecordFixture(
            'fresh-event',
            title: 'Fresh loaded event',
            startsAt: DateTime.utc(2035, 6, 14, 15),
          ),
        ],
        null,
        null,
      );
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => nowUtc,
            eventPageLoader: pageLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.text('Fresh loaded event'), findsOneWidget);
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

  testWidgets('loading state keeps provided event cards visible',
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
    await tester.pump();

    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.byKey(eventListCardShellKey), findsOneWidget);
    expect(find.text('Реальное событие'), findsOneWidget);
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

  testWidgets('error state stays visible above provided event cards',
      (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: [_eventCardFixture(title: 'Реальное событие')],
          eventListErrorMessage: 'События временно недоступны.',
          onRetryEventsPressed: () => retryCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListErrorStateKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.byKey(eventListCardShellKey), findsOneWidget);
    expect(find.text('Реальное событие'), findsOneWidget);

    await tester.tap(find.byKey(eventListErrorRetryButtonKey));
    await tester.pumpAndSettle();

    expect(retryCount, 1);
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
    expect(find.text('Здесь пока пусто'), findsOneWidget);
    expect(
        find.text('Выберите другой день, уровень или город.'), findsOneWidget);

    final emptySemantics = tester.widget<Semantics>(
      find.byKey(eventListEmptyStateKey),
    );
    expect(
      emptySemantics.properties.label,
      'Выберите другой день, уровень или город.',
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
    expect(find.text('А'), findsOneWidget);
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
    expect(find.text('A'), findsOneWidget);
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

  testWidgets('does not render language badge in event list cards',
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

    expect(find.byKey(eventListCardLanguageBadgeKey), findsNothing);
    expect(find.byIcon(Icons.translate), findsNothing);
    expect(find.byKey(eventListCardDateKey), findsOneWidget);
    expect(find.byKey(eventListCardTimeKey), findsOneWidget);
  });

  testWidgets('language badge stays hidden in English locale', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        locale: const Locale('en'),
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: [
            _eventCardFixture(
              languageCode: ' es-419 ',
              languageNameEn: 'Stale English',
              languageNameRu: 'Stale Russian',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _textInsideKey(eventListCardLanguageBadgeKey, 'Spanish'),
      findsNothing,
    );
    expect(
      _textInsideKey(eventListCardLanguageBadgeKey, 'Stale English'),
      findsNothing,
    );
  });

  testWidgets('language badge fallback text stays hidden', (tester) async {
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
      findsNothing,
    );
    expect(
      _textInsideKey(eventListCardLanguageBadgeKey, 'custom-code'),
      findsNothing,
    );
  });

  testWidgets('event list does not load language catalog for hidden badge',
      (tester) async {
    final bundle = _FailingLanguageAssetBundle();

    await tester.pumpWidget(
      _buildTestApp(
        home: DefaultAssetBundle(
          bundle: bundle,
          child: EventListWidget(
            cityCatalogOverride: _catalog,
            initialSelectedCity: _selectedCityFixture(),
            eventCardsOverride: [
              _eventCardFixture(
                languageCode: ' en-US ',
                languageNameEn: 'Fallback English',
                languageNameRu: 'Фолбэк русский',
              ),
              _eventCardFixture(
                languageCode: ' legacy-code ',
                languageNameEn: '',
                languageNameRu: null,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(bundle.languageCatalogLoadCount, 0);
    expect(
      _textInsideKey(eventListCardLanguageBadgeKey, 'Фолбэк русский'),
      findsNothing,
    );
    expect(
      _textInsideKey(eventListCardLanguageBadgeKey, 'legacy-code'),
      findsNothing,
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
              participantsCount: 9,
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
    expect(_participantAvatarFinder(3), findsOneWidget);
    expect(_participantAvatarFinder(4), findsOneWidget);
    expect(_participantAvatarFinder(5), findsOneWidget);
    expect(find.byKey(eventListParticipantOverflowKey), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('Л'), findsOneWidget);
    expect(find.text('K'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
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
    expect(find.text('B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('participant stack shows count-only participants before overflow',
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
    expect(_participantAvatarFinder(3), findsOneWidget);
    expect(find.byKey(eventListParticipantOverflowKey), findsNothing);
    expect(find.text('+1'), findsNothing);
  });

  testWidgets('participant stack shows count-only slots', (tester) async {
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
    expect(_participantAvatarFinder(0), findsOneWidget);
    expect(_participantAvatarFinder(1), findsOneWidget);
    expect(find.byKey(eventListParticipantOverflowKey), findsNothing);
    expect(find.text('+2'), findsNothing);
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
    for (var index = 0; index < 6; index += 1) {
      expect(_participantAvatarFinder(index), findsOneWidget);
    }
    expect(find.byKey(eventListParticipantOverflowKey), findsOneWidget);
    expect(find.text('+4'), findsOneWidget);
    expect(find.byKey(eventListCardOccupancyKey), findsOneWidget);
    expect(find.text('5/10 мест'), findsOneWidget);
  });

  testWidgets('count-only occupancy stack shows six slots before overflow',
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
              capacity: 10,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var index = 0; index < 6; index += 1) {
      expect(_participantAvatarFinder(index), findsOneWidget);
    }
    expect(find.byKey(eventListParticipantOverflowKey), findsOneWidget);
    expect(find.text('+4'), findsOneWidget);
    expect(find.text('+1'), findsNothing);
    expect(find.text('1/10 мест'), findsOneWidget);
  });

  testWidgets('loaded event uses organizer as first occupied avatar',
      (tester) async {
    currentUserDocument = _userFixture(
      uid: 'organizer-preview-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final nowUtc = DateTime.utc(2035, 6, 14, 9);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          nowUtcProvider: () => nowUtc,
          eventPageLoader: (
            collection,
            recordBuilder, {
            queryBuilder,
            nextPageMarker,
            required pageSize,
            required isStream,
          }) async {
            return FFFirestorePage<EventsRecord>(
              [
                _eventsRecordFixture(
                  'organizer-event',
                  title: 'Organizer preview event',
                  startsAt: DateTime.utc(2035, 6, 14, 15),
                ),
              ],
              null,
              null,
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(eventListParticipantAvatarStackKey), findsOneWidget);
    expect(_participantAvatarFinder(0), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(eventListParticipantAvatarStackKey),
        matching: find.text('А'),
      ),
      findsOneWidget,
    );
    expect(find.text('+4'), findsOneWidget);
    expect(find.text('+1'), findsNothing);
    expect(find.text('1/10 мест'), findsOneWidget);
  });

  testWidgets('loaded event uses active participants preview from records',
      (tester) async {
    currentUserDocument = _userFixture(
      uid: 'participant-preview-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final nowUtc = DateTime.utc(2035, 6, 14, 9);
    var previewLookups = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          nowUtcProvider: () => nowUtc,
          eventPageLoader: (
            collection,
            recordBuilder, {
            queryBuilder,
            nextPageMarker,
            required pageSize,
            required isStream,
          }) async {
            return FFFirestorePage<EventsRecord>(
              [
                _eventsRecordFixture(
                  'participant-preview-event',
                  title: 'Participant preview event',
                  startsAt: DateTime.utc(2035, 6, 14, 15),
                ),
              ],
              null,
              null,
            );
          },
          activeParticipantsLoader: (eventRef) async {
            previewLookups += 1;
            return [
              EventParticipantsRecord.getDocumentFromData(
                createEventParticipantsRecordData(
                  userId: 'organizer-user',
                  displayName: 'Анастасия Иванова',
                  role: 'organizer',
                  status: eventStatusActive,
                  joinedAt: DateTime.utc(2035, 6, 14, 8),
                ),
                EventParticipantsRecord.createDoc(
                  eventRef,
                  id: 'organizer-user',
                ),
              ),
              EventParticipantsRecord.getDocumentFromData(
                createEventParticipantsRecordData(
                  userId: 'student-1',
                  displayName: 'hjk',
                  role: 'participant',
                  status: eventStatusActive,
                  joinedAt: DateTime.utc(2035, 6, 14, 9),
                ),
                EventParticipantsRecord.createDoc(eventRef, id: 'student-1'),
              ),
              EventParticipantsRecord.getDocumentFromData(
                createEventParticipantsRecordData(
                  userId: 'student-2',
                  displayName: 'Участник',
                  role: 'participant',
                  status: eventStatusActive,
                  joinedAt: DateTime.utc(2035, 6, 14, 10),
                ),
                EventParticipantsRecord.createDoc(eventRef, id: 'student-2'),
              ),
            ];
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(previewLookups, 1);
    expect(find.byKey(eventListParticipantAvatarStackKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(eventListParticipantAvatarStackKey),
        matching: find.text('А'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(eventListParticipantAvatarStackKey),
        matching: find.text('H'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _participantAvatarFinder(2),
        matching: find.byIcon(Icons.person_outline),
      ),
      findsOneWidget,
    );
    expect(find.text('У'), findsNothing);
    expect(find.text('+4'), findsOneWidget);
    expect(find.text('1/10 мест'), findsNothing);
  });

  testWidgets(
    'loaded event uses current profile for generic participant preview',
    (tester) async {
      currentUser = _TestAuthUser('student-2');
      currentUserDocument = _userFixture(
        uid: 'student-2',
        data: {
          'display_name': 'Марко Росси',
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      final nowUtc = DateTime.utc(2035, 6, 14, 9);

      EventParticipantsRecord participantRecord(
        DocumentReference eventRef, {
        required String userId,
        required String displayName,
        required DateTime joinedAt,
      }) {
        return EventParticipantsRecord.getDocumentFromData(
          createEventParticipantsRecordData(
            userId: userId,
            displayName: displayName,
            role: 'participant',
            status: eventStatusActive,
            joinedAt: joinedAt,
          ),
          EventParticipantsRecord.createDoc(eventRef, id: userId),
        );
      }

      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => nowUtc,
            eventPageLoader: (
              collection,
              recordBuilder, {
              queryBuilder,
              nextPageMarker,
              required pageSize,
              required isStream,
            }) async {
              return FFFirestorePage<EventsRecord>(
                [
                  _eventsRecordFixture(
                    'current-profile-preview-event',
                    title: 'Current profile preview event',
                    startsAt: DateTime.utc(2035, 6, 14, 15),
                  ),
                ],
                null,
                null,
              );
            },
            currentUserParticipantLoader: (eventRef, userId) async {
              return participantRecord(
                eventRef,
                userId: userId,
                displayName: 'Участник',
                joinedAt: DateTime.utc(2035, 6, 14, 10),
              );
            },
            activeParticipantsLoader: (eventRef) async {
              return [
                participantRecord(
                  eventRef,
                  userId: 'organizer-user',
                  displayName: 'Анастасия Иванова',
                  joinedAt: DateTime.utc(2035, 6, 14, 8),
                ),
                participantRecord(
                  eventRef,
                  userId: 'student-2',
                  displayName: 'Участник',
                  joinedAt: DateTime.utc(2035, 6, 14, 10),
                ),
              ];
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: _participantAvatarFinder(1),
          matching: find.text('М'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _participantAvatarFinder(1),
          matching: find.byIcon(Icons.person_outline),
        ),
        findsNothing,
      );
      expect(find.text('У'), findsNothing);
    },
  );

  testWidgets(
    'loaded joined event appends current user avatar when preview omits it',
    (tester) async {
      currentUser = _TestAuthUser('student-joined-preview');
      currentUserDocument = _userFixture(
        uid: 'student-joined-preview',
        data: {
          'display_name': 'Марко Росси',
          'photo_url': '',
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      final nowUtc = DateTime.utc(2035, 6, 14, 9);

      EventParticipantsRecord participantRecord(
        DocumentReference eventRef, {
        required String userId,
        required String displayName,
        required String role,
        required DateTime joinedAt,
      }) {
        return EventParticipantsRecord.getDocumentFromData(
          createEventParticipantsRecordData(
            userId: userId,
            displayName: displayName,
            role: role,
            status: eventStatusActive,
            joinedAt: joinedAt,
          ),
          EventParticipantsRecord.createDoc(eventRef, id: userId),
        );
      }

      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => nowUtc,
            eventPageLoader: (
              collection,
              recordBuilder, {
              queryBuilder,
              nextPageMarker,
              required pageSize,
              required isStream,
            }) async {
              return FFFirestorePage<EventsRecord>(
                [
                  _eventsRecordFixture(
                    'joined-preview-event',
                    title: 'Joined preview event',
                    startsAt: DateTime.utc(2035, 6, 14, 15),
                  ),
                ],
                null,
                null,
              );
            },
            currentUserParticipantLoader: (eventRef, userId) async {
              return participantRecord(
                eventRef,
                userId: userId,
                displayName: 'Участник',
                role: 'participant',
                joinedAt: DateTime.utc(2035, 6, 14, 10),
              );
            },
            activeParticipantsLoader: (eventRef) async {
              return [
                participantRecord(
                  eventRef,
                  userId: 'organizer-user',
                  displayName: 'Анастасия Иванова',
                  role: 'organizer',
                  joinedAt: DateTime.utc(2035, 6, 14, 8),
                ),
              ];
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Вы участвуете'), findsOneWidget);
      expect(_participantAvatarFinder(0), findsOneWidget);
      expect(_participantAvatarFinder(1), findsOneWidget);
      expect(
        find.descendant(
          of: _participantAvatarFinder(1),
          matching: find.text('М'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _participantAvatarFinder(1),
          matching: find.byIcon(Icons.person_outline),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'loaded joined event keeps current user avatar visible when preview is full',
    (tester) async {
      currentUser = _TestAuthUser('student-visible-preview');
      currentUserDocument = _userFixture(
        uid: 'student-visible-preview',
        data: {
          'display_name': 'Марко Росси',
          'photo_url': '',
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      final nowUtc = DateTime.utc(2035, 6, 14, 9);

      EventParticipantsRecord participantRecord(
        DocumentReference eventRef, {
        required String userId,
        required String displayName,
        required String role,
        required DateTime joinedAt,
      }) {
        return EventParticipantsRecord.getDocumentFromData(
          createEventParticipantsRecordData(
            userId: userId,
            displayName: displayName,
            role: role,
            status: eventStatusActive,
            joinedAt: joinedAt,
          ),
          EventParticipantsRecord.createDoc(eventRef, id: userId),
        );
      }

      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => nowUtc,
            eventPageLoader: (
              collection,
              recordBuilder, {
              queryBuilder,
              nextPageMarker,
              required pageSize,
              required isStream,
            }) async {
              return FFFirestorePage<EventsRecord>(
                [
                  _eventsRecordFixture(
                    'full-preview-event',
                    title: 'Full preview event',
                    startsAt: DateTime.utc(2035, 6, 14, 15),
                  ),
                ],
                null,
                null,
              );
            },
            currentUserParticipantLoader: (eventRef, userId) async {
              return participantRecord(
                eventRef,
                userId: userId,
                displayName: 'Участник',
                role: 'participant',
                joinedAt: DateTime.utc(2035, 6, 14, 14),
              );
            },
            activeParticipantsLoader: (eventRef) async {
              return [
                participantRecord(
                  eventRef,
                  userId: 'organizer-user',
                  displayName: 'Анастасия Иванова',
                  role: 'organizer',
                  joinedAt: DateTime.utc(2035, 6, 14, 8),
                ),
                for (var index = 1; index <= 5; index += 1)
                  participantRecord(
                    eventRef,
                    userId: 'student-$index',
                    displayName: 'Student $index',
                    role: 'participant',
                    joinedAt: DateTime.utc(2035, 6, 14, 8 + index),
                  ),
              ];
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Вы участвуете'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(eventListParticipantAvatarStackKey),
          matching: find.text('М'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'marks loaded event as joined when current user is active participant',
    (tester) async {
      currentUser = _TestAuthUser('student-joined-user');
      currentUserDocument = _userFixture(
        uid: 'student-joined-user',
        data: {
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      final nowUtc = DateTime.utc(2035, 6, 14, 9);
      var participantLookups = 0;
      DocumentReference? capturedEventRef;
      String? capturedUserId;

      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => nowUtc,
            eventPageLoader: (
              collection,
              recordBuilder, {
              queryBuilder,
              nextPageMarker,
              required pageSize,
              required isStream,
            }) async {
              return FFFirestorePage<EventsRecord>(
                [
                  _eventsRecordFixture(
                    'joined-event',
                    title: 'Joined loaded event',
                    startsAt: DateTime.utc(2035, 6, 14, 15),
                  ),
                ],
                null,
                null,
              );
            },
            activeParticipantsLoader: (_) async =>
                const <EventParticipantsRecord>[],
            currentUserParticipantLoader: (eventRef, userId) async {
              participantLookups += 1;
              capturedEventRef = eventRef;
              capturedUserId = userId;
              return EventParticipantsRecord.getDocumentFromData(
                createEventParticipantsRecordData(
                  userId: userId,
                  displayName: 'Участник',
                  status: eventStatusActive,
                  joinedAt: DateTime.utc(2035, 6, 14, 8),
                ),
                EventParticipantsRecord.createDoc(eventRef, id: userId),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(participantLookups, 1);
      expect(capturedEventRef?.id, 'joined-event');
      expect(capturedUserId, 'student-joined-user');
      expect(find.text('Вы участвуете'), findsOneWidget);
      final chatSemantics =
          tester.getSemantics(find.byKey(eventListCardChatCtaKey));
      expect(chatSemantics.flagsCollection.isButton, isTrue);
      expect(chatSemantics.flagsCollection.isEnabled, isTrue);
    },
  );

  testWidgets(
    'refreshes signed-in participant state when event list is reopened',
    (tester) async {
      currentUser = _TestAuthUser('student-cache-user');
      currentUserDocument = _userFixture(
        uid: 'student-cache-user',
        data: {
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      final nowUtc = DateTime.utc(2035, 6, 14, 9);
      var participantLookups = 0;

      Widget buildList() => _buildTestApp(
            home: EventListWidget(
              cityCatalogOverride: _catalog,
              languageCatalogOverride: _languageCatalog,
              nowUtcProvider: () => nowUtc,
              eventPageLoader: (
                collection,
                recordBuilder, {
                queryBuilder,
                nextPageMarker,
                required pageSize,
                required isStream,
              }) async {
                return FFFirestorePage<EventsRecord>(
                  [
                    _eventsRecordFixture(
                      'joined-cache-event',
                      title: 'Joined cache event',
                      startsAt: DateTime.utc(2035, 6, 14, 15),
                    ),
                  ],
                  null,
                  null,
                );
              },
              activeParticipantsLoader: (_) async =>
                  const <EventParticipantsRecord>[],
              currentUserParticipantLoader: (eventRef, userId) async {
                participantLookups += 1;
                if (participantLookups == 1) {
                  return null;
                }
                return EventParticipantsRecord.getDocumentFromData(
                  createEventParticipantsRecordData(
                    userId: userId,
                    displayName: 'Участник',
                    status: eventStatusActive,
                    joinedAt: DateTime.utc(2035, 6, 14, 8),
                  ),
                  EventParticipantsRecord.createDoc(eventRef, id: userId),
                );
              },
            ),
          );

      await tester.pumpWidget(buildList());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(participantLookups, 1);
      expect(find.text('Присоединиться'), findsOneWidget);

      await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(buildList());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(participantLookups, 2);
      expect(find.text('Вы участвуете'), findsOneWidget);
    },
  );

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
    expect(
      tester.getSize(find.byKey(eventListCardPrimaryCtaKey)).height,
      36,
    );
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
    expect(find.byType(SvgPicture), findsOneWidget);
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
    expect(find.byType(SvgPicture), findsOneWidget);
    final semantics = tester.getSemantics(find.byKey(eventListCardChatCtaKey));
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isEnabled, isFalse);
    expect(semantics.label, contains('Чат доступен только участникам'));
  });

  testWidgets('opens event detail when an event card is tapped',
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
            eventCardsOverride: [
              _eventCardFixture(eventId: 'event-123'),
            ],
          ),
        ),
        GoRoute(
          name: EventDetailWidget.routeName,
          path: EventDetailWidget.routePath,
          builder: (context, state) => EventDetailWidget(
            eventId: state.pathParameters['eventId']!,
            title: 'Detail page',
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventListCardShellKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/events/event-123');
    expect(find.byType(EventDetailWidget), findsOneWidget);
    expect(find.text('Detail page'), findsOneWidget);
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

    expect(find.byKey(eventListCitySelectorKey), findsNothing);
    expect(find.text('Москва · Россия'), findsNothing);
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

  testWidgets('uses country-only profile data as default events city',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    currentUserDocument = _userFixture(
      uid: 'country-only-user',
      data: {
        'Country_NS': {'code': 'RU'},
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

    expect(find.byKey(eventListCitySelectorKey), findsNothing);
    expect(find.text('Выберите город'), findsNothing);
    expect(find.text('Выберите город, чтобы увидеть события.'), findsNothing);
    expect(find.text('Выберите город заново'), findsNothing);
    expect(find.textContaining('Сохранённый город больше недоступен'),
        findsNothing);
    expect(_citySelectorText('Москва · Россия'), findsNothing);
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
  });

  testWidgets('does not select a city from preferredLocation profile data',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    currentUserDocument = _userFixture(
      uid: 'preferred-location-only-user',
      data: {
        'preferences': {
          'preferredLocation': {'code': 'US'},
        },
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

    expect(find.text('Выберите город'), findsOneWidget);
    expect(find.text('Выберите город, чтобы увидеть события.'), findsOneWidget);
    expect(_citySelectorText('Нью-Йорк · United States'), findsNothing);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.byKey(eventListErrorStateKey), findsNothing);
    expect(find.byKey(eventListCardShellKey), findsNothing);
    expect(analyticsTracker.payloadsFor('event_list_opened'), isEmpty);
    expect(analyticsTracker.payloadsFor('city_selected'), isEmpty);
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
      'opens city dropdown with recent before country-hinted static cities',
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
        'profileCity': _profileCityFixture(
          countryCode: 'US',
          cityKey: 'new_york',
          catalogVersion: 'old-version',
        ).toMap(),
      },
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(cityCatalogOverride: _catalog),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventListCitySelectorKey));
    await tester.pumpAndSettle();

    final rome =
        find.byKey(const ValueKey<String>('event_manual_city_option_IT_rome'));
    final newYork = find
        .byKey(const ValueKey<String>('event_manual_city_option_US_new_york'));
    final moscow = find
        .byKey(const ValueKey<String>('event_manual_city_option_RU_moscow'));

    expect(find.text('Выберите город заново'), findsOneWidget);
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
      'dropdown city selection unlocks events city state without profile save',
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

    await tester.tap(find.byKey(eventListCitySelectorKey));
    await tester.pumpAndSettle();
    await tester.tap(
        find.byKey(const ValueKey<String>('event_manual_city_option_IT_rome')));
    await tester.pumpAndSettle();

    expect(_citySelectorText('Рим · Italy'), findsNothing);
    expect(find.byKey(eventListCitySelectorKey), findsNothing);
    expect(find.text('Выберите город, чтобы увидеть события.'), findsNothing);
    expect(find.byKey(const ValueKey<String>('event_city_chip_IT_rome')),
        findsNothing);
    expect(find.byKey(eventListCardShellKey), findsOneWidget);
    expect(currentUserDocument!.hasProfileCity(), isFalse);
  });

  testWidgets('tracks analytics after recent city dropdown selection',
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

    await tester.tap(find.byKey(eventListCitySelectorKey));
    await tester.pumpAndSettle();
    await tester.tap(
        find.byKey(const ValueKey<String>('event_manual_city_option_IT_rome')));
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

  testWidgets('tracks city selected from static city dropdown option',
      (tester) async {
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

    await tester.tap(find.byKey(eventListCitySelectorKey));
    await tester.pumpAndSettle();
    await tester.tap(find
        .byKey(const ValueKey<String>('event_manual_city_option_RU_moscow')));
    await tester.pumpAndSettle();

    expect(analyticsTracker.payloadsFor('city_selected'), [
      <String, String>{
        'countryCode': 'RU',
        'cityKey': 'moscow',
        'citySource': 'static',
      },
    ]);
  });

  testWidgets('opens city dropdown from selector without injected callback',
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
    expect(searchField, findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('event_manual_city_option_GE_tbilisi')),
    );
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

    expect(_citySelectorText('Нью-Йорк · United States'), findsNothing);
    expect(find.byKey(eventListCitySelectorKey), findsNothing);
    expect(find.byKey(eventManualCitySearchFieldKey), findsNothing);
    expect(find.text('Выберите город, чтобы увидеть события.'), findsNothing);
    expect(find.byKey(eventListCardShellKey), findsOneWidget);
    expect(currentUserDocument!.hasProfileCity(), isFalse);
  });

  testWidgets('tracks city selected from dropdown as static source',
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
        'citySource': 'static',
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

    expect(find.text('Нью-Йорк · United States'), findsNothing);
    expect(find.byKey(eventListCitySelectorKey), findsNothing);
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

  test('event list route uses repository loading without profile writes', () {
    final source = File('lib/shared_pages/events/event_list_widget.dart')
        .readAsStringSync();

    expect(source, contains('EventListRepository'));
    expect(source, contains('EventsRecord'));
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

bool _isDateFilterSelected(
  WidgetTester tester,
  EventListDateFilter filter,
) =>
    tester.getSemantics(_dateFilterFinder(filter)).flagsCollection.isSelected;

Finder _levelFilterFinder(String level) =>
    find.byKey(ValueKey<String>('event_level_filter_$level'));

bool _isLevelFilterSelected(WidgetTester tester, String level) =>
    tester.getSemantics(_levelFilterFinder(level)).flagsCollection.isSelected;

Color? _filterChipTextColor(WidgetTester tester, Finder chipFinder) {
  final text = tester.widget<Text>(
    find.descendant(
      of: chipFinder,
      matching: find.byType(Text),
    ),
  );
  return text.style?.color;
}

Color? _filterChipBackgroundColor(WidgetTester tester, Finder chipFinder) {
  final container = tester.widget<Container>(
    find.descendant(
      of: chipFinder,
      matching: find.byType(Container),
    ),
  );
  final decoration = container.decoration;
  return decoration is BoxDecoration ? decoration.color : null;
}

void _expectWhereCondition(
  List<dynamic> conditions,
  String field,
  String operator,
  Object? value,
) {
  final expectedField = FieldPath.fromString(field);
  final hasCondition = conditions.any(
    (condition) =>
        condition is List<dynamic> &&
        condition.length == 3 &&
        condition[0] == expectedField &&
        condition[1] == operator &&
        condition[2] == value,
  );

  expect(
    hasCondition,
    isTrue,
    reason: 'Expected where($field $operator $value).',
  );
}

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

EventsRecord _eventsRecordFixture(
  String id, {
  String title = 'Разговорный клуб',
  DateTime? startsAt,
}) {
  return EventsRecord.getDocumentFromData(
    {
      'title': title,
      'description': 'Описание события',
      'languageCode': 'en',
      'languageNameEn': 'English',
      'languageNameRu': 'Английский',
      'levelMin': 'B1',
      'levelMax': 'C1',
      'countryCode': 'RU',
      'cityKey': 'moscow',
      'locationName': 'Starbucks, ул. Арбат, 5',
      'startsAt': startsAt ?? DateTime.utc(2035, 6, 14, 15),
      'timeZoneId': 'Europe/Moscow',
      'capacity': 10,
      'participantsCount': 1,
      'organizerId': 'organizer-user',
      'organizerDisplayName': 'Анастасия Иванова',
      'organizerPhotoUrl': '',
      'status': eventStatusActive,
    },
    EventsRecord.collection.doc(id),
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

class _FailingLanguageAssetBundle extends CachingAssetBundle {
  var languageCatalogLoadCount = 0;

  @override
  Future<ByteData> load(String key) {
    if (key == eventLanguageCatalogAssetPath) {
      languageCatalogLoadCount += 1;
      return Future<ByteData>.error(
        FlutterError('Missing test language catalog'),
      );
    }
    return rootBundle.load(key);
  }
}
