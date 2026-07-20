import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/services/nearby_partner_preview_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('cache key is stable for equivalent filters', () {
    expect(
      nearbyPartnerPreviewCacheKey(
        languageCode: ' EN ',
        countryCode: ' DE ',
        partnerLevel: ' Beginner ',
      ),
      nearbyPartnerPreviewCacheKey(
        languageCode: 'en',
        countryCode: 'de',
        partnerLevel: 'beginner',
      ),
    );
  });

  test('cached partner previews are available synchronously after write',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final cache = NearbyPartnerPreviewCache(preferences);
    const key = 'preview-key';

    await cache.write(key, const <NearbyPartnerPreviewEntry>[
      NearbyPartnerPreviewEntry(
        displayName: ' Alice Example ',
        photoUrl: ' https://cdn.example/alice.jpg ',
      ),
      NearbyPartnerPreviewEntry(
        displayName: 'Bob Example',
        photoUrl: 'https://cdn.example/bob.jpg',
      ),
    ]);

    final entries = cache.read(key);
    expect(entries, hasLength(2));
    expect(entries!.first.displayName, 'Alice Example');
    expect(entries.first.photoUrl, 'https://cdn.example/alice.jpg');
  });

  test('malformed cached data is ignored', () async {
    final preferences = await SharedPreferences.getInstance();
    const key = 'malformed-preview-key';
    await preferences.setString(key, '{not-json');

    expect(NearbyPartnerPreviewCache(preferences).read(key), isNull);
  });

  test('cache limits the number of stored previews', () async {
    final preferences = await SharedPreferences.getInstance();
    final cache = NearbyPartnerPreviewCache(preferences, maxEntries: 2);
    const key = 'limited-preview-key';

    await cache.write(
      key,
      List<NearbyPartnerPreviewEntry>.generate(
        3,
        (index) => NearbyPartnerPreviewEntry(
          displayName: 'User $index',
          photoUrl: 'https://cdn.example/$index.jpg',
        ),
      ),
    );

    expect(cache.read(key), hasLength(2));
  });
}
