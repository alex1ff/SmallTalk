import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event list query indexes are present for private and public sources',
      () {
    final config = jsonDecode(
      File('firebase/firestore.indexes.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final indexes = config['indexes'] as List<dynamic>;
    final expectedFields = <Map<String, String>>[
      {'fieldPath': 'status', 'order': 'ASCENDING'},
      {'fieldPath': 'countryCode', 'order': 'ASCENDING'},
      {'fieldPath': 'cityKey', 'order': 'ASCENDING'},
      {'fieldPath': 'startsAt', 'order': 'ASCENDING'},
    ];

    for (final collection in ['events', 'events_public']) {
      final matchingIndexes = indexes.where((index) {
        final data = index as Map<String, dynamic>;
        return data['collectionGroup'] == collection &&
            data['queryScope'] == 'COLLECTION' &&
            _fieldsEqual(data['fields'] as List<dynamic>, expectedFields);
      }).toList(growable: false);

      expect(
        matchingIndexes,
        hasLength(1),
        reason: '$collection list queries require '
            'status/country/city/startsAt ASC in this exact order.',
      );
    }
  });
}

bool _fieldsEqual(
  List<dynamic> actual,
  List<Map<String, String>> expected,
) {
  if (actual.length != expected.length) {
    return false;
  }
  for (var index = 0; index < expected.length; index += 1) {
    final actualField = actual[index] as Map<String, dynamic>;
    if (actualField.length != expected[index].length ||
        actualField['fieldPath'] != expected[index]['fieldPath'] ||
        actualField['order'] != expected[index]['order']) {
      return false;
    }
  }
  return true;
}
