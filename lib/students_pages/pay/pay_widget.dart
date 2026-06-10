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

class PayWidget extends StatefulWidget {
  const PayWidget({super.key});

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

  Future<void> _loadPackages() async {
    if (mounted) {
      safeSetState(() {
        _isLoadingPackages = true;
      });
    }

    List<Package> packages;
    try {
      packages = await SubscriptionService.instance
          .fetchSubscriptionPackages()
          .timeout(const Duration(seconds: 20), onTimeout: () => const []);
    } catch (e, st) {
      debugPrint('⚠️ PayWidget._loadPackages failed: $e\n$st');
      packages = const [];
      if (mounted) {
        _showSnackBar('Не удалось загрузить тарифы. Попробуйте еще раз.');
      }
    }

    if (!mounted) {
      return;
    }

    safeSetState(() {
      _packagesByProductId = mapSubscriptionPackagesByProductId(packages);
      _isLoadingPackages = false;
    });
  }

  String _priceFor(StudentPayPlan plan) {
    final package = _packagesByProductId[plan.productId];
    if (package != null) {
      return package.storeProduct.priceString;
    }
    return _isLoadingPackages ? 'Загрузка...' : 'Недоступно';
  }

  bool _hasPackageFor(StudentPayPlan plan) =>
      _packagesByProductId.containsKey(plan.productId);

  Future<void> _purchaseSelectedPlan() async {
    if (_isPurchasing || _isLoadingPackages) {
      return;
    }

    Package? package = _selectedPackage;
    if (package == null) {
      await _loadPackages();
      if (!mounted) {
        return;
      }
      package = _selectedPackage;
    }

    if (package == null) {
      _showSnackBar('Покупки пока недоступны. Проверьте продукты RevenueCat.');
      return;
    }

    safeSetState(() {
      _isPurchasing = true;
    });

    try {
      final info = await SubscriptionService.instance.purchasePackage(package);
      if (!mounted || info == null) {
        return;
      }

      final hasPro =
          info.entitlements.active.containsKey(kSubscriptionProEntitlementId);
      if (hasPro) {
        _showSnackBar('Подписка активна.');
        context.safePop();
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('Не удалось оформить подписку. Попробуйте еще раз.');
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
            ? 'Покупки восстановлены.'
            : 'Активных покупок для восстановления не найдено.',
      );
      if (hasPro) {
        context.safePop();
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('Не удалось восстановить покупки. Попробуйте еще раз.');
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
              title: 'Тарифы',
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
            StudentPayBottomBar(
              plan: _selectedPlan,
              price: _priceFor(_selectedPlan),
              canPurchase: _hasPackageFor(_selectedPlan),
              isBusy: _isPurchasing,
              isLoading: _isLoadingPackages,
              onPressed: _hasPackageFor(_selectedPlan)
                  ? _purchaseSelectedPlan
                  : _loadPackages,
            ),
          ],
        ),
      ),
    );
  }
}
