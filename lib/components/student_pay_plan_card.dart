import '/components/student_pay_plan.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class StudentPayPlanCard extends StatelessWidget {
  const StudentPayPlanCard({
    super.key,
    required this.plan,
    required this.selected,
    required this.price,
    required this.priceAvailable,
    required this.onTap,
  });

  final StudentPayPlan plan;
  final bool selected;
  final String price;
  final bool priceAvailable;
  final VoidCallback onTap;

  static const _selectedBackground = Color(0xFFF3EEFF);
  static const _cardBorder = ExpatlioDesign.border;
  static const _unselectedIndicatorBorder = ExpatlioDesign.border;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: double.infinity,
        decoration: BoxDecoration(
          color: selected ? _selectedBackground : ExpatlioDesign.card,
          borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
          border: Border.all(
            color: _cardBorder,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10.0,
              offset: const Offset(0.0, 3.0),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(ExpatlioDesign.space16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StudentPayPlanIcon(icon: plan.icon),
              const SizedBox(width: ExpatlioDesign.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StudentPayPlanTitle(plan: plan),
                    const SizedBox(height: ExpatlioDesign.space4),
                    Text(
                      plan.subtitle,
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: ExpatlioDesign.muted,
                        size: 14.0,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space8),
                    _StudentPayPriceLine(
                      price: price,
                      periodLabel: plan.periodLabel,
                      priceAvailable: priceAvailable,
                    ),
                    const SizedBox(height: ExpatlioDesign.space16),
                    for (final feature in plan.features) ...[
                      _StudentPayFeatureLine(text: feature),
                      if (feature != plan.features.last)
                        const SizedBox(height: ExpatlioDesign.space8),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: ExpatlioDesign.space12),
              _StudentPaySelectionIndicator(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentPayPlanIcon extends StatelessWidget {
  const _StudentPayPlanIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52.0,
      height: 52.0,
      decoration: BoxDecoration(
        color: StudentPayPlanCard._selectedBackground,
        borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
      ),
      child: Icon(
        icon,
        color: ExpatlioDesign.primary,
        size: 25.0,
      ),
    );
  }
}

class _StudentPayPlanTitle extends StatelessWidget {
  const _StudentPayPlanTitle({required this.plan});

  final StudentPayPlan plan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            plan.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExpatlioDesign.textStyle(
              context,
              size: 20.0,
              weight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        if (plan.badge != null) ...[
          const SizedBox(width: ExpatlioDesign.space8),
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space8,
                ExpatlioDesign.space4,
                ExpatlioDesign.space8,
                ExpatlioDesign.space4),
            decoration: BoxDecoration(
              color: ExpatlioDesign.primary,
              borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
            ),
            child: Text(
              plan.badge!,
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.card,
                size: 10.0,
                weight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StudentPayPriceLine extends StatelessWidget {
  const _StudentPayPriceLine({
    required this.price,
    required this.periodLabel,
    required this.priceAvailable,
  });

  final String price;
  final String periodLabel;
  final bool priceAvailable;

  @override
  Widget build(BuildContext context) {
    if (!priceAvailable) {
      return Text(
        price,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.muted,
          size: 15.0,
          weight: FontWeight.w600,
        ),
      );
    }

    return RichText(
      textScaler: MediaQuery.of(context).textScaler,
      text: TextSpan(
        children: [
          TextSpan(
            text: price,
            style: ExpatlioDesign.textStyle(
              context,
              color: ExpatlioDesign.primary,
              size: 24.0,
              weight: FontWeight.w800,
              height: 1.18,
            ),
          ),
          TextSpan(
            text: ' / $periodLabel',
            style: ExpatlioDesign.textStyle(
              context,
              color: ExpatlioDesign.muted,
              size: 16.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentPayFeatureLine extends StatelessWidget {
  const _StudentPayFeatureLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_rounded,
          color: ExpatlioDesign.primary,
          size: 18.0,
        ),
        const SizedBox(width: ExpatlioDesign.space8),
        Expanded(
          child: Text(
            text,
            style: ExpatlioDesign.textStyle(
              context,
              size: 15.0,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentPaySelectionIndicator extends StatelessWidget {
  const _StudentPaySelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 28.0,
        height: 28.0,
        decoration: const BoxDecoration(
          color: ExpatlioDesign.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          color: ExpatlioDesign.card,
          size: 19.0,
        ),
      );
    }

    return Container(
      width: 28.0,
      height: 28.0,
      decoration: BoxDecoration(
        color: ExpatlioDesign.card,
        shape: BoxShape.circle,
        border: Border.all(
          color: StudentPayPlanCard._unselectedIndicatorBorder,
          width: 1.5,
        ),
      ),
    );
  }
}
