import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/event_city_catalog.dart';

void main() {
  late EventCityCatalog catalog;
  late Map<String, dynamic> rawCatalogData;

  setUpAll(() {
    final rawCatalog = File(eventCityCatalogAssetPath).readAsStringSync();
    rawCatalogData = Map<String, dynamic>.from(jsonDecode(rawCatalog) as Map);
    catalog = EventCityCatalog.fromMap(rawCatalogData);
  });

  test('loads static city catalog schema from app asset', () {
    expect(catalog.catalogVersion, 'events-city-catalog-mvp-2026-06-16');
    expect(catalog.cities.length, greaterThanOrEqualTo(10));

    final rawCities = rawCatalogData['cities'];
    expect(rawCities, isA<List>());
    final rawIdentities = <String>{};
    final rawCityMaps = <Map<String, dynamic>>[];
    for (final item in rawCities as List) {
      expect(item, isA<Map>());
      final rawCity = Map<String, dynamic>.from(item as Map);
      rawCityMaps.add(rawCity);
      final countryCode = _rawRequiredString(rawCity, 'countryCode');
      final cityKey = _rawRequiredString(rawCity, 'cityKey');
      final displayContext = _rawRequiredString(rawCity, 'displayContext');

      expect(RegExp(r'^[A-Z]{2}$').hasMatch(countryCode), isTrue);
      expect(eventCityKeyPattern.hasMatch(cityKey), isTrue);
      expect(rawIdentities.add('$countryCode:$cityKey'), isTrue);
      expect(displayContext, isNotEmpty);

      final regionCode = rawCity['regionCode'];
      if (regionCode != null) {
        expect(regionCode, isA<String>());
        expect((regionCode as String).trim(), isNotEmpty);
        expect(_rawRequiredString(rawCity, 'regionNameRu'), isNotEmpty);
        expect(_rawRequiredString(rawCity, 'regionNameEn'), isNotEmpty);
      }
    }
    _assertDuplicateDisplayNamesDisambiguated(rawCityMaps);

    final identities = <String>{};
    for (final city in catalog.cities) {
      expect(RegExp(r'^[A-Z]{2}$').hasMatch(city.countryCode), isTrue);
      expect(eventCityKeyPattern.hasMatch(city.cityKey), isTrue);
      expect(identities.add(city.identity), isTrue);
      expect(city.cityNameRu, isNotEmpty);
      expect(city.cityNameEn, isNotEmpty);
      expect(city.cityDisplayContext, isNotEmpty);
      expect(city.timeZoneId, contains('/'));
      expect(city.aliases, isNotEmpty);
      expect(city.transliterations, isNotEmpty);
      expect(city.priority, isA<int>());
    }
  });

  test('resolves canonical city identity without using display names', () {
    final city = catalog.resolve(' ru ', 'moscow');

    expect(city, isNotNull);
    expect(city!.countryCode, 'RU');
    expect(city.cityKey, 'moscow');
    expect(city.cityNameRu, 'Москва');
    expect(city.cityNameEn, 'Moscow');
    expect(city.cityDisplayContext, 'Россия');
    expect(city.timeZoneId, 'Europe/Moscow');
    expect(catalog.resolve('Россия', 'Москва'), isNull);
    expect(catalog.resolve('RU', 'Москва'), isNull);
    expect(catalog.resolve('RU', 'Moscow'), isNull);
    expect(catalog.resolve('RU', 'unknown_city'), isNull);
  });

  test('resolves the default city for a country code', () {
    expect(catalog.defaultCityForCountryCode(' ru ')?.identity, 'RU:moscow');
    expect(catalog.defaultCityForCountryCode('IT')?.identity, 'IT:rome');
    expect(catalog.defaultCityForCountryCode('NL'), isNull);
    expect(catalog.defaultCityForCountryCode('Russia'), isNull);
    expect(catalog.defaultCityForCountryCode(null), isNull);
  });

  test('searches names aliases and transliterations', () {
    expect(catalog.search('NYC').single.identity, 'US:new_york');
    expect(catalog.search('Roma').single.identity, 'IT:rome');
    expect(catalog.search('Sankt Peterburg').single.identity,
        'RU:saint_petersburg');
    expect(catalog.search('Дубай').single.identity, 'AE:dubai');
  });

  test('normalizes city search text consistently', () {
    expect(normalizeEventCitySearchText('  Sankt__PETERBURG  '),
        'sankt peterburg');
    expect(normalizeEventCitySearchText('New-York'), 'new york');
    expect(normalizeEventCitySearchText('  many   spaces  '), 'many spaces');
  });

  test('normalizes manual city search input to canonical city records', () {
    final city = catalog.search('  sankt__PETERBURG  ').single;

    expect(city.countryCode, 'RU');
    expect(city.cityKey, 'saint_petersburg');
    expect(city.timeZoneId, 'Europe/Moscow');
    expect(city.cityNameRu, 'Санкт-Петербург');
    expect(catalog.search('new-york').single.identity, 'US:new_york');
    expect(catalog.search('   '), isEmpty);
    expect(catalog.search('not in catalog'), isEmpty);
  });

  test('country hint ranks manual search matches without filtering countries',
      () {
    final searchCatalog = EventCityCatalog.fromMap({
      'catalogVersion': 'test',
      'cities': [
        _cityFixture(
          countryCode: 'US',
          cityKey: 'springfield_il',
          nameEn: 'Springfield',
          regionCode: 'IL',
          priority: 10,
        ),
        _cityFixture(
          countryCode: 'AU',
          cityKey: 'springfield_qld',
          nameEn: 'Springfield',
          regionCode: 'QLD',
          priority: 20,
        ),
      ],
    });

    final withoutHint = searchCatalog.search('springfield');
    final withHint = searchCatalog.search('springfield', countryCodeHint: 'US');

    expect(withoutHint.map((city) => city.identity), [
      'AU:springfield_qld',
      'US:springfield_il',
    ]);
    expect(withHint.map((city) => city.identity), [
      'US:springfield_il',
      'AU:springfield_qld',
    ]);
  });

  test('country hint ranks matches but does not hide other countries', () {
    final withoutHint = catalog.popularCities(limit: 2);
    final withHint = catalog.popularCities(countryCodeHint: 'IT', limit: 3);

    expect(withoutHint.first.cityKey, 'moscow');
    expect(withHint.first.cityKey, 'rome');
    expect(withHint.map((city) => city.countryCode), contains('RU'));
  });

  test('ambiguous aliases return all matches for caller-side disambiguation',
      () {
    final ambiguousCatalog = EventCityCatalog.fromMap({
      'catalogVersion': 'test',
      'cities': [
        _cityFixture(
          countryCode: 'US',
          cityKey: 'springfield_il',
          nameEn: 'Springfield',
          regionCode: 'IL',
          displayContext: 'Illinois, United States',
          aliases: const ['Twin City'],
          priority: 10,
        ),
        _cityFixture(
          countryCode: 'US',
          cityKey: 'springfield_ma',
          nameEn: 'Springfield',
          regionCode: 'MA',
          displayContext: 'Massachusetts, United States',
          aliases: const ['Twin City'],
          priority: 9,
        ),
        _cityFixture(
          countryCode: 'CA',
          cityKey: 'springfield_ns',
          nameEn: 'Springfield',
          regionCode: 'NS',
          displayContext: 'Nova Scotia, Canada',
          aliases: const ['Twin City'],
          priority: 12,
        ),
      ],
    });

    final options = ambiguousCatalog.searchOptions('Twin City');
    final optionsWithHint = ambiguousCatalog.searchOptions(
      'Twin City',
      countryCodeHint: 'US',
    );

    expect(options.map((option) => option.city.identity), [
      'CA:springfield_ns',
      'US:springfield_il',
      'US:springfield_ma',
    ]);
    expect(options.map((option) => option.displayContext), [
      'Nova Scotia, Canada',
      'Illinois, United States',
      'Massachusetts, United States',
    ]);
    expect(optionsWithHint.map((option) => option.city.identity), [
      'US:springfield_il',
      'US:springfield_ma',
      'CA:springfield_ns',
    ]);
    expect(optionsWithHint.map((option) => option.displayContext), [
      'Illinois, United States',
      'Massachusetts, United States',
      'Nova Scotia, Canada',
    ]);
    expect(optionsWithHint.first.countryCode, 'US');
    expect(optionsWithHint.first.cityKey, 'springfield_il');
    expect(optionsWithHint.first.identity, 'US:springfield_il');
    expect(optionsWithHint.first.displayNameEn, 'Springfield');
    expect(optionsWithHint.first.displayNameRu, 'Springfield');
  });

  test('search options expose ambiguity even when capped search would not', () {
    final ambiguousCatalog = EventCityCatalog.fromMap({
      'catalogVersion': 'test',
      'cities': [
        _cityFixture(
          countryCode: 'US',
          cityKey: 'springfield_il',
          nameEn: 'Springfield',
          regionCode: 'IL',
          regionNameRu: 'Иллинойс',
          regionNameEn: 'Illinois',
          displayContext: 'Illinois, United States',
          priority: 10,
        ),
        _cityFixture(
          countryCode: 'US',
          cityKey: 'springfield_ma',
          nameEn: 'Springfield',
          regionCode: 'MA',
          regionNameRu: 'Массачусетс',
          regionNameEn: 'Massachusetts',
          displayContext: 'Massachusetts, United States',
          priority: 9,
        ),
      ],
    });

    expect(ambiguousCatalog.search('Springfield', limit: 1), hasLength(1));
    expect(ambiguousCatalog.searchOptions('Springfield'), hasLength(2));
    expect(
      ambiguousCatalog.searchOptions('Springfield').map(
            (option) => option.displayContext,
          ),
      ['Illinois, United States', 'Massachusetts, United States'],
    );
  });

  test('empty city search options do not auto-resolve', () {
    expect(catalog.searchOptions('   '), isEmpty);
    expect(catalog.searchOptions('not in catalog'), isEmpty);
  });

  test('plain search still returns all ambiguous city matches', () {
    final ambiguousCatalog = EventCityCatalog.fromMap({
      'catalogVersion': 'test',
      'cities': [
        _cityFixture(
          countryCode: 'US',
          cityKey: 'springfield_il',
          nameEn: 'Springfield',
          regionCode: 'IL',
          priority: 10,
        ),
        _cityFixture(
          countryCode: 'US',
          cityKey: 'springfield_ma',
          nameEn: 'Springfield',
          regionCode: 'MA',
          priority: 9,
        ),
      ],
    });

    expect(ambiguousCatalog.search('Springfield').map((city) => city.cityKey), [
      'springfield_il',
      'springfield_ma',
    ]);
  });

  test('rejects duplicate country and city key identities', () {
    expect(
      () => EventCityCatalog.fromMap({
        'catalogVersion': 'test',
        'cities': [
          _cityFixture(
            countryCode: 'US',
            cityKey: 'springfield_il',
            nameEn: 'Springfield',
            regionCode: 'IL',
            priority: 10,
          ),
          _cityFixture(
            countryCode: 'US',
            cityKey: 'springfield_il',
            nameEn: 'Springfield',
            regionCode: 'IL',
            priority: 9,
          ),
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('duplicate display names require disambiguating context and region data',
      () {
    final ambiguousCatalog = EventCityCatalog.fromMap({
      'catalogVersion': 'test',
      'cities': [
        _cityFixture(
          countryCode: 'US',
          cityKey: 'springfield_il',
          nameEn: 'Springfield',
          regionCode: 'IL',
          regionNameRu: 'Иллинойс',
          regionNameEn: 'Illinois',
          displayContext: 'Illinois, United States',
          priority: 10,
        ),
        _cityFixture(
          countryCode: 'US',
          cityKey: 'springfield_ma',
          nameEn: 'Springfield',
          regionCode: 'MA',
          regionNameRu: 'Массачусетс',
          regionNameEn: 'Massachusetts',
          displayContext: 'Massachusetts, United States',
          priority: 9,
        ),
      ],
    });

    final options = ambiguousCatalog.searchOptions('Springfield');

    expect(options.map((option) => option.identity), [
      'US:springfield_il',
      'US:springfield_ma',
    ]);
    expect(options.map((option) => option.displayNameEn).toSet(), {
      'Springfield',
    });
    expect(options.map((option) => option.city.cityKey), [
      'springfield_il',
      'springfield_ma',
    ]);
    expect(options.map((option) => option.displayContext), [
      'Illinois, United States',
      'Massachusetts, United States',
    ]);
    expect(options.map((option) => option.city.regionCode), ['IL', 'MA']);
    expect(options.map((option) => option.city.regionNameRu), [
      'Иллинойс',
      'Массачусетс',
    ]);
    expect(options.map((option) => option.city.regionNameEn), [
      'Illinois',
      'Massachusetts',
    ]);
  });

  test('rejects duplicate display names without disambiguation metadata', () {
    final first = _cityFixture(
      countryCode: 'US',
      cityKey: 'springfield_il',
      nameEn: 'Springfield',
      regionCode: 'IL',
      regionNameRu: 'Иллинойс',
      regionNameEn: 'Illinois',
      displayContext: 'United States',
      priority: 10,
    );
    final second = _cityFixture(
      countryCode: 'US',
      cityKey: 'springfield_ma',
      nameEn: 'Springfield',
      regionCode: 'MA',
      regionNameRu: 'Массачусетс',
      regionNameEn: 'Massachusetts',
      displayContext: 'United States',
      priority: 9,
    );

    expect(
      () => _assertDuplicateDisplayNamesDisambiguated([first, second]),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => _assertDuplicateDisplayNamesDisambiguated([
        first,
        {
          ...second,
          'displayContext': 'Massachusetts, United States',
          'regionCode': null,
          'regionNameRu': null,
          'regionNameEn': null,
        },
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects malformed city catalog entries instead of dropping them', () {
    expect(
      () => EventCityCatalog.fromMap({
        'catalogVersion': 'test',
        'cities': ['bad-entry'],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}

String _rawRequiredString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value.trim();
}

void _assertDuplicateDisplayNamesDisambiguated(
  Iterable<Map<String, dynamic>> rawCities,
) {
  final cityMaps = rawCities.toList(growable: false);
  for (final nameKey in ['nameRu', 'nameEn']) {
    final byName = <String, List<Map<String, dynamic>>>{};
    for (final city in cityMaps) {
      final name = _rawRequiredString(city, nameKey).toLowerCase();
      byName.putIfAbsent(name, () => <Map<String, dynamic>>[]).add(city);
    }

    for (final group in byName.values.where((cities) => cities.length > 1)) {
      final contexts = <String>{};
      final byCountry = <String, List<Map<String, dynamic>>>{};
      for (final city in group) {
        final identity = '${_rawRequiredString(city, 'countryCode')}:'
            '${_rawRequiredString(city, 'cityKey')}';
        final displayContext = _rawRequiredString(city, 'displayContext');
        if (!contexts.add(displayContext)) {
          throw FormatException(
            'Duplicate city display name requires distinct context: $identity',
          );
        }
        byCountry
            .putIfAbsent(
              _rawRequiredString(city, 'countryCode'),
              () => <Map<String, dynamic>>[],
            )
            .add(city);
      }

      for (final countryGroup
          in byCountry.values.where((cities) => cities.length > 1)) {
        for (final city in countryGroup) {
          _rawRequiredString(city, 'regionCode');
          _rawRequiredString(city, 'regionNameRu');
          _rawRequiredString(city, 'regionNameEn');
          _rawRequiredString(city, 'displayContext');
        }
      }
    }
  }
}

Map<String, dynamic> _cityFixture({
  required String countryCode,
  required String cityKey,
  required String nameEn,
  required String regionCode,
  required int priority,
  String? regionNameRu,
  String? regionNameEn,
  String? displayContext,
  List<String>? aliases,
}) =>
    {
      'countryCode': countryCode,
      'cityKey': cityKey,
      'nameRu': nameEn,
      'nameEn': nameEn,
      'regionCode': regionCode,
      'regionNameRu': regionNameRu ?? regionCode,
      'regionNameEn': regionNameEn ?? regionCode,
      'timeZoneId': 'America/New_York',
      'displayContext': displayContext ?? regionCode,
      'aliases': aliases ?? [nameEn],
      'transliterations': [nameEn],
      'priority': priority,
    };
