# MinimalDailyWidget Stage 3 Performance And Smoothness

- Date: `2026-03-06`
- Status: `Completed`
- Working widget changed: `Yes`
- Scope:
  - `lib/custom_code/widgets/minimal_daily_widget.dart`

## Commands Executed

```bash
python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/daily_co_reference_flutter" "participantUpdated callStateUpdated event frequency participant media updates subscriptionsUpdated" --tokens 2500
python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/developers_deepgram" "streaming websocket interim transcript frequency final transcript cadence partial results" --tokens 2500
flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart
flutter analyze
flutter test
```

## Findings

### MDW-S3-01

- Severity: `P1`
- Type: `Rebuild pressure`
- Classification: `definite local widget issue`
- Trigger:
  - Active call running for a long time while the on-screen duration badge updates every second.
- Involved methods:
  - `MinimalDailyWidget._startDurationTimer()`
  - `MinimalDailyWidget.build()`
- Evidence:
  - The timer previously called `setState()` every second just to refresh the duration text.
  - That forced the whole widget tree to rebuild, including video, overlays, and controls.
- User-visible consequence:
  - Unnecessary rebuild work on every second tick during the entire call lifetime.
  - Avoidable smoothness loss on lower-end iOS/Android devices.
- Resolution:
  - Moved duration rendering onto a `ValueNotifier<int>` + `ValueListenableBuilder` so only the badge subtree refreshes.

### MDW-S3-02

- Severity: `P1`
- Type: `Layout pressure`
- Classification: `definite local widget issue`
- Trigger:
  - Partial/final transcript updates while captions are visible.
- Involved methods:
  - `MinimalDailyWidget._buildSpeakerSection()`
  - `MinimalDailyWidget._buildWordChip()`
- Evidence:
  - Both the speaker label chip and every word chip used `IntrinsicWidth`.
  - This path sits inside a frequently changing captions overlay and forces intrinsic measurement work.
- User-visible consequence:
  - Heavier layout passes exactly when transcript updates are most frequent.
- Resolution:
  - Removed `IntrinsicWidth` and let `Wrap` + `Container` size naturally.

### MDW-S3-03

- Severity: `P1`
- Type: `Paint isolation`
- Classification: `definite local widget issue`
- Trigger:
  - Timer updates, captions changes, or controls state changes while video is rendering.
- Involved methods:
  - `MinimalDailyWidget.build()`
- Evidence:
  - The main video layer, PiP, captions overlay, and controls lived in one stack without repaint isolation.
- User-visible consequence:
  - Overlay churn can request broader repaints than necessary.
- Resolution:
  - Added `RepaintBoundary` around the primary video layer, PiP, captions overlay, controls, and duration badge.

### MDW-S3-04

- Severity: `P2`
- Type: `Motion / transition quality`
- Classification: `definite local widget issue`
- Trigger:
  - Switching between local full-screen preview and remote full-screen video.
- Involved methods:
  - `MinimalDailyWidget.build()`
  - `MinimalDailyWidget._buildPrimaryVideo()`
- Evidence:
  - `AnimatedSwitcher` did not receive a stable child key for local-vs-remote mode changes.
  - Without a mode key, Flutter can reuse the subtree and skip the intended transition semantics.
- User-visible consequence:
  - Inconsistent or visually flat mode switching.
- Resolution:
  - Keyed the primary child by render mode and set explicit easing curves on the switch.

### MDW-S3-05

- Severity: `P2`
- Type: `Event churn`
- Classification: `mixed local widget issue + library cadence confirmation`
- Trigger:
  - Daily emits `participant-updated` for participant state changes.
- Involved methods:
  - `MinimalDailyWidget._handleParticipantUpdated()`
- Evidence:
  - Context7 confirms `participant-updated` fires whenever participant state changes.
  - The widget previously forced a no-op `_updateState(_state.copyWith())` on every remote participant update.
- User-visible consequence:
  - Chatty participant/media updates can create avoidable full-tree rebuild pressure.
- Resolution:
  - Added a lightweight remote UI signature cache and only trigger the rebuild when user-visible participant presentation data changes.
- Conclusion source:
  - Source reading + Context7.

## Remaining Runtime-Side Watch Items

- Caption overlay still rebuilds as transcript content changes, which is expected, but should be observed in `--profile` during long continuous speech.
- Deepgram interim/final cadence can still create bursty caption updates; Context7 confirms that multiple `is_final` results may arrive before `speech_final`.
- Final smoothness acceptance still belongs to Stage 4 device verification.

## Validation After Fixes

- `flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart`
  - `6 issues` remain, all from the FlutterFlow-generated import header above `DO NOT REMOVE OR MODIFY THE CODE ABOVE!`
- `flutter analyze`
  - `No issues found!`
- `flutter test`
  - `All tests passed!`

## Stage Conclusion

- Stage result: `Pass`
- Outcome:
  - Highest-confidence local rebuild/layout/paint hotspots were reduced in code.
  - Remaining uncertainty is runtime-only and belongs to profile-mode mobile verification rather than further static cleanup.
