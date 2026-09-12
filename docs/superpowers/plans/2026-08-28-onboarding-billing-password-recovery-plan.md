# Onboarding, Billing, and Password Recovery Implementation Plan

## Objective

Ship the approved fixes for country selection, hidden Native Speaker auth
entry, gift-minute localization, RevenueCat/TestFlight catalog reliability, and
privacy-safe password recovery.

## Stage 1 — Lock current behavior with tests

1. Add country catalog tests proving US is returned first and reused by the
   shared selector.
2. Add auth surface tests proving login/registration do not render the Native
   Speaker toggle and all new social/registration intent is student.
3. Expand loading-route tests for approved, pending, rejected, legacy-approved,
   and legacy-unapproved native accounts.
4. Add RU/EN expiry tests for today, tomorrow, date fallback, midnight, profile,
   dashboard, and promo success copy.

## Stage 2 — Small UI/data fixes

1. Add US to the reduced `countriesList()` return list without duplicating
   country data.
2. Remove the auth toggles and force student intent only on the paths that used
   them; keep existing email login routing unchanged.
3. Replace Russian-only expiry formatting with one locale-aware formatter and
   use it on profile, dashboard, and promo redemption.

## Stage 3 — RevenueCat lifecycle and catalog

1. Add an injectable RevenueCat SDK adapter around the static SDK calls.
2. Implement configure-once semantics, a pending/current Firebase uid, uid
   generation, and stale-result rejection for offerings and CustomerInfo.
3. Serialize login/logout/switch/purchase/restore through a commerce
   coordinator. Hold an identity lease throughout purchase/restore and reject
   overlapping commerce operations.
4. Cache and single-flight offering loads. Invalidate on uid change and expose
   typed catalog outcomes.
5. Match Roast behavior for initialization, eager offering/customer loading,
   explicit retry, localized StoreKit prices, purchase, and restore.
6. Keep direct StoreKit product lookup as fallback and diagnostic evidence.
7. Add race, mapping, timeout, busy, stale-result, purchase, restore, and UI
   state tests.
8. Harden the webhook to accept only the Expatlio app/entitlement/product
   allowlists and reject unsupported transfer projection.

## Stage 4 — Password recovery backend

1. Add `requestPasswordReset` callable:
   - App Check required, auth not required;
   - normalized `{email, locale}` input;
   - HMAC(email/IP) rate limits using dedicated secret;
   - neutral `{accepted: true}` response;
   - short-lived server-only queue document.
2. Add retry-enabled `processPasswordResetRequest` Firestore trigger:
   - lease/status/attempt/max-age state machine;
   - stable Resend idempotency key;
   - account lookup and canonical Firebase reset link only when account exists;
   - bounded retry classification;
   - immediate raw-email deletion after sent/discarded.
3. Extend the existing email module with localized reset email templates and a
   strict handler-link builder.
4. Export both functions and add deploy/readiness/secret checks.
5. Add Firestore deny rules, admin-fallback exclusion, TTL configuration, and
   emulator coverage.

## Stage 5 — Hosted reset handler and client

1. Extend `/auth/action` to preserve email verification and support
   `resetPassword` with `verifyPasswordResetCode` and
   `confirmPasswordReset`.
2. Add localized validation/success/error states and allowlisted deep link.
3. Replace the client Firebase-default call with `requestPasswordReset`, block
   duplicate submits, and show neutral localized confirmation only after the
   callable accepts the request.
4. Add backend, widget, and hosted-handler behavioral tests.

## Stage 6 — Validation and rollout

1. Run formatting, `git diff --check`, focused Dart/Node/emulator tests,
   `flutter analyze`, and full `flutter test`.
2. Run Firebase deployment and secret readiness.
3. Deploy rules/indexes/TTL, password-reset functions, and Hosting.
4. Push the client commit to GitHub `main` for the user's FlutterFlow Deploy
   from GitHub/TestFlight workflow.
5. Verify on TestFlight:
   - both non-empty StoreKit prices;
   - completed sandbox purchase;
   - active `Expatlio Pro` CustomerInfo;
   - RevenueCat transaction;
   - webhook projection and app unlock;
   - same-uid clean-install restore;
   - real reset email and completed password change.

## External release gate

If StoreKit still returns no products, inspect App Store Connect ownership for
`com.appwave.expatlio`, product localization/pricing, In-App Purchase
capability, Paid Apps Agreement/tax/banking, and RevenueCat App Store app/key
mapping. If products belong to the old app record, perform the approved
two-phase additive product-ID migration rather than attempting to reuse them.
