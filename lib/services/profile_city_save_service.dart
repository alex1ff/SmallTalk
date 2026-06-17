import 'dart:collection';

import '/backend/backend.dart';
import 'event_city_catalog.dart';

typedef ProfileCitySaveWriter = Future<void> Function(
  DocumentReference userRef,
  Map<String, dynamic> data,
);

enum ProfileCitySaveErrorCode {
  invalidIdentity,
  unknownCatalogCity,
}

class ProfileCitySaveException implements Exception {
  const ProfileCitySaveException({
    required this.code,
    required this.countryCode,
    required this.cityKey,
  });

  final ProfileCitySaveErrorCode code;
  final String countryCode;
  final String cityKey;

  @override
  String toString() =>
      'ProfileCitySaveException($code, countryCode: $countryCode, '
      'cityKey: $cityKey)';
}

class _ProfileCitySavePayload {
  const _ProfileCitySavePayload({
    required this.city,
    required this.updateData,
  });

  final EventCity city;
  final Map<String, dynamic> updateData;
}

class ProfileCitySaveResult {
  const ProfileCitySaveResult({
    required this.city,
  });

  final EventCity city;
}

class ProfileCitySaveService {
  const ProfileCitySaveService._();

  static Future<ProfileCitySaveResult> saveProfileCity({
    required DocumentReference userRef,
    required EventCityCatalog catalog,
    required String countryCode,
    required String cityKey,
    // Injectable for unit tests; production callers should use the default.
    ProfileCitySaveWriter writer = _defaultProfileCitySaveWriter,
  }) async {
    final payload = _buildProfileCitySavePayload(
      catalog: catalog,
      countryCode: countryCode,
      cityKey: cityKey,
    );
    await writer(userRef, payload.updateData);
    return ProfileCitySaveResult(city: payload.city);
  }
}

_ProfileCitySavePayload _buildProfileCitySavePayload({
  required EventCityCatalog catalog,
  required String countryCode,
  required String cityKey,
}) {
  final identity = normalizeEventCityIdentity(countryCode, cityKey);
  if (identity == null) {
    throw ProfileCitySaveException(
      code: ProfileCitySaveErrorCode.invalidIdentity,
      countryCode: countryCode,
      cityKey: cityKey,
    );
  }

  final city = catalog.resolve(identity.countryCode, identity.cityKey);
  if (city == null) {
    throw ProfileCitySaveException(
      code: ProfileCitySaveErrorCode.unknownCatalogCity,
      countryCode: identity.countryCode,
      cityKey: identity.cityKey,
    );
  }

  return _ProfileCitySavePayload(
    city: city,
    updateData: _profileCityUpdateData(city, catalog),
  );
}

Map<String, dynamic> _profileCityUpdateData(
  EventCity city,
  EventCityCatalog catalog,
) {
  final profileCityData = mapToFirestore(
    <String, dynamic>{
      'countryCode': city.countryCode,
      'cityKey': city.cityKey,
      'cityNameRu': city.cityNameRu,
      'cityNameEn': city.cityNameEn,
      'cityDisplayContext': city.cityDisplayContext,
      'regionCode': city.regionCode,
      'regionNameRu': city.regionNameRu,
      'regionNameEn': city.regionNameEn,
      'catalogVersion': catalog.catalogVersion,
      'updatedAt': FieldValue.serverTimestamp(),
    },
  );

  return UnmodifiableMapView<String, dynamic>(
    <String, dynamic>{
      'profileCity': UnmodifiableMapView<String, dynamic>(profileCityData),
    },
  );
}

Future<void> _defaultProfileCitySaveWriter(
  DocumentReference userRef,
  Map<String, dynamic> data,
) =>
    userRef.update(data);
