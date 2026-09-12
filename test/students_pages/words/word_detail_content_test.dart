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

    test('keeps translation synonyms, current translation, and meanings', () {
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
                ],
                mean: [
                  MeaningStruct(text: 'greeting'),
                ],
              ),
            ],
          ),
        ],
      );

      final group = content.translationGroups.single;
      expect(group.synonyms.map((synonym) => synonym.text), [
        'здравствуй',
        'привет',
      ]);
      expect(group.meanings.map((meaning) => meaning.text), ['greeting']);
    });
  });
}
