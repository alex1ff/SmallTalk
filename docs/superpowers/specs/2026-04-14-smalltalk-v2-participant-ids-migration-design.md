# SmallTalk V2 ParticipantIds Migration Design

Date: 2026-04-14  
Status: Implemented additive hardening slice

## Context

SmallTalk V2 wants `videoSessions` access to move toward a generalized participant model, but the live call stack still depends on legacy `studentId`, `tutorId`, and `currentTutorId` fields across rules, token minting, review submission, and call teardown.

The lowest-blast-radius privacy/access-control improvement available now is an additive migration step rather than a full session-schema rewrite.

## Decision

- New searching sessions write `participantIds` with the requesting student only.
- Accepted sessions expand `participantIds` to the confirmed student/tutor pair.
- Firestore rules and backend session callables treat `participantIds` as the preferred participant contract, while falling back to legacy fields for old documents and pending-tutor search state.
- Client-originated Firestore updates are not allowed to change `studentId`, `tutorId`, `currentTutorId`, or `participantIds`; only trusted backend writes should move those authorization fields.
- Pending tutors continue to rely on `currentTutorId` and are not treated as active session participants for room-token or Deepgram-token access.

## Why This Slice

- It improves participant-scoped access now, before the broader all-to-all matchmaking refactor.
- It keeps the current Flutter and callable contracts intact.
- It avoids widening access for notified-but-unaccepted tutors.
- It gives later `Issue 5.1` / `Issue 5.2` work a safer migration baseline.

## Deferred Work

- Full all-to-all session normalization still belongs to `Issue 5.1` / `Issue 5.2`.
- Review-target/session parity still needs explicit re-verification once legacy role fields stop being authoritative.
- Pending-tutor access is still modeled separately through `currentTutorId`.
