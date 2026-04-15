import 'package:flutter/foundation.dart';

@immutable
class CaptionTapSegment {
  const CaptionTapSegment({
    required this.text,
    this.lookupWord,
  });

  final String text;
  final String? lookupWord;

  bool get isTappable => lookupWord != null && lookupWord!.isNotEmpty;
}

final RegExp _captionWordPattern = RegExp(
  r"[A-Za-zА-Яа-яЁёÀ-ÖØ-öø-ÿ0-9]+(?:['’`-][A-Za-zА-Яа-яЁёÀ-ÖØ-öø-ÿ0-9]+)*",
);

List<String> splitCaptionDisplayTokens(String text) {
  return RegExp(r'\s+|[^\s]+')
      .allMatches(text)
      .map((match) => match.group(0) ?? '')
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

String normalizeCaptionLookupWord(String rawToken) {
  final trimmedToken = rawToken.trim();
  if (trimmedToken.isEmpty) {
    return '';
  }

  final runes = trimmedToken.runes.toList(growable: false);
  var start = 0;
  var end = runes.length - 1;

  while (start <= end && !_isCaptionLookupRune(runes[start])) {
    start += 1;
  }
  while (end >= start && !_isCaptionLookupRune(runes[end])) {
    end -= 1;
  }

  if (start > end) {
    return '';
  }

  return String.fromCharCodes(runes.sublist(start, end + 1));
}

List<CaptionTapSegment> buildCaptionTapSegments(String text) {
  final segments = <CaptionTapSegment>[];
  var currentIndex = 0;
  final matches = _captionWordPattern.allMatches(text);

  for (final match in matches) {
    if (match.start > currentIndex) {
      segments.add(
        CaptionTapSegment(
          text: text.substring(currentIndex, match.start),
        ),
      );
    }

    final word = match.group(0) ?? '';
    final normalizedWord = normalizeCaptionLookupWord(word);
    segments.add(
      CaptionTapSegment(
        text: word,
        lookupWord: normalizedWord.isNotEmpty ? normalizedWord : null,
      ),
    );
    currentIndex = match.end;
  }

  if (currentIndex < text.length) {
    segments.add(
      CaptionTapSegment(
        text: text.substring(currentIndex),
      ),
    );
  }

  if (segments.isEmpty) {
    segments.add(CaptionTapSegment(text: text));
  }

  return segments;
}

bool _isCaptionLookupRune(int rune) {
  final character = String.fromCharCode(rune);
  return RegExp(r'[0-9A-Za-z\u00C0-\u024F\u0400-\u04FF]').hasMatch(character);
}
