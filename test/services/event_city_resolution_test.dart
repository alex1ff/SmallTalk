import 'dart:io';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_resolution.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EventCityCatalog catalog;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    catalog = EventCityCatalog.fromJsonString(
      File(eventCityCatalogAssetPath).readAsStringSync(),
    );
  });

  group('resolveSelectedEventCityFromProfileCity', () {
    test('resolves profile city to the canonical catalog city', () {
      final result = resolveSelectedEventCityFromProfileCity(
        profileCity: profileCityFixture(
          countryCode: ' ru ',
          cityKey: ' moscow ',
          cityNameRu: 'Wrong stored name',
          catalogVersion: catalog.catalogVersion,
        ),
        catalog: catalog,
      );

      expect(result.status, EventCityResolutionStatus.resolved);
      expect(result.hasResolvedCity, isTrue);
      expect(result.city?.countryCode, 'RU');
      expect(result.city?.cityKey, 'moscow');
      expect(result.city?.cityNameRu, 'Москва');
      expect(result.city?.timeZoneId, 'Europe/Moscow');
    });

    test('does not resolve missing or empty profile city', () {
      expect(
        resolveSelectedEventCityFromProfileCity(
          profileCity: null,
          catalog: catalog,
        ).status,
        EventCityResolutionStatus.missingProfileCity,
      );
      expect(
        resolveSelectedEventCityFromProfileCity(
          profileCity: ProfileCityStruct(),
          catalog: catalog,
        ).status,
        EventCityResolutionStatus.missingProfileCity,
      );
      expect(
        resolveSelectedEventCityFromProfileCity(
          profileCity: profileCityFixture(
            countryCode: ' ',
            cityKey: '',
            catalogVersion: catalog.catalogVersion,
          ),
          catalog: catalog,
        ).status,
        EventCityResolutionStatus.missingProfileCity,
      );
    });

    test('does not resolve stale or missing catalog versions', () {
      expect(
        resolveSelectedEventCityFromProfileCity(
          profileCity: profileCityFixture(catalogVersion: 'old-version'),
          catalog: catalog,
        ).status,
        EventCityResolutionStatus.staleCatalogVersion,
      );
      expect(
        resolveSelectedEventCityFromProfileCity(
          profileCity: profileCityFixture(catalogVersion: null),
          catalog: catalog,
        ).status,
        EventCityResolutionStatus.staleCatalogVersion,
      );
    });

    test('does not resolve malformed or unknown catalog identities', () {
      expect(
        resolveSelectedEventCityFromProfileCity(
          profileCity: profileCityFixture(
            countryCode: 'Russia',
            catalogVersion: catalog.catalogVersion,
          ),
          catalog: catalog,
        ).status,
        EventCityResolutionStatus.invalidIdentity,
      );
      expect(
        resolveSelectedEventCityFromProfileCity(
          profileCity: profileCityFixture(
            cityKey: 'Moscow',
            catalogVersion: catalog.catalogVersion,
          ),
          catalog: catalog,
        ).status,
        EventCityResolutionStatus.invalidIdentity,
      );
      expect(
        resolveSelectedEventCityFromProfileCity(
          profileCity: profileCityFixture(
            cityKey: 'unknown_city',
            catalogVersion: catalog.catalogVersion,
          ),
          catalog: catalog,
        ).status,
        EventCityResolutionStatus.unknownCatalogCity,
      );
    });

    test('reports stale catalog before identity validation', () {
      final result = resolveSelectedEventCityFromProfileCity(
        profileCity: profileCityFixture(
          countryCode: 'Russia',
          cityKey: 'Moscow',
          catalogVersion: 'old-version',
        ),
        catalog: catalog,
      );

      expect(result.status, EventCityResolutionStatus.staleCatalogVersion);
      expect(result.city, isNull);
    });
  });

  group('resolveSelectedEventCityFromUserProfile', () {
    test('does not resolve null user', () {
      final result = resolveSelectedEventCityFromUserProfile(
        user: null,
        catalog: catalog,
      );

      expect(result.status, EventCityResolutionStatus.missingProfileCity);
      expect(result.city, isNull);
    });

    test(
        'ignores legacy country and preference fields when profile city is missing',
        () {
      final user = userFixture(
        data: {
          'uid': 'uid-1',
          'Country_NS': {'code': 'RU'},
          'preferences': {
            'preferredLocation': {'code': 'US'},
          },
          'countryCode': 'IT',
          'cityKey': 'rome',
        },
      );

      final result = resolveSelectedEventCityFromUserProfile(
        user: user,
        catalog: catalog,
      );

      expect(result.status, EventCityResolutionStatus.missingProfileCity);
      expect(result.city, isNull);
    });

    test('ignores legacy fields when profile city map is empty', () {
      final user = userFixture(
        data: {
          'uid': 'uid-empty-city',
          'Country_NS': {'code': 'RU'},
          'preferences': {
            'preferredLocation': {'code': 'US'},
          },
          'countryCode': 'IT',
          'cityKey': 'rome',
          'profileCity': <String, dynamic>{},
        },
      );

      final result = resolveSelectedEventCityFromUserProfile(
        user: user,
        catalog: catalog,
      );

      expect(result.status, EventCityResolutionStatus.missingProfileCity);
      expect(result.city, isNull);
    });

    test('uses profile city even when legacy fields conflict', () {
      final user = userFixture(
        data: {
          'uid': 'uid-2',
          'Country_NS': {'code': 'RU'},
          'preferences': {
            'preferredLocation': {'code': 'IT'},
          },
          'countryCode': 'IT',
          'cityKey': 'rome',
          'profileCity': profileCityFixture(
            countryCode: 'US',
            cityKey: 'new_york',
            catalogVersion: catalog.catalogVersion,
          ).toMap(),
        },
      );

      final result = resolveSelectedEventCityFromUserProfile(
        user: user,
        catalog: catalog,
      );

      expect(result.status, EventCityResolutionStatus.resolved);
      expect(result.city?.countryCode, 'US');
      expect(result.city?.cityKey, 'new_york');
      expect(resolveEventCityCountryCodeHintFromUserProfile(user: user), 'RU');
    });
  });

  group('resolveEventCityCountryCodeHintFromUserProfile', () {
    test('uses Country_NS only as a normalized country hint', () {
      final user = userFixture(
        data: {
          'uid': 'uid-country-hint',
          'Country_NS': {'code': ' it '},
        },
      );

      final hint = resolveEventCityCountryCodeHintFromUserProfile(user: user);
      final selectedCity = resolveSelectedEventCityFromUserProfile(
        user: user,
        catalog: catalog,
      );

      expect(hint, 'IT');
      expect(catalog.popularCities().first.cityKey, 'moscow');
      expect(
          catalog.popularCities(countryCodeHint: hint).first.cityKey, 'rome');
      expect(selectedCity.status, EventCityResolutionStatus.missingProfileCity);
      expect(selectedCity.city, isNull);
      expect(selectedCity.hasResolvedCity, isFalse);
    });

    test('resolves hints directly from country structs', () {
      expect(
        resolveEventCityCountryCodeHintFromCountry(
          country: CountryStruct(code: ' ru '),
        ),
        'RU',
      );
      expect(
        resolveEventCityCountryCodeHintFromCountry(country: CountryStruct()),
        isNull,
      );
      expect(resolveEventCityCountryCodeHintFromCountry(country: null), isNull);
    });

    test('ignores missing and malformed Country_NS values', () {
      for (final data in <Map<String, dynamic>>[
        {'uid': 'uid-no-country'},
        {'uid': 'uid-null-country', 'Country_NS': null},
        {'uid': 'uid-non-map-country', 'Country_NS': 'RU'},
        {'uid': 'uid-empty-country', 'Country_NS': <String, dynamic>{}},
        {
          'uid': 'uid-blank-country',
          'Country_NS': {'code': ''},
        },
        {
          'uid': 'uid-name-country',
          'Country_NS': {'code': 'Russia'},
        },
        {
          'uid': 'uid-alpha3-country',
          'Country_NS': {'code': 'USA'},
        },
      ]) {
        expect(
          resolveEventCityCountryCodeHintFromUserProfile(
            user: userFixture(data: data),
          ),
          isNull,
          reason: 'Expected no hint for ${data['uid']}.',
        );
      }
      expect(
          resolveEventCityCountryCodeHintFromUserProfile(user: null), isNull);
    });

    test('does not use preferredLocation as a country hint', () {
      final preferredOnlyUser = userFixture(
        data: {
          'uid': 'uid-preferred-location-only',
          'preferences': {
            'preferredLocation': {'code': 'US'},
          },
        },
      );
      final malformedCountryUser = userFixture(
        data: {
          'uid': 'uid-preferred-location-with-malformed-country',
          'Country_NS': <String, dynamic>{},
          'preferences': {
            'preferredLocation': {'code': 'US'},
          },
        },
      );
      final conflictingCountryUser = userFixture(
        data: {
          'uid': 'uid-preferred-location-with-country',
          'Country_NS': {'code': 'RU'},
          'preferences': {
            'preferredLocation': {'code': 'US'},
          },
        },
      );

      expect(
        resolveEventCityCountryCodeHintFromUserProfile(
          user: preferredOnlyUser,
        ),
        isNull,
      );
      expect(
        resolveEventCityCountryCodeHintFromUserProfile(
          user: malformedCountryUser,
        ),
        isNull,
      );
      expect(
        resolveEventCityCountryCodeHintFromUserProfile(
          user: conflictingCountryUser,
        ),
        'RU',
      );
      final preferredOnlySelectedCity = resolveSelectedEventCityFromUserProfile(
        user: preferredOnlyUser,
        catalog: catalog,
      );
      expect(
        preferredOnlySelectedCity.status,
        EventCityResolutionStatus.missingProfileCity,
      );
      expect(preferredOnlySelectedCity.city, isNull);
      expect(preferredOnlySelectedCity.hasResolvedCity, isFalse);
    });

    test('keeps hint separate from stale or unknown profile city status', () {
      final staleUser = userFixture(
        data: {
          'uid': 'uid-stale-profile-city',
          'Country_NS': {'code': 'ru'},
          'profileCity': profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: 'old-version',
          ).toMap(),
        },
      );
      final unknownUser = userFixture(
        data: {
          'uid': 'uid-unknown-profile-city',
          'Country_NS': {'code': 'ru'},
          'profileCity': profileCityFixture(
            countryCode: 'RU',
            cityKey: 'unknown_city',
            catalogVersion: catalog.catalogVersion,
          ).toMap(),
        },
      );

      expect(
        resolveEventCityCountryCodeHintFromUserProfile(user: staleUser),
        'RU',
      );
      expect(
        resolveSelectedEventCityFromUserProfile(
          user: staleUser,
          catalog: catalog,
        ).status,
        EventCityResolutionStatus.staleCatalogVersion,
      );
      expect(
        resolveEventCityCountryCodeHintFromUserProfile(user: unknownUser),
        'RU',
      );
      expect(
        resolveSelectedEventCityFromUserProfile(
          user: unknownUser,
          catalog: catalog,
        ).status,
        EventCityResolutionStatus.unknownCatalogCity,
      );
    });

    test('does not let Country_NS override a valid profile city', () {
      final user = userFixture(
        data: {
          'uid': 'uid-profile-city-with-country-hint',
          'Country_NS': {'code': 'RU'},
          'profileCity': profileCityFixture(
            countryCode: 'US',
            cityKey: 'new_york',
            catalogVersion: catalog.catalogVersion,
          ).toMap(),
        },
      );

      final selectedCity = resolveSelectedEventCityFromUserProfile(
        user: user,
        catalog: catalog,
      );

      expect(resolveEventCityCountryCodeHintFromUserProfile(user: user), 'RU');
      expect(selectedCity.status, EventCityResolutionStatus.resolved);
      expect(selectedCity.city?.countryCode, 'US');
      expect(selectedCity.city?.cityKey, 'new_york');
    });
  });
}

ProfileCityStruct profileCityFixture({
  String? countryCode = 'RU',
  String? cityKey = 'moscow',
  String? cityNameRu = 'Москва',
  String? cityNameEn = 'Moscow',
  String? cityDisplayContext = 'Россия',
  String? catalogVersion = 'events-city-catalog-mvp-2026-06-16',
}) =>
    ProfileCityStruct(
      countryCode: countryCode,
      cityKey: cityKey,
      cityNameRu: cityNameRu,
      cityNameEn: cityNameEn,
      cityDisplayContext: cityDisplayContext,
      catalogVersion: catalogVersion,
    );

UsersRecord userFixture({required Map<String, dynamic> data}) =>
    UsersRecord.getDocumentFromData(
      data,
      UsersRecord.collection.doc(data['uid'] as String? ?? 'uid'),
    );
