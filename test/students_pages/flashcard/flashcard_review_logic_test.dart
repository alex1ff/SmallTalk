import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/structs/index.dart';
import 'package:small_talk/students_pages/flashcard/flashcard_review_logic.dart';

void main() {
  group('flashcard review logic', () {
    test('maps stages to directions and intervals', () {
      expect(
        flashcardDirectionForStage(1),
        FlashcardPromptDirection.ruToEn,
      );
      expect(
        flashcardDirectionForStage(2),
        FlashcardPromptDirection.enToRu,
      );
      expect(flashcardIntervalDaysForStage(1), 1);
      expect(flashcardIntervalDaysForStage(4), 14);
      expect(flashcardIntervalDaysForStage(8), 180);
    });

    test('maps failure fallback stages', () {
      expect(flashcardFailureFallbackStage(1), 1);
      expect(flashcardFailureFallbackStage(2), 2);
      expect(flashcardFailureFallbackStage(3), 1);
      expect(flashcardFailureFallbackStage(4), 2);
      expect(flashcardFailureFallbackStage(5), 3);
      expect(flashcardFailureFallbackStage(6), 2);
      expect(flashcardFailureFallbackStage(7), 3);
      expect(flashcardFailureFallbackStage(8), 2);
    });

    test('stage 8 success stays at stage 8', () {
      expect(flashcardSuccessNextStage(8), 8);
    });

    test('schedules next due date at local 00:01', () {
      final dueAt = flashcardDueAtForStage(
        referenceTime: DateTime(2026, 3, 19, 18, 45),
        stage: 4,
      );

      expect(dueAt, DateTime(2026, 4, 2, 0, 1));
    });

    test('backfill initial state uses original addedAt for old words', () {
      final addedAt = DateTime(2026, 3, 1, 10, 30);
      final now = DateTime(2026, 3, 19, 12, 0);

      final state = buildInitialFlashcardReviewState(
        addedAt: addedAt,
        now: now,
      );

      expect(state.stage, 1);
      expect(state.createdAt, addedAt);
      expect(state.updatedAt, now);
      expect(state.dueAt, DateTime(2026, 3, 2, 0, 1));
    });

    test('selects source-language example containing the source word first', () {
      final selected = selectFlashcardExampleSentence(
        sentences: [
          SentenceStruct(text: 'Пример без английского', lang: 'ru'),
          SentenceStruct(text: 'A generic example', lang: 'en'),
          SentenceStruct(text: 'He said hello to everyone.', lang: 'en'),
        ],
        sourceWord: 'hello',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'ru',
      );

      expect(selected?.text, 'He said hello to everyone.');
    });

    test('prefers translated dictionary example over untranslated context sentence',
        () {
      final selected = selectFlashcardExampleSentence(
        sentences: [
          SentenceStruct(
            text: 'I said hello in class yesterday.',
            lang: 'en',
          ),
          SentenceStruct(
            id: 42,
            text: 'He said hello to everyone.',
            lang: 'en',
            translations: [
              Translation2Struct(text: 'Он всем сказал привет.', lang: 'ru'),
            ],
          ),
        ],
        sourceWord: 'hello',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'ru',
      );

      expect(selected?.text, 'He said hello to everyone.');
    });

    test('matches the exact source word instead of a substring inside another word',
        () {
      final selected = selectFlashcardExampleSentence(
        sentences: [
          SentenceStruct(
            text: 'The theater was full.',
            lang: 'en',
          ),
          SentenceStruct(
            text: 'He was late.',
            lang: 'en',
          ),
        ],
        sourceWord: 'he',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'ru',
      );

      expect(selected?.text, 'He was late.');
    });

    test('matches the source word when it appears at the end of the sentence',
        () {
      final selected = selectFlashcardExampleSentence(
        sentences: [
          SentenceStruct(
            text: 'They waved and said hello',
            lang: 'en',
          ),
          SentenceStruct(
            text: 'A generic example sentence.',
            lang: 'en',
          ),
        ],
        sourceWord: 'hello',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'ru',
      );

      expect(selected?.text, 'They waved and said hello');
    });

    test('selects example translation by matching target language, not first', () {
      final translation = selectFlashcardExampleTranslation(
        sentence: SentenceStruct(
          text: 'He said hello to everyone.',
          lang: 'en',
          translations: [
            Translation2Struct(text: 'Le dijo hola a todos.', lang: 'es'),
            Translation2Struct(text: 'Он всем сказал привет.', lang: 'ru'),
          ],
        ),
        targetLanguageCode: 'ru',
      );

      expect(translation?.text, 'Он всем сказал привет.');
    });

    test('resolveFlashcardExample uses existing matching translation', () async {
      final resolved = await resolveFlashcardExample(
        sentences: [
          SentenceStruct(
            text: 'He said hello to everyone.',
            lang: 'en',
            translations: [
              Translation2Struct(text: 'Le dijo hola a todos.', lang: 'es'),
              Translation2Struct(text: 'Он всем сказал привет.', lang: 'ru'),
            ],
          ),
        ],
        sourceWord: 'hello',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'ru',
      );

      expect(resolved.exampleText, 'He said hello to everyone.');
      expect(resolved.exampleTranslation, 'Он всем сказал привет.');
    });

    test('resolveFlashcardExample leaves translation empty when the target is missing',
        () async {
      final resolved = await resolveFlashcardExample(
        sentences: [
          SentenceStruct(
            text: 'He said hello to everyone.',
            lang: 'en',
            translations: [
              Translation2Struct(text: 'Le dijo hola a todos.', lang: 'es'),
            ],
          ),
        ],
        sourceWord: 'hello',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'ru',
      );

      expect(resolved.exampleText, 'He said hello to everyone.');
      expect(resolved.exampleTranslation, isNull);
    });

    test('resolveFlashcardExample leaves translation empty when source and target languages match',
        () async {
      final resolved = await resolveFlashcardExample(
        sentences: [
          SentenceStruct(
            text: 'He said hello to everyone.',
            lang: 'en',
          ),
        ],
        sourceWord: 'hello',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'en',
      );

      expect(resolved.exampleText, 'He said hello to everyone.');
      expect(resolved.exampleTranslation, isNull);
    });

    test('applySourceSynonymsToEntries merges and deduplicates source synonyms',
        () {
      final updatedEntries = applySourceSynonymsToEntries(
        entries: [
          EntryStruct(
            text: 'hello',
            ts: 'həˈləʊ',
            syn: [
              SynonymStruct(text: 'hi'),
            ],
            tr: [
              TranslationStruct(text: 'привет'),
            ],
          ),
        ],
        sourceSynonyms: [
          SynonymStruct(text: 'hi'),
          SynonymStruct(text: 'greetings'),
        ],
      );

      expect(updatedEntries, hasLength(1));
      expect(
        updatedEntries.first.syn.map((item) => item.text).toList(),
        ['hi', 'greetings'],
      );
      expect(updatedEntries.first.tr.first.text, 'привет');
    });
  });
}
