import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/authorization/acquaintance_s_t_u_d_e_n_t/student_onboarding_logic.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/backend/schema/structs/index.dart';
import 'package:small_talk/flutter_flow/uploaded_file.dart';

void main() {
  group('buildStudentOnboardingInitialState', () {
    test('hydrates existing student data and clones mutable fields', () {
      final learningLanguage = LanguageStruct(
        code: 'es',
        nameEn: 'Spanish',
        alternateCodes: <String>['spa'],
      );
      final preferredNativeLanguage = LanguageStruct(
        code: 'en',
        nameEn: 'English',
      );
      final preferredLocation = CountryStruct(
        code: 'US',
        nameEn: 'United States',
        flag: 'us',
      );
      final purpose = <String>['Travel', 'Work'];

      final initialState = buildStudentOnboardingInitialState(
        displayName: '  Alice  ',
        gender: Gender.female,
        level: Level.Intermediate,
        learningLanguage: learningLanguage,
        purpose: purpose,
        preferences: PreferencesStruct(
          preferredNativeLanguage: preferredNativeLanguage,
          preferredLocation: preferredLocation,
        ),
        photoUrl: ' https://cdn.example.com/photo.jpg ',
      );

      learningLanguage.code = 'de';
      learningLanguage.alternateCodes.add('ger');
      preferredNativeLanguage.nameEn = 'German';
      preferredLocation.code = 'DE';
      purpose.add('Culture');

      expect(initialState.displayName, 'Alice');
      expect(initialState.genderMale, isFalse);
      expect(initialState.level, Level.Intermediate);
      expect(initialState.learningLanguage?.code, 'es');
      expect(initialState.learningLanguage?.alternateCodes, <String>['spa']);
      expect(initialState.preferredNativeLanguage?.code, 'en');
      expect(initialState.preferredLocation?.code, 'US');
      expect(initialState.purpose, <String>['Travel', 'Work']);
      expect(initialState.photoUrl, 'https://cdn.example.com/photo.jpg');
    });

    test('uses safe defaults for incomplete profiles', () {
      final initialState = buildStudentOnboardingInitialState(
        displayName: null,
        gender: null,
        level: null,
        learningLanguage: null,
        purpose: null,
        preferences: null,
        photoUrl: null,
      );

      expect(initialState.displayName, isEmpty);
      expect(initialState.genderMale, isTrue);
      expect(initialState.level, Level.Basic);
      expect(initialState.learningLanguage, isNull);
      expect(initialState.purpose, isEmpty);
      expect(initialState.preferredNativeLanguage, isNull);
      expect(initialState.preferredLocation, isNull);
      expect(initialState.photoUrl, isEmpty);
    });
  });

  group('student onboarding completion helpers', () {
    test('requires either uploaded bytes or an existing remote photo', () {
      expect(
        hasStudentCompletionPhoto(
          localPhoto: null,
          existingPhotoUrl: null,
        ),
        isFalse,
      );

      expect(
        hasStudentCompletionPhoto(
          localPhoto: FFUploadedFile(
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
          ),
          existingPhotoUrl: '',
        ),
        isTrue,
      );

      expect(
        hasStudentCompletionPhoto(
          localPhoto: null,
          existingPhotoUrl: ' https://cdn.example.com/photo.jpg ',
        ),
        isTrue,
      );
    });

    test('accepts only meaningful language and country selections', () {
      expect(hasLanguageSelection(null), isFalse);
      expect(hasLanguageSelection(LanguageStruct()), isFalse);
      expect(
        hasLanguageSelection(
          LanguageStruct(
            code: 'en',
          ),
        ),
        isTrue,
      );

      expect(hasCountrySelection(null), isFalse);
      expect(hasCountrySelection(CountryStruct()), isFalse);
      expect(
        hasCountrySelection(
          CountryStruct(
            code: 'US',
          ),
        ),
        isTrue,
      );
    });

    test('clone helpers return null for empty selections', () {
      expect(cloneLanguageSelection(LanguageStruct()), isNull);
      expect(cloneCountrySelection(CountryStruct()), isNull);
    });

    test('builds full 8-step displayed flow when name and photo are visible',
        () {
      final pages = buildVisibleStudentPages(
        showName: true,
        showPhoto: true,
      );

      expect(pages.length, 9);
      expect(studentDisplayedTotalSteps(visiblePages: pages), 8);
      expect(pages.first, StudentOnboardingPage.name);
      expect(pages.last, StudentOnboardingPage.preferredLocation);
    });

    test('reduces displayed steps when only name is hidden', () {
      final pages = buildVisibleStudentPages(
        showName: false,
        showPhoto: true,
      );

      expect(studentDisplayedTotalSteps(visiblePages: pages), 7);
      expect(pages, isNot(contains(StudentOnboardingPage.name)));
      expect(
        resolveStudentInitialPage(
          requestedRawIndex: 0,
          visiblePages: pages,
        ),
        StudentOnboardingPage.gender.index,
      );
    });

    test('reduces displayed steps when name and photo are hidden', () {
      final pages = buildVisibleStudentPages(
        showName: false,
        showPhoto: false,
      );

      expect(studentDisplayedTotalSteps(visiblePages: pages), 6);
      expect(pages, isNot(contains(StudentOnboardingPage.name)));
      expect(pages, isNot(contains(StudentOnboardingPage.photo)));
    });

    test('keeps interstitial page non-counted in progress', () {
      final pages = buildVisibleStudentPages(
        showName: false,
        showPhoto: true,
      );

      expect(
        studentDisplayedCurrentStep(
          currentRawIndex: StudentOnboardingPage.interstitial.index,
          visiblePages: pages,
        ),
        3,
      );
      expect(
        studentDisplayedCurrentStep(
          currentRawIndex: StudentOnboardingPage.preferredNativeLanguage.index,
          visiblePages: pages,
        ),
        6,
      );
    });
  });
}
