import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/daily_join_credentials.dart'
    as credentials;

void main() {
  const invalidCredentials = <String?>[
    null,
    '',
    '  \t\n',
    'null',
    ' NULL ',
    'undefined',
    ' UnDeFiNeD ',
    'false',
    ' FaLsE ',
    '0',
    ' 0 ',
    'none',
    ' NoNe ',
  ];

  group('credential normalization', () {
    for (var index = 0; index < invalidCredentials.length; index++) {
      final value = invalidCredentials[index];
      test('rejects absent/sentinel credential [$index]', () {
        expect(credentials.sanitizeMeetingToken(value), isNull);
        expect(credentials.sanitizeDeepgramCredential(value), isNull);
      });
    }

    test('trims credentials without changing case or contents', () {
      for (final value in [
        ' Secret-A ',
        ' Bearer AbC.XyZ.sig ',
        ' a b ',
        ' nullify '
      ]) {
        expect(credentials.sanitizeMeetingToken(value), value.trim());
        expect(credentials.sanitizeDeepgramCredential(value), value.trim());
      }
    });
  });

  group('meeting token selection', () {
    test('uses configured token only when dynamic token is absent', () {
      expect(credentials.effectiveMeetingToken(configuredToken: ' configured '),
          'configured');
      expect(credentials.effectiveMeetingToken(), isNull);
    });

    test('dynamic token takes precedence', () {
      expect(
          credentials.effectiveMeetingToken(
            dynamicToken: ' fresh ',
            configuredToken: 'old',
          ),
          'fresh');
    });

    test('present but invalid dynamic token does not revive old token', () {
      for (final value in invalidCredentials.whereType<String>()) {
        expect(
            credentials.effectiveMeetingToken(
              dynamicToken: value,
              configuredToken: 'old',
            ),
            isNull,
            reason: 'Invalid override: "$value"');
      }
    });
  });

  group('room URL normalization and selection', () {
    test('requires both a scheme and an authority', () {
      for (final url in [
        '',
        '0',
        'null',
        ' NULL ',
        'room',
        '/room',
        '//call.daily.co/room',
        'https:room',
        'https://[broken'
      ]) {
        expect(credentials.isValidRoomUrl(url), isFalse, reason: url);
        expect(credentials.sanitizeRoomUrl(url), isNull, reason: url);
      }
      expect(credentials.sanitizeRoomUrl(null), isNull);
    });

    test('preserves existing scheme policy and URL contents', () {
      for (final url in [
        'https://call.daily.co/Room?x=Y#z',
        'http://localhost/room',
        'custom://example.test/room'
      ]) {
        expect(credentials.isValidRoomUrl(url), isTrue, reason: url);
        expect(credentials.sanitizeRoomUrl(url), url);
      }
    });

    test('sanitizer trims before validation; raw validation does not', () {
      const padded = '  https://call.daily.co/room  ';
      expect(credentials.isValidRoomUrl(padded), isFalse);
      expect(credentials.sanitizeRoomUrl(padded), 'https://call.daily.co/room');
    });

    test('valid dynamic URL takes precedence', () {
      expect(
          credentials.effectiveRoomUrl(
            dynamicRoomUrl: ' https://call.daily.co/new ',
            configuredRoomUrl: 'https://call.daily.co/old',
          ),
          'https://call.daily.co/new');
    });

    test('invalid or absent dynamic URL falls back to configured URL', () {
      for (final url in <String?>[
        null,
        '',
        'null',
        'relative',
        'https://[bad'
      ]) {
        expect(
            credentials.effectiveRoomUrl(
              dynamicRoomUrl: url,
              configuredRoomUrl: ' https://call.daily.co/configured ',
            ),
            'https://call.daily.co/configured',
            reason: 'Override: "$url"');
      }
    });

    test('invalid configured URL cannot be used as fallback', () {
      expect(
          credentials.effectiveRoomUrl(
            dynamicRoomUrl: 'invalid',
            configuredRoomUrl: 'invalid',
          ),
          isNull);
      expect(
          credentials.effectiveRoomUrl(
            dynamicRoomUrl: 'https://call.daily.co/new',
            configuredRoomUrl: '',
          ),
          'https://call.daily.co/new');
    });
  });

  group('configured Deepgram credential selection', () {
    test('primary credential takes precedence over deprecated API key', () {
      expect(
          credentials.configuredDeepgramCredential(
            primaryCredential: ' primary ',
            legacyApiKey: 'old',
          ),
          'primary');
    });

    test('legacy API key is used only when primary credential is absent', () {
      expect(credentials.configuredDeepgramCredential(legacyApiKey: ' old '),
          'old');
      expect(credentials.configuredDeepgramCredential(), isNull);
    });

    test('present invalid primary does not revive legacy API key', () {
      for (final value in invalidCredentials.whereType<String>()) {
        expect(
            credentials.configuredDeepgramCredential(
              primaryCredential: value,
              legacyApiKey: 'old',
            ),
            isNull,
            reason: 'Invalid primary: "$value"');
      }
    });
  });

  group('Deepgram authorization header', () {
    test('JWT heuristic requires exactly three nonempty segments', () {
      expect(credentials.looksLikeJwt('a.b.c'), isTrue);
      // A shape heuristic, not a signature or Base64 validator.
      expect(credentials.looksLikeJwt(r'!.$.x'), isTrue);
      for (final value in ['', 'a', 'a.b', 'a.b.c.d', '.b.c', 'a..c', 'a.b.']) {
        expect(credentials.looksLikeJwt(value), isFalse, reason: value);
      }
    });

    test('JWT-looking credential gets Bearer prefix', () {
      expect(credentials.buildDeepgramAuthHeader('  a.b.c  '), 'Bearer a.b.c');
    });

    test('non-JWT credential gets Token prefix', () {
      for (final value in ['key', 'a.b', 'a.b.c.d', 'a..c']) {
        expect(credentials.buildDeepgramAuthHeader(' $value '), 'Token $value');
      }
    });

    test('explicit prefixes retain case and interior spacing', () {
      for (final value in [
        'Token key',
        'token key',
        'tOkEn   Key',
        'Bearer a.b.c',
        'bearer key',
        'bEaReR   Key',
      ]) {
        expect(credentials.buildDeepgramAuthHeader('  $value  '), value);
      }
    });
  });
}
