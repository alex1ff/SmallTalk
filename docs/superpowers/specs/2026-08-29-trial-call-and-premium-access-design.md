# Trial call and Premium access design

## Goal

Give a newly registered user a low-friction way to try one real conversation,
while keeping the rest of the calling and events experience behind a paid
subscription.

## User-facing behavior

1. A registered user can browse the app without an active subscription.
2. The event catalogue is visible as previews. Full event details and event
   participation require Premium.
3. Tapping **Start search** without an active subscription opens the Apple
   subscription sheet for the monthly Premium product with a three-day free
   introductory offer. Apple displays the billing terms and asks the user to
   confirm; the app never collects card details itself. If the Apple ID is not
   eligible for an introductory offer, the sheet shows the standard full price.
   After the purchase webhook is accepted, the server unlocks Premium
   immediately; until then the client shows a processing state.
4. During the introductory period the user may make one trial call. The trial
   call window is `purchased_at_ms + 30 minutes`, using the Apple/RevenueCat
   transaction timestamp (UTC milliseconds), not the device clock. A delayed
   webhook never extends this window. The 30-minute deadline controls creation
   of a reservation, not the duration of a reservation already created.
5. A trial call is qualified when both participants are connected and the call
   reaches 120 seconds. The server also requires call-lifecycle evidence (and
   may use captions as supporting evidence). A connection that fails for a
   verified technical reason before qualification does not consume the trial.
   Retry attempts are server-controlled and rate-limited so the rule cannot be
   bypassed with repeated short sessions.
6. Once the call qualifies, or the 30-minute trial window expires, search is
   blocked until Premium is active. The user can continue browsing previews.
   A call reservation created before the window deadline may continue after the
   deadline; no new reservation is accepted after it.
7. If the user does not cancel, Apple automatically charges the monthly price
   after three days. The subscription then becomes full Premium and unlocks
   unlimited calls and full events. If the user cancels before renewal, no
   charge is made and trial access ends at the Apple-provided expiry.

## Product and entitlement model

Use the existing monthly product `expatlio_1_Month` as the canonical Premium
auto-renewable subscription and configure its three-day introductory offer in
App Store Connect. Keep `expatlio_3_Month` in the paid-product allowlist and
RevenueCat offering for existing and direct quarterly purchasers; it is not
shown as the trial-entry package. The app-level trial restriction is derived from the
subscription period type (`TRIAL`) and the server-owned trial-call state; it
is not a second fake subscription product.

The existing RevenueCat offering `subscriptions` and entitlement remain the
integration point. `expatlio_1_Month` must be present in the offering and in
the Cloud Function product allowlist/webhook mapping. The server must treat
RevenueCat/Apple as authoritative for subscription state and must not trust
client writes.

An optional early-upgrade product can be designed separately. It is not part
of this scope because it adds same-group tier ordering and dual-active-product
handling without being required for the confirmed user journey.

## Server state

Store trial state in a server-owned `users/{uid}/trialAccess/current` document
to avoid mixing lifecycle state with client profile data. Fields and types are:

- `trialStartedAt`: Firestore Timestamp, nullable until a TRIAL transaction is
  confirmed
- `trialCallWindowExpiresAt`: Firestore Timestamp, nullable
- `trialCallStatus`: `eligible`, `inProgress`, `consumed`, or `expired`
- `trialCallId`: string, nullable; the current reservation id
- `attemptCount`: integer, starts at 0, maximum 3 sessions in the 30-minute
  window
- `technicalRetryCount`: integer, starts at 0, maximum 2
- `retryNotBeforeAt`: Firestore Timestamp, nullable; the earliest next retry
  time after a technical failure (10 seconds after `lastEndedAt`)
- `reservationLeaseExpiresAt`: Firestore Timestamp, nullable; a pending
  reservation lease is 90 seconds
- `bothJoinedAt`, `lastSegmentStartedAt`, `lastLifecycleAt`: Firestore
  Timestamp, nullable
- `activeConnectedSeconds`: integer, starts at 0 and is accumulated only while
  both participants are joined for the same call id
- `disconnectCount`: integer, starts at 0
- `qualifiedAt`, `lastEndedAt`: Firestore Timestamp, nullable
- `terminationReason`: enum `qualified`, `technical_failure`,
  `user_ended`, `partner_ended`, `expired`, nullable
- subscription mirror ordering metadata: `lastProviderEventTimestampMs`
  (integer) and `lastProviderEventId` (string), stored with
  `users/{uid}.subscription`

The existing subscription mirror remains at `users/{uid}.subscription`; it is
not duplicated in `trialAccess/current`. The trial document is self-readable
but server-writable only (`allow read: if isSelf(uid); allow write: if false`).

Transitions are Firestore transactions with a matching `trialCallId` guard.
Every reservation increments `attemptCount` atomically; a fourth reservation
is rejected and sets the state to `expired`. A technical retry increments
`technicalRetryCount`; the maximum is two retries (three total reservations).

| From | Event/guard | To |
| --- | --- | --- |
| absent | valid TRIAL transaction, unique original transaction id | `eligible` |
| absent | valid NORMAL purchase or ineligible intro purchase | no trial doc; paid Premium |
| `eligible` | `startSearch`, server time before deadline, attempts < 3, and server time at/after `retryNotBeforeAt` | `inProgress` |
| `eligible` | server time at/after deadline | `expired` |
| `inProgress` | both joined and accumulated seconds reach 120 | `consumed` |
| `inProgress` | user/partner ends after both joined | `consumed` |
| `inProgress` | pre-join cancellation, verified technical failure, or stale lease; before deadline and retries < 2 | `eligible` |
| `inProgress` | the same failure after deadline or after retry budget | `expired` |
| any trial state | subscription renews to `NORMAL` | `expired` and paid Premium |
| any state | refund/revocation event | subscription revoked immediately; access removed immediately |

`startSearch`, `createVideoSession`, `markSessionConnected`, `endSession`,
and `dailyWebhook` use one shared server access/lifecycle module. Concurrent
requests are rejected by the transaction state guard; webhook and call events
are idempotent by event/session id. A reservation started before the deadline
uses its own server timestamps and may qualify after the deadline. A temporary
reconnect closes the current segment and opens a new segment for the same call
id. The normalized Daily event contract is `{eventId, eventType, sessionId,
participantId, eventTimestampMs}`. `participant.joined`/`participant.left`
events open/close a two-participant segment; `room.ended` closes any open
segment. Events older than the stored event timestamp, duplicate event ids, and
overlapping segments are ignored or clamped to zero duration. Each segment's
server-duration is added to `activeConnectedSeconds` exactly once by event id.
The app sends an authenticated `heartbeatSession({sessionId, clientEventId})`
every 30 seconds while the room is active; `dailyWebhook` events also refresh
`lastLifecycleAt`. `cleanupExpiredSessions` reconciles a pending lease older
than 90 seconds and an active call with no lifecycle heartbeat for 180 seconds.

Only Cloud Functions/call lifecycle handlers may create or change these fields.
The exact Firestore rule is `match /users/{uid}/trialAccess/current { allow
read: if isSelf(uid); allow write: if false; }`; the root
`serverOwnedUserFields` denylist continues to cover `users.subscription` and
does not replace this nested rule. Require authenticated Firebase context plus
App Check for modified callables. The client may display state but cannot grant,
reset, or consume a trial call.

## Access checks

- `isTrial`: subscription is active, product is `expatlio_1_Month`, and
  `periodType == TRIAL`.
- `isPaidPremium`: subscription is active, product is allowlisted, and
  `periodType` is exactly `NORMAL` (the only paid period currently accepted).
  Missing, null, or unknown period types fail closed. Additional paid period
  types must be explicitly allowlisted before release.
- `canBrowseApp`: authenticated user.
- `canViewEventPreview`: authenticated user, reading only a public projection.
- `canStartCall`: `isPaidPremium`, or `isTrial` plus trial state `eligible`,
  server time before the deadline, no active call, and server time at/after
  `retryNotBeforeAt`.
- `canReadProtectedEvent`: `isPaidPremium`, `isAdmin`, event organizer, or an
  existing enrolled participant. This predicate applies to details, participant
  reads, event chat/history, and organizer chat.
- `canJoinEvent`: paid Premium for students; admins and event organizers may
  join/manage through their role-specific server path. An existing enrolled
  participant can read their event but cannot create a second enrollment.

All call-start and event-detail checks are enforced server-side. UI gating is
only a presentation layer and must fail closed when subscription data is stale
or unavailable.

`giftMinutes` no longer grants student call access in this flow. Deployment
order is: (1) deploy the server gate that ignores legacy student gift minutes,
(2) stop registration and promo-minute grants, (3) remove gift-minute CTAs and
legacy balances from the student UI. Existing balances expire naturally and
are not converted into calls or refunds. Remove the
existing 60-minute/day and 8-hour/week subscription ceilings for paid Premium;
retain only infrastructure abuse/rate protection that does not present as a
plan limit.

Events use a separate `events_public` projection containing only preview-safe
fields (title, city, start time, short description, cover image, and capacity
summary). `createEvent`, `editEvent`, and `cancelEvent` synchronously update
the projection in the same server workflow; a repair job backfills existing
events. Direct client reads of full `events` documents are removed/restricted
in Firestore rules. A `getEventDetails` callable accepts `{eventId}` and
returns either `{event: <protected projection>}` or a stable
`permission-denied`/`not-found` error. It checks the shared event-access
predicate; admins, organizers, and already-enrolled participants are explicit
exceptions. The
same gate is required for `joinEvent`, event participant reads, event chat
access/message send, organizer chat, and any event-history/detail endpoint.
Projection reads require authentication; full event documents are available to
server code/admins only. Rollout is ordered: deploy projection writers, run and
verify the backfill, ship a client that reads previews from `events_public`,
then restrict direct `events` reads after the new client is available. During
the dual-read window, the old path remains only for the previous client
version; no new feature may depend on it.

## Failure handling

- Purchase cancelled: keep the user on the paywall; do not create trial state.
- Purchase pending: show a processing state; create trial state only after a
  confirmed RevenueCat transaction.
- Store/RevenueCat catalogue unavailable: show the existing retry state; do
  not unlock calling or invent a price.
- If a confirmed purchase has no server mirror after 60 seconds, show
  "Purchase is still processing" with Restore/Retry actions and keep all
  server-gated access locked; never infer Premium from the client alone.
- RevenueCat webhook delayed: use the transaction's `purchased_at_ms` when it
  arrives, keep the server authoritative, and show a short processing state.
  Repeated deliveries are idempotent by `event.id`. Store
  `lastProviderEventTimestampMs` and `lastProviderEventId`; process a webhook
  only when its `event_timestamp_ms` is newer, or has the greater id on a tie.
  Missing `original_transaction_id`, `event_timestamp_ms`, or product id is a
  malformed webhook: return a non-2xx response, write only diagnostics, and
  perform no entitlement or trial mutation. The global
  `subscriptionTrialGrants/{originalTransactionId}` claim and the user's
  `subscription`/`trialAccess` projection commit in one Firestore transaction.
- Refund/revocation marks the subscription revoked immediately and removes
  Premium immediately. Billing retry/grace follows RevenueCat's active
  entitlement until its authoritative expiry, then fails closed.
- Restore/account switch rebinds RevenueCat to the authenticated Firebase uid;
  it never re-grants an introductory offer or resets trial state. A global
  `subscriptionTrialGrants/{originalTransactionId}` transaction ensures one
  Apple introductory grant per original transaction. If the same transaction
  arrives for a different uid, reject the grant and flag an account-mismatch
  error for support.
- Technical failure means a server-observed Daily lifecycle failure (no second
  participant, room/token failure, or provider error), not a client-supplied
  flag. Only two technical retries are allowed, with a 10-second cooldown.
- A user/partner hang-up after both participants joined consumes the trial even
  before 120 seconds; the 120-second rule protects only verified technical
  failures and prevents repeated short-call abuse.

RevenueCat lifecycle handling is explicit:

| Event | Required handling |
| --- | --- |
| `INITIAL_PURCHASE` + `period_type=TRIAL` | claim the unique original transaction; write trial timestamps/state atomically; write `expired` immediately if the 30-minute deadline has already passed |
| `INITIAL_PURCHASE` + `period_type=NORMAL` | write paid Premium; no trial grant |
| `RENEWAL` | write the new expiry; `period_type=NORMAL` ends trial and unlocks Premium |
| `CANCELLATION` + `UNSUBSCRIBE` | set `willRenew=false`; keep access through store expiry |
| `CANCELLATION` + `CUSTOMER_SUPPORT` | revoke the refunded period immediately |
| `CANCELLATION` + `BILLING_ERROR` | keep access during configured grace; wait for `EXPIRATION` to revoke |
| `BILLING_ISSUE` | record the issue; do not revoke while entitlement is active |
| `EXPIRATION` | revoke access immediately at the event's authoritative expiry |
| `UNCANCELLATION`/`SUBSCRIPTION_EXTENDED` | update renewal/expiry without resetting trial |
| `TRANSFER` | paid entitlements follow RevenueCat to the destination uid; update the destination mirror and schedule source-mirror reconciliation. Never re-grant or reset a trial; preserve the global transaction claim and acknowledge with 200 |

Malformed events (missing required ids/timestamps/product) receive a non-2xx
response so RevenueCat retries and no state is changed. A valid event whose
original transaction is already claimed by another Firebase uid is an
account-mismatch: acknowledge with 200, write diagnostics only, and never
reassign or reset the trial. Valid duplicate or older events receive 200 after
being recorded as ignored, preventing retry loops. A transaction claim and all
user projections are committed atomically.

The shared gate has two operations. Pure
`evaluateStudentCallAccess({uid, userData, trialData, usageData, nowMillis})`
returns `{allowed: bool, mode: 'premium'|'trial'|null, reason,
trialCallId: string|null, retryAfterMillis: int|null}` and never writes. For a
trial it returns `mode == 'trial'` with a null trial id because no reservation
exists yet. Atomic
`reserveStudentCallAccess({uid, requestId, nowMillis})` repeats the evaluation
inside a Firestore transaction, increments `attemptCount`, creates the
reservation id, and returns the same shape with a non-null trial id. `requestId`
is an idempotency key for the client attempt. `retryAfterMillis` is populated
only for cooldown states. A locally confirmed purchase is not an authority:
until the webhook mirror exists the server returns `no_subscription`; the
client may display a separate processing message. Stable reasons are
`auth_required`, `student_required`, `active_call`, `no_subscription`,
`trial_window_expired`, `trial_call_consumed`, `trial_call_in_progress`,
`premium_required`, `retry_cooldown`, and `usage_limit`. `retry_cooldown`
includes a non-null `retryAfterMillis`; every
search/direct-call entry point calls this helper before creating a room; no
client-only gate is considered authoritative.

## Verification

Automated coverage should include trial-period detection, Apple offer
ineligibility, pending purchase, transaction timestamp handling, 30-minute
expiry, the deadline boundary, reconnect accumulation, 120-second
qualification, technical-failure retry limits, duplicate/out-of-order webhook
idempotency, renewal-to-Premium access, cancellation, refund/revocation,
restore/account switching, gift-minute denial, removal of paid usage caps, and
event-preview redaction/participation gates. Emulator coverage also includes
stale leases/heartbeats, malformed period types/webhooks, atomic duplicate
trial grants, cross-account restores, and admin/organizer/participant event
exceptions. StoreKit sandbox/TestFlight
testing is still required for the real Apple sheet, introductory-offer
eligibility, renewal, restore, and delayed webhook flows.
