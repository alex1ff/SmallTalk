import 'dart:io';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_resolution.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
import 'package:small_talk/services/event_selected_city_state.dart';

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

  group('resolveEventSelectedCityState', () {
    test('uses resolved profile city by default', () {
      final user = userFixture(
        data: {
          'uid': 'uid-profile-city',
          'Country_NS': {'code': 'US', 'cityKey': 'new_york'},
          'profileCity': profileCityFixture(
            countryCode: 'US',
            cityKey: 'new_york',
            catalogVersion: catalog.catalogVersion,
          ).toMap(),
        },
      );

      final state = resolveEventSelectedCityState(
        user: user,
        catalog: catalog,
      );

      expect(state.profileStatus, EventCityResolutionStatus.resolved);
      expect(state.countryCodeHint, 'US');
      expect(state.canLoadEvents, isTrue);
      expect(state.needsCitySelection, isFalse);
      expect(state.hasOutdatedProfileCity, isFalse);
      expect(state.selectedFromProfile, isTrue);
      expect(state.selectedTemporarily, isFalse);
      expect(state.selected?.city.identity, 'US:new_york');
      expect(state.selected?.source, EventCitySelectionSource.profile);
      expect(state.selected?.analyticsPayload, <String, String>{
        'countryCode': 'US',
        'cityKey': 'new_york',
        'citySource': 'profile',
      });
    });

    test('does not unlock disagreeing supported profile identities', () {
      final user = userFixture(
        data: {
          'uid': 'uid-inconsistent-location',
          'Country_NS': {'code': 'ID', 'cityKey': 'bali'},
          'profileCity': profileCityFixture(
            countryCode: 'US',
            cityKey: 'new_york',
            catalogVersion: catalog.catalogVersion,
          ).toMap(),
        },
      );

      final state = resolveEventSelectedCityState(
        user: user,
        catalog: catalog,
      );

      expect(
        state.profileStatus,
        EventCityResolutionStatus.inconsistentUserLocation,
      );
      expect(state.countryCodeHint, 'ID');
      expect(state.selected, isNull);
      expect(state.canLoadEvents, isFalse);
      expect(state.hasOutdatedProfileCity, isTrue);
    });

    test('does not infer a location from a legacy country hint', () {
      final user = userFixture(
        data: {
          'uid': 'uid-missing-profile-city',
          'Country_NS': {'code': 'it'},
          'preferences': {
            'preferredLocation': {'code': 'US'},
          },
          'countryCode': 'US',
          'cityKey': 'new_york',
        },
      );

      final state = resolveEventSelectedCityState(
        user: user,
        catalog: catalog,
      );

      expect(state.profileStatus, EventCityResolutionStatus.missingProfileCity);
      expect(state.countryCodeHint, 'IT');
      expect(state.selected, isNull);
      expect(state.canLoadEvents, isFalse);
      expect(state.needsCitySelection, isTrue);
      expect(state.hasOutdatedProfileCity, isFalse);
      expect(state.selectedFromProfile, isFalse);
    });

    test('Country_NS alone does not unlock Events', () {
      final user = userFixture(
        data: {
          'uid': 'uid-country-only',
          'Country_NS': {'code': ' RU '},
        },
      );

      final state = resolveEventSelectedCityState(
        user: user,
        catalog: catalog,
      );

      expect(state.profileStatus, EventCityResolutionStatus.missingProfileCity);
      expect(state.countryCodeHint, 'RU');
      expect(state.selected, isNull);
      expect(state.canLoadEvents, isFalse);
      expect(state.needsCitySelection, isTrue);
      expect(state.selectedFromProfile, isFalse);
      expect(state.selectedTemporarily, isFalse);
      expect(state.hasOutdatedProfileCity, isFalse);
    });

    test('preferredLocation alone does not unlock the Events list', () {
      final user = userFixture(
        data: {
          'uid': 'uid-preferred-location-only',
          'preferences': {
            'preferredLocation': {'code': 'US'},
          },
        },
      );

      final state = resolveEventSelectedCityState(
        user: user,
        catalog: catalog,
      );

      expect(state.profileStatus, EventCityResolutionStatus.missingProfileCity);
      expect(state.countryCodeHint, isNull);
      expect(state.selected, isNull);
      expect(state.canLoadEvents, isFalse);
      expect(state.needsCitySelection, isTrue);
      expect(state.selectedFromProfile, isFalse);
      expect(state.selectedTemporarily, isFalse);
      expect(state.hasOutdatedProfileCity, isFalse);
    });

    test('null profileCity field does not auto-migrate legacy city fields', () {
      final user = userFixture(
        data: {
          'uid': 'uid-null-profile-city',
          'Country_NS': {'code': ' RU '},
          'preferences': {
            'preferredLocation': {'code': 'US'},
          },
          'countryCode': 'IT',
          'cityKey': 'rome',
          'profileCity': null,
        },
      );

      final state = resolveEventSelectedCityState(
        user: user,
        catalog: catalog,
      );

      expect(user.hasProfileCity(), isFalse);
      expect(state.profileStatus, EventCityResolutionStatus.missingProfileCity);
      expect(state.countryCodeHint, 'RU');
      expect(state.selected, isNull);
      expect(state.canLoadEvents, isFalse);
      expect(state.needsCitySelection, isTrue);
      expect(state.selectedFromProfile, isFalse);
      expect(state.selectedTemporarily, isFalse);
      expect(state.hasOutdatedProfileCity, isFalse);
    });

    test('country without catalog city stays locked', () {
      final user = userFixture(
        data: {
          'uid': 'uid-country-without-event-city',
          'Country_NS': {'code': 'NL'},
        },
      );

      final state = resolveEventSelectedCityState(
        user: user,
        catalog: catalog,
      );

      expect(state.profileStatus, EventCityResolutionStatus.missingProfileCity);
      expect(state.countryCodeHint, 'NL');
      expect(state.selected, isNull);
      expect(state.canLoadEvents, isFalse);
      expect(state.needsCitySelection, isTrue);
      expect(state.selectedFromProfile, isFalse);
    });

    test('does not unlock stale invalid or unknown profile cities', () {
      for (final fixture in <({ProfileCityStruct profileCity, Object status})>[
        (
          profileCity: profileCityFixture(catalogVersion: 'old-version'),
          status: EventCityResolutionStatus.staleCatalogVersion,
        ),
        (
          profileCity: profileCityFixture(
            countryCode: 'Russia',
            catalogVersion: catalog.catalogVersion,
          ),
          status: EventCityResolutionStatus.invalidIdentity,
        ),
        (
          profileCity: profileCityFixture(
            cityKey: 'unknown_city',
            catalogVersion: catalog.catalogVersion,
          ),
          status: EventCityResolutionStatus.unknownCatalogCity,
        ),
      ]) {
        final state = resolveEventSelectedCityState(
          user: userFixture(
            data: {
              'uid': 'uid-${fixture.status}',
              'profileCity': fixture.profileCity.toMap(),
            },
          ),
          catalog: catalog,
        );

        expect(state.profileStatus, fixture.status);
        expect(state.selected, isNull);
        expect(state.canLoadEvents, isFalse);
        expect(state.hasOutdatedProfileCity, isTrue);
      }
    });

    test('temporary recent static and manual selections unlock the list', () {
      for (final input in <({EventSelectedCityInput input, String identity})>[
        (
          input: EventSelectedCityInput(
            countryCode: 'ID',
            cityKey: 'bali',
            source: EventCitySelectionSource.recent,
          ),
          identity: 'ID:bali',
        ),
        (
          input: EventSelectedCityInput(
            countryCode: 'AE',
            cityKey: 'dubai',
            source: EventCitySelectionSource.static,
          ),
          identity: 'AE:dubai',
        ),
        (
          input: EventSelectedCityInput(
            countryCode: 'US',
            cityKey: 'new_york',
            source: EventCitySelectionSource.manual,
          ),
          identity: 'US:new_york',
        ),
      ]) {
        final state = resolveEventSelectedCityState(
          user: null,
          catalog: catalog,
          temporarySelection: input.input,
        );

        expect(
            state.profileStatus, EventCityResolutionStatus.missingProfileCity);
        expect(state.selected?.city.identity, input.identity);
        expect(state.selected?.source, input.input.source);
        expect(state.canLoadEvents, isTrue);
        expect(state.selectedFromProfile, isFalse);
        expect(state.selectedTemporarily, isTrue);
        expect(state.selected?.analyticsPayload, <String, String>{
          'countryCode': input.identity.split(':').first,
          'cityKey': input.identity.split(':').last,
          'citySource': input.input.source.analyticsValue,
        });
      }
    });

    test('temporary selection preserves stale profile status and can override',
        () {
      final user = userFixture(
        data: {
          'uid': 'uid-stale-with-temporary',
          'Country_NS': {'code': 'RU'},
          'profileCity': profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: 'old-version',
          ).toMap(),
        },
      );

      final state = resolveEventSelectedCityState(
        user: user,
        catalog: catalog,
        temporarySelection: EventSelectedCityInput(
          countryCode: 'TH',
          cityKey: 'phuket',
          source: EventCitySelectionSource.manual,
        ),
      );

      expect(
          state.profileStatus, EventCityResolutionStatus.staleCatalogVersion);
      expect(state.countryCodeHint, 'RU');
      expect(state.selected?.city.identity, 'TH:phuket');
      expect(state.selected?.source, EventCitySelectionSource.manual);
      expect(state.canLoadEvents, isTrue);
    });

    test('temporary selection is not persisted as profile city', () {
      final user = userFixture(
        data: {
          'uid': 'uid-temporary-not-saved',
          'Country_NS': {'code': 'US'},
        },
      );

      final temporaryState = resolveEventSelectedCityState(
        user: user,
        catalog: catalog,
        temporarySelection: EventSelectedCityInput(
          countryCode: 'ID',
          cityKey: 'bali',
          source: EventCitySelectionSource.manual,
        ),
      );
      final nextState = resolveEventSelectedCityState(
        user: user,
        catalog: catalog,
      );

      expect(temporaryState.canLoadEvents, isTrue);
      expect(temporaryState.selected?.city.identity, 'ID:bali');
      expect(temporaryState.selectedTemporarily, isTrue);
      expect(user.hasProfileCity(), isFalse);
      expect(nextState.profileStatus,
          EventCityResolutionStatus.missingProfileCity);
      expect(nextState.countryCodeHint, 'US');
      expect(nextState.selected, isNull);
      expect(nextState.canLoadEvents, isFalse);
    });

    test('manual temporary selection overrides a valid profile city', () {
      final user = userFixture(
        data: {
          'uid': 'uid-profile-override',
          'profileCity': profileCityFixture(
            countryCode: 'US',
            cityKey: 'new_york',
            catalogVersion: catalog.catalogVersion,
          ).toMap(),
        },
      );

      final state = resolveEventSelectedCityState(
        user: user,
        catalog: catalog,
        temporarySelection: EventSelectedCityInput(
          countryCode: 'AE',
          cityKey: 'dubai',
          source: EventCitySelectionSource.manual,
        ),
      );

      expect(state.profileStatus, EventCityResolutionStatus.resolved);
      expect(state.selected?.city.identity, 'AE:dubai');
      expect(state.selected?.source, EventCitySelectionSource.manual);
      expect(state.selectedTemporarily, isTrue);
    });

    test('rejects profile-sourced temporary selection inputs', () {
      expect(
        () => EventSelectedCityInput(
          countryCode: 'US',
          cityKey: 'new_york',
          source: EventCitySelectionSource.profile,
        ),
        throwsArgumentError,
      );
    });

    test('ignores malformed and unknown temporary selections', () {
      for (final temporarySelection in <EventSelectedCityInput>[
        EventSelectedCityInput(
          countryCode: 'RUS',
          cityKey: 'moscow',
          source: EventCitySelectionSource.manual,
        ),
        EventSelectedCityInput(
          countryCode: 'RU',
          cityKey: 'unknown_city',
          source: EventCitySelectionSource.recent,
        ),
      ]) {
        final state = resolveEventSelectedCityState(
          user: null,
          catalog: catalog,
          temporarySelection: temporarySelection,
        );

        expect(state.selected, isNull);
        expect(state.canLoadEvents, isFalse);
        expect(state.needsCitySelection, isTrue);
      }
    });

    test('ignores invalid temporary selection while valid profile city remains',
        () {
      final user = userFixture(
        data: {
          'uid': 'uid-profile-with-invalid-temporary',
          'profileCity': profileCityFixture(
            countryCode: 'US',
            cityKey: 'new_york',
            catalogVersion: catalog.catalogVersion,
          ).toMap(),
        },
      );

      for (final temporarySelection in <EventSelectedCityInput>[
        EventSelectedCityInput(
          countryCode: 'RU',
          cityKey: 'unknown_city',
          source: EventCitySelectionSource.manual,
        ),
      ]) {
        final state = resolveEventSelectedCityState(
          user: user,
          catalog: catalog,
          temporarySelection: temporarySelection,
        );

        expect(state.profileStatus, EventCityResolutionStatus.resolved);
        expect(state.selected?.city.identity, 'US:new_york');
        expect(state.selected?.source, EventCitySelectionSource.profile);
        expect(state.selectedFromProfile, isTrue);
      }
    });
  });

  group('EventCitySelectionSource', () {
    test('uses stable analytics values', () {
      expect(EventCitySelectionSource.profile.analyticsValue, 'profile');
      expect(EventCitySelectionSource.recent.analyticsValue, 'recent');
      expect(EventCitySelectionSource.static.analyticsValue, 'static');
      expect(EventCitySelectionSource.manual.analyticsValue, 'manual');
    });
  });
}

ProfileCityStruct profileCityFixture({
  String? countryCode = 'US',
  String? cityKey = 'new_york',
  String? cityNameRu = 'New York',
  String? cityNameEn = 'New York',
  String? cityDisplayContext = 'US',
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

UsersRecord userFixture({required Map<String, dynamic> data}) {
  final normalizedData = Map<String, dynamic>.from(data);
  final profileCity = normalizedData['profileCity'];
  if (!normalizedData.containsKey('Country_NS') && profileCity is Map) {
    final countryCode = profileCity['countryCode'];
    final cityKey = profileCity['cityKey'];
    if (countryCode is String && cityKey is String) {
      normalizedData['Country_NS'] = {
        'code': countryCode,
        'cityKey': cityKey,
      };
    }
  }
  return UsersRecord.getDocumentFromData(
    normalizedData,
    UsersRecord.collection.doc(normalizedData['uid'] as String? ?? 'uid'),
  );
}
