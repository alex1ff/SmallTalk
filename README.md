# Small Talk

A new Flutter project.

## Getting Started

FlutterFlow projects are built to run on the Flutter _stable_ release.

## Firebase Tooling

The repo's Functions code is pinned to `firebase-functions@7.x`. Local backend
emulator checks should use a pinned `firebase-tools` version as well, because
older global CLI builds can fail during emulator runtime boot even when the
project code is correct.

Install the local tooling once:

```bash
npm ci
```

Use:

```bash
npm run backend:checks
```

This uses the repo-local `firebase-tools@15.14.0`, so the emulator path does
not depend on a globally installed Firebase CLI or on a runtime `npx` download.
If you need to override the Firebase project, set `FIREBASE_PROJECT` in the
environment.
