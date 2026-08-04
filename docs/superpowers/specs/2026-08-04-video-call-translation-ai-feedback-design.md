# Video Call Translation and AI Feedback Design

Status: Approved by user for specification review  
Date: 2026-08-04  
Owner: Product + Engineering

## Summary

Complete the two paused video-call integrations and make them production-ready:

1. quick Russian-English translation from manually entered text during a call;
2. private Gemini feedback after a call based on the authenticated user's own
   `captionLogs`.

Both provider integrations remain server-owned. Flutter calls authenticated
Firebase callable functions and never receives Google credentials. Translation
uses Cloud Translation v3. Feedback uses Gemini through the current Google Gen
AI SDK in Vertex AI mode with Application Default Credentials.

## Goals

- Let a participant enter a short word or phrase without leaving the call and
  receive a Russian-English or English-Russian translation.
- Keep the existing tappable live-caption dictionary flow working.
- Let a user save a translated term to the existing personal dictionary.
- Generate structured, actionable language feedback after a completed call.
- Persist one private feedback result per session and user so reopening the
  summary does not create another paid request.
- Protect provider quota with authentication, App Check, validation, caching,
  idempotency, and per-user limits.
- Keep prompts, concatenated transcripts, raw provider responses, credentials,
  and other users' feedback out of new client-visible documents and server
  logs. Short correction excerpts from the requesting user's own speech are an
  intentional exception described under privacy.

## Non-goals

- Real-time translation of the entire conversation or translated subtitles.
- Sending call audio or video to Translation or Gemini.
- Supporting arbitrary language pairs in the first production release.
- Replacing the existing Yandex Dictionary and Tatoeba vocabulary-detail flow.
- Giving Gemini access to names, email addresses, profile data, balances,
  tokens, private chat messages, or the other participant's caption logs.
- Building an administrator prompt editor or a general-purpose AI chat.

## Current Context

- `MinimalDailyWidget` already receives Deepgram captions and writes caption
  entries under `videoSessions/{sessionId}/captionLogs/{logId}`.
- Tapping a live caption word opens `NewWordWidget`, which currently looks up
  dictionary entries through Yandex Dictionary and examples through Tatoeba.
- `CallDetailsWidget` already displays persisted caption logs.
- `CallSummaryWidget` is the immediate post-call surface but currently contains
  participant actions and a human review form only.
- A previous local `translateTerm` scaffold was implemented and tested, then
  removed when the customer paused the feature on 2026-05-27. Its source is not
  present in the current repository, so the implementation will be recreated
  from the retained contract rather than restored.
- Firebase App Check is not initialized by the Flutter application today.

## Considered Approaches

### Chosen: server-owned callable functions

Use Firebase Functions for provider calls, validation, rate limiting, caching,
and persistence. Cloud Functions runs inside the Google Cloud project and uses
Application Default Credentials for Cloud Translation and Vertex AI.

This keeps credentials and privileged documents off devices, fits the existing
backend, and allows provider use to be authorized against the real session.

### Rejected: direct provider calls from Flutter

Direct Firebase AI Logic or Translation calls would reduce backend code, but
would move quota control and part of the privacy boundary to an untrusted
client. It also conflicts with the already-approved server-owned data model.

### Rejected: a separate Cloud Run service

A dedicated service would provide more runtime isolation but adds deployment,
authentication, monitoring, and operational surface without a current scaling
requirement that Firebase callable functions cannot satisfy.

## Unit 1: Provider and App Check Foundation

### Responsibility

Configure provider clients and ensure only authenticated app instances can use
the new paid callables.

All new callable functions run in `us-central1`, matching the existing default
Functions client. `translateTerm` and `saveTranslatedTerm` use a 15-second
timeout and 256 MB. `generateCallFeedback` uses a 120-second timeout and 512 MB.

### Provider clients

- Add `@google-cloud/translate` to `firebase/custom_cloud_functions` and create
  one reusable Translation v3 `TranslationServiceClient` per warm instance.
- Add the current `@google/genai` SDK and initialize `GoogleGenAI` with
  `vertexai: true`, the Firebase/Google Cloud project ID, and a configurable
  Vertex location.
- Use Application Default Credentials. No Translation or Gemini API key is
  stored in Flutter, Firestore, Remote Config, or source control.
- Read the Gemini model from `GEMINI_FEEDBACK_MODEL`. Use
  `gemini-2.5-flash` as the deployment default, while keeping the value
  configurable so a supported replacement can be rolled out without a Flutter
  release.
- Read the Vertex location from `GEMINI_VERTEX_LOCATION`, defaulting to
  `global` when the deployed SDK/API supports it. Deployment readiness must
  reject an unsupported configured location.

### App Check

- Add the Flutter `firebase_app_check` package.
- Activate Play Integrity on Android and App Attest with DeviceCheck fallback
  on Apple platforms after Firebase initialization and before normal Firebase
  feature use.
- Debug providers are selected only when `kDebugMode` is true. Flutter profile
  and release builds always use production attestation providers.
- Web App Check configuration remains out of the mobile production gate unless
  web deployment of these callables is explicitly enabled.
- The new Translation and Gemini callables set `enforceAppCheck: true`.
- Existing unrelated callables are not switched to enforced App Check in this
  tranche.

### Deployment prerequisites

- Cloud Translation API and Vertex AI API are enabled for the production
  project.
- The Functions runtime service account has the minimum roles required to call
  Translation and Vertex AI.
- Play Integrity, App Attest, and DeviceCheck apps are registered in Firebase
  App Check before enforcing the new callables in production.

## Unit 2: Quick Translation Backend

### Responsibility

Validate, translate, cache, rate-limit, and record one short term or phrase.

### Callable contract

Create `translateTerm` with input:

```json
{
  "text": "Как сказать это?",
  "sourceLang": "ru",
  "targetLang": "en",
  "sessionId": "required-video-session-id"
}
```

Return:

```json
{
  "sourceText": "Как сказать это?",
  "translatedText": "How do I say this?",
  "sourceLang": "ru",
  "targetLang": "en",
  "lookupId": "server-created-id",
  "cacheHit": false
}
```

### Validation and authorization

- Firebase Authentication and a valid App Check token are required.
- `text` must be a string containing 1-250 Unicode characters after trimming.
- Collapse repeated whitespace for provider input and cache identity, but keep
  letter case. `May` and `may` must not share a cache entry.
- The first release allows only `ru -> en` and `en -> ru`.
- `sessionId` is required. The callable verifies that the authenticated user is
  included in the session's trusted participant set and that `status` is
  exactly `connecting`, `connected`, or `active`. Translation after a terminal
  transition is rejected. It never trusts a client-provided participant role.
- Return stable `HttpsError` codes and safe reason values; never expose a raw
  provider error.

### Cache and quota control

- Cache documents use
  `translationCache/{sourceLang}_{targetLang}_{sha256(normalizedText)}` so raw
  text is not present in a document path.
- Cache documents are server-owned and have `pending`, `ready`, or `failed`
  status. A ready document contains source text, translated text, language pair,
  provider, timestamps, and usage count.
- Cache hits increment usage metadata transactionally and do not consume a
  provider-call allowance.
- Cache misses are limited to 30 per authenticated user per UTC day, with at
  least one second between misses. Limits live in server-owned
  `translationRateLimits/{uid}` documents.
- A transaction claims a cache miss by writing a random `leaseId` and a
  15-second `leaseExpiresAt` to the cache document while incrementing the
  user's daily provider-attempt counter. The Translation call happens only
  after that transaction commits.
- A concurrent request that finds a live pending lease returns `aborted` with a
  safe `translation_pending` reason and retry delay. It does not call the
  provider or increment the daily counter. An expired lease can be reclaimed
  transactionally by one request.
- Every acquired lease counts against the daily allowance even when the
  provider times out or fails, because quota or billable work may already have
  occurred. Failure changes the matching lease to `failed` with a safe error
  code and a retry timestamp five seconds later. The provider call has an
  eight-second deadline, leaving time to persist the result before the
  15-second lease expires. It never leaves a permanent pending lock.
- A successful lookup creates
  `users/{uid}/translationLookups/{lookupId}` with the result, language pair,
  required session reference, cache-hit flag, creation time, and initial
  `savedToDictionary: false`.
- Provider timeouts and failures do not write a successful cache or lookup
  record. A stale completion whose lease no longer matches cannot overwrite a
  newer cache attempt.

## Unit 3: In-call Translation UI

### Responsibility

Expose manual translation without coupling provider state to the large Daily
widget.

### Components

- Add a focused `TranslationRepository` that calls `translateTerm`, maps
  callable errors to domain failures, and contains no widget state.
- Add `InCallTranslationSheet`, a compact modal bottom sheet containing:
  - a 250-character multiline input;
  - a visible `Русский -> English` / `English -> Русский` direction control;
  - translate action, loading state, translated result, retryable error state;
  - copy result and save-to-dictionary actions.
- Add one accessible translate control to the in-call overlay. Opening or
  closing the sheet must not end, mute, reconnect, or rebuild the Daily call.
- The sheet receives the current session ID and initial language direction from
  the session language and active app locale.
- Preserve the existing caption-word tap path and its `NewWordWidget` sheet.

### Interaction

- The translate action is disabled for empty text and during an active request.
- Repeated taps cannot start concurrent requests.
- Swapping direction preserves input but clears a result from the old pair.
- Closing the sheet cancels only local presentation updates; a completed
  callable may populate backend cache/history but cannot call `setState` after
  disposal.
- Provider and quota errors use localized, actionable messages.

## Unit 4: Save Translation to Dictionary

### Responsibility

Reuse the personal `userWords` store without requiring another provider call.

### Callable contract

Create `saveTranslatedTerm` with input:

```json
{
  "lookupId": "server-issued-lookup-id",
  "existingWordId": "optional-existing-user-word-id"
}
```

It returns `{ "wordPath": "...", "alreadyExisted": false }`.

### Flow

- Authentication and App Check are required. The callable accepts no source or
  translated text from the client; both values come from the caller's own
  server-written lookup document.
- Normalize the source with Unicode NFC, trim, collapse whitespace, and
  lowercase only for dictionary identity. Store the original case for display.
- New translation-created words use deterministic ID
  `translation_{sha256(sourceLang + "|" + normalizedSourceText)}`. Concurrent
  saves therefore target the same document.
- When the UI has already found a matching legacy word, it may supply
  `existingWordId`. The backend reads that word under the authenticated user and
  accepts it only when its first entry has the same normalized source text, its
  top-level `sourceLanguage` or a legacy `Sentence.lang` matches the lookup's
  normalized source language, and one existing translation matches the
  lookup's normalized translated text. An invalid, foreign, homographic, or
  incompatible word ID is rejected.
- If the deterministic target already exists, validate its `ownerUid`,
  `source`, language pair, normalized source text, entry text, and translated
  text against the lookup before linking it. A mismatched deterministic
  document is treated as a collision and is never overwritten.
- In one Firestore transaction, create the deterministic `userWords` document
  if needed, create its initial `wordReviews` document if absent, and update the
  lookup with `savedToDictionary`, `savedWordRef`, and `savedAt`.
- The word uses the existing `entry: [{text, tr: [{text}]}]` and `Sentence: []`
  shapes. Additional top-level fields are `sourceLanguage`, `targetLanguage`,
  `normalizedSourceText`, `translationLookupRef`, `sessionRef`, `ownerUid`, and
  `source: google_cloud_translation`; existing readers safely ignore them.
- Repeating the callable for an already-saved lookup returns the same word path
  without rewriting content or review scheduling.

## Unit 5: AI Feedback Backend

### Responsibility

Collect eligible speech, claim an idempotent generation attempt, ask Gemini for
structured feedback, validate it, and persist only safe application data.

### Callable contract

Create `generateCallFeedback` with input
`{ "sessionId": "...", "outputLocale": "ru" }`. `outputLocale` accepts only
`ru` or `en` and comes from the active app locale, not a user profile.

Return one of:

- `{ "status": "ready", "feedback": ... }` for an existing or newly generated
  result;
- `{ "status": "pending", "retryAfterMs": 15000 }` during caption settling or
  when another valid generation owns the lease;
- `{ "status": "insufficient_text" }` when the user's transcript is too short;
- `{ "status": "failed_terminal", "errorCode": "..." }` after the retry cap;
- a stable callable error for invalid, unauthorized, rate-limited, or transient
  failures.

### Eligibility and transcript collection

- Authentication and App Check are required.
- The user must be a participant in the requested session.
- Eligible terminal statuses are `ended` and `completed`. `cancelled` or
  `expired` is eligible only when `sessionMetadata.callConnectedAt`,
  `sessionMetadata.callConnectedAtTimestamp`, or
  `sessionMetadata.dailyWebhookConnectedAt` is a valid timestamp and the
  session has `endedAt` or `sessionMetadata.endedAtTimestamp`.
- The resolved terminal timestamp must be no more than 14 days old. Calls older
  than that return `failed-precondition` with `feedback_window_expired`.
- Do not finalize generation until 15 seconds after the trusted terminal
  timestamp. During that settling window return `pending` with `retryAfterMs`
  and do not create an `insufficient_text` result.
- Query at most 200 caption documents with `speakerId == uid`, `writerId ==
  uid`, and `source == local_deepgram_final`, ordered by `createdAtServer`
  descending, then reverse them for chronological prompt order. This exact
  field combination is trusted because existing caption rules require local
  final documents to be written by that same authenticated speaker.
- Exclude diagnostics and empty entries defensively. Local logs are final
  Deepgram utterances, not interim captions. Deduplicate only identical
  `(utteranceId, normalizedText)` pairs; keep the newest trusted document.
- Require at least 80 non-whitespace characters and 20 words. Otherwise persist
  `insufficient_text` without calling Gemini.
- Limit input to 200 caption entries and 15,000 characters, keeping the most
  recent complete entries within both limits.
- Send roles such as `learner`; do not include UIDs, names, emails, session IDs,
  timestamps, profile fields, or the other participant's text in the prompt.

### Idempotency and retry

- Store feedback at `videoSessions/{sessionId}/aiFeedback/{uid}`.
- Use a Firestore transaction to create a generation lease with `status:
  pending`, random `leaseId`, `attemptCount`, `leaseExpiresAt` 130 seconds in
  the future, and timestamps.
- A `ready` or `insufficient_text` document is final and returned without a new
  provider call.
- A live pending lease returns `pending`. An expired lease or `failed` result
  may be retried after 60 seconds, up to three provider attempts.
- Provider attempts are also limited to 10 per user per UTC day across all
  sessions. The transaction that acquires a generation lease increments
  server-owned `aiFeedbackRateLimits/{uid}`. Failed provider attempts count;
  `ready`, `pending`, and `insufficient_text` reads do not.
- A successful generation writes `ready` atomically with the validated result.
- A failed generation stores only a stable `errorCode`, retry timestamp, and
  attempt metadata. Raw provider responses and prompts are never persisted.
- After the third failed provider attempt, persist `status: failed_terminal`.
  Normal clients cannot retry it; only an explicit administrator repair can
  clear the terminal failure.

The feedback document contains only `ownerUid`, `status`, `outputLocale`,
`analyzedLanguage`, validated `result`, `modelId`, `attemptCount`, lease fields,
safe error/retry fields, and server timestamps. Lease fields are removed when a
document becomes final.

### Gemini request and response

- Use one `generateContent` request with a low temperature and
  `responseMimeType: application/json`, a maximum of 2,048 output tokens, and a
  provider timeout bounded by the callable timeout.
- Supply a strict `responseSchema` and validate parsed JSON again on the server.
- Feedback is written in validated `outputLocale`, falling back to Russian. The
  analyzed language comes from the session.
- The persisted result contains:
  - `summary`: short overall assessment;
  - `score`: integer 0-100;
  - `strengths`: 1-3 concise items;
  - `corrections`: 1-7 items with `original`, `better`, and `explanation`;
  - `vocabulary`: 0-7 items with term, translation, and example;
  - `nextPractice`: one concrete exercise.
- `summary`, every strength, every correction field, and `nextPractice` must be
  non-empty. Vocabulary may be empty; when present, all three fields are
  non-empty. `score` must be an integer.
- Exact string limits are: summary 500 characters; each strength 240;
  correction original and better 300 each; correction explanation 500;
  vocabulary term 100, translation 150, and example 300; next practice 500.
- Server validation rejects extra fields at every object level, missing fields,
  invalid scores, control characters, oversized strings, and arrays outside
  their specified lengths.

## Unit 6: Post-call Feedback UI

### Responsibility

Trigger feedback lazily and render its lifecycle without blocking the existing
summary actions.

### Components and flow

- Add `CallFeedbackRepository` for callable invocation and decoding.
- Add a reusable `CallFeedbackCard` with explicit loading, pending, ready,
  insufficient-text, retryable-failure, terminal-failure, and unavailable
  states.
- Mount the card on `CallSummaryWidget` when a valid session reference exists.
- On first mount, read the user's feedback document. If it does not exist, call
  `generateCallFeedback` once. Rebuilds must not create duplicate invocations.
- While pending, listen to the user's feedback document so a completed result
  replaces the progress state.
- Every callable `pending` response carries `retryAfterMs`. The card schedules
  exactly one scope-bound timer and invokes `generateCallFeedback` again after
  that delay, even when the settling response did not create a feedback
  document. A session/user generation token cancels stale timers on scope
  change or disposal. A live feedback-document listener and the timer may race;
  the first ready/final state cancels the timer, and the backend lease keeps a
  duplicate callable from starting another provider request.
- Ready state shows summary, score, strengths, corrections, vocabulary, and the
  next-practice suggestion.
- Suggested vocabulary can be copied. Saving AI-suggested vocabulary is not
  included in this release because it needs a separate trusted dictionary
  contract; translation results remain saveable.
- Feedback loading or failure never blocks review submission, favorite/block
  controls, payment/session information, or leaving the summary screen.

## Unit 7: Firestore Security

### Translation documents

- Clients cannot read, list, create, update, or delete `translationCache` or
  `translationRateLimits` documents.
- Users can read their own `translationLookups`; clients cannot create or alter
  them directly.
- Administrators do not receive a broad client-side list permission for cache,
  rate-limit, or feedback collections.

### AI feedback documents

- A participant can `get` and listen to only
  `videoSessions/{sessionId}/aiFeedback/{theirUid}`.
- Clients cannot write feedback documents or `aiFeedbackRateLimits` documents.
- `aiFeedbackRateLimits` is completely server-owned and not client-readable.
- The other participant cannot read another user's feedback.
- Collection-group listing of AI feedback is denied to normal clients.

### Existing data

- Existing `captionLogs` membership and writer rules remain authoritative.
- Existing user dictionary self-write rules remain in place, with targeted
  validation added only if the new optional metadata requires it.

## Privacy and Retention

- Existing `captionLogs` remain readable by both session participants under the
  current transcript feature. This tranche does not claim that those existing
  documents are backend-only.
- No new document stores a complete Gemini prompt or concatenated transcript.
  `corrections.original` may contain a short excerpt from the requesting user's
  own speech and is readable only by that same user. This is an explicit part of
  the feedback product.
- Translation source/result text is intentionally readable in only the
  requesting user's lookup history and dictionary. It is still excluded from
  server logs.
- `translationCache` documents carry a Firestore TTL field 180 days after last
  use. Translation and feedback rate-limit documents expire after three days.
- Feedback follows the parent session's retention. The new implementation
  extends the existing auth-deletion trigger to delete the removed user's
  translation lookups, rate-limit docs, translation-created dictionary words,
  and `aiFeedback` documents identified by `ownerUid`. This cleanup must finish
  within the policy's existing 30-day deletion window.
- Shared cache entries are not user-owned and expire only through their TTL.

## Error Handling and Observability

- Callables expose stable error categories: invalid input, unauthenticated,
  App Check rejected, permission denied, failed precondition, quota exceeded,
  provider unavailable, and internal validation failure.
- Flutter maps these categories to localized messages and never displays raw
  exception strings.
- Structured server logs may include function name, status, latency, cache hit,
  model ID, attempt count, and hashed session/lookup correlation values.
- Logs must not include translation source text, translated text, transcript,
  prompt, Gemini response, names, emails, UIDs, or provider credentials.
- Provider calls use bounded timeouts. Translation remains retryable from the
  sheet; feedback follows the persisted lease/retry policy.

## Feature Flags and Rollback

- `ENABLE_CALL_TRANSLATION` and `ENABLE_CALL_FEEDBACK` backend parameters
  default to false until production prerequisites pass. Disabled callables
  return `failed-precondition` with a stable `feature_disabled` reason before
  any provider or Firestore work.
- Flutter has matching compile-time UI flags, enabled for internal validation
  only after backend deployment. Production release enables them after App
  Check verification.
- Turning off a backend flag immediately stops new paid calls. Existing private
  feedback and lookup documents remain readable. Hiding controls from an
  already-released client is not required for cost rollback because disabled
  callables are authoritative.

## Testing

### Backend unit tests

- Translation input and language-pair validation.
- Case-sensitive hashed cache identity and cache reuse.
- Cache-miss daily limit and cooldown.
- Required session membership and active-status enforcement.
- Lookup creation, legacy-word compatibility validation, deterministic-word
  collision rejection, and idempotent transactional dictionary save.
- Caption filtering, ordering, final-utterance deduplication, minimum text, and
  input truncation.
- Terminal-state eligibility, 14-day window, and 15-second caption settling.
- Feedback lease acquisition, pending handling, expiry, retry cap, and final
  result reuse.
- Per-user Translation and Gemini daily provider-attempt limits.
- Strict Gemini response validation with fake Translation and Gemini clients;
  unit tests never call live providers.

### Firestore emulator tests

- Cache and rate-limit collections are completely server-owned.
- A user reads only their own translation history and feedback.
- Cross-user feedback access and all client feedback writes are denied.
- Existing caption and user-word rules remain passing.
- Account-deletion cleanup removes only the deleted user's new private data.

### Flutter tests

- Translation sheet validation, direction swap, loading, success, copy, save,
  quota, error, and disposal behavior.
- In-call translate control semantics and no interference with Daily controls.
- Feedback card pending, ready, insufficient, failed, and retry states.
- Call-summary rebuilds invoke generation at most once per session/user scope.
- A settling-window pending response schedules one retry; disposal, a final
  snapshot, or a session/user scope change cancels it.
- Existing caption-word dictionary, call-summary actions, and call-details
  transcript tests remain passing.

### Required validation

- `dart format` on changed Dart files.
- `node --check` and targeted Node tests.
- Firestore emulator rules tests.
- `flutter analyze`.
- Targeted Flutter tests, followed by full `flutter test`.
- Deployment-readiness and secret/readiness tests.
- Add and validate the `captionLogs` composite index for `speakerId`,
  `writerId`, `source`, and descending `createdAtServer`. No unbounded caption
  query is permitted if the index is missing.
- `npm audit --omit=dev` results are recorded; broad dependency upgrades remain
  a separate change unless a new dependency introduces a fixable blocker.

## Production Rollout

1. Enable Translation and Vertex AI APIs and grant minimum service-account IAM.
2. Register production Apple and Android apps with App Check.
3. Deploy Firestore rules and backend callables before shipping Flutter UI.
4. Validate callables with production App Check tokens on internal builds.
5. Ship the Flutter release to internal/TestFlight tracks.
6. Run a real bilingual call and verify translation cache miss/hit, dictionary
   save, transcript persistence, feedback generation, retry, and private reads.
7. Inspect quota, error rate, latency, and provider cost before broad rollout.
8. Roll back immediately by setting both backend enable parameters to false.
   This stops provider spend for already-released clients while keeping
   persisted private results readable. Disable the compile-time UI flags in the
   next mobile release if the controls also need to disappear.

## Acceptance Criteria

- A signed-in production app user can translate a valid Russian or English term
  during an active call without interrupting media.
- The same user can save that result once to their personal dictionary.
- Invalid clients, unauthenticated callers, nonparticipants, and cross-user
  readers cannot use or access the new resources.
- A completed call with sufficient user captions produces exactly one valid,
  private Gemini feedback result and reuses it on subsequent opens.
- Short calls show the explicit insufficient-text state without a Gemini call.
- Translation and feedback failures are retryable according to their policies
  and never block existing call-summary actions.
- All automated checks pass, and real-device production-provider QA is recorded
  before broad release.
