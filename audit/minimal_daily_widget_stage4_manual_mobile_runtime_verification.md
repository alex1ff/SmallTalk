# MinimalDailyWidget Stage 4 Manual Mobile Runtime Verification

- Date: `2026-03-06`
- Status: `Partial`
- Working widget changed: `No`
- Scope:
  - `android/app/build.gradle`
  - `integration_test/critical_flows_smoke_test.dart`
  - `test_driver/integration_test.dart`

## Device Inventory Observed

- Android:
  - `emulator-5554`
  - Android 16 / API 36 emulator
- iOS:
  - `00008101-00056C640A88001E`
  - wirelessly connected iPhone
  - iOS `26.0.1`
- Missing for final Stage 4 sign-off:
  - mid-tier Android physical device

## Commands Executed

```bash
flutter devices
flutter emulators
python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/daily_co_reference_flutter" "mobile background foreground reconnect participant left call state updated flutter ios android" --tokens 3000
python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/developers_deepgram" "microphone permission mobile sdk websocket auth token runtime behavior streaming" --tokens 2500
flutter test integration_test/critical_flows_smoke_test.dart -d emulator-5554
flutter test integration_test/critical_flows_smoke_test.dart -d 00008101-00056C640A88001E
flutter drive --profile -d emulator-5554 --driver test_driver/integration_test.dart --target integration_test/critical_flows_smoke_test.dart --timeout 420
flutter drive --profile -d 00008101-00056C640A88001E --publish-port --driver test_driver/integration_test.dart --target integration_test/critical_flows_smoke_test.dart --device-timeout 30 --timeout 420
flutter run --profile -d 00008101-00056C640A88001E --publish-port --no-resident
xcrun devicectl list devices
xcrun devicectl device info processes --device D87F39A5-9F27-5FCF-AF01-CD4048551F65
flutter analyze
flutter test
```

## Findings

### MDW-S4-01

- Severity: `P1`
- Type: `Environment coverage`
- Classification: `definite verification gap`
- Finding:
  - A physical iPhone is available, but no physical Android device is connected.
- Consequence:
  - Final Stage 4 acceptance still cannot cover the required Android real-device lifecycle paths.

### MDW-S4-02

- Severity: `P1`
- Type: `Android verification blocker`
- Classification: `definite resolved config blocker`
- Finding:
  - Android integration smoke initially failed exactly as predicted by the audit guide because `daily_flutter` required `ndkVersion = "27.3.13750724"`.
- Resolution:
  - Added `ndkVersion = "27.3.13750724"` in `android/app/build.gradle`.
- Consequence:
  - The old NDK mismatch is no longer the active blocker for Android runtime checks.

### MDW-S4-03

- Severity: `P2`
- Type: `Android runtime verification status`
- Classification: `incomplete`
- Finding:
  - Added a minimal `flutter drive` host-driver in `test_driver/integration_test.dart` so the same smoke test can run through `flutter drive` on mobile devices.
  - Android `flutter drive` advanced past the old version mismatch, but failed because the local SDK created a malformed NDK folder at `~/Library/Android/sdk/ndk/27.3.13750724` containing only `.installer` and no `source.properties`.
- Consequence:
  - Android verification is unblocked at project-config level but still blocked by the local Android SDK installation state.

### MDW-S4-04

- Severity: `P2`
- Type: `iOS wireless automation limitation`
- Classification: `definite tooling limitation`
- Finding:
  - `flutter test integration_test/critical_flows_smoke_test.dart -d 00008101-00056C640A88001E` fails because `flutter test` cannot start apps on wirelessly tethered iOS devices and does not expose `--publish-port`.
- Consequence:
  - Wireless iPhone integration smoke cannot be executed through the current `flutter test` path.
- Recommended path:
  - Use USB for `flutter test`, or add a `flutter drive` harness if wireless automation is required.

### MDW-S4-05

- Severity: `P2`
- Type: `iOS profile launch status`
- Classification: `partial`
- Finding:
  - `flutter run --profile -d 00008101-00056C640A88001E --publish-port --no-resident` started, but stalled in the build/launch path around `xcodebuild -showBuildSettings` and did not produce a confirmed launch result during this session.
  - `flutter drive` with the new host-driver and `--publish-port` also started on the wireless iPhone, but did not produce a confirmed launch/test result within the session.
  - A direct `xcrun devicectl` probe showed the current immediate blocker: the device was locked, so the developer disk image could not be mounted.
- Consequence:
  - The previous historical USB provisioning blocker was not re-hit here, but the wireless iPhone runtime path is still not validated end-to-end.
  - The next retry should be done with the iPhone unlocked before reattempting `flutter run` or `flutter drive`.

### MDW-S4-06

- Severity: `P1`
- Type: `Manual scenario coverage`
- Classification: `not executable from current terminal-only session`
- Finding:
  - The core Stage 4 scenarios still require:
    - valid live join tokens
    - a second participant
    - background/foreground interaction on device
    - network interruption control
    - microphone permission prompts on-device
- Consequence:
  - Join/reconnect/captions/leave behavior remains unverified on real devices in this pass.

## Context7 Notes

- Daily docs confirm the relevant mobile participant lifecycle surface remains `ParticipantJoined`, `ParticipantUpdated`, and `ParticipantLeft` across Flutter/iOS/Android SDK layers.
- Deepgram docs confirm websocket auth is only needed for the initial connection and the stream remains open until explicit close, which matches the current Stage 2 stop/start interpretation.

## Validation After Config Change

- `flutter analyze`
  - `No issues found!`
- `flutter test`
  - `All tests passed!`

## Stage Conclusion

- Stage result: `Partial`
- What is now true:
  - Android is no longer blocked by the known Daily NDK mismatch.
  - A real iPhone is visible to Flutter tooling.
- What is still required:
  1. Repair or reinstall the local Android NDK `27.3.13750724`, then re-run Android smoke.
  2. Use either USB iPhone or continue with the new `flutter drive` harness until the wireless iPhone path yields a confirmed launch/test result.
  3. Execute the Stage 4 manual call scenarios on a signed iPhone and a physical Android device in `--profile`.
