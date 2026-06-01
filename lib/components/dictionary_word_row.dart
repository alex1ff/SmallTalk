import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class DictionaryWordRow extends StatelessWidget {
  const DictionaryWordRow({
    super.key,
    required this.sourceText,
    required this.translationText,
    required this.onTap,
  });

  final String sourceText;
  final String translationText;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final textStyle = ExpatlioDesign.textStyle(
      context,
      size: 16.0,
      weight: FontWeight.w500,
      height: 1.2,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 49.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
            border: Border.all(
              color: ExpatlioDesign.border,
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space16,
              ExpatlioDesign.space8,
              ExpatlioDesign.space16,
              ExpatlioDesign.space8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    sourceText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
                const SizedBox(width: ExpatlioDesign.space24),
                Expanded(
                  flex: 7,
                  child: Text(
                    translationText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
