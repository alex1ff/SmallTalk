# Passive search implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development for the backend task and independent reviews; integrate the Flutter client in the current task. Execute continuously under the already approved design.

**Goal:** Two-minute active search, durable opt-in passive waiting, ordinary availability notifications and teacher-only native incoming calls.

**Architecture:** Keep existing v2 session reservation/coordinator. Add server-owned passive records and a separate ordinary-push client. Share exact request versions across join, stop, notification, and connect.

**Tech Stack:** Flutter/Dart, Firebase Functions v1 Node.js, Firestore, FCM, current match protocol v2.

## 1. Server queue and active-search lifecycle

Files: `firebase/custom_cloud_functions/passive_search*.js`, existing search policy/matcher/pair-lock/delivery/recovery modules, `index.js`, `package.json`, `firebase/firestore.rules`, `firebase/firestore.indexes.json`.

- [ ] Add callable contracts (all require auth; errors are standard HttpsError):

```js
joinPassiveSearch({searchRequestId, requestId, duration: '30' | '60' | 'day', utcOffsetMinutes, locale: 'ru' | 'en'})
// => {status: 'waiting', requestId, expiresAt: ISO8601}
leavePassiveSearch({requestId})
// => {status: 'stopped', requestId, sessionId?: string}
connectPassiveSearch({requestId, activeUserId, activeRequestId})
// => {status: 'matched', sessionId, pairAttemptId, matchProtocolVersion: 2}
// or {status: 'unavailable'} without mutating waiting subscription
```

- [ ] Persist own subscription at `passiveSearches/{uid}` with `requestId`, `sourceSearchRequestId`, `status`, `expiresAt`, `language`, `filters`, `locale`, `userId`. A stopped tombstone blocks delayed join; successful connect stores its session for retry/stop. New ordinary start explicitly replaces passive waiting.
- [ ] Enforce active deadline `min(expiresAt, createdAt + 120000)` at matching, refresh and restoration. Students are only automatic candidates in foreground. Never dispatch CallKit for student recipients, including escalation/recovery and legacy routes; retain native-speaker dispatch.
- [ ] Add Firestore trigger for newly available active attempts with paginated compatible passive recipients and deterministic delivery claims. FCM payload:

```js
{ notification: {title, body}, data: {
  type: 'partner_available', recipientId, requestId,
  activeUserId, activeRequestId, expiresAt: ISO8601
}, android: {priority: 'high', ttl: remainingMillis},
apns: {headers: {'apns-push-type': 'alert', 'apns-expiration': epochSeconds}} }
```

- [ ] Extend existing reservation helper narrowly to atomically synthesize the responding user's active request from a still-valid passive subscription. Perform all reads before writes, reuse entitlement/trial/lock/role/block policies, validate both filter directions and exact versions inside the transaction. Consume passive waiting only on success.
- [ ] Add server-only rules, required indexes and deploy manifest entries.
- [ ] Test pure policies plus emulator races: expiry, manual stop vs join/connect, duplicate taps, several recipients competing for one active request, paging, wrong account/versions, incompatible filters, failed push retry, native-teacher preservation.

## 2. Flutter queue and notification services

Files: `lib/services/passive_search_service.dart`, `lib/services/partner_availability_notifications.dart`, `lib/main.dart`, corresponding service tests.

- [ ] Parse subscription snapshots and deadlines independently of widgets, wrap callables with timeouts, expose injected readers/invokers for tests.
- [ ] Register normal FCM permission/token on explicit queue join using the existing token registration callable. Refused permission leaves user on duration selection with a truthful error.
- [ ] Subscribe to ordinary foreground messages and tap events; read initial message once. Validate recipient/type/versions, wait for auth + resumed lifecycle + navigator readiness, request media permissions only on tap, invoke connect then let MatchCoordinator navigate. Stale target shows a message and preserves waiting. Dispose pending actions on account change.
- [ ] Cover parser/time calculations, stale/foreign payload, duplicate tap and network errors with injected dependencies.

## 3. Dashboard integration

Files: `lib/components/passive_search_panel.dart`, `lib/students_pages/students_dashboard/students_dashboard_widget.dart`, `lib/services/active_search_recovery.dart`, dashboard/component tests.

- [ ] Add choosing/passive states and render a compact panel using existing design tokens, RU/EN labels and red stop action.
- [ ] Derive countdown from server deadline and use one expiration transition. Stop extending/restarting active timers on rebuild/resume/retry. Restore expired active request as duration choice, restore passive waiting from its snapshot.
- [ ] Join stores a stable operation ID across uncertain retries; cancellation uses the same ID even while join is in flight. Stop must show error if server cancellation fails and keep the cancellation actionable.
- [ ] Tests: timer 02:00→00:00, choose all durations, permission refusal, stop, restoration and stale notification response; update old tests asserting ten-minute background calls to the approved behavior.

## 4. Review and validation

- [ ] Spec compliance review then code-quality review of the resulting diff; fix findings.
- [ ] Run `npm --prefix firebase/custom_cloud_functions run lint`, scoped node tests and emulator lifecycle/search suites, `flutter analyze`, `flutter test`.
- [ ] Record counts and limitations. Prepare deploy configuration; no production deploy is included in local validation.
