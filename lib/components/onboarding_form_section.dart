import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class OnboardingFormSection extends StatelessWidget {
  const OnboardingFormSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
              start: ExpatlioDesign.space4, bottom: ExpatlioDesign.space8),
          child: Text(
            title,
            style: ExpatlioDesign.formLabelStyle(context),
          ),
        ),
        child,
      ],
    );
  }
}
