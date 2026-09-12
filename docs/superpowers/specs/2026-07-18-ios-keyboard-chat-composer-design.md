# iOS Keyboard Backdrop and Shared Chat Composer Design

Status: Approved by user for specification review  
Date: 2026-07-18  
Owner: Product + Engineering

## Summary

Remove the black wedges visible around the rounded top corners of the iOS
keyboard throughout the Flutter app. Replace the separate private-chat,
event-group-chat, and in-call-chat input implementations with one shared
composer inspired by iMessage while retaining the Expatlio purple brand color.

## Goals

- Ensure transparent areas around the rounded iOS keyboard reveal a light app
  surface instead of black pixels on every screen.
- Give every chat surface the same message composer.
- Use an iMessage-like capsule with an integrated circular send button.
- Keep the existing message send, optimistic update, retry, access-control, and
  error-reporting flows intact.
- Preserve the existing public widget keys used by tests and accessibility
  tooling.

## Non-goals

- Adding attachments or an iMessage-style plus button.
- Changing message bubbles, headers, routing, repositories, or backend APIs.
- Replacing Material widgets across the rest of the app with Cupertino widgets.
- Introducing dark mode as part of this change.
- Refactoring unrelated former FlutterFlow code.

## Current Context

- The app-level `MaterialApp.router` applies the Expatlio theme but does not
  explicitly paint a fallback surface behind its routed content.
- The iOS `UIWindow` has no explicit light background. Transparent regions
  exposed by the system keyboard can therefore fall through to black.
- The private chat implements its composer inline in
  `lib/shared_pages/chat_thread/chat_thread_widget.dart`.
- The event group chat has a separate `_EventGroupChatComposer` in
  `lib/shared_pages/events/event_group_chat_widget.dart`.
- The in-call chat builds another custom composer in
  `lib/custom_code/widgets/minimal_daily_widget.dart`.
- The composers currently use separate field and send-button implementations.
- Bottom safe-area padding is already removed while the keyboard is open via
  `ExpatlioDesign.bottomBarSafePadding(context)` and must remain single-counted.

## Chosen Approach

Use one shared Flutter composer and two complementary keyboard backdrop layers:

1. Paint a light app-level Flutter surface behind all routed content.
2. Set the native iOS window/root Flutter view background to the same light
   surface so system transparency cannot reveal the default black backing view.
3. Replace all three chat-specific composer layouts with the shared component.

This is preferred over duplicating the new styling in each chat because a
single component prevents geometry, disabled-state, and safe-area behavior from
drifting again. A fully Cupertino chat surface is not required and would broaden
the scope beyond the requested composer.

## Unit 1: App and iOS Keyboard Backdrop

### Responsibility

Provide an opaque light color underneath Flutter routes and the iOS keyboard
window's transparent rounded corners.

### Flutter Integration

The `MaterialApp.router.builder` in `lib/main.dart` will keep the existing text
scaling `MediaQuery` and place its child inside an opaque surface colored with
`ExpatlioDesign.background`.

The wrapper must:

- fill the available app view;
- remain behind the routed child rather than adding layout padding;
- preserve the existing `MediaQuery` data except for the current text-scaler
  override;
- not alter keyboard resize behavior or `viewInsets`.

### iOS Integration

`ios/Runner/AppDelegate.swift` will set the app window and Flutter root view
background to an opaque light color matching `ExpatlioDesign.background`
(`0xFFFAFAFA`). An idempotent helper applies the color after
`super.application(...didFinishLaunching...)`, repeats on the next main-queue
turn, and runs again from `applicationDidBecomeActive` so a temporarily missing
window or root view receives the fallback later in the lifecycle.

This native fallback is platform-scoped. Android and other platforms continue
to use their existing behavior.

### Edge Cases

- The background remains light before the first route frame is rendered.
- Opening and closing the keyboard does not add or remove layout space by
  itself; normal Flutter scaffold resize behavior remains authoritative.
- Screens with their own opaque background continue to cover the fallback.

## Unit 2: Shared `ChatComposer`

### Responsibility

Render and own only the message-entry UI. Message validation beyond an empty
trimmed draft, persistence, optimistic records, retries, and errors remain owned
by each chat screen.

### Location

Create `lib/components/chat_composer.dart`.

### Interface

The component accepts:

- `TextEditingController controller`
- `FocusNode focusNode`
- `VoidCallback onSendPressed`
- `String hintText`
- `String sendButtonSemanticLabel`
- `bool enabled` (true when the current user may edit and send)
- `bool isSending` (true while the parent has an active send request)
- optional `Key inputKey`
- optional `Key sendButtonKey`

The normal widget `key` identifies the composer root. `inputKey` and
`sendButtonKey` are forwarded to their descendant controls.

The component observes its controller so the send button updates immediately
when the draft changes without forcing either parent screen to own extra draft
state.

### Visual Specification

- Outer composer surface: `ExpatlioDesign.background`.
- Horizontal padding: 16 points.
- Vertical padding: 8 points next to an open keyboard, plus the existing bottom
  safe-area inset only when the keyboard is closed.
- Input capsule minimum height: 44 points.
- Input capsule maximum text growth: four visible lines.
- Capsule radius: 22 points.
- Capsule fill: white.
- Capsule border: 1 point using `ExpatlioDesign.separator`.
- Text: existing 16-point Expatlio form text style.
- Placeholder: existing localized “Написать сообщение” / “Write a message”.
- Send button: 36-point circle integrated at the trailing edge of the capsule.
- Active button: `ExpatlioDesign.primary` with a white upward arrow.
- Inactive button: neutral system fill with a muted upward arrow.
- Sending state: disabled send action with a compact progress indicator; the
  text field remains editable for the next draft.

The component has no attachment button because neither chat supports
attachments.

### Interaction

- The send action is enabled only when the trimmed draft is non-empty,
  `enabled` is true, and `isSending` is false.
- Tapping the active circle invokes `onSendPressed` once.
- The keyboard send action invokes the same guarded callback.
- While `isSending` is true, the user may edit the next draft but cannot start
  another send.
- Wrapped or pasted text grows the field from one to four lines; additional
  content scrolls within the field.
- Disabling the composer prevents editing and sending.
- Focus and the parent-owned controller survive parent rebuilds.

### Accessibility

- The parent supplies the localized “Отправить сообщение” / “Send message”
  semantic label. The send control is exposed as a button with this label and
  its current enabled state.
- The integrated button retains at least a 44-point semantic tap target even
  though the painted circle is 36 points.
- Existing input and send-button keys are forwarded unchanged from each chat.
- Text scaling must not clip the send control; the capsule may grow vertically
  within its four-line limit.

## Unit 3: Chat Integrations

### Private Chat

`ChatThreadWidget` replaces its inline bottom composer with `ChatComposer` and
passes:

- the existing message controller and focus node;
- the existing `chatThreadMessageInputKey` and
  `chatThreadSendButtonKey`;
- the localized hint and send semantic label;
- `enabled: !_chatActionsBlocked`;
- `isSending: _isSending`;
- the existing `_sendMessage(resolvedConversation)` callback.

The bottom gradient may remain to preserve message readability, but the shared
composer owns its own capsule geometry and bottom safe-area padding.

### Event Group Chat

`EventGroupChatWidget` replaces `_EventGroupChatComposer` with
`ChatComposer` and passes:

- the existing event message controller and focus node;
- `key: eventGroupChatComposerKey`, plus
  `eventGroupChatMessageInputKey` and `eventGroupChatSendButtonKey` for the
  descendants;
- the localized hint and send semantic label;
- `enabled: true` while the already-confirmed accessible chat content is
  mounted;
- `isSending` derived from the current chat scope's local send operation;
- the existing `_sendMessage` callback;
- a scope-keyed local in-flight token so duplicate taps are blocked until the
  active send request settles.

The optimistic message remains visible immediately. Existing success, failure,
snackbar, and retry behavior is unchanged.

The send token stores the authenticated owner, normalized event ID, and action
boundary revision. Existing owner/event boundary reset handling clears a token
that no longer belongs to the active scope. The request `finally` block clears
the token only when it is still the same operation. A stale completion therefore
cannot enable or disable the composer for a different chat.

### In-call Chat

`MinimalDailyWidget` replaces its custom dark composer with `ChatComposer` and
passes the existing controller, focus node, localized labels, participant and
connection availability, and `_sendChatMessage` callback. A local in-flight
flag blocks duplicate sends while leaving the next draft editable.

## Error Handling

- Empty or whitespace-only drafts never call a parent send callback.
- A failed private-chat send continues through the existing pending-message and
  retry behavior.
- A failed event-chat send continues to mark the optimistic message failed and
  show the existing localized snackbar.
- A failed in-call send retains its existing debug logging behavior.
- The event composer re-enables in `finally` only when its widget state is still
  mounted and the operation token is still the identical active operation.
- Changing owner, event, or action boundary clears the old send token before the
  new accessible content is rendered.
- Native backdrop setup is centralized in an idempotent AppDelegate helper. It
  runs immediately after `super.application(...didFinishLaunching...)`, once on
  the next main-queue turn, and from `applicationDidBecomeActive`. This covers a
  window or root view that was not available on the first attempt without
  blocking startup or navigation.

## Testing

### Shared Component Widget Tests

Add tests covering:

- 44-point minimum capsule height and 36-point painted send circle;
- inactive state for an empty or whitespace-only draft;
- active purple state after text entry;
- guarded single callback from both tap and keyboard submit;
- disabled and sending states;
- growth up to four lines without overflow;
- bottom safe area included when the keyboard is closed and omitted when open;
- preservation of forwarded keys and semantic button behavior.

### Integration Tests

Update chat integration and contract tests to verify:

- all three chat surfaces render the shared composer;
- existing keys still locate the input and send button;
- existing send and optimistic-message flows continue to pass;
- keyboard opening moves the composer by exactly the view inset without keeping
  the home-indicator padding;
- the event chat rejects duplicate taps while a send is in flight.

Add `test/platform/ios_keyboard_backdrop_contract_test.dart` as a small
source-level regression test for the opaque Flutter wrapper, the native
AppDelegate backdrop helper, and both lifecycle calls. This test verifies that
the intended integration remains declared; it cannot render the native iOS
keyboard.

The primary visual acceptance criterion requires a manual iOS smoke test on a
simulator or device:

1. Open a normal form screen, the private chat, the event group chat, and the
   in-call chat.
2. Show the light iOS keyboard on each screen.
3. Confirm both rounded top corners reveal the light app surface with no black
   wedges during keyboard opening, steady state, and dismissal.
4. In all three chats, verify empty, typed, wrapped four-line, and sending composer
   states.

### Validation Commands

- `flutter analyze`
- `flutter test test/components/chat_composer_test.dart`
- `flutter test test/shared_pages/chat_thread_widget_test.dart`
- `flutter test test/shared_pages/events/event_group_chat_widget_test.dart`
- `flutter test test/shared_pages/events/event_bottom_safe_area_contract_test.dart`
- `flutter test test/regression/voip_call_surface_contracts_test.dart`
- `flutter test test/platform/ios_keyboard_backdrop_contract_test.dart`
- manual iOS smoke test described above

## Acceptance Criteria

- No black pixels are visible through the rounded top corners of the iOS
  keyboard on app screens with text input, confirmed by the manual iOS smoke
  test.
- Private, event group, and in-call chats render the same iMessage-inspired
  composer.
- The send control is inside the input capsule and uses the Expatlio purple
  active color.
- Empty drafts cannot be sent, and in-flight sends cannot be duplicated.
- The field grows to four lines and then scrolls without layout overflow.
- Keyboard-open and keyboard-closed layouts consume the bottom safe area exactly
  once.
- Existing chat send, optimistic update, error, and retry tests remain green.
- `flutter analyze` reports no new issues.
