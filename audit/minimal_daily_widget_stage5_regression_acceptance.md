# MinimalDailyWidget Stage 5 Regression And Acceptance

- Date: `2026-03-06`
- Status: `Acceptance criteria defined`
- Working widget changed: `No`
- Scope:
  - `audit/minimal_daily_widget_stage1_static_analysis.md`
  - `audit/minimal_daily_widget_stage2_correctness_lifecycle.md`
  - `audit/minimal_daily_widget_stage3_performance_smoothness.md`
  - `audit/minimal_daily_widget_stage4_manual_mobile_runtime_verification.md`
  - `audit/retest_checklist.md`

## Commands Executed

```bash
flutter analyze
flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart
flutter test
git rev-parse --short HEAD
```

## Current Post-Fix Baseline

- Build commit: `147dec0`
- `flutter analyze`
  - `No issues found!`
- `flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart`
  - `6 issues`
  - all are generated import-header warnings above `DO NOT REMOVE OR MODIFY THE CODE ABOVE!`
- `flutter test`
  - `All tests passed!`
- Stage status summary:
  - Stage 1: `Pass with generated-header exceptions`
  - Stage 2: `Pass with retest required`
  - Stage 3: `Pass`
  - Stage 4: `Partial`

## Fixed

- `MDW-S1-01` through `MDW-S1-05`
  - Closed in code, with only generated import-header analyzer noise left in the widget file.
- `MDW-S2-01` through `MDW-S2-05`
  - Closed in code.
  - Runtime retest is still required for background/foreground, reconnect, and transcript tail behavior.
- `MDW-S3-01` through `MDW-S3-05`
  - Closed in code.
  - Remaining uncertainty is runtime-only smoothness confirmation in profile mode.
- Android Daily NDK blocker
  - Resolved in configuration by pinning `ndkVersion = "27.3.13750724"`.
- Wireless mobile automation path
  - `flutter drive` host-driver now exists in `test_driver/integration_test.dart` for the existing integration smoke suite.

## Full-File Follow-Up Pass

- Date: `2026-03-06`
- Additional code fixes applied after a full-file review of `minimal_daily_widget.dart`:
  - preserved refreshed meeting tokens and token-refresh attempt state across cleanup/reconnect paths
  - switched in-call UI readiness from remote-video-only to remote-participant presence so audio-only calls no longer look like “still waiting”
  - made caption clear timers generation-aware so older timers cannot erase newer subtitles early
- Validation after this pass:
  - `flutter analyze`: `No issues found!`
  - `flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart`: unchanged `6` generated-header issues only
  - `flutter test`: `All tests passed!`

## Still Failing

- No current code-level `P0` or `P1` failures were reproduced in local static reruns.
- The only remaining local analyzer output is the known generated import-header noise in `minimal_daily_widget.dart`.

## Blocked By Environment

- No physical Android device is connected, so Android real-device lifecycle verification is still blocked.
- The local Android SDK currently contains a malformed `ndk/27.3.13750724` install, so Android emulator/device smoke is blocked until that NDK is repaired or reinstalled.
- Wireless iPhone automation cannot use the current `flutter test` path because that command does not expose `--publish-port`.
- The current wireless iPhone retries also require the device to stay unlocked so CoreDevice can mount the developer disk image.
- Manual call verification still needs:
  - valid live session tokens
  - a second participant
  - device-side permission prompts
  - network interruption control
  - background/foreground interaction on device

## Not Yet Retested

- Join with valid token on physical iPhone and Android device.
- Join with delayed/refreshed token on physical devices.
- 60-90 second captions run in `--profile`.
- Remote participant leaves during active call.
- Mid-call network interruption and reconnect.
- App background -> foreground during active call.
- Microphone permission denied then granted.
- 15+ minute soak call.

## Acceptance Gates

- Static acceptance:
  - `flutter analyze` passes.
  - `flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart` shows no new issues beyond the 6 generated-header warnings, unless the generated header is intentionally cleaned up.
  - `flutter test` passes.
- Correctness acceptance:
  - No early billing start before remote presence.
  - Mute fully stops transcription/caption emission.
  - Background/foreground does not invert mic/camera or break Deepgram recovery.
  - CallKit / ConnectionService actions remain session-scoped.
- Smoothness acceptance:
  - No visible timer-driven whole-screen jank.
  - Captions remain fresh and tappable during 60-90 second speech.
  - Local/remote video switch feels stable in profile mode.
- Environment acceptance:
  - Android runtime checks are performed on a physical device.
  - iPhone runtime checks are performed on a signed device path that can actually launch the app end-to-end.

## Required Rerun Set For Final Sign-Off

1. `flutter analyze`
2. `flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart`
3. `flutter test`
4. Android smoke rerun after the NDK install finishes cleanly.
5. iPhone smoke rerun via USB or the new `flutter drive` harness.
6. Stage 4 manual scenarios in `--profile` on physical devices.

## Comparison To Stage 0 Baseline

- Static/code posture improved:
  - widget-specific analyze moved from `25 issues` in Stage 1 baseline to `6 generated-header issues`
  - global analyze remains passing
  - tests remain passing
- Environment posture improved:
  - the old Android NDK mismatch is no longer the active blocker
  - a real iPhone is visible to Flutter tooling
- What Stage 0 still has over the current pass:
  - runtime performance metrics remain only partially measured
  - real-device call scenarios remain incomplete

## Stage Conclusion

- Stage result: `Partial sign-off only`
- Final acceptance is not yet justified because Stage 4 device scenarios remain blocked or incomplete.
- The codebase is ready for the final runtime pass; the remaining work is mostly environment execution, not additional static cleanup.
