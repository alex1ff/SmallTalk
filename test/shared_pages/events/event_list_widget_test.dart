import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/components/ux_refreshing_indicator_overlay.dart';
import 'package:small_talk/flutter_flow/custom_icons.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
import 'package:small_talk/shared_pages/events/event_create_widget.dart';
import 'package:small_talk/shared_pages/events/event_detail_widget.dart';
import 'package:small_talk/shared_pages/events/event_group_chat_widget.dart';
import 'package:small_talk/shared_pages/events/event_list_widget.dart';
import 'package:small_talk/shared_pages/design/expatlio_design.dart';
import 'package:small_talk/services/event_actions_repository.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_chip_source.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
import 'package:small_talk/services/event_selected_city_state.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';
import 'package:small_talk/services/event_list_repository.dart';
import 'package:small_talk/services/event_level_helper.dart';
import 'package:small_talk/services/event_language_catalog.dart';
import 'package:small_talk/services/event_list_cache_invalidation.dart';
import 'package:small_talk/services/events_analytics_service.dart';
import 'package:small_talk/services/user_public_profile_preload_repository.dart';

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
      ExpatlioDesign.segmentedControlBackground,
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
      ExpatlioDesign.segmentedControlBackground,
    );
  });

  testWidgets('uses compact spacing for event filter chips', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    final firstDateChip = _filterChipContainerFinder(
      _dateFilterFinder(EventListDateFilter.today),
    );
    final secondDateChip = _filterChipContainerFinder(
      _dateFilterFinder(EventListDateFilter.tomorrow),
    );
    final firstLevelChip = _filterChipContainerFinder(
      _levelFilterFinder('A1'),
    );
    final secondLevelChip = _filterChipContainerFinder(
      _levelFilterFinder('A2'),
    );

    expect(
      tester.getTopLeft(secondDateChip).dx -
          tester.getTopRight(firstDateChip).dx,
      ExpatlioDesign.space4,
    );
    expect(
      tester.getSize(firstDateChip).width -
          tester.getSize(find.text('Сегодня')).width,
      16,
    );
    expect(
      tester.getTopLeft(secondLevelChip).dx -
          tester.getTopRight(firstLevelChip).dx,
      ExpatlioDesign.space4,
    );
    expect(
      tester.getSize(firstLevelChip).width -
          tester.getSize(find.text('A1')).width,
      16,
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
    expect(find.byKey(eventListRefreshingIndicatorKey), findsNothing);
    expect(find.byType(UxRefreshingIndicatorPill), findsNothing);
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
    expect(find.byKey(eventListRefreshingIndicatorKey), findsNothing);
    expect(find.byType(UxRefreshingIndicatorPill), findsNothing);
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

  testWidgets('empty second page shows no more items without emptying the list',
      (tester) async {
    final marker = _FakeQueryDocumentSnapshot('pagination-cursor');
    final secondPage = Completer<FFFirestorePage<EventsRecord>>();
    final receivedMarkers = <DocumentSnapshot?>[];
    var calls = 0;
    addTearDown(() {
      if (!secondPage.isCompleted) {
        secondPage.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUserDocument = _userFixture(
      uid: 'pagination-empty-page-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final firstPageEvents = List<EventsRecord>.generate(
      8,
      (index) => _eventsRecordFixture(
        'pagination-first-$index',
        title: 'First page event $index',
        startsAt: DateTime.utc(2035, 6, 14, 15 + index),
      ),
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
          }) {
            calls += 1;
            receivedMarkers.add(nextPageMarker);
            if (calls == 1) {
              return Future.value(
                FFFirestorePage<EventsRecord>(
                  firstPageEvents,
                  null,
                  marker,
                ),
              );
            }
            return secondPage.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(receivedMarkers, <DocumentSnapshot?>[null]);
    expect(find.text('First page event 0'), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.byKey(eventListNoMoreItemsKey), findsNothing);

    await tester.drag(
      find.byKey(eventListScrollViewKey),
      const Offset(0, -5000),
    );
    await tester.pump();

    expect(calls, 2);
    expect(receivedMarkers, <DocumentSnapshot?>[null, marker]);
    expect(find.text('First page event 0'), findsOneWidget);
    expect(find.text('First page event 7'), findsOneWidget);
    expect(find.byKey(eventListCardShellKey), findsNWidgets(8));
    expect(find.byKey(eventListPaginationLoadingKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);

    await tester.drag(
      find.byKey(eventListScrollViewKey),
      const Offset(0, -400),
    );
    await tester.pump();
    expect(calls, 2);

    secondPage.complete(
      FFFirestorePage<EventsRecord>(const [], null, null),
    );
    await tester.pumpAndSettle();

    expect(find.text('First page event 0'), findsOneWidget);
    expect(find.text('First page event 7'), findsOneWidget);
    expect(find.byKey(eventListCardShellKey), findsNWidgets(8));
    expect(find.byKey(eventListPaginationLoadingKey), findsNothing);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);
    expect(find.text('Больше событий нет'), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    final noMoreSemantics = tester.widget<Semantics>(
      find.byKey(eventListNoMoreItemsKey),
    );
    expect(noMoreSemantics.properties.label, 'Больше событий нет');
    expect(noMoreSemantics.properties.liveRegion, isTrue);

    await tester.drag(
      find.byKey(eventListScrollViewKey),
      const Offset(0, -400),
    );
    await tester.pump();
    expect(calls, 2);
  });

  testWidgets(
      'undersized first page loads the empty second page without scroll',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final marker = _FakeQueryDocumentSnapshot('undersized-cursor');
    final secondPage = Completer<FFFirestorePage<EventsRecord>>();
    final receivedMarkers = <DocumentSnapshot?>[];
    var calls = 0;
    addTearDown(() {
      if (!secondPage.isCompleted) {
        secondPage.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUserDocument = _userFixture(
      uid: 'pagination-undersized-user',
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
          }) {
            calls += 1;
            receivedMarkers.add(nextPageMarker);
            if (calls == 1) {
              return Future.value(
                FFFirestorePage<EventsRecord>(
                  [
                    _eventsRecordFixture(
                      'undersized-first-event',
                      title: 'Undersized first event',
                      startsAt: DateTime.utc(2035, 6, 14, 15),
                    ),
                  ],
                  null,
                  marker,
                ),
              );
            }
            return secondPage.future;
          },
        ),
      ),
    );
    for (var pump = 0; pump < 10 && calls < 2; pump += 1) {
      await tester.pump();
    }
    await tester.pump();

    expect(calls, 2);
    expect(receivedMarkers, <DocumentSnapshot?>[null, marker]);
    expect(find.text('Undersized first event'), findsOneWidget);
    expect(find.byKey(eventListPaginationLoadingKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);

    secondPage.complete(
      FFFirestorePage<EventsRecord>(const [], null, null),
    );
    await tester.pumpAndSettle();

    expect(find.text('Undersized first event'), findsOneWidget);
    expect(find.byKey(eventListPaginationLoadingKey), findsNothing);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
  });

  testWidgets('duplicate-only page advances to the next cursor',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final firstMarker = _FakeQueryDocumentSnapshot('duplicate-cursor-1');
    final secondMarker = _FakeQueryDocumentSnapshot('duplicate-cursor-2');
    final thirdPage = Completer<FFFirestorePage<EventsRecord>>();
    final receivedMarkers = <DocumentSnapshot?>[];
    final firstEvent = _eventsRecordFixture(
      'duplicate-first-event',
      title: 'Duplicate first event',
      startsAt: DateTime.utc(2035, 6, 14, 15),
    );
    var calls = 0;
    addTearDown(() {
      if (!thirdPage.isCompleted) {
        thirdPage.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUserDocument = _userFixture(
      uid: 'pagination-duplicate-user',
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
          }) {
            calls += 1;
            receivedMarkers.add(nextPageMarker);
            if (calls == 1) {
              return Future.value(
                FFFirestorePage<EventsRecord>(
                  [firstEvent],
                  null,
                  firstMarker,
                ),
              );
            }
            if (calls == 2) {
              return Future.value(
                FFFirestorePage<EventsRecord>(
                  [firstEvent],
                  null,
                  secondMarker,
                ),
              );
            }
            if (calls == 3) {
              return thirdPage.future;
            }
            return Future.error(StateError('unexpected pagination request'));
          },
        ),
      ),
    );
    for (var pump = 0; pump < 20 && calls < 3; pump += 1) {
      await tester.pump();
    }
    await tester.pump();

    expect(calls, 3);
    expect(
      receivedMarkers,
      <DocumentSnapshot?>[null, firstMarker, secondMarker],
    );
    expect(find.text('Duplicate first event'), findsOneWidget);
    expect(find.byKey(eventListPaginationLoadingKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);

    thirdPage.complete(
      FFFirestorePage<EventsRecord>(
        [firstEvent],
        null,
        _FakeQueryDocumentSnapshot(secondMarker.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 3);
    expect(find.text('Duplicate first event'), findsOneWidget);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
  });

  testWidgets('cached no-more state reopens with the first page intact',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const userId = 'pagination-cache-user';
    final marker = _FakeQueryDocumentSnapshot('pagination-cache-cursor');
    final receivedMarkerIds = <String?>[];
    var calls = 0;
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
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
      receivedMarkerIds.add(nextPageMarker?.id);
      if (calls == 1) {
        expect(nextPageMarker, isNull);
        return FFFirestorePage<EventsRecord>(
          [
            _eventsRecordFixture(
              'pagination-cached-event',
              title: 'Cached pagination event',
              startsAt: DateTime.utc(2035, 6, 14, 15),
            ),
          ],
          null,
          marker,
        );
      }
      if (calls == 2) {
        expect(nextPageMarker, same(marker));
        return FFFirestorePage<EventsRecord>(const [], null, null);
      }
      throw StateError('cached pagination must not reload');
    };
    final EventListCurrentUserParticipantLoader participantLoader =
        (_, __) async => null;
    final EventListActiveParticipantsLoader activeParticipantsLoader =
        (_) async => const <EventParticipantsRecord>[];
    final EventListPublicProfilesLoader publicProfilesLoader = (userIds) async {
      return UserPublicProfilePreloadResult(
        profilesByUserId: {
          for (final userId in userIds)
            userId: _userPublicProfileFixture(userId),
        },
      );
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: participantLoader,
            activeParticipantsLoader: activeParticipantsLoader,
            publicProfilesLoader: publicProfilesLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(receivedMarkerIds, <String?>[null, marker.id]);
    expect(calls, 2);
    expect(find.text('Cached pagination event'), findsOneWidget);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(receivedMarkerIds, <String?>[null, marker.id]);
    expect(calls, 2);
    expect(find.text('Cached pagination event'), findsOneWidget);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
  });

  testWidgets('dispose ignores a pending second-page response', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final marker = _FakeQueryDocumentSnapshot('pagination-dispose-cursor');
    final secondPage = Completer<FFFirestorePage<EventsRecord>>();
    var calls = 0;
    addTearDown(() {
      if (!secondPage.isCompleted) {
        secondPage.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUserDocument = _userFixture(
      uid: 'pagination-dispose-user',
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
          }) {
            calls += 1;
            if (calls == 1) {
              return Future.value(
                FFFirestorePage<EventsRecord>(
                  [
                    _eventsRecordFixture(
                      'pagination-dispose-event',
                      title: 'Dispose pagination event',
                      startsAt: DateTime.utc(2035, 6, 14, 15),
                    ),
                  ],
                  null,
                  marker,
                ),
              );
            }
            expect(nextPageMarker, same(marker));
            return secondPage.future;
          },
        ),
      ),
    );
    for (var pump = 0; pump < 10 && calls < 2; pump += 1) {
      await tester.pump();
    }

    expect(calls, 2);
    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    secondPage.complete(
      FFFirestorePage<EventsRecord>(const [], null, null),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(eventListNoMoreItemsKey), findsNothing);
  });

  testWidgets('late first-page enrichment preserves pagination no-more state',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const userId = 'pagination-late-enrichment-user';
    final marker =
        _FakeQueryDocumentSnapshot('pagination-late-enrichment-cursor');
    final participant = Completer<EventParticipantsRecord?>();
    var calls = 0;
    addTearDown(() {
      if (!participant.isCompleted) {
        participant.complete(null);
      }
    });
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
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
            if (calls == 1) {
              return FFFirestorePage<EventsRecord>(
                [
                  _eventsRecordFixture(
                    'pagination-late-enrichment-event',
                    title: 'Late enrichment event',
                    startsAt: DateTime.utc(2035, 6, 14, 15),
                  ),
                ],
                null,
                marker,
              );
            }
            expect(nextPageMarker, same(marker));
            return FFFirestorePage<EventsRecord>(const [], null, null);
          },
          currentUserParticipantLoader: (_, __) => participant.future,
          activeParticipantsLoader: (_) async =>
              const <EventParticipantsRecord>[],
          publicProfilesLoader: (_) async => UserPublicProfilePreloadResult(),
        ),
      ),
    );
    for (var pump = 0; pump < 10 && calls < 2; pump += 1) {
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Late enrichment event'), findsOneWidget);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);

    participant.complete(null);
    await tester.pumpAndSettle();

    expect(find.text('Late enrichment event'), findsOneWidget);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
  });

  testWidgets('ready cache stays atomic while appended enrichment is pending',
      (tester) async {
    const userId = 'pagination-overlap-cache-user';
    const appendedEventId = 'pagination-overlap-appended';
    final firstMarker =
        _FakeQueryDocumentSnapshot('pagination-overlap-cursor-1');
    final secondMarker =
        _FakeQueryDocumentSnapshot('pagination-overlap-cursor-2');
    final appendedParticipant = Completer<EventParticipantsRecord?>();
    final reopenedBase = Completer<FFFirestorePage<EventsRecord>>();
    final receivedMarkerIds = <String?>[];
    var calls = 0;
    addTearDown(() {
      if (!appendedParticipant.isCompleted) {
        appendedParticipant.complete(null);
      }
      if (!reopenedBase.isCompleted) {
        reopenedBase.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
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
    }) {
      calls += 1;
      receivedMarkerIds.add(nextPageMarker?.id);
      if (calls == 1) {
        return Future.value(
          FFFirestorePage<EventsRecord>(
            List<EventsRecord>.generate(
              8,
              (index) => _eventsRecordFixture(
                'pagination-overlap-first-$index',
                title: 'Overlap first event $index',
                startsAt: DateTime.utc(2035, 6, 14, 15 + index),
              ),
            ),
            null,
            firstMarker,
          ),
        );
      }
      if (calls == 2) {
        expect(nextPageMarker, same(firstMarker));
        return Future.value(
          FFFirestorePage<EventsRecord>(
            [
              _eventsRecordFixture(
                appendedEventId,
                title: 'Overlap appended event',
                startsAt: DateTime.utc(2035, 6, 14, 16),
              ),
            ],
            null,
            secondMarker,
          ),
        );
      }
      if (calls == 3) {
        expect(nextPageMarker, same(secondMarker));
        return Future.value(
          FFFirestorePage<EventsRecord>(
            const [],
            null,
            null,
          ),
        );
      }
      if (calls == 4) {
        expect(nextPageMarker, isNull);
        return reopenedBase.future;
      }
      return Future.error(StateError('unexpected overlap pagination request'));
    };
    final EventListCurrentUserParticipantLoader participantLoader =
        (eventRef, _) {
      if (eventRef.id == appendedEventId) {
        return appendedParticipant.future;
      }
      return Future<EventParticipantsRecord?>.value();
    };
    final EventListActiveParticipantsLoader activeParticipantsLoader =
        (_) async => const <EventParticipantsRecord>[];
    final EventListPublicProfilesLoader publicProfilesLoader = (userIds) async {
      return UserPublicProfilePreloadResult(
        profilesByUserId: {
          for (final profileUserId in userIds)
            profileUserId: _userPublicProfileFixture(profileUserId),
        },
      );
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: participantLoader,
            activeParticipantsLoader: activeParticipantsLoader,
            publicProfilesLoader: publicProfilesLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Overlap first event 0'), findsOneWidget);

    await tester.drag(
      find.byKey(eventListScrollViewKey),
      const Offset(0, -5000),
    );
    for (var pump = 0; pump < 10 && calls < 2; pump += 1) {
      await tester.pump();
    }
    await tester.pumpAndSettle();
    if (calls < 3) {
      await tester.drag(
        find.byKey(eventListScrollViewKey),
        const Offset(0, -5000),
      );
      for (var pump = 0; pump < 10 && calls < 3; pump += 1) {
        await tester.pump();
      }
    }
    await tester.pump();

    expect(receivedMarkerIds, <String?>[
      null,
      firstMarker.id,
      secondMarker.id,
    ]);
    expect(calls, 3);
    expect(find.text('Overlap first event 0'), findsOneWidget);
    expect(find.text('Overlap appended event'), findsOneWidget);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());
    for (var pump = 0; pump < 10 && calls < 4; pump += 1) {
      await tester.pump();
    }
    await tester.pump();

    expect(receivedMarkerIds, <String?>[
      null,
      firstMarker.id,
      secondMarker.id,
      null,
    ]);
    expect(calls, 4);
    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.text('Overlap appended event'), findsNothing);

    appendedParticipant.complete(null);
    reopenedBase.complete(
      FFFirestorePage<EventsRecord>(const [], null, null),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('failed appended enrichment keeps the whole session uncached',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const userId = 'pagination-failed-enrichment-user';
    const firstEventId = 'pagination-failed-enrichment-first';
    const appendedEventId = 'pagination-failed-enrichment-appended';
    final marker =
        _FakeQueryDocumentSnapshot('pagination-failed-enrichment-cursor');
    final firstParticipant = Completer<EventParticipantsRecord?>();
    final reopenedBase = Completer<FFFirestorePage<EventsRecord>>();
    final receivedMarkerIds = <String?>[];
    var calls = 0;
    addTearDown(() {
      if (!firstParticipant.isCompleted) {
        firstParticipant.complete(null);
      }
      if (!reopenedBase.isCompleted) {
        reopenedBase.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
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
    }) {
      calls += 1;
      receivedMarkerIds.add(nextPageMarker?.id);
      if (calls == 1) {
        return Future.value(
          FFFirestorePage<EventsRecord>(
            [
              _eventsRecordFixture(
                firstEventId,
                title: 'Failed enrichment first event',
                startsAt: DateTime.utc(2035, 6, 14, 15),
              ),
            ],
            null,
            marker,
          ),
        );
      }
      if (calls == 2) {
        expect(nextPageMarker, same(marker));
        return Future.value(
          FFFirestorePage<EventsRecord>(
            [
              _eventsRecordFixture(
                appendedEventId,
                title: 'Failed enrichment appended event',
                startsAt: DateTime.utc(2035, 6, 14, 16),
              ),
            ],
            null,
            null,
          ),
        );
      }
      if (calls == 3) {
        expect(nextPageMarker, isNull);
        return reopenedBase.future;
      }
      return Future.error(
        StateError('unexpected failed-enrichment pagination request'),
      );
    };
    final EventListCurrentUserParticipantLoader participantLoader =
        (eventRef, _) {
      if (eventRef.id == firstEventId) {
        return firstParticipant.future;
      }
      if (eventRef.id == appendedEventId) {
        return Future<EventParticipantsRecord?>.error(
          StateError('membership enrichment failed'),
        );
      }
      return Future<EventParticipantsRecord?>.value();
    };
    final EventListActiveParticipantsLoader activeParticipantsLoader =
        (_) async => const <EventParticipantsRecord>[];
    final EventListPublicProfilesLoader publicProfilesLoader = (userIds) async {
      return UserPublicProfilePreloadResult(
        profilesByUserId: {
          for (final profileUserId in userIds)
            profileUserId: _userPublicProfileFixture(profileUserId),
        },
      );
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: participantLoader,
            activeParticipantsLoader: activeParticipantsLoader,
            publicProfilesLoader: publicProfilesLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    for (var pump = 0; pump < 10 && calls < 2; pump += 1) {
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Failed enrichment first event'), findsOneWidget);
    expect(find.text('Failed enrichment appended event'), findsOneWidget);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);

    firstParticipant.complete(null);
    await tester.pumpAndSettle();

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());
    for (var pump = 0; pump < 10 && calls < 3; pump += 1) {
      await tester.pump();
    }
    await tester.pump();

    expect(receivedMarkerIds, <String?>[null, marker.id, null]);
    expect(calls, 3);
    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.text('Failed enrichment appended event'), findsNothing);

    reopenedBase.complete(
      FFFirestorePage<EventsRecord>(const [], null, null),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('initial active-participant failure keeps the session uncached',
      (tester) async {
    const userId = 'pagination-initial-active-failure-user';
    const eventId = 'pagination-initial-active-failure-event';
    final reopenedBase = Completer<FFFirestorePage<EventsRecord>>();
    var calls = 0;
    addTearDown(() {
      if (!reopenedBase.isCompleted) {
        reopenedBase.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
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
    }) {
      calls += 1;
      expect(nextPageMarker, isNull);
      if (calls == 1) {
        return Future.value(
          FFFirestorePage<EventsRecord>(
            [
              _eventsRecordFixture(
                eventId,
                title: 'Initial active failure event',
                startsAt: DateTime.utc(2035, 6, 14, 15),
              ),
            ],
            null,
            null,
          ),
        );
      }
      if (calls == 2) {
        return reopenedBase.future;
      }
      return Future.error(
        StateError('unexpected initial-active-failure request'),
      );
    };
    final EventListCurrentUserParticipantLoader participantLoader =
        (_, __) async => null;
    final EventListActiveParticipantsLoader activeParticipantsLoader =
        (_) => Future<List<EventParticipantsRecord>>.error(
              StateError('active participants failed'),
            );
    final EventListPublicProfilesLoader publicProfilesLoader = (userIds) async {
      return UserPublicProfilePreloadResult(
        profilesByUserId: {
          for (final profileUserId in userIds)
            profileUserId: _userPublicProfileFixture(profileUserId),
        },
      );
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: participantLoader,
            activeParticipantsLoader: activeParticipantsLoader,
            publicProfilesLoader: publicProfilesLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Initial active failure event'), findsOneWidget);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());
    for (var pump = 0; pump < 10 && calls < 2; pump += 1) {
      await tester.pump();
    }
    await tester.pump();

    expect(calls, 2);
    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.text('Initial active failure event'), findsNothing);

    reopenedBase.complete(
      FFFirestorePage<EventsRecord>(const [], null, null),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('appended active-participant failure survives late page-one work',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const userId = 'pagination-appended-active-failure-user';
    const firstEventId = 'pagination-appended-active-failure-first';
    const appendedEventId = 'pagination-appended-active-failure-second';
    final marker =
        _FakeQueryDocumentSnapshot('pagination-appended-active-failure-cursor');
    final firstParticipant = Completer<EventParticipantsRecord?>();
    final reopenedBase = Completer<FFFirestorePage<EventsRecord>>();
    final receivedMarkerIds = <String?>[];
    var calls = 0;
    addTearDown(() {
      if (!firstParticipant.isCompleted) {
        firstParticipant.complete(null);
      }
      if (!reopenedBase.isCompleted) {
        reopenedBase.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
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
    }) {
      calls += 1;
      receivedMarkerIds.add(nextPageMarker?.id);
      if (calls == 1) {
        return Future.value(
          FFFirestorePage<EventsRecord>(
            [
              _eventsRecordFixture(
                firstEventId,
                title: 'Appended active failure first event',
                startsAt: DateTime.utc(2035, 6, 14, 15),
              ),
            ],
            null,
            marker,
          ),
        );
      }
      if (calls == 2) {
        expect(nextPageMarker, same(marker));
        return Future.value(
          FFFirestorePage<EventsRecord>(
            [
              _eventsRecordFixture(
                appendedEventId,
                title: 'Appended active failure second event',
                startsAt: DateTime.utc(2035, 6, 14, 16),
              ),
            ],
            null,
            null,
          ),
        );
      }
      if (calls == 3) {
        expect(nextPageMarker, isNull);
        return reopenedBase.future;
      }
      return Future.error(
        StateError('unexpected appended-active-failure request'),
      );
    };
    final EventListCurrentUserParticipantLoader participantLoader =
        (eventRef, _) {
      if (eventRef.id == firstEventId) {
        return firstParticipant.future;
      }
      return Future<EventParticipantsRecord?>.value();
    };
    final EventListActiveParticipantsLoader activeParticipantsLoader =
        (eventRef) {
      if (eventRef.id == appendedEventId) {
        return Future<List<EventParticipantsRecord>>.error(
          StateError('appended active participants failed'),
        );
      }
      return Future.value(const <EventParticipantsRecord>[]);
    };
    final EventListPublicProfilesLoader publicProfilesLoader = (userIds) async {
      return UserPublicProfilePreloadResult(
        profilesByUserId: {
          for (final profileUserId in userIds)
            profileUserId: _userPublicProfileFixture(profileUserId),
        },
      );
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: participantLoader,
            activeParticipantsLoader: activeParticipantsLoader,
            publicProfilesLoader: publicProfilesLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    for (var pump = 0; pump < 10 && calls < 2; pump += 1) {
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Appended active failure first event'), findsOneWidget);
    expect(find.text('Appended active failure second event'), findsOneWidget);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);

    firstParticipant.complete(null);
    await tester.pumpAndSettle();

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());
    for (var pump = 0; pump < 10 && calls < 3; pump += 1) {
      await tester.pump();
    }
    await tester.pump();

    expect(receivedMarkerIds, <String?>[null, marker.id, null]);
    expect(calls, 3);
    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.text('Appended active failure second event'), findsNothing);

    reopenedBase.complete(
      FFFirestorePage<EventsRecord>(const [], null, null),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('appended profile failure survives late page-one enrichment',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const userId = 'pagination-appended-profile-failure-user';
    const firstEventId = 'pagination-appended-profile-failure-first';
    const appendedEventId = 'pagination-appended-profile-failure-second';
    const appendedParticipantId =
        'pagination-appended-profile-failure-participant';
    final marker = _FakeQueryDocumentSnapshot(
      'pagination-appended-profile-failure-cursor',
    );
    final firstParticipant = Completer<EventParticipantsRecord?>();
    final reopenedBase = Completer<FFFirestorePage<EventsRecord>>();
    final receivedMarkerIds = <String?>[];
    var calls = 0;
    var profileLoads = 0;
    addTearDown(() {
      if (!firstParticipant.isCompleted) {
        firstParticipant.complete(null);
      }
      if (!reopenedBase.isCompleted) {
        reopenedBase.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
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
    }) {
      calls += 1;
      receivedMarkerIds.add(nextPageMarker?.id);
      if (calls == 1) {
        return Future.value(
          FFFirestorePage<EventsRecord>(
            [
              _eventsRecordFixture(
                firstEventId,
                title: 'Appended profile failure first event',
                startsAt: DateTime.utc(2035, 6, 14, 15),
              ),
            ],
            null,
            marker,
          ),
        );
      }
      if (calls == 2) {
        expect(nextPageMarker, same(marker));
        return Future.value(
          FFFirestorePage<EventsRecord>(
            [
              _eventsRecordFixture(
                appendedEventId,
                title: 'Appended profile failure second event',
                startsAt: DateTime.utc(2035, 6, 14, 16),
              ),
            ],
            null,
            null,
          ),
        );
      }
      if (calls == 3) {
        expect(nextPageMarker, isNull);
        return reopenedBase.future;
      }
      return Future.error(
        StateError('unexpected appended-profile-failure request'),
      );
    };
    final EventListCurrentUserParticipantLoader participantLoader =
        (eventRef, _) {
      if (eventRef.id == firstEventId) {
        return firstParticipant.future;
      }
      return Future<EventParticipantsRecord?>.value();
    };
    final EventListActiveParticipantsLoader activeParticipantsLoader =
        (eventRef) {
      if (eventRef.id == appendedEventId) {
        return Future.value(
          [
            _eventParticipantRecordFixture(
              eventRef,
              userId: appendedParticipantId,
              displayName: 'Appended profile snapshot',
              joinedAt: DateTime.utc(2035, 6, 14, 8),
            ),
          ],
        );
      }
      return Future.value(const <EventParticipantsRecord>[]);
    };
    final EventListPublicProfilesLoader publicProfilesLoader = (userIds) {
      profileLoads += 1;
      expect(userIds, <String>{appendedParticipantId});
      return Future<UserPublicProfilePreloadResult>.error(
        StateError('appended public profiles failed'),
      );
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: participantLoader,
            activeParticipantsLoader: activeParticipantsLoader,
            publicProfilesLoader: publicProfilesLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    for (var pump = 0; pump < 10 && calls < 2; pump += 1) {
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(profileLoads, greaterThan(0));
    expect(find.text('Appended profile failure first event'), findsOneWidget);
    expect(find.text('Appended profile failure second event'), findsOneWidget);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);

    firstParticipant.complete(null);
    await tester.pumpAndSettle();
    final profileLoadsAfterLatePageOne = profileLoads;

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());
    for (var pump = 0; pump < 10 && calls < 3; pump += 1) {
      await tester.pump();
    }
    await tester.pump();

    expect(receivedMarkerIds, <String?>[null, marker.id, null]);
    expect(calls, 3);
    expect(profileLoads, profileLoadsAfterLatePageOne);
    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.text('Appended profile failure second event'), findsNothing);

    reopenedBase.complete(
      FFFirestorePage<EventsRecord>(const [], null, null),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('successful appended enrichment reopens the complete cache',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const userId = 'pagination-successful-enrichment-user';
    final marker =
        _FakeQueryDocumentSnapshot('pagination-successful-enrichment-cursor');
    final receivedMarkerIds = <String?>[];
    var calls = 0;
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
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
      receivedMarkerIds.add(nextPageMarker?.id);
      if (calls == 1) {
        return FFFirestorePage<EventsRecord>(
          [
            _eventsRecordFixture(
              'pagination-successful-enrichment-first',
              title: 'Successful enrichment first event',
              startsAt: DateTime.utc(2035, 6, 14, 15),
            ),
          ],
          null,
          marker,
        );
      }
      if (calls == 2) {
        expect(nextPageMarker, same(marker));
        return FFFirestorePage<EventsRecord>(
          [
            _eventsRecordFixture(
              'pagination-successful-enrichment-appended',
              title: 'Successful enrichment appended event',
              startsAt: DateTime.utc(2035, 6, 14, 16),
            ),
          ],
          null,
          null,
        );
      }
      throw StateError('complete pagination cache must not reload');
    };
    final EventListCurrentUserParticipantLoader participantLoader =
        (_, __) async => null;
    final EventListActiveParticipantsLoader activeParticipantsLoader =
        (_) async => const <EventParticipantsRecord>[];
    final EventListPublicProfilesLoader publicProfilesLoader = (userIds) async {
      return UserPublicProfilePreloadResult(
        profilesByUserId: {
          for (final profileUserId in userIds)
            profileUserId: _userPublicProfileFixture(profileUserId),
        },
      );
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: participantLoader,
            activeParticipantsLoader: activeParticipantsLoader,
            publicProfilesLoader: publicProfilesLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(receivedMarkerIds, <String?>[null, marker.id]);
    expect(find.text('Successful enrichment first event'), findsOneWidget);
    expect(find.text('Successful enrichment appended event'), findsOneWidget);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(receivedMarkerIds, <String?>[null, marker.id]);
    expect(find.text('Successful enrichment first event'), findsOneWidget);
    expect(find.text('Successful enrichment appended event'), findsOneWidget);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
  });

  testWidgets('next-page error keeps cards and retries the same cursor',
      (tester) async {
    final marker = _FakeQueryDocumentSnapshot('pagination-retry-cursor');
    final receivedMarkers = <DocumentSnapshot?>[];
    var calls = 0;
    currentUserDocument = _userFixture(
      uid: 'pagination-retry-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final firstPageEvents = List<EventsRecord>.generate(
      8,
      (index) => _eventsRecordFixture(
        'pagination-retry-$index',
        title: 'Retry page event $index',
        startsAt: DateTime.utc(2035, 6, 14, 15 + index),
      ),
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
          }) {
            calls += 1;
            receivedMarkers.add(nextPageMarker);
            if (calls == 1) {
              return Future.value(
                FFFirestorePage<EventsRecord>(
                  firstPageEvents,
                  null,
                  marker,
                ),
              );
            }
            if (calls == 2) {
              return Future.error(StateError('next page failed'));
            }
            return Future.value(
              FFFirestorePage<EventsRecord>(const [], null, null),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(eventListScrollViewKey),
      const Offset(0, -5000),
    );
    await tester.pump();
    await tester.pump();

    expect(calls, 2);
    expect(find.text('Retry page event 0'), findsOneWidget);
    expect(find.byKey(eventListPaginationErrorKey), findsOneWidget);
    expect(find.byKey(eventListErrorStateKey), findsNothing);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);

    await tester.ensureVisible(find.byKey(eventListPaginationRetryButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(eventListPaginationRetryButtonKey));
    await tester.pumpAndSettle();

    expect(calls, 3);
    expect(receivedMarkers, <DocumentSnapshot?>[null, marker, marker]);
    expect(find.text('Retry page event 0'), findsOneWidget);
    expect(find.byKey(eventListPaginationErrorKey), findsNothing);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
  });

  testWidgets('non-empty next page appends cards without replacing page one',
      (tester) async {
    final marker = _FakeQueryDocumentSnapshot('pagination-append-cursor');
    var calls = 0;
    currentUserDocument = _userFixture(
      uid: 'pagination-append-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final firstPageEvents = List<EventsRecord>.generate(
      8,
      (index) => _eventsRecordFixture(
        'pagination-append-$index',
        title: 'Append page event $index',
        startsAt: DateTime.utc(2035, 6, 14, 15 + index),
      ),
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
          }) {
            calls += 1;
            if (calls == 1) {
              return Future.value(
                FFFirestorePage<EventsRecord>(
                  firstPageEvents,
                  null,
                  marker,
                ),
              );
            }
            expect(nextPageMarker, same(marker));
            return Future.value(
              FFFirestorePage<EventsRecord>(
                [
                  _eventsRecordFixture(
                    'pagination-appended-event',
                    title: 'Appended event',
                    startsAt: DateTime.utc(2035, 6, 15, 9),
                  ),
                ],
                null,
                null,
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(eventListScrollViewKey),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Append page event 0'), findsOneWidget);
    expect(find.text('Appended event'), findsOneWidget);
    expect(find.byKey(eventListNoMoreItemsKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
  });

  testWidgets('late next page is ignored after the active filter changes',
      (tester) async {
    final marker = _FakeQueryDocumentSnapshot('pagination-stale-cursor');
    final stalePage = Completer<FFFirestorePage<EventsRecord>>();
    var calls = 0;
    addTearDown(() {
      if (!stalePage.isCompleted) {
        stalePage.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUserDocument = _userFixture(
      uid: 'pagination-stale-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final firstPageEvents = List<EventsRecord>.generate(
      8,
      (index) => _eventsRecordFixture(
        'pagination-stale-$index',
        title: 'Stale base event $index',
        startsAt: DateTime.utc(2035, 6, 14, 15 + index),
      ),
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
          }) {
            calls += 1;
            if (calls == 1) {
              return Future.value(
                FFFirestorePage<EventsRecord>(
                  firstPageEvents,
                  null,
                  marker,
                ),
              );
            }
            if (calls == 2) {
              expect(nextPageMarker, same(marker));
              return stalePage.future;
            }
            return Future.value(
              FFFirestorePage<EventsRecord>(
                [
                  _eventsRecordFixture(
                    'pagination-filter-result',
                    title: 'Active filter result',
                    startsAt: DateTime.utc(2035, 6, 14, 18),
                  ),
                ],
                null,
                null,
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(eventListScrollViewKey),
      const Offset(0, -5000),
    );
    await tester.pump();
    expect(calls, 2);
    expect(find.byKey(eventListPaginationLoadingKey), findsOneWidget);

    await tester.drag(
      find.byKey(eventListScrollViewKey),
      const Offset(0, 5000),
    );
    await tester.pump();
    await tester.tap(_dateFilterFinder(EventListDateFilter.today));
    await tester.pumpAndSettle();

    expect(calls, 3);
    expect(find.text('Active filter result'), findsOneWidget);
    expect(find.byKey(eventListPaginationLoadingKey), findsNothing);

    stalePage.complete(
      FFFirestorePage<EventsRecord>(
        [
          _eventsRecordFixture(
            'pagination-late-result',
            title: 'Late stale page',
            startsAt: DateTime.utc(2035, 6, 14, 19),
          ),
        ],
        null,
        null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active filter result'), findsOneWidget);
    expect(find.text('Late stale page'), findsNothing);
    expect(find.byKey(eventListNoMoreItemsKey), findsNothing);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
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
    expect(find.byKey(eventListCardShellKey), findsOneWidget);
    final beforeRefreshGeometry = _eventCardGeometry(tester);

    await tester.tap(_dateFilterFinder(EventListDateFilter.today));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(eventListErrorStateKey), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(find.byKey(eventListRefreshingIndicatorKey), findsNothing);
    expect(find.byType(UxRefreshingIndicatorPill), findsNothing);
    expect(find.text('Loaded before refresh'), findsOneWidget);
    expect(_eventCardGeometry(tester), beforeRefreshGeometry);

    await tester.tap(find.byKey(eventListErrorRetryButtonKey));
    await tester.pumpAndSettle();

    expect(calls, 3);
    expect(find.byKey(eventListErrorStateKey), findsNothing);
    expect(find.text('Loaded after retry'), findsOneWidget);
    expect(_eventCardGeometry(tester), beforeRefreshGeometry);
    expect(tester.takeException(), isNull);
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
    expect(find.byKey(eventListCardShellKey), findsOneWidget);
    final beforeRefreshGeometry = _eventCardGeometry(tester);

    await tester.tap(_dateFilterFinder(EventListDateFilter.today));
    await tester.pump();

    expect(calls, 2);
    expect(find.byKey(eventListRefreshingIndicatorKey), findsOneWidget);
    expect(find.byType(UxRefreshingIndicatorPill), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(find.text('Loaded before pending'), findsOneWidget);
    expect(_eventCardGeometry(tester), beforeRefreshGeometry);

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
    expect(find.byKey(eventListRefreshingIndicatorKey), findsNothing);
    expect(find.byType(UxRefreshingIndicatorPill), findsNothing);
    expect(_eventCardGeometry(tester), beforeRefreshGeometry);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps loaded event cards visible while level filter is pending',
      (tester) async {
    var calls = 0;
    final levelCompleter = Completer<FFFirestorePage<EventsRecord>>();
    addTearDown(() {
      if (!levelCompleter.isCompleted) {
        levelCompleter.complete(FFFirestorePage<EventsRecord>(
          const [],
          null,
          null,
        ));
      }
    });
    currentUserDocument = _userFixture(
      uid: 'profile-city-pending-level-user',
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
              return levelCompleter.future;
            }
            return FFFirestorePage<EventsRecord>(
              [
                _eventsRecordFixture(
                  calls == 1
                      ? 'loaded-before-level-pending'
                      : 'loaded-after-level-pending',
                  title: calls == 1
                      ? 'Loaded before level pending'
                      : 'Loaded after level pending',
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
    expect(find.text('Loaded before level pending'), findsOneWidget);
    expect(find.byKey(eventListCardShellKey), findsOneWidget);
    final beforeRefreshGeometry = _eventCardGeometry(tester);

    await tester.tap(_levelFilterFinder('B2'));
    await tester.pump();

    expect(calls, 2);
    expect(find.byKey(eventListRefreshingIndicatorKey), findsOneWidget);
    expect(find.byType(UxRefreshingIndicatorPill), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(find.text('Loaded before level pending'), findsOneWidget);
    expect(_eventCardGeometry(tester), beforeRefreshGeometry);

    levelCompleter.complete(FFFirestorePage<EventsRecord>(
      [
        _eventsRecordFixture(
          'loaded-after-level-pending',
          title: 'Loaded after level pending',
          startsAt: DateTime.utc(2035, 6, 14, 15),
        ),
      ],
      null,
      null,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Loaded after level pending'), findsOneWidget);
    expect(find.text('Loaded before level pending'), findsNothing);
    expect(find.byKey(eventListRefreshingIndicatorKey), findsNothing);
    expect(find.byType(UxRefreshingIndicatorPill), findsNothing);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(_eventCardGeometry(tester), beforeRefreshGeometry);
    expect(tester.takeException(), isNull);
  });

  testWidgets('waits for the active filter before showing empty state',
      (tester) async {
    var calls = 0;
    final initialCompleter = Completer<FFFirestorePage<EventsRecord>>();
    final filteredCompleter = Completer<FFFirestorePage<EventsRecord>>();
    addTearDown(() {
      if (!initialCompleter.isCompleted) {
        initialCompleter.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
      if (!filteredCompleter.isCompleted) {
        filteredCompleter.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUserDocument = _userFixture(
      uid: 'profile-city-pending-empty-user',
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
          }) {
            calls += 1;
            return calls == 1
                ? initialCompleter.future
                : filteredCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();

    expect(calls, 1);
    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.byKey(eventListRefreshingIndicatorKey), findsNothing);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);

    initialCompleter.complete(
      FFFirestorePage<EventsRecord>(const [], null, null),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);
    final confirmedEmptySize = tester.getSize(
      find.byKey(eventListEmptyStateKey),
    );

    await tester.tap(_dateFilterFinder(EventListDateFilter.today));
    await tester.pump();

    expect(calls, 2);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.byKey(eventListRefreshingEmptyShellKey), findsOneWidget);
    expect(find.byKey(eventListRefreshingIndicatorKey), findsOneWidget);
    expect(find.byType(UxRefreshingIndicatorPill), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(
      tester.getSize(find.byKey(eventListRefreshingEmptyShellKey)),
      confirmedEmptySize,
    );

    filteredCompleter.complete(
      FFFirestorePage<EventsRecord>(const [], null, null),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);
    expect(find.byKey(eventListRefreshingEmptyShellKey), findsNothing);
    expect(find.byKey(eventListRefreshingIndicatorKey), findsNothing);
    expect(find.byType(UxRefreshingIndicatorPill), findsNothing);
    expect(
        tester.getSize(find.byKey(eventListEmptyStateKey)), confirmedEmptySize);
    expect(calls, 2);
  });

  testWidgets('keeps confirmed empty for the same filter across midnight',
      (tester) async {
    var calls = 0;
    var nowUtc = DateTime.utc(2035, 6, 14, 9);
    final nowUtcProvider = () => nowUtc;
    final refreshCompleter = Completer<FFFirestorePage<EventsRecord>>();
    addTearDown(() {
      if (!refreshCompleter.isCompleted) {
        refreshCompleter.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUserDocument = _userFixture(
      uid: 'profile-city-same-filter-midnight-user',
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
    }) {
      calls += 1;
      if (calls == 3) {
        return refreshCompleter.future;
      }
      return Future.value(
        FFFirestorePage<EventsRecord>(const [], null, null),
      );
    };
    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: nowUtcProvider,
            eventPageLoader: pageLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();
    await tester.tap(_dateFilterFinder(EventListDateFilter.today));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);
    final confirmedEmptySize = tester.getSize(
      find.byKey(eventListEmptyStateKey),
    );

    nowUtc = DateTime.utc(2035, 6, 15, 9);
    await tester.pumpWidget(buildList());
    await tester.pump();

    expect(calls, 3);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);
    expect(find.byKey(eventListRefreshingEmptyShellKey), findsNothing);
    expect(find.byKey(eventListRefreshingIndicatorKey), findsOneWidget);
    expect(find.byType(UxRefreshingIndicatorPill), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(
      tester.getSize(find.byKey(eventListEmptyStateKey)),
      confirmedEmptySize,
    );

    refreshCompleter.complete(
      FFFirestorePage<EventsRecord>(const [], null, null),
    );
    await tester.pumpAndSettle();

    expect(calls, 3);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);
    expect(find.byKey(eventListRefreshingIndicatorKey), findsNothing);
  });

  testWidgets('treats level and city as different active filters',
      (tester) async {
    var calls = 0;
    var selectedCity = _selectedCityFixture();
    final nowUtcProvider = () => DateTime.utc(2035, 6, 14, 9);
    final levelCompleter = Completer<FFFirestorePage<EventsRecord>>();
    final cityCompleter = Completer<FFFirestorePage<EventsRecord>>();
    addTearDown(() {
      if (!levelCompleter.isCompleted) {
        levelCompleter.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
      if (!cityCompleter.isCompleted) {
        cityCompleter.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) {
      calls += 1;
      return switch (calls) {
        1 => Future.value(
            FFFirestorePage<EventsRecord>(const [], null, null),
          ),
        2 => levelCompleter.future,
        3 => cityCompleter.future,
        _ => throw StateError('Unexpected event page request $calls'),
      };
    };
    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: selectedCity,
            nowUtcProvider: nowUtcProvider,
            eventPageLoader: pageLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);

    await tester.tap(_levelFilterFinder('B2'));
    await tester.pump();

    expect(calls, 2);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.byKey(eventListRefreshingEmptyShellKey), findsOneWidget);
    expect(find.byKey(eventListRefreshingIndicatorKey), findsOneWidget);

    levelCompleter.complete(
      FFFirestorePage<EventsRecord>(const [], null, null),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);
    selectedCity = EventSelectedCity(
      city: _catalog.cities.firstWhere(
        (city) => city.cityKey == 'new_york',
      ),
      source: EventCitySelectionSource.manual,
    );
    await tester.pumpWidget(buildList());
    await tester.pump();

    expect(calls, 3);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.byKey(eventListRefreshingEmptyShellKey), findsOneWidget);
    expect(find.byKey(eventListRefreshingIndicatorKey), findsOneWidget);

    cityCompleter.complete(
      FFFirestorePage<EventsRecord>(const [], null, null),
    );
    await tester.pumpAndSettle();

    expect(calls, 3);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);
    expect(find.byKey(eventListRefreshingEmptyShellKey), findsNothing);
    expect(find.byKey(eventListRefreshingIndicatorKey), findsNothing);
  });

  testWidgets('does not carry confirmed empty across user accounts',
      (tester) async {
    var calls = 0;
    final nowUtcProvider = () => DateTime.utc(2035, 6, 14, 9);
    final secondUserCompleter = Completer<FFFirestorePage<EventsRecord>>();
    addTearDown(() {
      if (!secondUserCompleter.isCompleted) {
        secondUserCompleter.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUser = _TestAuthUser('events-empty-account-a');
    currentUserDocument = _userFixture(
      uid: 'events-empty-account-a',
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
    }) {
      calls += 1;
      return calls == 1
          ? Future.value(
              FFFirestorePage<EventsRecord>(const [], null, null),
            )
          : secondUserCompleter.future;
    };
    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: nowUtcProvider,
            eventPageLoader: pageLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);

    currentUser = _TestAuthUser('events-empty-account-b');
    currentUserDocument = _userFixture(
      uid: 'events-empty-account-b',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    await tester.pumpWidget(buildList());
    await tester.pump();

    expect(calls, 2);
    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.byKey(eventListRefreshingEmptyShellKey), findsNothing);
    expect(find.byKey(eventListRefreshingIndicatorKey), findsNothing);

    secondUserCompleter.complete(
      FFFirestorePage<EventsRecord>(const [], null, null),
    );
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);
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

  testWidgets('reloads cached event cards when the clock moves backwards',
      (tester) async {
    var calls = 0;
    var nowUtc = DateTime.utc(2035, 6, 14, 9);
    currentUserDocument = _userFixture(
      uid: 'profile-city-cache-rollback-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final EventListNowProvider nowUtcProvider = () => nowUtc;
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
            'rollback-cached-event',
            title: 'Rollback cached event $calls',
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
            nowUtcProvider: nowUtcProvider,
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: currentUserParticipantLoader,
            activeParticipantsLoader: activeParticipantsLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Rollback cached event 1'), findsOneWidget);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    nowUtc = nowUtc.subtract(const Duration(minutes: 1));
    await tester.pumpWidget(buildList());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Rollback cached event 2'), findsOneWidget);
    expect(find.text('Rollback cached event 1'), findsNothing);
    expect(tester.takeException(), isNull);
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
    expect(find.text('Покинуть'), findsOneWidget);
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

  testWidgets('reuses cached confirmed empty when the page is reopened',
      (tester) async {
    var calls = 0;
    currentUser = _TestAuthUser('profile-city-empty-cache-user');
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
      if (calls > 1) {
        throw StateError('confirmed empty cache must avoid a reload');
      }
      return FFFirestorePage<EventsRecord>(const [], null, null);
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

    expect(calls, 1);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(find.byKey(eventListRefreshingIndicatorKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reloads a confirmed-empty cache entry after its ttl',
      (tester) async {
    var calls = 0;
    var nowUtc = DateTime.utc(2035, 6, 14, 9);
    final refreshCompleter = Completer<FFFirestorePage<EventsRecord>>();
    addTearDown(() {
      if (!refreshCompleter.isCompleted) {
        refreshCompleter.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUser = _TestAuthUser('profile-city-empty-cache-ttl-user');
    currentUserDocument = _userFixture(
      uid: 'profile-city-empty-cache-ttl-user',
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
    }) {
      calls += 1;
      return calls == 1
          ? Future.value(
              FFFirestorePage<EventsRecord>(const [], null, null),
            )
          : refreshCompleter.future;
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
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    nowUtc = nowUtc.add(const Duration(minutes: 4, seconds: 59));
    await tester.pumpWidget(buildList());

    expect(calls, 1);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    nowUtc = nowUtc.add(const Duration(seconds: 1));
    await tester.pumpWidget(buildList());
    await tester.pump();

    expect(calls, 2);
    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);

    refreshCompleter.complete(
      FFFirestorePage<EventsRecord>(
        [
          _eventsRecordFixture(
            'fresh-event-after-empty-cache-ttl',
            title: 'Fresh event after empty cache ttl',
            startsAt: DateTime.utc(2035, 6, 14, 15),
          ),
        ],
        null,
        null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(find.text('Fresh event after empty cache ttl'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event mutation invalidation evicts confirmed empty',
      (tester) async {
    var calls = 0;
    currentUser = _TestAuthUser('event-empty-cache-invalidation-user');
    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) async {
      calls += 1;
      return calls == 1
          ? FFFirestorePage<EventsRecord>(const [], null, null)
          : FFFirestorePage<EventsRecord>(
              [
                _eventsRecordFixture(
                  'event-after-cache-invalidation',
                  title: 'Event after cache invalidation',
                ),
              ],
              null,
              null,
            );
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            initialSelectedCity: _selectedCityFixture(),
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);

    EventListCacheInvalidation.invalidate();
    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
    expect(find.text('Event after cache invalidation'), findsOneWidget);
  });

  testWidgets('does not negative-cache an empty page with a next cursor',
      (tester) async {
    final marker = _FakeQueryDocumentSnapshot('empty-first-page-cursor');
    final pendingNextPage = Completer<FFFirestorePage<EventsRecord>>();
    final receivedMarkers = <DocumentSnapshot?>[];
    addTearDown(() {
      if (!pendingNextPage.isCompleted) {
        pendingNextPage.complete(
          FFFirestorePage<EventsRecord>(const [], null, null),
        );
      }
    });
    currentUser = _TestAuthUser('event-empty-cursor-cache-user');
    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) {
      receivedMarkers.add(nextPageMarker);
      if (nextPageMarker != null) {
        return pendingNextPage.future;
      }
      return Future.value(
        FFFirestorePage<EventsRecord>(const [], null, marker),
      );
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            initialSelectedCity: _selectedCityFixture(),
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(receivedMarkers, <DocumentSnapshot?>[null, marker]);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());

    expect(receivedMarkers, <DocumentSnapshot?>[null, marker, null]);
    expect(find.byKey(eventListLoadingStateKey), findsOneWidget);
  });

  testWidgets('does not negative-cache raw events that produce no cards',
      (tester) async {
    var calls = 0;
    currentUser = _TestAuthUser('event-invalid-raw-cache-user');
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
            calls == 1 ? 'raw-event-without-start' : 'fresh-valid-event',
            title: calls == 1 ? 'Invalid raw event' : 'Fresh valid event',
            includeStartsAt: calls != 1,
          ),
        ],
        null,
        null,
      );
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            initialSelectedCity: _selectedCityFixture(),
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Fresh valid event'), findsOneWidget);
    expect(find.byKey(eventListEmptyStateKey), findsNothing);
  });

  testWidgets('does not negative-cache a failed first page', (tester) async {
    var calls = 0;
    currentUser = _TestAuthUser('event-error-cache-user');
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
        throw StateError('first page failed');
      }
      return FFFirestorePage<EventsRecord>(const [], null, null);
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            initialSelectedCity: _selectedCityFixture(),
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byKey(eventListErrorStateKey), findsOneWidget);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(eventListErrorStateKey), findsNothing);
    expect(find.byKey(eventListEmptyStateKey), findsOneWidget);
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

  testWidgets('refreshing state keeps provided event cards visible',
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

    expect(find.byKey(eventListRefreshingIndicatorKey), findsOneWidget);
    expect(find.byType(UxRefreshingIndicatorPill), findsOneWidget);
    expect(find.byKey(eventListLoadingStateKey), findsNothing);
    expect(find.byKey(eventListCardShellKey), findsOneWidget);
    expect(find.text('Реальное событие'), findsOneWidget);

    final refreshOverlay = tester.widget<UxRefreshingIndicatorOverlay>(
      find.byKey(eventListRefreshingIndicatorKey),
    );
    expect(refreshOverlay.semanticsLabel, 'Обновляем события');
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
    'keeps card and avatar slots stable while participants enrich',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final participantsCompleter = Completer<List<EventParticipantsRecord>>();
      addTearDown(() {
        if (!participantsCompleter.isCompleted) {
          participantsCompleter.complete(const <EventParticipantsRecord>[]);
        }
      });
      var participantLookups = 0;

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
              return FFFirestorePage<EventsRecord>(
                [
                  _eventsRecordFixture(
                    'progressive-participants-event',
                    title: 'Progressive participants event',
                    startsAt: DateTime.utc(2035, 6, 14, 15),
                  ),
                ],
                null,
                null,
              );
            },
            activeParticipantsLoader: (eventRef) {
              participantLookups += 1;
              return participantsCompleter.future;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(participantLookups, 1);
      expect(find.text('Progressive participants event'), findsOneWidget);
      expect(find.byKey(eventListLoadingStateKey), findsNothing);
      final beforeGeometry = _eventCardGeometry(tester);
      final beforeStack =
          tester.getRect(find.byKey(eventListParticipantAvatarStackKey));
      final beforeSlots = _participantAvatarSlotRects(tester, count: 6);
      final beforeOrganizer =
          tester.getRect(find.byKey(eventListCardOrganizerAvatarKey));

      final eventRef = EventsRecord.collection.doc(
        'progressive-participants-event',
      );
      participantsCompleter.complete([
        _eventParticipantRecordFixture(
          eventRef,
          userId: 'organizer-user',
          displayName: 'Анастасия Иванова',
          role: 'organizer',
          joinedAt: DateTime.utc(2035, 6, 14, 8),
        ),
        _eventParticipantRecordFixture(
          eventRef,
          userId: 'participant-marco',
          displayName: 'Marco Rossi',
          photoUrl: 'not-a-valid-url',
          joinedAt: DateTime.utc(2035, 6, 14, 9),
        ),
        _eventParticipantRecordFixture(
          eventRef,
          userId: 'participant-liza',
          displayName: 'Лиза',
          joinedAt: DateTime.utc(2035, 6, 14, 10),
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('M'), findsOneWidget);
      expect(find.text('Л'), findsOneWidget);
      final participantImageFinder = find.descendant(
        of: _participantAvatarFinder(1),
        matching: find.byType(CachedNetworkImage),
      );
      expect(participantImageFinder, findsOneWidget);
      final participantImage =
          tester.widget<CachedNetworkImage>(participantImageFinder);
      expect(participantImage.width, 24);
      expect(participantImage.height, 24);
      final participantImageRect = tester.getRect(participantImageFinder);
      expect(_eventCardGeometry(tester), beforeGeometry);
      expect(
        tester.getRect(find.byKey(eventListParticipantAvatarStackKey)),
        beforeStack,
      );
      expect(_participantAvatarSlotRects(tester, count: 6), beforeSlots);
      expect(
        tester.getRect(find.byKey(eventListCardOrganizerAvatarKey)),
        beforeOrganizer,
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(_eventCardGeometry(tester), beforeGeometry);
      expect(_participantAvatarSlotRects(tester, count: 6), beforeSlots);
      expect(tester.getRect(participantImageFinder), participantImageRect);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keeps participant stack width stable without count or capacity',
    (tester) async {
      final participantsCompleter = Completer<List<EventParticipantsRecord>>();
      addTearDown(() {
        if (!participantsCompleter.isCompleted) {
          participantsCompleter.complete(const <EventParticipantsRecord>[]);
        }
      });

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
              return FFFirestorePage<EventsRecord>(
                [
                  _eventsRecordFixture(
                    'unknown-participant-total-event',
                    title: 'Unknown participant total event',
                    startsAt: DateTime.utc(2035, 6, 14, 15),
                    includeCapacity: false,
                    includeParticipantsCount: false,
                  ),
                ],
                null,
                null,
              );
            },
            activeParticipantsLoader: (_) => participantsCompleter.future,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Unknown participant total event'), findsOneWidget);
      final beforeGeometry = _eventCardGeometry(tester);
      final beforeStack =
          tester.getRect(find.byKey(eventListParticipantAvatarStackKey));
      final beforeOrganizerSlot = tester.getRect(_participantAvatarFinder(0));

      final eventRef =
          EventsRecord.collection.doc('unknown-participant-total-event');
      participantsCompleter.complete([
        _eventParticipantRecordFixture(
          eventRef,
          userId: 'organizer-user',
          displayName: 'Анастасия Иванова',
          role: 'organizer',
          joinedAt: DateTime.utc(2035, 6, 14, 8),
        ),
        _eventParticipantRecordFixture(
          eventRef,
          userId: 'participant-marco',
          displayName: 'Marco',
          joinedAt: DateTime.utc(2035, 6, 14, 9),
        ),
        _eventParticipantRecordFixture(
          eventRef,
          userId: 'participant-liza',
          displayName: 'Лиза',
          joinedAt: DateTime.utc(2035, 6, 14, 10),
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('M'), findsOneWidget);
      expect(find.text('Л'), findsOneWidget);
      expect(_eventCardGeometry(tester), beforeGeometry);
      expect(
        tester.getRect(find.byKey(eventListParticipantAvatarStackKey)),
        beforeStack,
      );
      expect(tester.getRect(_participantAvatarFinder(0)), beforeOrganizerSlot);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keeps a known participant fallback stable while its profile loads',
    (tester) async {
      const participantId = 'known-fallback-participant';
      _setEventProfileFallbackViewer('known-fallback-viewer');
      final profilesCompleter = Completer<UserPublicProfilePreloadResult>();
      addTearDown(() {
        if (!profilesCompleter.isCompleted) {
          profilesCompleter.complete(UserPublicProfilePreloadResult());
        }
      });
      final profileRequests = <Set<String>>[];

      await tester.pumpWidget(
        _buildEventProfileFallbackTestApp(
          eventId: 'known-fallback-event',
          activeParticipantsLoader: (eventRef) async => [
            _eventParticipantIdentityRecordFixture(
              eventRef,
              documentId: participantId,
              storedUserId: participantId,
            ),
          ],
          publicProfilesLoader: (userIds) {
            profileRequests.add(userIds.toSet());
            return profilesCompleter.future;
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(profileRequests, [
        <String>{participantId}
      ]);
      _expectGenericParticipantAvatar(0);
      final beforeSlot = tester.getRect(_participantAvatarFinder(0));
      expect(beforeSlot.size, const Size.square(24));
      final beforeCard = _eventCardGeometry(tester);
      final beforeStack =
          tester.getRect(find.byKey(eventListParticipantAvatarStackKey));
      final beforeSlots = _participantAvatarSlotRects(tester, count: 6);
      final beforeSemantics = _participantAvatarImageSemanticsNode(tester, 0);
      expect(beforeSemantics.flagsCollection.isImage, isTrue);
      expect(beforeSemantics.label, isNotEmpty);
      expect(beforeSemantics.label, isNot(contains(participantId)));
      final beforeSemanticsId = beforeSemantics.id;
      final beforeSemanticsRect = beforeSemantics.rect;

      profilesCompleter.complete(
        UserPublicProfilePreloadResult(
          profilesByUserId: {
            participantId: _userPublicProfileFixture(
              participantId,
              displayName: 'Marco',
            ),
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      final participantSlot = _participantAvatarFinder(0);
      expect(
        find.descendant(of: participantSlot, matching: find.text('M')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: participantSlot,
          matching: find.byIcon(Icons.person_outline),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: participantSlot,
          matching: find.byType(CachedNetworkImage),
        ),
        findsNothing,
      );
      expect(tester.getRect(participantSlot), beforeSlot);
      expect(_eventCardGeometry(tester), beforeCard);
      expect(
        tester.getRect(find.byKey(eventListParticipantAvatarStackKey)),
        beforeStack,
      );
      expect(_participantAvatarSlotRects(tester, count: 6), beforeSlots);
      final afterSemantics = _participantAvatarImageSemanticsNode(tester, 0);
      expect(afterSemantics.id, beforeSemanticsId);
      expect(afterSemantics.rect, beforeSemanticsRect);
      expect(afterSemantics.flagsCollection.isImage, isTrue);
      expect(afterSemantics.label, isNotEmpty);
      expect(afterSemantics.label, isNot(contains(participantId)));
      expect(tester.takeException(), isNull);
    },
  );

  for (final invisibleName in <String, String>{
    'zero-width controls': '\u200B\u2060\uFEFF',
    'braille blank': '\u2800',
    'supplementary controls': '\u{E0001}\u{E0100}',
  }.entries) {
    testWidgets(
      'keeps the known fallback icon for ${invisibleName.key}',
      (tester) async {
        final participantId =
            'invisible-profile-participant-${invisibleName.key}';
        _setEventProfileFallbackViewer(
          'invisible-profile-viewer-${invisibleName.key}',
        );

        await tester.pumpWidget(
          _buildEventProfileFallbackTestApp(
            eventId: 'invisible-profile-event-${invisibleName.key}',
            activeParticipantsLoader: (eventRef) async => [
              _eventParticipantIdentityRecordFixture(
                eventRef,
                documentId: participantId,
                storedUserId: participantId,
              ),
            ],
            publicProfilesLoader: (_) async => UserPublicProfilePreloadResult(
              profilesByUserId: {
                participantId: _userPublicProfileFixture(
                  participantId,
                  displayName: invisibleName.value,
                ),
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        _expectGenericParticipantAvatar(0);
        final semantics = _participantAvatarImageSemanticsNode(tester, 0);
        expect(semantics.flagsCollection.isImage, isTrue);
        expect(semantics.label, isNotEmpty);
        expect(semantics.label, isNot(contains(participantId)));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final failureMode in <String>['missing', 'failed', 'throw']) {
    testWidgets(
      '$failureMode public profile result preserves a known fallback',
      (tester) async {
        final participantId = '$failureMode-known-fallback-participant';
        _setEventProfileFallbackViewer('$failureMode-fallback-viewer');
        final profilesCompleter = Completer<UserPublicProfilePreloadResult>();
        addTearDown(() {
          if (!profilesCompleter.isCompleted) {
            profilesCompleter.complete(UserPublicProfilePreloadResult());
          }
        });

        await tester.pumpWidget(
          _buildEventProfileFallbackTestApp(
            eventId: '$failureMode-known-fallback-event',
            activeParticipantsLoader: (eventRef) async => [
              _eventParticipantIdentityRecordFixture(
                eventRef,
                documentId: participantId,
                storedUserId: participantId,
              ),
            ],
            publicProfilesLoader: (_) => profilesCompleter.future,
          ),
        );
        await tester.pump();
        await tester.pump();

        _expectGenericParticipantAvatar(0);
        final beforeCard = _eventCardGeometry(tester);
        final beforeStack =
            tester.getRect(find.byKey(eventListParticipantAvatarStackKey));
        final beforeSlots = _participantAvatarSlotRects(tester, count: 6);
        final beforeSemantics = _participantAvatarImageSemanticsNode(tester, 0);
        final beforeSemanticsId = beforeSemantics.id;
        final beforeSemanticsLabel = beforeSemantics.label;
        final beforeSemanticsRect = beforeSemantics.rect;

        if (failureMode == 'throw') {
          profilesCompleter.completeError(
            StateError('public profile failed'),
          );
        } else {
          profilesCompleter.complete(
            UserPublicProfilePreloadResult(
              missingUserIds: failureMode == 'missing'
                  ? <String>{participantId}
                  : const <String>{},
              failedUserIds: failureMode == 'failed'
                  ? <String>{participantId}
                  : const <String>{},
            ),
          );
        }
        await tester.pump();
        await tester.pump();

        _expectGenericParticipantAvatar(0);
        expect(_eventCardGeometry(tester), beforeCard);
        expect(
          tester.getRect(find.byKey(eventListParticipantAvatarStackKey)),
          beforeStack,
        );
        expect(_participantAvatarSlotRects(tester, count: 6), beforeSlots);
        final afterSemantics = _participantAvatarImageSemanticsNode(tester, 0);
        expect(afterSemantics.id, beforeSemanticsId);
        expect(afterSemantics.label, beforeSemanticsLabel);
        expect(afterSemantics.rect, beforeSemanticsRect);
        expect(afterSemantics.flagsCollection.isImage, isTrue);
        expect(afterSemantics.label, isNot(contains(participantId)));
        expect(find.byKey(eventListErrorStateKey), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'uses participant document ids for fallback and profile identity',
    (tester) async {
      const canonicalId = 'canonical-participant';
      const missingFieldId = 'missing-field-participant';
      const spoofedId = 'spoofed-profile-id';
      _setEventProfileFallbackViewer('canonical-identity-viewer');
      final profileRequests = <Set<String>>[];

      await tester.pumpWidget(
        _buildEventProfileFallbackTestApp(
          eventId: 'canonical-identity-event',
          activeParticipantsLoader: (eventRef) async => [
            _eventParticipantIdentityRecordFixture(
              eventRef,
              documentId: canonicalId,
              storedUserId: spoofedId,
              joinedAt: DateTime.utc(2035, 6, 14, 8),
            ),
            _eventParticipantIdentityRecordFixture(
              eventRef,
              documentId: missingFieldId,
              joinedAt: DateTime.utc(2035, 6, 14, 9),
            ),
          ],
          publicProfilesLoader: (userIds) async {
            final requested = userIds.toSet();
            profileRequests.add(requested);
            return UserPublicProfilePreloadResult(
              missingUserIds: requested,
            );
          },
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(profileRequests, [
        <String>{canonicalId, missingFieldId}
      ]);
      expect(
        profileRequests.expand((request) => request),
        isNot(contains(spoofedId)),
      );
      for (var index = 0; index < 2; index += 1) {
        _expectGenericParticipantAvatar(index);
        final semantics = _participantAvatarImageSemanticsNode(tester, index);
        expect(semantics.flagsCollection.isImage, isTrue);
        expect(semantics.label, isNotEmpty);
        expect(semantics.label, isNot(contains(canonicalId)));
        expect(semantics.label, isNot(contains(missingFieldId)));
        expect(semantics.label, isNot(contains(spoofedId)));
      }
      expect(find.byKey(eventListErrorStateKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keeps count-only and reserved slots out of participant semantics',
    (tester) async {
      const participantId = 'semantic-known-participant';

      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            eventCardsOverride: [
              _eventCardFixture(
                participants: const [
                  EventListParticipantViewModel(
                    userId: participantId,
                    displayName: '',
                  ),
                ],
                participantsCount: 3,
                capacity: 5,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      _expectGenericParticipantAvatar(0);
      final knownSemantics = _participantAvatarImageSemanticsNode(tester, 0);
      expect(knownSemantics.flagsCollection.isImage, isTrue);
      expect(knownSemantics.label, isNotEmpty);
      expect(knownSemantics.label, isNot(contains(participantId)));
      for (var index = 1; index < 5; index += 1) {
        expect(_participantAvatarImageSemanticsFinder(index), findsNothing);
        expect(tester.getRect(_participantAvatarFinder(index)).size,
            const Size.square(24));
      }
      expect(
        _participantPlaceholderFillColor(tester, 1),
        ExpatlioDesign.avatarFallbackBackground,
      );
      expect(
        _participantPlaceholderFillColor(tester, 2),
        ExpatlioDesign.avatarFallbackBackground,
      );
      expect(
        _participantPlaceholderFillColor(tester, 3),
        ExpatlioDesign.card,
      );
      expect(
        _participantPlaceholderFillColor(tester, 4),
        ExpatlioDesign.card,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preloads visible participant profiles before membership finishes',
    (tester) async {
      currentUser = _TestAuthUser('profile-preload-viewer');
      currentUserDocument = _userFixture(
        uid: 'profile-preload-viewer',
        data: {
          'display_name': 'Current Viewer',
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      final membershipCompleter = Completer<EventParticipantsRecord?>();
      final profilesCompleter = Completer<UserPublicProfilePreloadResult>();
      addTearDown(() {
        if (!membershipCompleter.isCompleted) {
          membershipCompleter.complete(null);
        }
        if (!profilesCompleter.isCompleted) {
          profilesCompleter.complete(UserPublicProfilePreloadResult());
        }
      });
      final profileRequests = <Set<String>>[];

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
              return FFFirestorePage<EventsRecord>(
                [
                  _eventsRecordFixture(
                    'profile-preload-event',
                    title: 'Profile preload event',
                    startsAt: DateTime.utc(2035, 6, 14, 15),
                  ),
                ],
                null,
                null,
              );
            },
            currentUserParticipantLoader: (_, __) => membershipCompleter.future,
            activeParticipantsLoader: (eventRef) async => [
              _eventParticipantRecordFixture(
                eventRef,
                userId: 'organizer-user',
                displayName: 'Snapshot Organizer',
                role: 'organizer',
                joinedAt: DateTime.utc(2035, 6, 14, 8),
              ),
              _eventParticipantRecordFixture(
                eventRef,
                userId: 'profile-participant',
                displayName: 'Snapshot Person',
                joinedAt: DateTime.utc(2035, 6, 14, 9),
              ),
            ],
            publicProfilesLoader: (userIds) {
              profileRequests.add(userIds.toSet());
              return profilesCompleter.future;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(profileRequests, [
        <String>{'organizer-user', 'profile-participant'},
      ]);
      expect(membershipCompleter.isCompleted, isFalse);
      expect(find.text('Проверяем участие'), findsOneWidget);

      final eventRef = EventsRecord.collection.doc('profile-preload-event');
      membershipCompleter.complete(
        _eventParticipantRecordFixture(
          eventRef,
          userId: 'profile-preload-viewer',
          displayName: 'Viewer Snapshot',
          joinedAt: DateTime.utc(2035, 6, 14, 10),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(profileRequests, [
        <String>{'organizer-user', 'profile-participant'},
        <String>{'profile-preload-viewer'},
      ]);
      expect(
        find.descendant(
          of: _participantAvatarFinder(1),
          matching: find.text('S'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _participantAvatarFinder(1),
          matching: find.text('P'),
        ),
        findsNothing,
      );
      expect(find.text('Покинуть'), findsOneWidget);
      final beforeGeometry = _eventCardGeometry(tester);
      final beforeStack =
          tester.getRect(find.byKey(eventListParticipantAvatarStackKey));
      final beforeSlots = _participantAvatarSlotRects(tester, count: 3);

      profilesCompleter.complete(
        UserPublicProfilePreloadResult(
          profilesByUserId: {
            'organizer-user': _userPublicProfileFixture(
              'organizer-user',
              displayName: 'Organizer Public',
            ),
            'profile-participant': _userPublicProfileFixture(
              'profile-participant',
              displayName: 'Profile Person',
              photoUrl: 'not-a-valid-profile-url',
            ),
            'profile-preload-viewer': _userPublicProfileFixture(
              'profile-preload-viewer',
              displayName: 'Hydrated Viewer',
            ),
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(
          of: _participantAvatarFinder(1),
          matching: find.text('S'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _participantAvatarFinder(1),
          matching: find.text('P'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _participantAvatarFinder(2),
          matching: find.text('H'),
        ),
        findsOneWidget,
      );
      final profileImageFinder = find.descendant(
        of: _participantAvatarFinder(1),
        matching: find.byType(CachedNetworkImage),
      );
      expect(profileImageFinder, findsOneWidget);
      expect(
        tester.widget<CachedNetworkImage>(profileImageFinder).imageUrl,
        'not-a-valid-profile-url',
      );
      expect(_eventCardGeometry(tester), beforeGeometry);
      expect(
        tester.getRect(find.byKey(eventListParticipantAvatarStackKey)),
        beforeStack,
      );
      expect(_participantAvatarSlotRects(tester, count: 3), beforeSlots);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'caps two full-card profile reads when pending membership changes a visible slot',
    (tester) async {
      currentUser = _TestAuthUser('profile-budget-viewer');
      currentUserDocument = _userFixture(
        uid: 'profile-budget-viewer',
        data: {
          'display_name': 'Budget Viewer',
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      final membershipCompleter = Completer<EventParticipantsRecord?>();
      addTearDown(() {
        if (!membershipCompleter.isCompleted) {
          membershipCompleter.complete(null);
        }
      });
      final profileRequests = <List<String>>[];

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
              return FFFirestorePage<EventsRecord>(
                [
                  for (var cardIndex = 0; cardIndex < 2; cardIndex += 1)
                    _eventsRecordFixture(
                      'profile-budget-event-$cardIndex',
                      title: 'Profile budget event $cardIndex',
                      startsAt: DateTime.utc(2035, 6, 14, 15 + cardIndex),
                    ),
                ],
                null,
                null,
              );
            },
            currentUserParticipantLoader: (eventRef, _) {
              if (eventRef.id == 'profile-budget-event-0') {
                return membershipCompleter.future;
              }
              return Future<EventParticipantsRecord?>.value(null);
            },
            activeParticipantsLoader: (eventRef) async {
              final cardIndex = int.parse(eventRef.id.split('-').last);
              return [
                for (var participantIndex = 0;
                    participantIndex < 6;
                    participantIndex += 1)
                  _eventParticipantRecordFixture(
                    eventRef,
                    userId: 'profile-budget-$cardIndex-$participantIndex',
                    displayName:
                        'Budget $cardIndex participant $participantIndex',
                    joinedAt: DateTime.utc(2035, 6, 14, 10)
                        .add(Duration(minutes: participantIndex)),
                  ),
              ];
            },
            publicProfilesLoader: (userIds) async {
              final requested = List<String>.of(userIds);
              profileRequests.add(requested);
              return UserPublicProfilePreloadResult(
                profilesByUserId: {
                  for (final userId in requested)
                    userId: _userPublicProfileFixture(userId),
                },
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final expectedEarlyUserIds = <String>{
        for (var cardIndex = 0; cardIndex < 2; cardIndex += 1)
          for (var participantIndex = 0;
              participantIndex < 5;
              participantIndex += 1)
            'profile-budget-$cardIndex-$participantIndex',
      };
      expect(membershipCompleter.isCompleted, isFalse);
      expect(profileRequests, hasLength(1));
      expect(profileRequests.single, hasLength(10));
      expect(profileRequests.single.toSet(), expectedEarlyUserIds);

      final firstEventRef =
          EventsRecord.collection.doc('profile-budget-event-0');
      membershipCompleter.complete(
        _eventParticipantRecordFixture(
          firstEventRef,
          userId: 'profile-budget-viewer',
          displayName: 'Budget Viewer',
          joinedAt: DateTime.utc(2035, 6, 14, 12),
        ),
      );
      await tester.pumpAndSettle();

      final expectedAdditionalUserIds = <String>{
        'profile-budget-viewer',
        'profile-budget-1-5',
      };
      final expectedFinalVisibleUserIds = <String>{
        for (var participantIndex = 0;
            participantIndex < 5;
            participantIndex += 1)
          'profile-budget-0-$participantIndex',
        'profile-budget-viewer',
        for (var participantIndex = 0;
            participantIndex < 6;
            participantIndex += 1)
          'profile-budget-1-$participantIndex',
      };
      expect(profileRequests, hasLength(2));
      expect(profileRequests[1], hasLength(2));
      expect(profileRequests[1].toSet(), expectedAdditionalUserIds);
      final requestedUserIds =
          profileRequests.expand((request) => request).toList(growable: false);
      expect(requestedUserIds, hasLength(12));
      expect(requestedUserIds.length, lessThanOrEqualTo(12));
      expect(requestedUserIds.toSet(), expectedFinalVisibleUserIds);
      expect(requestedUserIds.toSet(), hasLength(requestedUserIds.length));
      expect(requestedUserIds, isNot(contains('profile-budget-0-5')));
      expect(find.text('Покинуть'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'starts initial profile preload while an outside-window participant load is pending',
    (tester) async {
      currentUser = _TestAuthUser('early-window-profile-viewer');
      currentUserDocument = _userFixture(
        uid: 'early-window-profile-viewer',
        data: {
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      final outsideParticipantsCompleter =
          Completer<List<EventParticipantsRecord>>();
      addTearDown(() {
        if (!outsideParticipantsCompleter.isCompleted) {
          outsideParticipantsCompleter.complete(
            const <EventParticipantsRecord>[],
          );
        }
      });
      final profileRequests = <Set<String>>[];
      var outsideParticipantLoads = 0;

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
              return FFFirestorePage<EventsRecord>(
                [
                  for (var cardIndex = 0; cardIndex < 3; cardIndex += 1)
                    _eventsRecordFixture(
                      'early-window-event-$cardIndex',
                      title: 'Early window event $cardIndex',
                      startsAt: DateTime.utc(2035, 6, 14, 15)
                          .add(Duration(minutes: cardIndex)),
                    ),
                ],
                null,
                null,
              );
            },
            currentUserParticipantLoader: (_, __) async => null,
            activeParticipantsLoader: (eventRef) {
              final cardIndex = int.parse(eventRef.id.split('-').last);
              if (cardIndex == 2) {
                outsideParticipantLoads += 1;
                return outsideParticipantsCompleter.future;
              }
              return Future<List<EventParticipantsRecord>>.value([
                _eventParticipantRecordFixture(
                  eventRef,
                  userId: 'early-window-user-$cardIndex',
                  displayName: 'Early user $cardIndex',
                  joinedAt: DateTime.utc(2035, 6, 14, 10, cardIndex),
                ),
              ]);
            },
            publicProfilesLoader: (userIds) async {
              final requested = userIds.toSet();
              profileRequests.add(requested);
              return UserPublicProfilePreloadResult(
                profilesByUserId: {
                  for (final userId in requested)
                    userId: _userPublicProfileFixture(userId),
                },
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(outsideParticipantLoads, 1);
      expect(outsideParticipantsCompleter.isCompleted, isFalse);
      expect(profileRequests, [
        <String>{
          'early-window-user-0',
          'early-window-user-1',
        },
      ]);

      final outsideEventRef =
          EventsRecord.collection.doc('early-window-event-2');
      outsideParticipantsCompleter.complete([
        _eventParticipantRecordFixture(
          outsideEventRef,
          userId: 'early-window-user-2',
          displayName: 'Early user 2',
          joinedAt: DateTime.utc(2035, 6, 14, 10, 2),
        ),
      ]);
      await tester.pumpAndSettle();

      expect(profileRequests, hasLength(1));
      expect(find.text('Early window event 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deduplicates profile preload to the first six slots per card',
      (tester) async {
    currentUser = _TestAuthUser('profile-dedup-viewer');
    currentUserDocument = _userFixture(
      uid: 'profile-dedup-viewer',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final profileRequests = <List<String>>[];

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
            return FFFirestorePage<EventsRecord>(
              [
                _eventsRecordFixture(
                  'profile-dedup-a',
                  title: 'Profile dedup A',
                  startsAt: DateTime.utc(2035, 6, 14, 15),
                ),
                _eventsRecordFixture(
                  'profile-dedup-b',
                  title: 'Profile dedup B',
                  startsAt: DateTime.utc(2035, 6, 14, 16),
                ),
              ],
              null,
              null,
            );
          },
          currentUserParticipantLoader: (_, __) async => null,
          activeParticipantsLoader: (eventRef) async {
            final prefix = eventRef.id == 'profile-dedup-a' ? 'a' : 'b';
            return [
              _eventParticipantRecordFixture(
                eventRef,
                userId: 'shared-profile',
                displayName: 'Shared',
                joinedAt: DateTime.utc(2035, 6, 14, 8),
              ),
              for (var index = 1; index <= 6; index += 1)
                _eventParticipantRecordFixture(
                  eventRef,
                  userId: '$prefix-$index',
                  displayName: '$prefix $index',
                  joinedAt: DateTime.utc(2035, 6, 14, 8, index),
                ),
            ];
          },
          publicProfilesLoader: (userIds) async {
            final requested = List<String>.of(userIds);
            profileRequests.add(requested);
            return UserPublicProfilePreloadResult(
              profilesByUserId: {
                for (final userId in requested)
                  userId: _userPublicProfileFixture(userId),
              },
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(profileRequests, hasLength(2));
    expect(profileRequests.first.toSet(), {
      'shared-profile',
      'a-1',
      'a-2',
      'a-3',
      'a-4',
      'b-1',
      'b-2',
      'b-3',
      'b-4',
    });
    expect(profileRequests[1].toSet(), {'a-5', 'b-5'});
    final requestedUserIds =
        profileRequests.expand((request) => request).toList(growable: false);
    expect(requestedUserIds, hasLength(11));
    expect(
      requestedUserIds.where((userId) => userId == 'shared-profile'),
      hasLength(1),
    );
    expect(requestedUserIds.toSet(), {
      'shared-profile',
      'a-1',
      'a-2',
      'a-3',
      'a-4',
      'a-5',
      'b-1',
      'b-2',
      'b-3',
      'b-4',
      'b-5',
    });
    expect(requestedUserIds.toSet(), hasLength(requestedUserIds.length));
    expect(requestedUserIds, isNot(contains('a-6')));
    expect(requestedUserIds, isNot(contains('b-6')));
    expect(find.text('Profile dedup A'), findsOneWidget);
    expect(find.text('Profile dedup B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bounds profile preload to visible card windows while scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      currentUser = _TestAuthUser('bounded-profile-viewer');
      currentUserDocument = _userFixture(
        uid: 'bounded-profile-viewer',
        data: {
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      final profileRequests = <List<String>>[];
      String participantUserId(int cardIndex, int participantIndex) {
        if (cardIndex == 2 && participantIndex == 0) {
          return 'bounded-0-0';
        }
        return 'bounded-$cardIndex-$participantIndex';
      }

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
              return FFFirestorePage<EventsRecord>(
                [
                  for (var cardIndex = 0; cardIndex < 20; cardIndex += 1)
                    _eventsRecordFixture(
                      'bounded-profile-event-$cardIndex',
                      title: 'Bounded profile event $cardIndex',
                      startsAt: DateTime.utc(2035, 6, 14, 15)
                          .add(Duration(minutes: cardIndex)),
                    ),
                ],
                null,
                null,
              );
            },
            currentUserParticipantLoader: (_, __) async => null,
            activeParticipantsLoader: (eventRef) async {
              final cardIndex = int.parse(eventRef.id.split('-').last);
              return [
                for (var participantIndex = 0;
                    participantIndex < 6;
                    participantIndex += 1)
                  _eventParticipantRecordFixture(
                    eventRef,
                    userId: participantUserId(cardIndex, participantIndex),
                    displayName:
                        'Bounded $cardIndex participant $participantIndex',
                    joinedAt: DateTime.utc(2035, 6, 14, 10)
                        .add(Duration(minutes: participantIndex)),
                  ),
              ];
            },
            publicProfilesLoader: (userIds) async {
              final requested = List<String>.of(userIds);
              profileRequests.add(requested);
              return UserPublicProfilePreloadResult(
                profilesByUserId: {
                  for (final userId in requested)
                    userId: _userPublicProfileFixture(userId),
                },
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final expectedEarlyUserIds = <String>{
        for (var cardIndex = 0; cardIndex < 2; cardIndex += 1)
          for (var participantIndex = 0;
              participantIndex < 5;
              participantIndex += 1)
            participantUserId(cardIndex, participantIndex),
      };
      final expectedPostMembershipUserIds = <String>{
        for (var cardIndex = 0; cardIndex < 2; cardIndex += 1)
          participantUserId(cardIndex, 5),
      };
      final expectedInitialUserIds = <String>{
        for (var cardIndex = 0; cardIndex < 2; cardIndex += 1)
          for (var participantIndex = 0;
              participantIndex < 6;
              participantIndex += 1)
            participantUserId(cardIndex, participantIndex),
      };
      final allUserIds = <String>{
        for (var cardIndex = 0; cardIndex < 20; cardIndex += 1)
          for (var participantIndex = 0;
              participantIndex < 6;
              participantIndex += 1)
            participantUserId(cardIndex, participantIndex),
      };

      expect(profileRequests, hasLength(2));
      expect(profileRequests.first, hasLength(10));
      expect(profileRequests.first.toSet(), expectedEarlyUserIds);
      expect(profileRequests[1], hasLength(2));
      expect(profileRequests[1].toSet(), expectedPostMembershipUserIds);
      final initialRequestCount = profileRequests.length;
      final initialUserIds =
          profileRequests.expand((request) => request).toList(growable: false);
      expect(initialUserIds, hasLength(12));
      expect(initialUserIds.toSet(), expectedInitialUserIds);
      expect(initialUserIds.toSet(), hasLength(initialUserIds.length));
      expect(initialUserIds.toSet(), isNot(allUserIds));

      final position = _eventListScrollPosition(tester);
      final viewport = position.viewportDimension;
      expect(viewport, greaterThan(1));
      expect(position.maxScrollExtent, greaterThanOrEqualTo(viewport * 2));

      position.jumpTo(viewport - 1);
      await tester.pumpAndSettle();
      expect(profileRequests, hasLength(initialRequestCount));

      position.jumpTo(viewport);
      await tester.pumpAndSettle();

      final expectedFirstWindowUserIds = <String>{
        for (var cardIndex = 2; cardIndex < 4; cardIndex += 1)
          for (var participantIndex = 0;
              participantIndex < 6;
              participantIndex += 1)
            participantUserId(cardIndex, participantIndex),
      }.difference(expectedInitialUserIds);
      expect(profileRequests, hasLength(initialRequestCount + 1));
      expect(profileRequests[initialRequestCount], hasLength(11));
      expect(
        profileRequests[initialRequestCount].toSet(),
        expectedFirstWindowUserIds,
      );
      expect(
        profileRequests[initialRequestCount],
        isNot(contains('bounded-0-0')),
      );
      expect(
        profileRequests[initialRequestCount].length,
        lessThanOrEqualTo(12),
      );

      position.jumpTo((viewport * 2) - 1);
      await tester.pumpAndSettle();
      expect(profileRequests, hasLength(initialRequestCount + 1));

      position.jumpTo(viewport * 2);
      await tester.pumpAndSettle();

      final expectedSecondWindowUserIds = <String>{
        for (var cardIndex = 4; cardIndex < 6; cardIndex += 1)
          for (var participantIndex = 0;
              participantIndex < 6;
              participantIndex += 1)
            participantUserId(cardIndex, participantIndex),
      };
      expect(profileRequests, hasLength(initialRequestCount + 2));
      expect(profileRequests[initialRequestCount + 1], hasLength(12));
      expect(
        profileRequests[initialRequestCount + 1].toSet(),
        expectedSecondWindowUserIds,
      );
      expect(
        profileRequests[initialRequestCount + 1].length,
        lessThanOrEqualTo(12),
      );

      final requestedUserIds =
          profileRequests.expand((request) => request).toList(growable: false);
      final expectedRequestedUserIds = <String>{
        ...expectedInitialUserIds,
        ...expectedFirstWindowUserIds,
        ...expectedSecondWindowUserIds,
      };
      expect(requestedUserIds, hasLength(35));
      expect(requestedUserIds.toSet(), expectedRequestedUserIds);
      expect(requestedUserIds.toSet(), hasLength(requestedUserIds.length));
      expect(requestedUserIds.toSet().difference(allUserIds), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reopens a cached hydrated prefix and requests only the next scroll window',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      currentUser = _TestAuthUser('cached-prefix-profile-viewer');
      currentUserDocument = _userFixture(
        uid: 'cached-prefix-profile-viewer',
        data: {
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      var pageLoads = 0;
      final profileRequests = <Set<String>>[];
      final EventListNowProvider nowUtcProvider =
          () => DateTime.utc(2035, 6, 14, 9);
      final EventListPageLoader pageLoader = (
        collection,
        recordBuilder, {
        queryBuilder,
        nextPageMarker,
        required pageSize,
        required isStream,
      }) async {
        pageLoads += 1;
        return FFFirestorePage<EventsRecord>(
          [
            for (var cardIndex = 0; cardIndex < 8; cardIndex += 1)
              _eventsRecordFixture(
                'cached-prefix-event-$cardIndex',
                title: 'Cached prefix event $cardIndex',
                startsAt: DateTime.utc(2035, 6, 14, 15)
                    .add(Duration(minutes: cardIndex)),
              ),
          ],
          null,
          null,
        );
      };
      final EventListCurrentUserParticipantLoader membershipLoader =
          (_, __) async => null;
      final EventListActiveParticipantsLoader participantsLoader =
          (eventRef) async {
        final cardIndex = int.parse(eventRef.id.split('-').last);
        return [
          _eventParticipantRecordFixture(
            eventRef,
            userId: 'cached-prefix-user-$cardIndex',
            displayName: 'Cached user $cardIndex',
            joinedAt: DateTime.utc(2035, 6, 14, 10, cardIndex),
          ),
        ];
      };
      final EventListPublicProfilesLoader profilesLoader = (userIds) async {
        final requested = userIds.toSet();
        profileRequests.add(requested);
        return UserPublicProfilePreloadResult(
          profilesByUserId: {
            for (final userId in requested)
              userId: _userPublicProfileFixture(userId),
          },
        );
      };

      Widget buildList() => _buildTestApp(
            home: EventListWidget(
              key: const ValueKey<String>('cached-prefix-profile-list'),
              cityCatalogOverride: _catalog,
              languageCatalogOverride: _languageCatalog,
              initialSelectedCity: _selectedCityFixture(),
              nowUtcProvider: nowUtcProvider,
              eventPageLoader: pageLoader,
              currentUserParticipantLoader: membershipLoader,
              activeParticipantsLoader: participantsLoader,
              publicProfilesLoader: profilesLoader,
            ),
          );

      await tester.pumpWidget(buildList());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(pageLoads, 1);
      expect(profileRequests, [
        <String>{
          'cached-prefix-user-0',
          'cached-prefix-user-1',
        },
      ]);

      await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(buildList());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(pageLoads, 1);
      expect(profileRequests, hasLength(1));

      final position = _eventListScrollPosition(tester);
      final viewport = position.viewportDimension;
      expect(position.maxScrollExtent, greaterThanOrEqualTo(viewport));
      position.jumpTo(viewport);
      await tester.pumpAndSettle();

      expect(pageLoads, 1);
      expect(profileRequests, [
        <String>{
          'cached-prefix-user-0',
          'cached-prefix-user-1',
        },
        <String>{
          'cached-prefix-user-2',
          'cached-prefix-user-3',
        },
      ]);
      final requestedUserIds =
          profileRequests.expand((request) => request).toList(growable: false);
      expect(requestedUserIds.toSet(), hasLength(requestedUserIds.length));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'treats participant user ids as opaque when preloading profiles',
    (tester) async {
      currentUser = _TestAuthUser('opaque-profile-viewer');
      currentUserDocument = _userFixture(
        uid: 'opaque-profile-viewer',
        data: {
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      final profileRequests = <List<String>>[];

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
              return FFFirestorePage<EventsRecord>(
                [
                  _eventsRecordFixture(
                    'opaque-profile-event',
                    title: 'Opaque profile event',
                    startsAt: DateTime.utc(2035, 6, 14, 15),
                  ),
                ],
                null,
                null,
              );
            },
            currentUserParticipantLoader: (_, __) async => null,
            activeParticipantsLoader: (eventRef) async => [
              _eventParticipantRecordFixture(
                eventRef,
                userId: 'alice',
                displayName: 'Alice Snapshot',
                joinedAt: DateTime.utc(2035, 6, 14, 8),
              ),
              _eventParticipantRecordFixture(
                eventRef,
                userId: 'alice ',
                displayName: 'Whitespace Snapshot',
                joinedAt: DateTime.utc(2035, 6, 14, 9),
              ),
            ],
            publicProfilesLoader: (userIds) async {
              final requested = List<String>.of(userIds);
              profileRequests.add(requested);
              return UserPublicProfilePreloadResult(
                profilesByUserId: {
                  'alice': _userPublicProfileFixture(
                    'alice',
                    displayName: 'Hydrated Alice',
                  ),
                },
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        profileRequests.expand((request) => request),
        orderedEquals(<String>['alice']),
      );
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('H'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _participantAvatarFinder(1),
          matching: find.text('W'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _participantAvatarFinder(1),
          matching: find.text('H'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'does not trim or hydrate an edge-whitespace organizer fallback id',
    (tester) async {
      currentUser = _TestAuthUser('opaque-organizer-viewer');
      currentUserDocument = _userFixture(
        uid: 'opaque-organizer-viewer',
        data: {
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      final profileRequests = <Set<String>>[];

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
              return FFFirestorePage<EventsRecord>(
                [
                  _eventsRecordFixture(
                    'opaque-organizer-event',
                    title: 'Opaque organizer event',
                    startsAt: DateTime.utc(2035, 6, 14, 15),
                    organizerId: 'alice ',
                    organizerDisplayName: 'Whitespace Organizer',
                  ),
                ],
                null,
                null,
              );
            },
            currentUserParticipantLoader: (_, __) async => null,
            activeParticipantsLoader: (_) async =>
                const <EventParticipantsRecord>[],
            publicProfilesLoader: (userIds) async {
              profileRequests.add(userIds.toSet());
              return UserPublicProfilePreloadResult(
                profilesByUserId: {
                  'alice': _userPublicProfileFixture(
                    'alice',
                    displayName: 'Hydrated Alice',
                  ),
                },
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(profileRequests, isEmpty);
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('W'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('H'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'replaces hydrated cards when the public profile loader identity changes',
    (tester) async {
      currentUser = _TestAuthUser('profile-loader-identity-viewer');
      currentUserDocument = _userFixture(
        uid: 'profile-loader-identity-viewer',
        data: {
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      var pageLoads = 0;
      var firstProfileLoads = 0;
      var secondProfileLoads = 0;
      final EventListNowProvider nowUtcProvider =
          () => DateTime.utc(2035, 6, 14, 9);
      final EventListPageLoader pageLoader = (
        collection,
        recordBuilder, {
        queryBuilder,
        nextPageMarker,
        required pageSize,
        required isStream,
      }) async {
        pageLoads += 1;
        return FFFirestorePage<EventsRecord>(
          [
            _eventsRecordFixture(
              'profile-loader-identity-event',
              title: 'Profile loader identity event',
              startsAt: DateTime.utc(2035, 6, 14, 15),
            ),
          ],
          null,
          null,
        );
      };
      final EventListCurrentUserParticipantLoader membershipLoader =
          (_, __) async => null;
      final EventListActiveParticipantsLoader participantsLoader =
          (eventRef) async => [
                _eventParticipantRecordFixture(
                  eventRef,
                  userId: 'profile-loader-user',
                  displayName: 'Snapshot Person',
                  joinedAt: DateTime.utc(2035, 6, 14, 8),
                ),
              ];
      final EventListPublicProfilesLoader firstProfilesLoader =
          (userIds) async {
        firstProfileLoads += 1;
        return UserPublicProfilePreloadResult(
          profilesByUserId: {
            'profile-loader-user': _userPublicProfileFixture(
              'profile-loader-user',
              displayName: 'Alpha Public',
            ),
          },
        );
      };
      final EventListPublicProfilesLoader secondProfilesLoader =
          (userIds) async {
        secondProfileLoads += 1;
        return UserPublicProfilePreloadResult(
          profilesByUserId: {
            'profile-loader-user': _userPublicProfileFixture(
              'profile-loader-user',
              displayName: 'Beta Public',
            ),
          },
        );
      };

      Widget buildList(EventListPublicProfilesLoader profilesLoader) =>
          _buildTestApp(
            home: EventListWidget(
              key: const ValueKey<String>('profile-loader-identity-list'),
              cityCatalogOverride: _catalog,
              languageCatalogOverride: _languageCatalog,
              initialSelectedCity: _selectedCityFixture(),
              nowUtcProvider: nowUtcProvider,
              eventPageLoader: pageLoader,
              currentUserParticipantLoader: membershipLoader,
              activeParticipantsLoader: participantsLoader,
              publicProfilesLoader: profilesLoader,
            ),
          );

      await tester.pumpWidget(buildList(firstProfilesLoader));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(pageLoads, 1);
      expect(firstProfileLoads, 1);
      expect(secondProfileLoads, 0);
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(buildList(secondProfilesLoader));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(pageLoads, 2);
      expect(firstProfileLoads, 1);
      expect(secondProfileLoads, 1);
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('A'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('B'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
      'late profile completion after disposal cannot seed the remount cache',
      (tester) async {
    currentUser = _TestAuthUser('disposed-profile-viewer');
    currentUserDocument = _userFixture(
      uid: 'disposed-profile-viewer',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final profilesCompleter = Completer<UserPublicProfilePreloadResult>();
    addTearDown(() {
      if (!profilesCompleter.isCompleted) {
        profilesCompleter.complete(UserPublicProfilePreloadResult());
      }
    });
    var pageLoads = 0;
    var profileLoads = 0;
    final EventListNowProvider nowUtcProvider =
        () => DateTime.utc(2035, 6, 14, 9);
    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) async {
      pageLoads += 1;
      return FFFirestorePage<EventsRecord>(
        [
          _eventsRecordFixture(
            'disposed-profile-event',
            title: 'Disposed profile event',
            startsAt: DateTime.utc(2035, 6, 14, 15),
          ),
        ],
        null,
        null,
      );
    };
    final EventListCurrentUserParticipantLoader membershipLoader =
        (_, __) async => null;
    final EventListActiveParticipantsLoader participantsLoader =
        (eventRef) async => [
              _eventParticipantRecordFixture(
                eventRef,
                userId: 'disposed-profile-user',
                displayName: 'Disposed Snapshot',
                joinedAt: DateTime.utc(2035, 6, 14, 8),
              ),
            ];
    final EventListPublicProfilesLoader profilesLoader = (_) {
      profileLoads += 1;
      if (profileLoads == 1) {
        return profilesCompleter.future;
      }
      return Future<UserPublicProfilePreloadResult>.value(
        UserPublicProfilePreloadResult(
          profilesByUserId: {
            'disposed-profile-user': _userPublicProfileFixture(
              'disposed-profile-user',
              displayName: 'Fresh Profile',
            ),
          },
        ),
      );
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            key: const ValueKey<String>('disposed-profile-list'),
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: nowUtcProvider,
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: membershipLoader,
            activeParticipantsLoader: participantsLoader,
            publicProfilesLoader: profilesLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pump();
    await tester.pump();

    expect(pageLoads, 1);
    expect(profileLoads, 1);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    profilesCompleter.complete(
      UserPublicProfilePreloadResult(
        profilesByUserId: {
          'disposed-profile-user': _userPublicProfileFixture(
            'disposed-profile-user',
            displayName: 'Late Profile',
          ),
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Disposed profile event'), findsNothing);

    await tester.pumpWidget(buildList());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(pageLoads, 2);
    expect(profileLoads, 2);
    expect(
      find.descendant(
        of: _participantAvatarFinder(0),
        matching: find.text('F'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _participantAvatarFinder(0),
        matching: find.text('L'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not preload public profiles for a signed-out viewer',
      (tester) async {
    var profileLoads = 0;

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
            return FFFirestorePage<EventsRecord>(
              [
                _eventsRecordFixture(
                  'signed-out-profile-event',
                  title: 'Signed out profile event',
                  startsAt: DateTime.utc(2035, 6, 14, 15),
                ),
              ],
              null,
              null,
            );
          },
          activeParticipantsLoader: (eventRef) async => [
            _eventParticipantRecordFixture(
              eventRef,
              userId: 'signed-out-participant',
              displayName: 'Signed Out Participant',
              joinedAt: DateTime.utc(2035, 6, 14, 8),
            ),
          ],
          publicProfilesLoader: (_) async {
            profileLoads += 1;
            return UserPublicProfilePreloadResult();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(profileLoads, 0);
    expect(find.text('Signed out profile event'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final failureMode in <String>['missing', 'failed', 'throw']) {
    testWidgets(
      '$failureMode public profile result is not card-cached and retries on remount',
      (tester) async {
        currentUser = _TestAuthUser('$failureMode-profile-viewer');
        currentUserDocument = _userFixture(
          uid: '$failureMode-profile-viewer',
          data: {
            'profileCity': _profileCityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              catalogVersion: _catalog.catalogVersion,
            ).toMap(),
          },
        );
        var pageLoads = 0;
        var profileLoads = 0;
        final profileRequests = <Set<String>>[];
        final EventListNowProvider nowUtcProvider =
            () => DateTime.utc(2035, 6, 14, 9);
        final EventListPageLoader pageLoader = (
          collection,
          recordBuilder, {
          queryBuilder,
          nextPageMarker,
          required pageSize,
          required isStream,
        }) async {
          pageLoads += 1;
          return FFFirestorePage<EventsRecord>(
            [
              _eventsRecordFixture(
                '$failureMode-profile-event',
                title: '$failureMode profile event',
                startsAt: DateTime.utc(2035, 6, 14, 15),
              ),
            ],
            null,
            null,
          );
        };
        final EventListCurrentUserParticipantLoader membershipLoader =
            (_, __) async => null;
        final EventListActiveParticipantsLoader participantsLoader =
            (eventRef) async => [
                  _eventParticipantRecordFixture(
                    eventRef,
                    userId: 'profile-one',
                    displayName: 'Snapshot One',
                    photoUrl: 'old-snapshot-photo',
                    joinedAt: DateTime.utc(2035, 6, 14, 8),
                  ),
                  _eventParticipantRecordFixture(
                    eventRef,
                    userId: 'profile-two',
                    displayName: 'Snapshot Two',
                    joinedAt: DateTime.utc(2035, 6, 14, 9),
                  ),
                ];
        final EventListPublicProfilesLoader profilesLoader = (userIds) async {
          profileLoads += 1;
          profileRequests.add(userIds.toSet());
          if (profileLoads == 1) {
            if (failureMode == 'throw') {
              throw StateError('profile loader failed');
            }
            return UserPublicProfilePreloadResult(
              profilesByUserId: {
                'profile-one': _userPublicProfileFixture(
                  'profile-one',
                  displayName: 'Public One',
                ),
              },
              missingUserIds: failureMode == 'missing'
                  ? const <String>{'profile-two'}
                  : const <String>{},
              failedUserIds: failureMode == 'failed'
                  ? const <String>{'profile-two'}
                  : const <String>{},
            );
          }
          return UserPublicProfilePreloadResult(
            profilesByUserId: {
              'profile-one': _userPublicProfileFixture(
                'profile-one',
                displayName: 'Fresh One',
              ),
              'profile-two': _userPublicProfileFixture(
                'profile-two',
                displayName: 'Recovered Two',
              ),
            },
          );
        };

        Widget buildList() => _buildTestApp(
              home: EventListWidget(
                key: ValueKey<String>('$failureMode-profile-list'),
                cityCatalogOverride: _catalog,
                languageCatalogOverride: _languageCatalog,
                initialSelectedCity: _selectedCityFixture(),
                nowUtcProvider: nowUtcProvider,
                eventPageLoader: pageLoader,
                currentUserParticipantLoader: membershipLoader,
                activeParticipantsLoader: participantsLoader,
                publicProfilesLoader: profilesLoader,
              ),
            );

        await tester.pumpWidget(buildList());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(pageLoads, 1);
        expect(profileLoads, 1);
        expect(profileRequests, [
          <String>{'profile-one', 'profile-two'},
        ]);
        if (failureMode == 'throw') {
          expect(
            find.descendant(
              of: _participantAvatarFinder(0),
              matching: find.text('S'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: _participantAvatarFinder(0),
              matching: find.byType(CachedNetworkImage),
            ),
            findsOneWidget,
          );
        } else {
          expect(
            find.descendant(
              of: _participantAvatarFinder(0),
              matching: find.text('P'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: _participantAvatarFinder(0),
              matching: find.byType(CachedNetworkImage),
            ),
            findsNothing,
          );
        }
        expect(
          find.descendant(
            of: _participantAvatarFinder(1),
            matching: find.text('S'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(eventListErrorStateKey), findsNothing);

        await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
        await tester.pumpAndSettle();
        await tester.pumpWidget(buildList());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(pageLoads, 2);
        expect(profileLoads, 2);
        expect(profileRequests, [
          <String>{'profile-one', 'profile-two'},
          <String>{'profile-one', 'profile-two'},
        ]);
        expect(
          find.descendant(
            of: _participantAvatarFinder(0),
            matching: find.text('F'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _participantAvatarFinder(1),
            matching: find.text('R'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(eventListErrorStateKey), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('keeps base card geometry when participant enrichment fails',
      (tester) async {
    final participantsCompleter = Completer<List<EventParticipantsRecord>>();
    addTearDown(() {
      if (!participantsCompleter.isCompleted) {
        participantsCompleter.complete(const <EventParticipantsRecord>[]);
      }
    });

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
            return FFFirestorePage<EventsRecord>(
              [
                _eventsRecordFixture(
                  'participant-error-event',
                  title: 'Participant error event',
                  startsAt: DateTime.utc(2035, 6, 14, 15),
                ),
              ],
              null,
              null,
            );
          },
          activeParticipantsLoader: (_) => participantsCompleter.future,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Participant error event'), findsOneWidget);
    final beforeGeometry = _eventCardGeometry(tester);
    final beforeSlots = _participantAvatarSlotRects(tester, count: 6);

    participantsCompleter.completeError(StateError('participants failed'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Participant error event'), findsOneWidget);
    expect(_eventCardGeometry(tester), beforeGeometry);
    expect(_participantAvatarSlotRects(tester, count: 6), beforeSlots);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps membership actions neutral until the participant lookup completes',
    (tester) async {
      currentUser = _TestAuthUser('pending-member');
      currentUserDocument = _userFixture(
        uid: 'pending-member',
        data: {
          'display_name': 'Pending Member',
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      final membershipCompleter = Completer<EventParticipantsRecord?>();
      addTearDown(() {
        if (!membershipCompleter.isCompleted) {
          membershipCompleter.complete(null);
        }
      });
      var membershipLookups = 0;

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
              return FFFirestorePage<EventsRecord>(
                [
                  _eventsRecordFixture(
                    'pending-membership-event',
                    title: 'Pending membership event',
                    startsAt: DateTime.utc(2035, 6, 14, 15),
                  ),
                ],
                null,
                null,
              );
            },
            currentUserParticipantLoader: (eventRef, userId) {
              membershipLookups += 1;
              return membershipCompleter.future;
            },
            activeParticipantsLoader: (_) async =>
                const <EventParticipantsRecord>[],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(membershipLookups, 1);
      expect(find.text('Pending membership event'), findsOneWidget);
      expect(find.text('Проверяем участие'), findsOneWidget);
      expect(find.text('Присоединиться'), findsNothing);
      final pendingPrimarySemantics =
          tester.getSemantics(find.byKey(eventListCardPrimaryCtaKey));
      expect(pendingPrimarySemantics.flagsCollection.isButton, isTrue);
      expect(pendingPrimarySemantics.flagsCollection.isEnabled, isFalse);
      final pendingChatSemantics =
          tester.getSemantics(find.byKey(eventListCardChatCtaKey));
      expect(pendingChatSemantics.flagsCollection.isButton, isTrue);
      expect(pendingChatSemantics.flagsCollection.isEnabled, isFalse);
      expect(pendingChatSemantics.label, contains('Проверяем доступ к чату'));
      final pendingChatInkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(eventListCardChatCtaKey),
          matching: find.byType(InkWell),
        ),
      );
      expect(pendingChatInkWell.onTap, isNull);
      final beforeGeometry = _eventCardGeometry(tester);

      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      await tester.tap(find.byKey(eventListCardChatCtaKey));
      await tester.pump();

      expect(find.text('Pending membership event'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);

      final eventRef = EventsRecord.collection.doc('pending-membership-event');
      membershipCompleter.complete(
        _eventParticipantRecordFixture(
          eventRef,
          userId: 'pending-member',
          displayName: 'Pending Member',
          joinedAt: DateTime.utc(2035, 6, 14, 10),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Проверяем участие'), findsNothing);
      expect(find.text('Покинуть'), findsOneWidget);
      final joinedChatSemantics =
          tester.getSemantics(find.byKey(eventListCardChatCtaKey));
      expect(joinedChatSemantics.flagsCollection.isEnabled, isTrue);
      expect(_eventCardGeometry(tester), beforeGeometry);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keeps membership geometry stable when the participant lookup fails',
    (tester) async {
      currentUser = _TestAuthUser('membership-error-user');
      currentUserDocument = _userFixture(
        uid: 'membership-error-user',
        data: {
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _catalog.catalogVersion,
          ).toMap(),
        },
      );
      final membershipCompleter = Completer<EventParticipantsRecord?>();
      addTearDown(() {
        if (!membershipCompleter.isCompleted) {
          membershipCompleter.complete(null);
        }
      });
      var pageLoads = 0;
      var membershipLookups = 0;
      final EventListPageLoader pageLoader = (
        collection,
        recordBuilder, {
        queryBuilder,
        nextPageMarker,
        required pageSize,
        required isStream,
      }) async {
        pageLoads += 1;
        return FFFirestorePage<EventsRecord>(
          [
            _eventsRecordFixture(
              'membership-error-event',
              title: 'Membership error event',
              startsAt: DateTime.utc(2035, 6, 14, 15),
            ),
          ],
          null,
          null,
        );
      };
      final EventListCurrentUserParticipantLoader membershipLoader = (_, __) {
        membershipLookups += 1;
        if (membershipLookups == 1) {
          return membershipCompleter.future;
        }
        return Future<EventParticipantsRecord?>.value();
      };
      final EventListActiveParticipantsLoader activeParticipantsLoader =
          (_) async => const <EventParticipantsRecord>[];

      Widget buildList() => _buildTestApp(
            home: EventListWidget(
              key: const ValueKey<String>('membership-error-list'),
              cityCatalogOverride: _catalog,
              languageCatalogOverride: _languageCatalog,
              initialSelectedCity: _selectedCityFixture(),
              nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
              eventPageLoader: pageLoader,
              currentUserParticipantLoader: membershipLoader,
              activeParticipantsLoader: activeParticipantsLoader,
            ),
          );

      await tester.pumpWidget(buildList());
      await tester.pump();
      await tester.pump();

      expect(pageLoads, 1);
      expect(membershipLookups, 1);
      expect(find.text('Проверяем участие'), findsOneWidget);
      final beforeGeometry = _eventCardGeometry(tester);

      membershipCompleter.completeError(StateError('membership failed'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Проверяем участие'), findsNothing);
      expect(find.text('Статус недоступен'), findsOneWidget);
      expect(find.text('Присоединиться'), findsNothing);
      final chatSemantics =
          tester.getSemantics(find.byKey(eventListCardChatCtaKey));
      expect(chatSemantics.flagsCollection.isEnabled, isFalse);
      expect(
        chatSemantics.label,
        contains('Не удалось проверить доступ к чату'),
      );
      expect(_eventCardGeometry(tester), beforeGeometry);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(buildList());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(pageLoads, 2);
      expect(membershipLookups, 2);
      expect(find.text('Статус недоступен'), findsNothing);
      expect(find.text('Присоединиться'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('discards stale A-B-A participant enrichment and cache writes',
      (tester) async {
    final staleCompleter = Completer<List<EventParticipantsRecord>>();
    addTearDown(() {
      if (!staleCompleter.isCompleted) {
        staleCompleter.complete(const <EventParticipantsRecord>[]);
      }
    });
    var pageLoads = 0;
    var participantLoads = 0;

    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) async {
      pageLoads += 1;
      return FFFirestorePage<EventsRecord>(
        [
          _eventsRecordFixture(
            'participant-race-event',
            title: 'Participant race event',
            startsAt: DateTime.utc(2035, 6, 15, 15),
          ),
        ],
        null,
        null,
      );
    };
    final EventListActiveParticipantsLoader activeParticipantsLoader =
        (eventRef) {
      participantLoads += 1;
      if (participantLoads == 1) {
        return staleCompleter.future;
      }
      return Future<List<EventParticipantsRecord>>.value([
        _eventParticipantRecordFixture(
          eventRef,
          userId: participantLoads == 2
              ? 'participant-between'
              : 'participant-fresh',
          displayName: participantLoads == 2 ? 'Between' : 'Fresh',
          joinedAt: DateTime.utc(2035, 6, 15, 10),
        ),
      ]);
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            key: const ValueKey<String>('participant-race-list'),
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
            activeParticipantsLoader: activeParticipantsLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pump();
    await tester.pump();

    expect(find.text('Participant race event'), findsOneWidget);
    expect(pageLoads, 1);
    expect(participantLoads, 1);

    await tester.tap(_dateFilterFinder(EventListDateFilter.tomorrow));
    await tester.pumpAndSettle();

    expect(pageLoads, 2);
    expect(participantLoads, 2);
    expect(
      find.descendant(
        of: find.byKey(eventListParticipantAvatarStackKey),
        matching: find.text('B'),
      ),
      findsOneWidget,
    );

    await tester.tap(_dateFilterFinder(EventListDateFilter.tomorrow));
    await tester.pumpAndSettle();

    expect(pageLoads, 3);
    expect(participantLoads, 3);
    expect(
      find.descendant(
        of: find.byKey(eventListParticipantAvatarStackKey),
        matching: find.text('F'),
      ),
      findsOneWidget,
    );

    final eventRef = EventsRecord.collection.doc('participant-race-event');
    staleCompleter.complete([
      _eventParticipantRecordFixture(
        eventRef,
        userId: 'participant-stale',
        displayName: 'Stale',
        joinedAt: DateTime.utc(2035, 6, 15, 11),
      ),
    ]);
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(eventListParticipantAvatarStackKey),
        matching: find.text('F'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(eventListParticipantAvatarStackKey),
        matching: find.text('S'),
      ),
      findsNothing,
    );

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(pageLoads, 3);
    expect(participantLoads, 3);
    expect(
      find.descendant(
        of: find.byKey(eventListParticipantAvatarStackKey),
        matching: find.text('F'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(eventListParticipantAvatarStackKey),
        matching: find.text('S'),
      ),
      findsNothing,
    );
  });

  testWidgets('discards stale A-B-A public profile UI and cache writes',
      (tester) async {
    currentUser = _TestAuthUser('profile-race-viewer');
    currentUserDocument = _userFixture(
      uid: 'profile-race-viewer',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _catalog.catalogVersion,
        ).toMap(),
      },
    );
    final staleProfilesCompleter = Completer<UserPublicProfilePreloadResult>();
    addTearDown(() {
      if (!staleProfilesCompleter.isCompleted) {
        staleProfilesCompleter.complete(UserPublicProfilePreloadResult());
      }
    });
    var pageLoads = 0;
    var profileLoads = 0;
    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) async {
      pageLoads += 1;
      return FFFirestorePage<EventsRecord>(
        [
          _eventsRecordFixture(
            'public-profile-race-event',
            title: 'Public profile race event',
            startsAt: DateTime.utc(2035, 6, 15, 15),
          ),
        ],
        null,
        null,
      );
    };
    final EventListCurrentUserParticipantLoader membershipLoader =
        (_, __) async => null;
    final EventListActiveParticipantsLoader participantsLoader =
        (eventRef) async => [
              _eventParticipantRecordFixture(
                eventRef,
                userId: 'profile-race-user',
                displayName: 'Snapshot Profile',
                joinedAt: DateTime.utc(2035, 6, 15, 10),
              ),
            ];
    final EventListPublicProfilesLoader profilesLoader = (userIds) {
      profileLoads += 1;
      if (profileLoads == 1) {
        return staleProfilesCompleter.future;
      }
      final displayName =
          profileLoads == 2 ? 'Between Profile' : 'Fresh Profile';
      return Future<UserPublicProfilePreloadResult>.value(
        UserPublicProfilePreloadResult(
          profilesByUserId: {
            'profile-race-user': _userPublicProfileFixture(
              'profile-race-user',
              displayName: displayName,
            ),
          },
        ),
      );
    };

    Widget buildList() => _buildTestApp(
          home: EventListWidget(
            key: const ValueKey<String>('public-profile-race-list'),
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: membershipLoader,
            activeParticipantsLoader: participantsLoader,
            publicProfilesLoader: profilesLoader,
          ),
        );

    await tester.pumpWidget(buildList());
    await tester.pump();
    await tester.pump();

    expect(pageLoads, 1);
    expect(profileLoads, 1);
    expect(
      find.descendant(
        of: _participantAvatarFinder(0),
        matching: find.text('S'),
      ),
      findsOneWidget,
    );

    await tester.tap(_dateFilterFinder(EventListDateFilter.tomorrow));
    await tester.pumpAndSettle();

    expect(pageLoads, 2);
    expect(profileLoads, 2);
    expect(
      find.descendant(
        of: _participantAvatarFinder(0),
        matching: find.text('B'),
      ),
      findsOneWidget,
    );

    await tester.tap(_dateFilterFinder(EventListDateFilter.tomorrow));
    await tester.pumpAndSettle();

    expect(pageLoads, 3);
    expect(profileLoads, 3);
    expect(
      find.descendant(
        of: _participantAvatarFinder(0),
        matching: find.text('F'),
      ),
      findsOneWidget,
    );

    staleProfilesCompleter.complete(
      UserPublicProfilePreloadResult(
        profilesByUserId: {
          'profile-race-user': _userPublicProfileFixture(
            'profile-race-user',
            displayName: 'Stale Profile',
          ),
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(
        of: _participantAvatarFinder(0),
        matching: find.text('F'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _participantAvatarFinder(0),
        matching: find.text('S'),
      ),
      findsNothing,
    );

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildList());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(pageLoads, 3);
    expect(profileLoads, 3);
    expect(
      find.descendant(
        of: _participantAvatarFinder(0),
        matching: find.text('F'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final lateOldOutcome in <String>['success', 'missing']) {
    testWidgets(
      'late old $lateOldOutcome from a parallel list cannot replace the newer shared cache',
      (tester) async {
        currentUser = _TestAuthUser('parallel-profile-viewer');
        currentUserDocument = _userFixture(
          uid: 'parallel-profile-viewer',
          data: {
            'profileCity': _profileCityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              catalogVersion: _catalog.catalogVersion,
            ).toMap(),
          },
        );
        final oldProfilesCompleter =
            Completer<UserPublicProfilePreloadResult>();
        final newerProfilesCompleter =
            Completer<UserPublicProfilePreloadResult>();
        addTearDown(() {
          if (!oldProfilesCompleter.isCompleted) {
            oldProfilesCompleter.complete(UserPublicProfilePreloadResult());
          }
          if (!newerProfilesCompleter.isCompleted) {
            newerProfilesCompleter.complete(UserPublicProfilePreloadResult());
          }
        });
        var pageLoads = 0;
        var profileLoads = 0;
        final EventListNowProvider nowUtcProvider =
            () => DateTime.utc(2035, 6, 14, 9);
        final EventListPageLoader pageLoader = (
          collection,
          recordBuilder, {
          queryBuilder,
          nextPageMarker,
          required pageSize,
          required isStream,
        }) async {
          pageLoads += 1;
          return FFFirestorePage<EventsRecord>(
            [
              _eventsRecordFixture(
                'parallel-profile-event',
                title: 'Parallel profile event',
                startsAt: DateTime.utc(2035, 6, 14, 15),
              ),
            ],
            null,
            null,
          );
        };
        final EventListCurrentUserParticipantLoader membershipLoader =
            (_, __) async => null;
        final EventListActiveParticipantsLoader participantsLoader =
            (eventRef) async => [
                  _eventParticipantRecordFixture(
                    eventRef,
                    userId: 'parallel-profile-user',
                    displayName: 'Snapshot Profile',
                    joinedAt: DateTime.utc(2035, 6, 14, 8),
                  ),
                ];
        final EventListPublicProfilesLoader profilesLoader = (_) {
          profileLoads += 1;
          return switch (profileLoads) {
            1 => oldProfilesCompleter.future,
            2 => newerProfilesCompleter.future,
            _ => Future<UserPublicProfilePreloadResult>.value(
                UserPublicProfilePreloadResult(
                  profilesByUserId: {
                    'parallel-profile-user': _userPublicProfileFixture(
                      'parallel-profile-user',
                      displayName: 'Unexpected Reload',
                    ),
                  },
                ),
              ),
          };
        };

        EventListWidget buildList(String key) => EventListWidget(
              key: ValueKey<String>(key),
              cityCatalogOverride: _catalog,
              languageCatalogOverride: _languageCatalog,
              initialSelectedCity: _selectedCityFixture(),
              nowUtcProvider: nowUtcProvider,
              eventPageLoader: pageLoader,
              currentUserParticipantLoader: membershipLoader,
              activeParticipantsLoader: participantsLoader,
              publicProfilesLoader: profilesLoader,
            );

        await tester.pumpWidget(
          _buildTestApp(
            home: Stack(
              fit: StackFit.expand,
              children: [
                buildList('parallel-profile-old-list'),
                buildList('parallel-profile-new-list'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(pageLoads, 2);
        expect(profileLoads, 2);

        newerProfilesCompleter.complete(
          UserPublicProfilePreloadResult(
            profilesByUserId: {
              'parallel-profile-user': _userPublicProfileFixture(
                'parallel-profile-user',
                displayName: 'Newer Profile',
              ),
            },
          ),
        );
        await tester.pump();
        await tester.pump();

        oldProfilesCompleter.complete(
          lateOldOutcome == 'missing'
              ? UserPublicProfilePreloadResult(
                  missingUserIds: const <String>{'parallel-profile-user'},
                )
              : UserPublicProfilePreloadResult(
                  profilesByUserId: {
                    'parallel-profile-user': _userPublicProfileFixture(
                      'parallel-profile-user',
                      displayName: 'Older Profile',
                    ),
                  },
                ),
        );
        await tester.pump();
        await tester.pump();

        await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          _buildTestApp(home: buildList('parallel-profile-remount-list')),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(pageLoads, 2);
        expect(profileLoads, 2);
        expect(
          find.descendant(
            of: _participantAvatarFinder(0),
            matching: find.text('N'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _participantAvatarFinder(0),
            matching: find.text('O'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: _participantAvatarFinder(0),
            matching: find.text('U'),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

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

      expect(find.text('Покинуть'), findsOneWidget);
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

      expect(find.text('Покинуть'), findsOneWidget);
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
      expect(find.text('Покинуть'), findsOneWidget);
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
      expect(find.text('Покинуть'), findsOneWidget);
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

  testWidgets(
    'optimistic join updates CTA count participant and keeps geometry',
    (tester) async {
      const userId = 'optimistic-join-user';
      const eventId = 'optimistic-join-event';
      currentUser = _TestAuthUser(userId);
      currentUserDocument = _userFixture(
        uid: userId,
        data: const {'display_name': 'Olga Optimistic'},
      );
      final joinCompleter = Completer<Object?>();
      addTearDown(() {
        if (!joinCompleter.isCompleted) {
          joinCompleter.complete(
            _eventListJoinResponse(
              eventId: eventId,
              participantsCount: 4,
            ),
          );
        }
      });
      var calls = 0;
      String? functionName;
      Map<String, dynamic>? payload;

      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventCardsOverride: [
              _eventCardFixture(
                eventId: eventId,
                participants: const [
                  EventListParticipantViewModel(
                    userId: 'existing-participant',
                    displayName: 'Marco',
                  ),
                ],
                participantsCount: 2,
                capacity: 6,
                reserveParticipantPreviewSpace: true,
              ),
            ],
            joinEventInvoker: (calledFunctionName, calledPayload) {
              calls += 1;
              functionName = calledFunctionName;
              payload = calledPayload;
              return joinCompleter.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final beforeGeometry = _eventCardGeometry(tester);
      final beforeStack =
          tester.getRect(find.byKey(eventListParticipantAvatarStackKey));
      final beforeSlots = _participantAvatarSlotRects(tester, count: 6);
      expect(find.text('2/6 мест'), findsOneWidget);
      expect(
        find.descendant(
          of: _participantAvatarFinder(1),
          matching: find.text('O'),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();

      expect(calls, 1);
      expect(functionName, joinEventFunctionName);
      expect(payload, <String, dynamic>{'eventId': eventId});
      expect(find.text('Присоединяемся...'), findsOneWidget);
      expect(find.text('3/6 мест'), findsOneWidget);
      expect(
        find.descendant(
          of: _participantAvatarFinder(1),
          matching: find.text('O'),
        ),
        findsOneWidget,
      );
      final pendingPrimary =
          tester.getSemantics(find.byKey(eventListCardPrimaryCtaKey));
      expect(pendingPrimary.flagsCollection.isButton, isTrue);
      expect(pendingPrimary.flagsCollection.isEnabled, isFalse);
      expect(pendingPrimary.flagsCollection.isLiveRegion, isTrue);
      expect(pendingPrimary.label, contains('Присоединяемся'));
      final pendingChat =
          tester.getSemantics(find.byKey(eventListCardChatCtaKey));
      expect(pendingChat.flagsCollection.isEnabled, isFalse);
      expect(_eventCardGeometry(tester), beforeGeometry);
      expect(
        tester.getRect(find.byKey(eventListParticipantAvatarStackKey)),
        beforeStack,
      );
      expect(_participantAvatarSlotRects(tester, count: 6), beforeSlots);

      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      expect(calls, 1);

      joinCompleter.complete(
        _eventListJoinResponse(
          eventId: eventId,
          participantsCount: 4,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('4/6 мест'), findsOneWidget);
      final completedPrimary =
          tester.getSemantics(find.byKey(eventListCardPrimaryCtaKey));
      expect(completedPrimary.flagsCollection.isEnabled, isTrue);
      expect(completedPrimary.flagsCollection.isLiveRegion, isFalse);
      final completedChat =
          tester.getSemantics(find.byKey(eventListCardChatCtaKey));
      expect(completedChat.flagsCollection.isEnabled, isTrue);
      expect(_eventCardGeometry(tester), beforeGeometry);
      expect(
        tester.getRect(find.byKey(eventListParticipantAvatarStackKey)),
        beforeStack,
      );
      expect(_participantAvatarSlotRects(tester, count: 6), beforeSlots);
      expect(
        find.byKey(eventListParticipantActionErrorSnackBarKey),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'optimistic leave updates CTA count participant and keeps geometry',
    (tester) async {
      const userId = 'optimistic-leave-user';
      const eventId = 'optimistic-leave-event';
      currentUser = _TestAuthUser(userId);
      currentUserDocument = _userFixture(
        uid: userId,
        data: const {'display_name': 'Lena Leaving'},
      );
      final leaveCompleter = Completer<Object?>();
      addTearDown(() {
        if (!leaveCompleter.isCompleted) {
          leaveCompleter.complete(
            _eventListLeaveResponse(
              eventId: eventId,
              participantsCount: 1,
            ),
          );
        }
      });
      var calls = 0;
      String? functionName;
      Map<String, dynamic>? payload;

      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventCardsOverride: [
              _eventCardFixture(
                eventId: eventId,
                participants: const [
                  EventListParticipantViewModel(
                    userId: userId,
                    displayName: 'Lena Leaving',
                  ),
                  EventListParticipantViewModel(
                    userId: 'remaining-participant',
                    displayName: 'Marco',
                  ),
                  EventListParticipantViewModel(
                    userId: 'stale-participant-a',
                    displayName: 'Alice',
                  ),
                  EventListParticipantViewModel(
                    userId: 'stale-participant-b',
                    displayName: 'Boris',
                  ),
                  EventListParticipantViewModel(
                    userId: 'stale-participant-c',
                    displayName: 'Carla',
                  ),
                ],
                participantsCount: 5,
                capacity: 6,
                joinCtaState: EventListJoinCtaState.joined,
                chatCtaState: EventListChatCtaState.enabled,
                reserveParticipantPreviewSpace: true,
              ),
            ],
            leaveEventInvoker: (calledFunctionName, calledPayload) {
              calls += 1;
              functionName = calledFunctionName;
              payload = calledPayload;
              return leaveCompleter.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final beforeGeometry = _eventCardGeometry(tester);
      final beforeStack =
          tester.getRect(find.byKey(eventListParticipantAvatarStackKey));
      final beforeSlots = _participantAvatarSlotRects(tester, count: 6);
      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('5/6 мест'), findsOneWidget);
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('L'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();

      expect(calls, 1);
      expect(functionName, leaveEventFunctionName);
      expect(payload, <String, dynamic>{'eventId': eventId});
      expect(find.text('Покидаем...'), findsOneWidget);
      expect(find.text('4/6 мест'), findsOneWidget);
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('M'),
        ),
        findsOneWidget,
      );
      expect(find.text('L'), findsNothing);
      final pendingPrimary =
          tester.getSemantics(find.byKey(eventListCardPrimaryCtaKey));
      expect(pendingPrimary.flagsCollection.isEnabled, isFalse);
      expect(pendingPrimary.flagsCollection.isLiveRegion, isTrue);
      final pendingChat =
          tester.getSemantics(find.byKey(eventListCardChatCtaKey));
      expect(pendingChat.flagsCollection.isEnabled, isFalse);
      expect(_eventCardGeometry(tester), beforeGeometry);
      expect(
        tester.getRect(find.byKey(eventListParticipantAvatarStackKey)),
        beforeStack,
      );
      expect(_participantAvatarSlotRects(tester, count: 6), beforeSlots);

      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      expect(calls, 1);

      leaveCompleter.complete(
        _eventListLeaveResponse(
          eventId: eventId,
          participantsCount: 1,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Присоединиться'), findsOneWidget);
      expect(find.text('1/6 мест'), findsOneWidget);
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsNothing);
      expect(find.text('C'), findsNothing);
      final completedPrimary =
          tester.getSemantics(find.byKey(eventListCardPrimaryCtaKey));
      expect(completedPrimary.flagsCollection.isEnabled, isTrue);
      final completedChat =
          tester.getSemantics(find.byKey(eventListCardChatCtaKey));
      expect(completedChat.flagsCollection.isEnabled, isFalse);
      expect(_eventCardGeometry(tester), beforeGeometry);
      expect(
        tester.getRect(find.byKey(eventListParticipantAvatarStackKey)),
        beforeStack,
      );
      expect(_participantAvatarSlotRects(tester, count: 6), beforeSlots);
      expect(
        find.byKey(eventListParticipantActionErrorSnackBarKey),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed optimistic leave restores a server-confirmed joined card',
    (tester) async {
      const userId = 'server-confirmed-leave-rollback-user';
      const eventId = 'server-confirmed-leave-rollback-event';
      currentUser = _TestAuthUser(userId);
      currentUserDocument = _userFixture(
        uid: userId,
        data: const {'display_name': 'Lena Rollback'},
      );
      final leaveCompleter = Completer<Object?>();
      addTearDown(() {
        if (!leaveCompleter.isCompleted) {
          leaveCompleter.complete(
            _eventListLeaveResponse(
              eventId: eventId,
              participantsCount: 4,
            ),
          );
        }
      });
      var calls = 0;

      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventCardsOverride: [
              _eventCardFixture(
                eventId: eventId,
                participants: const [
                  EventListParticipantViewModel(
                    userId: userId,
                    displayName: 'Lena Rollback',
                  ),
                  EventListParticipantViewModel(
                    userId: 'remaining-participant',
                    displayName: 'Marco',
                  ),
                ],
                participantsCount: 5,
                capacity: 6,
                joinCtaState: EventListJoinCtaState.joined,
                chatCtaState: EventListChatCtaState.enabled,
                reserveParticipantPreviewSpace: true,
              ),
            ],
            leaveEventInvoker: (_, __) {
              calls += 1;
              return leaveCompleter.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final beforeGeometry = _eventCardGeometry(tester);
      final beforeStack =
          tester.getRect(find.byKey(eventListParticipantAvatarStackKey));
      final beforeSlots = _participantAvatarSlotRects(tester, count: 6);
      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('5/6 мест'), findsOneWidget);
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('L'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();

      expect(calls, 1);
      expect(find.text('Покидаем...'), findsOneWidget);
      expect(find.text('4/6 мест'), findsOneWidget);
      expect(find.text('L'), findsNothing);
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('M'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(find.byKey(eventListCardPrimaryCtaKey))
            .flagsCollection
            .isEnabled,
        isFalse,
      );
      expect(
        tester
            .getSemantics(find.byKey(eventListCardChatCtaKey))
            .flagsCollection
            .isEnabled,
        isFalse,
      );
      expect(_eventCardGeometry(tester), beforeGeometry);
      expect(
        tester.getRect(find.byKey(eventListParticipantAvatarStackKey)),
        beforeStack,
      );
      expect(_participantAvatarSlotRects(tester, count: 6), beforeSlots);

      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      expect(calls, 1);

      leaveCompleter.completeError(StateError('leave failed'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('5/6 мест'), findsOneWidget);
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('L'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(find.byKey(eventListCardPrimaryCtaKey))
            .flagsCollection
            .isEnabled,
        isTrue,
      );
      expect(
        tester
            .getSemantics(find.byKey(eventListCardChatCtaKey))
            .flagsCollection
            .isEnabled,
        isTrue,
      );
      expect(_eventCardGeometry(tester), beforeGeometry);
      expect(
        tester.getRect(find.byKey(eventListParticipantAvatarStackKey)),
        beforeStack,
      );
      expect(_participantAvatarSlotRects(tester, count: 6), beforeSlots);
      expect(
        find.byKey(eventListParticipantActionErrorSnackBarKey),
        findsOneWidget,
      );
      expect(
        find.text('Не удалось выполнить действие. Попробуйте снова.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('successful leave may remain above a legacy event capacity',
      (tester) async {
    const userId = 'optimistic-over-capacity-leave-user';
    const eventId = 'optimistic-over-capacity-leave-event';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Capacity User'},
    );
    var calls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
          eventCardsOverride: [
            _eventCardFixture(
              eventId: eventId,
              participants: const [
                EventListParticipantViewModel(
                  userId: userId,
                  displayName: 'Capacity User',
                ),
                EventListParticipantViewModel(
                  userId: 'legacy-organizer',
                  displayName: 'Legacy Organizer',
                ),
              ],
              participantsCount: 12,
              capacity: 10,
              joinCtaState: EventListJoinCtaState.joined,
              chatCtaState: EventListChatCtaState.enabled,
              reserveParticipantPreviewSpace: true,
            ),
          ],
          leaveEventInvoker: (_, __) async {
            calls += 1;
            return _eventListLeaveResponse(
              eventId: eventId,
              participantsCount: 11,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    await tester.pump();

    expect(calls, 1);
    expect(find.text('Мест нет'), findsOneWidget);
    expect(find.text('11/10 мест'), findsOneWidget);
    expect(find.text('C'), findsNothing);
    expect(find.text('L'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(eventListCardChatCtaKey))
          .flagsCollection
          .isEnabled,
      isFalse,
    );
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'optimistic participant action survives list remount and completion',
    (tester) async {
      const userId = 'optimistic-remount-user';
      const eventId = 'optimistic-remount-event';
      currentUser = _TestAuthUser(userId);
      currentUserDocument = _userFixture(
        uid: userId,
        data: const {'display_name': 'Remount User'},
      );
      final joinCompleter = Completer<Object?>();
      addTearDown(() {
        if (!joinCompleter.isCompleted) {
          joinCompleter.complete(
            _eventListJoinResponse(
              eventId: eventId,
              participantsCount: 3,
            ),
          );
        }
      });
      var calls = 0;
      final rawCards = <EventListCardViewModel>[
        _eventCardFixture(
          eventId: eventId,
          participantsCount: 1,
          capacity: 6,
          reserveParticipantPreviewSpace: true,
        ),
      ];

      Widget app(String stateKey) => _buildTestApp(
            home: EventListWidget(
              key: ValueKey<String>(stateKey),
              cityCatalogOverride: _catalog,
              languageCatalogOverride: _languageCatalog,
              initialSelectedCity: _selectedCityFixture(),
              nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
              eventCardsOverride: rawCards,
              joinEventInvoker: (_, __) {
                calls += 1;
                return joinCompleter.future;
              },
            ),
          );

      await tester.pumpWidget(app('optimistic-remount-a'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();

      expect(calls, 1);
      expect(find.text('Присоединяемся...'), findsOneWidget);
      expect(find.text('2/6 мест'), findsOneWidget);

      await tester.pumpWidget(app('optimistic-remount-b'));
      await tester.pump();
      await tester.pump();

      expect(calls, 1);
      expect(find.text('Присоединяемся...'), findsOneWidget);
      expect(find.text('2/6 мест'), findsOneWidget);
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('R'),
        ),
        findsOneWidget,
      );

      joinCompleter.complete(
        _eventListJoinResponse(
          eventId: eventId,
          participantsCount: 3,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('3/6 мест'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(eventListCardPrimaryCtaKey))
            .flagsCollection
            .isEnabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('remounted list receives one pending action failure',
      (tester) async {
    const userId = 'optimistic-error-remount-user';
    const eventId = 'optimistic-error-remount-event';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Error Remount User'},
    );
    final joinCompleter = Completer<Object?>();
    addTearDown(() {
      if (!joinCompleter.isCompleted) {
        joinCompleter.complete(
          _eventListJoinResponse(
            eventId: eventId,
            participantsCount: 2,
          ),
        );
      }
    });
    var calls = 0;
    final rawCards = <EventListCardViewModel>[
      _eventCardFixture(
        eventId: eventId,
        participantsCount: 1,
        capacity: 6,
        reserveParticipantPreviewSpace: true,
      ),
    ];

    Widget app(String stateKey) => _buildTestApp(
          home: EventListWidget(
            key: ValueKey<String>(stateKey),
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventCardsOverride: rawCards,
            joinEventInvoker: (_, __) {
              calls += 1;
              return joinCompleter.future;
            },
          ),
        );

    await tester.pumpWidget(app('error-remount-first'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    expect(find.text('Присоединяемся...'), findsOneWidget);
    final firstState = tester.state<State<EventListWidget>>(
      find.byType(EventListWidget),
    );

    await tester.pumpWidget(app('error-remount-second'));
    await tester.pump();
    final secondState = tester.state<State<EventListWidget>>(
      find.byType(EventListWidget),
    );
    expect(identical(firstState, secondState), isFalse);
    expect(firstState.mounted, isFalse);
    expect(find.text('Присоединяемся...'), findsOneWidget);
    expect(TickerMode.of(tester.element(find.byType(EventListWidget))), isTrue);

    joinCompleter.completeError(StateError('join failed'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(calls, 1);
    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('1/6 мест'), findsOneWidget);
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('current list consumes one failure with a sibling route mounted',
      (tester) async {
    const userId = 'optimistic-current-list-error-user';
    const eventId = 'optimistic-current-list-error-event';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Current List Error User'},
    );
    final joinCompleter = Completer<Object?>();
    addTearDown(() {
      if (!joinCompleter.isCompleted) {
        joinCompleter.complete(
          _eventListJoinResponse(
            eventId: eventId,
            participantsCount: 2,
          ),
        );
      }
    });
    final rawCards = <EventListCardViewModel>[
      _eventCardFixture(
        eventId: eventId,
        participantsCount: 1,
        capacity: 6,
        reserveParticipantPreviewSpace: true,
      ),
    ];

    EventListWidget list({EventCallableInvoker? joinInvoker}) =>
        EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
          eventCardsOverride: rawCards,
          joinEventInvoker: joinInvoker,
        );

    await tester.pumpWidget(
      _buildTestApp(
        home: list(joinInvoker: (_, __) => joinCompleter.future),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    expect(find.text('Присоединяемся...'), findsOneWidget);

    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(builder: (_) => list()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Присоединяемся...'), findsOneWidget);

    joinCompleter.completeError(StateError('join failed'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('1/6 мест'), findsOneWidget);
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'only a post-action raw source can bypass the optimistic overlay',
    (tester) async {
      const userId = 'optimistic-catch-up-user';
      const eventId = 'optimistic-catch-up-event';
      currentUser = _TestAuthUser(userId);
      currentUserDocument = _userFixture(
        uid: userId,
        data: const {'display_name': 'Catch Up User'},
      );
      final joinCompleter = Completer<Object?>();
      addTearDown(() {
        if (!joinCompleter.isCompleted) {
          joinCompleter.complete(
            _eventListJoinResponse(
              eventId: eventId,
              participantsCount: 4,
            ),
          );
        }
      });
      var calls = 0;

      Widget app(List<EventListCardViewModel> cards) => _buildTestApp(
            home: EventListWidget(
              cityCatalogOverride: _catalog,
              languageCatalogOverride: _languageCatalog,
              initialSelectedCity: _selectedCityFixture(),
              nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
              eventCardsOverride: cards,
              joinEventInvoker: (_, __) {
                calls += 1;
                return joinCompleter.future;
              },
            ),
          );

      await tester.pumpWidget(
        app([
          _eventCardFixture(
            eventId: eventId,
            participantsCount: 2,
            capacity: 6,
            reserveParticipantPreviewSpace: true,
          ),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      expect(find.text('Присоединяемся...'), findsOneWidget);
      expect(find.text('3/6 мест'), findsOneWidget);

      // Membership can arrive while the callable is pending, but its event
      // aggregate belongs to a load that started before the action completed.
      await tester.pumpWidget(
        app([
          _eventCardFixture(
            eventId: eventId,
            participants: const [
              EventListParticipantViewModel(
                userId: userId,
                displayName: 'Catch Up User',
              ),
              EventListParticipantViewModel(
                userId: 'fresh-participant',
                displayName: 'Fresh Person',
              ),
              EventListParticipantViewModel(
                userId: 'stale-catch-up-a',
                displayName: 'Stale A',
              ),
              EventListParticipantViewModel(
                userId: 'stale-catch-up-b',
                displayName: 'Stale B',
              ),
            ],
            participantsCount: 2,
            capacity: 6,
            joinCtaState: EventListJoinCtaState.joined,
            chatCtaState: EventListChatCtaState.enabled,
            reserveParticipantPreviewSpace: true,
          ),
        ]),
      );
      await tester.pump();

      expect(find.text('Присоединяемся...'), findsOneWidget);
      expect(find.text('3/6 мест'), findsOneWidget);

      joinCompleter.complete(
        _eventListJoinResponse(
          eventId: eventId,
          participantsCount: 4,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('4/6 мест'), findsOneWidget);

      // A new raw source created after completion may carry a newer count and
      // is trusted to bypass the retained overlay for this card.
      await tester.pumpWidget(
        app([
          _eventCardFixture(
            eventId: eventId,
            participants: const [
              EventListParticipantViewModel(
                userId: userId,
                displayName: 'Catch Up User',
              ),
              EventListParticipantViewModel(
                userId: 'fresh-participant',
                displayName: 'Fresh Person',
              ),
              EventListParticipantViewModel(
                userId: 'stale-catch-up-a',
                displayName: 'Stale A',
              ),
              EventListParticipantViewModel(
                userId: 'stale-catch-up-b',
                displayName: 'Stale B',
              ),
            ],
            participantsCount: 2,
            capacity: 6,
            joinCtaState: EventListJoinCtaState.joined,
            chatCtaState: EventListChatCtaState.enabled,
            reserveParticipantPreviewSpace: true,
          ),
        ]),
      );
      await tester.pump();

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('2/6 мест'), findsOneWidget);
      expect(find.text('S'), findsNothing);

      await tester.pumpWidget(
        app([
          _eventCardFixture(
            eventId: eventId,
            participantsCount: 1,
            capacity: 6,
            joinCtaState: EventListJoinCtaState.join,
            chatCtaState: EventListChatCtaState.participantOnly,
            reserveParticipantPreviewSpace: true,
          ),
        ]),
      );
      await tester.pump();

      expect(calls, 1);
      expect(find.text('Присоединиться'), findsOneWidget);
      expect(find.text('1/6 мест'), findsOneWidget);
      expect(find.text('Покинуть'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fresh list stays raw while a stale sibling keeps the shared overlay',
    (tester) async {
      const userId = 'optimistic-sibling-source-user';
      const eventId = 'optimistic-sibling-source-event';
      currentUser = _TestAuthUser(userId);
      currentUserDocument = _userFixture(
        uid: userId,
        data: const {'display_name': 'Sibling Source User'},
      );
      var calls = 0;
      final staleCards = <EventListCardViewModel>[
        _eventCardFixture(
          eventId: eventId,
          participantsCount: 2,
          capacity: 6,
          reserveParticipantPreviewSpace: true,
        ),
      ];

      Widget staleApp(String key) => _buildTestApp(
            home: EventListWidget(
              key: ValueKey<String>(key),
              cityCatalogOverride: _catalog,
              languageCatalogOverride: _languageCatalog,
              initialSelectedCity: _selectedCityFixture(),
              nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
              eventCardsOverride: staleCards,
              joinEventInvoker: (_, __) async {
                calls += 1;
                return _eventListJoinResponse(
                  eventId: eventId,
                  participantsCount: 4,
                );
              },
            ),
          );

      await tester.pumpWidget(staleApp('stale-sibling-first'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      await tester.pump();

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('4/6 мест'), findsOneWidget);

      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => EventListWidget(
              cityCatalogOverride: _catalog,
              languageCatalogOverride: _languageCatalog,
              initialSelectedCity: _selectedCityFixture(),
              nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
              eventCardsOverride: [
                _eventCardFixture(
                  eventId: eventId,
                  participants: const [
                    EventListParticipantViewModel(
                      userId: userId,
                      displayName: 'Sibling Source User',
                    ),
                  ],
                  participantsCount: 3,
                  capacity: 6,
                  joinCtaState: EventListJoinCtaState.joined,
                  chatCtaState: EventListChatCtaState.enabled,
                  reserveParticipantPreviewSpace: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('3/6 мест'), findsOneWidget);

      navigator.pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(staleApp('stale-sibling-remount'));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('4/6 мест'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmed overlay survives pending and failed fresh membership lookup',
    (tester) async {
      const userId = 'optimistic-membership-barrier-user';
      const eventId = 'optimistic-membership-barrier-event';
      currentUser = _TestAuthUser(userId);
      currentUserDocument = _userFixture(
        uid: userId,
        data: const {'display_name': 'Membership Barrier User'},
      );
      final membershipCompleter = Completer<EventParticipantsRecord?>();
      addTearDown(() {
        if (!membershipCompleter.isCompleted) {
          membershipCompleter.complete(null);
        }
      });
      final EventListActiveParticipantsLoader activeParticipantsLoader =
          (_) async => const <EventParticipantsRecord>[];

      EventListPageLoader pageLoaderForCount(int participantsCount) => (
            collection,
            recordBuilder, {
            queryBuilder,
            nextPageMarker,
            required pageSize,
            required isStream,
          }) async =>
              FFFirestorePage<EventsRecord>(
                [
                  _eventsRecordFixture(
                    eventId,
                    startsAt: DateTime.utc(2035, 6, 14, 15),
                    participantsCount: participantsCount,
                  ),
                ],
                null,
                null,
              );

      Widget repositoryApp({
        required String key,
        required EventListPageLoader pageLoader,
        required EventListCurrentUserParticipantLoader membershipLoader,
      }) =>
          _buildTestApp(
            home: EventListWidget(
              key: ValueKey<String>(key),
              cityCatalogOverride: _catalog,
              languageCatalogOverride: _languageCatalog,
              initialSelectedCity: _selectedCityFixture(),
              nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
              eventPageLoader: pageLoader,
              currentUserParticipantLoader: membershipLoader,
              activeParticipantsLoader: activeParticipantsLoader,
            ),
          );

      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventCardsOverride: [
              _eventCardFixture(
                eventId: eventId,
                participantsCount: 2,
                capacity: 10,
                reserveParticipantPreviewSpace: true,
              ),
            ],
            joinEventInvoker: (_, __) async => _eventListJoinResponse(
              eventId: eventId,
              participantsCount: 4,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      await tester.pump();
      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('4/10 мест'), findsOneWidget);

      await tester.pumpWidget(
        repositoryApp(
          key: 'membership-barrier-pending',
          pageLoader: pageLoaderForCount(1),
          membershipLoader: (_, __) => membershipCompleter.future,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Проверяем участие'), findsNothing);
      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('4/10 мест'), findsOneWidget);

      membershipCompleter.completeError(StateError('membership failed'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Проверяем участие'), findsNothing);
      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('4/10 мест'), findsOneWidget);

      await tester.pumpWidget(
        repositoryApp(
          key: 'membership-barrier-resolved',
          pageLoader: pageLoaderForCount(3),
          membershipLoader: (eventRef, _) async =>
              _eventParticipantRecordFixture(
            eventRef,
            userId: userId,
            displayName: 'Membership Barrier User',
            joinedAt: DateTime.utc(2035, 6, 14, 10),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('3/10 мест'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('time-of-tap blocks a stale join after the event starts',
      (tester) async {
    const userId = 'optimistic-stale-time-user';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Stale Time User'},
    );
    var nowUtc = DateTime.utc(2035, 6, 14, 9);
    var calls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          nowUtcProvider: () => nowUtc,
          eventCardsOverride: [
            _eventCardFixture(
              startsAt: DateTime.utc(2035, 6, 14, 10),
              joinCtaState: EventListJoinCtaState.join,
            ),
          ],
          joinEventInvoker: (_, __) async {
            calls += 1;
            return _eventListJoinResponse(
              eventId: 'event-1',
              participantsCount: 1,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Присоединиться'), findsOneWidget);

    nowUtc = DateTime.utc(2035, 6, 14, 10);
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();

    expect(calls, 0);
    expect(find.text('Уже началось'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(eventListCardPrimaryCtaKey))
          .flagsCollection
          .isEnabled,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('viewer captured by the card blocks an auth switch before tap',
      (tester) async {
    currentUser = _TestAuthUser('optimistic-captured-user-a');
    currentUserDocument = _userFixture(
      uid: 'optimistic-captured-user-a',
      data: const {'display_name': 'Captured Alpha'},
    );
    var calls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: [_eventCardFixture()],
          joinEventInvoker: (_, __) async {
            calls += 1;
            return _eventListJoinResponse(
              eventId: 'event-1',
              participantsCount: 1,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    currentUser = _TestAuthUser('optimistic-captured-user-b');
    currentUserDocument = _userFixture(
      uid: 'optimistic-captured-user-b',
      data: const {'display_name': 'Captured Beta'},
    );
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();

    expect(calls, 0);
    expect(find.text('Присоединяемся...'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'leave failure restores a previously confirmed optimistic join',
    (tester) async {
      const userId = 'optimistic-sequence-user';
      const eventId = 'optimistic-sequence-event';
      currentUser = _TestAuthUser(userId);
      currentUserDocument = _userFixture(
        uid: userId,
        data: const {'display_name': 'Sequence User'},
      );
      final leaveCompleter = Completer<Object?>();
      addTearDown(() {
        if (!leaveCompleter.isCompleted) {
          leaveCompleter.complete(
            _eventListLeaveResponse(
              eventId: eventId,
              participantsCount: 2,
            ),
          );
        }
      });
      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventCardsOverride: [
              _eventCardFixture(
                eventId: eventId,
                participantsCount: 2,
                capacity: 6,
                reserveParticipantPreviewSpace: true,
              ),
            ],
            joinEventInvoker: (_, __) async => _eventListJoinResponse(
              eventId: eventId,
              participantsCount: 3,
            ),
            leaveEventInvoker: (_, __) => leaveCompleter.future,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      await tester.pump();
      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('3/6 мест'), findsOneWidget);

      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      expect(find.text('Покидаем...'), findsOneWidget);
      expect(find.text('2/6 мест'), findsOneWidget);

      leaveCompleter.completeError(StateError('leave failed'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('3/6 мест'), findsOneWidget);
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('S'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(find.byKey(eventListCardChatCtaKey))
            .flagsCollection
            .isEnabled,
        isTrue,
      );
      expect(
        find.byKey(eventListParticipantActionErrorSnackBarKey),
        findsOneWidget,
      );
      expect(
        find.text('Не удалось выполнить действие. Попробуйте снова.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late participant action completion cannot affect another account',
    (tester) async {
      const eventId = 'optimistic-account-event';
      final joinCompleter = Completer<Object?>();
      addTearDown(() {
        if (!joinCompleter.isCompleted) {
          joinCompleter.complete(
            _eventListJoinResponse(
              eventId: eventId,
              participantsCount: 2,
            ),
          );
        }
      });
      var calls = 0;

      Widget app() => _buildTestApp(
            home: EventListWidget(
              cityCatalogOverride: _catalog,
              languageCatalogOverride: _languageCatalog,
              initialSelectedCity: _selectedCityFixture(),
              nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
              eventCardsOverride: [
                _eventCardFixture(
                  eventId: eventId,
                  participantsCount: 1,
                  capacity: 6,
                  reserveParticipantPreviewSpace: true,
                ),
              ],
              joinEventInvoker: (_, __) {
                calls += 1;
                return joinCompleter.future;
              },
            ),
          );

      currentUser = _TestAuthUser('optimistic-account-a');
      currentUserDocument = _userFixture(
        uid: 'optimistic-account-a',
        data: const {'display_name': 'Account Alpha'},
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      expect(find.text('Присоединяемся...'), findsOneWidget);
      expect(find.text('2/6 мест'), findsOneWidget);

      currentUser = _TestAuthUser('optimistic-account-b');
      currentUserDocument = _userFixture(
        uid: 'optimistic-account-b',
        data: const {'display_name': 'Account Beta'},
      );
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.pump();
      expect(find.text('Присоединиться'), findsOneWidget);
      expect(find.text('1/6 мест'), findsOneWidget);

      joinCompleter.complete(
        _eventListJoinResponse(
          eventId: eventId,
          participantsCount: 2,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(calls, 1);
      expect(find.text('Присоединиться'), findsOneWidget);
      expect(find.text('1/6 мест'), findsOneWidget);
      expect(find.text('Покинуть'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late action failure is not shown to another account',
      (tester) async {
    const firstUserId = 'optimistic-error-account-a';
    const secondUserId = 'optimistic-error-account-b';
    const eventId = 'optimistic-error-account-event';
    final joinCompleter = Completer<Object?>();
    addTearDown(() {
      if (!joinCompleter.isCompleted) {
        joinCompleter.complete(
          _eventListJoinResponse(
            eventId: eventId,
            participantsCount: 2,
          ),
        );
      }
    });
    var calls = 0;

    Widget app() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventCardsOverride: [
              _eventCardFixture(
                eventId: eventId,
                participantsCount: 1,
                capacity: 6,
                reserveParticipantPreviewSpace: true,
              ),
            ],
            joinEventInvoker: (_, __) {
              calls += 1;
              return joinCompleter.future;
            },
          ),
        );

    currentUser = _TestAuthUser(firstUserId);
    currentUserDocument = _userFixture(
      uid: firstUserId,
      data: const {'display_name': 'Error Account Alpha'},
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    expect(find.text('Присоединяемся...'), findsOneWidget);

    currentUser = _TestAuthUser(secondUserId);
    currentUserDocument = _userFixture(
      uid: secondUserId,
      data: const {'display_name': 'Error Account Beta'},
    );
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('Присоединиться'), findsOneWidget);

    joinCompleter.completeError(StateError('join failed'));
    await tester.pump();
    await tester.pump();

    expect(calls, 1);
    expect(find.text('Присоединиться'), findsOneWidget);
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );

    currentUser = _TestAuthUser(firstUserId);
    currentUserDocument = _userFixture(
      uid: firstUserId,
      data: const {'display_name': 'Error Account Alpha'},
    );
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Присоединиться'), findsOneWidget);
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('action failure is not shown on another route or after return',
      (tester) async {
    const userId = 'optimistic-hidden-route-user';
    const eventId = 'optimistic-hidden-route-event';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Hidden Route User'},
    );
    final joinCompleter = Completer<Object?>();
    addTearDown(() {
      if (!joinCompleter.isCompleted) {
        joinCompleter.complete(
          _eventListJoinResponse(
            eventId: eventId,
            participantsCount: 2,
          ),
        );
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
          eventCardsOverride: [
            _eventCardFixture(
              eventId: eventId,
              participantsCount: 1,
              capacity: 6,
              reserveParticipantPreviewSpace: true,
            ),
          ],
          joinEventInvoker: (_, __) => joinCompleter.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    expect(find.text('Присоединяемся...'), findsOneWidget);

    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Another route')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    joinCompleter.completeError(StateError('join failed'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Another route'), findsOneWidget);
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );

    navigator.pop();
    await tester.pumpAndSettle();

    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('1/6 мест'), findsOneWidget);
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('visible action failure clears on route change before retry',
      (tester) async {
    const userId = 'optimistic-visible-route-error-user';
    const eventId = 'optimistic-visible-route-error-event';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Visible Route Error User'},
    );
    var calls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
          eventCardsOverride: [
            _eventCardFixture(
              eventId: eventId,
              participantsCount: 1,
              capacity: 6,
              reserveParticipantPreviewSpace: true,
            ),
          ],
          joinEventInvoker: (_, __) async {
            calls += 1;
            if (calls == 1) {
              throw StateError('join failed');
            }
            return _eventListJoinResponse(
              eventId: eventId,
              participantsCount: 2,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsOneWidget,
    );

    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Retry route')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry route'), findsOneWidget);
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );

    navigator.pop();
    await tester.pumpAndSettle();
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );

    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.text('2/6 мест'), findsOneWidget);
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('visible action failure clears on list remount before retry',
      (tester) async {
    const userId = 'optimistic-visible-remount-error-user';
    const eventId = 'optimistic-visible-remount-error-event';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Visible Remount Error User'},
    );
    var calls = 0;
    final rawCards = <EventListCardViewModel>[
      _eventCardFixture(
        eventId: eventId,
        participantsCount: 1,
        capacity: 6,
        reserveParticipantPreviewSpace: true,
      ),
    ];

    Widget app(String stateKey) => _buildTestApp(
          home: EventListWidget(
            key: ValueKey<String>(stateKey),
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventCardsOverride: rawCards,
            joinEventInvoker: (_, __) async {
              calls += 1;
              if (calls == 1) {
                throw StateError('join failed');
              }
              return _eventListJoinResponse(
                eventId: eventId,
                participantsCount: 2,
              );
            },
          ),
        );

    await tester.pumpWidget(app('visible-remount-error-first'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsOneWidget,
    );

    await tester.pumpWidget(app('visible-remount-error-second'));
    await tester.pump();
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );

    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.text('2/6 мест'), findsOneWidget);
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('visible action failure clears across account changes',
      (tester) async {
    const firstUserId = 'optimistic-visible-error-account-a';
    const secondUserId = 'optimistic-visible-error-account-b';
    const eventId = 'optimistic-visible-error-account-event';
    var calls = 0;
    final rawCards = <EventListCardViewModel>[
      _eventCardFixture(
        eventId: eventId,
        participantsCount: 1,
        capacity: 6,
        reserveParticipantPreviewSpace: true,
      ),
    ];

    Widget app() => _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventCardsOverride: rawCards,
            joinEventInvoker: (_, __) async {
              calls += 1;
              if (calls == 1) {
                throw StateError('join failed');
              }
              return _eventListJoinResponse(
                eventId: eventId,
                participantsCount: 2,
              );
            },
          ),
        );

    currentUser = _TestAuthUser(firstUserId);
    currentUserDocument = _userFixture(
      uid: firstUserId,
      data: const {'display_name': 'Visible Error Account Alpha'},
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsOneWidget,
    );

    currentUser = _TestAuthUser(secondUserId);
    currentUserDocument = _userFixture(
      uid: secondUserId,
      data: const {'display_name': 'Visible Error Account Beta'},
    );
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );

    currentUser = _TestAuthUser(firstUserId);
    currentUserDocument = _userFixture(
      uid: firstUserId,
      data: const {'display_name': 'Visible Error Account Alpha'},
    );
    await tester.pumpWidget(app());
    await tester.pump();
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );

    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.text('2/6 мест'), findsOneWidget);
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale cleared action failure does not show feedback',
      (tester) async {
    const userId = 'optimistic-stale-error-user';
    const eventId = 'event-1';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Stale Error User'},
    );
    final joinCompleter = Completer<Object?>();
    addTearDown(() {
      if (!joinCompleter.isCompleted) {
        joinCompleter.complete(
          _eventListJoinResponse(
            eventId: eventId,
            participantsCount: 2,
          ),
        );
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: [_eventCardFixture()],
          joinEventInvoker: (_, __) => joinCompleter.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    expect(find.text('Присоединяемся...'), findsOneWidget);

    debugClearEventListCache();
    await tester.pump();
    expect(find.text('Присоединиться'), findsOneWidget);

    joinCompleter.completeError(StateError('join failed'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Присоединиться'), findsOneWidget);
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'same event cards share one optimistic action without changing others',
    (tester) async {
      const userId = 'optimistic-shared-user';
      const sharedEventId = 'optimistic-shared-event';
      currentUser = _TestAuthUser(userId);
      currentUserDocument = _userFixture(
        uid: userId,
        data: const {'display_name': 'Shared User'},
      );
      final joinCompleter = Completer<Object?>();
      addTearDown(() {
        if (!joinCompleter.isCompleted) {
          joinCompleter.complete(
            _eventListJoinResponse(
              eventId: sharedEventId,
              participantsCount: 2,
            ),
          );
        }
      });
      var calls = 0;

      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventCardsOverride: [
              _eventCardFixture(
                eventId: sharedEventId,
                title: 'Shared event first',
                participantsCount: 1,
                capacity: 6,
                reserveParticipantPreviewSpace: true,
              ),
              _eventCardFixture(
                eventId: sharedEventId,
                title: 'Shared event second',
                participantsCount: 1,
                capacity: 6,
                reserveParticipantPreviewSpace: true,
              ),
              _eventCardFixture(
                eventId: 'independent-event',
                title: 'Independent event',
                participantsCount: 1,
                capacity: 6,
                reserveParticipantPreviewSpace: true,
              ),
            ],
            joinEventInvoker: (_, __) {
              calls += 1;
              return joinCompleter.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(eventListCardPrimaryCtaKey).first);
      await tester.pump();

      expect(calls, 1);
      expect(find.text('Присоединяемся...'), findsNWidgets(2));
      expect(find.text('Присоединиться'), findsOneWidget);
      expect(find.text('2/6 мест'), findsNWidgets(2));
      expect(find.text('1/6 мест'), findsOneWidget);

      joinCompleter.complete(
        _eventListJoinResponse(
          eventId: sharedEventId,
          participantsCount: 2,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Покинуть'), findsNWidgets(2));
      expect(find.text('Присоединиться'), findsOneWidget);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile hydration cannot replace an in-flight optimistic join',
    (tester) async {
      const userId = 'optimistic-hydration-user';
      const eventId = 'optimistic-hydration-event';
      const participantId = 'optimistic-hydration-participant';
      currentUser = _TestAuthUser(userId);
      currentUserDocument = _userFixture(
        uid: userId,
        data: const {'display_name': 'Hydration Viewer'},
      );
      final profilesCompleter = Completer<UserPublicProfilePreloadResult>();
      final joinCompleter = Completer<Object?>();
      addTearDown(() {
        if (!profilesCompleter.isCompleted) {
          profilesCompleter.complete(UserPublicProfilePreloadResult());
        }
        if (!joinCompleter.isCompleted) {
          joinCompleter.complete(
            _eventListJoinResponse(
              eventId: eventId,
              participantsCount: 2,
            ),
          );
        }
      });

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
            }) async =>
                FFFirestorePage<EventsRecord>(
              [
                _eventsRecordFixture(
                  eventId,
                  startsAt: DateTime.utc(2035, 6, 14, 15),
                ),
              ],
              null,
              null,
            ),
            currentUserParticipantLoader: (_, __) async => null,
            activeParticipantsLoader: (eventRef) async => [
              _eventParticipantRecordFixture(
                eventRef,
                userId: participantId,
                displayName: 'Snapshot Person',
                joinedAt: DateTime.utc(2035, 6, 14, 8),
              ),
            ],
            publicProfilesLoader: (_) => profilesCompleter.future,
            joinEventInvoker: (_, __) => joinCompleter.future,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Присоединиться'), findsOneWidget);
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('S'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();

      expect(find.text('Присоединяемся...'), findsOneWidget);
      expect(find.text('2/10 мест'), findsOneWidget);
      expect(
        find.descendant(
          of: _participantAvatarFinder(1),
          matching: find.text('H'),
        ),
        findsOneWidget,
      );

      profilesCompleter.complete(
        UserPublicProfilePreloadResult(
          profilesByUserId: {
            participantId: _userPublicProfileFixture(
              participantId,
              displayName: 'Profile Person',
            ),
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Присоединяемся...'), findsOneWidget);
      expect(find.text('2/10 мест'), findsOneWidget);
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('P'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _participantAvatarFinder(1),
          matching: find.text('H'),
        ),
        findsOneWidget,
      );

      joinCompleter.complete(
        _eventListJoinResponse(
          eventId: eventId,
          participantsCount: 2,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('2/10 мест'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'participant action invalidates every in-flight event cache owner',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      const userId = 'optimistic-cache-owner-user';
      const eventId = 'optimistic-cache-owner-event';
      currentUser = _TestAuthUser(userId);
      currentUserDocument = _userFixture(
        uid: userId,
        data: const {'display_name': 'Cache Owner User'},
      );
      final profileCompleters = [
        Completer<UserPublicProfilePreloadResult>(),
        Completer<UserPublicProfilePreloadResult>(),
      ];
      final joinCompleter = Completer<Object?>();
      addTearDown(() {
        for (final completer in profileCompleters) {
          if (!completer.isCompleted) {
            completer.complete(UserPublicProfilePreloadResult());
          }
        }
        if (!joinCompleter.isCompleted) {
          joinCompleter.complete(
            _eventListJoinResponse(
              eventId: eventId,
              participantsCount: 2,
            ),
          );
        }
      });
      final pageLoads = [0, 0];
      final profileLoads = [0, 0];

      EventListPageLoader pageLoader(int index) => (
            collection,
            recordBuilder, {
            queryBuilder,
            nextPageMarker,
            required pageSize,
            required isStream,
          }) async {
            pageLoads[index] += 1;
            return FFFirestorePage<EventsRecord>(
              [
                _eventsRecordFixture(
                  eventId,
                  startsAt: DateTime.utc(2035, 6, 14, 15),
                ),
              ],
              null,
              null,
            );
          };

      final firstPageLoader = pageLoader(0);
      final secondPageLoader = pageLoader(1);
      final EventListCurrentUserParticipantLoader membershipLoader =
          (_, __) async => null;
      final EventListActiveParticipantsLoader activeParticipantsLoader =
          (_) async => const <EventParticipantsRecord>[];
      EventListPublicProfilesLoader profilesLoader(int index) => (_) {
            profileLoads[index] += 1;
            return profileCompleters[index].future;
          };
      final firstProfilesLoader = profilesLoader(0);
      final secondProfilesLoader = profilesLoader(1);
      final firstCity = _selectedCityFixture();
      final secondCity = firstCity;

      EventListWidget list({
        required String key,
        required EventSelectedCity selectedCity,
        required EventListPageLoader loader,
        required EventListPublicProfilesLoader profiles,
        EventCallableInvoker? joinInvoker,
      }) {
        return EventListWidget(
          key: ValueKey<String>(key),
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: selectedCity,
          nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
          eventPageLoader: loader,
          currentUserParticipantLoader: membershipLoader,
          activeParticipantsLoader: activeParticipantsLoader,
          publicProfilesLoader: profiles,
          joinEventInvoker: joinInvoker,
        );
      }

      await tester.pumpWidget(
        _buildTestApp(
          home: list(
            key: 'cache-owner-first',
            selectedCity: firstCity,
            loader: firstPageLoader,
            profiles: firstProfilesLoader,
            joinInvoker: (_, __) => joinCompleter.future,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(pageLoads, [1, 0]);
      expect(profileLoads, [1, 0]);
      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => list(
              key: 'cache-owner-second',
              selectedCity: secondCity,
              loader: secondPageLoader,
              profiles: secondProfilesLoader,
              joinInvoker: (_, __) => joinCompleter.future,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(pageLoads, [1, 1]);
      expect(profileLoads, [1, 1]);
      final visiblePrimary = find.byKey(eventListCardPrimaryCtaKey);
      await tester.ensureVisible(visiblePrimary);
      await tester.pump();
      await tester.tap(visiblePrimary);
      await tester.pump();
      expect(find.text('Присоединяемся...'), findsOneWidget);

      final profileResult = UserPublicProfilePreloadResult(
        profilesByUserId: {
          'organizer-user': _userPublicProfileFixture(
            'organizer-user',
            displayName: 'Organizer Public',
          ),
        },
      );
      profileCompleters[0].complete(profileResult);
      profileCompleters[1].complete(profileResult);
      joinCompleter.complete(
        _eventListJoinResponse(
          eventId: eventId,
          participantsCount: 2,
        ),
      );
      await tester.pump();
      await tester.pump();

      navigator.pop();
      await tester.pumpAndSettle();
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => list(
              key: 'cache-owner-second-remount',
              selectedCity: secondCity,
              loader: secondPageLoader,
              profiles: secondProfilesLoader,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(pageLoads, [1, 2]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cache owner claimed during an action cannot write after completion',
    (tester) async {
      const userId = 'optimistic-late-cache-owner-user';
      const eventId = 'optimistic-late-cache-owner-event';
      currentUser = _TestAuthUser(userId);
      currentUserDocument = _userFixture(
        uid: userId,
        data: const {'display_name': 'Late Cache Owner'},
      );
      final joinCompleter = Completer<Object?>();
      final pageCompleter = Completer<FFFirestorePage<EventsRecord>>();
      final stalePage = FFFirestorePage<EventsRecord>(
        [
          _eventsRecordFixture(
            eventId,
            startsAt: DateTime.utc(2035, 6, 14, 15),
          ),
        ],
        null,
        null,
      );
      addTearDown(() {
        if (!joinCompleter.isCompleted) {
          joinCompleter.complete(
            _eventListJoinResponse(
              eventId: eventId,
              participantsCount: 2,
            ),
          );
        }
        if (!pageCompleter.isCompleted) {
          pageCompleter.complete(stalePage);
        }
      });
      var pageLoads = 0;
      final EventListPageLoader pageLoader = (
        collection,
        recordBuilder, {
        queryBuilder,
        nextPageMarker,
        required pageSize,
        required isStream,
      }) {
        pageLoads += 1;
        return pageLoads == 1
            ? pageCompleter.future
            : Future<FFFirestorePage<EventsRecord>>.value(stalePage);
      };
      final EventListCurrentUserParticipantLoader membershipLoader =
          (eventRef, _) async => _eventParticipantRecordFixture(
                eventRef,
                userId: userId,
                displayName: 'Late Cache Owner',
                joinedAt: DateTime.utc(2035, 6, 14, 10),
              );
      final EventListActiveParticipantsLoader activeParticipantsLoader =
          (eventRef) async => [
                _eventParticipantRecordFixture(
                  eventRef,
                  userId: userId,
                  displayName: 'Late Cache Owner',
                  joinedAt: DateTime.utc(2035, 6, 14, 10),
                ),
              ];

      EventListWidget loadedList(String key) => EventListWidget(
            key: ValueKey<String>(key),
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventPageLoader: pageLoader,
            currentUserParticipantLoader: membershipLoader,
            activeParticipantsLoader: activeParticipantsLoader,
          );

      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventCardsOverride: [
              _eventCardFixture(
                eventId: eventId,
                participantsCount: 1,
                capacity: 6,
                reserveParticipantPreviewSpace: true,
              ),
            ],
            joinEventInvoker: (_, __) => joinCompleter.future,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      expect(find.text('Присоединяемся...'), findsOneWidget);

      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => loadedList('late-cache-owner-first'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(pageLoads, 1);

      joinCompleter.complete(
        _eventListJoinResponse(
          eventId: eventId,
          participantsCount: 2,
        ),
      );
      await tester.pump();
      await tester.pump();

      pageCompleter.complete(stalePage);
      await tester.pumpAndSettle();

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('2/10 мест'), findsOneWidget);

      navigator.pop();
      await tester.pumpAndSettle();
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => loadedList('late-cache-owner-remount'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(pageLoads, 2);

      navigator.pop();
      await tester.pumpAndSettle();
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => loadedList('late-cache-owner-fresh-cache'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(pageLoads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed optimistic action restores the card and shows an error',
    (tester) async {
      const userId = 'optimistic-rollback-user';
      const eventId = 'optimistic-rollback-event';
      currentUser = _TestAuthUser(userId);
      currentUserDocument = _userFixture(
        uid: userId,
        data: const {'display_name': 'Rollback User'},
      );
      final joinCompleter = Completer<Object?>();
      addTearDown(() {
        if (!joinCompleter.isCompleted) {
          joinCompleter.complete(
            _eventListJoinResponse(
              eventId: eventId,
              participantsCount: 1,
            ),
          );
        }
      });
      var calls = 0;

      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventCardsOverride: [
              _eventCardFixture(
                eventId: eventId,
                participantsCount: 1,
                capacity: 6,
                reserveParticipantPreviewSpace: true,
              ),
            ],
            joinEventInvoker: (_, __) {
              calls += 1;
              return joinCompleter.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      expect(find.text('Присоединяемся...'), findsOneWidget);
      expect(find.text('2/6 мест'), findsOneWidget);
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('R'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      expect(calls, 1);

      joinCompleter.completeError(StateError('join failed'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Присоединиться'), findsOneWidget);
      expect(calls, 1);
      expect(find.text('1/6 мест'), findsOneWidget);
      expect(
        find.descendant(
          of: _participantAvatarFinder(0),
          matching: find.text('R'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(eventListParticipantActionErrorSnackBarKey),
        findsOneWidget,
      );
      expect(
        find.text('Не удалось выполнить действие. Попробуйте снова.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('participant action error uses the safe localized mapper',
      (tester) async {
    const userId = 'optimistic-mapped-error-user';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Mapped Error User'},
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: [
            _eventCardFixture(
              participantsCount: 1,
              capacity: 6,
              reserveParticipantPreviewSpace: true,
            ),
          ],
          joinEventInvoker: (_, __) async {
            throw FirebaseException(
              plugin: 'cloud_functions',
              code: 'unavailable',
              message: 'Raw backend details must stay hidden',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsOneWidget,
    );
    expect(
      find.text('Проверьте подключение и попробуйте снова.'),
      findsOneWidget,
    );
    expect(find.textContaining('Raw backend'), findsNothing);
    expect(find.text('Присоединиться'), findsOneWidget);
    expect(
      tester
          .getSemantics(
            find.byKey(eventListParticipantActionErrorSnackBarKey),
          )
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('participant action error preserves an unrelated snackbar',
      (tester) async {
    const userId = 'optimistic-unrelated-snackbar-user';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Unrelated Snackbar User'},
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: [
            _eventCardFixture(
              participantsCount: 1,
              capacity: 6,
              reserveParticipantPreviewSpace: true,
            ),
          ],
          joinEventInvoker: (_, __) async {
            throw StateError('join failed');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventListCardChatCtaKey));
    await tester.pump();
    expect(
      find.byKey(eventListChatParticipantRequiredSnackBarKey),
      findsOneWidget,
    );

    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsOneWidget,
    );
    expect(
      find.byKey(eventListChatParticipantRequiredSnackBarKey),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated errors replace the snackbar and retry clears it',
      (tester) async {
    const userId = 'optimistic-repeated-error-user';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Repeated Error User'},
    );
    var calls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: [
            _eventCardFixture(
              participantsCount: 1,
              capacity: 6,
              reserveParticipantPreviewSpace: true,
            ),
          ],
          joinEventInvoker: (_, __) async {
            calls += 1;
            if (calls == 1) {
              throw FirebaseException(
                plugin: 'cloud_functions',
                code: 'unavailable',
                message: 'first failure',
              );
            }
            if (calls == 3) {
              return _eventListJoinResponse(
                eventId: 'event-1',
                participantsCount: 2,
              );
            }
            throw StateError('join failed $calls');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var attempt = 1; attempt <= 2; attempt += 1) {
      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      await tester.pump();
      expect(calls, attempt);
      expect(
        find.byKey(eventListParticipantActionErrorSnackBarKey),
        findsOneWidget,
      );
      expect(
        find.text(
          attempt == 1
              ? 'Проверьте подключение и попробуйте снова.'
              : 'Не удалось выполнить действие. Попробуйте снова.',
        ),
        findsOneWidget,
      );
    }

    expect(
      find.text('Проверьте подключение и попробуйте снова.'),
      findsNothing,
    );

    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    await tester.pump();

    expect(calls, 3);
    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.text('2/6 мест'), findsOneWidget);
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('malformed action response rolls back with a generic error',
      (tester) async {
    const userId = 'optimistic-malformed-response-user';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Malformed Response User'},
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: [
            _eventCardFixture(
              participantsCount: 1,
              capacity: 6,
              reserveParticipantPreviewSpace: true,
            ),
          ],
          joinEventInvoker: (_, __) async => <String, dynamic>{
            'unexpected': 'Raw malformed response',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    await tester.pump();

    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('1/6 мест'), findsOneWidget);
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsOneWidget,
    );
    expect(
      find.text('Не удалось выполнить действие. Попробуйте снова.'),
      findsOneWidget,
    );
    expect(find.textContaining('Raw malformed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mismatched action result restores the card and shows an error',
      (tester) async {
    const userId = 'optimistic-mismatch-user';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Mismatch User'},
    );
    var calls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          eventCardsOverride: [
            _eventCardFixture(
              eventId: 'optimistic-mismatch-event',
              participantsCount: 0,
              capacity: 6,
              reserveParticipantPreviewSpace: true,
            ),
          ],
          joinEventInvoker: (_, __) async {
            calls += 1;
            return _eventListJoinResponse(
              eventId: 'different-event',
              participantsCount: 2,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    await tester.pump();

    expect(calls, 1);
    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('0/6 мест'), findsOneWidget);
    expect(find.text('Покинуть'), findsNothing);
    expect(
      find.byKey(eventListParticipantActionErrorSnackBarKey),
      findsOneWidget,
    );
    expect(
      find.text('Не удалось выполнить действие. Попробуйте снова.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid join and leave counts restore the prior card',
      (tester) async {
    const userId = 'optimistic-invalid-count-user';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Invalid Count User'},
    );
    const capacity = 6;
    final scenarios = <({String name, bool joined, int resultCount})>[
      (name: 'join-negative', joined: false, resultCount: -1),
      (name: 'join-zero', joined: false, resultCount: 0),
      (name: 'join-without-organizer', joined: false, resultCount: 1),
      (name: 'join-over-capacity', joined: false, resultCount: 7),
      (name: 'leave-negative', joined: true, resultCount: -1),
      (name: 'leave-without-organizer', joined: true, resultCount: 0),
    ];

    for (final scenario in scenarios) {
      final eventId = 'optimistic-${scenario.name}';
      var calls = 0;
      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            key: ValueKey<String>(scenario.name),
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
            eventCardsOverride: [
              _eventCardFixture(
                eventId: eventId,
                participants: scenario.joined
                    ? const [
                        EventListParticipantViewModel(
                          userId: userId,
                          displayName: 'Invalid Count User',
                        ),
                      ]
                    : const [],
                participantsCount: scenario.joined ? 3 : 1,
                capacity: capacity,
                joinCtaState: scenario.joined
                    ? EventListJoinCtaState.joined
                    : EventListJoinCtaState.join,
                chatCtaState: scenario.joined
                    ? EventListChatCtaState.enabled
                    : EventListChatCtaState.participantOnly,
                reserveParticipantPreviewSpace: true,
              ),
            ],
            joinEventInvoker: (_, __) async {
              calls += 1;
              return _eventListJoinResponse(
                eventId: eventId,
                participantsCount: scenario.resultCount,
              );
            },
            leaveEventInvoker: (_, __) async {
              calls += 1;
              return _eventListLeaveResponse(
                eventId: eventId,
                participantsCount: scenario.resultCount,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
      await tester.pump();
      await tester.pump();

      expect(calls, 1, reason: scenario.name);
      expect(
        find.text(scenario.joined ? 'Покинуть' : 'Присоединиться'),
        findsOneWidget,
        reason: scenario.name,
      );
      expect(
        find.text(scenario.joined ? '3/6 мест' : '1/6 мест'),
        findsOneWidget,
        reason: scenario.name,
      );
      expect(
        find.byKey(eventListParticipantActionErrorSnackBarKey),
        findsOneWidget,
        reason: scenario.name,
      );
      expect(
        find.text('Не удалось выполнить действие. Попробуйте снова.'),
        findsOneWidget,
        reason: scenario.name,
      );
      expect(tester.takeException(), isNull, reason: scenario.name);
    }
  });

  testWidgets('signed-out and locked cards never invoke participant actions',
      (tester) async {
    var calls = 0;

    Widget app({
      required String key,
      required EventListJoinCtaState state,
    }) =>
        _buildTestApp(
          home: EventListWidget(
            key: ValueKey<String>(key),
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            eventCardsOverride: [
              _eventCardFixture(joinCtaState: state),
            ],
            joinEventInvoker: (_, __) async {
              calls += 1;
              return _eventListJoinResponse(
                eventId: 'event-1',
                participantsCount: 1,
              );
            },
            leaveEventInvoker: (_, __) async {
              calls += 1;
              return _eventListLeaveResponse(
                eventId: 'event-1',
                participantsCount: 0,
              );
            },
          ),
        );

    await tester.pumpWidget(
      app(key: 'signed-out-action', state: EventListJoinCtaState.join),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(eventListCardPrimaryCtaKey))
          .flagsCollection
          .isEnabled,
      isFalse,
    );
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    expect(calls, 0);

    currentUser = _TestAuthUser('locked-action-user');
    currentUserDocument = _userFixture(
      uid: 'locked-action-user',
      data: const {'display_name': 'Locked User'},
    );
    await tester.pumpWidget(
      app(
        key: 'locked-action',
        state: EventListJoinCtaState.joinedLocked,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Вы участвуете'), findsOneWidget);
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('organizer record resolves to a locked membership action',
      (tester) async {
    const userId = 'organizer-locked-action-user';
    const eventId = 'organizer-locked-action-event';
    currentUser = _TestAuthUser(userId);
    currentUserDocument = _userFixture(
      uid: userId,
      data: const {'display_name': 'Organizer Locked'},
    );
    var leaveCalls = 0;
    final EventListPageLoader pageLoader = (
      collection,
      recordBuilder, {
      queryBuilder,
      nextPageMarker,
      required pageSize,
      required isStream,
    }) async =>
        FFFirestorePage<EventsRecord>(
          [
            _eventsRecordFixture(
              eventId,
              organizerId: userId,
              organizerDisplayName: 'Organizer Locked',
              startsAt: DateTime.utc(2035, 6, 14, 15),
            ),
          ],
          null,
          null,
        );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          cityCatalogOverride: _catalog,
          languageCatalogOverride: _languageCatalog,
          initialSelectedCity: _selectedCityFixture(),
          nowUtcProvider: () => DateTime.utc(2035, 6, 14, 9),
          eventPageLoader: pageLoader,
          currentUserParticipantLoader: (_, __) async => null,
          activeParticipantsLoader: (_) async => const [],
          leaveEventInvoker: (_, __) async {
            leaveCalls += 1;
            return _eventListLeaveResponse(
              eventId: eventId,
              participantsCount: 1,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Вы участвуете'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(eventListCardPrimaryCtaKey))
          .flagsCollection
          .isEnabled,
      isFalse,
    );
    await tester.tap(find.byKey(eventListCardPrimaryCtaKey));
    await tester.pump();

    expect(leaveCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows join CTA state as enabled primary action', (tester) async {
    currentUser = _TestAuthUser('join-cta-user');
    currentUserDocument = _userFixture(
      uid: 'join-cta-user',
      data: const {'display_name': 'Join CTA User'},
    );
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
      const MapEntry(EventListJoinCtaState.joined, 'Покинуть'),
      const MapEntry(EventListJoinCtaState.joinedLocked, 'Вы участвуете'),
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
      _expectEventCardActionLabelsFit(tester);
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

  testWidgets('event card keeps the compact legacy content geometry',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<_EventCardGeometry> pumpCard({
      required String stateKey,
      EventListCardViewModel? card,
      bool isLoading = false,
    }) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventListWidget(
            key: ValueKey<String>(stateKey),
            cityCatalogOverride: _catalog,
            languageCatalogOverride: _languageCatalog,
            initialSelectedCity: _selectedCityFixture(),
            eventCardsOverride: card == null
                ? const <EventListCardViewModel>[]
                : <EventListCardViewModel>[card],
            isLoadingEvents: isLoading,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(eventListCardShellKey), findsOneWidget);
      final exception = tester.takeException();
      expect(exception == null ? null : exception.toStringDeep(), isNull);
      return _eventCardGeometry(tester);
    }

    final loading = await pumpCard(
      stateKey: 'loading-card',
      isLoading: true,
    );
    await pumpCard(
      stateKey: 'sparse-card',
      card: _eventCardFixture(
        organizerDisplayName: '',
        title: 'Клуб',
        description: '',
        locationName: '',
      ),
    );
    _expectEventCardActionLabelsFit(tester);
    expect(
      tester.getSize(find.byKey(eventListCardPrimaryCtaKey)).width,
      greaterThanOrEqualTo(
        tester.getSize(find.byKey(eventListCardChatCtaKey)).width,
      ),
    );
    final sparseShellSize = tester.getSize(find.byKey(eventListCardShellKey));
    final sparseMetaSize = tester.getSize(find.byKey(eventListCardMetaKey));
    final dateChipSize = tester.getSize(find.byKey(eventListCardDateKey));
    final timeChipSize = tester.getSize(find.byKey(eventListCardTimeKey));
    expect(dateChipSize.width, lessThan(sparseMetaSize.width * 0.60));
    expect(timeChipSize.width, lessThan(sparseMetaSize.width * 0.45));
    expect(
      dateChipSize.width + ExpatlioDesign.space8 + timeChipSize.width,
      lessThan(sparseMetaSize.width),
    );
    expect(
      tester.getSize(find.byKey(eventListCardPrimaryCtaKey)).height,
      36,
    );
    final maximal = await pumpCard(
      stateKey: 'maximal-card',
      card: _eventCardFixture(
        organizerDisplayName: 'Анастасия Александровна Иванова',
        title:
            'Очень длинное название встречи для проверки стабильной структуры карточки',
        description:
            'Длинное описание события занимает несколько строк, но не должно менять высоту карточки или положение действий.',
        levelMin: 'BEGINNER LEVEL',
        levelMax: 'ADVANCED LEVEL',
        locationName:
            'Очень длинный адрес, который занимает две строки на узком экране',
        participants: List<EventListParticipantViewModel>.generate(
          6,
          (index) => EventListParticipantViewModel(
            displayName: 'Участник ${index + 1}',
          ),
        ),
        participantsCount: 12,
        capacity: 20,
        joinCtaState: EventListJoinCtaState.joined,
        chatCtaState: EventListChatCtaState.enabled,
      ),
    );
    _expectEventCardActionLabelsFit(tester);

    expect(loading.shellSize.width, 286);
    expect(maximal.shellSize.width, 286);
    expect(sparseShellSize.width, 286);
    expect(sparseShellSize.height, lessThan(280));
    expect(sparseShellSize.height, lessThan(loading.shellSize.height));
    expect(maximal.shellSize.height, greaterThan(sparseShellSize.height));
    expect(maximal.shellSize.height, lessThan(420));
    expect(loading.actions.top, greaterThan(loading.footer!.bottom));
    expect(maximal.actions.top, greaterThan(maximal.footer!.bottom));
  });

  testWidgets('compact card stays bounded for scaled RU and EN content',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<_EventCardGeometry> pumpCard({
      required String stateKey,
      required Locale locale,
      required double textScale,
      EventListCardViewModel? card,
      bool isLoading = false,
    }) async {
      await tester.pumpWidget(
        _buildTestApp(
          locale: locale,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 1100),
              devicePixelRatio: 1,
              textScaler: TextScaler.linear(textScale),
            ),
            child: EventListWidget(
              key: ValueKey<String>(stateKey),
              cityCatalogOverride: _catalog,
              languageCatalogOverride: _languageCatalog,
              initialSelectedCity: _selectedCityFixture(),
              eventCardsOverride: card == null
                  ? const <EventListCardViewModel>[]
                  : <EventListCardViewModel>[card],
              isLoadingEvents: isLoading,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(eventListCardShellKey), findsOneWidget);
      final exception = tester.takeException();
      expect(exception == null ? null : exception.toStringDeep(), isNull);
      return _eventCardGeometry(tester);
    }

    void expectBoundedGeometry(_EventCardGeometry geometry) {
      expect(geometry.shellSize.width, 286);
      expect(geometry.body.top, greaterThan(geometry.header.top));
      expect(geometry.meta.top, greaterThan(geometry.body.top));
      final contentBottom = geometry.footer?.bottom ?? geometry.meta.bottom;
      expect(geometry.actions.top, greaterThan(contentBottom));
      expect(
        geometry.actions.bottom,
        lessThanOrEqualTo(geometry.shellSize.height - 16),
      );
    }

    for (final configuration in <({Locale locale, double textScale})>[
      (locale: const Locale('ru'), textScale: 1.6),
      (locale: const Locale('en'), textScale: 3.0),
    ]) {
      final suffix =
          '${configuration.locale.languageCode}-${configuration.textScale}';
      final loading = await pumpCard(
        stateKey: 'scaled-loading-$suffix',
        locale: configuration.locale,
        textScale: configuration.textScale,
        isLoading: true,
      );
      final sparse = await pumpCard(
        stateKey: 'scaled-sparse-$suffix',
        locale: configuration.locale,
        textScale: configuration.textScale,
        card: _eventCardFixture(
          organizerDisplayName: 'A',
          title: 'Short',
          description: '',
          locationName: '',
        ),
      );
      _expectEventCardActionLabelsFit(tester);
      final maximal = await pumpCard(
        stateKey: 'scaled-maximal-$suffix',
        locale: configuration.locale,
        textScale: configuration.textScale,
        card: _eventCardFixture(
          organizerDisplayName: List<String>.filled(12, 'Organizer').join(' '),
          title: List<String>.filled(20, 'Conversation').join(' '),
          description: List<String>.filled(30, 'Description').join(' '),
          levelMin: 'EXTREMELY LONG BEGINNER LEVEL',
          levelMax: 'EXTREMELY LONG ADVANCED LEVEL',
          locationName: List<String>.filled(20, 'Location').join(' '),
          participants: List<EventListParticipantViewModel>.generate(
            6,
            (index) => EventListParticipantViewModel(
              displayName: 'Participant ${index + 1}',
            ),
          ),
          participantsCount: 18,
          capacity: 20,
          joinCtaState: EventListJoinCtaState.full,
          chatCtaState: EventListChatCtaState.enabled,
        ),
      );
      _expectEventCardActionLabelsFit(tester);

      expectBoundedGeometry(loading);
      expectBoundedGeometry(sparse);
      expectBoundedGeometry(maximal);
      expect(maximal.shellSize.height, greaterThan(sparse.shellSize.height));

      for (final joinState in EventListJoinCtaState.values) {
        final stateGeometry = await pumpCard(
          stateKey: 'scaled-${joinState.name}-$suffix',
          locale: configuration.locale,
          textScale: configuration.textScale,
          card: _eventCardFixture(
            joinCtaState: joinState,
            chatCtaState: EventListChatCtaState.enabled,
          ),
        );
        _expectEventCardActionLabelsFit(tester);
        if (configuration.locale.languageCode == 'en' &&
            joinState == EventListJoinCtaState.past) {
          expect(find.text('Past'), findsOneWidget);
        }
        expectBoundedGeometry(stateGeometry);
      }

      for (final membershipState in <EventListMembershipState>[
        EventListMembershipState.pending,
        EventListMembershipState.lookupFailed,
      ]) {
        final stateGeometry = await pumpCard(
          stateKey: 'scaled-${membershipState.name}-$suffix',
          locale: configuration.locale,
          textScale: configuration.textScale,
          card: _eventCardFixture(
            membershipState: membershipState,
          ),
        );
        _expectEventCardActionLabelsFit(tester);
        expectBoundedGeometry(stateGeometry);
      }
    }
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
    _expectEventCardActionLabelsFit(tester);
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
    _filterChipContainerFinder(chipFinder),
  );
  final decoration = container.decoration;
  return decoration is BoxDecoration ? decoration.color : null;
}

Finder _filterChipContainerFinder(Finder chipFinder) => find.descendant(
      of: chipFinder,
      matching: find.byType(Container),
    );

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

ScrollPosition _eventListScrollPosition(WidgetTester tester) {
  final verticalScrollView = find.byWidgetPredicate(
    (widget) =>
        widget is SingleChildScrollView &&
        widget.scrollDirection == Axis.vertical,
  );
  expect(verticalScrollView, findsOneWidget);
  final scrollable = find.descendant(
    of: verticalScrollView,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
  expect(scrollable, findsOneWidget);
  return tester.state<ScrollableState>(scrollable).position;
}

Finder _participantAvatarFinder(int index) =>
    find.byKey(ValueKey<String>('event_list_participant_avatar_$index'));

Finder _participantAvatarImageSemanticsFinder(int index) => find.descendant(
      of: _participantAvatarFinder(index),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.container &&
            widget.properties.image == true,
      ),
    );

SemanticsNode _participantAvatarImageSemanticsNode(
  WidgetTester tester,
  int index,
) {
  final finder = _participantAvatarImageSemanticsFinder(index);
  expect(finder, findsOneWidget);
  return tester.getSemantics(finder);
}

void _expectGenericParticipantAvatar(int index) {
  final avatar = _participantAvatarFinder(index);
  expect(avatar, findsOneWidget);
  expect(
    find.descendant(
      of: avatar,
      matching: find.byIcon(Icons.person_outline),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(of: avatar, matching: find.byType(Text)),
    findsNothing,
  );
  expect(
    find.descendant(of: avatar, matching: find.byType(CachedNetworkImage)),
    findsNothing,
  );
}

Color? _participantPlaceholderFillColor(WidgetTester tester, int index) {
  final decoratedBox = find.descendant(
    of: _participantAvatarFinder(index),
    matching: find.byType(DecoratedBox),
  );
  expect(decoratedBox, findsWidgets);
  final decoration = tester.widget<DecoratedBox>(decoratedBox.last).decoration;
  return decoration is BoxDecoration ? decoration.color : null;
}

List<Rect> _participantAvatarSlotRects(
  WidgetTester tester, {
  required int count,
}) =>
    [
      for (var index = 0; index < count; index += 1)
        tester.getRect(_participantAvatarFinder(index)),
    ];

typedef _EventCardGeometry = ({
  Size shellSize,
  Rect header,
  Rect body,
  Rect meta,
  Rect? footer,
  Rect actions,
});

_EventCardGeometry _eventCardGeometry(WidgetTester tester) {
  final shell = tester.getRect(find.byKey(eventListCardShellKey));
  final relativeOffset = Offset(-shell.left, -shell.top);
  Rect relativeRect(ValueKey<String> key) =>
      tester.getRect(find.byKey(key)).shift(relativeOffset);

  return (
    shellSize: shell.size,
    header: relativeRect(eventListCardHeaderKey),
    body: relativeRect(eventListCardBodyKey),
    meta: relativeRect(eventListCardMetaKey),
    footer: find.byKey(eventListCardFooterKey).evaluate().isEmpty
        ? null
        : relativeRect(eventListCardFooterKey),
    actions: relativeRect(eventListCardActionsKey),
  );
}

void _expectEventCardActionLabelsFit(WidgetTester tester) {
  for (final actionKey in <ValueKey<String>>[
    eventListCardPrimaryCtaKey,
    eventListCardChatCtaKey,
  ]) {
    final textFinder = find.descendant(
      of: find.byKey(actionKey),
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget);
    final label = tester.widget<Text>(textFinder).data;
    final paragraph = tester.renderObject<RenderParagraph>(textFinder);
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'Action label "$label" for $actionKey must remain fully visible: '
          'intrinsic=${paragraph.getMaxIntrinsicWidth(double.infinity)}, '
          'available=${paragraph.size.width}.',
    );
  }
}

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
  EventListMembershipState membershipState = EventListMembershipState.resolved,
  bool reserveParticipantPreviewSpace = false,
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
    membershipState: membershipState,
    reserveParticipantPreviewSpace: reserveParticipantPreviewSpace,
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

Map<String, dynamic> _eventListJoinResponse({
  required String eventId,
  required int participantsCount,
}) =>
    <String, dynamic>{
      'eventId': eventId,
      'participantStatus': 'active',
      'participantsCount': participantsCount,
      'joinedAt': '2035-06-14T10:01:00.000Z',
    };

Map<String, dynamic> _eventListLeaveResponse({
  required String eventId,
  required int participantsCount,
}) =>
    <String, dynamic>{
      'eventId': eventId,
      'participantStatus': 'left',
      'participantsCount': participantsCount,
      'leftAt': '2035-06-14T10:02:00.000Z',
    };

EventParticipantsRecord _eventParticipantRecordFixture(
  DocumentReference eventRef, {
  required String userId,
  required String displayName,
  String? photoUrl,
  String role = 'participant',
  required DateTime joinedAt,
}) {
  return EventParticipantsRecord.getDocumentFromData(
    createEventParticipantsRecordData(
      userId: userId,
      displayName: displayName,
      photoUrl: photoUrl,
      role: role,
      status: eventStatusActive,
      joinedAt: joinedAt,
    ),
    EventParticipantsRecord.createDoc(eventRef, id: userId),
  );
}

EventParticipantsRecord _eventParticipantIdentityRecordFixture(
  DocumentReference eventRef, {
  required String documentId,
  String? storedUserId,
  String displayName = 'Участник',
  DateTime? joinedAt,
}) {
  return EventParticipantsRecord.getDocumentFromData(
    createEventParticipantsRecordData(
      userId: storedUserId,
      displayName: displayName,
      role: 'participant',
      status: eventStatusActive,
      joinedAt: joinedAt ?? DateTime.utc(2035, 6, 14, 8),
    ),
    EventParticipantsRecord.createDoc(eventRef, id: documentId),
  );
}

void _setEventProfileFallbackViewer(String userId) {
  currentUser = _TestAuthUser(userId);
  currentUserDocument = _userFixture(
    uid: userId,
    data: {
      'display_name': 'Fallback Viewer',
      'profileCity': _profileCityFixture(
        countryCode: 'RU',
        cityKey: 'moscow',
        catalogVersion: _catalog.catalogVersion,
      ).toMap(),
    },
  );
}

Widget _buildEventProfileFallbackTestApp({
  required String eventId,
  required EventListActiveParticipantsLoader activeParticipantsLoader,
  required EventListPublicProfilesLoader publicProfilesLoader,
}) {
  return _buildTestApp(
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
        return FFFirestorePage<EventsRecord>(
          [
            _eventsRecordFixture(
              eventId,
              title: 'Known participant fallback event',
              startsAt: DateTime.utc(2035, 6, 14, 15),
            ),
          ],
          null,
          null,
        );
      },
      currentUserParticipantLoader: (_, __) async => null,
      activeParticipantsLoader: activeParticipantsLoader,
      publicProfilesLoader: publicProfilesLoader,
    ),
  );
}

// Test-only cursor token; it is passed only to the injected page loader.
// ignore: subtype_of_sealed_class
class _FakeQueryDocumentSnapshot implements QueryDocumentSnapshot<Object?> {
  _FakeQueryDocumentSnapshot([this.id = 'query-cursor']);

  @override
  final String id;

  @override
  bool get exists => true;

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  DocumentReference<Object?> get reference => throw UnimplementedError();

  @override
  Object? data() => const <String, Object?>{};

  @override
  Object? get(Object field) => throw UnimplementedError();

  @override
  Object? operator [](Object field) => get(field);
}

UserPublicProfilesRecord _userPublicProfileFixture(
  String userId, {
  String? displayName,
  String? photoUrl,
}) {
  return UserPublicProfilesRecord.getDocumentFromData(
    {
      'userId': userId,
      'display_name': displayName ?? 'Profile $userId',
      if (photoUrl != null) 'photo_url': photoUrl,
    },
    UserPublicProfilesRecord.collection.doc(userId),
  );
}

EventsRecord _eventsRecordFixture(
  String id, {
  String title = 'Разговорный клуб',
  DateTime? startsAt,
  bool includeStartsAt = true,
  bool includeCapacity = true,
  bool includeParticipantsCount = true,
  int capacity = 10,
  int participantsCount = 1,
  String organizerId = 'organizer-user',
  String organizerDisplayName = 'Анастасия Иванова',
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
      if (includeStartsAt)
        'startsAt': startsAt ?? DateTime.utc(2035, 6, 14, 15),
      'timeZoneId': 'Europe/Moscow',
      if (includeCapacity) 'capacity': capacity,
      if (includeParticipantsCount) 'participantsCount': participantsCount,
      'organizerId': organizerId,
      'organizerDisplayName': organizerDisplayName,
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
