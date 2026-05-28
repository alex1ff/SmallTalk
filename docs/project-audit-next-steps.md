# Project Audit Next Steps

Last updated: 2026-05-28

## Next Recommended Tranche

No AI/translation tranche. Customer paused quick translation and AI feedback on 2026-05-27. VC-TR-022 closed the production secret/deployment readiness blocker; continue with final live QA or the next customer-approved app feature.

## Priority Queue

1. Final live QA: run a real/TestFlight call, verify RevenueCat offerings/prices/purchase flow, Resend verification email, Daily webhook delivery, and Deepgram caption token flow.
2. Production data maintenance: run/validate legacy VoIP token migration and public-profile backfill only when approved for production mutation.
3. Runtime upgrade debt: plan Functions Node.js 20 -> Node.js 22 before the 2026-10-30 decommission date.
4. Customer-approved feature work: pick the next approved feature that does not depend on the paused Translation/Gemini scope.
5. Test quality debt: replace high-value brittle source-string contracts with helper/emulator tests when setup cost is justified.

## Validation Debt

- `flutter analyze lib/students_pages/waiting_for_teacher_page/waiting_for_teacher_page_widget.dart` passed after the student navigation token-fetch change.
- `npx eslint` could not run because `firebase/custom_cloud_functions` has no ESLint config in this checkout.
- VC-TR-001 added no emulator-backed callable tests; that callable-emulator gap was closed for the highest-risk entitlement callables in VC-TR-018.
- Other modified `*test.js` files in `git status` are pre-existing/out-of-scope for VC-TR-001 and were not included in this tranche ledger.
- VC-TR-002 uses source/helper tests for token privacy; emulator-backed callable/rules tests stayed deferred outside that tranche.
- VC-TR-003 uses helper/source contract tests for Daily room lifecycle and cleanup metadata; live Daily API deletion was not exercised locally.
- VC-TR-003 added a targeted `flutter analyze lib/main.dart` run for the background logging privacy fix.
- VC-TR-004 used helper/source contract tests for callable authorization and idempotency; callable wrapper emulator coverage for connected-marker access control was added in VC-TR-018.
- VC-TR-005 adds Firestore Emulator rules coverage for user entitlement, transaction lockdown, registration gift claim docs, and withdrawal controls.
- VC-TR-005 kept callable emulator coverage for `claimRegistrationGift` and `requestWithdrawal` deferred; VC-TR-018 adds callable wrapper emulator coverage for both paths.
- VC-TR-005 reviewer gate re-raised broad `users` reads and mutable `role` as accepted VC-BUG-018 debt; VC-TR-008 started the public-profile split and VC-TR-012 closes the remaining read/rules hardening portion.
- VC-TR-006 adds source-level Flutter call-surface contract coverage for nullable `videoDocRef`, cached stream refresh, and stale credential callback guards.
- VC-TR-007 adds source-level Flutter call-surface contract coverage for accessible Daily call/chat control labels.
- VC-TR-008 adds helper/source contracts and Firestore Emulator rules coverage for `userPublicProfiles`, migrates dashboard/chat/call-details public reads, and keeps deployed backfill validation open.
- VC-TR-009 migrates call-summary counterpart and review-card author identity reads to `userPublicProfiles` with source-contract coverage, fallback rendering, and null-safe relationship writes.
- VC-TR-010 migrates favorite/native-speaker tiles, chat partner rows, and blacklist rows to `userPublicProfiles`; `NativeSpeakerPageWidget` remains open because it needs a safe tutor-detail/availability projection before broad `users` reads can be restricted.
- VC-TR-010 replacement reviewer gate passed with no P0-P2 blockers; P3/deferred debt remains tracked for `NativeSpeakerPageWidget` and source-string contract brittleness.
- VC-TR-011 migrates `NativeSpeakerPageWidget` static tutor-detail reads to `userPublicProfiles` and intentionally leaves live availability/call-state out of the public projection.
- VC-TR-011 reviewer gate passed after accepting the P3 stream-cache fix for `NativeSpeakerPageWidget`.
- VC-TR-012 closes `VC-BUG-018` by restricting `users` reads to self/admin plus uid-constrained legacy lookup, blocking client writes to live lifecycle fields including `lastCallEndedAt`, constraining role transitions, and removing client-side `isInCall` clearing from dashboard/profile writes.
- VC-TR-009 reviewer P3 debt: unblock cleanup, review-card empty-photo fallback, and brittle source-string contracts are deferred outside the privacy migration patch.
- VC-TR-013 closes `VC-BUG-011` by sharing an independent camera/microphone permission helper across dashboard call starts, waiting-page session creation, VoIP accept, and `VideoCallPageWidget` valid-session/media gating before Daily mounting.
- VC-TR-014 closes `VC-BUG-017` by writing incoming-call notification docs in the same Firestore transaction as tutor assignment for first-call and decline-handoff paths, and by atomically expiring old notifications plus assigning/notifying the next tutor in the expired-notification path. Reviewer P3 fixes added fresh assignment validation before expired-path push and whitelisted public student identity fields in notification docs.
- VC-TR-015 adds scheduled retry cleanup for sessions with `sessionMetadata.dailyRoomDeleteFailedAt`, using the existing Daily cleanup helper and no new client API or Firestore rule/index changes. Reviewer P3 fixes added terminal-state fallback guards, Daily room-name validation, and quarantine metadata for unsafe retry docs.
- VC-TR-016 adds authenticated `getDirectCallStatus` as a coarse advisory callable for native-speaker direct-call preflight, keeps private live fields out of `userPublicProfiles`, gates `NativeSpeakerPageWidget` before media prompts, and fixes stale top-level `isAvailable` overriding `availabilityToday.enabled=false`.
- VC-TR-017 makes client `markSessionConnected` signals advisory only, requires Daily presence/webhook two-party verification before `callConnectedAt`/`startedAt`, keeps accumulated webhook join events advisory unless current Daily presence confirms both accepted participants, and removes `startedAt` as connected proof for chat unlock, repeat completion, end-session duration, and persisted call-chat eligibility. VC-TR-022 later deployed and smoke-tested the Daily webhook endpoint.
- VC-TR-018 adds Firestore/Auth emulator callable wrapper coverage for `getDirectCallStatus`, `claimRegistrationGift`, `requestWithdrawal`, and `markSessionConnected`; the callable emulator gap for these access-control paths is closed. Remaining validation debt is production/runtime-only: Daily webhook delivery/config, Daily room deletion against the live Daily API, legacy VoIP token migration, public-profile backfill, and manual mobile media/call failure QA.
- VC-TR-019 adds a read-only deployment readiness gate that parses `firebase functions:list --json` and verifies critical `custom_cloud_functions` call/session/runtime exports, trigger types, secret bindings, and plaintext secret env metadata without printing secret values. VC-TR-022 later closed the production deployment gate blocker.
- VC-TR-020 adds a read-only Firebase Secret Manager metadata gate derived from the deployment readiness secret requirements. VC-TR-022 later closed the required-secret blocker and kept the gate value-safe.
- VC-TR-021 closes the local predeploy hardening gap for legacy VoIP token migration and public-profile backfill: existing private tokens and clear tombstones are preserved during migration, public legacy token fields are still deleted, and Firestore/Auth emulator plus fake-db behavior tests cover the migration/backfill paths before any production run.
- VC-TR-022 closes VC-BUG-026: required Firebase secrets exist with enabled versions, the scoped readiness deploy completed, `acceptCall` no longer exposes Daily keys as plaintext environment metadata, deployment readiness passes for 26 required functions, Daily webhook verification returns 200 OK, and RevenueCat webhook auth behavior was smoke-tested. The customer explicitly declined secret rotation; no secret values are stored in docs.
- AIF-TR-001 adds the local backend contract for quick in-call translation: authenticated `translateTerm`, Google Cloud Translation v3 server dependency, hashed case-sensitive cache ids, own-user lookup logging, optional participant-checked session refs, cache-miss provider rate limiting, and Firestore rules/tests that keep translation cache and rate-limit docs server-owned. Live provider validation remains blocked until customer Google Cloud credentials/secrets are available.
- AIF-TR-001 dependency audit note: `npm --prefix firebase/custom_cloud_functions audit --omit=dev --audit-level=critical` still fails on existing runtime dependency debt in the current Functions tree, mainly via the existing `firebase-admin`/Firestore stack and `axios`; broad/breaking upgrades are deferred to a focused dependency-hardening tranche.
- AIF-FREEZE-001 pauses the customer-deferred quick translation/AI feedback scope and removes the quick-translate runtime/deploy surface: no Flutter UI, no `translateTerm` export, no Google Cloud Translation dependency, no readiness requirement, and no translation-specific Firestore rules remain. Historical AIF notes stay in `docs/video-call-ai-features-tasks.md` for a future restart.
- AIF-FREEZE-001 reviewer fixes also expanded readiness coverage for existing UI-used `sendCustomEmailVerification` and `submitReview`; secret readiness now includes `RESEND_API_KEY`.
