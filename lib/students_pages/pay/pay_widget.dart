import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/basic_page_header.dart';
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

enum _PlanKind { monthly, quarterly }

class _PlanData {
  const _PlanData({
    required this.kind,
    required this.productId,
    required this.title,
    required this.subtitle,
    required this.fallbackPrice,
    required this.periodLabel,
    required this.icon,
    required this.features,
    this.badge,
  });

  final _PlanKind kind;
  final String productId;
  final String title;
  final String subtitle;
  final String fallbackPrice;
  final String periodLabel;
  final IconData icon;
  final List<String> features;
  final String? badge;
}

const _plans = [
  _PlanData(
    kind: _PlanKind.monthly,
    productId: SubscriptionProductIds.monthly,
    title: 'Basic',
    subtitle: 'Для старта изучения языка',
    fallbackPrice: r'$10',
    periodLabel: 'мес',
    icon: FFIcons.kwallet02,
    features: [
      'До 10 звонков в месяц',
      'Базовый словарь',
      'Субтитры в звонках',
    ],
  ),
  _PlanData(
    kind: _PlanKind.quarterly,
    productId: SubscriptionProductIds.quarterly,
    title: 'Pro',
    subtitle: 'Полный доступ ко всем возможностям',
    fallbackPrice: r'$20',
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
  static const _purple = Color(0xFF7430E8);
  static const _blueBorder = Color(0xFF7430E8);
  static const _cardBorder = Color(0xFFEBEBEB);
  static const _selectedBackground = Color(0xFFF3EEFF);
  static const _iconBackground = Color(0xFFF3EEFF);

  late PayModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  _PlanKind _selected = _PlanKind.quarterly;
  Map<String, Package> _packagesByProductId = const {};
  bool _isLoadingPackages = true;
  bool _isPurchasing = false;

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

  _PlanData get _selectedPlan =>
      _plans.firstWhere((plan) => plan.kind == _selected);

  Package? get _selectedPackage =>
      _packagesByProductId[_selectedPlan.productId];

  Future<void> _loadPackages() async {
    if (mounted) {
      safeSetState(() {
        _isLoadingPackages = true;
      });
    }

    final packages = await SubscriptionService.instance
        .fetchSubscriptionPackages()
        .timeout(const Duration(seconds: 20), onTimeout: () => const []);

    if (!mounted) {
      return;
    }

    safeSetState(() {
      _packagesByProductId = {
        for (final package in packages)
          package.storeProduct.identifier: package,
      };
      _isLoadingPackages = false;
    });
  }

  String _priceFor(_PlanData plan) {
    final package = _packagesByProductId[plan.productId];
    return package?.storeProduct.priceString ?? plan.fallbackPrice;
  }

  Future<void> _purchaseSelectedPlan() async {
    if (_isPurchasing) {
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
            _Header(onBack: () => context.safePop()),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(10, 34, 10, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Выберите свой тариф',
                          textAlign: TextAlign.center,
                          style: FlutterFlowTheme.of(context)
                              .headlineMedium
                              .override(
                                fontFamily: 'sf pro display',
                                color: ExpatlioDesign.text,
                                fontSize: 31,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Отмените или измените подписку в любой момент',
                          textAlign: TextAlign.center,
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'sf pro display',
                                    color: ExpatlioDesign.muted,
                                    fontSize: 20,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w400,
                                  ),
                        ),
                        SizedBox(height: 36),
                        for (final plan in _plans) ...[
                          _PlanCard(
                            plan: plan,
                            selected: _selected == plan.kind,
                            price: _priceFor(plan),
                            onTap: () {
                              safeSetState(() {
                                _selected = plan.kind;
                              });
                            },
                          ),
                          if (plan != _plans.last) SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _BottomBar(
              plan: _selectedPlan,
              price: _priceFor(_selectedPlan),
              isBusy: _isPurchasing,
              isLoading: _isLoadingPackages,
              onPressed: _purchaseSelectedPlan,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return BasicPageHeader(
      title: 'Тарифы',
      onBack: onBack,
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.price,
    required this.onTap,
  });

  final _PlanData plan;
  final bool selected;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: double.infinity,
        decoration: BoxDecoration(
          color: selected
              ? _PayWidgetState._selectedBackground
              : ExpatlioDesign.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? _PayWidgetState._blueBorder
                : _PayWidgetState._cardBorder,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(26, 24, 26, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: _PayWidgetState._iconBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  plan.icon,
                  color: _PayWidgetState._purple,
                  size: 32,
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            plan.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FlutterFlowTheme.of(context)
                                .titleMedium
                                .override(
                                  fontFamily: 'sf pro display',
                                  color: ExpatlioDesign.text,
                                  fontSize: 27,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (plan.badge != null) ...[
                          SizedBox(width: 10),
                          Container(
                            padding:
                                EdgeInsetsDirectional.fromSTEB(12, 5, 12, 5),
                            decoration: BoxDecoration(
                              color: _PayWidgetState._purple,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              plan.badge!,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: ExpatlioDesign.card,
                                    fontSize: 14,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      plan.subtitle,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'sf pro display',
                            color: ExpatlioDesign.muted,
                            fontSize: 20,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                    SizedBox(height: 10),
                    RichText(
                      textScaler: MediaQuery.of(context).textScaler,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: price,
                            style: FlutterFlowTheme.of(context)
                                .titleLarge
                                .override(
                                  fontFamily: 'sf pro display',
                                  color: _PayWidgetState._purple,
                                  fontSize: 31,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          TextSpan(
                            text: ' / ${plan.periodLabel}',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'sf pro display',
                                  color: ExpatlioDesign.muted,
                                  fontSize: 24,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 18),
                    for (final feature in plan.features) ...[
                      _FeatureLine(text: feature),
                      if (feature != plan.features.last) SizedBox(height: 13),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 18),
              _SelectionIndicator(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: _PayWidgetState._purple,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          color: ExpatlioDesign.card,
          size: 27,
        ),
      );
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: ExpatlioDesign.card,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFE6E6E6),
          width: 2,
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_rounded,
          color: _PayWidgetState._purple,
          size: 23,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  color: ExpatlioDesign.text,
                  fontSize: 20,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w400,
                  lineHeight: 1.25,
                ),
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.plan,
    required this.price,
    required this.isBusy,
    required this.isLoading,
    required this.onPressed,
  });

  final _PlanData plan;
  final String price;
  final bool isBusy;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(10, 20, 10, 12),
        decoration: const BoxDecoration(
          color: ExpatlioDesign.card,
          border: Border(
            top: BorderSide(color: ExpatlioDesign.border),
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: isBusy ? null : onPressed,
              child: Container(
                width: double.infinity,
                height: 78,
                decoration: BoxDecoration(
                  color: _PayWidgetState._purple,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: isBusy || isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Выбрать ${plan.title} · $price/${plan.periodLabel}',
                        textAlign: TextAlign.center,
                        style:
                            FlutterFlowTheme.of(context).titleMedium.override(
                                  fontFamily: 'sf pro display',
                                  color: ExpatlioDesign.card,
                                  fontSize: 24,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
