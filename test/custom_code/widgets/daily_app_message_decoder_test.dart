import 'dart:convert' as dart_convert;

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/daily_app_message_decoder.dart';

void main() {
  group('decodeDailyAppMessagePayload', () {
    const payload = <String, dynamic>{
      'type': 'chat',
      'text': 'hello',
      'revision': 2,
    };

    test('decodes single-encoded object with outer whitespace', () {
      final encoded = '  ${dart_convert.jsonEncode(payload)}\n';

      final result = decodeDailyAppMessagePayload(encoded);

      expect(result, payload);
      expect(result, isA<Map<String, dynamic>>());
    });

    test('decodes double-encoded object with outer whitespace', () {
      final encoded = ' \t${dart_convert.jsonEncode(
        dart_convert.jsonEncode(payload),
      )} ';

      expect(decodeDailyAppMessagePayload(encoded), payload);
    });

    test('returns null for raw and encoded empty strings', () {
      expect(decodeDailyAppMessagePayload(''), isNull);
      expect(decodeDailyAppMessagePayload('  \n\t '), isNull);
      expect(
        decodeDailyAppMessagePayload(dart_convert.jsonEncode('  \n ')),
        isNull,
      );
    });

    test('propagates malformed first and second layers', () {
      expect(
        () => decodeDailyAppMessagePayload('{'),
        throwsFormatException,
      );
      expect(
        () => decodeDailyAppMessagePayload(
          dart_convert.jsonEncode('plain'),
        ),
        throwsFormatException,
      );
      expect(
        () => decodeDailyAppMessagePayload(
          dart_convert.jsonEncode('{invalid'),
        ),
        throwsFormatException,
      );
    });

    test('returns null for non-object JSON after one or two decodes', () {
      final values = <dynamic>[
        null,
        <dynamic>['item'],
        true,
        42,
      ];

      for (final value in values) {
        final encodedOnce = dart_convert.jsonEncode(value);
        final encodedTwice = dart_convert.jsonEncode(encodedOnce);

        expect(
          decodeDailyAppMessagePayload(encodedOnce),
          isNull,
          reason: 'single-encoded $value',
        );
        expect(
          decodeDailyAppMessagePayload(encodedTwice),
          isNull,
          reason: 'double-encoded $value',
        );
      }
    });

    test('stops after two string decode passes', () {
      final tripleEncoded = dart_convert.jsonEncode(
        dart_convert.jsonEncode(
          dart_convert.jsonEncode(payload),
        ),
      );

      expect(decodeDailyAppMessagePayload(tripleEncoded), isNull);
    });

    test('returns a new mutable map with nested values preserved', () {
      final nestedPayload = <String, dynamic>{
        'type': 'caption',
        'nested': <String, dynamic>{'enabled': true},
        'items': <int>[1, 2],
      };

      final result = decodeDailyAppMessagePayload(
        dart_convert.jsonEncode(nestedPayload),
      )!;
      result['extra'] = 'value';

      expect(result['type'], 'caption');
      expect(result['nested'], <String, dynamic>{'enabled': true});
      expect(result['items'], <dynamic>[1, 2]);
      expect(result['extra'], 'value');
    });
  });
}
