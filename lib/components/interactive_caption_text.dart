import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/learning/caption_tokenization.dart';

enum InteractiveCaptionTextMode {
  tokenSplit,
  wordScan,
}

enum InteractiveCaptionTextTone {
  captionLog,
  overlayLocal,
  overlayRemote,
}

class InteractiveCaptionText extends StatefulWidget {
  const InteractiveCaptionText({
    super.key,
    required this.text,
    required this.mode,
    this.onWordTap,
    this.tone = InteractiveCaptionTextTone.captionLog,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.softWrap = true,
  });

  final String text;
  final InteractiveCaptionTextMode mode;
  final Future<void> Function(String word)? onWordTap;
  final InteractiveCaptionTextTone tone;
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

  TextStyle _textStyle(BuildContext context) {
    return switch (widget.tone) {
      InteractiveCaptionTextTone.captionLog => FlutterFlowTheme.of(context)
          .bodyMedium
          .override(
            fontFamily: ExpatlioDesign.fontFamily,
            fontSize: 15.0,
            letterSpacing: 0.0,
          )
          .copyWith(height: 1.35),
      InteractiveCaptionTextTone.overlayLocal => TextStyle(
          color: Colors.white,
          fontSize: 18.0,
          height: 1.18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.0,
          shadows: _overlayTextShadows,
        ),
      InteractiveCaptionTextTone.overlayRemote => TextStyle(
          color: const Color(0xFFF9F3FF),
          fontSize: 18.0,
          height: 1.18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.0,
          shadows: _overlayTextShadows,
        ),
    };
  }

  static final _overlayTextShadows = [
    Shadow(
      offset: const Offset(0.0, 1.0),
      blurRadius: 4.0,
      color: Colors.black.withValues(alpha: 0.52),
    ),
  ];

  List<InlineSpan> _buildTokenSplitSpans(TextStyle style) {
    final spans = <InlineSpan>[];
    final onWordTap = widget.onWordTap;

    for (final token in splitCaptionDisplayTokens(widget.text)) {
      final normalizedWord = normalizeCaptionLookupWord(token);
      if (normalizedWord.isEmpty || onWordTap == null) {
        spans.add(TextSpan(text: token, style: style));
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
                unawaited(onWordTap(normalizedWord));
              },
              child: Text(
                token,
                style: style,
              ),
            ),
          ),
        ),
      );
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: widget.text, style: style));
    }

    return spans;
  }

  List<InlineSpan> _buildWordScanSpans() {
    _disposeRecognizers();

    final spans = <InlineSpan>[];
    final onWordTap = widget.onWordTap;
    for (final segment in buildCaptionTapSegments(widget.text)) {
      if (segment.isTappable && onWordTap != null) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            unawaited(onWordTap(segment.lookupWord!));
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

  List<InlineSpan> _buildSpans(TextStyle style) {
    switch (widget.mode) {
      case InteractiveCaptionTextMode.tokenSplit:
        return _buildTokenSplitSpans(style);
      case InteractiveCaptionTextMode.wordScan:
        return _buildWordScanSpans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _textStyle(context);

    return Text.rich(
      TextSpan(
        style: style,
        children: _buildSpans(style),
      ),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      softWrap: widget.softWrap,
    );
  }
}
