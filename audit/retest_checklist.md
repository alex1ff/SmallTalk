# Retest Checklist (Cycle 1 -> Cycle 2)

## Test Environment
- Devices (required):
  - 1 mid-tier Android physical device.
  - 1 iPhone physical device.
- Build mode: `--profile` for performance measurements, `--release` for final verification.
- Backend: staging Firebase project with production-like rules and Cloud Functions.

## Baseline Re-run Commands
1. `flutter analyze`
2. `flutter test`
3. `flutter pub outdated --no-dev-dependencies`
4. Collect profile traces on critical flows via DevTools/`flutter run --profile`.

## Latest Local Snapshot (2026-03-04)
- `flutter analyze`: passed, 0 issues.
- `flutter test`: passed (`test/widget_test.dart`).
- `flutter test integration_test/critical_flows_smoke_test.dart -d emulator-5554`: passed (`All tests passed!`).
- `flutter test integration_test/critical_flows_smoke_test.dart -d 0C14CC14-2144-458F-89DE-90C2D9F27893` (iOS Simulator): passed (`All tests passed!`).
- `flutter test integration_test/critical_flows_smoke_test.dart -d 00008101-00056C640A88001E` (USB iPhone): blocked by iOS code signing/provisioning.
- Backend P0/P1 checks executed via Firebase Emulator Suite:
  - artifact: `audit/backend_checks_results.json`.
  - rules checks: pass.
  - concurrent `endSession`: pass (single charge + single earning).
  - `createVideoSession` load test: pass (`p95=160ms`, `20/20` success, `logLines=200`, `errorLines=20`).

## Scenario Matrix
| ID | Scenario | Platforms | Status | Required Metrics |
|---|---|---|---|---|
| RT-01 | Cold start offline / weak / normal network | iOS, Android | Not run | TTFF, first interactive, crash-free |
| RT-02 | Login / logout / relogin and role switch | iOS, Android | Not run | Navigation correctness, auth redirects |
| RT-03 | Heavy screens repeated back-forward navigation | iOS, Android | Not run | Frames >16.7ms, memory growth |
| RT-04 | Incoming call in foreground/background/terminated | iOS, Android | Not run | Notification-to-call UI latency, success rate |
| RT-05 | Accept call with valid token / expired token | iOS, Android | Not run | Join success, token refresh behavior |
| RT-06 | Mid-call network interruption and recovery | iOS, Android | Not run | Reconnect success, call drop rate |
| RT-07 | End call by both participants simultaneously | iOS, Android | Pass (Emulator backend validation) | Billing idempotency, summary navigation |
| RT-08 | Firestore burst updates on active screens | iOS, Android | Not run | Rebuild churn, frame drops |
| RT-09 | 15+ minute video call soak test | iOS, Android | Not run | Memory/CPU/battery trends |
| RT-10 | Payment flow + webview lifecycle | iOS, Android | Not run | Stuck state count, memory leaks |
| RT-11 | Security regression (rules) unauthorized access attempts | Emulator + devices | Pass (Emulator validation) | Denied reads/writes coverage |
| RT-12 | Post-fix analyze/test/profile rerun | iOS, Android | Partial (analyze/test + integration smoke pass on Android emulator/iOS simulator, USB iOS blocked by signing) | Delta vs baseline |

## Execution Notes (2026-03-04)
- Build commit: `f599c29`.
- Android startup proxy metric (`adb am start -W`, cold starts, emulator):
  - WaitTime samples: `11942ms`, `10890ms`, `10581ms`.
  - median: `10890ms`.
- Android memory snapshot (`adb dumpsys meminfo com.appwave.smalltalk`):
  - peak observed PSS: `206117 KB` (`~201.3 MB`).
  - 3-minute delta sample: `-2053 KB` (`~-2.0 MB`).
- Android app size:
  - `flutter build apk --release --target-platform android-arm64 --analyze-size`.
  - output apk size: `90.8MB` (`87MB` compressed report).
  - analysis file: `/Users/patrikkardenas/.flutter-devtools/apk-code-size-analysis_01.json`.

## Detailed Steps (Critical)

### RT-07 EndSession Concurrency (P0)
1. Start one active call between student and tutor.
2. Trigger end from both clients within 1 second.
3. Verify in Firestore:
   - single call charge transaction for student,
   - single earning transaction for tutor,
   - session status transitions once.
4. Expected: no double billing, no duplicate earnings.

### RT-11 Rules Security (P0)
1. Use unauthenticated client attempts for `users`, `videoSessions`, `transactions`.
2. Use authenticated user A to read/write user B private data.
3. Expected: denied by rules for unauthorized operations.

### RT-04 VoIP Lifecycle (P1)
1. Receive call in foreground.
2. Receive call in background.
3. Receive call with app terminated.
4. Accept and verify navigation to `VideoCallPage` without duplicate transitions.

## Pass/Fail Criteria
- Pass if all P0 scenarios pass and no blocker regression appears in P1 flows.
- Fail if any of the following occurs:
  - unauthorized data access succeeds,
  - duplicate billing/earning entries appear,
  - call flow dead-ends or repeated navigation loops,
  - startup or frame-time regressions exceed baseline by >10%.

## Reporting Format
For each scenario, record:
- `result`: pass/fail
- `build`: commit hash + build mode
- `evidence`: log, screenshot, trace file path
- `metrics`: measured values
- `notes`: anomaly and suspected root cause
