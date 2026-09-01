# Mobile crash reporting and safe error boundary

## Decision

Use Firebase Crashlytics as the single mobile provider because the application
already uses Firebase on iOS and Android. Web and unit tests use a no-op adapter;
adding a second cross-platform provider is out of scope. Existing localized UI
fallbacks remain unchanged.

## Boundaries

`ErrorReporter` is the injectable application-facing contract. Callers provide
only a typed feature, typed error code, a trusted VM `StackTrace`, and optional
session ID. `error_type` is a fixed property of the error-code enum, not a
caller value or `runtimeType`. Arbitrary metadata, reason, information,
exception text and externally supplied stack strings are not accepted.

Before calling Crashlytics the adapter builds an allow-listed payload:

- `environment`, `feature`, `error_code`, `error_type` from fixed enums;
- `session_hash`, the lowercase 64-character SHA-256 hex digest of UTF-8 bytes
  from the trimmed session ID, or the empty string when absent;
- a safe synthetic exception whose title is fixed for the
  `(feature, error_code, error_type)` tuple, never the original exception text,
  session hash or SDK/backend payload;
- the original stack trace.

Crashlytics already attaches the native app version/build; it is not duplicated
as a caller-supplied custom key. Raw session/user IDs, room URLs, tokens,
captions, transcript/text, email,
name/photo/profile and request/response payloads are forbidden. The reporter
must swallow its own failures and must not block call completion or UI error
handling. The deterministic session digest is pseudonymous, not anonymous.
Backend correlation uses the exact same trim → UTF-8 → SHA-256 → lowercase-hex
procedure and never logs the raw ID next to the digest.

Crashlytics custom keys are process-persistent and can race across Dart isolates,
so event-specific data is **not** stored in custom keys. Fixed feature/code/type
are embedded in the safe synthetic exception and fixed `reason`; optional
session hash exists only in per-event `information` passed to `recordError`. The only
custom key is the static app environment, set once to the same value by every
isolate. This avoids main/background-isolate metadata bleed.

## Bootstrap

Install a bounded, in-memory safe-report queue immediately after Flutter binding
initialization, before background registration and early CallKit handling. It
keeps at most 20 already-sanitized reports and never blocks. After Firebase
initialization, attach the mobile Crashlytics sink and flush the queue in order
using fire-and-forget work. Each sink operation has a short timeout and isolates
its own error; `runApp`, CallKit and FCM handler completion never await the queue.
If Firebase initialization fails, the existing Flutter presentation still runs;
the bounded queue remains local because no remote provider can be initialized.

Install one global boundary exactly once per isolate:

- `FlutterError.onError` first calls the previously installed handler (or
  `FlutterError.presentError`) and then enqueues a fatal report;
- `PlatformDispatcher.instance.onError` calls the previous handler when present,
  then enqueues a fatal report and returns `true` as the owning boundary;
- installer tests restore both previous global handlers in teardown;
- the background FCM entry point creates its own isolate-local boundary before
  Firebase initialization, attaches the mobile sink after initialization and
  uses non-blocking bounded reporting compatible with handler completion;
- early CallKit handling is not delayed and is covered by the bootstrap queue.

Crashlytics is not imported or instantiated on Web: conditional imports select
the no-op sink. Tests inject a fake sink and reporter. No production test-crash
button is shipped.

## Initial adoption

Add non-fatal reporting only at five exact boundaries:

1. `main.dart::_initializeVoipService` — `voip_initialize_failed`;
2. `main.dart::_refreshAuthUserOnResume` — `auth_refresh_failed`;
3. `SubscriptionService::_purchase` — `purchase_failed`; no report for the
   explicit RevenueCat states `purchaseCancelledError`, `paymentPendingError`,
   `operationAlreadyInProgressError`, `purchaseNotAllowedError` and
   `productAlreadyPurchasedError`. Every other purchase error, including
   network/offline/API-blocked/store/configuration failures, is reported and the
   exception is still rethrown to existing UI;
4. `InCallTranslationSheet::_translate` — only invalid server response and
   unexpected exceptions (`translation_invalid_response` /
   `translation_unexpected`);
5. `CallFeedbackCard::_invoke` — only invalid response and unexpected exceptions
   (`ai_feedback_invalid_response` / `ai_feedback_unexpected`).

Each catch captures `(error, stack)` before converting to the existing fallback.
Normal cancellation, invalid credentials, translation/AI provider failures
already classified as retryable for the user, and pending/cooldown/retry states
are not reported. Purchase exclusions are exactly the five codes above; other
purchase provider failures are an actionable availability signal. Catalog loading remains ordinary UI fallback and is not
mislabelled as a purchase failure. User-facing copy, retry behavior, control flow and return/error
shapes stay unchanged. A broad replacement of `debugPrint` and PII logging
belongs to P2-04.

## Platform setup

Pin `firebase_crashlytics: 4.3.7`, compatible with the existing
`firebase_core: 3.14.0`; do not take the v5/native SDK upgrade in this task.
Android uses `com.google.firebase.crashlytics` Gradle plugin `3.0.8` and upgrades
Google Services from `4.3.8` to `4.5.0` as required by plugin v3. Apply both
plugins in the app module.

iOS links Crashlytics through CocoaPods and adds the official final Xcode build
phase `[firebase_crashlytics] Crashlytics Upload Symbols`. The phase uses the
Firebase `upload-symbols` tool and includes the Xcode 15 dSYM, Info.plist,
GoogleService-Info.plist and executable input paths. Do not run an interactive
`flutterfire configure` against a remote project in this task. If the checked-in
project cannot safely reproduce the generated phase, mark iOS symbol upload as
an explicit release blocker instead of claiming it works.

## Tests and validation

- Unit tests for fixed-enum payload and type mapping, canonical stable session
  hash, safe synthetic exception/reason/per-event information, absence of
  event-specific persistent keys, and reporter failure isolation.
- Boundary tests for framework/dispatcher delegation and no-op behavior.
- Existing UI tests confirm localized fallbacks do not expose raw exceptions.
- `flutter analyze`, complete Flutter tests, Android debug build, and pod/native
  dependency resolution when available.

The Firebase dashboard cannot be proven locally. Each fixed synthetic exception
title maps to an owner in the runbook and is used for issue navigation/search;
`feature` and `error_code` are not claimed as Crashlytics filter dimensions.
The optional session hash is read from an individual event's information and is
not filterable. Release completion requires a
physical Android/iOS test crash and non-fatal event, reopening the app so queued
non-fatals can upload, allowing dashboard processing latency, and verifying
symbols/dSYMs. Ownership comes from the backlog owner table, not an inferred
Crashlytics “error rate”.
Analytics breadcrumbs are not claimed because current Apple configuration has
Analytics disabled. Until device/dashboard verification, P1-05 is locally
implemented but its external release smoke remains explicitly open.

## Rollback

Remove the reporter installation and Crashlytics adapter/plugin while retaining
the typed redaction tests and existing UI fallbacks. No schema or data migration
is involved.
