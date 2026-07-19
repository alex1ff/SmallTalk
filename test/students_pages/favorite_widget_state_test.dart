import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/components/empty/empty_widget.dart';
import 'package:small_talk/components/ux_error_state.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/services/event_group_chat_repository.dart';
import 'package:small_talk/services/ux_session_cache_lifecycle.dart';
import 'package:small_talk/students_pages/favorite/favorite_chat_source_state.dart';
import 'package:small_talk/students_pages/favorite/favorite_widget.dart';

const _supportedLocales = <Locale>[
  Locale('ru'),
  Locale('en'),
];

const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  FFLocalizationsDelegate(),
  FallbackMaterialLocalizationDelegate(),
  FallbackCupertinoLocalizationDelegate(),
];

class _TestFirebaseAuthPlatform extends FirebaseAuthPlatform {
  _TestFirebaseAuthPlatform({FirebaseApp? app}) : super(appInstance: app);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) =>
      _TestFirebaseAuthPlatform(app: app);

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) {
    this.languageCode = languageCode;
    return this;
  }

  @override
  UserPlatform? get currentUser => null;

  @override
  set currentUser(UserPlatform? userPlatform) {}

  @override
  String? languageCode;

  @override
  Stream<UserPlatform?> authStateChanges() =>
      const Stream<UserPlatform?>.empty();

  @override
  Stream<UserPlatform?> idTokenChanges() => const Stream<UserPlatform?>.empty();

  @override
  Stream<UserPlatform?> userChanges() => const Stream<UserPlatform?>.empty();
}

class _FavoriteSources {
  _FavoriteSources();

  final String initialUid = 'user-a';
  String authenticatedUid = 'user-a';
  final auth = StreamController<String>.broadcast(sync: true);
  final Map<String, StreamController<FavoriteFriendsLoadState>> friends = {};
  final Map<String, StreamController<FavoriteConversationsLoadState>>
      conversations = {};
  final Map<String, StreamController<FavoriteEventChatsLoadState>> eventChats =
      {};
  final Map<String, int> friendsListenCounts = {};
  final Map<String, int> conversationsListenCounts = {};
  final Map<String, int> eventChatsListenCounts = {};

  StreamController<FavoriteFriendsLoadState> friendsFor(String uid) =>
      friends.putIfAbsent(
        uid,
        () => StreamController<FavoriteFriendsLoadState>.broadcast(
          onListen: () => friendsListenCounts.update(
            uid,
            (count) => count + 1,
            ifAbsent: () => 1,
          ),
          sync: true,
        ),
      );

  StreamController<FavoriteConversationsLoadState> conversationsFor(
    String uid,
  ) =>
      conversations.putIfAbsent(
        uid,
        () => StreamController<FavoriteConversationsLoadState>.broadcast(
          onListen: () => conversationsListenCounts.update(
            uid,
            (count) => count + 1,
            ifAbsent: () => 1,
          ),
          sync: true,
        ),
      );

  StreamController<FavoriteEventChatsLoadState> eventChatsFor(String uid) =>
      eventChats.putIfAbsent(
        uid,
        () => StreamController<FavoriteEventChatsLoadState>.broadcast(
          onListen: () => eventChatsListenCounts.update(
            uid,
            (count) => count + 1,
            ifAbsent: () => 1,
          ),
          sync: true,
        ),
      );

  FavoriteWidget widget({
    FavoriteUserProfileLoader? profileLoader,
    FavoriteConversationUnreadCountSource? conversationUnreadCountSource,
    FavoriteEventLoader? eventLoader,
    FavoriteLatestEventChatMessageSource? latestMessageSource,
    FavoriteInboxChatsWatcher? inboxChatsWatcher,
    FavoriteHiddenChatWriter? hiddenChatWriter,
    FavoriteInaccessibleEventChatIdWriter? inaccessibleEventChatIdWriter,
    FavoriteConversationOpener? conversationOpener,
    FavoriteEventChatOpener? eventChatOpener,
    bool useDebugEventChatsSource = true,
  }) =>
      FavoriteWidget(
        debugAuthUidStream: auth.stream,
        debugInitialAuthUid: initialUid,
        debugFriendsSource: (uid) => friendsFor(uid).stream,
        debugConversationsSource: (uid) => conversationsFor(uid).stream,
        debugConversationUnreadCountSource: conversationUnreadCountSource,
        debugEventChatsSource: useDebugEventChatsSource
            ? (uid) => eventChatsFor(uid).stream
            : null,
        debugInboxChatsWatcher: inboxChatsWatcher,
        debugLatestEventChatMessageSource: latestMessageSource,
        debugUserProfileLoader: profileLoader ?? (_) async => null,
        debugEventLoader: eventLoader,
        debugAuthenticatedUidReader: () => authenticatedUid,
        debugHiddenChatWriter: hiddenChatWriter,
        debugInaccessibleEventChatIdWriter: inaccessibleEventChatIdWriter,
        debugConversationOpener: conversationOpener,
        debugEventChatOpener: eventChatOpener,
      );

  void switchAuthenticatedUid(String uid) {
    authenticatedUid = uid;
    auth.add(uid);
  }

  Future<void> dispose() async {
    await auth.close();
    for (final controller in friends.values) {
      await controller.close();
    }
    for (final controller in conversations.values) {
      await controller.close();
    }
    for (final controller in eventChats.values) {
      await controller.close();
    }
  }
}

Widget _testApp(Widget home, {Locale locale = const Locale('ru')}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: _supportedLocales,
      localizationsDelegates: _localizationsDelegates,
      home: home,
    );

FavoriteFriendsLoadState _friendsState({
  required String ownerUid,
  List<DocumentReference> friends = const <DocumentReference>[],
  Object? rawHiddenChatKeys,
  required bool authoritative,
}) =>
    FavoriteFriendsLoadState(
      ownerUid: ownerUid,
      friends: friends,
      rawHiddenChatKeys: rawHiddenChatKeys,
      friendsAreAuthoritative: authoritative,
      hiddenChatKeysAreKnown: authoritative,
      hiddenChatKeysAreAuthoritative: authoritative,
    );

ConversationsRecord _conversation({
  required String id,
  required String ownerUid,
  required String partnerUid,
  DateTime? lastMessageAt,
  String? lastMessageSenderId,
}) =>
    ConversationsRecord.getDocumentFromData(
      <String, dynamic>{
        'pairId': id,
        'participantIds': <String>[ownerUid, partnerUid],
        'participantRefs': <DocumentReference>[
          UsersRecord.collection.doc(ownerUid),
          UsersRecord.collection.doc(partnerUid),
        ],
        'isUnlocked': true,
        'unlockedAt': DateTime.parse('2026-07-13T10:00:00Z'),
        'lastMessageAt':
            lastMessageAt ?? DateTime.parse('2026-07-13T10:01:00Z'),
        'lastMessageType': kConversationMessageTypeText,
        'lastMessageText': 'Hello',
        'lastMessageSenderId': lastMessageSenderId ?? ownerUid,
      },
      ConversationsRecord.collection.doc(id),
    );

EventChatsRecord _eventChat(
  String eventId, {
  DateTime? updatedAt,
}) =>
    EventChatsRecord.getDocumentFromData(
      <String, dynamic>{
        'eventId': eventId,
        'readAccessUserIds': <String>['user-a'],
        'createdAt': DateTime.parse('2026-07-13T09:00:00Z'),
        'updatedAt': updatedAt ?? DateTime.parse('2026-07-13T09:00:00Z'),
      },
      EventChatsRecord.collection.doc(eventId),
    );

EventsRecord _event(String eventId, {required String title}) =>
    EventsRecord.getDocumentFromData(
      <String, dynamic>{'title': title},
      EventsRecord.collection.doc(eventId),
    );

EventChatMessagesRecord _eventMessage({
  required EventChatsRecord chat,
  required String id,
  required String text,
  required DateTime createdAt,
}) =>
    EventChatMessagesRecord.getDocumentFromData(
      <String, dynamic>{
        'senderId': 'friend-event',
        'senderDisplayName': 'Event friend',
        'text': text,
        'createdAt': createdAt,
      },
      EventChatMessagesRecord.createDoc(chat.reference, id: id),
    );

UserPublicProfilesRecord _profile(String id, {required String displayName}) =>
    UserPublicProfilesRecord.getDocumentFromData(
      <String, dynamic>{
        'userId': id,
        'display_name': displayName,
        'photo_url': '',
      },
      UserPublicProfilesRecord.collection.doc(id),
    );

Finder _conversationRow(String conversationId) => find.byKey(
      ValueKey<String>('favorite_chat_conversation:$conversationId'),
    );

void _invokeConversationDismiss(
  WidgetTester tester,
  String conversationId,
) {
  final semantics = tester.widget<Semantics>(
    find.byKey(
      favoriteChatDismissActionKey('conversation:$conversationId'),
    ),
  );
  semantics.properties.onDismiss!.call();
}

Future<void> _mount(
  WidgetTester tester,
  _FavoriteSources sources, {
  Locale locale = const Locale('ru'),
  FavoriteUserProfileLoader? profileLoader,
  FavoriteConversationUnreadCountSource? conversationUnreadCountSource,
  FavoriteEventLoader? eventLoader,
  FavoriteLatestEventChatMessageSource? latestMessageSource,
  FavoriteInboxChatsWatcher? inboxChatsWatcher,
  FavoriteHiddenChatWriter? hiddenChatWriter,
  FavoriteInaccessibleEventChatIdWriter? inaccessibleEventChatIdWriter,
  FavoriteConversationOpener? conversationOpener,
  FavoriteEventChatOpener? eventChatOpener,
  bool useDebugEventChatsSource = true,
}) async {
  FavoriteWidget.debugClearSessionCache();
  addTearDown(FavoriteWidget.debugClearSessionCache);
  addTearDown(sources.dispose);
  await tester.pumpWidget(
    _testApp(
      sources.widget(
        profileLoader: profileLoader,
        conversationUnreadCountSource: conversationUnreadCountSource,
        eventLoader: eventLoader,
        latestMessageSource: latestMessageSource,
        inboxChatsWatcher: inboxChatsWatcher,
        hiddenChatWriter: hiddenChatWriter,
        inaccessibleEventChatIdWriter: inaccessibleEventChatIdWriter,
        conversationOpener: conversationOpener,
        eventChatOpener: eventChatOpener,
        useDebugEventChatsSource: useDebugEventChatsSource,
      ),
      locale: locale,
    ),
  );
  await tester.pump();
}

Future<void> _emitFriends(
  WidgetTester tester,
  _FavoriteSources sources,
  String uid,
  FavoriteFriendsLoadState state,
) async {
  sources.friendsFor(uid).add(state);
  await tester.pump();
}

Future<void> _emitConversations(
  WidgetTester tester,
  _FavoriteSources sources,
  String uid,
  List<ConversationsRecord> conversations, {
  bool authoritative = true,
}) async {
  sources.conversationsFor(uid).add(
        FavoriteConversationsLoadState(
          ownerUid: uid,
          isAuthoritative: authoritative,
          conversations: conversations,
        ),
      );
  await tester.pump();
}

Future<void> _emitEventChats(
  WidgetTester tester,
  _FavoriteSources sources,
  String uid, {
  List<EventChatsRecord> eventChats = const <EventChatsRecord>[],
  bool authoritative = true,
}) async {
  sources.eventChatsFor(uid).add(
        FavoriteEventChatsLoadState(
          ownerUid: uid,
          isAuthoritative: authoritative,
          eventChats: eventChats,
        ),
      );
  await tester.pump();
}

Future<void> _selectFriendsTab(WidgetTester tester) async {
  await tester.tap(find.text('Друзья'));
  await tester.pump();
}

enum _FavoriteRequiredSource {
  friends,
  conversations,
  eventChats,
}

Future<void> _emitAuthoritativeRequiredSources(
  WidgetTester tester,
  _FavoriteSources sources, {
  required List<DocumentReference> friends,
  required List<ConversationsRecord> conversations,
  List<EventChatsRecord> eventChats = const <EventChatsRecord>[],
}) async {
  await _emitFriends(
    tester,
    sources,
    'user-a',
    _friendsState(
      ownerUid: 'user-a',
      friends: friends,
      authoritative: true,
    ),
  );
  await _emitConversations(
    tester,
    sources,
    'user-a',
    conversations,
  );
  await _emitEventChats(
    tester,
    sources,
    'user-a',
    eventChats: eventChats,
  );
}

Future<void> _emitRequiredSourceRefresh(
  WidgetTester tester,
  _FavoriteSources sources,
  _FavoriteRequiredSource source, {
  required List<DocumentReference> friends,
  required List<ConversationsRecord> conversations,
  List<EventChatsRecord> eventChats = const <EventChatsRecord>[],
}) async {
  switch (source) {
    case _FavoriteRequiredSource.friends:
      await _emitFriends(
        tester,
        sources,
        'user-a',
        _friendsState(
          ownerUid: 'user-a',
          friends: friends,
          authoritative: false,
        ),
      );
      return;
    case _FavoriteRequiredSource.conversations:
      await _emitConversations(
        tester,
        sources,
        'user-a',
        conversations,
        authoritative: false,
      );
      return;
    case _FavoriteRequiredSource.eventChats:
      await _emitEventChats(
        tester,
        sources,
        'user-a',
        eventChats: eventChats,
        authoritative: false,
      );
      return;
  }
}

Future<void> _emitRequiredSourceError(
  WidgetTester tester,
  _FavoriteSources sources,
  _FavoriteRequiredSource source,
) async {
  switch (source) {
    case _FavoriteRequiredSource.friends:
      sources.friendsFor('user-a').addError(StateError('friends failed'));
      break;
    case _FavoriteRequiredSource.conversations:
      sources
          .conversationsFor('user-a')
          .addError(StateError('conversations failed'));
      break;
    case _FavoriteRequiredSource.eventChats:
      sources
          .eventChatsFor('user-a')
          .addError(StateError('event chats failed'));
      break;
  }
  await tester.pump();
}

Future<void> _runRequiredSourceRefreshCase(
  WidgetTester tester, {
  required _FavoriteRequiredSource source,
  required bool friendsTab,
  required bool hasRows,
}) async {
  final semantics = tester.ensureSemantics();
  try {
    final sources = _FavoriteSources();
    final friends = friendsTab && hasRows
        ? List<DocumentReference>.generate(
            28,
            (index) => UsersRecord.collection.doc(
              'refresh-friend-${source.name}-$index',
            ),
          )
        : const <DocumentReference>[];
    final conversations = hasRows
        ? List<ConversationsRecord>.generate(
            28,
            (index) => _conversation(
              id: 'refresh-${friendsTab ? 'friends' : 'all'}-'
                  '${source.name}-$index',
              ownerUid: 'user-a',
              partnerUid: friendsTab
                  ? friends[index].id
                  : 'refresh-partner-${source.name}-$index',
            ),
          )
        : const <ConversationsRecord>[];
    final locale = friendsTab ? const Locale('en') : const Locale('ru');
    await _mount(tester, sources, locale: locale);
    await _emitAuthoritativeRequiredSources(
      tester,
      sources,
      friends: friends,
      conversations: conversations,
    );
    if (friendsTab) {
      await tester.tap(find.text('Friends'));
      await tester.pump();
    }

    final inlineErrorKey = friendsTab
        ? favoriteFriendsInlineErrorKey
        : favoriteMessagesInlineErrorKey;
    final retryButtonKey = friendsTab
        ? favoriteFriendsRetryButtonKey
        : favoriteMessagesRetryButtonKey;
    final refreshLabel =
        friendsTab ? 'Refreshing chats with friends' : 'Обновление сообщений';
    final initialLoadingKey = friendsTab
        ? favoriteFriendsInitialLoadingKey
        : favoriteMessagesInitialLoadingKey;

    expect(find.byKey(initialLoadingKey), findsNothing);
    expect(find.bySemanticsLabel(refreshLabel), findsNothing);

    late final Finder geometryTarget;
    Finder? scrollable;
    double? scrollOffset;
    if (hasRows) {
      final list = friendsTab
          ? find.descendant(
              of: find.byKey(favoriteFriendsDataKey),
              matching: find.byType(ListView),
            )
          : find.byKey(favoriteMessagesListKey);
      scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      await tester.drag(list, const Offset(0, -420));
      await tester.pumpAndSettle();
      scrollOffset = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(scrollOffset, greaterThan(0));
      geometryTarget = conversations
          .map((conversation) => _conversationRow(conversation.reference.id))
          .firstWhere((row) => row.evaluate().isNotEmpty);
      expect(geometryTarget, findsOneWidget);
    } else {
      geometryTarget = find.byType(EmptyWidget);
      expect(geometryTarget, findsOneWidget);
    }
    final initialRect = tester.getRect(geometryTarget);

    void expectDisplayUnchanged() {
      expect(tester.getRect(geometryTarget), initialRect);
      if (scrollable != null) {
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          scrollOffset,
        );
      }
    }

    await _emitRequiredSourceRefresh(
      tester,
      sources,
      source,
      friends: friends,
      conversations: conversations,
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(initialLoadingKey), findsNothing);
    expect(find.bySemanticsLabel(refreshLabel), findsNothing);
    expect(find.byKey(inlineErrorKey), findsNothing);
    expectDisplayUnchanged();

    await _emitRequiredSourceError(tester, sources, source);

    expect(find.bySemanticsLabel(refreshLabel), findsNothing);
    expect(find.byKey(inlineErrorKey), findsOneWidget);
    expectDisplayUnchanged();

    await tester.tap(find.byKey(retryButtonKey));
    await tester.pump();

    expect(find.byKey(inlineErrorKey), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(initialLoadingKey), findsNothing);
    expect(find.bySemanticsLabel(refreshLabel), findsNothing);
    expectDisplayUnchanged();

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: friends,
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      conversations,
    );
    if (!friendsTab) {
      await _emitEventChats(tester, sources, 'user-a');
    }

    expect(find.bySemanticsLabel(refreshLabel), findsNothing);
    expect(find.byKey(inlineErrorKey), findsNothing);
    expectDisplayUnchanged();
  } finally {
    semantics.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _TestFirebaseAuthPlatform();
    await FFLocalizations.initialize();
  });

  for (final source in _FavoriteRequiredSource.values) {
    for (final hasRows in <bool>[true, false]) {
      testWidgets(
        'All ${source.name} ${hasRows ? 'data' : 'empty'} '
        'refresh error retry success keeps display',
        (tester) => _runRequiredSourceRefreshCase(
          tester,
          source: source,
          friendsTab: false,
          hasRows: hasRows,
        ),
      );
    }
  }

  for (final source in <_FavoriteRequiredSource>[
    _FavoriteRequiredSource.friends,
    _FavoriteRequiredSource.conversations,
  ]) {
    for (final hasRows in <bool>[true, false]) {
      testWidgets(
        'Friends ${source.name} ${hasRows ? 'data' : 'empty'} '
        'refresh error retry success keeps display',
        (tester) => _runRequiredSourceRefreshCase(
          tester,
          source: source,
          friendsTab: true,
          hasRows: hasRows,
        ),
      );
    }
  }

  testWidgets('cold sources stay initial loading without refresh semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final sources = _FavoriteSources();
      await _mount(tester, sources);

      expect(find.byKey(favoriteMessagesInitialLoadingKey), findsOneWidget);
      expect(find.bySemanticsLabel('Загрузка сообщений'), findsOneWidget);
      expect(find.bySemanticsLabel('Обновление сообщений'), findsNothing);

      await _selectFriendsTab(tester);

      expect(find.byKey(favoriteFriendsInitialLoadingKey), findsOneWidget);
      expect(
        find.bySemanticsLabel('Загрузка чатов с друзьями'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Обновление чатов с друзьями'),
        findsNothing,
      );
    } finally {
      semantics.dispose();
    }
  });

  for (final pendingConversations in <bool>[true, false]) {
    final pendingSource = pendingConversations ? 'conversations' : 'eventChats';
    testWidgets('All tab waits for $pendingSource before showing empty',
        (tester) async {
      final sources = _FavoriteSources();
      await _mount(tester, sources);
      await _emitFriends(
        tester,
        sources,
        'user-a',
        _friendsState(ownerUid: 'user-a', authoritative: true),
      );

      if (pendingConversations) {
        await _emitEventChats(tester, sources, 'user-a');
      } else {
        await _emitConversations(tester, sources, 'user-a', const []);
      }

      expect(find.byType(EmptyWidget), findsNothing);
      expect(find.text('У вас пока нет сообщений.'), findsNothing);
      expect(find.byKey(favoriteMessagesListKey), findsNothing);
      expect(find.byKey(favoriteMessagesLoadErrorKey), findsNothing);
      expect(find.byKey(favoriteMessagesInitialLoadingKey), findsOneWidget);

      if (pendingConversations) {
        await _emitConversations(tester, sources, 'user-a', const []);
      } else {
        await _emitEventChats(tester, sources, 'user-a');
      }

      expect(find.byType(EmptyWidget), findsOneWidget);
      expect(find.text('У вас пока нет сообщений.'), findsOneWidget);
      expect(find.byKey(favoriteMessagesListKey), findsNothing);
      expect(find.byKey(favoriteMessagesLoadErrorKey), findsNothing);
      expect(find.byKey(favoriteMessagesInitialLoadingKey), findsNothing);
    });
  }

  testWidgets(
      'optional row enrichment and Friends event source do not refresh tabs',
      (tester) async {
    final sources = _FavoriteSources();
    final profile = Completer<UserPublicProfilesRecord?>();
    final preview = StreamController<EventChatMessagesLoadState>.broadcast();
    addTearDown(preview.close);
    final friend = UsersRecord.collection.doc('optional-refresh-friend');
    final conversation = _conversation(
      id: 'optional-refresh-conversation',
      ownerUid: 'user-a',
      partnerUid: friend.id,
    );
    final chat = _eventChat('optional-refresh-event');
    await _mount(
      tester,
      sources,
      profileLoader: (_) => profile.future,
      eventLoader: (eventId) async =>
          _event(eventId, title: 'Optional refresh event'),
      latestMessageSource: (_, __) => preview.stream,
    );
    await _emitAuthoritativeRequiredSources(
      tester,
      sources,
      friends: <DocumentReference>[friend],
      conversations: <ConversationsRecord>[conversation],
      eventChats: <EventChatsRecord>[chat],
    );
    await tester.pump();

    expect(_conversationRow(conversation.reference.id), findsOneWidget);
    expect(find.bySemanticsLabel('Обновление сообщений'), findsNothing);

    await _selectFriendsTab(tester);
    expect(
      find.bySemanticsLabel('Обновление чатов с друзьями'),
      findsNothing,
    );

    await _emitEventChats(
      tester,
      sources,
      'user-a',
      eventChats: <EventChatsRecord>[chat],
      authoritative: false,
    );

    expect(
      find.bySemanticsLabel('Обновление чатов с друзьями'),
      findsNothing,
    );
  });

  test('chat mutation owner must match active and direct auth owners', () {
    expect(
      favoriteChatMutationOwnerMatches(
        activeOwnerUid: 'user-a',
        authenticatedOwnerUid: 'user-a',
        requestedOwnerUid: 'user-a',
      ),
      isTrue,
    );
    expect(
      favoriteChatMutationOwnerMatches(
        activeOwnerUid: 'user-b',
        authenticatedOwnerUid: 'user-a',
        requestedOwnerUid: 'user-b',
      ),
      isFalse,
    );
    expect(
      favoriteChatMutationOwnerMatches(
        activeOwnerUid: 'user-a',
        authenticatedOwnerUid: 'user-b',
        requestedOwnerUid: 'user-a',
      ),
      isFalse,
    );
    expect(
      favoriteChatMutationOwnerMatches(
        activeOwnerUid: 'user-a',
        authenticatedOwnerUid: '',
        requestedOwnerUid: 'user-a',
      ),
      isFalse,
    );
  });

  testWidgets('conversation tap cannot navigate after direct UID changes first',
      (tester) async {
    final sources = _FavoriteSources();
    final openedConversations = <String>[];
    final conversation = _conversation(
      id: 'direct-auth-conversation',
      ownerUid: 'user-a',
      partnerUid: 'friend-direct-auth',
    );
    await _mount(
      tester,
      sources,
      conversationOpener: (ownerUid, openedConversation) async {
        openedConversations.add('$ownerUid:${openedConversation.reference.id}');
      },
    );
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );
    await _emitEventChats(tester, sources, 'user-a');
    expect(_conversationRow('direct-auth-conversation'), findsOneWidget);

    sources.authenticatedUid = 'user-b';
    await tester.tap(_conversationRow('direct-auth-conversation'));

    expect(openedConversations, isEmpty);
  });

  testWidgets('event tap cannot navigate after direct UID changes first',
      (tester) async {
    final sources = _FavoriteSources();
    final openedEvents = <String>[];
    final chat = _eventChat('direct-auth-event');
    await _mount(
      tester,
      sources,
      latestMessageSource: (ownerUid, _) => Stream.value(
        EventChatMessagesLoadState(
          ownerUid: ownerUid,
          messages: const <EventChatMessagesRecord>[],
          isFromCache: false,
          hasPendingWrites: false,
        ),
      ),
      eventChatOpener: (ownerUid, eventId, _) {
        openedEvents.add('$ownerUid:$eventId');
      },
    );
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      const <ConversationsRecord>[],
    );
    await _emitEventChats(
      tester,
      sources,
      'user-a',
      eventChats: <EventChatsRecord>[chat],
    );
    await tester.pump();
    final eventRow = find.byKey(
      const ValueKey<String>('favorite_chat_event:direct-auth-event'),
    );
    expect(eventRow, findsOneWidget);
    expect(
      find.byKey(
        favoriteEventChatAsyncRowKey(
          ownerUid: 'user-a',
          chatPath: chat.reference.path,
          eventId: 'direct-auth-event',
        ),
      ),
      findsOneWidget,
    );

    sources.authenticatedUid = 'user-b';
    await tester.tap(eventRow);

    expect(openedEvents, isEmpty);
  });

  testWidgets('delete action cannot write after direct UID changes first',
      (tester) async {
    final sources = _FavoriteSources();
    final writes = <String>[];
    final friend = UsersRecord.collection.doc('friend-direct-auth-delete');
    final conversation = _conversation(
      id: 'direct-auth-delete',
      ownerUid: 'user-a',
      partnerUid: friend.id,
    );
    await _mount(
      tester,
      sources,
      hiddenChatWriter: (ownerUid, hiddenChatKey) async {
        writes.add('$ownerUid:$hiddenChatKey');
      },
    );
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );
    await _emitEventChats(tester, sources, 'user-a');
    await _selectFriendsTab(tester);

    sources.authenticatedUid = 'user-b';
    _invokeConversationDismiss(tester, 'direct-auth-delete');

    expect(writes, isEmpty);
    expect(_conversationRow('direct-auth-delete'), findsOneWidget);
  });

  testWidgets(
      'optimistic hide rollback returns empty only after confirmed empty',
      (tester) async {
    final sources = _FavoriteSources();
    final writes = <Completer<void>>[];
    final friend = UsersRecord.collection.doc('friend-rollback-empty');
    final conversation = _conversation(
      id: 'rollback-empty',
      ownerUid: 'user-a',
      partnerUid: friend.id,
    );
    await _mount(
      tester,
      sources,
      hiddenChatWriter: (_, __) {
        final write = Completer<void>();
        writes.add(write);
        return write.future;
      },
    );
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );
    await _emitEventChats(tester, sources, 'user-a');
    await _selectFriendsTab(tester);

    final row = _conversationRow('rollback-empty');
    expect(row, findsOneWidget);
    expect(find.byKey(favoriteFriendsEmptyKey), findsNothing);

    _invokeConversationDismiss(tester, 'rollback-empty');
    await tester.pump();
    expect(writes, hasLength(1));
    expect(row, findsNothing);
    expect(find.byKey(favoriteFriendsEmptyKey), findsOneWidget);

    await _emitConversations(
      tester,
      sources,
      'user-a',
      const <ConversationsRecord>[],
      authoritative: false,
    );
    writes.first.completeError(StateError('cached refresh failed'));
    await tester.pump();
    await tester.pump();

    expect(row, findsOneWidget);
    expect(find.byKey(favoriteFriendsEmptyKey), findsNothing);
    expect(find.text('Не удалось удалить чат'), findsOneWidget);
    expect(find.byKey(favoriteFriendsLoadErrorKey), findsNothing);
    expect(find.byKey(favoriteFriendsInlineErrorKey), findsNothing);

    ScaffoldMessenger.of(tester.element(find.byType(FavoriteWidget)))
        .removeCurrentSnackBar();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    _invokeConversationDismiss(tester, 'rollback-empty');
    await tester.pump();
    expect(writes, hasLength(2));
    expect(row, findsNothing);

    await _emitConversations(
      tester,
      sources,
      'user-a',
      const <ConversationsRecord>[],
    );
    writes.last.completeError(StateError('server-confirmed empty'));
    await tester.pump();
    await tester.pump();

    expect(row, findsNothing);
    expect(find.byKey(favoriteFriendsEmptyKey), findsOneWidget);
    expect(find.text('Не удалось удалить чат'), findsOneWidget);
    expect(find.byKey(favoriteFriendsLoadErrorKey), findsNothing);
    expect(find.byKey(favoriteFriendsInlineErrorKey), findsNothing);
  });

  testWidgets('raw A B A before one frame recreates A sources and drops A1',
      (tester) async {
    final auth = StreamController<String>.broadcast(sync: true);
    var authenticatedUid = 'user-a';
    final friendCalls = <({
      String uid,
      StreamController<FavoriteFriendsLoadState> controller,
    })>[];
    final conversationCalls = <({
      String uid,
      StreamController<FavoriteConversationsLoadState> controller,
    })>[];
    final eventCalls = <({
      String uid,
      StreamController<FavoriteEventChatsLoadState> controller,
    })>[];
    final opened = <String>[];
    final hiddenWrites = <String>[];

    StreamController<T> newSource<T extends Object>() =>
        StreamController<T>.broadcast(sync: true);

    FavoriteWidget.debugClearSessionCache();
    addTearDown(() async {
      FavoriteWidget.debugClearSessionCache();
      await auth.close();
      for (final call in friendCalls) {
        await call.controller.close();
      }
      for (final call in conversationCalls) {
        await call.controller.close();
      }
      for (final call in eventCalls) {
        await call.controller.close();
      }
    });
    await tester.pumpWidget(
      _testApp(
        FavoriteWidget(
          debugAuthUidStream: auth.stream,
          debugInitialAuthUid: 'user-a',
          debugAuthenticatedUidReader: () => authenticatedUid,
          debugFriendsSource: (uid) {
            final controller = newSource<FavoriteFriendsLoadState>();
            friendCalls.add((uid: uid, controller: controller));
            return controller.stream;
          },
          debugConversationsSource: (uid) {
            final controller = newSource<FavoriteConversationsLoadState>();
            conversationCalls.add((uid: uid, controller: controller));
            return controller.stream;
          },
          debugEventChatsSource: (uid) {
            final controller = newSource<FavoriteEventChatsLoadState>();
            eventCalls.add((uid: uid, controller: controller));
            return controller.stream;
          },
          debugUserProfileLoader: (_) async => null,
          debugConversationOpener: (ownerUid, conversation) async {
            opened.add('$ownerUid:${conversation.reference.id}');
          },
          debugHiddenChatWriter: (ownerUid, hiddenChatKey) async {
            hiddenWrites.add('$ownerUid:$hiddenChatKey');
          },
        ),
      ),
    );
    await tester.pump();

    final friend = UsersRecord.collection.doc('epoch-friend');
    final conversation = _conversation(
      id: 'epoch-a1',
      ownerUid: 'user-a',
      partnerUid: friend.id,
    );
    friendCalls.single.controller.add(
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        authoritative: true,
      ),
    );
    conversationCalls.single.controller.add(
      FavoriteConversationsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: true,
        conversations: <ConversationsRecord>[conversation],
      ),
    );
    eventCalls.single.controller.add(
      const FavoriteEventChatsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: true,
      ),
    );
    await tester.pump();
    expect(_conversationRow('epoch-a1'), findsOneWidget);

    authenticatedUid = 'user-b';
    auth.add('user-b');
    authenticatedUid = 'user-a';
    auth.add('user-a');

    await tester.tap(_conversationRow('epoch-a1'));
    _invokeConversationDismiss(tester, 'epoch-a1');
    expect(opened, isEmpty);
    expect(hiddenWrites, isEmpty);

    await tester.pump();
    expect(friendCalls.map((call) => call.uid), ['user-a', 'user-a']);
    expect(
      conversationCalls.map((call) => call.uid),
      ['user-a', 'user-a'],
    );
    expect(eventCalls.map((call) => call.uid), ['user-a', 'user-a']);
    expect(_conversationRow('epoch-a1'), findsNothing);

    friendCalls.first.controller.add(
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        authoritative: true,
      ),
    );
    conversationCalls.first.controller.add(
      FavoriteConversationsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: true,
        conversations: <ConversationsRecord>[conversation],
      ),
    );
    await tester.pump();
    expect(_conversationRow('epoch-a1'), findsNothing);

    friendCalls.last.controller.add(
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        authoritative: true,
      ),
    );
    conversationCalls.last.controller.add(
      FavoriteConversationsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: true,
        conversations: <ConversationsRecord>[conversation],
      ),
    );
    eventCalls.last.controller.add(
      const FavoriteEventChatsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: true,
      ),
    );
    await tester.pump();
    expect(_conversationRow('epoch-a1'), findsOneWidget);
  });

  testWidgets('same owner first auth emission preserves warm remount rows',
      (tester) async {
    final firstSources = _FavoriteSources();
    final friend = UsersRecord.collection.doc('friend-warm-remount');
    final conversation = _conversation(
      id: 'warm-remount',
      ownerUid: 'user-a',
      partnerUid: friend.id,
    );
    await _mount(tester, firstSources);
    await _emitFriends(
      tester,
      firstSources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      firstSources,
      'user-a',
      <ConversationsRecord>[conversation],
    );
    await _emitEventChats(tester, firstSources, 'user-a');
    expect(_conversationRow('warm-remount'), findsOneWidget);

    await tester.pumpWidget(_testApp(const SizedBox.shrink()));
    await tester.pump();

    final secondSources = _FavoriteSources();
    addTearDown(secondSources.dispose);
    await tester.pumpWidget(
      _testApp(
        FavoriteWidget(
          debugAuthUidStream: Stream<String>.value('user-a'),
          debugInitialAuthUid: 'user-a',
          debugAuthenticatedUidReader: () => secondSources.authenticatedUid,
          debugFriendsSource: (uid) => secondSources.friendsFor(uid).stream,
          debugConversationsSource: (uid) =>
              secondSources.conversationsFor(uid).stream,
          debugEventChatsSource: (uid) =>
              secondSources.eventChatsFor(uid).stream,
          debugUserProfileLoader: (_) async => null,
        ),
      ),
    );
    await tester.pump();

    expect(_conversationRow('warm-remount'), findsOneWidget);
    expect(find.byKey(favoriteMessagesLoadErrorKey), findsNothing);
    expect(find.byType(UxErrorState), findsNothing);
    expect(find.byType(EmptyWidget), findsNothing);

    secondSources
        .friendsFor('user-a')
        .addError(StateError('remount friends pending failed'));
    secondSources
        .conversationsFor('user-a')
        .addError(StateError('remount conversations pending failed'));
    secondSources
        .eventChatsFor('user-a')
        .addError(StateError('remount events pending failed'));
    await tester.pump();

    expect(_conversationRow('warm-remount'), findsOneWidget);
    expect(find.byKey(favoriteMessagesInlineErrorKey), findsOneWidget);
    expect(find.byKey(favoriteMessagesLoadErrorKey), findsNothing);
    expect(find.byType(UxErrorState), findsNothing);
    expect(find.byType(EmptyWidget), findsNothing);
  });

  testWidgets('late A1 hide failure cannot roll back A2 after an ABA switch',
      (tester) async {
    final sources = _FavoriteSources();
    final writes = <Completer<void>>[];
    final friend = UsersRecord.collection.doc('friend-hide-aba');
    final conversation = _conversation(
      id: 'hide-aba',
      ownerUid: 'user-a',
      partnerUid: friend.id,
    );
    await _mount(
      tester,
      sources,
      hiddenChatWriter: (ownerUid, hiddenChatKey) {
        expect(ownerUid, 'user-a');
        expect(hiddenChatKey, 'conversation:hide-aba');
        final write = Completer<void>();
        writes.add(write);
        return write.future;
      },
    );
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );
    await _emitEventChats(tester, sources, 'user-a');
    await _selectFriendsTab(tester);

    _invokeConversationDismiss(tester, 'hide-aba');
    await tester.pump();
    expect(writes, hasLength(1));
    expect(_conversationRow('hide-aba'), findsNothing);

    sources.switchAuthenticatedUid('user-b');
    await tester.pump();
    sources.switchAuthenticatedUid('user-a');
    await tester.pump();
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );
    await _emitEventChats(tester, sources, 'user-a');
    await _selectFriendsTab(tester);
    expect(_conversationRow('hide-aba'), findsOneWidget);

    _invokeConversationDismiss(tester, 'hide-aba');
    await tester.pump();
    expect(writes, hasLength(2));
    expect(_conversationRow('hide-aba'), findsNothing);

    writes.first.completeError(StateError('late A1 failure'));
    await tester.pump();
    await tester.pump();
    expect(_conversationRow('hide-aba'), findsNothing);
    expect(find.text('Не удалось удалить чат'), findsNothing);

    writes.last.completeError(StateError('A2 failure'));
    await tester.pump();
    await tester.pump();
    expect(_conversationRow('hide-aba'), findsOneWidget);
    expect(find.text('Не удалось удалить чат'), findsOneWidget);
  });

  testWidgets('late A1 hide success cannot consume the A2 mutation token',
      (tester) async {
    final sources = _FavoriteSources();
    final writes = <Completer<void>>[];
    final friend = UsersRecord.collection.doc('friend-hide-success-aba');
    final conversation = _conversation(
      id: 'hide-success-aba',
      ownerUid: 'user-a',
      partnerUid: friend.id,
    );
    await _mount(
      tester,
      sources,
      hiddenChatWriter: (_, __) {
        final write = Completer<void>();
        writes.add(write);
        return write.future;
      },
    );
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );
    await _emitEventChats(tester, sources, 'user-a');
    await _selectFriendsTab(tester);

    _invokeConversationDismiss(tester, 'hide-success-aba');
    await tester.pump();
    expect(writes, hasLength(1));

    sources.switchAuthenticatedUid('user-b');
    await tester.pump();
    sources.switchAuthenticatedUid('user-a');
    await tester.pump();
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );
    await _emitEventChats(tester, sources, 'user-a');
    await _selectFriendsTab(tester);
    _invokeConversationDismiss(tester, 'hide-success-aba');
    await tester.pump();
    expect(writes, hasLength(2));
    expect(_conversationRow('hide-success-aba'), findsNothing);

    writes.first.complete();
    await tester.pump();
    writes.last.completeError(StateError('A2 failure'));
    await tester.pump();
    await tester.pump();

    expect(_conversationRow('hide-success-aba'), findsOneWidget);
    expect(find.text('Не удалось удалить чат'), findsOneWidget);
  });

  testWidgets(
    'production Friends tab waits for authoritative empty and exposes loading',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final sources = _FavoriteSources();
        await _mount(tester, sources);

        await _emitFriends(
          tester,
          sources,
          'user-a',
          resolveFavoriteFriendsDocumentSnapshotState(
            expectedOwnerUid: 'user-a',
            snapshotOwnerUid: 'user-a',
            documentExists: true,
            friends: const <DocumentReference>[],
            rawHiddenChatKeys: const <String>[],
            isFromCache: true,
            hasPendingWrites: false,
          ),
        );
        await _emitConversations(tester, sources, 'user-a', const []);
        await _emitEventChats(tester, sources, 'user-a');
        await _selectFriendsTab(tester);

        expect(find.byKey(favoriteFriendsInitialLoadingKey), findsOneWidget);
        expect(find.text('Загрузка чатов с друзьями'), findsOneWidget);
        expect(find.byKey(favoriteFriendsEmptyKey), findsNothing);
        final loadingSemantics = tester.getSemantics(
          find.bySemanticsLabel('Загрузка чатов с друзьями'),
        );
        expect(loadingSemantics.flagsCollection.isLiveRegion, isTrue);

        await _emitFriends(
          tester,
          sources,
          'user-a',
          resolveFavoriteFriendsDocumentSnapshotState(
            expectedOwnerUid: 'user-a',
            snapshotOwnerUid: 'user-a',
            documentExists: true,
            friends: const <DocumentReference>[],
            rawHiddenChatKeys: const <String>[],
            isFromCache: false,
            hasPendingWrites: false,
          ),
        );

        expect(find.byKey(favoriteFriendsInitialLoadingKey), findsNothing);
        expect(find.byKey(favoriteFriendsEmptyKey), findsOneWidget);
        expect(find.text('У вас пока нет чатов с друзьями.'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
      'Friends tab does not derive empty from a non-authoritative conversation',
      (tester) async {
    final sources = _FavoriteSources();
    final conversation = _conversation(
      id: 'pending-not-friend',
      ownerUid: 'user-a',
      partnerUid: 'not-a-friend',
    );
    await _mount(tester, sources);
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
      authoritative: false,
    );
    await _emitEventChats(tester, sources, 'user-a');
    await _selectFriendsTab(tester);

    expect(find.byKey(favoriteFriendsInitialLoadingKey), findsOneWidget);
    expect(find.byKey(favoriteFriendsEmptyKey), findsNothing);

    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );

    expect(find.byKey(favoriteFriendsInitialLoadingKey), findsNothing);
    expect(find.byKey(favoriteFriendsEmptyKey), findsOneWidget);
  });

  testWidgets(
      'All tab does not derive empty from a hidden partial conversation',
      (tester) async {
    final sources = _FavoriteSources();
    final conversation = _conversation(
      id: 'partial-hidden-conversation',
      ownerUid: 'user-a',
      partnerUid: 'friend-hidden',
    );
    await _mount(tester, sources);
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        rawHiddenChatKeys: const <String>[
          'conversation:partial-hidden-conversation',
        ],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
      authoritative: false,
    );
    await _emitEventChats(tester, sources, 'user-a');

    expect(find.byType(EmptyWidget), findsNothing);
    expect(find.byKey(favoriteMessagesLoadErrorKey), findsNothing);

    sources.conversationsFor('user-a').addError(
          StateError('partial conversations failed'),
        );
    await tester.pump();

    expect(find.byKey(favoriteMessagesLoadErrorKey), findsOneWidget);
    expect(find.byKey(favoriteMessagesInlineErrorKey), findsNothing);
    expect(find.byType(EmptyWidget), findsNothing);

    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );

    expect(find.byKey(favoriteMessagesLoadErrorKey), findsNothing);
    expect(find.byType(EmptyWidget), findsOneWidget);
  });

  testWidgets(
      'production inbox keeps confirmed empty through partial refresh error',
      (tester) async {
    final sources = _FavoriteSources();
    final inbox = StreamController<EventChatInboxLoadState>.broadcast(
      sync: true,
    );
    addTearDown(inbox.close);
    final chat = _eventChat('partial-hidden-event');
    await _mount(
      tester,
      sources,
      useDebugEventChatsSource: false,
      inboxChatsWatcher: ({
        required currentUid,
        required rememberedEventIdsStream,
        required canMutateOwner,
        required onInaccessibleEventId,
      }) =>
          inbox.stream,
    );
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        rawHiddenChatKeys: const <String>['event:partial-hidden-event'],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      const <ConversationsRecord>[],
    );

    inbox.add(
      EventChatInboxLoadState(
        ownerUid: 'user-a',
        chats: const <EventChatsRecord>[],
        isAuthoritative: true,
      ),
    );
    await tester.pump();
    expect(find.byType(EmptyWidget), findsOneWidget);

    inbox.add(
      EventChatInboxLoadState(
        ownerUid: 'user-a',
        isAuthoritative: false,
        chats: <EventChatsRecord>[chat],
      ),
    );
    await tester.pump();

    expect(find.byType(EmptyWidget), findsOneWidget);
    expect(find.byKey(favoriteMessagesLoadErrorKey), findsNothing);

    inbox.addError(StateError('partial inbox failed'));
    await tester.pump();

    expect(find.byKey(favoriteMessagesLoadErrorKey), findsNothing);
    expect(find.byKey(favoriteMessagesInlineErrorKey), findsOneWidget);
    expect(find.byType(EmptyWidget), findsOneWidget);

    inbox.add(
      EventChatInboxLoadState(
        ownerUid: 'user-a',
        isAuthoritative: true,
        chats: <EventChatsRecord>[chat],
      ),
    );
    await tester.pump();

    expect(find.byType(EmptyWidget), findsOneWidget);
  });

  testWidgets(
      'production inbox guard preserves A memory during direct auth switch',
      (tester) async {
    final sources = _FavoriteSources();
    final access = StreamController<EventChatAccessLoadState>.broadcast(
      sync: true,
    );
    EventChatOwnerMutationGuard? capturedGuard;
    addTearDown(access.close);
    addTearDown(() {
      EventGroupChatRepository.resetRememberedInboxEventIdsForTesting();
      UxSessionCacheLifecycle.debugResetForTesting();
    });
    UxSessionCacheLifecycle.updateAuthenticatedUser('user-a');
    EventGroupChatRepository.rememberInboxEventId(
      'stale-event',
      ownerUid: 'user-a',
    );

    await _mount(
      tester,
      sources,
      useDebugEventChatsSource: false,
      inboxChatsWatcher: ({
        required currentUid,
        required rememberedEventIdsStream,
        required canMutateOwner,
        required onInaccessibleEventId,
      }) {
        capturedGuard = canMutateOwner;
        return EventGroupChatRepository.watchInboxChatsState(
          currentUid: currentUid,
          eventIdsStream: () => Stream.value(
            EventInboxEventIdsLoadState(
              ownerUid: currentUid,
              eventIds: <String>['stale-event'],
              isReady: true,
              isAuthoritative: true,
            ),
          ),
          rememberedEventIdsStream: () => Stream.value(
            EventInboxEventIdsLoadState(
              ownerUid: currentUid,
              eventIds: const <String>[],
              isReady: true,
              isAuthoritative: true,
            ),
          ),
          chatAccessStateStream: (_, __) => access.stream,
          canMutateOwner: canMutateOwner,
          onInaccessibleEventId: onInaccessibleEventId,
        );
      },
    );
    await tester.pump();

    expect(capturedGuard, isNotNull);
    expect(capturedGuard!('user-a'), isTrue);

    sources.authenticatedUid = 'user-b';
    expect(capturedGuard!('user-a'), isFalse);
    access.add(
      const EventChatAccessLoadState(
        ownerUid: 'user-a',
        chat: null,
        accessGranted: false,
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      EventGroupChatRepository.rememberedInboxEventIdsForOwner('user-a'),
      contains('stale-event'),
    );
  });

  testWidgets(
      'late A1 permission denial cannot remove the A2 inbox id after ABA',
      (tester) async {
    final sources = _FavoriteSources();
    final accessSources = <StreamController<EventChatAccessLoadState>>[];
    final favoriteCleanupCallbacks = <void Function(String)>[];
    final repositoryCleanupReports = <String>[];
    final cleanupWrites = <String>[];
    final retainedWatchers = <Stream<EventChatInboxLoadState>>[];
    addTearDown(() async {
      for (final source in accessSources) {
        await source.close();
      }
      EventGroupChatRepository.resetRememberedInboxEventIdsForTesting();
      UxSessionCacheLifecycle.debugResetForTesting();
    });
    UxSessionCacheLifecycle.updateAuthenticatedUser('user-a');
    EventGroupChatRepository.rememberInboxEventId(
      'aba-inaccessible',
      ownerUid: 'user-a',
    );

    await _mount(
      tester,
      sources,
      useDebugEventChatsSource: false,
      inaccessibleEventChatIdWriter: (ownerUid, eventId) async {
        cleanupWrites.add('$ownerUid:$eventId');
      },
      inboxChatsWatcher: ({
        required currentUid,
        required rememberedEventIdsStream,
        required canMutateOwner,
        required onInaccessibleEventId,
      }) {
        final access = StreamController<EventChatAccessLoadState>.broadcast(
          sync: true,
        );
        accessSources.add(access);
        favoriteCleanupCallbacks.add(onInaccessibleEventId);
        final watcher = EventGroupChatRepository.watchInboxChatsState(
          currentUid: currentUid,
          eventIdsStream: () => Stream.value(
            EventInboxEventIdsLoadState(
              ownerUid: currentUid,
              eventIds: const <String>['aba-inaccessible'],
              isReady: true,
              isAuthoritative: true,
            ),
          ),
          rememberedEventIdsStream: () => Stream.value(
            EventInboxEventIdsLoadState(
              ownerUid: currentUid,
              eventIds: const <String>[],
              isReady: true,
              isAuthoritative: true,
            ),
          ),
          chatAccessStateStream: (_, __) => access.stream,
          canMutateOwner: canMutateOwner,
          onInaccessibleEventId: (eventId) {
            repositoryCleanupReports.add('$currentUid:$eventId');
            onInaccessibleEventId(eventId);
          },
        ).asBroadcastStream(
          onCancel: (_) {},
        );
        retainedWatchers.add(watcher);
        return watcher;
      },
    );
    expect(accessSources, hasLength(1));

    sources.switchAuthenticatedUid('user-b');
    await tester.pump();
    sources.switchAuthenticatedUid('user-a');
    await tester.pump();
    expect(accessSources, hasLength(3));
    expect(accessSources.first.hasListener, isTrue);

    EventGroupChatRepository.rememberInboxEventId(
      'aba-inaccessible',
      ownerUid: 'user-a',
    );
    favoriteCleanupCallbacks.first('aba-inaccessible');
    await tester.pump();
    expect(cleanupWrites, isEmpty);
    expect(
      EventGroupChatRepository.rememberedInboxEventIdsForOwner('user-a'),
      contains('aba-inaccessible'),
    );

    accessSources.first.addError(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(repositoryCleanupReports, isEmpty);
    expect(cleanupWrites, isEmpty);
    expect(
      EventGroupChatRepository.rememberedInboxEventIdsForOwner('user-a'),
      contains('aba-inaccessible'),
    );
    expect(retainedWatchers, hasLength(3));
  });

  testWidgets('cached owner hidden keys suppress a cached conversation',
      (tester) async {
    final sources = _FavoriteSources();
    final hiddenConversation = _conversation(
      id: 'hidden-a',
      ownerUid: 'user-a',
      partnerUid: 'friend-a',
    );
    await _mount(tester, sources);

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        rawHiddenChatKeys: const <String>['conversation:hidden-a'],
        authoritative: false,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[hiddenConversation],
    );
    await _emitEventChats(tester, sources, 'user-a');

    expect(_conversationRow('hidden-a'), findsNothing);

    await _selectFriendsTab(tester);
    expect(find.byKey(favoriteFriendsInitialLoadingKey), findsOneWidget);
    expect(find.byKey(favoriteFriendsEmptyKey), findsNothing);
  });

  testWidgets('unknown owner metadata withholds rows in both chat tabs',
      (tester) async {
    final sources = _FavoriteSources();
    final friend = UsersRecord.collection.doc('friend-unknown-hidden');
    final conversation = _conversation(
      id: 'unknown-hidden',
      ownerUid: 'user-a',
      partnerUid: friend.id,
    );
    await _mount(tester, sources);

    await _emitFriends(
      tester,
      sources,
      'user-a',
      resolveFavoriteFriendsDocumentSnapshotState(
        expectedOwnerUid: 'user-a',
        snapshotOwnerUid: 'user-a',
        documentExists: true,
        friends: <DocumentReference>[friend],
        rawHiddenChatKeys: const <String>[],
        isFromCache: true,
        hasPendingWrites: false,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );
    await _emitEventChats(tester, sources, 'user-a');

    expect(_conversationRow('unknown-hidden'), findsNothing);

    await _selectFriendsTab(tester);
    expect(_conversationRow('unknown-hidden'), findsNothing);
    expect(find.byKey(favoriteFriendsInitialLoadingKey), findsOneWidget);

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        rawHiddenChatKeys: const <String>['conversation:unknown-hidden'],
        authoritative: true,
      ),
    );
    expect(_conversationRow('unknown-hidden'), findsNothing);
    expect(find.byKey(favoriteFriendsEmptyKey), findsOneWidget);
  });

  testWidgets(
      'pending empty friends keeps confirmed rows and applies hidden keys',
      (tester) async {
    final sources = _FavoriteSources();
    final friendA = UsersRecord.collection.doc('friend-a');
    final friendB = UsersRecord.collection.doc('friend-b');
    final conversationA = _conversation(
      id: 'visible-a',
      ownerUid: 'user-a',
      partnerUid: 'friend-a',
    );
    final conversationB = _conversation(
      id: 'hidden-b',
      ownerUid: 'user-a',
      partnerUid: 'friend-b',
    );
    await _mount(tester, sources);

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friendA, friendB],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversationA, conversationB],
    );
    await _emitEventChats(tester, sources, 'user-a');
    await _selectFriendsTab(tester);
    expect(_conversationRow('visible-a'), findsOneWidget);
    expect(_conversationRow('hidden-b'), findsOneWidget);

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        rawHiddenChatKeys: const <String>['conversation:hidden-b'],
        authoritative: false,
      ),
    );

    expect(find.byKey(favoriteFriendsDataKey), findsOneWidget);
    expect(_conversationRow('visible-a'), findsOneWidget);
    expect(_conversationRow('hidden-b'), findsNothing);
    expect(find.byKey(favoriteFriendsEmptyKey), findsNothing);
  });

  testWidgets(
      'complete friends A B then pending B keeps the only visible A row',
      (tester) async {
    final sources = _FavoriteSources();
    final friendA = UsersRecord.collection.doc('friend-authority-a');
    final friendB = UsersRecord.collection.doc('friend-authority-b');
    final conversationA = _conversation(
      id: 'authority-visible-a',
      ownerUid: 'user-a',
      partnerUid: friendA.id,
    );
    await _mount(tester, sources);
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friendA, friendB],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversationA],
    );
    await _emitEventChats(tester, sources, 'user-a');
    await _selectFriendsTab(tester);
    expect(_conversationRow('authority-visible-a'), findsOneWidget);

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friendB],
        authoritative: false,
      ),
    );

    expect(_conversationRow('authority-visible-a'), findsOneWidget);
    expect(find.byKey(favoriteFriendsDataKey), findsOneWidget);
    expect(find.byKey(favoriteFriendsEmptyKey), findsNothing);

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friendB],
        authoritative: true,
      ),
    );

    expect(_conversationRow('authority-visible-a'), findsNothing);
    expect(find.byKey(favoriteFriendsEmptyKey), findsOneWidget);
  });

  testWidgets(
      'unknown owner metadata never reveals a server-hidden conversation',
      (tester) async {
    final sources = _FavoriteSources();
    final conversation = _conversation(
      id: 'hidden-until-server',
      ownerUid: 'user-a',
      partnerUid: 'friend-hidden',
    );
    await _mount(tester, sources);
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        rawHiddenChatKeys: const <String>[
          'conversation:hidden-until-server',
        ],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );
    await _emitEventChats(tester, sources, 'user-a');
    expect(_conversationRow('hidden-until-server'), findsNothing);

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        authoritative: false,
      ),
    );
    expect(_conversationRow('hidden-until-server'), findsNothing);

    sources.friendsFor('user-a').addError(StateError('owner unavailable'));
    await tester.pump();
    expect(find.byKey(favoriteMessagesInlineErrorKey), findsOneWidget);
    expect(_conversationRow('hidden-until-server'), findsNothing);

    await tester.tap(find.byKey(favoriteMessagesRetryButtonKey));
    await tester.pump();
    expect(_conversationRow('hidden-until-server'), findsNothing);

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    expect(_conversationRow('hidden-until-server'), findsOneWidget);
  });

  testWidgets(
      'All-tab warm error and late friend status keep row geometry stable',
      (tester) async {
    final sources = _FavoriteSources();
    final friend = UsersRecord.collection.doc('friend-stable');
    final conversation = _conversation(
      id: 'all-stable',
      ownerUid: 'user-a',
      partnerUid: 'friend-stable',
    );
    await _mount(tester, sources);
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );
    await _emitEventChats(tester, sources, 'user-a');

    final row = _conversationRow('all-stable');
    final timestamp = find.byKey(
      favoriteChatTimestampKey('conversation:all-stable'),
    );
    final initialRowRect = tester.getRect(row);
    final initialTimestampRect = tester.getRect(timestamp);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

    sources.eventChatsFor('user-a').addError(StateError('event chats failed'));
    await tester.pump();
    expect(find.byKey(favoriteMessagesInlineErrorKey), findsOneWidget);
    expect(tester.getRect(row), initialRowRect);
    expect(tester.getRect(timestamp), initialTimestampRect);

    final conversationSubscriptions =
        sources.conversationsListenCounts['user-a'] ?? 0;
    final eventSubscriptions = sources.eventChatsListenCounts['user-a'] ?? 0;
    await tester.tap(find.byKey(favoriteMessagesRetryButtonKey));
    await tester.pump();
    expect(
      sources.conversationsListenCounts['user-a'],
      greaterThan(conversationSubscriptions),
    );
    expect(
      sources.eventChatsListenCounts['user-a'],
      greaterThan(eventSubscriptions),
    );
    expect(tester.getRect(row), initialRowRect);

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        authoritative: true,
      ),
    );
    expect(tester.getRect(row), initialRowRect);
    expect(tester.getRect(timestamp), initialTimestampRect);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });

  testWidgets('All-tab keeps available rows when another source fails cold',
      (tester) async {
    final sources = _FavoriteSources();
    final conversation = _conversation(
      id: 'partial-source-row',
      ownerUid: 'user-a',
      partnerUid: 'friend-partial',
    );
    await _mount(tester, sources);
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );

    sources.eventChatsFor('user-a').addError(StateError('cold failure'));
    await tester.pump();

    expect(_conversationRow('partial-source-row'), findsOneWidget);
    expect(find.byKey(favoriteMessagesInlineErrorKey), findsOneWidget);
    expect(find.byKey(favoriteMessagesLoadErrorKey), findsNothing);
  });

  testWidgets('All-tab keeps an event row when conversations fail cold',
      (tester) async {
    final sources = _FavoriteSources();
    final chat = _eventChat('partial-event-row');
    await _mount(
      tester,
      sources,
      latestMessageSource: (uid, _) => Stream.value(
        EventChatMessagesLoadState(
          ownerUid: uid,
          messages: const <EventChatMessagesRecord>[],
          isFromCache: false,
          hasPendingWrites: false,
        ),
      ),
    );
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    await _emitEventChats(
      tester,
      sources,
      'user-a',
      eventChats: <EventChatsRecord>[chat],
    );

    sources.conversationsFor('user-a').addError(StateError('cold failure'));
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('favorite_chat_event:partial-event-row'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(favoriteMessagesInlineErrorKey), findsOneWidget);
    expect(find.byKey(favoriteMessagesLoadErrorKey), findsNothing);
  });

  testWidgets('All-tab keeps scroll position through error retry recovery',
      (tester) async {
    final sources = _FavoriteSources();
    final conversations = List<ConversationsRecord>.generate(
      24,
      (index) => _conversation(
        id: 'scroll-$index',
        ownerUid: 'user-a',
        partnerUid: 'friend-$index',
      ),
    );
    await _mount(tester, sources);
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    await _emitConversations(tester, sources, 'user-a', conversations);
    await _emitEventChats(tester, sources, 'user-a');

    final list = find.byKey(favoriteMessagesListKey);
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    await tester.drag(list, const Offset(0, -520));
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(before, greaterThan(0));

    sources.eventChatsFor('user-a').addError(StateError('offline'));
    await tester.pump();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      before,
    );

    await tester.tap(find.byKey(favoriteMessagesRetryButtonKey));
    await tester.pump();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      before,
    );

    await _emitEventChats(tester, sources, 'user-a');
    expect(find.byKey(favoriteMessagesInlineErrorKey), findsNothing);
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      before,
    );
  });

  testWidgets('All-tab refresh retry stays above an outer bottom bar',
      (tester) async {
    const bottomBarKey = ValueKey<String>('test_bottom_bar');
    final sources = _FavoriteSources();
    FavoriteWidget.debugClearSessionCache();
    addTearDown(FavoriteWidget.debugClearSessionCache);
    addTearDown(sources.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: _supportedLocales,
        localizationsDelegates: _localizationsDelegates,
        home: Scaffold(
          extendBody: true,
          body: sources.widget(),
          bottomNavigationBar: const SizedBox(
            key: bottomBarKey,
            height: 96,
          ),
        ),
      ),
    );
    await tester.pump();
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[
        _conversation(
          id: 'bottom-safe',
          ownerUid: 'user-a',
          partnerUid: 'friend-bottom',
        ),
      ],
    );
    await _emitEventChats(tester, sources, 'user-a');
    sources.eventChatsFor('user-a').addError(StateError('offline'));
    await tester.pump();

    final retryRect = tester.getRect(
      find.byKey(favoriteMessagesRetryButtonKey),
    );
    final bottomBarRect = tester.getRect(find.byKey(bottomBarKey));
    expect(retryRect.bottom, lessThanOrEqualTo(bottomBarRect.top));
  });

  testWidgets(
      'confirmed empty survives cached pending refresh and later errors',
      (tester) async {
    final sources = _FavoriteSources();
    await _mount(tester, sources);
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      const <ConversationsRecord>[],
    );
    await _emitEventChats(tester, sources, 'user-a');
    expect(find.byType(EmptyWidget), findsOneWidget);

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: false),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      const <ConversationsRecord>[],
      authoritative: false,
    );
    await _emitEventChats(
      tester,
      sources,
      'user-a',
      authoritative: false,
    );
    expect(find.byType(EmptyWidget), findsOneWidget);
    expect(find.byKey(favoriteMessagesLoadErrorKey), findsNothing);

    sources.friendsFor('user-a').addError(StateError('friends offline'));
    sources.conversationsFor('user-a').addError(StateError('offline'));
    sources.eventChatsFor('user-a').addError(StateError('events offline'));
    await tester.pump();
    expect(find.byType(EmptyWidget), findsOneWidget);
    expect(find.byKey(favoriteMessagesLoadErrorKey), findsNothing);
    expect(find.byKey(favoriteMessagesInlineErrorKey), findsOneWidget);
    expect(find.byKey(favoriteMessagesRetryButtonKey), findsOneWidget);
  });

  testWidgets('event preview keeps subtitle and timestamp through error',
      (tester) async {
    final sources = _FavoriteSources();
    final preview = StreamController<EventChatMessagesLoadState>.broadcast(
      sync: true,
    );
    addTearDown(preview.close);
    final chat = _eventChat('event-preview');
    final firstCreatedAt = DateTime.parse('2026-07-13T10:00:00Z');
    final nextCreatedAt = DateTime.parse('2026-07-13T11:00:00Z');
    final firstMessage = _eventMessage(
      chat: chat,
      id: 'preview-1',
      text: 'Stable preview',
      createdAt: firstCreatedAt,
    );
    final nextMessage = _eventMessage(
      chat: chat,
      id: 'preview-2',
      text: 'Recovered preview',
      createdAt: nextCreatedAt,
    );
    await _mount(
      tester,
      sources,
      latestMessageSource: (_, __) => preview.stream,
    );
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    await _emitConversations(tester, sources, 'user-a', const []);
    await _emitEventChats(
      tester,
      sources,
      'user-a',
      eventChats: <EventChatsRecord>[chat],
    );

    preview.add(
      EventChatMessagesLoadState(
        ownerUid: 'user-a',
        messages: <EventChatMessagesRecord>[firstMessage],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    final firstTimestamp = formatFavoriteInboxTimestamp(firstCreatedAt);
    expect(find.text('Stable preview'), findsOneWidget);
    expect(find.text(firstTimestamp), findsOneWidget);

    preview.addError(StateError('preview unavailable'));
    await tester.pump();
    expect(find.text('Stable preview'), findsOneWidget);
    expect(find.text(firstTimestamp), findsOneWidget);

    preview.add(
      EventChatMessagesLoadState(
        ownerUid: 'user-a',
        messages: <EventChatMessagesRecord>[nextMessage],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.text('Stable preview'), findsNothing);
    expect(find.text('Recovered preview'), findsOneWidget);
    expect(
      find.text(formatFavoriteInboxTimestamp(nextCreatedAt)),
      findsOneWidget,
    );
  });

  testWidgets('event preview rejects state owned by another account',
      (tester) async {
    final sources = _FavoriteSources();
    final preview = StreamController<EventChatMessagesLoadState>.broadcast(
      sync: true,
    );
    addTearDown(preview.close);
    final chat = _eventChat('wrong-owner-preview');
    final message = _eventMessage(
      chat: chat,
      id: 'wrong-owner-message',
      text: 'Must not appear',
      createdAt: DateTime.parse('2026-07-13T10:00:00Z'),
    );
    await _mount(
      tester,
      sources,
      latestMessageSource: (_, __) => preview.stream,
    );
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    await _emitConversations(tester, sources, 'user-a', const []);
    await _emitEventChats(
      tester,
      sources,
      'user-a',
      eventChats: <EventChatsRecord>[chat],
    );

    preview.add(
      EventChatMessagesLoadState(
        ownerUid: 'user-b',
        messages: <EventChatMessagesRecord>[message],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();

    expect(find.text('Must not appear'), findsNothing);
    expect(find.text('Чат события'), findsWidgets);
  });

  testWidgets('cold friends error is a localized live error, not empty',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final sources = _FavoriteSources();
      await _mount(tester, sources);

      sources.friendsFor('user-a').addError(StateError('friends failed'));
      await tester.pump();
      await _emitConversations(tester, sources, 'user-a', const []);
      await _emitEventChats(tester, sources, 'user-a');
      await _selectFriendsTab(tester);

      expect(find.byKey(favoriteFriendsLoadErrorKey), findsOneWidget);
      expect(find.byType(UxErrorState), findsOneWidget);
      expect(find.byType(EmptyWidget), findsNothing);
      expect(find.text('Не удалось загрузить чаты'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
      final errorSemantics = tester.getSemantics(
        find.bySemanticsLabel(
          'Не удалось загрузить чаты. '
          'Не удалось загрузить чаты с друзьями. Попробуйте позже.',
        ),
      );
      expect(errorSemantics.flagsCollection.isLiveRegion, isTrue);

      final retry = find.byKey(favoriteFriendsRetryButtonKey);
      final retrySemantics = tester.getSemantics(retry);
      expect(
        retrySemantics.label,
        'Повторить загрузку чатов с друзьями',
      );
      expect(
        retrySemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      final friendsListensBeforeRetry =
          sources.friendsListenCounts['user-a'] ?? 0;
      final conversationsListensBeforeRetry =
          sources.conversationsListenCounts['user-a'] ?? 0;
      await tester.tap(retry);
      await tester.pump();
      expect(
        sources.friendsListenCounts['user-a'],
        greaterThan(friendsListensBeforeRetry),
      );
      expect(
        sources.conversationsListenCounts['user-a'],
        greaterThan(conversationsListensBeforeRetry),
      );
      expect(find.byKey(favoriteFriendsLoadErrorKey), findsOneWidget);

      await _emitFriends(
        tester,
        sources,
        'user-a',
        _friendsState(ownerUid: 'user-a', authoritative: true),
      );
      expect(find.byKey(favoriteFriendsLoadErrorKey), findsNothing);
      expect(find.byKey(favoriteFriendsEmptyKey), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('cold partial friends row keeps inline error and retry',
      (tester) async {
    final sources = _FavoriteSources();
    final friend = UsersRecord.collection.doc('friend-cold-partial');
    final conversation = _conversation(
      id: 'cold-partial-row',
      ownerUid: 'user-a',
      partnerUid: friend.id,
    );
    await _mount(tester, sources);

    await _emitFriends(
      tester,
      sources,
      'user-a',
      FavoriteFriendsLoadState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        rawHiddenChatKeys: const <String>[],
        friendsAreAuthoritative: false,
        hiddenChatKeysAreKnown: true,
        hiddenChatKeysAreAuthoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
      authoritative: false,
    );
    await _emitEventChats(tester, sources, 'user-a');
    await _selectFriendsTab(tester);
    expect(_conversationRow('cold-partial-row'), findsOneWidget);

    sources
        .conversationsFor('user-a')
        .addError(StateError('cold partial conversations failed'));
    await tester.pump();

    expect(_conversationRow('cold-partial-row'), findsOneWidget);
    expect(find.byKey(favoriteFriendsInlineErrorKey), findsOneWidget);
    expect(find.byKey(favoriteFriendsRetryButtonKey), findsOneWidget);
    expect(find.byKey(favoriteFriendsLoadErrorKey), findsNothing);
  });

  testWidgets('cold conversations error is localized in English',
      (tester) async {
    final sources = _FavoriteSources();
    await _mount(tester, sources, locale: const Locale('en'));

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    sources
        .conversationsFor('user-a')
        .addError(StateError('conversations failed'));
    await tester.pump();
    await _emitEventChats(tester, sources, 'user-a');
    await tester.tap(find.text('Friends'));
    await tester.pump();

    expect(find.byKey(favoriteFriendsLoadErrorKey), findsOneWidget);
    expect(find.byType(UxErrorState), findsOneWidget);
    expect(find.byType(EmptyWidget), findsNothing);
    expect(find.text('Could not load chats'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text('Could not load chats with friends. Please try again later.'),
      findsOneWidget,
    );
  });

  testWidgets('empty and data survive source errors with a live retry notice',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final sources = _FavoriteSources();
      await _mount(tester, sources);

      await _emitFriends(
        tester,
        sources,
        'user-a',
        _friendsState(ownerUid: 'user-a', authoritative: true),
      );
      await _emitConversations(tester, sources, 'user-a', const []);
      await _emitEventChats(tester, sources, 'user-a');
      await _selectFriendsTab(tester);
      expect(find.byKey(favoriteFriendsEmptyKey), findsOneWidget);

      sources.friendsFor('user-a').addError(StateError('friends failed'));
      await tester.pump();

      expect(find.byKey(favoriteFriendsEmptyKey), findsOneWidget);
      expect(find.byKey(favoriteFriendsInlineErrorKey), findsOneWidget);
      expect(find.byKey(favoriteFriendsLoadErrorKey), findsNothing);
      expect(
        tester
            .getSemantics(find.byKey(favoriteFriendsInlineErrorKey))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );

      await tester.tap(find.byKey(favoriteFriendsRetryButtonKey));
      await tester.pump();
      expect(find.byKey(favoriteFriendsInlineErrorKey), findsNothing);
      expect(find.byKey(favoriteFriendsEmptyKey), findsOneWidget);
      expect(
        find.bySemanticsLabel('Обновление чатов с друзьями'),
        findsNothing,
      );

      final friend = UsersRecord.collection.doc('friend-retry');
      final conversation = _conversation(
        id: 'retry-row',
        ownerUid: 'user-a',
        partnerUid: 'friend-retry',
      );
      await _emitFriends(
        tester,
        sources,
        'user-a',
        _friendsState(
          ownerUid: 'user-a',
          friends: <DocumentReference>[friend],
          authoritative: true,
        ),
      );
      expect(find.byKey(favoriteFriendsInlineErrorKey), findsNothing);
      await _emitConversations(
        tester,
        sources,
        'user-a',
        <ConversationsRecord>[conversation],
      );
      expect(_conversationRow('retry-row'), findsOneWidget);
      final rowTopLeft = tester.getTopLeft(_conversationRow('retry-row'));
      final rowSize = tester.getSize(_conversationRow('retry-row'));

      sources
          .conversationsFor('user-a')
          .addError(StateError('conversations failed'));
      await tester.pump();

      expect(_conversationRow('retry-row'), findsOneWidget);
      expect(find.byKey(favoriteFriendsInlineErrorKey), findsOneWidget);
      expect(find.byKey(favoriteFriendsLoadErrorKey), findsNothing);
      expect(find.text('Повторить'), findsOneWidget);
      expect(tester.getTopLeft(_conversationRow('retry-row')), rowTopLeft);
      expect(tester.getSize(_conversationRow('retry-row')), rowSize);

      await tester.tap(find.byKey(favoriteFriendsRetryButtonKey));
      await tester.pump();
      expect(find.byKey(favoriteFriendsInlineErrorKey), findsNothing);
      expect(
        find.bySemanticsLabel('Обновление чатов с друзьями'),
        findsNothing,
      );
      expect(tester.getTopLeft(_conversationRow('retry-row')), rowTopLeft);
      expect(tester.getSize(_conversationRow('retry-row')), rowSize);

      await _emitConversations(
        tester,
        sources,
        'user-a',
        <ConversationsRecord>[conversation],
      );
      expect(find.byKey(favoriteFriendsInlineErrorKey), findsNothing);
      expect(tester.getTopLeft(_conversationRow('retry-row')), rowTopLeft);
      expect(tester.getSize(_conversationRow('retry-row')), rowSize);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('account switch and logout remove A and ignore late A events',
      (tester) async {
    final sources = _FavoriteSources();
    final friendA = UsersRecord.collection.doc('friend-a');
    final conversationA = _conversation(
      id: 'chat-a',
      ownerUid: 'user-a',
      partnerUid: 'friend-a',
    );
    await _mount(tester, sources);

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friendA],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversationA],
    );
    await _emitEventChats(tester, sources, 'user-a');
    await _selectFriendsTab(tester);
    expect(_conversationRow('chat-a'), findsOneWidget);

    sources.switchAuthenticatedUid('user-b');
    await tester.pump();
    expect(_conversationRow('chat-a'), findsNothing);

    sources.conversationsFor('user-a').add(
          FavoriteConversationsLoadState(
            ownerUid: 'user-a',
            isAuthoritative: true,
            conversations: <ConversationsRecord>[conversationA],
          ),
        );
    sources.friendsFor('user-a').add(
          _friendsState(
            ownerUid: 'user-a',
            friends: <DocumentReference>[friendA],
            authoritative: true,
          ),
        );
    await tester.pump();
    expect(_conversationRow('chat-a'), findsNothing);

    sources.switchAuthenticatedUid('');
    await tester.pump();
    expect(_conversationRow('chat-a'), findsNothing);
    expect(find.text('Чаты'), findsOneWidget);
  });

  testWidgets('direct auth mismatch clears A before the auth stream catches up',
      (tester) async {
    final sources = _FavoriteSources();
    final conversationA = _conversation(
      id: 'direct-a',
      ownerUid: 'user-a',
      partnerUid: 'friend-a',
    );
    final conversationB = _conversation(
      id: 'direct-b',
      ownerUid: 'user-b',
      partnerUid: 'friend-b',
    );
    await _mount(tester, sources);
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversationA],
    );
    await _emitEventChats(tester, sources, 'user-a');
    expect(_conversationRow('direct-a'), findsOneWidget);

    sources.authenticatedUid = 'user-b';
    sources.conversationsFor('user-a').add(
          FavoriteConversationsLoadState(
            ownerUid: 'user-a',
            isAuthoritative: true,
            conversations: <ConversationsRecord>[conversationA],
          ),
        );
    await tester.pump();
    await tester.pump();

    expect(_conversationRow('direct-a'), findsNothing);
    expect(find.byType(EmptyWidget), findsNothing);
    expect(find.byType(UxErrorState), findsNothing);
    expect(sources.friendsListenCounts['user-b'] ?? 0, 0);
    expect(FavoriteWidget.debugUserScopedCacheContains('user-a'), isFalse);

    sources.auth.add('user-b');
    await tester.pump();
    await _emitFriends(
      tester,
      sources,
      'user-b',
      _friendsState(ownerUid: 'user-b', authoritative: true),
    );
    await _emitConversations(
      tester,
      sources,
      'user-b',
      <ConversationsRecord>[conversationB],
    );
    await _emitEventChats(tester, sources, 'user-b');
    expect(_conversationRow('direct-b'), findsOneWidget);

    sources.authenticatedUid = '';
    sources.conversationsFor('user-b').add(
          FavoriteConversationsLoadState(
            ownerUid: 'user-b',
            isAuthoritative: true,
            conversations: <ConversationsRecord>[conversationB],
          ),
        );
    await tester.pump();
    await tester.pump();

    expect(_conversationRow('direct-b'), findsNothing);
    expect(find.byType(EmptyWidget), findsNothing);
    expect(find.byType(UxErrorState), findsNothing);
  });

  testWidgets('friend chat hides delete icon and exposes dismiss semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final (locale, tabLabel) in <(Locale, String)>[
        (const Locale('ru'), 'Друзья'),
        (const Locale('en'), 'Friends'),
      ]) {
        final sources = _FavoriteSources();
        final friend = UsersRecord.collection.doc('friend-delete');
        final conversation = _conversation(
          id: 'delete-row',
          ownerUid: 'user-a',
          partnerUid: 'friend-delete',
        );
        await _mount(
          tester,
          sources,
          locale: locale,
          profileLoader: (reference) async => _profile(
            reference.id,
            displayName: 'Анна',
          ),
        );
        await _emitFriends(
          tester,
          sources,
          'user-a',
          _friendsState(
            ownerUid: 'user-a',
            friends: <DocumentReference>[friend],
            authoritative: true,
          ),
        );
        await _emitConversations(
          tester,
          sources,
          'user-a',
          <ConversationsRecord>[conversation],
        );
        await _emitEventChats(tester, sources, 'user-a');
        await tester.tap(find.text(tabLabel));
        await tester.pump();
        await tester.pump();

        final dismissAction = find.byKey(
          favoriteChatDismissActionKey('conversation:delete-row'),
        );
        final dismissSemantics = tester.getSemantics(dismissAction);

        expect(dismissAction, findsOneWidget);
        expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
        expect(
          dismissSemantics
              .getSemanticsData()
              .hasAction(SemanticsAction.dismiss),
          isTrue,
        );
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('late A1 profile success cannot seed the A2 owner cache',
      (tester) async {
    final sources = _FavoriteSources();
    final profileLoads = <Completer<UserPublicProfilesRecord?>>[];
    final conversation = _conversation(
      id: 'profile-success-aba',
      ownerUid: 'user-a',
      partnerUid: 'friend-profile-success-aba',
    );
    await _mount(
      tester,
      sources,
      profileLoader: (_) {
        final load = Completer<UserPublicProfilesRecord?>();
        profileLoads.add(load);
        return load.future;
      },
    );

    Future<void> emitAConversation() async {
      await _emitFriends(
        tester,
        sources,
        'user-a',
        _friendsState(ownerUid: 'user-a', authoritative: true),
      );
      await _emitConversations(
        tester,
        sources,
        'user-a',
        <ConversationsRecord>[conversation],
      );
      await _emitEventChats(tester, sources, 'user-a');
    }

    await emitAConversation();
    expect(profileLoads, hasLength(1));
    sources.switchAuthenticatedUid('user-b');
    await tester.pump();
    sources.switchAuthenticatedUid('user-a');
    await tester.pump();
    await emitAConversation();
    expect(profileLoads, hasLength(2));

    profileLoads.first.complete(
      _profile(
        'friend-profile-success-aba',
        displayName: 'Stale A1 profile',
      ),
    );
    await tester.pump();
    await _emitConversations(tester, sources, 'user-a', const []);
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );

    expect(find.text('Stale A1 profile'), findsNothing);
    expect(profileLoads, hasLength(2));

    profileLoads.last.complete(
      _profile(
        'friend-profile-success-aba',
        displayName: 'Fresh A2 profile',
      ),
    );
    await tester.pump();
    expect(find.text('Fresh A2 profile'), findsOneWidget);
  });

  testWidgets('conversation async state follows identity across reorder',
      (tester) async {
    final sources = _FavoriteSources();
    final profileLoads = <String, Completer<UserPublicProfilesRecord?>>{};
    final conversationX = _conversation(
      id: 'reorder-x',
      ownerUid: 'user-a',
      partnerUid: 'friend-reorder-x',
      lastMessageAt: DateTime.parse('2026-07-13T12:00:00Z'),
    );
    final conversationY = _conversation(
      id: 'reorder-y',
      ownerUid: 'user-a',
      partnerUid: 'friend-reorder-y',
      lastMessageAt: DateTime.parse('2026-07-13T11:00:00Z'),
    );
    await _mount(
      tester,
      sources,
      profileLoader: (reference) => profileLoads
          .putIfAbsent(
            reference.id,
            () => Completer<UserPublicProfilesRecord?>(),
          )
          .future,
    );
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversationX, conversationY],
    );
    await _emitEventChats(tester, sources, 'user-a');

    profileLoads['friend-reorder-x']!.complete(
      _profile('friend-reorder-x', displayName: 'Profile X'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Profile X'), findsOneWidget);
    expect(
      tester.getTopLeft(_conversationRow('reorder-x')).dy,
      lessThan(tester.getTopLeft(_conversationRow('reorder-y')).dy),
    );

    final reorderedX = _conversation(
      id: 'reorder-x',
      ownerUid: 'user-a',
      partnerUid: 'friend-reorder-x',
      lastMessageAt: DateTime.parse('2026-07-13T10:00:00Z'),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[reorderedX, conversationY],
    );

    final xAsyncRow = find.byKey(
      favoriteConversationAsyncRowKey(
        ownerUid: 'user-a',
        conversationPath: conversationX.reference.path,
      ),
    );
    final yAsyncRow = find.byKey(
      favoriteConversationAsyncRowKey(
        ownerUid: 'user-a',
        conversationPath: conversationY.reference.path,
      ),
    );
    expect(
      tester.getTopLeft(_conversationRow('reorder-y')).dy,
      lessThan(tester.getTopLeft(_conversationRow('reorder-x')).dy),
    );
    expect(find.descendant(of: xAsyncRow, matching: find.text('Profile X')),
        findsOneWidget);
    expect(find.descendant(of: yAsyncRow, matching: find.text('Profile X')),
        findsNothing);
  });

  testWidgets('two event async rows keep title and preview with identity',
      (tester) async {
    final sources = _FavoriteSources();
    final eventLoads = <String, Completer<EventsRecord?>>{};
    final previews = <String, StreamController<EventChatMessagesLoadState>>{
      'event-reorder-x':
          StreamController<EventChatMessagesLoadState>.broadcast(sync: true),
      'event-reorder-y':
          StreamController<EventChatMessagesLoadState>.broadcast(sync: true),
    };
    for (final preview in previews.values) {
      addTearDown(preview.close);
    }
    final chatX = _eventChat(
      'event-reorder-x',
      updatedAt: DateTime.parse('2026-07-13T12:00:00Z'),
    );
    final chatY = _eventChat(
      'event-reorder-y',
      updatedAt: DateTime.parse('2026-07-13T11:00:00Z'),
    );
    final messageX = _eventMessage(
      chat: chatX,
      id: 'event-reorder-message-x',
      text: 'Preview X',
      createdAt: DateTime.parse('2026-07-13T12:01:00Z'),
    );
    await _mount(
      tester,
      sources,
      eventLoader: (eventId) => eventLoads
          .putIfAbsent(eventId, () => Completer<EventsRecord?>())
          .future,
      latestMessageSource: (_, chat) {
        final eventId = EventGroupChatRepository.eventIdForChat(chat);
        return previews[eventId]!.stream;
      },
    );
    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(ownerUid: 'user-a', authoritative: true),
    );
    await _emitConversations(tester, sources, 'user-a', const []);
    await _emitEventChats(
      tester,
      sources,
      'user-a',
      eventChats: <EventChatsRecord>[chatX, chatY],
    );

    previews['event-reorder-x']!.add(
      EventChatMessagesLoadState(
        ownerUid: 'user-a',
        messages: <EventChatMessagesRecord>[messageX],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    eventLoads['event-reorder-x']!.complete(
      _event('event-reorder-x', title: 'Event X title'),
    );
    await tester.pump();
    await tester.pump();

    final xAsyncRow = find.byKey(
      favoriteEventChatAsyncRowKey(
        ownerUid: 'user-a',
        chatPath: chatX.reference.path,
        eventId: chatX.eventId,
      ),
    );
    final yAsyncRow = find.byKey(
      favoriteEventChatAsyncRowKey(
        ownerUid: 'user-a',
        chatPath: chatY.reference.path,
        eventId: chatY.eventId,
      ),
    );
    expect(xAsyncRow, findsOneWidget);
    expect(yAsyncRow, findsOneWidget);
    expect(
      find.descendant(of: xAsyncRow, matching: find.text('Event X title')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: xAsyncRow, matching: find.text('Preview X')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey<String>('favorite_chat_event:event-reorder-x'),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                const ValueKey<String>('favorite_chat_event:event-reorder-y'),
              ),
            )
            .dy,
      ),
    );

    final reorderedX = _eventChat(
      'event-reorder-x',
      updatedAt: DateTime.parse('2026-07-13T10:00:00Z'),
    );
    await _emitEventChats(
      tester,
      sources,
      'user-a',
      eventChats: <EventChatsRecord>[reorderedX, chatY],
    );

    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey<String>('favorite_chat_event:event-reorder-y'),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                const ValueKey<String>('favorite_chat_event:event-reorder-x'),
              ),
            )
            .dy,
      ),
    );
    expect(
      find.descendant(of: xAsyncRow, matching: find.text('Event X title')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: xAsyncRow, matching: find.text('Preview X')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: yAsyncRow, matching: find.text('Event X title')),
      findsNothing,
    );
    expect(
      find.descendant(of: yAsyncRow, matching: find.text('Preview X')),
      findsNothing,
    );
  });

  testWidgets('late A1 profile error cannot evict the A2 in-flight load',
      (tester) async {
    final sources = _FavoriteSources();
    final profileLoads = <Completer<UserPublicProfilesRecord?>>[];
    final conversation = _conversation(
      id: 'profile-error-aba',
      ownerUid: 'user-a',
      partnerUid: 'friend-profile-error-aba',
    );
    await _mount(
      tester,
      sources,
      profileLoader: (_) {
        final load = Completer<UserPublicProfilesRecord?>();
        profileLoads.add(load);
        return load.future;
      },
    );

    Future<void> emitAConversation() async {
      await _emitFriends(
        tester,
        sources,
        'user-a',
        _friendsState(ownerUid: 'user-a', authoritative: true),
      );
      await _emitConversations(
        tester,
        sources,
        'user-a',
        <ConversationsRecord>[conversation],
      );
      await _emitEventChats(tester, sources, 'user-a');
    }

    await emitAConversation();
    sources.switchAuthenticatedUid('user-b');
    await tester.pump();
    sources.switchAuthenticatedUid('user-a');
    await tester.pump();
    await emitAConversation();
    expect(profileLoads, hasLength(2));

    profileLoads.first.completeError(StateError('late A1 profile error'));
    await tester.pump();
    await _emitConversations(tester, sources, 'user-a', const []);
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );

    expect(profileLoads, hasLength(2));
    profileLoads.last.complete(
      _profile(
        'friend-profile-error-aba',
        displayName: 'Fresh after A1 error',
      ),
    );
    await tester.pump();
    expect(find.text('Fresh after A1 error'), findsOneWidget);
  });

  for (final configuration
      in const <({Locale locale, double devicePixelRatio, String name})>[
    (locale: Locale('ru'), devicePixelRatio: 1.0, name: 'RU/DPR1'),
    (locale: Locale('en'), devicePixelRatio: 3.0, name: 'EN/DPR3'),
  ]) {
    testWidgets(
      'chat row keeps avatar, time, unread slot, and divider fixed for '
      '0/1/99/99+ (${configuration.name})',
      (tester) async {
        tester.view.devicePixelRatio = configuration.devicePixelRatio;
        tester.view.physicalSize = Size(
          320 * configuration.devicePixelRatio,
          900 * configuration.devicePixelRatio,
        );
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final sources = _FavoriteSources();
        final unreadCounts = StreamController<int>.broadcast(sync: true);
        addTearDown(unreadCounts.close);
        var unreadSourceCalls = 0;
        final id = 'unread-geometry-${configuration.locale.languageCode}';
        final hiddenChatKey = 'conversation:$id';
        final conversation = _conversation(
          id: id,
          ownerUid: 'user-a',
          partnerUid: 'friend-unread',
          lastMessageSenderId: 'friend-unread',
        );

        await _mount(
          tester,
          sources,
          locale: configuration.locale,
          profileLoader: (_) async => _profile(
            'friend-unread',
            displayName: 'A deliberately long conversation partner name',
          ),
          conversationUnreadCountSource: (conversation, currentUid) {
            expect(conversation.reference.id, id);
            expect(currentUid, 'user-a');
            unreadSourceCalls += 1;
            return unreadCounts.stream;
          },
        );
        await _emitFriends(
          tester,
          sources,
          'user-a',
          _friendsState(ownerUid: 'user-a', authoritative: true),
        );
        await _emitConversations(
          tester,
          sources,
          'user-a',
          <ConversationsRecord>[conversation],
        );
        await _emitEventChats(tester, sources, 'user-a');
        await tester.pump();

        expect(unreadSourceCalls, 1);
        unreadCounts.add(0);
        await tester.pump();

        final row = _conversationRow(id);
        final avatar = find.byKey(favoriteChatAvatarKey(hiddenChatKey));
        final timestamp = find.byKey(favoriteChatTimestampKey(hiddenChatKey));
        final timestampText =
            find.byKey(favoriteChatTimestampTextKey(hiddenChatKey));
        final unreadSlot = find.byKey(favoriteChatUnreadSlotKey(hiddenChatKey));
        final badge = find.byKey(favoriteChatUnreadBadgeKey(hiddenChatKey));
        final divider = find.byKey(favoriteChatDividerKey(hiddenChatKey));

        expect(row, findsOneWidget);
        expect(avatar, findsOneWidget);
        expect(timestamp, findsOneWidget);
        expect(timestampText, findsOneWidget);
        expect(unreadSlot, findsOneWidget);
        expect(divider, findsOneWidget);
        expect(badge, findsNothing);
        expect(tester.takeException(), isNull);

        final rowRect = tester.getRect(row);
        final avatarRect = tester.getRect(avatar);
        final timestampRect = tester.getRect(timestamp);
        final timestampTextRect = tester.getRect(timestampText);
        final unreadSlotRect = tester.getRect(unreadSlot);
        final dividerRect = tester.getRect(divider);
        expect(rowRect.height, favoriteChatRowHeight());
        expect(
          avatarRect.size,
          Size.square(favoriteChatAvatarSize()),
        );
        expect(timestampRect.width, favoriteChatTimestampWidth());
        expect(timestampRect.center.dy, avatarRect.center.dy);
        expect(unreadSlotRect.height, favoriteChatUnreadBadgeSize());
        expect(dividerRect.height, favoriteChatDividerThickness());

        void expectStableGeometry() {
          expect(tester.getRect(row), rowRect);
          expect(tester.getRect(avatar), avatarRect);
          expect(tester.getRect(timestamp), timestampRect);
          expect(tester.getRect(timestampText), timestampTextRect);
          expect(tester.getRect(unreadSlot), unreadSlotRect);
          expect(tester.getRect(divider), dividerRect);
          expect(tester.takeException(), isNull);
        }

        Future<void> emitUnreadCount(int count, String? expectedLabel) async {
          unreadCounts.add(count);
          await tester.pump();
          if (expectedLabel == null) {
            expect(badge, findsNothing);
          } else {
            expect(badge, findsOneWidget);
            expect(
              find.descendant(of: badge, matching: find.text(expectedLabel)),
              findsOneWidget,
            );
            expect(
              tester.getSize(badge),
              Size.square(favoriteChatUnreadBadgeSize()),
            );
          }
          expectStableGeometry();
        }

        await emitUnreadCount(1, '1');
        await emitUnreadCount(99, '99');
        await emitUnreadCount(100, '99+');
        await emitUnreadCount(0, null);
        await emitUnreadCount(-1, null);
        expect(unreadSourceCalls, 1);
      },
    );
  }

  testWidgets('actual conversation row keeps height across profile states',
      (tester) async {
    final profileCompleter = Completer<UserPublicProfilesRecord?>();
    final sources = _FavoriteSources();
    final friend = UsersRecord.collection.doc('friend-profile');
    final conversation = _conversation(
      id: 'profile-row',
      ownerUid: 'user-a',
      partnerUid: 'friend-profile',
    );
    await _mount(
      tester,
      sources,
      profileLoader: (_) => profileCompleter.future,
    );

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );
    await _emitEventChats(tester, sources, 'user-a');
    await _selectFriendsTab(tester);

    final row = _conversationRow('profile-row');
    expect(tester.getSize(row).height, favoriteChatRowHeight());

    profileCompleter.complete(
      UserPublicProfilesRecord.getDocumentFromData(
        <String, dynamic>{
          'userId': 'friend-profile',
          'display_name': 'Profile friend',
          'photo_url': '',
        },
        UserPublicProfilesRecord.collection.doc('friend-profile'),
      ),
    );
    await tester.pump();
    expect(find.text('Profile friend'), findsOneWidget);
    expect(tester.getSize(row).height, favoriteChatRowHeight());
  });

  testWidgets('actual conversation row keeps height on profile error',
      (tester) async {
    final sources = _FavoriteSources();
    final friend = UsersRecord.collection.doc('friend-error');
    final conversation = _conversation(
      id: 'profile-error-row',
      ownerUid: 'user-a',
      partnerUid: 'friend-error',
    );
    await _mount(
      tester,
      sources,
      profileLoader: (_) async => throw StateError('profile failed'),
    );

    await _emitFriends(
      tester,
      sources,
      'user-a',
      _friendsState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friend],
        authoritative: true,
      ),
    );
    await _emitConversations(
      tester,
      sources,
      'user-a',
      <ConversationsRecord>[conversation],
    );
    await _emitEventChats(tester, sources, 'user-a');
    await _selectFriendsTab(tester);
    await tester.pump();

    final row = _conversationRow('profile-error-row');
    expect(row, findsOneWidget);
    expect(tester.getSize(row).height, favoriteChatRowHeight());
    expect(find.text('Собеседник'), findsOneWidget);
  });
}
