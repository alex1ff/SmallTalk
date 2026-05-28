# Video Call AI Features Tasks

Last updated: 2026-05-27

## Scope

Customer decision on 2026-05-27: feature work is paused. Do not continue quick translation or AI feedback until the customer re-approves the scope.

Original requested integrations over the current video-call flow:

1. Быстрый перевод во время звонка.
2. AI-обратная связь после звонка по `captionLogs`.

Проект больше не требует совместимости с FlutterFlow regeneration. Former FlutterFlow files можно менять, если это самый безопасный и узкий фикс.

## Working Mode

- Брать одну задачу за раз.
- После каждой задачи обновлять этот файл.
- Если задача трогает video-call security, Functions, Firestore rules, tokens, captions или session data - обновлять также текущие audit docs:
  - `docs/project-audit-prd.md`
  - `docs/project-audit-status.tsv`
  - `docs/project-audit-next-steps.md`
  - `docs/video-call-review-status.tsv`
  - `docs/video-call-review-bugs.tsv`
  - `docs/video-call-review-tasks.md`
  - `docs/project-audit-inventory.tsv`
- После code/docs edits запускать reviewer gate:
  - code/regression reviewer
  - tests/docs reviewer
  - auth/data-exposure reviewer для backend, rules, AI, captions, tokens, sessions
- Не деплоить production, пока открыт `VC-BUG-026`.

## Feature Counters

- feature_tranche_id: AIF-FREEZE-001
- feature_review_round: 23
- feature_tasks_total: 9
- feature_tasks_done: 0
- feature_tasks_open: 0
- feature_tasks_paused: 9
- blockers_open: 1

## Current Blockers

- `VC-BUG-026`: production secrets/deploy readiness blocker. Не блокирует локальную разработку, но блокирует production validation.
- Runtime dependency audit has existing critical/high findings in the Functions dependency tree, mostly through the current `firebase-admin`/Firestore stack and `axios`. Do not run broad breaking upgrades inside feature tranches; plan a focused dependency-hardening tranche.
- Provider setup for Translation/Gemini is no longer needed while this feature set is paused.

## Runtime Freeze State

- No Flutter UI was added.
- `MinimalDailyWidget` does not call translation or feedback code.
- `translateTerm` is not exported from Functions.
- `translateTerm` is not included in the scoped deploy script or deployment readiness validator.
- `@google-cloud/translate` was removed from `firebase/custom_cloud_functions` dependencies.
- Translation-specific Firestore rules were removed and the previous admin fallback read behavior was restored.
- The old AIF implementation notes below are retained only as history for a future restart.

## Design Decisions

- Flutter не вызывает Google Translation или Gemini напрямую.
- `translateTerm` and `generateCallFeedback` are server-owned callable/background paths.
- Translation cache doc id should not contain raw user text. Use a deterministic hash key:
  - `translationCache/{sourceLang}_{targetLang}_{sha256(normalizedText)}`
- Store raw `sourceText` inside server-owned cache doc only if rules block client reads.
- `users/{uid}/translationLookups/{lookupId}` is user-owned read history, written by backend callable.
- `videoSessions/{sessionId}/aiFeedback/{uid}` is backend-owned; participants can read only their own feedback.
- Do not send names, emails, balances, tokens, or private profile fields to AI. Use roles like `student` and `tutor`.
- Hard limits:
  - translate input: small phrase only, target 1-250 chars for MVP
  - feedback input: max caption logs and max chars, target 12-15k chars
  - one feedback generation per session per user unless admin/debug path is added later

## Task Queue

### AIF-TR-001 - Backend Quick Translate Callable

Status: paused and removed from runtime

Goal: add `translateTerm` callable with cache and lookup logging.

Files likely touched:
- `firebase/custom_cloud_functions/translate_term.js`
- `firebase/custom_cloud_functions/index.js`
- `firebase/custom_cloud_functions/package.json`
- `firebase/custom_cloud_functions/*translation*.test.js`
- `firebase/custom_cloud_functions/scripts/validate_deployment_readiness.js`
- `firebase/custom_cloud_functions/deployment_readiness.test.js`
- `firebase/firestore.rules`

Requirements:
- Auth required.
- Allow only `ru -> en` and `en -> ru` initially.
- Validate `sourceLang`, `targetLang`, and text length.
- Normalize text for cache lookup.
- Use server-side Google Cloud Translation v3.
- Cache repeated translations in `translationCache`.
- Increment `usageCount` without exposing raw provider keys.
- Write `users/{uid}/translationLookups/{lookupId}`.
- Rules: clients cannot write `translationCache`; users can read own lookup history only.

Validation:
- `node --check`
- targeted Node tests with fake Translation client
- Firestore rules emulator tests if rules change
- no Flutter validation unless Dart files change

Completed in this tranche:
- Added `translateTerm` callable export.
- Added `translateTerm` to the scoped readiness deploy target list and deployment readiness validator.
- Added server-side Google Cloud Translation v3 SDK dependency.
- Added deterministic, case-sensitive hash cache key so raw user text is not embedded in document ids and `May`/`may` do not collide.
- Added per-user daily provider-call limit and cooldown for cache misses.
- Added `translationCache` and `translationRateLimits` server-owned rules, including exclusion from the admin client fallback read.
- Changed the catch-all admin fallback to `allow get` only so cache/rate-limit collection listing is denied.
- Added own-read/admin-write `users/{uid}/translationLookups` rules.
- Added fake-provider tests for validation, cache reuse, case-sensitive keys, provider-call rate limiting, lookup writes, and optional session ownership.
- Added Firestore rules tests for cache/rate-limit/lookup access.

Validation run:
- `node --check` on touched Functions/test files: passed.
- `node --test firebase/custom_cloud_functions/translate_term.test.js`: passed with Firestore behavior skipped without emulator.
- `node --test firebase/custom_cloud_functions/public_user_profiles.test.js firebase/custom_cloud_functions/voip_token_privacy_contracts.test.js`: passed 11/11.
- `node --test firebase/custom_cloud_functions/deployment_readiness.test.js`: passed 6/6.
- `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-smalltalk GOOGLE_CLOUD_PROJECT=demo-smalltalk node --test --test-concurrency=1 firebase/custom_cloud_functions/translate_term.test.js firebase/custom_cloud_functions/user_document_rules.test.js`: passed 21/21 on the already-running Firestore emulator.
- `firebase emulators:exec --project demo-smalltalk --config firebase/firebase.json --only firestore "node --test firebase/custom_cloud_functions/translate_term.test.js firebase/custom_cloud_functions/user_document_rules.test.js"`: could not start because port 8080 was already occupied by the existing Firestore emulator; rerun above used that emulator directly.
- `npm --prefix firebase/custom_cloud_functions audit --omit=dev --audit-level=critical`: failed on existing dependency debt; deferred to dependency-hardening tranche because fixes require broad/breaking dependency upgrades.

Reviewer findings accepted/fixed:
- P1 readiness: added `translateTerm` to the scoped readiness deploy target list and deployment readiness validator.
- P2 correctness: cache key normalization is now case-sensitive so `May` and `may` do not collide.
- P2 privacy: `translationCache` and `translationRateLimits` are server-owned and excluded from admin fallback document reads.
- P2 cost/control: cache misses now have per-user daily provider-call limit and cooldown.
- P2 privacy: admin catch-all fallback is get-only, so cache/rate-limit collection listing is denied.
- Final reviewer gate: code/regression, docs/tests, and auth/data-exposure reviewers found no remaining P0-P2 blockers.

Paused/freeze update:
- Customer paused the feature set before UI integration.
- Removed `translateTerm` export from `index.js`.
- Removed `translateTerm` from the scoped deploy script and deployment readiness validator.
- Removed `@google-cloud/translate` dependency and lockfile entries.
- Deleted the local `translate_term.js` and `translate_term.test.js` runtime scaffold.
- Removed translation-specific Firestore rules/tests and restored the catch-all admin fallback to `allow read`.

Freeze validation run:
- `node --check` on touched Functions/test files: passed.
- `node --test firebase/custom_cloud_functions/deployment_readiness.test.js firebase/custom_cloud_functions/secret_readiness.test.js`: passed 15/15.
- `node --test firebase/custom_cloud_functions/email_verification.test.js firebase/custom_cloud_functions/submit_review.test.js`: passed 14/14.
- `node --test firebase/custom_cloud_functions/public_user_profiles.test.js firebase/custom_cloud_functions/voip_token_privacy_contracts.test.js`: passed 11/11.
- `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-smalltalk GOOGLE_CLOUD_PROJECT=demo-smalltalk node --test firebase/custom_cloud_functions/user_document_rules.test.js`: passed 14/14 on the already-running Firestore emulator.
- `flutter analyze`: skipped because no Flutter/Dart code changed.
- Accepted reviewer fixes: added existing UI-used `sendCustomEmailVerification` and `submitReview` to deploy/readiness coverage, bound `sendCustomEmailVerification` to `RESEND_API_KEY` via `runWith` and secret readiness, removed unrelated lockfile churn, and corrected the docs ledger mismatch.

### AIF-TR-002 - Quick Translate UI In Call Overlay

Status: paused by customer

Goal: add translate button and compact bottom sheet inside `MinimalDailyWidget`.

Files likely touched:
- `lib/custom_code/widgets/minimal_daily_widget.dart`
- `test/regression/voip_call_surface_contracts_test.dart`

Requirements:
- Button in call overlay with tooltip/semantic label.
- Bottom sheet: input, language pair selector/label, result, loading/error states.
- Calls `translateTerm` only through Firebase callable.
- `mounted` checks after async calls.
- No heavy logic in `build`.
- Does not interrupt Daily media controls.

Validation:
- `dart format`
- targeted `flutter analyze`
- targeted Flutter contract/widget tests where feasible

### AIF-TR-003 - Save Translation To Dictionary

Status: paused by customer

Goal: allow translated result to be saved to existing user dictionary.

Files likely touched:
- existing `NewWordWidget` or adapter/helper around it
- `lib/custom_code/widgets/minimal_daily_widget.dart`
- `lib/backend/schema/user_words_record.dart` if needed
- relevant Flutter tests

Requirements:
- Reuse or adapt existing dictionary write path.
- Save source phrase, translated word/phrase, language pair, session id.
- Attach nearest caption context when available.
- Avoid duplicate words where existing project patterns support it.
- Update `translationLookups.savedToDictionary`.

Validation:
- `flutter analyze`
- targeted Flutter tests
- rules/backend tests if write path changes

### AIF-TR-004 - AI Feedback Contract And Caption Collector

Status: paused by customer

Goal: create backend helpers for feedback eligibility before adding Gemini.

Files likely touched:
- `firebase/custom_cloud_functions/call_feedback.js`
- `firebase/custom_cloud_functions/*feedback*.test.js`

Requirements:
- Input: `sessionId`.
- Verify auth user is session participant.
- Collect `videoSessions/{sessionId}/captionLogs`.
- Filter only user's own speech.
- Return `insufficient_text` without calling AI when logs are too small.
- Redact names/private identifiers into `student` / `tutor`.
- Truncate by max logs and max chars.

Validation:
- `node --check`
- helper/unit tests
- emulator test if reading real Firestore paths

### AIF-TR-005 - Gemini Feedback Generation

Status: paused by customer

Goal: generate and persist structured feedback JSON.

Files likely touched:
- `firebase/custom_cloud_functions/call_feedback.js`
- `firebase/custom_cloud_functions/index.js`
- `firebase/custom_cloud_functions/package.json`
- `firebase/custom_cloud_functions/*feedback*.test.js`

Requirements:
- Callable or callable-triggered background flow: `generateCallFeedback`.
- Status lifecycle: `pending`, `ready`, `failed`.
- Strict JSON schema validation server-side.
- Configurable model id through env/secret/config.
- Rate limit: one generation per session/user.
- Store errors as `errorCode`, not raw provider response.
- Tests use fake Gemini client; no live AI call in unit tests.

Validation:
- `node --check`
- targeted Node tests
- secret/readiness docs updated if new secret is required

### AIF-TR-006 - AI Feedback Firestore Rules

Status: paused by customer

Goal: lock down `videoSessions/{sessionId}/aiFeedback/{uid}`.

Files likely touched:
- `firebase/firestore.rules`
- Firestore rules tests

Requirements:
- Participants can read their own feedback.
- Clients cannot write feedback docs.
- Admin/backend owns writes.
- No broad read exposure of feedback across users.

Validation:
- Firestore emulator rules tests

### AIF-TR-007 - Post Call Feedback UI

Status: paused by customer

Goal: show feedback block on call summary/result screen.

Files likely touched:
- `lib/shared_pages/call_summary/call_summary_widget.dart`
- `lib/shared_pages/call_summary/call_summary_model.dart`
- Flutter tests

Requirements:
- Show "Разбор звонка" block.
- Loading/skeleton while pending.
- Ready state: summary, score, 3-7 corrections, vocabulary, next practice.
- Failed/insufficient text state.
- Button to add suggested words to dictionary.
- Does not block existing review/payment/session summary flow.

Validation:
- `dart format`
- targeted `flutter analyze`
- targeted Flutter tests

### AIF-TR-008 - EndSession Or Lazy Trigger Wiring

Status: paused by customer

Goal: decide and wire generation trigger safely.

Options:
- Lazy callable from call summary if feedback missing.
- Backend trigger after trusted `endSession`.

Recommendation for MVP:
- Lazy callable from call summary first. Lower blast radius and easier retry/error UX.

Validation:
- targeted backend and Flutter tests depending on chosen path

### AIF-TR-009 - Production Readiness And Manual QA

Status: paused by customer

Goal: validate real provider integration after secrets and deployment blockers are closed.

Requirements:
- Secret readiness includes Gemini/Translation config if needed.
- Deployment readiness includes new Functions.
- Manual call with captions.
- Test quick translation in-call.
- Test post-call feedback ready/failed/insufficient-text states.
- Confirm provider cost/rate limits are acceptable.

Validation:
- backend tests
- `flutter analyze`
- manual mobile QA
- production gates after `VC-BUG-026` is fixed

## Next Recommended Task

None for this feature set.

Reason: customer paused quick translation and AI feedback. Resume only after explicit re-approval.

## Reference Docs

- Google Cloud Translation v3 `translateText`: https://cloud.google.com/translate/docs/reference/rest/v3/projects/translateText
- Google Cloud Translation advanced translate text: https://docs.cloud.google.com/translate/docs/advanced/translating-text-v3
- Gemini structured output: https://ai.google.dev/gemini-api/docs/structured-output
- Gemini models: https://ai.google.dev/models/gemini
- Firestore transactions: https://firebase.google.com/docs/firestore/manage-data/transactions
- Firebase Functions secrets: https://firebase.google.com/docs/functions/config-env
