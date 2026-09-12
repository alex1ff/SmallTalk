import '/components/student_pay_plan.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

const double studentPayPriceSlotBaseHeight = 28.0;

ValueKey<String> studentPayPlanCardKey(StudentPayPlanKind kind) =>
    ValueKey<String>('student_pay_plan_card_${kind.name}');

ValueKey<String> studentPayPlanIconSlotKey(StudentPayPlanKind kind) =>
    ValueKey<String>('student_pay_plan_icon_slot_${kind.name}');

ValueKey<String> studentPayPlanPriceSlotKey(StudentPayPlanKind kind) =>
    ValueKey<String>('student_pay_plan_price_slot_${kind.name}');

ValueKey<String> studentPayPlanSelectionSlotKey(StudentPayPlanKind kind) =>
    ValueKey<String>('student_pay_plan_selection_slot_${kind.name}');

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

  static const _selectedBackground = Color(0xFFF7F3FF);
  static const _cardBorder = ExpatlioDesign.border;
  static const _unselectedIndicatorBorder = ExpatlioDesign.border;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: priceAvailable,
      label: '${plan.title}, $price',
      child: InkWell(
        borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
        onTap: onTap,
        child: AnimatedContainer(
          key: studentPayPlanCardKey(plan.kind),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: double.infinity,
          decoration: BoxDecoration(
            color: selected ? _selectedBackground : ExpatlioDesign.card,
            borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10.0,
                offset: const Offset(0.0, 3.0),
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
            border: Border.all(
              color: _cardBorder,
              width: selected ? 2.0 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space16,
              ExpatlioDesign.space16,
              ExpatlioDesign.space16,
              ExpatlioDesign.space16,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _StudentPaySelectionIndicator(
                  kind: plan.kind,
                  selected: selected,
                ),
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
                      const SizedBox(height: ExpatlioDesign.space4),
                      _StudentPayPriceLine(
                        kind: plan.kind,
                        price: price,
                        periodLabel: plan.periodLabel,
                        priceAvailable: priceAvailable,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
        Expanded(
          child: Text(
            plan.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExpatlioDesign.textStyle(
              context,
              size: 18.0,
              weight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        if (plan.badge != null) ...[
          const SizedBox(width: ExpatlioDesign.space8),
          Flexible(
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space8,
                  ExpatlioDesign.space4,
                  ExpatlioDesign.space8,
                  ExpatlioDesign.space4),
              decoration: BoxDecoration(
                color: ExpatlioDesign.primary,
                borderRadius:
                    BorderRadius.circular(ExpatlioDesign.radiusMedium),
              ),
              child: Text(
                plan.badge!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  color: ExpatlioDesign.card,
                  size: 9.5,
                  weight: FontWeight.w700,
                  height: 1.2,
                ),
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
    required this.kind,
    required this.price,
    required this.periodLabel,
    required this.priceAvailable,
  });

  final StudentPayPlanKind kind;
  final String price;
  final String periodLabel;
  final bool priceAvailable;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: studentPayPlanPriceSlotKey(kind),
      height: MediaQuery.textScalerOf(context).scale(
        studentPayPriceSlotBaseHeight,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: priceAvailable
            ? RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: MediaQuery.of(context).textScaler,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: price,
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: ExpatlioDesign.primary,
                        size: 20.0,
                        weight: FontWeight.w700,
                        height: 1.18,
                      ),
                    ),
                    TextSpan(
                      text: ' / $periodLabel',
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: ExpatlioDesign.muted,
                        size: 14.0,
                      ),
                    ),
                  ],
                ),
              )
            : Text(
                price,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  color: ExpatlioDesign.muted,
                  size: 15.0,
                  weight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _StudentPaySelectionIndicator extends StatelessWidget {
  const _StudentPaySelectionIndicator({
    required this.kind,
    required this.selected,
  });

  final StudentPayPlanKind kind;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        key: studentPayPlanSelectionSlotKey(kind),
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
      key: studentPayPlanSelectionSlotKey(kind),
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
