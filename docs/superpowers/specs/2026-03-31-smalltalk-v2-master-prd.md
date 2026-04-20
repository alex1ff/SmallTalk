# SmallTalk V2 Master PRD

Status: Draft for execution  
Date: 2026-03-31  
Updated: 2026-04-08  
Owner: Product + Engineering

## Summary

SmallTalk V2 upgrades the current student-to-teacher calling flow into a general communication platform where any eligible user can be matched with any other eligible user. Teachers remain a special trusted capability layer, not a separate registration path.

The release combines these product directions:

1. Communication shell: bottom nav becomes `Главная / Словарь / Чаты`; `Чаты` contains messages, friends, and call history.
2. Social graph: `Избранное` becomes `Друзья`; friends are one-way follows and do not affect matching or call duration.
3. Matchmaking: all-to-all matching based on language, location, level, review rating, and a future internal-ranking slot.
4. Repeat prevention: do not match the same pair twice in one calendar day after a completed conversation, with a tester allow-list for Alexander/client QA.
5. Teacher trust: users register through one flow; approved teacher status is granted manually in the existing Firebase-connected admin process.
6. Messaging: users can message each other only after at least one completed connected call.
7. Learning: live and post-call subtitles become clickable and feed the existing dictionary/flashcard flows.
8. Session policy: all calls start at 5 minutes, warn 1 minute before end, and can be extended once by 5 minutes only if both participants agree.
9. Email verification: verification remains soft and does not block app access.

This PRD is grounded in the current codebase, where several requested features already exist in partial form:

- favorites are stored in `users.favoriteNativeSpeakers`
- the bottom shell exists in `lib/shared_pages/tab_shell/tab_shell_page.dart` and `lib/shared_pages/nav_bar/nav_bar_widget.dart`
- matchmaking is implemented in `firebase/custom_cloud_functions/create_video_session.js`
- subtitle logs already exist as `videoSessions/{sessionId}/captionLogs`
- post-call review already exists through `submitSessionReview`
- dictionary word capture and flashcards already exist
- teacher earnings/withdrawals/payment-related surfaces already exist under teacher pages and transaction flows
- Firebase Auth already exposes `emailVerified`

## Current State

- Student navigation currently uses `Главная / Словарь / Профиль / Мои звонки`.
- Teacher navigation currently uses `Главная / Профиль / Мои звонки`.
- Favorites are stored as `users.favoriteNativeSpeakers` and appear in dashboard/detail/post-call flows.
- Matchmaking currently starts from `WaitingForTeacherPageWidget`, calls `createVideoSession`, and is still centered on `student -> native_speaker`/teacher-like profiles.
- `UserRole` currently has `student` and `native_speaker`; legacy `teacher`/`tutor` values normalize into `native_speaker`.
- Firestore rules and session docs still rely on legacy role-specific fields like `studentId`, `tutorId`, and `currentTutorId`.
- No conversation/message schema exists yet.
- Teacher-specific finance functions already exist and must not be removed.

## Product Decisions

### 1. Navigation and chats

- Bottom nav becomes exactly `Главная / Словарь / Чаты`.
- `Профиль` is removed from bottom nav and opened from the top-right of Home.
- `Мои звонки` is not moved to Profile in this update.
- `Чаты` is a communication hub that contains:
  - unlocked message threads
  - friends list
  - call history / previous call entries
- If the user has no calls and no messages, `Чаты` shows `Пусто. У вас пока нет звонков и сообщений`.

### 2. Friends model

- `Избранное` is renamed to `Друзья`.
- Friends remain one-way follows, not mutual confirmation.
- Existing `favoriteNativeSpeakers` data is migrated or dual-read into the new friends surface.
- Direct calls from friend/favorite surfaces are removed.
- Friends do not affect matchmaking priority.
- Friends do not affect session length.
- Friend cards may expose messaging only when messaging is already unlocked by a completed call.

### 3. Messaging access model

- Messaging is allowed only after at least one completed connected call between the two users.
- The unlock is pair-based: once unlocked, the pair keeps the 1:1 conversation.
- Cancelled, expired, or never-connected sessions do not unlock messaging.
- Conversations appear inside `Чаты`, not in a separate `Сообщения` bottom tab.

### 4. Matchmaking model

- All-to-all matching is enabled for the general queue.
- Matching inputs are:
  - active conversation language
  - preferred partner location
  - preferred partner level bucket; in the general queue, an unset explicit
    preference defaults to the requester's effective profile level
  - partner review rating
  - approved teacher boost for advanced-level requests
  - reserved zero-value slot for future internal app ranking
- `preferFriendsFirst` and friend-priority behavior are not part of this release.
- Candidate exclusion must reject a candidate if the requester and candidate already had a completed connected call on the same calendar day.
- A backend/admin tester allow-list bypasses the same-day repeat exclusion for QA with Alexander/client test users.

### 5. Teacher trust model

- Registration process is the same for all users.
- Teacher functionality remains in the app, including payments, earnings, withdrawals, and teacher-only sections.
- Teacher status is assigned manually through the existing Firebase-connected admin process.
- The user creates a teacher verification request in the database.
- That request can include accreditation metadata such as teaching experience,
  one or more qualification proof types, and attached evidence-file storage
  paths.
- Admin reviews that request and manually approves or rejects it.
- Approved teacher status opens teacher sections and activates teacher boost in matching.
- Non-approved users can remain in the general user pool but must not receive teacher-only access or teacher boost.

### 6. Email verification model

- Firebase Auth `emailVerified` remains the source of truth.
- Verification prompts are soft.
- Users can resend verification email from the UI.
- Unverified email does not block calling, messaging, profile usage, or teacher verification request submission in v1.

### 7. Subtitle learning model

- Users can tap words in live subtitles during a call.
- Users can tap words in saved subtitle logs after a call.
- Both entry points route into the existing dictionary-add flow and preserve source context.
- Flashcards remain the downstream review mechanism and are not replaced.

### 8. Session policy model

- Base call duration is 5 minutes for everyone.
- A 1-minute warning appears before the current session limit.
- A call may be extended once by 5 minutes.
- Extension applies only when both participants agree before the current limit expires.
- Maximum duration after one approved extension is 10 minutes.
- The final extension UI is design-dependent, but the backend/session contract is fixed in this PRD.

## Data and Interface Rules

### Users

Add or normalize:

- `friends: List<DocumentReference<users>>`
- teacher accreditation status driven by the existing teacher verification request/admin process
- optional teacher access flags only if needed to preserve compatibility with existing `native_speaker` pages

Migration:

- Backfill or dual-read `favoriteNativeSpeakers` into the friends surface.
- Do not make friends mutual.
- Do not use friends in matching or session duration logic.

### Conversations and messages

Add root `conversations` and message storage for 1:1 text chat:

- conversation identity is deterministic per participant pair
- conversation reads/writes are participant-only
- message creation is participant-only
- conversation unlock requires a completed connected session
- conversations are displayed under `Чаты`

### Video sessions

Update session metadata to support:

- `participantIds`
- generalized participant roles
- pair identifier for same-day repeat checks
- `messagingUnlocked`
- `matchContext`
- `sessionPolicy`

Recommended `sessionPolicy` fields:

- `baseLimitSeconds = 300`
- `warningLeadSeconds = 60`
- `maxExtensionCount = 1`
- `extensionSeconds = 300`
- `extensionRequests`
- `extensionApproved`
- `effectiveLimitSeconds`

### createVideoSession

Update callable contract:

- support all-to-all matching
- derive active conversation language by role/profile
- use partner location, level, review rating, and teacher boost
- reserve a zero-value internal-ranking slot
- reject same-day repeat matches after completed connected calls
- bypass same-day repeat for configured tester allow-list users
- do not accept or use `preferFriendsFirst`

### Teacher verification

Use the existing Firebase-connected admin flow:

- user creates a teacher verification request
- admin approves/rejects manually
- approved status opens teacher sections
- approved status gates teacher payments/earnings/withdrawals access where applicable
- approved teacher status is the only condition for teacher boost

## User Journeys

### Journey A: User starts a call from Home

1. User opens Home.
2. User sets conversation filters: language, partner location, partner level bucket. Home defaults partner level to the user's effective profile level unless the user selects an explicit partner level.
3. App sends the request to `createVideoSession`.
4. Backend builds the eligible all-to-all candidate pool.
5. Backend excludes blocked/unavailable/in-call users and same-day completed pairs unless tester allow-list bypass applies.
6. Backend ranks by filters, review rating, teacher boost, and future internal-ranking placeholder.
7. Session is created with 5-minute policy and 1-minute warning.
8. Call starts.

### Journey B: User opens Chats

1. User opens `Чаты`.
2. If calls/messages exist, the screen shows communication entries.
3. User can open unlocked message threads, friends, or previous call entries.
4. If there are no calls and no messages, the screen shows `Пусто. У вас пока нет звонков и сообщений`.

### Journey C: User adds a partner to friends after a call

1. User completes a call.
2. User leaves a rating as today.
3. User can choose `Добавить в друзья`.
4. The partner appears in friends inside `Чаты`.
5. This relationship does not change matching or duration.

### Journey D: User messages after a completed call

1. User completes at least one connected session with another user.
2. Session completion unlocks or creates the 1:1 conversation.
3. `Чаты` shows the unlocked conversation.
4. User can open the thread and send text messages.

### Journey E: Teacher status approval

1. Any user registers through the same general registration process.
2. User creates a teacher verification request.
3. Admin reviews that request in the existing Firebase-connected admin process.
4. Approved status opens teacher sections and teacher payment/earnings/withdrawal functionality.
5. Approved teachers receive boost for advanced-level matching.

### Journey F: Call extension

1. Call starts with a 5-minute limit.
2. At 1 minute before the current limit, users see warning and extension affordance once UI is finalized.
3. Each participant can request/accept extension.
4. If both agree before timeout, the session extends by 5 minutes.
5. If either participant does not agree, the call ends at the current limit.

### Journey G: Vocabulary capture

1. User sees live subtitles or post-call subtitle logs.
2. User taps a word.
3. App opens the existing add-word flow with source context.
4. Saved word appears in dictionary and later in flashcard review.

## Success Criteria

- Bottom nav shows `Главная / Словарь / Чаты`.
- Profile is reachable from Home top-right.
- `Чаты` contains messages, friends, and call history.
- Empty chats state is `Пусто. У вас пока нет звонков и сообщений`.
- Existing favorite relations survive as friends.
- Direct calls from friends/favorites surfaces are removed.
- Friend-priority is absent from UI, payloads, and backend matching.
- Users can be matched across role combinations under the new all-to-all rules.
- Same pair is not matched twice in one day after a completed connected call, except configured tester allow-list users.
- Approved teachers keep teacher functionality and receive matching boost where defined.
- Messaging is impossible before a completed connected call and available afterward.
- Live and post-call subtitles can save words into the existing learning pipeline.
- Soft email verification is visible and actionable without blocking the app.
- Calls use 5-minute base limit, 1-minute warning, and one mutual 5-minute extension.

## Out-of-Scope Follow-Ups

- Internal application ranking implementation and weight tuning
- Push notifications for messaging read/delivery beyond inbox freshness
- Group messaging or attachments
- New standalone admin app in this repository
- Mutual friend confirmation workflow
- Friend-priority matching
- Friend-specific call duration
