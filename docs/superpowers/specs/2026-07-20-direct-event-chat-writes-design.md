# Direct Event Chat Writes

## Goal

Make event-chat sends reach Firestore without the extra callable Cloud Function
round trip while preserving the current optimistic UI, participant-only access,
trusted sender identity, retry behavior, and rollback path.

The normal send path becomes one Firestore document create. The existing
`sendEventChatMessage` callable remains deployed for older app versions and as
a narrow compatibility fallback.

## Current Problem

The UI already inserts a local pending message before any network request, but
the message remains in `sending` until `sendEventChatMessage` returns. That
callable runs in `us-central1` and performs an authenticated Firestore
transaction that reads the event, chat metadata, participant, user, and
possibly an existing message before committing the write. Live calls around
the reported send took roughly 1.1-1.8 seconds, with warm calls still around
0.5 seconds.

Direct event-message creates are currently denied by Firestore Rules, so the
callable is the only production write path.

## Chosen Approach

Use a staged hybrid:

1. Firestore Rules allow a narrowly validated `create` at
   `eventChats/{eventId}/messages/{clientMessageId}`.
2. The Flutter client preloads the authenticated user's trusted event
   participant snapshot when opening the chat.
3. A send writes the canonical message document directly with the existing
   UUID v4 as its document ID.
4. `update` and `delete` remain denied to clients.
5. The callable remains available to old clients and is used by the new client
   only when the direct create definitively fails with `permission-denied`.

This removes the callable round trip for the normal path without weakening
identity checks or requiring a coordinated removal of the old backend.

## Alternatives Rejected

### Direct-only cutover

Removing the callable would reduce code paths, but it would remove the safest
rollback mechanism and could break older app versions. The callable will stay
deployed.

### Client-writable outbox plus server trigger

An outbox would keep all canonicalization on the server, but recipients would
still wait for a serverless trigger before the canonical message appeared. It
does not solve the latency goal.

### Looser Rules using the current user profile

Allowing client-provided display names or avatars without comparing them to a
server-owned participant snapshot would permit sender presentation spoofing.
The participant document remains the canonical sender snapshot.

## Canonical Message Contract

The direct create uses the existing six-field message shape and includes every
field, including nullable fields:

```text
senderId: auth uid
senderDisplayName: participant.displayName
senderPhotoUrl: participant.photoUrl or null
text: normalized non-empty message text
createdAt: FieldValue.serverTimestamp()
deletedAt: null
```

The document ID is the existing client-generated lowercase UUID v4. The same
ID is retained across pending UI, direct create, fallback callable, Firestore
stream reconciliation, and retry.

The Flutter canonicalizer must match the callable's current text transform in
this exact order:

1. normalize to Unicode NFC;
2. replace CRLF and bare CR with LF;
3. collapse runs of three or more LF characters to two LF characters;
4. trim leading and trailing whitespace;
5. require 1-1000 grapheme clusters.

Add `unorm_dart` as a direct dependency for NFC and `characters` as a direct
dependency for grapheme counting. The pending bubble, direct payload, fallback
payload, retry comparison, and tests all use the one shared canonicalizer. No
call site performs an additional independent trim or normalization.

Rules cannot prove NFC or count grapheme clusters. They enforce the following
strict, implementable subset:

- `text.size()` is 1-1000; Rules `String.size()` counts Unicode characters;
- `text == text.trim()`;
- removing CR characters does not change the string;
- replacing runs of three or more LF characters with two does not change the
  string.

The rule predicate is specified as:

```text
text is string
text.size() > 0 && text.size() <= 1000
text == text.trim()
text == text.replace('\\r', '')
text == text.replace('\\n{3,}', '\\n\\n')
```

`rules.String.trim()` is part of the current Firebase Rules String API. A
minimal Rules file using this predicate must compile under the repository's
pinned Firestore emulator before implementation proceeds; regex emulation of
trim is not an accepted substitute.

The character limit can reject a valid 1000-grapheme message made from
multi-code-point graphemes. That definitive `permission-denied` uses the
callable compatibility path, which retains the exact 1000-grapheme product
limit. A malicious direct client receives a stricter limit, never a broader
one. Rules tests pin `size`, `trim`, and `replace` behavior in the emulator.

## Firestore Security Rules

Client `create` is allowed only when all conditions hold:

- the request is authenticated;
- `clientMessageId` matches lowercase UUID v4 format;
- `eventChats/{eventId}` exists and has the existing exact valid metadata
  shape with `eventId` matching its document ID;
- `events/{eventId}` exists, points to the same chat, is `active`, and has
  `canceledAt == null`;
- `events/{eventId}/participants/{auth.uid}` exists, has the existing valid
  participant shape, is `active`, and has `leftAt == null`;
- the request contains exactly the six canonical message fields;
- `senderId == request.auth.uid`;
- `senderDisplayName` and `senderPhotoUrl` exactly equal the trusted
  participant snapshot;
- `text` is a canonical non-empty string satisfying the exact rule-level
  predicates above;
- `createdAt` is a timestamp equal to `request.time`, which requires a client
  server-timestamp sentinel;
- `deletedAt == null`.

Client `update` and `delete` remain unconditionally denied. Admin SDK behavior
used by moderation/tombstoning is unchanged because Admin SDK bypasses client
Rules.

Rules continue to deny direct writes from guests, nonparticipants, left
participants, participants of canceled events, and admin-claim users who are
not active participants.

## Trusted Participant Snapshot

The widget must not build the direct payload from `currentUserDocument` or
Firebase Auth profile fields. Those values may have changed since the user
joined the event and may differ from the server-owned participant snapshot.

`EventGroupChatRepository` exposes a dedicated
`watchOwnParticipantState(eventId, ownerUid)` stream. Its load state contains
the owner UID, event ID, parsed participant, raw display-name/photo values,
`isFromCache`, and `hasPendingWrites`. Production uses document snapshots with
metadata changes; tests inject the stream through a typed callback.

The widget derives one of three send modes for the current owner/event
generation:

- `direct`: chat access and participant state are server-authoritative
  (`!isFromCache && !hasPendingWrites`), the participant is active, and its
  sender snapshot satisfies the direct eligibility rules below;
- `callableOnly`: chat access is server-authoritative, but participant state is
  still cache-only, failed to load, or is active yet direct-ineligible because
  of legacy snapshot formatting;
- `disabled`: chat access is loading/denied, the owner/event does not match, or
  an authoritative participant is missing, left, or identity-mismatched.

`direct` enables the fast path. `callableOnly` keeps the composer enabled and
calls `sendEventChatMessage` immediately without first attempting a direct
create. An inline participant-refresh error may remain visible with retry, but
it does not block the trusted callable. `disabled` follows the existing access
loading/denied UI. Retry recreates both access and participant subscriptions.
Owner/event changes synchronously reset the mode to `disabled` and clear the
retained participant state before new subscriptions start.

Direct sender semantics are exact and do not use the callable's user-profile
fallback:

- `senderDisplayName` is the raw participant `displayName`. Direct eligibility
  additionally requires a non-empty, trimmed string no longer than 70
  characters, and the payload must equal it byte-for-byte.
- If participant `photoUrl` is missing or null, `senderPhotoUrl` is null.
- A present photo is eligible only when it is a non-empty, trimmed string no
  longer than 2048 characters; the payload must equal it byte-for-byte.
- A legacy active participant with untrimmed or otherwise direct-ineligible
  snapshot fields uses `callableOnly` when server-authoritative chat access is
  still valid.

The participant loader preserves missing/null/string photo semantics from the
raw snapshot rather than relying on the generated record's empty-string
getter. In `direct` mode, the pending bubble uses the same values as the direct
payload. In `callableOnly` mode, it uses the widget's existing current-user
name/photo only as provisional presentation; those values are never written
directly. The callable remains allowed to normalize the participant snapshot
or use its existing trusted user-profile fallback, and the authoritative
record then replaces the provisional presentation.

## Send Flow

1. Validate and normalize composer text.
2. Capture the current owner, event, action-boundary generation, and send mode.
3. Generate the UUID v4 and add the pending message synchronously.
4. Clear the composer immediately.
5. In `direct` mode, create `eventChats/{eventId}/messages/{uuid}` with the
   canonical participant payload. In `callableOnly` mode, invoke the callable
   immediately with the normalized text and UUID; its authoritative response
   supplies the final sender snapshot.
6. On success, mark the pending message sent and reconcile it with the
   authoritative Firestore record.
7. On definitive `permission-denied`, call `sendEventChatMessage` with the
   same event ID, normalized text, and UUID. Do not fall back on timeout,
   `unavailable`, or another ambiguous transport failure because the direct
   commit may still be pending.
8. On final failure, keep the bubble, mark it failed, show the existing error,
   and expose retry.

`EventGroupChatRepository` owns the participant stream, canonical direct-create
payload builder, production `DocumentReference.set`, server-only retry lookup,
and per-document snapshot metadata extraction. It exposes typed create and
lookup callbacks for tests. `EventActionsRepository` continues to own the
callable fallback. The widget owns only composer state, the pending-message
state machine, rendering, and existing auth/event lifecycle boundaries.

## Local Echo and Reconciliation

Firestore may emit a local document with the UUID before Security Rules have
accepted the write. The current merge code treats any matching record as
confirmed and prunes the in-memory pending message too early. That would make a
later Rules rejection remove the bubble before it can become failed.

The message load state exposes `pendingWriteMessagePaths` from each document's
`metadata.hasPendingWrites`, plus query-level `isFromCache`. Query-level
`hasPendingWrites` alone is insufficient when several messages are in flight.

Each in-memory item has an attempt serial and one of these phases:

- `sending`: a direct create or fallback is in flight;
- `sentAwaitingAuthoritativeRecord`: an operation returned success but the
  stream has not yet produced a server-authoritative matching record;
- `failed`: the final attempt failed and can be retried.

A confirmed record has no in-memory phase because the pending item is removed.
The transition table is order-independent:

| Input | Required transition and display |
| --- | --- |
| Local matching record with `hasPendingWrites == true` | Keep or recover `sending`; suppress the record and display one pending bubble. Never prune. |
| Direct/fallback operation succeeds first | Move to `sentAwaitingAuthoritativeRecord`; keep one pending bubble until an authoritative record arrives. |
| Server-authoritative matching record arrives first | Validate canonical shape, mark the UUID confirmed, remove the pending item, and display the record. Later success/error callbacks for older attempt serials are ignored. |
| Direct create returns `permission-denied` with no confirmed record | Keep `sending` while the callable fallback runs. |
| Final definite or ambiguous error with no confirmed record | Move to `failed`; keep the bubble and retry action. A later authoritative matching record still wins and clears the failure. |
| Local matching record is removed after previously being pending, with no authoritative match | Keep its recovered data and move to `failed`; do not make the bubble disappear. |
| Auth owner or event generation changes | Clear pending/recovered state, confirmed IDs, participant state, and ignore all older callbacks. |

An authoritative match requires the same UUID, current owner/event scope,
`senderId`, canonical text, non-null `createdAt`, valid canonical field shape,
document `hasPendingWrites == false`, and query `isFromCache == false`.

When no in-memory item exists but the stream exposes a local pending record,
the widget recovers a `sending` item from its six fields and records
`DateTime.now()` as a display-only sort time if `createdAt` is unresolved. This
covers route re-entry and process restart while the SDK still retains the
pending mutation. No frame renders both variants of the same UUID.

This mirrors the more mature pending-write handling already used by the
one-to-one chat while adding explicit recovery for the event-chat UUID.

## Retry and Ambiguous Outcomes

A second `set` to an existing UUID is an update and must remain forbidden by
Rules. Manual retry therefore begins with a `Source.server` read of the UUID:

- a document counts as the already-sent message only when it has the exact six
  fields, matching `senderId` and canonical text, a non-null valid
  `createdAt`, and `deletedAt == null`;
- a tombstoned, malformed, wrong-sender, or wrong-text document is a conflict;
  fail closed and do not overwrite it;
- if no document exists, retry the direct create;
- if the original commit wins after the missing read but before the second
  create, the create receives `permission-denied`; invoke the callable with the
  same UUID, and its existing transaction resolves the matching document
  idempotently;
- if the create receives `permission-denied` because access changed, the
  callable returns the existing stable product error and the bubble becomes
  failed;
- if the existence check cannot reach the server, keep the message failed and
  retryable rather than risking a conflicting write.

Every attempt receives a new serial. An authoritative matching record always
wins; completions from older serials cannot change a confirmed or newer
attempt. This also handles a late completion from the original operation after
the user pressed retry.

The callable's existing `clientMessageId` transaction remains idempotent and
interoperable with a document previously created by the direct path.

## Errors and Offline Behavior

- Local Firestore queueing is allowed: the bubble remains `sending` while the
  device is offline and resolves after reconnect.
- A permission or product-state rejection is mapped through the existing
  event-action error copy after the compatibility fallback also rejects it.
- Network and ambiguous Firestore errors do not trigger the callable
  automatically.
- Logout, event changes, or owner changes invalidate outstanding completions
  using the existing action-boundary generation checks.
- No stale participant snapshot or pending message may cross an owner/event
  boundary.
- Route re-entry, and process restart while Firestore still exposes the local
  pending document, recover a sending bubble from document metadata.
- A write rejected entirely while the app is closed cannot be reconstructed
  after Firestore has discarded the local document. A durable application
  outbox is explicitly out of scope for this latency change; the success
  criteria do not promise post-rejection recovery across a closed process.

## Compatibility and Rollout

Deployment order:

1. Add Rules and adversarial emulator tests.
2. Deploy Rules while the production app still uses the callable.
3. Release the direct-write client.
4. Observe direct-write errors, callable fallback rate, and send latency.
5. Keep the callable deployed for old clients.

Rollback does not require removing the new app: restore `allow create: false`.
New clients will receive definitive `permission-denied` and use the callable;
old clients are unaffected. This emergency mode is slower because it attempts
the denied direct create first, but it preserves message delivery.

Production Rules deployment is a separate explicit operational action after
the code and emulator tests pass.

## Documentation Updates

Update `TASKS.md` and `docs/events-prd.md` statements that currently declare
the callable the only allowed event-message write path. The revised contract
must describe direct create as the primary path and callable as the
compatibility/fallback path without loosening update/delete or moderation
rules.

## Verification

### Firestore Rules emulator

Allow:

- valid active participant create;
- valid active organizer create;
- exact participant snapshot, UUID, server timestamp, and canonical fields.

Deny:

- guest, nonparticipant, left participant, canceled event participant, and
  admin-only actor;
- missing, orphaned, or mismatched event/chat metadata;
- spoofed sender ID, display name, or photo;
- non-UUID document ID;
- client timestamp, null/missing timestamp, non-null `deletedAt`;
- missing fields, extra fields, wrong types, blank text, and oversized text;
- every client update, merge, delete, and batch bypass attempt.

### Dart repository/unit tests

- direct writer targets the UUID document path;
- payload contains exactly the six fields, including explicit nulls and server
  timestamp;
- text normalization and boundaries;
- trusted participant snapshot validation;
- permission-denied compatibility fallback uses the same UUID and text;
- ambiguous errors do not fall back;
- retry classifies matching, missing, and conflicting existing documents;
- canonicalizer matches callable NFC/newline/trim/grapheme behavior;
- direct-eligible participant snapshot preserves raw null/string semantics;
- direct-ineligible legacy participant uses callable-only mode without a
  direct-write attempt;
- rollback `permission-denied` causes exactly one callable fallback with the
  same UUID and produces no duplicate.

### Flutter widget tests

- pending bubble appears before the direct write completes;
- composer stays usable for concurrent sends;
- a local pending Firestore snapshot with the same UUID does not duplicate or
  prune the in-memory message;
- successful authoritative snapshot replaces pending exactly once;
- Rules rejection leaves a failed bubble and retry action;
- retry with an already-created matching UUID resolves as sent;
- logout, owner switch, and event switch ignore stale completions and clear
  old snapshots;
- route re-entry recovers a local pending document; rejection after recovery
  leaves a failed bubble;
- mixed snapshots with multiple concurrent messages use per-document pending
  metadata and reconcile each UUID independently.

### Commands

- `npm test -- --test-name-pattern` or the focused event Rules test command in
  `firebase/custom_cloud_functions`;
- focused Dart and widget tests for event chat;
- `flutter analyze`;
- `flutter test` when the focused checks pass.

If any broader check is skipped, the implementation handoff must explain why.

## Success Criteria

- A normal event message uses one direct Firestore create and does not invoke
  `sendEventChatMessage`.
- The sender sees the optimistic bubble in the same UI frame as today.
- The clock reflects only Firestore acknowledgement rather than callable plus
  transaction latency.
- Other participants receive the canonical message after the Firestore commit.
- Invalid or spoofed client creates are denied by Rules.
- Failed and ambiguous sends observed during the active or recovered local
  pending lifecycle remain visible and retryable without duplicates.
- Existing clients using the callable continue to work.
