# MinimalDailyWidget Review Guide

## Purpose
- This guide defines a staged verification process for `MinimalDailyWidget` without changing the working implementation during the review itself.
- Primary media stack for this widget: Daily (`daily_flutter`).
- Primary live transcription stack for this widget: Deepgram.
- Agora is not the active SDK of this widget. It appears only in legacy/policy/runtime-config context and must be checked as a reference layer, not as the current implementation source.

## Rollback Baseline
- Current working widget: `lib/custom_code/widgets/minimal_daily_widget.dart`
- Rollback snapshot: `audit/snapshots/minimal_daily_widget_snapshot_20260306.dart.txt`
- Older archive copy: `audit/snapshots/minimal_daily_widget_backup_20260124.dart.txt`

### Manual Rollback Steps
1. Confirm that the active implementation must be reverted to the pre-audit state.
2. Restore the contents of `audit/snapshots/minimal_daily_widget_snapshot_20260306.dart.txt` into `lib/custom_code/widgets/minimal_daily_widget.dart` through a reviewed commit.
3. Run the baseline checks from Stage 0 again.
4. Record the rollback date, reason, and observed behavior after restore.

## Current Baseline Before Fixes
- Date of baseline: `2026-03-06`
- `flutter analyze`: covers the active custom widget and custom-functions source; archived snapshots are stored outside `lib/` as text.
- `flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart`: currently reports `25 issues`, including unused imports, dead code, and deprecated `withOpacity` usage.
- `flutter test`: passes.
- Android integration smoke run is blocked at build stage by `daily_flutter` NDK mismatch and requires `ndkVersion = "27.3.13750724"` in `android/app/build.gradle`.
- Current widget file must stay unchanged while following this guide.

## Skill Selection
- `flutter-expert`
  - Primary skill for widget lifecycle, mobile runtime behavior, media/state management, and Flutter performance review.
- `dart-expert`
  - Primary skill for async control flow, timers, cleanup order, stream handling, null safety, and state correctness.
- `context7`
  - Mandatory for library-specific verification where current package behavior matters.
- `flutter-animations`
  - Use for transition smoothness, `AnimatedSwitcher`, motion quality, and animation-related UI jank analysis.

## Skills Not To Use As Primary
- `performance`
  - Do not use as the main audit skill here; it is web-centric and not appropriate as the primary framework for a Flutter mobile widget runtime audit.
- `e2e-testing-patterns`
  - Do not use as the main audit skill; this review targets Flutter mobile widget/runtime verification, not Playwright/Cypress workflows.

## Context7 Library Map

### Daily
- Required: yes
- Role: primary media SDK verification
- Preferred Context7 ID: `/websites/daily_co_reference_flutter`
- Optional secondary ID: `/websites/daily_co`
- Example commands:
  - `python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/daily_co_reference_flutter" "join updatePublishing updateSubscriptions participant lifecycle"`
  - `python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/daily_co_reference_flutter" "VideoViewController setTrack dispose call lifecycle"`
- Recommended queries:
  - `join updatePublishing updateSubscriptions participant lifecycle`
  - `VideoViewController setTrack dispose call lifecycle`
  - `callStateUpdated participantUpdated participantLeft reconnect behavior`

### Deepgram
- Required: yes
- Role: primary transcription and websocket behavior verification
- Preferred Context7 ID: `/websites/developers_deepgram`
- Example commands:
  - `python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/developers_deepgram" "live transcription websocket auth token vs api key"`
  - `python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/developers_deepgram" "streaming transcription websocket parameters language interim_results endpointing"`
- Recommended queries:
  - `live transcription websocket auth token vs api key`
  - `streaming transcription websocket parameters language interim_results endpointing`
  - `websocket reconnect and close behavior`

### Agora
- Required: yes, but only as legacy/reference verification
- Role: verify legacy assumptions in policy text, runtime config, or historical architecture notes
- Preferred Context7 IDs:
  - `/websites/api-ref_agora_io_en_video-sdk_flutter_6_x`
  - `/agoraio-extensions/agora-flutter-sdk`
- Example commands:
  - `python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/api-ref_agora_io_en_video-sdk_flutter_6_x" "flutter video sdk token lifecycle reconnect permissions"`
  - `python3 ~/.agents/skills/context7/scripts/context7.py context "/agoraio-extensions/agora-flutter-sdk" "join channel leave channel app lifecycle"`
- Recommended queries:
  - `flutter video sdk token lifecycle reconnect permissions`
  - `join channel leave channel app lifecycle`
  - `best practices realtime video call flutter`

### Optional Supporting Libraries
- `flutter_sound`
  - Use if recorder lifecycle or microphone stream behavior is unclear.
  - Example query: `FlutterSoundRecorder openRecorder startRecorder stopRecorder closeRecorder lifecycle`
- `permission_handler`
  - Use if permission state handling is unclear.
  - Example query: `microphone permission request granted denied lifecycle flutter`
- `web_socket_channel`
  - Use if websocket close/reconnect semantics need confirmation.
  - Example query: `IOWebSocketChannel connect close error done behavior`

## Evidence To Record For Every Stage
- Commands executed
- `context7` searches and exact queries used
- Findings split into:
  - Daily-related
  - Deepgram-related
  - Agora legacy/reference-related
  - Pure Flutter/Dart/widget findings
- Screenshots, logs, traces, or note paths
- Pass/fail conclusion for the stage

## Stage 0. Baseline And Rollback

### Goal
- Lock the current review starting point before any future fixes.

### Skills
- `dart-expert`
- `flutter-expert`

### Context7 Targets
- Not required for this stage.

### Commands / Manual Steps
1. Confirm the active widget file path and snapshot path.
2. Run:
   - `flutter analyze`
   - `flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart`
   - `flutter test`
3. Confirm that project-wide analysis includes active files under `lib/custom_code/`.
4. Record whether Android smoke verification is still blocked by the `daily_flutter` NDK requirement.
5. Verify that `audit/snapshots/minimal_daily_widget_snapshot_20260306.dart.txt` still matches the intended rollback baseline except for the archive header.

### Expected Result
- Baseline state is frozen and reproducible.
- The reviewer can restore the widget to the pre-fix state without ambiguity.

### Problem Signals
- Snapshot file differs from the intended baseline implementation.
- Reviewer cannot explain which file is authoritative for rollback.
- Baseline command outputs are missing or inconsistent.

### Report Notes
- Save exact command results.
- Record baseline date and device/build context if mobile runtime checks are performed later.

## Stage 1. Static Analysis

### Goal
- Identify compile-time risks, code hygiene issues, dead code, deprecated APIs, and mismatches with current library contracts.

### Skills
- `dart-expert`
- `flutter-expert`
- `context7`

### Context7 Targets
- Daily docs for join/publishing/subscriptions/video controller lifecycle.
- Deepgram docs for websocket auth, live transcription params, and token/API key behavior.
- Agora docs only for legacy cross-check if project documentation or config still assumes Agora behavior.

### Commands / Manual Steps
1. Run:
   - `flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart`
2. Review:
   - imports
   - dead private methods
   - deprecated API usage
   - constructor and callback contract stability
3. Search for related integration points:
   - `lib/shared_pages/video_call_page/video_call_page_widget.dart`
   - `lib/services/voip_service.dart`
4. Use `context7` to confirm current package behavior before classifying any library-specific code as wrong.
5. Separate findings into:
   - definite Flutter/Dart issue
   - probable library misuse
   - style-only noise

### Expected Result
- A ranked list of static findings exists with clear ownership: widget code, integration code, or third-party API usage.

### Problem Signals
- File-level warnings are treated as generic cleanup without checking whether they affect runtime behavior.
- Reviewer assumes package API behavior without validating it in `context7`.

### Report Notes
- For each library-specific finding, record the `context7` library ID and query used.
- Mark whether the issue affects correctness, maintainability, or performance only.

## Stage 2. Correctness And Lifecycle

### Goal
- Validate that the widget behaves correctly across init, join, media updates, transcription, participant changes, reconnects, and cleanup.

### Skills
- `flutter-expert`
- `dart-expert`
- `context7`

### Context7 Targets
- Daily as primary media source.
- Deepgram as primary transcription source.
- Agora as secondary reference only to validate that no stale media-stack assumptions remain in docs or runtime config.

### Commands / Manual Steps
1. Trace widget lifecycle paths:
   - `initState`
   - `_initializeWidget`
   - `_initializeCall`
   - event subscription setup
   - `didChangeAppLifecycleState`
   - `didUpdateWidget`
   - `_cleanup`
   - `dispose`
2. Verify correctness of:
   - meeting token resolution and refresh
   - Deepgram credential resolution
   - join flow without valid token
   - participant join/left handling
   - remote-left timer behavior
   - caption clear timing
   - cleanup order and async safety
3. Use `context7` to confirm:
   - Daily participant and call state expectations
   - Deepgram websocket auth expectations
   - any disputed reconnect assumptions
4. Cross-check project text/config mentioning Agora and note that the active widget does not use Agora runtime APIs.

### Expected Result
- The reviewer can explain whether each lifecycle path is correct, risky, or undocumented.
- All race-condition candidates are listed with exact methods and triggers.

### Problem Signals
- `setState` or timer callbacks can fire after disposal.
- cleanup can double-dispose or dispose after late callbacks.
- Deepgram start/stop can overlap under reconnect or background/foreground transitions.
- participant leave logic can fail to fire the navigation callback.

### Report Notes
- For each lifecycle risk, record:
  - trigger
  - involved methods
  - user-visible consequence
  - whether the conclusion came from source reading or `context7`

## Stage 3. Performance And Smoothness

### Goal
- Find rebuild, repaint, layout, timer, and animation hotspots that can degrade call smoothness on iOS and Android.

### Skills
- `flutter-expert`
- `flutter-animations`
- `context7`

### Context7 Targets
- Daily docs for video rendering, call state cadence, and participant/media update frequency.
- Deepgram docs for streaming cadence, websocket lifecycle, and transcript update behavior.
- Agora docs only if needed to challenge stale assumptions in project documentation or historical notes.

### Commands / Manual Steps
1. Review hot paths:
   - `_updateState`
   - partial transcript updates
   - caption rendering
   - duration timer
   - participant update handlers
   - `AnimatedSwitcher`
2. Flag expensive patterns:
   - full-tree rebuilds
   - repeated `copyWith()` no-op state updates
   - timer accumulation
   - `IntrinsicWidth` in frequently changing overlays
   - missing repaint isolation around video/content layers
3. Use `flutter-animations` to evaluate whether current transition choices are correct for the intended UX.
4. Use `context7` if library event cadence or rendering expectations affect the interpretation of a hotspot.

### Expected Result
- A prioritized list of performance risks exists, split into:
  - rebuild pressure
  - layout pressure
  - timer/stream churn
  - motion/transition quality

### Problem Signals
- Smoothness claims rely only on static reading without identifying the highest-frequency update sources.
- Animation issues are described without distinguishing Flutter animation misuse from library-driven update cadence.

### Report Notes
- Record which issues are definitely local widget issues and which depend on observed runtime traces.
- Mark which findings require profile-mode confirmation before code changes.

## Stage 4. Manual Mobile Runtime Verification

### Goal
- Confirm real-device behavior on iOS and Android for call stability, permissions, background/foreground flow, reconnects, and perceived smoothness.

### Skills
- `flutter-expert`
- `dart-expert`
- `context7`

### Context7 Targets
- Daily join/leave/reconnect/mobile lifecycle behavior.
- Deepgram permission/auth/runtime behavior.
- Agora docs only when current runtime behavior conflicts with legacy expectations from project docs or config.

### Commands / Manual Steps
1. Prefer physical devices for final validation.
2. Run in `--profile` for performance-oriented checks.
3. Execute these manual scenarios:
   - join with valid token
   - join with delayed/refresh token
   - speak continuously for 60-90 seconds with captions enabled
   - remote participant leaves
   - network interruption and reconnect
   - app background -> foreground during active call
   - microphone permission denied then granted
4. Observe:
   - call UI continuity
   - local/remote video switching
   - caption freshness and clearing behavior
   - reconnect messaging
   - end-call and summary navigation behavior
5. If behavior is surprising, confirm the relevant library expectation in `context7` before concluding it is a bug.

### Expected Result
- Device-level notes exist for both iOS and Android, including correctness and perceived smoothness.

### Problem Signals
- Runtime verification is attempted only on simulator/emulator for microphone/call lifecycle conclusions.
- Reviewer does not distinguish environment issues from widget logic issues.

### Report Notes
- Record device model, OS version, build mode, and network conditions.
- Attach trace/log references when visible jank or reconnect failures occur.

## Stage 5. Regression And Acceptance

### Goal
- Define what must be re-run after future fixes and what counts as an accepted stabilization result.

### Skills
- `flutter-expert`
- `dart-expert`

### Context7 Targets
- Only use for final confirmation of disputed library-specific decisions.

### Commands / Manual Steps
1. After future fixes, rerun:
   - `flutter analyze`
   - `flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart`
   - `flutter test`
   - relevant mobile runtime scenarios from Stage 4
2. Re-check the Android NDK blocker before treating Android verification as complete.
3. Compare post-fix behavior against the Stage 0 baseline.

### Expected Result
- The reviewer can say which issues were fixed, which were unchanged, and which remain unverified.

### Problem Signals
- Final sign-off happens without rerunning the widget-specific analyze and runtime stages.
- Library-sensitive fixes are accepted without confirming current docs.

### Report Notes
- Final report must clearly separate:
  - fixed
  - still failing
  - blocked by environment
  - not yet retested

## Final Acceptance Criteria
- The guide execution must produce:
  - a baseline record,
  - a stage-by-stage finding log,
  - documented `context7` usage for Daily and Deepgram,
  - documented Agora legacy/reference verification,
  - a clear list of correctness, performance, and smoothness findings,
  - explicit blockers such as Android NDK configuration if they still prevent full validation.
