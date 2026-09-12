import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

const double dictionaryWordRowHeight = ExpatlioDesign.space56;
const ValueKey<String> dictionaryWordSourceTextKey =
    ValueKey<String>('dictionary_word_source_text');
const ValueKey<String> dictionaryWordTranslationTextKey =
    ValueKey<String>('dictionary_word_translation_text');
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
    final sourceTextStyle = ExpatlioDesign.textStyle(
      context,
      size: _dictionaryWordFontSize,
      weight: FontWeight.w600,
      height: _dictionaryWordTextHeight,
    );
    final translationTextStyle = ExpatlioDesign.textStyle(
      context,
      size: _dictionaryWordFontSize,
      weight: FontWeight.w400,
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
            child: Semantics(
              label: '$sourceText\n$translationText',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      sourceText,
                      key: dictionaryWordSourceTextKey,
                      maxLines: visibleLines,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      textScaler: textScaler,
                      style: sourceTextStyle,
                    ),
                  ),
                  const SizedBox(
                    width: ExpatlioDesign.space24,
                    height: ExpatlioDesign.space24,
                    child: VerticalDivider(
                      width: ExpatlioDesign.space24,
                      thickness: 1.0,
                      color: ExpatlioDesign.border,
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: Text(
                      translationText,
                      key: dictionaryWordTranslationTextKey,
                      maxLines: visibleLines,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      textScaler: textScaler,
                      style: translationTextStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
