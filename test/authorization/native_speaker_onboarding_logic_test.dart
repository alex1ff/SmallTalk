import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/authorization/acquaintance_n_s/native_speaker_onboarding_logic.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/flutter_flow/uploaded_file.dart';

void main() {
  group('buildVisibleNativeSpeakerPages', () {
    test('keeps full 8-step flow when nothing is prefilled', () {
      final pages = buildVisibleNativeSpeakerPages(
        showName: true,
        showPhoto: true,
      );

      expect(pages.length, 8);
      expect(pages.first, NativeSpeakerOnboardingPage.name);
      expect(pages.last, NativeSpeakerOnboardingPage.photo);
    });

    test('hides only name when display name is prefilled', () {
      final pages = buildVisibleNativeSpeakerPages(
        showName: false,
        showPhoto: true,
      );

      expect(pages.length, 7);
      expect(pages, isNot(contains(NativeSpeakerOnboardingPage.name)));
      expect(pages.last, NativeSpeakerOnboardingPage.photo);
    });

    test('hides only photo when profile photo is prefilled', () {
      final pages = buildVisibleNativeSpeakerPages(
        showName: true,
        showPhoto: false,
      );

      expect(pages.length, 7);
      expect(pages.first, NativeSpeakerOnboardingPage.name);
      expect(pages, isNot(contains(NativeSpeakerOnboardingPage.photo)));
    });

    test('hides both name and photo when both are prefilled', () {
      final pages = buildVisibleNativeSpeakerPages(
        showName: false,
        showPhoto: false,
      );

      expect(pages.length, 6);
      expect(pages, isNot(contains(NativeSpeakerOnboardingPage.name)));
      expect(pages, isNot(contains(NativeSpeakerOnboardingPage.photo)));
    });
  });

  group('native speaker page helpers', () {
    test('maps hidden first page to the first visible raw page', () {
      final pages = buildVisibleNativeSpeakerPages(
        showName: false,
        showPhoto: true,
      );

      expect(
        resolveNativeSpeakerInitialPage(
          requestedRawIndex: 0,
          visiblePages: pages,
        ),
        NativeSpeakerOnboardingPage.languageInstruction.index,
      );
    });

    test('profile entry normalizes to the first visible raw page', () {
      final pages = buildVisibleNativeSpeakerPages(
        showName: false,
        showPhoto: true,
      );

      expect(
        resolveNativeSpeakerEntryInitialPage(
          requestedRawIndex: NativeSpeakerOnboardingPage.country.index,
          visiblePages: pages,
          entrySource: NativeSpeakerOnboardingEntrySource.profile,
        ),
        NativeSpeakerOnboardingPage.languageInstruction.index,
      );
    });

    test('preserves progress counting against visible pages only', () {
      final pages = buildVisibleNativeSpeakerPages(
        showName: false,
        showPhoto: true,
      );

      expect(
        nativeSpeakerDisplayedStep(
          currentRawIndex:
              NativeSpeakerOnboardingPage.languageInstruction.index,
          visiblePages: pages,
        ),
        1,
      );
      expect(
        nativeSpeakerDisplayedStep(
          currentRawIndex: NativeSpeakerOnboardingPage.aboutMe.index,
          visiblePages: pages,
        ),
        5,
      );
    });

    test('accepts either local upload or existing remote photo', () {
      expect(
        hasNativeSpeakerCompletionPhoto(
          localPhoto: null,
          existingPhotoUrl: null,
        ),
        isFalse,
      );

      expect(
        hasNativeSpeakerCompletionPhoto(
          localPhoto: FFUploadedFile(
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
          ),
          existingPhotoUrl: '',
        ),
        isTrue,
      );

      expect(
        hasNativeSpeakerCompletionPhoto(
          localPhoto: null,
          existingPhotoUrl: 'https://cdn.example.com/photo.jpg',
        ),
        isTrue,
      );
    });
  });

  group('native speaker accreditation helpers', () {
    test('builds trimmed payload with only remaining accreditation keys', () {
      final draft = buildNativeSpeakerOnboardingDraft(
        displayName: 'Alice',
        languageInstruction: null,
        nativeLanguage: null,
        gender: null,
        country: null,
        aboutMe: 'About me',
        teachingExperience: '1_3_years',
        qualificationProof: 'certificate',
        localPhoto: null,
        existingPhotoUrl: '',
      );

      expect(
        buildNativeSpeakerAccreditationData(draft),
        <String, dynamic>{
          'teachingExperience': '1_3_years',
          'qualificationProof': 'certificate',
          'qualificationProofs': const <String>['certificate'],
        },
      );
    });

    test('validation only depends on remaining accreditation fields', () {
      final missingExperience = buildNativeSpeakerOnboardingDraft(
        displayName: 'Alice',
        languageInstruction: null,
        nativeLanguage: null,
        gender: null,
        country: null,
        aboutMe: 'About me',
        teachingExperience: null,
        qualificationProof: 'certificate',
        localPhoto: null,
        existingPhotoUrl: '',
      );

      final missingProof = updateNativeSpeakerOnboardingDraft(
        missingExperience,
        teachingExperience: '1_3_years',
        qualificationProof: null,
      );

      final completeDraft = updateNativeSpeakerOnboardingDraft(
        missingProof,
        qualificationProof: 'experience_only',
      );

      expect(hasNativeSpeakerAccreditationAnswers(missingExperience), isFalse);
      expect(hasNativeSpeakerAccreditationAnswers(missingProof), isFalse);
      expect(hasNativeSpeakerAccreditationAnswers(completeDraft), isTrue);
      expect(
        validateNativeSpeakerOnboardingPage(
          page: NativeSpeakerOnboardingPage.accreditation,
          draft: missingExperience,
        ),
        isNotNull,
      );
      expect(
        validateNativeSpeakerOnboardingPage(
          page: NativeSpeakerOnboardingPage.accreditation,
          draft: completeDraft,
        ),
        isNull,
      );
    });

    test('document proofs require at least one evidence file', () {
      final draftWithoutFiles = buildNativeSpeakerOnboardingDraft(
        displayName: 'Alice',
        languageInstruction: null,
        nativeLanguage: null,
        gender: null,
        country: null,
        aboutMe: 'About me',
        teachingExperience: '1_3_years',
        qualificationProofs: const <String>['degree', 'certificate'],
        qualificationProof: null,
        localPhoto: null,
        existingPhotoUrl: '',
      );

      final draftWithExistingFile = updateNativeSpeakerOnboardingDraft(
        draftWithoutFiles,
        existingQualificationFiles: const <NativeSpeakerEvidenceFile>[
          NativeSpeakerEvidenceFile(
            name: 'Diploma.pdf',
            storagePath:
                'users/native-speaker-test/teacher_verification/qualification_proofs/Diploma.pdf',
          ),
        ],
      );

      expect(hasNativeSpeakerAccreditationAnswers(draftWithoutFiles), isFalse);
      expect(
        validateNativeSpeakerOnboardingPage(
          page: NativeSpeakerOnboardingPage.accreditation,
          draft: draftWithoutFiles,
        ),
        'Добавьте файлы подтверждения',
      );
      expect(
          hasNativeSpeakerAccreditationAnswers(draftWithExistingFile), isTrue);
      expect(
        buildNativeSpeakerAccreditationData(draftWithExistingFile),
        <String, dynamic>{
          'teachingExperience': '1_3_years',
          'qualificationProof': 'degree',
          'qualificationProofs': const <String>['degree', 'certificate'],
          'qualificationProofFiles': const <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Diploma.pdf',
              'storagePath':
                  'users/native-speaker-test/teacher_verification/qualification_proofs/Diploma.pdf',
            },
          ],
        },
      );
    });

    test('document proofs also accept pending local files before upload', () {
      final draftWithLocalFile = buildNativeSpeakerOnboardingDraft(
        displayName: 'Alice',
        languageInstruction: null,
        nativeLanguage: null,
        gender: null,
        country: null,
        aboutMe: 'About me',
        teachingExperience: '1_3_years',
        qualificationProofs: const <String>['degree'],
        qualificationProof: null,
        localQualificationFiles: <FFUploadedFile>[
          FFUploadedFile(
            name: 'Diploma.pdf',
            originalFilename: 'Diploma.pdf',
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
          ),
        ],
        localPhoto: null,
        existingPhotoUrl: '',
      );

      expect(hasNativeSpeakerAccreditationAnswers(draftWithLocalFile), isTrue);
      expect(
        validateNativeSpeakerOnboardingPage(
          page: NativeSpeakerOnboardingPage.accreditation,
          draft: draftWithLocalFile,
        ),
        isNull,
      );
    });

    test('qualification proof toggle keeps exclusive options exclusive', () {
      expect(
        toggleNativeSpeakerQualificationProof(
            const <String>['degree'], 'certificate'),
        const <String>['degree', 'certificate'],
      );
      expect(
        toggleNativeSpeakerQualificationProof(
          const <String>['degree', 'certificate'],
          'none',
        ),
        const <String>['none'],
      );
      expect(
        toggleNativeSpeakerQualificationProof(
          const <String>['none'],
          'degree',
        ),
        const <String>['degree'],
      );
    });

    test('approved update data preserves verified teacher status', () {
      final payload = buildNativeSpeakerOnboardingPayload(
        draft: buildNativeSpeakerOnboardingDraft(
          displayName: 'Alice',
          languageInstruction: null,
          nativeLanguage: null,
          gender: Gender.female,
          country: null,
          aboutMe: 'About me',
          teachingExperience: '1_3_years',
          qualificationProof: 'certificate',
          localPhoto: null,
          existingPhotoUrl: '',
        ),
        photoUrl: 'https://cdn.example.com/photo.jpg',
      );

      final data = buildNativeSpeakerOnboardingUpdateData(
        payload: payload,
        markProfileComplete: true,
        switchToNativeSpeakerRole: true,
      );

      expect(data.containsKey('teacherAccreditationStatus'), isFalse);
      expect(data.containsKey('verif_NS'), isFalse);
      expect(data['role'], 'native_speaker');
    });

    test('pending update data mirrors pending teacher shell state only', () {
      final payload = buildNativeSpeakerOnboardingPayload(
        draft: buildNativeSpeakerOnboardingDraft(
          displayName: 'Alice',
          languageInstruction: null,
          nativeLanguage: null,
          gender: Gender.female,
          country: null,
          aboutMe: 'About me',
          teachingExperience: '1_3_years',
          qualificationProof: 'certificate',
          localPhoto: null,
          existingPhotoUrl: '',
        ),
        photoUrl: 'https://cdn.example.com/photo.jpg',
      );

      final data = buildNativeSpeakerOnboardingUpdateData(
        payload: payload,
        markProfileComplete: true,
        teacherAccreditationStatus: TeacherAccreditationStatus.pending,
      );

      expect(data['role'], 'native_speaker');
      expect(data['teacherAccreditationStatus'], 'pending');
      expect(data['verif_NS'], isFalse);
    });

    test('non-pending teacher statuses are not self-written by the client', () {
      final payload = buildNativeSpeakerOnboardingPayload(
        draft: buildNativeSpeakerOnboardingDraft(
          displayName: 'Alice',
          languageInstruction: null,
          nativeLanguage: null,
          gender: Gender.female,
          country: null,
          aboutMe: 'About me',
          teachingExperience: '1_3_years',
          qualificationProof: 'certificate',
          localPhoto: null,
          existingPhotoUrl: '',
        ),
        photoUrl: 'https://cdn.example.com/photo.jpg',
      );

      final data = buildNativeSpeakerOnboardingUpdateData(
        payload: payload,
        markProfileComplete: true,
        teacherAccreditationStatus: TeacherAccreditationStatus.approved,
      );

      expect(data.containsKey('teacherAccreditationStatus'), isFalse);
      expect(data.containsKey('verif_NS'), isFalse);
      expect(data.containsKey('role'), isFalse);
    });

    test('parses legacy accreditation payload into normalized state', () {
      final legacyState = parseNativeSpeakerAccreditationState(
        <String, dynamic>{
          'teachingExperience': '1_3_years',
          'qualificationProof': 'certificate',
          'qualificationProofFiles': const <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Certificate.pdf',
              'url':
                  'https://firebasestorage.googleapis.com/v0/b/demo/o/users%2Fnative-speaker-test%2Fteacher_verification%2Fqualification_proofs%2FCertificate.pdf?alt=media&token=secret',
            },
          ],
        },
      );

      expect(legacyState.teachingExperience, '1_3_years');
      expect(legacyState.qualificationProofs, const <String>['certificate']);
      expect(
        legacyState.evidenceFiles,
        const <NativeSpeakerEvidenceFile>[
          NativeSpeakerEvidenceFile(
            name: 'Certificate.pdf',
            storagePath:
                'users/native-speaker-test/teacher_verification/qualification_proofs/Certificate.pdf',
          ),
        ],
      );
    });
  });

  group('native speaker validation consistency', () {
    test('draft validation flags non-empty invalid names as incomplete', () {
      final draft = buildNativeSpeakerOnboardingDraft(
        displayName: 'Alice1',
        languageInstruction: null,
        nativeLanguage: null,
        gender: Gender.female,
        country: null,
        aboutMe: 'About me',
        teachingExperience: '1_3_years',
        qualificationProof: 'degree',
        localPhoto: null,
        existingPhotoUrl: 'https://cdn.example.com/photo.jpg',
      );

      final validation = validateNativeSpeakerOnboardingDraft(draft);

      expect(
          validation.missingPages, contains(NativeSpeakerOnboardingPage.name));
      expect(
        validateNativeSpeakerOnboardingPage(
          page: NativeSpeakerOnboardingPage.name,
          draft: draft,
        ),
        isNotNull,
      );
    });
  });
}
