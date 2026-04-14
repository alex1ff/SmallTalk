import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/backend/schema/structs/preferences_struct.dart';
import 'package:small_talk/backend/schema/users_record.dart';

void main() {
  group('PreferencesStruct preferredPartnerLevel', () {
    test('serializes and deserializes level values', () {
      final preferences = createPreferencesStruct(
        preferredPartnerLevel: Level.Fluent,
        clearUnsetFields: false,
      );

      expect(preferences.toMap()['preferredPartnerLevel'], 'Fluent');
      expect(
        PreferencesStruct.fromMap({'preferredPartnerLevel': 'Basic'})
            .preferredPartnerLevel,
        Level.Basic,
      );
      expect(
        PreferencesStruct.fromSerializableMap({
          'preferredPartnerLevel': 'Intermediate',
        }).preferredPartnerLevel,
        Level.Intermediate,
      );
    });

    test('does not default to a level when unset', () {
      final preferences = createPreferencesStruct();

      expect(preferences.preferredPartnerLevel, isNull);
      expect(preferences.toMap().containsKey('preferredPartnerLevel'), isFalse);
    });

    test('builds a nested delete payload when clearing the level filter', () {
      final deleteValue = FieldValue.delete();
      final data = createUsersRecordData(
        preferences: createPreferencesStruct(
          fieldValues: {
            'preferredPartnerLevel': deleteValue,
          },
          clearUnsetFields: false,
        ),
      );

      expect(data, isNot(contains('preferences')));
      expect(data['preferences.preferredPartnerLevel'], same(deleteValue));
    });
  });
}
