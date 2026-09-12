# Translation and AI Feedback Implementation Plan

Spec: `docs/superpowers/specs/2026-08-27-translation-ai-feedback-ux-reliability-design.md`

## 1. Automatic translation direction and compact sheet

Files:
- `lib/services/translation_repository.dart`
- `lib/shared_pages/translation/in_call_translation_sheet.dart`
- `test/services/translation_repository_test.dart`
- translation widget tests under `test/shared_pages/`

Steps:
1. Add pure RU/EN character-count direction helpers and deterministic fallback.
2. Replace mutable swap state with derived direction from current input.
3. Remove swap/copy UI and clipboard behavior.
4. Reduce input, spacing, action height, result card, and dictionary action.
5. Add unit and widget regression coverage.

## 2. Reliable Gemini structured response

Files:
- `firebase/custom_cloud_functions/call_feedback.js`
- `firebase/custom_cloud_functions/call_feedback.test.js`
- deployment/readiness tests if constants/contracts are asserted there

Steps:
1. Replace SDK `responseSchema` with lowercase literal `responseJsonSchema`.
2. Use validated model-specific thinking config, `maxOutputTokens: 4096`,
   provider timeout 40 seconds, lease 115 seconds, and keep SDK retry attempts
   at 1.
3. Classify finish reason, empty output, parse, validation, transport, and
   provider failures; perform at most one application-level retry.
4. Log safe generation metadata only.
5. Add `generationVersion: 3` to current writes/responses.
6. Transactionally reclaim legacy failed documents once while preserving ready
   and insufficient-text results and daily quota.
7. Cover successful retry, terminal failure, timeout budget, permanent errors,
   migration, and safe logging.

## 3. Shared feedback lifecycle on summary and call details

Files:
- `lib/services/call_feedback_repository.dart`
- `lib/shared_pages/call_summary/call_feedback_card.dart`
- `lib/shared_pages/call_summary/call_summary_widget.dart`
- `lib/shared_pages/call_details/call_details_widget.dart`
- related repository/widget/contract tests

Steps:
1. Parse/expose generation version with legacy default 1.
2. Add summary/details presentation mode for pending copy only.
3. Add one-time guarded automatic recovery invocation for legacy failures.
4. Keep current-version terminal failure final and retryable failures explicit.
5. Mount the card above subtitle logs in call details.
6. Verify pending handoff copy and all final/error states on both surfaces.

## 4. Subtitle toggle visual cleanup

Files:
- `lib/shared_pages/call_details/call_details_widget.dart`
- call-details/contract tests

Steps:
1. Replace the nested transparent Material/Ink/shadow construction with one
   clipped white shaped Material and InkWell.
2. Preserve a 44x44 minimum target, border, labels, alignment, and fade.
3. Assert the old shadow/square artifact cannot regress.

## 5. Validation and delivery

1. Format changed Dart and JavaScript files.
2. Run relevant Flutter unit/widget/contract tests.
3. Run relevant Node Functions tests.
4. Run `flutter analyze` and full `flutter test`.
5. Build iOS simulator if platform code/contracts changed materially.
6. Commit focused implementation changes.
7. Report that `generateCallFeedback` requires deployment; deploy only within
   the user's approved release workflow.
