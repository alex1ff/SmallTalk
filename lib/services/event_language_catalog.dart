import 'dart:convert';

import 'package:flutter/services.dart';

const eventLanguageCatalogAssetPath = 'assets/jsons/languages_catalog.json';

class EventLanguageCatalog {
  factory EventLanguageCatalog({
    required List<EventLanguage> languages,
  }) =>
      EventLanguageCatalog._(
        languages: List.unmodifiable(languages),
      );

  const EventLanguageCatalog._({
    required this.languages,
  });

  final List<EventLanguage> languages;

  List<String> get primaryCodes => List.unmodifiable(
        languages.map((language) => language.code),
      );

  static Future<EventLanguageCatalog> loadFromAsset({
    AssetBundle? bundle,
    String assetPath = eventLanguageCatalogAssetPath,
  }) async {
    final rawCatalog = await (bundle ?? rootBundle).loadString(assetPath);
    return EventLanguageCatalog.fromJsonString(rawCatalog);
  }

  factory EventLanguageCatalog.fromJsonString(String rawCatalog) {
    final decoded = jsonDecode(rawCatalog);
    if (decoded is! List) {
      throw const FormatException('Language catalog must be a JSON list');
    }
    return EventLanguageCatalog.fromList(decoded);
  }

  factory EventLanguageCatalog.fromList(List<dynamic> data) {
    if (data.isEmpty) {
      throw const FormatException('Language catalog must not be empty');
    }

    final languages = <EventLanguage>[];
    for (var index = 0; index < data.length; index += 1) {
      final item = data[index];
      if (item is! Map) {
        throw FormatException('languages[$index] must be an object');
      }
      languages.add(EventLanguage.fromMap(Map<String, dynamic>.from(item)));
    }
    _assertUniqueLanguageAliases(languages);

    return EventLanguageCatalog(languages: languages);
  }

  EventLanguage? languageByPrimaryCode(String? code) {
    final normalizedCode = _normalizeLanguageCodeKey(code);
    if (normalizedCode == null) {
      return null;
    }
    for (final language in languages) {
      if (_normalizeLanguageCodeKey(language.code) == normalizedCode) {
        return language;
      }
    }
    return null;
  }

  List<EventLanguage> popularLanguages({int? limit}) {
    if (limit != null && limit <= 0) {
      return const [];
    }
    final popular = languages
        .where((language) => language.isPopular)
        .toList(growable: false);
    if (limit == null || popular.length <= limit) {
      return List.unmodifiable(popular);
    }
    return List.unmodifiable(popular.sublist(0, limit));
  }
}

class EventLanguage {
  factory EventLanguage({
    required String code,
    required List<String> alternateCodes,
    required String nameEn,
    required String nameRu,
    required String model,
    required bool isPopular,
    required String iconUrl,
  }) =>
      EventLanguage._(
        code: code,
        alternateCodes: List.unmodifiable(alternateCodes),
        nameEn: nameEn,
        nameRu: nameRu,
        model: model,
        isPopular: isPopular,
        iconUrl: iconUrl,
      );

  const EventLanguage._({
    required this.code,
    required this.alternateCodes,
    required this.nameEn,
    required this.nameRu,
    required this.model,
    required this.isPopular,
    required this.iconUrl,
  });

  final String code;
  final List<String> alternateCodes;
  final String nameEn;
  final String nameRu;
  final String model;
  final bool isPopular;
  final String iconUrl;

  factory EventLanguage.fromMap(Map<String, dynamic> data) {
    final code = _readRequiredString(data, 'code');
    final alternateCodes = _readStringList(data, 'alternateCodes');
    if (!alternateCodes.contains(code)) {
      throw FormatException('alternateCodes must include primary code $code');
    }

    return EventLanguage(
      code: code,
      alternateCodes: alternateCodes,
      nameEn: _readRequiredString(data, 'nameEn'),
      nameRu: _readRequiredString(data, 'nameRu'),
      model: _readRequiredString(data, 'model'),
      isPopular: _readRequiredBool(data, 'isPopular'),
      iconUrl: _readRequiredString(data, 'ss'),
    );
  }
}

void _assertUniqueLanguageAliases(List<EventLanguage> languages) {
  final aliasOwners = <String, String>{};
  final primaryCodes = <String>{};
  for (final language in languages) {
    final primaryKey = _normalizeLanguageCodeKey(language.code);
    if (primaryKey == null) {
      throw const FormatException('Language code is required');
    }
    if (!primaryCodes.add(primaryKey)) {
      throw FormatException('Duplicate language code ${language.code}');
    }

    for (final alias in language.alternateCodes) {
      final aliasKey = _normalizeLanguageCodeKey(alias);
      if (aliasKey == null) {
        throw FormatException('Empty language alias for ${language.code}');
      }
      final owner = aliasOwners[aliasKey];
      if (owner != null && owner != language.code) {
        throw FormatException('Duplicate language alias $alias');
      }
      aliasOwners[aliasKey] = language.code;
    }
  }
}

String? _normalizeLanguageCodeKey(String? code) {
  final normalized = code?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String _readRequiredString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key is required');
  }
  return value.trim();
}

bool _readRequiredBool(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! bool) {
    throw FormatException('$key is required');
  }
  return value;
}

List<String> _readStringList(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! List || value.isEmpty) {
    throw FormatException('$key must be a non-empty list');
  }
  return value.map((item) {
    if (item is! String || item.trim().isEmpty) {
      throw FormatException('$key must contain only non-empty strings');
    }
    return item.trim();
  }).toList(growable: false);
}
