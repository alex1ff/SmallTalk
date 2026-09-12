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

  static Future<String?> fetchEnglishSourceTranscription({
    required String sourceWord,
  }) async {
    final normalizedSourceWord = sourceWord.trim();
    if (normalizedSourceWord.isEmpty) {
      return null;
    }

    final response = await YandexCall.call(
      text: normalizedSourceWord,
      lang: 'en-ru',
    );
    final jsonBody = response.jsonBody;
    if (!response.succeeded || jsonBody is! Map) {
      return null;
    }

    final entries =
        YyStruct.maybeFromMap(jsonBody)?.def.toList() ?? const <EntryStruct>[];
    for (final entry in entries) {
      final transcription = entry.ts.trim();
      if (transcription.isEmpty) {
        continue;
      }

      if (entry.text.trim().toLowerCase() ==
          normalizedSourceWord.toLowerCase()) {
        return transcription;
      }
    }

    for (final entry in entries) {
      final transcription = entry.ts.trim();
      if (transcription.isNotEmpty) {
        return transcription;
      }
    }

    return null;
  }

  static Future<List<EntryStruct>> enrichWordWithSourceSynonyms({
    required DocumentReference wordRef,
    required List<EntryStruct> entries,
    required String sourceLanguageCode,
  }) async {
    return enrichWordWithSourceMetadata(
      wordRef: wordRef,
      entries: entries,
      sourceLanguageCode: sourceLanguageCode,
    );
  }

  static Future<List<EntryStruct>> enrichWordWithSourceMetadata({
    required DocumentReference wordRef,
    required List<EntryStruct> entries,
    required String sourceLanguageCode,
  }) async {
    if (entries.isEmpty ||
        !flashcardLanguageMatches(sourceLanguageCode, 'en')) {
      return entries;
    }

    final sourceWord = entries.first.text.trim();
    if (sourceWord.isEmpty) {
      return entries;
    }

    final needsTranscription = entries.first.ts.trim().isEmpty;
    final needsSynonyms = entries.first.syn.isEmpty;
    if (!needsTranscription && !needsSynonyms) {
      return entries;
    }

    String? transcription;
    var synonyms = const <SynonymStruct>[];

    await Future.wait([
      if (needsTranscription)
        Future(() async {
          transcription = await fetchEnglishSourceTranscription(
            sourceWord: sourceWord,
          );
        }),
      if (needsSynonyms)
        Future(() async {
          synonyms = await fetchEnglishSourceSynonyms(
            sourceWord: sourceWord,
          );
        }),
    ]);

    if ((transcription?.trim().isEmpty ?? true) && synonyms.isEmpty) {
      return entries;
    }

    final updatedEntries = _entriesWithSourceMetadata(
      entries: entries,
      sourceTranscription: transcription,
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

  static List<EntryStruct> _entriesWithSourceMetadata({
    required List<EntryStruct> entries,
    required String? sourceTranscription,
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
      final resolvedTranscription =
          sourceTranscription?.trim().isNotEmpty ?? false
              ? sourceTranscription!.trim()
              : entry.ts;

      updatedEntries.add(
        EntryStruct(
          text: entry.text,
          pos: entry.pos,
          ts: resolvedTranscription,
          syn: resolvedSynonyms.isEmpty ? entry.syn : resolvedSynonyms,
          tr: entry.tr,
        ),
      );
    }

    return updatedEntries;
  }
}
