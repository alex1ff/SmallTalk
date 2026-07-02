import '/components/student_pay_plan.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class StudentPayBottomBar extends StatelessWidget {
  const StudentPayBottomBar({
    super.key,
    required this.plan,
    required this.price,
    required this.canPurchase,
    required this.isBusy,
    required this.isLoading,
    required this.onPressed,
  });

  final StudentPayPlan plan;
  final String price;
  final bool canPurchase;
  final bool isBusy;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ExpatlioDesign.background,
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520.0),
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(ExpatlioDesign.buttonRadius),
                onTap: isBusy || isLoading ? null : onPressed,
                child: Container(
                  width: double.infinity,
                  height: ExpatlioDesign.buttonHeight,
                  decoration: BoxDecoration(
                    color: ExpatlioDesign.primary,
                    borderRadius:
                        BorderRadius.circular(ExpatlioDesign.buttonRadius),
                  ),
                  alignment: Alignment.center,
                  child: isBusy || isLoading
                      ? const SizedBox(
                          width: 24.0,
                          height: 24.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          canPurchase
                              ? 'Выбрать ${plan.title} · $price/${plan.periodLabel}'
                              : 'Повторить загрузку',
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
        ),
      ),
    );
  }
}
