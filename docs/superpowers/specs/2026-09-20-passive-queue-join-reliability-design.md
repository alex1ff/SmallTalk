# Passive queue join reliability

## Goal

Make joining the passive matchmaking queue reliable across account switches, delayed Firestore restoration, slow iOS notification-token registration, and small client/server timing differences. Do not create duplicate queue entries or weaken the existing match race protection.

## Confirmed failure surface

Production logs show successful callable verification followed by HTTP 400 responses from `joinPassiveSearch`. The client currently maps every thrown error to the same connection message, so the server reason is hidden.

The code contains three failure races:

1. A valid `passiveSearches/{uid}` document may already be waiting while the dashboard still shows duration choices. The client creates a new consent ID and the server rejects it as `passive_search_already_waiting`.
2. The dashboard sends the locally retained source search request ID. If restoration or a late search update changed the canonical request, the server rejects the action without explaining that the displayed offer is stale.
3. On iOS, notification permission may already be granted while `getAPNSToken()` is temporarily null. The client immediately fails and reports a connection problem.

## Server behavior

`joinPassiveSearch` remains the only authority that creates or adopts a queue entry.

Inside its transaction it must:

- read the current queue, operation, user, canonical search, access state, and FCM token;
- if the current queue is still waiting for the same user and has the same `sourceSearchRequestId` requested by the client, adopt it as an idempotent success;
- when adopting queue request `A` for incoming operation `B`, write operation `B` as an alias containing `canonicalRequestId: A`; this lets a concurrent Stop resolve the same queue;
- otherwise require the current `searchRequests/{uid}.requestId` to equal the client source ID; a mismatch is `source_request_changed`, never an automatic rebind to a newer search;
- validate the matching canonical search document using server time;
- reject manual stops, active/matched sessions, invalid access, missing notification tokens, and a source whose server deadline has not elapsed;
- return the exact success schema: `status: "waiting"`, canonical queue `requestId`, `expiresAt`, canonical `sourceSearchRequestId`, `serverNowMillis`, and `adopted`;
- preserve the existing transaction and operation tombstones so concurrent join/leave and connect races cannot revive a stopped queue.

`leavePassiveSearch` receives both the local operation ID and `sourceSearchRequestId`. If its operation is an alias it reads the canonical operation, propagates any winning `sessionId`, stops the queue, and tombstones both alias and canonical operations. If Stop reaches the server before Join, it writes a tombstone for the local operation and also stops an existing waiting queue only when that queue has the same source ID. Thus either transaction ordering makes Stop win without affecting a queue for a different search.

The client-provided source ID is a causal version. A delayed join for search `A` can never enroll the user into a newer search `B`.

## Client behavior

### Notification readiness

After permission is granted on iOS, poll for the APNs token immediately and after delays of 250, 500, 750, 1000, and 1500 milliseconds, for a maximum of four seconds. Each poll exception is retained; success ends polling. Permission request, APNs polling, FCM-token retrieval, and token registration each keep the existing 25-second outer timeout. Stop immediately when the signed-in Firebase user changes. APNs or FCM exhaustion produces `notification_token_unavailable`; a permission API error produces `notification_permission_unavailable`.

### Joining

The join response is authoritative. `PassiveSearchState.sourceSearchRequestId` uses the server response. The service records request start and round-trip duration and reuses `resolveServerClockOffset` from `session_limit_ui.dart`; the request midpoint is compared with `serverNowMillis`. The resulting offset is stored once in the dashboard for the active account and applied through `_passiveNow()` to success validation, queue timers, and all later Firestore queue snapshots. It is reset only when the authenticated user changes. The absolute server `expiresAt` is never shifted, so network transit time cannot extend the queue. After any successful join or adoption, the dashboard replaces its local operation ID with the returned canonical queue request ID so later Stop targets the correct queue.

An existing waiting queue is a success, not an error. Repeated taps remain blocked by `_passiveBusy`, and duplicate network delivery is safe because the server adopts the existing queue transactionally.

### Errors

Add `PassiveSearchFailure` with the callable reason and optional `retryAfterMillis`, defined as an absolute Unix epoch in milliseconds. The complete join handling table is:

- `source_not_expired`: its error details contain both absolute `retryAfterMillis` and `serverNowMillis`; calculate/update the midpoint clock offset first, then retry once with the same operation ID when the server-aligned delay is no more than five seconds; otherwise keep the choices visible and say the search is still finishing;
- `notification_token_unavailable`, `notification_permission_unavailable`, `fcm_token_required`: retryable with the same operation ID; explain that notification setup did not complete;
- `source_request_changed`, `source_stopped_manually`, `source_has_session`, `source_status_invalid`, `source_already_consented`, `consent_closed`, `consent_expired`: terminal for the displayed offer; return the dashboard to idle and discard the local operation ID;
- `call_access_required`: terminal for the offer; return idle and show that subscription or trial access is unavailable;
- `invalid_request_id`, `invalid_passive_search`, `invalid_duration_or_timezone`: terminal programming/input errors; discard the operation and show that the queue request could not be created;
- `authentication_required`: terminal until the account is restored; return idle;
- deadline/transport/unknown failures: retryable with the same operation ID and the connection message.

The server supplies these reasons separately. Manual stop is `source_stopped_manually`; any current or matched session is `source_has_session`; ownership/request mismatch is `source_request_changed`; a not-yet-elapsed server deadline is `source_not_expired`; an already attached passive consent that is not adoptable is `source_already_consented`; unsupported status or stop reason is `source_status_invalid`.

The UI keeps the duration controls available after a retryable failure. It never claims that the user joined unless the returned state is `waiting` with a future expiry.

## Concurrency guarantees

- There is at most one waiting queue document per user because its document ID is the user ID.
- A second join adopts the existing request ID and expiry; it does not extend the queue. Its small alias operation exists only for cancellation/idempotency and never becomes another queue.
- A concurrent Leave wins for both transaction orderings because it carries the causal source ID and the alias/tombstone is durable.
- Starting a new active search continues to stop an existing passive queue atomically.
- Competing users connecting to one active search continue through `reserveMatchPairInTransaction`, so only one session can win.

## Validation

- Unit-test APNs token readiness: immediate token, delayed token, polling exception then success, timeout, FCM timeout, permission timeout, and account switch.
- Widget-test that an adopted queue replaces the local consent ID and Stop uses the returned ID.
- Test reason-specific Russian and English messages.
- Backend-test same-source existing-queue adoption, source-ID mismatch rejection, both orderings of `join(B)`/`leave(B)` while queue `A` exists, delayed join for search `A` after search `B`, duplicate joins, and existing connect races.
- Run passive-search backend tests, affected dashboard tests, and `flutter analyze`.
