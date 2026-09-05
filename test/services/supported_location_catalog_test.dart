import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/structs/index.dart';
import 'package:small_talk/flutter_flow/custom_functions.dart' as functions;
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/supported_location_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exposes exactly four supported locations in product order', () {
    expect(
      supportedLocations.map((location) => location.label),
      [
        'New York, US',
        'Bali, Indonesia',
        'Dubai, UAE',
        'Phuket, Thailand',
      ],
    );
    expect(
      supportedLocations.map((location) => location.identity),
      ['US:new_york', 'ID:bali', 'AE:dubai', 'TH:phuket'],
    );
  });

  test('Flutter selector list matches supported location catalog exactly', () {
    final selectorLocations = functions.countriesList();

    expect(selectorLocations, hasLength(4));
    expect(
      selectorLocations.map((location) =>
          '${location.code}:${location.cityKey}:${location.nameEn}'),
      supportedLocations.map((location) =>
          '${location.countryCode}:${location.cityKey}:${location.label}'),
    );
  });

  test('event asset contains every supported canonical identity', () {
    final catalog = EventCityCatalog.fromJsonString(
      File(eventCityCatalogAssetPath).readAsStringSync(),
    );

    expect(catalog.catalogVersion, supportedLocationCatalogVersion);
    expect(
      catalog.supportedCities.map((city) => city.identity),
      supportedLocations.map((location) => location.identity),
    );
  });

  test('legacy country-only and unsupported city values are reset logically',
      () {
    expect(
      resolveSupportedCountryStruct(
        CountryStruct(code: 'US', nameEn: 'United States'),
      ),
      isNull,
    );
    expect(
      resolveSupportedCountryStruct(
        CountryStruct(code: 'US', cityKey: 'los_angeles'),
      ),
      isNull,
    );
    expect(
      resolveSupportedCountryStruct(
        CountryStruct(code: 'US', cityKey: 'new_york'),
      )?.identity,
      'US:new_york',
    );
  });

  test('user location is valid only when both stored identities agree', () {
    expect(
      hasConsistentSupportedUserLocation(
        country: supportedLocations.first.toCountryStruct(),
        profileCity: supportedLocations.first.toProfileCityStruct(),
      ),
      isTrue,
    );
    expect(
      hasConsistentSupportedUserLocation(
        country: supportedLocations.first.toCountryStruct(),
        profileCity: supportedLocations[1].toProfileCityStruct(),
      ),
      isFalse,
    );
  });
}
