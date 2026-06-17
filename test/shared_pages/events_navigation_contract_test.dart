import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/auth/base_auth_user_provider.dart';
import 'package:small_talk/components/nav_bar_widget.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
import 'package:small_talk/shared_pages/events/event_detail_widget.dart';
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
          r'FFRoute\([\s\S]*name: EventDetailWidget\.routeName,[\s\S]*path: EventDetailWidget\.routePath,[\s\S]*requireAuth: true,[\s\S]*eventId[\s\S]*ParamType\.String',
        ),
      ),
    );
    expect(
      router.indexOf('name: EventDetailWidget.routeName'),
      lessThan(router.indexOf('ShellRoute(')),
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

  testWidgets('router opens event detail path outside the tab shell',
      (tester) async {
    final notifier = AppStateNotifier.instance;
    notifier.initialUser = null;
    notifier.clearRedirectLocation();
    notifier.showSplashImage = true;

    final user = _TestAuthUser(userId: 'events-user');
    currentUser = user;
    notifier.update(user);
    notifier.stopShowingSplashImage();

    final router = createRouter(notifier);
    router.go('/events/event-123');

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(router.getCurrentLocation(), '/events/event-123');
    expect(find.byType(EventDetailWidget), findsOneWidget);
    expect(find.text('event-123'), findsOneWidget);
    expect(find.byType(NavBarWidget), findsNothing);
  });
}

class _TestAuthUser extends BaseAuthUser {
  _TestAuthUser({required this.userId});

  final String userId;

  @override
  bool get loggedIn => true;

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
