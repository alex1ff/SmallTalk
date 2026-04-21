import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/email_verification_service.dart';

void main() {
  group('custom email verification service', () {
    test('parses sent responses', () {
      final result = parseCustomEmailVerificationResult({
        'sent': true,
        'alreadyVerified': false,
        'providerMessageId': 'email_123',
      });

      expect(result.sent, isTrue);
      expect(result.alreadyVerified, isFalse);
      expect(result.providerMessageId, 'email_123');
    });

    test('passes locale payload to callable invoker once', () async {
      final calls = <Map<String, dynamic>>[];

      final result = await sendCustomEmailVerification(
        locale: 'ru',
        invoker: (payload) async {
          calls.add(payload);
          return {
            'sent': false,
            'alreadyVerified': true,
          };
        },
      );

      expect(calls, [
        {'locale': 'ru'},
      ]);
      expect(result.sent, isFalse);
      expect(result.alreadyVerified, isTrue);
    });

    test('falls back to Firebase default verification when callable fails',
        () async {
      var fallbackCalls = 0;

      final result = await sendCustomEmailVerification(
        locale: 'ru',
        invoker: (_) async => throw Exception('callable unavailable'),
        firebaseEmailFallback: () async {
          fallbackCalls += 1;
        },
      );

      expect(fallbackCalls, 1);
      expect(result.sent, isTrue);
      expect(result.alreadyVerified, isFalse);
      expect(result.providerMessageId, 'firebase_default');
    });

    test('can disable Firebase default fallback', () async {
      expect(
        () => sendCustomEmailVerification(
          locale: 'ru',
          invoker: (_) async => throw Exception('callable unavailable'),
          firebaseEmailFallback: () async {
            fail('fallback should not run');
          },
          fallbackToFirebaseDefault: false,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
