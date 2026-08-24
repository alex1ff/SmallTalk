# Call Timers, Native Speaker Toggle, and AI Features Fixes

## Goal

Fix the five QA regressions reported on 2026-08-24 without changing the
matching limit, call limit, authentication roles, or server-side AI privacy
model.

Success means:

- the search screen shows a `2:00` countdown as soon as the searching state is
  visible;
- login and registration show an interactive native-speaker switch on iOS;
- quick translation and post-call AI feedback receive a valid App Check token
  on a physical iPhone development build;
- a limited call displays `5:00` immediately and never flashes an elapsed
  `0:00` timer first;
- focused tests, `flutter analyze`, and relevant Flutter/Functions tests pass.

## Confirmed Causes

1. The dashboard enters `searching` before awaiting `startSearch`, but starts
   the two-minute UI countdown only after the callable responds. A quick match
   can therefore hide the countdown completely or show it only briefly.
2. `adaptive_platform_ui` 0.1.104 renders `AdaptiveSwitch` through a UIKit
   platform view on iOS 26. The platform view occupies the expected 63 logical
   pixels but is blank in the reported environment.
3. Production Functions are deployed and the translation/feedback feature
   flags are enabled. Logs for the reported calls show valid Firebase Auth but
   an invalid App Check token and HTTP 401. The iOS app selects the debug App
   Check provider for every debug build, while the Firebase iOS app currently
   has no registered debug tokens.
4. `VideoCallPageWidget` withholds the session policy and expiry while the
   Firestore session is `connecting`. `MinimalDailyWidget` therefore renders
   elapsed time from `0:00`, then changes to the five-minute countdown when the
   document becomes `active`.

## Design

### 1. Search countdown ownership

`StudentsDashboardWidget` remains the owner of the search timers. When access
checks succeed and the UI changes to `searching`, it starts the existing
two-minute foreground notice countdown in the same transition, before awaiting
`startSearch`.

The callable response must not restart the countdown. A transition to
`connecting`, cancellation, failure, or disposal cancels it through the
existing cleanup paths. Recovered searches continue to derive their elapsed
time from persisted recovery state. The independent ten-minute search timeout
is unchanged.

### 2. Native-speaker entry switch

`NativeSpeakerEntryToggle` replaces the package `AdaptiveSwitch` with Flutter's
`Switch.adaptive`. The surrounding row, label, value, callback, and role
routing remain unchanged. This avoids the iOS 26 platform-view failure while
retaining native Cupertino/Material appearance and semantics.

The `adaptive_platform_ui` dependency is not removed because that would be an
unrelated project-wide dependency change.

### 3. App Check provider selection

`firebase_app_check_service.dart` will select the Apple provider from the
runtime device type:

- physical iPhone/iPad: `AppleProvider.deviceCheck` in debug and release;
- iOS simulator: `AppleProvider.debug`;
- macOS and Android retain their current platform-appropriate behavior unless
  the existing code requires a small compatibility adjustment.

`device_info_plus`, already present in the project, supplies
`IosDeviceInfo.isPhysicalDevice`. Provider selection will be extracted into a
small independently testable helper.

Simulator debug tokens remain credentials: they are registered in Firebase
from the locally generated Xcode token and are never committed. If no token is
registered, debug logging must make the App Check failure explicit. Server-side
App Check enforcement stays enabled.

The translation and feedback UIs will map callable `unauthenticated` failures
to the existing app-verification message so App Check failures are not
misreported as network failures.

### 4. Limited-call countdown

`shouldUseSessionLimitCountdown` will consider a policy-backed `connecting`
session eligible for countdown presentation as well as an `active` session.
It will continue to reject `searching` and terminal sessions.

`VideoCallPageWidget` can then pass the existing policy and expiry to
`MinimalDailyWidget` before the active Firestore update. The widget's current
fallback clock derives the display from the effective policy limit and its
local two-party stopwatch, producing `5:00` at connection. When
`markSessionConnected` returns and Firestore publishes the authoritative active
expiry, the existing server clock offset takes over without changing timer
mode.

Auto-end and warning checks continue to run only when the call duration timer
is advancing after a remote participant is present. The five-minute limit and
extension policy do not change.

## Error Handling

- A failed `startSearch` clears the early countdown through `_setSearchError`.
- A quick match cancels the countdown immediately on the `connecting`
  transition.
- App Check activation remains non-fatal for general app startup, but debug
  output identifies token acquisition failures. Paid callables still reject
  missing or invalid attestation.
- Translation and feedback retain their existing retry/quota/provider error
  handling; only App Check error classification changes.
- Missing or malformed session policy data continues to fall back to elapsed
  call time for legacy sessions.

## Validation

- Add/update dashboard tests to prove the `2:00` timer starts before the
  `startSearch` future completes and is cancelled for immediate matches.
- Add a widget/contract test ensuring the shared entry toggle uses a visible
  Flutter adaptive switch and updates its value.
- Add unit tests for Apple App Check provider selection on physical and
  simulated devices and for callable error mapping.
- Update session-limit tests so `connecting` policy-backed sessions use the
  countdown while `searching` and terminal sessions do not.
- Add/adjust a video-call surface test that prevents an elapsed-to-countdown
  mode switch for policy-backed calls.
- Run relevant targeted tests, `flutter test`, and `flutter analyze`.
- Run the existing Functions tests for translation, feedback, and deployment
  readiness because these features cross the client/server boundary.
- Perform live QA on a physical iPhone build and inspect Functions logs for
  valid App Check verification. Simulator QA additionally requires a locally
  registered debug token.

## Non-goals

- No change to the two-minute search notice or ten-minute search timeout.
- No change to the five-minute call limit or extension rules.
- No FlutterFire major-version upgrade.
- No disabling or weakening of App Check.
- No Translation, Gemini, matching, or Daily provider redesign.
- No production deployment or App Store/TestFlight release as part of the code
  change unless requested separately.
