import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class StudentPayRestorePurchasesButton extends StatelessWidget {
  const StudentPayRestorePurchasesButton({
    super.key,
    required this.isBusy,
    required this.onPressed,
  });

  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isBusy ? null : onPressed,
      child: isBusy
          ? const SizedBox(
              width: 18.0,
              height: 18.0,
              child: CircularProgressIndicator(strokeWidth: 2.0),
            )
          : Text(
              'Восстановить покупки',
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.primary,
                size: 15.0,
                weight: FontWeight.w600,
              ),
            ),
    );
  }
}
