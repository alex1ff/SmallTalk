import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/components/chat_composer.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/design/expatlio_design.dart';
import 'package:small_talk/shared_pages/events/event_group_chat_widget.dart';
import 'package:small_talk/services/event_actions_repository.dart';
import 'package:small_talk/services/event_group_chat_repository.dart';
import 'package:small_talk/services/ux_session_cache_lifecycle.dart';

const _supportedLocales = [
  Locale('ru'),
  Locale('en'),
];

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  FFLocalizationsDelegate(),
  FallbackMaterialLocalizationDelegate(),
  FallbackCupertinoLocalizationDelegate(),
];

final RegExp _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

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

String? _testAuthenticatedUserId() => currentUser?.uid ?? 'test-user';

Future<void> _ignoreInboxPersistence({
  required String ownerUid,
  required DocumentReference userReference,
  required String eventId,
}) async {}

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
    EventGroupChatRepository.resetRememberedInboxEventIdsForTesting();
    UxSessionCacheLifecycle.debugResetForTesting();
    currentUser = null;
  });

  test('production client ID fallback uses secure randomness', () {
    final source = File(
      'lib/shared_pages/events/event_group_chat_widget.dart',
    ).readAsStringSync();
    final secureFallback = RegExp(
      r'widget\.debugClientMessageIdRandom\s*\?\?\s*math\.Random\.secure\(\)',
    );
    final insecureFallback = RegExp(
      r'widget\.debugClientMessageIdRandom\s*\?\?\s*math\.Random\(\)',
    );

    expect(secureFallback.allMatches(source), hasLength(2));
    expect(insecureFallback.hasMatch(source), isFalse);
  });

  test('post-frame pending prune is owner and generation scoped', () {
    final source = File(
      'lib/shared_pages/events/event_group_chat_widget.dart',
    ).readAsStringSync();
    final pruneStart = source.indexOf(
      'void _schedulePruneConfirmedPendingMessages(',
    );
    final pruneEnd = source.indexOf('Widget _accessDeniedState()', pruneStart);
    expect(pruneStart, greaterThanOrEqualTo(0));
    expect(pruneEnd, greaterThan(pruneStart));
    final pruneSource = source.substring(pruneStart, pruneEnd);

    expect(pruneSource, contains('required String ownerUid'));
    expect(pruneSource, contains('required int actionBoundaryRevision'));
    expect(pruneSource, contains('_activeOwnerUid != ownerUid'));
    expect(pruneSource, contains('_authenticatedOwnerUid() != ownerUid'));
    expect(
      pruneSource,
      contains('_actionBoundaryRevision != actionBoundaryRevision'),
    );
    expect(
      pruneSource.indexOf('_actionBoundaryRevision != actionBoundaryRevision'),
      lessThan(pruneSource.indexOf('setState(()')),
    );
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
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
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

  testWidgets('transient access error keeps confirmed chat and retries',
      (tester) async {
    final access = StreamController<EventChatAccessLoadState>.broadcast(
      sync: true,
    );
    addTearDown(access.close);
    var accessSourceCalls = 0;
    final chatRef = EventChatsRecord.collection.doc('event-access-retry');
    final chat = _chatFixture(
      chatRef: chatRef,
      eventId: 'event-access-retry',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-access-retry',
          debugChatAccessStateStream: (_, __) {
            accessSourceCalls += 1;
            return access.stream;
          },
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          debugAuthenticatedUserIdProvider: () => 'test-user',
          debugInitialAuthenticatedUserId: 'test-user',
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
        ),
      ),
    );
    await tester.pump();
    access.add(
      EventChatAccessLoadState(
        ownerUid: 'test-user',
        chat: chat,
        accessGranted: true,
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(eventGroupChatComposerKey), findsOneWidget);

    access.addError(StateError('offline'));
    await tester.pump();
    expect(find.byKey(eventGroupChatComposerKey), findsOneWidget);
    expect(find.byKey(eventGroupChatAccessInlineErrorKey), findsOneWidget);
    expect(find.byKey(eventGroupChatAccessDeniedKey), findsNothing);

    final callsBeforeRetry = accessSourceCalls;
    await tester.tap(find.byKey(eventGroupChatAccessRetryButtonKey));
    await tester.pump();
    expect(accessSourceCalls, greaterThan(callsBeforeRetry));
    expect(find.byKey(eventGroupChatComposerKey), findsOneWidget);

    access.add(
      EventChatAccessLoadState(
        ownerUid: 'test-user',
        chat: chat,
        accessGranted: true,
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.byKey(eventGroupChatAccessInlineErrorKey), findsNothing);
    expect(find.byKey(eventGroupChatComposerKey), findsOneWidget);
  });

  testWidgets('permission denial revokes previously confirmed chat',
      (tester) async {
    final access = StreamController<EventChatAccessLoadState>.broadcast(
      sync: true,
    );
    addTearDown(access.close);
    final chatRef = EventChatsRecord.collection.doc('event-access-denied');

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-access-denied',
          debugChatAccessStateStream: (_, __) => access.stream,
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          debugAuthenticatedUserIdProvider: () => 'test-user',
          debugInitialAuthenticatedUserId: 'test-user',
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
        ),
      ),
    );
    await tester.pump();
    access.add(
      EventChatAccessLoadState(
        ownerUid: 'test-user',
        chat: _chatFixture(
          chatRef: chatRef,
          eventId: 'event-access-denied',
        ),
        accessGranted: true,
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(eventGroupChatComposerKey), findsOneWidget);

    access.addError(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      ),
    );
    await tester.pump();

    expect(find.byKey(eventGroupChatAccessDeniedKey), findsOneWidget);
    expect(find.byKey(eventGroupChatComposerKey), findsNothing);
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

  testWidgets(
      'cached access cannot cross account boundary before server confirmation',
      (tester) async {
    String? authenticatedUid = 'user-a';
    final authOwners = StreamController<String?>.broadcast(sync: true);
    final accessA = StreamController<EventChatAccessLoadState>.broadcast(
      sync: true,
    );
    final accessB = StreamController<EventChatAccessLoadState>.broadcast(
      sync: true,
    );
    final messagesA = StreamController<EventChatMessagesLoadState>.broadcast(
      sync: true,
    );
    final messagesB = StreamController<EventChatMessagesLoadState>.broadcast(
      sync: true,
    );
    final messageOwners = <String>[];
    var persistenceCalls = 0;
    addTearDown(authOwners.close);
    addTearDown(accessA.close);
    addTearDown(accessB.close);
    addTearDown(messagesA.close);
    addTearDown(messagesB.close);
    final chatRef = EventChatsRecord.collection.doc('event-secure');
    final chat = _chatFixture(chatRef: chatRef, eventId: 'event-secure');
    final messageA = _messageFixture(
      chatRef: chatRef,
      messageId: 'private-a',
      text: 'Private A',
      senderId: 'user-a',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-secure',
          debugChatAccessStateStream: (_, ownerUid) =>
              ownerUid == 'user-a' ? accessA.stream : accessB.stream,
          debugMessagesStateStream: (_, ownerUid) {
            messageOwners.add(ownerUid);
            return ownerUid == 'user-a' ? messagesA.stream : messagesB.stream;
          },
          debugAuthenticatedUserIdProvider: () => authenticatedUid,
          debugAuthenticatedUserIdStream: authOwners.stream,
          debugInitialAuthenticatedUserId: authenticatedUid,
          debugInboxPersistenceInvoker: ({
            required ownerUid,
            required userReference,
            required eventId,
          }) async {
            persistenceCalls += 1;
          },
        ),
      ),
    );
    await tester.pump();

    accessA.add(
      EventChatAccessLoadState(
        ownerUid: 'user-a',
        chat: chat,
        accessGranted: true,
        isFromCache: true,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.byKey(eventGroupChatAccessLoadingKey), findsOneWidget);
    expect(find.byKey(eventGroupChatComposerKey), findsNothing);
    expect(messageOwners, isEmpty);
    expect(persistenceCalls, 0);

    accessA.add(
      EventChatAccessLoadState(
        ownerUid: 'user-a',
        chat: chat,
        accessGranted: true,
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(messageOwners, <String>['user-a']);
    expect(persistenceCalls, 1);
    messagesA.add(
      EventChatMessagesLoadState(
        ownerUid: 'user-a',
        messages: <EventChatMessagesRecord>[messageA],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.text('Private A'), findsOneWidget);

    authenticatedUid = 'user-b';
    authOwners.add('user-b');
    await tester.pump();
    await tester.pump();
    expect(find.text('Private A'), findsNothing);
    expect(find.byKey(eventGroupChatComposerKey), findsNothing);

    accessB.add(
      EventChatAccessLoadState(
        ownerUid: 'user-b',
        chat: chat,
        accessGranted: true,
        isFromCache: true,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.byKey(eventGroupChatAccessLoadingKey), findsOneWidget);
    expect(messageOwners, <String>['user-a']);
    expect(persistenceCalls, 1);

    accessB.add(
      EventChatAccessLoadState(
        ownerUid: 'user-b',
        chat: chat,
        accessGranted: false,
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.byKey(eventGroupChatAccessDeniedKey), findsOneWidget);
    expect(find.byKey(eventGroupChatComposerKey), findsNothing);
    expect(messageOwners, <String>['user-a']);
  });

  testWidgets(
      'raw auth ABA without a frame cannot reuse retained A1 access or messages',
      (tester) async {
    const eventId = 'event-raw-auth-aba';
    String? authenticatedUid = 'user-a';
    currentUser = _TestAuthUser('user-a');
    final authOwners = StreamController<String?>.broadcast(sync: true);
    final accessSources = <StreamController<EventChatAccessLoadState>>[];
    final accessOwners = <String>[];
    final messageSources = <StreamController<EventChatMessagesLoadState>>[];
    final messageOwners = <String>[];
    var persistenceCalls = 0;
    addTearDown(authOwners.close);
    addTearDown(() async {
      for (final source in accessSources) {
        await source.close();
      }
      for (final source in messageSources) {
        await source.close();
      }
    });
    final chatRef = EventChatsRecord.collection.doc(eventId);
    final chat = _chatFixture(chatRef: chatRef, eventId: eventId);
    final a1Message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-a1',
      text: 'Private A1',
      senderId: 'user-a',
    );
    final a2Message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-a2',
      text: 'Fresh A2',
      senderId: 'user-a',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: eventId,
          debugChatAccessStateStream: (_, ownerUid) {
            final source = StreamController<EventChatAccessLoadState>.broadcast(
              sync: true,
            );
            accessOwners.add(ownerUid);
            accessSources.add(source);
            return source.stream;
          },
          debugMessagesStateStream: (_, ownerUid) {
            final source =
                StreamController<EventChatMessagesLoadState>.broadcast(
              sync: true,
            );
            messageOwners.add(ownerUid);
            messageSources.add(source);
            return source.stream;
          },
          debugAuthenticatedUserIdProvider: () => authenticatedUid,
          debugAuthenticatedUserIdStream: authOwners.stream,
          debugInitialAuthenticatedUserId: authenticatedUid,
          debugInboxPersistenceInvoker: ({
            required ownerUid,
            required userReference,
            required eventId,
          }) async {
            persistenceCalls += 1;
          },
        ),
      ),
    );
    await tester.pump();
    expect(accessOwners, <String>['user-a']);

    accessSources.single.add(
      EventChatAccessLoadState(
        ownerUid: 'user-a',
        chat: chat,
        accessGranted: true,
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(messageOwners, <String>['user-a']);
    expect(persistenceCalls, 1);

    messageSources.single.add(
      EventChatMessagesLoadState(
        ownerUid: 'user-a',
        messages: <EventChatMessagesRecord>[a1Message],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.byKey(eventGroupChatComposerKey), findsOneWidget);
    expect(find.text('Private A1'), findsOneWidget);

    authenticatedUid = 'user-b';
    currentUser = _TestAuthUser('user-b');
    authOwners.add(authenticatedUid);
    authenticatedUid = 'user-a';
    currentUser = _TestAuthUser('user-a');
    authOwners.add(authenticatedUid);
    expect(accessOwners, <String>['user-a', 'user-b', 'user-a']);

    accessSources.first.add(
      EventChatAccessLoadState(
        ownerUid: 'user-a',
        chat: chat,
        accessGranted: true,
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    messageSources.first.add(
      EventChatMessagesLoadState(
        ownerUid: 'user-a',
        messages: <EventChatMessagesRecord>[a1Message],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();

    expect(find.byKey(eventGroupChatAccessLoadingKey), findsOneWidget);
    expect(find.byKey(eventGroupChatComposerKey), findsNothing);
    expect(find.text('Private A1'), findsNothing);
    expect(persistenceCalls, 1);

    accessSources.last.add(
      EventChatAccessLoadState(
        ownerUid: 'user-a',
        chat: chat,
        accessGranted: true,
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();

    expect(find.byKey(eventGroupChatComposerKey), findsOneWidget);
    expect(find.text('Private A1'), findsNothing);
    expect(find.byKey(eventGroupChatMessagesLoadingKey), findsOneWidget);
    expect(messageOwners, <String>['user-a', 'user-a']);
    expect(persistenceCalls, 2);

    messageSources.last.add(
      EventChatMessagesLoadState(
        ownerUid: 'user-a',
        messages: <EventChatMessagesRecord>[a2Message],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();

    expect(find.text('Private A1'), findsNothing);
    expect(find.text('Fresh A2'), findsOneWidget);
    expect(find.byKey(eventGroupChatMessagesLoadingKey), findsNothing);
  });

  testWidgets('message data survives error and retry creates a subscription',
      (tester) async {
    final messageSources = <StreamController<EventChatMessagesLoadState>>[];
    addTearDown(() async {
      for (final source in messageSources) {
        await source.close();
      }
    });
    final chatRef = EventChatsRecord.collection.doc('event-message-retry');
    final stableMessage = _messageFixture(
      chatRef: chatRef,
      messageId: 'stable-message',
      text: 'Stable message',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-message-retry',
          chatStream: _allowedChatStream(eventId: 'event-message-retry'),
          debugMessagesStateStream: (_, ownerUid) {
            final source =
                StreamController<EventChatMessagesLoadState>.broadcast(
              sync: true,
            );
            messageSources.add(source);
            return source.stream;
          },
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(messageSources, hasLength(1));

    messageSources.single.add(
      EventChatMessagesLoadState(
        ownerUid: 'test-user',
        messages: const <EventChatMessagesRecord>[],
        isFromCache: true,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.byKey(eventGroupChatMessagesLoadingKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsNothing);

    messageSources.single.add(
      EventChatMessagesLoadState(
        ownerUid: 'test-user',
        messages: <EventChatMessagesRecord>[stableMessage],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    final messageRow = find.byKey(
      eventGroupChatMessageItemKey('stable-message'),
    );
    final rowTopLeft = tester.getTopLeft(messageRow);
    expect(find.text('Stable message'), findsOneWidget);

    messageSources.single.addError(StateError('offline'));
    await tester.pump();
    expect(find.text('Stable message'), findsOneWidget);
    expect(find.byKey(eventGroupChatMessagesInlineErrorKey), findsOneWidget);
    expect(tester.getTopLeft(messageRow), rowTopLeft);

    await tester.tap(find.byKey(eventGroupChatMessagesRetryButtonKey));
    await tester.pump();
    expect(messageSources, hasLength(2));
    expect(find.text('Stable message'), findsOneWidget);
    expect(tester.getTopLeft(messageRow), rowTopLeft);

    messageSources.last.add(
      EventChatMessagesLoadState(
        ownerUid: 'test-user',
        messages: <EventChatMessagesRecord>[stableMessage],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.byKey(eventGroupChatMessagesInlineErrorKey), findsNothing);
    expect(find.text('Stable message'), findsOneWidget);
  });

  testWidgets(
      'non-authoritative message snapshot overlays matching rows until authoritative removal',
      (tester) async {
    const eventId = 'event-message-overlay';
    final messageSources = <StreamController<EventChatMessagesLoadState>>[];
    addTearDown(() async {
      for (final source in messageSources) {
        await source.close();
      }
    });
    final chatRef = EventChatsRecord.collection.doc(eventId);
    final firstMessage = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-1',
      text: 'First message',
      createdAt: DateTime.parse('2026-06-14T10:00:00Z'),
    );
    final secondMessage = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-2',
      text: 'Second message old',
      createdAt: DateTime.parse('2026-06-14T10:01:00Z'),
    );
    final updatedSecondMessage = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-2',
      text: 'Second message updated',
      createdAt: DateTime.parse('2026-06-14T10:01:00Z'),
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: eventId,
          chatStream: _allowedChatStream(eventId: eventId),
          debugMessagesStateStream: (_, __) {
            final source =
                StreamController<EventChatMessagesLoadState>.broadcast(
              sync: true,
            );
            messageSources.add(source);
            return source.stream;
          },
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(messageSources, hasLength(1));

    messageSources.single.add(
      EventChatMessagesLoadState(
        ownerUid: 'test-user',
        messages: <EventChatMessagesRecord>[firstMessage, secondMessage],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();

    final firstRow = find.byKey(eventGroupChatMessageItemKey('message-1'));
    final secondRow = find.byKey(eventGroupChatMessageItemKey('message-2'));
    expect(firstRow, findsOneWidget);
    expect(secondRow, findsOneWidget);
    expect(
      tester.getTopLeft(firstRow).dy,
      lessThan(tester.getTopLeft(secondRow).dy),
    );

    messageSources.single.add(
      EventChatMessagesLoadState(
        ownerUid: 'test-user',
        messages: <EventChatMessagesRecord>[updatedSecondMessage],
        isFromCache: true,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();

    expect(firstRow, findsOneWidget);
    expect(secondRow, findsOneWidget);
    expect(find.text('Second message old'), findsNothing);
    expect(find.text('Second message updated'), findsOneWidget);
    expect(
      tester.getTopLeft(firstRow).dy,
      lessThan(tester.getTopLeft(secondRow).dy),
    );

    messageSources.single.addError(StateError('offline'));
    await tester.pump();
    expect(firstRow, findsOneWidget);
    expect(secondRow, findsOneWidget);
    expect(find.byKey(eventGroupChatMessagesInlineErrorKey), findsOneWidget);

    await tester.tap(find.byKey(eventGroupChatMessagesRetryButtonKey));
    await tester.pump();
    expect(messageSources, hasLength(2));
    expect(firstRow, findsOneWidget);
    expect(secondRow, findsOneWidget);
    expect(find.text('Second message old'), findsNothing);
    expect(find.text('Second message updated'), findsOneWidget);

    messageSources.last.add(
      EventChatMessagesLoadState(
        ownerUid: 'test-user',
        messages: <EventChatMessagesRecord>[updatedSecondMessage],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();

    expect(firstRow, findsNothing);
    expect(secondRow, findsOneWidget);
    expect(find.text('Second message updated'), findsOneWidget);
    expect(find.byKey(eventGroupChatMessagesInlineErrorKey), findsNothing);
  });

  testWidgets(
      'non-authoritative empty keeps confirmed empty or data until authoritative empty',
      (tester) async {
    const eventId = 'event-message-empty-overlay';
    final source = StreamController<EventChatMessagesLoadState>.broadcast(
      sync: true,
    );
    addTearDown(source.close);
    final chatRef = EventChatsRecord.collection.doc(eventId);
    final message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-1',
      text: 'Confirmed message',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: eventId,
          chatStream: _allowedChatStream(eventId: eventId),
          debugMessagesStateStream: (_, __) => source.stream,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    source.add(
      const EventChatMessagesLoadState(
        ownerUid: 'test-user',
        messages: <EventChatMessagesRecord>[],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessagesLoadingKey), findsNothing);

    source.add(
      const EventChatMessagesLoadState(
        ownerUid: 'test-user',
        messages: <EventChatMessagesRecord>[],
        isFromCache: true,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessagesLoadingKey), findsNothing);

    source.add(
      EventChatMessagesLoadState(
        ownerUid: 'test-user',
        messages: <EventChatMessagesRecord>[message],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.text('Confirmed message'), findsOneWidget);
    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsNothing);

    source.add(
      const EventChatMessagesLoadState(
        ownerUid: 'test-user',
        messages: <EventChatMessagesRecord>[],
        isFromCache: false,
        hasPendingWrites: true,
      ),
    );
    await tester.pump();
    expect(find.text('Confirmed message'), findsOneWidget);
    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsNothing);
    expect(find.byKey(eventGroupChatMessagesLoadingKey), findsNothing);

    source.add(
      const EventChatMessagesLoadState(
        ownerUid: 'test-user',
        messages: <EventChatMessagesRecord>[],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.text('Confirmed message'), findsNothing);
    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessagesLoadingKey), findsNothing);
  });

  testWidgets('confirmed empty survives message error and retry',
      (tester) async {
    final source = StreamController<EventChatMessagesLoadState>.broadcast(
      sync: true,
    );
    addTearDown(source.close);
    var subscriptions = 0;
    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-empty-retry',
          chatStream: _allowedChatStream(eventId: 'event-empty-retry'),
          debugMessagesStateStream: (_, ownerUid) {
            subscriptions += 1;
            return source.stream;
          },
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    source.add(
      const EventChatMessagesLoadState(
        ownerUid: 'test-user',
        messages: <EventChatMessagesRecord>[],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsOneWidget);

    source.addError(StateError('offline'));
    await tester.pump();
    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessagesInlineErrorKey), findsOneWidget);

    await tester.tap(find.byKey(eventGroupChatMessagesRetryButtonKey));
    await tester.pump();
    expect(subscriptions, 2);
    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsOneWidget);
  });

  testWidgets('cached and pending message data survive error and retry',
      (tester) async {
    for (final metadata in const <(bool, bool)>[
      (true, false),
      (false, true),
    ]) {
      final eventId = metadata.$1 ? 'event-cached-data' : 'event-pending-data';
      final source = StreamController<EventChatMessagesLoadState>.broadcast(
        sync: true,
      );
      addTearDown(source.close);
      var subscriptions = 0;
      final chatRef = EventChatsRecord.collection.doc(eventId);
      final message = _messageFixture(
        chatRef: chatRef,
        messageId: '$eventId-message',
        text: metadata.$1 ? 'Cached visible' : 'Pending visible',
      );

      await tester.pumpWidget(
        _buildTestApp(
          home: EventGroupChatWidget(
            key: ValueKey<String>(eventId),
            eventId: eventId,
            chatStream: _allowedChatStream(eventId: eventId),
            debugMessagesStateStream: (_, ownerUid) {
              subscriptions += 1;
              return source.stream;
            },
            debugInboxPersistenceInvoker: _ignoreInboxPersistence,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      source.add(
        EventChatMessagesLoadState(
          ownerUid: 'test-user',
          messages: <EventChatMessagesRecord>[message],
          isFromCache: metadata.$1,
          hasPendingWrites: metadata.$2,
        ),
      );
      await tester.pump();
      final row = find.byKey(
        eventGroupChatMessageItemKey('$eventId-message'),
      );
      final initialRect = tester.getRect(row);

      source.addError(StateError('offline'));
      await tester.pump();
      expect(row, findsOneWidget);
      expect(tester.getRect(row), initialRect);

      await tester.tap(find.byKey(eventGroupChatMessagesRetryButtonKey));
      await tester.pump();
      expect(subscriptions, 2);
      expect(row, findsOneWidget);
      expect(tester.getRect(row), initialRect);
    }
  });

  for (final succeeds in const <bool>[true, false]) {
    testWidgets(
        'pending send ${succeeds ? 'success' : 'failure'} survives message retry',
        (tester) async {
      currentUser = _TestAuthUser('viewer-send', displayName: 'Марко');
      final eventId = succeeds ? 'event-send-success' : 'event-send-failure';
      final messageSources = <StreamController<EventChatMessagesLoadState>>[];
      final sendCompleter = Completer<Object?>();
      addTearDown(() async {
        if (!sendCompleter.isCompleted) {
          sendCompleter.complete(<String, dynamic>{
            'messageId': 'message-cleanup',
            'createdAt': '2026-06-14T12:00:00.000Z',
          });
        }
        for (final source in messageSources) {
          await source.close();
        }
      });

      await tester.pumpWidget(
        _buildTestApp(
          home: EventGroupChatWidget(
            eventId: eventId,
            chatStream: _allowedChatStream(eventId: eventId),
            debugMessagesStateStream: (_, __) {
              final source =
                  StreamController<EventChatMessagesLoadState>.broadcast(
                sync: true,
              );
              messageSources.add(source);
              return source.stream;
            },
            debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
            debugInboxPersistenceInvoker: _ignoreInboxPersistence,
            sendMessageInvoker: (_, __) => sendCompleter.future,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(messageSources, hasLength(1));
      messageSources.single.add(
        const EventChatMessagesLoadState(
          ownerUid: 'viewer-send',
          messages: <EventChatMessagesRecord>[],
          isFromCache: false,
          hasPendingWrites: false,
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(eventGroupChatMessageInputKey),
        'Привет',
      );
      await tester.tap(find.byKey(eventGroupChatSendButtonKey));
      await tester.pump();
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

      messageSources.single.addError(StateError('offline'));
      await tester.pump();
      await tester.tap(find.byKey(eventGroupChatMessagesRetryButtonKey));
      await tester.pump();
      expect(messageSources, hasLength(2));
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

      if (succeeds) {
        sendCompleter.complete(<String, dynamic>{
          'messageId': 'message-send-success',
          'createdAt': '2026-06-14T12:00:00.000Z',
        });
      } else {
        sendCompleter.completeError(StateError('send failed'));
      }
      await tester.pumpAndSettle();

      if (succeeds) {
        expect(find.byIcon(Icons.done_rounded), findsOneWidget);
        expect(find.byIcon(Icons.schedule_rounded), findsNothing);
        expect(find.byKey(eventGroupChatSendErrorSnackBarKey), findsNothing);
      } else {
        expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
        expect(find.text('Повторить'), findsWidgets);
        expect(find.byKey(eventGroupChatSendErrorSnackBarKey), findsOneWidget);
      }
    });
  }

  for (final succeeds in const <bool>[true, false]) {
    testWidgets(
        'pending report ${succeeds ? 'success' : 'failure'} survives message retry',
        (tester) async {
      currentUser = _TestAuthUser('viewer-report');
      final eventId =
          succeeds ? 'event-report-success' : 'event-report-failure';
      final messageSources = <StreamController<EventChatMessagesLoadState>>[];
      final reportCompleter = Completer<Object?>();
      var reportCalls = 0;
      addTearDown(() async {
        if (!reportCompleter.isCompleted) {
          reportCompleter.complete(<String, dynamic>{
            'eventId': eventId,
            'messageId': 'message-report',
            'reportId': 'report-cleanup',
            'status': 'submitted',
            'reportedAt': '2026-06-16T10:00:00.000Z',
          });
        }
        for (final source in messageSources) {
          await source.close();
        }
      });
      final chatRef = EventChatsRecord.collection.doc(eventId);
      final message = _messageFixture(
        chatRef: chatRef,
        messageId: 'message-report',
        senderId: 'sender-1',
        text: 'Suspicious message',
      );

      await tester.pumpWidget(
        _buildTestApp(
          home: EventGroupChatWidget(
            eventId: eventId,
            chatStream: _allowedChatStream(eventId: eventId),
            debugMessagesStateStream: (_, __) {
              final source =
                  StreamController<EventChatMessagesLoadState>.broadcast(
                sync: true,
              );
              messageSources.add(source);
              return source.stream;
            },
            debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
            debugInboxPersistenceInvoker: _ignoreInboxPersistence,
            reportMessageInvoker: (_, __) {
              reportCalls += 1;
              return reportCompleter.future;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(messageSources, hasLength(1));
      messageSources.single.add(
        EventChatMessagesLoadState(
          ownerUid: 'viewer-report',
          messages: <EventChatMessagesRecord>[message],
          isFromCache: false,
          hasPendingWrites: false,
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(eventGroupChatMessageReportButtonKey('message-report')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventGroupChatReportReasonKey('spam')));
      await tester.pump();
      await tester.tap(find.byKey(eventGroupChatReportSubmitButtonKey));
      await tester.pump();
      expect(reportCalls, 1);

      messageSources.single.addError(StateError('offline'));
      await tester.pump();
      await tester.tap(find.byKey(eventGroupChatMessagesRetryButtonKey));
      await tester.pump();
      expect(messageSources, hasLength(2));

      await tester.tap(
        find.byKey(eventGroupChatMessageReportButtonKey('message-report')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(eventGroupChatReportDialogKey), findsNothing);
      expect(reportCalls, 1);

      if (succeeds) {
        reportCompleter.complete(<String, dynamic>{
          'eventId': eventId,
          'messageId': 'message-report',
          'reportId': 'report-1',
          'status': 'submitted',
          'reportedAt': '2026-06-16T10:00:00.000Z',
        });
      } else {
        reportCompleter.completeError(StateError('report failed'));
      }
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          succeeds
              ? eventGroupChatReportSuccessSnackBarKey
              : eventGroupChatReportErrorSnackBarKey,
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(eventGroupChatMessageReportButtonKey('message-report')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(eventGroupChatReportDialogKey), findsOneWidget);
    });
  }

  testWidgets('shows composer without trusted access state confirmation',
      (tester) async {
    var messageStreamCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
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
    expect(messageStreamCalls, 1);
  });

  testWidgets('does not require trusted access state after rebuild',
      (tester) async {
    final chatStream = _allowedChatStream();

    Widget buildSubject() => _buildTestApp(
          home: EventGroupChatWidget(
            eventId: 'event-123',
            chatStream: chatStream,
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
          debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
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
          debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
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

  testWidgets(
      'switching owner drops A stream, pending message, and cache before B',
      (tester) async {
    String? authenticatedUid = 'user-a';
    final authOwners = StreamController<String?>.broadcast();
    final ownerAMessages =
        StreamController<List<EventChatMessagesRecord>>.broadcast();
    final ownerBMessages =
        StreamController<List<EventChatMessagesRecord>>.broadcast();
    final sendCompleter = Completer<Object?>();
    addTearDown(authOwners.close);
    addTearDown(ownerAMessages.close);
    addTearDown(ownerBMessages.close);
    addTearDown(() {
      if (!sendCompleter.isCompleted) {
        sendCompleter.complete(<String, dynamic>{
          'messageId': 'late-server-message',
          'createdAt': '2026-06-14T12:00:00.000Z',
        });
      }
    });
    final chatRef = EventChatsRecord.collection.doc('event-owner-boundary');
    final ownerAMessage = _messageFixture(
      chatRef: chatRef,
      messageId: 'owner-a-message',
      senderId: 'user-a',
      text: 'Сообщение A',
    );
    final lateOwnerAMessage = _messageFixture(
      chatRef: chatRef,
      messageId: 'owner-a-late-message',
      senderId: 'user-a',
      text: 'Позднее сообщение A',
    );
    final streamOwners = <String?>[];

    Stream<List<EventChatMessagesRecord>> messagesForActiveOwner(
      DocumentReference _,
    ) {
      final ownerAtCreation = authenticatedUid;
      streamOwners.add(ownerAtCreation);
      return ownerAtCreation == 'user-a'
          ? ownerAMessages.stream
          : ownerBMessages.stream;
    }

    Widget buildChat({required Key key}) => _buildTestApp(
          home: EventGroupChatWidget(
            key: key,
            eventId: 'event-owner-boundary',
            chatStream: _allowedChatStream(eventId: 'event-owner-boundary'),
            messagesStream: messagesForActiveOwner,
            sendMessageInvoker: (_, __) => sendCompleter.future,
            debugAuthenticatedUserIdProvider: () => authenticatedUid,
            debugAuthenticatedUserIdStream: authOwners.stream,
            debugInitialAuthenticatedUserId: authenticatedUid,
            debugInboxPersistenceInvoker: _ignoreInboxPersistence,
          ),
        );

    await tester.pumpWidget(
      buildChat(key: const ValueKey<String>('owner-a-chat')),
    );
    await tester.pump();
    await tester.pump();
    ownerAMessages.add(<EventChatMessagesRecord>[ownerAMessage]);
    await tester.pump();

    expect(find.text('Сообщение A'), findsOneWidget);
    await tester.enterText(
      find.byKey(eventGroupChatMessageInputKey),
      'Ожидающее A',
    );
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pump();
    expect(find.text('Ожидающее A'), findsOneWidget);

    authenticatedUid = 'user-b';
    ownerAMessages.add(<EventChatMessagesRecord>[lateOwnerAMessage]);
    await tester.pump();
    expect(find.text('Позднее сообщение A'), findsNothing);

    authOwners.add(authenticatedUid);
    await tester.pump();
    await tester.pump();

    expect(find.text('Сообщение A'), findsNothing);
    expect(find.text('Ожидающее A'), findsNothing);
    expect(streamOwners, ['user-a', 'user-b']);

    ownerAMessages.add(<EventChatMessagesRecord>[lateOwnerAMessage]);
    await tester.pump();
    expect(find.text('Позднее сообщение A'), findsNothing);

    ownerBMessages.add(const <EventChatMessagesRecord>[]);
    await tester.pump();
    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      buildChat(key: const ValueKey<String>('owner-b-remount')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsOneWidget);
    expect(find.text('Сообщение A'), findsNothing);
    expect(find.text('Позднее сообщение A'), findsNothing);
    expect(find.text('Ожидающее A'), findsNothing);
    expect(streamOwners, ['user-a', 'user-b', 'user-b']);

    ownerBMessages.add(const <EventChatMessagesRecord>[]);
    await tester.pump();
    sendCompleter.complete(<String, dynamic>{
      'messageId': 'late-server-message',
      'createdAt': '2026-06-14T12:00:00.000Z',
    });
    await tester.pump();
    expect(find.text('Ожидающее A'), findsNothing);
  });

  testWidgets('logout drops A stream and pending message before late snapshot',
      (tester) async {
    String? authenticatedUid = 'user-a';
    final authOwners = StreamController<String?>.broadcast();
    final ownerAMessages =
        StreamController<List<EventChatMessagesRecord>>.broadcast();
    final loggedOutMessages =
        StreamController<List<EventChatMessagesRecord>>.broadcast();
    final sendCompleter = Completer<Object?>();
    addTearDown(authOwners.close);
    addTearDown(ownerAMessages.close);
    addTearDown(loggedOutMessages.close);
    addTearDown(() {
      if (!sendCompleter.isCompleted) {
        sendCompleter.complete(<String, dynamic>{
          'messageId': 'late-after-logout',
          'createdAt': '2026-06-14T12:00:00.000Z',
        });
      }
    });
    final chatRef = EventChatsRecord.collection.doc('event-logout-boundary');
    final ownerAMessage = _messageFixture(
      chatRef: chatRef,
      messageId: 'logout-owner-a-message',
      senderId: 'user-a',
      text: 'До выхода',
    );
    final lateOwnerAMessage = _messageFixture(
      chatRef: chatRef,
      messageId: 'logout-owner-a-late-message',
      senderId: 'user-a',
      text: 'После выхода',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-logout-boundary',
          chatStream: _allowedChatStream(eventId: 'event-logout-boundary'),
          messagesStream: (_) => authenticatedUid == 'user-a'
              ? ownerAMessages.stream
              : loggedOutMessages.stream,
          sendMessageInvoker: (_, __) => sendCompleter.future,
          debugAuthenticatedUserIdProvider: () => authenticatedUid,
          debugAuthenticatedUserIdStream: authOwners.stream,
          debugInitialAuthenticatedUserId: authenticatedUid,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    ownerAMessages.add(<EventChatMessagesRecord>[ownerAMessage]);
    await tester.pump();
    await tester.enterText(
      find.byKey(eventGroupChatMessageInputKey),
      'Ожидающее до выхода',
    );
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pump();

    expect(find.text('До выхода'), findsOneWidget);
    expect(find.text('Ожидающее до выхода'), findsOneWidget);

    authenticatedUid = null;
    authOwners.add(null);
    await tester.pump();
    await tester.pump();

    expect(find.text('До выхода'), findsNothing);
    expect(find.text('Ожидающее до выхода'), findsNothing);

    ownerAMessages.add(<EventChatMessagesRecord>[lateOwnerAMessage]);
    await tester.pump();
    expect(find.text('После выхода'), findsNothing);

    loggedOutMessages.add(const <EventChatMessagesRecord>[]);
    await tester.pump();
    expect(find.byKey(eventGroupChatAccessDeniedKey), findsOneWidget);
    expect(find.byKey(eventGroupChatComposerKey), findsNothing);
    expect(find.byKey(eventGroupChatMessagesEmptyKey), findsNothing);
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

  testWidgets('shows the message date and time without a large composer gap',
      (tester) async {
    final chatRef = EventChatsRecord.collection.doc('event-123');
    final message = _messageFixture(
      chatRef: chatRef,
      messageId: 'dated-message',
      text: 'До встречи!',
      createdAt: DateTime(2026, 6, 14, 18, 29),
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
            message,
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(eventGroupChatDateDividerKey('dated-message')),
      findsOneWidget,
    );
    expect(
      find.byKey(eventGroupChatMessageTimestampKey('dated-message')),
      findsOneWidget,
    );

    final messageBottom = tester
        .getRect(find.byKey(eventGroupChatMessageItemKey('dated-message')))
        .bottom;
    final composerTop =
        tester.getRect(find.byKey(eventGroupChatComposerKey)).top;
    expect(
      composerTop - messageBottom,
      inInclusiveRange(0, ExpatlioDesign.space24),
    );
  });

  testWidgets('keeps a short optimistic message bubble compact',
      (tester) async {
    currentUser = _TestAuthUser('uid-1', displayName: 'Haha');
    final sendCompleter = Completer<Object?>();
    String? clientMessageId;
    addTearDown(() {
      if (!sendCompleter.isCompleted) {
        sendCompleter.complete(<String, dynamic>{
          'messageId': 'message-cleanup',
          'createdAt': '2026-06-14T12:00:00.000Z',
        });
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
          sendMessageInvoker: (_, payload) {
            clientMessageId = payload['clientMessageId'] as String;
            return sendCompleter.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventGroupChatMessageInputKey), 'По');
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pump();

    expect(clientMessageId, isNotNull);
    expect(
      tester
          .getSize(
            find.byKey(eventGroupChatMessageBubbleKey(clientMessageId!)),
          )
          .width,
      lessThan(180),
    );
    expect(
      find.descendant(
        of: find.byKey(eventGroupChatComposerKey),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
  });

  testWidgets('keeps composer available for an accessible event chat',
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
          messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
            message,
          ]),
          debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
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

    await tester.enterText(find.byKey(eventGroupChatMessageInputKey), 'Привет');
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pumpAndSettle();

    expect(sendCalls, 1);
  });

  testWidgets('keeps composer visible when chat metadata updates',
      (tester) async {
    final chatController = StreamController<EventChatsRecord?>();
    addTearDown(chatController.close);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: (chatRef) => chatController.stream,
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

    expect(find.byKey(eventGroupChatMessageInputKey), findsOneWidget);
    expect(find.byKey(eventGroupChatSendButtonKey), findsOneWidget);
  });

  testWidgets('keeps composer visible while rendering chat metadata updates',
      (tester) async {
    final chatController = StreamController<EventChatsRecord?>();
    addTearDown(chatController.close);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: (_) => chatController.stream,
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

  testWidgets('account switch while report dialog is open cancels submission',
      (tester) async {
    String? authenticatedUid = 'user-a';
    currentUser = _TestAuthUser('user-a');
    final authOwners = StreamController<String?>.broadcast(sync: true);
    addTearDown(authOwners.close);
    var reportCalls = 0;
    final chatRef = EventChatsRecord.collection.doc('event-report-owner');
    final message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-report-owner',
      senderId: 'sender-1',
      text: 'Suspicious message',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-report-owner',
          chatStream: _allowedChatStream(eventId: 'event-report-owner'),
          messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
            message,
          ]),
          reportMessageInvoker: (_, __) async {
            reportCalls += 1;
            return <String, dynamic>{};
          },
          debugAuthenticatedUserIdProvider: () => authenticatedUid,
          debugAuthenticatedUserIdStream: authOwners.stream,
          debugInitialAuthenticatedUserId: authenticatedUid,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        eventGroupChatMessageReportButtonKey('message-report-owner'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(eventGroupChatReportDialogKey), findsOneWidget);

    authenticatedUid = 'user-b';
    currentUser = _TestAuthUser('user-b');
    authOwners.add(authenticatedUid);
    await tester.pumpAndSettle();
    expect(find.byKey(eventGroupChatReportDialogKey), findsOneWidget);

    await tester.tap(find.byKey(eventGroupChatReportReasonKey('spam')));
    await tester.pump();
    await tester.tap(find.byKey(eventGroupChatReportSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(reportCalls, 0);
    expect(find.byKey(eventGroupChatReportSuccessSnackBarKey), findsNothing);
    expect(find.byKey(eventGroupChatReportErrorSnackBarKey), findsNothing);
  });

  testWidgets('pending report completion cannot affect the next account',
      (tester) async {
    String? authenticatedUid = 'user-a';
    currentUser = _TestAuthUser('user-a');
    final authOwners = StreamController<String?>.broadcast(sync: true);
    final reportCompleter = Completer<Object?>();
    addTearDown(authOwners.close);
    addTearDown(() {
      if (!reportCompleter.isCompleted) {
        reportCompleter.complete(<String, dynamic>{
          'eventId': 'event-report-pending',
          'messageId': 'message-report-pending',
          'reportId': 'report-1',
          'status': 'submitted',
          'reportedAt': '2026-06-16T10:00:00.000Z',
        });
      }
    });
    var reportCalls = 0;
    final chatRef = EventChatsRecord.collection.doc('event-report-pending');
    final message = _messageFixture(
      chatRef: chatRef,
      messageId: 'message-report-pending',
      senderId: 'sender-1',
      text: 'Suspicious message',
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-report-pending',
          chatStream: _allowedChatStream(eventId: 'event-report-pending'),
          messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
            message,
          ]),
          reportMessageInvoker: (_, __) {
            reportCalls += 1;
            return reportCompleter.future;
          },
          debugAuthenticatedUserIdProvider: () => authenticatedUid,
          debugAuthenticatedUserIdStream: authOwners.stream,
          debugInitialAuthenticatedUserId: authenticatedUid,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        eventGroupChatMessageReportButtonKey('message-report-pending'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventGroupChatReportReasonKey('spam')));
    await tester.pump();
    await tester.tap(find.byKey(eventGroupChatReportSubmitButtonKey));
    await tester.pump();
    expect(reportCalls, 1);

    authenticatedUid = 'user-b';
    currentUser = _TestAuthUser('user-b');
    reportCompleter.complete(<String, dynamic>{
      'eventId': 'event-report-pending',
      'messageId': 'message-report-pending',
      'reportId': 'report-1',
      'status': 'submitted',
      'reportedAt': '2026-06-16T10:00:00.000Z',
    });
    await tester.pump();

    expect(find.byKey(eventGroupChatReportSuccessSnackBarKey), findsNothing);
    expect(find.byKey(eventGroupChatReportErrorSnackBarKey), findsNothing);
    authOwners.add(authenticatedUid);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        eventGroupChatMessageReportButtonKey('message-report-pending'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(eventGroupChatReportDialogKey), findsOneWidget);
  });

  for (final staleSucceeds in const <bool>[true, false]) {
    testWidgets(
        'stale report ${staleSucceeds ? 'success' : 'failure'} cannot clear a newer ABA operation',
        (tester) async {
      String? authenticatedUid = 'user-a';
      currentUser = _TestAuthUser('user-a');
      final authOwners = StreamController<String?>.broadcast(sync: true);
      final firstReport = Completer<Object?>();
      final secondReport = Completer<Object?>();
      final reportCompleters = <Completer<Object?>>[
        firstReport,
        secondReport,
      ];
      addTearDown(authOwners.close);
      addTearDown(() {
        for (final completer in reportCompleters) {
          if (!completer.isCompleted) {
            completer.complete(<String, dynamic>{
              'eventId': 'event-report-aba',
              'messageId': 'message-report-aba',
              'reportId': 'report-cleanup',
              'status': 'submitted',
              'reportedAt': '2026-06-16T10:00:00.000Z',
            });
          }
        }
      });
      var reportCalls = 0;
      final chatRef = EventChatsRecord.collection.doc('event-report-aba');
      final message = _messageFixture(
        chatRef: chatRef,
        messageId: 'message-report-aba',
        senderId: 'sender-1',
        text: 'Suspicious message',
      );

      await tester.pumpWidget(
        _buildTestApp(
          home: EventGroupChatWidget(
            eventId: 'event-report-aba',
            chatStream: _allowedChatStream(eventId: 'event-report-aba'),
            messagesStream: (_) => Stream.value(<EventChatMessagesRecord>[
              message,
            ]),
            reportMessageInvoker: (_, __) {
              final completer = reportCompleters[reportCalls];
              reportCalls += 1;
              return completer.future;
            },
            debugAuthenticatedUserIdProvider: () => authenticatedUid,
            debugAuthenticatedUserIdStream: authOwners.stream,
            debugInitialAuthenticatedUserId: authenticatedUid,
            debugInboxPersistenceInvoker: _ignoreInboxPersistence,
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> submitReport() async {
        await tester.tap(
          find.byKey(
            eventGroupChatMessageReportButtonKey('message-report-aba'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(eventGroupChatReportReasonKey('spam')));
        await tester.pump();
        await tester.tap(find.byKey(eventGroupChatReportSubmitButtonKey));
        await tester.pump();
      }

      await submitReport();
      expect(reportCalls, 1);

      authenticatedUid = 'user-b';
      currentUser = _TestAuthUser('user-b');
      authOwners.add(authenticatedUid);
      await tester.pumpAndSettle();
      authenticatedUid = 'user-a';
      currentUser = _TestAuthUser('user-a');
      authOwners.add(authenticatedUid);
      await tester.pumpAndSettle();

      await submitReport();
      expect(reportCalls, 2);

      if (staleSucceeds) {
        firstReport.complete(<String, dynamic>{
          'eventId': 'event-report-aba',
          'messageId': 'message-report-aba',
          'reportId': 'report-1',
          'status': 'submitted',
          'reportedAt': '2026-06-16T10:00:00.000Z',
        });
      } else {
        firstReport.completeError(StateError('stale report failed'));
      }
      await tester.pumpAndSettle();

      expect(find.byKey(eventGroupChatReportSuccessSnackBarKey), findsNothing);
      expect(find.byKey(eventGroupChatReportErrorSnackBarKey), findsNothing);
      await tester.tap(
        find.byKey(
          eventGroupChatMessageReportButtonKey('message-report-aba'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(eventGroupChatReportDialogKey), findsNothing);
      expect(reportCalls, 2);

      secondReport.complete(<String, dynamic>{
        'eventId': 'event-report-aba',
        'messageId': 'message-report-aba',
        'reportId': 'report-2',
        'status': 'submitted',
        'reportedAt': '2026-06-16T10:00:00.000Z',
      });
      await tester.pumpAndSettle();

      expect(
          find.byKey(eventGroupChatReportSuccessSnackBarKey), findsOneWidget);
      expect(find.byKey(eventGroupChatReportErrorSnackBarKey), findsNothing);
      expect(reportCalls, 2);
    });
  }

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
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
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
    expect(payload?['clientMessageId'], matches(_uuidV4Pattern));
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

  testWidgets('grows composer input to four lines with integrated send button',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
          sendMessageInvoker: (_, __) async => <String, dynamic>{
            'messageId': 'message-1',
            'createdAt': '2026-06-14T12:00:00.000Z',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final inputFinder = find.byKey(eventGroupChatMessageInputKey);
    final sendButtonFinder = find.byKey(eventGroupChatSendButtonKey);
    final inputTextField = tester.widget<TextField>(
      find.descendant(
        of: inputFinder,
        matching: find.byType(TextField),
      ),
    );

    expect(inputTextField.minLines, 1);
    expect(inputTextField.maxLines, 4);
    final initialInputHeight = tester.getSize(inputFinder).height;
    expect(initialInputHeight, 42);
    expect(
      tester.getSize(sendButtonFinder),
      const Size.square(44),
    );
    expect(
      tester.getSize(find.byKey(chatComposerSendCircleKey)),
      const Size.square(36),
    );

    await tester.enterText(
      inputFinder,
      List<String>.filled(30, 'Очень длинное сообщение').join(' '),
    );
    await tester.pump();

    expect(tester.getSize(inputFinder).height, greaterThan(initialInputHeight));
    expect(
      tester.getSize(sendButtonFinder),
      const Size.square(44),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not keep bottom safe area while keyboard is open',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget buildChatWithMediaQuery({required bool keyboardOpen}) {
      return _buildTestApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            viewPadding: const EdgeInsets.only(bottom: 34),
            padding: EdgeInsets.only(bottom: keyboardOpen ? 0 : 34),
            viewInsets: EdgeInsets.only(bottom: keyboardOpen ? 320 : 0),
          ),
          child: EventGroupChatWidget(
            eventId: 'event-123',
            chatStream: _allowedChatStream(),
            messagesStream: (_) =>
                Stream.value(const <EventChatMessagesRecord>[]),
            debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
            debugInboxPersistenceInvoker: _ignoreInboxPersistence,
            sendMessageInvoker: (_, __) async => <String, dynamic>{
              'messageId': 'message-1',
              'createdAt': '2026-06-14T12:00:00.000Z',
            },
          ),
        ),
      );
    }

    await tester.pumpWidget(
      buildChatWithMediaQuery(keyboardOpen: false),
    );
    await tester.pumpAndSettle();
    final composerFinder = find.byKey(eventGroupChatComposerKey);
    final inputFinder = find.byKey(eventGroupChatMessageInputKey);
    final sendButtonFinder = find.byKey(eventGroupChatSendButtonKey);
    final scaffoldFinder = find.byType(Scaffold);
    final closedScaffoldRect = tester.getRect(scaffoldFinder);
    final closedComposerRect = tester.getRect(composerFinder);
    final closedInputRect = tester.getRect(inputFinder);
    final closedSendButtonRect = tester.getRect(sendButtonFinder);

    expect(
      closedComposerRect.height,
      ExpatlioDesign.space8 + 44 + ExpatlioDesign.space8 + 34,
    );
    expect(closedInputRect.height, 42);
    expect(
      closedSendButtonRect.size,
      const Size.square(44),
    );
    expect(
      closedComposerRect.bottom - closedInputRect.bottom,
      ExpatlioDesign.space8 + 34,
    );
    expect(closedComposerRect.bottom, closedScaffoldRect.bottom);

    await tester.pumpWidget(
      buildChatWithMediaQuery(keyboardOpen: true),
    );
    await tester.pumpAndSettle();
    final openScaffoldRect = tester.getRect(scaffoldFinder);
    final openComposerRect = tester.getRect(composerFinder);
    final openInputRect = tester.getRect(inputFinder);
    final openSendButtonRect = tester.getRect(sendButtonFinder);

    expect(
      openComposerRect.height,
      ExpatlioDesign.space8 + 44 + ExpatlioDesign.space8,
    );
    expect(openInputRect.size, closedInputRect.size);
    expect(openSendButtonRect.size, closedSendButtonRect.size);
    expect(
      openComposerRect.bottom - openInputRect.bottom,
      ExpatlioDesign.space8,
    );
    expect(
      closedComposerRect.bottom - openComposerRect.bottom,
      320,
    );
    expect(openComposerRect.bottom, openScaffoldRect.bottom - 320);
    expect(
      openInputRect.shift(-openComposerRect.topLeft),
      closedInputRect.shift(-closedComposerRect.topLeft),
    );
    expect(
      openSendButtonRect.shift(-openComposerRect.topLeft),
      closedSendButtonRect.shift(-closedComposerRect.topLeft),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps composer editable while send is pending', (tester) async {
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
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
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
    expect(
      find.descendant(
        of: find.byKey(eventGroupChatComposerKey),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );

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

  testWidgets('allows the next optimistic send while a request is pending',
      (tester) async {
    currentUser = _TestAuthUser('uid-1', displayName: 'Марко');
    final sendCompleters = <Completer<Object?>>[
      Completer<Object?>(),
      Completer<Object?>(),
    ];
    final clientMessageIds = <String>[];
    var sendCalls = 0;
    addTearDown(() {
      for (var index = 0; index < sendCompleters.length; index += 1) {
        final completer = sendCompleters[index];
        if (!completer.isCompleted) {
          completer.complete(<String, dynamic>{
            'messageId': 'message-cleanup-$index',
            'createdAt': '2026-06-14T12:00:00.000Z',
          });
        }
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-two-sends',
          chatStream: _allowedChatStream(eventId: 'event-two-sends'),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
          sendMessageInvoker: (_, payload) {
            clientMessageIds.add(payload['clientMessageId'] as String);
            final completer = sendCompleters[sendCalls];
            sendCalls += 1;
            return completer.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(eventGroupChatMessageInputKey),
      'Первое',
    );
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(eventGroupChatMessageInputKey),
      'Второе',
    );
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pump();

    expect(sendCalls, 2);
    expect(clientMessageIds, hasLength(2));
    expect(clientMessageIds[0], isNot(clientMessageIds[1]));
    expect(find.byIcon(Icons.schedule_rounded), findsNWidgets(2));
    expect(
      tester
          .widget<TextFormField>(find.byKey(eventGroupChatMessageInputKey))
          .controller
          ?.text,
      isEmpty,
    );
    expect(
      find.descendant(
        of: find.byKey(eventGroupChatComposerKey),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );

    sendCompleters[0].complete(<String, dynamic>{
      'messageId': 'message-1',
      'createdAt': '2026-06-14T12:00:00.000Z',
    });
    await tester.pump();

    expect(sendCalls, 2);
    expect(clientMessageIds, hasLength(2));
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.byIcon(Icons.done_rounded), findsOneWidget);

    sendCompleters[1].complete(<String, dynamic>{
      'messageId': 'message-2',
      'createdAt': '2026-06-14T12:01:00.000Z',
    });
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    expect(find.byIcon(Icons.done_rounded), findsNWidgets(2));
    expect(find.byKey(eventGroupChatSendErrorSnackBarKey), findsNothing);
  });

  testWidgets('seeded client ID generation is reproducible across widgets',
      (tester) async {
    currentUser = _TestAuthUser('uid-1');
    Future<List<String>> generateSequence(int instance) async {
      final clientMessageIds = <String>[];
      final eventId = 'event-seeded-client-ids-$instance';
      await tester.pumpWidget(
        _buildTestApp(
          home: EventGroupChatWidget(
            key: ValueKey<String>('seeded-client-id-widget-$instance'),
            eventId: eventId,
            chatStream: _allowedChatStream(eventId: eventId),
            messagesStream: (_) =>
                Stream.value(const <EventChatMessagesRecord>[]),
            debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
            debugInboxPersistenceInvoker: _ignoreInboxPersistence,
            debugClientMessageIdRandom: math.Random(42),
            sendMessageInvoker: (_, payload) async {
              final clientMessageId = payload['clientMessageId'] as String;
              clientMessageIds.add(clientMessageId);
              return <String, dynamic>{
                'messageId': 'server-$clientMessageId',
                'createdAt': '2026-06-14T12:00:00.000Z',
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final text in <String>['Первое', 'Второе']) {
        await tester.enterText(
          find.byKey(eventGroupChatMessageInputKey),
          text,
        );
        await tester.tap(find.byKey(eventGroupChatSendButtonKey));
        await tester.pumpAndSettle();
      }
      return List<String>.unmodifiable(clientMessageIds);
    }

    final firstSequence = await generateSequence(1);
    final secondSequence = await generateSequence(2);

    expect(firstSequence, hasLength(2));
    expect(secondSequence, firstSequence);
    for (final sequence in <List<String>>[firstSequence, secondSequence]) {
      expect(sequence[0], isNot(sequence[1]));
      expect(sequence, everyElement(matches(_uuidV4Pattern)));
    }
  });

  testWidgets('pending sender does not reuse another auth owner profile',
      (tester) async {
    currentUser = _TestAuthUser('user-a', displayName: 'Секрет A');
    final sendCompleter = Completer<Object?>();
    addTearDown(() {
      if (!sendCompleter.isCompleted) {
        sendCompleter.complete(<String, dynamic>{
          'messageId': 'message-b',
          'createdAt': '2026-06-14T12:00:00.000Z',
        });
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          debugAuthenticatedUserIdProvider: () => 'user-b',
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
          sendMessageInvoker: (_, __) => sendCompleter.future,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventGroupChatMessageInputKey), 'Привет');
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pump();

    expect(find.text('Секрет A'), findsNothing);
    expect(find.text('Участник'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
  });

  testWidgets(
      'drops late send completion after account switch without recontamination',
      (tester) async {
    var authenticatedUid = 'user-a';
    currentUser = _TestAuthUser('user-a', displayName: 'Марко');
    UxSessionCacheLifecycle.updateAuthenticatedUser(authenticatedUid);
    final sendCompleter = Completer<Object?>();
    final persistedTargets = <String>[];
    addTearDown(() {
      if (!sendCompleter.isCompleted) {
        sendCompleter.complete(<String, dynamic>{
          'messageId': 'message-late',
          'createdAt': '2026-06-14T12:00:00.000Z',
        });
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          sendMessageInvoker: (_, __) => sendCompleter.future,
          debugAuthenticatedUserIdProvider: () => authenticatedUid,
          debugInboxPersistenceInvoker: ({
            required String ownerUid,
            required DocumentReference userReference,
            required String eventId,
          }) async {
            persistedTargets.add('$ownerUid|${userReference.path}|$eventId');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(persistedTargets, ['user-a|users/user-a|event-123']);
    expect(
      EventGroupChatRepository.rememberedInboxEventIdsForOwner('user-a'),
      ['event-123'],
    );

    await tester.enterText(find.byKey(eventGroupChatMessageInputKey), 'Привет');
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pump();

    authenticatedUid = 'user-b';
    currentUser = _TestAuthUser('user-b');
    UxSessionCacheLifecycle.updateAuthenticatedUser(authenticatedUid);
    sendCompleter.complete(<String, dynamic>{
      'messageId': 'message-late',
      'createdAt': '2026-06-14T12:00:00.000Z',
    });
    await tester.pump();

    expect(
      EventGroupChatRepository.rememberedInboxEventIdsForOwner('user-a'),
      isEmpty,
    );
    expect(
      EventGroupChatRepository.rememberedInboxEventIdsForOwner('user-b'),
      isEmpty,
    );
    expect(persistedTargets, ['user-a|users/user-a|event-123']);
    expect(
      persistedTargets.where((target) => target.contains('user-b')),
      isEmpty,
    );
    expect(find.byIcon(Icons.done_rounded), findsNothing);
  });

  for (final staleSucceeds in const <bool>[true, false]) {
    testWidgets(
        'stale send ${staleSucceeds ? 'success' : 'failure'} cannot affect a newer ABA send',
        (tester) async {
      final eventId =
          staleSucceeds ? 'event-send-aba-success' : 'event-send-aba-failure';
      String? authenticatedUid = 'user-a';
      currentUser = _TestAuthUser('user-a', displayName: 'Марко');
      final authOwners = StreamController<String?>.broadcast(sync: true);
      final sendCompleters = <Completer<Object?>>[
        Completer<Object?>(),
        Completer<Object?>(),
      ];
      final clientMessageIds = <String>[];
      var sendCalls = 0;
      addTearDown(authOwners.close);
      addTearDown(() {
        for (var index = 0; index < sendCompleters.length; index += 1) {
          final completer = sendCompleters[index];
          if (!completer.isCompleted) {
            completer.complete(<String, dynamic>{
              'messageId': 'message-cleanup-$index',
              'createdAt': '2026-06-14T12:00:00.000Z',
            });
          }
        }
      });

      await tester.pumpWidget(
        _buildTestApp(
          home: EventGroupChatWidget(
            eventId: eventId,
            chatStream: _allowedChatStream(eventId: eventId),
            messagesStream: (_) =>
                Stream.value(const <EventChatMessagesRecord>[]),
            sendMessageInvoker: (_, payload) {
              clientMessageIds.add(payload['clientMessageId'] as String);
              final completer = sendCompleters[sendCalls];
              sendCalls += 1;
              return completer.future;
            },
            debugAuthenticatedUserIdProvider: () => authenticatedUid,
            debugAuthenticatedUserIdStream: authOwners.stream,
            debugInitialAuthenticatedUserId: authenticatedUid,
            debugInboxPersistenceInvoker: _ignoreInboxPersistence,
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> send(String text) async {
        await tester.enterText(
          find.byKey(eventGroupChatMessageInputKey),
          text,
        );
        await tester.tap(find.byKey(eventGroupChatSendButtonKey));
        await tester.pump();
      }

      await send('Старое A1');
      expect(sendCalls, 1);

      authenticatedUid = 'user-b';
      currentUser = _TestAuthUser('user-b');
      authOwners.add(authenticatedUid);
      await tester.pumpAndSettle();
      authenticatedUid = 'user-a';
      currentUser = _TestAuthUser('user-a', displayName: 'Марко');
      authOwners.add(authenticatedUid);
      await tester.pumpAndSettle();

      await send('Новое A2');
      expect(sendCalls, 2);
      expect(clientMessageIds[0], isNot(clientMessageIds[1]));
      expect(find.text('Старое A1'), findsNothing);
      expect(find.text('Новое A2'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

      if (staleSucceeds) {
        sendCompleters[0].complete(<String, dynamic>{
          'messageId': 'message-stale',
          'createdAt': '2026-06-14T12:00:00.000Z',
        });
      } else {
        sendCompleters[0].completeError(StateError('stale send failed'));
      }
      await tester.pump();

      expect(find.byKey(eventGroupChatSendErrorSnackBarKey), findsNothing);
      expect(find.text('Новое A2'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.byIcon(Icons.done_rounded), findsNothing);

      sendCompleters[1].complete(<String, dynamic>{
        'messageId': 'message-current',
        'createdAt': '2026-06-14T12:01:00.000Z',
      });
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);
      expect(find.byKey(eventGroupChatSendErrorSnackBarKey), findsNothing);
      expect(sendCalls, 2);
    });
  }

  testWidgets(
      'drops late retry completion after logout without recontamination',
      (tester) async {
    String? authenticatedUid = 'user-a';
    currentUser = _TestAuthUser('user-a', displayName: 'Марко');
    UxSessionCacheLifecycle.updateAuthenticatedUser(authenticatedUid);
    final retryCompleter = Completer<Object?>();
    final persistedTargets = <String>[];
    var sendCalls = 0;
    addTearDown(() {
      if (!retryCompleter.isCompleted) {
        retryCompleter.complete(<String, dynamic>{
          'messageId': 'message-retry-late',
          'createdAt': '2026-06-14T12:00:00.000Z',
        });
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          sendMessageInvoker: (_, __) {
            sendCalls += 1;
            if (sendCalls == 1) {
              return Future<Object?>.error(StateError('send failed'));
            }
            return retryCompleter.future;
          },
          debugAuthenticatedUserIdProvider: () => authenticatedUid,
          debugInboxPersistenceInvoker: ({
            required String ownerUid,
            required DocumentReference userReference,
            required String eventId,
          }) async {
            persistedTargets.add('$ownerUid|${userReference.path}|$eventId');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventGroupChatMessageInputKey), 'Привет');
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pump();
    authenticatedUid = null;
    currentUser = null;
    UxSessionCacheLifecycle.updateAuthenticatedUser(null);
    retryCompleter.complete(<String, dynamic>{
      'messageId': 'message-retry-late',
      'createdAt': '2026-06-14T12:00:00.000Z',
    });
    await tester.pumpAndSettle();

    expect(sendCalls, 2);
    expect(
      EventGroupChatRepository.rememberedInboxEventIdsForOwner('user-a'),
      isEmpty,
    );
    expect(persistedTargets, ['user-a|users/user-a|event-123']);
    expect(find.byIcon(Icons.done_rounded), findsNothing);
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
          messagesStream: (_) => messagesController.stream,
          debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
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
          messagesStream: (_) => messagesController.stream,
          debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
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

  testWidgets(
      'post-frame prune cannot remove pending after direct owner boundary',
      (tester) async {
    const eventId = 'event-prune-owner-boundary';
    var authenticatedUid = 'user-a';
    currentUser = _TestAuthUser('user-a');
    final messages = StreamController<EventChatMessagesLoadState>.broadcast(
      sync: true,
    );
    String? clientMessageId;
    addTearDown(messages.close);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: eventId,
          chatStream: _allowedChatStream(eventId: eventId),
          debugMessagesStateStream: (_, __) => messages.stream,
          debugAuthenticatedUserIdProvider: () => authenticatedUid,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
          sendMessageInvoker: (_, payload) async {
            clientMessageId = payload['clientMessageId'] as String;
            throw StateError('network response lost after write');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    messages.add(
      const EventChatMessagesLoadState(
        ownerUid: 'user-a',
        messages: <EventChatMessagesRecord>[],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(eventGroupChatMessageInputKey),
      'Сохранить pending',
    );
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pumpAndSettle();

    expect(clientMessageId, isNotNull);
    final retryButton = eventGroupChatMessageRetryButtonKey(clientMessageId!);
    expect(find.byKey(retryButton), findsOneWidget);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      authenticatedUid = 'user-b';
      currentUser = _TestAuthUser('user-b');
    });
    messages.add(
      EventChatMessagesLoadState(
        ownerUid: 'user-a',
        messages: <EventChatMessagesRecord>[
          _messageFixture(
            chatRef: EventChatsRecord.collection.doc(eventId),
            messageId: clientMessageId!,
            senderId: 'user-a',
            text: 'Сохранить pending',
          ),
        ],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(authenticatedUid, 'user-b');

    authenticatedUid = 'user-a';
    currentUser = _TestAuthUser('user-a');
    messages.add(
      const EventChatMessagesLoadState(
        ownerUid: 'user-a',
        messages: <EventChatMessagesRecord>[],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();

    expect(find.text('Сохранить pending'), findsOneWidget);
    expect(find.byKey(retryButton), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('does not call send callable for blank event chat messages',
      (tester) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
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

  testWidgets('does not send when the direct auth owner is unavailable',
      (tester) async {
    currentUser = _TestAuthUser('stale-user');
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          debugAuthenticatedUserIdProvider: () => null,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
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

    expect(sendCalls, 0);
    expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    expect(find.byKey(eventGroupChatAccessDeniedKey), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageInputKey), findsNothing);
    expect(find.byKey(eventGroupChatSendButtonKey), findsNothing);
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
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
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

  testWidgets('two retry taps without a frame invoke one pending retry',
      (tester) async {
    currentUser = _TestAuthUser('uid-1');
    final retryCompleter = Completer<Object?>();
    final payloads = <Map<String, dynamic>>[];
    var sendCalls = 0;
    addTearDown(() {
      if (!retryCompleter.isCompleted) {
        retryCompleter.complete(<String, dynamic>{
          'messageId': 'message-cleanup',
          'createdAt': '2026-06-14T12:00:00.000Z',
        });
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-double-retry',
          chatStream: _allowedChatStream(eventId: 'event-double-retry'),
          messagesStream: (_) =>
              Stream.value(const <EventChatMessagesRecord>[]),
          debugAuthenticatedUserIdProvider: _testAuthenticatedUserId,
          debugInboxPersistenceInvoker: _ignoreInboxPersistence,
          sendMessageInvoker: (_, payload) {
            sendCalls += 1;
            payloads.add(payload);
            if (sendCalls == 1) {
              return Future<Object?>.error(StateError('send failed'));
            }
            return retryCompleter.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(eventGroupChatMessageInputKey),
      'Повторить один раз',
    );
    await tester.tap(find.byKey(eventGroupChatSendButtonKey));
    await tester.pumpAndSettle();

    final clientMessageId = payloads.single['clientMessageId'] as String;
    final retryButton = find.byKey(
      eventGroupChatMessageRetryButtonKey(clientMessageId),
    );
    expect(retryButton, findsOneWidget);

    await tester.tap(retryButton);
    await tester.tap(retryButton);
    expect(sendCalls, 2);
    expect(payloads, hasLength(2));
    expect(payloads[1]['clientMessageId'], clientMessageId);

    await tester.pump();
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.byKey(eventGroupChatMessageRetryButtonKey(clientMessageId)),
        findsNothing);

    retryCompleter.complete(<String, dynamic>{
      'messageId': 'message-retry',
      'createdAt': '2026-06-14T12:00:00.000Z',
    });
    await tester.pumpAndSettle();

    expect(sendCalls, 2);
    expect(find.byIcon(Icons.done_rounded), findsOneWidget);
  });

  testWidgets('shows error state when event chat messages fail to load',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventGroupChatWidget(
          eventId: 'event-123',
          chatStream: _allowedChatStream(),
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
