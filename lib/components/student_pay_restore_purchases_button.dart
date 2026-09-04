import '/shared_pages/design/expatlio_design.dart';
import '/flutter_flow/internationalization.dart';
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
    final label = Text(
      FFLocalizations.of(context).getVariableText(
        ruText: 'Восстановить покупки',
        enText: 'Restore purchases',
      ),
      style: ExpatlioDesign.buttonTextStyle(
        context,
        color: ExpatlioDesign.primary,
      ),
    );
    return TextButton(
      onPressed: isBusy ? null : onPressed,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Visibility(
            visible: !isBusy,
            maintainAnimation: true,
            maintainSize: true,
            maintainState: true,
            child: label,
          ),
          if (isBusy)
            const SizedBox(
              width: 18.0,
              height: 18.0,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
              ),
            ),
        ],
      ),
    );
  }
}
