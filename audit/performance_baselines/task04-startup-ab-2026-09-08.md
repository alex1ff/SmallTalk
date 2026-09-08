# Task 04 startup A/B — 08.09.2026

## Scope

- Before: sequential Firebase/App Check, then local startup initialization.
- After: Firebase/App Check overlaps local startup initialization; preferences
  also overlap the bundled language-catalog load.
- Both variants were built and measured consecutively with the Task 03
  `web-onboarding-startup-v1` profile-web launcher on the same host.
- Each result contains ten fresh browser contexts with HTTP cache disabled and
  service workers blocked. Browser timing is diagnostic and does not replace
  the physical-device check deferred to task 02.

## Result

| Metric | Before mean | After mean | Change | Before median | After median |
| --- | ---: | ---: | ---: | ---: | ---: |
| Flutter surface ready | 1295.0 ms | 1266.6 ms | -2.19% | 1314.5 ms | 1292.0 ms |
| First actionable control | 1827.6 ms | 1761.8 ms | -3.60% | 1697.5 ms | 1741.0 ms |
| Network transfer | 22.541 MiB | 22.593 MiB | +0.23% | 22.611 MiB | 22.612 MiB |
| Resource count | 36.7 | 36.9 | +0.54% | 37 | 37 |
| Used JS heap | 89.303 MiB | 89.841 MiB | +0.60% | 88.765 MiB | 88.565 MiB |
| `main.dart.js` | 19.390489 MiB | 19.391699 MiB | +0.01% | 19.390489 MiB | 19.391699 MiB |

The directly controlled A/B improved both mean startup timings and the median
surface timing. First-action samples remain noisy: its median changed by
+2.56% while the mean improved by 3.60%. Therefore the result supports the
small critical-path change but does not justify a strong mobile-speed claim.
Transfer, resource-count and bundle-size changes remain far below their 10%
Task 03 regression budgets.

## Evidence identity

The raw files remain in ignored local output directories for this worktree.
Their identities are recorded so an accidental replacement is detectable.

- Before source fingerprint:
  `14a7ba6b85b3c1b6a8ce8f65ba56ef599e9f9039f7ecca68177c2bade4819a4b`
- Before build fingerprint:
  `0442536dc639a0dd095f47204c39f26e6916cbf082c5b0a5cf35a8ce17a8f2de`
- Before raw SHA-256:
  `1c4f1fb9d1bd1037540fa84c940132578735b8f9eb10146f560d831adc264a4a`
- After source fingerprint:
  `7984546cda5f43cd64de635b69b3f4abe54a9dce4a4b849592cba7d3e1a35c1c`
- After build fingerprint:
  `f016105575ecac7443190ce07da63d1a3a7f9ec19090e6b2cf7e03c35afad0bd`
- After raw SHA-256:
  `2b5d8ff0e8da102e4746b61569f8bbff2985030e2939dcaf0b5ec30dd28ee922`

## Deferred verification

Cold/warm iOS startup, incoming CallKit, authenticated deep links, offline
fallback and first protected request remain explicit physical-device checks in
task 02. The code keeps App Check behind the startup barrier and does not defer
authentication readiness.
