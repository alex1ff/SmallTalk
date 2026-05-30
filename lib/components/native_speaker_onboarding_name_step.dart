import '/components/student_onboarding_name_step.dart';
import 'package:flutter/material.dart';

class NativeSpeakerOnboardingNameStep extends StatelessWidget {
  const NativeSpeakerOnboardingNameStep({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function()? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return StudentOnboardingNameStep(
      controller: controller,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
    );
  }
}
