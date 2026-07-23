import 'dart:async';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/chat_thread/chat_thread_widget.dart';
import 'package:small_talk/shared_pages/chat_thread/open_chat_thread.dart';
import 'package:small_talk/services/ux_session_cache_lifecycle.dart';

const _supportedLocales = <Locale>[
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
    await initializeDateFormatting('ru');
  });

  setUp(() {
    currentUser = _TestAuthUser('user-a');
    currentUserDocument = null;
  });

  tearDown(() {
    ChatThreadWidget.debugResetMessageCacheForTesting();
    UxSessionCacheLifecycle.debugResetForTesting();
    currentUser = null;
    currentUserDocument = null;
  });

  testWidgets('deferred chat starts its listener after preparation succeeds',
      (tester) async {
    final preparation = Completer<void>();
    var calls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: DeferredChatThreadWidget(
          conversationRef: null,
          preparation: () {
            calls += 1;
            return preparation.future;
          },
        ),
      ),
    );
    await tester.pump();

    expect(calls, 1);
    expect(find.byKey(deferredChatThreadLoadingKey), findsOneWidget);
    expect(find.byType(ChatThreadWidget), findsNothing);

    preparation.complete();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(deferredChatThreadLoadingKey), findsNothing);
    expect(find.byType(ChatThreadWidget), findsOneWidget);
  });

  testWidgets('deferred chat retries preparation without concurrent attempts',
      (tester) async {
    final retryPreparation = Completer<void>();
    var calls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: DeferredChatThreadWidget(
          conversationRef: null,
          preparation: () {
            calls += 1;
            if (calls == 1) {
              return Future<void>.error(StateError('offline'));
            }
            return retryPreparation.future;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(calls, 1);
    expect(find.byKey(deferredChatThreadErrorKey), findsOneWidget);

    await tester.tap(find.byKey(deferredChatThreadRetryButtonKey));
    await tester.pump();

    expect(calls, 2);
    expect(find.byKey(deferredChatThreadLoadingKey), findsOneWidget);
    expect(find.byKey(deferredChatThreadRetryButtonKey), findsNothing);

    retryPreparation.complete();
    await tester.pump();
    await tester.pump();

    expect(calls, 2);
    expect(find.byType(ChatThreadWidget), findsOneWidget);
  });

  testWidgets(
    'private chat keeps previous messages through refresh errors and retries',
    (tester) async {
      final sources = _ChatThreadSources();
      addTearDown(sources.close);
      final conversation = _conversationFixture('refresh-chat');
      final message = _messageFixture(
        conversationRef: conversation.reference,
        messageId: 'stable-message',
        text: 'Stable private message',
      );

      await tester.pumpWidget(
        _buildTestApp(
          home: ChatThreadWidget(
            conversationRef: conversation.reference,
            debugConversationStream: sources.watchConversation,
            debugMessagesStream: sources.watchMessages,
            debugPublicProfileStream: (_) => Stream.value(null),
            debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
          ),
        ),
      );
      await tester.pump();

      sources.conversations.single.add(_conversationState(conversation));
      await tester.pump();
      expect(sources.messages, hasLength(1));

      sources.messages.single.add(_messagesState(<MessagesRecord>[message]));
      await tester.pump();
      expect(find.text('Stable private message'), findsOneWidget);

      sources.messages.single.addError(StateError('offline'));
      await tester.pump();
      expect(find.text('Stable private message'), findsOneWidget);
      expect(find.byKey(chatThreadMessagesInlineErrorKey), findsOneWidget);
      expect(find.text('Не удалось загрузить сообщения.'), findsNothing);

      await tester.tap(find.byKey(chatThreadMessagesRetryButtonKey));
      await tester.pump();
      expect(sources.messages, hasLength(2));
      expect(find.text('Stable private message'), findsOneWidget);
      expect(find.byKey(chatThreadMessagesInlineErrorKey), findsNothing);

      sources.messages.last.add(_messagesState(<MessagesRecord>[message]));
      await tester.pump();

      sources.conversations.first.addError(StateError('offline'));
      await tester.pump();
      expect(find.text('Stable private message'), findsOneWidget);
      expect(find.byKey(chatThreadConversationInlineErrorKey), findsOneWidget);
      expect(find.text('Не удалось загрузить чат. Попробуйте позже.'),
          findsNothing);

      await tester.tap(find.byKey(chatThreadConversationRetryButtonKey));
      await tester.pump();
      expect(sources.conversations, hasLength(2));
      expect(find.text('Stable private message'), findsOneWidget);
      expect(find.byKey(chatThreadConversationInlineErrorKey), findsNothing);

      sources.conversations.last.add(_conversationState(conversation));
      await tester.pump();
      expect(find.text('Stable private message'), findsOneWidget);
    },
  );

  testWidgets(
      'message viewport keeps offset through error retry and pagination',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final conversation = _conversationFixture('scroll-anchor-chat');
    final messages = List<MessagesRecord>.generate(
      65,
      (index) => _messageFixture(
        conversationRef: conversation.reference,
        messageId: 'scroll-message-$index',
        text: 'Scroll message $index',
      ),
      growable: false,
    );

    ScrollPosition messagePosition() {
      final scrollable = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      return tester.state<ScrollableState>(scrollable).position;
    }

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: sources.watchConversation,
          debugMessagesStream: sources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    sources.messages.single.add(_messagesState(messages.take(60)));
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pump();
    final beforeError = messagePosition().pixels;
    expect(beforeError, greaterThan(0.0));

    sources.messages.single.addError(StateError('offline'));
    await tester.pump();

    expect(messagePosition().pixels, closeTo(beforeError, 1.0));
    expect(find.byKey(chatThreadMessagesInlineErrorKey), findsOneWidget);

    await tester.tap(find.byKey(chatThreadMessagesRetryButtonKey));
    await tester.pump();

    expect(sources.messages, hasLength(2));
    expect(messagePosition().pixels, closeTo(beforeError, 1.0));

    sources.messages.last.add(_messagesState(messages.take(60)));
    await tester.pump();
    expect(messagePosition().pixels, closeTo(beforeError, 1.0));

    final beforePaginationDrag = messagePosition().maxScrollExtent - 520.0;
    expect(beforePaginationDrag, greaterThan(0.0));
    messagePosition().jumpTo(beforePaginationDrag);
    await tester.pump();
    expect(sources.messages, hasLength(2));

    final paginationGesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    await paginationGesture.moveBy(const Offset(0.0, 320.0));
    final activePaginationPosition = messagePosition();
    final duringPaginationDrag = activePaginationPosition.pixels;
    expect(
      activePaginationPosition.maxScrollExtent - duringPaginationDrag,
      lessThanOrEqualTo(260.0),
    );
    await tester.pump();

    expect(sources.messages, hasLength(3));
    expect(sources.messageLimits, <int>[60, 60, 120]);
    expect(identical(messagePosition(), activePaginationPosition), isTrue);
    expect(messagePosition().pixels, closeTo(duringPaginationDrag, 1.0));

    await paginationGesture.moveBy(const Offset(0.0, 40.0));
    final continuedDragOffset = activePaginationPosition.pixels;
    expect(continuedDragOffset, greaterThan(duringPaginationDrag));
    expect(identical(messagePosition(), activePaginationPosition), isTrue);
    await tester.pump();

    sources.messages.last.add(_messagesState(messages));
    await tester.pump();

    expect(messagePosition().pixels, closeTo(continuedDragOffset, 1.0));
    await paginationGesture.up();
    await tester.pump();
  });

  testWidgets('optimistic send replaces the initial messages loader',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final conversation = _conversationFixture('optimistic-loading-chat');
    final writeCompleter = Completer<void>();
    addTearDown(() {
      if (!writeCompleter.isCompleted) {
        writeCompleter.complete();
      }
    });
    DocumentReference? writtenRef;

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: sources.watchConversation,
          debugMessagesStream: sources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
          debugMessageWrite: (messageRef, _) {
            writtenRef = messageRef;
            return writeCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(conversation));
    await tester.pump();

    expect(sources.messages, hasLength(1));
    expect(find.byType(SpinKitCircle), findsOneWidget);

    await tester.enterText(
      find.byKey(chatThreadMessageInputKey),
      'Send while loading',
    );
    await tester.tap(find.byKey(chatThreadSendButtonKey));
    await tester.pump();

    final messageRef = writtenRef!;
    final pendingItem = find.byKey(
      chatThreadMessageItemKey(messageRef.path),
    );
    expect(pendingItem, findsOneWidget);
    expect(find.text('Send while loading'), findsOneWidget);
    expect(find.byType(SpinKitCircle), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(chatThreadMessageStatusSlotKey(messageRef.path)),
        matching: find.byIcon(Icons.schedule_rounded),
      ),
      findsOneWidget,
    );

    writeCompleter.complete();
    await tester.pump();
    expect(pendingItem, findsOneWidget);
  });

  testWidgets(
      'firestore pending record stays sending without in-memory optimistic state',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final conversation = _conversationFixture('firestore-pending-chat');
    final messageRef = MessagesRecord.createDoc(
      conversation.reference,
      id: 'local-pending-message',
    );
    final confirmedMessageRef = MessagesRecord.createDoc(
      conversation.reference,
      id: 'confirmed-message',
    );
    final confirmedMessage = _outgoingMessageFixture(
      messageRef: confirmedMessageRef,
      text: 'Confirmed outgoing message',
      createdAt: DateTime.utc(2026, 7, 14, 10),
    );
    final pendingObservedAt = DateTime.utc(2026, 7, 14, 10, 5);
    final pendingItem = find.byKey(
      chatThreadMessageItemKey(messageRef.path),
    );
    final confirmedItem = find.byKey(
      chatThreadMessageItemKey(confirmedMessageRef.path),
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: sources.watchConversation,
          debugMessagesStream: sources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    sources.messages.single.add(
      _messagesState(
        <MessagesRecord>[
          _outgoingMessageFixture(
            messageRef: messageRef,
            text: 'Restored local write',
          ),
          confirmedMessage,
        ],
        isFromCache: true,
        hasPendingWrites: true,
        pendingWriteMessagePaths: <String>[messageRef.path],
        pendingWritesObservedAt: pendingObservedAt,
      ),
    );
    await tester.pump();

    expect(find.text('Restored local write'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(chatThreadMessageStatusSlotKey(messageRef.path)),
        matching: find.byIcon(Icons.schedule_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(chatThreadMessageStatusSlotKey(messageRef.path)),
        matching: find.byIcon(Icons.done_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(
          chatThreadMessageStatusSlotKey(confirmedMessageRef.path),
        ),
        matching: find.byIcon(Icons.done_rounded),
      ),
      findsOneWidget,
    );
    expect(tester.getCenter(pendingItem).dy,
        greaterThan(tester.getCenter(confirmedItem).dy));

    sources.messages.single.add(
      _messagesState(
        <MessagesRecord>[confirmedMessage],
        isFromCache: true,
      ),
    );
    await tester.pump();

    expect(find.text('Restored local write'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(chatThreadMessageStatusSlotKey(messageRef.path)),
        matching: find.byIcon(Icons.schedule_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          chatThreadMessageStatusSlotKey(confirmedMessageRef.path),
        ),
        matching: find.byIcon(Icons.done_rounded),
      ),
      findsOneWidget,
    );
    expect(tester.getCenter(pendingItem).dy,
        greaterThan(tester.getCenter(confirmedItem).dy));

    sources.messages.single.add(
      _messagesState(
        <MessagesRecord>[
          _outgoingMessageFixture(
            messageRef: messageRef,
            text: 'Restored local write',
            createdAt: pendingObservedAt,
          ),
          confirmedMessage,
        ],
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(chatThreadMessageStatusSlotKey(messageRef.path)),
        matching: find.byIcon(Icons.done_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    expect(tester.getCenter(pendingItem).dy,
        greaterThan(tester.getCenter(confirmedItem).dy));
  });

  testWidgets(
      'optimistic private message appears immediately and reconciles once',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final conversation = _conversationFixture('optimistic-send-chat');
    final previousMessage = _messageFixture(
      conversationRef: conversation.reference,
      messageId: 'previous-message',
      text: 'Previous server message',
    );
    final writeCompleter = Completer<void>();
    addTearDown(() {
      if (!writeCompleter.isCompleted) {
        writeCompleter.complete();
      }
    });
    DocumentReference? writtenRef;
    Map<String, dynamic>? writtenData;
    var writeCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: sources.watchConversation,
          debugMessagesStream: sources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
          debugMessageWrite: (messageRef, data) {
            writeCount += 1;
            writtenRef = messageRef;
            writtenData = Map<String, dynamic>.from(data);
            return writeCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    sources.messages.single.add(
      _messagesState(<MessagesRecord>[previousMessage]),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(chatThreadMessageInputKey),
      '  Optimistic hello  ',
    );
    await tester.tap(find.byKey(chatThreadSendButtonKey));
    await tester.pump();

    expect(writeCount, 1);
    final messageRef = writtenRef!;
    final pendingItem = find.byKey(
      chatThreadMessageItemKey(messageRef.path),
    );
    expect(find.text('Previous server message'), findsOneWidget);
    expect(pendingItem, findsOneWidget);
    expect(
      find.descendant(
        of: pendingItem,
        matching: find.text('Optimistic hello'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(chatThreadMessageStatusSlotKey(messageRef.path)),
        matching: find.byIcon(Icons.schedule_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(chatThreadMessageInputKey))
          .controller
          ?.text,
      isEmpty,
    );
    expect(writtenData?['senderId'], 'user-a');
    expect(writtenData?['senderRef'], UsersRecord.collection.doc('user-a'));
    expect(writtenData?['type'], kConversationMessageTypeText);
    expect(writtenData?['text'], 'Optimistic hello');
    expect(writtenData?['createdAt'], isA<FieldValue>());

    sources.messages.single.add(
      _messagesState(
        <MessagesRecord>[
          previousMessage,
          _outgoingMessageFixture(
            messageRef: messageRef,
            text: 'Optimistic hello',
          ),
        ],
        hasPendingWrites: true,
        pendingWriteMessagePaths: <String>[messageRef.path],
      ),
    );
    await tester.pump();

    expect(pendingItem, findsOneWidget);
    expect(find.text('Optimistic hello'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(chatThreadMessageStatusSlotKey(messageRef.path)),
        matching: find.byIcon(Icons.schedule_rounded),
      ),
      findsOneWidget,
    );

    writeCompleter.complete();
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(chatThreadMessageStatusSlotKey(messageRef.path)),
        matching: find.byIcon(Icons.done_rounded),
      ),
      findsOneWidget,
    );

    sources.messages.single.add(
      _messagesState(<MessagesRecord>[
        previousMessage,
        _outgoingMessageFixture(
          messageRef: messageRef,
          text: 'Optimistic hello',
          createdAt: DateTime.utc(2026, 7, 14, 10, 1),
        ),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(writeCount, 1);
    expect(pendingItem, findsOneWidget);
    expect(find.text('Optimistic hello'), findsOneWidget);
  });

  testWidgets('failed optimistic private message retries the same write once',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final conversation = _conversationFixture('optimistic-retry-chat');
    final writes =
        <(DocumentReference, Map<String, dynamic>, Completer<void>)>[];
    addTearDown(() {
      for (final write in writes) {
        if (!write.$3.isCompleted) {
          write.$3.complete();
        }
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: sources.watchConversation,
          debugMessagesStream: sources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
          debugMessageWrite: (messageRef, data) {
            final completion = Completer<void>();
            writes.add((
              messageRef,
              Map<String, dynamic>.from(data),
              completion,
            ));
            return completion.future;
          },
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    sources.messages.single.add(_messagesState(const <MessagesRecord>[]));
    await tester.pump();

    await tester.enterText(
      find.byKey(chatThreadMessageInputKey),
      'Retry this message',
    );
    await tester.tap(find.byKey(chatThreadSendButtonKey));
    await tester.pump();

    expect(writes, hasLength(1));
    final messageRef = writes.single.$1;
    final pendingItem = find.byKey(
      chatThreadMessageItemKey(messageRef.path),
    );
    expect(pendingItem, findsOneWidget);
    expect(find.text('Retry this message'), findsOneWidget);

    const foreignSnackBarKey = ValueKey<String>('foreign_chat_snack_bar');
    ScaffoldMessenger.of(
      tester.element(find.byKey(chatThreadMessageInputKey)),
    ).showSnackBar(
      const SnackBar(
        key: foreignSnackBarKey,
        content: Text('Foreign notification'),
      ),
    );
    await tester.pump();
    expect(find.byKey(foreignSnackBarKey), findsOneWidget);

    writes.single.$3.completeError(StateError('write failed'));
    await tester.pump();

    final retryButton = find.byKey(
      chatThreadMessageRetryButtonKey(messageRef.path),
    );
    expect(
      find.descendant(
        of: find.byKey(chatThreadMessageStatusSlotKey(messageRef.path)),
        matching: find.byIcon(Icons.error_outline_rounded),
      ),
      findsOneWidget,
    );
    expect(retryButton.hitTestable(), findsOneWidget);
    expect(find.byKey(foreignSnackBarKey), findsNothing);
    expect(find.byKey(chatThreadSendErrorSnackBarKey), findsOneWidget);

    await tester.tap(retryButton);
    await tester.tap(retryButton);
    await tester.pump();

    expect(writes, hasLength(2));
    expect(find.byKey(chatThreadSendErrorSnackBarKey), findsNothing);
    expect(writes.last.$1.path, messageRef.path);
    expect(writes.last.$2['senderId'], writes.first.$2['senderId']);
    expect(writes.last.$2['senderRef'], writes.first.$2['senderRef']);
    expect(writes.last.$2['type'], writes.first.$2['type']);
    expect(writes.last.$2['text'], writes.first.$2['text']);
    expect(
      find.descendant(
        of: find.byKey(chatThreadMessageStatusSlotKey(messageRef.path)),
        matching: find.byIcon(Icons.schedule_rounded),
      ),
      findsOneWidget,
    );
    expect(retryButton.hitTestable(), findsNothing);

    writes.last.$3.complete();
    await tester.pump();

    expect(find.byKey(chatThreadSendErrorSnackBarKey), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(chatThreadMessageStatusSlotKey(messageRef.path)),
        matching: find.byIcon(Icons.done_rounded),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(chatThreadSendErrorSnackBarKey), findsNothing);

    sources.messages.single.add(
      _messagesState(<MessagesRecord>[
        _outgoingMessageFixture(
          messageRef: messageRef,
          text: 'Retry this message',
          createdAt: DateTime.utc(2026, 7, 14, 10, 2),
        ),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(pendingItem, findsOneWidget);
    expect(find.text('Retry this message'), findsOneWidget);
  });

  testWidgets('send error snackbar clears on path boundary and dispose',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final firstConversation = _conversationFixture('snackbar-first-chat');
    final secondConversation = _conversationFixture('snackbar-second-chat');
    final ownerStream = Stream<String>.value('user-a');
    final writes = <Completer<void>>[];
    addTearDown(() {
      for (final write in writes) {
        if (!write.isCompleted) {
          write.complete();
        }
      }
    });

    ChatThreadWidget buildThread(ConversationsRecord conversation) {
      return ChatThreadWidget(
        conversationRef: conversation.reference,
        debugConversationStream: sources.watchConversation,
        debugMessagesStream: sources.watchMessages,
        debugPublicProfileStream: (_) => Stream.value(null),
        debugAuthenticatedOwnerUidStream: ownerStream,
        debugMessageWrite: (_, __) {
          final completion = Completer<void>();
          writes.add(completion);
          return completion.future;
        },
      );
    }

    await tester.pumpWidget(
      _buildTestApp(home: buildThread(firstConversation)),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(firstConversation));
    await tester.pump();
    sources.messages.single.add(_messagesState(const <MessagesRecord>[]));
    await tester.pump();

    await tester.enterText(
      find.byKey(chatThreadMessageInputKey),
      'First path failure',
    );
    await tester.tap(find.byKey(chatThreadSendButtonKey));
    await tester.pump();
    writes.single.completeError(StateError('first path failed'));
    await tester.pump();
    expect(find.byKey(chatThreadSendErrorSnackBarKey), findsOneWidget);

    await tester.pumpWidget(
      _buildTestApp(home: buildThread(secondConversation)),
    );
    await tester.pump();
    expect(find.byKey(chatThreadSendErrorSnackBarKey), findsNothing);
    expect(find.text('First path failure'), findsNothing);

    sources.conversations.last.add(_conversationState(secondConversation));
    await tester.pump();
    sources.messages.last.add(_messagesState(const <MessagesRecord>[]));
    await tester.pump();

    await tester.enterText(
      find.byKey(chatThreadMessageInputKey),
      'Dispose failure',
    );
    await tester.tap(find.byKey(chatThreadSendButtonKey));
    await tester.pump();
    writes.last.completeError(StateError('dispose failed'));
    await tester.pump();
    expect(find.byKey(chatThreadSendErrorSnackBarKey), findsOneWidget);

    await tester.pumpWidget(_buildTestApp(home: const SizedBox.shrink()));
    await tester.pump();
    expect(find.byKey(chatThreadSendErrorSnackBarKey), findsNothing);
  });

  testWidgets('confirmed optimistic message ignores a late write failure',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final conversation = _conversationFixture('optimistic-confirmed-chat');
    final writeCompleter = Completer<void>();
    addTearDown(() {
      if (!writeCompleter.isCompleted) {
        writeCompleter.complete();
      }
    });
    DocumentReference? writtenRef;

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: sources.watchConversation,
          debugMessagesStream: sources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
          debugMessageWrite: (messageRef, _) {
            writtenRef = messageRef;
            return writeCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    sources.messages.single.add(_messagesState(const <MessagesRecord>[]));
    await tester.pump();

    await tester.enterText(
      find.byKey(chatThreadMessageInputKey),
      'Already confirmed',
    );
    await tester.tap(find.byKey(chatThreadSendButtonKey));
    await tester.pump();

    final messageRef = writtenRef!;
    sources.messages.single.add(
      _messagesState(<MessagesRecord>[
        _outgoingMessageFixture(
          messageRef: messageRef,
          text: 'Already confirmed',
          createdAt: DateTime.utc(2026, 7, 14, 10, 3),
        ),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Already confirmed'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(chatThreadMessageStatusSlotKey(messageRef.path)),
        matching: find.byIcon(Icons.done_rounded),
      ),
      findsOneWidget,
    );

    writeCompleter.completeError(StateError('late write failure'));
    await tester.pump();

    expect(find.text('Already confirmed'), findsOneWidget);
    expect(find.byKey(chatThreadSendErrorSnackBarKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'old owner write completion cannot affect a fresh optimistic send',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final authenticatedOwners = StreamController<String>.broadcast(sync: true);
    addTearDown(authenticatedOwners.close);
    final conversation = _conversationFixture('optimistic-owner-aba-chat');
    final writes = <(DocumentReference, Completer<void>)>[];
    addTearDown(() {
      for (final write in writes) {
        if (!write.$2.isCompleted) {
          write.$2.complete();
        }
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: sources.watchConversation,
          debugMessagesStream: sources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: authenticatedOwners.stream,
          debugMessageWrite: (messageRef, _) {
            final completion = Completer<void>();
            writes.add((messageRef, completion));
            return completion.future;
          },
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    sources.messages.single.add(_messagesState(const <MessagesRecord>[]));
    await tester.pump();

    await tester.enterText(
      find.byKey(chatThreadMessageInputKey),
      'Old owner pending',
    );
    await tester.tap(find.byKey(chatThreadSendButtonKey));
    await tester.pump();

    expect(writes, hasLength(1));
    expect(find.text('Old owner pending'), findsOneWidget);

    authenticatedOwners.add('user-b');
    await tester.pump();
    expect(find.text('Old owner pending'), findsNothing);
    sources.conversations.last.add(
      _conversationState(conversation, ownerUid: 'user-b'),
    );
    await tester.pump();
    sources.messages.last.add(
      _messagesState(const <MessagesRecord>[], ownerUid: 'user-b'),
    );
    await tester.pump();

    authenticatedOwners.add('user-a');
    await tester.pump();
    sources.conversations.last.add(_conversationState(conversation));
    await tester.pump();
    sources.messages.last.add(_messagesState(const <MessagesRecord>[]));
    await tester.pump();

    await tester.enterText(
      find.byKey(chatThreadMessageInputKey),
      'Current owner pending',
    );
    await tester.tap(find.byKey(chatThreadSendButtonKey));
    await tester.pump();

    expect(writes, hasLength(2));
    final currentMessageRef = writes.last.$1;
    expect(
      find.descendant(
        of: find.byKey(
          chatThreadMessageStatusSlotKey(currentMessageRef.path),
        ),
        matching: find.byIcon(Icons.schedule_rounded),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(chatThreadMessageInputKey),
      'Keep this draft',
    );
    writes.first.$2.completeError(StateError('stale owner failure'));
    await tester.pump();

    expect(find.byKey(chatThreadSendErrorSnackBarKey), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(
          chatThreadMessageStatusSlotKey(currentMessageRef.path),
        ),
        matching: find.byIcon(Icons.schedule_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(chatThreadSendButtonKey));
    await tester.pump();
    expect(writes, hasLength(2));
    expect(
      tester
          .widget<TextFormField>(find.byKey(chatThreadMessageInputKey))
          .controller
          ?.text,
      'Keep this draft',
    );

    writes.last.$2.complete();
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(
          chatThreadMessageStatusSlotKey(currentMessageRef.path),
        ),
        matching: find.byIcon(Icons.done_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cold conversation error exposes retry with a fresh source',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final conversation = _conversationFixture('cold-conversation-error');

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: sources.watchConversation,
          debugMessagesStream: sources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.addError(StateError('offline'));
    await tester.pump();

    expect(
      find.text('Не удалось загрузить чат. Попробуйте позже.'),
      findsOneWidget,
    );
    expect(find.byKey(chatThreadConversationRetryButtonKey), findsOneWidget);
    expect(
      find.bySemanticsLabel('Повторить загрузку чата'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(chatThreadConversationRetryButtonKey));
    await tester.pump();

    expect(sources.conversations, hasLength(2));
    expect(
      find.text('Не удалось загрузить чат. Попробуйте позже.'),
      findsNothing,
    );
  });

  testWidgets('cold messages error exposes retry with a fresh source',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final conversation = _conversationFixture('cold-messages-error');

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: sources.watchConversation,
          debugMessagesStream: sources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    sources.messages.single.addError(StateError('offline'));
    await tester.pump();

    expect(find.text('Не удалось загрузить сообщения.'), findsOneWidget);
    expect(find.byKey(chatThreadMessagesRetryButtonKey), findsOneWidget);
    expect(
      find.bySemanticsLabel('Повторить загрузку сообщений'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(chatThreadMessagesRetryButtonKey));
    await tester.pump();

    expect(sources.messages, hasLength(2));
    expect(find.text('Не удалось загрузить сообщения.'), findsNothing);
  });

  testWidgets('confirmed empty chat stays visible through refresh error',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final conversation = _conversationFixture('empty-refresh-chat');

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: sources.watchConversation,
          debugMessagesStream: sources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    sources.messages.single.add(
      _messagesState(const <MessagesRecord>[], isFromCache: true),
    );
    await tester.pump();

    expect(
      find.text('Чат открыт. Напишите первое сообщение.'),
      findsNothing,
    );

    sources.messages.single.add(_messagesState(const <MessagesRecord>[]));
    await tester.pump();

    expect(
      find.text('Чат открыт. Напишите первое сообщение.'),
      findsOneWidget,
    );

    sources.messages.single.addError(StateError('offline'));
    await tester.pump();
    expect(
      find.text('Чат открыт. Напишите первое сообщение.'),
      findsOneWidget,
    );
    expect(find.byKey(chatThreadMessagesInlineErrorKey), findsOneWidget);

    await tester.tap(find.byKey(chatThreadMessagesRetryButtonKey));
    await tester.pump();
    expect(sources.messages, hasLength(2));
    expect(
      find.text('Чат открыт. Напишите первое сообщение.'),
      findsOneWidget,
    );
    expect(find.byKey(chatThreadMessagesInlineErrorKey), findsNothing);
  });

  testWidgets(
      'non-authoritative partial snapshot keeps records until reconciliation',
      (tester) async {
    final firstSources = _ChatThreadSources();
    final secondSources = _ChatThreadSources();
    addTearDown(firstSources.close);
    addTearDown(secondSources.close);
    final conversation = _conversationFixture('partial-refresh-chat');
    final retainedMessage = _messageFixture(
      conversationRef: conversation.reference,
      messageId: 'retained-message',
      text: 'Retained during cache refresh',
    );
    final refreshedMessage = _messageFixture(
      conversationRef: conversation.reference,
      messageId: 'refreshed-message',
      text: 'Present in partial snapshot',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: firstSources.watchConversation,
          debugMessagesStream: firstSources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
        ),
      ),
    );
    await tester.pump();
    firstSources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    firstSources.messages.single.add(
      _messagesState(<MessagesRecord>[retainedMessage, refreshedMessage]),
    );
    await tester.pump();

    expect(find.text('Retained during cache refresh'), findsOneWidget);
    expect(find.text('Present in partial snapshot'), findsOneWidget);

    firstSources.messages.single.add(
      _messagesState(
        <MessagesRecord>[refreshedMessage],
        isFromCache: true,
      ),
    );
    await tester.pump();

    expect(find.text('Retained during cache refresh'), findsOneWidget);
    expect(find.text('Present in partial snapshot'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: secondSources.watchConversation,
          debugMessagesStream: secondSources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
        ),
      ),
    );
    await tester.pump();
    secondSources.conversations.single.add(_conversationState(conversation));
    await tester.pump();

    expect(find.text('Retained during cache refresh'), findsOneWidget);
    expect(find.text('Present in partial snapshot'), findsOneWidget);

    secondSources.messages.single.add(
      _messagesState(<MessagesRecord>[refreshedMessage]),
    );
    await tester.pump();

    expect(find.text('Retained during cache refresh'), findsNothing);
    expect(find.text('Present in partial snapshot'), findsOneWidget);
  });

  testWidgets('pending-only snapshot is retained but not cached as empty',
      (tester) async {
    final firstSources = _ChatThreadSources();
    final secondSources = _ChatThreadSources();
    addTearDown(firstSources.close);
    addTearDown(secondSources.close);
    final conversation = _conversationFixture('pending-only-refresh-chat');
    final pendingMessage = _pendingMessageFixture(
      conversationRef: conversation.reference,
      messageId: 'pending-only-message',
      text: 'Pending-only message',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: firstSources.watchConversation,
          debugMessagesStream: firstSources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
        ),
      ),
    );
    await tester.pump();
    firstSources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    firstSources.messages.single.add(
      _messagesState(
        <MessagesRecord>[pendingMessage],
        hasPendingWrites: true,
        pendingWriteMessagePaths: <String>[pendingMessage.reference.path],
      ),
    );
    await tester.pump();
    expect(find.text('Pending-only message'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(
          chatThreadMessageStatusSlotKey(pendingMessage.reference.path),
        ),
        matching: find.byIcon(Icons.schedule_rounded),
      ),
      findsOneWidget,
    );

    firstSources.messages.single.addError(StateError('offline'));
    await tester.pump();

    expect(find.text('Pending-only message'), findsOneWidget);
    expect(find.byKey(chatThreadMessagesInlineErrorKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(
          chatThreadMessageStatusSlotKey(pendingMessage.reference.path),
        ),
        matching: find.byIcon(Icons.schedule_rounded),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: secondSources.watchConversation,
          debugMessagesStream: secondSources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
        ),
      ),
    );
    await tester.pump();
    secondSources.conversations.single.add(_conversationState(conversation));
    await tester.pump();

    expect(find.text('Pending-only message'), findsNothing);
    expect(
      find.text('Чат открыт. Напишите первое сообщение.'),
      findsNothing,
    );
    expect(find.byType(SpinKitCircle), findsOneWidget);
  });

  testWidgets('paginated message cache restores its query limit on remount',
      (tester) async {
    final firstSources = _ChatThreadSources();
    final secondSources = _ChatThreadSources();
    addTearDown(firstSources.close);
    addTearDown(secondSources.close);
    final conversation = _conversationFixture('paginated-cache-chat');
    final messages = List<MessagesRecord>.generate(
      65,
      (index) => _messageFixture(
        conversationRef: conversation.reference,
        messageId: 'page-message-$index',
        text: 'Page message $index',
      ),
      growable: false,
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: firstSources.watchConversation,
          debugMessagesStream: firstSources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
        ),
      ),
    );
    await tester.pump();
    firstSources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    expect(firstSources.messageLimits, <int>[60]);

    firstSources.messages.single.add(
      _messagesState(messages.take(60)),
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, 5000));
    await tester.pump();

    expect(firstSources.messages, hasLength(2));
    expect(firstSources.messageLimits, <int>[60, 120]);

    firstSources.messages.last.add(_messagesState(messages));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: secondSources.watchConversation,
          debugMessagesStream: secondSources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
        ),
      ),
    );
    await tester.pump();
    secondSources.conversations.single.add(_conversationState(conversation));
    await tester.pump();

    expect(secondSources.messageLimits, <int>[120]);
  });

  testWidgets('permission denial revokes retained private chat content',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final conversation = _conversationFixture('revoked-chat');
    final message = _messageFixture(
      conversationRef: conversation.reference,
      messageId: 'private-message',
      text: 'Private retained content',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: sources.watchConversation,
          debugMessagesStream: sources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    sources.messages.single.add(_messagesState(<MessagesRecord>[message]));
    await tester.pump();
    expect(find.text('Private retained content'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Revoked draft');

    sources.conversations.single.addError(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      ),
    );
    await tester.pump();

    expect(find.text('Private retained content'), findsNothing);
    expect(find.byKey(chatThreadConversationInlineErrorKey), findsNothing);
    expect(find.text('У вас нет доступа к этому чату.'), findsOneWidget);

    sources.conversations.single.add(
      _conversationState(conversation, isFromCache: true),
    );
    await tester.pump();

    expect(find.text('У вас нет доступа к этому чату.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);

    sources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    await tester.pump();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('message permission denial clears retained message history',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final conversation = _conversationFixture('messages-revoked-chat');
    final message = _messageFixture(
      conversationRef: conversation.reference,
      messageId: 'revoked-message',
      text: 'Revoked message history',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: sources.watchConversation,
          debugMessagesStream: sources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    sources.messages.single.add(_messagesState(<MessagesRecord>[message]));
    await tester.pump();
    expect(find.text('Revoked message history'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'History access draft');

    sources.messages.single.addError(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Revoked message history'), findsNothing);
    expect(find.byKey(chatThreadMessagesInlineErrorKey), findsNothing);
    expect(
      find.text('У вас нет доступа к сообщениям этого чата.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      isEmpty,
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isFalse,
    );

    sources.messages.single.add(
      _messagesState(<MessagesRecord>[message], isFromCache: true),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('У вас нет доступа к сообщениям этого чата.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isFalse,
    );

    sources.messages.single.add(_messagesState(<MessagesRecord>[message]));
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isTrue,
    );
    expect(find.text('Revoked message history'), findsOneWidget);
  });

  testWidgets('confirmed missing conversation clears retained chat content',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final conversation = _conversationFixture('missing-chat');
    final message = _messageFixture(
      conversationRef: conversation.reference,
      messageId: 'removed-message',
      text: 'Removed conversation content',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          debugConversationStream: sources.watchConversation,
          debugMessagesStream: sources.watchMessages,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: Stream.value('user-a'),
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    sources.messages.single.add(_messagesState(<MessagesRecord>[message]));
    await tester.pump();
    expect(find.text('Removed conversation content'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Removed chat draft');

    sources.conversations.single.add(
      _conversationState(null, isFromCache: true),
    );
    await tester.pump();

    expect(find.text('Removed conversation content'), findsOneWidget);
    expect(find.text('Чат пока недоступен.'), findsNothing);

    sources.conversations.single.add(_conversationState(null));
    await tester.pump();

    expect(find.text('Removed conversation content'), findsNothing);
    expect(find.text('Чат пока недоступен.'), findsOneWidget);

    sources.conversations.single.addError(StateError('offline'));
    await tester.pump();

    expect(find.text('Чат пока недоступен.'), findsOneWidget);
    expect(find.byKey(chatThreadConversationInlineErrorKey), findsOneWidget);
    expect(
      find.text('Не удалось загрузить чат. Попробуйте позже.'),
      findsNothing,
    );

    await tester.tap(find.byKey(chatThreadConversationRetryButtonKey));
    await tester.pump();

    expect(sources.conversations, hasLength(2));
    expect(find.text('Чат пока недоступен.'), findsOneWidget);
    expect(find.byKey(chatThreadConversationInlineErrorKey), findsNothing);

    sources.conversations.last.add(
      _conversationState(conversation, isFromCache: true),
    );
    await tester.pump();

    expect(find.text('Чат пока недоступен.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);

    sources.conversations.last.add(_conversationState(conversation));
    await tester.pump();
    await tester.pump();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('authorized account switch clears retained content and draft',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final conversationStream = sources.watchConversation;
    final messagesStream = sources.watchMessages;
    final conversation = _conversationFixture('owner-chat');
    final message = _messageFixture(
      conversationRef: conversation.reference,
      messageId: 'owner-a-message',
      text: 'Owner A private content',
    );
    final authenticatedOwners = StreamController<String>.broadcast(sync: true);
    addTearDown(authenticatedOwners.close);

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: conversation.reference,
          initialConversation: conversation,
          debugConversationStream: conversationStream,
          debugMessagesStream: messagesStream,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: authenticatedOwners.stream,
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(conversation));
    await tester.pump();
    sources.messages.single.add(_messagesState(<MessagesRecord>[message]));
    await tester.pump();
    expect(find.text('Owner A private content'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Owner A private draft');
    expect(find.text('Owner A private draft'), findsOneWidget);

    authenticatedOwners.add('user-b');
    await tester.pump();

    expect(sources.conversations, hasLength(2));
    expect(sources.conversationOwners, <String>['user-a', 'user-b']);
    expect(find.text('Owner A private content'), findsNothing);
    expect(find.text('Owner A private draft'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byKey(chatThreadConversationInlineErrorKey), findsNothing);

    sources.conversations.first.add(_conversationState(conversation));
    sources.messages.first.add(_messagesState(<MessagesRecord>[message]));
    await tester.pump();

    expect(find.text('Owner A private content'), findsNothing);

    sources.conversations.last.add(
      _conversationState(conversation, ownerUid: 'user-b'),
    );
    await tester.pump();

    expect(sources.messages, hasLength(2));
    expect(sources.messageOwners, <String>['user-a', 'user-b']);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('same-owner path switch rejects old events and clears draft',
      (tester) async {
    final sources = _ChatThreadSources();
    addTearDown(sources.close);
    final conversationStream = sources.watchConversation;
    final messagesStream = sources.watchMessages;
    final ownerStream = Stream<String>.value('user-a');
    final firstConversation = _conversationFixture('first-path-chat');
    final secondConversation = _conversationFixture('second-path-chat');
    final firstMessage = _messageFixture(
      conversationRef: firstConversation.reference,
      messageId: 'first-path-message',
      text: 'First path private content',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: firstConversation.reference,
          debugConversationStream: conversationStream,
          debugMessagesStream: messagesStream,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: ownerStream,
        ),
      ),
    );
    await tester.pump();
    sources.conversations.single.add(_conversationState(firstConversation));
    await tester.pump();
    sources.messages.single.add(_messagesState(<MessagesRecord>[firstMessage]));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'First path draft');

    await tester.pumpWidget(
      _buildTestApp(
        home: ChatThreadWidget(
          conversationRef: secondConversation.reference,
          debugConversationStream: conversationStream,
          debugMessagesStream: messagesStream,
          debugPublicProfileStream: (_) => Stream.value(null),
          debugAuthenticatedOwnerUidStream: ownerStream,
        ),
      ),
    );
    await tester.pump();

    expect(sources.conversations, hasLength(2));
    expect(find.text('First path private content'), findsNothing);
    expect(find.text('First path draft'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);

    sources.conversations.first.add(_conversationState(firstConversation));
    sources.messages.first.add(
      _messagesState(<MessagesRecord>[firstMessage]),
    );
    await tester.pump();

    expect(find.text('First path private content'), findsNothing);

    sources.conversations.last.add(_conversationState(secondConversation));
    await tester.pump();

    expect(sources.messages, hasLength(2));
    expect(find.byType(TextFormField), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      isEmpty,
    );
  });
}

class _ChatThreadSources {
  final conversations = <StreamController<ChatThreadConversationLoadState>>[];
  final messages = <StreamController<ChatThreadMessagesLoadState>>[];
  final conversationOwners = <String>[];
  final messageOwners = <String>[];
  final messageLimits = <int>[];

  Stream<ChatThreadConversationLoadState> watchConversation(
    DocumentReference conversationRef,
    String ownerUid,
  ) {
    final source =
        StreamController<ChatThreadConversationLoadState>.broadcast(sync: true);
    conversations.add(source);
    conversationOwners.add(ownerUid);
    return source.stream;
  }

  Stream<ChatThreadMessagesLoadState> watchMessages(
    DocumentReference conversationRef,
    int limit,
    String ownerUid,
  ) {
    final source =
        StreamController<ChatThreadMessagesLoadState>.broadcast(sync: true);
    messages.add(source);
    messageOwners.add(ownerUid);
    messageLimits.add(limit);
    return source.stream;
  }

  Future<void> close() async {
    for (final source in conversations) {
      await source.close();
    }
    for (final source in messages) {
      await source.close();
    }
  }
}

class _TestAuthUser extends BaseAuthUser {
  _TestAuthUser(this._uid);

  final String _uid;

  @override
  bool get loggedIn => true;

  @override
  bool get emailVerified => true;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(uid: _uid);

  @override
  Future<void> delete() async {}

  @override
  Future<void> updateEmail(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> sendEmailVerification() async {}
}

ChatThreadConversationLoadState _conversationState(
  ConversationsRecord? conversation, {
  String ownerUid = 'user-a',
  bool isFromCache = false,
  bool hasPendingWrites = false,
}) {
  return ChatThreadConversationLoadState(
    ownerUid: ownerUid,
    conversation: conversation,
    isFromCache: isFromCache,
    hasPendingWrites: hasPendingWrites,
  );
}

ChatThreadMessagesLoadState _messagesState(
  Iterable<MessagesRecord> messages, {
  String ownerUid = 'user-a',
  bool isFromCache = false,
  bool hasPendingWrites = false,
  Iterable<String> pendingWriteMessagePaths = const <String>[],
  DateTime? pendingWritesObservedAt,
}) {
  return ChatThreadMessagesLoadState(
    ownerUid: ownerUid,
    messages: messages,
    isFromCache: isFromCache,
    hasPendingWrites: hasPendingWrites,
    pendingWriteMessagePaths: pendingWriteMessagePaths,
    pendingWritesObservedAt: pendingWritesObservedAt,
  );
}

ConversationsRecord _conversationFixture(String id) {
  final currentUserRef = UsersRecord.collection.doc('user-a');
  final partnerRef = UsersRecord.collection.doc('user-b');
  final timestamp = DateTime.utc(2026, 7, 14, 10);
  return ConversationsRecord.getDocumentFromData(
    <String, dynamic>{
      'pairId': id,
      'participantIds': const <String>['user-a', 'user-b'],
      'participantRefs': <DocumentReference>[currentUserRef, partnerRef],
      'participantInfoByUserId': <String, dynamic>{
        'user-b': <String, dynamic>{'displayName': 'Partner'},
      },
      'isUnlocked': true,
      'unlockedAt': timestamp,
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'lastMessageAt': timestamp,
      'lastMessageType': kConversationMessageTypeText,
      'lastMessageText': 'Stable private message',
      'lastMessageSenderId': 'user-a',
      'lastReadAtByUserId': <String, DateTime?>{
        'user-a': timestamp,
      },
    },
    ConversationsRecord.collection.doc(id),
  );
}

MessagesRecord _messageFixture({
  required DocumentReference conversationRef,
  required String messageId,
  required String text,
}) {
  return MessagesRecord.getDocumentFromData(
    <String, dynamic>{
      'senderId': 'user-b',
      'senderRef': UsersRecord.collection.doc('user-b'),
      'type': kConversationMessageTypeText,
      'text': text,
      'createdAt': DateTime.utc(2026, 7, 14, 10),
    },
    MessagesRecord.createDoc(conversationRef, id: messageId),
  );
}

MessagesRecord _pendingMessageFixture({
  required DocumentReference conversationRef,
  required String messageId,
  required String text,
}) {
  return MessagesRecord.getDocumentFromData(
    <String, dynamic>{
      'senderId': 'user-a',
      'senderRef': UsersRecord.collection.doc('user-a'),
      'type': kConversationMessageTypeText,
      'text': text,
    },
    MessagesRecord.createDoc(conversationRef, id: messageId),
  );
}

MessagesRecord _outgoingMessageFixture({
  required DocumentReference messageRef,
  required String text,
  DateTime? createdAt,
}) {
  return MessagesRecord.getDocumentFromData(
    <String, dynamic>{
      'senderId': 'user-a',
      'senderRef': UsersRecord.collection.doc('user-a'),
      'type': kConversationMessageTypeText,
      'text': text,
      if (createdAt != null) 'createdAt': createdAt,
    },
    messageRef,
  );
}
