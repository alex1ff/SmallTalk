import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class DashboardInlineFilterButton extends StatelessWidget {
  const DashboardInlineFilterButton({
    super.key,
    required this.title,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.icon,
    this.menuOpen = false,
    this.onClear,
  });

  final String title;
  final String label;
  final bool selected;
  final bool menuOpen;
  final IconData icon;
  final Future<void> Function(BuildContext context) onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final clearVisible = selected && onClear != null && !menuOpen;
    final hasTitle = title.trim().isNotEmpty;
    final hasLabel = label.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
        onTap: () async => onTap(context),
        child: Container(
          height: 45.0,
          padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.itemSpacing,
            ExpatlioDesign.space0,
            ExpatlioDesign.itemSpacing,
            ExpatlioDesign.space0,
          ),
          decoration: BoxDecoration(
            color: ExpatlioDesign.card,
            borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
            border: Border.all(color: ExpatlioDesign.border),
          ),
          child: Row(
            children: [
              const SizedBox(width: ExpatlioDesign.sectionSpacing),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16.0,
                      color: selected
                          ? ExpatlioDesign.primary
                          : ExpatlioDesign.muted,
                    ),
                    const SizedBox(width: ExpatlioDesign.compactSpacing),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (hasTitle)
                              TextSpan(
                                text: title,
                                style: ExpatlioDesign.textStyle(
                                  context,
                                  color: selected
                                      ? ExpatlioDesign.primary
                                      : ExpatlioDesign.muted,
                                  size: 15.0,
                                  weight: FontWeight.w500,
                                ),
                              ),
                            if (hasTitle && hasLabel)
                              TextSpan(
                                text: ' · ',
                                style: ExpatlioDesign.textStyle(
                                  context,
                                  color: selected
                                      ? ExpatlioDesign.primary
                                      : ExpatlioDesign.muted,
                                  size: 15.0,
                                  weight: FontWeight.w500,
                                ),
                              ),
                            if (hasLabel)
                              TextSpan(
                                text: label,
                                style: ExpatlioDesign.textStyle(
                                  context,
                                  color: selected
                                      ? ExpatlioDesign.primary
                                      : ExpatlioDesign.text,
                                  size: 15.0,
                                  weight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 18.0,
                child: clearVisible
                    ? InkWell(
                        borderRadius:
                            BorderRadius.circular(ExpatlioDesign.radiusSmall),
                        onTap: onClear,
                        child: Icon(
                          Icons.close_rounded,
                          size: 16.0,
                          color: selected
                              ? ExpatlioDesign.primary
                              : ExpatlioDesign.muted,
                        ),
                      )
                    : Icon(
                        menuOpen
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18.0,
                        color: selected
                            ? ExpatlioDesign.primary
                            : ExpatlioDesign.muted,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
