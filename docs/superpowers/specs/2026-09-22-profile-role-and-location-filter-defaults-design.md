# Profile role controls and location filter defaults

## Goal

Remove role switching from the profile UI while keeping teacher data, teacher flows, and database-controlled role changes intact. Make the home search and Events location filters start from the location selected during onboarding, then remember later choices independently on the current device.

## Profile role controls

The profile page must not show either “Стать учителем / Become a teacher” or “Стать учеником / Become a student”. This applies to every profile layout that currently renders a role-switch action.

Only the UI entry points are removed. The user role field, teacher accreditation state, teacher screens, routing for users whose role is changed in the database, and existing teacher-domain services remain unchanged. No database migration is required.

## Local filter state

The home search and Events page use separate local settings. Every key is scoped by the authenticated user ID so different accounts on one device do not share filter choices.

Each filter stores an explicit state rather than treating a missing value as “Любая”. The state distinguishes:

- not initialized;
- a selected supported location;
- “Любая” for the home search filter.

Events does not currently offer “Любая”, so its stored state only needs uninitialized and selected-location states. An Events selection also stores its selection source (`profile`, `recent`, `static`, or `manual`) so restored analytics keep the same meaning after an app restart.

Shared preferences are the storage boundary. A small service owns key construction, serialization, validation, and reads/writes. UI widgets consume resolved filter values and do not construct storage keys themselves.

## Initial values and later changes

Initialization starts only after authentication and the current user's Firestore document have both loaded. A temporary `null` document is not treated as a missing `profileCity` and must never cause “Любая” to be persisted.

When a filter has no stored state for the current user, it resolves the supported location from `users.profileCity`, which is populated during onboarding.

- Home search uses that location as its initial partner-search filter.
- Events uses that location as its initial event-city filter.

The derived initial value is persisted immediately, making initialization one-time. After initialization:

- changing the home search location updates only the home search setting;
- choosing “Любая” stores an explicit any-location state;
- changing the Events city updates only the Events setting;
- reopening the app restores each filter independently.

Changing `profileCity` later does not overwrite an initialized filter. This preserves the requirement that the onboarding location is only the default and later choices belong to the user.

Both screens remain in a lightweight loading state until their local filter initialization finishes. Partner queries, search requests, and Events card loading do not start with an unresolved filter.

If the authenticated user changes while either widget is mounted, the widget clears its resolved filter state and starts initialization for the new user ID. Every asynchronous read captures both the user ID and an initialization generation; a result is applied only when both still match. Late reads from a previous account or an older initialization are discarded.

## Invalid and missing data

Stored locations are validated against the supported-location catalog before use. Home search validates its stored and profile locations through the shared supported-location resolver.

Events validates a stored local city against the current Events catalog. Its `profileCity` fallback uses the existing Events profile resolver, including catalog-version and `countryNS` consistency checks. This preserves the current outdated-profile and inconsistent-location behavior instead of silently accepting a partially valid profile.

If a stored selected location is no longer supported, the filter tries its valid current-profile fallback and replaces the invalid local value. If neither value is valid:

- home search resolves to “Любая” and stores that explicit state;
- Events shows its existing location-selection prompt.

An explicit home-search “Любая” choice is never replaced by `profileCity`.

Storage read or write failures must not permanently block either screen. Reads fall back to the filter's valid current-profile resolution without marking the filter initialized on disk. Writes are best-effort and the in-memory selection remains usable for the current session.

## Integration

The home dashboard must use the locally resolved location everywhere the current `preferences.preferredLocation` value drives UI labels, partner counts, previews, and search requests. It must stop writing filter changes to the user document.

The Events page must resolve its initial city asynchronously from local storage before loading event cards. Existing date and level filters, temporary city-selection UI, pagination, and event actions stay unchanged. A locally restored or initialized registration city is treated as a profile-derived default. Later selections persist their current source, and restoring them keeps that source for analytics.

## Verification

Meaningful checks cover:

- first use defaults both filters from `profileCity`;
- the two filters retain different cities after restart;
- home search retains an explicit “Любая” choice;
- stored settings do not leak between user IDs;
- a late local read cannot overwrite the state of a newly signed-in user;
- an invalid stored location follows the fallback rules;
- filters do not start data requests before initialization completes;
- neither profile layout exposes a role-switch action;
- `flutter analyze` passes.
