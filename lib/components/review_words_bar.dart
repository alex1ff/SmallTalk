import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class ReviewWordsBar extends StatelessWidget {
  const ReviewWordsBar({
    super.key,
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final decoration = enabled
        ? BoxDecoration(
            gradient: ExpatlioDesign.primaryGradient,
            borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
            boxShadow: const [
              BoxShadow(
                color: Color(0x302B0B63),
                blurRadius: 20.0,
                offset: Offset(0.0, 8.0),
              ),
            ],
          )
        : BoxDecoration(
            color: ExpatlioDesign.mutedSurface,
            borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
            border: Border.all(color: ExpatlioDesign.border),
          );
    final foregroundColor = enabled ? Colors.white : ExpatlioDesign.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
        onTap: onTap,
        child: Ink(
          height: 60.0,
          decoration: decoration,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space20,
              ExpatlioDesign.space0,
              ExpatlioDesign.space16,
              ExpatlioDesign.space0,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: foregroundColor,
                  size: 21.0,
                ),
                const SizedBox(width: ExpatlioDesign.space16),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ExpatlioDesign.textStyle(
                      context,
                      color: foregroundColor,
                      size: 16.0,
                      weight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                if (enabled) ...[
                  const SizedBox(width: ExpatlioDesign.space12),
                  Container(
                    height: 44.0,
                    constraints: const BoxConstraints(minWidth: 96.0),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius:
                          BorderRadius.circular(ExpatlioDesign.radiusLarge),
                    ),
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space20,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space20,
                      ExpatlioDesign.space0,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      FFLocalizations.of(context).getVariableText(
                        ruText: 'Повторить',
                        enText: 'Review',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: Colors.white,
                        size: 16.0,
                        weight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
