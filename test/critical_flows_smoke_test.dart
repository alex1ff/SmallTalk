import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/auth/base_auth_user_provider.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
import '../test_support/routing_smoke_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    final harness = await pumpRoutingSmokeRouter(tester,
        loggedIn: false, configureDesktopViewport: true);

    harness.router.go(routingSmokeOnboardingPath);
    await pumpRoutingSmoke(tester);
    expect(harness.router.getCurrentLocation(), routingSmokeOnboardingPath);

    harness.router.go(routingSmokeLoginPath);
    await pumpRoutingSmoke(tester);
    expect(harness.router.getCurrentLocation(), routingSmokeLoginPath);
  });

  const protectedRoutePaths = routingSmokeProtectedPaths;

  for (final routePath in protectedRoutePaths) {
    testWidgets('redirects signed-out user from $routePath to onboarding',
        (tester) async {
      final harness = await pumpRoutingSmokeRouter(tester,
          loggedIn: false, configureDesktopViewport: true);

      harness.router.go(routePath);
      await pumpRoutingSmoke(tester);

      expect(harness.router.getCurrentLocation(), routingSmokeOnboardingPath);
      expect(harness.notifier.hasRedirect(), isTrue);
    });
  }

  testWidgets('restores pending protected route after sign-in', (tester) async {
    final harness = await pumpRoutingSmokeRouter(tester,
        loggedIn: false, configureDesktopViewport: true);

    harness.router.go(routingSmokeWaitingPath);
    await pumpRoutingSmoke(tester);
    expect(harness.router.getCurrentLocation(), routingSmokeOnboardingPath);

    final signedInUser =
        RoutingSmokeAuthUser(isLoggedIn: true, userId: 'smoke-user');
    currentUser = signedInUser;
    harness.notifier.update(signedInUser);
    await pumpRoutingSmoke(tester);

    expect(harness.router.getCurrentLocation(), routingSmokeWaitingPath);
    expect(harness.notifier.hasRedirect(), isFalse);
  });
}
