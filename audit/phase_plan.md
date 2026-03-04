# Detailed Audit Phase Plan (Implemented)

## Phase 0: Project Map + Baseline
- Inventory modules, heavy files, and integration points.
- Run `flutter analyze`, `flutter test`, dependency drift check.
- Output: `audit/baseline_metrics.json`.

## Phase 1: App Shell + Lifecycle
- Files: `lib/main.dart`, `lib/flutter_flow/nav/nav.dart`, `lib/authorization/loading/*`.
- Checkpoints:
  - startup blocking delays,
  - auth stream lifecycle,
  - router redirect correctness,
  - route protection strategy.

## Phase 2: Auth + Onboarding
- Files: `lib/auth/**`, `lib/authorization/**`.
- Checkpoints:
  - auth API correctness,
  - error handling,
  - onboarding latency and transition quality.

## Phase 3: Student Domain
- Files: `lib/students_pages/**`.
- Checkpoints:
  - expensive build/layout patterns,
  - permission flow correctness,
  - review/list rendering correctness,
  - waiting flow resilience.

## Phase 4: Teacher Domain
- Files: `lib/teachers_pages/**`.
- Checkpoints:
  - list performance,
  - payment/history rendering,
  - repeated scroll/list anti-patterns.

## Phase 5: Shared Pages
- Files: `lib/shared_pages/**`.
- Checkpoints:
  - call summary aggregation consistency,
  - video call page token/navigation behavior,
  - profile/edit heavy UI patterns.

## Phase 6: Realtime + VoIP + Video
- Files: `lib/services/voip_service.dart`, `lib/custom_code/widgets/minimal_daily_widget.dart`.
- Checkpoints:
  - listener lifecycle and cleanup,
  - race conditions around accept/end/reconnect,
  - resource cleanup and long-call stability.

## Phase 7: Backend + Firebase + Cloud Functions
- Files: `firebase/custom_cloud_functions/*.js`, `firebase/firestore.rules`, `firebase/storage.rules`, `firebase/firestore.indexes.json`.
- Checkpoints:
  - authorization and data integrity,
  - idempotency in call termination,
  - query/read amplification,
  - scheduling and timeout risk.

## Phase 8: Assets + Rendering
- Files: `assets/**`, `pubspec.yaml`.
- Checkpoints:
  - bundle weight,
  - high-cost fonts/images/json animations,
  - optimization opportunities.

## Phase 9: Stability + Bugs
- Combine cross-module P0/P1 findings into defect log with evidence.
- Output: `audit/issues.csv`.

## Phase 10: Finalization + Roadmap
- Build prioritized execution plan and acceptance KPIs.
- Outputs:
  - `audit/optimization_backlog.md`
  - `audit/retest_checklist.md`
  - `audit/master_prompt.md`
