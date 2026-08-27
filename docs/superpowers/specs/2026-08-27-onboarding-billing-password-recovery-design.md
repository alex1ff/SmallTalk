# Onboarding, Billing, and Password Recovery Design

## Goal

Fix the current TestFlight blockers across onboarding, localization, billing,
and password recovery. Subscription price loading and sandbox purchases are the
highest priority. The RevenueCat client behavior should match the proven Roast
repository flow while retaining Expatlio's own products, entitlement, Firebase
webhook, and application identifiers.

## Confirmed scope

1. Add the United States to every user-facing country selection backed by the
   shared country catalog.
2. Remove the Native Speaker choice from login and registration. Existing
   native speakers must still enter their correct shell automatically from the
   role already stored in their user document.
3. Localize relative gift-minute deadlines, including `today`, `tomorrow`,
   `at`, and surrounding copy.
4. Make RevenueCat prices and sandbox purchasing available in TestFlight.
5. Repair password recovery end to end.

## Current findings

### Country catalog

`countriesList()` defines the United States correctly, but returns a reduced
six-country reference list containing only DE, ES, FR, IT, PT, and NL. All
onboarding, profile, settings, and location-filter selectors use this shared
function, so adding US to the returned popular catalog fixes those surfaces at
one source. Events already include `US:new_york` in the canonical city catalog;
its existing city identity must remain unchanged.

### Native Speaker entry

Login and registration both render `NativeSpeakerEntryToggle` and pass its
value into email/social-auth routing. The controls will be removed and all new
auth entry will use student intent. Existing accounts will continue through the
loading resolver, which derives their destination from persisted role and
teacher approval state rather than from the removed toggle.

### Gift-minute localization

`formatGiftExpiry()` always returns Russian relative words. The profile wraps
that Russian deadline in otherwise localized text, and the student dashboard
contains additional hard-coded Russian copy. Deadline formatting will accept a
locale/language code and produce complete RU or EN text without mixing
languages. The same formatter will be used by every gift-minute surface.

### RevenueCat

The public RevenueCat offerings endpoint for Expatlio currently returns:

- current offering: `subscriptions`;
- products/packages: `expatlio_1_Month` and `expatlio_3_Month`.

Therefore the RevenueCat catalog exists. The client receives no StoreKit
product metadata, which is why prices show as unavailable and purchase buttons
cannot start a sandbox transaction.

The Roast repository has a working lifecycle with these relevant properties:

- initialization is represented by one shared future;
- a Firebase uid received before configuration is retained and logged in after
  configuration;
- customer info and offerings load during initialization;
- the paywall can explicitly ensure offerings are loaded and retry;
- package identifiers are resolved directly from the active offering;
- purchase and restore update cached customer information.

Expatlio will match this behavior without copying Roast product identifiers or
backend state. It keeps:

- iOS RevenueCat public key `appl_uOxpqrnmkxvmCHhFmxJqQePzjRA`;
- offering `subscriptions`;
- products `expatlio_1_Month` and `expatlio_3_Month`;
- entitlement `Expatlio Pro`;
- RevenueCat webhook as the persistent entitlement authority.

The iOS bundle changed from `com.appwave.smalltalk` to
`com.appwave.expatlio` on 2026-08-11. Apple StoreKit requires the TestFlight
bundle ID, App Store Connect app record, In-App Purchase capability, and the
app owning the subscription products to match. This external configuration is
part of the release gate: code cannot manufacture StoreKit prices when Apple
returns no products.

## Design

### 1. Shared country source

Keep one canonical `countriesList()` source. Return US as the first popular
country, followed by the existing reference countries. Do not duplicate country
arrays in onboarding or settings. Add contract tests proving US is visible in
the shared selector and continues to resolve to the existing US event city.

### 2. Auth entry behavior

Remove `NativeSpeakerEntryToggle` from login and registration UI. Email and
social registration always pass `nativeSpeakerIntent: false`. Login also starts
with student intent; the authenticated loading resolver remains responsible for
restoring existing native-speaker accounts from persisted user state. Direct
profile-based teacher onboarding remains available to the existing approved
product path and is not deleted.

### 3. Localized deadlines

Introduce a locale-aware gift-expiry formatter that returns:

- RU: `сегодня в HH:MM`, `завтра в HH:MM`, `DD.MM в HH:MM`;
- EN: `today at HH:MM`, `tomorrow at HH:MM`, `DD.MM at HH:MM`.

Profile and dashboard copy will use `FFLocalizations` for the complete sentence.
Tests cover RU and EN with stable timestamps.

### 4. RevenueCat lifecycle parity with Roast

Refine `SubscriptionService` around a durable initialization state:

- preserve a pending Firebase uid until SDK configuration completes;
- expose `waitForInitialization()` / `ensureOfferingsLoaded()` equivalents;
- load customer info and offerings on startup;
- cache offerings and customer info;
- retry a failed initialization rather than permanently retaining a failed
  future;
- prefer the explicit `subscriptions` offering, then current/all offerings;
- keep a direct `getProducts()` fallback for StoreKit diagnostics;
- return structured catalog status to the paywall so the UI distinguishes
  configuration failure, empty StoreKit products, timeout, and network failure;
- retain StoreKit localized `priceString`; do not hard-code prices;
- keep purchase/restore through `SubscriptionService` and refresh customer info
  after success.

The paywall remains usable during retries and shows an actionable localized
message instead of only `Unavailable`. A purchase button is enabled only when a
real RevenueCat package or StoreKit product is available.

### 5. App Store / RevenueCat release gate

Before accepting the billing fix, verify in App Store Connect and RevenueCat:

- TestFlight binary bundle ID is `com.appwave.expatlio`;
- the App Store Connect app with that bundle owns both Expatlio product IDs;
- In-App Purchase capability is enabled for the explicit bundle identifier;
- product localization and price are complete;
- Paid Applications Agreement, tax, and banking are active;
- both products are attached to the Expatlio RevenueCat app, offering, and
  `Expatlio Pro` entitlement;
- a sandbox tester can open the Apple purchase sheet from TestFlight.

If the products were created under the old bundle's App Store app, code changes
are insufficient: equivalent subscriptions must be created for the current app
record and attached to the Expatlio RevenueCat app.

### 6. Password recovery

Use the already deployed Expatlio/Resend email infrastructure rather than the
opaque default Firebase template:

- add an unauthenticated callable that accepts a normalized email and locale;
- always return a neutral success response to prevent account enumeration;
- server-side Firebase Admin generates a password-reset link when the account
  exists;
- Resend delivers localized Expatlio HTML/text email;
- the hosted `/auth/action` handler accepts `mode=resetPassword`, verifies the
  OOB code, lets the user enter a new password twice, applies it through
  Firebase Auth, and offers a deep link back to the app;
- the client shows success only when the callable accepted the request and
  shows localized retryable failure otherwise.

Rate limiting, normalized input, metadata-only logs, and no email disclosure in
responses are required. Existing email-verification behavior remains intact.

## Error handling

- Country and localization changes have deterministic local fallbacks.
- RevenueCat errors are classified into configuration, network/timeout, empty
  offerings, and StoreKit-product absence. Logs include identifiers and SDK
  error codes but no secrets.
- Password recovery returns the same public response for existing and missing
  accounts. Provider failures are retryable and do not show a false success.
- Async UI work checks `mounted` and blocks duplicate submits/purchases.

## Validation

- Unit/widget tests for country visibility, auth surfaces, role restoration,
  localized deadline output, RevenueCat lifecycle/race behavior, price mapping,
  paywall states, password-reset callable, and hosted action handler contract.
- Node tests for email link generation, privacy, rate limits, and Resend errors.
- `flutter analyze`.
- Focused tests, then full `flutter test`.
- `node --check` and targeted backend tests.
- Firebase deployment-readiness validation.
- TestFlight sandbox purchase with a sandbox Apple account.
- Real password-reset email and completed password change on a disposable test
  account.

## Rollout

Deploy the password-recovery callable and hosted action page first. Push the
Flutter client to `main` for FlutterFlow/TestFlight build. Confirm StoreKit
prices and purchase sheet in TestFlight before broad testing. RevenueCat webhook
and entitlement state remain the source of truth after purchase.
