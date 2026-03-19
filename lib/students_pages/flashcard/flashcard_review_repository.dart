import '/backend/backend.dart';

import 'flashcard_review_logic.dart';

class FlashcardReviewRepository {
  const FlashcardReviewRepository._();

  static Future<void> ensureInitialReviewForWord({
    required DocumentReference wordRef,
    DateTime? addedAt,
    DateTime? now,
  }) async {
    final userRef = wordRef.parent.parent;
    if (userRef == null) {
      return;
    }

    final effectiveNow = now ?? DateTime.now();
    final initialState = buildInitialFlashcardReviewState(
      addedAt: addedAt,
      now: effectiveNow,
    );
    final reviewRef = WordReviewsRecord.createDoc(userRef, id: wordRef.id);

    await reviewRef.set(
      createWordReviewsRecordData(
        wordRef: wordRef,
        stage: initialState.stage,
        dueAt: initialState.dueAt,
        createdAt: initialState.createdAt,
        updatedAt: initialState.updatedAt,
      ),
      SetOptions(merge: true),
    );
  }

  static Future<void> deleteReviewForWord(DocumentReference wordRef) async {
    final userRef = wordRef.parent.parent;
    if (userRef == null) {
      return;
    }

    final reviewRef = WordReviewsRecord.createDoc(userRef, id: wordRef.id);
    try {
      await reviewRef.delete();
    } catch (_) {}
  }

  static Future<void> ensureWordReviewsBackfilled({
    required DocumentReference userRef,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final userWords = await queryUserWordsRecordOnce(parent: userRef);
    if (userWords.isEmpty) {
      return;
    }

    final existingReviews = await queryWordReviewsRecordOnce(parent: userRef);
    final reviewIds = existingReviews.map((review) => review.reference.id).toSet();
    final missingWords =
        userWords.where((word) => !reviewIds.contains(word.reference.id)).toList();
    if (missingWords.isEmpty) {
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    for (final word in missingWords) {
      final initialState = buildInitialFlashcardReviewState(
        addedAt: word.addedAt,
        now: effectiveNow,
      );
      batch.set(
        WordReviewsRecord.createDoc(userRef, id: word.reference.id),
        createWordReviewsRecordData(
          wordRef: word.reference,
          stage: initialState.stage,
          dueAt: initialState.dueAt,
          createdAt: initialState.createdAt,
          updatedAt: initialState.updatedAt,
        ),
      );
    }

    await batch.commit();
  }

  static Future<List<FlashcardSessionEntry>> loadDueSession({
    required DocumentReference userRef,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    await ensureWordReviewsBackfilled(
      userRef: userRef,
      now: effectiveNow,
    );

    final words = await queryUserWordsRecordOnce(parent: userRef);
    final reviews = await queryWordReviewsRecordOnce(parent: userRef);
    if (words.isEmpty || reviews.isEmpty) {
      return const <FlashcardSessionEntry>[];
    }

    final wordsById = <String, UserWordsRecord>{
      for (final word in words) word.reference.id: word,
    };

    final dueReviews = reviews
        .where(
          (review) => isFlashcardDue(
            dueAt: review.dueAt,
            now: effectiveNow,
          ),
        )
        .toList()
      ..sort((left, right) {
        final leftDueAt = left.dueAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final rightDueAt = right.dueAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return leftDueAt.compareTo(rightDueAt);
      });

    return dueReviews
        .map((review) {
          final word = wordsById[review.reference.id];
          if (word == null) {
            return null;
          }
          return buildFlashcardSessionEntry(
            word: word,
            review: review,
          );
        })
        .whereType<FlashcardSessionEntry>()
        .toList();
  }

  static Future<void> persistCompletedReview({
    required FlashcardSessionEntry entry,
    required bool hadAnyMiss,
    DateTime? now,
  }) async {
    final reviewRef = entry.reviewRef;
    final wordRef = entry.wordRef;
    if (reviewRef == null || wordRef == null) {
      return;
    }

    final reviewedAt = now ?? DateTime.now();
    final nextStage = hadAnyMiss
        ? flashcardFailureFallbackStage(entry.stage)
        : flashcardSuccessNextStage(entry.stage);

    await reviewRef.set(
      createWordReviewsRecordData(
        wordRef: wordRef,
        stage: nextStage,
        dueAt: flashcardDueAtForStage(
          referenceTime: reviewedAt,
          stage: nextStage,
        ),
        createdAt: entry.reviewCreatedAt ?? reviewedAt,
        updatedAt: reviewedAt,
        lastReviewedAt: reviewedAt,
      ),
      SetOptions(merge: true),
    );
  }
}
