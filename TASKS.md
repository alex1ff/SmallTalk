# SmallTalk Events TASKS

Source PRD: `docs/events-prd.md`  
Status: Draft  
Date: 2026-06-14

## MVP Definition of Done

- New bottom tab `События` is available to authorized users.
- User can browse active future offline events by selected city.
- User can filter events by date and level.
- User can create up to 5 events per calendar day.
- User can join events without organizer approval and leave only before event `startsAt`.
- Organizer can edit and cancel own events.
- Event chat is available to active participants; canceled event chats remain read-only for organizer and participants active at cancellation time.
- Event can be shared through native share sheet with deep link.
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
- [ ] Confirm whether event language list reuses existing app language catalog.
- [ ] Confirm whether organizer can permanently delete drafts or only cancel published events.

## Phase 1: Firebase Data Contract

- [ ] Audit existing `users` location fields from registration/profile.
- [ ] Define canonical city identity as `countryCode + cityKey`, with localized city names used only for display.
- [ ] Define canonical event level order: `A1`, `A2`, `B1`, `B2`, `C1`, `C2`.
- [ ] Define event statuses: `active`, `canceled`.
- [ ] Add Firestore collection contract for `events/{eventId}`.
- [ ] Add Firestore subcollection contract for `events/{eventId}/participants/{userId}`.
- [ ] Add Firestore collection contract for `eventChats/{chatId}`.
- [ ] Define `eventChats.readAccessUserIds` as the chat read-access list that freezes on cancel with organizer and active participants, excludes users who left before cancel, and does not gain new readers after cancel.
- [ ] Add Firestore subcollection contract for `eventChats/{chatId}/messages/{messageId}`.
- [ ] Add daily creation counter contract: `eventCreationCounters/{userId_yyyyMMdd}` or equivalent.
- [ ] Define required compound index baseline: `status + countryCode + cityKey + startsAt`, with level filtering strategy handled separately.
- [ ] Decide whether level filtering needs denormalized fields for Firestore queries.

## Phase 2: Firebase Write Logic

- [ ] Implement transaction-safe event creation.
- [ ] Enforce 5 events per user per calendar day server-side.
- [ ] Add organizer as first participant during event creation.
- [ ] Create or reserve event chat during event creation.
- [ ] Implement transaction-safe join.
- [ ] Block duplicate join.
- [ ] Block join for full, canceled, past, or missing events.
- [ ] Implement transaction-safe leave.
- [ ] Block leave at or after `startsAt` without changing occupancy or chat access.
- [ ] Block organizer from leaving through participant leave flow.
- [ ] Remove or deactivate participant membership on leave.
- [ ] Update chat access after join and leave.
- [ ] Implement organizer-only event edit.
- [ ] Block capacity reduction below active participant count.
- [ ] Implement organizer-only event cancel.
- [ ] On cancel, atomically set `status = canceled`, set `canceledAt`, and preserve event chat read-access snapshot for organizer and users active at cancellation time.
- [ ] Block event chat writes after cancellation.

## Phase 3: Firebase Security Rules

- [ ] Allow authorized users to read active event list data.
- [ ] Allow authorized users to create valid events only.
- [ ] Allow only organizer to edit own event.
- [ ] Allow only organizer to cancel own event.
- [ ] Prevent client-side tampering with `organizerId`, `participantsCount`, and protected status fields.
- [ ] Allow participant reads only where required by UI.
- [ ] Allow active event chat reads only for active participants.
- [ ] Allow canceled event chat reads only for organizer and participants active at cancellation time.
- [ ] Deny canceled event chat reads for nonparticipants and users who left before cancellation.
- [ ] Allow event chat writes only for active participants while event status is `active`.
- [ ] Require event status `active` for event chat writes.
- [ ] Block direct leave/membership writes at or after `startsAt` using trusted request/server time.
- [ ] Block direct client writes to `eventChats/{chatId}` metadata, especially `readAccessUserIds`.
- [ ] Prevent users from sending chat messages as another user.
- [ ] Add rules tests for create, edit, cancel, join, leave, and chat access.

## Phase 4: Flutter Data Layer

- [ ] Add event model.
- [ ] Add event participant model.
- [ ] Add event chat/message model or reuse existing chat model if compatible.
- [ ] Add static curated city catalog with `countryCode`, `cityKey`, localized names, country/region display context, and priority.
- [ ] Add event repository/service for list queries.
- [ ] Add event repository/service for detail stream.
- [ ] Add event repository/service for create, edit, cancel, join, and leave.
- [ ] Add date filter helper for today, tomorrow, current week, and current month.
- [ ] Add level overlap helper.
- [ ] Add city resolution helper from user profile.
- [ ] Add city chip source helper backed by local recent selections and a static curated popular city list.
- [ ] Add fallback selected city state when profile location is missing.
- [ ] Add user-facing error mapping for Firebase failures.

## Phase 5: Navigation

- [ ] Add `События` item to bottom navigation.
- [ ] Add route for event list.
- [ ] Add route for event detail.
- [ ] Add route for event create.
- [ ] Add route for event edit.
- [ ] Add route for event group chat.
- [ ] Ensure existing tabs keep current behavior.

## Phase 6: Event List Screen

- [ ] Build header with title `События`.
- [ ] Add `+` create button.
- [ ] Add city selector/state.
- [ ] Show profile city by default when available.
- [ ] Show location prompt when profile city is missing.
- [ ] Add city chips in missing-location flow: recent selections first, static popular cities second.
- [ ] Add manual city selection action because chips are shortcuts, not the full city set.
- [ ] Allow chip/manual city selection to unlock the event list without saving profile location.
- [ ] Add date filter chips: `Сегодня`, `Завтра`, `На этой неделе`, `В этом месяце`.
- [ ] Add level filter chips: `A1`, `A2`, `B1`, `B2`, `C1`, `C2`.
- [ ] Build event card layout from design.
- [ ] Show organizer avatar/name.
- [ ] Show title, description, level/range, date, time, and place.
- [ ] Show participant avatar stack.
- [ ] Show occupancy like `5/10 мест`.
- [ ] Add card CTA states: join, joined, full, canceled/past unavailable.
- [ ] Add `Чат` CTA with participant-only behavior.
- [ ] Add loading state.
- [ ] Add empty state.
- [ ] Add error state with retry.

## Phase 7: Event Detail Screen

- [ ] Build top bar with back and share actions.
- [ ] Show level/range badge.
- [ ] Show language badge.
- [ ] Show title and full description.
- [ ] Show organizer card.
- [ ] Add `Написать` action for organizer.
- [ ] Show date, time, and place block.
- [ ] Show participant list.
- [ ] Show occupancy.
- [ ] Add sticky bottom action bar.
- [ ] Show `Присоединиться` for non-participants.
- [ ] Show joined/leave state for participants.
- [ ] Show disabled state for full, canceled, and past events.
- [ ] Show organizer edit/cancel controls.
- [ ] Show canceled state when opening canceled event by direct link.

## Phase 8: Create Event Screen

- [ ] Build form fields for title and description.
- [ ] Add language selector.
- [ ] Add level/range selector.
- [ ] Add date picker.
- [ ] Add time picker.
- [ ] Add city selector.
- [ ] Add place/address input.
- [ ] Add participant limit input.
- [ ] Validate required fields.
- [ ] Block date/time in the past.
- [ ] Block capacity below 2.
- [ ] Handle daily creation limit error.
- [ ] Submit event creation.
- [ ] Open created event detail after success.

## Phase 9: Edit And Cancel Event

- [ ] Reuse create form for edit mode.
- [ ] Prefill existing event values.
- [ ] Hide edit route from non-organizers.
- [ ] Validate edited values.
- [ ] Block capacity below active participant count.
- [ ] Save organizer edits.
- [ ] Add cancel confirmation dialog.
- [ ] Set event status to `canceled`.
- [ ] Return user to detail or list after cancellation.
- [ ] Ensure canceled event disappears from active list.

## Phase 10: Join And Leave UX

- [ ] Add optimistic or loading state for join button.
- [ ] Disable repeated taps during join.
- [ ] Show success state after join.
- [ ] Update occupancy after join.
- [ ] Add leave action for active participants.
- [ ] Add leave confirmation.
- [ ] Hide or disable leave action at or after `startsAt`.
- [ ] Update occupancy after leave.
- [ ] Remove chat access after leave.
- [ ] Show clear errors for full event, canceled event, past event, and duplicate join.
- [ ] Show clear error if leave races with event start and backend blocks it.

## Phase 11: Event Group Chat

- [ ] Decide whether to reuse existing chat UI or create event-specific chat wrapper.
- [ ] Open chat from event card only for participants.
- [ ] Open chat from event detail only for participants.
- [ ] Show `Сначала присоединитесь к событию` for non-participants.
- [ ] Load event chat messages.
- [ ] Send event chat messages.
- [ ] Show sender name/avatar.
- [ ] Prevent read/write after participant leaves.
- [ ] Show canceled event chats as read-only for eligible organizer/participants.
- [ ] Show read-only status/banner for canceled event chats.
- [ ] Hide or disable message composer/send for canceled event chats.

## Phase 12: Sharing And Deep Links

- [ ] Add native share sheet integration.
- [ ] Generate event deep link.
- [ ] Share title, date/time, place, and link.
- [ ] Add route handling for event deep links.
- [ ] Open event detail from link.
- [ ] Handle missing/deleted/canceled/past/full event link states without auto-join.
- [ ] Preserve target `eventId` through auth redirect before opening event detail.
- [ ] Configure HTTPS App Links / Universal Links for `https://smalltalk-2109b.firebaseapp.com/events/{eventId}`.
- [ ] Add Android App Links config: `/.well-known/assetlinks.json` and Android manifest intent filter with `autoVerify`.
- [ ] Add iOS Universal Links config: `/.well-known/apple-app-site-association` and Associated Domains entitlement.
- [ ] Add Firebase Hosting fallback landing for `/events/{eventId}` when app is not installed or browser handles the link.
- [ ] Add Firebase Hosting rewrites/fallback for `/events/**`.
- [ ] Add App Store and Google Play actions to fallback landing.
- [ ] Confirm final App Store and Google Play URLs for fallback landing.
- [ ] Ensure fallback landing does not auto-redirect to stores.
- [ ] Ensure fallback landing does not read Firestore, render event-specific OG/meta tags, or expose participant lists, chat data, or private event metadata.
- [ ] Ensure Firebase Hosting config does not use Firebase Dynamic Links or `dynamicLinks: true`.

## Phase 13: Analytics

- [ ] Track event list opened.
- [ ] Track city selected with canonical payload: `countryCode`, `cityKey`, `selectionSource` (`profile|recent|static|manual`), without localized city name.
- [ ] Track date filter selected.
- [ ] Track level filter selected.
- [ ] Track event detail opened.
- [ ] Track event created.
- [ ] Track event edited.
- [ ] Track event canceled.
- [ ] Track event joined.
- [ ] Track event left.
- [ ] Track event chat opened.
- [ ] Track event shared.
- [ ] Add dashboard notes for PRD success metrics.

## Phase 14: Testing And QA

- [ ] Add unit tests for date filter helper.
- [ ] Add unit tests for level overlap helper.
- [ ] Add repository tests for event creation validation.
- [ ] Add create/edit/server validation tests for title: empty, whitespace-only, 70 grapheme clusters, 71 grapheme clusters, line breaks, and Unicode input.
- [ ] Add create/edit/server validation tests for description: empty, whitespace-only, 1000 grapheme clusters, 1001 grapheme clusters, multiline input, repeated line breaks collapsing to 2, and Unicode input.
- [ ] Add rules tests that block direct client writes bypassing validated event create/edit paths.
- [ ] Add tests for 5-events-per-day limit.
- [ ] Add tests for city/date/level list filtering.
- [ ] Add city chip source tests for profile default, missing profile city, recent city ordering, static popular fallback, profile city absent from chips, and recent/static dedupe by `countryCode + cityKey`.
- [ ] Add city query tests for canonical `countryCode + cityKey`.
- [ ] Add transaction tests for join capacity.
- [ ] Add transaction tests for duplicate join.
- [ ] Add transaction tests for leave.
- [ ] Add tests that leave is blocked at or after `startsAt` and preserves occupancy/chat access.
- [ ] Add tests that organizer cannot leave as participant.
- [ ] Add tests that organizer can edit/cancel.
- [ ] Add tests that non-organizer cannot edit/cancel.
- [ ] Add rules tests for participant-only chat access on active events.
- [ ] Add rules tests that canceled event chat stays readable for organizer and active participants at cancellation time.
- [ ] Add rules tests that canceled event chat denies reads for nonparticipants and users who left before cancellation.
- [ ] Add rules tests that canceled event chat does not gain new readers after cancellation.
- [ ] Add rules tests that canceled event chat blocks all chat writes for everyone, including message create/update/delete and `eventChats` metadata writes.
- [ ] Add widget tests for canceled chat read-only banner/status and hidden or disabled composer.
- [ ] Add widget tests for list empty/loading/error states.
- [ ] Add widget tests for create form validation.
- [ ] Add widget tests for detail CTA states.
- [ ] Add deep link test for opening event detail.
- [ ] Add deep link test for preserving target `eventId` through auth redirect.
- [ ] Add deep link tests for missing, deleted, canceled, past, and full event link states without auto-join.
- [ ] Add fallback landing tests for no auto-redirect, no Firestore reads, no event-specific OG/meta tags, no private event/participant/chat data, and generic missing/deleted response.
- [ ] Add hosting verification for `/.well-known/assetlinks.json`, `/.well-known/apple-app-site-association`, `/events/**` fallback, and absence of Dynamic Links config.
- [ ] Run `flutter analyze`.
- [ ] Run relevant `flutter test`.

## Phase 15: Release Checklist

- [ ] Confirm Firebase indexes deployed.
- [ ] Confirm Firebase rules deployed.
- [ ] Confirm Cloud Functions or transaction endpoints deployed if used.
- [ ] Smoke test new user with profile city.
- [ ] Smoke test user without profile city.
- [ ] Smoke test create, edit, cancel.
- [ ] Smoke test join, leave, full event.
- [ ] Smoke test participant-only chat.
- [ ] Smoke test share link.
- [ ] Smoke test installed app opens shared event detail.
- [ ] Smoke test unauthenticated deep link preserves target `eventId` through login.
- [ ] Smoke test no-app/browser opens install landing.
- [ ] Verify production `assetlinks.json` and `apple-app-site-association` are reachable without redirects and have correct content type and app identifiers.
- [ ] Confirm no regression in existing bottom navigation.

## Post-MVP Backlog

- [ ] Rich web event preview, deferred deep linking, and optional vendor attribution.
- [ ] Report event.
- [ ] Report chat message.
- [ ] Event history in profile.
- [ ] Improved city picker.
- [ ] Online events.
- [ ] Push reminders.
- [ ] Waitlist.
- [ ] Map/radius search.
- [ ] Event recommendations.
- [ ] Organizer ratings.
- [ ] Event cover images.
