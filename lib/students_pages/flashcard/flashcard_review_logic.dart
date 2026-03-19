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

class FlashcardSessionEntry {
  const FlashcardSessionEntry({
    required this.id,
    required this.stage,
    required this.direction,
    required this.promptText,
    required this.answerText,
    required this.sourceWord,
    required this.translationWord,
    this.exampleSource,
    this.exampleTranslation,
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
  final String? exampleSource;
  final String? exampleTranslation;
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

String? flashcardExampleSource(UserWordsRecord word) {
  for (final sentence in word.sentence) {
    final text = sentence.text.trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

String? flashcardExampleTranslation(UserWordsRecord word) {
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

FlashcardSessionEntry? buildFlashcardSessionEntry({
  required UserWordsRecord word,
  required WordReviewsRecord review,
}) {
  final sourceWord = flashcardSourceWord(word);
  final translationWord = flashcardTranslationWord(word);
  if (sourceWord.isEmpty || translationWord.isEmpty) {
    return null;
  }

  final stage = normalizeFlashcardStage(review.stage);
  final direction = flashcardDirectionForStage(stage);

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
    exampleSource: flashcardExampleSource(word),
    exampleTranslation: flashcardExampleTranslation(word),
    wordRef: word.reference,
    reviewRef: review.reference,
    reviewCreatedAt: review.createdAt,
  );
}
