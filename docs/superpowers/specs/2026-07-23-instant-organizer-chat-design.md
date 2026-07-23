# Instant Organizer Chat Design

## Goal

Open the organizer chat screen immediately after the user taps “Message”, while
creating or unlocking the direct conversation in the background. Event
membership must not be required.

## Constraints

- Keep Firestore conversation isolation: only the two conversation participants
  may read the conversation and its messages.
- Do not start the Firestore conversation listener before the trusted callable
  has created or unlocked the conversation.
- Do not create conversations merely because an event detail page was viewed.
- Preserve the existing `openEventOrganizerChat` validation for authentication,
  active events, organizer identity, and canonical participant data.

## Design

### Deferred chat opening

`openChatThread` will accept an optional preparation future. Navigation happens
immediately. When preparation is present, the pushed route displays the normal
chat loading state and waits for preparation before constructing the
`ChatThreadWidget`.

The Firestore listener therefore cannot receive an initial
`permission-denied`, while the user still gets an immediate navigation
response.

### Event detail integration

The organizer-message handler will:

1. Start `openEventOrganizerChat`.
2. Compute the canonical organizer conversation reference.
3. Push the chat route immediately with a preparation future.
4. Validate that the callable returned the expected conversation path.
5. Let the deferred route start `ChatThreadWidget` only after validation
   succeeds.

No participant document or event membership is consulted.

### Failure behavior

If preparation fails, the deferred route shows a localized retryable chat-load
error. Retry invokes `openEventOrganizerChat` again and does not create another
navigation route.

### Security boundary

The client button is a UX control, not an authorization boundary. Firestore
rules and the callable continue preventing access to conversations belonging to
other users. The change removes visible waiting and the race, not conversation
isolation.

## Tests

- Tapping “Message” pushes the chat route before the callable completes.
- The conversation stream is not created while preparation is pending.
- Successful preparation starts the chat with the canonical conversation.
- Failed preparation shows an error and retry can recover.
- Existing event-list and event-detail chat tests continue to pass.
- `flutter analyze` reports no issues.
