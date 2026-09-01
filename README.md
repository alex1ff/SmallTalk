# SmallTalk

Flutter/Firebase platform for live language practice. The app matches compatible speakers, supports video sessions and messaging, and extends the core call flow with events, translation, feedback, subscriptions, and trust controls. The runtime product name is **Expatlio**.

## Engineering highlights

- Flutter client with feature-level services and explicit Firebase boundaries;
- callable Cloud Functions and Firestore/Storage rules for privileged state transitions;
- server-owned matchmaking, call lifecycle, entitlement, and moderation decisions;
- Daily-based video sessions, VoIP notifications, translation, and post-call feedback;
- 1,972 Flutter tests plus focused backend lifecycle/event-contract tests.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for component ownership, trust boundaries, and the main call lifecycle.

## Source ownership

The first application version originated in FlutterFlow. FlutterFlow export is now retired: this repository is the only source of truth and all files may be maintained normally.

- `lib/flutter_flow/` and parts of the widget scaffold retain generated conventions.
- Product services, Firebase integrations, custom media code, rules, Cloud Functions, and tests are actively maintained in Git.
- Archived rollback copies are stored as text under `audit/snapshots/`, outside analyzed production source.

The project does not claim that generated code is hand-written. Quality is established by explicit boundaries, reviewable changes, static analysis, backend policy tests, and a reproducible local release gate.

## Local setup

Required versions:

- Flutter 3.35.3 / Dart 3.9.2;
- Node.js 22 and npm;

```bash
flutter pub get
flutter analyze
flutter test
```

The backend checks use repository-pinned dependencies:

```bash
npm ci --ignore-scripts
npm ci --prefix firebase/custom_cloud_functions
npm run backend:ci
```

`firebase/custom_cloud_functions` is the only maintained and configured
Functions codebase. `backend:ci` validates every backend JavaScript file and
runs the focused event/lifecycle contract suite without production access. The
broader `npm run backend:checks` emulator harness remains available for
environment, security-rule, and call/trial lifecycle transaction audits; it
writes detailed evidence under `audit/` and is intentionally separate from the
deterministic release gate.

To verify the production source inventory without deploying anything, use an
account with read access to the Firebase project:

```bash
npm --prefix firebase/custom_cloud_functions run inventory:backend-source
```

The command fails if a deployed function belongs to a codebase other than
`custom_cloud_functions`.

To update the sanitized, versioned production snapshot (IDs, regions,
runtimes, hashes, service accounts and triggers; no environment values or
logs), run:

```bash
npm --prefix firebase/custom_cloud_functions run inventory:backend-source:snapshot
```

## Project structure

| Path | Responsibility |
| --- | --- |
| `lib/services/` | App-facing use cases and external-service adapters |
| `lib/backend/` | Typed Firebase records, API requests, and storage helpers |
| `lib/custom_code/` | Maintained media widgets and custom actions |
| `lib/shared_pages/` | Shared chat, event, profile, review, and call surfaces |
| `firebase/custom_cloud_functions/` | Matchmaking, call, event, payment, and moderation backend |
| `firebase/*.rules` | Firestore and Storage authorization policy |
| `test/` | Flutter unit, widget, contract, and regression tests |
| `audit/` | Review evidence, backend harness, and non-production snapshots |

## Runtime configuration

Firebase platform files identify the application but do not contain server credentials. Production-only keys are supplied through runtime configuration or Firebase secrets.

Custom email verification requires a verified Resend sender:

```text
RESEND_API_KEY
EMAIL_FROM
EMAIL_REPLY_TO  # optional
```

Other external integrations follow the same rule: identifiers may be versioned when safe; credentials never are.

## Local quality gate

Run the complete release check from a clean checkout:

```bash
./scripts/local_ci.sh
```

It installs locked Flutter and Node dependencies, audits runtime packages for high-severity advisories, runs static analysis, the complete Flutter suite, backend syntax validation, and the deterministic event/lifecycle contract tests. The command must pass before `main` is considered releasable.
