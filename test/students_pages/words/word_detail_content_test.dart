import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/structs/index.dart';
import 'package:small_talk/components/word_detail_content.dart';

void main() {
  group('buildWordDetailContent', () {
    test('uses API entries and merges duplicate examples with API translation',
        () {
      final content = buildWordDetailContent(
        savedEntries: [
          EntryStruct(
            text: 'hello',
            tr: [
              TranslationStruct(text: 'привет'),
            ],
          ),
        ],
        savedExamples: [
          SentenceStruct(text: 'Hello!', lang: 'eng'),
        ],
        apiEntries: [
          EntryStruct(
            text: 'hello',
            ts: 'həˈləʊ',
            tr: [
              TranslationStruct(text: 'здравствуйте'),
            ],
          ),
        ],
        apiExamples: [
          SentenceStruct(
            text: 'Hello!',
            lang: 'eng',
            translations: [
              Translation2Struct(text: 'Привет!', lang: 'rus'),
            ],
          ),
        ],
      );

      expect(content.entries.single.tr.single.text, 'здравствуйте');
      expect(content.examples, hasLength(1));
      expect(content.examples.single.translations.single.text, 'Привет!');
    });

    test('shows the primary translation once and deduplicates lower sections',
        () {
      final content = buildWordDetailContent(
        savedEntries: [
          EntryStruct(
            text: 'hello',
            tr: [
              TranslationStruct(
                text: 'привет',
                gen: 'м',
                syn: [
                  SynonymStruct(text: 'здравствуй'),
                  SynonymStruct(text: 'Привет!'),
                ],
                mean: [
                  MeaningStruct(text: 'greeting'),
                  MeaningStruct(text: 'привет'),
                ],
              ),
              TranslationStruct(text: 'Привет.'),
              TranslationStruct(text: 'здравствуйте'),
            ],
          ),
        ],
      );

      expect(content.translationText, 'привет');
      expect(
        content.additionalTranslations.map((value) => value.text),
        ['здравствуйте'],
      );
      expect(
        content.translationSynonyms.map((value) => value.text),
        ['здравствуй'],
      );
      expect(content.meanings, ['greeting']);
    });

    test('uses transcription from a matching enriched entry', () {
      final content = buildWordDetailContent(
        savedEntries: [
          EntryStruct(
            text: 'hello',
            tr: [TranslationStruct(text: 'привет')],
          ),
          EntryStruct(text: 'Hello', ts: 'həˈləʊ'),
        ],
      );

      expect(content.transcription, '/həˈləʊ/');
    });
  });
}
