import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:small_talk/auth/base_auth_user_provider.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';

class _TestAuthUser extends BaseAuthUser {
  _TestAuthUser({
    required this.isLoggedIn,
    this.userId,
  });

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

class _Harness {
  const _Harness({
    required this.router,
    required this.notifier,
  });

  final GoRouter router;
  final AppStateNotifier notifier;
}

const _onboardingPath = '/onboarding';
const _loginPath = '/login';
const _waitingPath = '/waitingForTeacherPage';
const _videoCallPath = '/videoCallPage?videoDocRef=session-smoke';
const _payPath = '/pay';
const _payWebViewPath = '/payWebWiew';
const _callSummaryPath =
    '/callSummary?userRef=user-smoke&sessionID=session-smoke&lang=en&dur=30';

Future<void> _pumpForRouting(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<_Harness> _pumpRouter(
  WidgetTester tester, {
  required bool loggedIn,
}) async {
  final notifier = AppStateNotifier.instance;
  notifier.initialUser = null;
  notifier.clearRedirectLocation();
  notifier.showSplashImage = true;

  final user = _TestAuthUser(
    isLoggedIn: loggedIn,
    userId: loggedIn ? 'smoke-user' : null,
  );
  currentUser = user;
  notifier.update(user);
  notifier.stopShowingSplashImage();

  final router = createRouter(notifier);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await _pumpForRouting(tester);

  return _Harness(router: router, notifier: notifier);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    currentUser = null;
  });

  tearDown(() {
    currentUser = null;
    final notifier = AppStateNotifier.instance;
    notifier.clearRedirectLocation();
  });

  testWidgets('public auth routes stay accessible while signed out',
      (tester) async {
    final harness = await _pumpRouter(tester, loggedIn: false);

    harness.router.go(_onboardingPath);
    await _pumpForRouting(tester);
    expect(harness.router.getCurrentLocation(), _onboardingPath);

    harness.router.go(_loginPath);
    await _pumpForRouting(tester);
    expect(harness.router.getCurrentLocation(), _loginPath);
  });

  const protectedRoutePaths = <String>[
    _waitingPath,
    _videoCallPath,
    _callSummaryPath,
    _payPath,
    _payWebViewPath,
  ];

  for (final routePath in protectedRoutePaths) {
    testWidgets('redirects signed-out user from $routePath to onboarding',
        (tester) async {
      final harness = await _pumpRouter(tester, loggedIn: false);

      harness.router.go(routePath);
      await _pumpForRouting(tester);

      expect(harness.router.getCurrentLocation(), _onboardingPath);
      expect(harness.notifier.hasRedirect(), isTrue);
    });
  }

  testWidgets('restores pending protected route after sign-in', (tester) async {
    final harness = await _pumpRouter(tester, loggedIn: false);

    harness.router.go(_waitingPath);
    await _pumpForRouting(tester);
    expect(harness.router.getCurrentLocation(), _onboardingPath);

    final signedInUser = _TestAuthUser(isLoggedIn: true, userId: 'smoke-user');
    currentUser = signedInUser;
    harness.notifier.update(signedInUser);
    await _pumpForRouting(tester);

    expect(harness.router.getCurrentLocation(), _waitingPath);
    expect(harness.notifier.hasRedirect(), isFalse);
  });
}
