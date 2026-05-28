import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/structs/index.dart';
import 'package:small_talk/students_pages/words/word_lookup_service.dart';

void main() {
  const languageConfig = WordLookupLanguageConfig(
    sourceLanguageCode: 'en',
    yandexSourceLanguageCode: 'en',
    yandexTranslationLanguageCode: 'ru',
    tatoebaSourceLanguageCode: 'eng',
    tatoebaTranslationLanguageCode: 'rus',
  );

  tearDown(WordLookupService.clearMemoryCacheForTests);

  test('returns saved word content without calling API fetchers', () async {
    var entryFetchCount = 0;
    var exampleFetchCount = 0;

    final result = await WordLookupService.resolve(
      word: 'Hello',
      languageConfig: languageConfig,
      savedContents: [
        WordLookupSavedContent(
          entries: [
            EntryStruct(
              text: 'hello',
              tr: [
                TranslationStruct(text: 'привет'),
              ],
            ),
          ],
          examples: [
            SentenceStruct(text: 'Hello!', lang: 'eng'),
          ],
        ),
      ],
      fetchEntries: (_) async {
        entryFetchCount++;
        return const <EntryStruct>[];
      },
      fetchExamples: (_) async {
        exampleFetchCount++;
        return const <SentenceStruct>[];
      },
    );

    expect(result.fromSavedWord, isTrue);
    expect(result.entries.single.tr.single.text, 'привет');
    expect(result.examples.single.text, 'Hello!');
    expect(entryFetchCount, 0);
    expect(exampleFetchCount, 0);
  });

  test(
      'matches saved content across two-letter and three-letter language codes',
      () async {
    final result = await WordLookupService.resolve(
      word: 'Hello',
      languageConfig: languageConfig,
      savedContents: [
        WordLookupSavedContent(
          entries: [
            EntryStruct(
              text: 'hello',
              tr: [
                TranslationStruct(text: 'не тот язык'),
              ],
            ),
          ],
          examples: [
            SentenceStruct(text: 'Hello!', lang: 'rus'),
          ],
        ),
        WordLookupSavedContent(
          entries: [
            EntryStruct(
              text: 'hello',
              tr: [
                TranslationStruct(text: 'привет'),
              ],
            ),
          ],
          examples: [
            SentenceStruct(text: 'Hello!', lang: 'eng'),
          ],
        ),
      ],
    );

    expect(result.entries.single.tr.single.text, 'привет');
    expect(result.fromSavedWord, isTrue);
  });

  test('caches API content for repeated unsaved word lookup', () async {
    var entryFetchCount = 0;
    var exampleFetchCount = 0;

    Future<WordLookupResult> resolveHello() {
      return WordLookupService.resolve(
        word: 'hello',
        languageConfig: languageConfig,
        fetchEntries: (_) async {
          entryFetchCount++;
          return [
            EntryStruct(
              text: 'hello',
              tr: [
                TranslationStruct(text: 'привет'),
              ],
            ),
          ];
        },
        fetchExamples: (_) async {
          exampleFetchCount++;
          return [
            SentenceStruct(text: 'Hello!', lang: 'eng'),
          ];
        },
      );
    }

    final first = await resolveHello();
    final second = await resolveHello();

    expect(first.fromMemoryCache, isFalse);
    expect(second.fromMemoryCache, isTrue);
    expect(second.entries.single.tr.single.text, 'привет');
    expect(second.examples.single.text, 'Hello!');
    expect(entryFetchCount, 1);
    expect(exampleFetchCount, 1);
  });

  test('keeps available API content when one fetcher fails', () async {
    final result = await WordLookupService.resolve(
      word: 'hello',
      languageConfig: languageConfig,
      fetchEntries: (_) async => throw Exception('translation failed'),
      fetchExamples: (_) async => [
        SentenceStruct(text: 'Hello!', lang: 'eng'),
      ],
    );

    expect(result.entries, isEmpty);
    expect(result.examples.single.text, 'Hello!');
  });
}
