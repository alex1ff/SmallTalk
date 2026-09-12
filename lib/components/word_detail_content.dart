import '/backend/schema/structs/index.dart';
import 'package:collection/collection.dart';

class WordDetailContent {
  const WordDetailContent({
    required this.entries,
    required this.examples,
  });

  final List<EntryStruct> entries;
  final List<SentenceStruct> examples;

  EntryStruct? get primaryEntry => entries.firstOrNull;

  String get sourceText {
    final text = primaryEntry?.text.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
    return '-';
  }

  String get transcription {
    final value = primaryEntry?.ts.trim() ?? '';
    if (value.isEmpty) {
      return '';
    }
    if (value.startsWith('/')) {
      return value;
    }
    return '/$value/';
  }

  String get translationText {
    final translations = primaryEntry?.tr
            .map((translation) => translation.text.trim())
            .where((text) => text.isNotEmpty)
            .take(3)
            .toList() ??
        const <String>[];
    if (translations.isEmpty) {
      return '-';
    }
    return translations.join('; ');
  }

  List<SynonymStruct> get sourceSynonyms {
    final synonyms = <SynonymStruct>[];
    final seen = <String>{};

    for (final synonym in primaryEntry?.syn ?? const <SynonymStruct>[]) {
      final text = synonym.text.trim();
      if (text.isEmpty) {
        continue;
      }

      final key = text.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }

      synonyms.add(
        SynonymStruct(
          text: text,
          gen: synonym.gen.trim().isEmpty ? null : synonym.gen.trim(),
        ),
      );
    }

    return synonyms;
  }

  List<WordDetailTranslationGroup> get translationGroups {
    final groups = <WordDetailTranslationGroup>[];
    for (final entry in entries) {
      for (final translation in entry.tr.take(3)) {
        final synonyms = _translationSynonyms(translation);
        final meanings = translation.mean
            .where((meaning) => meaning.text.trim().isNotEmpty)
            .toList();
        if (translation.text.trim().isEmpty &&
            synonyms.isEmpty &&
            meanings.isEmpty) {
          continue;
        }

        groups.add(
          WordDetailTranslationGroup(
            entry: entry,
            translation: translation,
            synonyms: synonyms,
            meanings: meanings,
          ),
        );
      }
    }
    return groups;
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

List<SentenceStruct> _mergeExamples({
  required List<SentenceStruct> savedExamples,
  required List<SentenceStruct> apiExamples,
}) {
  final merged = <SentenceStruct>[];
  final indexByKey = <String, int>{};

  void upsertSentence(
    SentenceStruct sentence, {
    required bool preferNew,
  }) {
    final text = sentence.text.trim();
    if (text.isEmpty) {
      return;
    }

    final language = _normalizeLanguageCode(sentence.lang);
    final dedupeKey = '$language|${text.toLowerCase()}';
    final existingIndex = indexByKey[dedupeKey];

    if (existingIndex != null) {
      if (preferNew) {
        merged[existingIndex] = sentence;
      }
      return;
    }

    indexByKey[dedupeKey] = merged.length;
    merged.add(sentence);
  }

  for (final sentence in savedExamples) {
    upsertSentence(sentence, preferNew: false);
  }

  for (final sentence in apiExamples) {
    upsertSentence(sentence, preferNew: true);
  }

  return merged;
}

List<SynonymStruct> _translationSynonyms(TranslationStruct translation) {
  final synonyms = <SynonymStruct>[];
  final seen = <String>{};

  void addSynonym(SynonymStruct synonym) {
    final text = synonym.text.trim();
    if (text.isEmpty) {
      return;
    }

    final gen = synonym.gen.trim();
    final key = '$text|$gen'.toLowerCase();
    if (!seen.add(key)) {
      return;
    }

    synonyms.add(
      SynonymStruct(
        text: text,
        gen: gen.isEmpty ? null : gen,
      ),
    );
  }

  for (final synonym in translation.syn) {
    addSynonym(synonym);
  }

  addSynonym(
    SynonymStruct(
      text: translation.text,
      gen: translation.gen,
    ),
  );

  return synonyms;
}

String _normalizeLanguageCode(String? code) {
  return (code ?? '').trim().toLowerCase().replaceAll('_', '-');
}
