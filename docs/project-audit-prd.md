# Project Audit PRD

Last updated: 2026-06-13

## Source Status

The audit files requested by the tranche prompt were missing from this checkout, so this run bootstrapped the audit log from the current repository state and subagent findings.

## Project Direction

- As of 2026-05-26, the app is no longer intended to be maintained through FlutterFlow.
- Former FlutterFlow-generated files may be edited directly when needed for a safe, scoped fix.
- Future tranches do not need to preserve FlutterFlow regeneration compatibility.

## Goal

Review, optimize, and safely remediate the Flutter/Dart video call surface and directly related backend/session code in narrow, reviewable tranches.

## Current Tranche

- tranche_id: VC-TR-023
- review_round: 25
- focus: Make in-call Deepgram caption failures visible, auditable, and lifecycle-safe.
- priority: runtime-correctness/learning-surface
- scope: Keep live captions available while the in-call chat is open, surface Deepgram token/start/WebSocket/audio failures in the call UI, persist safe system diagnostic records into `videoSessions/{sessionId}/captionLogs`, guard Deepgram start/stop against stale async work, and keep normal caption log ids/rules aligned with Firebase user ids so call details explain why subtitle logs are absent.

## Counters

- bugs_found_total: 38
- bugs_fixed_total: 38
- bugs_open_total: 0
- privacy_findings_open: 0
- lifecycle_findings_open: 0
- test_gaps_open: 2
- docs_updated_count: 7

## Acceptance Criteria

- Deepgram credential/start/WebSocket/audio failures no longer disappear behind `kDebugMode` only.
- Caption failures show a safe in-call subtitle status instead of a silent empty overlay.
- Caption runtime failures persist safe system diagnostics under `captionLogs` without raw tokens or provider error payloads.
- Firestore rules allow only bounded, writer-scoped runtime diagnostic records and exact-id normal caption logs from accepted call participants.
- Deepgram streaming start/stop ignores stale session/credential/audio callbacks and retries when a credential arrives after initial mount.
- Successful Deepgram streaming/transcripts clear stale caption failure state.
- Captions remain renderable while chat is open and avoid the chat panel on mobile/wide layouts.
- Regression coverage protects caption diagnostics and chat-open caption visibility.
- Audit docs and inventory are updated after the tranche.
- Reviewer gate completed with no P0-P2 blockers or accepted fixes documented.
