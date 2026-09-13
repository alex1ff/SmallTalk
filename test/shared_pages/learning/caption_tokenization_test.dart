import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/shared_pages/learning/caption_word_flow.dart';
import 'package:small_talk/shared_pages/learning/caption_tokenization.dart';
import 'package:small_talk/components/interactive_caption_text.dart';
import 'package:small_talk/components/new_word_widget.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('splitCaptionDisplayTokens', () {
    test('preserves whitespace and punctuation-bound tokens', () {
      expect(
        splitCaptionDisplayTokens(' Hello,   world! '),
        const [' ', 'Hello,', '   ', 'world!', ' '],
      );
    });
  });

  group('normalizeCaptionLookupWord', () {
    test('strips edge punctuation and keeps internal apostrophes/hyphens', () {
      expect(normalizeCaptionLookupWord('“rock-n-roll!”'), 'rock-n-roll');
      expect(normalizeCaptionLookupWord("l'amour"), "l'amour");
      expect(normalizeCaptionLookupWord('...'), isEmpty);
    });

    test('supports cyrillic and accented latin text', () {
      expect(normalizeCaptionLookupWord('«Привет!»'), 'Привет');
      expect(normalizeCaptionLookupWord('déjà-vu,'), 'déjà-vu');
    });
  });

  group('buildCaptionTapSegments', () {
    test('preserves punctuation while marking only words tappable', () {
      final segments = buildCaptionTapSegments('Привет, world!');

      expect(
        segments.map((segment) => (segment.text, segment.lookupWord)).toList(),
        const [
          ('Привет', 'Привет'),
          (', ', null),
          ('world', 'world'),
          ('!', null),
        ],
      );
    });

    test('returns a single untappable segment for punctuation-only text', () {
      final segments = buildCaptionTapSegments('…?!');

      expect(segments.length, 1);
      expect(segments.single.text, '…?!');
      expect(segments.single.lookupWord, isNull);
    });
  });

  group('InteractiveCaptionText', () {
    testWidgets('tokenSplit mode emits normalized word on tap', (tester) async {
      String? tappedWord;

      await tester.pumpWidget(
        _buildTestApp(
          InteractiveCaptionText(
            text: '“hello!”',
            mode: InteractiveCaptionTextMode.tokenSplit,
            onWordTap: (word) async {
              tappedWord = word;
            },
          ),
        ),
      );

      await tester.tap(find.text('“hello!”'));
      await tester.pump();

      expect(tappedWord, 'hello');
    });

    testWidgets('wordScan mode emits tapped word on tap', (tester) async {
      String? tappedWord;

      await tester.pumpWidget(
        _buildTestApp(
          InteractiveCaptionText(
            text: 'hello',
            mode: InteractiveCaptionTextMode.wordScan,
            onWordTap: (word) async {
              tappedWord = word;
            },
          ),
        ),
      );

      await tester.tap(find.text('hello'));
      await tester.pump();

      expect(tappedWord, 'hello');
    });
  });

  group('caption word flow builders', () {
    test('live caption sheet builds NewWordWidget with runtime payload', () {
      final widget = buildLiveCaptionWordSheet(
        word: 'hello',
        languageCode: 'en',
        sentence: 'hello world',
        contextText: 'hello world',
      ) as NewWordWidget;

      expect(widget.word, 'hello');
      expect(widget.langCode, 'en');
      expect(widget.sentence, 'hello world');
      expect(widget.contextText, 'hello world');
    });

    test('saved caption sheet builds NewWordWidget for new words', () {
      final widget = buildSavedCaptionWordSheet(
        existingWord: null,
        word: 'bonjour',
        languageCode: 'fr',
        sentence: 'bonjour le monde',
      ) as NewWordWidget;

      expect(widget.word, 'bonjour');
      expect(widget.langCode, 'fr');
      expect(widget.sentence, 'bonjour le monde');
      expect(widget.contextText, isNull);
    });
  });
}
