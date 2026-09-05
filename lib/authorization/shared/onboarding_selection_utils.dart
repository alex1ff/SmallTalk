import '/backend/schema/structs/index.dart';
import '/services/supported_location_catalog.dart';

bool hasOnboardingLanguageSelection(LanguageStruct? language) {
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

bool hasOnboardingCountrySelection(CountryStruct? country) {
  return isSupportedCountryStruct(country);
}

LanguageStruct? cloneOnboardingLanguageSelection(LanguageStruct? language) {
  if (!hasOnboardingLanguageSelection(language)) {
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

CountryStruct? cloneOnboardingCountrySelection(CountryStruct? country) {
  if (!hasOnboardingCountrySelection(country)) {
    return null;
  }

  return CountryStruct(
    code: country!.hasCode() ? country.code : null,
    cityKey: country.hasCityKey() ? country.cityKey : null,
    nameEn: country.hasNameEn() ? country.nameEn : null,
    nameRu: country.hasNameRu() ? country.nameRu : null,
    flag: country.hasFlag() ? country.flag : null,
    languages: country.hasLanguages() ? country.languages : null,
    isPopular: country.hasIsPopular() ? country.isPopular : null,
    index: country.hasIndex() ? country.index : null,
  );
}
