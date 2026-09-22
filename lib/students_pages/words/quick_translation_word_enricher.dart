import 'package:collection/collection.dart';

import '/backend/backend.dart';
import '/students_pages/words/word_content_normalization.dart';
import '/students_pages/words/word_lookup_service.dart';

class SavedWordLookupMetadata {
  const SavedWordLookupMetadata({
    required this.source,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
  });

  factory SavedWordLookupMetadata.fromRecord(UserWordsRecord record) {
    String readString(String key) {
      final value = record.snapshotData[key];
      return value is String ? value.trim() : '';
    }

    return SavedWordLookupMetadata(
      source: readString('source'),
      sourceLanguageCode: readString('sourceLanguage'),
      targetLanguageCode: readString('targetLanguage'),
    );
  }

  final String source;
  final String sourceLanguageCode;
  final String targetLanguageCode;

  bool get canRetryRemoteLookup =>
      source == 'google_cloud_translation' &&
      sourceLanguageCode.isNotEmpty &&
      targetLanguageCode.isNotEmpty;

  bool needsEnrichment(UserWordsRecord record) {
    final hasTranscription = record.entry.any(
      (entry) => entry.ts.trim().isNotEmpty,
    );
    return !hasTranscription || record.sentence.isEmpty;
  }

  WordLookupLanguageConfig toLanguageConfig() {
    return WordLookupLanguageConfig(
      sourceLanguageCode: sourceLanguageCode,
      yandexSourceLanguageCode: resolveYandexWordLookupLanguageCode(
        <String?>[sourceLanguageCode],
        fallback: 'en',
      ),
      yandexTranslationLanguageCode: resolveYandexWordLookupLanguageCode(
        <String?>[targetLanguageCode],
        fallback: 'ru',
      ),
      tatoebaSourceLanguageCode: resolveTatoebaWordLookupLanguageCode(
        <String?>[sourceLanguageCode],
        fallback: 'eng',
      ),
      tatoebaTranslationLanguageCode: resolveTatoebaWordLookupLanguageCode(
        <String?>[targetLanguageCode],
        fallback: 'rus',
      ),
    );
  }
}

class WordEnrichmentMerge {
  const WordEnrichmentMerge({
    required this.entries,
    required this.examples,
  });

  final List<EntryStruct> entries;
  final List<SentenceStruct> examples;
}

class QuickTranslationWordEnricher {
  const QuickTranslationWordEnricher();

  Future<WordEnrichmentMerge?> enrich({
    required DocumentReference wordReference,
    required String sourceText,
    required String directTranslation,
    required WordRemoteLookupResult remoteResult,
  }) async {
    WordEnrichmentMerge? result;
    await wordReference.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(wordReference);
      if (!snapshot.exists) {
        return;
      }

      final record = UserWordsRecord.fromSnapshot(snapshot);
      result = merge(
        existingEntries: record.entry,
        existingExamples: record.sentence,
        sourceText: sourceText,
        directTranslation: directTranslation,
        remoteEntries: remoteResult.entries,
        remoteExamples: remoteResult.examples,
      );
      final merged = result!;
      transaction.update(
        wordReference,
        mapToFirestore(<String, dynamic>{
          'entry': getEntryListFirestoreData(merged.entries),
          'Sentence': getSentenceListFirestoreData(merged.examples),
        }),
      );
    });
    return result;
  }

  WordEnrichmentMerge merge({
    required List<EntryStruct> existingEntries,
    required List<SentenceStruct> existingExamples,
    required String sourceText,
    required String directTranslation,
    required List<EntryStruct> remoteEntries,
    required List<SentenceStruct> remoteExamples,
  }) {
    final normalizedSource = normalizeWordContentValue(sourceText);
    final normalizedDirect = normalizeWordContentValue(directTranslation);
    final existingPrimary = existingEntries.firstOrNull ??
        EntryStruct(
          text: sourceText,
          tr: <TranslationStruct>[
            if (normalizedDirect.isNotEmpty)
              TranslationStruct(text: directTranslation),
          ],
        );
    final primaryRemoteIndex = remoteEntries.indexWhere(
      (entry) => normalizeWordContentValue(entry.text) == normalizedSource,
    );
    final primaryRemote =
        primaryRemoteIndex < 0 ? null : remoteEntries[primaryRemoteIndex];

    final mergedEntries = <EntryStruct>[
      _mergeEntry(
        existingPrimary,
        primaryRemote,
        forcedSourceText: sourceText,
        forcedPrimaryTranslation: directTranslation,
      ),
      ...existingEntries.skip(1).map(_copyEntry),
    ];

    for (var index = 0; index < remoteEntries.length; index += 1) {
      if (index == primaryRemoteIndex) {
        continue;
      }
      final remote = remoteEntries[index];
      final matchIndex = mergedEntries.indexWhere(
        (entry) => _entryKeysMatch(entry, remote),
      );
      if (matchIndex < 0) {
        mergedEntries.add(_copyEntry(remote));
      } else {
        mergedEntries[matchIndex] = _mergeEntry(
          mergedEntries[matchIndex],
          remote,
        );
      }
    }

    return WordEnrichmentMerge(
      entries: mergedEntries,
      examples: _mergeExamples(existingExamples, remoteExamples),
    );
  }

  EntryStruct _mergeEntry(
    EntryStruct existing,
    EntryStruct? remote, {
    String? forcedSourceText,
    String? forcedPrimaryTranslation,
  }) {
    final remoteEntry = remote ?? EntryStruct();
    return EntryStruct(
      text: _firstNonEmpty(<String?>[
        forcedSourceText,
        existing.text,
        remoteEntry.text,
      ]),
      pos: _firstNonEmpty(<String?>[existing.pos, remoteEntry.pos]),
      ts: _firstNonEmpty(<String?>[existing.ts, remoteEntry.ts]),
      syn: _mergeSynonyms(existing.syn, remoteEntry.syn),
      tr: _mergeTranslations(
        existing.tr,
        remoteEntry.tr,
        forcedPrimaryTranslation: forcedPrimaryTranslation,
      ),
    );
  }

  List<TranslationStruct> _mergeTranslations(
    List<TranslationStruct> existing,
    List<TranslationStruct> remote, {
    String? forcedPrimaryTranslation,
  }) {
    final merged = <TranslationStruct>[];
    final forcedKey = normalizeWordContentValue(forcedPrimaryTranslation);

    if (forcedKey.isNotEmpty) {
      TranslationStruct primary = TranslationStruct(
        text: forcedPrimaryTranslation,
      );
      for (final candidate in <TranslationStruct>[...existing, ...remote]) {
        if (normalizeWordContentValue(candidate.text) == forcedKey) {
          primary = _mergeTranslation(primary, candidate);
        }
      }
      merged.add(primary);
    }

    for (final candidate in <TranslationStruct>[...existing, ...remote]) {
      if (forcedKey.isNotEmpty &&
          normalizeWordContentValue(candidate.text) == forcedKey) {
        continue;
      }
      final matchIndex = merged.indexWhere(
        (item) => _translationKeysMatch(item, candidate),
      );
      if (matchIndex < 0) {
        merged.add(_copyTranslation(candidate));
      } else {
        merged[matchIndex] = _mergeTranslation(merged[matchIndex], candidate);
      }
    }
    return merged;
  }

  TranslationStruct _mergeTranslation(
    TranslationStruct existing,
    TranslationStruct remote,
  ) {
    return TranslationStruct(
      text: _firstNonEmpty(<String?>[existing.text, remote.text]),
      pos: _firstNonEmpty(<String?>[existing.pos, remote.pos]),
      gen: _firstNonEmpty(<String?>[existing.gen, remote.gen]),
      fr: existing.hasFr()
          ? existing.fr
          : remote.hasFr()
              ? remote.fr
              : null,
      asp: _firstNonEmpty(<String?>[existing.asp, remote.asp]),
      syn: _mergeSynonyms(existing.syn, remote.syn),
      mean: _mergeMeanings(existing.mean, remote.mean),
    );
  }

  List<SynonymStruct> _mergeSynonyms(
    List<SynonymStruct> existing,
    List<SynonymStruct> remote,
  ) {
    final merged = <SynonymStruct>[];
    final seen = <String>{};
    for (final synonym in <SynonymStruct>[...existing, ...remote]) {
      final key = normalizeWordContentValue(synonym.text);
      if (key.isEmpty || !seen.add(key)) {
        continue;
      }
      merged.add(
        SynonymStruct(
          text: synonym.text.trim(),
          gen: synonym.gen.trim().isEmpty ? null : synonym.gen.trim(),
        ),
      );
    }
    return merged;
  }

  List<MeaningStruct> _mergeMeanings(
    List<MeaningStruct> existing,
    List<MeaningStruct> remote,
  ) {
    final merged = <MeaningStruct>[];
    final seen = <String>{};
    for (final meaning in <MeaningStruct>[...existing, ...remote]) {
      final key = normalizeWordContentValue(meaning.text);
      if (key.isEmpty || !seen.add(key)) {
        continue;
      }
      merged.add(MeaningStruct(text: meaning.text.trim()));
    }
    return merged;
  }

  List<SentenceStruct> _mergeExamples(
    List<SentenceStruct> existing,
    List<SentenceStruct> remote,
  ) {
    final merged = <SentenceStruct>[];
    final indexByKey = <String, int>{};
    for (final sentence in <SentenceStruct>[...existing, ...remote]) {
      final textKey = normalizeWordContentValue(sentence.text);
      if (textKey.isEmpty) {
        continue;
      }
      final key = '${normalizedWordLanguageCode(sentence.lang)}|$textKey';
      final matchIndex = indexByKey[key];
      if (matchIndex == null) {
        indexByKey[key] = merged.length;
        merged.add(_copySentence(sentence));
      } else {
        merged[matchIndex] = _mergeSentence(merged[matchIndex], sentence);
      }
    }
    return merged;
  }

  SentenceStruct _mergeSentence(
    SentenceStruct existing,
    SentenceStruct remote,
  ) {
    final translations = <Translation2Struct>[];
    final seen = <String>{};
    for (final translation in <Translation2Struct>[
      ...existing.translations,
      ...remote.translations,
    ]) {
      final key =
          '${normalizedWordLanguageCode(translation.lang)}|${normalizeWordContentValue(translation.text)}';
      if (key.endsWith('|') || !seen.add(key)) {
        continue;
      }
      translations.add(
        Translation2Struct(
          id: translation.hasId() ? translation.id : null,
          text: translation.text.trim(),
          lang: translation.lang.trim(),
        ),
      );
    }
    return SentenceStruct(
      id: existing.hasId()
          ? existing.id
          : remote.hasId()
              ? remote.id
              : null,
      text: _firstNonEmpty(<String?>[existing.text, remote.text]),
      lang: _firstNonEmpty(<String?>[existing.lang, remote.lang]),
      translations: translations,
    );
  }

  bool _entryKeysMatch(EntryStruct left, EntryStruct right) {
    final leftText = normalizeWordContentValue(left.text);
    final rightText = normalizeWordContentValue(right.text);
    if (leftText.isEmpty || leftText != rightText) {
      return false;
    }
    final leftPos = normalizeWordContentValue(left.pos);
    final rightPos = normalizeWordContentValue(right.pos);
    return leftPos == rightPos || leftPos.isEmpty || rightPos.isEmpty;
  }

  bool _translationKeysMatch(
    TranslationStruct left,
    TranslationStruct right,
  ) {
    final leftText = normalizeWordContentValue(left.text);
    final rightText = normalizeWordContentValue(right.text);
    if (leftText.isEmpty || leftText != rightText) {
      return false;
    }
    final leftPos = normalizeWordContentValue(left.pos);
    final rightPos = normalizeWordContentValue(right.pos);
    return leftPos == rightPos || leftPos.isEmpty || rightPos.isEmpty;
  }

  EntryStruct _copyEntry(EntryStruct value) {
    return EntryStruct(
      text: value.text,
      pos: value.pos,
      ts: value.ts,
      syn: value.syn.map(_copySynonym).toList(growable: false),
      tr: value.tr.map(_copyTranslation).toList(growable: false),
    );
  }

  TranslationStruct _copyTranslation(TranslationStruct value) {
    return TranslationStruct(
      text: value.text,
      pos: value.pos,
      gen: value.gen,
      fr: value.hasFr() ? value.fr : null,
      syn: value.syn.map(_copySynonym).toList(growable: false),
      mean: value.mean
          .map((meaning) => MeaningStruct(text: meaning.text))
          .toList(growable: false),
      asp: value.asp,
    );
  }

  SynonymStruct _copySynonym(SynonymStruct value) {
    return SynonymStruct(text: value.text, gen: value.gen);
  }

  SentenceStruct _copySentence(SentenceStruct value) {
    return SentenceStruct(
      id: value.hasId() ? value.id : null,
      text: value.text,
      lang: value.lang,
      translations: value.translations
          .map(
            (translation) => Translation2Struct(
              id: translation.hasId() ? translation.id : null,
              text: translation.text,
              lang: translation.lang,
            ),
          )
          .toList(growable: false),
    );
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }
}
