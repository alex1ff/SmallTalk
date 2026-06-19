import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/authorization/shared/social_auth_entry_logic.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';

void main() {
  group('resolveSocialAuthEntryDecision', () {
    test('routes existing users to loading and ignores toggle', () {
      final decision = resolveSocialAuthEntryDecision(
        hasAssignedRole: true,
        nativeSpeakerIntent: true,
        hasStudentBalance: true,
      );

      expect(decision.destination, SocialAuthEntryDestination.loading);
      expect(decision.roleToAssign, isNull);
      expect(decision.grantStudentBonus, isFalse);
    });

    test('routes first social native speaker registration to teacher flow', () {
      final decision = resolveSocialAuthEntryDecision(
        hasAssignedRole: false,
        nativeSpeakerIntent: true,
        hasStudentBalance: false,
      );

      expect(
        decision.destination,
        SocialAuthEntryDestination.acquaintanceNativeSpeaker,
      );
      expect(decision.roleToAssign, UserRole.native_speaker);
      expect(decision.grantStudentBonus, isFalse);
    });

    test('routes first social student registration to student flow', () {
      final decision = resolveSocialAuthEntryDecision(
        hasAssignedRole: false,
        nativeSpeakerIntent: false,
        hasStudentBalance: false,
      );

      expect(
        decision.destination,
        SocialAuthEntryDestination.acquaintanceStudent,
      );
      expect(decision.roleToAssign, UserRole.student);
      expect(decision.grantStudentBonus, isTrue);
    });

    test('does not duplicate student bonus when balance already exists', () {
      final decision = resolveSocialAuthEntryDecision(
        hasAssignedRole: false,
        nativeSpeakerIntent: false,
        hasStudentBalance: true,
      );

      expect(
        decision.destination,
        SocialAuthEntryDestination.acquaintanceStudent,
      );
      expect(decision.roleToAssign, UserRole.student);
      expect(decision.grantStudentBonus, isFalse);
    });
  });

  group('inferRoleFromProfileShape', () {
    test('student role persistence deletes legacy availabilityToday', () {
      final source = File(
        'lib/authorization/shared/social_auth_entry_logic.dart',
      ).readAsStringSync();
      final persistRoleBody = RegExp(
        r'Future<UsersRecord\?> persistCanonicalUserRole\([\s\S]*?\n}',
      ).firstMatch(source)!.group(0)!;

      expect(persistRoleBody, contains('role == UserRole.student'));
      expect(persistRoleBody, contains("updateData['availabilityToday']"));
      expect(persistRoleBody, contains('FieldValue.delete()'));
    });

    test('does not treat availabilityToday as a teacher role signal', () {
      final source = File(
        'lib/authorization/shared/social_auth_entry_logic.dart',
      ).readAsStringSync();
      final teacherSignalsBody = RegExp(
        r'bool _hasTeacherRoleSignals\([\s\S]*?\n}',
      ).firstMatch(source)!.group(0)!;

      expect(teacherSignalsBody, isNot(contains('hasAvailabilityToday')));
    });

    test('infers native speaker when only teacher signals are present', () {
      expect(
        inferRoleFromProfileShape(
          hasTeacherSignals: true,
          hasStudentSignals: false,
        ),
        UserRole.native_speaker,
      );
    });

    test('infers student when only student signals are present', () {
      expect(
        inferRoleFromProfileShape(
          hasTeacherSignals: false,
          hasStudentSignals: true,
        ),
        UserRole.student,
      );
    });

    test('returns null when signals are ambiguous', () {
      expect(
        inferRoleFromProfileShape(
          hasTeacherSignals: true,
          hasStudentSignals: true,
        ),
        isNull,
      );
    });
  });

  group('resolveLoadingRecoveryDecisionFromState', () {
    test('prefers pending social intent over profile inference', () {
      final decision = resolveLoadingRecoveryDecisionFromState(
        resolutionStatus:
            AuthenticatedUserProfileResolutionStatus.missingProfile,
        hasUserDocument: false,
        hasStudentBalance: false,
        pendingContextRole: UserRole.native_speaker,
        inferredRole: UserRole.student,
      );

      expect(decision.action, LoadingRecoveryAction.assignRole);
      expect(decision.roleToAssign, UserRole.native_speaker);
      expect(decision.recoverySource, UserRoleRecoverySource.pendingIntent);
      expect(decision.grantStudentBonus, isFalse);
    });

    test('heals student role from profile shape and grants first bonus once',
        () {
      final decision = resolveLoadingRecoveryDecisionFromState(
        resolutionStatus:
            AuthenticatedUserProfileResolutionStatus.resolvedCanonical,
        hasUserDocument: true,
        hasStudentBalance: false,
        pendingContextRole: null,
        inferredRole: UserRole.student,
      );

      expect(decision.action, LoadingRecoveryAction.assignRole);
      expect(decision.roleToAssign, UserRole.student);
      expect(decision.recoverySource, UserRoleRecoverySource.profileShape);
      expect(decision.grantStudentBonus, isTrue);
    });

    test('shows manual chooser for ambiguous role-less profiles', () {
      final decision = resolveLoadingRecoveryDecisionFromState(
        resolutionStatus:
            AuthenticatedUserProfileResolutionStatus.resolvedCanonical,
        hasUserDocument: true,
        hasStudentBalance: false,
        pendingContextRole: null,
        inferredRole: null,
      );

      expect(decision.action, LoadingRecoveryAction.showManualRoleChoice);
      expect(decision.recoverySource, UserRoleRecoverySource.manualRecovery);
    });

    test('returns fatal error for duplicate legacy profiles', () {
      final decision = resolveLoadingRecoveryDecisionFromState(
        resolutionStatus:
            AuthenticatedUserProfileResolutionStatus.duplicateLegacyProfiles,
        hasUserDocument: false,
        hasStudentBalance: false,
        pendingContextRole: null,
        inferredRole: null,
      );

      expect(decision.action, LoadingRecoveryAction.fatalError);
      expect(decision.errorMessage, isNotEmpty);
    });
  });
}
