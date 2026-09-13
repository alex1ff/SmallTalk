import '/shared_pages/design/expatlio_design.dart';
import '/flutter_flow/internationalization.dart';
import 'package:flutter/material.dart';

const studentPayCatalogErrorKey = ValueKey<String>('student_pay_catalog_error');

class StudentPayCatalogError extends StatelessWidget {
  const StudentPayCatalogError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: studentPayCatalogErrorKey,
      width: double.infinity,
      padding: const EdgeInsets.all(ExpatlioDesign.space20),
      decoration: ExpatlioDesign.cardDecoration(
        borderColor: ExpatlioDesign.border,
      ),
      child: Column(
        children: [
          Container(
            width: 44.0,
            height: 44.0,
            decoration: ExpatlioDesign.softPrimaryDecoration(
              radius: ExpatlioDesign.radiusCapsule,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: ExpatlioDesign.primary,
              size: 22.0,
            ),
          ),
          const SizedBox(height: ExpatlioDesign.space12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: ExpatlioDesign.textStyle(
              context,
              color: ExpatlioDesign.muted,
              size: 14.0,
              height: 1.35,
            ),
          ),
          const SizedBox(height: ExpatlioDesign.space12),
          TextButton(
            onPressed: onRetry,
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Повторить загрузку',
                enText: 'Try again',
              ),
              style: ExpatlioDesign.buttonTextStyle(
                context,
                color: ExpatlioDesign.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
