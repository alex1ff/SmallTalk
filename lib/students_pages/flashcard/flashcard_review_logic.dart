import 'dart:ui' show PlatformDispatcher;

import '/backend/api_requests/api_calls.dart';
import '/backend/backend.dart';

enum FlashcardPromptDirection {
  ruToEn,
  enToRu,
}

class FlashcardInitialReviewState {
  const FlashcardInitialReviewState({
    required this.stage,
    required this.createdAt,
    required this.updatedAt,
    required this.dueAt,
  });

  final int stage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime dueAt;
}

class FlashcardResolvedExample {
  const FlashcardResolvedExample({
    this.selectedSentence,
    this.exampleText,
    this.exampleTranslation,
  });

  final SentenceStruct? selectedSentence;
  final String? exampleText;
  final String? exampleTranslation;
}

class FlashcardSessionEntry {
  const FlashcardSessionEntry({
    required this.id,
    required this.stage,
    required this.direction,
    required this.promptText,
    required this.answerText,
    required this.sourceWord,
    required this.translationWord,
    this.sourceLanguageCode = 'en',
    this.sourceTranscription,
    this.sourceSynonyms = const <SynonymStruct>[],
    this.exampleSource,
    this.exampleTranslation,
    this.selectedExampleText,
    this.selectedExampleTranslation,
    this.wordRef,
    this.reviewRef,
    this.reviewCreatedAt,
  });

  final String id;
  final int stage;
  final FlashcardPromptDirection direction;
  final String promptText;
  final String answerText;
  final String sourceWord;
  final String translationWord;
  final String sourceLanguageCode;
  final String? sourceTranscription;
  final List<SynonymStruct> sourceSynonyms;
  final String? exampleSource;
  final String? exampleTranslation;
  final String? selectedExampleText;
  final String? selectedExampleTranslation;
  final DocumentReference? wordRef;
  final DocumentReference? reviewRef;
  final DateTime? reviewCreatedAt;
}

int normalizeFlashcardStage(int stage) => stage.clamp(1, 8).toInt();

FlashcardPromptDirection flashcardDirectionForStage(int stage) {
  final normalizedStage = normalizeFlashcardStage(stage);
  return normalizedStage.isOdd
      ? FlashcardPromptDirection.ruToEn
      : FlashcardPromptDirection.enToRu;
}

int flashcardIntervalDaysForStage(int stage) {
  switch (normalizeFlashcardStage(stage)) {
    case 1:
      return 1;
    case 2:
      return 3;
    case 3:
      return 7;
    case 4:
      return 14;
    case 5:
      return 30;
    case 6:
      return 30;
    case 7:
      return 180;
    case 8:
      return 180;
  }
  return 180;
}

int flashcardFailureFallbackStage(int stage) {
  switch (normalizeFlashcardStage(stage)) {
    case 1:
      return 1;
    case 2:
      return 2;
    case 3:
      return 1;
    case 4:
      return 2;
    case 5:
      return 3;
    case 6:
      return 2;
    case 7:
      return 3;
    case 8:
      return 2;
  }
  return 1;
}

int flashcardSuccessNextStage(int stage) {
  final normalizedStage = normalizeFlashcardStage(stage);
  return normalizedStage >= 8 ? 8 : normalizedStage + 1;
}

DateTime flashcardDueAtForStage({
  required DateTime referenceTime,
  required int stage,
}) {
  final localReference = referenceTime.toLocal();
  return DateTime(
    localReference.year,
    localReference.month,
    localReference.day + flashcardIntervalDaysForStage(stage),
    0,
    1,
  );
}

FlashcardInitialReviewState buildInitialFlashcardReviewState({
  DateTime? addedAt,
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();
  final effectiveAddedAt = addedAt ?? effectiveNow;
  return FlashcardInitialReviewState(
    stage: 1,
    createdAt: effectiveAddedAt,
    updatedAt: effectiveNow,
    dueAt: flashcardDueAtForStage(
      referenceTime: effectiveAddedAt,
      stage: 1,
    ),
  );
}

bool isFlashcardDue({
  required DateTime? dueAt,
  required DateTime now,
}) {
  if (dueAt == null) {
    return false;
  }
  return !dueAt.isAfter(now);
}

String normalizeFlashcardLanguageCode(String? code) {
  final normalizedByApi = YandexCall.normalizeLanguageCode(code);
  if (normalizedByApi != null && normalizedByApi.isNotEmpty) {
    return normalizedByApi;
  }

  final normalized =
      (code ?? '').trim().toLowerCase().replaceAll('_', '-').split('-').first;
  return normalized;
}

bool flashcardLanguageMatches(String? left, String? right) {
  final normalizedLeft = normalizeFlashcardLanguageCode(left);
  final normalizedRight = normalizeFlashcardLanguageCode(right);
  return normalizedLeft.isNotEmpty &&
      normalizedRight.isNotEmpty &&
      normalizedLeft == normalizedRight;
}

String flashcardPreferredTranslationLanguageCode(
  UsersRecord? user, {
  String? localeLanguageCode,
}) {
  final normalizedLocale = normalizeFlashcardLanguageCode(
    localeLanguageCode ?? PlatformDispatcher.instance.locale.languageCode,
  );

  final candidates = <String?>[
    user?.preferences.preferredNativeLanguage.code,
    user?.nativeLanguageNS.code,
    localeLanguageCode,
    normalizedLocale,
    'en',
  ];

  for (final candidate in candidates) {
    final normalized = normalizeFlashcardLanguageCode(candidate);
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }

  return 'en';
}

String flashcardSourceWord(UserWordsRecord word) {
  return word.entry.isNotEmpty ? word.entry.first.text.trim() : '';
}

String flashcardTranslationWord(UserWordsRecord word) {
  final translation = word.entry.isNotEmpty && word.entry.first.tr.isNotEmpty
      ? word.entry.first.tr.first.text.trim()
      : '';
  if (translation.isNotEmpty) {
    return translation;
  }
  return flashcardSourceWord(word);
}

String flashcardSourceLanguageCode(UserWordsRecord word) {
  for (final sentence in word.sentence) {
    final normalized = normalizeFlashcardLanguageCode(sentence.lang);
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }

  return 'en';
}

String? flashcardSourceTranscription(UserWordsRecord word) {
  if (word.entry.isEmpty) {
    return null;
  }

  final transcription = word.entry.first.ts.trim();
  if (transcription.isEmpty) {
    return null;
  }

  return transcription;
}

List<SynonymStruct> flashcardSourceSynonyms(UserWordsRecord word) {
  if (word.entry.isEmpty) {
    return const <SynonymStruct>[];
  }

  final seen = <String>{};
  final synonyms = <SynonymStruct>[];

  for (final synonym in word.entry.first.syn) {
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

bool flashcardIsSourceWordVisible({
  required FlashcardPromptDirection direction,
  required bool isAnswerVisible,
}) {
  return direction == FlashcardPromptDirection.enToRu || isAnswerVisible;
}

SentenceStruct? selectFlashcardExampleSentence({
  required List<SentenceStruct> sentences,
  required String sourceWord,
  required String sourceLanguageCode,
  String? targetLanguageCode,
}) {
  final nonEmptySentences = sentences
      .where((sentence) => sentence.text.trim().isNotEmpty)
      .toList(growable: false);
  if (nonEmptySentences.isEmpty) {
    return null;
  }

  SentenceStruct? bestSentence;
  var bestScore = -1;
  var bestLength = 1 << 30;

  for (final sentence in nonEmptySentences) {
    final score = _scoreFlashcardExampleSentence(
      sentence: sentence,
      sourceWord: sourceWord,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
    );
    final length = sentence.text.trim().length;

    if (score > bestScore || (score == bestScore && length < bestLength)) {
      bestSentence = sentence;
      bestScore = score;
      bestLength = length;
    }
  }

  return bestSentence;
}

Translation2Struct? selectFlashcardExampleTranslation({
  required SentenceStruct sentence,
  required String targetLanguageCode,
}) {
  for (final translation in sentence.translations) {
    if (!flashcardLanguageMatches(translation.lang, targetLanguageCode)) {
      continue;
    }

    final text = translation.text.trim();
    if (text.isEmpty) {
      continue;
    }

    return translation;
  }

  return null;
}

Future<FlashcardResolvedExample> resolveFlashcardExample({
  required List<SentenceStruct> sentences,
  required String sourceWord,
  required String sourceLanguageCode,
  required String targetLanguageCode,
}) async {
  final selectedSentence = selectFlashcardExampleSentence(
    sentences: sentences,
    sourceWord: sourceWord,
    sourceLanguageCode: sourceLanguageCode,
    targetLanguageCode: targetLanguageCode,
  );
  if (selectedSentence == null) {
    return const FlashcardResolvedExample();
  }

  final exampleText = selectedSentence.text.trim();
  if (exampleText.isEmpty) {
    return const FlashcardResolvedExample();
  }

  final existingTranslation = selectFlashcardExampleTranslation(
    sentence: selectedSentence,
    targetLanguageCode: targetLanguageCode,
  );
  if (existingTranslation != null) {
    return FlashcardResolvedExample(
      selectedSentence: selectedSentence,
      exampleText: exampleText,
      exampleTranslation: existingTranslation.text.trim(),
    );
  }

  if (flashcardLanguageMatches(sourceLanguageCode, targetLanguageCode)) {
    return FlashcardResolvedExample(
      selectedSentence: selectedSentence,
      exampleText: exampleText,
    );
  }

  return FlashcardResolvedExample(
    selectedSentence: selectedSentence,
    exampleText: exampleText,
  );
}

int _scoreFlashcardExampleSentence({
  required SentenceStruct sentence,
  required String sourceWord,
  required String sourceLanguageCode,
  String? targetLanguageCode,
}) {
  var score = 0;

  if (flashcardLanguageMatches(sentence.lang, sourceLanguageCode)) {
    score += 1000;
  }

  if (_flashcardSentenceContainsSourceWord(
    sentenceText: sentence.text,
    sourceWord: sourceWord,
  )) {
    score += 100;
  }

  if (targetLanguageCode != null &&
      targetLanguageCode.trim().isNotEmpty &&
      selectFlashcardExampleTranslation(
            sentence: sentence,
            targetLanguageCode: targetLanguageCode,
          ) !=
          null) {
    score += 40;
  }

  if (sentence.translations.any((translation) => translation.text.trim().isNotEmpty)) {
    score += 10;
  }

  if (sentence.hasId()) {
    score += 5;
  }

  return score;
}

bool _flashcardSentenceContainsSourceWord({
  required String sentenceText,
  required String sourceWord,
}) {
  final normalizedSentence = sentenceText.trim();
  final normalizedSourceWord = sourceWord.trim();
  if (normalizedSentence.isEmpty || normalizedSourceWord.isEmpty) {
    return false;
  }

  final pattern = RegExp(
    '(^|[^A-Za-zА-Яа-яЁё0-9])${RegExp.escape(normalizedSourceWord)}(?=[^A-Za-zА-Яа-яЁё0-9]|\$)',
    caseSensitive: false,
  );

  return pattern.hasMatch(normalizedSentence);
}

List<EntryStruct> applySourceSynonymsToEntries({
  required List<EntryStruct> entries,
  required List<SynonymStruct> sourceSynonyms,
}) {
  if (entries.isEmpty || sourceSynonyms.isEmpty) {
    return entries;
  }

  final updatedEntries = <EntryStruct>[];
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    if (index != 0) {
      updatedEntries.add(entry);
      continue;
    }

    final mergedSynonyms = <SynonymStruct>[];
    final seen = <String>{};

    void addSynonym(SynonymStruct synonym) {
      final text = synonym.text.trim();
      if (text.isEmpty) {
        return;
      }

      final key = text.toLowerCase();
      if (!seen.add(key)) {
        return;
      }

      mergedSynonyms.add(
        SynonymStruct(
          text: text,
          gen: synonym.gen.trim().isEmpty ? null : synonym.gen.trim(),
        ),
      );
    }

    for (final synonym in entry.syn) {
      addSynonym(synonym);
    }
    for (final synonym in sourceSynonyms) {
      addSynonym(synonym);
    }

    updatedEntries.add(
      EntryStruct(
        text: entry.text,
        pos: entry.pos,
        ts: entry.ts,
        syn: mergedSynonyms,
        tr: entry.tr,
      ),
    );
  }

  return updatedEntries;
}

FlashcardSessionEntry? buildFlashcardSessionEntry({
  required UserWordsRecord word,
  required WordReviewsRecord review,
  String? exampleSource,
  String? exampleTranslation,
}) {
  final sourceWord = flashcardSourceWord(word);
  final translationWord = flashcardTranslationWord(word);
  if (sourceWord.isEmpty || translationWord.isEmpty) {
    return null;
  }

  final stage = normalizeFlashcardStage(review.stage);
  final direction = flashcardDirectionForStage(stage);
  final resolvedExampleSource = exampleSource ?? _legacyFlashcardExampleSource(word);
  final resolvedExampleTranslation =
      exampleTranslation ?? _legacyFlashcardExampleTranslation(word);

  return FlashcardSessionEntry(
    id: word.reference.id,
    stage: stage,
    direction: direction,
    promptText:
        direction == FlashcardPromptDirection.ruToEn ? translationWord : sourceWord,
    answerText:
        direction == FlashcardPromptDirection.ruToEn ? sourceWord : translationWord,
    sourceWord: sourceWord,
    translationWord: translationWord,
    sourceLanguageCode: flashcardSourceLanguageCode(word),
    sourceTranscription: flashcardSourceTranscription(word),
    sourceSynonyms: flashcardSourceSynonyms(word),
    exampleSource: resolvedExampleSource,
    exampleTranslation: resolvedExampleTranslation,
    selectedExampleText: resolvedExampleSource,
    selectedExampleTranslation: resolvedExampleTranslation,
    wordRef: word.reference,
    reviewRef: review.reference,
    reviewCreatedAt: review.createdAt,
  );
}

String? _legacyFlashcardExampleSource(UserWordsRecord word) {
  for (final sentence in word.sentence) {
    final text = sentence.text.trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

String? _legacyFlashcardExampleTranslation(UserWordsRecord word) {
  for (final sentence in word.sentence) {
    if (sentence.translations.isEmpty) {
      continue;
    }
    final text = sentence.translations.first.text.trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return null;
}
