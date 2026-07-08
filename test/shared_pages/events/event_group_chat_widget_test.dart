import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
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

  tearDown(() {
    EventGroupChatWidget.debugResetMessageCacheForTesting();
    currentUser = null;
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

  testWidgets('shows composer without trusted access state confirmation',
      (tester) async {
    var accessCalls = 0;
    var messageStreamCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: (_, __) async {
            accessCalls += 1;
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

    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageInputKey), findsOneWidget);
    expect(find.byKey(eventGroupChatSendButtonKey), findsOneWidget);
    expect(accessCalls, 0);
    expect(messageStreamCalls, 1);
  });

  testWidgets('does not call trusted access state after rebuild',
      (tester) async {
    var accessCalls = 0;
    final chatStream = _allowedChatStream();
    Future<Object?> accessStateInvoker(
      String functionName,
      Map<String, dynamic> payload,
    ) async {
      accessCalls += 1;
      throw StateError('access callable should not be used');
    }

    Widget buildSubject() => _buildTestApp(
          home: EventGroupChatWidget(
            eventId: 'event-123',
            chatStream: chatStream,
            accessStateInvoker: accessStateInvoker,
            messagesStream: (_) =>
                Stream.value(const <EventChatMessagesRecord>[]),
          ),
        );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageInputKey), findsOneWidget);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(accessCalls, 0);
    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageInputKey), findsOneWidget);
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

  testWidgets('shows cached event chat messages while stream reconnects',
      (tester) async {
    final chatRef = EventChatsRecord.collection.doc('event-cache');
    final cachedMessage = _messageFixture(
      chatRef: chatRef,
      messageId: 'cached-message',
      text: 'Кешированное сообщение',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          key: const ValueKey<String>('event-cache-first'),
          eventId: 'event-cache',
          chatStream: _allowedChatStream(eventId: 'event-cache'),
          accessStateInvoker: _accessStateInvoker(eventId: 'event-cache'),
          messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
            cachedMessage,
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Кешированное сообщение'), findsOneWidget);

    final pendingMessages = Completer<List<EventChatMessagesRecord>>();
    addTearDown(() {
      if (!pendingMessages.isCompleted) {
        pendingMessages.complete(const <EventChatMessagesRecord>[]);
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          key: const ValueKey<String>('event-cache-second'),
          eventId: 'event-cache',
          chatStream: _allowedChatStream(eventId: 'event-cache'),
          accessStateInvoker: _accessStateInvoker(eventId: 'event-cache'),
          messagesStream: (_) => pendingMessages.future.asStream(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(eventGroupChatMessagesLoadingKey), findsNothing);
    expect(find.byKey(eventGroupChatMessagesListKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageBubbleKey('cached-message')),
        findsOneWidget);
    expect(find.text('Кешированное сообщение'), findsOneWidget);
  });

  testWidgets('renders own event chat messages with the shared lavender color',
      (tester) async {
    currentUser = _TestAuthUser('uid-1');
    final chatRef = EventChatsRecord.collection.doc('event-123');
    final message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-1',
      senderId: 'uid-1',
      text: 'Моё сообщение',
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

    final bubble = tester.widget<Container>(
      find.byKey(eventGroupChatMessageBubbleKey('message-1')),
    );
    final decoration = bubble.decoration as BoxDecoration;
    final text = tester.widget<Text>(find.text('Моё сообщение'));

    expect(decoration.color, const Color(0xFFEDE4FA));
    expect(text.style?.color, Colors.black);
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

  testWidgets('keeps composer available when access state would be read-only',
      (tester) async {
    final chatRef = EventChatsRecord.collection.doc('event-123');
    final message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-1',
      text: 'До встречи!',
    );
    var accessCalls = 0;
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: (_, __) async {
            accessCalls += 1;
            return <String, dynamic>{
              'eventId': 'event-123',
              'status': 'canceled',
              'readOnly': true,
            };
          },
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
    expect(find.byKey(eventGroupChatMessageInputKey), findsOneWidget);
    expect(find.byKey(eventGroupChatSendButtonKey), findsOneWidget);
    expect(accessCalls, 0);

    await tester.enterText(find.byKey(eventGroupChatMessageInputKey), 'Привет');
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pumpAndSettle();

    expect(sendCalls, 1);
  });

  testWidgets('keeps composer visible when chat metadata updates',
      (tester) async {
    final chatController = StreamController<EventChatsRecord?>();
    var accessCalls = 0;
    addTearDown(chatController.close);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: (chatRef) => chatController.stream,
          accessStateInvoker: (_, __) async {
            accessCalls += 1;
            throw StateError('access callable should not be used');
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
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatMessageInputKey), findsOneWidget);
    expect(find.byKey(eventGroupChatSendButtonKey), findsOneWidget);

    chatController.add(
      _chatFixture(
        chatRef: EventChatsRecord.collection.doc('event-123'),
        eventId: 'event-123',
        updatedAt: DateTime.parse('2026-06-14T10:01:00Z'),
      ),
    );
    await tester.pumpAndSettle();

    expect(accessCalls, 0);
    expect(find.byKey(eventGroupChatMessageInputKey), findsOneWidget);
    expect(find.byKey(eventGroupChatSendButtonKey), findsOneWidget);
  });

  testWidgets('ignores access invoker while rendering chat', (tester) async {
    final chatController = StreamController<EventChatsRecord?>();
    var accessCalls = 0;
    addTearDown(chatController.close);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: (_) => chatController.stream,
          accessStateInvoker: (_, __) async {
            accessCalls += 1;
            throw StateError('access callable should not be used');
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
    await tester.pumpAndSettle();

    expect(accessCalls, 0);
    expect(find.byKey(eventGroupChatMessageInputKey), findsOneWidget);
    expect(find.byKey(eventGroupChatSendButtonKey), findsOneWidget);

    chatController.add(
      _chatFixture(
        chatRef: EventChatsRecord.collection.doc('event-123'),
        eventId: 'event-123',
        updatedAt: DateTime.parse('2026-06-14T10:01:00Z'),
      ),
    );
    await tester.pumpAndSettle();

    expect(accessCalls, 0);
    expect(find.byKey(eventGroupChatMessageInputKey), findsOneWidget);
    expect(find.byKey(eventGroupChatSendButtonKey), findsOneWidget);
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
        matching: find.text('М'),
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
        matching: find.text('У'),
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

  testWidgets('reports another participant event chat message', (tester) async {
    currentUser = _TestAuthUser('viewer-1');
    final chatRef = EventChatsRecord.collection.doc('event-123');
    final message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-1',
      senderId: 'sender-1',
      text: 'Suspicious message',
    );
    String? functionName;
    Map<String, dynamic>? payload;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: ' event-123 ',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
            message,
          ]),
          reportMessageInvoker: (calledFunctionName, calledPayload) async {
            functionName = calledFunctionName;
            payload = calledPayload;
            return <String, dynamic>{
              'eventId': 'event-123',
              'messageId': 'message-1',
              'reportId': 'report-1',
              'status': 'submitted',
              'reportedAt': '2026-06-16T10:00:00.000Z',
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatMessageReportButtonKey('message-1')),
        findsOneWidget);
    final reportIconButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(eventGroupChatMessageReportButtonKey('message-1')),
        matching: find.byType(IconButton),
      ),
    );
    expect(
      reportIconButton.constraints,
      const BoxConstraints.tightFor(width: 48, height: 48),
    );

    await tester
        .tap(find.byKey(eventGroupChatMessageReportButtonKey('message-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatReportDialogKey), findsOneWidget);

    await tester.tap(find.byKey(eventGroupChatReportReasonKey('offensive')));
    await tester.enterText(
      find.byKey(eventGroupChatReportDetailsFieldKey),
      '  rude text  ',
    );
    await tester.tap(find.byKey(eventGroupChatReportSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(functionName, reportEventChatMessageFunctionName);
    expect(payload, <String, dynamic>{
      'eventId': 'event-123',
      'messageId': 'message-1',
      'reasonCode': 'offensive',
      'details': 'rude text',
    });
    expect(find.byKey(eventGroupChatReportSuccessSnackBarKey), findsOneWidget);
    expect(find.text('Жалоба отправлена.'), findsOneWidget);
  });

  testWidgets('hides report action for own and deleted messages',
      (tester) async {
    currentUser = _TestAuthUser('viewer-1');
    final chatRef = EventChatsRecord.collection.doc('event-123');
    final ownMessage = _messageFixture(
      chatRef: chatRef,
      messageId: 'own-message',
      senderId: 'viewer-1',
      text: 'Own message',
    );
    final deletedMessage = _messageFixture(
      chatRef: chatRef,
      messageId: 'deleted-message',
      senderId: 'sender-1',
      text: 'Deleted message',
      deletedAt: DateTime.parse('2026-06-15T11:30:00Z'),
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
            ownMessage,
            deletedMessage,
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatMessageReportButtonKey('own-message')),
        findsNothing);
    expect(find.byKey(eventGroupChatMessageReportButtonKey('deleted-message')),
        findsNothing);

    currentUser = null;
    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
            _messageFixture(
              chatRef: chatRef,
              messageId: 'anonymous-view-message',
              senderId: 'sender-1',
              text: 'Visible message',
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(
          eventGroupChatMessageReportButtonKey('anonymous-view-message'),
        ),
        findsNothing);
  });

  testWidgets(
      'ignores stale event chat message report result after event change',
      (tester) async {
    currentUser = _TestAuthUser('viewer-1');
    var eventId = 'event-123';
    var reportCalls = 0;
    late StateSetter setHostState;
    final reportCompleter = Completer<Object?>();
    addTearDown(() {
      if (!reportCompleter.isCompleted) {
        reportCompleter.complete(<String, dynamic>{
          'eventId': 'event-123',
          'messageId': 'message-1',
          'reportId': 'report-1',
          'status': 'submitted',
          'reportedAt': '2026-06-16T10:00:00.000Z',
        });
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventGroupChatWidget(
              eventId: eventId,
              chatStream: (chatRef) => Stream<EventChatsRecord?>.value(
                _chatFixture(chatRef: chatRef, eventId: eventId),
              ),
              accessStateInvoker: (functionName, payload) async {
                expect(functionName, getEventChatAccessStateFunctionName);
                return <String, dynamic>{
                  'eventId': payload['eventId'] as String,
                  'status': 'active',
                  'readOnly': false,
                };
              },
              messagesStream: (chatRef) =>
                  Stream.value(<EventChatMessagesRecord>[
                _messageFixture(
                  chatRef: chatRef,
                  messageId: 'message-1',
                  senderId: 'sender-1',
                  text: 'Suspicious message',
                ),
              ]),
              reportMessageInvoker: (_, __) {
                reportCalls += 1;
                return reportCompleter.future;
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(eventGroupChatMessageReportButtonKey('message-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventGroupChatReportReasonKey('spam')));
    await tester.pump();
    await tester.tap(find.byKey(eventGroupChatReportSubmitButtonKey));
    await tester.pump();

    setHostState(() {
      eventId = 'event-456';
    });
    await tester.pumpAndSettle();

    reportCompleter.complete(<String, dynamic>{
      'eventId': 'event-123',
      'messageId': 'message-1',
      'reportId': 'report-1',
      'status': 'submitted',
      'reportedAt': '2026-06-16T10:00:00.000Z',
    });
    await tester.pumpAndSettle();

    expect(reportCalls, 1);
    expect(find.byKey(eventGroupChatReportSuccessSnackBarKey), findsNothing);
    expect(find.byKey(eventGroupChatReportErrorSnackBarKey), findsNothing);
    expect(find.text('Жалоба отправлена.'), findsNothing);
  });

  testWidgets('shows mapped error when event chat message report fails',
      (tester) async {
    currentUser = _TestAuthUser('viewer-1');
    final chatRef = EventChatsRecord.collection.doc('event-123');
    final message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-1',
      senderId: 'sender-1',
      text: 'Suspicious message',
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
          reportMessageInvoker: (_, __) async {
            throw _TestFirebaseFunctionsException(
              code: 'failed-precondition',
              message: 'Raw backend message',
              details: <String, dynamic>{
                'domainCode': 'event_chat_message_not_reportable',
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(eventGroupChatMessageReportButtonKey('message-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventGroupChatReportReasonKey('spam')));
    await tester.pump();
    await tester.tap(find.byKey(eventGroupChatReportSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatReportErrorSnackBarKey), findsOneWidget);
    expect(find.text('На это сообщение больше нельзя пожаловаться.'),
        findsOneWidget);
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
    expect(payload?['eventId'], 'event-123');
    expect(payload?['text'], 'Всем привет!');
    expect(payload?['clientMessageId'], isA<String>());
    expect((payload?['clientMessageId'] as String).trim(), isNotEmpty);
    expect(
      find.byKey(
        eventGroupChatMessageItemKey(payload?['clientMessageId'] as String),
      ),
      findsOneWidget,
    );
    final input = tester.widget<TextFormField>(
      find.byKey(eventGroupChatMessageInputKey),
    );
    expect(input.controller?.text, isEmpty);
  });

  testWidgets('keeps composer active while send is pending', (tester) async {
    currentUser = _TestAuthUser('uid-1', displayName: 'Марко');
    final sendCompleter = Completer<Object?>();
    addTearDown(() {
      if (!sendCompleter.isCompleted) {
        sendCompleter.complete(<String, dynamic>{
          'messageId': 'message-1',
          'createdAt': '2026-06-14T12:00:00.000Z',
        });
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          sendMessageInvoker: (_, __) => sendCompleter.future,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventGroupChatMessageInputKey), 'Привет');
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pump();

    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsNothing);
    expect(find.text('Привет'), findsOneWidget);
    expect(find.text('Марко'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsNothing);

    final input = tester.widget<TextFormField>(
      find.byKey(eventGroupChatMessageInputKey),
    );
    expect(input.controller?.text, isEmpty);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    await tester.enterText(
      find.byKey(eventGroupChatMessageInputKey),
      'Следующее',
    );
    final activeInput = tester.widget<TextFormField>(
      find.byKey(eventGroupChatMessageInputKey),
    );
    expect(activeInput.enabled, isTrue);
    expect(activeInput.controller?.text, 'Следующее');

    sendCompleter.complete(<String, dynamic>{
      'messageId': 'message-1',
      'createdAt': '2026-06-14T12:00:00.000Z',
    });
    await tester.pumpAndSettle();
  });

  testWidgets('replaces optimistic event chat message with firestore message',
      (tester) async {
    currentUser = _TestAuthUser('uid-1', displayName: 'Марко');
    final messagesController =
        StreamController<List<EventChatMessagesRecord>>();
    final sendCompleter = Completer<Object?>();
    addTearDown(messagesController.close);
    addTearDown(() {
      if (!sendCompleter.isCompleted) {
        sendCompleter.complete(<String, dynamic>{
          'messageId': 'message-1',
          'createdAt': '2026-06-14T12:00:00.000Z',
        });
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) => messagesController.stream,
          sendMessageInvoker: (_, __) => sendCompleter.future,
        ),
      ),
    );

    messagesController.add(const <EventChatMessagesRecord>[]);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventGroupChatMessageInputKey), 'Привет');
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pump();

    expect(find.text('Привет'), findsOneWidget);

    sendCompleter.complete(<String, dynamic>{
      'messageId': 'message-1',
      'createdAt': '2026-06-14T12:00:00.000Z',
    });
    await tester.pump();

    expect(find.text('Привет'), findsOneWidget);

    messagesController.add(<EventChatMessagesRecord>[
      _messageFixture(
        chatRef: EventChatsRecord.collection.doc('event-123'),
        messageId: 'message-1',
        senderId: 'uid-1',
        senderDisplayName: 'Марко',
        text: 'Привет',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatMessageBubbleKey('message-1')),
        findsOneWidget);
    expect(find.text('Привет'), findsOneWidget);
  });

  testWidgets('hides failed pending when server message with client id appears',
      (tester) async {
    currentUser = _TestAuthUser('uid-1', displayName: 'Марко');
    final messagesController =
        StreamController<List<EventChatMessagesRecord>>();
    String? clientMessageId;
    addTearDown(messagesController.close);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) => messagesController.stream,
          sendMessageInvoker: (_, payload) async {
            clientMessageId = payload['clientMessageId'] as String;
            throw StateError('network response lost after write');
          },
        ),
      ),
    );

    messagesController.add(const <EventChatMessagesRecord>[]);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventGroupChatMessageInputKey), 'Привет');
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pumpAndSettle();

    expect(clientMessageId, isNotNull);
    expect(find.text('Привет'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    messagesController.add(<EventChatMessagesRecord>[
      _messageFixture(
        chatRef: EventChatsRecord.collection.doc('event-123'),
        messageId: clientMessageId!,
        senderId: 'uid-1',
        senderDisplayName: 'Марко',
        text: 'Привет',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Привет'), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    expect(find.byKey(eventGroupChatMessageBubbleKey(clientMessageId!)),
        findsOneWidget);
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
    var sendCalls = 0;
    final payloads = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          accessStateInvoker: _accessStateInvoker(),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          sendMessageInvoker: (_, payload) async {
            sendCalls += 1;
            payloads.add(payload);
            if (sendCalls == 1) {
              throw StateError('send failed');
            }
            return <String, dynamic>{
              'messageId': 'message-retry',
              'createdAt': '2026-06-14T12:00:00.000Z',
            };
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
    expect(find.text('Привет'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    final input = tester.widget<TextFormField>(
      find.byKey(eventGroupChatMessageInputKey),
    );
    expect(input.controller?.text, isEmpty);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(sendCalls, 2);
    expect(payloads, hasLength(2));
    expect(payloads[0]['clientMessageId'], payloads[1]['clientMessageId']);
    expect(find.byIcon(Icons.done_rounded), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
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

class _TestAuthUser extends BaseAuthUser {
  _TestAuthUser(
    this._uid, {
    String? displayName,
    String? photoUrl,
  })  : _displayName = displayName,
        _photoUrl = photoUrl;

  final String _uid;
  final String? _displayName;
  final String? _photoUrl;

  @override
  bool get loggedIn => true;

  @override
  bool get emailVerified => true;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(
        uid: _uid,
        displayName: _displayName,
        photoUrl: _photoUrl,
      );

  @override
  Future<void> delete() async {}

  @override
  Future<void> updateEmail(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> sendEmailVerification() async {}
}

class _TestFirebaseFunctionsException extends FirebaseFunctionsException {
  _TestFirebaseFunctionsException({
    required super.code,
    required super.message,
    super.details,
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
