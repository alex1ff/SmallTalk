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
- Event language selection backed by the existing app language catalog.
- Instant join.
- Leave event.
- Organizer edit event.
- Organizer cancel event.
- Local-only create form draft/discard before submit.
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

- If the user has a saved canonical profile city that resolves in the current canonical city catalog, events are filtered by that city by default.
- Existing registration/profile location data is country-level only (`users.Country_NS`) and must not be treated as an event city.
- If the profile has only country-level data, use it only as a country hint for the city selector/chip ordering and still require the user to choose a city before rendering the normal list.
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
- Language badge.
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

Draft behavior:

- MVP has no server-side event drafts and no `draft` Firestore status.
- A partially filled create form is local UI state only.
- Closing the create form before submit discards local input and does not delete anything on the server, because no event, participant, or chat document has been created.
- If the form has unsaved user input, show a discard confirmation before leaving the screen.
- Local form state is not guaranteed to survive app restart, logout, or reinstall in MVP.

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
- Language selector must reuse the existing app language catalog from `assets/jsons/languages_catalog.json`.
- The canonical stored value is `languageCode`, equal to the catalog primary `LanguageStruct.code`.
- If selection input matches a catalog `code` or `alternateCodes` value after trim and case-insensitive comparison, it must be normalized to the matching primary `code` exactly as stored in the catalog.
- Persist `languageNameEn` and `languageNameRu` as denormalized display fallback values derived from the catalog `nameEn` and `nameRu` fields in the backend language allowlist after `languageCode` normalization; client-provided display names must not be trusted.
- Event data must not persist catalog-only fields such as `model`, `isPopular`, or `ss`.
- Level/range is required.
- Date/time must be in the future.
- City is required.
- Place/address is required.
- Participant limit must be at least 2.
- User cannot create more than 5 events per calendar day.

After successful creation:

- Event creation must be atomic: the event document, organizer participant membership, and event chat reservation are created together, or none are created.
- Creator becomes organizer.
- Organizer is added as event participant.
- Event group chat is created or reserved with `chatId = eventId`.
- App opens the created event detail.
- After successful submit, the event is considered `active` and cannot be permanently deleted by the organizer.

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
- Edited language must pass the same validation as create: selected from the existing app language catalog, stored as primary `languageCode`, with denormalized `languageNameEn` and `languageNameRu`.
- Cannot edit past events.
- Cannot edit canceled events.
- Cannot reduce participant limit below current participant count.
- Updates are visible in list/detail immediately after Firebase write.
- MVP has no push notifications; participants see changes only in app.

#### Cancel Event

Only organizer can cancel.

Active and canceled events cannot be permanently deleted by the organizer in MVP. The organizer can only cancel an active event, which keeps the event record available for direct links, history, chat read snapshots, support, and debugging.

Required behavior:

- Show confirmation before canceling.
- Atomically set event status to `canceled`, set `canceledAt` to trusted server/request time, and preserve the event chat read-access snapshot for organizer and users active at cancellation time.
- Treat repeated cancel attempts as idempotent success or return a clear already-canceled error without changing the existing cancellation snapshot.
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
- Missing or admin-deleted event links opened in app show an unavailable/not-found state.
- Missing or admin-deleted event links opened in browser still show the generic install landing and must not reveal whether the event exists.
- In this context, `admin-deleted` means removal by trusted admin/ops/moderation or data-retention tooling outside MVP, not organizer hard delete.

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
- If `users.profileCity.countryCode + users.profileCity.cityKey` exists and resolves in the current canonical city catalog, it is selected by default.
- If `users.profileCity.countryCode + users.profileCity.cityKey` is missing, user is prompted to choose/fill location.
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
- Missing or admin-deleted links show an unavailable/not-found state without offering join.
- Canceled, past, or full event links open the relevant event detail state without auto-joining.

### Non-Goals

Not included in MVP:

- Online events.
- Server-side event drafts.
- Organizer permanent delete for active or canceled events.
- Trusted admin/ops/moderation deletion or data-retention tooling.
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
5. Create form state remains local until submit; there are no server-side draft event documents in MVP.
6. Successful submit atomically creates an active event, organizer participant membership, and event chat reservation.
7. Join/leave/edit/cancel writes go through transaction-safe Firebase logic.
8. Event chat reads/writes are protected by participant membership; canceled event chats keep a read-only access snapshot for organizer and users active at cancellation time.

### Suggested Firestore Model

#### `events/{eventId}`

```json
{
  "title": "Разговорный клуб: кофе и английский",
  "description": "Неформальная встреча для практики разговорного английского.",
  "languageCode": "en",
  "languageNameEn": "English",
  "languageNameRu": "Английский",
  "levelMin": "B1",
  "levelMax": "C1",
  "countryCode": "RU",
  "cityKey": "moscow",
  "cityNameRu": "Москва",
  "cityNameEn": "Moscow",
  "cityDisplayContext": "Россия",
  "locationName": "Starbucks, ул. Арбат, 5",
  "locationGeoPoint": null,
  "startsAt": "timestamp",
  "capacity": 10,
  "participantsCount": 5,
  "organizerId": "uid",
  "organizerDisplayName": "Анастасия Иванова",
  "organizerPhotoUrl": "https://...",
  "chatId": "eventId",
  "status": "active",
  "timeZoneId": "Europe/Moscow",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "canceledAt": null
}
```

This section defines only the `events/{eventId}` document. Participant documents, chat documents, and message documents are defined in their own contracts. The only cross-contract fields here are the event aggregate `participantsCount` and the stable chat pointer `chatId`.

`events/{eventId}` field contract:

| Field | Type | Required / nullable | Source | Rules |
| --- | --- | --- | --- | --- |
| `title` | string | yes | client input, server-normalized | Trimmed, single-line, max 70 grapheme clusters. |
| `description` | string | yes | client input, server-normalized | Trimmed, multiline, max 1000 grapheme clusters, repeated line breaks collapsed. |
| `languageCode` | string | yes | server-normalized catalog code | Primary language catalog code only. |
| `languageNameEn` | string | yes | server-derived catalog fallback | Display fallback only; not identity. |
| `languageNameRu` | string | yes | server-derived catalog fallback | Display fallback only; not identity. |
| `levelMin` | string | yes | client input, server-normalized | Canonical CEFR code only. |
| `levelMax` | string | yes | client input, server-normalized | Canonical CEFR code only; rank must be >= `levelMin`. |
| `countryCode` | string | yes | canonical city catalog | ISO 3166-1 alpha-2 uppercase. |
| `cityKey` | string | yes | canonical city catalog | Stable canonical city key. |
| `cityNameRu` | string | yes | server-derived city fallback | Display fallback only; not identity. |
| `cityNameEn` | string | yes | server-derived city fallback | Display fallback only; not identity. |
| `cityDisplayContext` | string | yes | server-derived city fallback | Display disambiguation only; not identity. |
| `locationName` | string | yes | client input, server-normalized | MVP stores a human-readable place/address string in one field. |
| `locationGeoPoint` | GeoPoint or null | no | optional client input | Nullable in MVP; not used for discovery queries or map/radius search. |
| `startsAt` | timestamp | yes | client selected local date/time converted by server/client helper | Must be in the future at create/edit using trusted server/request time. |
| `timeZoneId` | string | yes | canonical city catalog | Valid IANA timezone for the event city, used to interpret and display local event time. |
| `capacity` | integer | yes | client input, server-validated | MVP range is 2..50. |
| `participantsCount` | integer | yes | server-managed aggregate | Starts at 1 for organizer, must stay between 1 and `capacity`, changes only in join/leave transactions. |
| `organizerId` | string | yes | authenticated creator uid | Protected after create; organizer is included in `participantsCount`. |
| `organizerDisplayName` | string | yes | server-derived organizer profile snapshot | Denormalized display snapshot for event list/detail. |
| `organizerPhotoUrl` | string or null | no | server-derived organizer profile snapshot | Denormalized display snapshot; nullable if organizer has no avatar. |
| `chatId` | string | yes | server-managed | Stable value is `eventId` in MVP. |
| `status` | string | yes | server-managed lifecycle | Only `active` or `canceled`. |
| `createdAt` | timestamp | yes | server-managed | Trusted server/request time at creation. |
| `updatedAt` | timestamp | yes | server-managed | Trusted server/request time when event fields or aggregate counters change. |
| `canceledAt` | timestamp or null | yes | server-managed | Null while active; server/request time when canceled. |

Protected/server-derived field rules:

- Clients must not directly set or change `organizerId`, `organizerDisplayName`, `organizerPhotoUrl`, `participantsCount`, `chatId`, `status`, `createdAt`, `updatedAt`, or `canceledAt`.
- Clients must not directly set trusted display fallback fields: `languageNameEn`, `languageNameRu`, `cityNameRu`, `cityNameEn`, or `cityDisplayContext`.
- Server-side create/edit logic must derive catalog-backed display fallback fields after validating canonical language and city identity.
- Organizer display fields are snapshots for the event list/detail. They do not replace the organizer's user profile as the identity source.
- `chatId = eventId` is required in MVP so event links, chat lookup, and atomic create logic share a stable key.
- `updatedAt` changes on organizer edits, cancellation, and join/leave transactions that change `participantsCount`.
- Event list queries and analytics must use canonical identity fields, not denormalized display fields.

Event document invariants:

- `participantsCount` starts at 1 because the organizer is added as the first participant during creation.
- `participantsCount <= capacity` must hold after every create/join/leave/cancel transaction.
- Capacity cannot be edited below current `participantsCount`.
- `startsAt` is stored as a Firestore timestamp. Create/edit UI captures event-local date/time for the selected canonical city; `timeZoneId` from the city catalog is used for conversion and display.
- Past events do not get a separate status; list queries hide them with `startsAt`.
- Canceled events keep their event document for direct links, history, support, and chat read snapshots.
- Admin/ops/moderation hard delete is outside MVP and not an organizer action.

Lifecycle rules:

- `events.status` is required and allowed event statuses in MVP are only `active` and `canceled`; spelling is exactly `canceled`.
- `draft` is not a Firestore status in MVP.
- MVP has no `past`, `completed`, `deleted`, `archived`, or `cancelled` event statuses.
- Past events remain `active` unless canceled, and are hidden from discovery by `startsAt` filters.
- Before submit, a user's create form is local UI state and has no `eventId`, `chatId`, participant document, or indexable event record.
- Closing or abandoning the create form before submit discards local state only.
- After submit succeeds, the event is created as `active`.
- Active events must have `canceledAt = null`.
- Cancel is the only MVP status transition: `active -> canceled`.
- Canceled events are terminal in MVP; `canceled -> active` restore/reopen is not supported.
- Cancel sets `canceledAt` to trusted server/request time.
- Organizer cannot hard-delete active or canceled events in MVP; cancel is the only organizer removal action.
- Canceled event and chat records are retained for direct links, history, read-only chat access snapshots, support, and debugging.

Language rules:

- New and edited event documents must store required string fields `languageCode`, `languageNameEn`, and `languageNameRu`.
- `languageCode` is the only query/filter key for event language.
- `languageCode` must equal a primary `code` from `assets/jsons/languages_catalog.json`, preserving the catalog's exact casing and spelling.
- `code` and `alternateCodes` input values are matched after trim and case-insensitive comparison, then normalized to the matching primary `code`.
- Backend validation must use an allowlist or shared helper synchronized from the same language catalog source; the server-side list must not drift into a separately maintained language set.
- `languageNameEn` and `languageNameRu` are stored only as display fallbacks, are not identity or lookup keys, and must be derived from the backend allowlist's `nameEn` and `nameRu` values after normalization; client-provided values must be rejected or ignored.
- Event language is independent from the user's app UI locale; locale affects only which display name the UI prefers.
- Event documents must not store full `LanguageStruct` objects or catalog-only fields such as `model`, `isPopular`, or `ss`.
- Unknown `languageCode` fallback is read/display-only for legacy or drifted documents. Create/edit/server validation must reject unknown language codes.
- When reading an older or drifted event whose `languageCode` is unknown in the current app catalog, UI displays the denormalized localized name when available; otherwise it displays the raw `languageCode`.
- Event language badges use the current app locale when the catalog entry exists, then fall back to denormalized `languageNameRu`/`languageNameEn`, then to `languageCode`.

Level rules:

- MVP supports only CEFR level codes `A1`, `A2`, `B1`, `B2`, `C1`, `C2`.
- Canonical level order and rank are `A1=0`, `A2=1`, `B1=2`, `B2=3`, `C1=4`, `C2=5`.
- New and edited event documents must store required string fields `levelMin` and `levelMax` using canonical level codes only.
- Level input must be normalized by trim and uppercase before validation.
- Unknown level values such as `A0`, `B1+`, `Beginner`, `Native`, `Any`, empty, or null must be rejected on create/edit.
- Event level range is valid only when `rank(levelMin) <= rank(levelMax)`.
- A single-level event stores the same value in both fields, for example `levelMin = "B1"` and `levelMax = "B1"`.
- Level display badges show `B1-C1` for ranges and `B1` when `levelMin == levelMax`.
- Level range is a discovery filter in MVP and does not block joining an event by user profile level.

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

#### Existing user location audit

Audit scope:

- This audit is based on the current code, generated schemas, and Firestore indexes.
- It did not sample production Firestore `users` documents.
- Production `users` sampling is not required for MVP profile-city migration/defaulting because there is no automatic migration/defaulting from legacy user location fields. Missing, null, or stale `users.profileCity` must show the missing/outdated city flow. `users.Country_NS` may only rank suggestions and must never unlock the Events list or silently choose `cityKey`.
- Only run Firestore `users` data sampling if a future approved product decision introduces a legacy-data-based migration, backfill, or automatic defaulting strategy. Current MVP explicitly does not do this.

Current registration/profile fields are not city-ready:

- `users.Country_NS`: `CountryStruct` selected in student onboarding, native speaker onboarding, and profile edit. `EditCountryWidget` can update `Country_NS` only when called with `persistSelectedCountryToUserCountry: true`; filter flows call it with `false` to update `preferences.preferredLocation` instead.
- `CountryStruct` contains `code`, `nameEn`, `nameRu`, `flag`, `languages`, `isPopular`, and `index`; it does not contain city, region/state, place id, coordinates, or geocoded address fields.
- `userPublicProfiles.Country_NS` projects a country-level public profile subset for native speaker discovery. `userPublicProfiles.countryCode` is a generated Dart getter derived from `Country_NS.code`, not a stored Firestore field.
- `users.preferences.preferredLocation` is also a `CountryStruct`, but it represents preferred interlocutor/tutor country for matching, not the user's own city.
- Existing Firestore indexes and queries use stored `Country_NS.code`, including public profile matching by country.
- No saved `city`, `cityKey`, profile `countryCode + cityKey`, user `GeoPoint`, or profile place id was found in registration/profile/onboarding code.
- FlutterFlow `FFPlace.city` serialization exists as a generic utility, but it is not wired to user registration/profile location.

Source references:

| Source | Field or usage | Product meaning for Events |
| --- | --- | --- |
| `lib/backend/schema/users_record.dart` | `users.Country_NS` | User country; not city-ready. |
| `lib/backend/schema/structs/country_struct.dart` | `CountryStruct` | Country code/display metadata only. |
| `lib/authorization/acquaintance_s_t_u_d_e_n_t/student_onboarding_logic.dart` | writes `countryNS` | Student registration country. |
| `lib/authorization/acquaintance_n_s/native_speaker_onboarding_logic.dart` | writes `countryNS` | Native speaker registration country. |
| `lib/authorization/loading/loading_widget.dart` | reads existing `countryNS` into onboarding resume state | Existing registration/profile country continuity. |
| `lib/shared_pages/profile_edit/profile_edit_widget.dart`, `lib/components/edit_country_widget.dart` | updates `countryNS` only in profile/persisted-country flows | Editable profile country. |
| `lib/backend/schema/user_public_profiles_record.dart`, `firebase/custom_cloud_functions/public_user_profiles.js` | `userPublicProfiles.Country_NS`; generated `countryCode` getter | Country-level public projection; query key remains stored `Country_NS.code`. |
| `lib/backend/schema/structs/preferences_struct.dart` | `preferences.preferredLocation` | Preferred interlocutor country, not user's city. |
| `lib/students_pages/students_dashboard/students_dashboard_widget.dart`, `firebase/firestore.indexes.json` | queries/indexes on `Country_NS.code` | Existing country-level query support. |

Implications for Events:

- Existing `Country_NS` can help prioritize country-specific city suggestions, but it cannot unlock the event list by itself.
- This still honors registration location: the selected registration country is used as a country hint, but not as a city-level Events location.
- `preferences.preferredLocation` must not be used as the default Events city because it is a match preference, not the user's location.
- Events needs `users.profileCity` before profile-based default city selection can work.
- Until a user has canonical city fields, the Events screen must show the missing-city flow with recent/static/manual city selection.

#### Required user profile city meaning

Events profile city must be stored as a new nested map `users.profileCity`.

`users.profileCity.countryCode + users.profileCity.cityKey` is the only profile-city identity for Events default city selection:

```json
{
  "profileCity": {
    "countryCode": "RU",
    "cityKey": "moscow",
    "cityNameRu": "Москва",
    "cityNameEn": "Moscow",
    "cityDisplayContext": "Россия",
    "regionCode": null,
    "regionNameRu": null,
    "regionNameEn": null,
    "catalogVersion": 1,
    "updatedAt": "server timestamp"
  }
}
```

Profile city field rules:

- Do not add city data to `users.Country_NS`; it remains the user's country-level registration/profile field.
- Do not use a top-level `users.countryCode` or `users.cityKey` for Events city identity; keep the Events city under `users.profileCity` to avoid collisions with country/profile projections.
- `users.profileCity` may be missing or null for legacy users and for new users who have not saved a city.
- Missing `users.profileCity` must show the Events missing-city flow; `Country_NS.code` can only rank city suggestions.
- Stale or unknown `users.profileCity.countryCode + users.profileCity.cityKey` must show the missing/outdated city flow and must not unlock the normal Events list.
- Do not auto-migrate or default `users.profileCity` from `Country_NS`, because country is not city.
- A temporary Events city selection must not update `users.profileCity` unless the user explicitly chooses to save/fill profile location.
- `users.preferences.preferredLocation` must never populate or override `users.profileCity`.
- `userPublicProfiles` does not need `profileCity` projection in MVP. If future public projection is added, it must use catalog-derived canonical fields only and avoid precise/private location data.

Profile city save rules:

- Saving profile city must validate `countryCode + cityKey` against the same canonical city catalog/allowlist as event create/edit.
- Profile city display and region fields must be derived from the canonical catalog after validation.
- Client-provided profile city display fields must not be trusted as identity or display fallback source.
- `catalogVersion` must be stored from the catalog version used to derive display fields.
- `updatedAt` must use trusted server/request time.
- Catalog version is diagnostic metadata only; current selection validity must still be checked against the current canonical city catalog.

#### Canonical city identity

Canonical city identity is the pair `countryCode + cityKey`.

Rules:

- `countryCode` is required and must be ISO 3166-1 alpha-2 uppercase, for example `RU`, `US`, `AE`.
- `cityKey` is required, stable over time, and must match `^[a-z0-9]+(?:_[a-z0-9]+)*$`.
- `cityKey` must be unique within its `countryCode`.
- `cityKey` is not localized and must not be derived at runtime from `nameRu`, `nameEn`, user input, transliteration, or display aliases.
- `nameRu`, `nameEn`, `displayContext`, aliases, transliterations, and manual search text are display/search inputs only; they must resolve to an existing canonical `countryCode + cityKey`.
- If two cities share the same display name within a country, `cityKey` must include a stable curated disambiguator. Use region/state code when available, for example `springfield_il`.
- For duplicate-name cities, `displayContext` is required. If a region/state exists, `regionCode` and localized region names are also required for that city record; do not rely on display text as identity.
- When region/state metadata is known for any city, store it in the canonical catalog even if the city name is currently unique.
- If a normalized alias/transliteration matches multiple city records, the app must not auto-resolve it. Show matching options with `displayContext`; a country hint can rank results but must not silently choose the city.
- Renaming a city or changing localized display names must not change `cityKey` when it is the same city.
- City merge/split/rename migrations must be explicit product/data migrations, not silent client-side key changes.
- Users with only country-level legacy data (`Country_NS`) do not get a default `cityKey`; they must choose a city.
- Events can be created or edited only for a city that resolves to a known canonical city record.
- Backend validation must use a server-side city allowlist or shared catalog synchronized from the canonical city catalog; bundled client catalog data alone is not sufficient for trusted create/edit validation.
- Client catalog and backend allowlist/shared catalog must be versioned and generated from the same source so selectable cities match server validation.
- `cityNameRu`, `cityNameEn`, and `cityDisplayContext` are display-only denormalized fallbacks derived from the canonical city catalog after city validation. Firestore queries and analytics must never use these fields as identity.
- Analytics and Firestore queries must use `countryCode + cityKey`; localized names must not be sent as identity fields.

#### City chip source

MVP city chips come from two local sources:

- Recent city selections stored locally on device for the Events screen.
- A static curated popular city list bundled with the app.

Manual city selection searches the full canonical city catalog available to the app, not only the popular chip subset. If a city is not present in the canonical catalog, the user cannot select it or create an event for it in MVP.

Static city records must include:

```json
{
  "countryCode": "RU",
  "cityKey": "moscow",
  "nameRu": "Москва",
  "nameEn": "Moscow",
  "regionCode": null,
  "regionNameRu": null,
  "regionNameEn": null,
  "timeZoneId": "Europe/Moscow",
  "displayContext": "Россия",
  "aliases": ["Moskva", "Moscow", "Москва"],
  "transliterations": ["Moskva"],
  "priority": 10
}
```

Rules:

- If `users.profileCity.countryCode + users.profileCity.cityKey` resolves in the current canonical city catalog, it is the default city.
- If `users.profileCity` is missing city, show recent city chips first, then static popular city chips.
- Selecting a chip or manual city can be temporary for Events discovery; the UI must also offer an action to save/fill profile location.
- If the user's profile city is not in chips, still use it as the selected city.
- If a saved profile city no longer resolves to a known canonical city record, do not unlock the list from that stale value; show the missing/outdated city flow and ask the user to choose a valid city.
- If a recent city chip no longer resolves to a known canonical city record, hide or ignore that recent chip and do not use it to unlock the list.
- If no events exist for selected city, show empty state, not another location prompt.
- Recent and static city chips must dedupe by `countryCode + cityKey`.
- Cities with the same display name in different countries or regions must include country/region context in UI.
- Manual city search can match aliases/transliterations, but selection must persist only canonical `countryCode + cityKey`.
- City records must include an IANA `timeZoneId` because event `startsAt` is entered and displayed in the selected event city's local time.
- Remote Config is not part of MVP; keep the city chip source behind a replaceable helper/service so Remote Config can be added later without changing UI contracts.

### Query Requirements

Event list query must support:

- `status == active`.
- `countryCode == selectedCountryCode`.
- `cityKey == selectedCityKey`.
- `startsAt >= max(now, selectedDateRangeStart)`.
- `startsAt < selectedDateRangeEnd`.
- `orderBy startsAt ASC`.
- Date range filter for today/tomorrow/week/month.
- Level overlap filter.
- Required composite index in `firebase/firestore.indexes.json`: `status ASC`, `countryCode ASC`, `cityKey ASC`, `startsAt ASC`.

Level overlap rule:

- Event is visible for selected level if `rank(event.levelMin) <= rank(selectedLevel) <= rank(event.levelMax)` using the canonical level rank map.
- If no level is selected, show all levels in selected city/date range.
- MVP must not add unsupported Firestore range filters on both `levelMin` and `levelMax`.
- Unless the separate level denormalization task changes the strategy, apply level overlap filtering client-side after the canonical city/date query.

### Analytics City Payload Requirements

Any analytics event with city context must include canonical city identity:

- `event_list_opened`.
- `city_selected`.
- `event_detail_opened`.
- `event_created`.
- `event_edited`.
- `event_canceled`.
- `event_joined`.
- `event_left`.
- `event_chat_opened`.
- `event_shared`.

Required payload fields:

- `countryCode`.
- `cityKey`.
- `citySource` is required for `city_selected` and for `event_list_opened` when the list city came from selection/default state: `profile|recent|static|manual`.
- For detail/create/edit/cancel/join/leave/chat/share analytics, `citySource` is optional; include it only when the source is known.

Localized city names, aliases, and `displayContext` must not be sent as analytics identity fields.

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

#### Create atomicity and drafts

Requirement:

- MVP must not create server-side draft events.
- Event creation must atomically create the active event, organizer participant membership, and event chat reservation.
- Failed or interrupted create attempts must not leave partially created event/chat/participant documents.
- Repeated submit taps must be blocked in UI.
- Event create requests must include a client-generated `createRequestId` or equivalent idempotency key so backend retries can reuse or reject duplicate create attempts instead of creating duplicate events.

### Security & Privacy

Firebase write paths must enforce:

- Only authorized users can create events.
- Only organizer can edit/cancel their event.
- Organizers and ordinary clients cannot permanently delete active or canceled event documents.
- Trusted admin/ops/moderation deletion and data-retention tooling are outside MVP.
- Clients cannot hard-delete event chat documents; participant membership deletion is allowed only if the chosen validated leave implementation uses deletion before `startsAt`.
- Non-organizer cannot change `organizerId`, `participantsCount`, or `status`.
- Event creation must respect required fields and allowed status.
- Server-side create/edit/cancel validation must reject any `events.status` outside the allowlist `active|canceled`.
- Event creation must not create `draft` status documents.
- Server-side create/edit validation must enforce that `countryCode + cityKey` resolves to a known canonical city record from the synchronized city allowlist/catalog.
- Server-side create/edit logic must derive city display fallback fields from the canonical city catalog and reject or ignore mismatched client-provided city display names.
- Server-side create/edit validation must enforce title: required after normalization, max 70 grapheme clusters, single-line.
- Server-side create/edit validation must enforce description: required after normalization, max 1000 grapheme clusters, multiline allowed, more than 2 consecutive line breaks collapsed to 2.
- Server-side create/edit validation must enforce that `languageCode` is a supported primary language code, or normalize a known alternate code before persisting.
- Server-side create/edit logic must derive `languageNameEn` and `languageNameRu` from the synchronized allowlist and reject or ignore mismatched client-provided language display names.
- Server-side create/edit validation must enforce `capacity` as an integer from 2 to 50, and edits must not reduce it below `participantsCount`.
- Server-side create/edit validation must enforce future `startsAt` using trusted server/request time.
- Server-side create/edit logic must derive `timeZoneId` from the selected canonical city record, validate it as an IANA timezone, and reject or ignore client-provided timezone mismatches.
- Server-side create logic must derive `organizerDisplayName` and `organizerPhotoUrl` from the authenticated organizer profile snapshot.
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
- Create/discard tests proving leaving the create form before submit creates no server event, participant, or chat documents.
- Create atomicity tests proving failed/interrupted creates do not leave partial event, participant, or chat documents.
- Submit double-tap/retry tests proving duplicate event creation is blocked or idempotently handled through `createRequestId` or equivalent.
- Create/edit/server validation tests for title: empty, whitespace-only, 70 grapheme clusters, 71 grapheme clusters, line breaks, and Unicode input.
- Create/edit/server validation tests for description: empty, whitespace-only, 1000 grapheme clusters, 1001 grapheme clusters, multiline input, repeated line breaks collapsing to 2, and Unicode input.
- Create/edit/server validation tests for `capacity`: below 2, above 50, non-integer, valid bounds, and edit below current `participantsCount`.
- Create/edit/server validation tests for `startsAt` and `timeZoneId`: future trusted-time validation, selected city timezone derivation, and rejected or ignored client timezone mismatch.
- Create tests proving `organizerDisplayName` and `organizerPhotoUrl` are derived from the authenticated organizer profile snapshot.
- Rules tests that block direct client writes bypassing validated event create/edit paths.
- City chip source tests for profile default, missing profile city, recent city ordering, static popular city fallback, profile city not present in chips, and recent/static dedupe by `countryCode + cityKey`.
- City query tests must use canonical `countryCode + cityKey`, not localized display names.
- City identity tests must cover uppercase ISO `countryCode`, `cityKey` regex `^[a-z0-9]+(?:_[a-z0-9]+)*$`, unique `(countryCode, cityKey)`, duplicate-name disambiguation, required region/display context for ambiguous cities, alias/transliteration resolution, ambiguous alias no-auto-resolve behavior, stale profile city fallback, unknown city create/edit rejection, and localized names never acting as identity.
- City resolution tests must prove `Country_NS` alone does not unlock the Events list.
- City resolution tests must prove `preferences.preferredLocation` is not used as the default Events city.
- Language catalog tests for primary code selection, alternate code normalization, denormalized display fallback, unknown legacy code read fallback, rejecting unknown create/edit codes, rejecting or ignoring mismatched client-provided names, backend allowlist sync with the app catalog, unique `alternateCodes`, and avoiding full `LanguageStruct` persistence.
- 5-events-per-day limit.
- Event list filters by city/date/level.
- Join transaction does not exceed capacity.
- Duplicate join is blocked.
- Leave decrements occupancy.
- Leave is blocked at or after `startsAt` and does not change occupancy or chat access.
- Organizer cannot leave as participant.
- Organizer can edit/cancel.
- Non-organizer cannot edit/cancel.
- Rules tests deny organizer/client hard delete of active and canceled events.
- Rules/model tests reject `draft`, `past`, `completed`, `deleted`, `archived`, `cancelled`, and unknown values as event statuses in MVP.
- Status lifecycle tests cover `active` with `canceledAt = null`, only `active -> canceled`, terminal canceled without reopen/restore, and `canceledAt` set from trusted server/request time.
- Chat access only for participants.
- User loses chat access after leaving.
- Canceled event chat remains readable for organizer and users who were active participants at cancellation time.
- Users who left before cancellation cannot read canceled event chat.
- Canceled event chat does not gain new readers after cancellation.
- Canceled event chat blocks all chat writes for everyone, including message create/update/delete and `eventChats` metadata writes.
- Deep link opens event detail.
- Deep link preserves target `eventId` through auth login redirect.
- Deep link handles missing, admin-deleted, canceled, past, and full event states without auto-joining.
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
- Optional server-side drafts and draft restore.
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
- Language validation cannot rely only on a local asset when writes are server-side; the backend needs an allowlist or validation helper synchronized from the same catalog source.
- Organizer hard-deleting events would break direct links, canceled chat snapshots, participant history, and support/debug workflows; MVP uses cancel retention instead.
- Existing profile location data is country-only; treating `Country_NS` or `preferences.preferredLocation` as a city would show incorrect event lists.
- Missing profile location can block discovery unless the fallback chip flow is clear.
- Without push notifications, users may miss event edits/cancellations.
- Without moderation, open event creation can create spam risk.

### Open Questions

- Exact static popular chip list and country coverage.
