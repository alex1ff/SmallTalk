import 'dart:convert';

import 'package:flutter/services.dart';

const eventCityCatalogAssetPath = 'assets/jsons/events_city_catalog.json';

final RegExp eventCityKeyPattern = RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$');
final RegExp _spacePattern = RegExp(r'\s+');

class EventCityCatalog {
  const EventCityCatalog({
    required this.catalogVersion,
    required this.cities,
  });

  final String catalogVersion;
  final List<EventCity> cities;

  static Future<EventCityCatalog> loadFromAsset({
    AssetBundle? bundle,
    String assetPath = eventCityCatalogAssetPath,
  }) async {
    final rawCatalog = await (bundle ?? rootBundle).loadString(assetPath);
    return EventCityCatalog.fromJsonString(rawCatalog);
  }

  factory EventCityCatalog.fromJsonString(String rawCatalog) {
    final decoded = jsonDecode(rawCatalog);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('City catalog must be a JSON object');
    }
    return EventCityCatalog.fromMap(decoded);
  }

  factory EventCityCatalog.fromMap(Map<String, dynamic> data) {
    final catalogVersion = data['catalogVersion'];
    final citiesData = data['cities'];
    if (catalogVersion is! String || catalogVersion.trim().isEmpty) {
      throw const FormatException('City catalog version is required');
    }
    if (citiesData is! List || citiesData.isEmpty) {
      throw const FormatException('City catalog must contain cities');
    }

    final cities = <EventCity>[];
    for (var index = 0; index < citiesData.length; index += 1) {
      final item = citiesData[index];
      if (item is! Map) {
        throw FormatException('cities[$index] must be an object');
      }
      cities.add(EventCity.fromMap(Map<String, dynamic>.from(item)));
    }
    _assertUniqueCityIdentities(cities);

    return EventCityCatalog(
      catalogVersion: catalogVersion.trim(),
      cities: List.unmodifiable(cities),
    );
  }

  EventCity? resolve(String? countryCode, String? cityKey) {
    final normalized = normalizeEventCityIdentity(countryCode, cityKey);
    if (normalized == null) {
      return null;
    }
    for (final city in cities) {
      if (city.countryCode == normalized.countryCode &&
          city.cityKey == normalized.cityKey) {
        return city;
      }
    }
    return null;
  }

  List<EventCity> popularCities({
    String? countryCodeHint,
    int? limit,
  }) {
    final hint = normalizeEventCountryCode(countryCodeHint);
    final sorted = [...cities]..sort((left, right) {
        final countryRank = _countryHintRank(left, hint)
            .compareTo(_countryHintRank(right, hint));
        if (countryRank != 0) {
          return countryRank;
        }
        final priorityRank = right.priority.compareTo(left.priority);
        if (priorityRank != 0) {
          return priorityRank;
        }
        return left.identity.compareTo(right.identity);
      });
    if (limit == null || limit < 0 || sorted.length <= limit) {
      return sorted;
    }
    return sorted.sublist(0, limit);
  }

  List<EventCity> search(
    String query, {
    String? countryCodeHint,
    int? limit,
  }) {
    final normalizedQuery = normalizeEventCitySearchText(query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }
    final hint = normalizeEventCountryCode(countryCodeHint);
    final scored = <_ScoredCity>[];
    for (final city in cities) {
      final score = city._matchScore(normalizedQuery);
      if (score == null) {
        continue;
      }
      scored.add(_ScoredCity(
        city: city,
        score: score,
        countryHintRank: _countryHintRank(city, hint),
      ));
    }

    scored.sort((left, right) {
      final scoreRank = left.score.compareTo(right.score);
      if (scoreRank != 0) {
        return scoreRank;
      }
      final countryRank = left.countryHintRank.compareTo(right.countryHintRank);
      if (countryRank != 0) {
        return countryRank;
      }
      final priorityRank = right.city.priority.compareTo(left.city.priority);
      if (priorityRank != 0) {
        return priorityRank;
      }
      return left.city.identity.compareTo(right.city.identity);
    });

    final results = scored.map((match) => match.city).toList(growable: false);
    if (limit == null || limit < 0 || results.length <= limit) {
      return results;
    }
    return results.sublist(0, limit);
  }

  /// Manual city selection uses this instead of a capped search so ambiguous
  /// aliases can be shown with context instead of being auto-resolved.
  List<EventCitySearchOption> searchOptions(
    String query, {
    String? countryCodeHint,
  }) {
    return search(query, countryCodeHint: countryCodeHint)
        .map((city) => EventCitySearchOption(city: city))
        .toList(growable: false);
  }
}

class EventCitySearchOption {
  const EventCitySearchOption({
    required this.city,
  });

  final EventCity city;

  String get countryCode => city.countryCode;
  String get cityKey => city.cityKey;
  String get identity => city.identity;
  String get displayNameRu => city.cityNameRu;
  String get displayNameEn => city.cityNameEn;
  String get displayContext => city.cityDisplayContext;
}

class EventCityIdentity {
  const EventCityIdentity({
    required this.countryCode,
    required this.cityKey,
  });

  final String countryCode;
  final String cityKey;
}

class EventCity {
  const EventCity({
    required this.countryCode,
    required this.cityKey,
    required this.cityNameRu,
    required this.cityNameEn,
    required this.regionCode,
    required this.regionNameRu,
    required this.regionNameEn,
    required this.timeZoneId,
    required this.cityDisplayContext,
    required this.aliases,
    required this.transliterations,
    required this.priority,
  });

  final String countryCode;
  final String cityKey;
  final String cityNameRu;
  final String cityNameEn;
  final String? regionCode;
  final String? regionNameRu;
  final String? regionNameEn;
  final String timeZoneId;
  final String cityDisplayContext;
  final List<String> aliases;
  final List<String> transliterations;
  final int priority;

  String get identity => '$countryCode:$cityKey';

  factory EventCity.fromMap(Map<String, dynamic> data) {
    final countryCode = _readRequiredString(data, 'countryCode').toUpperCase();
    final cityKey = _readRequiredString(data, 'cityKey');
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)) {
      throw FormatException('Invalid countryCode for city $cityKey');
    }
    if (!eventCityKeyPattern.hasMatch(cityKey)) {
      throw FormatException('Invalid cityKey: $cityKey');
    }

    return EventCity(
      countryCode: countryCode,
      cityKey: cityKey,
      cityNameRu: _readRequiredString(data, 'nameRu'),
      cityNameEn: _readRequiredString(data, 'nameEn'),
      regionCode: _readNullableString(data, 'regionCode'),
      regionNameRu: _readNullableString(data, 'regionNameRu'),
      regionNameEn: _readNullableString(data, 'regionNameEn'),
      timeZoneId: _readRequiredString(data, 'timeZoneId'),
      cityDisplayContext: _readRequiredString(data, 'displayContext'),
      aliases: List.unmodifiable(_readStringList(data, 'aliases')),
      transliterations:
          List.unmodifiable(_readStringList(data, 'transliterations')),
      priority: _readRequiredInt(data, 'priority'),
    );
  }

  List<String> get _searchTerms => [
        cityKey.replaceAll('_', ' '),
        cityNameRu,
        cityNameEn,
        cityDisplayContext,
        if (regionCode != null) regionCode!,
        if (regionNameRu != null) regionNameRu!,
        if (regionNameEn != null) regionNameEn!,
        ...aliases,
        ...transliterations,
      ];

  int? _matchScore(String normalizedQuery) {
    var bestScore = 1 << 30;
    for (final term in _searchTerms) {
      final normalizedTerm = normalizeEventCitySearchText(term);
      if (normalizedTerm.isEmpty) {
        continue;
      }
      final score = _scoreTerm(normalizedTerm, normalizedQuery);
      if (score != null && score < bestScore) {
        bestScore = score;
      }
    }
    return bestScore == 1 << 30 ? null : bestScore;
  }

  static int? _scoreTerm(String term, String query) {
    if (term == query) {
      return 0;
    }
    if (term.startsWith(query)) {
      return 1;
    }
    if (term.contains(query)) {
      return 2;
    }
    return null;
  }
}

class _ScoredCity {
  const _ScoredCity({
    required this.city,
    required this.score,
    required this.countryHintRank,
  });

  final EventCity city;
  final int score;
  final int countryHintRank;
}

EventCityIdentity? normalizeEventCityIdentity(
  String? countryCode,
  String? cityKey,
) {
  final normalizedCountryCode = normalizeEventCountryCode(countryCode);
  final normalizedCityKey = cityKey?.trim();
  if (normalizedCountryCode == null ||
      normalizedCityKey == null ||
      !eventCityKeyPattern.hasMatch(normalizedCityKey)) {
    return null;
  }
  return EventCityIdentity(
    countryCode: normalizedCountryCode,
    cityKey: normalizedCityKey,
  );
}

String? normalizeEventCountryCode(String? countryCode) {
  final normalized = countryCode?.trim().toUpperCase();
  if (normalized == null || !RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) {
    return null;
  }
  return normalized;
}

String normalizeEventCitySearchText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(_spacePattern, ' ');
}

void _assertUniqueCityIdentities(List<EventCity> cities) {
  final seen = <String>{};
  for (final city in cities) {
    if (!seen.add(city.identity)) {
      throw FormatException('Duplicate city identity: ${city.identity}');
    }
  }
}

int _countryHintRank(EventCity city, String? countryCodeHint) =>
    city.countryCode == countryCodeHint ? 0 : 1;

String _readRequiredString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value.trim();
}

String? _readNullableString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be null or a non-empty string');
  }
  return value.trim();
}

List<String> _readStringList(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! List) {
    throw FormatException('$key must be a list');
  }
  return value.map((item) {
    if (item is! String || item.trim().isEmpty) {
      throw FormatException('$key must contain only non-empty strings');
    }
    return item.trim();
  }).toList(growable: false);
}

int _readRequiredInt(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! int) {
    throw FormatException('$key must be an integer');
  }
  return value;
}
