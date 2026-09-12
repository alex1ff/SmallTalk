# Silent Chat List Refresh

## Goal

Make reopening the Chats page feel immediate: render the latest session-cached chat list at once and refresh Firestore data silently, without the top refresh spinner shown in the supplied screenshot.

## Scope

- Apply the behavior to both Chats tabs: **All** and **Friends**.
- Keep the existing user-scoped in-memory state caches and Firestore streams.
- Do not add persistent storage, pull-to-refresh, skeleton rows, or change chat row layout.

## Display States

The **All** tab requires current-owner metadata (friends and known hidden-chat keys), conversations, and event chats. The **Friends** tab requires current-owner metadata and conversations; event chats do not affect this tab.

A result is **displayable** when it belongs to the current authenticated owner, hidden-chat keys are known, and either:

- the filtered tab contains at least one row; or
- every required source for that tab has produced a server-authoritative result during the current authenticated session, confirming that the filtered tab is empty.

After such an authoritative result is cached for the current owner, it remains displayable while a new stream subscription first emits cache-only data. A cache-only empty snapshot that has never been server-confirmed in the current authenticated session is not a displayable empty result.

### First load without cached data

- When the required sources for the selected tab have not produced a displayable result, show a centered loading indicator.
- Do not show an empty state until all required sources have produced a result.

### Reopen or background refresh with previous data

- Render cached rows, or a previously confirmed empty state, immediately.
- Continue listening to the existing Firestore sources and apply incoming changes normally.
- Do not display `UxRefreshingIndicatorOverlay` while these sources obtain a server-authoritative refresh.
- Preserve the current list and scrollable content while refresh is in progress.

### Errors

- If any required source fails and the tab has no displayable result, show the existing full error state and retry action.
- If any required source fails while rows or a previously confirmed empty state are displayable, preserve that content and show the existing inline retry message.
- Preserve current access-denied handling and user-bound cache isolation.

## State Decision Table

| Current-owner state | Required-source status | Result |
| --- | --- | --- |
| No cached rows or confirmed empty state | Still loading | Centered first-load indicator |
| Rows exist and hidden-chat keys are known | Loading or cache-only refresh | Rows immediately; no refresh pill |
| All required sources previously confirmed the filtered result empty | Loading or cache-only refresh | Empty state immediately; no refresh pill |
| No displayable result | Any required source fails | Full error state with retry |
| Rows or confirmed empty state are displayable | Any required source fails | Preserve content and show inline retry message |
| All required sources return a new authoritative result | Success | Replace/merge content through the existing reducers |
| Authenticated owner changes or signs out | Any | Immediately remove the previous owner's rows and confirmed-empty state |

## Implementation Boundaries

- `FavoriteWidget` owns the Chats-page display-state decision. Change its **All** and **Friends** tab builders so background refresh is silent and cold loading is explicit.
- Do not change the reusable `UxRefreshingIndicatorOverlay` component because other screens may intentionally use it.
- Do not change repository queries, merge reducers, session cache lifecycle, or authentication ownership guards.
- Never render rows or a confirmed-empty state cached for a different owner after logout or an authentication-owner change.

## Verification

- Add or update focused widget tests proving that cached chat content remains visible and no refresh pill is shown during a non-authoritative background refresh.
- Cover both **All** and **Friends** tabs.
- Verify that a first load without cached data shows a loading indicator and does not prematurely show the empty state.
- Preserve coverage for initial errors, background-refresh errors, authoritative empty states, and owner changes.
- Run `flutter analyze`.
- Run the relevant Flutter tests for `FavoriteWidget` and chat source state.
