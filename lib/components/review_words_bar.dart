import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

const double reviewWordsBarHeight = 60.0;
const double reviewWordsBarActionHeight = 44.0;
const double reviewWordsBarActionWidth = 116.0;
const ValueKey<String> reviewWordsBarSurfaceKey =
    ValueKey<String>('review_words_bar_surface');
const ValueKey<String> reviewWordsBarCountTextKey =
    ValueKey<String>('review_words_bar_count_text');
const ValueKey<String> reviewWordsBarCountSlotKey =
    ValueKey<String>('review_words_bar_count_slot');
const ValueKey<String> reviewWordsBarActionKey =
    ValueKey<String>('review_words_bar_action');
const double _reviewWordsBarMaxTextScaleFactor = 2.0;
const double _reviewWordsBarCompactBreakpoint = 272.0;

String reviewWordsVisibleCount(int count) {
  final normalizedCount = count < 0 ? 0 : count;
  return normalizedCount > 99 ? '99+' : normalizedCount.toString();
}

String _russianWordsForm(int count) {
  final mod100 = count % 100;
  final mod10 = count % 10;
  return mod100 >= 11 && mod100 <= 14
      ? 'слов'
      : mod10 == 1
          ? 'слово'
          : mod10 >= 2 && mod10 <= 4
              ? 'слова'
              : 'слов';
}

String reviewWordsVisibleLabel({
  required int count,
  required String languageCode,
}) {
  final normalizedCount = count < 0 ? 0 : count;
  final visibleCount = reviewWordsVisibleCount(normalizedCount);
  if (languageCode.startsWith('en')) {
    return '$visibleCount ${normalizedCount == 1 ? 'word' : 'words'}';
  }

  final wordForm =
      normalizedCount > 99 ? 'слов' : _russianWordsForm(normalizedCount);
  return '$visibleCount $wordForm';
}

String reviewWordsCountSemanticsLabel({
  required int count,
  required String languageCode,
}) {
  final normalizedCount = count < 0 ? 0 : count;
  if (languageCode.startsWith('en')) {
    return '$normalizedCount '
        '${normalizedCount == 1 ? 'word' : 'words'} to review';
  }

  return '$normalizedCount ${_russianWordsForm(normalizedCount)} '
      'к повторению';
}

class ReviewWordsBar extends StatelessWidget {
  const ReviewWordsBar({
    super.key,
    required this.text,
    required this.semanticsLabel,
    required this.onTap,
  });

  final String text;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final textScaler = MediaQuery.textScalerOf(context).clamp(
      minScaleFactor: 1.0,
      maxScaleFactor: _reviewWordsBarMaxTextScaleFactor,
    );
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactLayout =
            constraints.maxWidth < _reviewWordsBarCompactBreakpoint;
        return SizedBox(
          key: reviewWordsBarSurfaceKey,
          height: reviewWordsBarHeight,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
              onTap: onTap,
              child: Ink(
                decoration: decoration,
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    useCompactLayout
                        ? ExpatlioDesign.space8
                        : ExpatlioDesign.space20,
                    ExpatlioDesign.space0,
                    useCompactLayout
                        ? ExpatlioDesign.space8
                        : ExpatlioDesign.space16,
                    ExpatlioDesign.space0,
                  ),
                  child: Row(
                    children: [
                      if (!useCompactLayout) ...[
                        Icon(
                          Icons.auto_awesome_outlined,
                          color: foregroundColor,
                          size: 21.0,
                        ),
                        const SizedBox(width: ExpatlioDesign.space16),
                      ],
                      Expanded(
                        child: Align(
                          key: reviewWordsBarCountSlotKey,
                          alignment: AlignmentDirectional.centerStart,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              text,
                              key: reviewWordsBarCountTextKey,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              semanticsLabel: semanticsLabel,
                              textScaler: textScaler,
                              style: ExpatlioDesign.textStyle(
                                context,
                                color: foregroundColor,
                                size: 16.0,
                                weight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (enabled) ...[
                        SizedBox(
                          width: useCompactLayout
                              ? ExpatlioDesign.space8
                              : ExpatlioDesign.space12,
                        ),
                        Container(
                          key: reviewWordsBarActionKey,
                          width: reviewWordsBarActionWidth,
                          height: reviewWordsBarActionHeight,
                          decoration: BoxDecoration(
                            color: const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(
                              ExpatlioDesign.radiusLarge,
                            ),
                          ),
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            ExpatlioDesign.space16,
                            ExpatlioDesign.space0,
                            ExpatlioDesign.space16,
                            ExpatlioDesign.space0,
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              FFLocalizations.of(context).getVariableText(
                                ruText: 'Повторить',
                                enText: 'Review',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: textScaler,
                              style: ExpatlioDesign.textStyle(
                                context,
                                color: Colors.white,
                                size: 16.0,
                                weight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
