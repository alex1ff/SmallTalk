import 'package:flutter_test/flutter_test.dart';
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
  });
}
