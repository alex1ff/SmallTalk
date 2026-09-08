import '/components/student_pay_bottom_bar.dart';
import '/components/student_pay_intro.dart';
import '/components/student_pay_plan.dart';
import '/components/student_pay_plan_card.dart';
import '/components/student_pay_restore_purchases_button.dart';
import '/components/student_pay_catalog_error.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/subscription_service.dart';
import '/services/safe_debug_log.dart';
import '/utils/subscription_utils.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'pay_model.dart';
export 'pay_model.dart';

typedef StudentPayCatalogLoader = Future<Map<String, String>> Function();
typedef StudentPayPurchaseHandler = Future<void> Function(String productId);
typedef StudentPayRestoreHandler = Future<bool> Function();

class PayWidget extends StatefulWidget {
  const PayWidget({super.key, this.premiumOnly = false})
      : _catalogLoader = null,
        _purchaseHandler = null,
        _restoreHandler = null,
        _trialOfferEligibleOverride = null;

  @visibleForTesting
  const PayWidget.withPaymentGateway({
    super.key,
    required StudentPayCatalogLoader catalogLoader,
    required StudentPayPurchaseHandler purchaseHandler,
    StudentPayRestoreHandler? restoreHandler,
    bool trialOfferEligible = false,
    this.premiumOnly = false,
  })  : _catalogLoader = catalogLoader,
        _purchaseHandler = purchaseHandler,
        _restoreHandler = restoreHandler,
        _trialOfferEligibleOverride = trialOfferEligible;

  final StudentPayCatalogLoader? _catalogLoader;
  final StudentPayPurchaseHandler? _purchaseHandler;
  final StudentPayRestoreHandler? _restoreHandler;
  final bool? _trialOfferEligibleOverride;
  final bool premiumOnly;

  static String routeName = 'Pay';
  static String routePath = '/pay';

  @override
  State<PayWidget> createState() => _PayWidgetState();
}

const _trialPlan = StudentPayPlan(
  kind: StudentPayPlanKind.trialMonthly,
  productId: SubscriptionProductIds.trialMonthly,
  title: '1 месяц',
  subtitle: '3 дня бесплатно, затем полный доступ',
  periodLabel: 'мес',
  icon: Icons.calendar_today_rounded,
  badge: '3 ДНЯ БЕСПЛАТНО',
  features: [],
);

const _monthlyPlan = StudentPayPlan(
  kind: StudentPayPlanKind.monthly,
  productId: SubscriptionProductIds.monthly,
  title: '1 месяц',
  subtitle: 'Оплата ежемесячно',
  periodLabel: 'мес',
  icon: FFIcons.kwallet02,
  features: [],
);

const _quarterlyPlan = StudentPayPlan(
  kind: StudentPayPlanKind.quarterly,
  productId: SubscriptionProductIds.quarterly,
  title: '3 месяца',
  subtitle: 'Оплата сразу за 3 месяца',
  periodLabel: '3 мес',
  icon: Icons.auto_awesome_rounded,
  badge: 'ВЫГОДНЕЕ',
  features: [],
);

@visibleForTesting
List<StudentPayPlan> resolveStudentPayPlans({
  required bool paidOnly,
  required bool catalogLoaded,
  required bool trialOfferEligible,
  required Set<String> availableProductIds,
}) {
  bool available(String productId) =>
      !catalogLoaded || availableProductIds.contains(productId);

  if (paidOnly) {
    return [
      if (available(SubscriptionProductIds.monthly)) _monthlyPlan,
      if (available(SubscriptionProductIds.quarterly)) _quarterlyPlan,
    ];
  }

  final monthly =
      trialOfferEligible && available(SubscriptionProductIds.trialMonthly)
          ? _trialPlan
          : available(SubscriptionProductIds.monthly)
              ? _monthlyPlan
              : available(SubscriptionProductIds.trialMonthly)
                  ? _monthlyPlan.copyWith(
                      productId: SubscriptionProductIds.trialMonthly,
                    )
                  : null;

  return [
    if (monthly != null) monthly,
    if (available(SubscriptionProductIds.quarterly)) _quarterlyPlan,
  ];
}

@visibleForTesting
bool hasVerifiedThreeDayTrialOffer({
  required SubscriptionIntroEligibility eligibility,
  required StoreProduct? product,
}) {
  if (eligibility != SubscriptionIntroEligibility.eligible) return false;
  final intro = product?.introductoryPrice;
  return intro != null &&
      intro.price == 0 &&
      intro.cycles == 1 &&
      intro.periodUnit == PeriodUnit.day &&
      intro.periodNumberOfUnits == 3;
}

typedef StudentPayPurchaseTarget = ({
  Package? package,
  StoreProduct? storeProduct,
});

@visibleForTesting
StudentPayPurchaseTarget resolveStudentPayPurchaseTarget({
  required String productId,
  required Map<String, Package> packagesByProductId,
  required Map<String, StoreProduct> storeProductsByProductId,
}) {
  final package = packagesByProductId[productId];
  return (
    package: package,
    storeProduct: package == null ? storeProductsByProductId[productId] : null,
  );
}

@visibleForTesting
String resolveDefaultStudentPayProductId({
  required List<StudentPayPlan> plans,
  required bool preferQuarterly,
  String? currentProductId,
}) {
  if (plans.isEmpty) return '';

  bool contains(String productId) =>
      plans.any((plan) => plan.productId == productId);

  if (preferQuarterly && contains(SubscriptionProductIds.quarterly)) {
    return SubscriptionProductIds.quarterly;
  }
  if (currentProductId == SubscriptionProductIds.quarterly &&
      contains(SubscriptionProductIds.quarterly)) {
    return SubscriptionProductIds.quarterly;
  }
  if ((currentProductId == SubscriptionProductIds.monthly ||
          currentProductId == SubscriptionProductIds.trialMonthly) &&
      contains(SubscriptionProductIds.monthly)) {
    return SubscriptionProductIds.monthly;
  }
  return plans.first.productId;
}

class _PayWidgetState extends State<PayWidget> {
  late PayModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  String? _selectedProductId;
  Map<String, Package> _packagesByProductId = const {};
  Map<String, StoreProduct> _storeProductsByProductId = const {};
  Map<String, String> _injectedPricesByProductId = const {};
  bool _isLoadingPackages = true;
  bool _isPurchasing = false;
  bool _isRestoringPurchases = false;
  bool _catalogLoadScheduled = false;
  SubscriptionCatalogStatus _catalogStatus =
      SubscriptionCatalogStatus.noProducts;
  SubscriptionIntroEligibility _trialEligibility =
      SubscriptionIntroEligibility.unknown;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PayModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  bool get _paidOnly =>
      widget.premiumOnly || hasActiveSubscription(currentUserDocument);

  bool get _isAwaitingUserDocument =>
      widget._catalogLoader == null &&
      !hasCurrentUserDocumentForUid(currentUserUid);

  void _scheduleInitialCatalogLoad() {
    if (_catalogLoadScheduled) return;
    _catalogLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPackages();
      }
    });
  }

  Set<String> get _availableProductIds => {
        ..._injectedPricesByProductId.keys,
        ..._packagesByProductId.keys,
        ..._storeProductsByProductId.keys,
      };

  StoreProduct? _storeProductFor(String productId) =>
      _packagesByProductId[productId]?.storeProduct ??
      _storeProductsByProductId[productId];

  bool get _hasVerifiedThreeDayTrial {
    final override = widget._trialOfferEligibleOverride;
    if (override != null) return override;
    return hasVerifiedThreeDayTrialOffer(
      eligibility: _trialEligibility,
      product: _storeProductFor(SubscriptionProductIds.trialMonthly),
    );
  }

  List<StudentPayPlan> get _visiblePlans => resolveStudentPayPlans(
        paidOnly: _paidOnly,
        catalogLoaded: !_isLoadingPackages,
        trialOfferEligible: _hasVerifiedThreeDayTrial,
        availableProductIds: _availableProductIds,
      ).map(_localizedPlan).toList(growable: false);

  StudentPayPlan _localizedPlan(StudentPayPlan plan) {
    return switch (plan.kind) {
      StudentPayPlanKind.trialMonthly => plan.copyWith(
          title: _localized('1 месяц', '1 month'),
          subtitle: _localized(
            '3 дня бесплатно, затем полный доступ',
            '3 days free, then full access',
          ),
          periodLabel: _localized('мес', 'month'),
          badge: _localized('3 ДНЯ БЕСПЛАТНО', '3 DAYS FREE'),
        ),
      StudentPayPlanKind.monthly => plan.copyWith(
          title: _localized('1 месяц', '1 month'),
          subtitle: _localized('Оплата ежемесячно', 'Billed monthly'),
          periodLabel: _localized('мес', 'month'),
        ),
      StudentPayPlanKind.quarterly => plan.copyWith(
          title: _localized('3 месяца', '3 months'),
          subtitle: _localized(
            'Оплата сразу за 3 месяца',
            'Billed every 3 months',
          ),
          periodLabel: _localized('3 мес', '3 months'),
          badge: _localized('ВЫГОДНЕЕ', 'BEST VALUE'),
        ),
    };
  }

  StudentPayPlan get _selectedPlan {
    final plans = _visiblePlans;
    if (plans.isEmpty) {
      return _paidOnly ? _quarterlyPlan : _monthlyPlan;
    }
    final requestedProductId = _selectedProductId;
    final selectedProductId = requestedProductId != null &&
            plans.any((plan) => plan.productId == requestedProductId)
        ? requestedProductId
        : _defaultProductId(plans);
    return plans.firstWhere(
      (plan) => plan.productId == selectedProductId,
      orElse: () => plans.first,
    );
  }

  String _defaultProductId(List<StudentPayPlan> plans) {
    return resolveDefaultStudentPayProductId(
      plans: plans,
      preferQuarterly:
          widget.premiumOnly || isTrialSubscription(currentUserDocument),
      currentProductId: currentUserDocument?.subscription?.productId,
    );
  }

  StudentPayPurchaseTarget get _selectedPurchaseTarget =>
      resolveStudentPayPurchaseTarget(
        productId: _selectedPlan.productId,
        packagesByProductId: _packagesByProductId,
        storeProductsByProductId: _storeProductsByProductId,
      );

  Package? get _selectedPackage => _selectedPurchaseTarget.package;

  StoreProduct? get _selectedStoreProduct =>
      _selectedPurchaseTarget.storeProduct;

  Future<void> _loadPackages() async {
    if (mounted) {
      safeSetState(() {
        _isLoadingPackages = true;
      });
    }

    final catalogLoader = widget._catalogLoader;
    if (catalogLoader != null) {
      Map<String, String> prices = const {};
      try {
        prices = await catalogLoader().timeout(
          const Duration(seconds: 20),
          onTimeout: () => const {},
        );
      } catch (e, st) {
        safeDebugLog('⚠️ PayWidget._loadPackages failed: $e\n$st');
        if (mounted) {
          _showSnackBar(_localized(
            'Не удалось загрузить тарифы. Попробуйте ещё раз.',
            'Could not load plans. Please try again.',
          ));
        }
      }
      if (!mounted) {
        return;
      }
      safeSetState(() {
        _injectedPricesByProductId = Map.unmodifiable(prices);
        _catalogStatus = prices.isEmpty
            ? SubscriptionCatalogStatus.noProducts
            : SubscriptionCatalogStatus.ready;
        _isLoadingPackages = false;
        _selectedProductId = _defaultProductId(_visiblePlans);
      });
      return;
    }

    List<Package> packages = const [];
    List<StoreProduct> storeProducts = const [];
    SubscriptionCatalogResult catalogResult;
    try {
      catalogResult = await SubscriptionService.instance
          .loadSubscriptionCatalog(
            includeTrialEligibility: !_paidOnly,
          )
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => const SubscriptionCatalogResult(
              status: SubscriptionCatalogStatus.timedOut,
            ),
          );
      packages = catalogResult.packages;
      storeProducts = catalogResult.storeProducts;
    } catch (e, st) {
      safeDebugLog('⚠️ PayWidget._loadPackages failed: $e\n$st');
      catalogResult = SubscriptionCatalogResult(
        status: SubscriptionCatalogStatus.failed,
        error: e,
      );
      if (mounted) {
        _showSnackBar(_localized(
          'Не удалось загрузить тарифы. Попробуйте ещё раз.',
          'Could not load plans. Please try again.',
        ));
      }
    }

    if (!mounted) {
      return;
    }

    safeSetState(() {
      _packagesByProductId = mapSubscriptionPackagesByProductId(packages);
      _storeProductsByProductId =
          mapSubscriptionStoreProductsByProductId(storeProducts);
      _catalogStatus = catalogResult.status;
      _trialEligibility = catalogResult.trialEligibility;
      _isLoadingPackages = false;
      final plans = _visiblePlans;
      if (!plans.any((plan) => plan.productId == _selectedProductId)) {
        _selectedProductId = _defaultProductId(plans);
      }
    });

    if (!catalogResult.hasAnyProduct && mounted) {
      _showSnackBar(_catalogFailureMessage(catalogResult.status));
    }
  }

  String _catalogFailureMessage(SubscriptionCatalogStatus status) {
    return switch (status) {
      SubscriptionCatalogStatus.identityUnavailable => _localized(
          'Войдите в аккаунт и повторите загрузку тарифов.',
          'Sign in and reload the plans.',
        ),
      SubscriptionCatalogStatus.configurationUnavailable => _localized(
          'Покупки не настроены для этой версии приложения.',
          'Purchases are not configured for this app version.',
        ),
      SubscriptionCatalogStatus.noProducts => _localized(
          'App Store не вернул цены. Проверьте продукты для этого приложения.',
          'The App Store did not return prices for this app.',
        ),
      SubscriptionCatalogStatus.networkUnavailable => _localized(
          'Не удалось подключиться к App Store. Проверьте интернет.',
          'Could not connect to the App Store. Check your connection.',
        ),
      SubscriptionCatalogStatus.timedOut => _localized(
          'Загрузка тарифов заняла слишком много времени. Повторите.',
          'Loading plans took too long. Please try again.',
        ),
      SubscriptionCatalogStatus.failed => _localized(
          'Не удалось загрузить тарифы. Повторите ещё раз.',
          'Could not load plans. Please try again.',
        ),
      SubscriptionCatalogStatus.ready ||
      SubscriptionCatalogStatus.partial =>
        _localized(
          'Не удалось загрузить выбранный тариф.',
          'Could not load the selected plan.',
        ),
    };
  }

  String _localized(String ru, String en) =>
      FFLocalizations.of(context).getVariableText(ruText: ru, enText: en);

  String _priceFor(StudentPayPlan plan) {
    final injectedPrice = _injectedPricesByProductId[plan.productId];
    if (injectedPrice != null) {
      return injectedPrice;
    }
    final package = _packagesByProductId[plan.productId];
    if (package != null) {
      return package.storeProduct.priceString;
    }
    final storeProduct = _storeProductsByProductId[plan.productId];
    if (storeProduct != null) {
      return storeProduct.priceString;
    }
    return _isLoadingPackages
        ? _localized('Загрузка...', 'Loading...')
        : _localized('Недоступно', 'Unavailable');
  }

  bool _hasPackageFor(StudentPayPlan plan) =>
      _injectedPricesByProductId.containsKey(plan.productId) ||
      _packagesByProductId.containsKey(plan.productId) ||
      _storeProductsByProductId.containsKey(plan.productId);

  String _actionLabelFor(StudentPayPlan plan) {
    final price = _priceFor(plan);
    if (plan.kind == StudentPayPlanKind.trialMonthly &&
        _hasVerifiedThreeDayTrial) {
      return _localized(
        'Попробовать 3 дня бесплатно',
        'Try 3 days free',
      );
    }
    if (isTrialSubscription(currentUserDocument)) {
      return _localized(
        'Начать Premium сейчас · $price',
        'Start Premium now · $price',
      );
    }
    return switch (plan.kind) {
      StudentPayPlanKind.quarterly => _localized(
          'Оформить 3 месяца · $price',
          'Get 3 months · $price',
        ),
      StudentPayPlanKind.monthly ||
      StudentPayPlanKind.trialMonthly =>
        _localized(
          'Оформить месяц · $price',
          'Get 1 month · $price',
        ),
    };
  }

  String _termsTextFor(StudentPayPlan plan) {
    if (plan.kind == StudentPayPlanKind.trialMonthly &&
        _hasVerifiedThreeDayTrial) {
      return _localized(
        '3 дня бесплатно, затем ${_priceFor(plan)} в месяц. Автопродление, отмена в любой момент.',
        '3 days free, then ${_priceFor(plan)} per month. Auto-renews; cancel anytime.',
      );
    }
    return _localized(
      'Подписка продлевается автоматически. Отмена в любой момент.',
      'Subscription renews automatically. Cancel anytime.',
    );
  }

  Future<bool> _waitForServerSubscriptionMirror([String? productId]) async {
    final userRef = currentUserReference;
    if (userRef == null) return false;
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final user = await UsersRecord.getDocumentOnce(userRef);
        final subscription = user.subscription;
        final matchesCurrentProduct =
            productId == null || subscription?.productId == productId;
        final matchesDeferredPaidChange = productId != null &&
            subscription?.pendingProductId == productId &&
            isPaidPremiumSubscription(user);
        if ((matchesCurrentProduct || matchesDeferredPaidChange) &&
            hasActiveSubscription(user)) {
          if (matchesCurrentProduct && isTrialSubscription(user)) {
            final trialState =
                await userRef.collection('trialAccess').doc('current').get();
            if (trialState.exists) return true;
          } else if (isPaidPremiumSubscription(user)) {
            return true;
          }
        }
      } catch (error, stackTrace) {
        safeDebugLog(
          '⚠️ PayWidget._waitForServerSubscriptionMirror failed: '
          '$error\n$stackTrace',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return false;
  }

  Future<void> _purchaseSelectedPlan() async {
    if (_isPurchasing || _isRestoringPurchases || _isLoadingPackages) {
      return;
    }

    final purchaseHandler = widget._purchaseHandler;
    if (purchaseHandler != null) {
      if (!_hasPackageFor(_selectedPlan)) {
        await _loadPackages();
      }
      if (!mounted || !_hasPackageFor(_selectedPlan)) {
        _showSnackBar(
          _localized(
            'Покупки пока недоступны. Повторите загрузку тарифов.',
            'Purchases are unavailable. Reload the plans.',
          ),
        );
        return;
      }

      safeSetState(() {
        _isPurchasing = true;
      });
      try {
        await purchaseHandler(_selectedPlan.productId);
      } catch (_) {
        if (mounted) {
          _showSnackBar(_localized(
            'Не удалось оформить подписку. Попробуйте ещё раз.',
            'Could not complete the subscription. Please try again.',
          ));
        }
      } finally {
        if (mounted) {
          safeSetState(() {
            _isPurchasing = false;
          });
        }
      }
      return;
    }

    Package? package = _selectedPackage;
    StoreProduct? storeProduct = _selectedStoreProduct;
    if (package == null && storeProduct == null) {
      await _loadPackages();
      if (!mounted) {
        return;
      }
      package = _selectedPackage;
      storeProduct = _selectedStoreProduct;
    }

    if (package == null && storeProduct == null) {
      _showSnackBar(_localized(
        'Покупки пока недоступны. Повторите загрузку тарифов.',
        'Purchases are unavailable. Reload the plans.',
      ));
      return;
    }

    safeSetState(() {
      _isPurchasing = true;
    });

    try {
      final info = package != null
          ? await SubscriptionService.instance.purchasePackage(package)
          : await SubscriptionService.instance.purchaseStoreProduct(
              storeProduct!,
            );
      if (!mounted || info == null) {
        return;
      }

      final hasPro =
          info.entitlements.active.containsKey(kSubscriptionProEntitlementId);
      if (hasPro) {
        _showSnackBar(_localized(
          'Покупка подтверждена. Активируем доступ…',
          'Purchase confirmed. Activating access…',
        ));
        final mirrorReady = await _waitForServerSubscriptionMirror(
          _selectedPlan.productId,
        );
        if (!mounted) return;
        if (mirrorReady) {
          _showSnackBar(
            _localized('Подписка активна.', 'Subscription active.'),
          );
          context.safePop();
        } else {
          _showSnackBar(_localized(
            'Покупка ещё обрабатывается. Оставайтесь на экране и нажмите «Восстановить покупки» или повторите загрузку.',
            'Your purchase is still processing. Stay on this screen and use Restore purchases or reload the plans.',
          ));
        }
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar(_localized(
          'Не удалось оформить подписку. Попробуйте ещё раз.',
          'Could not complete the subscription. Please try again.',
        ));
      }
    } finally {
      if (mounted) {
        safeSetState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    if (_isRestoringPurchases || _isPurchasing) {
      return;
    }

    safeSetState(() {
      _isRestoringPurchases = true;
    });

    try {
      final restoreHandler = widget._restoreHandler;
      if (restoreHandler != null) {
        final hasActivePurchase = await restoreHandler();
        if (!mounted) return;
        _showSnackBar(
          hasActivePurchase
              ? _localized(
                  'Покупки восстановлены.',
                  'Purchases restored.',
                )
              : _localized(
                  'Активных покупок для восстановления не найдено.',
                  'No active purchases were found to restore.',
                ),
        );
        return;
      }
      final info = await SubscriptionService.instance.restorePurchases();
      if (!mounted) {
        return;
      }
      final hasPro =
          info.entitlements.active.containsKey(kSubscriptionProEntitlementId);
      _showSnackBar(
        hasPro
            ? _localized(
                'Покупки восстановлены. Активируем доступ…',
                'Purchases restored. Activating access…',
              )
            : _localized(
                'Активных покупок для восстановления не найдено.',
                'No active purchases were found to restore.',
              ),
      );
      if (hasPro) {
        final mirrorReady = await _waitForServerSubscriptionMirror();
        if (!mounted) return;
        if (mirrorReady) {
          _showSnackBar(
            _localized('Подписка активна.', 'Subscription active.'),
          );
          context.safePop();
        } else {
          _showSnackBar(_localized(
            'Покупка ещё обрабатывается. Повторите восстановление позже.',
            'Your purchase is still processing. Restore it again shortly.',
          ));
        }
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar(_localized(
          'Не удалось восстановить покупки. Попробуйте ещё раз.',
          'Could not restore purchases. Please try again.',
        ));
      }
    } finally {
      if (mounted) {
        safeSetState(() {
          _isRestoringPurchases = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget._catalogLoader != null) {
      _scheduleInitialCatalogLoad();
      return _buildPaywall(context);
    }
    return AuthUserStreamWidget(
      builder: (context) {
        if (_isAwaitingUserDocument) {
          return _buildUserDocumentLoading(context);
        }
        _scheduleInitialCatalogLoad();
        return _buildPaywall(context);
      },
    );
  }

  Widget _buildUserDocumentLoading(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: ExpatlioDesign.background,
      body: Column(
        children: [
          BasicPageHeader(
            title: _localized('Тарифы', 'Plans'),
            onBack: () => context.safePop(),
          ),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator.adaptive(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaywall(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: ExpatlioDesign.background,
        body: Column(
          children: [
            BasicPageHeader(
              title: _localized('Тарифы', 'Plans'),
              onBack: () => context.safePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.pagePadding,
                  ExpatlioDesign.space24,
                  ExpatlioDesign.pagePadding,
                  ExpatlioDesign.space24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const StudentPayIntro(),
                        const SizedBox(height: ExpatlioDesign.space24),
                        if (!_isLoadingPackages && _visiblePlans.isEmpty)
                          StudentPayCatalogError(
                            message: _catalogFailureMessage(_catalogStatus),
                            onRetry: _loadPackages,
                          )
                        else
                          for (final plan in _visiblePlans) ...[
                            StudentPayPlanCard(
                              plan: plan,
                              selected:
                                  _selectedPlan.productId == plan.productId,
                              price: _priceFor(plan),
                              priceAvailable: _hasPackageFor(plan),
                              onTap: () {
                                safeSetState(() {
                                  _selectedProductId = plan.productId;
                                });
                              },
                            ),
                            if (plan != _visiblePlans.last)
                              const SizedBox(height: ExpatlioDesign.space12),
                          ],
                        const SizedBox(height: ExpatlioDesign.space16),
                        StudentPayRestorePurchasesButton(
                          isBusy: _isRestoringPurchases || _isPurchasing,
                          onPressed: _restorePurchases,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: StudentPayBottomBar(
          plan: _selectedPlan,
          price: _priceFor(_selectedPlan),
          actionLabel: _actionLabelFor(_selectedPlan),
          termsText: _termsTextFor(_selectedPlan),
          canPurchase: _hasPackageFor(_selectedPlan),
          isBusy: _isPurchasing || _isRestoringPurchases,
          isLoading: _isLoadingPackages,
          retryLabel: _localized('Повторить загрузку', 'Try again'),
          onPressed: _hasPackageFor(_selectedPlan)
              ? _purchaseSelectedPlan
              : _loadPackages,
        ),
      ),
    );
  }
}
