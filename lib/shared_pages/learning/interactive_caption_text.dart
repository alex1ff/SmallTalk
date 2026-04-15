import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'caption_tokenization.dart';

enum InteractiveCaptionTextMode {
  tokenSplit,
  wordScan,
}

class InteractiveCaptionText extends StatefulWidget {
  const InteractiveCaptionText({
    super.key,
    required this.text,
    required this.style,
    required this.onWordTap,
    required this.mode,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.softWrap = true,
  });

  final String text;
  final TextStyle style;
  final Future<void> Function(String word) onWordTap;
  final InteractiveCaptionTextMode mode;
  final int? maxLines;
  final TextOverflow overflow;
  final bool softWrap;

  @override
  State<InteractiveCaptionText> createState() => _InteractiveCaptionTextState();
}

class _InteractiveCaptionTextState extends State<InteractiveCaptionText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  List<InlineSpan> _buildTokenSplitSpans() {
    final spans = <InlineSpan>[];

    for (final token in splitCaptionDisplayTokens(widget.text)) {
      final normalizedWord = normalizeCaptionLookupWord(token);
      if (normalizedWord.isEmpty) {
        spans.add(TextSpan(text: token, style: widget.style));
        continue;
      }

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                unawaited(widget.onWordTap(normalizedWord));
              },
              child: Text(
                token,
                style: widget.style,
              ),
            ),
          ),
        ),
      );
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: widget.text, style: widget.style));
    }

    return spans;
  }

  List<InlineSpan> _buildWordScanSpans() {
    _disposeRecognizers();

    final spans = <InlineSpan>[];
    for (final segment in buildCaptionTapSegments(widget.text)) {
      if (segment.isTappable) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            widget.onWordTap(segment.lookupWord!);
          };
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: segment.text,
            recognizer: recognizer,
          ),
        );
        continue;
      }

      spans.add(TextSpan(text: segment.text));
    }

    return spans;
  }

  List<InlineSpan> _buildSpans() {
    switch (widget.mode) {
      case InteractiveCaptionTextMode.tokenSplit:
        return _buildTokenSplitSpans();
      case InteractiveCaptionTextMode.wordScan:
        return _buildWordScanSpans();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: _buildSpans(),
      ),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      softWrap: widget.softWrap,
    );
  }
}
