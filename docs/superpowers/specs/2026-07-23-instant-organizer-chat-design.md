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

`openChatThread` will accept an optional restartable preparation callback:

```dart
typedef ChatConversationPreparation = Future<void> Function();
```

The existing locally derived `conversationRef` remains the only reference
passed to `ChatThreadWidget`. Navigation happens immediately. When preparation
is present, the pushed route displays a chat loading scaffold and invokes the
callback once. It constructs `ChatThreadWidget` only after that invocation
completes successfully.

The Firestore listener therefore cannot receive an initial
`permission-denied`, while the user still gets an immediate navigation
response.

The deferred route owns three explicit states:

- loading/retrying: progress indicator, no Firestore listener;
- error: localized generic “Could not open chat” message and retry button;
- ready: `ChatThreadWidget` with the locally derived reference.

Retry calls the same preparation callback again. Only one invocation may run at
a time; the retry button is disabled while retrying.

### Event detail integration

The organizer-message handler will:

1. Compute the canonical organizer conversation reference from the current user
   ID and event organizer ID.
2. Build a restartable preparation callback around
   `openEventOrganizerChat(eventId)`.
3. Push the chat route immediately with the local reference and callback.
4. For every callback result, require both `conversationId` to equal the local
   reference ID and `conversationPath` to equal its path. A mismatch throws a
   `StateError` handled by the deferred route as a generic open failure.
5. Let the deferred route start `ChatThreadWidget` with the local reference only
   after validation
   succeeds.

No participant document or event membership is consulted.

### Failure behavior

If preparation or response validation fails, the deferred route shows its own
localized generic error instead of exposing raw callable errors. Event-specific
error mapping remains on the event page only for failures that occur before
navigation.

Retry invokes `openEventOrganizerChat` again through the restartable callback
and does not create another navigation route. The loading/error/retrying UI has
stable keys and semantics for widget tests.

### Lifecycle

The deferred route tracks its active attempt with a generation token. Completion
after route disposal is ignored. Popping the route does not cancel the callable,
but it cannot start a listener, navigate, or call `setState` afterward.
Repeated retry taps cannot start concurrent attempts. Disposing the original
event-detail widget is harmless because the preparation callback contains only
immutable IDs and repository calls; it does not use the event page context.

The immediate route uses the same background and safe-area behavior as the chat
screen. While preparing, it shows only the centered progress state; after an
error it shows the localized message and retry action.

### Test seam

`EventChatThreadOpener` gains an optional named
`ChatConversationPreparation? preparation` parameter. Production passes it to
`openChatThread`; injected tests can capture and invoke it independently.

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
- Repeated retry taps do not run concurrent preparations.
- Completion after the deferred route is popped has no effect.
- Mismatched `conversationId` or `conversationPath` never reaches
  `ChatThreadWidget`.
- The updated `EventChatThreadOpener` seam forwards the restartable callback.
- Existing event-list and event-detail chat tests continue to pass.
- `flutter analyze` reports no issues.
