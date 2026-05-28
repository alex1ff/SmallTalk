# Video Call Review Tasks

Last updated: 2026-05-28

## Completed Tasks

- VC-TR-001: Added strict accepted-session credential participant helper.
- VC-TR-001: Blocked Daily token minting for searching, ended, cancelled, and no-tutor sessions.
- VC-TR-001: Blocked assigned-but-unaccepted `currentTutorId` from credential eligibility.
- VC-TR-001: Removed Deepgram raw API-key fallback to clients.
- VC-TR-001: Added `expiresAt` credential joinability gate for Daily and Deepgram callables.
- VC-TR-001: Capped Daily and Deepgram credential TTL by remaining session time.
- VC-TR-001: Added `acceptCall` joinability checks for idempotent Daily token returns.
- VC-TR-001: Removed persisted `studentMeetingToken` from shared `videoSessions` writes.
- VC-TR-001: Updated student waiting flow to fetch call tokens through `getSessionTokens`.
- VC-TR-001: Added Node tests/source contracts for credential issuance.
- VC-TR-001: Bootstrapped missing audit docs and inventory generator.
- VC-TR-002: Added authenticated `registerVoipToken` callable for FCM/PushKit token registration.
- VC-TR-002: Moved new VoIP token storage to server-owned `userPrivateTokens`.
- VC-TR-002: Updated push senders to use shared private-token helper with legacy fallback.
- VC-TR-002: Blocked new public user-doc VoIP token writes in Firestore rules.
- VC-TR-002: Added scheduled/admin migration for legacy public VoIP token fields.
- VC-TR-002: Added explicit-clear tombstone to prevent logged-out legacy fallback.
- VC-TR-002: Removed VoIP/FCM token prefixes from client and server logs.
- VC-TR-002: Added source/helper privacy contract tests for VoIP token storage.
- VC-TR-003: Added server-side Daily room deletion after trusted `endSession`.
- VC-TR-003: Awaited Daily room deletion during expired-session cleanup.
- VC-TR-003: Deleted precreated Daily rooms when `createVideoSession` is abandoned by the final repeat guard.
- VC-TR-003: Deleted Daily rooms when notification retry exhausts all tutors and marks no tutors available.
- VC-TR-003: Added Daily room-name URL fallback and idempotent already-deleted handling.
- VC-TR-003: Added Daily room cleanup status metadata for success/failure visibility.
- VC-TR-003: Made `declineCall` next-tutor/no-tutor transition atomic with the decline.
- VC-TR-003: Added transactional/fresh checks for Daily replacement rooms in `getSessionTokens` and transient room cleanup in `acceptCall`.
- VC-TR-003: Removed full background FCM payload logging from `main.dart`.
- VC-TR-003: Updated audit inventory generation to include `lib/main.dart`.
- VC-TR-003: Added source/helper lifecycle contract tests.
- VC-TR-004: Added authenticated `markSessionConnected` callable for server-owned connected timestamp writes.
- VC-TR-004: Replaced `MinimalDailyWidget` direct Firestore timestamp update with callable-backed marking.
- VC-TR-004: Required connected signals from both accepted participants before writing billing-critical `callConnectedAt`/`startedAt`.
- VC-TR-004: Changed missing-session callable response to `permission-denied` to avoid session enumeration.
- VC-TR-004: Added idempotency, accepted-participant, joinable-session, and index-export contract coverage.
- VC-TR-004: Added Flutter call-surface contract coverage for the connected marker path.
- VC-TR-005: Recorded that the project is no longer maintained through FlutterFlow and former generated files may be edited directly.
- VC-TR-005: Added authenticated `claimRegistrationGift` callable for server-owned registration gift minutes.
- VC-TR-005: Gated registration gift eligibility on trusted Firebase Auth account creation time instead of mutable user document role.
- VC-TR-005: Replaced email and social registration direct `giftMinutes`/bonus writes with the callable where a registration gift is granted.
- VC-TR-005: Kept student role persistence before gift claiming so callable outages do not strand new accounts.
- VC-TR-005: Blocked client writes to server-owned user fields: `balanceST`, `balance_NS`, `earnings`, `giftMinutes`, `priorityScore`, `rating`, `subscription`, `queuePriority`, and `totalCalls`.
- VC-TR-005: Added `requestWithdrawal` callable to create withdrawal requests from server-read balance and owned card ids.
- VC-TR-005: Disabled direct client transaction creation and direct `balance_NS` clearing.
- VC-TR-005: Added explicit admin-only rules for `registrationGiftClaims`.
- VC-TR-005: Updated audit inventory scope for AGENTS.md and current tranche Flutter files.
- VC-TR-005: Added helper tests and Firestore Emulator rules tests for user entitlement and withdrawal controls.
- VC-TR-006: Added a safe missing-session state for nullable or empty `VideoCallPageWidget.videoDocRef`.
- VC-TR-006: Rebound the cached `VideoCallPageModel.sessionStream` when `videoDocRef` changes.
- VC-TR-006: Reset session-scoped Daily/Deepgram credentials and ignore stale credential callbacks after session reference changes.
- VC-TR-006: Guarded terminal-status post-frame navigation with the captured session reference.
- VC-TR-006: Added Flutter call-surface contract coverage for nullable `videoDocRef`, stream refresh, and stale callback guards.
- VC-TR-007: Added state-aware tooltips/accessibility names for camera, microphone, chat, and end-call controls.
- VC-TR-007: Added chat close/send tooltips, excluded duplicate unread badge semantics, and kept the chat send button at a 48 dp touch target.
- VC-TR-007: Added Flutter call-surface contract coverage for accessible Daily call/chat controls.
- VC-TR-008: Added server-owned `userPublicProfiles` projection and sync trigger for public matching/profile fields.
- VC-TR-008: Added Firestore rules that allow signed-in reads of `userPublicProfiles` and block client writes.
- VC-TR-008: Added a backfill helper for existing `users` documents.
- VC-TR-008: Migrated the student dashboard partner-count query from `users` to `userPublicProfiles`.
- VC-TR-008: Added Firestore composite index definitions for the migrated public partner-count query.
- VC-TR-008: Migrated chat-thread and call-details public identity reads from counterpart `users` reads to `userPublicProfiles`.
- VC-TR-008: Removed duplicate public-profile writes from `syncUserMatchProfile`, leaving `public_user_profiles.js` as the single sync owner.
- VC-TR-008: Added helper/source contracts and Firestore Emulator coverage for public-profile privacy, migrated read paths, and rules behavior.
- VC-TR-008: Completed code/privacy, docs/tests, and auth/data-exposure reviewer gate with no P0-P2 blockers.
- VC-TR-009: Migrated `CallSummaryWidget` counterpart header identity reads from private `users` to `userPublicProfiles`.
- VC-TR-009: Migrated `ReviewCardWidget` review-author identity reads from private `users` to `userPublicProfiles`.
- VC-TR-009: Added source-contract coverage for post-call/review public-profile reads.
- VC-TR-009: Accepted and fixed reviewer P2 by keeping `CallSummaryWidget` usable when `userPublicProfiles/{uid}` is missing before deployed backfill completes.
- VC-TR-009: Guarded `CallSummaryWidget` relationship writes when `userRef` or `currentUserReference` is unavailable.
- VC-TR-009: Completed final reviewer recheck with no P0-P2 blockers.
- VC-TR-010: Migrated `FavWidget` favorite/native-speaker tiles from private `users` reads to `userPublicProfiles`.
- VC-TR-010: Migrated `FavoriteWidget` chat partner rows from private `users` reads to `userPublicProfiles`.
- VC-TR-010: Migrated `BlackListWidget` rows from private `users` reads to `userPublicProfiles` while keeping unblock writes scoped to the stored blocked user reference.
- VC-TR-010: Added source-contract coverage for favorite/chat/blacklist public-profile reads and regenerated audit inventory scope.
- VC-TR-010: Completed replacement code/privacy, tests/docs, and auth/data-exposure reviewer gate with no P0-P2 blockers.
- VC-TR-011: Added safe static native-speaker detail fields to the server-owned `userPublicProfiles` projection.
- VC-TR-011: Migrated `NativeSpeakerPageWidget` profile display, about text, language/country cards, and review totals from private `users` reads to `userPublicProfiles`.
- VC-TR-011: Kept live availability/session fields out of the public projection and left backend call creation as the authority for real availability/busy checks.
- VC-TR-011: Added source-contract coverage for native-speaker public-profile reads and regenerated audit inventory scope.
- VC-TR-011: Accepted reviewer P3 by caching the native-speaker public-profile stream and rebinding it with stats/reviews futures when `nsUserDocRef` changes.
- VC-TR-011: Completed code/privacy, tests/docs, and auth/data-exposure reviewer gate with no P0-P2 blockers.
- VC-TR-012: Restricted `users` document reads to self/admin plus uid-constrained legacy lookup for canonical profile migration.
- VC-TR-012: Blocked client writes to live lifecycle fields `isInCall`, `currentSessionId`, `isAvailable`, `availableAfter`, and `lastCallEndedAt`.
- VC-TR-012: Constrained user role mutation to valid roles and teacher-track-safe transitions.
- VC-TR-012: Removed client-side `isInCall: false` writes from dashboard/profile availability and role-switch paths.
- VC-TR-012: Added Firestore Emulator and source-contract coverage for scoped `users` reads, role constraints, and lifecycle write denial.
- VC-TR-012: Accepted reviewer P3 fixes by extending create/update denial coverage to all lifecycle fields and tightening the public-profile rules source-contract check.
- VC-TR-012: Completed code/privacy, tests/docs, and auth/data-exposure reviewer gate with no P0-P2 blockers.
- VC-TR-013: Added shared `ensureCameraAndMicrophonePermissions` helper that requests and rechecks camera and microphone independently.
- VC-TR-013: Replaced student dashboard call-start permission gates with the shared camera/microphone helper in both start paths.
- VC-TR-013: Added waiting-page media permission gate before `createVideoSession`.
- VC-TR-013: Added VoIP accept media permission gate before student token prefetch/navigation and tutor `acceptCall`.
- VC-TR-013: Added `VideoCallPageWidget` media permission state before credential fetches and `MinimalDailyWidget` mounting.
- VC-TR-013: Added source-contract coverage for the shared helper and all patched call-entry gates.
- VC-TR-013: Accepted reviewer fixes by moving fallback `getSessionTokens` behind the media-permission grant, guarding waiting-page permission returns with `mounted`, releasing VoIP process accept claims on permission denial, rejecting invalid VideoCallPage session refs before media prompts, and expanding inventory scope for all touched files.
- VC-TR-013: Completed code/regression/privacy, tests/docs, and authorization/data-exposure reviewer gate with accepted findings fixed; final authorization/data-exposure recheck found no P0-P2 blockers.
- VC-TR-014: Added shared incoming-call notification helper for durable `notifications` documents and matching push payloads.
- VC-TR-014: Wrote the first tutor notification in the same Firestore transaction as `createVideoSession` assigns `currentTutorId`.
- VC-TR-014: Wrote the decline handoff notification in the same Firestore transaction as the next `currentTutorId`.
- VC-TR-014: Made expired-notification processing atomically expire the old notification, record the timed-out tutor, assign the next tutor, and write the next tutor notification.
- VC-TR-014: Kept APNs/FCM push best-effort after the durable notification transaction commits.
- VC-TR-014: Added helper/source-contract coverage for transactional notification assignment.
- VC-TR-014: Added source-contract coverage that expired-notification handoff reads session state before transaction writes.
- VC-TR-014: Accepted reviewer fixes by revalidating expired-handoff assignment before push and whitelisting public `studentInfo` fields in notification docs.
- VC-TR-015: Added scheduled `cleanupFailedDailyRoomDeletes` worker for sessions with `sessionMetadata.dailyRoomDeleteFailedAt`.
- VC-TR-015: Reused `deleteDailyRoomForSession` so successful retries clear retry metadata and failed retries keep retry metadata.
- VC-TR-015: Added helper/source-contract coverage for retry room resolution, bounded query shape, schedule, export, and cleanup source.
- VC-TR-015: Accepted reviewer fixes by guarding fallback room resolution to terminal sessions, validating Daily room names, quarantining unsafe retry docs, and tightening delete-sentinel assertions.
- VC-TR-015: Completed code/regression, tests/docs, and authorization/data-exposure reviewer recheck with no P0-P2 blockers.
- VC-TR-016: Added authenticated `getDirectCallStatus` callable for coarse advisory direct-call availability.
- VC-TR-016: Kept private target live state server-side and returned only `canStartDirectCall`, coarse `callability`, `reason`, checked timestamp, and TTL.
- VC-TR-016: Collapsed target-side denial reasons to `unavailable` while preserving requester-owned `self`, `blocked_for_requester`, and `requires_access` states.
- VC-TR-016: Gated `NativeSpeakerPageWidget` direct calls through `getDirectCallStatus` before camera/microphone permission prompts and navigation.
- VC-TR-016: Reused the shared camera/microphone permission helper on the native-speaker direct-call path.
- VC-TR-016: Fixed stale top-level `isAvailable` overriding `availabilityToday.enabled=false`.
- VC-TR-016: Added helper/source-contract coverage for direct-call status, availability precedence, public-profile privacy, and native-speaker preflight ordering.
- VC-TR-016: Accepted reviewer fixes by restricting direct-call status probing to student requesters and approved native-speaker targets before live checks, hardening target id normalization, adding a mounted guard after native-speaker preflight, and regenerating inventory after final status edits.
- VC-TR-017: Added Daily presence/webhook verification for connected-call markers beyond the previous two-party client signal.
- VC-TR-017: Prevented client-only `markSessionConnected` signals from writing billing/chat/repeat-critical connected timestamps.
- VC-TR-017: Removed `startedAt`-only connected proof from chat unlock, repeat completion, end-session duration, and persisted call-chat consumers.
- VC-TR-017: Added Daily webhook HMAC/replay, accepted-participant, joinable-session, and two-party participant coverage.
- VC-TR-017: Added source-contract coverage that `dailyWebhook` is exported and the call surface requires Daily-backed connected marker authority.
- VC-TR-017: Accepted reviewer P2 fix so accumulated webhook join events stay advisory unless current Daily presence confirms both accepted participants.
- VC-TR-018: Added callable emulator coverage for `getDirectCallStatus`, `claimRegistrationGift`, `requestWithdrawal`, and connected-marker flows.
- VC-TR-018: Added Firestore/Auth emulator callable wrapper tests that exercise real auth context, Firestore paths, transactions, and server-owned writes through `firebase-functions-test.wrap`.
- VC-TR-018: Added Firebase Auth emulator config so `claimRegistrationGift` trusted Auth creation-time checks run under local emulator validation.
- VC-TR-018: Fixed `markSessionConnected` path-shaped session id handling and added emulator coverage for fail-closed second client signals without a Daily room.
- VC-TR-018: Updated audit inventory generation to include `firebase/firebase.json`.
- VC-TR-019: Added a read-only Firebase deployment readiness gate for critical `custom_cloud_functions` call/session/runtime exports, trigger types, secret bindings, and plaintext secret env metadata.
- VC-TR-019: Added unit coverage for the deployment readiness gate and ran it against production `smalltalk-2109b` without mutating production.
- VC-TR-019: Accepted reviewer fixes that expanded the gate to core call/session/token runtime exports and APNS/RevenueCat secret aliases.
- VC-TR-019: Recorded VC-BUG-026 because production is missing critical Functions, some deployed call lifecycle functions lack Daily secret bindings, and `acceptCall` has Daily keys visible as plain env metadata.
- VC-TR-020: Added a read-only Firebase Secret Manager metadata gate derived from the deployment readiness secret requirements.
- VC-TR-020: Replaced the broad package `deploy` script with an explicit readiness-gate target Function deploy script.
- VC-TR-020: Blocked production deploy at the time because Daily/RevenueCat secrets were missing or inaccessible; VC-TR-022 later closed this blocker.
- VC-TR-021: Fixed stale legacy VoIP migration so existing private FCM/PushKit tokens are not overwritten by public `users` token fields.
- VC-TR-021: Accepted reviewer P2 by moving private-token and current legacy-field reads inside the same Firestore transaction used for migration writes/deletes.
- VC-TR-021: Kept legacy public VoIP fields deleted during migration even when private tokens or clear tombstones are preserved.
- VC-TR-021: Added Firestore/Auth emulator coverage for `registerVoipToken` private writes, clear-all tombstones, admin migration gating, and legacy migration behavior.
- VC-TR-021: Added fake-db backfill coverage that `userPublicProfiles` writes only safe public projections and closes the BulkWriter when there are no users.
- VC-TR-021: Completed reviewer recheck after the transactional migration fix with no remaining P0-P2 findings.
- AIF-TR-001: Added authenticated `translateTerm` callable for quick in-call translation through server-side Google Cloud Translation v3.
- AIF-TR-001: Added hashed, case-sensitive `translationCache` ids so raw user text is not embedded in document paths and terms like `May`/`may` do not collide.
- AIF-TR-001: Added per-user cache-miss provider rate limit and cooldown while keeping cache hits provider-free.
- AIF-TR-001: Added optional session ownership validation before writing a lookup with `sessionRef`.
- AIF-TR-001: Added server-owned Firestore rules for `translationCache` and `translationRateLimits`, own-user read rules for `users/{uid}/translationLookups`, and denial coverage for admin collection listing of cache/rate-limit docs.
- AIF-TR-001: Added helper/emulator tests for validation, cache reuse, lookup writes, rate limiting, case-sensitive keys, session ownership, and translation rules access.
- AIF-TR-001: Accepted reviewer fixes for readiness deploy inclusion, cache collision, cache/rate-limit data exposure, missing provider rate limit, and catch-all admin list exposure.
- AIF-FREEZE-001: Customer paused quick translation and AI feedback before Flutter UI integration.
- AIF-FREEZE-001: Removed `translateTerm` from Functions exports, scoped deploy script, and deployment readiness requirements.
- AIF-FREEZE-001: Removed `@google-cloud/translate` from Functions dependencies and removed the local `translate_term` scaffold files.
- AIF-FREEZE-001: Removed translation-specific Firestore rules/tests and restored the previous catch-all admin fallback read behavior.
- AIF-FREEZE-001: Added existing UI-used `sendCustomEmailVerification` and `submitReview` to deploy/readiness coverage.
- AIF-FREEZE-001: Bound `sendCustomEmailVerification` to `RESEND_API_KEY` via `runWith` and added the secret to secret readiness.
- AIF-FREEZE-001: Removed unrelated protobufjs lockfile churn from the freeze patch and corrected the docs ledger mismatch.
- AIF-FREEZE-001: Completed final code/regression, docs/tests, and authorization/data-exposure reviewer recheck with no P0-P2 blockers.
- VC-TR-022: Set/validated required production Firebase secrets and reran secret readiness to PASS for 10/10 required secrets.
- VC-TR-022: Added retry support for transient Firebase CLI secret metadata failures, including parsed JSON error payloads, without printing secret values.
- VC-TR-022: Deployed only the scoped readiness-gate `custom_cloud_functions` target list to `smalltalk-2109b`.
- VC-TR-022: Cleared stale plaintext `DAILY_API_KEY`/`DAILY_DOMAIN` metadata from deployed `acceptCall` while keeping Secret Manager bindings.
- VC-TR-022: Reran deployment readiness to PASS for 26 required functions and smoke-tested Daily and RevenueCat webhook endpoints after redeploy.
- VC-TR-022: Documented the authorization/data-exposure reviewer recommendation to rotate chat-exposed operational secrets as customer-declined; no secret values are stored in repo docs.

## Open Tasks

- Run final live QA on a real device/TestFlight: Daily call join/end, RevenueCat offerings/prices/purchase, Resend verification email, Deepgram captions/token, and webhook delivery.
- Run/validate legacy VoIP token migration and public-profile backfill only when production mutation is approved.

## Blocked Tasks

- ESLint verification is blocked because no ESLint config is present in `firebase/custom_cloud_functions`.
- No current production readiness gate blocker remains after VC-TR-022.

## Open Test Gaps

- Manual mobile validation of Daily/Deepgram credential failure states and registration gift fallback messaging.
- Deployed/runtime validation that legacy VoIP migration drains existing production `users` fields and `backfill_user_public_profiles.js` fills existing `userPublicProfiles` after production mutation approval.

## Deferred Debt

- Larger decomposition of `MinimalDailyWidget` lifecycle/state ownership.
- Add lint config or documented JS style check for `firebase/custom_cloud_functions`.
- Current git status contains unrelated modified tests outside VC-TR-001; keep tranche validation scoped unless those files are intentionally included.
- Live Daily event-delivery validation and delete-room behavior beyond the webhook verification smoke test.
- Native-speaker live online/busy labels remain hidden in the UI; `getDirectCallStatus` is available for preflight, but visible labels still need a focused UX tranche if desired.
- Existing post-call relationship toggle debt: unblocking from `CallSummaryWidget` does not remove `blockedUsers`; defer to a relationship-state cleanup tranche.
- Review-card avatar fallback debt: missing public-profile photos still pass an empty URL to `CachedNetworkImage`; defer to a UI resilience tranche.
- Source-string contract tests are useful migration sentinels but brittle under harmless refactors; replace high-value cases with widget/helper tests when test harness cost is justified.
- VC-TR-011 reviewer P3 debt: native-speaker migration source-string checks now overlap with broader public-profile tests; replace with a less brittle widget/helper contract when test harness cost is justified.
- VC-TR-014 reviewer P3 debt: replace sanitized deterministic incoming-call notification ids with collision-resistant encoding or hashing if session/user id formats ever expand beyond Firestore auto ids.
- VC-TR-019 reviewer P3 debt: deployment readiness CLI supports `--project value` but not `--project=value`; copied warnings containing `{` before JSON fail closed; `formatReport`/JSON output should get explicit no-secret-value assertions.
- VC-TR-020 reviewer P3 debt: further improve copied-warning diagnostics before Firebase JSON; nonzero Firebase CLI JSON error output is now retried in VC-TR-022.
- Existing Functions dependency audit debt: `npm --prefix firebase/custom_cloud_functions audit --omit=dev --audit-level=critical` fails on pre-existing runtime dependency chains, mainly current `firebase-admin`/Firestore and `axios`; handle in a focused dependency-hardening tranche instead of broad forced upgrades inside feature work.
- Paused customer feature: quick translation and AI feedback tasks are retained in `docs/video-call-ai-features-tasks.md` for future restart, but should not be implemented until re-approved.
- Functions runtime debt: Node.js 20 deploy warning says upgrade before 2026-10-30 decommission.
- Customer-declined operational hardening: secrets pasted in chat/terminal context were not rotated per customer instruction on 2026-05-28; keep values out of repo/docs/logs.

## Next Recommended Tranche

No AI/translation tranche while customer scope is paused. Next recommended tranche is final live QA plus approved production data maintenance, or the next customer-approved app feature.
