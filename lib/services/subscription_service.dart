// SubscriptionService — singleton wrapper over RevenueCat SDK.
//
// Responsibilities:
//   • Configure RevenueCat with platform-specific public API keys.
//   • Sync Firebase Auth uid ↔ RevenueCat App User ID.
//   • Fetch offerings (1mo / 3mo subscription packages).
//   • Launch native paywall via Purchases.purchasePackage(...).
//   • Stream CustomerInfo updates to UI.
//   • Expose `hasActiveEntitlement` for client-side gating.
//
// Server-side flow remains source of truth:
//   • RevenueCat → revenueCatWebhook Cloud Function → users.subscription
//   • Client reads users.subscription for persistent gating
//   • This service is used for the purchase flow and for live UI updates
//     between webhook delivery (a few seconds delay is normal).
//
// CLAUDE.md rule: never call Purchases.* directly from page widgets —
// always go through this service.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

/// Public RevenueCat API keys. These are SAFE to commit — RC public keys
/// are designed to live in client code; the SECRET key (used server-side
/// for `grant_promo_entitlement`) lives in Firebase Secret Manager.
///
/// Provide real values from RevenueCat Dashboard → Project settings →
/// API keys → "Public app-specific API key".
class SubscriptionApiKeys {
  const SubscriptionApiKeys._();

  /// Public App Store SDK key. Safe to bundle in the app; never put the
  /// RevenueCat `sk_...` secret key here.
  static const String iosPublicFallback = 'appl_uOxpqrnmkxvmCHhFmxJqQePzjRA';

  static const String _iosPublicFromEnv =
      String.fromEnvironment('REVENUECAT_IOS_PUBLIC_KEY');
  static const String _appStorePublicFromEnv = String.fromEnvironment(
    'REVENUECAT_APPSTORE_API_KEY',
    defaultValue: iosPublicFallback,
  );

  static String get iosPublic => resolveRevenueCatPublicKey(
        primary: _iosPublicFromEnv,
        secondary: _appStorePublicFromEnv,
        fallback: iosPublicFallback,
        allowedPrefix: 'appl_',
      );

  static const String _androidPublicFromEnv =
      String.fromEnvironment('REVENUECAT_ANDROID_PUBLIC_KEY');
  static const String _playStorePublicFromEnv =
      String.fromEnvironment('REVENUECAT_PLAYSTORE_API_KEY');

  static String get androidPublic => resolveRevenueCatPublicKey(
        primary: _androidPublicFromEnv,
        secondary: _playStorePublicFromEnv,
        fallback: '',
        allowedPrefix: 'goog_',
      );
}

@visibleForTesting
String resolveRevenueCatPublicKey({
  required String primary,
  required String fallback,
  String secondary = '',
  String? allowedPrefix,
}) {
  for (final key in [primary, secondary, fallback]) {
    final normalized = key.trim();
    if (normalized.isEmpty || normalized.contains('REPLACE_ME')) {
      continue;
    }
    if (allowedPrefix == null || normalized.startsWith(allowedPrefix)) {
      return normalized;
    }
  }
  return '';
}

/// Entitlement ID configured in RevenueCat dashboard. Must match the value
/// in firebase/custom_cloud_functions/revenue_cat_webhook.js and
/// grant_promo_entitlement.js (PRO_ENTITLEMENT_ID).
const String kSubscriptionProEntitlementId = 'pro_access';

/// Stable identifiers of our two products in App Store Connect / Google
/// Play. Used when matching packages returned by RevenueCat offerings.
class SubscriptionProductIds {
  const SubscriptionProductIds._();
  static const String monthly = 'expatlio_1_Month';
  static const String quarterly = 'expatlio_3_Month';

  static const Set<String> monthlyPackageIdentifiers = {
    'expatlio_1_month',
    r'$rc_monthly',
    'monthly',
  };

  static const Set<String> quarterlyPackageIdentifiers = {
    'expatlio_3_month',
    r'$rc_three_month',
    r'$rc_3_month',
    'three_month',
    'quarterly',
  };
}

@visibleForTesting
String? subscriptionProductIdForPackage(Package package) {
  final productId = package.storeProduct.identifier.trim();
  if (productId == SubscriptionProductIds.monthly ||
      productId == SubscriptionProductIds.quarterly) {
    return productId;
  }

  final packageId = package.identifier.trim().toLowerCase();
  if (SubscriptionProductIds.monthlyPackageIdentifiers.contains(packageId)) {
    return SubscriptionProductIds.monthly;
  }
  if (SubscriptionProductIds.quarterlyPackageIdentifiers.contains(packageId)) {
    return SubscriptionProductIds.quarterly;
  }

  switch (package.packageType) {
    case PackageType.monthly:
      return SubscriptionProductIds.monthly;
    case PackageType.threeMonth:
      return SubscriptionProductIds.quarterly;
    case PackageType.unknown:
    case PackageType.custom:
    case PackageType.lifetime:
    case PackageType.annual:
    case PackageType.sixMonth:
    case PackageType.twoMonth:
    case PackageType.weekly:
      return null;
  }
}

Map<String, Package> mapSubscriptionPackagesByProductId(
  Iterable<Package> packages,
) {
  final packagesByProductId = <String, Package>{};

  for (final package in packages) {
    final productId = subscriptionProductIdForPackage(package);
    if (productId != null) {
      packagesByProductId.putIfAbsent(productId, () => package);
    }
  }

  return packagesByProductId;
}

@visibleForTesting
List<Package> selectSubscriptionPackagesFromOfferings(Offerings offerings) {
  final packagesByProductId =
      mapSubscriptionPackagesByProductId(_candidatePackagesFromOfferings(
    offerings,
  ));

  return [
    if (packagesByProductId[SubscriptionProductIds.monthly] != null)
      packagesByProductId[SubscriptionProductIds.monthly]!,
    if (packagesByProductId[SubscriptionProductIds.quarterly] != null)
      packagesByProductId[SubscriptionProductIds.quarterly]!,
  ];
}

List<Package> _candidatePackagesFromOfferings(Offerings offerings) {
  final candidates = <Package>[];
  final seen = <String>{};

  void addOfferingPackages(Offering? offering) {
    if (offering == null) return;

    for (final package in offering.availablePackages) {
      final key =
          '${offering.identifier}/${package.identifier}/${package.storeProduct.identifier}';
      if (seen.add(key)) {
        candidates.add(package);
      }
    }
  }

  // Match FlutterFlow's current-offering behavior first, then fall back to
  // dashboard offerings if targeting/current offering is not ready yet.
  addOfferingPackages(offerings.current);
  for (final offering in offerings.all.values) {
    addOfferingPackages(offering);
  }

  return candidates;
}

class SubscriptionService {
  SubscriptionService._internal();
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;

  /// Convenience alias matching the VoIPService pattern.
  static SubscriptionService get instance => _instance;

  bool _configured = false;
  Future<void>? _configureFuture;

  /// Last known CustomerInfo from RevenueCat. `null` until first event.
  CustomerInfo? _customerInfo;
  CustomerInfo? get customerInfo => _customerInfo;

  final StreamController<CustomerInfo> _customerInfoController =
      StreamController<CustomerInfo>.broadcast();

  /// Broadcast stream of CustomerInfo updates. UI can `listen` to react to
  /// entitlement changes (e.g., refresh "Subscription active until X").
  Stream<CustomerInfo> get customerInfoStream => _customerInfoController.stream;

  /// True iff the user has the `pro_access` entitlement active right now.
  /// Use this for ephemeral UI state — the persistent gating signal is
  /// users.subscription.expiresAt (mirrored by the webhook).
  bool get hasActiveEntitlement {
    final info = _customerInfo;
    if (info == null) return false;
    return info.entitlements.active.containsKey(kSubscriptionProEntitlementId);
  }

  /// Initialise RevenueCat. Call this once from `main.dart` AFTER Firebase
  /// initialisation. Safe to call multiple times — guards re-entry.
  Future<void> configure() async {
    if (_configured) return;
    final existingConfigure = _configureFuture;
    if (existingConfigure != null) {
      return existingConfigure;
    }

    final configureFuture = _configure();
    _configureFuture = configureFuture;
    return configureFuture;
  }

  Future<void> _configure() async {
    try {
      await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.warn,
      );

      final String apiKey = _resolveApiKey();
      if (_isPlaceholderKey(apiKey)) {
        debugPrint(
          '⚠️ SubscriptionService: RevenueCat public API key is not set for '
          'this platform. RevenueCat will stay disabled.',
        );
        return;
      }

      await Purchases.configure(PurchasesConfiguration(apiKey));

      // Initial pull so `hasActiveEntitlement` is meaningful before the
      // first listener event fires.
      try {
        _customerInfo = await Purchases.getCustomerInfo();
      } catch (e, st) {
        debugPrint(
            '⚠️ SubscriptionService: initial getCustomerInfo failed: $e\n$st');
      }

      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);
      _configured = true;
    } catch (e, st) {
      debugPrint('❌ SubscriptionService.configure failed: $e\n$st');
      rethrow;
    } finally {
      _configureFuture = null;
    }
  }

  String _resolveApiKey() {
    if (Platform.isIOS || Platform.isMacOS) {
      return SubscriptionApiKeys.iosPublic;
    }
    if (Platform.isAndroid) {
      return SubscriptionApiKeys.androidPublic;
    }
    // Web / desktop: RevenueCat web SDK is a separate package and not
    // wired up in Phase 1. Fall through to iOS key so the call doesn't
    // crash; offerings will be empty and UI will fall back to "Subscribe
    // in the mobile app" copy.
    return SubscriptionApiKeys.iosPublic;
  }

  bool _isPlaceholderKey(String key) =>
      key.contains('REPLACE_ME') || key.isEmpty;

  void _handleCustomerInfoUpdate(CustomerInfo info) {
    _customerInfo = info;
    if (!_customerInfoController.isClosed) {
      _customerInfoController.add(info);
    }
  }

  /// Bind RevenueCat App User ID to the Firebase uid. Call right after
  /// Firebase Auth sign-in and on app start when a user is already signed
  /// in. Idempotent — RC handles the case where the user is already
  /// logged in to the same id.
  Future<void> logInUser(String firebaseUid) async {
    if (!_configured) {
      await configure();
    }
    if (!_configured) return;
    if (firebaseUid.isEmpty) return;
    try {
      final result = await Purchases.logIn(firebaseUid);
      _customerInfo = result.customerInfo;
      _customerInfoController.add(result.customerInfo);
    } catch (e, st) {
      debugPrint('⚠️ SubscriptionService.logInUser failed: $e\n$st');
    }
  }

  /// Clear the RC user. Call on Firebase Auth sign-out.
  Future<void> logOutUser() async {
    if (!_configured) return;
    try {
      final info = await Purchases.logOut();
      _customerInfo = info;
      _customerInfoController.add(info);
    } catch (e, st) {
      // RC throws if you log out an anonymous user — that's fine, ignore.
      debugPrint('ℹ️ SubscriptionService.logOutUser: $e\n$st');
    }
  }

  /// Fetch RevenueCat offerings and return monthly + quarterly packages, in the
  /// order the UI expects (monthly first, quarterly second).
  /// Returns an empty list if RC doesn't expose either expected product.
  Future<List<Package>> fetchSubscriptionPackages() async {
    try {
      if (!_configured) {
        await configure();
      }
      if (!_configured) return const [];

      final offerings = await Purchases.getOfferings();
      _debugLogOfferings(offerings);

      return selectSubscriptionPackagesFromOfferings(offerings);
    } catch (e, st) {
      debugPrint(
          '❌ SubscriptionService.fetchSubscriptionPackages failed: $e\n$st');
      return const [];
    }
  }

  void _debugLogOfferings(Offerings offerings) {
    if (!kDebugMode) return;

    final currentId = offerings.current?.identifier ?? 'none';
    final packages = _candidatePackagesFromOfferings(offerings)
        .map(
          (package) => '${package.presentedOfferingContext.offeringIdentifier}:'
              '${package.identifier}->${package.storeProduct.identifier}',
        )
        .join(', ');

    debugPrint(
      'ℹ️ SubscriptionService.offerings current=$currentId '
      'all=[${offerings.all.keys.join(', ')}] packages=[$packages]',
    );
  }

  /// Launch the native paywall and complete the purchase. Returns the
  /// updated CustomerInfo on success, or `null` if the user cancelled.
  /// Throws `PlatformException` on unexpected errors so callers can show
  /// a snackbar.
  Future<CustomerInfo?> purchasePackage(Package package) async {
    if (!_configured) {
      await configure();
    }
    if (!_configured) return null;
    try {
      final result = await Purchases.purchasePackage(package);
      _customerInfo = result;
      _customerInfoController.add(result);
      return result;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return null;
      }
      debugPrint(
        '❌ SubscriptionService.purchasePackage failed: code=$errorCode '
        'message=${e.message}',
      );
      rethrow;
    }
  }

  /// Force a fresh fetch of CustomerInfo. Useful after returning from a
  /// background paywall or restoring purchases.
  Future<void> refresh() async {
    if (!_configured) return;
    try {
      final info = await Purchases.getCustomerInfo();
      _customerInfo = info;
      _customerInfoController.add(info);
    } catch (e, st) {
      debugPrint('⚠️ SubscriptionService.refresh failed: $e\n$st');
    }
  }

  /// Restore prior purchases (e.g. after reinstall). Returns updated
  /// CustomerInfo. Throws on RevenueCat/network failure so UI can distinguish
  /// an outage from a successful restore with no active purchases.
  Future<CustomerInfo> restorePurchases() async {
    if (!_configured) {
      await configure();
    }
    if (!_configured) {
      throw StateError('RevenueCat is not configured.');
    }
    try {
      final info = await Purchases.restorePurchases();
      _customerInfo = info;
      _customerInfoController.add(info);
      return info;
    } catch (e, st) {
      debugPrint('⚠️ SubscriptionService.restorePurchases failed: $e\n$st');
      rethrow;
    }
  }
}
