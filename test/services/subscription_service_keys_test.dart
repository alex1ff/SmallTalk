import 'dart:async';

import 'package:flutter/services.dart';
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

    test('prefers the dashboard subscriptions offering over current offering',
        () {
      final staleMonthly = _package(
        packageId: 'stale_monthly',
        productId: SubscriptionProductIds.monthly,
        packageType: PackageType.custom,
        offeringId: 'current',
      );
      final staleQuarterly = _package(
        packageId: 'stale_quarterly',
        productId: SubscriptionProductIds.quarterly,
        packageType: PackageType.custom,
        offeringId: 'current',
      );
      final monthly = _package(
        packageId: r'$rc_monthly',
        productId: SubscriptionProductIds.monthly,
        packageType: PackageType.monthly,
        offeringId: kSubscriptionOfferingId,
      );
      final quarterly = _package(
        packageId: r'$rc_three_month',
        productId: SubscriptionProductIds.quarterly,
        packageType: PackageType.threeMonth,
        offeringId: kSubscriptionOfferingId,
      );
      final offerings = Offerings(
        {
          kSubscriptionOfferingId: _offering(
            kSubscriptionOfferingId,
            [monthly, quarterly],
          ),
          'current': _offering(
            'current',
            [staleMonthly, staleQuarterly],
          ),
        },
        current: _offering(
          'current',
          [staleMonthly, staleQuarterly],
        ),
      );

      expect(
        selectSubscriptionPackagesFromOfferings(offerings)
            .map((package) => package.identifier),
        [
          r'$rc_monthly',
          r'$rc_three_month',
        ],
      );
    });

    test('rejects package identifiers when store product ids differ', () {
      final monthly = _package(
        packageId: SubscriptionProductIds.monthly,
        productId: 'app_store_monthly_product',
        packageType: PackageType.custom,
      );
      final quarterly = _package(
        packageId: SubscriptionProductIds.quarterly,
        productId: 'app_store_quarterly_product',
        packageType: PackageType.custom,
      );

      expect(
        subscriptionProductIdForPackage(monthly),
        isNull,
      );
      expect(
        subscriptionProductIdForPackage(quarterly),
        isNull,
      );
    });

    test('does not map packages with unapproved store product ids', () {
      final monthly = _package(
        packageId: SubscriptionProductIds.monthly,
        productId: 'app_store_monthly_product',
        packageType: PackageType.custom,
      );
      final quarterly = _package(
        packageId: SubscriptionProductIds.quarterly,
        productId: 'app_store_quarterly_product',
        packageType: PackageType.custom,
      );

      final packagesByProductId =
          mapSubscriptionPackagesByProductId([monthly, quarterly]);

      expect(packagesByProductId, isEmpty);
    });

    test('maps direct StoreKit products by product id', () {
      final monthly = _storeProduct(SubscriptionProductIds.monthly);
      final quarterly = _storeProduct(SubscriptionProductIds.quarterly);
      final unrelated = _storeProduct('other_product');

      final productsByProductId = mapSubscriptionStoreProductsByProductId([
        unrelated,
        monthly,
        quarterly,
      ]);

      expect(
        productsByProductId.keys,
        [
          SubscriptionProductIds.monthly,
          SubscriptionProductIds.quarterly,
        ],
      );
    });
  });

  group('RevenueCat catalog error classification', () {
    test('classifies timeout and network failures separately', () {
      expect(
        subscriptionCatalogStatusForError(TimeoutException('slow')),
        SubscriptionCatalogStatus.timedOut,
      );
      expect(
        subscriptionCatalogStatusForError(PlatformException(
          code: PurchasesErrorCode.networkError.index.toString(),
        )),
        SubscriptionCatalogStatus.networkUnavailable,
      );
    });
  });

  group('SubscriptionService identity coordinator', () {
    test('configures once with Firebase uid and eagerly loads customer info',
        () async {
      final sdk = _FakeRevenueCatSdk();
      final service = SubscriptionService.forTesting(
        sdk: sdk,
        apiKey: 'appl_test',
      );

      final first = service.logInUser(' uid-1 ');
      final second = service.logInUser('uid-1');
      await Future.wait([first, second]);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(sdk.configureCalls, 1);
      expect(sdk.configuredUserId, 'uid-1');
      expect(sdk.currentUserId, 'uid-1');
      expect(sdk.offeringsCalls, 1);
      expect(sdk.productsCalls, 1);
      expect(sdk.customerInfoCalls, greaterThanOrEqualTo(1));
    });

    test('deduplicates concurrent offering loads and retries after failure',
        () async {
      final sdk = _FakeRevenueCatSdk();
      final service = SubscriptionService.forTesting(
        sdk: sdk,
        apiKey: 'appl_test',
      );
      await service.logInUser('uid-1');
      sdk.offeringsGate = Completer<void>();

      final first = service.ensureOfferingsLoaded();
      final second = service.ensureOfferingsLoaded();
      await Future<void>.delayed(Duration.zero);

      expect(sdk.offeringsCalls, 1);
      sdk.offeringsGate!.complete();
      expect(identical(await first, await second), isTrue);
      expect(sdk.offeringsCalls, 1);

      await service.logInUser('uid-2');
      sdk.offeringsError = StateError('temporary');
      await expectLater(service.ensureOfferingsLoaded(), throwsStateError);
      sdk.offeringsError = null;
      await service.ensureOfferingsLoaded();
      expect(sdk.offeringsCalls, 3);
    });

    test('uses direct StoreKit products when offerings fail', () async {
      final sdk = _FakeRevenueCatSdk()
        ..offeringsError = StateError('offerings unavailable');
      final service = SubscriptionService.forTesting(
        sdk: sdk,
        apiKey: 'appl_test',
      );
      await service.logInUser('uid-1');

      final catalog = await service.loadSubscriptionCatalog();

      expect(catalog.status, SubscriptionCatalogStatus.ready);
      expect(catalog.packages, isEmpty);
      expect(
        catalog.storeProducts.map((product) => product.identifier).toSet(),
        SubscriptionProductIds.all.toSet(),
      );
      expect(sdk.productsCalls, 1);
    });

    test('times out a hung offering request without blocking restore or retry',
        () async {
      final sdk = _FakeRevenueCatSdk()..offeringsGate = Completer<void>();
      final service = SubscriptionService.forTesting(
        sdk: sdk,
        apiKey: 'appl_test',
        catalogRequestTimeout: const Duration(milliseconds: 20),
      );
      await service.logInUser('uid-1');

      final firstOfferingLoad = service.ensureOfferingsLoaded();
      await Future<void>.delayed(Duration.zero);
      final restored = await service
          .restorePurchases()
          .timeout(const Duration(milliseconds: 100));
      expect(restored.originalAppUserId, 'uid-1');
      await expectLater(firstOfferingLoad, throwsA(isA<TimeoutException>()));

      sdk.offeringsGate = null;
      final offerings = await service.ensureOfferingsLoaded();
      expect(offerings, isNotNull);
      expect(sdk.offeringsCalls, 2);
    });

    test('blocks restore while purchase owns the identity lease', () async {
      final sdk = _FakeRevenueCatSdk();
      final service = SubscriptionService.forTesting(
        sdk: sdk,
        apiKey: 'appl_test',
      );
      await service.logInUser('uid-1');
      sdk.purchaseGate = Completer<void>();
      final purchase = service.purchasePackage(_package(
        packageId: r'$rc_monthly',
        productId: SubscriptionProductIds.monthly,
        packageType: PackageType.monthly,
      ));
      await sdk.purchaseStarted.future;

      await expectLater(
        service.restorePurchases(),
        throwsA(isA<SubscriptionCommerceBusyException>()),
      );

      sdk.purchaseGate!.complete();
      await purchase;
    });

    test('defers Firebase uid changes until purchase releases identity lease',
        () async {
      final sdk = _FakeRevenueCatSdk();
      final service = SubscriptionService.forTesting(
        sdk: sdk,
        apiKey: 'appl_test',
      );
      await service.logInUser('uid-1');
      sdk.purchaseGate = Completer<void>();
      final purchase = service.purchasePackage(_package(
        packageId: r'$rc_monthly',
        productId: SubscriptionProductIds.monthly,
        packageType: PackageType.monthly,
      ));
      await sdk.purchaseStarted.future;

      final switchUser = service.logInUser('uid-2');
      await Future<void>.delayed(Duration.zero);
      expect(sdk.currentUserId, 'uid-1');
      sdk.purchaseGate!.complete();

      final purchaseInfo = await purchase;
      expect(purchaseInfo?.originalAppUserId, 'uid-1');
      await switchUser;
      expect(sdk.currentUserId, 'uid-2');
      expect(service.customerInfo?.originalAppUserId, 'uid-2');
    });

    test('defers logout until purchase releases identity lease', () async {
      final sdk = _FakeRevenueCatSdk();
      final service = SubscriptionService.forTesting(
        sdk: sdk,
        apiKey: 'appl_test',
      );
      await service.logInUser('uid-1');
      sdk.purchaseGate = Completer<void>();
      final purchase = service.purchasePackage(_package(
        packageId: r'$rc_monthly',
        productId: SubscriptionProductIds.monthly,
        packageType: PackageType.monthly,
      ));
      await sdk.purchaseStarted.future;

      final logout = service.logOutUser();
      await Future<void>.delayed(Duration.zero);
      expect(sdk.currentUserId, 'uid-1');
      sdk.purchaseGate!.complete();

      expect((await purchase)?.originalAppUserId, 'uid-1');
      await logout;
      expect(service.customerInfo, isNull);
    });

    test('listener refresh reads current uid data instead of stale payload',
        () async {
      final sdk = _FakeRevenueCatSdk();
      final service = SubscriptionService.forTesting(
        sdk: sdk,
        apiKey: 'appl_test',
      );
      await service.logInUser('uid-1');
      await service.logInUser('uid-2');

      sdk.listener?.call(_customerInfo('uid-1'));
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(service.customerInfo?.originalAppUserId, 'uid-2');
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

StoreProduct _storeProduct(String productId) {
  return StoreProduct(
    productId,
    'Description',
    'Title',
    1,
    r'$1.00',
    'USD',
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

CustomerInfo _customerInfo(String userId) => CustomerInfo.fromJson({
      'entitlements': const <String, dynamic>{
        'all': <String, dynamic>{},
        'active': <String, dynamic>{},
        'verification': 'NOT_REQUESTED',
      },
      'allPurchaseDates': const <String, dynamic>{},
      'activeSubscriptions': const <String>[],
      'allPurchasedProductIdentifiers': const <String>[],
      'nonSubscriptionTransactions': const <Object>[],
      'firstSeen': '2026-08-28T00:00:00Z',
      'originalAppUserId': userId,
      'allExpirationDates': const <String, dynamic>{},
      'requestDate': '2026-08-28T00:00:00Z',
    });

class _FakeRevenueCatSdk implements RevenueCatSdkAdapter {
  bool configured = false;
  String currentUserId = '';
  String? configuredUserId;
  int configureCalls = 0;
  int offeringsCalls = 0;
  int productsCalls = 0;
  int customerInfoCalls = 0;
  Object? offeringsError;
  Completer<void>? offeringsGate;
  Completer<void>? purchaseGate;
  Completer<void> purchaseStarted = Completer<void>();
  void Function(CustomerInfo info)? listener;

  Offerings get offerings => Offerings({
        kSubscriptionOfferingId: _offering(
          kSubscriptionOfferingId,
          [
            _package(
              packageId: r'$rc_monthly',
              productId: SubscriptionProductIds.monthly,
              packageType: PackageType.monthly,
              offeringId: kSubscriptionOfferingId,
            ),
            _package(
              packageId: r'$rc_three_month',
              productId: SubscriptionProductIds.quarterly,
              packageType: PackageType.threeMonth,
              offeringId: kSubscriptionOfferingId,
            ),
          ],
        ),
      });

  @override
  void addCustomerInfoUpdateListener(
    void Function(CustomerInfo info) listener,
  ) {
    this.listener = listener;
  }

  @override
  Future<void> configure({
    required String apiKey,
    required String appUserId,
  }) async {
    configureCalls += 1;
    configured = true;
    configuredUserId = appUserId;
    currentUserId = appUserId;
  }

  @override
  Future<String> currentAppUserId() async => currentUserId;

  @override
  Future<CustomerInfo> getCustomerInfo() async {
    customerInfoCalls += 1;
    return _customerInfo(currentUserId);
  }

  @override
  Future<Offerings> getOfferings() async {
    offeringsCalls += 1;
    final error = offeringsError;
    if (error != null) throw error;
    final gate = offeringsGate;
    if (gate != null) await gate.future;
    return offerings;
  }

  @override
  Future<List<StoreProduct>> getProducts(List<String> productIds) async {
    productsCalls += 1;
    return productIds.map(_storeProduct).toList();
  }

  @override
  Future<bool> isConfigured() async => configured;

  @override
  Future<CustomerInfo> logIn(String appUserId) async {
    currentUserId = appUserId;
    return _customerInfo(appUserId);
  }

  @override
  Future<CustomerInfo> purchase(PurchaseParams params) async {
    if (!purchaseStarted.isCompleted) purchaseStarted.complete();
    final gate = purchaseGate;
    if (gate != null) await gate.future;
    return _customerInfo(currentUserId);
  }

  @override
  Future<CustomerInfo> restorePurchases() async => _customerInfo(currentUserId);

  @override
  Future<void> setLogLevel(LogLevel level) async {}
}
