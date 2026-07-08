import 'dart:io';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/components/nav_bar_widget.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/services/user_match_profile.dart';
import 'package:small_talk/shared_pages/design/expatlio_design.dart';
import 'package:small_talk/shared_pages/events/event_create_widget.dart';
import 'package:small_talk/shared_pages/events/event_detail_route_widget.dart';
import 'package:small_talk/shared_pages/events/event_detail_widget.dart';
import 'package:small_talk/shared_pages/events/event_edit_widget.dart';
import 'package:small_talk/shared_pages/events/event_group_chat_widget.dart';
import 'package:small_talk/shared_pages/events/event_history_widget.dart';
import 'package:small_talk/shared_pages/events/event_list_widget.dart';
import 'package:small_talk/shared_pages/profile/profile_widget.dart';
import 'package:small_talk/students_pages/favorite/favorite_widget.dart';
import 'package:small_talk/students_pages/students_dashboard/students_dashboard_widget.dart';
import 'package:small_talk/students_pages/words/words_widget.dart';
import 'package:small_talk/teachers_pages/dashboard_n_s/dashboard_n_s_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ru');
    await initializeDateFormatting('en');
    setupFirebaseCoreMocks();
    await FFLocalizations.initialize();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _TestFirebaseAuthPlatform();
  });

  setUp(() {
    currentUser = null;
    currentUserDocument = null;
  });

  tearDown(() {
    currentUser = null;
    currentUserDocument = null;
    AppStateNotifier.instance.clearRedirectLocation();
  });

  test('event list route exposes the canonical shell tab route', () {
    expect(EventListWidget.routeName, 'events');
    expect(EventListWidget.routePath, '/events');
  });

  test('event detail route exposes the canonical deep link route', () {
    expect(EventDetailWidget.routeName, 'eventDetail');
    expect(EventDetailWidget.routePath, '/events/:eventId');
  });

  test('event create route exposes the canonical create route', () {
    expect(EventCreateWidget.routeName, 'eventCreate');
    expect(EventCreateWidget.routePath, '/events/create');
  });

  test('event edit route exposes the canonical edit route', () {
    expect(EventEditWidget.routeName, 'eventEdit');
    expect(EventEditWidget.routePath, '/events/:eventId/edit');
  });

  test('event group chat route exposes the canonical chat route', () {
    expect(EventGroupChatWidget.routeName, 'eventGroupChat');
    expect(EventGroupChatWidget.routePath, '/events/:eventId/chat');
  });

  test('event history route exposes the canonical profile route', () {
    expect(EventHistoryWidget.routeName, 'eventHistory');
    expect(EventHistoryWidget.routePath, '/profile/events');
  });

  test('bottom navigation exposes events in the role-specific tab order', () {
    final navBar =
        File('lib/components/nav_bar_widget.dart').readAsStringSync();
    final tabShell = File('lib/shared_pages/tab_shell/tab_shell_page.dart')
        .readAsStringSync();
    final router = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();
    final index = File('lib/index.dart').readAsStringSync();

    expect(navBar, contains("ruText: 'События'"));
    expect(navBar, contains("enText: 'Events'"));
    expect(navBar, contains('FFIcons.kcalendar'));
    expect(navBar, contains('FFIcons.kusers02'));
    expect(
      navBar,
      contains(
        RegExp(
          r'void _handleTeacherTap[\s\S]*case 1:[\s\S]*EventListWidget\.routeName[\s\S]*case 2:[\s\S]*FavoriteWidget\.routeName[\s\S]*case 3:[\s\S]*ProfileWidget\.routeName',
        ),
      ),
    );
    expect(
      navBar,
      contains(
        RegExp(
          r'void _handleStudentTap[\s\S]*case 1:[\s\S]*WordsWidget\.routeName[\s\S]*case 2:[\s\S]*FavoriteWidget\.routeName[\s\S]*case 3:[\s\S]*ProfileWidget\.routeName[\s\S]*case 4:[\s\S]*EventListWidget\.routeName',
        ),
      ),
    );

    expect(
      tabShell,
      contains(
        RegExp(
          r'DashboardNSWidget\.routePath,[\s\S]*EventListWidget\.routePath,[\s\S]*FavoriteWidget\.routePath,[\s\S]*ProfileWidget\.routePath',
        ),
      ),
    );
    expect(
      tabShell,
      contains(
        RegExp(
          r'StudentsDashboardWidget\.routePath,[\s\S]*WordsWidget\.routePath,[\s\S]*FavoriteWidget\.routePath,[\s\S]*ProfileWidget\.routePath,[\s\S]*EventListWidget\.routePath',
        ),
      ),
    );
    expect(
      router,
      contains(
        RegExp(
          r'ShellRoute\([\s\S]*name: EventListWidget\.routeName,[\s\S]*path: EventListWidget\.routePath,[\s\S]*requireAuth: true,[\s\S]*noTransition: true',
        ),
      ),
    );
    expect(index,
        contains("export '/shared_pages/events/event_list_widget.dart'"));
  });

  test('teacher tabs keep existing destinations after adding events', () {
    final navBar =
        File('lib/components/nav_bar_widget.dart').readAsStringSync();
    final teacherTap = _sourceBetween(
      navBar,
      'void _handleTeacherTap(int index) {',
      'void _handleStudentTap(int index) {',
    );

    expect(
        navBar, contains('final maxIndex = _usesNativeSpeakerShell ? 3 : 4'));
    expect(
      teacherTap,
      contains(
        RegExp(
          r'case 0:[\s\S]*_isCurrentTab\(0\)[\s\S]*DashboardNSWidget\.routeName',
        ),
      ),
    );
    expect(
      teacherTap,
      contains(
        RegExp(
          r'case 1:[\s\S]*_isCurrentTab\(1\)[\s\S]*EventListWidget\.routeName',
        ),
      ),
    );
    expect(
      teacherTap,
      contains(
        RegExp(
          r'case 2:[\s\S]*_isCurrentTab\(2\)[\s\S]*FavoriteWidget\.routeName',
        ),
      ),
    );
    expect(
      teacherTap,
      contains(
        RegExp(
          r'case 3:[\s\S]*_isCurrentTab\(3\)[\s\S]*ProfileWidget\.routeName',
        ),
      ),
    );
    expect(teacherTap, isNot(contains('WordsWidget.routeName')));
  });

  test('student tabs keep existing destinations after adding events', () {
    final navBar =
        File('lib/components/nav_bar_widget.dart').readAsStringSync();
    final studentTap = _sourceBetween(
      navBar,
      'void _handleStudentTap(int index) {',
      '@override\n  Widget build(BuildContext context)',
    );

    expect(
        navBar, contains('final maxIndex = _usesNativeSpeakerShell ? 3 : 4'));
    expect(
      studentTap,
      contains(
        RegExp(
          r"case 0:[\s\S]*_isCurrentTab\(0\)[\s\S]*StudentsDashboardWidget\.routeName[\s\S]*'zn': serializeParam\(false, ParamType\.bool\)",
        ),
      ),
    );
    expect(
      studentTap,
      contains(
        RegExp(
          r'case 1:[\s\S]*_isCurrentTab\(1\)[\s\S]*WordsWidget\.routeName',
        ),
      ),
    );
    expect(
      studentTap,
      contains(
        RegExp(
          r'case 2:[\s\S]*_isCurrentTab\(2\)[\s\S]*FavoriteWidget\.routeName',
        ),
      ),
    );
    expect(
      studentTap,
      contains(
        RegExp(
          r'case 3:[\s\S]*_isCurrentTab\(3\)[\s\S]*ProfileWidget\.routeName',
        ),
      ),
    );
    expect(
      studentTap,
      contains(
        RegExp(
          r'case 4:[\s\S]*_isCurrentTab\(4\)[\s\S]*EventListWidget\.routeName',
        ),
      ),
    );
  });

  test('tab shell keeps exact role-specific tab path order', () {
    final tabShell = File('lib/shared_pages/tab_shell/tab_shell_page.dart')
        .readAsStringSync();

    expect(
      tabShell,
      contains(
        RegExp(
          r'\? \[\s*DashboardNSWidget\.routePath,\s*EventListWidget\.routePath,\s*FavoriteWidget\.routePath,\s*ProfileWidget\.routePath,\s*\]\s*: \[\s*StudentsDashboardWidget\.routePath,\s*WordsWidget\.routePath,\s*FavoriteWidget\.routePath,\s*ProfileWidget\.routePath,\s*EventListWidget\.routePath,\s*\]',
        ),
      ),
    );
    expect(
      tabShell,
      contains('List<String> get _pathsWithNavBar => _tabPathsOrdered;'),
    );
  });

  test('event detail route stays outside bottom tab shell', () {
    final router = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();
    final index = File('lib/index.dart').readAsStringSync();

    expect(
      router,
      contains(
        RegExp(
          r'FFRoute\([\s\S]*name: EventCreateWidget\.routeName,[\s\S]*path: EventCreateWidget\.routePath,[\s\S]*requireAuth: true',
        ),
      ),
    );
    expect(
      router,
      contains(
        RegExp(
          r'FFRoute\([\s\S]*name: EventEditWidget\.routeName,[\s\S]*path: EventEditWidget\.routePath,[\s\S]*requireAuth: true,[\s\S]*eventId[\s\S]*ParamType\.String',
        ),
      ),
    );
    expect(
      router,
      contains(
        RegExp(
          r'FFRoute\([\s\S]*name: EventGroupChatWidget\.routeName,[\s\S]*path: EventGroupChatWidget\.routePath,[\s\S]*requireAuth: true,[\s\S]*eventId[\s\S]*ParamType\.String',
        ),
      ),
    );
    expect(
      router,
      contains(
        RegExp(
          r'FFRoute\([\s\S]*name: EventDetailWidget\.routeName,[\s\S]*path: EventDetailWidget\.routePath,[\s\S]*requireAuth: true,[\s\S]*EventDetailRouteWidget[\s\S]*eventId[\s\S]*ParamType\.String',
        ),
      ),
    );
    expect(
      router,
      contains(
        RegExp(
          r'FFRoute\([\s\S]*name: EventHistoryWidget\.routeName,[\s\S]*path: EventHistoryWidget\.routePath,[\s\S]*requireAuth: true',
        ),
      ),
    );
    expect(
      router.indexOf('name: EventCreateWidget.routeName'),
      lessThan(router.indexOf('name: EventEditWidget.routeName')),
    );
    expect(
      router.indexOf('name: EventEditWidget.routeName'),
      lessThan(router.indexOf('name: EventGroupChatWidget.routeName')),
    );
    expect(
      router.indexOf('name: EventGroupChatWidget.routeName'),
      lessThan(router.indexOf('name: EventDetailWidget.routeName')),
    );
    expect(
      router.indexOf('name: EventDetailWidget.routeName'),
      lessThan(router.indexOf('ShellRoute(')),
    );
    expect(
      router.indexOf('name: EventCreateWidget.routeName'),
      lessThan(router.indexOf('ShellRoute(')),
    );
    expect(
      router.indexOf('name: EventEditWidget.routeName'),
      lessThan(router.indexOf('ShellRoute(')),
    );
    expect(
      router.indexOf('name: EventGroupChatWidget.routeName'),
      lessThan(router.indexOf('ShellRoute(')),
    );
    expect(
      router.indexOf('name: EventHistoryWidget.routeName'),
      lessThan(router.indexOf('ShellRoute(')),
    );
    expect(index,
        contains("export '/shared_pages/events/event_create_widget.dart'"));
    expect(index, contains('show EventCreateWidget, EventFormMode'));
    expect(index,
        contains("export '/shared_pages/events/event_edit_widget.dart'"));
    expect(
      index,
      contains("export '/shared_pages/events/event_group_chat_widget.dart'"),
    );
    expect(index,
        contains("export '/shared_pages/events/event_detail_widget.dart'"));
    expect(
      index,
      contains("export '/shared_pages/events/event_detail_route_widget.dart'"),
    );
    expect(index,
        contains("export '/shared_pages/events/event_history_widget.dart'"));
  });

  test('event detail screen stays presentation-only behind route binding', () {
    final detail = File('lib/shared_pages/events/event_detail_widget.dart')
        .readAsStringSync();
    final route = File('lib/shared_pages/events/event_detail_route_widget.dart')
        .readAsStringSync();

    expect(detail, contains('final String eventId;'));
    expect(detail, contains('eventId'));
    expect(detail, isNot(contains('EventDetailRepository')));
    expect(detail, isNot(contains('EventActionsRepository')));
    expect(detail, isNot(contains('watchEventDetail')));
    expect(detail, isNot(contains('EventsRecord')));
    expect(route, contains('EventDetailRepository.watchEventDetail'));
    expect(route, contains('EventActionsRepository.cancelEvent'));
    expect(route, contains('EventDetailWidget('));
  });

  test('event form submits through event actions only', () {
    final create = File('lib/shared_pages/events/event_create_widget.dart')
        .readAsStringSync();

    expect(create, contains('Создать событие'));
    expect(create, contains('Create event'));
    expect(create, contains('eventCreateSubmitErrorKey'));
    expect(create, contains('EventActionsRepository.createEvent'));
    expect(create, contains('EventActionsRepository.editEvent'));
    expect(create, contains('EventEditableFields'));
    expect(create, contains('newEventCreateRequestId'));
    expect(create, contains('context.goNamed('));
    expect(create, contains('EventDetailWidget.routeName'));
    expect(create, contains("'eventId': savedEventId"));
    expect(create, isNot(contains('pushNamed(')));
    expect(create, isNot(contains('EventsRecord')));
    expect(create, isNot(contains('EventChatsRecord')));
    expect(create, isNot(contains('EventParticipantsRecord')));
    expect(create, isNot(contains('createEventsRecordData')));
    expect(create, isNot(contains('createEventChatsRecordData')));
    expect(create, isNot(contains('createEventParticipantsRecordData')));
    expect(create, isNot(contains('EventsRecord.collection')));
    expect(create, isNot(contains('EventChatsRecord.collection')));
    expect(create, isNot(contains('EventParticipantsRecord.collection')));
    expect(create,
        isNot(contains("package:cloud_firestore/cloud_firestore.dart")));
    expect(create, isNot(contains('FirebaseFirestore')));
    expect(create, isNot(contains('ProfileCitySaveService')));
  });

  test('event edit screen loads detail data into save-enabled form', () {
    final edit = File('lib/shared_pages/events/event_edit_widget.dart')
        .readAsStringSync();

    expect(edit, contains('final String eventId;'));
    expect(edit, contains('EventCreateWidget('));
    expect(edit, contains('formMode: EventFormMode.edit'));
    expect(edit, contains('eventId: widget.eventId'));
    expect(edit, contains('editEventInvoker'));
    expect(edit, contains('EventDetailRepository'));
    expect(edit, contains('watchEventDetail'));
    expect(edit, contains('EventsRecord'));
    expect(edit, contains('organizerId'));
    expect(edit, contains('currentUserUid'));
    expect(edit, contains('eventEditForbiddenKey'));
    expect(edit, isNot(contains('EventActionsRepository')));
    expect(edit, isNot(contains('EventEditableFields')));
    expect(edit, isNot(contains('.editEvent(')));
  });

  test('event group chat screen sends only through trusted callable', () {
    final chat = File('lib/shared_pages/events/event_group_chat_widget.dart')
        .readAsStringSync();
    final repository = File('lib/services/event_group_chat_repository.dart')
        .readAsStringSync();
    final actionsRepository =
        File('lib/services/event_actions_repository.dart').readAsStringSync();

    expect(chat, contains('final String eventId;'));
    expect(chat, contains('Чат события'));
    expect(chat, contains('Event chat'));
    expect(chat, contains('EventGroupChatRepository'));
    expect(chat, contains('EventActionsRepository.sendEventChatMessage'));
    expect(chat, contains('EventChatMessagesRecord'));
    expect(repository, contains('EventChatsRecord.collection.doc'));
    expect(repository, contains('queryEventChatMessagesRecord'));
    expect(repository, contains("orderBy('createdAt', descending: false)"));
    expect(repository, contains('orderBy(FieldPath.documentId'));
    expect(
        repository, contains('queryCollectionPage<EventChatMessagesRecord>'));
    expect(actionsRepository, contains('sendEventChatMessageFunctionName'));
    expect(actionsRepository, contains("'eventId': normalizeEventActionId"));
    expect(actionsRepository, contains("'text': text"));
    expect(chat, isNot(contains('ChatThreadWidget')));
    expect(chat, isNot(contains('FirebaseFirestore')));
    expect(chat, isNot(contains('.set(')));
    expect(chat, isNot(contains("collection('messages')")));
    expect(chat, isNot(contains('EventChatMessagesRecord.createDoc')));
    expect(chat, isNot(contains('.delete(')));
    expect(chat, isNot(contains('accessStateInvoker')));
    expect(repository, isNot(contains('sendEventChatMessage')));
  });

  testWidgets('event create route redirects signed-out users to onboarding',
      (tester) async {
    final harness = await _pumpSignedOutEventsRouter(tester, '/events/create');

    expect(harness.router.getCurrentLocation(), '/onboarding');
    expect(harness.notifier.hasRedirect(), isTrue);
    expect(harness.notifier.getRedirectLocation(), '/events/create');
  });

  testWidgets('event edit route redirects signed-out users to onboarding',
      (tester) async {
    final harness =
        await _pumpSignedOutEventsRouter(tester, '/events/event-123/edit');

    expect(harness.router.getCurrentLocation(), '/onboarding');
    expect(harness.notifier.hasRedirect(), isTrue);
    expect(harness.notifier.getRedirectLocation(), '/events/event-123/edit');
  });

  testWidgets('event group chat route redirects signed-out users to onboarding',
      (tester) async {
    final harness =
        await _pumpSignedOutEventsRouter(tester, '/events/event-123/chat');

    expect(harness.router.getCurrentLocation(), '/onboarding');
    expect(harness.notifier.hasRedirect(), isTrue);
    expect(harness.notifier.getRedirectLocation(), '/events/event-123/chat');
  });

  testWidgets('event list route redirects signed-out users to onboarding',
      (tester) async {
    final harness = await _pumpSignedOutEventsRouter(tester, '/events');

    expect(harness.router.getCurrentLocation(), '/onboarding');
    expect(harness.notifier.hasRedirect(), isTrue);
    expect(harness.notifier.getRedirectLocation(), '/events');
  });

  testWidgets('event detail route redirects signed-out users to onboarding',
      (tester) async {
    final harness =
        await _pumpSignedOutEventsRouter(tester, '/events/event-123');

    expect(harness.router.getCurrentLocation(), '/onboarding');
    expect(harness.notifier.hasRedirect(), isTrue);
    expect(harness.notifier.getRedirectLocation(), '/events/event-123');
  });

  testWidgets(
      'student bottom navigation keeps events selected and old tabs live',
      (tester) async {
    final router = _buildNavBarRouter();
    currentUser = _TestAuthUser(userId: 'student-nav-user');
    currentUserDocument = _userDocumentFixture(
      userId: 'student-nav-user',
      role: UserRole.student,
    );

    router.go(EventListWidget.routePath);
    await tester.pumpWidget(_routerTestApp(router, locale: const Locale('ru')));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), EventListWidget.routePath);
    expect(find.byType(NavBarWidget), findsOneWidget);
    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('События'), findsOneWidget);
    expect(find.text('Словарь'), findsOneWidget);
    expect(find.text('Чаты'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
    _expectNavLabelOrder([
      'Главная',
      'Словарь',
      'Чаты',
      'Профиль',
      'События',
    ]);
    _expectSelectedNavLabel(tester, 'События');
    _expectInactiveNavLabel(tester, 'Главная');
    _expectInactiveNavLabel(tester, 'Профиль');

    await tester.tap(find.text('Главная'));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/studentsDashboard?zn=false');

    router.go(EventListWidget.routePath);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Словарь'));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), WordsWidget.routePath);

    router.go(EventListWidget.routePath);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Чаты'));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), FavoriteWidget.routePath);

    router.go(EventListWidget.routePath);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), ProfileWidget.routePath);
  });

  testWidgets(
      'teacher bottom navigation keeps events selected and old tabs live',
      (tester) async {
    final router = _buildNavBarRouter();
    currentUser = _TestAuthUser(userId: 'teacher-nav-user');
    currentUserDocument = _userDocumentFixture(
      userId: 'teacher-nav-user',
      role: UserRole.native_speaker,
      teacherAccreditationStatus: TeacherAccreditationStatus.approved,
    );

    router.go(EventListWidget.routePath);
    await tester.pumpWidget(_routerTestApp(router, locale: const Locale('ru')));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), EventListWidget.routePath);
    expect(find.byType(NavBarWidget), findsOneWidget);
    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('События'), findsOneWidget);
    expect(find.text('Словарь'), findsNothing);
    expect(find.text('Чаты'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
    _expectNavLabelOrder([
      'Главная',
      'События',
      'Чаты',
      'Профиль',
    ]);
    _expectSelectedNavLabel(tester, 'События');
    _expectInactiveNavLabel(tester, 'Главная');
    _expectInactiveNavLabel(tester, 'Профиль');

    await tester.tap(find.text('Главная'));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), DashboardNSWidget.routePath);

    router.go(EventListWidget.routePath);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Чаты'));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), FavoriteWidget.routePath);

    router.go(EventListWidget.routePath);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), ProfileWidget.routePath);
  });

  testWidgets('router opens event create path before dynamic detail route',
      (tester) async {
    final router = await _pumpEventsRouter(tester, '/events/create');

    expect(router.getCurrentLocation(), '/events/create');
    expect(find.byType(EventCreateWidget), findsOneWidget);
    expect(find.byType(EventDetailWidget), findsNothing);
    expect(find.byType(NavBarWidget), findsNothing);
  });

  testWidgets('router opens event edit path before dynamic detail route',
      (tester) async {
    final router = await _pumpEventsRouter(tester, '/events/event-123/edit');

    expect(router.getCurrentLocation(), '/events/event-123/edit');
    expect(find.byType(EventEditWidget), findsOneWidget);
    expect(tester.widget<EventEditWidget>(find.byType(EventEditWidget)).eventId,
        'event-123');
    expect(find.byType(EventCreateWidget), findsNothing);
    expect(find.byType(EventDetailWidget), findsNothing);
    expect(find.text('Edit event'), findsOneWidget);
    expect(find.byType(NavBarWidget), findsNothing);
  });

  testWidgets('router opens event group chat path before dynamic detail route',
      (tester) async {
    final router = await _pumpEventsRouter(tester, '/events/event-123/chat');

    expect(router.getCurrentLocation(), '/events/event-123/chat');
    expect(find.byType(EventGroupChatWidget), findsOneWidget);
    expect(find.byType(EventDetailWidget), findsNothing);
    expect(find.text('Event chat'), findsOneWidget);
    expect(find.byType(NavBarWidget), findsNothing);
  });

  testWidgets('router opens event detail path outside the tab shell',
      (tester) async {
    final router = await _pumpEventsRouter(tester, '/events/event-123');

    expect(router.getCurrentLocation(), '/events/event-123');
    expect(find.byType(EventDetailRouteWidget), findsOneWidget);
    expect(find.byKey(eventDetailRouteLoadingKey), findsOneWidget);
    expect(find.byType(NavBarWidget), findsNothing);
  });
}

Future<GoRouter> _pumpEventsRouter(
  WidgetTester tester,
  String location,
) async {
  final notifier = AppStateNotifier.instance;
  notifier.initialUser = null;
  notifier.clearRedirectLocation();
  notifier.showSplashImage = true;

  final user = _TestAuthUser(userId: 'events-user');
  currentUser = user;
  notifier.update(user);
  notifier.stopShowingSplashImage();

  final router = createRouter(notifier);
  router.go(location);

  await tester.pumpWidget(_routerTestApp(router));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  return router;
}

Future<_RouterHarness> _pumpSignedOutEventsRouter(
  WidgetTester tester,
  String location,
) async {
  final notifier = AppStateNotifier.instance;
  notifier.initialUser = null;
  notifier.clearRedirectLocation();
  notifier.showSplashImage = true;

  final user = _TestAuthUser(userId: null, isLoggedIn: false);
  currentUser = user;
  notifier.update(user);
  notifier.stopShowingSplashImage();

  final router = createRouter(notifier);
  router.go(location);

  await tester.pumpWidget(_routerTestApp(router));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  return _RouterHarness(router: router, notifier: notifier);
}

Widget _routerTestApp(
  GoRouter router, {
  Locale? locale,
}) =>
    MaterialApp.router(
      locale: locale,
      supportedLocales: const <Locale>[
        Locale('ru'),
        Locale('en'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        FFLocalizationsDelegate(),
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
      ],
      routerConfig: router,
    );

GoRouter _buildNavBarRouter() {
  Widget shell(String label, GoRouterState state) => Scaffold(
        body: Center(child: Text(label)),
        bottomNavigationBar: NavBarWidget(
          indexCurrentPage: _navBarIndexForPath(state.uri.path),
        ),
      );

  return GoRouter(
    initialLocation: EventListWidget.routePath,
    routes: [
      GoRoute(
        name: DashboardNSWidget.routeName,
        path: DashboardNSWidget.routePath,
        builder: (context, state) => shell('teacher home', state),
      ),
      GoRoute(
        name: StudentsDashboardWidget.routeName,
        path: StudentsDashboardWidget.routePath,
        builder: (context, state) => shell('student home', state),
      ),
      GoRoute(
        name: EventListWidget.routeName,
        path: EventListWidget.routePath,
        builder: (context, state) => shell('events', state),
      ),
      GoRoute(
        name: WordsWidget.routeName,
        path: WordsWidget.routePath,
        builder: (context, state) => shell('words', state),
      ),
      GoRoute(
        name: FavoriteWidget.routeName,
        path: FavoriteWidget.routePath,
        builder: (context, state) => shell('favorite', state),
      ),
      GoRoute(
        name: ProfileWidget.routeName,
        path: ProfileWidget.routePath,
        builder: (context, state) => shell('profile', state),
      ),
    ],
  );
}

int _navBarIndexForPath(String path) {
  final teacherPaths = [
    DashboardNSWidget.routePath,
    EventListWidget.routePath,
    FavoriteWidget.routePath,
    ProfileWidget.routePath,
  ];
  final studentPaths = [
    StudentsDashboardWidget.routePath,
    WordsWidget.routePath,
    FavoriteWidget.routePath,
    ProfileWidget.routePath,
    EventListWidget.routePath,
  ];
  final paths = canUseNativeSpeakerShell(currentUserDocument)
      ? teacherPaths
      : studentPaths;
  return paths.indexOf(path);
}

void _expectSelectedNavLabel(WidgetTester tester, String label) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byType(NavBarWidget),
      matching: find.text(label),
    ),
  );

  expect(text.style?.color, ExpatlioDesign.primary);
  expect(text.style?.fontWeight, FontWeight.w500);
}

void _expectNavLabelOrder(List<String> labels) {
  expect(
    find
        .descendant(
          of: find.byType(NavBarWidget),
          matching: find.byType(Text),
        )
        .evaluate()
        .map((element) => element.widget)
        .cast<Text>()
        .map((widget) => widget.data)
        .whereType<String>()
        .toList(),
    labels,
  );
}

void _expectInactiveNavLabel(WidgetTester tester, String label) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byType(NavBarWidget),
      matching: find.text(label),
    ),
  );

  expect(text.style?.color, ExpatlioDesign.inactive);
  expect(text.style?.fontWeight, FontWeight.w500);
}

UsersRecord _userDocumentFixture({
  required String userId,
  required UserRole role,
  TeacherAccreditationStatus? teacherAccreditationStatus,
}) {
  return UsersRecord.getDocumentFromData(
    {
      'uid': userId,
      'role': role.name,
      if (teacherAccreditationStatus != null)
        'teacherAccreditationStatus': teacherAccreditationStatus.name,
    },
    UsersRecord.collection.doc(userId),
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

class _RouterHarness {
  const _RouterHarness({
    required this.router,
    required this.notifier,
  });

  final GoRouter router;
  final AppStateNotifier notifier;
}

class _TestAuthUser extends BaseAuthUser {
  _TestAuthUser({
    required this.userId,
    this.isLoggedIn = true,
  });

  final String? userId;
  final bool isLoggedIn;

  @override
  bool get loggedIn => isLoggedIn;

  @override
  bool get emailVerified => true;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(uid: userId);

  @override
  Future<void> delete() async {}

  @override
  Future<void> updateEmail(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> sendEmailVerification() async {}
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  if (startIndex < 0) {
    fail('Missing source marker: $start');
  }
  final endIndex = source.indexOf(end, startIndex + start.length);
  if (endIndex < 0) {
    fail('Missing source marker: $end');
  }
  return source.substring(startIndex, endIndex);
}
