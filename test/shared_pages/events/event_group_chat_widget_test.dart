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
          messagesStream: (_) => completer.future.asStream(),
        ),
      ),
    );
    await tester.pump();

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
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsOneWidget);
    expect(find.text('Сообщений пока нет'), findsOneWidget);
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
}) {
  return EventChatMessagesRecord.getDocumentFromData(
    {
      'senderId': senderId,
      'senderDisplayName': senderDisplayName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'createdAt': DateTime.parse('2026-06-14T10:00:00Z'),
      'deletedAt': deletedAt,
    },
    EventChatMessagesRecord.createDoc(chatRef, id: messageId),
  );
}
