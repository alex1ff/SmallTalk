# Call Timers, Native Speaker Toggle, and AI Features Fixes

## Goal

Fix the five QA regressions reported on 2026-08-24 without changing the
matching limit, call limit, authentication roles, or server-side AI privacy
model.

Success means:

- the search screen shows the existing two-minute countdown (`02:00` in the
  current `mm:ss` UI format) as soon as the searching state is visible;
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

Only the start timing changes. The existing zero-padded `mm:ss` formatter and
the initial visible text `Осталось 02:00` remain unchanged.

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
runtime device type. Provider selection is a pure mapping; device inspection
and activation stay in the service wrapper:

- physical iPhone/iPad: `AppleProvider.deviceCheck` in debug and release;
- iOS simulator: `AppleProvider.debug`;
- macOS: debug provider in debug builds and DeviceCheck in release builds;
- Android: debug provider in debug builds and Play Integrity in release builds;
- web: the current reCAPTCHA provider when its site key is configured.

`device_info_plus`, already present in the project, supplies
`IosDeviceInfo.isPhysicalDevice`. If the iOS device lookup fails, debug builds
fall back to the debug provider and release builds fall back to DeviceCheck,
and the lookup error is logged without aborting startup.

Before physical-device QA, the Firebase App Check configuration for app
`1:1024626146715:ios:7438f350d2c09ff86bf53e` must be confirmed to have
DeviceCheck enabled. This is an operational prerequisite; client provider
selection alone cannot register the provider in Firebase.

Simulator debug tokens remain credentials: they are registered in Firebase
from the locally generated Xcode token and are never committed. If no token is
registered, debug logging must make the App Check failure explicit. After
activation, debug builds make one forced `FirebaseAppCheck.getToken(true)`
readiness request. They log only whether a non-empty token was obtained or the
sanitized exception; the token value is never logged by Dart code. The probe is
non-fatal and is not repeated during normal feature calls. Server-side App
Check enforcement stays enabled.

Callable `unauthenticated` failures are classified at the UI boundary. If
`currentUserUid` is empty, the UI reports that sign-in is required. If it is
non-empty on these auth-gated in-call/post-call surfaces, the UI reports an app
verification failure; Firebase Auth already owns token refresh before the
callable request. Translation uses its existing localized app-verification
copy. Feedback adds the localized non-retry state “Не удалось подтвердить
приложение. Перезапустите его.” / “The app could not be verified. Restart it.”
This state does not show the retry button because an unregistered debug token
cannot recover by repeating the same callable.

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
- App Check activation and the debug readiness probe remain non-fatal for
  general app startup, but debug output identifies provider lookup, activation,
  and token acquisition failures. Paid callables still reject missing or
  invalid attestation.
- Translation and feedback retain their existing retry/quota/provider error
  handling; only App Check error classification changes.
- Missing or malformed session policy data continues to fall back to elapsed
  call time for legacy sessions.

## Validation

- Add/update dashboard tests to prove the `2:00` timer starts before the
  `startSearch` future completes and is cancelled for immediate matches.
- Add a widget/contract test ensuring the shared entry toggle uses a visible
  Flutter adaptive switch and updates its value.
- Add unit tests for the pure App Check provider mapping across iOS physical,
  iOS simulator, macOS, Android, debug, and release inputs; test lookup-failure
  fallbacks and authenticated/unauthenticated callable error mapping.
- Update session-limit tests so `connecting` policy-backed sessions use the
  countdown while `searching` and terminal sessions do not.
- Add/adjust a video-call surface test that prevents an elapsed-to-countdown
  mode switch for policy-backed calls.
- Run relevant targeted tests, `flutter test`, and `flutter analyze`.
- Run the existing Functions tests for translation, feedback, and deployment
  readiness because these features cross the client/server boundary.
- Confirm DeviceCheck is enabled for the Firebase iOS app, perform live QA on a
  physical iPhone build, and inspect Functions logs for valid App Check
  verification. Simulator QA additionally requires a locally registered debug
  token.

## Non-goals

- No change to the two-minute search notice or ten-minute search timeout.
- No change to the five-minute call limit or extension rules.
- No FlutterFire major-version upgrade.
- No disabling or weakening of App Check.
- No Translation, Gemini, matching, or Daily provider redesign.
- No production deployment or App Store/TestFlight release as part of the code
  change unless requested separately.
