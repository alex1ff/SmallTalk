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

Login and registration both render `NativeSpeakerEntryToggle`. On login the
toggle affects social auth only; email login already goes directly through the
authenticated loading resolver. On registration it affects both email and
social entry. The controls will be removed and every new registration/social
entry will use student intent. Existing accounts will continue through the
loading resolver, which derives their destination from persisted role and
teacher approval state rather than from the removed toggle.

### Gift-minute localization

`formatGiftExpiry()` always returns Russian relative words. The profile wraps
that Russian deadline in otherwise localized text, and the student dashboard
contains additional hard-coded Russian copy. `PromoRedeemWidget` also owns a
second formatter that always inserts Russian `в`. Deadline formatting will
accept a locale/language code and produce complete RU or EN text without mixing
languages. The same formatter will be used by profile, student dashboard, promo
success, and any other gift-minute surface.

### RevenueCat

The public RevenueCat offerings endpoint for Expatlio currently returns:

- current offering: `subscriptions`;
- products/packages: `expatlio_1_Month` and `expatlio_3_Month`.

Therefore the RevenueCat catalog exists. The client receives no StoreKit
product metadata, which is why prices show as unavailable and purchase buttons
cannot start a sandbox transaction.

The Roast repository has a working lifecycle with these relevant properties:

- SDK configuration is represented by one shared future and occurs once;
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
social registration always pass `nativeSpeakerIntent: false`; social login does
the same. Email login keeps its existing path unchanged and goes directly to
the authenticated loading resolver. The resolver remains responsible for
restoring existing native-speaker accounts from persisted user state. Direct
profile-based teacher onboarding remains available to the existing approved
product path and is not deleted. Tests cover approved and unapproved existing
native speakers signing in with email and social providers.

### 3. Localized deadlines

Introduce a locale-aware gift-expiry formatter that returns:

- RU: `сегодня в HH:MM`, `завтра в HH:MM`, `DD.MM в HH:MM`;
- EN: `today at HH:MM`, `tomorrow at HH:MM`, `DD.MM at HH:MM`.

Profile, dashboard, and promo redemption copy will use `FFLocalizations` and the
shared formatter for the complete sentence. Tests cover RU and EN, same-day and
next-day boundaries, midnight, and ensure `now` and expiry are compared in the
same local timezone.

### 4. RevenueCat lifecycle parity with Roast

Refine `SubscriptionService` around a durable initialization and identity
state, behind an injectable SDK adapter for deterministic tests:

- call `Purchases.configure` at most once, guard with `Purchases.isConfigured`,
  and register the customer-info listener at most once;
- preserve a pending Firebase uid until SDK configuration completes and
  serialize later login/logout/user-switch operations;
- expose an identity-ready future and require purchase/restore to wait until
  `Purchases.appUserID` equals the current Firebase uid; never purchase as an
  anonymous RevenueCat user because the webhook intentionally rejects
  `$RCAnonymousID`;
- expose `waitForInitialization()` / `ensureOfferingsLoaded()` equivalents;
- load customer info and offerings on startup;
- cache offerings and customer info;
- separate one-time SDK configuration from independently retryable customer
  info and offering loads;
- prefer the explicit `subscriptions` offering, then current/all offerings;
- keep a direct `getProducts()` fallback for StoreKit diagnostics;
- return structured catalog status to the paywall so the UI distinguishes
  configuration failure, empty StoreKit products, timeout, and network failure;
- retain StoreKit localized `priceString`; do not hard-code prices;
- keep purchase/restore through `SubscriptionService` and refresh customer info
  after success.

Race tests cover uid arrival before, during, and after configuration, duplicate
configure calls, logout, switching Firebase uid, and purchase/restore attempted
before identity synchronization.

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
- TestFlight returns a non-empty StoreKit `priceString` for each product (the
  exact sandbox currency/value is not an acceptance condition);
- a sandbox tester completes a purchase through the Apple purchase sheet;
- RevenueCat `CustomerInfo` contains active `Expatlio Pro`;
- the transaction appears for the Firebase uid in RevenueCat;
- `revenueCatWebhook` updates `users/{uid}.subscription`;
- the application unlocks the paid entitlement from the persisted state.

If the products were created under the old bundle's App Store app, code changes
are insufficient: equivalent subscriptions must be created for the current app
record and attached to the Expatlio RevenueCat app.

### 6. Password recovery

Use the already deployed Expatlio/Resend email infrastructure rather than the
opaque default Firebase template. Delivery is asynchronous so account
existence and Resend success cannot be inferred from the callable response:

- add App-Check-enforced callable `requestPasswordReset` with payload
  `{email, locale}` and response `{accepted: true}`;
- normalize and validate the email, then always return the same accepted shape
  for existing and missing accounts;
- enqueue a short-lived server-only `passwordResetRequests/{requestId}` record;
- add Firestore trigger `processPasswordResetRequest` that looks up the account,
  asks Firebase Admin for the password-reset link when it exists, and sends the
  localized Expatlio HTML/text email through Resend;
- rate-limit the callable by HMAC(email) and HMAC(client IP), never raw email/IP,
  with server-secret key material, bounded windows, and TTL cleanup;
- keep the queued raw email only in the locked server-only request document for
  the minimum processing TTL; never log email, reset link, OOB code, IP, or
  request payload;
- retry transient provider delivery in the background with bounded attempts;
- the hosted `/auth/action` handler accepts `mode=resetPassword`, verifies the
  OOB code with `verifyPasswordResetCode`, lets the user enter a new password
  twice, and applies it with `confirmPasswordReset`;
- localize the handler from allowlisted `lang=ru|en`, preserve existing
  `verifyEmail`, allowlist the Expatlio deep-link continuation target, and render
  explicit mismatch, weak-password, invalid-code, expired-code, success, and
  retry states;
- the client shows the same localized “if this account exists, check your
  email” confirmation for every accepted request. Synchronous network/App Check
  failure remains retryable but does not claim that email delivery failed for a
  particular account.

Both functions are exported from `index.js`, added to the scoped deploy script
and deployment-readiness `REQUIRED_FUNCTIONS`; `RESEND_API_KEY` remains bound
only to the processing trigger. The rollout explicitly deploys Firebase Hosting
because the current function deploy script does not publish `/auth/action`.

## Error handling

- Country and localization changes have deterministic local fallbacks.
- RevenueCat errors are classified into configuration, network/timeout, empty
  offerings, and StoreKit-product absence. Logs include identifiers and SDK
  error codes but no secrets.
- Password recovery returns the same public response and comparable callable
  timing for existing and missing accounts. Provider failures are handled by
  the background processor and cannot reveal account existence.
- Async UI work checks `mounted` and blocks duplicate submits/purchases.

## Validation

- Unit/widget tests for country visibility, auth surfaces, role restoration,
  localized deadline output, RevenueCat lifecycle/race behavior, price mapping,
  paywall states, password-reset callable, and hosted action handler contract.
- Node tests for queueing, HMAC rate limits, privacy, link generation, trigger
  retries, Resend errors, index exports, deploy targets, and TTL fields.
- Firebase Auth/Firestore emulator tests plus behavioral browser tests for both
  `verifyEmail` and `resetPassword`; source-regex checks alone are insufficient.
- `flutter analyze`.
- Focused tests, then full `flutter test`.
- `node --check` and targeted backend tests.
- Firebase deployment-readiness validation.
- Completed TestFlight sandbox purchase, active RevenueCat entitlement,
  RevenueCat transaction, webhook projection, and in-app unlock.
- Real password-reset email and completed password change on a disposable test
  account.

## Rollout

Deploy `requestPasswordReset`, `processPasswordResetRequest`, their Firestore
rules/index support, and Firebase Hosting `/auth/action` first. Push the Flutter
client to `main` for FlutterFlow/TestFlight build. Confirm non-empty StoreKit
prices and the full purchase → entitlement → webhook → unlock chain in
TestFlight before broad testing. RevenueCat webhook and entitlement state remain
the source of truth after purchase.
