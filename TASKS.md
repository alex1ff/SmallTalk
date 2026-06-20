# SmallTalk Events TASKS

Source PRD: `docs/events-prd.md`  
Status: Draft  
Date: 2026-06-14

## MVP Definition of Done

- New bottom tab `События` is available to authorized users.
- User can browse active future offline events by selected city.
- User can filter events by date and level.
- User can create up to 5 events per UTC calendar day using trusted backend creation time.
- User can join events without organizer approval and leave only before event `startsAt`.
- Organizer can edit and cancel own events.
- Event chat is available to active participants; canceled event chats remain read-only for organizer and participants active at cancellation time.
- Sharing and deep links are deferred from the active MVP scope.
- Firebase rules prevent unauthorized reads/writes.
- `flutter analyze` passes.
- Relevant tests pass.

## Phase 0: Product Decisions

- [x] Confirm max title length: 70 user-perceived characters / grapheme clusters after trim and whitespace normalization; line breaks are not allowed.
- [x] Confirm max description length: 1000 user-perceived characters / grapheme clusters after trim and whitespace normalization; multiline allowed and more than 2 consecutive line breaks collapse to 2.
- [x] Confirm city chip source: local recent city selections first, static curated popular city list second; Remote Config is not in MVP, and chips do not replace manual city selection.
- [x] Decide whether participant can leave after event start: no; leave is allowed only before `startsAt`, using trusted server/request time.
- [x] Decide canceled event chat behavior: read-only for organizer and users active at cancellation time; writes blocked for everyone.
- [x] Decide deep link fallback when app is not installed: `https://smalltalk-2109b.firebaseapp.com/events/{eventId}` HTTPS App Link/Universal Link with simple Firebase Hosting install landing; no rich web preview, deferred deep link, or Firebase Dynamic Links in MVP.
- [x] Confirm whether event language list reuses existing app language catalog.
- [x] Confirm MVP policy: no server-side drafts; pre-submit is local discard only; active events can be canceled by organizer, and active/canceled events cannot be hard deleted by organizer.

## Phase 1: Firebase Data Contract

- [x] Audit existing `users` location fields from registration/profile.
- [x] Define canonical city identity as required ISO 3166-1 alpha-2 uppercase `countryCode` plus stable `cityKey` matching `^[a-z0-9]+(?:_[a-z0-9]+)*$`, with localized city names used only for display/search.
- [x] Define city disambiguation rules for duplicate city display names using stable curated disambiguators in `cityKey`, required `displayContext`, and region/state metadata whenever known.
- [x] Define city alias/transliteration rules that resolve manual input to canonical `countryCode + cityKey` and show choices instead of auto-resolving ambiguous aliases.
- [x] Define `users.profileCity` as the new nested profile city map because existing `users.Country_NS` is country-only.
- [x] Define profile city save contract: validate `countryCode + cityKey` against canonical catalog and derive display/region fields from catalog.
- [x] N/A: Firestore `users` data sampling is not required for city migration/defaulting because MVP must not auto-migrate or default `users.profileCity` from legacy data. `users.Country_NS` is country-only and may only rank city suggestions.
- [x] Define event language fields as canonical `languageCode` plus denormalized `languageNameEn` and `languageNameRu`.
- [x] Define canonical event level order: `A1`, `A2`, `B1`, `B2`, `C1`, `C2`.
- [x] Define `events.status` lifecycle, allowed values `active|canceled`, rejected values, `draft` as local-only create state, and no `past|completed|deleted|archived|cancelled` statuses in MVP.
- [x] Add Firestore collection contract for `events/{eventId}`.
- [x] Add Firestore subcollection contract for `events/{eventId}/participants/{userId}`.
- [x] Add Firestore collection contract for `eventChats/{chatId}`.
- [x] Define `eventChats.readAccessUserIds` as the chat read-access list that freezes on cancel with organizer and active participants, excludes users who left before cancel, and does not gain new readers after cancel.
- [x] Add Firestore subcollection contract for `eventChats/{chatId}/messages/{messageId}`.
- [x] Add daily creation counter contract: `eventCreationCounters/{userId}/days/{yyyyMMdd}` plus `eventCreateRequests/{userId}/requests/{createRequestId}`.
- [x] Define required compound index baseline: `status ASC + countryCode ASC + cityKey ASC + startsAt ASC`, with MVP level filtering applied client-side unless denormalized fields are later added.
- [x] Decide whether level filtering needs denormalized fields for Firestore queries: not in MVP; use client-side level overlap filtering after the canonical city/date Firestore query.

## Phase 2: Firebase Write Logic

- [x] Implement transaction-safe event creation.
- [x] Implement callable Cloud Function `createEvent` with exact request schema: `createRequestId`, `title`, `description`, `languageCode`, `levelMin`, `levelMax`, `countryCode`, `cityKey`, `locationName`, `locationGeoPoint`, `startsAt`, and `capacity`; reject unknown keys.
- [x] Ensure event creation atomically creates active event, organizer participant membership, chat reservation, daily creation counter update, and day-independent `eventCreateRequests` idempotency marker without partial server drafts.
- [x] Validate `createRequestId` as a required UUID v4.
- [x] Add `createRequestId` idempotency handling: same request id plus same normalized payload returns the original `eventId` without incrementing the daily counter.
- [x] Return `already-exists` with `details.domainCode = create_request_conflict` when the same `createRequestId` is retried with a different normalized payload.
- [x] Compute one trusted backend `creationTimeUtc` per create attempt and reuse it for `events.createdAt`, initial `updatedAt`, participant/chat/counter/request marker timestamps, and daily counter UTC key/window derivation.
- [x] Compute daily creation counter key from trusted backend UTC time, not client device time, event city timezone, or event `startsAt`.
- [x] Store and update `eventCreationCounters/{userId}/days/{yyyyMMdd}` with `userId`, `dayKeyUtc`, `count`, `eventIds`, `requestEventIds`, `requestPayloadHashes`, `windowStartAt`, `windowEndAt`, `createdAt`, and `updatedAt`.
- [x] Store `eventCreateRequests/{userId}/requests/{createRequestId}` as a day-independent idempotency marker with `userId`, `createRequestId`, `eventId`, `payloadHash`, `counterPath`, `dayKeyUtc`, original `dailyCreation` response snapshot, `status`, `createdAt`, and `updatedAt`.
- [x] Define canonical event create payload hashing with stable lexicographic JSON key order, Unicode NFC normalization, ISO-8601 UTC millisecond `startsAt`, normalized `locationGeoPoint`, and exclusions for `createRequestId`, auth uid, generated ids, timestamps, counters, server-derived snapshots, catalog-derived display fields, participant data, and chat metadata.
- [x] Enforce `count < 5` inside the same Firestore transaction before writing the event, participant, chat metadata, and counter update.
- [x] Return `resource-exhausted` with `details.domainCode = daily_limit_reached`, `resetAtUtc`, `dayKeyUtc`, `count`, and `limit` when the UTC daily counter is already 5.
- [x] Validate event create/edit city against a backend-supported allowlist or shared canonical city catalog.
- [x] Keep backend city allowlist/shared catalog versioned and generated from the same source as the full app canonical city catalog.
- [x] Derive city display fallback fields server-side from the canonical city catalog after validation.
- [x] Ensure cancel, edit, and trusted admin delete do not decrement or increment the daily creation counter.
- [x] Normalize trimmed, case-insensitive event language input from catalog `code` or `alternateCodes` to exact primary `languageCode`.
- [x] Validate event `languageCode` against a backend-supported allowlist or shared validation helper synchronized from the app language catalog.
- [x] Derive `languageNameEn` and `languageNameRu` server-side from synchronized catalog `nameEn` and `nameRu` values after normalization.
- [x] Normalize event level input by trim and uppercase, validate against `A1`, `A2`, `B1`, `B2`, `C1`, `C2`, and reject reversed `levelMin`/`levelMax` ranges using canonical rank.
- [x] Validate event `capacity` server-side as an integer from 2 to 50 and reject edits below active `participantsCount`.
- [x] Validate event `startsAt` against trusted server/request time and derive `timeZoneId` from the selected canonical city record.
- [x] Derive `organizerDisplayName` and `organizerPhotoUrl` server-side from the authenticated organizer profile snapshot during event creation.
- [x] Add organizer as first participant during event creation.
- [x] Create or reserve event chat during event creation.
- [x] Implement transaction-safe join.
- [x] Block duplicate join.
- [x] Allow rejoin after leave before `startsAt` only when event is active, future, and not full, reusing the same participant document.
- [x] Block join for full, canceled, past by `startsAt`, or missing events.
- [x] Implement transaction-safe leave.
- [x] Block leave at or after `startsAt` without changing occupancy or chat access.
- [x] Block organizer from leaving through participant leave flow.
- [x] Mark participant membership as `status = left` on leave, set `leftAt` to trusted server/request time, and do not delete the participant document in MVP.
- [x] Update chat access after join and leave.
- [x] Implement organizer-only event edit.
- [x] Block capacity reduction below active participant count.
- [x] Implement organizer-only event cancel.
- [x] On cancel, atomically set `status = canceled`, set `canceledAt` to trusted server/request time, and preserve event chat read-access snapshot for organizer and users active at cancellation time.
- [x] Build cancel chat snapshot from `events.organizerId` plus participant documents with `status = active` read inside the cancel transaction, not from timestamp comparisons.
- [x] Make repeated cancel idempotent or return a clear already-canceled error without changing the cancellation snapshot.
- [x] Block reopening/restoring canceled events to `active` in MVP.
- [x] Block event chat writes after cancellation.
- [x] Fail closed when event chat metadata is missing or `eventChats/{chatId}.eventId` does not match the owning event id.
- [x] Implement callable Cloud Function `sendEventChatMessage` with exact request schema `{eventId, text}`; reject unknown request keys; validate `eventId` as a non-empty Firestore document id/path segment with no `/`; use authenticated uid as `senderId`; generate `messageId`; return `messageId` and `createdAt`; and check active event status, matching chat metadata, active participant membership, allowed message fields, trusted `createdAt`, `deletedAt = null`, normalized non-empty text, and max 1000 grapheme clusters.
- [x] Derive event chat message `senderDisplayName` and `senderPhotoUrl` server-side from trusted participant/profile data during send.
- [x] Block ordinary event chat message edit, soft delete, hard delete, and sender snapshot mutation in MVP.

## Phase 3: Firebase Security Rules

- [x] Allow authorized users to read active event list data.
- [x] Deny direct client event creates outside the trusted `createEvent` callable/Admin SDK path.
- [x] Allow only organizer to edit own event.
- [x] Allow only organizer to cancel own event.
- [x] Deny organizer/client hard delete of active and canceled event documents.
- [x] Deny any client-created or client-updated `events.status` outside `active|canceled`.
- [x] Prevent client-side tampering with protected event fields: `organizerId`, organizer snapshot fields, `participantsCount`, `chatId`, status fields, timestamps, and catalog-derived display fields.
- [x] Allow participant reads only where required by UI.
- [x] Deny direct client creates, updates, and deletes of participant documents outside validated join/leave/create flows.
- [x] Deny direct client reads, creates, updates, and deletes of `eventCreationCounters` and `eventCreateRequests`.
- [x] Allow active event chat reads only for active participants.
- [x] Allow canceled event chat reads only for organizer and participants active at cancellation time.
- [x] Deny canceled event chat reads for nonparticipants and users who left before cancellation.
- [x] Allow event chat metadata reads only according to active/canceled chat access rules.
- [x] Enforce that `sendEventChatMessage` is the only MVP message write path; Firestore rules must deny direct message creates, updates, and deletes.
- [x] Block direct leave/membership writes at or after `startsAt` using trusted request/server time.
- [x] Block direct client creates, updates, and deletes of `eventChats/{chatId}` metadata, especially `readAccessUserIds`.
- [x] Block client hard delete of event chat documents.
- [x] Allow active event chat message reads only for active participants.
- [x] Allow canceled event chat message reads only for users in frozen `readAccessUserIds`.
- [x] Deny event chat message reads for nonparticipants, users who left while the event is active, users outside canceled `readAccessUserIds`, and missing/mismatched chat metadata.
- [x] Deny direct client creates, updates, and deletes of event chat message documents.
- [x] Add rules tests for create, edit, cancel, join, leave, and chat access.

## Phase 4: Flutter Data Layer

- [x] Add event model matching the `events/{eventId}` field contract, including server-managed fields, catalog-derived fields, organizer snapshot fields, and `timeZoneId`.
- [x] Add event participant model matching the `events/{eventId}/participants/{userId}` field contract with `active|left` membership status and immutable role.
- [x] Add event chat metadata model matching the `eventChats/{chatId}` contract and event chat message model matching `eventChats/{chatId}/messages/{messageId}`, or reuse existing chat model only if it matches the contract exactly.
- [x] Add `users.profileCity` model/struct with `countryCode`, `cityKey`, catalog-derived localized display fields, catalog-derived region fields, `catalogVersion`, and server-time `updatedAt`.
- [x] Add static curated city catalog with `countryCode`, `cityKey`, localized names, region metadata required for duplicate-name disambiguation, IANA `timeZoneId`, aliases/transliterations, country/region display context, and priority.
- [x] Add event repository/service for list queries.
- [x] Add the `events` composite index to `firebase/firestore.indexes.json`: `status ASC`, `countryCode ASC`, `cityKey ASC`, `startsAt ASC`.
- [x] Implement event list query exactly as `status == active`, `countryCode == selectedCountryCode`, `cityKey == selectedCityKey`, `startsAt >= lowerBoundUtc`, `startsAt < upperBoundUtc`, `orderBy startsAt ASC`.
- [x] Compute event list date bounds in the selected city `timeZoneId`, convert bounds to UTC timestamps, and use an exclusive upper bound.
- [x] Apply level overlap filtering client-side after raw Firestore pages are fetched.
- [x] Continue raw Firestore pagination until enough visible level-matching events are collected or the query is exhausted.
- [x] Advance pagination cursors by the last raw Firestore document, not the last visible filtered event.
- [x] Add event repository/service for detail stream.
- [x] Add event repository/service for create, edit, cancel, join, and leave.
- [x] Add date filter helper for today, tomorrow, current week, and current month.
- [x] Add level overlap helper.
- [x] Add city resolution helper from user profile.
- [x] Add profile city save helper that does not trust client-provided display or region fields.
- [x] Ensure city resolution treats existing `users.Country_NS` as a country hint only, not as selected event city.
- [x] Ensure city resolution ignores `users.preferences.preferredLocation` as default Events city because it is an interlocutor country preference.
- [x] Add city chip source helper backed by local recent selections and a static curated popular city list.
- [x] Add manual city search normalization that resolves aliases/transliterations to canonical city records.
- [x] Add ambiguous city search handling that shows all matching city options with `displayContext`.
- [x] Add fallback selected city state when profile location is missing.
- [x] Ensure temporary Events city selection does not write `users.profileCity` unless the user explicitly saves/fills profile location.
- [x] Keep `users.Country_NS`, top-level country fields, `users.preferences.preferredLocation`, and `userPublicProfiles.Country_NS` separate from Events profile city identity.
- [x] Add event language helper backed by existing `assets/jsons/languages_catalog.json`.
- [x] Add helper to resolve exact primary `languageCode` by trimmed, case-insensitive primary code or `alternateCodes`.
- [x] Add localized event language display helper with fallback to denormalized names, then raw `languageCode`.
- [x] Add user-facing error mapping for Firebase failures.

## Phase 5: Navigation

- [x] Add `События` item to bottom navigation.
- [x] Add route for event list.
- [x] Add route for event detail.
- [x] Add route for event create.
- [x] Add route for event edit.
- [x] Add route for event group chat.
- [x] Ensure existing tabs keep current behavior.

## Phase 6: Event List Screen

- [x] Build header with title `События`.
- [x] Add `+` create button.
- [x] Add city selector/state.
- [x] Show profile city by default when available.
- [x] Validate saved profile `countryCode + cityKey` against the canonical city catalog before using it as the default Events city.
- [x] Route stale/unknown saved profile city to the missing/outdated city flow instead of unlocking the list.
- [x] If profile has only existing `Country_NS`, show missing-city flow and use country only to prioritize city suggestions.
- [x] Show location prompt when profile city is missing.
- [x] Add city chips in missing-location flow: recent selections first, static popular cities second.
- [x] Add manual city selection action because chips are shortcuts, not the full city set.
- [x] Allow chip/manual city selection to unlock the event list without saving profile location.
- [x] Add date filter chips: `Сегодня`, `Завтра`, `На этой неделе`, `В этом месяце`.
- [x] Add level filter chips: `A1`, `A2`, `B1`, `B2`, `C1`, `C2`.
- [x] Build event card layout from design.
- [x] Show organizer avatar/name.
- [x] Show title, description, level/range, date, time, and place.
- [x] Show language badge from `languageCode`.
- [x] Show participant avatar stack.
- [x] Show occupancy like `5/10 мест`.
- [x] Add card CTA states: join, joined, full, canceled/past unavailable.
- [x] Add `Чат` CTA with participant-only behavior.
- [x] Add loading state.
- [x] Add empty state.
- [x] Add error state with retry.

## Phase 7: Event Detail Screen

- [x] Build top bar with back and share actions.
- [x] Show level/range badge.
- [x] Show language badge.
- [x] Show title and full description.
- [x] Show organizer card.
- [x] Add `Написать` action for organizer.
- [x] Show date, time, and place block.
- [x] Show participant list.
- [x] Show occupancy.
- [x] Add sticky bottom action bar.
- [x] Show `Присоединиться` for non-participants.
- [x] Show joined/leave state for participants.
- [x] Show disabled state for full, canceled, and past events.
- [x] Show organizer edit/cancel controls.
- [x] Show canceled state when opening canceled event by direct link.

## Phase 8: Create Event Screen

- [x] Build form fields for title and description.
- [x] Add language selector backed by the existing app language catalog.
- [x] Submit selected language as primary `languageCode`; backend persists denormalized `languageNameEn` and `languageNameRu` from the synchronized allowlist.
- [x] Add level/range selector.
- [x] Add date picker.
- [x] Add time picker.
- [x] Add city selector.
- [x] Add place/address input.
- [x] Add participant limit input.
- [x] Validate required fields.
- [x] Interpret date/time in the selected event city's `timeZoneId` and block past values using trusted-time validation feedback.
- [x] Block capacity below 2.
- [x] Block capacity above 50.
- [x] Handle daily creation limit error.
- [x] Generate one `createRequestId` per create-form submit attempt and reuse it for retries of the same in-flight logical submit.
- [x] Map `details.domainCode = daily_limit_reached` errors to user-facing copy and keep `resetAtUtc`, `dayKeyUtc`, `count`, and `limit` available for retry timing/support context.
- [x] Map `details.domainCode = create_request_conflict` with `eventId`, `createRequestId`, and `dayKeyUtc` to a recoverable submit error that does not create another event.
- [x] After `create_request_conflict`, discard the old `createRequestId` and generate a new one only when the user intentionally submits the changed payload again.
- [x] Treat partially filled create form as local-only draft state before submit.
- [x] Add dirty-form discard confirmation before leaving create screen.
- [x] Do not promise local draft restore after app restart, logout, or reinstall in MVP.
- [x] Ensure closing create form before submit creates no event, participant, or chat documents.
- [x] Disable repeated submit taps while create request is in flight.
- [x] Submit event creation.
- [x] Open created event detail after success.

## Phase 9: Edit And Cancel Event

- [x] Reuse create form for edit mode.
- [x] Prefill existing event values.
- [x] Hide edit route from non-organizers.
- [x] Do not show permanent delete action for active or canceled events.
- [x] Validate edited values.
- [x] Block capacity below active participant count.
- [x] Save organizer edits.
- [x] Add cancel confirmation dialog.
- [x] Set event status to `canceled`.
- [x] Return user to detail or list after cancellation.
- [x] Ensure canceled event disappears from active list.

## Phase 10: Join And Leave UX

- [x] Add optimistic or loading state for join button.
- [x] Disable repeated taps during join.
- [x] Show success state after join.
- [x] Update occupancy after join.
- [x] Add leave action for active participants.
- [x] Add leave confirmation.
- [x] Hide or disable leave action at or after `startsAt`.
- [x] Update occupancy after leave.
- [x] Remove chat access after leave.
- [x] Show clear errors for full event, canceled event, past event, and duplicate join.
- [x] Show clear error if leave races with event start and backend blocks it.

## Phase 11: Event Group Chat

- [x] Decide whether to reuse existing chat UI or create event-specific chat wrapper. Decision: use an event-specific wrapper; reuse visual patterns only.
- [x] Open chat from event card only for participants.
- [x] Open chat from event detail only for participants.
- [x] Show `Сначала присоединитесь к событию` for non-participants.
- [x] Load event chat messages.
- [x] Send event chat messages through `sendEventChatMessage`.
- [x] Show sender name/avatar.
- [x] Render removed/tombstoned message state when `deletedAt` is non-null, if such messages are encountered.
- [x] Prevent read/write after participant leaves.
- [x] Show canceled event chats as read-only for eligible organizer/participants.
- [x] Show read-only status/banner for canceled event chats.
- [x] Hide or disable message composer/send for canceled event chats.

## Deferred: Sharing And Deep Links

Deferred from active scope on 2026-06-19.

- Deferred: Add native share sheet integration.
- Deferred: Generate event deep link.
- Deferred: Share title, date/time, place, and link.
- Deferred: Add route handling for event deep links.
- Deferred: Open event detail from link.
- Deferred: Handle missing/admin-deleted/canceled/past/full event link states without auto-join.
- Deferred: Preserve target `eventId` through auth redirect before opening event detail.
- Deferred: Configure HTTPS App Links / Universal Links for `https://smalltalk-2109b.firebaseapp.com/events/{eventId}`.
- Deferred: Add Android App Links config: `/.well-known/assetlinks.json` and Android manifest intent filter with `autoVerify`.
- Deferred: Add iOS Universal Links config: `/.well-known/apple-app-site-association` and Associated Domains entitlement.
- Deferred: Add Firebase Hosting fallback landing for `/events/{eventId}` when app is not installed or browser handles the link.
- Deferred: Add Firebase Hosting rewrites/fallback for `/events/**`.
- Deferred: Add App Store and Google Play actions to fallback landing.
- Deferred: Confirm final App Store and Google Play URLs for fallback landing.
- Deferred: Ensure fallback landing does not auto-redirect to stores.
- Deferred: Ensure fallback landing does not read Firestore, render event-specific OG/meta tags, or expose participant lists, chat data, or private event metadata.
- Deferred: Ensure Firebase Hosting config does not use Firebase Dynamic Links or `dynamicLinks: true`.

## Phase 13: Analytics

- [x] Track event list opened with canonical city payload and `citySource` when list city came from selection/default state.
- [x] Track city selected with canonical payload: `countryCode`, `cityKey`, `citySource` (`profile|recent|static|manual`), without localized city name.
- [x] Track date filter selected.
- [x] Track level filter selected.
- [x] Track event detail opened with canonical city payload and optional `citySource` only when known.
- [x] Track event created with canonical city payload and optional `citySource` only when known.
- [x] Track event edited with canonical city payload and optional `citySource` only when known.
- [x] Track event canceled with canonical city payload and optional `citySource` only when known.
- [x] Track event joined with canonical city payload and optional `citySource` only when known.
- [x] Track event left with canonical city payload and optional `citySource` only when known.
- [x] Track event chat opened with canonical city payload and optional `citySource` only when known.
- Deferred: Track event shared with canonical city payload and optional `citySource` only when known.
- [x] Ensure analytics never sends localized city names, aliases, or display context as city identity fields.
- [x] Add dashboard notes for PRD success metrics.

## Phase 14: Testing And QA

- [x] Add unit tests for date filter helper.
- [x] Add unit tests for level overlap helper covering all six canonical ranks, no selected level, same-level ranges, rejected invalid levels, and rejected reversed ranges.
- [x] Add repository tests for event creation validation.
- [x] Add `createEvent` request/response schema tests for required exact keys, unknown keys denied, invalid/missing `createRequestId`, per-field required/null/type/range validation, ISO-8601 UTC millisecond `startsAt`, nullable or `{latitude, longitude}` `locationGeoPoint`, exact success response fields/types, idempotent retry response returning original `eventId`/`createdAt`/`dailyCreation`, and normalized payload hashing inputs.
- [x] Add create discard tests proving leaving create form before submit creates no server event, participant, chat, counter, or request-marker documents.
- [x] Add create atomicity tests proving failed/interrupted creates do not leave partial event, participant, chat, counter, or request-marker documents.
- [x] Add submit double-tap/retry tests proving duplicate event creation is blocked or idempotently handled through UUID v4 `createRequestId`.
- [x] Add daily creation counter schema tests for `userId`, `dayKeyUtc`, `count`, `eventIds`, `requestEventIds`, `requestPayloadHashes`, `windowStartAt`, `windowEndAt`, `createdAt`, `updatedAt`, and count/request map invariants.
- [x] Add daily creation counter UTC tests for 23:59/00:00 boundary, one captured `creationTimeUtc`, trusted backend time, client clock/timezone spoof ignored, selected event city timezone ignored, and event `startsAt` day ignored.
- [x] Add daily creation limit tests for 4th-to-5th create success, 6th create denied with `resource-exhausted` plus `details.domainCode = daily_limit_reached`, `resetAtUtc`, `dayKeyUtc`, `count`, and `limit`, and concurrent creates never exceeding 5.
- [x] Add `createRequestId` tests for required UUID v4, same id plus same normalized payload returning original `eventId` without counter increment, same id plus changed normalized payload returning `already-exists` with full `create_request_conflict` details, retry after UTC midnight finding the original request marker, and transient retry leaving no duplicate increment.
- [x] Add `eventCreateRequests` marker tests for field schema including original `dailyCreation` snapshot, lowercase UUID v4 document id, parent `userId` match, day-independent lookup, original `dailyCreation` response on retry after UTC midnight without reading/updating the new daily counter, atomic write with event/counter, no marker on failed validation, immutability after create, and direct client access denial.
- [x] Add tests proving cancel, edit, and trusted admin delete do not decrement or increment the daily creation counter.
- [x] Add create/edit/server validation tests for title: empty, whitespace-only, 70 grapheme clusters, 71 grapheme clusters, line breaks, and Unicode input.
- [x] Add create/edit/server validation tests for description: empty, whitespace-only, 1000 grapheme clusters, 1001 grapheme clusters, multiline input, repeated line breaks collapsing to 2, and Unicode input.
- [x] Add create/edit/server validation tests for `capacity`: below 2, above 50, non-integer, valid bounds, and edit below active `participantsCount`.
- [x] Add create/edit/server validation tests for `startsAt` and `timeZoneId`: future trusted-time validation, selected city timezone derivation, and rejected or ignored client timezone mismatch.
- [x] Add create tests proving `organizerDisplayName` and `organizerPhotoUrl` are derived from the authenticated organizer profile snapshot.
- [x] Add create/edit/server validation tests for language: primary code accepted, alternate code normalized, trim/case input normalized, unknown code rejected, mismatched client-provided names rejected or ignored, and full `LanguageStruct` persistence blocked.
- [x] Add language catalog sync tests that backend allowlist matches the app catalog and `alternateCodes` resolve uniquely.
- [x] Add language display tests for current locale name, denormalized fallback names, unknown legacy code fallback, and missing catalog load fallback.
- [x] Add rules tests that block direct client writes bypassing validated event create/edit paths.
- [x] Add index contract test or CI check proving `firebase/firestore.indexes.json` contains the `events` collection index with `status ASC`, `countryCode ASC`, `cityKey ASC`, and `startsAt ASC`.
- [x] Add rules/model tests that reject `draft`, `past`, `completed`, `deleted`, `archived`, `cancelled`, and unknown values as event statuses in MVP.
- [x] Add status lifecycle tests for `active` with `canceledAt = null`, only `active -> canceled`, terminal canceled without reopen/restore, and `canceledAt` set from trusted server/request time.
- [x] Add rules tests that deny organizer/client hard delete of active and canceled events.
- [x] Add rules tests that deny client hard delete of event chat documents.
- [x] Add rules tests denying direct client reads, creates, updates, and deletes of `eventCreationCounters` and `eventCreateRequests`.
- [x] Add tests for city/date/level list filtering.
- [x] Add event list query tests for active-only discovery, canceled hidden from list, past hidden by `startsAt`, date lower/upper UTC bounds, selected city timezone boundary conversion, and exclusive upper bound.
- [x] Add pagination tests proving client-side level filtering can fetch additional raw pages until enough visible events are collected or the source is exhausted.
- [x] Add pagination cursor tests proving the cursor advances by the last raw Firestore document when level filtering hides trailing raw results.
- [x] Add same-`startsAt` ordering tests documenting that MVP has no product-visible tie guarantee unless `__name__ ASC` is added later.
- [x] Add repository/query-shape tests that event list queries include `status == active`, canonical city equality filters, compatible `startsAt` bounds, and `orderBy startsAt ASC`.
- [x] Add rules tests for enforceable event list constraints only: active-only list reads, reasonable query metadata such as `limit/orderBy` if implemented, and separate direct detail `get` behavior.
- [x] Add city chip source tests for profile default, missing profile city, recent city ordering, static popular fallback, profile city absent from chips, and recent/static dedupe by `countryCode + cityKey`.
- [x] Add city catalog sync tests that backend allowlist/shared catalog is versioned and generated from the same source as the full app canonical city catalog.
- [x] Add city query tests for canonical `countryCode + cityKey`.
- [x] Add city identity tests for ISO uppercase `countryCode`, `cityKey` regex, unique `(countryCode, cityKey)`, duplicate-name disambiguation, required display context/known region metadata, alias resolution, ambiguous alias no-auto-resolve behavior, unknown city create/edit/profile-save rejection, stale profile/recent city fallback, and localized names never acting as identity.
- [x] Add city resolution tests that `Country_NS` alone does not unlock the Events list.
- [x] Add city resolution tests that `preferences.preferredLocation` is not used as the default Events city.
- [x] Add profile city field tests for missing/null `users.profileCity`, stale `profileCity`, explicit save-only behavior, no auto-migration from `Country_NS`, no top-level `users.countryCode`/`users.cityKey` identity, stored `catalogVersion`, and server-time `updatedAt`.
- [x] Add transaction tests for join capacity.
- [x] Add transaction tests for duplicate join.
- [x] Add transaction tests for rejoin after leave using the same participant document and no duplicate membership.
- [x] Add transaction tests for leave.
- [x] Add participant count invariant tests proving `participantsCount` equals active participant documents, including organizer.
- [x] Add participant document tests for `active|left` status allowlist, immutable `role`, server-derived snapshots, server-time `joinedAt`/`leftAt`/`updatedAt`, and no delete-on-leave.
- [x] Add tests that leave is blocked at or after `startsAt` and preserves occupancy/chat access.
- [x] Add tests that organizer cannot leave as participant.
- [x] Add tests that organizer can edit/cancel.
- [x] Add tests that non-organizer cannot edit/cancel.
- [x] Add rules tests for participant-only chat access on active events.
- [x] Add rules tests that canceled event chat stays readable for organizer and active participants at cancellation time.
- [x] Add rules tests that canceled event chat denies reads for nonparticipants and users who left before cancellation.
- [x] Add rules tests that canceled event chat does not gain new readers after cancellation.
- [x] Add rules tests that canceled event chat blocks all chat writes for everyone, including message create/update/delete and `eventChats` metadata writes.
- [x] Add event chat metadata tests for `chatId = eventId`, matching `eventId`, no independent chat status fields, blocked direct metadata writes/deletes, `updatedAt` metadata semantics, and fail-closed missing/mismatched metadata.
- [x] Add `readAccessUserIds` tests for uniqueness, no semantic ordering, create `[organizerId]`, join/rejoin add, duplicate active join no-op, leave removes only before `startsAt`, cancel snapshot formula, immutable frozen snapshot, repeated cancel no snapshot changes, and join/leave/rejoin versus cancel commit ordering.
- [x] Add event chat message backend send tests for valid send, exact `{eventId, text}` request schema, unknown request keys denied, malformed/empty/slash-containing `eventId` denied, active participant requirement, nonparticipant denied, user who left denied, canceled send denied, spoofed `senderId` denied or ignored, server-derived sender snapshots, blank display name after fallback denied, 70/71 grapheme sender display name bounds, nullable sender photo, 2048/2049 character sender photo URL bounds, missing/mismatched chat metadata fail-closed behavior, allowed-fields-only writes, invalid `text` denied, text normalization, 1000/1001 grapheme text length bounds, multiline text, trusted `createdAt`, and `deletedAt = null`.
- [x] Add moderation tombstone tests proving trusted deletion replaces readable `text` with a fixed non-user-content placeholder and does not expose original removed content through event chat message reads.
- [x] Add event chat message rules tests for active participant read, left/nonparticipant read denial while active, canceled read for frozen `readAccessUserIds`, canceled read denial for users outside the snapshot, missing/mismatched chat metadata fail-closed behavior, and direct client create/update/delete denied.
- [x] Add event chat message repository/UI tests for stable ordering and pagination by `createdAt` plus `__name__` / document id.
- [x] Add widget tests for canceled chat read-only banner/status and hidden or disabled composer.
- [x] Add widget tests for list empty/loading/error states.
- [x] Add widget tests for create form validation.
- [x] Add widget tests for detail CTA states.
- Deferred: Add deep link test for opening event detail.
- Deferred: Add deep link test for preserving target `eventId` through auth redirect.
- Deferred: Add deep link tests for missing, admin-deleted, canceled, past, and full event link states without auto-join.
- Deferred: Add fallback landing tests for no auto-redirect, no Firestore reads, no event-specific OG/meta tags, no private event/participant/chat data, and generic missing/admin-deleted response.
- Deferred: Add hosting verification for `/.well-known/assetlinks.json`, `/.well-known/apple-app-site-association`, `/events/**` fallback, and absence of Dynamic Links config.
- [x] Run `flutter analyze`.
- [x] Run relevant `flutter test`.

## Phase 15: Release Checklist

- [x] Confirm Firebase indexes deployed.
- [x] Confirm Firebase rules deployed.
- [ ] Confirm Cloud Functions or transaction endpoints deployed if used.
- [ ] Smoke test new user with profile city.
- [ ] Smoke test user without profile city.
- [ ] Smoke test create, edit, cancel.
- [ ] Smoke test join, leave, full event.
- [ ] Smoke test participant-only chat.
- Deferred: Smoke test share link.
- Deferred: Smoke test installed app opens shared event detail.
- Deferred: Smoke test unauthenticated deep link preserves target `eventId` through login.
- Deferred: Smoke test no-app/browser opens install landing.
- Deferred: Verify production `assetlinks.json` and `apple-app-site-association` are reachable without redirects and have correct content type and app identifiers.
- [ ] Confirm no regression in existing bottom navigation.

## Post-MVP Backlog

- [ ] Rich web event preview, deferred deep linking, and optional vendor attribution.
- [ ] Report event.
- [ ] Report chat message.
- [ ] Event history in profile.
- [ ] Improved city picker.
- [ ] Server-side event drafts and draft restore.
- [ ] Online events.
- [ ] Push reminders.
- [ ] Waitlist.
- [ ] Map/radius search.
- [ ] Event recommendations.
- [ ] Organizer ratings.
- [ ] Event cover images.
