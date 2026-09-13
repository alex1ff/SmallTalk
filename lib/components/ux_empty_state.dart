import 'package:flutter/material.dart';

import '/shared_pages/design/expatlio_design.dart';

const String uxDefaultEmptyStateImageAsset =
    'assets/images/Group_1171275321.png';

class UxEmptyState extends StatelessWidget {
  const UxEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.shrinkWrap = false,
    this.topPadding = ExpatlioDesign.space64,
    this.horizontalPadding = ExpatlioDesign.space24,
    this.maxWidth = 360.0,
    this.showImage = true,
    this.imageAsset = uxDefaultEmptyStateImageAsset,
    this.imageSize = 104.0,
    this.titleStyle,
    this.messageStyle,
    this.action,
    this.semanticsLabel,
    this.liveRegion = false,
  });

  final String title;
  final String message;
  final bool shrinkWrap;
  final double topPadding;
  final double horizontalPadding;
  final double maxWidth;
  final bool showImage;
  final String? imageAsset;
  final double imageSize;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final Widget? action;
  final String? semanticsLabel;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final effectiveTitleStyle = titleStyle ??
        ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.text,
          size: 17.0,
          weight: FontWeight.w700,
        );
    final effectiveMessageStyle = messageStyle ??
        ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.muted,
          size: 15.0,
          height: 1.35,
        );
    final summary = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showImage && imageAsset != null) ...[
          SizedBox.square(
            dimension: imageSize,
            child: Image.asset(
              imageAsset!,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(height: ExpatlioDesign.space16),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: effectiveTitleStyle,
        ),
        const SizedBox(height: ExpatlioDesign.space8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: effectiveMessageStyle,
        ),
      ],
    );
    final normalizedSemanticsLabel =
        semanticsLabel == null || semanticsLabel!.trim().isEmpty
            ? null
            : semanticsLabel!.trim();
    final semanticSummary = normalizedSemanticsLabel == null
        ? (liveRegion
            ? Semantics(
                container: true,
                liveRegion: true,
                child: summary,
              )
            : summary)
        : Semantics(
            container: true,
            liveRegion: liveRegion,
            label: normalizedSemanticsLabel,
            child: ExcludeSemantics(child: summary),
          );

    final content = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        ExpatlioDesign.space0,
      ),
      child: Center(
        heightFactor: shrinkWrap ? 1.0 : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
            children: [
              semanticSummary,
              if (action != null) ...[
                const SizedBox(height: ExpatlioDesign.space24),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
    return content;
  }
}
