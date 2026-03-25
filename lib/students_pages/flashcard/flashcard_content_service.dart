import '/backend/api_requests/api_calls.dart';
import '/backend/backend.dart';

import 'flashcard_review_logic.dart';

class FlashcardContentService {
  const FlashcardContentService._();

  static const _maxSourceSynonyms = 6;

  static Future<List<SynonymStruct>> fetchEnglishSourceSynonyms({
    required String sourceWord,
  }) async {
    final normalizedSourceWord = sourceWord.trim();
    if (normalizedSourceWord.isEmpty) {
      return const <SynonymStruct>[];
    }

    final response = await DatamuseCall.call(
      word: normalizedSourceWord,
      max: _maxSourceSynonyms * 2,
    );
    if (!response.succeeded || response.jsonBody is! List) {
      return const <SynonymStruct>[];
    }

    final seen = <String>{normalizedSourceWord.toLowerCase()};
    final synonyms = <SynonymStruct>[];

    for (final item in response.jsonBody as List) {
      if (item is! Map) {
        continue;
      }

      final word = (item['word'] as String?)?.trim() ?? '';
      if (word.isEmpty) {
        continue;
      }

      final key = word.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }

      synonyms.add(
        SynonymStruct(
          text: word,
        ),
      );

      if (synonyms.length >= _maxSourceSynonyms) {
        break;
      }
    }

    return synonyms;
  }

  static Future<List<EntryStruct>> enrichWordWithSourceSynonyms({
    required DocumentReference wordRef,
    required List<EntryStruct> entries,
    required String sourceLanguageCode,
  }) async {
    if (entries.isEmpty || !flashcardLanguageMatches(sourceLanguageCode, 'en')) {
      return entries;
    }

    if (entries.first.hasSyn()) {
      return entries;
    }

    final sourceWord = entries.first.text.trim();
    if (sourceWord.isEmpty) {
      return entries;
    }

    final synonyms = await fetchEnglishSourceSynonyms(
      sourceWord: sourceWord,
    );
    final updatedEntries = _entriesWithSourceSynonyms(
      entries: entries,
      sourceSynonyms: synonyms,
    );

    await wordRef.set(
      mapToFirestore(
        <String, dynamic>{
          'entry': getEntryListFirestoreData(updatedEntries),
        },
      ),
      SetOptions(merge: true),
    );

    return updatedEntries;
  }

  static List<EntryStruct> _entriesWithSourceSynonyms({
    required List<EntryStruct> entries,
    required List<SynonymStruct> sourceSynonyms,
  }) {
    if (entries.isEmpty) {
      return entries;
    }

    final updatedEntries = <EntryStruct>[];
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (index != 0) {
        updatedEntries.add(entry);
        continue;
      }

      final resolvedSynonyms = sourceSynonyms.isEmpty
          ? const <SynonymStruct>[]
          : applySourceSynonymsToEntries(
              entries: [entry],
              sourceSynonyms: sourceSynonyms,
            ).first.syn;

      updatedEntries.add(
        EntryStruct(
          text: entry.text,
          pos: entry.pos,
          ts: entry.ts,
          syn: resolvedSynonyms,
          tr: entry.tr,
        ),
      );
    }

    return updatedEntries;
  }
}
