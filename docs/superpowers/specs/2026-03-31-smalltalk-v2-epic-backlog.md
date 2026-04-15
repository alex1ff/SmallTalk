# SmallTalk V2 Epic Backlog

Date: 2026-03-31  
Updated: 2026-04-14  
Source PRD: `2026-03-31-smalltalk-v2-master-prd.md`

## Usage

This backlog is the execution bridge between the approved PRD and GitHub issues. It reflects the updated 2026-04-08 scope: `Чаты` replaces separate `Друзья` and `Сообщения` bottom tabs, friend-priority is removed, and all calls use the same 5-minute base policy with mutual extension.

## Epic 1. Navigation Shell

Objective: Replace the current role-specific bottom shell with the new primary navigation and communication hub.

In scope:

- Bottom nav becomes `Главная / Словарь / Чаты`
- Remove profile from bottom nav
- Add profile entry to top-right of Home
- Do not move `Мои звонки` into Profile
- Route calls/messages/friends into `Чаты`
- Add empty state `Пусто. У вас пока нет звонков и сообщений`

Out of scope:

- Chat message sending implementation
- Matchmaking logic changes

Dependencies:

- none

Acceptance criteria:

- Student and teacher shells do not show separate `Друзья` or `Сообщения` bottom tabs
- Profile is reachable from Home top-right
- `Чаты` can host messages, friends, and call history
- Empty chats state uses the approved copy

Impacted systems:

- Flutter routing
- tab shell
- nav bar
- dashboard UI
- chats hub UI

## Epic 2. Friends Model

Objective: Replace `Избранное` wording with one-way `Друзья` inside `Чаты`.

In scope:

- Introduce/dual-read `users.friends`
- Backfill from `favoriteNativeSpeakers`
- Rename all user-facing favorite strings to friends
- Show friends inside `Чаты`
- Remove direct-call affordances from friend surfaces

Out of scope:

- Mutual friendship workflow
- Friend-priority matching
- Friend-specific duration

Dependencies:

- Epic 1 for `Чаты` entry point

Execution note (2026-04-14):

- `users.friends` now dual-reads and syncs with legacy `favoriteNativeSpeakers`.
- The `Чаты` hub owns the friends surface, direct-call affordances are removed from friend surfaces, and friend messaging remains unlock-gated.
- The remaining user-facing post-call relationship CTA now uses friend add/remove wording, so Epic 2 is complete without requiring internal route/model renames away from legacy `favorite` identifiers.

Acceptance criteria:

- Existing favorites survive migration as friends
- UI consistently uses friend terminology with add/remove friend wording instead of favorite wording
- Friends are one-way follows
- Friend surfaces do not offer direct calls
- Friend surfaces show message CTA only when messaging is unlocked

Impacted systems:

- users schema
- chats hub
- detail page CTA
- post-call summary
- data migration

## Epic 3. Messaging Access Rules

Objective: Define and enforce who is allowed to message whom.

In scope:

- Conversation unlock only after a completed connected call
- Root `conversations` collection
- Session completion flow unlock metadata
- Firestore rules for participant-only access

Out of scope:

- Rich chat UI
- push delivery semantics

Dependencies:

- Epic 5 for updated session model

Acceptance criteria:

- Pair without completed call cannot open or create a conversation
- Pair with completed call gets an unlocked conversation
- Cancelled and never-connected sessions do not unlock messaging

Impacted systems:

- Firestore rules
- session completion flow
- conversations schema

## Epic 4. Messaging UI MVP

Objective: Build the `Чаты` messaging MVP for unlocked 1:1 conversations.

In scope:

- Inbox/list inside `Чаты`
- 1:1 text thread
- send plain text messages
- basic read/open behavior
- message CTA from eligible friend/post-call surfaces

Out of scope:

- media attachments
- group chat
- push notifications

Dependencies:

- Epic 1 for `Чаты`
- Epic 3 for unlock rules

Acceptance criteria:

- `Чаты` shows unlocked conversations
- Users can open a thread and send plain text
- Locked pairs do not show active message CTA

Impacted systems:

- chats hub
- conversation queries
- message writes

## Epic 5. Matchmaking Engine V2

Objective: Replace student-to-teacher-only matching with all-to-all matching and add same-day repeat prevention.

In scope:

- Shared candidate pool across `student` and `native_speaker`
- active conversation language derivation
- candidate exclusion rules
- same-day repeat exclusion for completed connected pairs
- tester allow-list bypass for Alexander/client QA
- match context persistence
- future internal-ranking placeholder

Out of scope:

- friend-priority behavior
- internal ranking implementation

Dependencies:

- normalized user match profile fields

Execution note (2026-04-14):

- Scheduled cleanup now writes the same repeat-history metadata as manual `endSession`, using the session `expiresAt` value for day-key bucketing and a fresh transaction re-read before commit.
- The latest recorded emulator-backed `audit/backend_checks_results.json` run includes passing completed, never-connected, cancelled, and tester-bypass repeat scenarios for the current backend slice.
- This tranche now has both focused Node coverage around repeat lookup/bypass helpers and a fresh passing `npm run backend:checks` rerun for the current UTC-day, env-backed tester-bypass implementation; `Issue 5.4` is closed independently of the remaining Epic 5 scope.
- Remaining Epic 5 scope is the broader all-to-all ranking/profile/session normalization work in `Issue 5.1`, `Issue 5.2`, and `Issue 5.3`.

Acceptance criteria:

- `student-student`, `student-native_speaker`, and `native_speaker-native_speaker` matches are possible
- `createVideoSession` no longer restricts candidate pool to teacher-like profiles only
- Same pair is not matched twice in one day after a completed connected call
- Tester allow-list can bypass same-day repeat exclusion
- match context is stored on the session

Impacted systems:

- custom cloud functions
- Firestore indexes/rules
- waiting screen client payload
- session schema

## Epic 6. Matchmaking Preferences UI

Objective: Extend filters UI and request payload for the new ranking logic, without friend-priority.

In scope:

- add preferred partner level filter
- preserve language/location filters
- update request payload
- persist new preferences on user profile

Out of scope:

- `соединять в первую очередь с друзьями`
- score-tuning experiments

Dependencies:

- Epic 5 callable contract

Acceptance criteria:

- User can set preferred partner level
- Language/location filters still work
- Payload does not include `preferFriendsFirst`
- Friends are not sent as a ranking preference

Impacted systems:

- filters UI
- preferences schema
- waiting page payload builder

## Epic 7. Teacher Trust

Objective: Add manual teacher accreditation while preserving existing teacher functionality.

In scope:

- teacher accreditation status on user/profile data
- user-created verification document in Firebase
- admin approve/reject through the existing Firebase-connected admin process
- gate teacher sections by approved status where needed
- preserve payments, earnings, and withdrawals
- approved teacher boost for advanced-level matching

Out of scope:

- new standalone admin app in this repository
- document upload pipeline redesign

Dependencies:

- existing Firebase/admin verification process
- existing teacher finance flows

Acceptance criteria:

- Registration remains one shared process
- User can create a teacher verification document
- Admin can approve/reject in the existing admin flow
- Approved status opens teacher sections and teacher finance access
- Only approved teachers receive teacher boost

Impacted systems:

- users schema
- verification collection
- admin process contract
- teacher pages
- payment/earning/withdrawal access gates
- matchmaking scoring

## Epic 8. Email Verification

Objective: Add soft email verification prompts without blocking app usage.

In scope:

- show verification status
- allow resend verification email
- refresh verification state after return/app resume

Out of scope:

- blocking calls/messages/profile usage

Dependencies:

- Firebase Auth

Execution note (2026-04-14):

- Profile now shows a soft Firebase Auth email verification status surface with resend and manual refresh actions.
- App resume now refreshes the Firebase Auth user so users can return from their email client without logging out/in.
- Email verification remains informational only; it does not gate calling, messaging, profile usage, or teacher verification request submission.

Acceptance criteria:

- User can see unverified/verified state
- User can resend verification email
- Unverified users remain able to use core flows

Impacted systems:

- auth state
- profile/trust UI

## Epic 9. Live Learning Tools

Objective: Make live subtitles tappable and connect them to the existing add-word flow.

In scope:

- token selection in live subtitles
- add-word flow from selected token
- source context from the live caption fragment

Out of scope:

- replacing the dictionary or flashcards

Dependencies:

- existing live caption rendering
- existing add-word flow

Execution note (2026-04-14):

- Live subtitle token taps and add-word routing were already present in handwritten Flutter before this tranche.
- This tranche only extracted and tested shared helper/widget surfaces reused by that page path: shared caption tokenization, interactive caption rendering, and modal payload builders.
- This repo still does not have dedicated page-level integration tests for the surrounding live-call wiring.
- The current live flow passes the tapped word plus caption text into the existing add-word modal; it does not add structured subtitle provenance beyond that text context.

Acceptance criteria:

- User can tap a live subtitle word
- Tapping routes to the add-word flow
- Saved word appears in the dictionary pipeline

Impacted systems:

- video call page
- caption rendering
- add-word component

## Epic 10. Post-Call Learning Tools

Objective: Make saved subtitle logs tappable and connect them to dictionary/flashcards.

In scope:

- token selection in call-details caption logs
- add-word flow from selected saved token
- source context from session/caption log

Out of scope:

- new flashcard engine

Dependencies:

- existing `captionLogs`
- existing call details page
- existing add-word flow

Execution note (2026-04-14):

- Saved subtitle logs in Call Details were already tappable and already routed into the existing dictionary/add-word flow before this tranche.
- This tranche only extracted and tested shared helper/widget surfaces reused by that page path: shared caption tokenization, interactive caption rendering, and modal payload builders.
- This repo still does not have dedicated page-level integration tests for the surrounding Call Details wiring.
- Existing dictionary and flashcard persistence remain unchanged, so saved subtitle taps continue to flow through the current `userWords` and flashcard pipeline.

Acceptance criteria:

- User can tap a word in call details subtitles
- Saved words appear in dictionary
- Flashcards continue to use the existing pipeline

Impacted systems:

- call details
- caption log rendering
- add-word flow
- flashcards

## Epic 11. Session Policy

Objective: Enforce universal 5-minute calls with a one-time mutual 5-minute extension.

In scope:

- 5-minute base policy for all calls
- 1-minute warning
- one +5-minute extension
- extension only when both participants agree
- session metadata storage
- session-end enforcement

Out of scope:

- friend-specific duration
- billing redesign
- longer custom packages

Dependencies:

- Epic 5 for session metadata
- final UI mockup for extension screen visuals

Execution note (2026-04-14):

- New video sessions now persist a `sessionPolicy` contract with 300-second base limit, 60-second warning lead, one 300-second extension allowance, extension request state, and 300-second current effective limit.
- Accepting a policy-backed call now derives active `expiresAt` and callable `sessionData.maxDuration` from the stored policy instead of the legacy 1-hour response constant.
- Pre-existing sessions without `sessionPolicy` keep the legacy fallback, so this tranche applies the new contract only to new policy-backed sessions.
- The active call UI now uses the participant-gated `videoSessions.expiresAt` value for an in-call countdown and one-minute warning overlay.
- Policy-backed active calls now auto-trigger the existing `endSession` teardown path when the stored limit is reached, while `cleanupExpiredSessions` runs every minute as a server backstop for disconnected clients.
- Policy-backed active calls now support a one-time mutual +5-minute extension: each participant can consent once, the extension applies only after both agree, `expiresAt` moves forward by 300 seconds atomically, and stale `endReason=expired` requests are ignored if the session limit has already moved.
- Focused backend contract assertions for Session Policy currently come from the Functions JS tests already in this repo, including `video_sessions_shared.test.js`, `session_policy_live_surfaces.test.js`, `request_session_extension.test.js`, `end_session.test.js`, and `cleanup_expired_sessions.test.js`.
- Focused Flutter helper assertions for Session Policy currently come from `session_limit_ui_test.dart`; this repo still does not have a dedicated `MinimalDailyWidget` integration harness for the live countdown / auto-end / extension wiring, so this note does not imply full release-regression confidence by itself.

Acceptance criteria:

- Every new policy-backed session starts with 5-minute policy
- Warning appears 1 minute before limit on new policy-backed sessions
- New policy-backed session extends by 5 minutes only after both participants agree
- New policy-backed session ends at 5 minutes without mutual approval
- New policy-backed session ends at 10 minutes after one approved extension

Impacted systems:

- session schema
- live call widget
- end session flow
- backend enforcement

## Epic 12. Review And Relationship Flow

Objective: Keep review flow intact while integrating friends and messaging outcomes.

In scope:

- preserve post-call review submission
- rename favorite action to `Добавить в друзья`
- show open-chat CTA only for unlocked pairs

Out of scope:

- replacing rating logic
- direct friend calls

Dependencies:

- Epic 2 for friends model
- Epic 3 for messaging unlock

Execution note (2026-04-14):

- The post-call relationship CTA now uses friend semantics and the unlocked-pair chat CTA is already in place.
- Review submission now resolves the correct partner through participant-aware backend and handwritten Flutter paths, while preserving canonical pair reviews, rating aggregation, and existing validation.
- Epic 12 is complete; broader regression confidence remains tracked under QA.1.

Acceptance criteria:

- User can rate the partner after a call
- User can add partner to friends from post-call flow
- Open-chat CTA appears only when messaging is unlocked

Impacted systems:

- call summary
- review flow
- friends data
- conversations data

## QA And Release

Execution note (2026-04-15):

- `Issue QA.2` now has both focused backend/helper assertions and a fresh passing live emulator-backed `npm run backend:checks` run covering explicit `student-student`, `student-native_speaker`, and `native_speaker-native_speaker` pairwise scenarios, mixed candidate-pool scenarios for both `student` and `native_speaker` requesters, same-day repeat prevention, partner-level filtering, teacher boost ranking, and the 5-minute to mutual 10-minute session-policy path.
- `Issue QA.1` now has a targeted release-regression bundle covering auth/onboarding, VoIP/session teardown, reviews, dictionary/flashcards, `Чаты` unlock/empty-state contracts, approved-teacher finance access, soft email verification, and teacher payment/earning/withdrawal flows.
- `Issue QA.1` and `Issue QA.2` are complete; no SmallTalk V2 QA/release backlog gate remains open.

Acceptance criteria:

- Active scope defines one `Чаты` tab instead of separate friends/messages tabs
- Friend-priority appears only as removed/out-of-scope behavior
- No friend-specific duration remains in active scope
- `Чаты`, no-repeat-per-day, tester allow-list, universal 5-minute policy, mutual extension, and teacher admin approval are covered by issues
- Regression covers auth, VoIP/session teardown, reviews, dictionary, flashcards, teacher finance access, and chat unlock rules
