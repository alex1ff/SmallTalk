import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/authorization/loading/loading_route_logic.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';

void main() {
  group('hasResolvedLoadingRouteState', () {
    test('resolves once role is known for native speakers', () {
      expect(
        hasResolvedLoadingRouteState(
          role: UserRole.native_speaker,
          acquaintance: null,
          isProfileComplete: null,
        ),
        isTrue,
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

    test('resolves once role is known for student profiles', () {
      expect(
        hasResolvedLoadingRouteState(
          role: UserRole.student,
          acquaintance: null,
          isProfileComplete: null,
        ),
        isTrue,
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
        isTrue,
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
        hasInferredStudentProfileCompletion: false,
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
        hasInferredStudentProfileCompletion: false,
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
        hasInferredStudentProfileCompletion: false,
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
        hasInferredStudentProfileCompletion: false,
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
        hasInferredStudentProfileCompletion: false,
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
        hasInferredStudentProfileCompletion: false,
      );

      expect(destination, isNull);
    });

    test('routes legacy student without acquaintance flag to onboarding start',
        () {
      final destination = resolveLoadingRouteDestination(
        role: UserRole.student,
        acquaintance: null,
        isProfileComplete: null,
        hasInferredStudentProfileCompletion: false,
      );

      expect(
        destination,
        LoadingRouteDestination.acquaintanceStudentStart,
      );
    });

    test('routes legacy completed student without profile flag to dashboard',
        () {
      final destination = resolveLoadingRouteDestination(
        role: UserRole.student,
        acquaintance: true,
        isProfileComplete: null,
        hasInferredStudentProfileCompletion: true,
      );

      expect(
        destination,
        LoadingRouteDestination.studentsDashboard,
      );
    });

    test('routes legacy unfinished student without profile flag to resume', () {
      final destination = resolveLoadingRouteDestination(
        role: UserRole.student,
        acquaintance: true,
        isProfileComplete: null,
        hasInferredStudentProfileCompletion: false,
      );

      expect(
        destination,
        LoadingRouteDestination.acquaintanceStudentResume,
      );
    });
  });
}
