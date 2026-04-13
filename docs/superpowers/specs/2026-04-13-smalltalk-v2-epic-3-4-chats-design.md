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

The system is split into four bounded units:

1. Unlock event producer
2. Unlock event processor
3. Conversation and message data model
4. Chat surfaces in the Flutter app

Each unit has one clear responsibility:

- The producer emits unlock work after a qualifying session ends.
- The processor validates the event and unlocks the pair conversation.
- The data model stores unlocked conversations and messages.
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
- `source: "endSession"`

### Eligibility

An event is emitted only for a session that:

- ended successfully
- has a valid participant pair
- has evidence of a real connected call

Connected-call evidence uses the existing session metadata with fallback:

- `sessionMetadata.callConnectedAt`
- legacy `sessionMetadata.callConnectedAtTimestamp`
- guarded fallback derived from `startedAt` only where already supported by current session logic

### Constraints

- The producer does not create or update `conversations`.
- The producer does not block session teardown, billing, or navigation if event creation fails.
- Event identity is one document per `sessionId`, so duplicate event creation is naturally limited.

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
- `lastReadAtByUserId: Map<String, Timestamp?>`

### Messages

Document path:

`conversations/{pairId}/messages/{messageId}`

Fields:

- `senderId: string`
- `senderRef: DocumentReference`
- `type: "text"`
- `text: string`
- `createdAt: Timestamp`

### Design Notes

- `pairId` is deterministic from sorted participant IDs.
- `lastMessage*` lives on the conversation root to support inbox rendering without fetching the newest message document for every row.
- `lastReadAtByUserId` supports MVP unread state without a separate unread counter service.
- Message type is constrained to plain text for this release.

## Unit 4: Firestore Rules

Add new rules for `conversations` and `messages`.

### Conversation Rules

- Read allowed only for participants listed in `participantIds`.
- Client create is not allowed.
- Client delete is not allowed.
- Client update is limited to safe participant-owned read marker updates.
- Unlock metadata and participant membership are server-owned only.

### Message Rules

- Read allowed only for conversation participants.
- Create allowed only for a participant of an unlocked conversation.
- The client may create messages only with its own `senderId` and `senderRef`.
- Client update and delete are not allowed in MVP.

### Security Goals

- A client cannot self-unlock a chat.
- A client cannot forge a conversation for an arbitrary pair.
- A non-participant cannot read conversations or messages.
- A participant cannot send on behalf of the other participant.

## Flutter App Design

## Chats Hub

The current route remains the user-facing `Чаты` destination, but its contents change from a friends-only list into a communications hub.

### Sections

1. `Сообщения`
2. `Друзья`
3. `Звонки`

### Messages Section

- Shows unlocked conversations for the current user.
- Sort order:
  - `lastMessageAt desc` when available
  - fallback to `updatedAt desc` or `unlockedAt desc` for newly unlocked empty threads
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

### Empty State

If the user has no conversations and no call history, the hub shows:

`Пусто. У вас пока нет звонков и сообщений`

Friends may still exist below, but the communication empty state is defined by the absence of calls and messages.

## 1:1 Thread Screen

### Responsibility

Render one unlocked conversation and allow plain-text send.

### Layout

- header with partner avatar and name
- message list ordered by `createdAt asc`
- bottom composer for text send

### Behavior

- Opening the thread updates the current user's read marker.
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

- `conversations` with `participantIds arrayContains` + descending recency field for inbox sorting
- standard ordered reads for `messages` by `createdAt`

Exact composite index definitions should be added only for the queries used by the final UI implementation.

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
- No backfill job is included in this MVP.
- Historical completed sessions do not create conversations automatically.

## Open Decisions Already Resolved

- Unlock model: event-driven server-owned unlock
- Historical sessions: no retroactive unlock
- Message scope: plain-text 1:1 only
- Chat placement: inside the existing `Чаты` destination
