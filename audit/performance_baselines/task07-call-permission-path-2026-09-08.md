# Task 07 — call permission path evidence

Date: 2026-09-08

## Scope

This evidence covers the deterministic camera/microphone permission part of
the call connection path. It does not claim mobile network, callable, Daily
join, first-media or end-to-end latency; those measurements remain in final
device Task 02.

## Before

- One granted permission flow performed four sequential platform status reads:
  camera before request, microphone before request, then both statuses again.
- The legacy dashboard CTA performed the complete access check before calling
  `_handleStartConversation`, which performed the same permission flow again.
- CallKit accept and the immediately opened video page could also repeat a
  recently successful permission check.

## After

- Camera and microphone status are read concurrently and exactly once when
  both are already granted.
- Concurrent callers share one in-flight permission operation.
- A confirmed grant can be reused for 30 seconds across an uninterrupted
  foreground transition into the call page.
- The success cache is invalidated on paused, hidden or detached lifecycle
  states. A generation guard prevents late pre-background work from restoring
  it. Denials are never cached.
- A five-second timeout applies only to status platform calls. Permission
  dialogs remain unbounded so the user has time to respond. A hung read fails
  closed and cannot poison later attempts.
- The duplicate dashboard CTA gate was removed; the existing centralized
  `_ensureStartSearchAccess` still owns auth, subscription, active-session and
  permission checks.

## Validation

- `flutter analyze`: passed.
- Permission, VoIP surface, dashboard and startup scoped tests: 90 passed.
- Unit contracts cover concurrent status reads, single-flight ownership,
  success TTL, lifecycle invalidation, late completion after invalidation,
  hung status recovery, sequential prompts and uncached denial.
