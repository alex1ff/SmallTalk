import 'package:flutter/material.dart';

import '/shared_pages/design/expatlio_design.dart';

class UxErrorState extends StatelessWidget {
  const UxErrorState({
    super.key,
    required this.title,
    required this.message,
    this.stateKey,
    this.semanticsLabel,
    this.liveRegion = true,
    this.explicitChildNodes = true,
    this.onRetry,
    this.retryLabel,
    this.retrySemanticsLabel,
    this.retryButtonKey,
    this.showIcon = true,
    this.icon = Icons.refresh_rounded,
    this.iconSize = 28.0,
    this.iconColor = ExpatlioDesign.danger,
    this.iconBackgroundColor,
    this.contained = false,
    this.borderColor = ExpatlioDesign.border,
    this.padding = const EdgeInsetsDirectional.fromSTEB(
      ExpatlioDesign.space24,
      ExpatlioDesign.space32,
      ExpatlioDesign.space24,
      ExpatlioDesign.space32,
    ),
    this.maxWidth = 360.0,
    this.retryMinWidth = 160.0,
    this.retryMinHeight = 48.0,
    this.titleSize = 20.0,
    this.messageSize = 15.0,
  });

  final String title;
  final String message;
  final Key? stateKey;
  final String? semanticsLabel;
  final bool liveRegion;
  final bool explicitChildNodes;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final String? retrySemanticsLabel;
  final Key? retryButtonKey;
  final bool showIcon;
  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final Color? iconBackgroundColor;
  final bool contained;
  final Color borderColor;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final double retryMinWidth;
  final double retryMinHeight;
  final double titleSize;
  final double messageSize;

  @override
  Widget build(BuildContext context) {
    final normalizedTitle = title.trim();
    final normalizedMessage = message.trim();
    final normalizedSemanticsLabel = semanticsLabel?.trim();
    final effectiveSemanticsLabel =
        normalizedSemanticsLabel == null || normalizedSemanticsLabel.isEmpty
            ? '$normalizedTitle. $normalizedMessage'
            : normalizedSemanticsLabel;
    final normalizedRetryLabel = retryLabel?.trim();
    final canShowRetry =
        normalizedRetryLabel != null && normalizedRetryLabel.isNotEmpty;
    final effectiveRetrySemanticsLabel =
        (retrySemanticsLabel?.trim().isNotEmpty ?? false)
            ? retrySemanticsLabel!.trim()
            : normalizedRetryLabel;

    final content = Container(
      padding: padding,
      decoration: contained
          ? ExpatlioDesign.cardDecoration(borderColor: borderColor)
          : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showIcon) ...[
                    Container(
                      width: 56.0,
                      height: 56.0,
                      decoration: BoxDecoration(
                        color: iconBackgroundColor ??
                            iconColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(
                          ExpatlioDesign.radiusCapsule,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: iconSize,
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space16),
                  ],
                  Text(
                    normalizedTitle,
                    textAlign: TextAlign.center,
                    style: ExpatlioDesign.textStyle(
                      context,
                      size: titleSize,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: ExpatlioDesign.space8),
                  Text(
                    normalizedMessage,
                    textAlign: TextAlign.center,
                    style: ExpatlioDesign.textStyle(
                      context,
                      color: ExpatlioDesign.muted,
                      size: messageSize,
                      height: 1.36,
                    ),
                  ),
                ],
              ),
            ),
            if (canShowRetry) ...[
              const SizedBox(height: ExpatlioDesign.space20),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: retryMinWidth,
                  minHeight: retryMinHeight,
                ),
                child: Semantics(
                  key: retryButtonKey,
                  container: true,
                  button: true,
                  enabled: onRetry != null,
                  label: effectiveRetrySemanticsLabel,
                  onTap: onRetry,
                  child: ExcludeSemantics(
                    child: TextButton.icon(
                      onPressed: onRetry,
                      style: TextButton.styleFrom(
                        minimumSize: Size(retryMinWidth, retryMinHeight),
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: ExpatlioDesign.space16,
                          vertical: ExpatlioDesign.space12,
                        ),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: ExpatlioDesign.muted,
                        backgroundColor: ExpatlioDesign.primary,
                        disabledBackgroundColor:
                            ExpatlioDesign.secondarySystemBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ExpatlioDesign.buttonRadius,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 20.0),
                      label: Text(
                        normalizedRetryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: onRetry == null
                              ? ExpatlioDesign.muted
                              : Colors.white,
                          size: 16.0,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Semantics(
      key: stateKey,
      container: true,
      explicitChildNodes: explicitChildNodes,
      liveRegion: liveRegion,
      label: effectiveSemanticsLabel,
      child: content,
    );
  }
}
