import '/components/student_pay_bottom_bar.dart';
import '/components/student_pay_intro.dart';
import '/components/student_pay_plan.dart';
import '/components/student_pay_plan_card.dart';
import '/components/student_pay_restore_purchases_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'pay_model.dart';
export 'pay_model.dart';

typedef StudentPayCatalogLoader = Future<Map<String, String>> Function();
typedef StudentPayPurchaseHandler = Future<void> Function(String productId);

class PayWidget extends StatefulWidget {
  const PayWidget({super.key})
      : _catalogLoader = null,
        _purchaseHandler = null;

  @visibleForTesting
  const PayWidget.withPaymentGateway({
    super.key,
    required StudentPayCatalogLoader catalogLoader,
    required StudentPayPurchaseHandler purchaseHandler,
  })  : _catalogLoader = catalogLoader,
        _purchaseHandler = purchaseHandler;

  final StudentPayCatalogLoader? _catalogLoader;
  final StudentPayPurchaseHandler? _purchaseHandler;

  static String routeName = 'Pay';
  static String routePath = '/pay';

  @override
  State<PayWidget> createState() => _PayWidgetState();
}

const _plans = [
  StudentPayPlan(
    kind: StudentPayPlanKind.monthly,
    productId: SubscriptionProductIds.monthly,
    title: 'Basic',
    subtitle: 'Для старта изучения языка',
    periodLabel: 'мес',
    icon: FFIcons.kwallet02,
    features: [
      'До 10 звонков в месяц',
      'Базовый словарь',
      'Субтитры в звонках',
    ],
  ),
  StudentPayPlan(
    kind: StudentPayPlanKind.quarterly,
    productId: SubscriptionProductIds.quarterly,
    title: 'Pro',
    subtitle: 'Полный доступ ко всем возможностям',
    periodLabel: '3 мес',
    icon: Icons.auto_awesome_rounded,
    badge: 'ПОПУЛЯРНЫЙ',
    features: [
      'Безлимитные звонки',
      'Расширенный словарь и флэшкарты',
      'Перевод в реальном времени',
      'Приоритетная поддержка',
    ],
  ),
];

class _PayWidgetState extends State<PayWidget> {
  late PayModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  StudentPayPlanKind _selected = StudentPayPlanKind.quarterly;
  Map<String, Package> _packagesByProductId = const {};
  Map<String, StoreProduct> _storeProductsByProductId = const {};
  Map<String, String> _injectedPricesByProductId = const {};
  bool _isLoadingPackages = true;
  bool _isPurchasing = false;
  bool _isRestoringPurchases = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PayModel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPackages();
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  StudentPayPlan get _selectedPlan =>
      _plans.firstWhere((plan) => plan.kind == _selected);

  Package? get _selectedPackage =>
      _packagesByProductId[_selectedPlan.productId];

  StoreProduct? get _selectedStoreProduct =>
      _storeProductsByProductId[_selectedPlan.productId];

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
        debugPrint('⚠️ PayWidget._loadPackages failed: $e\n$st');
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
        _isLoadingPackages = false;
      });
      return;
    }

    List<Package> packages = const [];
    List<StoreProduct> storeProducts = const [];
    SubscriptionCatalogResult catalogResult;
    try {
      catalogResult =
          await SubscriptionService.instance.loadSubscriptionCatalog().timeout(
                const Duration(seconds: 25),
                onTimeout: () => const SubscriptionCatalogResult(
                  status: SubscriptionCatalogStatus.timedOut,
                ),
              );
      packages = catalogResult.packages;
      storeProducts = catalogResult.storeProducts;
    } catch (e, st) {
      debugPrint('⚠️ PayWidget._loadPackages failed: $e\n$st');
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
      _isLoadingPackages = false;
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

  Future<void> _purchaseSelectedPlan() async {
    if (_isPurchasing || _isLoadingPackages) {
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
        _showSnackBar(_localized('Подписка активна.', 'Subscription active.'));
        context.safePop();
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
      final info = await SubscriptionService.instance.restorePurchases();
      if (!mounted) {
        return;
      }
      final hasPro =
          info.entitlements.active.containsKey(kSubscriptionProEntitlementId);
      _showSnackBar(
        hasPro
            ? _localized('Покупки восстановлены.', 'Purchases restored.')
            : _localized(
                'Активных покупок для восстановления не найдено.',
                'No active purchases were found to restore.',
              ),
      );
      if (hasPro) {
        context.safePop();
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
                        for (final plan in _plans) ...[
                          StudentPayPlanCard(
                            plan: plan,
                            selected: _selected == plan.kind,
                            price: _priceFor(plan),
                            priceAvailable: _hasPackageFor(plan),
                            onTap: () {
                              safeSetState(() {
                                _selected = plan.kind;
                              });
                            },
                          ),
                          if (plan != _plans.last)
                            const SizedBox(height: ExpatlioDesign.space12),
                        ],
                        const SizedBox(height: ExpatlioDesign.space16),
                        StudentPayRestorePurchasesButton(
                          isBusy: _isRestoringPurchases,
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
          canPurchase: _hasPackageFor(_selectedPlan),
          isBusy: _isPurchasing,
          isLoading: _isLoadingPackages,
          onPressed: _hasPackageFor(_selectedPlan)
              ? _purchaseSelectedPlan
              : _loadPackages,
        ),
      ),
    );
  }
}
