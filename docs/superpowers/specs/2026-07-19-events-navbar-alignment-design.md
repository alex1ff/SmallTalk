# Events Navbar Alignment

## Goal

Make the Events destination visually and positionally consistent for teachers and students.

## Design

- Use `FFIcons.kcalendar` for Events in both role-specific navbar configurations.
- Keep Events as the second destination, immediately after Home, for both roles.
- Preserve the remaining student destinations in their existing relative order: Words, Chats, Profile.
- Update the student route-index mapping in `TabShellPage` and the tap handling in `NavBarWidget` so selection and navigation remain aligned with the new order.
- Do not change destination labels, colors, sizing, event routes, or teacher behavior.

## Resulting Order

- Teacher: Home, Events, Chats, Profile.
- Student: Home, Events, Words, Chats, Profile.

## Error Handling

No new runtime error paths are introduced. Existing route navigation and selected-tab handling remain in use.

## Verification

- Add or update focused widget/unit coverage for destination order, icon, and route-index mapping where practical.
- Run `flutter analyze`.
- Run relevant Flutter tests.
