import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/event_city_catalog.dart';

void main() {
  late EventCityCatalog catalog;

  setUpAll(() {
    final rawCatalog = File(eventCityCatalogAssetPath).readAsStringSync();
    catalog = EventCityCatalog.fromJsonString(rawCatalog);
  });

  test('loads static city catalog schema from app asset', () {
    expect(catalog.catalogVersion, 'events-city-catalog-mvp-2026-06-16');
    expect(catalog.cities.length, greaterThanOrEqualTo(10));

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
    expect(catalog.resolve('RU', 'unknown_city'), isNull);
  });

  test('searches names aliases and transliterations', () {
    expect(catalog.search('NYC').single.cityKey, 'new_york');
    expect(catalog.search('Roma').single.cityKey, 'rome');
    expect(
        catalog.search('Sankt Peterburg').single.cityKey, 'saint_petersburg');
    expect(catalog.search('Дубай').single.cityKey, 'dubai');
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

    final matches = ambiguousCatalog.search('Springfield');

    expect(matches.map((city) => city.cityKey), [
      'springfield_il',
      'springfield_ma',
    ]);
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

Map<String, dynamic> _cityFixture({
  required String countryCode,
  required String cityKey,
  required String nameEn,
  required String regionCode,
  required int priority,
}) =>
    {
      'countryCode': countryCode,
      'cityKey': cityKey,
      'nameRu': nameEn,
      'nameEn': nameEn,
      'regionCode': regionCode,
      'regionNameRu': regionCode,
      'regionNameEn': regionCode,
      'timeZoneId': 'America/New_York',
      'displayContext': regionCode,
      'aliases': [nameEn],
      'transliterations': [nameEn],
      'priority': priority,
    };
