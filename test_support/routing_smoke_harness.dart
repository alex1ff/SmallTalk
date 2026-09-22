import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/auth/base_auth_user_provider.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';

class RoutingSmokeHarness {
  const RoutingSmokeHarness({required this.router, required this.notifier});

  final GoRouter router;
  final AppStateNotifier notifier;
}

class RoutingSmokeAuthUser extends BaseAuthUser {
  RoutingSmokeAuthUser({required this.isLoggedIn, this.userId});

  final bool isLoggedIn;
  final String? userId;

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

const routingSmokeOnboardingPath = '/onboarding';
const routingSmokeLoginPath = '/login';
const routingSmokeWaitingPath = '/waitingForTeacherPage';
const routingSmokeVideoCallPath = '/videoCallPage?videoDocRef=session-smoke';
const routingSmokeMyCallsPath = '/myCalls';
const routingSmokeCallDetailsPath = '/callDetails?videoDocRef=session-smoke';
const routingSmokePayPath = '/pay';
const routingSmokePayWebViewPath = '/payWebWiew';
const routingSmokeCallSummaryPath =
    '/callSummary?userRef=user-smoke&sessionID=session-smoke&lang=en&dur=30';

const routingSmokeProtectedPaths = <String>[
  routingSmokeWaitingPath,
  routingSmokeVideoCallPath,
  routingSmokeMyCallsPath,
  routingSmokeCallDetailsPath,
  routingSmokeCallSummaryPath,
  routingSmokePayPath,
  routingSmokePayWebViewPath,
];

Future<void> pumpRoutingSmoke(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<RoutingSmokeHarness> pumpRoutingSmokeRouter(
  WidgetTester tester, {
  required bool loggedIn,
  bool configureDesktopViewport = false,
}) async {
  if (configureDesktopViewport) {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  final notifier = AppStateNotifier.instance;
  notifier.initialUser = null;
  notifier.clearRedirectLocation();
  notifier.showSplashImage = true;
  final user = RoutingSmokeAuthUser(
    isLoggedIn: loggedIn,
    userId: loggedIn ? 'smoke-user' : null,
  );
  currentUser = user;
  notifier.update(user);
  notifier.stopShowingSplashImage();
  final router = createRouter(notifier);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await pumpRoutingSmoke(tester);
  return RoutingSmokeHarness(router: router, notifier: notifier);
}
