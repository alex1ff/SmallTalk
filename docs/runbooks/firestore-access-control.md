# Firestore access-control manifest

Source of truth: [`firebase/firestore.rules`](../../firebase/firestore.rules).
This document records the **effective client-SDK permissions**, including the
recursive support-admin fallback. Firebase Admin SDK calls use service-account
credentials and bypass these rules; they are not represented by `admin=true`
below.

## Identity and global invariants

- A support admin is a signed-in Firebase Auth user with the immutable custom
  claim `admin == true`. No Firestore document grants this role.
- Normal client access is deny-by-default. The final recursive match permits
  support-admin **reads only**, except when the first path segment is in the
  protected-root list.
- No catch-all client write exists. Server-owned writes are performed through
  callable/background functions using the Admin SDK.
- An explicit local `allow ...: if false` does not override another matching
  allow. Therefore a non-protected path can still be read by support admins via
  the recursive fallback.

## Effective permissions

`Owner` means the authenticated document owner. `Participant` means membership
derived from a server-owned participant field or participant document.

| Path | Get/list | Create | Update | Delete | Sensitive invariant / writer |
|---|---|---|---|---|---|
| `users/{uid}` | Owner, matching legacy `uid`, or support admin; list succeeds only when every result meets the same condition | Owner with protected/server fields excluded, or support admin | Owner with role, accreditation, lifecycle, token and balance restrictions, or support admin | Support admin | Auth UID/path and privilege fields cannot be self-escalated |
| `users/{uid}/trialAccess/current` | Owner; support admin via fallback | Deny | Deny | Deny | Server subscription/trial functions |
| `subscriptionTrialGrants/{id}` | Support admin via fallback only | Deny | Deny | Deny | Server webhook/callable |
| `userPrivateTokens/{uid}` | Support admin via fallback only | Deny | Deny | Deny | Server token registration |
| `registrationGiftClaims/{uid}` | Support admin | Support admin | Support admin | Support admin | Server or explicit support operation |
| `userPublicProfiles/{uid}` | Any signed-in user | Deny | Deny | Deny | Server projection; contains public profile data only |
| `teacherVerificationRequests/{uid}` | Owner or support admin | Owner pending request with validated snapshot, or support admin | Owner can keep pending and cannot set review fields; support admin can review | Support admin | Proof paths must remain scoped to the owner |
| `searchRequests/{uid}` | Owner or support-admin single get; list denied to both | Deny | Deny | Deny | Protected root; server matchmaking only |
| `passiveSearches/{uid}` | Owner single get only | Deny | Deny | Deny | Server passive-search consent and presence |
| `activeSearchAttempts/**`, `passiveSearchOperations/**`, `passiveSearchDeliveries/**` | Deny, including support admin | Deny | Deny | Deny | Protected server coordination/idempotency state |
| `videoSessions/{id}` | Participant; support admin via fallback | Deny | Participant navigation fields only, or support admin | Deny | Server owns lifecycle and participant authority |
| `videoSessions/{id}/captionLogs/{log}` | Participant; support admin via fallback | Participant with bounded caption/diagnostic schema | Participant with immutable identity/source fields | Deny | Writer and speaker IDs must be session participants |
| `videoSessions/{id}/aiFeedback/{uid}` | Feedback owner who is a participant; support admin via fallback | Deny | Deny | Deny | Server AI generation |
| `translationCache/**`, `translationRateLimits/**`, `aiFeedbackRateLimits/**` | Deny, including support admin | Deny | Deny | Deny | Protected provider internals |
| `passwordResetRequests/**`, `passwordResetRateLimits/**` | Deny, including support admin | Deny | Deny | Deny | Protected authentication internals |
| `users/{uid}/translationLookups/{id}` | Owner; support admin via fallback | Deny | Deny | Deny | Server translation function |
| `conversationUnlockEvents/{id}`, `matchPairDailyCompletions/{id}` | Support admin via fallback only | Deny | Deny | Deny | Server idempotency/anti-repeat state |
| `conversations/{pair}` | Participant get; participant-map equality list; support admin via fallback | Deny | Participant may advance only their own read marker; no field addition/removal | Deny | Participant maps/IDs and unlock state are server-owned |
| `conversations/{pair}/messages/{id}` | Participant of unlocked conversation; support admin via fallback | Participant text message with exact sender identity and schema | Deny | Deny | Conversation must exist and be unlocked |
| `events/{id}` | Allowed active detail/list policy; organizer/participant exceptions; support admin via fallback | Deny | Active organizer may edit only validated content fields | Deny | Lifecycle/membership operations use functions |
| `events/{id}/participants/{uid}` | Own participant doc or authorized event viewer; bounded active list; support admin via fallback | Deny | Deny | Deny | Server membership functions |
| `events_public/{id}` | Signed-in users for active rows; support admin can read all via fallback | Deny | Deny | Deny | Server projection, no private event fields |
| `eventChats/{id}` and `/messages/{id}` | Active/canceled authorized participant only | Direct message create for active participant with trusted snapshot and UUID v4 ID | Deny | Deny | Protected root: no support-admin fallback |
| `users/{uid}/userWords`, `wordReviews`, `stats`, `cards` | Owner or support admin | Owner or support admin | Owner or support admin | Owner or support admin | Account-owned learning data |
| `users/{uid}/usage/{id}` | Owner or support admin | Support admin | Support admin | Support admin | Server usage accounting |
| `notifications/{id}` | Recipient or support admin | Support admin | Support admin | Support admin | Recipient ID is server-owned |
| `transactions/{id}` | Referenced owner or support admin | Support admin | Support admin | Support admin | Server billing ledger |
| `promoCodes/{id}` | Any signed-in user | Support admin | Support admin | Support admin | Callable `redeemPromoCode` is the server-only redemption writer |
| `reviews/{id}` | Any signed-in user | Signed-in author with rating 1–5, or support admin | Support admin | Support admin | Author reference must equal current user |
| `rewiews_of_the_app/{id}` | Owner or support admin | Owner or support admin | Support admin | Support admin | Legacy misspelled collection retained |
| `packages/{id}`, `avatars/{id}` | Public | Support admin | Support admin | Support admin | Deliberately public catalog assets |
| `eventCreationCounters/**`, `eventCreateRequests/**` | Deny, including support admin | Deny | Deny | Deny | Protected server idempotency/rate-limit state |
| `eventReports/**`, `chatMessageReports/**` | Support admin | Deny | Deny | Deny | Protected moderation evidence |
| Any unmatched path | Support admin only | Deny | Deny | Deny | Temporary support fallback; new roots require an explicit review |

Cloud Storage follows the same deny-by-default approach: authenticated users
may read and write only `users/{auth.uid}/**`; cross-user, unauthenticated and
all paths outside `users/{uid}/**` are denied. Admin SDK operations bypass
Storage Rules in the same way as Firestore Admin SDK operations.

Server code also uses unmatched operational roots such as `analytics`,
`maintenanceJobs`, `revenueCatPendingTransfers` and
`revenueCatTransferSources`. Normal clients cannot access them; support admins
can read them through the fallback. `acceptAttempts` is currently used only to
allocate an ID and is not evidence of a persisted collection.

## Query and index contracts

The emulator checks authorization predicates but does **not** prove production
composite indexes exist. Keep these shapes synchronized with
`firebase/firestore.indexes.json` and the Dart contract test.

| Client query | Required rules shape | Index contract |
|---|---|---|
| `events_public`: `status == active`, country, city, bounded `startsAt`, ordered by `startsAt` | Only active projections are listable | `events_public`: status/country/city/startsAt ascending |
| Legacy `events` equivalent | Paid-premium active event list | `events`: status/country/city/startsAt ascending |
| `conversations`: `participantMap.<uid> == true` | Dynamic map key must match the authenticated UID | Single equality predicate; no composite index currently required |
| `users`: `uid == <auth uid>` | Every returned document must satisfy owner/legacy UID rule | Single equality predicate |
| `events/{id}/participants`: active rows, limit at most 50 | Active event and authorized viewer | Query limit is enforced in rules |
| `eventChats/{id}/messages`: limit 1–100 | Authorized active/canceled event participant | Query limit is enforced in rules |

## Security regression procedure

Install both dependency trees first with `npm ci --ignore-scripts` and
`npm ci --prefix firebase/custom_cloud_functions --ignore-scripts`, then run
`npm run firestore:rules:test`. It starts isolated demo-project Firestore and
Storage emulators and executes all eight dedicated rules suites sequentially.
The suite covers positive client flows plus denial of cross-user access,
privilege-field changes, catch-all writes, protected-root admin reads, field
addition/removal during read-marker updates, promo-field tampering and
owner-only Storage paths.

`npm run backend:checks` first runs that canonical rules suite and then executes
only the unique backend integration/load checks: concurrent session ending,
conversation unlock processing, current matchmaking/session shape, partner
level filtering, verification/profile trigger delivery, 20-request load and
the call-lifecycle emulator scenario. It no longer carries a second copy of
rules expectations. Disabled same-day-repeat enforcement and the deliberately
removed teacher-only ranking are covered by their current unit contracts, not
by obsolete integration expectations.
