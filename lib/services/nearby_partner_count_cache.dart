import 'package:shared_preferences/shared_preferences.dart';

const nearbyPartnerCountPrefsPrefix = 'ff_student_nearby_partner_count_v1';

String nearbyPartnerCountCacheKey({
  required String languageCode,
  required String countryCode,
  String cityKey = '',
  required String partnerLevel,
}) {
  String normalize(String value) => value.trim().toLowerCase();

  return <String>[
    nearbyPartnerCountPrefsPrefix,
    Uri.encodeComponent(normalize(languageCode)),
    Uri.encodeComponent(normalize(countryCode)),
    Uri.encodeComponent(normalize(cityKey)),
    Uri.encodeComponent(normalize(partnerLevel)),
  ].join('|');
}

class NearbyPartnerCountCache {
  const NearbyPartnerCountCache(this._preferences);

  final SharedPreferences _preferences;

  int? read(String key) {
    try {
      final count = _preferences.getInt(key);
      return count != null && count >= 0 ? count : null;
    } on TypeError {
      return null;
    }
  }

  Future<void> write(String key, int count) async {
    if (count < 0) {
      return;
    }
    await _preferences.setInt(key, count);
  }
}
