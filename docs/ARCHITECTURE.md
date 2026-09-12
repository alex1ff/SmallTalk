# Architecture

## Overview

SmallTalk is a Flutter client backed by Firebase Authentication, Firestore, Storage, and callable/scheduled Cloud Functions. Client code owns presentation and local interaction state; server code owns privileged transitions and cross-user coordination.

## Component boundaries

| Layer | Responsibility |
| --- | --- |
| Flutter pages/components | Presentation, navigation, form state, and user feedback |
| Client services | Use cases for events, profiles, calls, translation, reviews, and subscriptions |
| Firebase record layer | Typed document/struct conversion and query boundaries |
| Cloud Functions | Matchmaking, call state transitions, tokens, moderation, billing webhooks, and cleanup |
| Firestore/Storage rules | Per-document authorization and client write limits |
| External adapters | Daily, push/VoIP, translation/AI, RevenueCat, and email providers |

Former FlutterFlow files are an implementation origin, not an architectural boundary. Maintained behavior is placed behind services and backend contracts where practical, while generated-style widgets remain editable presentation code.

## Main video-session lifecycle

```text
search request -> server-side candidate selection -> pair lock
      -> session document -> token issuance -> Daily room
      -> connected/heartbeat state -> end/timeout cleanup
      -> persisted history -> feedback and review
```

Important transitions are callable functions rather than direct client writes. Firestore rules constrain which fields a participant can read or mutate, and cleanup jobs handle abandoned or expired state.

## Trust boundaries

1. The client never grants roles, entitlements, balances, or administrative access.
2. Matchmaking and session membership are decided server-side.
3. Tokens and provider credentials are issued or consumed by Cloud Functions, not stored in the app bundle.
4. RevenueCat and other webhooks are verified before changing entitlement state.
5. Public profile documents contain a deliberately reduced projection of user data.
6. Emulator-backed rule tests exercise both allowed and denied access paths.

## Client structure

- `lib/services/` contains maintained application logic and integration façades.
- `lib/backend/` contains Firebase schemas and transport helpers.
- `lib/custom_code/` contains the media surface and behavior that does not fit generated widget conventions.
- role-specific and shared page directories own UI composition only; privileged decisions remain on the backend.

## Backend structure

`firebase/custom_cloud_functions/` is split by use case instead of one monolithic handler: call lifecycle, matchmaking, events, moderation, payments, notifications, translation, and cleanup. The repository also contains deployment-readiness and secret-readiness checks so production configuration can be validated without committing secrets.

## Verification strategy

- `flutter analyze` covers all active Dart source, including custom functions and custom widgets.
- `flutter test` runs 1,972 unit, widget, contract, and regression tests.
- `npm run backend:checks` starts local emulators and exercises Cloud Functions plus Firestore/Storage policy.
- CI pins Flutter 3.35.3 / Dart 3.9.2, Node.js 22, Java 21, Firebase CLI, and npm lockfiles.
