# Search regression gate and pre-push context

## Scope

Restore the full `start_search.test.js` emulator suite as evidence for P1-03.
Do not change subscription, filtering, ranking, transaction ordering or the
public callable response. This is a prerequisite, not completion of P1-03.

## Evidence

- Baseline with Firestore: 77/103 pass; 26 failures are initially hidden behind
  gift-only fixtures, although access now requires a subscription.
- Paid fixtures expose 18 failures, mostly cross-test candidate contamination.
- A process-specific demo project and between-test cleanup reduce this to six.
- Four background delivery scenarios fail with `db.collection` on undefined:
  the legacy notification hook is zero-argument, but its default callback now
  delegates to `waitForForegroundMatchClaim`, which requires match context.
- Two expectations conflict with separately tested current rules: no-filter
  role-neutral waiting order, and a selected minimum level (not ±1 adjacency).

## Minimal design

1. Paid positive fixtures, explicit gift-only denial, preserved `subscription:
   null` and trial overrides. Assert denied starts do not create search/trial
   records or modify the user.
2. A fixed `demo-smalltalk-search-<pid>` namespace, guarded loopback emulator
   endpoint, awaited cleanup between tests and at exit. Never clear a namespace
   selected from a production environment variable. Keep within-test races.
3. Assert absent location filters stay absent. For reuse, supply explicit
   location filters initially and verify later input cannot replace them.
4. Bind the default pre-push wait at the orchestration call site to the current
   `db`, `sessionId`, `pairAttemptId`, and responder `participantId`. Keep the
   notification helper's zero-argument hook and optional/non-function skip.
   Keep its post-wait revalidation and cancellation behavior unchanged.
5. Align ranking fixture inputs with their intended current scenario; do not
   alter production ranking to satisfy old assertions. No new token fixtures.
6. Point direct-call separation source contracts at the entry policy that now
   owns input normalization, while also checking the endpoint imports it.

Passing an empty object or swallowing the wait error would hide the defect.
Replacing the delivery flow or disabling the wait is unnecessarily broad.

## Validation / rollback

The four existing default-path emulator scenarios are red regression tests
before the wiring fix: notify, decline restore, timeout restore, push failure
retry. Preserve their transport assertions and the one-session race checks.
Run all search tests twice with no skips, lifecycle tests in the emulator,
backend lint/CI, Flutter analyzer and scoped review. No native push delivery or
production rollout is claimed. Rollback is limited to the call-site binding;
test isolation remains useful independently. No deployment or data migration.
