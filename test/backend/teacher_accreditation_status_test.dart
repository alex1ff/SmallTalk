import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/backend/schema/users_record.dart';
import 'package:small_talk/services/user_match_profile.dart';
import 'package:small_talk/services/teacher_verification_request_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

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

    test('derives explicit pending teacher signal without fallback magic', () {
      expect(hasPendingTeacherVerificationFromData({}), isFalse);
      expect(
        hasPendingTeacherVerificationFromData({
          'teacherAccreditationStatus': 'pending',
        }),
        isTrue,
      );
      expect(
        hasPendingTeacherVerificationFromData({
          'teacherVerificationStatus': 'pending',
        }),
        isTrue,
      );
      expect(
        hasPendingTeacherVerificationFromData({
          'teacherAccreditationStatus': 'approved',
        }),
        isFalse,
      );
      expect(
        hasPendingTeacherVerificationFromData({
          'teacherAccreditationStatus': 'rejected',
        }),
        isFalse,
      );
    });

    test('uses native speaker shell only for approved or explicit pending', () {
      final approvedUser = UsersRecord.getDocumentFromData(
        {
          'role': 'native_speaker',
          'teacherAccreditationStatus': 'approved',
        },
        UsersRecord.collection.doc('approved-shell-test'),
      );
      final pendingUser = UsersRecord.getDocumentFromData(
        {
          'role': 'native_speaker',
          'teacherAccreditationStatus': 'pending',
          'verif_NS': false,
        },
        UsersRecord.collection.doc('pending-shell-test'),
      );
      final rejectedUser = UsersRecord.getDocumentFromData(
        {
          'role': 'native_speaker',
          'teacherAccreditationStatus': 'rejected',
        },
        UsersRecord.collection.doc('rejected-shell-test'),
      );
      final studentUser = UsersRecord.getDocumentFromData(
        {
          'role': 'student',
          'teacherAccreditationStatus': 'pending',
        },
        UsersRecord.collection.doc('student-shell-test'),
      );
      final legacyNativeSpeaker = UsersRecord.getDocumentFromData(
        {
          'role': 'native_speaker',
        },
        UsersRecord.collection.doc('legacy-shell-test'),
      );

      expect(canUseNativeSpeakerShell(approvedUser), isTrue);
      expect(canUseNativeSpeakerShell(pendingUser), isTrue);
      expect(canUseNativeSpeakerShell(rejectedUser), isFalse);
      expect(canUseNativeSpeakerShell(studentUser), isFalse);
      expect(canUseNativeSpeakerShell(legacyNativeSpeaker), isFalse);
    });

    test(
        'restores native speaker track from approved, explicit pending, or request status',
        () {
      final approvedStudent = UsersRecord.getDocumentFromData(
        {
          'role': 'student',
          'teacherAccreditationStatus': 'approved',
        },
        UsersRecord.collection.doc('restore-approved-test'),
      );
      final explicitPendingStudent = UsersRecord.getDocumentFromData(
        {
          'role': 'student',
          'teacherAccreditationStatus': 'pending',
        },
        UsersRecord.collection.doc('restore-pending-test'),
      );
      final legacyStudent = UsersRecord.getDocumentFromData(
        {
          'role': 'student',
        },
        UsersRecord.collection.doc('restore-legacy-test'),
      );

      expect(canRestoreNativeSpeakerTrack(approvedStudent), isTrue);
      expect(canRestoreNativeSpeakerTrack(explicitPendingStudent), isTrue);
      expect(
        canRestoreNativeSpeakerTrack(
          legacyStudent,
          requestStatus: TeacherAccreditationStatus.pending,
        ),
        isTrue,
      );
      expect(
        canRestoreNativeSpeakerTrack(
          legacyStudent,
          requestStatus: TeacherAccreditationStatus.approved,
        ),
        isFalse,
      );
      expect(
        canRestoreNativeSpeakerTrack(
          legacyStudent,
          requestStatus: TeacherAccreditationStatus.rejected,
        ),
        isFalse,
      );
    });

    test('mirrors pending teacher status only when restore target is pending',
        () {
      final explicitPendingStudent = UsersRecord.getDocumentFromData(
        {
          'role': 'student',
          'teacherAccreditationStatus': 'pending',
        },
        UsersRecord.collection.doc('mirror-pending-test'),
      );
      final approvedStudent = UsersRecord.getDocumentFromData(
        {
          'role': 'student',
          'teacherAccreditationStatus': 'approved',
        },
        UsersRecord.collection.doc('mirror-approved-test'),
      );
      final legacyStudent = UsersRecord.getDocumentFromData(
        {
          'role': 'student',
        },
        UsersRecord.collection.doc('mirror-legacy-test'),
      );

      expect(
        shouldMirrorPendingTeacherStatusOnRestore(explicitPendingStudent),
        isTrue,
      );
      expect(
        shouldMirrorPendingTeacherStatusOnRestore(
          legacyStudent,
          requestStatus: TeacherAccreditationStatus.pending,
        ),
        isTrue,
      );
      expect(
        shouldMirrorPendingTeacherStatusOnRestore(approvedStudent),
        isFalse,
      );
      expect(
        shouldMirrorPendingTeacherStatusOnRestore(
          legacyStudent,
          requestStatus: TeacherAccreditationStatus.approved,
        ),
        isFalse,
      );
    });

    test('resolves profile teacher-track CTA for apply, reapply, and none', () {
      final studentUser = UsersRecord.getDocumentFromData(
        {
          'role': 'student',
        },
        UsersRecord.collection.doc('profile-student-test'),
      );
      final rejectedNativeSpeaker = UsersRecord.getDocumentFromData(
        {
          'role': 'native_speaker',
          'teacherAccreditationStatus': 'rejected',
        },
        UsersRecord.collection.doc('profile-rejected-test'),
      );
      final pendingNativeSpeaker = UsersRecord.getDocumentFromData(
        {
          'role': 'native_speaker',
          'teacherAccreditationStatus': 'pending',
        },
        UsersRecord.collection.doc('profile-pending-test'),
      );

      expect(
        resolveTeacherTrackProfileAction(studentUser),
        TeacherTrackProfileAction.apply,
      );
      expect(
        resolveTeacherTrackProfileAction(rejectedNativeSpeaker),
        TeacherTrackProfileAction.reapply,
      );
      expect(
        resolveTeacherTrackProfileAction(pendingNativeSpeaker),
        TeacherTrackProfileAction.none,
      );
    });
  });
}
