# Silent Chat List Refresh

## Goal

Make reopening the Chats page feel immediate: render the latest session-cached chat list at once and refresh Firestore data silently, without the top refresh spinner shown in the supplied screenshot.

## Scope

- Apply the behavior to both Chats tabs: **All** and **Friends**.
- Keep the existing user-scoped in-memory state caches and Firestore streams.
- Do not add persistent storage, pull-to-refresh, skeleton rows, or change chat row layout.

## Display States

### First load without cached data

- When the required sources have not produced a displayable result and no cached rows or authoritative empty state exist, show a centered loading indicator.
- Do not show an empty state until all required sources have produced a result.

### Reopen or background refresh with previous data

- Render cached rows, or a previously confirmed empty state, immediately.
- Continue listening to the existing Firestore sources and apply incoming changes normally.
- Do not display `UxRefreshingIndicatorOverlay` while these sources obtain a server-authoritative refresh.
- Preserve the current list and scrollable content while refresh is in progress.

### Errors

- If the initial load fails with no displayable data, keep the existing full error state and retry action.
- If a background refresh fails while previous data is visible, keep the visible list and existing unobtrusive retry message.
- Preserve current access-denied handling and user-bound cache isolation.

## Implementation Boundaries

- `FavoriteWidget` owns the Chats-page display-state decision. Change its **All** and **Friends** tab builders so background refresh is silent and cold loading is explicit.
- Do not change the reusable `UxRefreshingIndicatorOverlay` component because other screens may intentionally use it.
- Do not change repository queries, merge reducers, session cache lifecycle, or authentication ownership guards.

## Verification

- Add or update focused widget tests proving that cached chat content remains visible and no refresh pill is shown during a non-authoritative background refresh.
- Cover both **All** and **Friends** tabs.
- Verify that a first load without cached data shows a loading indicator and does not prematurely show the empty state.
- Preserve coverage for initial errors, background-refresh errors, authoritative empty states, and owner changes.
- Run `flutter analyze`.
- Run the relevant Flutter tests for `FavoriteWidget` and chat source state.

