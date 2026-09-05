import '/backend/schema/structs/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const supportedLocationCatalogVersion = 'supported-locations-2026-09-04';

class SupportedLocation {
  const SupportedLocation({
    required this.countryCode,
    required this.cityKey,
    required this.label,
    required this.flag,
    required this.timeZoneId,
    required this.index,
  });

  final String countryCode;
  final String cityKey;
  final String label;
  final String flag;
  final String timeZoneId;
  final int index;

  String get identity => '$countryCode:$cityKey';

  CountryStruct toCountryStruct() => CountryStruct(
        code: countryCode,
        cityKey: cityKey,
        nameEn: label,
        nameRu: label,
        flag: flag,
        isPopular: true,
        index: index,
      );

  ProfileCityStruct toProfileCityStruct({bool serverTimestamp = false}) =>
      createProfileCityStruct(
        countryCode: countryCode,
        cityKey: cityKey,
        cityNameRu: label.split(',').first,
        cityNameEn: label.split(',').first,
        cityDisplayContext: label.split(',').last.trim(),
        catalogVersion: supportedLocationCatalogVersion,
        fieldValues: serverTimestamp
            ? <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()}
            : const <String, dynamic>{},
        clearUnsetFields: false,
      );
}

const supportedLocations = <SupportedLocation>[
  SupportedLocation(
    countryCode: 'US',
    cityKey: 'new_york',
    label: 'New York, US',
    flag: '🇺🇸',
    timeZoneId: 'America/New_York',
    index: 1,
  ),
  SupportedLocation(
    countryCode: 'ID',
    cityKey: 'bali',
    label: 'Bali, Indonesia',
    flag: '🇮🇩',
    timeZoneId: 'Asia/Makassar',
    index: 2,
  ),
  SupportedLocation(
    countryCode: 'AE',
    cityKey: 'dubai',
    label: 'Dubai, UAE',
    flag: '🇦🇪',
    timeZoneId: 'Asia/Dubai',
    index: 3,
  ),
  SupportedLocation(
    countryCode: 'TH',
    cityKey: 'phuket',
    label: 'Phuket, Thailand',
    flag: '🇹🇭',
    timeZoneId: 'Asia/Bangkok',
    index: 4,
  ),
];

SupportedLocation? resolveSupportedLocation(
  String? countryCode,
  String? cityKey,
) {
  final normalizedCountryCode = countryCode?.trim().toUpperCase();
  final normalizedCityKey = cityKey?.trim().toLowerCase();
  if (normalizedCountryCode == null ||
      normalizedCountryCode.isEmpty ||
      normalizedCityKey == null ||
      normalizedCityKey.isEmpty) {
    return null;
  }
  for (final location in supportedLocations) {
    if (location.countryCode == normalizedCountryCode &&
        location.cityKey == normalizedCityKey) {
      return location;
    }
  }
  return null;
}

SupportedLocation? resolveSupportedCountryStruct(CountryStruct? value) =>
    resolveSupportedLocation(value?.code, value?.cityKey);

SupportedLocation? resolveSupportedProfileCity(ProfileCityStruct? value) =>
    resolveSupportedLocation(value?.countryCode, value?.cityKey);

String? supportedLocationLabel(String? countryCode, String? cityKey) =>
    resolveSupportedLocation(countryCode, cityKey)?.label;

bool isSupportedCountryStruct(CountryStruct? value) =>
    resolveSupportedCountryStruct(value) != null;

bool hasConsistentSupportedUserLocation({
  required CountryStruct? country,
  required ProfileCityStruct? profileCity,
}) {
  final countryLocation = resolveSupportedCountryStruct(country);
  final profileLocation = resolveSupportedProfileCity(profileCity);
  return countryLocation != null &&
      profileLocation != null &&
      countryLocation.identity == profileLocation.identity;
}

CountryStruct? canonicalSupportedCountryStruct(CountryStruct? value) =>
    resolveSupportedCountryStruct(value)?.toCountryStruct();

List<CountryStruct> supportedLocationCountries() => supportedLocations
    .map((location) => location.toCountryStruct())
    .toList(growable: false);
