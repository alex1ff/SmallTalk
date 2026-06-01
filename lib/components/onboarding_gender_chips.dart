import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class OnboardingGenderChips extends StatelessWidget {
  const OnboardingGenderChips({
    super.key,
    required this.genderMale,
    required this.onChanged,
  });

  final bool genderMale;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey<String>('student_onboarding_gender_selector'),
      children: [
        Expanded(
          child: _OnboardingGenderChip(
            key: const ValueKey<String>('student_onboarding_gender_male'),
            title: FFLocalizations.of(context).getVariableText(
              ruText: 'Мужчина',
              enText: 'Male',
            ),
            icon: Icons.male_rounded,
            selected: genderMale,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: ExpatlioDesign.space8),
        Expanded(
          child: _OnboardingGenderChip(
            key: const ValueKey<String>('student_onboarding_gender_female'),
            title: FFLocalizations.of(context).getVariableText(
              ruText: 'Женщина',
              enText: 'Female',
            ),
            icon: Icons.female_rounded,
            selected: !genderMale,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _OnboardingGenderChip extends StatelessWidget {
  const _OnboardingGenderChip({
    super.key,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : ExpatlioDesign.text;
    final decoration = selected
        ? BoxDecoration(
            color: ExpatlioDesign.primary,
            borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
          )
        : ExpatlioDesign.cardDecoration(
            color: ExpatlioDesign.mutedSurface,
            radius: ExpatlioDesign.controlRadius,
          );

    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
      onTap: onTap,
      child: Container(
        height: ExpatlioDesign.formFieldHeight,
        decoration: decoration,
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ExpatlioDesign.space12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground, size: 19.0),
            const SizedBox(width: ExpatlioDesign.space8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  color: foreground,
                  size: 15.0,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
