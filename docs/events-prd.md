# SmallTalk Events PRD

Status: Draft  
Date: 2026-06-14  
Owner: Product + Engineering

## 1. Executive Summary

### Problem Statement

SmallTalk needs an offline practice layer: users should be able to find language meetings in their city, join them instantly, coordinate with participants, and create their own events without admin approval.

### Proposed Solution

Add a new `События` section with city-aware event discovery, event creation, event details, instant join, participant-only group chat, event sharing, leave flow, and organizer edit/cancel controls. MVP is offline-only, Firebase-backed, and available to any authorized user.

### Success Criteria

- At least 20% of monthly active users open `События` within 30 days after release.
- At least 10% of event detail views convert into `Присоединиться`.
- At least 30% of created events receive 2+ participants.
- At least 50% of event participants open the group chat before the event starts.
- Join/leave transaction failures stay below 1% of attempts.

## 2. User Experience & Functionality

### User Personas

- **Participant**: wants to find an offline language practice event matching their city, schedule, language, and level.
- **Organizer**: wants to create and manage an offline event, gather participants, and communicate in a group chat.
- **Shared-link user**: receives an event link and wants to open the event detail directly.

### Product Scope

MVP includes:

- Event list tab.
- City-aware event discovery.
- Date filters: `Сегодня`, `Завтра`, `На этой неделе`, `В этом месяце`.
- Level filters: `A1`, `A2`, `B1`, `B2`, `C1`, `C2`.
- Event cards.
- Event detail screen.
- Event creation screen.
- Instant join.
- Leave event.
- Organizer edit event.
- Organizer cancel event.
- Participant-only group chat.
- Event sharing through native share sheet.
- Limit: one user can create up to 5 events per calendar day.

### Screens

#### Event List

Entry point: bottom tab `События`.

Required UI:

- Header `События`.
- Create button `+`.
- City selector/state.
- Date filter chips.
- Level filter chips.
- Event cards.
- Empty state when no events match filters.
- Loading and error states.

City behavior:

- If the user has a saved registration/profile location, events are filtered by that city by default.
- If location is missing, show a required location prompt before rendering the normal list.
- Prompt options:
  - quick city chips, for example popular/recent cities;
  - action to fill/save profile location.
- User can change the city from the Events screen.
- MVP should filter by city, not by map radius.

Event card must show:

- Organizer avatar and name.
- Event title.
- Short description.
- Level/range badge, for example `B1-C1`.
- Date and time.
- Place name/address.
- Participant avatar stack.
- Occupancy, for example `5/10 мест`.
- Primary CTA:
  - `Присоединиться` if user is not a participant and event has free spots;
  - `Вы присоединились` or equivalent participant state after join;
  - disabled/full state if no spots remain.
- Secondary CTA `Чат`.

#### Event Detail

Required UI:

- Back button.
- Share button.
- Level/range badge.
- Language badge.
- Title.
- Full description.
- Organizer card with `Написать`.
- Date, time, and place.
- Participant list.
- Occupancy.
- Sticky bottom actions:
  - `Присоединиться` for non-participants;
  - `Выйти` or joined state for participants;
  - `Чат`.

Participant behavior:

- User joins instantly when tapping `Присоединиться`.
- User can leave the event after joining.
- User cannot join a full, canceled, past, or already joined event.
- User loses group chat access after leaving.

Organizer behavior:

- Organizer can edit event details.
- Organizer can cancel the event.
- Organizer cannot use ordinary `Выйти`; they must cancel the event or keep ownership.
- Organizer is included in the group chat by default.

Canceled event behavior:

- Canceled events do not appear in the main active list.
- Direct link to a canceled event opens detail with canceled status.
- Join is disabled.
- Chat can remain readable for existing participants, but sending messages after cancellation is TBD.

#### Create Event

Any authorized user can create an event.

Required fields:

- Title.
- Description.
- Language.
- Level or level range.
- Date.
- Time.
- City.
- Place/address.
- Participant limit.

Validation:

- Title is required.
- Title max length is 70 user-perceived characters, meaning grapheme clusters, after trimming and whitespace normalization.
- Title must be single-line; line breaks are not allowed.
- Description is required.
- Language is required.
- Level/range is required.
- Date/time must be in the future.
- City is required.
- Place/address is required.
- Participant limit must be at least 2.
- User cannot create more than 5 events per calendar day.

After successful creation:

- Creator becomes organizer.
- Organizer is added as event participant.
- Event group chat is created or reserved with `chatId = eventId`.
- App opens the created event detail.

#### Edit Event

Only organizer can edit.

Editable fields:

- Title.
- Description.
- Language.
- Level/range.
- Date/time.
- City.
- Place/address.
- Participant limit.

Rules:

- Edited title must pass the same validation as create: required after normalization, max 70 grapheme clusters, single-line.
- Cannot edit past events.
- Cannot edit canceled events.
- Cannot reduce participant limit below current participant count.
- Updates are visible in list/detail immediately after Firebase write.
- MVP has no push notifications; participants see changes only in app.

#### Cancel Event

Only organizer can cancel.

Required behavior:

- Show confirmation before canceling.
- Set event status to `canceled`.
- Hide from active list.
- Disable join.
- Keep event accessible through direct link/history where applicable.
- MVP has no push notifications.

#### Group Chat

Chat rules:

- One group chat per event.
- Chat is accessible only after user joins the event.
- Organizer is a member by default.
- New participants can read previous messages.
- Users who leave lose read/write access.
- Non-participants cannot read or write messages.

Entry points:

- Event card `Чат`.
- Event detail sticky action `Чат`.

If user is not a participant:

- Do not open chat.
- Show CTA/state: `Сначала присоединитесь к событию`.

#### Share Event

Required behavior:

- Detail screen share button opens native share sheet.
- Shared payload includes event title, date/time, place, and deep link.
- Deep link opens event detail.

Example payload:

```text
Разговорный клуб: кофе и английский
Сегодня в 18:00, Starbucks, ул. Арбат, 5
Присоединиться: {eventDeepLink}
```

Fallback if app is not installed is TBD.

### User Stories

#### Story 1: Browse Events

As a user, I want to browse offline events in my city so that I can find relevant language practice nearby.

Acceptance criteria:

- User sees active future events for selected city.
- If profile location exists, it is selected by default.
- If profile location is missing, user is prompted to choose/fill location.
- Date and level filters update the list.
- Past and canceled events are hidden from the main list.

#### Story 2: Join Event

As a user, I want to join an event instantly so that I can reserve a spot without organizer approval.

Acceptance criteria:

- Tapping `Присоединиться` adds the user as participant.
- Occupancy updates atomically.
- User cannot join twice.
- User cannot join if event is full, canceled, or past.
- Join operation cannot exceed capacity under concurrent attempts.

#### Story 3: Leave Event

As a participant, I want to leave an event so that my spot becomes available.

Acceptance criteria:

- Participant can leave before the event starts.
- Leaving removes participant document or marks it inactive.
- Occupancy decrements atomically.
- User loses event chat access after leaving.
- Organizer cannot leave through this flow.

#### Story 4: Create Event

As a user, I want to create an offline event so that I can organize language practice.

Acceptance criteria:

- Any authorized user can open creation screen.
- Required fields are validated.
- Event cannot be created in the past.
- User cannot create more than 5 events per calendar day.
- After creation, user becomes organizer and participant.
- Event appears in the selected city list.

#### Story 5: Edit Event

As an organizer, I want to edit my event so that I can correct details or update plans.

Acceptance criteria:

- Only organizer can edit.
- Current values are prefilled.
- Capacity cannot be lowered below current participant count.
- Saved changes update list and detail data.
- Non-organizers cannot access edit controls or write updates.

#### Story 6: Cancel Event

As an organizer, I want to cancel my event so that users stop joining unavailable meetings.

Acceptance criteria:

- Only organizer can cancel.
- Confirmation is required.
- Canceled event disappears from active list.
- Direct link shows canceled state.
- Join is disabled.

#### Story 7: Use Group Chat

As a participant, I want to chat with event participants so that we can coordinate before the meeting.

Acceptance criteria:

- Chat opens only for participants.
- Messages are visible to event participants.
- Non-participants cannot read or write messages.
- User who leaves loses access.

#### Story 8: Share Event

As a user, I want to share an event so that I can invite friends.

Acceptance criteria:

- Share button opens native share sheet.
- Shared text includes event title, time, place, and link.
- Link routes to event detail when opened in app.

### Non-Goals

Not included in MVP:

- Online events.
- Push notifications.
- Payments/tickets.
- Waitlist.
- Organizer approval flow.
- Map/radius search.
- Event recommendations.
- Ratings/reviews for organizers.
- Advanced moderation workflow.
- Event cover images.

## 3. AI System Requirements

Not applicable. This feature does not require AI behavior.

## 4. Technical Specifications

### Architecture Overview

- Client: Flutter.
- Backend: Firebase.
- Auth: Firebase Auth.
- Database: Cloud Firestore.
- Optional later: Firebase Storage for event images.
- Deep links: Firebase/App Links setup TBD.

Core flow:

1. User opens `События`.
2. App resolves selected city from profile or local temporary city selection.
3. App queries active future events by city, date range, and optional level.
4. User opens detail or creates event.
5. Join/leave/edit/cancel writes go through transaction-safe Firebase logic.
6. Event chat reads/writes are protected by participant membership.

### Suggested Firestore Model

#### `events/{eventId}`

```json
{
  "title": "Разговорный клуб: кофе и английский",
  "description": "Неформальная встреча для практики разговорного английского.",
  "language": "english",
  "levelMin": "B1",
  "levelMax": "C1",
  "countryCode": "RU",
  "city": "Москва",
  "locationName": "Starbucks, ул. Арбат, 5",
  "locationGeoPoint": null,
  "startsAt": "timestamp",
  "capacity": 10,
  "participantsCount": 5,
  "organizerId": "uid",
  "chatId": "eventId",
  "status": "active",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "canceledAt": null
}
```

#### `events/{eventId}/participants/{userId}`

```json
{
  "userId": "uid",
  "displayName": "Марко",
  "photoUrl": "...",
  "role": "organizer|participant",
  "joinedAt": "timestamp",
  "leftAt": null,
  "status": "active"
}
```

#### `eventChats/{chatId}`

```json
{
  "eventId": "eventId",
  "participantIds": ["uid1", "uid2"],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### `eventChats/{chatId}/messages/{messageId}`

```json
{
  "senderId": "uid",
  "text": "Всем привет!",
  "createdAt": "timestamp",
  "deletedAt": null
}
```

#### User profile fields

Use existing profile fields if already present. Required product meaning:

```json
{
  "countryCode": "RU",
  "city": "Москва"
}
```

### Query Requirements

Event list query must support:

- `status == active`.
- `city == selectedCity`.
- `startsAt >= now`.
- Date range filter for today/tomorrow/week/month.
- Level overlap filter.

Level overlap rule:

- Event is visible for selected level if `event.levelMin <= selectedLevel <= event.levelMax`.
- If no level is selected, show all levels in selected city/date range.

### Transaction Requirements

#### Join transaction

Checks:

- User is authorized.
- Event exists.
- Event status is `active`.
- Event starts in the future.
- User is not already active participant.
- `participantsCount < capacity`.

Writes:

- Create/update participant doc as active.
- Increment `participantsCount`.
- Add user to chat participant access if denormalized.

#### Leave transaction

Checks:

- User is authorized.
- User is active participant.
- User is not organizer.
- Event status is `active`.
- Event starts in the future.

Writes:

- Mark participant as left or delete participant doc.
- Decrement `participantsCount`.
- Remove user from chat participant access if denormalized.

#### Create limit

Requirement:

- A user can create no more than 5 events per calendar day.

Implementation options:

- Cloud Function callable with server-side counter.
- Firestore transaction on `eventCreationCounters/{userId_yyyyMMdd}`.

Client-only enforcement is not sufficient.

### Security & Privacy

Firestore rules must enforce:

- Only authorized users can create events.
- Only organizer can edit/cancel their event.
- Non-organizer cannot change `organizerId`, `participantsCount`, or `status`.
- Event creation must respect required fields and allowed status.
- Server-side create/edit validation must enforce title: required after normalization, max 70 grapheme clusters, single-line.
- Firestore rules must block direct client writes that bypass validated event create/edit paths.
- Chat read/write is participant-only.
- User cannot write messages as another sender.
- User cannot directly inflate `participantsCount`.

Personal data exposed in event UI:

- Display name.
- Avatar.
- User id/reference.
- Organizer role.

### Testing Requirements

Required tests:

- Event creation validation.
- Create/edit and rules tests for title validation: empty, whitespace-only, 70 grapheme clusters, 71 grapheme clusters, line breaks, and Unicode input.
- 5-events-per-day limit.
- Event list filters by city/date/level.
- Join transaction does not exceed capacity.
- Duplicate join is blocked.
- Leave decrements occupancy.
- Organizer cannot leave as participant.
- Organizer can edit/cancel.
- Non-organizer cannot edit/cancel.
- Chat access only for participants.
- User loses chat access after leaving.
- Deep link opens event detail.

## 5. Risks & Roadmap

### Phased Rollout

#### MVP

- Event list.
- City selection/default from profile.
- Date and level filters.
- Event detail.
- Create event.
- Edit event.
- Cancel event.
- Join event.
- Leave event.
- Participant-only group chat.
- Native share sheet.
- Firebase rules and transaction-safe writes.

#### v1.1

- Better deep link fallback when app is not installed.
- Report event/message.
- Read-only canceled chat decision.
- Event history in profile.
- More robust city picker.

#### v2.0

- Online events.
- Push reminders.
- Waitlist.
- Map/radius search.
- Event recommendations.
- Organizer ratings.
- Event cover images.

### Technical Risks

- Concurrent joins can overfill event capacity if not transaction-protected.
- Firestore compound indexes will be needed for city/date/status queries.
- Level range filtering may require denormalized query fields depending on Firestore limitations.
- Missing profile location can block discovery unless the fallback chip flow is clear.
- Without push notifications, users may miss event edits/cancellations.
- Without moderation, open event creation can create spam risk.

### Open Questions

- Exact max description length.
- Exact list of supported cities/countries for chips.
- Should canceled event chat become read-only or stay writable for participants?
- Should users be allowed to leave after event start?
- Should organizer be able to delete event draft permanently, or only cancel published events?
