import '/backend/schema/enums/enums.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/users_record.dart';
import '/authorization/shared/onboarding_selection_utils.dart';
import '/services/supported_location_catalog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Object _studentOnboardingNoChange = Object();
const List<String> allowedStudentLearningLanguageCodes = <String>['en', 'ru'];
const Level defaultStudentOnboardingLevel = Level.Basic;

final RegExp _studentNameRegex = RegExp(
  r"^\p{L}[\p{L}\p{M}]*(?:[ '\-.ʼ’][\p{L}\p{M}]+)*$",
  unicode: true,
);

class StudentOnboardingDraft {
  const StudentOnboardingDraft({
    required this.displayName,
    Gender? gender,
    bool? genderMale,
    required this.level,
    required this.learningLanguage,
    required this.country,
  }) : _gender = gender ??
            (genderMale == null
                ? null
                : (genderMale ? Gender.male : Gender.female));

  final String displayName;
  final Gender? _gender;
  final Level? level;
  final LanguageStruct? learningLanguage;
  final CountryStruct? country;

  Gender? get gender => _gender;
  bool get genderMale => _gender != Gender.female;

  StudentOnboardingDraft copyWith({
    Object? displayName = _studentOnboardingNoChange,
    Object? gender = _studentOnboardingNoChange,
    Object? level = _studentOnboardingNoChange,
    Object? learningLanguage = _studentOnboardingNoChange,
    Object? country = _studentOnboardingNoChange,
  }) {
    return StudentOnboardingDraft(
      displayName: displayName == _studentOnboardingNoChange
          ? this.displayName
          : ((displayName as String?) ?? '').trim(),
      gender: gender == _studentOnboardingNoChange
          ? this.gender
          : gender as Gender?,
      level: level == _studentOnboardingNoChange ? this.level : level as Level?,
      learningLanguage: learningLanguage == _studentOnboardingNoChange
          ? cloneLanguageSelection(this.learningLanguage)
          : cloneLanguageSelection(learningLanguage as LanguageStruct?),
      country: country == _studentOnboardingNoChange
          ? cloneCountrySelection(this.country)
          : cloneCountrySelection(country as CountryStruct?),
    );
  }
}

class StudentOnboardingValidation {
  const StudentOnboardingValidation({
    required this.missingPages,
  });

  final List<StudentOnboardingPage> missingPages;

  bool get isComplete => missingPages.isEmpty;
}

class StudentOnboardingPayload {
  const StudentOnboardingPayload({
    required this.displayName,
    required this.gender,
    required this.level,
    required this.learningLanguage,
    required this.country,
  });

  final String? displayName;
  final Gender gender;
  final Level level;
  final LanguageStruct? learningLanguage;
  final CountryStruct? country;
}

class StudentOnboardingInitialState {
  const StudentOnboardingInitialState({
    required this.draft,
  });

  final StudentOnboardingDraft draft;

  String get displayName => draft.displayName;
  bool get genderMale => draft.gender != Gender.female;
  Level get level => draft.level ?? defaultStudentOnboardingLevel;
  LanguageStruct? get learningLanguage => draft.learningLanguage;
  CountryStruct? get country => draft.country;
}

enum StudentOnboardingPage {
  name,
  gender,
  learningLanguage,
  country,
  level,
}

StudentOnboardingDraft buildStudentOnboardingDraft({
  required String? displayName,
  required Gender? gender,
  required Level? level,
  required LanguageStruct? learningLanguage,
  required CountryStruct? country,
}) {
  return StudentOnboardingDraft(
    displayName: (displayName ?? '').trim(),
    gender: gender,
    level: level,
    learningLanguage: cloneLanguageSelection(learningLanguage),
    country: cloneCountrySelection(country),
  );
}

StudentOnboardingInitialState buildStudentOnboardingInitialState({
  required String? displayName,
  required Gender? gender,
  required Level? level,
  required LanguageStruct? learningLanguage,
  required CountryStruct? country,
}) {
  return StudentOnboardingInitialState(
    draft: buildStudentOnboardingDraft(
      displayName: displayName,
      gender: gender,
      level: level,
      learningLanguage: learningLanguage,
      country: country,
    ),
  );
}

StudentOnboardingDraft updateStudentOnboardingDraft(
  StudentOnboardingDraft draft, {
  Object? displayName = _studentOnboardingNoChange,
  Object? gender = _studentOnboardingNoChange,
  Object? level = _studentOnboardingNoChange,
  Object? learningLanguage = _studentOnboardingNoChange,
  Object? country = _studentOnboardingNoChange,
}) {
  return draft.copyWith(
    displayName: displayName,
    gender: gender,
    level: level,
    learningLanguage: learningLanguage,
    country: country,
  );
}

StudentOnboardingValidation validateStudentOnboardingDraft(
  StudentOnboardingDraft draft,
) {
  return StudentOnboardingValidation(
    missingPages: <StudentOnboardingPage>[
      if (draft.displayName.trim().isEmpty) StudentOnboardingPage.name,
      if (draft.gender == null) StudentOnboardingPage.gender,
      if (!hasLanguageSelection(draft.learningLanguage))
        StudentOnboardingPage.learningLanguage,
      if (!hasCountrySelection(draft.country)) StudentOnboardingPage.country,
    ],
  );
}

StudentOnboardingPayload buildStudentOnboardingPayload(
  StudentOnboardingDraft draft,
) {
  final normalizedDisplayName = draft.displayName.trim();
  return StudentOnboardingPayload(
    displayName: normalizedDisplayName.isEmpty ? null : normalizedDisplayName,
    gender: draft.gender ?? Gender.male,
    level: draft.level ?? defaultStudentOnboardingLevel,
    learningLanguage: cloneLanguageSelection(draft.learningLanguage),
    country: cloneCountrySelection(draft.country),
  );
}

Map<String, dynamic> buildStudentOnboardingUpdateData({
  required StudentOnboardingPayload payload,
  required bool markProfileComplete,
}) {
  final learningLanguage = cloneLanguageSelection(payload.learningLanguage);
  final country = cloneCountrySelection(payload.country);
  final location = resolveSupportedCountryStruct(country);
  final updateData = createUsersRecordData(
    displayName: payload.displayName,
    gender: payload.gender,
    level: payload.level,
    acquaintance: true,
    isProfileComplete: markProfileComplete ? true : null,
    learningLanguage: learningLanguage != null
        ? updateLanguageStruct(
            learningLanguage,
            clearUnsetFields: false,
          )
        : null,
    countryNS: country != null
        ? updateCountryStruct(
            country,
            clearUnsetFields: false,
          )
        : null,
    profileCity: location?.toProfileCityStruct(serverTimestamp: true),
  );
  updateData['availabilityToday'] = FieldValue.delete();
  return updateData;
}

Map<String, dynamic> buildStudentProfileUpdateData({
  required StudentOnboardingDraft draft,
  required bool markProfileComplete,
}) {
  return buildStudentOnboardingUpdateData(
    payload: buildStudentOnboardingPayload(draft),
    markProfileComplete: markProfileComplete,
  );
}

bool hasCompletedStudentOnboardingContract({
  required bool acquaintance,
  required String? displayName,
  required Gender? gender,
  required Level? level,
  required LanguageStruct? learningLanguage,
  required CountryStruct? country,
}) {
  if (!acquaintance) {
    return false;
  }

  return validateStudentOnboardingDraft(
    buildStudentOnboardingDraft(
      displayName: displayName,
      gender: gender,
      level: level,
      learningLanguage: learningLanguage,
      country: country,
    ),
  ).isComplete;
}

String? validateStudentOnboardingPage({
  required StudentOnboardingPage page,
  required StudentOnboardingDraft draft,
}) {
  switch (page) {
    case StudentOnboardingPage.name:
      if (draft.displayName.trim().isEmpty) {
        return 'Пожалуйста, представьтесь';
      }
      return _studentNameRegex.hasMatch(draft.displayName.trim())
          ? null
          : 'Неверное имя';
    case StudentOnboardingPage.learningLanguage:
      return hasLanguageSelection(draft.learningLanguage)
          ? null
          : 'Выберите язык из списка';
    case StudentOnboardingPage.country:
      return hasCountrySelection(draft.country)
          ? null
          : 'Выберите локацию из списка';
    case StudentOnboardingPage.gender:
    case StudentOnboardingPage.level:
      return null;
  }
}

bool hasLanguageSelection(LanguageStruct? language) {
  return hasOnboardingLanguageSelection(language);
}

bool hasCountrySelection(CountryStruct? country) {
  return hasOnboardingCountrySelection(country);
}

LanguageStruct? cloneLanguageSelection(LanguageStruct? language) {
  return cloneOnboardingLanguageSelection(language);
}

CountryStruct? cloneCountrySelection(CountryStruct? country) {
  return cloneOnboardingCountrySelection(country);
}

List<LanguageStruct> filterAllowedLearningLanguages({
  required List<LanguageStruct> allLanguages,
  required List<String> allowedCodes,
}) {
  final normalizedAllowedCodes = allowedCodes
      .map((code) => code.trim().toLowerCase())
      .where((code) => code.isNotEmpty)
      .toSet();
  if (normalizedAllowedCodes.isEmpty) {
    return const <LanguageStruct>[];
  }

  return allLanguages.where((language) {
    final normalizedCodes = <String>{
      language.code.trim().toLowerCase(),
      ...language.alternateCodes.map((code) => code.trim().toLowerCase()),
    }..remove('');
    return normalizedCodes.any(normalizedAllowedCodes.contains);
  }).toList(growable: false);
}

List<StudentOnboardingPage> buildVisibleStudentPages({
  required bool showName,
  required bool showPhoto,
}) {
  return <StudentOnboardingPage>[
    if (showName) StudentOnboardingPage.name,
    StudentOnboardingPage.gender,
    StudentOnboardingPage.learningLanguage,
    StudentOnboardingPage.country,
    StudentOnboardingPage.level,
  ];
}

int resolveStudentInitialPage({
  required int requestedRawIndex,
  required List<StudentOnboardingPage> visiblePages,
}) {
  if (visiblePages.isEmpty) {
    return 0;
  }

  final targetIndex = requestedRawIndex.clamp(
    0,
    StudentOnboardingPage.values.length - 1,
  );

  for (final page in visiblePages) {
    if (page.index >= targetIndex) {
      return page.index;
    }
  }

  return visiblePages.last.index;
}

int? nextVisibleStudentPage({
  required int currentRawIndex,
  required List<StudentOnboardingPage> visiblePages,
}) {
  for (final page in visiblePages) {
    if (page.index > currentRawIndex) {
      return page.index;
    }
  }
  return null;
}

int? previousVisibleStudentPage({
  required int currentRawIndex,
  required List<StudentOnboardingPage> visiblePages,
}) {
  for (final page in visiblePages.reversed) {
    if (page.index < currentRawIndex) {
      return page.index;
    }
  }
  return null;
}

int studentDisplayedTotalSteps({
  required List<StudentOnboardingPage> visiblePages,
}) {
  return visiblePages.length;
}

int studentDisplayedCurrentStep({
  required int currentRawIndex,
  required List<StudentOnboardingPage> visiblePages,
}) {
  return visiblePages.where((page) => page.index <= currentRawIndex).length;
}

bool isStudentLastVisiblePage({
  required int currentRawIndex,
  required List<StudentOnboardingPage> visiblePages,
}) {
  return visiblePages.isNotEmpty && visiblePages.last.index == currentRawIndex;
}
