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
  - local recent city chips from prior Events selections;
  - static curated popular city chips bundled with the app;
  - action to fill/save profile location.
- User can change the city from the Events screen.
- Selecting a chip or manual city can be temporary and must unlock the event list without requiring the user to save profile location.
- City chips are shortcuts, not the full allowed city set; user must be able to choose another city manually.
- MVP must not depend on Firebase Remote Config for city chips.
- City selection must use a canonical `countryCode + cityKey` pair for queries and analytics; localized city names are display-only.
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
  - `Выйти` for participants only before `startsAt`;
  - joined/chat state without enabled leave action at or after `startsAt`;
  - `Чат`.

Participant behavior:

- User joins instantly when tapping `Присоединиться`.
- User can leave the event after joining only before event start.
- At or after `startsAt`, participants cannot leave in MVP; membership and chat access remain active.
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
- Event chat becomes read-only after cancellation.
- Chat read access after cancellation remains available to the organizer and users who were active participants at cancellation time.
- Users who left before cancellation do not regain chat access.
- Sending messages after cancellation is blocked for everyone, including organizer.

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
- Description max length is 1000 user-perceived characters, meaning grapheme clusters, after trimming and whitespace normalization.
- Description can be multiline.
- Description normalization must convert `\r\n` and `\r` to `\n`, collapse repeated spaces/tabs inside each line, and collapse more than 2 consecutive line breaks down to 2.
- Persist normalized title and description values, not raw user input.
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
- Edited description must pass the same validation as create: required after normalization, max 1000 grapheme clusters, multiline allowed, more than 2 consecutive line breaks collapsed to 2.
- Cannot edit past events.
- Cannot edit canceled events.
- Cannot reduce participant limit below current participant count.
- Updates are visible in list/detail immediately after Firebase write.
- MVP has no push notifications; participants see changes only in app.

#### Cancel Event

Only organizer can cancel.

Required behavior:

- Show confirmation before canceling.
- Atomically set event status to `canceled`, set `canceledAt`, and preserve the event chat read-access snapshot for organizer and users active at cancellation time.
- Hide from active list.
- Disable join.
- Keep event chat readable for organizer and users who were active participants at cancellation time.
- Disable event chat writes for everyone after cancellation.
- Keep event accessible through direct link/history where applicable.
- MVP has no push notifications.

#### Group Chat

Chat rules:

- One group chat per event.
- While event is active, chat is accessible only after user joins the event.
- Organizer is a member by default.
- New participants can read previous messages.
- While event is active, users who leave lose read/write access.
- While event is active, non-participants cannot read or write messages.
- If event status becomes `canceled`, eligible chat readers keep read-only access, a read-only status/banner is shown, and message composer/send is disabled.

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
- Deep link canonical URL is `https://smalltalk-2109b.firebaseapp.com/events/{eventId}`.
- Deep link is an HTTPS App Link/Universal Link using the `/events/{eventId}` path.
- If the app is installed and link association works, the link opens event detail.
- If the app is not installed or the link opens in browser, Firebase Hosting serves a simple fallback landing page.
- Fallback landing shows SmallTalk branding, a short "event is available in the app" message, and App Store / Google Play actions.
- Fallback landing shows explicit store buttons and must not auto-redirect to a store.
- Fallback landing must not read Firestore or render event-specific Open Graph/meta tags in MVP.
- Fallback landing must not expose participant lists, chat data, or private event metadata.
- MVP does not include full web event preview, deferred deep linking, or Firebase Dynamic Links.
- Missing or deleted event links opened in app show an unavailable/not-found state.
- Missing or deleted event links opened in browser still show the generic install landing and must not reveal whether the event exists.

Example payload:

```text
Разговорный клуб: кофе и английский
Сегодня в 18:00, Starbucks, ул. Арбат, 5
Присоединиться: {eventDeepLink}
```

Fallback keeps the same `/events/{eventId}` URL so the shared link remains stable.

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
- Participant cannot leave at or after event `startsAt`.
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
- Event chat becomes read-only for organizer and users who were active participants at cancellation time.

#### Story 7: Use Group Chat

As a participant, I want to chat with event participants so that we can coordinate before the meeting.

Acceptance criteria:

- Chat opens only for participants.
- Messages are visible to event participants.
- Non-participants cannot read or write messages.
- User who leaves loses access.
- After event cancellation, eligible participants and organizer can read existing messages but nobody can send new messages.

#### Story 8: Share Event

As a user, I want to share an event so that I can invite friends.

Acceptance criteria:

- Share button opens native share sheet.
- Shared text includes event title, time, place, and link.
- Link routes to event detail when opened in app.
- Link opens a simple install landing page when opened without the app.
- If user is not authenticated in app, route preserves `eventId` through auth and opens event detail after login.
- Missing or deleted links show an unavailable/not-found state without offering join.
- Canceled, past, or full event links open the relevant event detail state without auto-joining.

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
- Deep links: HTTPS App Links / Universal Links for `https://smalltalk-2109b.firebaseapp.com/events/{eventId}` with Firebase Hosting fallback.

Core flow:

1. User opens `События`.
2. App resolves selected city from profile or local temporary city selection.
3. App queries active future events by city, date range, and optional level.
4. User opens detail or creates event.
5. Join/leave/edit/cancel writes go through transaction-safe Firebase logic.
6. Event chat reads/writes are protected by participant membership; canceled event chats keep a read-only access snapshot for organizer and users active at cancellation time.

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
  "cityKey": "moscow",
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
  "readAccessUserIds": ["uid1", "uid2"],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

`readAccessUserIds` is the chat read-access list. While the event is active, it stays synced with active participants plus organizer. When the event is canceled, this list is preserved as the read-only snapshot for organizer and users active at cancellation time. Users who left before cancellation remain excluded, and no new readers are added after cancellation.

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
  "cityKey": "moscow",
  "city": "Москва"
}
```

#### City chip source

MVP city chips come from two local sources:

- Recent city selections stored locally on device for the Events screen.
- A static curated popular city list bundled with the app.

Static city records must include:

```json
{
  "countryCode": "RU",
  "cityKey": "moscow",
  "nameRu": "Москва",
  "nameEn": "Moscow",
  "displayContext": "Россия",
  "priority": 10
}
```

Rules:

- If profile location has `countryCode + cityKey`, it is the default city.
- If profile location is missing city, show recent city chips first, then static popular city chips.
- Selecting a chip or manual city can be temporary for Events discovery; the UI must also offer an action to save/fill profile location.
- If the user's profile city is not in chips, still use it as the selected city.
- If no events exist for selected city, show empty state, not another location prompt.
- Recent and static city chips must dedupe by `countryCode + cityKey`.
- Cities with the same display name in different countries or regions must include country/region context in UI.
- Remote Config is not part of MVP; keep the city chip source behind a replaceable helper/service so Remote Config can be added later without changing UI contracts.

### Query Requirements

Event list query must support:

- `status == active`.
- `countryCode == selectedCountryCode`.
- `cityKey == selectedCityKey`.
- `startsAt >= now`.
- Date range filter for today/tomorrow/week/month.
- Level overlap filter.
- Required index baseline: `status`, `countryCode`, `cityKey`, `startsAt`.

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
- Event starts in the future: leave is allowed only when `startsAt` is greater than trusted server/request time.

Writes:

- Mark participant as left or delete participant doc.
- Decrement `participantsCount`.
- Remove user from chat participant access if denormalized.

At or after `startsAt`:

- Leave must be blocked.
- `participantsCount` must not change.
- Participant membership remains active.
- Event chat access remains available to the participant.

#### Create limit

Requirement:

- A user can create no more than 5 events per calendar day.

Implementation options:

- Cloud Function callable with server-side counter.
- Firestore transaction on `eventCreationCounters/{userId_yyyyMMdd}`.

Client-only enforcement is not sufficient.

### Security & Privacy

Firebase write paths must enforce:

- Only authorized users can create events.
- Only organizer can edit/cancel their event.
- Non-organizer cannot change `organizerId`, `participantsCount`, or `status`.
- Event creation must respect required fields and allowed status.
- Server-side create/edit validation must enforce title: required after normalization, max 70 grapheme clusters, single-line.
- Server-side create/edit validation must enforce description: required after normalization, max 1000 grapheme clusters, multiline allowed, more than 2 consecutive line breaks collapsed to 2.
- Firestore rules must block direct client writes that bypass validated event create/edit paths; exact grapheme counting belongs in server-side validation.
- Direct leave or membership writes must be blocked at or after `startsAt` using trusted request/server time.
- Active event chat read/write is participant-only.
- Canceled event chat reads are allowed only for organizer and the preserved read-access snapshot of users active at cancellation time.
- Canceled event chat reads are denied for nonparticipants and users who left before cancellation.
- Chat writes require event status `active`; canceled event chats are read-only for eligible existing participants and organizer.
- Direct client writes to `eventChats/{chatId}` metadata, including `readAccessUserIds`, are blocked.
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
- Create/edit/server validation tests for title: empty, whitespace-only, 70 grapheme clusters, 71 grapheme clusters, line breaks, and Unicode input.
- Create/edit/server validation tests for description: empty, whitespace-only, 1000 grapheme clusters, 1001 grapheme clusters, multiline input, repeated line breaks collapsing to 2, and Unicode input.
- Rules tests that block direct client writes bypassing validated event create/edit paths.
- City chip source tests for profile default, missing profile city, recent city ordering, static popular city fallback, profile city not present in chips, and recent/static dedupe by `countryCode + cityKey`.
- City query tests must use canonical `countryCode + cityKey`, not localized display names.
- 5-events-per-day limit.
- Event list filters by city/date/level.
- Join transaction does not exceed capacity.
- Duplicate join is blocked.
- Leave decrements occupancy.
- Leave is blocked at or after `startsAt` and does not change occupancy or chat access.
- Organizer cannot leave as participant.
- Organizer can edit/cancel.
- Non-organizer cannot edit/cancel.
- Chat access only for participants.
- User loses chat access after leaving.
- Canceled event chat remains readable for organizer and users who were active participants at cancellation time.
- Users who left before cancellation cannot read canceled event chat.
- Canceled event chat does not gain new readers after cancellation.
- Canceled event chat blocks all chat writes for everyone, including message create/update/delete and `eventChats` metadata writes.
- Deep link opens event detail.
- Deep link preserves target `eventId` through auth login redirect.
- Deep link handles missing, deleted, canceled, past, and full event states without auto-joining.
- Browser fallback opens simple install landing without exposing private event data.

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
- HTTPS App Link / Universal Link fallback landing for shared event links.
- Firebase rules and transaction-safe writes.

#### v1.1

- Rich web event preview and deferred deep linking.
- Report event/message.
- Event history in profile.
- More robust city picker.
- Optional Remote Config-backed city chip source.

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

- Exact static popular chip list and country coverage.
- Should organizer be able to delete event draft permanently, or only cancel published events?
