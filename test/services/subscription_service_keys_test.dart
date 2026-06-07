import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
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

    test('falls back to FlutterFlow Play Store dart-define key', () {
      expect(
        resolveRevenueCatPublicKey(
          primary: '',
          secondary: 'goog_flutterflow',
          fallback: '',
          allowedPrefix: 'goog_',
        ),
        'goog_flutterflow',
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

  group('RevenueCat subscription package selection', () {
    test('uses packages from all offerings when current offering is empty', () {
      final monthly = _package(
        packageId: r'$rc_monthly',
        productId: SubscriptionProductIds.monthly,
        packageType: PackageType.monthly,
        offeringId: 'fallback',
      );
      final quarterly = _package(
        packageId: r'$rc_three_month',
        productId: SubscriptionProductIds.quarterly,
        packageType: PackageType.threeMonth,
        offeringId: 'fallback',
      );
      final offerings = Offerings(
        {
          'fallback': _offering(
            'fallback',
            [quarterly, monthly],
          ),
        },
      );

      expect(
        selectSubscriptionPackagesFromOfferings(offerings)
            .map((package) => package.storeProduct.identifier),
        [
          SubscriptionProductIds.monthly,
          SubscriptionProductIds.quarterly,
        ],
      );
    });

    test('matches FlutterFlow package identifiers when product ids differ', () {
      final monthly = _package(
        packageId: r'$rc_monthly',
        productId: 'app_store_monthly_product',
        packageType: PackageType.monthly,
      );
      final quarterly = _package(
        packageId: r'$rc_three_month',
        productId: 'app_store_quarterly_product',
        packageType: PackageType.threeMonth,
      );

      expect(
        subscriptionProductIdForPackage(monthly),
        SubscriptionProductIds.monthly,
      );
      expect(
        subscriptionProductIdForPackage(quarterly),
        SubscriptionProductIds.quarterly,
      );
    });
  });
}

Package _package({
  required String packageId,
  required String productId,
  required PackageType packageType,
  String offeringId = 'current',
}) {
  return Package(
    packageId,
    packageType,
    StoreProduct(
      productId,
      'Description',
      'Title',
      1,
      r'$1.00',
      'USD',
    ),
    PresentedOfferingContext(offeringId, null, null),
  );
}

Offering _offering(String id, List<Package> packages) {
  return Offering(
    id,
    'Subscription offering',
    const {},
    packages,
  );
}
