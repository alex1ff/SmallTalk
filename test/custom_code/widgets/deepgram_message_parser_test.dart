import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/deepgram_message_parser.dart';

void main() {
  group('invalid input and envelope', () {
    for (final raw in ['{', '', 'not json']) {
      test('malformed JSON throws: "$raw"', () {
        expect(() => parseDeepgramMessage(raw), throwsA(anything));
      });
    }

    test('non-string input preserves jsonDecode type failure', () {
      expect(
          () => parseDeepgramMessage(<String, dynamic>{}), throwsA(anything));
    });

    for (final raw in ['null', '[]', '42', '"text"', 'true']) {
      test('decoded non-object is invalid envelope: $raw', () {
        final parsed = parseDeepgramMessage(raw);
        expect(parsed.kind, DeepgramMessageKind.invalidEnvelope);
        expect(parsed.transcript, isNull);
      });
    }
  });

  group('control frame precedence', () {
    for (final type in ['error', ' ERROR ', 'ErRoR']) {
      test('normalized error type is service error: "$type"', () {
        expect(parseDeepgramMessage('{"type":"$type"}').kind,
            DeepgramMessageKind.serviceError);
      });
    }

    for (final errorJson in ['null', 'false', '0', '""', '{}']) {
      test('presence of error key wins for value $errorJson', () {
        final parsed = parseDeepgramMessage(
          '{"type":"UtteranceEnd","error":$errorJson,'
          '"channel":{"alternatives":[{"transcript":"ignored"}]}}',
        );
        expect(parsed.kind, DeepgramMessageKind.serviceError);
      });
    }

    test('UtteranceEnd remains exact and case-sensitive', () {
      expect(parseDeepgramMessage('{"type":"UtteranceEnd"}').kind,
          DeepgramMessageKind.utteranceEnd);
      for (final value in ['utteranceend', 'UTTERANCEEND', ' UtteranceEnd ']) {
        expect(parseDeepgramMessage('{"type":"$value"}').kind,
            DeepgramMessageKind.ignored,
            reason: value);
      }
    });
  });

  group('alternatives compatibility', () {
    final ignoredFrames = <String>[
      '{}',
      '{"channel":null}',
      '{"channel":[]}',
      '{"channel":{"alternatives":null}}',
      '{"channel":{"alternatives":{}}}',
      '{"channel":{"alternatives":[]}}',
      '{"channel":{"alternatives":[null]}}',
      '{"channel":{"alternatives":[42]}}',
      '{"channel":{"alternatives":["text"]}}',
    ];
    for (var index = 0; index < ignoredFrames.length; index++) {
      test('malformed alternatives shape is ignored [$index]', () {
        expect(parseDeepgramMessage(ignoredFrames[index]).kind,
            DeepgramMessageKind.ignored);
      });
    }

    test('only the first alternative is considered', () {
      final emptyFirst = parseDeepgramMessage(
        '{"channel":{"alternatives":['
        '{"transcript":""},{"transcript":"second"}]}}',
      );
      expect(emptyFirst.kind, DeepgramMessageKind.ignored);

      final firstWins = parseDeepgramMessage(
        '{"channel":{"alternatives":['
        '{"transcript":"first"},{"transcript":"second"}]}}',
      );
      expect(firstWins.kind, DeepgramMessageKind.transcript);
      expect(firstWins.transcript, 'first');
    });
  });

  group('transcript and flags', () {
    test('text uses toString then shared whitespace normalization', () {
      final parsed = parseDeepgramMessage(
        '{"channel":{"alternatives":[{"transcript":"  Hello\\n  мир  "}]}}',
      );
      expect(parsed.kind, DeepgramMessageKind.transcript);
      expect(parsed.transcript, 'Hello мир');

      final number = parseDeepgramMessage(
        '{"channel":{"alternatives":[{"transcript":42}]}}',
      );
      expect(number.transcript, '42');

      final boolean = parseDeepgramMessage(
        '{"channel":{"alternatives":[{"transcript":true}]}}',
      );
      expect(boolean.transcript, 'true');
    });

    for (final isFinal in [false, true]) {
      for (final speechFinal in [false, true]) {
        test('literal flags: isFinal=$isFinal speechFinal=$speechFinal', () {
          final parsed = parseDeepgramMessage(
            '{"is_final":$isFinal,"speech_final":$speechFinal,'
            '"channel":{"alternatives":[{"transcript":"text"}]}}',
          );
          expect(parsed.kind, DeepgramMessageKind.transcript);
          expect(parsed.isFinalSegment, isFinal);
          expect(parsed.speechFinal, speechFinal);
        });
      }
    }

    test('speech_finalized true is an accepted final signal', () {
      final parsed = parseDeepgramMessage(
        '{"speech_finalized":true,'
        '"channel":{"alternatives":[{"transcript":"text"}]}}',
      );
      expect(parsed.speechFinal, isTrue);
    });

    for (final flagJson in ['"true"', '1', '"1"', '{}', '[]', 'null']) {
      test('non-boolean truthy-looking flag is false: $flagJson', () {
        final parsed = parseDeepgramMessage(
          '{"is_final":$flagJson,"speech_final":$flagJson,'
          '"speech_finalized":$flagJson,'
          '"channel":{"alternatives":[{"transcript":"text"}]}}',
        );
        expect(parsed.isFinalSegment, isFalse);
        expect(parsed.speechFinal, isFalse);
      });
    }

    test('empty transcript with speech final requests current finalization',
        () {
      for (final signal in [
        '"speech_final":true',
        '"speech_finalized":true',
      ]) {
        final parsed = parseDeepgramMessage(
          '{$signal,"channel":{"alternatives":[{"transcript":"  "}]}}',
        );
        expect(parsed.kind, DeepgramMessageKind.finalizeCurrent);
        expect(parsed.transcript, '');
        expect(parsed.speechFinal, isTrue);
      }
    });

    test('empty transcript without speech final is ignored', () {
      final parsed = parseDeepgramMessage(
        '{"is_final":true,'
        '"channel":{"alternatives":[{"transcript":null}]}}',
      );
      expect(parsed.kind, DeepgramMessageKind.ignored);
      expect(parsed.isFinalSegment, isTrue);
      expect(parsed.speechFinal, isFalse);
    });
  });

  group('confidence compatibility', () {
    final cases = <({String json, double? expected})>[
      (json: '0', expected: 0),
      (json: '1', expected: 1),
      (json: '0.75', expected: 0.75),
      (json: '" 0.25 "', expected: 0.25),
      (json: 'null', expected: null),
      (json: 'true', expected: null),
      (json: '"bad"', expected: null),
      (json: '{}', expected: null),
    ];
    for (var index = 0; index < cases.length; index++) {
      test('confidence conversion [$index]', () {
        final value = cases[index];
        final parsed = parseDeepgramMessage(
          '{"channel":{"alternatives":['
          '{"transcript":"text","confidence":${value.json}}]}}',
        );
        expect(parsed.confidence, value.expected);
      });
    }

    test('unvalidated special doubles remain compatible', () {
      final nan = parseDeepgramMessage(
        '{"channel":{"alternatives":['
        '{"transcript":"text","confidence":"NaN"}]}}',
      ).confidence;
      expect(nan, isNotNull);
      expect(nan!.isNaN, isTrue);

      final infinity = parseDeepgramMessage(
        '{"channel":{"alternatives":['
        '{"transcript":"text","confidence":"Infinity"}]}}',
      ).confidence;
      expect(infinity, double.infinity);
    });
  });
}
