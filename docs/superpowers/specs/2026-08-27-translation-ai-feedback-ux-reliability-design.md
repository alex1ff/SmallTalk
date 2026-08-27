# Compact Translation and Reliable AI Feedback Design

Status: Approved by user for specification review  
Date: 2026-08-27  
Owner: Product + Engineering

## Summary

Polish the in-call Russian-English translator, make post-call AI feedback
reliable, and expose the same persisted feedback on the call-details page.

The translator will infer direction from the entered text, remove the explicit
copy and language-swap controls, and use a denser layout. AI feedback will keep
generating after the user leaves the immediate summary, clearly explain where
the result will appear, and render above subtitle logs in call details. The
subtitle expand/collapse control will lose its unintended square background.

## Confirmed Production Diagnosis

Firebase Function logs from 2026-08-26 show valid authentication and App Check
for both integrations. Translation succeeds in roughly 2.1–2.7 seconds.

AI feedback reaches Vertex AI, but the provider path fails after generation
with `SyntaxError`. The current implementation calls
`JSON.parse(safeJsonText(response))`, so this error proves that Gemini returned
text that was not complete valid JSON. The first failure stores a retry delay;
subsequent UI retries then return `503` and eventually reach the per-session
terminal attempt limit.

The deployed Functions package uses `@google/genai` 2.15.0 and the older
`responseSchema` field. Current SDK guidance prefers `responseJsonSchema`, and
the model's thinking output is not needed for this structured, concise task.

## Goals

- Reduce the vertical footprint of the translation sheet.
- Automatically translate Russian input to English and English input to
  Russian.
- Remove the language-swap and explicit copy controls.
- Keep saving a translation to the personal dictionary, with a compact action.
- Make structured Gemini feedback succeed reliably without exposing transcript
  text in logs.
- Let users leave the summary while feedback is processing.
- Show the persisted AI feedback above subtitle logs in call details.
- Recover sessions that were terminally failed by the previous broken
  generation format.
- Remove the gray square/shadow behind the subtitle show/hide control.

## Non-goals

- Automatic translation of live subtitles or audio.
- Supporting language pairs other than Russian and English.
- Replacing Cloud Translation or Vertex AI.
- Adding a general AI chat, notifications, background push delivery, or a new
  job-queue service.
- Optimizing the current 2–3 second Cloud Translation provider latency.
- Changing App Check, which is now valid in production.

## Considered Approaches

### Chosen: focused UI changes plus resilient existing callable

Keep the current callable/Firestore architecture. Improve structured generation
inside `generateCallFeedback`, reuse `CallFeedbackCard` on both post-call
surfaces, and keep Firestore as the durable handoff when a user leaves.

This is the smallest change that solves the observed production failure and
the requested UX without adding infrastructure.

### Rejected: UI-only changes

This would make the screens cleaner but leave the confirmed Gemini JSON parsing
failure unresolved.

### Rejected: background queue or Cloud Tasks pipeline

A queue could provide more operational controls, but the existing callable
already continues after the client leaves and persists results. A new queue is
unnecessary for the current traffic and reliability requirement.

## Unit 1: Automatic Translation Direction

### Responsibility

Resolve one of the two allowed language directions from the current input
without mutable swap state.

### Interface

Add a pure helper that accepts text and a fallback source language, and returns
`TranslationLanguage.russian` or `TranslationLanguage.english`.

### Rules

- Count Cyrillic letters, including `Ё/ё`, and basic Latin letters.
- More Cyrillic letters selects Russian to English.
- More Latin letters selects English to Russian.
- A tie or text without letters uses the initial fallback derived from the
  practiced language and app locale.
- Detection updates the visible direction label while typing.
- Submission recomputes direction from the final trimmed text so the label and
  request cannot diverge.
- Mixed punctuation, numbers, emoji, and whitespace do not affect counts.

## Unit 2: Compact Translation Sheet

### Responsibility

Present the existing manual translation flow with less visual weight.

### Layout and interaction

- Keep the title and a read-only direction label.
- Remove the swap icon and `_swapLanguages` state transition.
- Change the input to one initial line and at most three lines.
- Keep the 250-character backend limit but hide the persistent character
  counter unless the framework needs to show a validation error.
- Use compact vertical spacing and a 44–48 point translate action.
- Keep a visible loading state and block concurrent requests.
- Remove the explicit Copy button and its snackbar. The translated text remains
  selectable, so normal platform text selection is still available.
- Render the result in a compact row/card with the translated text taking the
  remaining width and one small `В словарь` / `Save` action.
- Preserve saved/loading/error states and the trusted server-issued `lookupId`
  dictionary flow.

## Unit 3: Reliable Structured AI Generation

### Responsibility

Produce one validated feedback object per user/session even when the first
model response is malformed or truncated.

### Provider configuration

- Replace `responseSchema` with `responseJsonSchema` while retaining
  `responseMimeType: application/json`.
- Disable Gemini 2.5 thinking for this task with a zero thinking budget.
- Increase the structured response token allowance to leave adequate room for
  the complete object.
- Keep temperature low and the existing strict result validator.
- Require a normal completion/finish reason before parsing when that metadata
  is available.

### Parsing and retry

- Trim `response.text` and parse it as JSON.
- Do not heuristically invent or repair missing fields.
- If parsing or result validation fails, make exactly one internal provider
  retry with the same schema and a concise reminder to return only the schema.
- Both provider calls belong to one logical user/session attempt and one
  Firestore lease. The internal retry does not increment the user-facing daily
  or session attempt counters again.
- If the second response fails, preserve the existing retryable/terminal error
  behavior.
- Log only safe metadata: error type, attempt number, response character count,
  and finish reason. Never log response text, prompts, or transcript content.

### Recovery of already failed sessions

Introduce a generation format/version on feedback documents.

- Existing `ready` feedback remains reusable regardless of version.
- A missing/older version with `failed` or `failed_terminal` may be reclaimed
  once by the new implementation instead of remaining permanently broken.
- The reclaimed attempt writes the current generation version and resets only
  the per-session generation state needed for the new format.
- Daily quota protection remains in force.
- New `pending`, `ready`, and failure writes carry the current generation
  version.

## Unit 4: Shared Feedback Presentation and Durable Handoff

### Responsibility

Use the persisted feedback result on both the immediate summary and call
details without making the user wait on either page.

### Immediate post-call summary

- Mounting the feedback card continues to start generation when no result
  exists.
- Pending copy states that the analysis is being prepared and can be viewed
  later in call information.
- Leaving the page does not cancel the Cloud Function or delete its Firestore
  lease/result.
- Short transcripts show the existing insufficient-text state as an expected
  outcome, not a generic error.

### Call details

- Place `CallFeedbackCard` above the subtitle-log section.
- The card watches the same private
  `videoSessions/{sessionId}/aiFeedback/{uid}` document.
- If no document exists, it may start generation; if one is pending, it keeps
  watching; if ready, it renders the persisted result; if retryable, it exposes
  the existing retry action.
- Pending copy on this page says that the result will appear here, rather than
  directing the user to another screen.

Add a small presentation enum/parameter to the shared card instead of
duplicating its state machine.

## Unit 5: Subtitle Toggle Visual Fix

### Responsibility

Keep the existing expand/collapse behavior while removing the square gray
artifact visible behind the rounded button.

### Change

- Replace the transparent `Material` plus decorated `Ink` and shadow with one
  shaped, clipped `Material` and `InkWell`.
- Use the white card color, rounded border, and no box shadow.
- Preserve the minimum touch target, centered placement, labels, and collapsed
  fade over the next subtitle item.
- Ensure the fade is not used as the button's own background.

## Error Handling

- Translation preserves localized quota, session, auth, App Check, pending,
  disabled, and network messages.
- AI pending is not an error and never blocks navigation.
- Insufficient speech is a terminal informational state.
- Malformed Gemini output is retried once internally and is never shown raw.
- Firestore watch failures and true provider failures keep the existing safe
  localized retry surfaces.

## Testing

### Flutter

- Unit-test automatic direction detection for Russian, English, mixed text,
  punctuation/numbers, ties, and fallback behavior.
- Widget-test the compact sheet, absence of swap/copy controls, dynamic
  direction label, compact dictionary action, loading, result, and save states.
- Widget-test summary and details pending copy independently.
- Verify `CallFeedbackCard` is placed before subtitle logs in call details.
- Verify ready, insufficient, retryable, and terminal feedback states remain
  usable from both placements.
- Widget/contract-test the show/hide button shape and absence of its old shadow
  or square decoration.

### Functions

- Test valid structured output on the first attempt.
- Test malformed JSON followed by valid JSON on the internal retry.
- Test validation failure followed by valid JSON.
- Test two malformed responses produce the expected safe failure.
- Assert internal retry does not double-count the logical user attempt.
- Test current-version failure cooldown and terminal limits.
- Test migration/reclaim of old failed and failed-terminal documents.
- Test that ready documents from older versions are still reused.
- Test safe diagnostic metadata without model or transcript text.

### Validation commands

- `flutter analyze`
- Relevant translation, feedback, call-details, and call-summary Flutter tests
- Relevant Node test suites for translation and call feedback
- `flutter test`

## Deployment and Verification

- Deploy the updated `generateCallFeedback` function and any other changed
  callable in the same codebase.
- Install a new Flutter build for the UI changes.
- Run a physical-iPhone smoke test with enough captured speech for feedback.
- Confirm live logs show valid App Check/auth, successful provider completion,
  and no response content.
- Confirm the result is visible after leaving the summary and reopening call
  details.

