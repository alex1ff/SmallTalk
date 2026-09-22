import 'package:flutter/material.dart';

import '/shared_pages/design/expatlio_design.dart';

class OnboardingCard extends StatelessWidget {
  const OnboardingCard({
    super.key,
    required this.assetPath,
  });

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
      child: ColoredBox(
        color: ExpatlioDesign.card,
        child: Image.asset(
          assetPath,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
