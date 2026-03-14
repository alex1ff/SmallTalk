import '/backend/schema/enums/enums.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/uploaded_file.dart';

class StudentOnboardingInitialState {
  const StudentOnboardingInitialState({
    required this.displayName,
    required this.genderMale,
    required this.level,
    required this.learningLanguage,
    required this.purpose,
    required this.preferredNativeLanguage,
    required this.preferredLocation,
    required this.photoUrl,
  });

  final String displayName;
  final bool genderMale;
  final Level level;
  final LanguageStruct? learningLanguage;
  final List<String> purpose;
  final LanguageStruct? preferredNativeLanguage;
  final CountryStruct? preferredLocation;
  final String photoUrl;
}

enum StudentOnboardingPage {
  name,
  gender,
  learningLanguage,
  level,
  interstitial,
  purpose,
  photo,
  preferredNativeLanguage,
  preferredLocation,
}

StudentOnboardingInitialState buildStudentOnboardingInitialState({
  required String? displayName,
  required Gender? gender,
  required Level? level,
  required LanguageStruct? learningLanguage,
  required List<String>? purpose,
  required PreferencesStruct? preferences,
  required String? photoUrl,
}) {
  return StudentOnboardingInitialState(
    displayName: (displayName ?? '').trim(),
    genderMale: gender != Gender.female,
    level: level ?? Level.Basic,
    learningLanguage: cloneLanguageSelection(learningLanguage),
    purpose: List<String>.from(purpose ?? const <String>[]),
    preferredNativeLanguage: cloneLanguageSelection(
      preferences != null && preferences.hasPreferredNativeLanguage()
          ? preferences.preferredNativeLanguage
          : null,
    ),
    preferredLocation: cloneCountrySelection(
      preferences != null && preferences.hasPreferredLocation()
          ? preferences.preferredLocation
          : null,
    ),
    photoUrl: (photoUrl ?? '').trim(),
  );
}

bool hasStudentCompletionPhoto({
  required FFUploadedFile? localPhoto,
  required String? existingPhotoUrl,
}) {
  return (localPhoto?.bytes?.isNotEmpty ?? false) ||
      (existingPhotoUrl?.trim().isNotEmpty ?? false);
}

bool hasLanguageSelection(LanguageStruct? language) {
  if (language == null) {
    return false;
  }
  return language.code.trim().isNotEmpty ||
      language.nameEn.trim().isNotEmpty ||
      language.nameRu.trim().isNotEmpty ||
      language.model.trim().isNotEmpty ||
      language.ss.trim().isNotEmpty ||
      language.alternateCodes.isNotEmpty;
}

bool hasCountrySelection(CountryStruct? country) {
  if (country == null) {
    return false;
  }
  return country.code.trim().isNotEmpty ||
      country.nameEn.trim().isNotEmpty ||
      country.nameRu.trim().isNotEmpty ||
      country.flag.trim().isNotEmpty ||
      country.languages.trim().isNotEmpty;
}

LanguageStruct? cloneLanguageSelection(LanguageStruct? language) {
  if (!hasLanguageSelection(language)) {
    return null;
  }
  return LanguageStruct(
    code: language!.hasCode() ? language.code : null,
    alternateCodes:
        language.hasAlternateCodes() ? language.alternateCodes.toList() : null,
    nameEn: language.hasNameEn() ? language.nameEn : null,
    nameRu: language.hasNameRu() ? language.nameRu : null,
    model: language.hasModel() ? language.model : null,
    isPopular: language.hasIsPopular() ? language.isPopular : null,
    ss: language.hasSs() ? language.ss : null,
  );
}

CountryStruct? cloneCountrySelection(CountryStruct? country) {
  if (!hasCountrySelection(country)) {
    return null;
  }
  return CountryStruct(
    code: country!.hasCode() ? country.code : null,
    nameEn: country.hasNameEn() ? country.nameEn : null,
    nameRu: country.hasNameRu() ? country.nameRu : null,
    flag: country.hasFlag() ? country.flag : null,
    languages: country.hasLanguages() ? country.languages : null,
    isPopular: country.hasIsPopular() ? country.isPopular : null,
    index: country.hasIndex() ? country.index : null,
  );
}

List<StudentOnboardingPage> buildVisibleStudentPages({
  required bool showName,
  required bool showPhoto,
}) {
  return StudentOnboardingPage.values.where((page) {
    switch (page) {
      case StudentOnboardingPage.name:
        return showName;
      case StudentOnboardingPage.photo:
        return showPhoto;
      default:
        return true;
    }
  }).toList(growable: false);
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
  return visiblePages
      .where((page) => page != StudentOnboardingPage.interstitial)
      .length;
}

int studentDisplayedCurrentStep({
  required int currentRawIndex,
  required List<StudentOnboardingPage> visiblePages,
}) {
  return visiblePages
      .where(
        (page) =>
            page != StudentOnboardingPage.interstitial &&
            page.index <= currentRawIndex,
      )
      .length;
}

bool isStudentLastVisiblePage({
  required int currentRawIndex,
  required List<StudentOnboardingPage> visiblePages,
}) {
  return visiblePages.isNotEmpty && visiblePages.last.index == currentRawIndex;
}
