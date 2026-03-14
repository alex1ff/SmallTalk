import 'package:flutter_test/flutter_test.dart';
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
}
