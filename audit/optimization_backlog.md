# SmallTalk Optimization Backlog (Cycle 1)

## 1) Audit Summary
- Scope: full project static audit (Flutter app + Firebase rules/functions + assets + dependencies).
- Platforms: iOS and Android priority.
- Baseline gates:
  - `flutter analyze`: 68 issues (60 warnings, 8 info).
  - `flutter test`: 1 test, passed.
- Runtime profiling on real devices: not executed in this environment (tracked in retest checklist).

## 2) Phase Status (from plan)
- Phase 0 (Project map + baseline): Completed.
- Phase 1 (App shell/lifecycle): Completed (issues ISS-006, ISS-007, ISS-017, ISS-021).
- Phase 2 (Auth/onboarding): Completed (issues ISS-002, ISS-018).
- Phase 3 (Student domain): Completed (issues ISS-008, ISS-009, ISS-010, ISS-013).
- Phase 4 (Teacher domain): Completed (cross-screen performance pattern ISS-013).
- Phase 5 (Shared pages): Completed (issues ISS-011, ISS-014, ISS-018).
- Phase 6 (Realtime/VoIP/Video): Completed (issues ISS-004, ISS-015, ISS-016).
- Phase 7 (Backend/Firebase/CF): Completed (issues ISS-001, ISS-003, ISS-005, ISS-012, ISS-023, ISS-024).
- Phase 8 (Assets/rendering): Completed (issue ISS-022).
- Phase 9 (Stability/bugs): Completed (cross-cutting issues ISS-003, ISS-006, ISS-011, ISS-014, ISS-016).
- Phase 10 (Finalization/roadmap): Completed (this backlog + retest checklist).

## 3) Top 10 Quick Wins (Immediate)
1. Fix Firestore rules from open access to ownership/role checks (ISS-001).
2. Remove hardcoded Deepgram key from client, proxy via server token minting (ISS-004).
3. Fix `queryCollectionCount` null-path crash (ISS-005).
4. Keep and cancel auth stream subscription in `MyApp` (ISS-006).
5. Remove fixed 3s + 1s startup delays (ISS-007).
6. Fix review histogram math and zero-division guard on native speaker page (ISS-008/009).
7. Correct camera/microphone permission flow (ISS-010).
8. Guard GoRouter diagnostics with `kDebugMode` (ISS-017).
9. Reduce createVideoSession tutor-loop log verbosity (ISS-023).
10. Block cross-user storage reads (ISS-024).

Expected impact: immediate reduction in security risk, fewer runtime edge-case failures, faster perceived startup.

## 4) Top 10 Medium Tasks (Next)
1. Make `endSession` idempotent with transactional status compare-and-set (ISS-003).
2. Move rating aggregate updates to Cloud Function transaction (ISS-011).
3. Enforce route auth (`requireAuth`) and fix redirect setter bug (ISS-002).
4. Remove users-collection full-scan fallback in matchmaking callable (ISS-012).
5. Refactor high-traffic screens from `SingleChildScrollView + shrinkWrap ListView` to slivers (ISS-013).
6. Move waiting-flow side effects from post-frame callback to transition-aware listener (ISS-014).
7. Track/cancel all VoIP listeners and add explicit service deinit on sign-out (ISS-015).
8. Add TTL cleanup for stale VoIP session maps/sets (ISS-016).
9. Reduce analyze issues in `call_summary` and `video_call_page` modules (ISS-018).
10. Add integration test coverage for auth/call/wait/payment critical paths (ISS-019).

Expected impact: improved consistency under concurrency, reduced jank, better reliability in call flows.

## 5) Top 10 Deep Refactors (Later)
1. Introduce unified server authoritative state machine for call lifecycle transitions.
2. Add replay-safe event IDs for `acceptCall`/`endSession` to prevent duplicate side effects.
3. Move all billing/statistics writes into idempotent backend pipelines with dedupe keys.
4. Introduce repository layer for stream/query deduplication and caching strategy.
5. Build performance budget tooling (`frame >16.7ms`, memory growth, call drop KPI) in CI/nightly.
6. Stage major dependency upgrade wave (FlutterFire + router + media) with migration tests (ISS-020).
7. Replace runtime-embedded language catalog with lazy asset loading + caching (ISS-021).
8. Asset optimization pipeline: font subsetting + image preprocessing automation (ISS-022).
9. Introduce emulator-based security test suite for Firestore/Storage rules.
10. Add synthetic load tests for cloud functions (matchmaking, accept, endSession).

Expected impact: long-term scalability, lower infra cost, deterministic realtime behavior.

## 6) Roadmap

### Wave A: Immediate (0-7 days)
- Focus: ISS-001, 004, 005, 006, 007, 008, 009, 010, 017, 024.
- Done criteria:
  - Security tests deny unauthorized access.
  - No hardcoded provider secrets in client artifact.
  - Startup path has no artificial fixed delays.
  - Native speaker rating section renders correct percentages and never divides by zero.

### Wave B: Next (1-3 weeks)
- Focus: ISS-002, 003, 011, 012, 013, 014, 015, 016, 018, 019.
- Done criteria:
  - Concurrent `endSession` does not double-charge.
  - Rating aggregation remains correct under concurrent review writes.
  - Realtime waiting/call navigation shows no duplicate transitions.
  - Key screens show measurable frame-time reduction in profile mode.

### Wave C: Later (3-8 weeks)
- Focus: ISS-020, 021, 022 + deep architectural tasks.
- Done criteria:
  - Dependency modernization completed without regression spike.
  - Runtime KPIs tracked continuously (startup, jank, drops, memory).
  - Asset and language catalog optimizations reflected in app size/startup metrics.

## 7) Dependency Upgrade Matrix (ISS-020)

Baseline source: `flutter pub outdated --no-dev-dependencies` on 2026-03-04 (84 constrained dependencies older than resolvable).

### Execution Rules
1. Upgrade one wave per PR; do not mix waves.
2. For each wave, run: `flutter pub get` -> `flutter analyze` -> `flutter test`.
3. For each wave, run device regression subset: `RT-02`, `RT-04`, `RT-05`, `RT-10`, `RT-12`.
4. Rollback rule: if crash-free drops, auth/call flow regresses, or frame-time degrades >10%, revert the whole wave.

### Compatibility Matrix
| Wave | Scope | Current -> Target (resolvable) | Risk | Validation Gate | Rollback Trigger |
|---|---|---|---|---|---|
| W0 | Baseline lock + tooling | keep current lockfile, capture pre-upgrade metrics | Low | record TTFF/FPS/crash-free baseline; save build artifacts | baseline missing/incomplete |
| W1 | FlutterFire Core | `firebase_core 3.14.0 -> 4.5.0`, `firebase_auth 5.6.0 -> 6.2.0`, `cloud_firestore 5.6.9 -> 6.1.3`, `cloud_functions 5.5.2 -> 6.0.7`, `firebase_storage 12.4.7 -> 13.1.0` (+ web/platform interface companions) | High | auth sign-in/out, Firestore reads/writes, callable functions, storage uploads/downloads | auth breakage, Firestore permission/serialization regressions |
| W2 | Messaging + Performance | `firebase_messaging 15.2.7 -> 16.1.2`, `firebase_performance 0.10.1+7 -> 0.11.1+5` (+ companion packages) | High | foreground/background/terminated push, VoIP incoming-call path, perf trace upload | missed notifications, duplicate handlers, token refresh failures |
| W3 | Navigation | `go_router 12.1.3 -> 17.1.0` | High | deep links, redirect restoration, guarded route access, shell tab navigation | redirect loops, broken path/query param decode |
| W4 | Realtime + Media | `daily_flutter 0.34.0 -> 0.37.0`, `video_player 2.10.0 -> 2.10.1`, `webview_flutter 4.13.0 -> 4.13.1` (+ platform packages) | Medium/High | call join/rejoin/end, token refresh, payment webview lifecycle | call drops increase, reconnect failure, webview freeze |
| W5 | Ecosystem Cleanup | remaining low-risk libs (`adaptive_platform_ui`, `provider`, `lottie`, `url_launcher`, `path_provider`, `shared_preferences`, `sqflite`, etc.) | Medium | smoke run all critical routes + compare startup/build size | broad UI/runtime regressions from transitive changes |

### Wave Deliverables
- `audit/dependency_wave_wX_report.md` per wave with:
  - upgraded package list,
  - migration notes,
  - pass/fail for required RT scenarios,
  - metric delta (startup, frame-time, crash-free),
  - go/no-go decision for next wave.

## 8) Acceptance KPI Targets (post-fix)
- Startup:
  - First interactive screen <= 1.8s on mid-tier Android.
  - First interactive screen <= 1.4s on recent iPhone.
- UI smoothness on critical flows:
  - Frames >16.7ms <= 5%.
  - Frames >33ms <= 1%.
- Realtime calls:
  - Join success >= 99%.
  - Reconnect success >= 95%.
  - Dropped calls <= 1%.
- Reliability:
  - Zero duplicate billing events in concurrent end-session tests.
- Quality gate:
  - `flutter analyze` warning budget reduced from 68 to <= 15 in next cycle.
