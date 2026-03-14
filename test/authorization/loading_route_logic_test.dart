import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/authorization/loading/loading_route_logic.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';

void main() {
  group('hasResolvedLoadingRouteState', () {
    test('waits for acquaintance before routing native speakers', () {
      expect(
        hasResolvedLoadingRouteState(
          role: UserRole.native_speaker,
          acquaintance: null,
          isProfileComplete: null,
        ),
        isFalse,
      );

      expect(
        hasResolvedLoadingRouteState(
          role: UserRole.native_speaker,
          acquaintance: false,
          isProfileComplete: null,
        ),
        isTrue,
      );
    });

    test('waits for isProfileComplete only on resumed student onboarding', () {
      expect(
        hasResolvedLoadingRouteState(
          role: UserRole.student,
          acquaintance: null,
          isProfileComplete: null,
        ),
        isFalse,
      );

      expect(
        hasResolvedLoadingRouteState(
          role: UserRole.student,
          acquaintance: false,
          isProfileComplete: null,
        ),
        isTrue,
      );

      expect(
        hasResolvedLoadingRouteState(
          role: UserRole.student,
          acquaintance: true,
          isProfileComplete: null,
        ),
        isFalse,
      );

      expect(
        hasResolvedLoadingRouteState(
          role: UserRole.student,
          acquaintance: true,
          isProfileComplete: false,
        ),
        isTrue,
      );
    });
  });

  group('resolveLoadingRouteDestination', () {
    test('returns native speaker onboarding when acquaintance is incomplete',
        () {
      final destination = resolveLoadingRouteDestination(
        role: UserRole.native_speaker,
        acquaintance: false,
        isProfileComplete: false,
      );

      expect(
        destination,
        LoadingRouteDestination.acquaintanceNativeSpeaker,
      );
    });

    test('returns native speaker dashboard when onboarding is complete', () {
      final destination = resolveLoadingRouteDestination(
        role: UserRole.native_speaker,
        acquaintance: true,
        isProfileComplete: true,
      );

      expect(
        destination,
        LoadingRouteDestination.dashboardNativeSpeaker,
      );
    });

    test('returns student onboarding start when acquaintance is incomplete',
        () {
      final destination = resolveLoadingRouteDestination(
        role: UserRole.student,
        acquaintance: false,
        isProfileComplete: false,
      );

      expect(
        destination,
        LoadingRouteDestination.acquaintanceStudentStart,
      );
    });

    test('returns student onboarding resume when profile is unfinished', () {
      final destination = resolveLoadingRouteDestination(
        role: UserRole.student,
        acquaintance: true,
        isProfileComplete: false,
      );

      expect(
        destination,
        LoadingRouteDestination.acquaintanceStudentResume,
      );
    });

    test('returns students dashboard when profile is complete', () {
      final destination = resolveLoadingRouteDestination(
        role: UserRole.student,
        acquaintance: true,
        isProfileComplete: true,
      );

      expect(
        destination,
        LoadingRouteDestination.studentsDashboard,
      );
    });

    test('returns null when role is still unresolved', () {
      final destination = resolveLoadingRouteDestination(
        role: null,
        acquaintance: false,
        isProfileComplete: false,
      );

      expect(destination, isNull);
    });
  });
}
