import 'dart:async';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/services/event_group_chat_repository.dart';
import 'package:small_talk/services/ux_session_cache_lifecycle.dart';
import 'package:small_talk/students_pages/favorite/favorite_chat_source_state.dart';
import 'package:small_talk/students_pages/favorite/favorite_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  test('initial auth owner never falls back after Firebase logout', () {
    expect(favoriteAuthOwnerUid(' user-a '), 'user-a');
    expect(favoriteAuthOwnerUid(null), isEmpty);
  });

  test('required source refresh includes waiting and non-authoritative states',
      () {
    expect(
      favoriteRequiredSourceIsRefreshing(
        connectionState: ConnectionState.waiting,
        hasError: false,
        isAuthoritative: true,
      ),
      isTrue,
    );
    expect(
      favoriteRequiredSourceIsRefreshing(
        connectionState: ConnectionState.active,
        hasError: false,
        isAuthoritative: false,
      ),
      isTrue,
    );
    expect(
      favoriteRequiredSourceIsRefreshing(
        connectionState: ConnectionState.active,
        hasError: true,
        isAuthoritative: false,
      ),
      isFalse,
    );
    expect(
      favoriteRequiredSourceIsRefreshing(
        connectionState: ConnectionState.active,
        hasError: false,
        isAuthoritative: true,
      ),
      isFalse,
    );
  });

  group('friends document metadata adapter', () {
    FavoriteFriendsLoadState resolve({
      bool exists = true,
      List<DocumentReference> friends = const <DocumentReference>[],
      bool isFromCache = false,
      bool hasPendingWrites = false,
      String snapshotOwnerUid = 'user-a',
      Object? hiddenKeys = const <String>[],
    }) =>
        resolveFavoriteFriendsDocumentSnapshotState(
          expectedOwnerUid: 'user-a',
          snapshotOwnerUid: snapshotOwnerUid,
          documentExists: exists,
          friends: friends,
          rawHiddenChatKeys: hiddenKeys,
          isFromCache: isFromCache,
          hasPendingWrites: hasPendingWrites,
        );

    test('distinguishes cached, pending, data, and server empty', () {
      final friend = UsersRecord.collection.doc('friend-1');
      final cachedEmpty = resolve(isFromCache: true);
      final pendingEmpty = resolve(hasPendingWrites: true);
      final cachedData = resolve(
        friends: <DocumentReference>[friend],
        isFromCache: true,
      );
      final serverEmpty = resolve();

      expect(cachedEmpty.friendsAreAuthoritative, isFalse);
      expect(cachedEmpty.hasAuthoritativeResult, isFalse);
      expect(cachedEmpty.hiddenChatKeysAreKnown, isFalse);
      expect(pendingEmpty.friendsAreAuthoritative, isFalse);
      expect(pendingEmpty.hasAuthoritativeResult, isFalse);
      expect(pendingEmpty.hiddenChatKeysAreAuthoritative, isFalse);
      expect(cachedData.friends, <DocumentReference>[friend]);
      expect(cachedData.friendsAreAuthoritative, isFalse);
      expect(cachedData.hiddenChatKeysAreKnown, isFalse);
      expect(serverEmpty.friendsAreAuthoritative, isTrue);
      expect(serverEmpty.hasAuthoritativeResult, isTrue);
      expect(serverEmpty.hiddenChatKeysAreKnown, isTrue);
      expect(serverEmpty.hiddenChatKeysAreAuthoritative, isTrue);
    });

    test('fails closed for server missing and owner mismatch', () {
      final cachedMissing = resolve(exists: false, isFromCache: true);
      expect(cachedMissing.friendsAreAuthoritative, isFalse);
      expect(cachedMissing.hiddenChatKeysAreKnown, isFalse);

      expect(() => resolve(exists: false), throwsStateError);
      expect(
        () => resolve(snapshotOwnerUid: 'user-b'),
        throwsStateError,
      );
    });

    test('retains hidden keys until authoritative metadata removes them', () {
      final previous = resolve(
        hiddenKeys: const <String>['conversation:hidden'],
      );
      final pending = resolve(
        hasPendingWrites: true,
        hiddenKeys: const <String>[],
      );
      final retained = mergeFavoriteFriendsLoadState(previous, pending);

      expect(
        normalizeFavoriteHiddenChatKeys(retained.rawHiddenChatKeys),
        contains('conversation:hidden'),
      );
      expect(retained.hiddenChatKeysAreKnown, isTrue);
      expect(retained.hiddenChatKeysAreAuthoritative, isFalse);

      final removed = mergeFavoriteFriendsLoadState(retained, resolve());
      expect(
        normalizeFavoriteHiddenChatKeys(removed.rawHiddenChatKeys),
        isEmpty,
      );
      expect(removed.hiddenChatKeysAreAuthoritative, isTrue);
    });
  });

  group('favorite chat load-state reducers', () {
    test('partial friends retain absent rows until authoritative replacement',
        () {
      final friendA = UsersRecord.collection.doc('friend-a');
      final friendB = UsersRecord.collection.doc('friend-b');
      final previous = FavoriteFriendsLoadState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friendA, friendB],
        friendsAreAuthoritative: true,
      );
      final pending = FavoriteFriendsLoadState(
        ownerUid: 'user-a',
        friends: <DocumentReference>[friendB],
        friendsAreAuthoritative: false,
      );

      final partial = mergeFavoriteFriendsLoadState(previous, pending);
      expect(partial.friends.map((reference) => reference.id), [
        'friend-a',
        'friend-b',
      ]);
      expect(partial.friendsAreAuthoritative, isFalse);
      expect(partial.hasAuthoritativeResult, isTrue);
      expect(partial.isRefreshing, isTrue);

      final replaced = mergeFavoriteFriendsLoadState(
        partial,
        FavoriteFriendsLoadState(
          ownerUid: 'user-a',
          friends: <DocumentReference>[friendB],
          friendsAreAuthoritative: true,
        ),
      );
      expect(replaced.friends.map((reference) => reference.id), ['friend-b']);
      expect(replaced.friendsAreAuthoritative, isTrue);
      expect(replaced.hasAuthoritativeResult, isTrue);
    });

    test('partial conversations refresh matches and retain absent rows', () {
      ConversationsRecord conversation(String id, String text) =>
          ConversationsRecord.getDocumentFromData(
            <String, dynamic>{
              'pairId': id,
              'isUnlocked': true,
              'lastMessageText': text,
            },
            ConversationsRecord.collection.doc(id),
          );

      final conversationA = conversation('conversation-a', 'A');
      final conversationB1 = conversation('conversation-b', 'B1');
      final conversationB2 = conversation('conversation-b', 'B2');
      final previous = FavoriteConversationsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: true,
        conversations: <ConversationsRecord>[conversationA, conversationB1],
      );
      final pending = FavoriteConversationsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: false,
        conversations: <ConversationsRecord>[conversationB2],
      );

      final merged = mergeFavoriteConversationsLoadState(previous, pending);

      expect(
        merged.conversations.map((conversation) => conversation.reference.id),
        ['conversation-a', 'conversation-b'],
      );
      expect(merged.conversations.last, same(conversationB2));
      expect(merged.isAuthoritative, isFalse);
      expect(merged.hasAuthoritativeResult, isTrue);
      expect(merged.isRefreshing, isTrue);
    });

    test('partial event chats refresh matches and retain absent rows', () {
      EventChatsRecord chat(String id, DateTime updatedAt) =>
          EventChatsRecord.getDocumentFromData(
            <String, dynamic>{'eventId': id, 'updatedAt': updatedAt},
            EventChatsRecord.collection.doc(id),
          );

      final chatA = chat('event-a', DateTime.utc(2026, 7, 1));
      final chatB1 = chat('event-b', DateTime.utc(2026, 7, 1));
      final chatB2 = chat('event-b', DateTime.utc(2026, 7, 2));
      final previous = FavoriteEventChatsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: true,
        eventChats: <EventChatsRecord>[chatA, chatB1],
      );
      final pending = FavoriteEventChatsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: false,
        eventChats: <EventChatsRecord>[chatB2],
      );

      final merged = mergeFavoriteEventChatsLoadState(previous, pending);

      expect(
        merged.eventChats.map(EventGroupChatRepository.eventIdForChat),
        ['event-a', 'event-b'],
      );
      expect(merged.eventChats.last, same(chatB2));
      expect(merged.isAuthoritative, isFalse);
      expect(merged.hasAuthoritativeResult, isTrue);
      expect(merged.isRefreshing, isTrue);
    });

    test('partial conversations retain filtered-empty confirmation', () {
      const previous = FavoriteConversationsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: true,
      );
      const pending = FavoriteConversationsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: false,
      );

      final merged = mergeFavoriteConversationsLoadState(previous, pending);

      expect(merged.ownerUid, 'user-a');
      expect(merged.isAuthoritative, isFalse);
      expect(merged.hasAuthoritativeResult, isTrue);
      expect(merged.isRefreshing, isTrue);
      expect(merged.conversations, isEmpty);
    });

    test('partial event chats retain filtered-empty confirmation', () {
      const previous = FavoriteEventChatsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: true,
      );
      const partial = FavoriteEventChatsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: false,
      );

      final merged = mergeFavoriteEventChatsLoadState(previous, partial);

      expect(merged.ownerUid, 'user-a');
      expect(merged.isAuthoritative, isFalse);
      expect(merged.hasAuthoritativeResult, isTrue);
      expect(merged.isRefreshing, isTrue);
      expect(merged.eventChats, isEmpty);
    });

    test('cold partial empty never becomes a confirmed empty result', () {
      const conversations = FavoriteConversationsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: false,
      );
      const eventChats = FavoriteEventChatsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: false,
      );
      const friends = FavoriteFriendsLoadState(
        ownerUid: 'user-a',
        friendsAreAuthoritative: false,
        hiddenChatKeysAreKnown: false,
        hiddenChatKeysAreAuthoritative: false,
      );

      expect(conversations.hasAuthoritativeResult, isFalse);
      expect(eventChats.hasAuthoritativeResult, isFalse);
      expect(friends.hasAuthoritativeResult, isFalse);
    });

    test('reject mixing owner scopes in chat reducers', () {
      const ownerA = FavoriteConversationsLoadState(
        ownerUid: 'user-a',
        isAuthoritative: true,
      );
      const ownerB = FavoriteConversationsLoadState(
        ownerUid: 'user-b',
        isAuthoritative: true,
      );

      expect(
        () => mergeFavoriteConversationsLoadState(ownerA, ownerB),
        throwsStateError,
      );
    });
  });

  group('resolveFavoriteFriendsTabViewState', () {
    test('keeps cold sources in initial loading', () {
      expect(
        resolveFavoriteFriendsTabViewState(
          conversationsLoading: true,
          conversationsLoadFailed: false,
          conversationsHasLoaded: false,
          friendsLoading: false,
          friendsLoadFailed: false,
          friendsHasLoaded: true,
          hasFriendConversations: false,
        ),
        FavoriteFriendsTabViewState.initialLoading,
      );
      expect(
        resolveFavoriteFriendsTabViewState(
          conversationsLoading: false,
          conversationsLoadFailed: false,
          conversationsHasLoaded: true,
          friendsLoading: true,
          friendsLoadFailed: false,
          friendsHasLoaded: false,
          hasFriendConversations: false,
        ),
        FavoriteFriendsTabViewState.initialLoading,
      );
    });

    test('shows data whenever friend conversations exist', () {
      expect(
        resolveFavoriteFriendsTabViewState(
          conversationsLoading: false,
          conversationsLoadFailed: false,
          conversationsHasLoaded: true,
          friendsLoading: false,
          friendsLoadFailed: false,
          friendsHasLoaded: true,
          hasFriendConversations: true,
        ),
        FavoriteFriendsTabViewState.data,
      );
    });

    test('shows empty only after conversations and friends are loaded', () {
      expect(
        resolveFavoriteFriendsTabViewState(
          conversationsLoading: false,
          conversationsLoadFailed: false,
          conversationsHasLoaded: true,
          friendsLoading: false,
          friendsLoadFailed: false,
          friendsHasLoaded: true,
          hasFriendConversations: false,
        ),
        FavoriteFriendsTabViewState.empty,
      );
    });

    test('cold conversations error wins over friends empty/loading', () {
      expect(
        resolveFavoriteFriendsTabViewState(
          conversationsLoading: false,
          conversationsLoadFailed: true,
          conversationsHasLoaded: false,
          friendsLoading: true,
          friendsLoadFailed: false,
          friendsHasLoaded: false,
          hasFriendConversations: false,
        ),
        FavoriteFriendsTabViewState.errorWithoutData,
      );
    });

    test('cold friends error wins over confirmed empty conversations', () {
      expect(
        resolveFavoriteFriendsTabViewState(
          conversationsLoading: false,
          conversationsLoadFailed: false,
          conversationsHasLoaded: true,
          friendsLoading: false,
          friendsLoadFailed: true,
          friendsHasLoaded: false,
          hasFriendConversations: false,
        ),
        FavoriteFriendsTabViewState.errorWithoutData,
      );
    });
  });

  group('transformFavoriteFirestoreSnapshots', () {
    test('waits through cached and pending empty until server confirmation',
        () async {
      final controller =
          StreamController<FavoriteFirestoreSourceSnapshot<List<String>>>(
              sync: true);
      final emitted = <FavoriteFirestoreSourceSnapshot<List<String>>>[];
      final subscription = transformFavoriteFirestoreSnapshots(
        controller.stream,
      ).listen(emitted.add);

      controller.add(
        const FavoriteFirestoreSourceSnapshot<List<String>>(
          value: <String>[],
          isEmpty: true,
          isFromCache: true,
          hasPendingWrites: false,
        ),
      );
      controller.add(
        const FavoriteFirestoreSourceSnapshot<List<String>>(
          value: <String>[],
          isEmpty: true,
          isFromCache: false,
          hasPendingWrites: true,
        ),
      );
      expect(emitted, isEmpty);

      controller.add(
        const FavoriteFirestoreSourceSnapshot<List<String>>(
          value: <String>[],
          isEmpty: true,
          isFromCache: false,
          hasPendingWrites: false,
        ),
      );
      expect(emitted, hasLength(1));
      expect(emitted.single.hasServerConfirmedEmpty, isTrue);

      await subscription.cancel();
      await controller.close();
    });

    test('publishes cached data and propagates source errors', () async {
      final sourceError = StateError('source failed');
      final controller =
          StreamController<FavoriteFirestoreSourceSnapshot<List<String>>>(
              sync: true);
      final emitted = <FavoriteFirestoreSourceSnapshot<List<String>>>[];
      final errors = <Object>[];
      final subscription = transformFavoriteFirestoreSnapshots(
        controller.stream,
      ).listen(emitted.add, onError: errors.add);

      controller.add(
        const FavoriteFirestoreSourceSnapshot<List<String>>(
          value: <String>['cached'],
          isEmpty: false,
          isFromCache: true,
          hasPendingWrites: false,
        ),
      );
      controller.addError(sourceError);

      expect(emitted.single.value, <String>['cached']);
      expect(errors, <Object>[sourceError]);

      await subscription.cancel();
      await controller.close();
    });
  });

  test('owned user values never cross UID or logout boundaries', () {
    final friendsA = <String>['friend-a'];
    final hiddenKeysA = <String>{'conversation:a'};

    expect(
      favoriteOwnedUserDocumentValue(
        currentUid: 'user-a',
        documentOwnerUid: 'user-a',
        value: friendsA,
      ),
      same(friendsA),
    );
    expect(
      favoriteOwnedUserDocumentValue(
        currentUid: 'user-b',
        documentOwnerUid: 'user-a',
        value: friendsA,
      ),
      isNull,
    );
    expect(
      favoriteOwnedUserDocumentValue(
        currentUid: '',
        documentOwnerUid: 'user-a',
        value: hiddenKeysA,
      ),
      isNull,
    );
  });

  test('favorite user caches clear on account change and logout', () {
    UxSessionCacheLifecycle.debugResetForTesting();
    FavoriteWidget.debugClearSessionCache();
    addTearDown(() {
      FavoriteWidget.debugClearSessionCache();
      UxSessionCacheLifecycle.debugResetForTesting();
    });

    FavoriteWidget.debugEnsureSessionCacheLifecycleRegistered();
    UxSessionCacheLifecycle.updateAuthenticatedUser('user-a');
    FavoriteWidget.debugSeedUserScopedCache('user-a');
    expect(FavoriteWidget.debugUserScopedCacheContains('user-a'), isTrue);

    UxSessionCacheLifecycle.updateAuthenticatedUser('user-b');
    expect(FavoriteWidget.debugUserScopedCacheContains('user-a'), isFalse);

    FavoriteWidget.debugSeedUserScopedCache('user-b');
    expect(FavoriteWidget.debugUserScopedCacheContains('user-b'), isTrue);

    UxSessionCacheLifecycle.updateAuthenticatedUser(null);
    expect(FavoriteWidget.debugUserScopedCacheContains('user-b'), isFalse);
  });

  testWidgets('friends state slot renders one deterministic branch',
      (tester) async {
    const rowKey = ValueKey<String>('friends-test-row');

    Widget app(FavoriteFriendsTabViewState state) {
      return MaterialApp(
        home: Scaffold(
          body: FavoriteFriendsTabStateSlot(
            state: state,
            initialLoading: const Text('loading'),
            data: SizedBox(
              key: rowKey,
              height: favoriteChatRowHeight(),
              child: const Text('data'),
            ),
            empty: const Text('empty'),
            errorWithoutData: const Text('error'),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      app(FavoriteFriendsTabViewState.initialLoading),
    );
    expect(find.byKey(favoriteFriendsInitialLoadingKey), findsOneWidget);
    expect(find.byKey(favoriteFriendsEmptyKey), findsNothing);

    await tester.pumpWidget(app(FavoriteFriendsTabViewState.data));
    expect(find.byKey(favoriteFriendsDataKey), findsOneWidget);
    expect(tester.getSize(find.byKey(rowKey)).height, favoriteChatRowHeight());

    await tester.pumpWidget(app(FavoriteFriendsTabViewState.empty));
    expect(find.byKey(favoriteFriendsEmptyKey), findsOneWidget);
    expect(find.byKey(favoriteFriendsLoadErrorKey), findsNothing);

    await tester.pumpWidget(
      app(FavoriteFriendsTabViewState.errorWithoutData),
    );
    expect(find.byKey(favoriteFriendsLoadErrorKey), findsOneWidget);
    expect(find.byKey(favoriteFriendsEmptyKey), findsNothing);
    expect(find.text('error'), findsOneWidget);
  });

  testWidgets('either required source cold error renders the error branch',
      (tester) async {
    Widget app({
      required bool conversationsFailed,
      required bool friendsFailed,
    }) {
      final state = resolveFavoriteFriendsTabViewState(
        conversationsLoading: false,
        conversationsLoadFailed: conversationsFailed,
        conversationsHasLoaded: !conversationsFailed,
        friendsLoading: false,
        friendsLoadFailed: friendsFailed,
        friendsHasLoaded: !friendsFailed,
        hasFriendConversations: false,
      );
      return MaterialApp(
        home: Scaffold(
          body: FavoriteFriendsTabStateSlot(
            state: state,
            initialLoading: const Text('loading'),
            data: const Text('data'),
            empty: const Text('empty'),
            errorWithoutData: const Text('cold error'),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      app(conversationsFailed: true, friendsFailed: false),
    );
    expect(find.byKey(favoriteFriendsLoadErrorKey), findsOneWidget);
    expect(find.text('cold error'), findsOneWidget);
    expect(find.byKey(favoriteFriendsEmptyKey), findsNothing);

    await tester.pumpWidget(
      app(conversationsFailed: false, friendsFailed: true),
    );
    expect(find.byKey(favoriteFriendsLoadErrorKey), findsOneWidget);
    expect(find.text('cold error'), findsOneWidget);
    expect(find.byKey(favoriteFriendsEmptyKey), findsNothing);
  });
}
