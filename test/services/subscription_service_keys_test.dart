import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/subscription_service.dart';

void main() {
  group('RevenueCat public key resolution', () {
    test('prefers explicit iOS dart-define key', () {
      expect(
        resolveRevenueCatPublicKey(
          primary: 'appl_env',
          secondary: 'appl_flutterflow',
          fallback: 'appl_fallback',
          allowedPrefix: 'appl_',
        ),
        'appl_env',
      );
    });

    test('falls back to FlutterFlow App Store dart-define key', () {
      expect(
        resolveRevenueCatPublicKey(
          primary: '',
          secondary: 'appl_flutterflow',
          fallback: 'appl_fallback',
          allowedPrefix: 'appl_',
        ),
        'appl_flutterflow',
      );
    });

    test('uses bundled public fallback when dart-define values are empty', () {
      expect(
        resolveRevenueCatPublicKey(
          primary: '',
          secondary: '',
          fallback: SubscriptionApiKeys.iosPublicFallback,
          allowedPrefix: 'appl_',
        ),
        SubscriptionApiKeys.iosPublicFallback,
      );
    });

    test('rejects secret API keys even if accidentally passed by dart-define',
        () {
      expect(
        resolveRevenueCatPublicKey(
          primary: 'sk_accidentally_configured',
          secondary: '',
          fallback: SubscriptionApiKeys.iosPublicFallback,
          allowedPrefix: 'appl_',
        ),
        SubscriptionApiKeys.iosPublicFallback,
      );
    });

    test('rejects non-App-Store keys for iOS fallback resolution', () {
      expect(
        resolveRevenueCatPublicKey(
          primary: 'goog_android_key',
          secondary: 'sk_accidentally_configured',
          fallback: SubscriptionApiKeys.iosPublicFallback,
          allowedPrefix: 'appl_',
        ),
        SubscriptionApiKeys.iosPublicFallback,
      );
    });
  });
}
