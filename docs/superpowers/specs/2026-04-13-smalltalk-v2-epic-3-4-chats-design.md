# SmallTalk V2 Epic 3 + 4 Chats Design

Status: Approved for planning  
Date: 2026-04-13  
Owner: Product + Engineering

## Summary

This spec defines the MVP architecture for Epic 3 and Epic 4:

1. Add persistent 1:1 conversation and message storage.
2. Unlock messaging only after a completed connected call.
3. Implement the `Чаты` hub with inbox, friends, and call history.
4. Implement the 1:1 thread with plain-text messaging.

The approved direction is event-driven unlock, not client-side unlock and not direct unlock inside `endSession`.

This design intentionally supports only new completed calls after release. No retroactive unlock is performed for historical sessions.

## Goals

- Add a durable `conversations` root collection and `messages` subcollection.
- Enforce pair-based chat unlock only after a completed connected call.
- Keep unlock processing server-owned and idempotent.
- Reuse one deterministic conversation per participant pair.
- Turn the existing `Чаты` route into a communication hub with:
  - unlocked conversations
  - friends
  - call history
- Add a dedicated 1:1 thread screen with plain-text send.

## Non-Goals

- Retroactive unlock for old calls.
- Attachments, reactions, edits, deletes, typing indicators, or delivery receipts.
- Group chat.
- Replacing the existing in-call Daily chat overlay.
- Broad refactors of unrelated navigation, billing, or review flows.

## Current Context

- The current `Чаты` tab is the existing route implemented in `lib/students_pages/favorite/favorite_widget.dart`, and it currently renders the friends list.
- Persistent conversation and message schema do not yet exist.
- The current call lifecycle is centered on `videoSessions`.
- `firebase/custom_cloud_functions/end_session.js` is the canonical session teardown path for connected calls, but unlock must not be embedded there as direct conversation creation logic.
- Firestore rules currently do not define access for conversations or messages.
- In-call Daily chat already exists in `lib/custom_code/widgets/minimal_daily_widget.dart`, but it is transient and must remain separate from the persistent messaging MVP.

## Architecture Overview

The system is split into six bounded units:

1. Unlock event producer
2. Unlock event processor
3. Conversation and message data model
4. Message summary updater
5. Firestore rules
6. Chat surfaces in the Flutter app

Each unit has one clear responsibility:

- The producer emits unlock work after a qualifying session ends.
- The processor validates the event and unlocks the pair conversation.
- The data model stores unlocked conversations and messages.
- The summary updater maintains inbox preview fields after message creation.
- Firestore rules enforce participant-only access and prevent client-side unlock.
- The app renders the chat hub, thread UI, and entry points without owning unlock decisions.

## Unit 1: Unlock Event Producer

### Responsibility

Publish an unlock event for a newly completed connected call.

### Location

Primary hook: `firebase/custom_cloud_functions/end_session.js`

### Behavior

After the session teardown transaction succeeds, the producer attempts to write:

`conversationUnlockEvents/{sessionId}`

with:

- `sessionRef`
- `sessionId`
- `participantIds`
- `pairId`
- `status: "pending"`
- `createdAt`
- `updatedAt`
- `source: "endSession"`

### Unlock Event Schema

Document path:

`conversationUnlockEvents/{sessionId}`

Required fields:

- `sessionId: string`
- `sessionRef: DocumentReference`
- `participantIds: List<String>`
- `participantRefs: List<DocumentReference>`
- `pairId: string`
- `source: "endSession" | "repairMissingConversationUnlockEvents"`
- `status: "pending" | "processing" | "processed" | "ignored" | "failed"`
- `reason: string?`
- `attemptCount: int`
- `createdAt: Timestamp`
- `updatedAt: Timestamp`

Processor-owned fields:

- `processingStartedAt: Timestamp?`
- `processedAt: Timestamp?`
- `conversationRef: DocumentReference?`
- `errorCode: string?`
- `errorMessage: string?`

`reason` is used for terminal explanations such as `processed_unlocked`, `processed_existing_conversation`, `ignored_not_connected`, `ignored_invalid_pair`, or `failed_exception`.

The event document is the persisted interface between session teardown and conversation unlock. Producer code may create only `pending` events. Processor code owns all later state transitions.

### Unlock Event State Transitions

| From | To | Actor | Field updates |
| --- | --- | --- | --- |
| missing | `pending` | producer | sets required producer fields, `attemptCount: 0`, `createdAt`, `updatedAt` |
| `pending` | `processing` | processor | increments `attemptCount`, sets `processingStartedAt`, clears `errorCode` and `errorMessage`, sets `updatedAt` |
| `processing` | `processed` | processor | sets `conversationRef`, `reason`, `processedAt`, `updatedAt` |
| `processing` | `ignored` | processor | sets `reason`, `processedAt`, `updatedAt`; leaves `conversationRef` empty |
| `processing` | `failed` | processor | sets `reason: "failed_exception"`, `errorCode`, `errorMessage`, `processedAt`, `updatedAt` |
| `processing` | `pending` | `repairMissingConversationUnlockEvents` | allowed only for stale `processing`; clears `processingStartedAt`, `processedAt`, `errorCode`, and `errorMessage`; keeps `attemptCount`; sets `updatedAt`, `source: "repairMissingConversationUnlockEvents"` |
| `failed` | `pending` | `repairMissingConversationUnlockEvents` | clears `processingStartedAt`, `processedAt`, `errorCode`, and `errorMessage`; keeps `attemptCount`; sets `updatedAt`, `source: "repairMissingConversationUnlockEvents"` |

`processed` and `ignored` are terminal states. Normal client code cannot reset any event state. If a processor instance crashes after setting `processing`, trusted retry tooling may reset stale `processing` events to `pending` while keeping the existing `attemptCount`.

### Eligibility

An event is emitted only for a session that:

- ended successfully
- has a valid participant pair
- has evidence of a real connected call
- was created at or after the configured chats rollout timestamp

Connected-call evidence uses the existing session metadata with fallback:

- `sessionMetadata.callConnectedAt`
- legacy `sessionMetadata.callConnectedAtTimestamp`
- guarded fallback derived from `startedAt` only where already supported by current session logic

### Constraints

- The producer does not create or update `conversations`.
- The producer does not block session teardown, billing, or navigation if event creation fails.
- Event identity is one document per `sessionId`, so duplicate event creation is naturally limited.

For this spec, a "qualifying session" always includes the rollout guard above. Historical sessions created before rollout are out of scope even if `endSession` is called again later.

## Unit 2: Unlock Event Processor

### Responsibility

Consume unlock events and idempotently create or unlock the pair conversation.

### Location

Firebase Cloud Function triggered from `conversationUnlockEvents`.

### Event State Model

- `pending`
- `processing`
- `processed`
- `ignored`
- `failed`

### Processing Rules

For each event, the processor:

1. Loads the referenced `videoSessions/{sessionId}` document.
2. Validates that the session reached an ended state after a connected call.
3. Validates the pair and deterministic `pairId`.
4. Creates or reuses `conversations/{pairId}`.
5. Marks the event terminally as `processed`, `ignored`, or `failed`.

The processor may be implemented as a create/update trigger on `conversationUnlockEvents`, but it must process only non-terminal events. Events already marked `processed` or `ignored` are no-ops. Failed events may be retried only by explicitly resetting their status to `pending` or by an implementation-defined retry path that increments `attemptCount`.

### Recovery Policy

- A `processing` event is considered stale if `processingStartedAt` is older than 5 minutes and the event is not terminal.
- Trusted backend retry tooling is responsible for reclaiming stale `processing` events by resetting them to `pending`.
- The same retry tooling may also create a missing `conversationUnlockEvents/{sessionId}` document for a qualifying ended session when the original producer path failed and no event exists.
- The repair tooling is automatic and scoped only to sessions that satisfy the rollout guard. It is not a historical backfill job.

### Repair Mechanism

The repair owner is a scheduled backend worker:

- name: `repairMissingConversationUnlockEvents`
- cadence: every 5 minutes
- scope: all `videoSessions` created after rollout and qualifying for messaging unlock
- scan contract:
  - maintain a persistent cursor over post-rollout `videoSessions` ordered by `createdAt asc`, then `documentId asc`
  - process one bounded page per run
  - when the cursor reaches the current head, restart from the rollout boundary on the next cycle
- behavior:
  - page through qualifying ended sessions after rollout
  - find sessions with no `conversationUnlockEvents/{sessionId}`
  - create the missing event as `pending` with `source: "repairMissingConversationUnlockEvents"`
  - reset stale `processing` events to `pending`

This worker is the canonical and only missed-unlock recovery path in MVP.

### Repair Ownership

| Failure mode | Owner | Mechanism |
| --- | --- | --- |
| initial unlock event production after qualifying `endSession` | `endSession` producer path | create `conversationUnlockEvents/{sessionId}` with `source: "endSession"` |
| missing unlock event after producer failure | `repairMissingConversationUnlockEvents` | create missing `pending` event |
| stale or failed unlock-event processing | `repairMissingConversationUnlockEvents` | reset stale or failed events to `pending` |
| missed or stale `lastMessage*` summary fields | `repairConversationMessageSummaries` | reconcile conversation summary from newest message |

### Conversation Creation Rules

The processor creates or reuses:

`conversations/{sortedUidA_sortedUidB}`

Rules:

- exactly one conversation per pair
- repeat completed calls reuse the same conversation
- first qualifying session sets unlock metadata
- later qualifying sessions must not overwrite first unlock metadata

### Transaction and Idempotency

Processor work must be transactional across the event document and the target conversation document to avoid duplicate creation under retries or parallel execution.

Safe rerun behavior:

- if the conversation already exists and is unlocked, the processor must keep it
- if the event was already terminally processed, reruns must be no-ops
- duplicate triggers must not create duplicate conversations

## Unit 3: Data Model

### Pair ID Canonicalization

The canonical pair identifier is generated from the two Firebase Auth UID strings:

1. Convert both IDs to raw strings.
2. Sort ascending by code-unit lexicographic order.
3. Join with a single underscore: `<lowerUid>_<higherUid>`.

The generated value is stored as `pairId` and used as the Firestore document ID for the conversation.

The app and backend must use the same helper algorithm. `pairId` is treated as an opaque identifier; code must not parse it back to recover participants because UIDs can contain separator-like characters. Participant identity always comes from `participantIds` and `participantRefs`.

Unread interpretation rules:

- If the conversation has no `lastMessageAt`, it has no unread state.
- If the current user has no `lastReadAtByUserId[currentUserUid]` entry and `lastMessageSenderId != currentUserUid`, the conversation is unread.
- If the current user has a read marker, unread is determined by comparing `lastReadAtByUserId[currentUserUid] < lastMessageAt`.
- A message authored by the current user does not create an unread badge for that same user.
- While the 1:1 thread is foregrounded on the current device, the conversation is treated as locally read and the client must advance the read marker again whenever `lastMessageAt` changes. This is the MVP race-healing rule for concurrent summary and read-marker updates.

### Conversations

Document path:

`conversations/{pairId}`

Fields:

- `pairId: string`
- `participantIds: List<String>`
- `participantRefs: List<DocumentReference>`
- `isUnlocked: bool`
- `unlockedAt: Timestamp`
- `unlockedBySessionRef: DocumentReference`
- `createdAt: Timestamp`
- `updatedAt: Timestamp`
- `lastMessageAt: Timestamp?`
- `lastMessageText: String?`
- `lastMessageSenderId: String?`
- `lastMessageId: String?`
- `lastReadAtByUserId: Map<String, Timestamp?>`

Conversation creation initializes:

- `lastMessageAt = null`
- `lastMessageText = null`
- `lastMessageSenderId = null`
- `lastMessageId = null`
- `lastReadAtByUserId = {}`

### Messages

Document path:

`conversations/{pairId}/messages/{messageId}`

Fields:

- `senderId: string`
- `senderRef: DocumentReference`
- `type: "text"`
- `text: string`
- `createdAt: Timestamp`

`createdAt` is server-assigned. The Flutter client writes it with Firestore server timestamp semantics; rules reject arbitrary client-chosen timestamps.

### Design Notes

- `pairId` is deterministic from sorted participant IDs.
- `lastMessage*` lives on the conversation root to support inbox rendering without fetching the newest message document for every row.
- `lastReadAtByUserId` supports MVP unread state without a separate unread counter service.
- Message type is constrained to plain text for this release.

## Unit 4: Message Summary Updater

### Responsibility

Keep conversation inbox summary fields synchronized after a participant sends a text message.

### Location

Firebase Cloud Function triggered from:

`conversations/{pairId}/messages/{messageId}`

### Behavior

When a valid message is created, the updater writes to the parent conversation:

- `lastMessageAt`
- `lastMessageText`
- `lastMessageSenderId`
- `lastMessageId`
- `updatedAt`

The updater must verify the parent conversation still exists, is unlocked, and contains the message sender as a participant.

### Stale-Write Protection

The updater must use a transaction and compare the incoming message against the current parent summary.

Authoritative ordering tuple:

1. `message.createdAt`
2. `messageId` as a deterministic tie-breaker

The updater writes the parent summary only if the incoming tuple is newer than the existing tuple `(lastMessageAt, lastMessageId)`. Older or duplicate trigger deliveries are no-ops and must not regress inbox ordering or previews.

### Constraints

- Client code does not update `lastMessage*` fields directly.
- Message creation remains participant-only.
- The updater is idempotent: repeated handling of the same message must leave the parent conversation in a valid latest-message state.
- The updater must update only summary fields and must preserve `lastReadAtByUserId`, unlock metadata, and participant metadata via transaction field merge semantics.

### Summary Repair Mechanism

Missed or failed `lastMessage*` updates are recovered by a scheduled backend worker:

- name: `repairConversationMessageSummaries`
- cadence: every 10 minutes
- scope: post-rollout conversations
- scan contract:
  - maintain a persistent cursor over `conversations` ordered by `updatedAt asc`, then `documentId asc`
  - process one bounded page per run
  - for each conversation, compare parent summary fields against the newest message tuple `(createdAt, messageId)`
  - if mismatched, repair `lastMessageAt`, `lastMessageText`, `lastMessageSenderId`, `lastMessageId`, and `updatedAt`

This worker is the canonical reconciliation path for stale inbox previews and ordering after trigger failure.

## Unit 5: Firestore Rules

Add new rules for `conversations` and `messages`.

### Unlock Event Rules

- Client create, read, update, and delete are not allowed for `conversationUnlockEvents`.
- Unlock events are written and processed only by trusted backend code.

### Conversation Rules

- Read allowed only for participants listed in `participantIds`.
- Client create is not allowed.
- Client delete is not allowed.
- Client update is limited to safe participant-owned read marker updates.
- Unlock metadata and participant membership are server-owned only.

Allowed client conversation update shape:

- A participant may update only `lastReadAtByUserId.<auth.uid>`.
- The value must equal `request.time`.
- The new value must be greater than or equal to the previous value for `lastReadAtByUserId.<auth.uid>` when that previous value exists.
- The top-level document diff must change only `lastReadAtByUserId`.
- Inside the map diff, only the entry for `<auth.uid>` may change.
- Existing sibling entries for other user IDs must remain byte-for-byte unchanged.
- The update must preserve all existing keys in `lastReadAtByUserId`; replacing the whole map is not allowed.
- No client update may change `participantIds`, `participantRefs`, `pairId`, `isUnlocked`, `unlockedAt`, `unlockedBySessionRef`, `lastMessageAt`, `lastMessageText`, `lastMessageSenderId`, `lastMessageId`, `createdAt`, or `updatedAt`.
- Conversation summary fields are updated by trusted backend code when a message is sent.

The Flutter app may optimistically request a read-marker update, but Firestore rules must reject every other conversation-field mutation from client code.

### Message Rules

- Read allowed only for conversation participants.
- Create allowed only for a participant of an unlocked conversation.
- The client may create messages only with its own `senderId` and `senderRef`.
- Client update and delete are not allowed in MVP.

Allowed client message create shape:

- `senderId == request.auth.uid`
- `senderRef == /databases/$(database)/documents/users/$(request.auth.uid)`
- `type == "text"`
- `text` is a non-empty string
- `createdAt == request.time`
- no additional client-owned fields are accepted

The backend may update the parent conversation summary after a message create.

### Rules Matrix

| Resource | Actor | Create | Read | Update | Delete |
| --- | --- | --- | --- | --- | --- |
| `conversations/{pairId}` | backend | yes | yes | yes | no normal path |
| `conversations/{pairId}` | participant client | no | yes | only own read marker | no |
| `conversations/{pairId}` | non-participant client | no | no | no | no |
| `messages/{messageId}` | participant client | yes, text only as self | yes | no | no |
| `messages/{messageId}` | non-participant client | no | no | no | no |

### Security Goals

- A client cannot self-unlock a chat.
- A client cannot forge a conversation for an arbitrary pair.
- A non-participant cannot read conversations or messages.
- A participant cannot send on behalf of the other participant.
- A client cannot read or mutate unlock-event internals.

## Unit 6: Flutter App Design

## Chats Hub

The current route remains the user-facing `Чаты` destination, but its contents change from a friends-only list into a communications hub.

### Sections

1. `Сообщения`
2. `Друзья`
3. `Звонки`

### Messages Section

- Shows unlocked conversations for the current user.
- Sort order uses one total tuple for every row:
  - `conversationSortAt = lastMessageAt ?? unlockedAt`
  - `conversationSortId = lastMessageId ?? pairId`
  - final order: `(conversationSortAt, conversationSortId, pairId) desc`
- The Flutter inbox must apply this sort tuple in memory after fetching the participant's conversations.
- Each row shows:
  - avatar
  - display name
  - last message preview when present
  - timestamp
  - unread indicator derived from `lastReadAtByUserId`

### Friends Section

- Reuses the existing friends model introduced in Epic 2.
- Opening a friend still opens the profile surface.
- A friend card may expose an open-chat CTA only if the pair conversation already exists and is unlocked.

### Calls Section

- Reuses existing `videoSessions`-based call history logic in compact form.
- This is a summary surface in the hub, not a replacement for deeper call-history pages that may already exist elsewhere.
- Shows a capped recent-history preview, not the full call-history product surface.
- Data source interface: `fetchRecentHubCallSessions(currentUserUid, limit: 5)`.
- The interface runs a union of participant queries for `studentId == currentUserUid`, `tutorId == currentUserUid`, and `currentTutorId == currentUserUid`.
- In MVP, each branch query fetches the full matching set for that participant role, then the three branches are unioned in memory.
- This full-fetch union is an intentional MVP contract based on bounded per-user call volume in the current product.
- Results are deduped by `VideoSessionsRecord.reference.path`.
- Results are filtered to `status == "ended"`.
- Recency is sorted after dedupe, using the existing call-history resolver order: `sessionMetadata.callConnectedAt`, then `startedAt`, then `createdAt`.
- Tie-break order after the resolved recency timestamp is `endedAt desc`, then `VideoSessionsRecord.reference.path desc`.
- Rows show only completed call-history entries already considered valid by existing call-history logic, with the peer identity, call time, and duration when available.
- Final hub limit is applied after fetch, dedupe, filter, and sort. Initial MVP cap: recent 5 entries.
- If there are no call-history entries, the `Звонки` section is hidden unless both conversations and calls are absent, in which case the approved hub empty state is shown.

### Empty State

If the user has no conversations and no call history, the hub shows:

`Пусто. У вас пока нет звонков и сообщений`

Friends may still exist below, but the communication empty state is defined by the absence of calls and messages.

## 1:1 Thread Screen

### Responsibility

Render one unlocked conversation and allow plain-text send.

### Layout

- header with partner avatar and name
- message list ordered by `(createdAt, messageId) asc`
- bottom composer for text send

### Behavior

- Opening the thread updates the current user's read marker.
- After the first thread snapshot is visible, and on every later change to `lastMessageAt` while the thread stays foregrounded, the client advances the read marker again to `request.time`.
- Sending a message creates a message document and updates conversation summary fields.
- Normal entry points never route into a locked or missing conversation.

### Out of Scope

- edit or delete messages
- attachments
- typing states
- optimistic multi-device sync beyond standard Firestore stream behavior

## Entry Points

### Post-call

- If the unlock event is processed and the conversation exists, the post-call surface can show `Открыть чат`.
- If the event is still pending or failed, the CTA is not shown.

### Friend Surfaces

- Friend-related UI may show `Открыть чат` only for an unlocked pair.
- Friend profile access remains independent from chat unlock.

### Chats Hub

- The inbox is the primary path into unlocked threads.

## Failure Handling

### Event Creation Failure

- Session teardown still succeeds.
- Messaging for that session remains locked until the missing event is retried manually or by follow-up tooling.
- Event creation failure must be logged clearly.

### Event Processing Failure

- The event is marked `failed` with:
  - `errorCode`
  - `errorMessage`
  - `attemptCount`
  - `processedAt`
- The processor must be safe to retry.

### Ignored Event Cases

Use `ignored` when:

- the session was cancelled, expired, or never connected
- the session lacks a valid participant pair
- the session data does not satisfy unlock requirements

## Indexes

Expected Firestore index requirements:

- `conversations` queried by `participantIds arrayContains`, with inbox ordering applied client-side after fetch in MVP
- standard ordered reads for `messages` by `createdAt`

Exact composite index definitions should be added only for the queries used by the final UI implementation. The computed inbox tuple `(lastMessageAt ?? unlockedAt, lastMessageId ?? pairId, pairId)` is not materialized as a dedicated Firestore sort field in this MVP.

## Testing and Validation

### Processor Validation

- completed connected session creates an unlock event and unlocks one conversation
- cancelled or never-connected session results in `ignored`
- repeated completed sessions for the same pair reuse the same conversation
- duplicate processor runs remain idempotent

### Rules Validation

- non-participant cannot read conversation or messages
- participant can read unlocked conversation and messages
- participant cannot create a conversation directly
- participant cannot send a message as another user

### App Validation

- `Чаты` renders messages, friends, and calls in one hub
- empty state copy matches the approved product text
- post-call CTA opens the unlocked thread only after processing succeeds
- friend surface shows open-chat CTA only when messaging is unlocked
- existing call flows, reviews, and friend flows do not regress

## Rollout Notes

- Unlock applies only to new completed calls after release.
- Two post-rollout repair workers are included in this MVP:
  - `repairMissingConversationUnlockEvents`
  - `repairConversationMessageSummaries`
- No historical backfill job is included in this MVP.
- Historical completed sessions do not create conversations automatically.

## Open Decisions Already Resolved

- Unlock model: event-driven server-owned unlock
- Historical sessions: no retroactive unlock
- Message scope: plain-text 1:1 only
- Chat placement: inside the existing `Чаты` destination
