# SmallTalk Events TASKS

Source PRD: `docs/events-prd.md`  
Status: Draft  
Date: 2026-06-14

## MVP Definition of Done

- New bottom tab `События` is available to authorized users.
- User can browse active future offline events by selected city.
- User can filter events by date and level.
- User can create up to 5 events per calendar day.
- User can join and leave events without organizer approval.
- Organizer can edit and cancel own events.
- Event chat is available only to active participants.
- Event can be shared through native share sheet with deep link.
- Firebase rules prevent unauthorized reads/writes.
- `flutter analyze` passes.
- Relevant tests pass.

## Phase 0: Product Decisions

- [x] Confirm max title length: 70 user-perceived characters / grapheme clusters after trim and whitespace normalization; line breaks are not allowed.
- [ ] Confirm max description length.
- [ ] Confirm city chip source: static list, recent cities, popular cities, or remote config.
- [ ] Decide whether participant can leave after event start.
- [ ] Decide canceled event chat behavior: read-only or still writable.
- [ ] Decide deep link fallback when app is not installed.
- [ ] Confirm whether event language list reuses existing app language catalog.
- [ ] Confirm whether organizer can permanently delete drafts or only cancel published events.

## Phase 1: Firebase Data Contract

- [ ] Audit existing `users` location fields from registration/profile.
- [ ] Define canonical event level order: `A1`, `A2`, `B1`, `B2`, `C1`, `C2`.
- [ ] Define event statuses: `active`, `canceled`.
- [ ] Add Firestore collection contract for `events/{eventId}`.
- [ ] Add Firestore subcollection contract for `events/{eventId}/participants/{userId}`.
- [ ] Add Firestore collection contract for `eventChats/{chatId}`.
- [ ] Add Firestore subcollection contract for `eventChats/{chatId}/messages/{messageId}`.
- [ ] Add daily creation counter contract: `eventCreationCounters/{userId_yyyyMMdd}` or equivalent.
- [ ] Define required compound indexes for city, status, start date, and level filters.
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
- [ ] Block organizer from leaving through participant leave flow.
- [ ] Remove or deactivate participant membership on leave.
- [ ] Update chat access after join and leave.
- [ ] Implement organizer-only event edit.
- [ ] Block capacity reduction below active participant count.
- [ ] Implement organizer-only event cancel.

## Phase 3: Firebase Security Rules

- [ ] Allow authorized users to read active event list data.
- [ ] Allow authorized users to create valid events only.
- [ ] Allow only organizer to edit own event.
- [ ] Allow only organizer to cancel own event.
- [ ] Prevent client-side tampering with `organizerId`, `participantsCount`, and protected status fields.
- [ ] Allow participant reads only where required by UI.
- [ ] Allow event chat reads only for active participants.
- [ ] Allow event chat writes only for active participants.
- [ ] Prevent users from sending chat messages as another user.
- [ ] Add rules tests for create, edit, cancel, join, leave, and chat access.

## Phase 4: Flutter Data Layer

- [ ] Add event model.
- [ ] Add event participant model.
- [ ] Add event chat/message model or reuse existing chat model if compatible.
- [ ] Add event repository/service for list queries.
- [ ] Add event repository/service for detail stream.
- [ ] Add event repository/service for create, edit, cancel, join, and leave.
- [ ] Add date filter helper for today, tomorrow, current week, and current month.
- [ ] Add level overlap helper.
- [ ] Add city resolution helper from user profile.
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
- [ ] Add city chips in missing-location flow.
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
- [ ] Update occupancy after leave.
- [ ] Remove chat access after leave.
- [ ] Show clear errors for full event, canceled event, past event, and duplicate join.

## Phase 11: Event Group Chat

- [ ] Decide whether to reuse existing chat UI or create event-specific chat wrapper.
- [ ] Open chat from event card only for participants.
- [ ] Open chat from event detail only for participants.
- [ ] Show `Сначала присоединитесь к событию` for non-participants.
- [ ] Load event chat messages.
- [ ] Send event chat messages.
- [ ] Show sender name/avatar.
- [ ] Prevent read/write after participant leaves.
- [ ] Handle canceled event chat behavior based on Phase 0 decision.

## Phase 12: Sharing And Deep Links

- [ ] Add native share sheet integration.
- [ ] Generate event deep link.
- [ ] Share title, date/time, place, and link.
- [ ] Add route handling for event deep links.
- [ ] Open event detail from link.
- [ ] Handle missing/deleted/canceled event link states.
- [ ] Implement app-not-installed fallback if included in MVP decision.

## Phase 13: Analytics

- [ ] Track event list opened.
- [ ] Track city selected.
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
- [ ] Add create/edit and rules tests for title validation: empty, whitespace-only, 70 grapheme clusters, 71 grapheme clusters, line breaks, and Unicode input.
- [ ] Add tests for 5-events-per-day limit.
- [ ] Add tests for city/date/level list filtering.
- [ ] Add transaction tests for join capacity.
- [ ] Add transaction tests for duplicate join.
- [ ] Add transaction tests for leave.
- [ ] Add tests that organizer cannot leave as participant.
- [ ] Add tests that organizer can edit/cancel.
- [ ] Add tests that non-organizer cannot edit/cancel.
- [ ] Add rules tests for participant-only chat access.
- [ ] Add widget tests for list empty/loading/error states.
- [ ] Add widget tests for create form validation.
- [ ] Add widget tests for detail CTA states.
- [ ] Add deep link test for opening event detail.
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
- [ ] Confirm no regression in existing bottom navigation.

## Post-MVP Backlog

- [ ] Deep link fallback when app is not installed.
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
