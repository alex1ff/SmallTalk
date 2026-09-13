import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/structs/index.dart';
import 'package:small_talk/students_pages/words/quick_translation_word_enricher.dart';

void main() {
  const enricher = QuickTranslationWordEnricher();

  test('keeps direct translation first and enriches the primary entry', () {
    final result = enricher.merge(
      existingEntries: [
        EntryStruct(
          text: 'hello',
          tr: [TranslationStruct(text: 'привет')],
        ),
      ],
      existingExamples: const <SentenceStruct>[],
      sourceText: 'hello',
      directTranslation: 'привет',
      remoteEntries: [
        EntryStruct(
          text: 'Hello',
          pos: 'noun',
          ts: 'həˈləʊ',
          tr: [
            TranslationStruct(
              text: 'Привет!',
              syn: [SynonymStruct(text: 'здравствуй')],
            ),
            TranslationStruct(text: 'здравствуйте'),
          ],
        ),
      ],
      remoteExamples: [
        SentenceStruct(
          text: 'Hello!',
          lang: 'eng',
          translations: [
            Translation2Struct(text: 'Привет!', lang: 'rus'),
          ],
        ),
      ],
    );

    expect(result.entries, hasLength(1));
    expect(result.entries.single.ts, 'həˈləʊ');
    expect(result.entries.single.pos, 'noun');
    expect(
      result.entries.single.tr.map((translation) => translation.text),
      ['привет', 'здравствуйте'],
    );
    expect(
      result.entries.single.tr.first.syn.single.text,
      'здравствуй',
    );
    expect(result.examples.single.translations.single.text, 'Привет!');
  });

  test('merge is idempotent and upgrades duplicate examples', () {
    final first = enricher.merge(
      existingEntries: [
        EntryStruct(
          text: 'bye',
          tr: [TranslationStruct(text: 'пока')],
        ),
      ],
      existingExamples: [SentenceStruct(text: 'Bye!', lang: 'eng')],
      sourceText: 'bye',
      directTranslation: 'пока',
      remoteEntries: [
        EntryStruct(
          text: 'bye',
          ts: 'baɪ',
          tr: [TranslationStruct(text: 'пока')],
        ),
      ],
      remoteExamples: [
        SentenceStruct(
          text: 'Bye!',
          lang: 'eng',
          translations: [Translation2Struct(text: 'Пока!', lang: 'rus')],
        ),
      ],
    );
    final second = enricher.merge(
      existingEntries: first.entries,
      existingExamples: first.examples,
      sourceText: 'bye',
      directTranslation: 'пока',
      remoteEntries: first.entries,
      remoteExamples: first.examples,
    );

    expect(second.entries, first.entries);
    expect(second.examples, first.examples);
    expect(second.examples.single.translations.single.text, 'Пока!');
  });
}
