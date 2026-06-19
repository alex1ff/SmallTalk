import 'dart:async';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/events/event_group_chat_widget.dart';
import 'package:small_talk/services/event_actions_repository.dart';
import 'package:small_talk/services/event_group_chat_repository.dart';

const _supportedLocales = [
  Locale('ru'),
  Locale('en'),
];

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  FFLocalizationsDelegate(),
  FallbackMaterialLocalizationDelegate(),
  FallbackCupertinoLocalizationDelegate(),
];

Widget _buildTestApp({required Widget home}) {
  return MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: _supportedLocales,
    localizationsDelegates: _localizationsDelegates,
    home: home,
  );
}

EventChatMetadataStream _allowedChatStream({String eventId = 'event-123'}) =>
    (chatRef) => Stream<EventChatsRecord?>.value(
          _chatFixture(chatRef: chatRef, eventId: eventId),
        );

EventCallableInvoker _accessStateInvoker({
  String eventId = 'event-123',
  String status = 'active',
  bool readOnly = false,
}) =>
    (functionName, payload) async {
      expect(functionName, getEventChatAccessStateFunctionName);
      expect(payload, <String, dynamic>{'eventId': eventId});
      return <String, dynamic>{
        'eventId': eventId,
        'status': status,
        'readOnly': readOnly,
      };
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    setupFirebaseCoreMocks();
    await FFLocalizations.initialize();
    await Firebase.initializeApp();
  });

  testWidgets('shows loading while event chat messages stream is pending',
      (tester) async {
    final completer = Completer<List<EventChatMessagesRecord>>();
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete(const <EventChatMessagesRecord>[]);
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) => completer.future.asStream(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(eventGroupChatAccessLoadingKey), findsOneWidget);

    for (var attempt = 0;
        attempt < 5 &&
            find.byKey(eventGroupChatMessagesLoadingKey).evaluate().isEmpty;
        attempt += 1) {
      await tester.pump();
    }

    expect(find.byKey(eventGroupChatMessagesLoadingKey), findsOneWidget);
    expect(find.text('Чат события'), findsOneWidget);

    completer.complete(const <EventChatMessagesRecord>[]);
    await tester.pump();
  });

  testWidgets('shows empty state when event chat has no messages',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsOneWidget);
    expect(find.byKey(eventGroupChatCanceledReadOnlyBannerKey), findsNothing);
    expect(find.text('Сообщений пока нет'), findsOneWidget);
  });

  testWidgets('blocks chat content when access metadata is denied',
      (tester) async {
    var messageStreamCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: (_) => Stream<EventChatsRecord?>.error(
            StateError('permission-denied'),
          ),
          messagesStream: (_) {
            messageStreamCalls += 1;
            return Stream.value(const <EventChatMessagesRecord>[]);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(eventGroupChatAccessDeniedKey), findsOneWidget);
    expect(find.text('Сначала присоединитесь к событию'), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageInputKey), findsNothing);
    expect(find.byKey(eventGroupChatSendButtonKey), findsNothing);
    expect(find.byKey(eventGroupChatMessagesListKey), findsNothing);
    expect(messageStreamCalls, 0);
  });

  testWidgets('blocks chat content when access metadata is missing',
      (tester) async {
    var messageStreamCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: (_) => Stream<EventChatsRecord?>.value(null),
          messagesStream: (_) {
            messageStreamCalls += 1;
            return Stream.value(const <EventChatMessagesRecord>[]);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatAccessDeniedKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageInputKey), findsNothing);
    expect(messageStreamCalls, 0);
  });

  testWidgets('blocks chat content when trusted access state is denied',
      (tester) async {
    var messageStreamCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: (_, __) async {
            throw StateError('permission-denied');
          },
          messagesStream: (_) {
            messageStreamCalls += 1;
            return Stream.value(const <EventChatMessagesRecord>[]);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatAccessDeniedKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageInputKey), findsNothing);
    expect(messageStreamCalls, 0);
  });

  testWidgets('retries trusted access state after a rebuild', (tester) async {
    var accessCalls = 0;
    var messageStreamCalls = 0;
    final chatStream = _allowedChatStream();
    Future<Object?> accessStateInvoker(
      String functionName,
      Map<String, dynamic> payload,
    ) async {
      accessCalls += 1;
      if (accessCalls == 1) {
        throw StateError('temporary network error');
      }
      expect(functionName, getEventChatAccessStateFunctionName);
      expect(payload, <String, dynamic>{'eventId': 'event-123'});
      return <String, dynamic>{
        'eventId': 'event-123',
        'status': 'active',
        'readOnly': false,
      };
    }

    Widget buildSubject() => _buildTestApp(
          home: EventGroupChatWidget(
            eventId: 'event-123',
            chatStream: chatStream,
            accessStateInvoker: accessStateInvoker,
            messagesStream: (_) {
              messageStreamCalls += 1;
              return Stream.value(const <EventChatMessagesRecord>[]);
            },
          ),
        );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatAccessDeniedKey), findsOneWidget);
    expect(messageStreamCalls, 0);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(accessCalls, 2);
    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageInputKey), findsOneWidget);
    expect(messageStreamCalls, 1);
  });

  testWidgets('does not reuse allowed access after event changes',
      (tester) async {
    var deniedEventMessageStreamCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-1',
          chatStream: _allowedChatStream(eventId: 'event-1'),
          accessStateInvoker: _accessStateInvoker(eventId: 'event-1'),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatMessageInputKey), findsOneWidget);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-2',
          chatStream: (_) => Stream<EventChatsRecord?>.value(null),
          messagesStream: (_) {
            deniedEventMessageStreamCalls += 1;
            return Stream.value(const <EventChatMessagesRecord>[]);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(eventGroupChatAccessDeniedKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageInputKey), findsNothing);
    expect(deniedEventMessageStreamCalls, 0);
  });

  testWidgets('loads event chat messages from event chat document',
      (tester) async {
    final chatRef = EventChatsRecord.collection.doc('event-123');
    final message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-1',
      text: 'Всем привет!',
    );
    String? requestedChatPath;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: ' event-123 ',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (requestedChatRef) {
            requestedChatPath = requestedChatRef.path;
            return Stream.value(<EventChatMessagesRecord>[message]);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedChatPath, 'eventChats/event-123');
    expect(find.byKey(eventGroupChatMessagesListKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageBubbleKey('message-1')),
        findsOneWidget);
    expect(find.text('Всем привет!'), findsOneWidget);
  });

  testWidgets('renders chronological repository messages with newest at bottom',
      (tester) async {
    final chatRef = EventChatsRecord.collection.doc('event-123');
    final sameTimestamp = DateTime.parse('2026-06-14T10:00:00Z');
    final olderTimestamp = DateTime.parse('2026-06-14T09:59:00Z');
    final newestTieMessage = _messageFixture(
      chatRef: chatRef,
      messageId: 'same-time-b',
      text: 'Same timestamp B',
      createdAt: sameTimestamp,
    );
    final olderTieMessage = _messageFixture(
      chatRef: chatRef,
      messageId: 'same-time-a',
      text: 'Same timestamp A',
      createdAt: sameTimestamp,
    );
    final olderMessage = _messageFixture(
      chatRef: chatRef,
      messageId: 'older-message',
      text: 'Older message',
      createdAt: olderTimestamp,
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
            olderMessage,
            olderTieMessage,
            newestTieMessage,
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final olderTop = tester
        .getTopLeft(find.byKey(eventGroupChatMessageBubbleKey('older-message')))
        .dy;
    final sameATop = tester
        .getTopLeft(find.byKey(eventGroupChatMessageBubbleKey('same-time-a')))
        .dy;
    final sameBTop = tester
        .getTopLeft(find.byKey(eventGroupChatMessageBubbleKey('same-time-b')))
        .dy;

    expect(olderTop, lessThan(sameATop));
    expect(sameATop, lessThan(sameBTop));
    expect(find.text('Older message'), findsOneWidget);
    expect(find.text('Same timestamp A'), findsOneWidget);
    expect(find.text('Same timestamp B'), findsOneWidget);
  });

  testWidgets('shows canceled event chat as read-only for eligible readers',
      (tester) async {
    final chatRef = EventChatsRecord.collection.doc('event-123');
    final message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-1',
      text: 'До встречи!',
    );
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(
            status: 'canceled',
            readOnly: true,
          ),
          messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
            message,
          ]),
          sendMessageInvoker: (_, __) async {
            sendCalls += 1;
            return <String, dynamic>{
              'messageId': 'message-2',
              'createdAt': '2026-06-14T12:00:00.000Z',
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('До встречи!'), findsOneWidget);
    expect(find.byKey(eventGroupChatCanceledReadOnlyBannerKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(eventGroupChatCanceledReadOnlyBannerKey),
        matching: find.text('Событие отменено'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(eventGroupChatCanceledReadOnlyBannerKey),
        matching: find.text('Чат доступен только для чтения.'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(eventGroupChatMessageInputKey), findsNothing);
    expect(find.byKey(eventGroupChatSendButtonKey), findsNothing);
    expect(sendCalls, 0);
  });

  testWidgets('does not use stale writable state while cancel state loads',
      (tester) async {
    final chatController = StreamController<EventChatsRecord?>();
    final activeAccess = Completer<Object?>();
    final canceledAccess = Completer<Object?>();
    var accessCalls = 0;
    var sendCalls = 0;
    addTearDown(chatController.close);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: (chatRef) => chatController.stream,
          accessStateInvoker: (functionName, payload) async {
            accessCalls += 1;
            expect(functionName, getEventChatAccessStateFunctionName);
            expect(payload, <String, dynamic>{'eventId': 'event-123'});
            if (accessCalls == 1) {
              return activeAccess.future;
            }
            return canceledAccess.future;
          },
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          sendMessageInvoker: (_, __) async {
            sendCalls += 1;
            return <String, dynamic>{
              'messageId': 'message-1',
              'createdAt': '2026-06-14T12:00:00.000Z',
            };
          },
        ),
      ),
    );

    chatController.add(
      _chatFixture(
        chatRef: EventChatsRecord.collection.doc('event-123'),
        eventId: 'event-123',
      ),
    );
    await tester.pump();
    activeAccess.complete(<String, dynamic>{
      'eventId': 'event-123',
      'status': 'active',
      'readOnly': false,
    });
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatMessageInputKey), findsOneWidget);

    chatController.add(
      _chatFixture(
        chatRef: EventChatsRecord.collection.doc('event-123'),
        eventId: 'event-123',
        updatedAt: DateTime.parse('2026-06-14T10:01:00Z'),
      ),
    );
    for (var attempt = 0; attempt < 5 && accessCalls < 2; attempt += 1) {
      await tester.pump();
    }

    expect(accessCalls, 2);
    expect(find.byKey(eventGroupChatAccessLoadingKey), findsOneWidget);
    expect(find.byKey(eventGroupChatCanceledReadOnlyBannerKey), findsNothing);
    expect(find.byKey(eventGroupChatMessageInputKey), findsNothing);

    canceledAccess.complete(<String, dynamic>{
      'eventId': 'event-123',
      'status': 'canceled',
      'readOnly': true,
    });
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatCanceledReadOnlyBannerKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageInputKey), findsNothing);
    expect(find.byKey(eventGroupChatSendButtonKey), findsNothing);
    expect(sendCalls, 0);
  });

  testWidgets('ignores stale writable access result after cancel metadata',
      (tester) async {
    final chatController = StreamController<EventChatsRecord?>();
    final activeAccess = Completer<Object?>();
    final canceledAccess = Completer<Object?>();
    var accessCalls = 0;
    addTearDown(chatController.close);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: (_) => chatController.stream,
          accessStateInvoker: (functionName, payload) async {
            accessCalls += 1;
            expect(functionName, getEventChatAccessStateFunctionName);
            expect(payload, <String, dynamic>{'eventId': 'event-123'});
            if (accessCalls == 1) {
              return activeAccess.future;
            }
            return canceledAccess.future;
          },
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
        ),
      ),
    );

    chatController.add(
      _chatFixture(
        chatRef: EventChatsRecord.collection.doc('event-123'),
        eventId: 'event-123',
      ),
    );
    for (var attempt = 0; attempt < 5 && accessCalls < 1; attempt += 1) {
      await tester.pump();
    }

    expect(accessCalls, 1);
    expect(find.byKey(eventGroupChatAccessLoadingKey), findsOneWidget);

    chatController.add(
      _chatFixture(
        chatRef: EventChatsRecord.collection.doc('event-123'),
        eventId: 'event-123',
        updatedAt: DateTime.parse('2026-06-14T10:01:00Z'),
      ),
    );
    for (var attempt = 0; attempt < 5 && accessCalls < 2; attempt += 1) {
      await tester.pump();
    }

    expect(accessCalls, 2);
    activeAccess.complete(<String, dynamic>{
      'eventId': 'event-123',
      'status': 'active',
      'readOnly': false,
    });
    await tester.pump();

    expect(find.byKey(eventGroupChatAccessLoadingKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageInputKey), findsNothing);

    canceledAccess.complete(<String, dynamic>{
      'eventId': 'event-123',
      'status': 'canceled',
      'readOnly': true,
    });
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatCanceledReadOnlyBannerKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageInputKey), findsNothing);
    expect(find.byKey(eventGroupChatSendButtonKey), findsNothing);
  });

  testWidgets('shows sender name and avatar fallback for event chat messages',
      (tester) async {
    final chatRef = EventChatsRecord.collection.doc('event-123');
    final message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-1',
      text: 'Всем привет!',
      senderDisplayName: 'Марко Росси',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
            message,
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatMessageBubbleKey('message-1')),
        findsOneWidget);
    expect(find.byKey(eventGroupChatMessageSenderNameKey('message-1')),
        findsOneWidget);
    expect(find.text('Марко Росси'), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageSenderAvatarKey('message-1')),
        findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(eventGroupChatMessageSenderAvatarKey('message-1')),
        matching: find.text('МР'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('falls back when sender name is blank and photo fails',
      (tester) async {
    final chatRef = EventChatsRecord.collection.doc('event-123');
    final message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-1',
      text: 'Привет',
      senderDisplayName: '   ',
      senderPhotoUrl: 'https://invalid.example/avatar.png',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
            message,
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatMessageSenderNameKey('message-1')),
        findsOneWidget);
    expect(find.text('Участник'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(eventGroupChatMessageSenderAvatarKey('message-1')),
        matching: find.text('УЧ'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses sender photo url for event chat avatar', (tester) async {
    final chatRef = EventChatsRecord.collection.doc('event-123');
    final message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-1',
      text: 'Привет',
      senderDisplayName: 'Marco',
      senderPhotoUrl: 'https://example.com/avatar.png',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
            message,
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<CachedNetworkImage>(
      find.descendant(
        of: find.byKey(eventGroupChatMessageSenderAvatarKey('message-1')),
        matching: find.byType(CachedNetworkImage),
      ),
    );
    expect(image.imageUrl, 'https://example.com/avatar.png');
  });

  testWidgets('renders deleted event chat message without original text',
      (tester) async {
    final chatRef = EventChatsRecord.collection.doc('event-123');
    final message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-1',
      text: 'Скрытый исходный текст',
      senderDisplayName: 'Марко',
      deletedAt: DateTime.parse('2026-06-15T11:30:00Z'),
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
            message,
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatMessageBubbleKey('message-1')),
        findsOneWidget);
    expect(find.byKey(eventGroupChatMessageTombstoneKey('message-1')),
        findsOneWidget);
    expect(find.text('Сообщение удалено'), findsOneWidget);
    expect(find.text('Скрытый исходный текст'), findsNothing);
    expect(find.text('Марко'), findsOneWidget);
  });

  testWidgets('sends event chat message through callable and clears input',
      (tester) async {
    String? functionName;
    Map<String, dynamic>? payload;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: ' event-123 ',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          sendMessageInvoker: (calledFunctionName, calledPayload) async {
            functionName = calledFunctionName;
            payload = calledPayload;
            return <String, dynamic>{
              'messageId': 'message-1',
              'createdAt': '2026-06-14T12:00:00.000Z',
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatMessageInputKey), findsOneWidget);
    expect(find.byKey(eventGroupChatSendButtonKey), findsOneWidget);

    await tester.enterText(
      find.byKey(eventGroupChatMessageInputKey),
      '  Всем привет!  ',
    );
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pumpAndSettle();

    expect(functionName, sendEventChatMessageFunctionName);
    expect(payload, <String, dynamic>{
      'eventId': 'event-123',
      'text': 'Всем привет!',
    });
    final input = tester.widget<TextFormField>(
      find.byKey(eventGroupChatMessageInputKey),
    );
    expect(input.controller?.text, isEmpty);
  });

  testWidgets('does not call send callable for blank event chat messages',
      (tester) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          sendMessageInvoker: (_, __) async {
            sendCalls += 1;
            return <String, dynamic>{
              'messageId': 'message-1',
              'createdAt': '2026-06-14T12:00:00.000Z',
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventGroupChatMessageInputKey), '   ');
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pumpAndSettle();

    expect(sendCalls, 0);
  });

  testWidgets('shows mapped error when event chat message send fails',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          sendMessageInvoker: (_, __) async {
            throw StateError('send failed');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventGroupChatMessageInputKey), 'Привет');
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatSendErrorSnackBarKey), findsOneWidget);
    expect(find.text('Не удалось выполнить действие. Попробуйте снова.'),
        findsOneWidget);
  });

  testWidgets('shows error state when event chat messages fail to load',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) => Stream<List<EventChatMessagesRecord>>.error(
            StateError('permission-denied'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatMessagesErrorKey), findsOneWidget);
    expect(find.text('Не удалось загрузить чат'), findsOneWidget);
  });
}

EventChatMessagesRecord _messageFixture({
  required DocumentReference chatRef,
  required String messageId,
  required String text,
  String senderId = 'uid-1',
  String senderDisplayName = 'Marco',
  String? senderPhotoUrl,
  DateTime? deletedAt,
  DateTime? createdAt,
}) {
  return EventChatMessagesRecord.getDocumentFromData(
    {
      'senderId': senderId,
      'senderDisplayName': senderDisplayName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'createdAt': createdAt ?? DateTime.parse('2026-06-14T10:00:00Z'),
      'deletedAt': deletedAt,
    },
    EventChatMessagesRecord.createDoc(chatRef, id: messageId),
  );
}

EventChatsRecord _chatFixture({
  required DocumentReference chatRef,
  required String eventId,
  DateTime? updatedAt,
}) {
  return EventChatsRecord.getDocumentFromData(
    {
      'eventId': eventId,
      'readAccessUserIds': <String>['uid-1'],
      'createdAt': DateTime.parse('2026-06-14T10:00:00Z'),
      'updatedAt': updatedAt ?? DateTime.parse('2026-06-14T10:00:00Z'),
    },
    chatRef,
  );
}
