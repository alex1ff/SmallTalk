import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/services/nearby_partner_count_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('builds a normalized cache key for the active filters', () {
    expect(
      nearbyPartnerCountCacheKey(
        languageCode: ' EN ',
        countryCode: ' US ',
        cityKey: ' NEW_YORK ',
        partnerLevel: ' Basic ',
        userScope: ' Student-A ',
      ),
      '$nearbyPartnerCountPrefsPrefix|student-a|en|us|new_york|basic',
    );
  });

  test('persists zero and positive partner counts', () async {
    final preferences = await SharedPreferences.getInstance();
    final cache = NearbyPartnerCountCache(preferences);
    const key = 'partner-count-test';

    expect(cache.read(key), isNull);

    await cache.write(key, 0);
    expect(cache.read(key), 0);

    await cache.write(key, 7);
    expect(cache.read(key), 7);
  });

  test('ignores negative partner counts', () async {
    final preferences = await SharedPreferences.getInstance();
    final cache = NearbyPartnerCountCache(preferences);
    const key = 'negative-partner-count-test';

    await cache.write(key, -1);

    expect(cache.read(key), isNull);
  });
}
