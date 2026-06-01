import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';

class BasicPageHeader extends StatelessWidget {
  const BasicPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.showBackButton = true,
    this.trailing,
  });

  static const double height = ExpatlioDesign.pageHeaderHeight;

  final String title;
  final VoidCallback? onBack;
  final bool showBackButton;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ExpatlioDesign.background,
        border: const Border(
          bottom: BorderSide(color: ExpatlioDesign.border, width: 1.0),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (showBackButton)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: ExpatlioDesign.compactSpacing,
                    ),
                    child: IconButton(
                      onPressed: onBack ?? () => context.safePop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: ExpatlioDesign.text,
                        size: 24.0,
                      ),
                      splashRadius: 22.0,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.pagePadding * ExpatlioDesign.space8,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.pagePadding * ExpatlioDesign.space8,
                  ExpatlioDesign.space0,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: ExpatlioDesign.pageHeaderTitleStyle(context),
                  ),
                ),
              ),
              if (trailing != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: ExpatlioDesign.compactSpacing,
                    ),
                    child: trailing,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
