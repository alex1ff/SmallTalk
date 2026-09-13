# SmallTalk portfolio-readiness design

## Goal

Promote the current local product state to the default branch and make the engineering approach visible without hiding the project's FlutterFlow origin.

## Source of truth

FlutterFlow exports are retired. The GitHub codebase is now authoritative. The local `codex/smalltalk-v2-remediation` branch is a clean, tested, 37-commit fast-forward of `origin/main` and is the candidate for the new `main` state.

## Scope

- Fast-forward `main` to the validated local branch after preparation changes pass.
- Replace the generic README with product scope, architecture, ownership boundaries, local setup, backend setup, and verification commands.
- State clearly which areas originated from FlutterFlow and which layers contain maintained application, backend, security, VoIP, matchmaking, translation, and test code.
- Ensure production custom code is analyzed; remove or isolate stale backup/snapshot sources instead of broadly excluding maintained code.
- Add GitHub Actions jobs pinned to Flutter 3.35.3 / Dart 3.9.2 for Flutter analysis/tests and deterministic backend contract checks.
- Improve repository description and topics while preserving private visibility.

## Non-goals

- No UI or business-flow redesign.
- No broad refactor of generated widgets.
- No change to Firebase contracts, security rules, call lifecycle, subscription behavior, or deployment configuration.

## Validation

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- Preserve Flutter test discovery: the full suite must report at least the current baseline of 1,972 passing tests.
- `npm ci --prefix firebase/functions`
- `npm ci --prefix firebase/custom_cloud_functions`
- `npm run backend:ci`
- Both CI jobs pass from a clean checkout.

The broader emulator-backed `backend:checks` harness is retained as diagnostic evidence rather than a release gate: its checked-in baseline already contains environment-dependent failures, so treating it as green CI would be misleading.

## Publishing

Use the current feature branch as the preparation branch. Merge only by fast-forwarding `main`; retain historical branches until the default branch is verified.
