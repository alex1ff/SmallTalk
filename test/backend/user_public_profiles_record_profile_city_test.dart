import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('UserPublicProfilesRecord Events city separation', () {
    test('keeps Country_NS separate from Events profile city identity', () {
      final profile = UserPublicProfilesRecord.getDocumentFromData(
        {
          'userId': 'uid-public-country',
          'Country_NS': {'code': 'RU'},
          'countryCode': 'IT',
          'cityKey': 'rome',
          'profileCity': {
            'countryCode': 'US',
            'cityKey': 'new_york',
          },
        },
        UserPublicProfilesRecord.collection.doc('uid-public-country'),
      );

      expect(profile.hasCountryNS(), isTrue);
      expect(profile.countryNS.code, 'RU');
      expect(profile.countryCode, 'RU');
      expect(profile.countryCode, isNot('IT'));
      expect(profile.countryNS.code, isNot('US'));
    });

    test('does not derive country from top-level city identity fields', () {
      final profile = UserPublicProfilesRecord.getDocumentFromData(
        {
          'userId': 'uid-public-top-level-only',
          'countryCode': 'IT',
          'cityKey': 'rome',
          'profileCity': {
            'countryCode': 'US',
            'cityKey': 'new_york',
          },
        },
        UserPublicProfilesRecord.collection.doc('uid-public-top-level-only'),
      );

      expect(profile.hasCountryNS(), isFalse);
      expect(profile.countryNS.code, '');
      expect(profile.hasCountryCode(), isFalse);
      expect(profile.countryCode, '');
    });
  });
}
