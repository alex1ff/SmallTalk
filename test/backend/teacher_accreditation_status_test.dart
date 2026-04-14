import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/backend/schema/users_record.dart';
import 'package:small_talk/services/teacher_verification_request_service.dart';

void main() {
  group('TeacherAccreditationStatus', () {
    test('deserializes canonical and legacy admin status values', () {
      expect(
        deserializeEnum<TeacherAccreditationStatus>('approved'),
        TeacherAccreditationStatus.approved,
      );
      expect(
        deserializeEnum<TeacherAccreditationStatus>('verified'),
        TeacherAccreditationStatus.approved,
      );
      expect(
        deserializeEnum<TeacherAccreditationStatus>('under review'),
        TeacherAccreditationStatus.pending,
      );
      expect(
        deserializeEnum<TeacherAccreditationStatus>('declined'),
        TeacherAccreditationStatus.rejected,
      );
    });

    test('resolves canonical status before legacy verif_NS', () {
      expect(
        resolveTeacherAccreditationStatusFromData({
          'teacherAccreditationStatus': 'rejected',
          'verif_NS': true,
        }),
        TeacherAccreditationStatus.rejected,
      );
    });

    test('falls back to legacy and matchProfile compatibility signals', () {
      expect(
        resolveTeacherAccreditationStatusFromData({'verif_NS': true}),
        TeacherAccreditationStatus.approved,
      );
      expect(
        resolveTeacherAccreditationStatusFromData({
          'matchProfile': {'teacherAccreditationStatus': 'approved'},
        }),
        TeacherAccreditationStatus.approved,
      );
      expect(
        resolveTeacherAccreditationStatusFromData({
          'matchProfile': {'approvedTeacher': true},
        }),
        TeacherAccreditationStatus.approved,
      );
      expect(
        resolveTeacherAccreditationStatusFromData({}),
        TeacherAccreditationStatus.pending,
      );
    });

    test('serializes canonical user field for Firestore writes', () {
      final data = createUsersRecordData(
        teacherAccreditationStatus: TeacherAccreditationStatus.approved,
      );

      expect(data['teacherAccreditationStatus'], 'approved');
    });

    test('resolves verification request status without downgrading terminals',
        () {
      expect(
        resolveTeacherVerificationRequestStatus({'status': 'verified'}),
        TeacherAccreditationStatus.approved,
      );
      expect(
        resolveTeacherVerificationRequestStatus({
          'teacherVerificationStatus': 'declined',
        }),
        TeacherAccreditationStatus.rejected,
      );
      expect(
        resolveTeacherVerificationRequestStatus({'status': 'pending'}),
        TeacherAccreditationStatus.pending,
      );
      expect(resolveTeacherVerificationRequestStatus({}), isNull);
    });
  });
}
