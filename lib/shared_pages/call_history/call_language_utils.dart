import '/backend/schema/structs/index.dart';

String normalizeSessionLanguageCode(String? code) {
  return (code ?? '').trim().toLowerCase().replaceAll('_', '-');
}

LanguageStruct? findSessionLanguageByCode({
  required Iterable<LanguageStruct> languages,
  required String? code,
}) {
  final normalizedCode = normalizeSessionLanguageCode(code);
  if (normalizedCode.isEmpty) {
    return null;
  }

  final fallbackCodes = <String>{
    normalizedCode,
    normalizedCode.split('-').first,
  };

  for (final language in languages) {
    final normalizedCandidates = <String>{
      normalizeSessionLanguageCode(language.code),
      ...language.alternateCodes.map(normalizeSessionLanguageCode),
    }..removeWhere((value) => value.isEmpty);

    if (normalizedCandidates.any(fallbackCodes.contains)) {
      return language;
    }
  }

  return null;
}

String resolveSessionLanguageName({
  required Iterable<LanguageStruct> languages,
  required String? code,
  required bool useRussian,
  String fallback = '-',
}) {
  final language = findSessionLanguageByCode(
    languages: languages,
    code: code,
  );
  if (language == null) {
    return (code != null && code.isNotEmpty) ? code : fallback;
  }

  final localizedName = useRussian ? language.nameRu : language.nameEn;
  if (localizedName.isNotEmpty) {
    return localizedName;
  }

  return language.nameEn.isNotEmpty
      ? language.nameEn
      : ((code != null && code.isNotEmpty) ? code : fallback);
}
