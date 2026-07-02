import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class OnboardingDropdownField extends StatelessWidget {
  const OnboardingDropdownField({
    super.key,
    required this.value,
    required this.icon,
    required this.onTap,
    this.placeholder = false,
    this.menuOpen = false,
  });

  final String value;
  final IconData icon;
  final Future<void> Function(BuildContext context) onTap;
  final bool placeholder;
  final bool menuOpen;

  @override
  Widget build(BuildContext context) {
    final active = !placeholder || menuOpen;
    final foreground = placeholder ? ExpatlioDesign.muted : ExpatlioDesign.text;
    final accent = active ? ExpatlioDesign.primary : ExpatlioDesign.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
        onTap: () async => onTap(context),
        child: Container(
          height: ExpatlioDesign.formFieldHeight,
          decoration: BoxDecoration(
            color: menuOpen
                ? ExpatlioDesign.card
                : active
                    ? ExpatlioDesign.primary.withValues(alpha: 0.08)
                    : ExpatlioDesign.mutedSurface,
            borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
            border: Border.all(color: ExpatlioDesign.border),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space16,
              ExpatlioDesign.space0,
              ExpatlioDesign.space12,
              ExpatlioDesign.space0),
          child: Row(
            children: [
              Icon(icon, size: 17.0, color: accent),
              const SizedBox(width: ExpatlioDesign.space8),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: foreground,
                    size: 15.0,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: ExpatlioDesign.space8),
              Icon(
                menuOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: accent,
                size: 20.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
