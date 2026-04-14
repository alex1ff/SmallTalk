# SmallTalk V2 Issue Drafts

Date: 2026-03-31  
Updated: 2026-04-14  
Source docs:

- `2026-03-31-smalltalk-v2-master-prd.md`
- `2026-03-31-smalltalk-v2-epic-backlog.md`

Suggested labels:

- `epic`
- `backend`
- `flutter`
- `firebase`
- `migration`
- `product`
- `qa`

## Epic 1. Navigation Shell

### Issue 1.1 - Replace bottom navigation with Home / Words / Chats

Type: Flutter  
Depends on: none

Description:

Update the shared tab shell and nav bar so the primary navigation becomes `Главная / Словарь / Чаты`.

Acceptance criteria:

- Bottom nav no longer shows separate `Друзья`, `Сообщения`, `Профиль`, or `Мои звонки`
- `Профиль` is reachable from Home top-right
- `Чаты` is wired as the communication hub destination
- `Чаты` can host messages, friends, and call history entries

Technical notes:

- update `NavBarWidget`
- update `TabShellPage`
- do not move `Мои звонки` into Profile

### Issue 1.2 - Add Chats hub empty state and Home profile entry

Type: Flutter  
Depends on: Issue 1.1

Description:

Add the Home top-right profile CTA and the initial `Чаты` hub state for users without calls/messages.

Acceptance criteria:

- Profile opens from Home top-right
- Empty `Чаты` state says `Пусто. У вас пока нет звонков и сообщений`
- Call history entry point is inside `Чаты`, not Profile

Technical notes:

- final internal layout of `Чаты` can be refined with design, but destination ownership is fixed

## Epic 2. Friends Model

### Issue 2.1 - Add users.friends and migrate favoriteNativeSpeakers

Type: Firebase + migration  
Depends on: none

Description:

Introduce `users.friends` as the one-way relationship field and migrate or dual-read existing `favoriteNativeSpeakers` values into the friends surface.

Acceptance criteria:

- Existing favorite relations are present as friends
- New code can read friends
- Friends remain one-way follows
- Friends are not used for matchmaking priority or duration

Technical notes:

- add migration script or documented dual-read window
- do not implement mutual confirmation

### Issue 2.2 - Rename favorite UI to friends inside Chats

Type: Flutter  
Depends on: Issue 2.1, Issue 1.1

Description:

Rename favorite CTAs, empty states, and post-call actions to `Друзья`, and show the friends surface inside `Чаты`.

Acceptance criteria:

- No user-facing `Избранное` remains in v2 surfaces
- Friends are discoverable inside `Чаты`
- add/remove friend flows still work

Technical notes:

- update dashboard/detail/post-call labels where needed
- avoid adding a separate bottom `Друзья` tab

### Issue 2.3 - Remove direct-call affordances from friend surfaces

Type: Flutter  
Depends on: Issue 2.2, Issue 4.1

Description:

Remove direct-call shortcuts from saved favorite/friend surfaces. Friends should act as contacts/relationship entries, not direct call targets.

Acceptance criteria:

- Friend surfaces do not expose direct-call shortcuts
- Message CTA is shown only when messaging is unlocked
- Friends do not imply longer calls or match priority

Technical notes:

- review friend list cards and user detail surfaces

## Epic 3. Messaging Access Rules

### Issue 3.1 - Add conversation and message schema

Type: Firebase  
Depends on: none

Description:

Add the Firestore data model for unlocked 1:1 conversations and plain text messages.

Acceptance criteria:

- Conversation identity is deterministic per pair
- Conversation stores participant IDs and unlock metadata
- Messages belong to a participant-only conversation

Technical notes:

- use root `conversations`
- store messages in a subcollection or agreed message storage shape

### Issue 3.2 - Unlock conversation only after a completed connected session

Type: Backend  
Depends on: Issue 3.1

Description:

Create or unlock a conversation only after a session reaches completed/ended state after an active connection.

Acceptance criteria:

- Completed connected call unlocks the pair conversation
- Cancelled, expired, or never-connected calls do not unlock messaging
- Repeated completed calls reuse the same conversation

Technical notes:

- integrate with the existing session completion path

### Issue 3.3 - Add Firestore rules for conversations and messages

Type: Firebase  
Depends on: Issue 3.1

Description:

Restrict conversation and message access to participants only.

Acceptance criteria:

- Only participants can read a conversation
- Only participants can create messages in that conversation
- Non-participants cannot read or write messages

Technical notes:

- preserve caption log access behavior

### Issue 3.4 - Upgrade firebase-functions SDK in both Firebase codebases

Type: Firebase hardening  
Depends on: none

Description:

Upgrade `firebase-functions` in both `firebase/custom_cloud_functions` and `firebase/functions` to a current supported SDK version, then resolve any breaking changes so emulator and deploy behavior stay stable.

Acceptance criteria:

- Both Firebase codebases use the agreed supported `firebase-functions` version
- Functions emulator no longer reports the outdated SDK warning for either codebase
- Existing HTTP/callable/session/chat triggers still load and execute correctly
- `firebase emulators:exec --project demo-smalltalk --config firebase/firebase.json --only firestore,storage,functions "node audit/scripts/backend_checks_runner.js"` passes after the upgrade
- No Epic 3 or call-lifecycle regressions are introduced by the SDK migration

Technical notes:

- review v4 -> v7 breaking changes before upgrading
- verify compatibility with the installed `firebase-admin` version in each codebase
- keep legacy handlers on explicit `firebase-functions/v1` imports unless and until a separate v2 trigger migration is scheduled
- validate Firestore trigger, scheduled function, and HTTP function imports/options after the upgrade
- local emulator validation for `firebase-functions@7.x` requires a `firebase-tools` version that no longer calls `functions.config()` internally during runtime boot
- treat this as platform hardening, not as new product scope

## Epic 4. Messaging UI MVP

### Issue 4.1 - Add Chats hub inbox screen

Type: Flutter  
Depends on: Issue 1.1, Issue 3.1

Description:

Implement the `Чаты` destination as a communications hub that includes unlocked conversations, friends, and call history ownership.

Acceptance criteria:

- `Чаты` shows unlocked conversations when they exist
- `Чаты` owns friends and previous call entries
- Empty state uses `Пусто. У вас пока нет звонков и сообщений`

Technical notes:

- do not create a separate `Сообщения` bottom tab

### Issue 4.2 - Implement 1:1 thread screen with plain text send

Type: Flutter  
Depends on: Issue 4.1, Issue 3.3

Description:

Build the unlocked 1:1 text thread experience.

Acceptance criteria:

- User can open an unlocked conversation
- User can send a plain text message
- Messages stream in chronological order

Technical notes:

- no media attachments in v1

### Issue 4.3 - Add messaging entry points from post-call and friends surfaces

Type: Flutter  
Depends on: Issue 4.2, Issue 3.2

Description:

Expose entry points into an unlocked thread from post-call and eligible friend surfaces.

Acceptance criteria:

- Post-call flow can open the thread when unlocked
- Friend UI shows message CTA only when eligible
- Locked pairs do not show active message CTA

Technical notes:

- keep message CTA secondary to review/friend actions

## Epic 5. Matchmaking Engine V2

### Issue 5.1 - Redesign createVideoSession for all-to-all matching

Type: Backend  
Depends on: none

Description:

Replace student-to-teacher-only matching with all-to-all candidate selection using language, location, level, review rating, approved teacher boost, and a future internal-ranking placeholder.

Acceptance criteria:

- `student-student`, `student-native_speaker`, and `native_speaker-native_speaker` matches are possible
- Candidate pool is not restricted to teacher-like profiles only
- Friends are not used as a ranking factor
- Match context is stored on the session

Technical notes:

- update `create_video_session.js`
- do not accept or use `preferFriendsFirst`

### Issue 5.2 - Add normalized match profile data for all users

Type: Backend + Flutter  
Depends on: Issue 5.1

Description:

Normalize the user data required by all-to-all matching.

Acceptance criteria:

- Users expose active conversation language
- Location/level/rating inputs can be read consistently
- Existing onboarding/profile flows keep working

Technical notes:

- avoid broad FlutterFlow-generated refactors

### Issue 5.3 - Update session schema and rules for participantIds

Type: Firebase  
Depends on: Issue 5.1

Description:

Move session access rules toward a generalized participant model.

Acceptance criteria:

- Session docs store `participantIds`
- Rules allow session participants to read/update based on the new model
- Existing caption log access remains intact

Technical notes:

- preserve legacy compatibility where needed during migration

### Issue 5.4 - Prevent same-day repeat matches with tester allow-list

Type: Backend  
Depends on: Issue 5.1

Description:

Prevent matching the same pair twice in one calendar day after a completed connected conversation, while allowing configured tester users to bypass this for QA with Alexander/client testing. In the current backend slice, that bypass applies when either participant is on the tester allow-list.

Acceptance criteria:

- Completed connected pair is excluded from matching again on the same calendar day
- Cancelled/expired/never-connected calls do not count as completed repeats
- Tester allow-list bypasses the exclusion when either participant is allow-listed for QA
- Bypass is not exposed as a normal user-facing setting

Technical notes:

- store/query pair history using completed session metadata
- keep allow-list in backend/admin config or equivalent trusted source

Hardening note (2026-04-14):

- Completed connected sessions now write repeat-history metadata from both manual `endSession` and scheduled `cleanupExpiredSessions` teardown paths.
- Cancelled, never-connected, and unconnected expiry paths still skip repeat-history writes because no connected-call start is present.
- The day-key remains UTC-backed in this tranche; no local-calendar override was introduced.
- Focused Node tests now cover allow-list short-circuiting, repeat lookup exclusion, and completion-history payload generation in `match_repeat_prevention.js`.
- The latest recorded `audit/backend_checks_results.json` run confirms the completed-connected exclusion, never-connected skip, cancelled skip, and tester-bypass behavior for the current backend slice.
- A fresh `npm run backend:checks` rerun now passes in `/Users/patrikkardenas/SmallTalk` for the current UTC-day, env-backed tester-bypass implementation, so GitHub issue `#48` is closed while `Issue 5.1` through `Issue 5.3` remain open.

## Epic 6. Matchmaking Preferences UI

### Issue 6.1 - Extend filters with partner level

Type: Flutter  
Depends on: Issue 5.1

Description:

Update filters so users can choose preferred partner level while preserving language/location behavior.

Acceptance criteria:

- Preferred partner level control is visible and persists
- Existing language/location filters remain functional
- UI does not show `соединять в первую очередь с друзьями`

Technical notes:

- extend preferences only for active filters
- do not add friend-priority fields

### Issue 6.2 - Send updated filter payload to createVideoSession

Type: Flutter  
Depends on: Issue 6.1, Issue 5.1

Description:

Update the waiting-screen payload builder to send the current matchmaking inputs without friend-priority.

Acceptance criteria:

- Payload contains preferred partner level when relevant
- Old language/location fields still flow correctly
- Payload does not contain `preferFriendsFirst`

Technical notes:

- update `WaitingForTeacherPageWidget`

### Issue 6.3 - Close obsolete friend-priority task

Type: Product  
Depends on: none

Description:

Friend-priority matching was removed from the release. Close the obsolete implementation issue as out-of-scope.

Acceptance criteria:

- GitHub issue `#30` is closed with an out-of-scope comment
- Active docs no longer describe friend-priority as a deliverable

Technical notes:

- keep friends as contacts only

## Epic 7. Teacher Trust

### Issue 7.1 - Add teacher accreditation status to users

Type: Firebase  
Depends on: none

Description:

Add the user/profile fields needed to read teacher accreditation status from the Firebase/admin approval flow.

Acceptance criteria:

- User has a readable teacher accreditation status
- Status supports pending/approved/rejected or equivalent existing admin states
- Non-approved users do not receive teacher boost

Technical notes:

- align with existing verification document data where possible

### Issue 7.2 - Support Firebase/admin verification-document approval flow

Type: Flutter + Firebase  
Depends on: Issue 7.1

Description:

Support the flow where a user creates a verification document in Firebase and an admin approves or rejects it in the existing Firebase-connected admin process.

Acceptance criteria:

- Registration process remains shared for all users
- User can create or surface a teacher verification request
- Admin approval/rejection is reflected in the app
- No new standalone admin app is required in this repository

Technical notes:

- use the existing admin process contract rather than inventing a new moderation UI

### Issue 7.3 - Apply teacher boost to Fluent matching

Type: Backend  
Depends on: Issue 7.1, Issue 5.1

Description:

When the requester targets advanced/Fluent partners, approved teachers should receive a score boost.

Acceptance criteria:

- Approved teachers rank higher for Fluent requests
- Non-approved users stay eligible where otherwise valid but without teacher boost
- Teacher boost does not override hard eligibility filters

Technical notes:

- score boost depends on approved accreditation status

### Issue 7.4 - Gate teacher sections and payouts by approved accreditation status

Type: Flutter + Firebase  
Depends on: Issue 7.1, Issue 7.2

Description:

Preserve existing teacher functionality while ensuring teacher-only sections, payments, earnings, and withdrawals are available only after approved accreditation status where required.

Acceptance criteria:

- Existing teacher finance flows are not removed
- Approved users can access teacher sections and finance surfaces
- Non-approved users do not get teacher-only access
- Existing teacher users can be handled through migration/compatibility rules

Technical notes:

- review teacher dashboard, payment, earnings, and withdrawal surfaces

## Epic 8. Email Verification

### Issue 8.1 - Add soft verification status surfaces

Type: Flutter  
Depends on: none

Description:

Surface Firebase email verification state without blocking app usage.

Acceptance criteria:

- User can see whether email is verified
- User can resend verification email
- Unverified state does not block calling, messaging, or profile usage

Technical notes:

- use Firebase Auth `emailVerified`

### Issue 8.2 - Refresh email verification state on app resume and return flows

Type: Flutter  
Depends on: Issue 8.1

Description:

Refresh email verification state after the user returns to the app.

Acceptance criteria:

- Verification state updates after email confirmation
- User does not need to log out/in to see updated state

Technical notes:

- use current auth refresh patterns

## Epic 9. Live Learning Tools

### Issue 9.1 - Make live subtitles token-selectable

Type: Flutter  
Depends on: none

Description:

Make live subtitles tappable at word/token level.

Acceptance criteria:

- User can tap a word in live subtitles
- Tap target does not break caption readability

Technical notes:

- preserve current live caption rendering

### Issue 9.2 - Route live subtitle tokens into the add-word flow

Type: Flutter  
Depends on: Issue 9.1

Description:

Connect tapped live subtitle tokens to the existing dictionary add-word flow.

Acceptance criteria:

- Tapped token opens add-word flow
- Saved word appears in the existing dictionary pipeline

Technical notes:

- include source session/caption context where available

## Epic 10. Post-Call Learning Tools

### Issue 10.1 - Make call-details subtitle logs tappable

Type: Flutter  
Depends on: none

Description:

Make words in saved subtitle logs tappable in call details.

Acceptance criteria:

- User can tap words in post-call subtitle logs
- Caption log rendering remains readable

Technical notes:

- use existing `captionLogs`

### Issue 10.2 - Connect saved subtitle tokens to dictionary and flashcards

Type: Flutter  
Depends on: Issue 10.1

Description:

Route tapped saved subtitle tokens into the add-word flow and existing flashcard pipeline.

Acceptance criteria:

- Saved token can be added to dictionary
- Flashcards continue using existing saved-word data

Technical notes:

- do not replace the flashcard engine

## Epic 11. Session Policy

### Issue 11.1 - Persist universal session limit policy on session creation

Type: Backend  
Depends on: Issue 5.1

Description:

Store the universal 5-minute base session policy and extension contract when a match is created.

Acceptance criteria:

- Every session stores 5-minute base policy
- Warning lead is stored as 60 seconds
- One +5-minute extension is represented in session metadata
- Policy does not depend on friend status

Technical notes:

- recommended fields: `baseLimitSeconds`, `warningLeadSeconds`, `maxExtensionCount`, `extensionSeconds`, `effectiveLimitSeconds`

### Issue 11.2 - Add in-call countdown and 1-minute warning

Type: Flutter  
Depends on: Issue 11.1

Description:

Expose countdown behavior inside the active call experience and notify users 1 minute before the current session limit.

Acceptance criteria:

- Warning appears 1 minute before current limit
- Countdown starts from 5-minute base policy
- Countdown updates correctly if mutual extension is approved

Technical notes:

- final extension visual treatment follows the upcoming design

### Issue 11.3 - Enforce session end at the configured limit

Type: Backend + Flutter  
Depends on: Issue 11.2

Description:

Terminate sessions according to stored session policy.

Acceptance criteria:

- Session ends at 5 minutes when extension is not mutually approved
- Session ends at 10 minutes after one approved extension
- End flow remains consistent with current call teardown behavior

Technical notes:

- integrate with existing `endSession` behavior

### Issue 11.4 - Implement mutual 5-minute call extension flow

Type: Backend + Flutter  
Depends on: Issue 11.1, Issue 11.2

Description:

Implement the one-time +5-minute extension flow where both participants must agree before the current limit expires.

Acceptance criteria:

- Each participant can express extension consent once per session
- Extension applies only after both participants agree
- Extension cannot be applied more than once
- If one participant does not agree before timeout, the session ends at the current limit

Technical notes:

- UI visuals are design-dependent; backend/session contract is fixed

## Epic 12. Review And Relationship Flow

### Issue 12.1 - Rename post-call favorite action to add to friends

Type: Flutter  
Depends on: Issue 2.1

Description:

Update the post-call summary flow so the relationship CTA uses friend semantics instead of favorites semantics.

Acceptance criteria:

- CTA says `Добавить в друзья`
- Relationship write uses the new friends model
- Direct call behavior is not introduced

Technical notes:

- preserve current review flow

### Issue 12.2 - Keep review submission intact after session model changes

Type: Backend + Flutter  
Depends on: Issue 5.3

Description:

Ensure review submission still works after generalized participant session changes.

Acceptance criteria:

- User can review the correct partner
- Pair review aggregates continue to update
- Existing review validation still applies

Technical notes:

- update session participant resolution as needed

### Issue 12.3 - Add post-call open-chat CTA for unlocked pairs

Type: Flutter  
Depends on: Issue 4.3, Issue 3.2

Description:

If the just-finished session unlocked messaging, let the user jump directly into the thread from the post-call surface.

Acceptance criteria:

- CTA appears only for unlocked pairs
- CTA opens the correct pair thread

Technical notes:

- keep CTA secondary to rating flow

## QA And Release Issues

### Issue QA.1 - End-to-end regression pass for auth, VoIP, reviews, dictionary, flashcards, chats, and teacher access

Type: QA  
Depends on: Issue 1.1, Issue 3.3, Issue 5.4, Issue 7.4, Issue 8.2, Issue 10.2, Issue 11.4, Issue 12.2

Description:

Run a full regression pass across the release-critical flows.

Acceptance criteria:

- Auth/onboarding still works
- VoIP/session teardown still works
- Reviews still submit
- Dictionary/flashcards still work
- `Чаты` unlock/empty states work
- Teacher finance access remains available only under approved status
- Email verification remains soft

Technical notes:

- include regression for existing teacher payment/earning/withdrawal flows

### Issue QA.2 - Matchmaking matrix validation

Type: QA  
Depends on: Issue 5.1, Issue 5.4, Issue 7.3, Issue 11.4

Description:

Validate the new matching matrix across role combinations, repeat-prevention cases, teacher boost, and session policy variants.

Acceptance criteria:

- `student-student`, `student-native_speaker`, `native_speaker-native_speaker` verified
- same-day repeat prevention verified
- tester allow-list bypass verified
- Fluent approved-teacher boost verified
- 5-minute base duration and mutual 10-minute maximum verified

Technical notes:

- no friend-priority QA is required because that scope was removed
