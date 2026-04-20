import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/structs/index.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/services/teacher_verification_request_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('shouldReuseExistingTeacherVerificationStatus', () {
    test('reuses approved requests and allows resubmitting rejected ones', () {
      expect(
        shouldReuseExistingTeacherVerificationStatus(
          TeacherAccreditationStatus.approved,
        ),
        isTrue,
      );
      expect(
        shouldReuseExistingTeacherVerificationStatus(
          TeacherAccreditationStatus.pending,
        ),
        isFalse,
      );
      expect(
        shouldReuseExistingTeacherVerificationStatus(
          TeacherAccreditationStatus.rejected,
        ),
        isFalse,
      );
      expect(shouldReuseExistingTeacherVerificationStatus(null), isFalse);
    });
  });

  group('buildTeacherVerificationRequestData', () {
    test('keeps multi-proof accreditation payload intact', () {
      final userRef = FirebaseFirestore.instance.doc('users/native-speaker');

      final data = buildTeacherVerificationRequestData(
        userId: 'native-speaker',
        userRef: userRef,
        displayName: 'Alice',
        photoUrl: 'https://cdn.example.com/photo.jpg',
        aboutMe: 'About me',
        languageInstruction: LanguageStruct(
          code: 'en',
          nameEn: 'English',
          nameRu: 'Английский',
        ),
        nativeLanguage: LanguageStruct(
          code: 'ru',
          nameEn: 'Russian',
          nameRu: 'Русский',
        ),
        country: CountryStruct(
          code: 'US',
          nameEn: 'United States',
          nameRu: 'США',
        ),
        accreditation: const <String, dynamic>{
          'teachingExperience': '3_plus_years',
          'qualificationProof': 'degree',
          'qualificationProofs': <String>['degree', 'certificate'],
          'qualificationProofFiles': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Diploma.pdf',
              'storagePath':
                  'users/native-speaker/teacher_verification/qualification_proofs/Diploma.pdf',
            },
          ],
        },
        timestamp: 'server-ts',
        includeCreatedAt: true,
      );

      expect(data['status'], TeacherAccreditationStatus.pending.name);
      expect(
        data['accreditation'],
        const <String, dynamic>{
          'teachingExperience': '3_plus_years',
          'qualificationProof': 'degree',
          'qualificationProofs': <String>['degree', 'certificate'],
          'qualificationProofFiles': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Diploma.pdf',
              'storagePath':
                  'users/native-speaker/teacher_verification/qualification_proofs/Diploma.pdf',
            },
          ],
        },
      );
    });

    test(
        'prepareTeacherVerificationRequestWrite preserves multi-proof payload on resubmit',
        () {
      final userRef = FirebaseFirestore.instance.doc('users/native-speaker');
      final decision = prepareTeacherVerificationRequestWrite(
        userId: 'native-speaker',
        userRef: userRef,
        existingData: <String, dynamic>{
          'status': 'rejected',
          'createdAt': 'created-ts',
          'reviewComment': 'Old review',
          'reviewedBy': 'admin',
          'reviewedAt': 'reviewed-ts',
          'accreditation': <String, dynamic>{
            'teachingExperience': '0_1_year',
            'qualificationProof': 'other',
            'teachingFormats': <String>['conversation'],
          },
        },
        displayName: 'Alice',
        photoUrl: 'https://cdn.example.com/photo.jpg',
        aboutMe: 'About me',
        languageInstruction: null,
        nativeLanguage: null,
        country: null,
        accreditation: const <String, dynamic>{
          'teachingExperience': '3_plus_years',
          'qualificationProof': 'degree',
          'qualificationProofs': <String>['degree', 'certificate'],
          'qualificationProofFiles': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Diploma.pdf',
              'storagePath':
                  'users/native-speaker/teacher_verification/qualification_proofs/Diploma.pdf',
            },
          ],
        },
        timestamp: 'server-ts',
      );

      expect(decision.shouldWrite, isTrue);
      expect(decision.status, TeacherAccreditationStatus.pending);
      expect(decision.requestData?['createdAt'], 'created-ts');
      expect(decision.requestData?['reviewComment'], isNull);
      expect(
        decision.requestData?['accreditation'],
        const <String, dynamic>{
          'teachingExperience': '3_plus_years',
          'qualificationProof': 'degree',
          'qualificationProofs': <String>['degree', 'certificate'],
          'qualificationProofFiles': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Diploma.pdf',
              'storagePath':
                  'users/native-speaker/teacher_verification/qualification_proofs/Diploma.pdf',
            },
          ],
        },
      );
    });
  });

  group('teacher verification write recovery helpers', () {
    test('classifies retryable request write errors', () {
      expect(
        isTeacherVerificationRequestSubmissionError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'deadline-exceeded',
          ),
        ),
        isTrue,
      );
      expect(
        isTeacherVerificationRequestSubmissionError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        isTrue,
      );
      expect(
        isTeacherVerificationRequestSubmissionError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'invalid-argument',
          ),
        ),
        isFalse,
      );
      expect(
        isTeacherVerificationRequestAmbiguousWriteError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'deadline-exceeded',
          ),
        ),
        isTrue,
      );
      expect(
        isTeacherVerificationRequestAmbiguousWriteError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        isFalse,
      );
    });

    test('matches expected request payload while ignoring timestamps', () {
      final userRef = FirebaseFirestore.instance.doc('users/native-speaker');
      final expectedData = buildTeacherVerificationRequestData(
        userId: 'native-speaker',
        userRef: userRef,
        displayName: 'Alice',
        photoUrl: 'https://cdn.example.com/photo.jpg',
        aboutMe: 'About me',
        languageInstruction: LanguageStruct(
          code: 'en',
          nameEn: 'English',
          nameRu: 'Английский',
        ),
        nativeLanguage: LanguageStruct(
          code: 'ru',
          nameEn: 'Russian',
          nameRu: 'Русский',
        ),
        country: CountryStruct(
          code: 'US',
          nameEn: 'United States',
          nameRu: 'США',
        ),
        accreditation: const <String, dynamic>{
          'teachingExperience': '3_plus_years',
          'qualificationProof': 'degree',
          'qualificationProofs': <String>['degree', 'certificate'],
          'qualificationProofFiles': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Diploma.pdf',
              'storagePath':
                  'users/native-speaker/teacher_verification/qualification_proofs/Diploma.pdf',
            },
          ],
        },
        timestamp: 'server-ts',
        includeCreatedAt: true,
      );

      final actualData = <String, dynamic>{
        ...expectedData,
        'createdAt': 'different-created-ts',
        'updatedAt': 'different-updated-ts',
        'reviewComment': 'legacy review comment',
      };

      expect(
        teacherVerificationRequestMatchesExpected(
          actualData: actualData,
          expectedData: expectedData,
        ),
        isTrue,
      );
    });

    test('detects mismatched pending request payloads', () {
      final userRef = FirebaseFirestore.instance.doc('users/native-speaker');
      final expectedData = buildTeacherVerificationRequestData(
        userId: 'native-speaker',
        userRef: userRef,
        displayName: 'Alice',
        photoUrl: 'https://cdn.example.com/photo.jpg',
        aboutMe: 'About me',
        languageInstruction: null,
        nativeLanguage: null,
        country: null,
        accreditation: const <String, dynamic>{
          'teachingExperience': '3_plus_years',
          'qualificationProof': 'degree',
          'qualificationProofs': <String>['degree'],
        },
        timestamp: 'server-ts',
        includeCreatedAt: true,
      );

      final actualData = <String, dynamic>{
        ...expectedData,
        'accreditation': const <String, dynamic>{
          'teachingExperience': '0_1_year',
          'qualificationProof': 'degree',
          'qualificationProofs': <String>['degree'],
        },
      };

      expect(
        teacherVerificationRequestMatchesExpected(
          actualData: actualData,
          expectedData: expectedData,
        ),
        isFalse,
      );
    });

    test('recovers pending status from matching reread payload', () {
      final userRef = FirebaseFirestore.instance.doc('users/native-speaker');
      final expectedData = buildTeacherVerificationRequestData(
        userId: 'native-speaker',
        userRef: userRef,
        displayName: 'Alice',
        photoUrl: 'https://cdn.example.com/photo.jpg',
        aboutMe: 'About me',
        languageInstruction: null,
        nativeLanguage: null,
        country: null,
        accreditation: const <String, dynamic>{
          'teachingExperience': '3_plus_years',
          'qualificationProof': 'degree',
          'qualificationProofs': <String>['degree'],
        },
        timestamp: 'server-ts',
        includeCreatedAt: true,
      );

      final actualData = <String, dynamic>{
        ...expectedData,
        'createdAt': 'another-created-ts',
        'updatedAt': 'another-updated-ts',
      };

      expect(
        recoverTeacherVerificationRequestWriteStatus(
          actualData: actualData,
          expectedData: expectedData,
          expectedStatus: TeacherAccreditationStatus.pending,
        ),
        TeacherAccreditationStatus.pending,
      );
    });

    test('recovers approved status even when payload differs', () {
      final userRef = FirebaseFirestore.instance.doc('users/native-speaker');
      final expectedData = buildTeacherVerificationRequestData(
        userId: 'native-speaker',
        userRef: userRef,
        displayName: 'Alice',
        photoUrl: 'https://cdn.example.com/photo.jpg',
        aboutMe: 'About me',
        languageInstruction: null,
        nativeLanguage: null,
        country: null,
        accreditation: null,
        timestamp: 'server-ts',
        includeCreatedAt: true,
      );

      final actualData = <String, dynamic>{
        ...expectedData,
        'status': 'approved',
        'reviewComment': 'Approved by admin',
      };

      expect(
        recoverTeacherVerificationRequestWriteStatus(
          actualData: actualData,
          expectedData: expectedData,
          expectedStatus: TeacherAccreditationStatus.pending,
        ),
        TeacherAccreditationStatus.approved,
      );
    });
  });
}
