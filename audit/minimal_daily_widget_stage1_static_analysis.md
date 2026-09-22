# MinimalDailyWidget Stage 1 Static Analysis

- Date: `2026-03-06`
- Status: `Completed`
- Working widget changed: `No`
- Scope:
  - `lib/custom_code/widgets/minimal_daily_widget.dart`
  - `lib/shared_pages/video_call_page/video_call_page_widget.dart`
  - `lib/services/voip_service.dart`

## Commands Executed

```bash
flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart
diff -u lib/custom_code/widgets/minimal_daily_widget.dart audit/snapshots/minimal_daily_widget_snapshot_20260306.dart.txt
python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/daily_co_reference_flutter" "CallClient join updatePublishing updateSubscriptions InputSettingsUpdate ParticipantId VideoViewController setTrack dispose" --tokens 5000
python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/daily_co_reference_flutter" "VideoViewController setTrack track no longer exists dispose controller attached to streams individually disposed updateSubscriptions forParticipants call client" --tokens 3500
python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/developers_deepgram" "live transcription websocket auth token vs api key streaming websocket parameters language interim_results endpointing websocket reconnect and close behavior" --tokens 3500
python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/developers_deepgram" "temporary token websocket token query parameter Authorization bearer websocket headers" --tokens 2500
```

## Baseline Checks

- `diff -u` shows that `audit/snapshots/minimal_daily_widget_snapshot_20260306.dart.txt` matches the working widget baseline except for the snapshot header comment block.
- `flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart` reports `25 issues`.
- Result split:
  - Definite code hygiene noise: duplicate/unused imports, unused local, unused private methods.
  - Deprecated API noise: `withOpacity`.
  - Higher-value review targets are not the lint count itself, but the async/lifecycle contract gaps listed below.

## Library Verification Notes

### Daily

- Installed package: `daily_flutter 0.34.0` (`pubspec.lock`).
- Verified in installed package source:
  - `CallClient.join`, `updateInputs`, `updatePublishing`, `updateSubscriptions`, and `dispose` exist in `~/.pub-cache/hosted/pub.dev/daily_flutter-0.34.0/lib/src/call_client.dart`.
  - `VideoViewController.setTrack()` is asynchronous and returns `Future<void>`; it can throw if the track no longer exists. See `~/.pub-cache/hosted/pub.dev/daily_flutter-0.34.0/lib/src/widgets/video_view.dart:52-72`.
  - `VideoViewController.dispose()` performs async teardown internally. See `~/.pub-cache/hosted/pub.dev/daily_flutter-0.34.0/lib/src/widgets/video_view.dart:82-94`.
  - `CallClient.dispose()` notes that attached controllers should be disposed individually before client disposal. See `~/.pub-cache/hosted/pub.dev/daily_flutter-0.34.0/lib/src/call_client.dart:277-286`.
- Context7 confirmation:
  - `updateSubscriptions()` is the correct Daily Flutter API surface for subscription management.
  - Daily docs also state that explicit track subscription control depends on subscription management mode rather than default auto-subscribe behavior.

### Deepgram

- Context7 confirmation:
  - Realtime STT websocket supports `Authorization: Token <api_key>`.
  - Temporary JWT auth is supported with `Authorization: Bearer <token>`.
  - STT websocket also documents `Sec-WebSocket-Protocol: token, <api_key>` for environments where header auth is constrained.
- Conclusion:
  - Current auth header construction in the widget is broadly compatible with current Deepgram docs.
  - No Stage 1 evidence that the current Deepgram auth path is inherently invalid.

## Findings

### MDW-S1-01

- Severity: `P1`
- Type: `Daily-related`
- Classification: `definite library contract issue`
- Symptom:
  - The widget calls `VideoViewController.setTrack()` as fire-and-forget even though the installed Daily package exposes it as `Future<void>`.
- Evidence:
  - `lib/custom_code/widgets/minimal_daily_widget.dart:855`
  - `lib/custom_code/widgets/minimal_daily_widget.dart:920`
  - `lib/custom_code/widgets/minimal_daily_widget.dart:950`
  - `lib/custom_code/widgets/minimal_daily_widget.dart:2352`
  - `lib/custom_code/widgets/minimal_daily_widget.dart:2359`
  - `~/.pub-cache/hosted/pub.dev/daily_flutter-0.34.0/lib/src/widgets/video_view.dart:58-72`
- Root cause:
  - The widget treats `setTrack()` like a synchronous setter, so its async errors are not caught by surrounding `try/catch`, and the intended clear-track-before-dispose ordering is not actually enforced.
- Impact:
  - Possible unhandled async `StateError` during stale-track updates.
  - Renderer teardown can race with controller disposal during participant removal and full cleanup.
  - Static comments about safe cleanup order are weaker than the actual execution order.

### MDW-S1-02

- Severity: `P1`
- Type: `Pure Flutter/Dart/widget`
- Classification: `definite issue`
- Symptom:
  - Cleanup registries are append-only, while high-frequency caption/reconnect flow keeps creating timers and stream resources.
- Evidence:
  - Tracking sets declared in `lib/custom_code/widgets/minimal_daily_widget.dart:153-155`
  - Tracking helpers in `lib/custom_code/widgets/minimal_daily_widget.dart:1584-1595`
  - Caption clear timer in `lib/custom_code/widgets/minimal_daily_widget.dart:1303-1324`
  - Reconnect timers in `lib/custom_code/widgets/minimal_daily_widget.dart:1066-1071` and `lib/custom_code/widgets/minimal_daily_widget.dart:1332-1340`
  - Cleanup only clears everything at the end of the call in `lib/custom_code/widgets/minimal_daily_widget.dart:2308-2402`
  - Untracked short timers in `lib/custom_code/widgets/minimal_daily_widget.dart:824`, `lib/custom_code/widgets/minimal_daily_widget.dart:841`, `lib/custom_code/widgets/minimal_daily_widget.dart:923`
- Root cause:
  - Timers, subscriptions, and controllers are added to tracking sets but never removed when they naturally complete or are replaced.
  - Some short-lived timers bypass the tracking system entirely.
- Impact:
  - Long caption-heavy or reconnect-heavy sessions can grow in-memory bookkeeping monotonically until final cleanup.
  - Cleanup work becomes larger than necessary and relies on catch-and-ignore behavior for already-closed resources.

### MDW-S1-03

- Severity: `P2`
- Type: `Daily-related`
- Classification: `probable library misuse`
- Symptom:
  - `_prioritizeRemoteSubscription()` assumes explicit per-participant subscription control is active and meaningful for quality prioritization.
- Evidence:
  - Join path uses plain `join(url, token)` with no visible subscription mode configuration in `lib/custom_code/widgets/minimal_daily_widget.dart:433-460`
  - Explicit subscription override happens in `lib/custom_code/widgets/minimal_daily_widget.dart:872-905`
  - Context7 Daily docs state that explicit track subscription control depends on disabling automatic subscriptions first.
- Root cause:
  - There is no visible code in this widget or its immediate integration path that switches Daily into an explicit subscription-management mode before calling `updateSubscriptions()`.
- Impact:
  - The “prioritize remote subscription” logic may be ineffective, partially effective, or rely on undocumented defaults.
  - Comments that describe this as a guaranteed remote-quality fix are stronger than the verified contract.
- Note:
  - This is an inference from the current code plus Daily docs; runtime verification belongs to Stage 2.

### MDW-S1-04

- Severity: `P3`
- Type: `Integration contract clarity`
- Classification: `definite maintainability issue`
- Symptom:
  - `VideoCallPageWidget` passes a temporary Deepgram access token into a widget parameter named `deepgramApiKey`.
- Evidence:
  - `lib/shared_pages/video_call_page/video_call_page_widget.dart:147-156`
  - `lib/shared_pages/video_call_page/video_call_page_widget.dart:348-353`
  - `lib/custom_code/widgets/minimal_daily_widget.dart:110-126`
- Root cause:
  - Parameter naming still reflects the older “client API key” model even though the integration now fetches a token from `getDeepgramToken`.
- Impact:
  - Raises the chance of future regressions where a long-lived API key is accidentally reintroduced or handled inconsistently.
  - Makes static review of auth semantics harder than necessary.

### MDW-S1-05

- Severity: `P3`
- Type: `Style-only noise`
- Classification: `non-blocking`
- Evidence:
  - Duplicate/unused imports at the top of `lib/custom_code/widgets/minimal_daily_widget.dart`
  - Unused methods `_enableAdaptiveBitrate()` and `_forceHighQualityVideo()`
  - Unused local `oldValid`
  - Deprecated `withOpacity` calls around `lib/custom_code/widgets/minimal_daily_widget.dart:1631`, `1968-1972`, `1995`, `2100`, `2123`, `2179-2230`
- Impact:
  - Increases review noise and makes higher-risk findings harder to spot.
  - Does not currently look like the main source of runtime instability by itself.

## Pass Notes

- Snapshot rollback artifact is valid for pre-fix restore.
- Deepgram auth handling is compatible with current docs for both API-key and JWT flows.
- The widget already tries to dispose video controllers before `CallClient.dispose()`, which matches the package guidance, but `MDW-S1-01` weakens that ordering in practice.

## Stage Conclusion

- Stage result: `Fail`
- Reason:
  - There are open `P1` findings in async track handling and in-memory lifecycle bookkeeping.
- Recommended Stage 2 focus:
  - Trace `initState -> _initializeCall -> event handlers -> didUpdateWidget -> _cleanup -> dispose`
  - Validate whether unawaited `setTrack()` calls surface real late errors during participant churn/reconnect/teardown
  - Validate whether `updateSubscriptions()` is functionally affecting remote quality in the current Daily configuration

## Resolution Update

- Date: `2026-03-06`
- Status: `Stage 1 code fixes completed`
- Working widget changed: `Yes`

### Resolved Findings

- `MDW-S1-01`
  - Fixed by awaiting `VideoViewController.setTrack()` through dedicated helpers and preserving cleanup ordering in `lib/custom_code/widgets/minimal_daily_widget.dart`.
- `MDW-S1-02`
  - Fixed by tracking and cancelling timers, subscriptions, controllers, and related reconnect/deepgram resources explicitly.
- `MDW-S1-03`
  - Fixed by configuring the Daily `active-remote` subscription profile up front, assigning remote participants to that profile, and tracking `subscriptionsUpdated` / `subscriptionProfilesUpdated` events to avoid blind repeated overrides.
- `MDW-S1-04`
  - Fixed by introducing `deepgramCredential` as the primary widget API, keeping `deepgramApiKey` only as a deprecated backward-compatible alias, and migrating the active call site to the new parameter name.
- `MDW-S1-05`
  - Partially fixed. Dead code, deprecated `withOpacity`, and fixable local import noise were removed. Remaining warnings are limited to the FlutterFlow-generated import header above `DO NOT REMOVE OR MODIFY THE CODE ABOVE!`.

### Validation After Fixes

- `flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart`
  - `6 issues` remain, all from the generated import block:
    - unnecessary import `/backend/schema/structs/index.dart`
    - unused imports `/backend/schema/enums/enums.dart`, `/flutter_flow/flutter_flow_theme.dart`, `index.dart`, `/custom_code/actions/index.dart`, `/flutter_flow/custom_functions.dart`
- `flutter analyze`
  - `No issues found!`
- `flutter test`
  - `All tests passed!`

### Updated Stage Status

- Stage result: `Pass with generated-header exceptions`
- Residual risk:
  - File-level analyzer noise still exists in the generated import header and should only be touched if FlutterFlow regeneration strategy is agreed first.
