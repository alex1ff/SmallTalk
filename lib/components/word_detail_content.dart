import 'package:collection/collection.dart';

import '/backend/schema/structs/index.dart';
import '/students_pages/words/word_content_normalization.dart';

class WordDetailContent {
  const WordDetailContent({
    required this.entries,
    required this.examples,
  });

  final List<EntryStruct> entries;
  final List<SentenceStruct> examples;

  EntryStruct? get primaryEntry => entries.firstOrNull;

  String get sourceText {
    for (final entry in entries) {
      final text = entry.text.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '-';
  }

  String get transcription {
    final sourceKey = normalizeWordContentValue(sourceText);
    for (final entry in entries) {
      if (normalizeWordContentValue(entry.text) != sourceKey) {
        continue;
      }
      final value = entry.ts.trim();
      if (value.isEmpty) {
        continue;
      }
      if (value.startsWith('/') && value.endsWith('/')) {
        return value;
      }
      return '/${value.replaceAll('/', '')}/';
    }
    return '';
  }

  TranslationStruct? get primaryTranslation {
    for (final entry in entries) {
      for (final translation in entry.tr) {
        if (translation.text.trim().isNotEmpty) {
          return translation;
        }
      }
    }
    return null;
  }

  String get translationText => primaryTranslation?.text.trim() ?? '-';

  List<SynonymStruct> get sourceSynonyms {
    final used = <String>{normalizeWordContentValue(sourceText)};
    final result = <SynonymStruct>[];
    for (final entry in entries) {
      for (final synonym in entry.syn) {
        _addSynonym(result, used, synonym);
      }
    }
    return result;
  }

  List<SynonymStruct> get additionalTranslations {
    final used = <String>{
      normalizeWordContentValue(sourceText),
      normalizeWordContentValue(translationText),
      ...sourceSynonyms.map(
        (synonym) => normalizeWordContentValue(synonym.text),
      ),
    };
    final result = <SynonymStruct>[];
    var skippedPrimary = false;
    for (final entry in entries) {
      for (final translation in entry.tr) {
        final key = normalizeWordContentValue(translation.text);
        if (!skippedPrimary && key.isNotEmpty) {
          skippedPrimary = true;
          continue;
        }
        _addSynonym(
          result,
          used,
          SynonymStruct(text: translation.text, gen: translation.gen),
        );
      }
    }
    return result;
  }

  List<SynonymStruct> get translationSynonyms {
    final used = <String>{
      normalizeWordContentValue(sourceText),
      normalizeWordContentValue(translationText),
      ...sourceSynonyms.map(
        (synonym) => normalizeWordContentValue(synonym.text),
      ),
      ...additionalTranslations.map(
        (translation) => normalizeWordContentValue(translation.text),
      ),
      ...meanings.map(normalizeWordContentValue),
    };
    final result = <SynonymStruct>[];
    for (final entry in entries) {
      for (final translation in entry.tr) {
        for (final synonym in translation.syn) {
          _addSynonym(result, used, synonym);
        }
      }
    }
    return result;
  }

  List<String> get meanings {
    final used = <String>{
      normalizeWordContentValue(sourceText),
      normalizeWordContentValue(translationText),
      ...additionalTranslations.map(
        (translation) => normalizeWordContentValue(translation.text),
      ),
      ...sourceSynonyms.map(
        (synonym) => normalizeWordContentValue(synonym.text),
      ),
    };
    final result = <String>[];
    for (final entry in entries) {
      for (final translation in entry.tr) {
        for (final meaning in translation.mean) {
          final text = meaning.text.trim();
          final key = normalizeWordContentValue(text);
          if (key.isEmpty || !used.add(key)) {
            continue;
          }
          result.add(text);
        }
      }
    }
    return result;
  }

  List<WordDetailTranslationGroup> get translationGroups {
    final synonyms = translationSynonyms;
    final allMeanings =
        meanings.map((text) => MeaningStruct(text: text)).toList();
    if (additionalTranslations.isEmpty &&
        synonyms.isEmpty &&
        allMeanings.isEmpty) {
      return const <WordDetailTranslationGroup>[];
    }
    return <WordDetailTranslationGroup>[
      WordDetailTranslationGroup(
        entry: primaryEntry ?? EntryStruct(text: sourceText),
        translation:
            primaryTranslation ?? TranslationStruct(text: translationText),
        synonyms: <SynonymStruct>[
          ...additionalTranslations,
          ...synonyms,
        ],
        meanings: allMeanings,
      ),
    ];
  }
}

class WordDetailTranslationGroup {
  const WordDetailTranslationGroup({
    required this.entry,
    required this.translation,
    required this.synonyms,
    required this.meanings,
  });

  final EntryStruct entry;
  final TranslationStruct translation;
  final List<SynonymStruct> synonyms;
  final List<MeaningStruct> meanings;
}

WordDetailContent buildWordDetailContent({
  List<EntryStruct> savedEntries = const <EntryStruct>[],
  List<SentenceStruct> savedExamples = const <SentenceStruct>[],
  List<EntryStruct> apiEntries = const <EntryStruct>[],
  List<SentenceStruct> apiExamples = const <SentenceStruct>[],
}) {
  return WordDetailContent(
    entries: apiEntries.isNotEmpty ? apiEntries : savedEntries,
    examples: _mergeExamples(
      savedExamples: savedExamples,
      apiExamples: apiExamples,
    ),
  );
}

void _addSynonym(
  List<SynonymStruct> result,
  Set<String> used,
  SynonymStruct synonym,
) {
  final text = synonym.text.trim();
  final key = normalizeWordContentValue(text);
  if (key.isEmpty || !used.add(key)) {
    return;
  }
  result.add(
    SynonymStruct(
      text: text,
      gen: synonym.gen.trim().isEmpty ? null : synonym.gen.trim(),
    ),
  );
}

List<SentenceStruct> _mergeExamples({
  required List<SentenceStruct> savedExamples,
  required List<SentenceStruct> apiExamples,
}) {
  final merged = <SentenceStruct>[];
  final indexByKey = <String, int>{};

  void upsertSentence(SentenceStruct sentence) {
    final text = sentence.text.trim();
    if (text.isEmpty) {
      return;
    }
    final key =
        '${normalizedWordLanguageCode(sentence.lang)}|${normalizeWordContentValue(text)}';
    final existingIndex = indexByKey[key];
    if (existingIndex == null) {
      indexByKey[key] = merged.length;
      merged.add(sentence);
      return;
    }
    if (merged[existingIndex].translations.isEmpty &&
        sentence.translations.isNotEmpty) {
      merged[existingIndex] = sentence;
    }
  }

  for (final sentence in savedExamples) {
    upsertSentence(sentence);
  }
  for (final sentence in apiExamples) {
    upsertSentence(sentence);
  }
  return merged;
}
