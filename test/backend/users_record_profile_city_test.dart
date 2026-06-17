import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('UsersRecord profileCity', () {
    test('treats missing profileCity as unset', () {
      final user = UsersRecord.getDocumentFromData(
        {
          'uid': 'uid-1',
          'display_name': 'User',
          'Country_NS': {'code': 'RU'},
          'preferences': {
            'preferredLocation': {'code': 'US'},
          },
          'countryCode': 'IT',
          'cityKey': 'rome',
        },
        UsersRecord.collection.doc('uid-1'),
      );

      expect(user.hasProfileCity(), isFalse);
      expect(user.profileCity.countryCode, '');
      expect(user.profileCity.cityKey, '');
      expect(user.countryNS.code, 'RU');
      expect(user.preferences.preferredLocation.code, 'US');
    });

    test('parses profileCity independently from legacy country fields', () {
      final updatedAt = DateTime.parse('2026-06-16T12:00:00Z');
      final user = UsersRecord.getDocumentFromData(
        {
          'uid': 'uid-2',
          'Country_NS': {'code': 'RU'},
          'preferences': {
            'preferredLocation': {'code': 'US'},
          },
          'profileCity': {
            'countryCode': 'IT',
            'cityKey': 'rome',
            'cityNameRu': 'Рим',
            'cityNameEn': 'Rome',
            'cityDisplayContext': 'Italia',
            'regionCode': 'LAZ',
            'regionNameRu': 'Лацио',
            'regionNameEn': 'Lazio',
            'catalogVersion': 'events-city-catalog-mvp-2026-06-16',
            'updatedAt': updatedAt,
          },
        },
        UsersRecord.collection.doc('uid-2'),
      );

      expect(user.hasProfileCity(), isTrue);
      expect(user.profileCity.countryCode, 'IT');
      expect(user.profileCity.cityKey, 'rome');
      expect(user.profileCity.cityNameRu, 'Рим');
      expect(user.profileCity.cityNameEn, 'Rome');
      expect(user.profileCity.cityDisplayContext, 'Italia');
      expect(user.profileCity.regionCode, 'LAZ');
      expect(user.profileCity.regionNameRu, 'Лацио');
      expect(user.profileCity.regionNameEn, 'Lazio');
      expect(user.profileCity.catalogVersion,
          'events-city-catalog-mvp-2026-06-16');
      expect(user.profileCity.updatedAt, updatedAt);
      expect(user.countryNS.code, 'RU');
      expect(user.preferences.preferredLocation.code, 'US');
    });

    test('writes profileCity as nested map without top-level city identity',
        () {
      final serverTimestamp = FieldValue.serverTimestamp();
      final data = createUsersRecordData(
        profileCity: createProfileCityStruct(
          countryCode: 'RU',
          cityKey: 'moscow',
          cityNameRu: 'Москва',
          cityNameEn: 'Moscow',
          cityDisplayContext: 'Россия',
          catalogVersion: 'events-city-catalog-mvp-2026-06-16',
          fieldValues: {'updatedAt': serverTimestamp},
          clearUnsetFields: false,
        ),
      );

      expect(data, isNot(contains('countryCode')));
      expect(data, isNot(contains('cityKey')));
      expect(data['profileCity.countryCode'], 'RU');
      expect(data['profileCity.cityKey'], 'moscow');
      expect(data['profileCity.cityNameRu'], 'Москва');
      expect(data['profileCity.cityNameEn'], 'Moscow');
      expect(data['profileCity.cityDisplayContext'], 'Россия');
      expect(
        data['profileCity.catalogVersion'],
        'events-city-catalog-mvp-2026-06-16',
      );
      expect(data['profileCity.updatedAt'], same(serverTimestamp));
    });

    test('does not write profileCity from country or preference updates', () {
      final countryData = createUsersRecordData(
        countryNS: createCountryStruct(
          code: 'US',
          clearUnsetFields: false,
        ),
      );
      final preferenceData = createUsersRecordData(
        preferences: createPreferencesStruct(
          preferredLocation: createCountryStruct(
            code: 'IT',
            clearUnsetFields: false,
          ),
          clearUnsetFields: false,
        ),
      );

      expect(countryData['Country_NS.code'], 'US');
      expect(preferenceData['preferences.preferredLocation.code'], 'IT');
      expectNoTopLevelEventCityIdentityWrite(countryData);
      expectNoTopLevelEventCityIdentityWrite(preferenceData);
      expectNoProfileCityWrite(countryData);
      expectNoProfileCityWrite(preferenceData);
    });
  });
}

void expectNoProfileCityWrite(Map<String, dynamic> data) {
  expect(
    data.keys
        .where((key) => key == 'profileCity' || key.startsWith('profileCity.')),
    isEmpty,
  );
}

void expectNoTopLevelEventCityIdentityWrite(Map<String, dynamic> data) {
  expect(data, isNot(contains('countryCode')));
  expect(data, isNot(contains('cityKey')));
}
