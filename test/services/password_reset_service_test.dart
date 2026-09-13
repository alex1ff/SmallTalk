import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/password_reset_service.dart';

void main() {
  group('password reset service', () {
    test('parses accepted response', () {
      final result = parsePasswordResetRequestResult({'accepted': true});

      expect(result.accepted, isTrue);
    });

    test('sends trimmed email and locale', () async {
      final calls = <Map<String, dynamic>>[];

      final result = await requestPasswordReset(
        email: ' user@example.com ',
        locale: 'en',
        invoker: (payload) async {
          calls.add(payload);
          return {'accepted': true};
        },
      );

      expect(result.accepted, isTrue);
      expect(calls, [
        {'email': 'user@example.com', 'locale': 'en'},
      ]);
    });

    test('rejects malformed server response', () async {
      expect(
        () => requestPasswordReset(
          email: 'user@example.com',
          invoker: (_) async => {'accepted': false},
        ),
        throwsStateError,
      );
    });
  });
}
