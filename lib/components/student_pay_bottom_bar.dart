import '/components/student_pay_plan.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

const studentPayBottomBarKey = ValueKey<String>('student_pay_bottom_bar');
const studentPayPurchaseCtaKey = ValueKey<String>('student_pay_purchase_cta');
const studentPayPurchaseContentSlotKey =
    ValueKey<String>('student_pay_purchase_content_slot');

class StudentPayBottomBar extends StatelessWidget {
  const StudentPayBottomBar({
    super.key,
    required this.plan,
    required this.price,
    required this.canPurchase,
    required this.isBusy,
    required this.isLoading,
    required this.onPressed,
    required this.termsText,
    required this.retryLabel,
    this.actionLabel,
  });

  final StudentPayPlan plan;
  final String price;
  final bool canPurchase;
  final bool isBusy;
  final bool isLoading;
  final VoidCallback onPressed;
  final String termsText;
  final String retryLabel;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedActionLabel = actionLabel ??
        switch (plan.kind) {
          StudentPayPlanKind.trialMonthly => 'Начать 3 дня бесплатно',
          StudentPayPlanKind.monthly ||
          StudentPayPlanKind.quarterly =>
            'Выбрать ${plan.title} · $price/${plan.periodLabel}',
        };
    return Container(
      key: studentPayBottomBarKey,
      decoration: const BoxDecoration(
        color: ExpatlioDesign.background,
      ),
      foregroundDecoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: ExpatlioDesign.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.pagePadding,
            ExpatlioDesign.space12,
            ExpatlioDesign.pagePadding,
            ExpatlioDesign.space12,
          ),
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius:
                        BorderRadius.circular(ExpatlioDesign.buttonRadius),
                    onTap: isBusy || isLoading ? null : onPressed,
                    child: Container(
                      key: studentPayPurchaseCtaKey,
                      width: double.infinity,
                      height: ExpatlioDesign.buttonHeight,
                      decoration: BoxDecoration(
                        color: isBusy || isLoading
                            ? ExpatlioDesign.primary.withValues(alpha: 0.7)
                            : ExpatlioDesign.primary,
                        borderRadius:
                            BorderRadius.circular(ExpatlioDesign.buttonRadius),
                      ),
                      alignment: Alignment.center,
                      child: SizedBox.expand(
                        key: studentPayPurchaseContentSlotKey,
                        child: Center(
                          child: isBusy || isLoading
                              ? const SizedBox(
                                  width: 24.0,
                                  height: 24.0,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  canPurchase
                                      ? resolvedActionLabel
                                      : retryLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: ExpatlioDesign.buttonTextStyle(
                                    context,
                                    color: ExpatlioDesign.card,
                                  ).copyWith(height: 1.2),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ExpatlioDesign.space8),
                  Text(
                    termsText,
                    textAlign: TextAlign.center,
                    style: ExpatlioDesign.textStyle(
                      context,
                      color: ExpatlioDesign.muted,
                      size: 11.0,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
