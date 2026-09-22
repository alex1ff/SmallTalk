import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';

void main() {
  group('ProfileCityStruct', () {
    test('serializes and deserializes profile city fields', () {
      final updatedAt = DateTime.parse('2026-06-16T12:00:00Z');
      final profileCity = ProfileCityStruct.fromMap({
        'countryCode': 'US',
        'cityKey': 'new_york',
        'cityNameRu': 'Нью-Йорк',
        'cityNameEn': 'New York',
        'cityDisplayContext': 'United States',
        'regionCode': 'NY',
        'regionNameRu': 'Нью-Йорк',
        'regionNameEn': 'New York',
        'catalogVersion': 'events-city-catalog-mvp-2026-06-16',
        'updatedAt': updatedAt,
      });

      expect(profileCity.countryCode, 'US');
      expect(profileCity.cityKey, 'new_york');
      expect(profileCity.cityNameRu, 'Нью-Йорк');
      expect(profileCity.cityNameEn, 'New York');
      expect(profileCity.cityDisplayContext, 'United States');
      expect(profileCity.regionCode, 'NY');
      expect(profileCity.regionNameRu, 'Нью-Йорк');
      expect(profileCity.regionNameEn, 'New York');
      expect(
        profileCity.catalogVersion,
        'events-city-catalog-mvp-2026-06-16',
      );
      expect(profileCity.updatedAt, updatedAt);
      expect(profileCity.toMap(), {
        'countryCode': 'US',
        'cityKey': 'new_york',
        'cityNameRu': 'Нью-Йорк',
        'cityNameEn': 'New York',
        'cityDisplayContext': 'United States',
        'regionCode': 'NY',
        'regionNameRu': 'Нью-Йорк',
        'regionNameEn': 'New York',
        'catalogVersion': 'events-city-catalog-mvp-2026-06-16',
        'updatedAt': updatedAt,
      });
    });

    test('round-trips through serializable map', () {
      final updatedAt = DateTime.parse('2026-06-16T12:00:00Z');
      final profileCity = createProfileCityStruct(
        countryCode: 'RU',
        cityKey: 'moscow',
        cityNameRu: 'Москва',
        cityNameEn: 'Moscow',
        cityDisplayContext: 'Россия',
        catalogVersion: 'events-city-catalog-mvp-2026-06-16',
        updatedAt: updatedAt,
      );

      final restored = ProfileCityStruct.fromSerializableMap(
          profileCity.toSerializableMap());

      expect(restored.countryCode, profileCity.countryCode);
      expect(restored.cityKey, profileCity.cityKey);
      expect(restored.cityNameRu, profileCity.cityNameRu);
      expect(restored.cityNameEn, profileCity.cityNameEn);
      expect(restored.cityDisplayContext, profileCity.cityDisplayContext);
      expect(restored.catalogVersion, profileCity.catalogVersion);
      expect(restored.updatedAt?.isAtSameMomentAs(updatedAt), isTrue);
      expect(restored.catalogVersion, isA<String>());
      expect(restored.regionCode, '');
      expect(restored.hasRegionCode(), isFalse);
    });

    test('supports server timestamp field value for updatedAt', () {
      final serverTimestamp = FieldValue.serverTimestamp();
      final data = getProfileCityFirestoreData(
        createProfileCityStruct(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: 'events-city-catalog-mvp-2026-06-16',
          fieldValues: {'updatedAt': serverTimestamp},
          clearUnsetFields: false,
        ),
      );

      expect(data['countryCode'], 'RU');
      expect(data['cityKey'], 'moscow');
      expect(data['updatedAt'], same(serverTimestamp));
    });
  });
}
