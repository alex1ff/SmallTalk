import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/auth/base_auth_user_provider.dart';
import 'package:small_talk/components/nav_bar_widget.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
import 'package:small_talk/shared_pages/events/event_create_widget.dart';
import 'package:small_talk/shared_pages/events/event_detail_widget.dart';
import 'package:small_talk/shared_pages/events/event_edit_widget.dart';
import 'package:small_talk/shared_pages/events/event_group_chat_widget.dart';
import 'package:small_talk/shared_pages/events/event_list_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    currentUser = null;
  });

  tearDown(() {
    currentUser = null;
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

  test('bottom navigation exposes events between home and existing tabs', () {
    final navBar =
        File('lib/components/nav_bar_widget.dart').readAsStringSync();
    final tabShell = File('lib/shared_pages/tab_shell/tab_shell_page.dart')
        .readAsStringSync();
    final router = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();
    final index = File('lib/index.dart').readAsStringSync();

    expect(navBar, contains("ruText: 'События'"));
    expect(navBar, contains("enText: 'Events'"));
    expect(navBar, contains('FFIcons.kcalendar'));
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
          r'void _handleStudentTap[\s\S]*case 1:[\s\S]*EventListWidget\.routeName[\s\S]*case 2:[\s\S]*WordsWidget\.routeName[\s\S]*case 3:[\s\S]*FavoriteWidget\.routeName[\s\S]*case 4:[\s\S]*ProfileWidget\.routeName',
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
          r'StudentsDashboardWidget\.routePath,[\s\S]*EventListWidget\.routePath,[\s\S]*WordsWidget\.routePath,[\s\S]*FavoriteWidget\.routePath,[\s\S]*ProfileWidget\.routePath',
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
          r'FFRoute\([\s\S]*name: EventDetailWidget\.routeName,[\s\S]*path: EventDetailWidget\.routePath,[\s\S]*requireAuth: true,[\s\S]*eventId[\s\S]*ParamType\.String',
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
    expect(index,
        contains("export '/shared_pages/events/event_create_widget.dart'"));
    expect(index,
        contains("export '/shared_pages/events/event_edit_widget.dart'"));
    expect(
      index,
      contains("export '/shared_pages/events/event_group_chat_widget.dart'"),
    );
    expect(index,
        contains("export '/shared_pages/events/event_detail_widget.dart'"));
  });

  test('event detail screen stays a route placeholder for Phase 5', () {
    final detail = File('lib/shared_pages/events/event_detail_widget.dart')
        .readAsStringSync();

    expect(detail, contains('final String eventId;'));
    expect(detail, contains('eventId'));
    expect(detail, isNot(contains('EventDetailRepository')));
    expect(detail, isNot(contains('watchEventDetail')));
    expect(detail, isNot(contains('EventsRecord')));
  });

  test('event create screen stays a route placeholder for Phase 5', () {
    final create = File('lib/shared_pages/events/event_create_widget.dart')
        .readAsStringSync();

    expect(create, contains('Создать событие'));
    expect(create, contains('Create event'));
    expect(create, isNot(contains('EventActionsRepository')));
    expect(create, isNot(contains('EventEditableFields')));
    expect(create, isNot(contains('createRequestId')));
    expect(create, isNot(contains('newEventCreateRequestId')));
    expect(create, isNot(contains('.createEvent(')));
  });

  test('event edit screen stays a route placeholder before Phase 9', () {
    final edit = File('lib/shared_pages/events/event_edit_widget.dart')
        .readAsStringSync();

    expect(edit, contains('final String eventId;'));
    expect(edit, contains('Редактировать событие'));
    expect(edit, contains('Edit event'));
    expect(edit, isNot(contains('EventActionsRepository')));
    expect(edit, isNot(contains('EventEditableFields')));
    expect(edit, isNot(contains('EventDetailRepository')));
    expect(edit, isNot(contains('watchEventDetail')));
    expect(edit, isNot(contains('.editEvent(')));
  });

  test('event group chat screen stays a route placeholder before Phase 11', () {
    final chat = File('lib/shared_pages/events/event_group_chat_widget.dart')
        .readAsStringSync();

    expect(chat, contains('final String eventId;'));
    expect(chat, contains('Чат события'));
    expect(chat, contains('Event chat'));
    expect(chat, isNot(contains('ChatThreadWidget')));
    expect(chat, isNot(contains('EventChatsRecord')));
    expect(chat, isNot(contains('EventChatMessagesRecord')));
    expect(chat, isNot(contains('sendEventChatMessage')));
    expect(chat, isNot(contains('queryEventChatMessagesRecord')));
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
    expect(find.byType(EventDetailWidget), findsNothing);
    expect(find.text('event-123'), findsOneWidget);
    expect(find.byType(NavBarWidget), findsNothing);
  });

  testWidgets('router opens event group chat path before dynamic detail route',
      (tester) async {
    final router = await _pumpEventsRouter(tester, '/events/event-123/chat');

    expect(router.getCurrentLocation(), '/events/event-123/chat');
    expect(find.byType(EventGroupChatWidget), findsOneWidget);
    expect(find.byType(EventDetailWidget), findsNothing);
    expect(find.text('event-123'), findsOneWidget);
    expect(find.byType(NavBarWidget), findsNothing);
  });

  testWidgets('router opens event detail path outside the tab shell',
      (tester) async {
    final router = await _pumpEventsRouter(tester, '/events/event-123');

    expect(router.getCurrentLocation(), '/events/event-123');
    expect(find.byType(EventDetailWidget), findsOneWidget);
    expect(find.text('event-123'), findsOneWidget);
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

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
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

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  return _RouterHarness(router: router, notifier: notifier);
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
