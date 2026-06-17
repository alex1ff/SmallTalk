import 'dart:io';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/profile_city_save_service.dart';

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

  group('ProfileCitySaveService', () {
    test('writes canonical profile city data from the catalog', () async {
      final capture = await saveAndCaptureProfileCity(
        catalog: catalog,
        countryCode: ' us ',
        cityKey: ' new_york ',
      );
      final updateData = capture.updateData;
      final profileCity = updateData['profileCity'] as Map<String, dynamic>;

      expect(capture.calls, 1);
      expect(capture.userRef?.path, 'users/uid-save-city');
      expect(capture.result.city.countryCode, 'US');
      expect(capture.result.city.cityKey, 'new_york');
      expect(updateData.keys, orderedEquals(<String>['profileCity']));
      expect(
        profileCity.keys,
        unorderedEquals(<String>[
          'countryCode',
          'cityKey',
          'cityNameRu',
          'cityNameEn',
          'cityDisplayContext',
          'regionCode',
          'regionNameRu',
          'regionNameEn',
          'catalogVersion',
          'updatedAt',
        ]),
      );
      expect(updateData, isNot(contains('countryCode')));
      expect(updateData, isNot(contains('cityKey')));
      expect(updateData, isNot(contains('Country_NS')));
      expect(updateData, isNot(contains('preferences')));
      expect(profileCity, containsPair('countryCode', 'US'));
      expect(profileCity, containsPair('cityKey', 'new_york'));
      expect(profileCity, containsPair('cityNameRu', 'Нью-Йорк'));
      expect(profileCity, containsPair('cityNameEn', 'New York'));
      expect(profileCity, containsPair('cityDisplayContext', 'United States'));
      expect(profileCity, containsPair('regionCode', 'NY'));
      expect(profileCity, containsPair('regionNameRu', 'Нью-Йорк'));
      expect(profileCity, containsPair('regionNameEn', 'New York'));
      expect(
        profileCity,
        containsPair('catalogVersion', catalog.catalogVersion),
      );
      expect(profileCity['updatedAt'], isA<FieldValue>());
      expect(() => updateData['countryCode'] = 'RU', throwsUnsupportedError);
      expect(() => profileCity['cityNameRu'] = 'Fake', throwsUnsupportedError);
    });

    test('keeps null region fields when overwriting the nested profile city',
        () async {
      final capture = await saveAndCaptureProfileCity(
        catalog: catalog,
        countryCode: 'RU',
        cityKey: 'moscow',
      );
      final updateData = capture.updateData;
      final profileCity = updateData['profileCity'] as Map<String, dynamic>;

      expect(profileCity.containsKey('regionCode'), isTrue);
      expect(profileCity.containsKey('regionNameRu'), isTrue);
      expect(profileCity.containsKey('regionNameEn'), isTrue);
      expect(profileCity['regionCode'], isNull);
      expect(profileCity['regionNameRu'], isNull);
      expect(profileCity['regionNameEn'], isNull);
    });

    test('rejects malformed identities before writing', () async {
      var calls = 0;

      for (final input in const <({String countryCode, String cityKey})>[
        (countryCode: '', cityKey: 'moscow'),
        (countryCode: 'Russia', cityKey: 'moscow'),
        (countryCode: 'RU', cityKey: ''),
        (countryCode: 'RU', cityKey: 'Moscow'),
        (countryCode: 'RU', cityKey: 'new york'),
      ]) {
        await expectLater(
          ProfileCitySaveService.saveProfileCity(
            userRef: UsersRecord.collection.doc('uid-invalid-city'),
            catalog: catalog,
            countryCode: input.countryCode,
            cityKey: input.cityKey,
            writer: (_, __) async {
              calls += 1;
            },
          ),
          throwsA(
            isA<ProfileCitySaveException>().having(
              (error) => error.code,
              'code',
              ProfileCitySaveErrorCode.invalidIdentity,
            ),
          ),
          reason: 'Expected $input to be rejected.',
        );
      }

      expect(calls, 0);
    });

    test('rejects well-formed but unknown catalog cities before writing',
        () async {
      var calls = 0;

      await expectLater(
        ProfileCitySaveService.saveProfileCity(
          userRef: UsersRecord.collection.doc('uid-unknown-city'),
          catalog: catalog,
          countryCode: 'US',
          cityKey: 'unknown_city',
          writer: (_, __) async {
            calls += 1;
          },
        ),
        throwsA(
          isA<ProfileCitySaveException>().having(
            (error) => error.code,
            'code',
            ProfileCitySaveErrorCode.unknownCatalogCity,
          ),
        ),
      );

      expect(calls, 0);
    });

    test('passes writer errors through unchanged', () async {
      final error = StateError('profile city write failed');

      await expectLater(
        ProfileCitySaveService.saveProfileCity(
          userRef: UsersRecord.collection.doc('uid-write-error'),
          catalog: catalog,
          countryCode: 'RU',
          cityKey: 'moscow',
          writer: (_, __) => Future<void>.error(error),
        ),
        throwsA(same(error)),
      );
    });
  });
}

class _CapturedProfileCitySave {
  const _CapturedProfileCitySave({
    required this.result,
    required this.userRef,
    required this.updateData,
    required this.calls,
  });

  final ProfileCitySaveResult result;
  final DocumentReference? userRef;
  final Map<String, dynamic> updateData;
  final int calls;
}

Future<_CapturedProfileCitySave> saveAndCaptureProfileCity({
  required EventCityCatalog catalog,
  required String countryCode,
  required String cityKey,
}) async {
  final userRef = UsersRecord.collection.doc('uid-save-city');
  DocumentReference? capturedUserRef;
  Map<String, dynamic>? capturedData;
  var calls = 0;

  final result = await ProfileCitySaveService.saveProfileCity(
    userRef: userRef,
    catalog: catalog,
    countryCode: countryCode,
    cityKey: cityKey,
    writer: (calledUserRef, data) async {
      calls += 1;
      capturedUserRef = calledUserRef;
      capturedData = data;
    },
  );

  final updateData = capturedData;
  if (updateData == null) {
    throw StateError('Expected profile city writer to be called.');
  }

  return _CapturedProfileCitySave(
    result: result,
    userRef: capturedUserRef,
    updateData: updateData,
    calls: calls,
  );
}
