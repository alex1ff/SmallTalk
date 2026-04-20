import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/authorization/acquaintance_s_t_u_d_e_n_t/student_onboarding_logic.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/backend/schema/structs/index.dart';

CountryStruct _country([String code = 'US']) => CountryStruct(
      code: code,
      nameEn: code,
    );

void main() {
  group('buildStudentOnboardingInitialState', () {
    test('hydrates existing student data and clones mutable fields', () {
      final learningLanguage = LanguageStruct(
        code: 'es',
        nameEn: 'Spanish',
        alternateCodes: <String>['spa'],
      );

      final initialState = buildStudentOnboardingInitialState(
        displayName: '  Alice  ',
        gender: Gender.female,
        level: Level.Intermediate,
        learningLanguage: learningLanguage,
        country: _country('ES'),
      );

      learningLanguage.code = 'de';
      learningLanguage.alternateCodes.add('ger');

      expect(initialState.displayName, 'Alice');
      expect(initialState.genderMale, isFalse);
      expect(initialState.level, Level.Intermediate);
      expect(initialState.learningLanguage?.code, 'es');
      expect(initialState.learningLanguage?.alternateCodes, <String>['spa']);
      expect(initialState.country?.code, 'ES');
    });

    test('exposes widget-safe defaults for missing draft fields', () {
      final initialState = buildStudentOnboardingInitialState(
        displayName: null,
        gender: null,
        level: null,
        learningLanguage: null,
        country: null,
      );

      expect(initialState.displayName, isEmpty);
      expect(initialState.genderMale, isTrue);
      expect(initialState.level, defaultStudentOnboardingLevel);
      expect(initialState.learningLanguage, isNull);
      expect(initialState.country, isNull);
    });
  });

  group('student onboarding contract helpers', () {
    test('updates drafts immutably and preserves legacy language selections',
        () {
      final original = buildStudentOnboardingDraft(
        displayName: null,
        gender: null,
        level: null,
        learningLanguage: null,
        country: null,
      );
      final legacyLanguage = LanguageStruct(
        code: 'kk',
        model: 'kaz-Latn',
        alternateCodes: <String>['kaz'],
      );

      final updated = updateStudentOnboardingDraft(
        original,
        displayName: '  Alice  ',
        gender: Gender.female,
        level: Level.Fluent,
        learningLanguage: legacyLanguage,
        country: _country('KZ'),
      );

      legacyLanguage.code = 'ru';
      legacyLanguage.alternateCodes.add('rus');

      expect(original.displayName, isEmpty);
      expect(original.gender, isNull);
      expect(original.level, isNull);
      expect(original.learningLanguage, isNull);
      expect(original.country, isNull);

      expect(updated.displayName, 'Alice');
      expect(updated.gender, Gender.female);
      expect(updated.level, Level.Fluent);
      expect(updated.learningLanguage?.code, 'kk');
      expect(updated.learningLanguage?.alternateCodes, <String>['kaz']);
      expect(updated.country?.code, 'KZ');

      final cleared = updateStudentOnboardingDraft(
        updated,
        learningLanguage: null,
        country: null,
      );
      expect(cleared.learningLanguage, isNull);
      expect(cleared.country, isNull);
      expect(updated.learningLanguage?.code, 'kk');
    });

    test('validates required fields while treating level as Basic by default',
        () {
      final validation = validateStudentOnboardingDraft(
        buildStudentOnboardingDraft(
          displayName: ' ',
          gender: null,
          level: null,
          learningLanguage: LanguageStruct(),
          country: null,
        ),
      );

      expect(
        validation.missingPages,
        <StudentOnboardingPage>[
          StudentOnboardingPage.name,
          StudentOnboardingPage.gender,
          StudentOnboardingPage.learningLanguage,
          StudentOnboardingPage.country,
        ],
      );
      expect(validation.isComplete, isFalse);
    });

    test('builds payloads with normalized defaults and legacy languages', () {
      final payload = buildStudentOnboardingPayload(
        buildStudentOnboardingDraft(
          displayName: '  Alice  ',
          gender: null,
          level: null,
          learningLanguage: LanguageStruct(
            code: 'kk',
            model: 'kaz-Latn',
            alternateCodes: <String>['kaz'],
          ),
          country: _country('KZ'),
        ),
      );

      expect(payload.displayName, 'Alice');
      expect(payload.gender, Gender.male);
      expect(payload.level, defaultStudentOnboardingLevel);
      expect(payload.learningLanguage?.code, 'kk');
      expect(payload.learningLanguage?.alternateCodes, <String>['kaz']);
      expect(payload.country?.code, 'KZ');
    });

    test('builds firestore updates for the student onboarding contract', () {
      final updateData = buildStudentOnboardingUpdateData(
        payload: buildStudentOnboardingPayload(
          buildStudentOnboardingDraft(
            displayName: ' Alice ',
            gender: Gender.female,
            level: Level.Intermediate,
            learningLanguage: LanguageStruct(
              code: 'ja',
              alternateCodes: <String>['jpn'],
            ),
            country: _country('JP'),
          ),
        ),
        markProfileComplete: true,
      );

      expect(updateData['display_name'], 'Alice');
      expect(updateData['Acquaintance'], isTrue);
      expect(updateData['isProfileComplete'], isTrue);
      expect(updateData['learningLanguage.code'], 'ja');
      expect(updateData['learningLanguage.alternateCodes'], <String>['jpn']);
      expect(updateData['Country_NS.code'], 'JP');
      expect(updateData.containsKey('photo_url'), isFalse);
    });

    test('validates page-level messages', () {
      expect(
        validateStudentOnboardingPage(
          page: StudentOnboardingPage.name,
          draft: buildStudentOnboardingDraft(
            displayName: '',
            gender: Gender.male,
            level: Level.Basic,
            learningLanguage: LanguageStruct(code: 'en'),
            country: _country(),
          ),
        ),
        'Пожалуйста, представьтесь',
      );

      expect(
        validateStudentOnboardingPage(
          page: StudentOnboardingPage.name,
          draft: buildStudentOnboardingDraft(
            displayName: 'John123',
            gender: Gender.male,
            level: Level.Basic,
            learningLanguage: LanguageStruct(code: 'en'),
            country: _country(),
          ),
        ),
        'Неверное имя',
      );

      for (final validName in <String>[
        'José Ángel',
        'Mary-Jane',
        'O’Connor',
        '李',
      ]) {
        expect(
          validateStudentOnboardingPage(
            page: StudentOnboardingPage.name,
            draft: buildStudentOnboardingDraft(
              displayName: validName,
              gender: Gender.male,
              level: Level.Basic,
              learningLanguage: LanguageStruct(code: 'en'),
              country: _country(),
            ),
          ),
          isNull,
        );
      }

      expect(
        validateStudentOnboardingPage(
          page: StudentOnboardingPage.learningLanguage,
          draft: buildStudentOnboardingDraft(
            displayName: 'Alice',
            gender: Gender.female,
            level: Level.Basic,
            learningLanguage: null,
            country: _country(),
          ),
        ),
        'Выберите язык из списка',
      );

      expect(
        validateStudentOnboardingPage(
          page: StudentOnboardingPage.country,
          draft: buildStudentOnboardingDraft(
            displayName: 'Alice',
            gender: Gender.female,
            level: Level.Basic,
            learningLanguage: LanguageStruct(code: 'en'),
            country: null,
          ),
        ),
        'Выберите страну из списка',
      );
    });

    test('filters allowed languages by primary and alternate codes', () {
      final result = filterAllowedLearningLanguages(
        allLanguages: <LanguageStruct>[
          LanguageStruct(code: 'en', nameEn: 'English'),
          LanguageStruct(code: 'ru', nameEn: 'Russian'),
          LanguageStruct(code: 'ja', alternateCodes: <String>['jpn']),
        ],
        allowedCodes: const <String>['ru', 'jpn'],
      );

      expect(
        result.map((language) => language.code).toList(),
        <String>['ru', 'ja'],
      );
    });

    test('accepts legacy non-en-ru learning languages in completion contract',
        () {
      expect(
        hasCompletedStudentOnboardingContract(
          acquaintance: true,
          displayName: 'Alice',
          gender: Gender.female,
          level: Level.Fluent,
          learningLanguage: LanguageStruct(
            code: 'kk',
            alternateCodes: <String>['kaz'],
          ),
          country: _country('KZ'),
        ),
        isTrue,
      );
    });
  });

  group('student onboarding navigation helpers', () {
    test('builds a 4-step flow when the name page is visible', () {
      final pages = buildVisibleStudentPages(
        showName: true,
        showPhoto: false,
      );

      expect(
        pages,
        <StudentOnboardingPage>[
          StudentOnboardingPage.name,
          StudentOnboardingPage.gender,
          StudentOnboardingPage.learningLanguage,
          StudentOnboardingPage.country,
          StudentOnboardingPage.level,
        ],
      );
      expect(studentDisplayedTotalSteps(visiblePages: pages), 5);
    });

    test('supports legacy resume indices while keeping legacy pages hidden',
        () {
      final pages = buildVisibleStudentPages(
        showName: false,
        showPhoto: false,
      );

      expect(
        pages,
        <StudentOnboardingPage>[
          StudentOnboardingPage.gender,
          StudentOnboardingPage.learningLanguage,
          StudentOnboardingPage.country,
          StudentOnboardingPage.level,
        ],
      );
      expect(
        resolveStudentInitialPage(
          requestedRawIndex: 4,
          visiblePages: pages,
        ),
        StudentOnboardingPage.level.index,
      );
      expect(
        studentDisplayedCurrentStep(
          currentRawIndex: StudentOnboardingPage.level.index,
          visiblePages: pages,
        ),
        4,
      );
      expect(
        isStudentLastVisiblePage(
          currentRawIndex: StudentOnboardingPage.level.index,
          visiblePages: pages,
        ),
        isTrue,
      );
    });
  });
}
