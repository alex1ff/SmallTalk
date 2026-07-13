import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

const double dictionaryWordRowHeight = ExpatlioDesign.space56;
const double _dictionaryWordFontSize = 16.0;
const double _dictionaryWordTextHeight = 1.2;
const double _dictionaryWordMaxTextScaleFactor = 2.0;
const int _dictionaryWordMaxLines = 2;
const double _dictionaryWordTextSlotHeight =
    dictionaryWordRowHeight - (ExpatlioDesign.space8 * 2);

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
    final textScaler = MediaQuery.textScalerOf(context).clamp(
      minScaleFactor: 1.0,
      maxScaleFactor: _dictionaryWordMaxTextScaleFactor,
    );
    final scaledLineHeight =
        textScaler.scale(_dictionaryWordFontSize) * _dictionaryWordTextHeight;
    final visibleLines = (_dictionaryWordTextSlotHeight / scaledLineHeight)
        .floor()
        .clamp(1, _dictionaryWordMaxLines);
    final textStyle = ExpatlioDesign.textStyle(
      context,
      size: _dictionaryWordFontSize,
      weight: FontWeight.w500,
      height: _dictionaryWordTextHeight,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: dictionaryWordRowHeight,
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
                    maxLines: visibleLines,
                    overflow: TextOverflow.ellipsis,
                    textScaler: textScaler,
                    style: textStyle,
                  ),
                ),
                const SizedBox(width: ExpatlioDesign.space24),
                Expanded(
                  flex: 7,
                  child: Text(
                    translationText,
                    maxLines: visibleLines,
                    overflow: TextOverflow.ellipsis,
                    textScaler: textScaler,
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
