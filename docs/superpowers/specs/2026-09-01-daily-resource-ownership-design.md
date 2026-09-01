# P1-04: resource ownership completion

Scope: retain the public `MinimalDailyWidget` constructor, callbacks, Daily
settings, caption schema and call UI. No new state-management or SDK package.
Server call/trial policy remains outside this refactor.

## Boundaries and order

1. `DailySessionController`: one native client lifetime, process lease, event
   subscription, ordered join/configuration, close and disposal. SDK operations
   are injected; they use a captured client, never a mutable widget lookup after
   an await. Widget error/retry policy is migrated separately after this owner
   is validated; it is not called from inside an owner's pending operation.
2. `CallTimerController`: periodic scheduler, server clock alignment, elapsed
   time and one-shot checkpoint/deadline decisions. The widget supplies a live
   session snapshot and renders updates. Focus/notice animation timers are UI.
3. Caption and chat controllers reuse the existing tested assemblers/queues.
   Move their transport, finalization and persistence orchestration next, then
   separate presentation. These remain required, not implicitly completed by
   the first two owners.

Alternatives considered: another set of pure helper extractions would leave
resource ownership unchanged; a new global store or SDK replacement would
increase migration risk without solving a current need. Use local owners with
small callback boundaries instead.

## Daily lifetime invariants

- Concurrent opens, including two callers waiting behind another lease, share
  one operation and create at most one client.
- Creation timeout is not cancellation. A late client must be disposed without
  joining. The lease stays reserved until pending creation/disposal settles.
- Close invalidates the generation immediately. Stale callbacks cannot update
  state; each awaited join/configuration step rechecks its lifetime.
- Concurrent close calls share one root future. `leaveCall: true` upgrades an
  earlier reconnect cleanup request while leaving is still possible. A request
  arriving after irreversible native disposal must not call leave on a disposed
  handle; report that exceptional state with a fixed, non-sensitive code.
- Cleanup order: invalidate/cancel events, settle the pending SDK operation,
  disable capture, drain captions, leave, detach video, dispose client, release
  lease. Each failing cleanup phase must not skip unrelated later phases.
- Caption and detach-video hooks also run without a created client. Parent
  state reset belongs to the one cleanup root, after native cleanup completes.
- A permanently unresolved native create cannot safely release a lease: the
  SDK exposes no cancellation API. Do not fabricate a successful cleanup or
  start a competing client merely because a UI timeout elapsed.

## Timer invariants

- Start publishes immediately and schedules one periodic tick; repeated start
  does not create another timer. Stop/dispose cancels it synchronously.
- Each tick computes elapsed time from server `connectedAt` and current clock
  offset, not by adding seconds. Restart therefore catches up without drift.
- Expiry changes reset only limit markers; session changes reset offset and
  checkpoint history too. A stale failure cannot clear a newer expiry marker.
- Keep provisional countdown, 5/10-minute student checkpoints, 60-second
  warning and 2-second auto-end grace. The server still validates auto-end.
- UI notifiers remain widget-owned; no callback may publish after disposal.

## Evidence and completion

Baseline: 362 focused Flutter tests passed before production edits. Use
controllable futures and injected clocks/schedulers for resource races; source
contracts verify wiring only and do not substitute for execution tests.
Run focused tests after each owner, `flutter analyze`, then the full Flutter
suite and an independent fresh-agent review of the integrated changes.

Physical iOS/Android call, background/foreground, reconnect and final-caption
smoke remains a release check. Neither unit tests nor a successful analyzer
run proves native media behavior. P1-04 stays open until remaining ownership
work and its acceptance checks are accounted for explicitly.
