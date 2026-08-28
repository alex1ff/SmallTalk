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
const String kSubscriptionProEntitlementId = 'Expatlio Pro';

/// Offering ID configured in RevenueCat dashboard for the subscription screen.
const String kSubscriptionOfferingId = 'subscriptions';

/// Stable identifiers of our two products in App Store Connect / Google
/// Play. Used when matching packages returned by RevenueCat offerings.
class SubscriptionProductIds {
  const SubscriptionProductIds._();
  static const String monthly = 'expatlio_1_Month';
  static const String quarterly = 'expatlio_3_Month';
  static const List<String> all = [monthly, quarterly];
}

String? subscriptionProductIdForStoreProduct(StoreProduct product) {
  final productId = product.identifier.trim();
  if (productId == SubscriptionProductIds.monthly ||
      productId == SubscriptionProductIds.quarterly) {
    return productId;
  }
  return null;
}

@visibleForTesting
String? subscriptionProductIdForPackage(Package package) {
  // Package identifiers and package types are presentation metadata and can
  // be reused by stale/targeted offerings. Only the exact store product IDs
  // accepted by the backend webhook are safe to purchase.
  return subscriptionProductIdForStoreProduct(package.storeProduct);
}

Map<String, StoreProduct> mapSubscriptionStoreProductsByProductId(
  Iterable<StoreProduct> products,
) {
  final productsByProductId = <String, StoreProduct>{};

  for (final product in products) {
    final productId = subscriptionProductIdForStoreProduct(product);
    if (productId != null) {
      productsByProductId.putIfAbsent(productId, () => product);
    }
  }

  return productsByProductId;
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

  // The RevenueCat dashboard offering for this app is `subscriptions`.
  // Prefer it explicitly because `current` can be null or point elsewhere
  // when targeting/paywall rules are not configured for the user yet.
  addOfferingPackages(offerings.getOffering(kSubscriptionOfferingId));
  addOfferingPackages(offerings.current);
  for (final offering in offerings.all.values) {
    addOfferingPackages(offering);
  }

  return candidates;
}

abstract interface class RevenueCatSdkAdapter {
  Future<bool> isConfigured();
  Future<void> setLogLevel(LogLevel level);
  Future<void> configure({
    required String apiKey,
    required String appUserId,
  });
  Future<String> currentAppUserId();
  Future<CustomerInfo> getCustomerInfo();
  Future<CustomerInfo> logIn(String appUserId);
  Future<Offerings> getOfferings();
  Future<List<StoreProduct>> getProducts(List<String> productIds);
  Future<CustomerInfo> purchase(PurchaseParams params);
  Future<CustomerInfo> restorePurchases();
  void addCustomerInfoUpdateListener(
    void Function(CustomerInfo info) listener,
  );
}

class PurchasesRevenueCatSdkAdapter implements RevenueCatSdkAdapter {
  const PurchasesRevenueCatSdkAdapter();

  @override
  Future<bool> isConfigured() => Purchases.isConfigured;

  @override
  Future<void> setLogLevel(LogLevel level) => Purchases.setLogLevel(level);

  @override
  Future<void> configure({
    required String apiKey,
    required String appUserId,
  }) {
    final configuration = PurchasesConfiguration(apiKey)..appUserID = appUserId;
    return Purchases.configure(configuration);
  }

  @override
  Future<String> currentAppUserId() => Purchases.appUserID;

  @override
  Future<CustomerInfo> getCustomerInfo() => Purchases.getCustomerInfo();

  @override
  Future<CustomerInfo> logIn(String appUserId) async =>
      (await Purchases.logIn(appUserId)).customerInfo;

  @override
  Future<Offerings> getOfferings() => Purchases.getOfferings();

  @override
  Future<List<StoreProduct>> getProducts(List<String> productIds) =>
      Purchases.getProducts(
        productIds,
        productCategory: ProductCategory.subscription,
      );

  @override
  Future<CustomerInfo> purchase(PurchaseParams params) async =>
      (await Purchases.purchase(params)).customerInfo;

  @override
  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();

  @override
  void addCustomerInfoUpdateListener(
    void Function(CustomerInfo info) listener,
  ) {
    Purchases.addCustomerInfoUpdateListener(listener);
  }
}

enum SubscriptionCatalogStatus {
  ready,
  partial,
  noProducts,
  identityUnavailable,
  configurationUnavailable,
  networkUnavailable,
  timedOut,
  failed,
}

@visibleForTesting
SubscriptionCatalogStatus subscriptionCatalogStatusForError(Object error) {
  if (error is TimeoutException) {
    return SubscriptionCatalogStatus.timedOut;
  }
  if (error is PlatformException) {
    try {
      final code = PurchasesErrorHelper.getErrorCode(error);
      if (code == PurchasesErrorCode.networkError ||
          code == PurchasesErrorCode.offlineConnectionError ||
          code == PurchasesErrorCode.apiEndpointBlocked) {
        return SubscriptionCatalogStatus.networkUnavailable;
      }
      if (code == PurchasesErrorCode.productRequestTimeout) {
        return SubscriptionCatalogStatus.timedOut;
      }
      if (code == PurchasesErrorCode.configurationError ||
          code == PurchasesErrorCode.invalidCredentialsError) {
        return SubscriptionCatalogStatus.configurationUnavailable;
      }
    } catch (_) {
      // Malformed native errors remain generic failures.
    }
  }
  return SubscriptionCatalogStatus.failed;
}

class SubscriptionCatalogResult {
  const SubscriptionCatalogResult({
    required this.status,
    this.packages = const <Package>[],
    this.storeProducts = const <StoreProduct>[],
    this.error,
  });

  final SubscriptionCatalogStatus status;
  final List<Package> packages;
  final List<StoreProduct> storeProducts;
  final Object? error;

  bool get hasAnyProduct => packages.isNotEmpty || storeProducts.isNotEmpty;
}

class SubscriptionIdentityException implements Exception {
  const SubscriptionIdentityException(this.message);
  final String message;

  @override
  String toString() => 'SubscriptionIdentityException: $message';
}

class SubscriptionCommerceBusyException implements Exception {
  const SubscriptionCommerceBusyException();

  @override
  String toString() => 'A purchase or restore operation is already active.';
}

class SubscriptionService {
  SubscriptionService._internal()
      : _sdk = const PurchasesRevenueCatSdkAdapter(),
        _apiKeyOverride = null,
        _identityTimeout = const Duration(seconds: 20),
        _catalogRequestTimeout = const Duration(seconds: 15);

  @visibleForTesting
  SubscriptionService.forTesting({
    required RevenueCatSdkAdapter sdk,
    required String apiKey,
    Duration identityTimeout = const Duration(seconds: 2),
    Duration catalogRequestTimeout = const Duration(seconds: 2),
  })  : _sdk = sdk,
        _apiKeyOverride = apiKey,
        _identityTimeout = identityTimeout,
        _catalogRequestTimeout = catalogRequestTimeout;

  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;

  /// Convenience alias matching the VoIPService pattern.
  static SubscriptionService get instance => _instance;

  final RevenueCatSdkAdapter _sdk;
  final String? _apiKeyOverride;
  final Duration _identityTimeout;
  final Duration _catalogRequestTimeout;

  bool _configured = false;
  bool _listenerRegistered = false;
  Future<void>? _configureFuture;
  Future<void> _operationTail = Future<void>.value();
  Future<void>? _identityReadyFuture;
  int _identityGeneration = 0;
  String? _desiredUserId;
  String? _activeUserId;
  bool _commerceBusy = false;

  Offerings? _offerings;
  int? _offeringsGeneration;
  Future<Offerings?>? _offeringsFuture;
  int? _offeringsFutureGeneration;
  List<StoreProduct> _storeProducts = const <StoreProduct>[];
  int? _storeProductsGeneration;
  Future<List<StoreProduct>>? _storeProductsFuture;
  int? _storeProductsFutureGeneration;
  Future<void>? _listenerRefreshFuture;
  int? _listenerRefreshGeneration;

  /// Last known CustomerInfo from RevenueCat. `null` until first event.
  CustomerInfo? _customerInfo;
  CustomerInfo? get customerInfo => _customerInfo;

  final StreamController<CustomerInfo> _customerInfoController =
      StreamController<CustomerInfo>.broadcast();

  /// Broadcast stream of CustomerInfo updates. UI can `listen` to react to
  /// entitlement changes (e.g., refresh "Subscription active until X").
  Stream<CustomerInfo> get customerInfoStream => _customerInfoController.stream;

  /// True iff the user has the paid entitlement active right now.
  /// Use this for ephemeral UI state — the persistent gating signal is
  /// users.subscription.expiresAt (mirrored by the webhook).
  bool get hasActiveEntitlement {
    final info = _customerInfo;
    if (info == null) return false;
    return info.entitlements.active.containsKey(kSubscriptionProEntitlementId);
  }

  /// Initialise RevenueCat. Call this once from `main.dart` AFTER Firebase
  /// initialisation. Safe to call multiple times — guards re-entry.
  Future<void> configure({String? initialAppUserId}) {
    final normalizedInitialUserId = _normalizeUserId(initialAppUserId);
    if (normalizedInitialUserId != null) {
      return logInUser(normalizedInitialUserId);
    }
    final desiredUserId = _desiredUserId;
    if (desiredUserId == null) {
      return Future<void>.value();
    }
    return logInUser(desiredUserId);
  }

  Future<void> waitForInitialization() async {
    final future = _identityReadyFuture;
    if (future != null) {
      await future;
    }
  }

  Future<void> _configureSdkIfNeeded(String userId) async {
    if (_configured) return;
    final existingConfigure = _configureFuture;
    if (existingConfigure != null) {
      await existingConfigure;
      return;
    }

    final configureFuture = _configureSdk(userId);
    _configureFuture = configureFuture;
    try {
      await configureFuture;
    } finally {
      if (identical(_configureFuture, configureFuture)) {
        _configureFuture = null;
      }
    }
  }

  Future<void> _configureSdk(String userId) async {
    try {
      await _sdk.setLogLevel(
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

      final alreadyConfigured = await _sdk.isConfigured();
      if (!alreadyConfigured) {
        await _sdk.configure(apiKey: apiKey, appUserId: userId);
      }

      if (!_listenerRegistered) {
        _sdk.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);
        _listenerRegistered = true;
      }
      _configured = true;
    } catch (e, st) {
      debugPrint('❌ SubscriptionService.configure failed: $e\n$st');
      rethrow;
    }
  }

  String _resolveApiKey() {
    final override = _apiKeyOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
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

  void _handleCustomerInfoUpdate(CustomerInfo _) {
    final generation = _identityGeneration;
    final userId = _desiredUserId;
    if (userId == null) return;
    final existing = _listenerRefreshFuture;
    if (existing != null && _listenerRefreshGeneration == generation) return;

    late final Future<void> future;
    future = _enqueue<void>(() async {
      final identity = _RevenueCatIdentity(
        generation: generation,
        userId: userId,
      );
      await _assertIdentityInsideOperation(identity);
      final currentInfo = await _sdk.getCustomerInfo();
      await _acceptCustomerInfoIfCurrent(
        currentInfo,
        generation: generation,
        userId: userId,
      );
    });
    _listenerRefreshFuture = future;
    _listenerRefreshGeneration = generation;
    unawaited(future.whenComplete(() {
      if (identical(_listenerRefreshFuture, future)) {
        _listenerRefreshFuture = null;
        _listenerRefreshGeneration = null;
      }
    }).catchError((Object error, StackTrace stackTrace) {
      debugPrint('⚠️ RevenueCat listener refresh failed: $error\n$stackTrace');
    }));
  }

  /// Bind RevenueCat App User ID to the Firebase uid. Call right after
  /// Firebase Auth sign-in and on app start when a user is already signed
  /// in. Idempotent — RC handles the case where the user is already
  /// logged in to the same id.
  Future<void> logInUser(String firebaseUid) {
    final userId = _normalizeUserId(firebaseUid);
    if (userId == null) return Future<void>.value();

    if (_commerceBusy) {
      return _deferLoginUntilCommerceCompletes(userId);
    }

    return _startLogin(userId);
  }

  Future<void> _deferLoginUntilCommerceCompletes(String userId) {
    final queuedIdentityFuture = _enqueue<void>(() async {
      _prepareIdentityChange(userId);
      await _synchronizeIdentity(
        generation: _identityGeneration,
        userId: userId,
        eagerLoad: true,
      );
    });
    return _trackIdentityFuture(queuedIdentityFuture);
  }

  Future<void> _startLogin(String userId) {
    final identityChanged = _prepareIdentityChange(userId);
    if (!identityChanged) {
      final existingIdentityFuture = _identityReadyFuture;
      if (existingIdentityFuture != null) {
        return existingIdentityFuture;
      }
    }
    final generation = _identityGeneration;
    final queuedIdentityFuture = _enqueue<void>(() async {
      if (!_isCurrentIdentity(generation, userId)) return;
      await _synchronizeIdentity(
        generation: generation,
        userId: userId,
        eagerLoad: true,
      );
    });
    return _trackIdentityFuture(queuedIdentityFuture);
  }

  bool _prepareIdentityChange(String userId) {
    final identityChanged = _desiredUserId != userId;
    if (identityChanged) {
      _desiredUserId = userId;
      _identityGeneration += 1;
      _invalidateIdentityCaches();
    }
    return identityChanged;
  }

  Future<void> _trackIdentityFuture(Future<void> queuedIdentityFuture) {
    late final Future<void> identityFuture;
    identityFuture = (() async {
      try {
        await queuedIdentityFuture;
      } catch (_) {
        if (identical(_identityReadyFuture, identityFuture)) {
          _identityReadyFuture = null;
        }
        rethrow;
      }
    })();
    _identityReadyFuture = identityFuture;
    return identityFuture;
  }

  /// Clear the RC user. Call on Firebase Auth sign-out.
  Future<void> logOutUser() {
    if (_desiredUserId == null && _activeUserId == null) {
      return Future<void>.value();
    }
    if (_commerceBusy) {
      return _enqueue<void>(() async {
        _applyLogoutState();
      });
    }
    _applyLogoutState();
    final generation = _identityGeneration;
    return _enqueue<void>(() async {
      if (generation != _identityGeneration || _desiredUserId != null) return;
      _activeUserId = null;
    });
  }

  void _applyLogoutState() {
    _desiredUserId = null;
    _identityGeneration += 1;
    _identityReadyFuture = null;
    _invalidateIdentityCaches();
    _activeUserId = null;
  }

  /// Fetch RevenueCat offerings and return monthly + quarterly packages, in the
  /// order the UI expects (monthly first, quarterly second).
  /// Returns an empty list if RC doesn't expose either expected product.
  Future<List<Package>> fetchSubscriptionPackages() async {
    try {
      final offerings = await ensureOfferingsLoaded();
      if (offerings == null) return const [];
      _debugLogOfferings(offerings);

      return selectSubscriptionPackagesFromOfferings(offerings);
    } catch (e, st) {
      debugPrint(
          '❌ SubscriptionService.fetchSubscriptionPackages failed: $e\n$st');
      return const [];
    }
  }

  /// Fetch products directly from StoreKit / Play Billing. This is a fallback
  /// for cases where RevenueCat returns the offering metadata but the SDK does
  /// not map packages into available offerings.
  Future<List<StoreProduct>> fetchSubscriptionStoreProducts() async {
    try {
      final products = await _ensureStoreProductsLoaded();
      _debugLogStoreProducts(products);
      return products;
    } catch (e, st) {
      debugPrint(
        '❌ SubscriptionService.fetchSubscriptionStoreProducts failed: $e\n$st',
      );
      return const [];
    }
  }

  Future<Offerings?> ensureOfferingsLoaded() async {
    final identity = await _ensureIdentityReady();
    if (_offeringsGeneration == identity.generation && _offerings != null) {
      return _offerings;
    }
    final existing = _offeringsFuture;
    if (existing != null && _offeringsFutureGeneration == identity.generation) {
      return existing;
    }

    late final Future<Offerings?> future;
    future = (() async {
      await _assertIdentityCurrent(identity);
      final offerings =
          await _sdk.getOfferings().timeout(_catalogRequestTimeout);
      await _assertIdentityCurrent(identity);
      if (!_isCurrentIdentity(identity.generation, identity.userId)) {
        return null;
      }
      _offerings = offerings;
      _offeringsGeneration = identity.generation;
      return offerings;
    })();
    _offeringsFuture = future;
    _offeringsFutureGeneration = identity.generation;
    try {
      return await future;
    } finally {
      if (identical(_offeringsFuture, future)) {
        _offeringsFuture = null;
        _offeringsFutureGeneration = null;
      }
    }
  }

  Future<SubscriptionCatalogResult> loadSubscriptionCatalog() async {
    Offerings? offerings;
    List<StoreProduct> directProducts = const [];
    Object? offeringsError;
    Object? productsError;

    await Future.wait<void>([
      (() async {
        try {
          offerings = await ensureOfferingsLoaded();
        } catch (error, st) {
          offeringsError = error;
          debugPrint('⚠️ RevenueCat offerings unavailable: $error\n$st');
        }
      })(),
      (() async {
        try {
          directProducts = await _ensureStoreProductsLoaded();
        } catch (error, st) {
          productsError = error;
          debugPrint('⚠️ RevenueCat direct products unavailable: $error\n$st');
        }
      })(),
    ]);

    final packages = offerings == null
        ? const <Package>[]
        : selectSubscriptionPackagesFromOfferings(offerings!);
    final packageProducts = mapSubscriptionStoreProductsByProductId(
      packages.map((package) => package.storeProduct),
    );
    final mappedDirectProducts =
        mapSubscriptionStoreProductsByProductId(directProducts);
    final productsById = <String, StoreProduct>{
      ...packageProducts,
      ...mappedDirectProducts,
    };
    final availableIds = <String>{
      ...mapSubscriptionPackagesByProductId(packages).keys,
      ...productsById.keys,
    };
    final error = productsError ?? offeringsError;

    if (availableIds.isEmpty && error != null) {
      return SubscriptionCatalogResult(
        status: error is SubscriptionIdentityException
            ? SubscriptionCatalogStatus.identityUnavailable
            : _configured
                ? subscriptionCatalogStatusForError(error)
                : SubscriptionCatalogStatus.configurationUnavailable,
        error: error,
      );
    }

    final status = availableIds.isEmpty
        ? SubscriptionCatalogStatus.noProducts
        : availableIds.length == SubscriptionProductIds.all.length
            ? SubscriptionCatalogStatus.ready
            : SubscriptionCatalogStatus.partial;
    return SubscriptionCatalogResult(
      status: status,
      packages: List<Package>.unmodifiable(packages),
      storeProducts: List<StoreProduct>.unmodifiable(productsById.values),
      error: error,
    );
  }

  void _debugLogOfferings(Offerings offerings) {
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

  void _debugLogStoreProducts(List<StoreProduct> products) {
    final productLog = products
        .map((product) => '${product.identifier}:${product.priceString}')
        .join(', ');
    debugPrint(
      'ℹ️ SubscriptionService.storeProducts requested='
      '[${SubscriptionProductIds.all.join(', ')}] products=[$productLog]',
    );
  }

  /// Launch the native paywall and complete the purchase. Returns the
  /// updated CustomerInfo on success, or `null` if the user cancelled.
  /// Throws `PlatformException` on unexpected errors so callers can show
  /// a snackbar.
  Future<CustomerInfo?> purchasePackage(Package package) async {
    return _purchase(() => _sdk.purchase(PurchaseParams.package(package)));
  }

  Future<CustomerInfo?> _purchase(
    Future<CustomerInfo> Function() action,
  ) async {
    try {
      return await _runCommerce(action);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return null;
      }
      debugPrint(
        '❌ SubscriptionService.purchase failed: code=$errorCode '
        'message=${e.message}',
      );
      rethrow;
    }
  }

  /// Purchase a store product fetched directly via Purchases.getProducts.
  Future<CustomerInfo?> purchaseStoreProduct(StoreProduct product) async {
    return _purchase(() => _sdk.purchase(PurchaseParams.storeProduct(product)));
  }

  /// Force a fresh fetch of CustomerInfo. Useful after returning from a
  /// background paywall or restoring purchases.
  Future<void> refresh() async {
    try {
      final identity = await _ensureIdentityReady();
      await _enqueue<void>(() async {
        await _assertIdentityInsideOperation(identity);
        final info = await _sdk.getCustomerInfo();
        await _acceptCustomerInfoIfCurrent(
          info,
          generation: identity.generation,
          userId: identity.userId,
        );
      });
    } catch (e, st) {
      debugPrint('⚠️ SubscriptionService.refresh failed: $e\n$st');
    }
  }

  /// Restore prior purchases (e.g. after reinstall). Returns updated
  /// CustomerInfo. Throws on RevenueCat/network failure so UI can distinguish
  /// an outage from a successful restore with no active purchases.
  Future<CustomerInfo> restorePurchases() async {
    try {
      final info = await _runCommerce(_sdk.restorePurchases);
      if (info == null) {
        throw const SubscriptionIdentityException(
          'Restore completed after the authenticated identity changed.',
        );
      }
      return info;
    } catch (e, st) {
      debugPrint('⚠️ SubscriptionService.restorePurchases failed: $e\n$st');
      rethrow;
    }
  }

  Future<CustomerInfo?> _runCommerce(
    Future<CustomerInfo> Function() action,
  ) async {
    if (_commerceBusy) {
      throw const SubscriptionCommerceBusyException();
    }
    _commerceBusy = true;
    try {
      final identity = await _ensureIdentityReady();
      return await _enqueue<CustomerInfo?>(() async {
        await _assertIdentityInsideOperation(identity);
        final info = await action();
        await _assertIdentityInsideOperation(identity);
        await _acceptCustomerInfoIfCurrent(
          info,
          generation: identity.generation,
          userId: identity.userId,
        );
        return info;
      });
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return null;
      }
      rethrow;
    } finally {
      _commerceBusy = false;
    }
  }

  Future<List<StoreProduct>> _ensureStoreProductsLoaded() async {
    final identity = await _ensureIdentityReady();
    if (_storeProductsGeneration == identity.generation &&
        _storeProducts.isNotEmpty) {
      return _storeProducts;
    }
    final existing = _storeProductsFuture;
    if (existing != null &&
        _storeProductsFutureGeneration == identity.generation) {
      return existing;
    }

    late final Future<List<StoreProduct>> future;
    future = (() async {
      await _assertIdentityCurrent(identity);
      final products = await _sdk
          .getProducts(SubscriptionProductIds.all)
          .timeout(_catalogRequestTimeout);
      await _assertIdentityCurrent(identity);
      if (!_isCurrentIdentity(identity.generation, identity.userId)) {
        return const <StoreProduct>[];
      }
      _storeProducts = List<StoreProduct>.unmodifiable(products);
      _storeProductsGeneration = identity.generation;
      return _storeProducts;
    })();
    _storeProductsFuture = future;
    _storeProductsFutureGeneration = identity.generation;
    try {
      return await future;
    } finally {
      if (identical(_storeProductsFuture, future)) {
        _storeProductsFuture = null;
        _storeProductsFutureGeneration = null;
      }
    }
  }

  Future<_RevenueCatIdentity> _ensureIdentityReady() async {
    final userId = _desiredUserId;
    if (userId == null) {
      throw const SubscriptionIdentityException(
        'A signed-in Firebase user is required for purchases.',
      );
    }
    final generation = _identityGeneration;
    var future = _identityReadyFuture;
    if (future == null || _activeUserId != userId) {
      future = logInUser(userId);
    }
    await future.timeout(_identityTimeout);
    final identity = _RevenueCatIdentity(
      generation: generation,
      userId: userId,
    );
    await _assertIdentityCurrent(identity);
    return identity;
  }

  Future<void> _synchronizeIdentity({
    required int generation,
    required String userId,
    required bool eagerLoad,
  }) async {
    await _configureSdkIfNeeded(userId);
    if (!_isCurrentIdentity(generation, userId)) return;

    var currentUserId = await _sdk.currentAppUserId();
    CustomerInfo? loginInfo;
    if (currentUserId != userId) {
      loginInfo = await _sdk.logIn(userId);
      currentUserId = await _sdk.currentAppUserId();
    }
    if (currentUserId != userId || !_isCurrentIdentity(generation, userId)) {
      throw const SubscriptionIdentityException(
        'RevenueCat did not bind to the authenticated Firebase user.',
      );
    }
    _activeUserId = userId;
    if (loginInfo != null) {
      await _acceptCustomerInfoIfCurrent(
        loginInfo,
        generation: generation,
        userId: userId,
      );
    }

    if (!eagerLoad) return;
    try {
      final info = await _sdk.getCustomerInfo();
      await _acceptCustomerInfoIfCurrent(
        info,
        generation: generation,
        userId: userId,
      );
    } catch (error, st) {
      debugPrint('⚠️ RevenueCat customer preload failed: $error\n$st');
    }
    _scheduleCatalogPreload(
      generation: generation,
      userId: userId,
    );
  }

  void _scheduleCatalogPreload({
    required int generation,
    required String userId,
  }) {
    unawaited(Future<void>(() async {
      if (!_isCurrentIdentity(generation, userId)) return;
      await Future.wait<void>([
        (() async {
          try {
            await ensureOfferingsLoaded();
          } catch (error, stackTrace) {
            debugPrint('⚠️ RevenueCat offering preload failed: '
                '$error\n$stackTrace');
          }
        })(),
        (() async {
          try {
            await _ensureStoreProductsLoaded();
          } catch (error, stackTrace) {
            debugPrint('⚠️ RevenueCat product preload failed: '
                '$error\n$stackTrace');
          }
        })(),
      ]);
    }));
  }

  Future<void> _acceptCustomerInfoIfCurrent(
    CustomerInfo info, {
    required int generation,
    required String userId,
  }) async {
    if (!_isCurrentIdentity(generation, userId)) return;
    final sdkUserId = await _sdk.currentAppUserId();
    if (!_isCurrentIdentity(generation, userId) || sdkUserId != userId) return;
    _customerInfo = info;
    if (!_customerInfoController.isClosed) {
      _customerInfoController.add(info);
    }
  }

  Future<void> _assertIdentityCurrent(_RevenueCatIdentity identity) async {
    if (!_isCurrentIdentity(identity.generation, identity.userId)) {
      throw const SubscriptionIdentityException(
        'The authenticated Firebase user changed.',
      );
    }
    final sdkUserId = await _sdk.currentAppUserId();
    if (!_isCurrentIdentity(identity.generation, identity.userId) ||
        sdkUserId != identity.userId) {
      throw const SubscriptionIdentityException(
        'RevenueCat identity is not ready for this Firebase user.',
      );
    }
  }

  Future<void> _assertIdentityInsideOperation(
    _RevenueCatIdentity identity,
  ) =>
      _assertIdentityCurrent(identity);

  bool _isCurrentIdentity(int generation, String userId) =>
      generation == _identityGeneration && _desiredUserId == userId;

  void _invalidateIdentityCaches() {
    _customerInfo = null;
    _offerings = null;
    _offeringsGeneration = null;
    _offeringsFuture = null;
    _offeringsFutureGeneration = null;
    _storeProducts = const <StoreProduct>[];
    _storeProductsGeneration = null;
    _storeProductsFuture = null;
    _storeProductsFutureGeneration = null;
    _listenerRefreshFuture = null;
    _listenerRefreshGeneration = null;
  }

  String? _normalizeUserId(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operationTail = _operationTail.catchError((_) {}).then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

class _RevenueCatIdentity {
  const _RevenueCatIdentity({
    required this.generation,
    required this.userId,
  });

  final int generation;
  final String userId;
}
