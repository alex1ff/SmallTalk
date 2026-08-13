import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/components/empty/empty_widget.dart';
import '/components/segmented_tab_bar.dart';
import '/components/ux_error_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/chat_call_event_presentation.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/chat_thread/open_chat_thread.dart';
import '/shared_pages/events/event_group_chat_widget.dart';
import '/services/event_group_chat_repository.dart';
import '/services/new_account_inbox_bootstrap.dart';
import '/services/ux_loading_state.dart';
import '/services/ux_session_cache_lifecycle.dart';
import '/services/ux_session_loaded_result_cache.dart';

import 'favorite_chat_source_state.dart';
import 'favorite_model.dart';
export 'favorite_model.dart';

const double _favoriteChatAvatarSize = 52.0;
const double _favoriteChatTimestampWidth = 74.0;
const double _favoriteChatRowContentHeight = 76.0;
const double _favoriteChatRowHeight = _favoriteChatRowContentHeight + 1.0;
const double _favoriteChatTrailingHeight = 48.0;
const double _favoriteChatUnreadSlotHeight = 30.0;
const double _favoriteChatUnreadBadgeSize = 30.0;
const double _favoriteChatDividerThickness = 1.0;
const Color _favoriteChatDividerColor = Color(0xFFEBEBEB);
const Color _favoriteChatDeleteBackground = Color(0xFFFF3B30);

const ValueKey<String> favoriteMessagesLoadErrorKey =
    ValueKey<String>('favorite_messages_load_error');
const ValueKey<String> favoriteMessagesInlineErrorKey =
    ValueKey<String>('favorite_messages_inline_error');
const ValueKey<String> favoriteMessagesListKey =
    ValueKey<String>('favorite_messages_list');
const ValueKey<String> favoriteMessagesRetryButtonKey =
    ValueKey<String>('favorite_messages_retry_button');
const ValueKey<String> favoriteMessagesInitialLoadingKey =
    ValueKey<String>('favorite_messages_initial_loading');

ValueKey<String> favoriteChatDismissActionKey(String hiddenChatKey) =>
    ValueKey<String>('favorite_chat_dismiss_$hiddenChatKey');
ValueKey<String> favoriteChatAvatarKey(String hiddenChatKey) =>
    ValueKey<String>('favorite_chat_avatar_$hiddenChatKey');
ValueKey<String> favoriteChatTimestampKey(String hiddenChatKey) =>
    ValueKey<String>('favorite_chat_timestamp_$hiddenChatKey');
ValueKey<String> favoriteChatTimestampTextKey(String hiddenChatKey) =>
    ValueKey<String>('favorite_chat_timestamp_text_$hiddenChatKey');
ValueKey<String> favoriteChatUnreadSlotKey(String hiddenChatKey) =>
    ValueKey<String>('favorite_chat_unread_slot_$hiddenChatKey');
ValueKey<String> favoriteChatUnreadBadgeKey(String hiddenChatKey) =>
    ValueKey<String>('favorite_chat_unread_badge_$hiddenChatKey');
ValueKey<String> favoriteChatDividerKey(String hiddenChatKey) =>
    ValueKey<String>('favorite_chat_divider_$hiddenChatKey');
Key favoriteConversationAsyncRowKey({
  required String ownerUid,
  required String conversationPath,
}) =>
    ValueKey(('favorite-conversation-async-row', ownerUid, conversationPath));
Key favoriteEventChatAsyncRowKey({
  required String ownerUid,
  required String chatPath,
  required String eventId,
}) =>
    ValueKey(('favorite-event-async-row', ownerUid, chatPath, eventId));

String formatFavoriteInboxTimestamp(DateTime? timestamp, {DateTime? now}) {
  if (timestamp == null) {
    return '';
  }

  final localTime = timestamp.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  final sameDay = DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
      ) ==
      DateTime(
        localTime.year,
        localTime.month,
        localTime.day,
      );

  if (sameDay) {
    return DateFormat('HH:mm').format(localTime);
  }

  if (localTime.year == localNow.year) {
    return DateFormat('MM/dd').format(localTime);
  }

  return DateFormat('MM/dd/yy').format(localTime);
}

Set<String> normalizeFavoriteHiddenChatKeys(Object? rawHiddenChatKeys) {
  final keys = <String>{};

  void addHiddenKey(String rawKey) {
    final key = rawKey.trim();
    if (key.isNotEmpty) {
      keys.add(key);
    }
  }

  if (rawHiddenChatKeys is Iterable) {
    for (final rawKey in rawHiddenChatKeys) {
      if (rawKey is String) {
        addHiddenKey(rawKey);
      }
    }
  }

  return keys;
}

class FavoriteHiddenChatKeySyncResult {
  const FavoriteHiddenChatKeySyncResult({
    required this.optimisticHiddenKeys,
    required this.serverConfirmedOptimisticHiddenKeys,
  });

  final Set<String> optimisticHiddenKeys;
  final Set<String> serverConfirmedOptimisticHiddenKeys;
}

FavoriteHiddenChatKeySyncResult syncFavoriteOptimisticHiddenChatKeys({
  required Iterable<String> optimisticHiddenKeys,
  required Iterable<String> serverConfirmedOptimisticHiddenKeys,
  required Set<String> serverHiddenKeys,
}) {
  final confirmedInput = normalizeFavoriteHiddenChatKeys(
    serverConfirmedOptimisticHiddenKeys,
  );
  final nextOptimistic = <String>{};
  final nextConfirmed = <String>{};

  for (final rawKey in optimisticHiddenKeys) {
    final key = rawKey.trim();
    if (key.isEmpty) {
      continue;
    }

    final serverHasKey = serverHiddenKeys.contains(key);
    if (serverHasKey) {
      nextOptimistic.add(key);
      nextConfirmed.add(key);
      continue;
    }

    if (!confirmedInput.contains(key)) {
      nextOptimistic.add(key);
    }
  }

  return FavoriteHiddenChatKeySyncResult(
    optimisticHiddenKeys: nextOptimistic,
    serverConfirmedOptimisticHiddenKeys: nextConfirmed,
  );
}

Set<String> resolveFavoriteEffectiveHiddenChatKeys({
  required Object? rawHiddenChatKeys,
  Iterable<String> rememberedEventIds = const <String>[],
  Iterable<String> optimisticHiddenKeys = const <String>[],
}) {
  final keys = normalizeFavoriteHiddenChatKeys(rawHiddenChatKeys);

  for (final rawEventId in rememberedEventIds) {
    final eventId = rawEventId.trim();
    if (eventId.isNotEmpty) {
      keys.remove('event:$eventId');
    }
  }

  keys.addAll(normalizeFavoriteHiddenChatKeys(optimisticHiddenKeys));

  return keys;
}

bool shouldShowFavoriteMessagesLoadError({
  required bool conversationsLoadFailed,
  required bool eventChatsLoadFailed,
  required bool conversationsHasLoaded,
  required bool eventChatsHasLoaded,
  required bool inboxIsEmpty,
}) {
  if (!inboxIsEmpty || (!conversationsLoadFailed && !eventChatsLoadFailed)) {
    return false;
  }

  return !conversationsHasLoaded || !eventChatsHasLoaded;
}

bool favoriteChatMutationOwnerMatches({
  required String activeOwnerUid,
  required String authenticatedOwnerUid,
  required String requestedOwnerUid,
}) {
  final requestedUid = requestedOwnerUid.trim();
  return requestedUid.isNotEmpty &&
      activeOwnerUid.trim() == requestedUid &&
      authenticatedOwnerUid.trim() == requestedUid;
}

double favoriteChatRowHeight() => _favoriteChatRowHeight;
double favoriteChatAvatarSize() => _favoriteChatAvatarSize;
double favoriteChatTimestampWidth() => _favoriteChatTimestampWidth;
double favoriteChatUnreadBadgeSize() => _favoriteChatUnreadBadgeSize;
double favoriteChatDividerThickness() => _favoriteChatDividerThickness;
String favoriteChatUnreadBadgeLabel(int count) =>
    count > 99 ? '99+' : count.toString();

typedef FavoriteFriendsSource = Stream<FavoriteFriendsLoadState> Function(
  String currentUid,
);
typedef FavoriteConversationsSource = Stream<FavoriteConversationsLoadState>
    Function(String currentUid);
typedef FavoriteConversationUnreadCountSource = Stream<int> Function(
  ConversationsRecord conversation,
  String currentUid,
);
typedef FavoriteEventChatsSource = Stream<FavoriteEventChatsLoadState> Function(
    String currentUid);
typedef FavoriteInboxChatsWatcher = Stream<EventChatInboxLoadState> Function({
  required String currentUid,
  required EventInboxEventIdsStream rememberedEventIdsStream,
  required EventChatOwnerMutationGuard canMutateOwner,
  required void Function(String eventId) onInaccessibleEventId,
});
typedef FavoriteUserProfileLoader = Future<UserPublicProfilesRecord?> Function(
  DocumentReference reference,
);
typedef FavoriteEventLoader = Future<EventsRecord?> Function(String eventId);
typedef FavoriteAuthenticatedUidReader = String Function();
typedef FavoriteHiddenChatWriter = Future<void> Function(
  String ownerUid,
  String hiddenChatKey,
);
typedef FavoriteInaccessibleEventChatIdWriter = Future<void> Function(
  String ownerUid,
  String eventId,
);
typedef FavoriteConversationOpener = Future<void> Function(
  String ownerUid,
  ConversationsRecord conversation,
);
typedef FavoriteEventChatOpener = void Function(
  String ownerUid,
  String eventId,
  EventChatsRecord chat,
);
typedef FavoriteLatestEventChatMessageSource
    = Stream<EventChatMessagesLoadState> Function(
  String currentUid,
  EventChatsRecord chat,
);

@immutable
class FavoriteFriendsLoadState {
  const FavoriteFriendsLoadState({
    required this.ownerUid,
    this.friends = const <DocumentReference>[],
    this.rawHiddenChatKeys,
    this.friendsAreAuthoritative = true,
    bool? hasAuthoritativeResult,
    this.hiddenChatKeysAreKnown = true,
    this.hiddenChatKeysAreAuthoritative = true,
  })  : hasAuthoritativeResult =
            hasAuthoritativeResult ?? friendsAreAuthoritative,
        assert(
          !friendsAreAuthoritative ||
              (hasAuthoritativeResult ?? friendsAreAuthoritative),
        );

  final String ownerUid;
  final List<DocumentReference> friends;
  final Object? rawHiddenChatKeys;

  /// Whether the current source snapshot is server-authoritative.
  final bool friendsAreAuthoritative;

  /// Whether this owner has produced any server-authoritative result.
  final bool hasAuthoritativeResult;
  final bool hiddenChatKeysAreKnown;
  final bool hiddenChatKeysAreAuthoritative;

  bool get isAuthoritative => friendsAreAuthoritative;
  bool get isRefreshing => hasAuthoritativeResult && !isAuthoritative;
}

FavoriteFriendsLoadState resolveFavoriteFriendsDocumentSnapshotState({
  required String expectedOwnerUid,
  required String snapshotOwnerUid,
  required bool documentExists,
  required Iterable<DocumentReference> friends,
  required Object? rawHiddenChatKeys,
  required bool isFromCache,
  required bool hasPendingWrites,
}) {
  final expectedUid = expectedOwnerUid.trim();
  final snapshotUid = snapshotOwnerUid.trim();
  if (expectedUid.isEmpty || snapshotUid != expectedUid) {
    throw StateError(
      'FavoriteWidget: received user document for a different owner',
    );
  }
  final isAuthoritative = !isFromCache && !hasPendingWrites;
  if (!documentExists && isAuthoritative) {
    throw StateError('FavoriteWidget: user document does not exist');
  }
  final resolvedFriends = documentExists
      ? List<DocumentReference>.unmodifiable(friends)
      : const <DocumentReference>[];
  return FavoriteFriendsLoadState(
    ownerUid: expectedUid,
    friends: resolvedFriends,
    rawHiddenChatKeys: documentExists ? rawHiddenChatKeys : null,
    friendsAreAuthoritative: documentExists && isAuthoritative,
    hiddenChatKeysAreKnown: documentExists && isAuthoritative,
    hiddenChatKeysAreAuthoritative: documentExists && isAuthoritative,
  );
}

List<T> _mergeFavoritePartialRowsByIdentity<T>({
  required Iterable<T> previousRows,
  required Iterable<T> incomingRows,
  required Object Function(T row) identityOf,
}) {
  final incomingByIdentity = <Object, T>{
    for (final row in incomingRows) identityOf(row): row,
  };
  final mergedRows = <T>[];
  final seenIdentities = <Object>{};

  for (final previousRow in previousRows) {
    final identity = identityOf(previousRow);
    if (!seenIdentities.add(identity)) {
      continue;
    }
    mergedRows.add(incomingByIdentity.remove(identity) ?? previousRow);
  }
  for (final entry in incomingByIdentity.entries) {
    if (seenIdentities.add(entry.key)) {
      mergedRows.add(entry.value);
    }
  }

  return List<T>.unmodifiable(mergedRows);
}

FavoriteFriendsLoadState mergeFavoriteFriendsLoadState(
  FavoriteFriendsLoadState? previousState,
  FavoriteFriendsLoadState incomingState,
) {
  if (previousState == null) {
    return incomingState;
  }
  if (previousState.ownerUid != incomingState.ownerUid) {
    throw StateError(
      'FavoriteWidget: cannot merge friends from different owners',
    );
  }

  final incomingHiddenKeys = normalizeFavoriteHiddenChatKeys(
    incomingState.rawHiddenChatKeys,
  );
  final previousHiddenKeys = normalizeFavoriteHiddenChatKeys(
    previousState.rawHiddenChatKeys,
  );
  final hiddenKeys = incomingState.hiddenChatKeysAreAuthoritative
      ? incomingHiddenKeys
      : <String>{...previousHiddenKeys, ...incomingHiddenKeys};

  return FavoriteFriendsLoadState(
    ownerUid: incomingState.ownerUid,
    friends: incomingState.friendsAreAuthoritative
        ? incomingState.friends
        : _mergeFavoritePartialRowsByIdentity(
            previousRows: previousState.friends,
            incomingRows: incomingState.friends,
            identityOf: (reference) => reference.path,
          ),
    rawHiddenChatKeys: hiddenKeys,
    friendsAreAuthoritative: incomingState.friendsAreAuthoritative,
    hasAuthoritativeResult: previousState.hasAuthoritativeResult ||
        incomingState.hasAuthoritativeResult,
    hiddenChatKeysAreKnown: incomingState.hiddenChatKeysAreAuthoritative ||
        previousState.hiddenChatKeysAreKnown,
    hiddenChatKeysAreAuthoritative:
        incomingState.hiddenChatKeysAreAuthoritative,
  );
}

@immutable
class FavoriteConversationsLoadState {
  const FavoriteConversationsLoadState({
    required this.ownerUid,
    required this.isAuthoritative,
    bool? hasAuthoritativeResult,
    this.conversations = const <ConversationsRecord>[],
  })  : hasAuthoritativeResult = hasAuthoritativeResult ?? isAuthoritative,
        assert(
          !isAuthoritative || (hasAuthoritativeResult ?? isAuthoritative),
        );

  final String ownerUid;

  /// Whether the current source snapshot is server-authoritative.
  final bool isAuthoritative;

  /// Whether this owner has produced any server-authoritative result.
  final bool hasAuthoritativeResult;
  final List<ConversationsRecord> conversations;

  bool get isRefreshing => hasAuthoritativeResult && !isAuthoritative;
}

FavoriteConversationsLoadState mergeFavoriteConversationsLoadState(
  FavoriteConversationsLoadState? previousState,
  FavoriteConversationsLoadState incomingState,
) {
  if (previousState == null) {
    return incomingState;
  }
  if (previousState.ownerUid != incomingState.ownerUid) {
    throw StateError(
      'FavoriteWidget: cannot merge conversations from different owners',
    );
  }
  if (incomingState.isAuthoritative) {
    return incomingState;
  }
  return FavoriteConversationsLoadState(
    ownerUid: incomingState.ownerUid,
    isAuthoritative: false,
    hasAuthoritativeResult: previousState.hasAuthoritativeResult ||
        incomingState.hasAuthoritativeResult,
    conversations: _mergeFavoritePartialRowsByIdentity(
      previousRows: previousState.conversations,
      incomingRows: incomingState.conversations,
      identityOf: (conversation) => conversation.reference.path,
    ),
  );
}

@immutable
class FavoriteEventChatsLoadState {
  const FavoriteEventChatsLoadState({
    required this.ownerUid,
    required this.isAuthoritative,
    bool? hasAuthoritativeResult,
    this.eventChats = const <EventChatsRecord>[],
  })  : hasAuthoritativeResult = hasAuthoritativeResult ?? isAuthoritative,
        assert(
          !isAuthoritative || (hasAuthoritativeResult ?? isAuthoritative),
        );

  final String ownerUid;

  /// Whether the current source snapshot is server-authoritative.
  final bool isAuthoritative;

  /// Whether this owner has produced any server-authoritative result.
  final bool hasAuthoritativeResult;
  final List<EventChatsRecord> eventChats;

  bool get isRefreshing => hasAuthoritativeResult && !isAuthoritative;
}

FavoriteEventChatsLoadState mergeFavoriteEventChatsLoadState(
  FavoriteEventChatsLoadState? previousState,
  FavoriteEventChatsLoadState incomingState,
) {
  if (previousState == null) {
    return incomingState;
  }
  if (previousState.ownerUid != incomingState.ownerUid) {
    throw StateError(
      'FavoriteWidget: cannot merge event chats from different owners',
    );
  }
  if (incomingState.isAuthoritative) {
    return incomingState;
  }
  return FavoriteEventChatsLoadState(
    ownerUid: incomingState.ownerUid,
    isAuthoritative: false,
    hasAuthoritativeResult: previousState.hasAuthoritativeResult ||
        incomingState.hasAuthoritativeResult,
    eventChats: _mergeFavoritePartialRowsByIdentity(
      previousRows: previousState.eventChats,
      incomingRows: incomingState.eventChats,
      identityOf: EventGroupChatRepository.eventIdForChat,
    ),
  );
}

@immutable
final class _FavoriteAuthOwnerEpoch {
  const _FavoriteAuthOwnerEpoch({
    required this.ownerUid,
    required this.sourceEpoch,
  });

  final String ownerUid;
  final int sourceEpoch;
}

class FavoriteWidget extends StatefulWidget {
  const FavoriteWidget({
    super.key,
    @visibleForTesting this.debugAuthUidStream,
    @visibleForTesting this.debugInitialAuthUid,
    @visibleForTesting this.debugFriendsSource,
    @visibleForTesting this.debugConversationsSource,
    @visibleForTesting this.debugConversationUnreadCountSource,
    @visibleForTesting this.debugEventChatsSource,
    @visibleForTesting this.debugInboxChatsWatcher,
    @visibleForTesting this.debugLatestEventChatMessageSource,
    @visibleForTesting this.debugUserProfileLoader,
    @visibleForTesting this.debugEventLoader,
    @visibleForTesting this.debugAuthenticatedUidReader,
    @visibleForTesting this.debugHiddenChatWriter,
    @visibleForTesting this.debugInaccessibleEventChatIdWriter,
    @visibleForTesting this.debugConversationOpener,
    @visibleForTesting this.debugEventChatOpener,
  });

  final Stream<String>? debugAuthUidStream;
  final String? debugInitialAuthUid;
  final FavoriteFriendsSource? debugFriendsSource;
  final FavoriteConversationsSource? debugConversationsSource;
  final FavoriteConversationUnreadCountSource?
      debugConversationUnreadCountSource;
  final FavoriteEventChatsSource? debugEventChatsSource;
  final FavoriteInboxChatsWatcher? debugInboxChatsWatcher;
  final FavoriteLatestEventChatMessageSource? debugLatestEventChatMessageSource;
  final FavoriteUserProfileLoader? debugUserProfileLoader;
  final FavoriteEventLoader? debugEventLoader;
  final FavoriteAuthenticatedUidReader? debugAuthenticatedUidReader;
  final FavoriteHiddenChatWriter? debugHiddenChatWriter;
  final FavoriteInaccessibleEventChatIdWriter?
      debugInaccessibleEventChatIdWriter;
  final FavoriteConversationOpener? debugConversationOpener;
  final FavoriteEventChatOpener? debugEventChatOpener;

  static String routeName = 'favorite';
  static String routePath = '/favorite';

  @visibleForTesting
  static void debugEnsureSessionCacheLifecycleRegistered() =>
      _FavoriteWidgetState._ensureSessionCacheLifecycleRegistered();

  @visibleForTesting
  static void debugSeedUserScopedCache(String uid) {
    _FavoriteWidgetState._friendsCacheByUid[uid] = const <DocumentReference>[];
    _FavoriteWidgetState._friendsOwnerDocumentCacheByUid[uid] =
        const _FavoriteOwnerDocumentState(
      rawHiddenChatKeys: <String>[],
      hiddenChatKeysAreKnown: true,
    );
    _FavoriteWidgetState._userFutureCacheByUid[(uid, 'debug')] =
        Future<UserPublicProfilesRecord?>.value();
    _FavoriteWidgetState._hiddenChatKeyOverridesByUid[uid] = <String>{
      'debug:$uid'
    };
  }

  @visibleForTesting
  static bool debugUserScopedCacheContains(String uid) =>
      _FavoriteWidgetState._friendsCacheByUid.containsKey(uid) ||
      _FavoriteWidgetState._friendsOwnerDocumentCacheByUid.containsKey(uid) ||
      _FavoriteWidgetState._userFutureCacheByUid.keys
          .any((cacheKey) => cacheKey.$1 == uid) ||
      _FavoriteWidgetState._eventFutureCacheByOwnerAndEventId.keys
          .any((cacheKey) => cacheKey.$1 == uid) ||
      _FavoriteWidgetState._eventCacheByOwnerAndEventId.keys
          .any((cacheKey) => cacheKey.$1 == uid) ||
      _FavoriteWidgetState._latestEventChatMessageStateCacheByOwnerAndChat.keys
          .any((cacheKey) => cacheKey.$1 == uid) ||
      _FavoriteWidgetState._hiddenChatKeyOverridesByUid.containsKey(uid) ||
      _FavoriteWidgetState._serverConfirmedHiddenChatKeyOverridesByUid
          .containsKey(uid);

  @visibleForTesting
  static void debugClearSessionCache() =>
      _FavoriteWidgetState._clearSessionCache();

  @override
  State<FavoriteWidget> createState() => _FavoriteWidgetState();
}

class _FavoriteWidgetState extends State<FavoriteWidget> {
  late FavoriteModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  static final UxSessionLoadedResultCache<FavoriteConversationsLoadState>
      _conversationStateCacheByUid =
      UxSessionLoadedResultCache<FavoriteConversationsLoadState>();
  static final UxSessionLoadedResultCache<FavoriteEventChatsLoadState>
      _eventChatStateCacheByUid =
      UxSessionLoadedResultCache<FavoriteEventChatsLoadState>();
  static final Map<String, List<DocumentReference>> _friendsCacheByUid = {};
  static final Map<String, _FavoriteOwnerDocumentState>
      _friendsOwnerDocumentCacheByUid = {};
  static final Map<(String, String), Future<UserPublicProfilesRecord?>>
      _userFutureCacheByUid = {};
  static final Map<(String, String), UserPublicProfilesRecord>
      _userProfileCacheByUid = {};
  static final Map<(String, String), EventChatMessagesLoadState>
      _latestEventChatMessageStateCacheByOwnerAndChat = {};
  static final Map<(String, String), Future<EventsRecord?>>
      _eventFutureCacheByOwnerAndEventId = {};
  static final Map<(String, String), EventsRecord>
      _eventCacheByOwnerAndEventId = {};
  static final Map<String, Set<String>> _hiddenChatKeyOverridesByUid = {};
  static final Map<String, Set<String>>
      _serverConfirmedHiddenChatKeyOverridesByUid = {};
  static final Map<(String, String), Object> _hiddenChatMutationTokens = {};
  static int _sessionCacheGeneration = 0;
  late final Stream<_FavoriteAuthOwnerEpoch> _currentUidStream;
  int _authSourceEpoch = 0;
  late String _lastRawAuthOwnerUid;
  String? _activeUid;
  String? _friendsStreamUid;
  Stream<FavoriteFriendsLoadState>? _friendsStream;
  String? _conversationsStreamUid;
  Stream<FavoriteConversationsLoadState>? _conversationsStream;
  String? _eventChatsStreamUid;
  Stream<FavoriteEventChatsLoadState>? _eventChatsStream;
  final Map<(String, String), Stream<EventChatMessagesLoadState>>
      _latestEventChatMessageStreams = {};
  final Map<String, Stream<int>> _conversationUnreadCountStreams = {};
  int _selectedChatTabIndex = 0;
  int _friendsRetryToken = 0;
  int _conversationsRetryToken = 0;
  int _eventChatsRetryToken = 0;
  int _latestMessagesRetryToken = 0;
  bool _ownerBoundaryInvalidationScheduled = false;

  static void _ensureSessionCacheLifecycleRegistered() {
    UxSessionCacheLifecycle.register(_clearSessionCache);
  }

  static void _clearSessionCache() {
    _sessionCacheGeneration += 1;
    _conversationStateCacheByUid.clear();
    _eventChatStateCacheByUid.clear();
    _friendsCacheByUid.clear();
    _friendsOwnerDocumentCacheByUid.clear();
    _userFutureCacheByUid.clear();
    _userProfileCacheByUid.clear();
    _latestEventChatMessageStateCacheByOwnerAndChat.clear();
    _eventFutureCacheByOwnerAndEventId.clear();
    _eventCacheByOwnerAndEventId.clear();
    _hiddenChatKeyOverridesByUid.clear();
    _serverConfirmedHiddenChatKeyOverridesByUid.clear();
    _hiddenChatMutationTokens.clear();
  }

  bool get _hasIndependentDirectAuthUid =>
      widget.debugAuthenticatedUidReader != null ||
      widget.debugAuthUidStream == null;

  String get _authenticatedUid => (widget.debugAuthenticatedUidReader?.call() ??
          FirebaseAuth.instance.currentUser?.uid ??
          '')
      .trim();

  bool _streamOwnerMatchesDirectAuth(String streamOwnerUid) =>
      !_hasIndependentDirectAuthUid ||
      _authenticatedUid == streamOwnerUid.trim();

  bool _ownerIsCurrent(String requestedOwnerUid) =>
      favoriteChatMutationOwnerMatches(
        activeOwnerUid: _activeUid ?? '',
        authenticatedOwnerUid: _authenticatedUid,
        requestedOwnerUid: requestedOwnerUid,
      );

  bool _sourceOwnerIsCurrent(String ownerUid, int sourceGeneration) =>
      sourceGeneration == _sessionCacheGeneration && _ownerIsCurrent(ownerUid);

  bool _authEpochOwnerIsCurrent(String ownerUid, int sourceEpoch) =>
      sourceEpoch == _authSourceEpoch && _ownerIsCurrent(ownerUid);

  bool _guardedSourceOwnerIsCurrent(String ownerUid) {
    final isCurrent = _ownerIsCurrent(ownerUid);
    if (!isCurrent) {
      _scheduleOwnerBoundaryInvalidation(ownerUid);
    }
    return isCurrent;
  }

  Future<UserPublicProfilesRecord?> _getUserFuture(
    String currentUid,
    DocumentReference ref,
  ) {
    final cacheKey = (currentUid, ref.path);
    final generation = _sessionCacheGeneration;
    return _userFutureCacheByUid.putIfAbsent(
      cacheKey,
      () => (widget.debugUserProfileLoader?.call(ref) ??
              UserPublicProfilesRecord.maybeGetDocumentOnce(
                UserPublicProfilesRecord.collection.doc(ref.id),
              ))
          .then((profile) {
        if (!_sourceOwnerIsCurrent(currentUid, generation)) {
          if (!_ownerIsCurrent(currentUid)) {
            _scheduleOwnerBoundaryInvalidation(currentUid);
          }
          return null;
        }
        if (profile != null) {
          _userProfileCacheByUid[cacheKey] = profile;
        }
        return profile;
      }).catchError((Object error, StackTrace stackTrace) {
        if (!_sourceOwnerIsCurrent(currentUid, generation)) {
          return null;
        }
        _userFutureCacheByUid.remove(cacheKey);
        throw error;
      }),
    );
  }

  UserPublicProfilesRecord? _cachedUserProfile(
    String currentUid,
    DocumentReference ref,
  ) =>
      _ownerIsCurrent(currentUid)
          ? _userProfileCacheByUid[(currentUid, ref.path)]
          : null;

  Future<EventsRecord?> _getEventFuture(String currentUid, String eventId) {
    final generation = _sessionCacheGeneration;
    final cacheKey = (currentUid, eventId);
    return _eventFutureCacheByOwnerAndEventId.putIfAbsent(
      cacheKey,
      () => (widget.debugEventLoader?.call(eventId) ??
              (() async {
                final snapshot =
                    await EventsRecord.collection.doc(eventId).get();
                if (!snapshot.exists) {
                  return null;
                }
                return EventsRecord.fromSnapshot(snapshot);
              })())
          .then((event) {
        if (!_sourceOwnerIsCurrent(currentUid, generation)) {
          if (!_ownerIsCurrent(currentUid)) {
            _scheduleOwnerBoundaryInvalidation(currentUid);
          }
          return null;
        }
        if (event != null) {
          _eventCacheByOwnerAndEventId[cacheKey] = event;
        }
        return event;
      }).catchError((Object error, StackTrace stackTrace) {
        if (!_sourceOwnerIsCurrent(currentUid, generation)) {
          return null;
        }
        _eventFutureCacheByOwnerAndEventId.remove(cacheKey);
        throw error;
      }),
    );
  }

  EventsRecord? _cachedEvent(String currentUid, String eventId) =>
      _ownerIsCurrent(currentUid)
          ? _eventCacheByOwnerAndEventId[(currentUid, eventId)]
          : null;

  Set<String> _hiddenChatKeysForCurrentUser(
    String currentUid,
    Object? rawHiddenChatKeys, {
    required bool hiddenChatKeysAreAuthoritative,
  }) {
    if (currentUid.isEmpty || !_ownerIsCurrent(currentUid)) {
      if (currentUid.isNotEmpty) {
        _scheduleOwnerBoundaryInvalidation(currentUid);
      }
      return const <String>{};
    }

    final serverHiddenKeys = normalizeFavoriteHiddenChatKeys(
      rawHiddenChatKeys,
    );
    final optimisticHiddenKeys =
        _hiddenChatKeyOverridesByUid[currentUid] ?? const <String>{};
    final serverConfirmedHiddenKeys =
        _serverConfirmedHiddenChatKeyOverridesByUid[currentUid] ??
            const <String>{};

    if (hiddenChatKeysAreAuthoritative &&
        (optimisticHiddenKeys.isNotEmpty ||
            serverConfirmedHiddenKeys.isNotEmpty)) {
      final syncResult = syncFavoriteOptimisticHiddenChatKeys(
        optimisticHiddenKeys: optimisticHiddenKeys,
        serverConfirmedOptimisticHiddenKeys: serverConfirmedHiddenKeys,
        serverHiddenKeys: serverHiddenKeys,
      );
      if (syncResult.optimisticHiddenKeys.isEmpty) {
        _hiddenChatKeyOverridesByUid.remove(currentUid);
      } else {
        _hiddenChatKeyOverridesByUid[currentUid] =
            syncResult.optimisticHiddenKeys;
      }
      if (syncResult.serverConfirmedOptimisticHiddenKeys.isEmpty) {
        _serverConfirmedHiddenChatKeyOverridesByUid.remove(currentUid);
      } else {
        _serverConfirmedHiddenChatKeyOverridesByUid[currentUid] =
            syncResult.serverConfirmedOptimisticHiddenKeys;
      }
    }

    return resolveFavoriteEffectiveHiddenChatKeys(
      rawHiddenChatKeys: serverHiddenKeys,
      rememberedEventIds:
          EventGroupChatRepository.rememberedInboxEventIdsForOwner(currentUid),
      optimisticHiddenKeys:
          _hiddenChatKeyOverridesByUid[currentUid] ?? const <String>{},
    );
  }

  String _conversationHiddenKey(ConversationsRecord conversation) =>
      'conversation:${conversation.reference.id}';

  String _eventChatHiddenKey(EventChatsRecord chat) =>
      'event:${EventGroupChatRepository.eventIdForChat(chat)}';

  Future<void> _hideChat({
    required String ownerUid,
    required String hiddenKey,
    required int sourceEpoch,
  }) async {
    final normalizedKey = hiddenKey.trim();
    final uid = ownerUid.trim();
    if (normalizedKey.isEmpty || !_authEpochOwnerIsCurrent(uid, sourceEpoch)) {
      return;
    }
    final userRef = UsersRecord.collection.doc(uid);
    final mutationScope = (uid, normalizedKey);
    final mutationToken = Object();
    final sessionGeneration = _sessionCacheGeneration;

    bool mutationIsCurrent() =>
        sessionGeneration == _sessionCacheGeneration &&
        identical(
          _hiddenChatMutationTokens[mutationScope],
          mutationToken,
        );

    setState(() {
      _hiddenChatMutationTokens[mutationScope] = mutationToken;
      _hiddenChatKeyOverridesByUid
          .putIfAbsent(uid, () => <String>{})
          .add(normalizedKey);
      _serverConfirmedHiddenChatKeyOverridesByUid[uid]?.remove(normalizedKey);
    });

    try {
      final debugWriter = widget.debugHiddenChatWriter;
      if (debugWriter != null) {
        await debugWriter(uid, normalizedKey);
      } else {
        await userRef.update({
          'hiddenChatKeys': FieldValue.arrayUnion([normalizedKey]),
        });
      }
      if (mutationIsCurrent()) {
        _hiddenChatMutationTokens.remove(mutationScope);
      }
    } catch (error) {
      if (!mutationIsCurrent()) {
        return;
      }
      _hiddenChatMutationTokens.remove(mutationScope);
      final optimisticKeys = _hiddenChatKeyOverridesByUid[uid];
      optimisticKeys?.remove(normalizedKey);
      if (optimisticKeys?.isEmpty ?? false) {
        _hiddenChatKeyOverridesByUid.remove(uid);
      }
      final serverConfirmedKeys =
          _serverConfirmedHiddenChatKeyOverridesByUid[uid];
      serverConfirmedKeys?.remove(normalizedKey);
      if (serverConfirmedKeys?.isEmpty ?? false) {
        _serverConfirmedHiddenChatKeyOverridesByUid.remove(uid);
      }
      if (mounted && _ownerIsCurrent(uid)) {
        setState(() {});
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              FFLocalizations.of(this.context).getVariableText(
                ruText: 'Не удалось удалить чат',
                enText: 'Could not delete chat',
              ),
            ),
          ),
        );
      }
    }
  }

  String _fallbackPartnerDisplayName(BuildContext context) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Собеседник',
      enText: 'Conversation partner',
    );
  }

  String _publicProfilePhotoUrl(UserPublicProfilesRecord? profile) =>
      profile?.photoUrl.trim() ?? '';

  Map<String, dynamic> _conversationParticipantInfo(
    ConversationsRecord conversation,
    DocumentReference participantRef,
  ) {
    final rawInfoByUserId =
        conversation.snapshotData['participantInfoByUserId'];
    if (rawInfoByUserId is Map) {
      final rawInfo = rawInfoByUserId[participantRef.id] ??
          rawInfoByUserId[participantRef.path];
      if (rawInfo is Map) {
        return rawInfo.map((key, value) => MapEntry(key.toString(), value));
      }
    }

    return const <String, dynamic>{};
  }

  String _conversationParticipantDisplayName(
    ConversationsRecord conversation,
    DocumentReference participantRef,
  ) {
    final info = _conversationParticipantInfo(conversation, participantRef);
    for (final key in const ['displayName', 'display_name', 'name']) {
      final value = info[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }

  String _conversationParticipantPhotoUrl(
    ConversationsRecord conversation,
    DocumentReference participantRef,
  ) {
    final info = _conversationParticipantInfo(conversation, participantRef);
    for (final key in const ['photoUrl', 'photo_url', 'photo']) {
      final value = info[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }

  String _partnerDisplayName(
    ConversationsRecord conversation,
    DocumentReference partnerRef,
    UserPublicProfilesRecord? profile,
  ) {
    final profileDisplayName = profile?.displayName.trim();
    if (profileDisplayName != null && profileDisplayName.isNotEmpty) {
      return profileDisplayName;
    }

    final conversationDisplayName =
        _conversationParticipantDisplayName(conversation, partnerRef);
    if (conversationDisplayName.isNotEmpty) {
      return conversationDisplayName;
    }

    return '';
  }

  String _partnerPhotoUrl(
    ConversationsRecord conversation,
    DocumentReference partnerRef,
    UserPublicProfilesRecord? profile,
  ) {
    final profilePhotoUrl = _publicProfilePhotoUrl(profile);
    if (profilePhotoUrl.isNotEmpty) {
      return profilePhotoUrl;
    }

    return _conversationParticipantPhotoUrl(conversation, partnerRef);
  }

  Stream<FavoriteFriendsLoadState> _watchFriendsForUser(String currentUid) {
    if (currentUid.isEmpty) {
      return const Stream<FavoriteFriendsLoadState>.empty();
    }

    if (_friendsStreamUid == currentUid && _friendsStream != null) {
      return _friendsStream!;
    }

    _friendsStreamUid = currentUid;
    final sourceGeneration = _sessionCacheGeneration;
    final userReference = UsersRecord.collection.doc(currentUid);
    final sourceSnapshots = userReference
        .snapshots(includeMetadataChanges: true)
        .map<FavoriteFirestoreSourceSnapshot<FavoriteFriendsLoadState>>(
            (snapshot) {
      final userDocument =
          snapshot.exists ? UsersRecord.fromSnapshot(snapshot) : null;
      final friends = userDocument == null
          ? const <DocumentReference>[]
          : resolveFriendsForUser(userDocument);
      final loadedState = resolveFavoriteFriendsDocumentSnapshotState(
        expectedOwnerUid: currentUid,
        snapshotOwnerUid: snapshot.reference.id,
        documentExists: snapshot.exists,
        friends: friends,
        rawHiddenChatKeys: userDocument?.snapshotData['hiddenChatKeys'],
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      );
      return FavoriteFirestoreSourceSnapshot<FavoriteFriendsLoadState>(
        value: loadedState,
        isEmpty: friends.isEmpty,
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      );
    });

    FavoriteFriendsLoadState? lastState =
        _cachedFriendsStateForUser(currentUid);
    _friendsStream = sourceSnapshots.map((sourceSnapshot) {
      if (!_sourceOwnerIsCurrent(currentUid, sourceGeneration)) {
        if (!_ownerIsCurrent(currentUid)) {
          _scheduleOwnerBoundaryInvalidation(currentUid);
        }
        throw StateError(
          'FavoriteWidget: rejected owner metadata for a stale owner',
        );
      }
      final loadedState = mergeFavoriteFriendsLoadState(
        lastState,
        sourceSnapshot.value,
      );
      lastState = loadedState;
      if (loadedState.ownerUid != currentUid) {
        throw StateError(
          'FavoriteWidget: received friends state for a different owner',
        );
      }

      _rememberFriendsState(currentUid, loadedState);
      return loadedState;
    });
    return _friendsStream!;
  }

  void _rememberFriendsState(
    String currentUid,
    FavoriteFriendsLoadState state,
  ) {
    if (!_ownerIsCurrent(currentUid)) {
      return;
    }
    _friendsOwnerDocumentCacheByUid[currentUid] = _FavoriteOwnerDocumentState(
      rawHiddenChatKeys: state.rawHiddenChatKeys,
      hiddenChatKeysAreKnown: state.hiddenChatKeysAreKnown,
    );
    if (state.friendsAreAuthoritative) {
      _friendsCacheByUid[currentUid] = state.friends;
    }
  }

  FavoriteFriendsLoadState? _cachedFriendsStateForUser(String currentUid) {
    if (!_ownerIsCurrent(currentUid)) {
      return null;
    }
    final friends = _friendsCacheByUid[currentUid];
    final ownerDocument = _friendsOwnerDocumentCacheByUid[currentUid];
    if (friends == null && ownerDocument == null) {
      return null;
    }
    return FavoriteFriendsLoadState(
      ownerUid: currentUid,
      friends: friends ?? const <DocumentReference>[],
      rawHiddenChatKeys: ownerDocument?.rawHiddenChatKeys,
      friendsAreAuthoritative: false,
      hasAuthoritativeResult: friends != null,
      hiddenChatKeysAreKnown: ownerDocument?.hiddenChatKeysAreKnown ?? false,
      hiddenChatKeysAreAuthoritative: false,
    );
  }

  Stream<FavoriteConversationsLoadState> _watchConversationsForUser(
    String currentUid,
  ) {
    if (currentUid.isEmpty) {
      return const Stream<FavoriteConversationsLoadState>.empty();
    }

    if (_conversationsStreamUid == currentUid && _conversationsStream != null) {
      return _conversationsStream!;
    }

    _conversationsStreamUid = currentUid;
    final sourceGeneration = _sessionCacheGeneration;
    final query = ConversationsRecord.collection.where(
      FieldPath(['participantMap', currentUid]),
      isEqualTo: true,
    );
    final sourceSnapshots = query
        .snapshots(includeMetadataChanges: true)
        .map<FavoriteFirestoreSourceSnapshot<List<ConversationsRecord>>>(
      (snapshot) {
        final loadedConversations = snapshot.docs
            .map(ConversationsRecord.fromSnapshot)
            .where((conversation) => conversation.isUnlocked)
            .toList();
        loadedConversations.sort(compareConversationsForInbox);
        final conversations = List<ConversationsRecord>.unmodifiable(
          loadedConversations,
        );
        return FavoriteFirestoreSourceSnapshot<List<ConversationsRecord>>(
          value: conversations,
          isEmpty: conversations.isEmpty,
          isFromCache: snapshot.metadata.isFromCache,
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
        );
      },
    );
    var lastState = _cachedConversationsStateForUser(currentUid);
    _conversationsStream = sourceSnapshots.map((snapshot) {
      if (!_sourceOwnerIsCurrent(currentUid, sourceGeneration)) {
        if (!_ownerIsCurrent(currentUid)) {
          _scheduleOwnerBoundaryInvalidation(currentUid);
        }
        throw StateError(
          'FavoriteWidget: rejected conversations for a stale owner',
        );
      }
      final incomingState = FavoriteConversationsLoadState(
        ownerUid: currentUid,
        isAuthoritative: !snapshot.isFromCache && !snapshot.hasPendingWrites,
        conversations: snapshot.value,
      );
      final loadedState = mergeFavoriteConversationsLoadState(
        lastState,
        incomingState,
      );
      lastState = loadedState;
      _rememberConversationsState(currentUid, loadedState);
      return loadedState;
    });
    return _conversationsStream!;
  }

  void _rememberConversationsState(
    String currentUid,
    FavoriteConversationsLoadState state,
  ) {
    if (!_ownerIsCurrent(currentUid)) {
      return;
    }
    _conversationStateCacheByUid.write(
      UxLoadedResult<FavoriteConversationsLoadState>.data(
        dataKey: _conversationStateCacheKey(currentUid),
        data: state,
      ),
    );
  }

  Object _conversationStateCacheKey(String currentUid) => [
        'favoriteConversations',
        currentUid,
      ];

  FavoriteConversationsLoadState? _cachedConversationsStateForUser(
    String currentUid,
  ) {
    if (!_ownerIsCurrent(currentUid)) {
      return null;
    }
    final state = _conversationStateCacheByUid
        .read(_conversationStateCacheKey(currentUid))
        ?.data;
    if (state == null || state.ownerUid != currentUid) {
      return null;
    }
    return FavoriteConversationsLoadState(
      ownerUid: currentUid,
      isAuthoritative: false,
      hasAuthoritativeResult: state.hasAuthoritativeResult,
      conversations: state.conversations,
    );
  }

  Stream<FavoriteEventChatsLoadState> _defaultInboxChatsWatcher(
    String currentUid,
  ) {
    final sourceGeneration = _sessionCacheGeneration;
    bool sourceCanMutateOwner(String requestedOwnerUid) =>
        _sourceOwnerIsCurrent(requestedOwnerUid, sourceGeneration);

    final watcher = widget.debugInboxChatsWatcher ??
        EventGroupChatRepository.watchInboxChatsState;
    return watcher(
      currentUid: currentUid,
      rememberedEventIdsStream: () =>
          _watchSavedEventChatInboxEventIds(currentUid),
      canMutateOwner: sourceCanMutateOwner,
      onInaccessibleEventId: (eventId) {
        if (!sourceCanMutateOwner(currentUid)) {
          return;
        }
        unawaited(_removeInaccessibleEventChatId(
          currentUid: currentUid,
          eventId: eventId,
          sourceGeneration: sourceGeneration,
        ));
      },
    ).map((inboxState) {
      if (inboxState.ownerUid != currentUid) {
        throw StateError(
          'FavoriteWidget: received inbox state for a different owner',
        );
      }
      return FavoriteEventChatsLoadState(
        ownerUid: currentUid,
        isAuthoritative: inboxState.isAuthoritative,
        eventChats: inboxState.chats,
      );
    });
  }

  Stream<FavoriteEventChatsLoadState> _watchEventChatsForUser(
    String currentUid,
  ) {
    if (currentUid.isEmpty) {
      return const Stream<FavoriteEventChatsLoadState>.empty();
    }

    if (_eventChatsStreamUid == currentUid && _eventChatsStream != null) {
      return _eventChatsStream!;
    }

    _eventChatsStreamUid = currentUid;
    final sourceGeneration = _sessionCacheGeneration;
    var lastState = _cachedEventChatsStateForUser(currentUid);
    final source = guardFavoriteOwnerScopedSource(
      source: _defaultInboxChatsWatcher(currentUid),
      expectedOwnerUid: currentUid,
      sourceGeneration: sourceGeneration,
      currentGeneration: () => _sessionCacheGeneration,
      ownerIsCurrent: _guardedSourceOwnerIsCurrent,
      ownerUidOf: (state) => state.ownerUid,
    );
    _eventChatsStream = source.map((incomingState) {
      final loadedState = mergeFavoriteEventChatsLoadState(
        lastState,
        incomingState,
      );
      lastState = loadedState;
      _rememberEventChatsState(currentUid, loadedState);
      return loadedState;
    });
    return _eventChatsStream!;
  }

  void _rememberEventChatsState(
    String currentUid,
    FavoriteEventChatsLoadState state,
  ) {
    if (!_ownerIsCurrent(currentUid)) {
      return;
    }
    _eventChatStateCacheByUid.write(
      UxLoadedResult<FavoriteEventChatsLoadState>.data(
        dataKey: _eventChatsStateCacheKey(currentUid),
        data: state,
      ),
    );
  }

  Object _eventChatsStateCacheKey(String currentUid) => [
        'favoriteEventChats',
        currentUid,
      ];

  FavoriteEventChatsLoadState? _cachedEventChatsStateForUser(
    String currentUid,
  ) {
    if (!_ownerIsCurrent(currentUid)) {
      return null;
    }
    final state = _eventChatStateCacheByUid
        .read(_eventChatsStateCacheKey(currentUid))
        ?.data;
    if (state == null || state.ownerUid != currentUid) {
      return null;
    }
    return FavoriteEventChatsLoadState(
      ownerUid: currentUid,
      isAuthoritative: false,
      hasAuthoritativeResult: state.hasAuthoritativeResult,
      eventChats: state.eventChats,
    );
  }

  Stream<EventInboxEventIdsLoadState> _watchSavedEventChatInboxEventIds(
    String currentUid,
  ) {
    if (currentUid.isEmpty) {
      return Stream.value(
        EventInboxEventIdsLoadState(
          ownerUid: '',
          eventIds: const <String>[],
          isReady: true,
          isAuthoritative: true,
        ),
      );
    }

    final sourceGeneration = _sessionCacheGeneration;
    final userRef = UsersRecord.collection.doc(currentUid);
    final snapshots = userRef
        .snapshots(includeMetadataChanges: true)
        .map<FavoriteFirestoreSourceSnapshot<List<String>>>((snapshot) {
      if (!_sourceOwnerIsCurrent(currentUid, sourceGeneration)) {
        if (!_ownerIsCurrent(currentUid)) {
          _scheduleOwnerBoundaryInvalidation(currentUid);
        }
        throw StateError(
          'FavoriteWidget: rejected saved event chats for a stale owner',
        );
      }
      if (!snapshot.exists &&
          !snapshot.metadata.isFromCache &&
          !snapshot.metadata.hasPendingWrites) {
        throw StateError('FavoriteWidget: user document does not exist');
      }
      final eventIds = snapshot.exists
          ? _eventChatInboxEventIdsFromData(snapshot.data())
          : const <String>[];
      return FavoriteFirestoreSourceSnapshot<List<String>>(
        value: eventIds,
        isEmpty: eventIds.isEmpty,
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      );
    });
    return snapshots.map(
      (snapshot) => EventInboxEventIdsLoadState(
        ownerUid: currentUid,
        eventIds: snapshot.value,
        isReady: true,
        isAuthoritative: !snapshot.isFromCache && !snapshot.hasPendingWrites,
      ),
    );
  }

  List<String> _eventChatInboxEventIdsFromData(Object? data) {
    if (data is! Map) {
      return const <String>[];
    }

    final ids = <String>[];
    final seen = <String>{};
    final rawIds = data['eventChatInboxEventIds'];
    if (rawIds is Iterable) {
      for (final rawId in rawIds) {
        if (rawId is! String) {
          continue;
        }
        final id = rawId.trim();
        if (id.isNotEmpty && seen.add(id)) {
          ids.add(id);
        }
      }
    }
    return EventGroupChatRepository.boundedInboxEventIds(ids);
  }

  Future<void> _removeInaccessibleEventChatId({
    required String currentUid,
    required String eventId,
    required int sourceGeneration,
  }) async {
    bool sourceOwnerIsCurrent() =>
        _sourceOwnerIsCurrent(currentUid, sourceGeneration);

    if (!sourceOwnerIsCurrent()) {
      return;
    }
    EventGroupChatRepository.forgetInboxEventId(
      eventId,
      ownerUid: currentUid,
    );
    if (!sourceOwnerIsCurrent()) {
      return;
    }
    try {
      final debugWriter = widget.debugInaccessibleEventChatIdWriter;
      if (debugWriter != null) {
        await debugWriter(currentUid, eventId);
      } else {
        await UsersRecord.collection.doc(currentUid).update({
          'eventChatInboxEventIds': FieldValue.arrayRemove([eventId]),
        });
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'FavoriteWidget: failed to remove inaccessible event chat: '
          '${error.runtimeType}',
        );
      }
    }
  }

  Stream<EventChatMessagesLoadState> _watchLatestEventChatMessage(
    String currentUid,
    EventChatsRecord chat,
  ) {
    final eventId = EventGroupChatRepository.eventIdForChat(chat);
    return _latestEventChatMessageStreams.putIfAbsent(
      (currentUid, chat.reference.path),
      () {
        final sourceGeneration = _sessionCacheGeneration;
        final source = widget.debugLatestEventChatMessageSource?.call(
              currentUid,
              chat,
            ) ??
            EventGroupChatRepository.watchLatestMessageState(
              eventId: eventId,
              ownerUid: currentUid,
            );
        return guardFavoriteOwnerScopedSource(
          source: source,
          expectedOwnerUid: currentUid,
          sourceGeneration: sourceGeneration,
          currentGeneration: () => _sessionCacheGeneration,
          ownerIsCurrent: _guardedSourceOwnerIsCurrent,
          ownerUidOf: (state) => state.ownerUid,
        ).map((state) {
          _latestEventChatMessageStateCacheByOwnerAndChat[(
            currentUid,
            chat.reference.path
          )] = state;
          return state;
        });
      },
    );
  }

  EventChatMessagesLoadState? _cachedLatestEventChatMessageState(
    String currentUid,
    EventChatsRecord chat,
  ) {
    if (!_ownerIsCurrent(currentUid)) {
      return null;
    }
    final state = _latestEventChatMessageStateCacheByOwnerAndChat[(
      currentUid,
      chat.reference.path
    )];
    return state?.ownerUid == currentUid ? state : null;
  }

  Stream<int> _watchConversationUnreadCount(
    ConversationsRecord conversation,
    String currentUid,
  ) {
    if (currentUid.isEmpty ||
        !conversationIsUnreadForUser(conversation, currentUid)) {
      return Stream<int>.value(0);
    }

    final readAt = conversationReadAtForUser(conversation, currentUid);
    final unreadAt = conversation.lastUnreadMessageAt ??
        conversation.lastMessageAt ??
        conversation.unlockedAt;
    final cacheKey = [
      conversation.reference.path,
      currentUid,
      readAt?.microsecondsSinceEpoch ?? 0,
      unreadAt?.microsecondsSinceEpoch ?? 0,
    ].join('|');

    return _conversationUnreadCountStreams.putIfAbsent(
      cacheKey,
      () {
        final sourceGeneration = _sessionCacheGeneration;
        final debugSource = widget.debugConversationUnreadCountSource?.call(
          conversation,
          currentUid,
        );
        final countSource = debugSource ??
            queryMessagesRecord(
              parent: conversation.reference,
              queryBuilder: (messagesQuery) {
                var query = messagesQuery;
                if (readAt != null) {
                  query = query.where('createdAt', isGreaterThan: readAt);
                }
                return query.orderBy('createdAt', descending: true);
              },
              limit: 100,
            ).map((messages) {
              var unreadCount = 0;
              for (final message in messages) {
                final createdAt = message.createdAt;
                if (createdAt == null) {
                  continue;
                }
                if (readAt != null && !createdAt.isAfter(readAt)) {
                  continue;
                }
                if (message.senderId == currentUid ||
                    messageIsCallEvent(message)) {
                  continue;
                }
                unreadCount += 1;
              }
              if (unreadCount <= 0 &&
                  conversationIsUnreadForUser(conversation, currentUid)) {
                return 1;
              }
              return unreadCount;
            });
        return countSource.map((unreadCount) {
          if (!_sourceOwnerIsCurrent(currentUid, sourceGeneration)) {
            if (!_ownerIsCurrent(currentUid)) {
              _scheduleOwnerBoundaryInvalidation(currentUid);
            }
            throw StateError(
              'FavoriteWidget: rejected unread count for a stale owner',
            );
          }
          return unreadCount;
        }).handleError((Object error, StackTrace stackTrace) {
          if (kDebugMode &&
              _sourceOwnerIsCurrent(currentUid, sourceGeneration)) {
            debugPrint(
              'FavoriteWidget: failed to load unread count: '
              '${error.runtimeType}',
            );
          }
        });
      },
    );
  }

  DocumentReference? _otherParticipantRef(
    ConversationsRecord conversation,
    String currentUid,
  ) {
    if (currentUid.isEmpty) {
      return null;
    }

    for (final participantRef in conversation.participantRefs) {
      if (participantRef.id != currentUid) {
        return participantRef;
      }
    }

    return null;
  }

  bool _conversationPartnerIsFriendPathSet(
    ConversationsRecord conversation,
    Set<String> friendPaths,
    String currentUid,
  ) {
    for (final participantRef in conversation.participantRefs) {
      if (participantRef.id != currentUid &&
          friendPaths.contains(participantRef.path)) {
        return true;
      }
    }
    return false;
  }

  String _formatInboxTimestamp(DateTime? timestamp) {
    return formatFavoriteInboxTimestamp(timestamp);
  }

  Future<void> _openConversation(
    String currentUid,
    ConversationsRecord conversation,
    int sourceEpoch,
  ) async {
    if (!_authEpochOwnerIsCurrent(currentUid, sourceEpoch) ||
        !conversation.participantIds.contains(currentUid)) {
      return;
    }
    final debugOpener = widget.debugConversationOpener;
    if (debugOpener != null) {
      await debugOpener(currentUid, conversation);
      return;
    }
    await openChatThread(
      context,
      conversationRef: conversation.reference,
      initialConversation: conversation,
    );
  }

  void _openEventChat(
    String currentUid,
    EventChatsRecord chat,
    int sourceEpoch,
  ) {
    if (!_authEpochOwnerIsCurrent(currentUid, sourceEpoch) ||
        !chat.readAccessUserIds.contains(currentUid)) {
      return;
    }
    final eventId = EventGroupChatRepository.eventIdForChat(chat);
    if (eventId.isEmpty) {
      return;
    }
    final debugOpener = widget.debugEventChatOpener;
    if (debugOpener != null) {
      debugOpener(currentUid, eventId, chat);
      return;
    }

    context.pushNamed(
      EventGroupChatWidget.routeName,
      pathParameters: <String, String>{'eventId': eventId},
    );
  }

  String _conversationSubtitle(
    BuildContext context,
    ConversationsRecord conversation,
    String currentUid,
  ) {
    if (conversation.lastMessageType == kConversationMessageTypeCallEvent) {
      return formatChatCallEventTitle(
        context,
        outcome: conversation.lastCallOutcome,
        callerId: conversation.lastCallCallerId,
        currentUserUid: currentUid,
      );
    }

    final lastMessageText = (conversation.lastMessageText ?? '').trim();
    if (lastMessageText.isNotEmpty) {
      return lastMessageText;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: 'Чат открыт',
      enText: 'Chat unlocked',
    );
  }

  String _eventChatTitle(BuildContext context, EventsRecord? event) {
    final title = event?.title.trim() ?? '';
    if (title.isNotEmpty) {
      return title;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: 'Чат события',
      enText: 'Event chat',
    );
  }

  String _eventChatSubtitle(
    BuildContext context,
    EventChatMessagesRecord? latestMessage,
  ) {
    if (latestMessage?.deletedAt != null) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Сообщение удалено',
        enText: 'Message deleted',
      );
    }

    final text = latestMessage?.text.trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: 'Чат события',
      enText: 'Event chat',
    );
  }

  DateTime? _eventChatTimestamp(
    EventChatsRecord chat,
    EventChatMessagesRecord? latestMessage,
  ) =>
      latestMessage?.createdAt ?? chat.updatedAt ?? chat.createdAt;

  List<_InboxChatItem> _buildInboxItems({
    required List<ConversationsRecord> conversations,
    required List<EventChatsRecord> eventChats,
    required Set<String> hiddenChatKeys,
  }) {
    final items = <_InboxChatItem>[
      for (final conversation in conversations)
        if (!hiddenChatKeys.contains(_conversationHiddenKey(conversation)))
          _InboxChatItem.conversation(conversation),
      for (final eventChat in eventChats) _InboxChatItem.eventChat(eventChat),
    ];
    items.removeWhere((item) {
      final eventChat = item.eventChat;
      return eventChat != null &&
          hiddenChatKeys.contains(_eventChatHiddenKey(eventChat));
    });
    items.sort(_compareInboxChatItems);
    return items;
  }

  Key? _inboxItemAsyncRowKey(String currentUid, _InboxChatItem item) {
    final conversation = item.conversation;
    if (conversation != null) {
      return favoriteConversationAsyncRowKey(
        ownerUid: currentUid,
        conversationPath: conversation.reference.path,
      );
    }
    final eventChat = item.eventChat;
    if (eventChat == null) {
      return null;
    }
    final eventId = EventGroupChatRepository.eventIdForChat(eventChat);
    if (eventId.isEmpty) {
      return null;
    }
    return favoriteEventChatAsyncRowKey(
      ownerUid: currentUid,
      chatPath: eventChat.reference.path,
      eventId: eventId,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: ExpatlioDesign.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: ExpatlioDesign.pageHeaderHeight,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ExpatlioDesign.pagePadding,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 45.0,
                  height: 45.0,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Чаты',
                    enText: 'Chats',
                  ),
                  style: ExpatlioDesign.pageHeaderTitleStyle(context),
                ),
                Container(
                  width: 45.0,
                  height: 45.0,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatsTabBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExpatlioDesign.pagePadding,
        ExpatlioDesign.compactSpacing,
        ExpatlioDesign.pagePadding,
        ExpatlioDesign.itemSpacing,
      ),
      child: ExpatlioSegmentedTabBar(
        labels: [
          FFLocalizations.of(context).getVariableText(
            ruText: 'Все',
            enText: 'All',
          ),
          FFLocalizations.of(context).getVariableText(
            ruText: 'Друзья',
            enText: 'Friends',
          ),
        ],
        selectedIndex: _selectedChatTabIndex,
        onChanged: (index) => setState(() => _selectedChatTabIndex = index),
      ),
    );
  }

  Widget _conversationCard(
    BuildContext context, {
    required String currentUid,
    required int sourceEpoch,
    required ConversationsRecord conversation,
    required bool isFriend,
    required VoidCallback onDelete,
  }) {
    final partnerRef = _otherParticipantRef(conversation, currentUid);
    if (partnerRef == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<UserPublicProfilesRecord?>(
      key: favoriteConversationAsyncRowKey(
        ownerUid: currentUid,
        conversationPath: conversation.reference.path,
      ),
      future: _getUserFuture(currentUid, partnerRef),
      initialData: _cachedUserProfile(currentUid, partnerRef),
      builder: (context, partnerSnapshot) {
        if (!_authEpochOwnerIsCurrent(currentUid, sourceEpoch)) {
          _scheduleOwnerBoundaryInvalidation(currentUid);
          return const SizedBox.shrink();
        }
        if (kDebugMode && partnerSnapshot.hasError) {
          debugPrint(
            'FavoriteWidget: failed to load partner: '
            '${partnerSnapshot.error.runtimeType}',
          );
        }

        final partner = partnerSnapshot.hasError
            ? _cachedUserProfile(currentUid, partnerRef)
            : partnerSnapshot.data;
        final partnerDisplayName = _partnerDisplayName(
          conversation,
          partnerRef,
          partner,
        );
        final partnerPhotoUrl = _partnerPhotoUrl(
          conversation,
          partnerRef,
          partner,
        );
        final visiblePartnerDisplayName = partnerDisplayName.isNotEmpty
            ? partnerDisplayName
            : _fallbackPartnerDisplayName(context);
        final unread = conversationIsUnreadForUser(conversation, currentUid);
        final subtitle =
            _conversationSubtitle(context, conversation, currentUid);

        return _dismissibleChatCard(
          keyValue: _conversationHiddenKey(conversation),
          onDelete: onDelete,
          child: InkWell(
            splashColor: Colors.transparent,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () => _openConversation(
              currentUid,
              conversation,
              sourceEpoch,
            ),
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.zero,
              color: Colors.transparent,
              child: _chatRowFrame(
                dividerKey: favoriteChatDividerKey(
                  _conversationHiddenKey(conversation),
                ),
                child: Row(
                  children: [
                    Container(
                      key: favoriteChatAvatarKey(
                        _conversationHiddenKey(conversation),
                      ),
                      width: _favoriteChatAvatarSize,
                      height: _favoriteChatAvatarSize,
                      decoration: BoxDecoration(
                        color: partnerPhotoUrl.isEmpty
                            ? ExpatlioDesign.avatarFallbackBackground
                            : ExpatlioDesign.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: ExpatlioDesign.border),
                        image: partnerPhotoUrl.isNotEmpty
                            ? DecorationImage(
                                fit: BoxFit.cover,
                                image: CachedNetworkImageProvider(
                                  partnerPhotoUrl,
                                  maxWidth: 108,
                                  maxHeight: 108,
                                ),
                              )
                            : null,
                      ),
                      child: partnerPhotoUrl.isEmpty
                          ? Center(
                              child: Text(
                                ExpatlioDesign.avatarInitial(
                                    visiblePartnerDisplayName),
                                style: ExpatlioDesign.textStyle(
                                  context,
                                  color: ExpatlioDesign.avatarFallbackText,
                                  size: 14.0,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.itemSpacing,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          visiblePartnerDisplayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: ExpatlioDesign.textStyle(
                                            context,
                                            size: 16.0,
                                            weight: unread
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (isFriend)
                                        const Padding(
                                          padding: EdgeInsetsDirectional.only(
                                              start: ExpatlioDesign.space8),
                                          child: Icon(
                                            Icons.star_rounded,
                                            color: ExpatlioDesign.warning,
                                            size: 18.0,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: ExpatlioDesign.space4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ExpatlioDesign.textStyle(
                                context,
                                color: ExpatlioDesign.muted,
                                size: 14.0,
                                weight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _chatTimestampColumn(
                      key: favoriteChatTimestampKey(
                        _conversationHiddenKey(conversation),
                      ),
                      timestampTextKey: favoriteChatTimestampTextKey(
                        _conversationHiddenKey(conversation),
                      ),
                      unreadSlotKey: favoriteChatUnreadSlotKey(
                        _conversationHiddenKey(conversation),
                      ),
                      timestampText: _formatInboxTimestamp(
                        conversation.lastMessageAt ?? conversation.unlockedAt,
                      ),
                      badge: unread
                          ? _ConversationUnreadBadge(
                              badgeKey: favoriteChatUnreadBadgeKey(
                                _conversationHiddenKey(conversation),
                              ),
                              unreadCountStream: _watchConversationUnreadCount(
                                conversation,
                                currentUid,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dismissibleChatCard({
    required String keyValue,
    required VoidCallback onDelete,
    required Widget child,
  }) {
    return Semantics(
      key: favoriteChatDismissActionKey(keyValue),
      container: true,
      onDismiss: onDelete,
      child: Dismissible(
        key: ValueKey<String>('favorite_chat_$keyValue'),
        direction: DismissDirection.endToStart,
        dismissThresholds: const {
          DismissDirection.endToStart: 0.34,
        },
        background: const SizedBox.shrink(),
        secondaryBackground: Container(
          color: _favoriteChatDeleteBackground,
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsetsDirectional.only(
            end: ExpatlioDesign.pagePadding,
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.white,
            size: 24.0,
          ),
        ),
        onDismissed: (_) => onDelete(),
        child: child,
      ),
    );
  }

  Widget _chatRowFrame({
    required Widget child,
    Key? dividerKey,
  }) {
    return SizedBox(
      height: _favoriteChatRowHeight,
      child: Column(
        children: [
          SizedBox(
            height: _favoriteChatRowContentHeight,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ExpatlioDesign.pagePadding,
              ),
              child: child,
            ),
          ),
          _chatDivider(key: dividerKey),
        ],
      ),
    );
  }

  Widget _chatTimestampColumn({
    Key? key,
    required String timestampText,
    Key? timestampTextKey,
    Key? unreadSlotKey,
    Widget? badge,
  }) {
    return SizedBox(
      key: key,
      width: _favoriteChatTimestampWidth,
      height: _favoriteChatTrailingHeight,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: ExpatlioDesign.space12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              timestampText,
              key: timestampTextKey,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              textAlign: TextAlign.end,
              textScaler: TextScaler.noScaling,
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.inactive,
                size: 12.0,
                weight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            SizedBox(
              key: unreadSlotKey,
              height: _favoriteChatUnreadSlotHeight,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: badge ?? const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatDivider({Key? key}) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: ExpatlioDesign.pagePadding +
            _favoriteChatAvatarSize +
            ExpatlioDesign.itemSpacing,
        end: ExpatlioDesign.pagePadding,
      ),
      child: Divider(
        key: key,
        height: _favoriteChatDividerThickness,
        thickness: _favoriteChatDividerThickness,
        color: _favoriteChatDividerColor,
      ),
    );
  }

  Widget _eventChatCard(
    BuildContext context, {
    required String currentUid,
    required int sourceEpoch,
    required EventChatsRecord chat,
    required VoidCallback onDelete,
  }) {
    final eventId = EventGroupChatRepository.eventIdForChat(chat);
    if (eventId.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<EventsRecord?>(
      key: favoriteEventChatAsyncRowKey(
        ownerUid: currentUid,
        chatPath: chat.reference.path,
        eventId: eventId,
      ),
      future: _getEventFuture(currentUid, eventId),
      initialData: _cachedEvent(currentUid, eventId),
      builder: (context, eventSnapshot) {
        if (!_authEpochOwnerIsCurrent(currentUid, sourceEpoch)) {
          _scheduleOwnerBoundaryInvalidation(currentUid);
          return const SizedBox.shrink();
        }
        if (kDebugMode && eventSnapshot.hasError) {
          debugPrint(
            'FavoriteWidget: failed to load event: '
            '${eventSnapshot.error.runtimeType}',
          );
        }

        final event = eventSnapshot.hasError
            ? _cachedEvent(currentUid, eventId)
            : eventSnapshot.data;
        final title = _eventChatTitle(context, event);

        return FavoriteChatSourceBuilder<EventChatMessagesLoadState>(
          sourceId: 'event-preview:${chat.reference.path}',
          currentUid: currentUid,
          sourceEpoch: sourceEpoch,
          stream: _watchLatestEventChatMessage(currentUid, chat),
          cachedState: _cachedLatestEventChatMessageState(currentUid, chat),
          retryToken: _latestMessagesRetryToken,
          builder: (context, messageSnapshot, messageResolution) {
            if (!_authEpochOwnerIsCurrent(currentUid, sourceEpoch)) {
              _scheduleOwnerBoundaryInvalidation(currentUid);
              return const SizedBox.shrink();
            }
            if (kDebugMode && messageSnapshot.hasError) {
              debugPrint(
                'FavoriteWidget: failed to load latest event chat message: '
                '${messageSnapshot.error.runtimeType}',
              );
            }

            final messageState = messageResolution.displayState;
            final latestMessages =
                messageState?.messages ?? const <EventChatMessagesRecord>[];
            final latestMessage =
                latestMessages.isEmpty ? null : latestMessages.first;
            final subtitle = messageState == null
                ? '\u00A0'
                : _eventChatSubtitle(context, latestMessage);
            final timestamp = _eventChatTimestamp(chat, latestMessage);

            return _dismissibleChatCard(
              keyValue: _eventChatHiddenKey(chat),
              onDelete: onDelete,
              child: InkWell(
                splashColor: Colors.transparent,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () => _openEventChat(
                  currentUid,
                  chat,
                  sourceEpoch,
                ),
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.zero,
                  color: Colors.transparent,
                  child: _chatRowFrame(
                    child: Row(
                      children: [
                        Container(
                          width: _favoriteChatAvatarSize,
                          height: _favoriteChatAvatarSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ExpatlioDesign.avatarFallbackBackground,
                            shape: BoxShape.circle,
                            border: Border.all(color: ExpatlioDesign.border),
                          ),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            color: FlutterFlowTheme.of(context).primary,
                            size: 20.0,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.itemSpacing,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: ExpatlioDesign.textStyle(
                                          context,
                                          size: 16.0,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: ExpatlioDesign.space4),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ExpatlioDesign.textStyle(
                                    context,
                                    color: ExpatlioDesign.muted,
                                    size: 14.0,
                                    weight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _chatTimestampColumn(
                          timestampText: _formatInboxTimestamp(timestamp),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyListState(
    BuildContext context, {
    required String text,
  }) {
    return Center(
      child: SizedBox(
        height: 360.0,
        child: EmptyWidget(
          txt: text,
        ),
      ),
    );
  }

  Widget _buildMessagesInitialLoadingState(BuildContext context) {
    final loadingLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Загрузка сообщений',
      enText: 'Loading messages',
    );
    return Center(
      key: favoriteMessagesInitialLoadingKey,
      child: Semantics(
        container: true,
        liveRegion: true,
        label: loadingLabel,
        child: const ExcludeSemantics(
          child: SizedBox(
            width: 28.0,
            height: 28.0,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: ExpatlioDesign.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesTabContent(
    BuildContext context, {
    required String currentUid,
    required int sourceEpoch,
    required bool ownerMetadataLoading,
    required bool ownerMetadataLoadFailed,
    required bool ownerMetadataAccessDenied,
    required bool ownerMetadataCanDisplay,
    required bool ownerMetadataHasLoaded,
    required bool conversationsLoading,
    required bool conversationsLoadFailed,
    required bool conversationsAccessDenied,
    required bool conversationsHasLoaded,
    required List<ConversationsRecord> conversations,
    required bool eventChatsLoading,
    required bool eventChatsLoadFailed,
    required bool eventChatsAccessDenied,
    required bool eventChatsHasLoaded,
    required List<EventChatsRecord> eventChats,
    required List<DocumentReference> friends,
    required Set<String> hiddenChatKeys,
  }) {
    final friendPaths = friends.map((reference) => reference.path).toSet();
    final inboxItems = _buildInboxItems(
      conversations: conversations,
      eventChats: eventChats,
      hiddenChatKeys: hiddenChatKeys,
    );
    final inboxItemIndexByRowKey = <Key, int>{
      for (var index = 0; index < inboxItems.length; index += 1)
        if (_inboxItemAsyncRowKey(currentUid, inboxItems[index])
            case final rowKey?)
          rowKey: index,
    };
    final messagesInitialLoading =
        ownerMetadataLoading || conversationsLoading || eventChatsLoading;
    final messagesLoadFailed = ownerMetadataLoadFailed ||
        conversationsLoadFailed ||
        eventChatsLoadFailed;
    final messagesHaveLoaded =
        ownerMetadataHasLoaded && conversationsHasLoaded && eventChatsHasLoaded;
    final accessDenied = ownerMetadataAccessDenied ||
        conversationsAccessDenied ||
        eventChatsAccessDenied;

    if (!ownerMetadataCanDisplay) {
      if (!ownerMetadataLoadFailed) {
        return _buildMessagesInitialLoadingState(context);
      }
      return _buildMessagesLoadError(
        context,
        accessDenied: accessDenied,
      );
    }

    if (messagesLoadFailed && !messagesHaveLoaded && inboxItems.isEmpty) {
      return _buildMessagesLoadError(
        context,
        accessDenied: accessDenied,
      );
    }

    if (messagesInitialLoading && inboxItems.isEmpty) {
      return _buildMessagesInitialLoadingState(context);
    }

    final content = inboxItems.isEmpty
        ? _buildEmptyListState(
            context,
            text: FFLocalizations.of(context).getVariableText(
              ruText: 'У вас пока нет сообщений.',
              enText: 'You do not have messages yet.',
            ),
          )
        : ListView.builder(
            key: favoriteMessagesListKey,
            padding: const EdgeInsetsDirectional.only(
              bottom: ExpatlioDesign.space112,
            ),
            itemCount: inboxItems.length,
            findChildIndexCallback: (key) => inboxItemIndexByRowKey[key],
            itemBuilder: (context, index) {
              final item = inboxItems[index];
              final conversation = item.conversation;
              if (conversation == null) {
                final eventChat = item.eventChat;
                if (eventChat == null) {
                  return const SizedBox.shrink();
                }

                return _eventChatCard(
                  context,
                  currentUid: currentUid,
                  sourceEpoch: sourceEpoch,
                  chat: eventChat,
                  onDelete: () => _hideChat(
                    ownerUid: currentUid,
                    hiddenKey: _eventChatHiddenKey(eventChat),
                    sourceEpoch: sourceEpoch,
                  ),
                );
              }

              return _conversationCard(
                context,
                currentUid: currentUid,
                sourceEpoch: sourceEpoch,
                conversation: conversation,
                isFriend: _conversationPartnerIsFriendPathSet(
                  conversation,
                  friendPaths,
                  currentUid,
                ),
                onDelete: () => _hideChat(
                  ownerUid: currentUid,
                  hiddenKey: _conversationHiddenKey(conversation),
                  sourceEpoch: sourceEpoch,
                ),
              );
            },
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (messagesLoadFailed)
          PositionedDirectional(
            start: ExpatlioDesign.pagePadding,
            end: ExpatlioDesign.pagePadding,
            bottom:
                MediaQuery.paddingOf(context).bottom + ExpatlioDesign.space16,
            child: _buildMessagesPreviousDataError(context),
          ),
      ],
    );
  }

  Widget _buildMessagesLoadError(
    BuildContext context, {
    required bool accessDenied,
  }) {
    final title = FFLocalizations.of(context).getVariableText(
      ruText: 'Не удалось загрузить сообщения',
      enText: 'Could not load messages',
    );
    final message = accessDenied
        ? FFLocalizations.of(context).getVariableText(
            ruText: 'Чаты пока недоступны для этого аккаунта.',
            enText: 'Chats are not available for this account yet.',
          )
        : FFLocalizations.of(context).getVariableText(
            ruText: 'Проверьте подключение и попробуйте снова.',
            enText: 'Check your connection and try again.',
          );
    return Center(
      child: UxErrorState(
        key: favoriteMessagesLoadErrorKey,
        title: title,
        message: message,
        semanticsLabel: '$title. $message',
        onRetry: _retryMessagesTabSources,
        retryLabel: FFLocalizations.of(context).getVariableText(
          ruText: 'Повторить',
          enText: 'Retry',
        ),
        retrySemanticsLabel: FFLocalizations.of(context).getVariableText(
          ruText: 'Повторить загрузку сообщений',
          enText: 'Retry loading messages',
        ),
        retryButtonKey: favoriteMessagesRetryButtonKey,
      ),
    );
  }

  Widget _buildMessagesPreviousDataError(BuildContext context) {
    final message = FFLocalizations.of(context).getVariableText(
      ruText: 'Не удалось обновить сообщения.',
      enText: 'Could not refresh messages.',
    );
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
      child: Semantics(
        key: favoriteMessagesInlineErrorKey,
        container: true,
        liveRegion: true,
        label: message,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.space12,
            ExpatlioDesign.space8,
            ExpatlioDesign.space8,
            ExpatlioDesign.space8,
          ),
          decoration: BoxDecoration(
            color: ExpatlioDesign.card,
            borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
            border: Border.all(color: ExpatlioDesign.danger),
          ),
          child: Row(
            children: [
              Expanded(child: Text(message)),
              TextButton(
                key: favoriteMessagesRetryButtonKey,
                onPressed: _retryMessagesTabSources,
                child: Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Повторить',
                    enText: 'Retry',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsTabContent(
    BuildContext context, {
    required String currentUid,
    required int sourceEpoch,
    required bool conversationsLoading,
    required bool conversationsLoadFailed,
    required bool conversationsAccessDenied,
    required bool conversationsHasLoaded,
    required bool friendsLoading,
    required bool friendsLoadFailed,
    required bool friendsAccessDenied,
    required bool friendsHasLoaded,
    required List<DocumentReference> friends,
    required List<ConversationsRecord> conversations,
    required Set<String> hiddenChatKeys,
  }) {
    final friendPaths = friends.map((reference) => reference.path).toSet();
    final friendConversations = conversations
        .where(
          (conversation) =>
              _conversationPartnerIsFriendPathSet(
                conversation,
                friendPaths,
                currentUid,
              ) &&
              !hiddenChatKeys.contains(_conversationHiddenKey(conversation)),
        )
        .toList();
    final viewState = resolveFavoriteFriendsTabViewState(
      conversationsLoading: conversationsLoading,
      conversationsLoadFailed: conversationsLoadFailed,
      conversationsHasLoaded: conversationsHasLoaded,
      friendsLoading: friendsLoading,
      friendsLoadFailed: friendsLoadFailed,
      friendsHasLoaded: friendsHasLoaded,
      hasFriendConversations: friendConversations.isNotEmpty,
    );
    final loadingLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Загрузка чатов с друзьями',
      enText: 'Loading chats with friends',
    );
    final errorTitle = FFLocalizations.of(context).getVariableText(
      ruText: 'Не удалось загрузить чаты',
      enText: 'Could not load chats',
    );
    final errorMessage = conversationsAccessDenied || friendsAccessDenied
        ? FFLocalizations.of(context).getVariableText(
            ruText: 'Чаты пока недоступны для этого аккаунта.',
            enText: 'Chats are not available for this account yet.',
          )
        : FFLocalizations.of(context).getVariableText(
            ruText: 'Не удалось загрузить чаты с друзьями. Попробуйте позже.',
            enText:
                'Could not load chats with friends. Please try again later.',
          );
    final retryLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Повторить',
      enText: 'Retry',
    );
    final retrySemanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Повторить загрузку чатов с друзьями',
      enText: 'Retry loading chats with friends',
    );
    final hasVisiblePartialData = friendConversations.isNotEmpty;
    final hasPreviousDataError = (conversationsLoadFailed &&
            (conversationsHasLoaded || hasVisiblePartialData)) ||
        (friendsLoadFailed && (friendsHasLoaded || hasVisiblePartialData));
    final friendConversationIndexByRowKey = <Key, int>{
      for (var index = 0; index < friendConversations.length; index += 1)
        favoriteConversationAsyncRowKey(
          ownerUid: currentUid,
          conversationPath: friendConversations[index].reference.path,
        ): index,
    };

    final stateSlot = FavoriteFriendsTabStateSlot(
      state: viewState,
      initialLoading: Center(
        child: Semantics(
          container: true,
          liveRegion: true,
          label: loadingLabel,
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28.0,
                  height: 28.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: ExpatlioDesign.primary,
                  ),
                ),
                const SizedBox(height: ExpatlioDesign.space12),
                Text(
                  loadingLabel,
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: ExpatlioDesign.muted,
                    size: 14.0,
                    weight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      data: ListView.builder(
        padding:
            const EdgeInsetsDirectional.only(bottom: ExpatlioDesign.space112),
        itemCount: friendConversations.length,
        findChildIndexCallback: (key) => friendConversationIndexByRowKey[key],
        itemBuilder: (context, index) => _conversationCard(
          context,
          currentUid: currentUid,
          sourceEpoch: sourceEpoch,
          conversation: friendConversations[index],
          isFriend: true,
          onDelete: () => _hideChat(
            ownerUid: currentUid,
            hiddenKey: _conversationHiddenKey(friendConversations[index]),
            sourceEpoch: sourceEpoch,
          ),
        ),
      ),
      empty: _buildEmptyListState(
        context,
        text: FFLocalizations.of(context).getVariableText(
          ruText: 'У вас пока нет чатов с друзьями.',
          enText: 'You do not have chats with friends yet.',
        ),
      ),
      errorWithoutData: Center(
        child: UxErrorState(
          title: errorTitle,
          message: errorMessage,
          semanticsLabel: '$errorTitle. $errorMessage',
          onRetry: _retryFriendsTabSources,
          retryLabel: retryLabel,
          retrySemanticsLabel: retrySemanticsLabel,
          retryButtonKey: favoriteFriendsRetryButtonKey,
        ),
      ),
    );
    if (viewState == FavoriteFriendsTabViewState.errorWithoutData) {
      return stateSlot;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        stateSlot,
        if (hasPreviousDataError)
          PositionedDirectional(
            start: ExpatlioDesign.pagePadding,
            end: ExpatlioDesign.pagePadding,
            bottom:
                MediaQuery.paddingOf(context).bottom + ExpatlioDesign.space16,
            child: _buildFriendsPreviousDataError(
              context,
              title: errorTitle,
              message: errorMessage,
              retryLabel: retryLabel,
              retrySemanticsLabel: retrySemanticsLabel,
            ),
          ),
      ],
    );
  }

  Widget _buildFriendsPreviousDataError(
    BuildContext context, {
    required String title,
    required String message,
    required String retryLabel,
    required String retrySemanticsLabel,
  }) {
    return Semantics(
      key: favoriteFriendsInlineErrorKey,
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: '$title. $message',
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.zero,
        padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space12,
          ExpatlioDesign.space8,
          ExpatlioDesign.space8,
          ExpatlioDesign.space8,
        ),
        decoration: BoxDecoration(
          color: ExpatlioDesign.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
          border: Border.all(
            color: ExpatlioDesign.danger.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: ExpatlioDesign.text,
                    size: 13.0,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: ExpatlioDesign.space8),
            Semantics(
              key: favoriteFriendsRetryButtonKey,
              container: true,
              button: true,
              label: retrySemanticsLabel,
              onTap: _retryFriendsTabSources,
              excludeSemantics: true,
              child: TextButton(
                onPressed: _retryFriendsTabSources,
                child: Text(retryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isPermissionDenied(Object? error) =>
      error is FirebaseException && error.code == 'permission-denied';

  void _retryFriendsTabSources() {
    setState(() {
      _friendsRetryToken += 1;
      _conversationsRetryToken += 1;
      _friendsStreamUid = null;
      _friendsStream = null;
      _conversationsStreamUid = null;
      _conversationsStream = null;
    });
  }

  void _retryMessagesTabSources() {
    setState(() {
      _friendsRetryToken += 1;
      _conversationsRetryToken += 1;
      _eventChatsRetryToken += 1;
      _latestMessagesRetryToken += 1;
      _friendsStreamUid = null;
      _friendsStream = null;
      _conversationsStreamUid = null;
      _conversationsStream = null;
      _eventChatsStreamUid = null;
      _eventChatsStream = null;
      _latestEventChatMessageStreams.clear();
    });
  }

  void _invalidateInstanceSources() {
    _friendsStreamUid = null;
    _friendsStream = null;
    _conversationsStreamUid = null;
    _conversationsStream = null;
    _eventChatsStreamUid = null;
    _eventChatsStream = null;
    _latestEventChatMessageStreams.clear();
    _conversationUnreadCountStreams.clear();
  }

  _FavoriteAuthOwnerEpoch _observeRawAuthOwner(String rawOwnerUid) {
    final ownerUid = favoriteAuthOwnerUid(rawOwnerUid);
    final ownerChanged = ownerUid != _lastRawAuthOwnerUid;
    _lastRawAuthOwnerUid = ownerUid;
    _authSourceEpoch += 1;
    if (ownerChanged) {
      _clearSessionCache();
    }
    _invalidateInstanceSources();
    _activeUid = ownerUid;
    return _FavoriteAuthOwnerEpoch(
      ownerUid: ownerUid,
      sourceEpoch: _authSourceEpoch,
    );
  }

  void _activateCurrentUid(String currentUid) {
    final previousUid = _activeUid;
    if (previousUid == null) {
      _activeUid = currentUid;
      return;
    }
    if (previousUid == currentUid) {
      return;
    }

    _clearSessionCache();
    _invalidateInstanceSources();
    _activeUid = currentUid;
  }

  void _scheduleOwnerBoundaryInvalidation(String expectedOwnerUid) {
    if (!mounted ||
        _ownerBoundaryInvalidationScheduled ||
        _ownerIsCurrent(expectedOwnerUid)) {
      return;
    }
    _ownerBoundaryInvalidationScheduled = true;
    scheduleMicrotask(() {
      _ownerBoundaryInvalidationScheduled = false;
      if (!mounted || _ownerIsCurrent(expectedOwnerUid)) {
        return;
      }
      setState(() => _activateCurrentUid(''));
    });
  }

  Stream<FavoriteFriendsLoadState> _friendsSourceForUser(String currentUid) {
    final debugSource = widget.debugFriendsSource;
    if (debugSource == null) {
      return _watchFriendsForUser(currentUid);
    }
    if (_friendsStreamUid == currentUid && _friendsStream != null) {
      return _friendsStream!;
    }
    _friendsStreamUid = currentUid;
    final sourceGeneration = _sessionCacheGeneration;
    var lastState = _cachedFriendsStateForUser(currentUid);
    final source = guardFavoriteOwnerScopedSource(
      source: debugSource(currentUid),
      expectedOwnerUid: currentUid,
      sourceGeneration: sourceGeneration,
      currentGeneration: () => _sessionCacheGeneration,
      ownerIsCurrent: _guardedSourceOwnerIsCurrent,
      ownerUidOf: (state) => state.ownerUid,
    );
    _friendsStream = source.map((incomingState) {
      final loadedState = mergeFavoriteFriendsLoadState(
        lastState,
        incomingState,
      );
      lastState = loadedState;
      _rememberFriendsState(currentUid, loadedState);
      return loadedState;
    });
    return _friendsStream!;
  }

  Stream<FavoriteConversationsLoadState> _conversationsSourceForUser(
    String currentUid,
  ) {
    final debugSource = widget.debugConversationsSource;
    if (debugSource == null) {
      return _watchConversationsForUser(currentUid);
    }
    if (_conversationsStreamUid == currentUid && _conversationsStream != null) {
      return _conversationsStream!;
    }
    _conversationsStreamUid = currentUid;
    final sourceGeneration = _sessionCacheGeneration;
    var lastState = _cachedConversationsStateForUser(currentUid);
    final source = guardFavoriteOwnerScopedSource(
      source: debugSource(currentUid),
      expectedOwnerUid: currentUid,
      sourceGeneration: sourceGeneration,
      currentGeneration: () => _sessionCacheGeneration,
      ownerIsCurrent: _guardedSourceOwnerIsCurrent,
      ownerUidOf: (state) => state.ownerUid,
    );
    _conversationsStream = source.map((incomingState) {
      final loadedState = mergeFavoriteConversationsLoadState(
        lastState,
        incomingState,
      );
      lastState = loadedState;
      _rememberConversationsState(currentUid, loadedState);
      return loadedState;
    });
    return _conversationsStream!;
  }

  Stream<FavoriteEventChatsLoadState> _eventChatsSourceForUser(
    String currentUid,
  ) {
    final debugSource = widget.debugEventChatsSource;
    if (debugSource == null) {
      return _watchEventChatsForUser(currentUid);
    }
    if (_eventChatsStreamUid == currentUid && _eventChatsStream != null) {
      return _eventChatsStream!;
    }
    _eventChatsStreamUid = currentUid;
    final sourceGeneration = _sessionCacheGeneration;
    var lastState = _cachedEventChatsStateForUser(currentUid);
    final source = guardFavoriteOwnerScopedSource(
      source: debugSource(currentUid),
      expectedOwnerUid: currentUid,
      sourceGeneration: sourceGeneration,
      currentGeneration: () => _sessionCacheGeneration,
      ownerIsCurrent: _guardedSourceOwnerIsCurrent,
      ownerUidOf: (state) => state.ownerUid,
    );
    _eventChatsStream = source.map((incomingState) {
      final loadedState = mergeFavoriteEventChatsLoadState(
        lastState,
        incomingState,
      );
      lastState = loadedState;
      _rememberEventChatsState(currentUid, loadedState);
      return loadedState;
    });
    return _eventChatsStream!;
  }

  FavoriteFriendsLoadState? _initialFriendsStateForUser(String currentUid) =>
      _cachedFriendsStateForUser(currentUid) ??
      (NewAccountInboxBootstrap.shouldSeedEmptyInbox(currentUid)
          ? FavoriteFriendsLoadState(
              ownerUid: currentUid,
              rawHiddenChatKeys: const <String>[],
            )
          : null);

  FavoriteConversationsLoadState? _initialConversationsStateForUser(
    String currentUid,
  ) =>
      _cachedConversationsStateForUser(currentUid) ??
      (NewAccountInboxBootstrap.shouldSeedEmptyInbox(currentUid)
          ? FavoriteConversationsLoadState(
              ownerUid: currentUid,
              isAuthoritative: true,
            )
          : null);

  FavoriteEventChatsLoadState? _initialEventChatsStateForUser(
    String currentUid,
  ) =>
      _cachedEventChatsStateForUser(currentUid) ??
      (NewAccountInboxBootstrap.shouldSeedEmptyInbox(currentUid)
          ? FavoriteEventChatsLoadState(
              ownerUid: currentUid,
              isAuthoritative: true,
            )
          : null);

  Widget _buildNeutralOwnerShell(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: MediaQuery.paddingOf(context).top + 56),
            _buildChatsTabBar(context),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
        _buildHeader(context),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _ensureSessionCacheLifecycleRegistered();
    _lastRawAuthOwnerUid = widget.debugAuthUidStream == null
        ? favoriteAuthOwnerUid(FirebaseAuth.instance.currentUser?.uid)
        : favoriteAuthOwnerUid(widget.debugInitialAuthUid);
    final rawUidStream = widget.debugAuthUidStream ??
        FirebaseAuth.instance
            .authStateChanges()
            .map((user) => favoriteAuthOwnerUid(user?.uid));
    _currentUidStream = rawUidStream.map(_observeRawAuthOwner);
    _model = createModel(context, () => FavoriteModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: ExpatlioDesign.background,
        body: Stack(
          children: [
            StreamBuilder<_FavoriteAuthOwnerEpoch>(
              stream: _currentUidStream,
              initialData: _FavoriteAuthOwnerEpoch(
                ownerUid: widget.debugAuthUidStream == null
                    ? favoriteAuthOwnerUid(
                        FirebaseAuth.instance.currentUser?.uid,
                      )
                    : favoriteAuthOwnerUid(widget.debugInitialAuthUid),
                sourceEpoch: _authSourceEpoch,
              ),
              builder: (context, currentUidSnapshot) {
                final authOwnerEpoch = currentUidSnapshot.data ??
                    _FavoriteAuthOwnerEpoch(
                      ownerUid: '',
                      sourceEpoch: _authSourceEpoch,
                    );
                final streamOwnerUid = authOwnerEpoch.ownerUid;
                final sourceEpoch = authOwnerEpoch.sourceEpoch;
                final currentUid = _streamOwnerMatchesDirectAuth(
                  streamOwnerUid,
                )
                    ? streamOwnerUid
                    : '';
                _activateCurrentUid(currentUid);

                if (currentUid.isEmpty) {
                  return _buildNeutralOwnerShell(context);
                }

                return FavoriteChatSourceBuilder<FavoriteFriendsLoadState>(
                  sourceId: 'friends',
                  currentUid: currentUid,
                  sourceEpoch: sourceEpoch,
                  stream: _friendsSourceForUser(currentUid),
                  cachedState: _initialFriendsStateForUser(currentUid),
                  retryToken: _friendsRetryToken,
                  stateReducer: mergeFavoriteFriendsLoadState,
                  builder: (context, friendsSnapshot, friendsResolution) {
                    if (!_authEpochOwnerIsCurrent(currentUid, sourceEpoch)) {
                      _scheduleOwnerBoundaryInvalidation(currentUid);
                      return _buildNeutralOwnerShell(context);
                    }
                    if (kDebugMode && friendsSnapshot.hasError) {
                      debugPrint(
                        'FavoriteWidget: friends stream error: '
                        '${friendsSnapshot.error.runtimeType}',
                      );
                    }

                    final candidateFriendsState =
                        friendsResolution.displayState;
                    final friendsState = favoriteOwnedUserDocumentValue(
                      currentUid: currentUid,
                      documentOwnerUid: candidateFriendsState?.ownerUid,
                      value: candidateFriendsState,
                    );
                    final friendsHasLoaded =
                        friendsState?.hasAuthoritativeResult ?? false;
                    final friendsLoading =
                        !(friendsState?.hasAuthoritativeResult ?? false);
                    final friendsLoadFailed = friendsSnapshot.hasError;
                    final friendsAccessDenied =
                        _isPermissionDenied(friendsSnapshot.error);
                    final friends =
                        friendsState?.friends ?? const <DocumentReference>[];
                    final rawHiddenChatKeys = friendsState?.rawHiddenChatKeys;
                    final hiddenChatKeysHaveLoaded =
                        friendsState?.hiddenChatKeysAreKnown ?? false;
                    final hiddenChatKeysLoading = !hiddenChatKeysHaveLoaded;
                    final hiddenChatKeysAreAuthoritative =
                        friendsState?.hiddenChatKeysAreAuthoritative ?? false;
                    return FavoriteChatSourceBuilder<
                        FavoriteConversationsLoadState>(
                      sourceId: 'conversations',
                      currentUid: currentUid,
                      sourceEpoch: sourceEpoch,
                      stream: _conversationsSourceForUser(currentUid),
                      cachedState:
                          _initialConversationsStateForUser(currentUid),
                      retryToken: _conversationsRetryToken,
                      stateReducer: mergeFavoriteConversationsLoadState,
                      builder: (context, conversationsSnapshot,
                          conversationsResolution) {
                        if (!_authEpochOwnerIsCurrent(
                          currentUid,
                          sourceEpoch,
                        )) {
                          _scheduleOwnerBoundaryInvalidation(currentUid);
                          return _buildNeutralOwnerShell(context);
                        }
                        if (kDebugMode && conversationsSnapshot.hasError) {
                          debugPrint(
                            'FavoriteWidget: conversations stream error: '
                            '${conversationsSnapshot.error.runtimeType}',
                          );
                        }

                        final conversationsState =
                            conversationsResolution.displayState;
                        final conversationsHasLoaded =
                            conversationsState?.hasAuthoritativeResult ?? false;
                        final conversationsError = conversationsSnapshot.error;
                        final conversationsLoading =
                            !(conversationsState?.hasAuthoritativeResult ??
                                false);
                        final conversationsLoadFailed =
                            conversationsSnapshot.hasError;
                        final conversationsAccessDenied =
                            _isPermissionDenied(conversationsError);
                        final conversations =
                            conversationsState?.conversations ??
                                <ConversationsRecord>[];

                        return FavoriteChatSourceBuilder<
                            FavoriteEventChatsLoadState>(
                          sourceId: 'event-chats',
                          currentUid: currentUid,
                          sourceEpoch: sourceEpoch,
                          stream: _eventChatsSourceForUser(currentUid),
                          cachedState:
                              _initialEventChatsStateForUser(currentUid),
                          retryToken: _eventChatsRetryToken,
                          stateReducer: mergeFavoriteEventChatsLoadState,
                          builder: (context, eventChatsSnapshot,
                              eventChatsResolution) {
                            if (!_authEpochOwnerIsCurrent(
                              currentUid,
                              sourceEpoch,
                            )) {
                              _scheduleOwnerBoundaryInvalidation(currentUid);
                              return _buildNeutralOwnerShell(context);
                            }
                            if (kDebugMode && eventChatsSnapshot.hasError) {
                              debugPrint(
                                'FavoriteWidget: event chats stream error: '
                                '${eventChatsSnapshot.error.runtimeType}',
                              );
                            }

                            final eventChatsState =
                                eventChatsResolution.displayState;
                            final eventChatsHasLoaded =
                                eventChatsState?.hasAuthoritativeResult ??
                                    false;
                            final eventChatsLoading =
                                !(eventChatsState?.hasAuthoritativeResult ??
                                    false);
                            final eventChatsLoadFailed =
                                eventChatsSnapshot.hasError;
                            final eventChatsAccessDenied =
                                _isPermissionDenied(eventChatsSnapshot.error);
                            final eventChats = eventChatsState?.eventChats ??
                                <EventChatsRecord>[];
                            final hiddenChatKeys =
                                _hiddenChatKeysForCurrentUser(
                              currentUid,
                              rawHiddenChatKeys,
                              hiddenChatKeysAreAuthoritative:
                                  hiddenChatKeysAreAuthoritative,
                            );

                            final showFriendsTab = _selectedChatTabIndex == 1;

                            return Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.paddingOf(context).top +
                                              56,
                                    ),
                                    _buildChatsTabBar(context),
                                    Expanded(
                                      child: showFriendsTab
                                          ? _buildFriendsTabContent(
                                              context,
                                              currentUid: currentUid,
                                              sourceEpoch: sourceEpoch,
                                              conversationsLoading:
                                                  conversationsLoading,
                                              conversationsLoadFailed:
                                                  conversationsLoadFailed,
                                              conversationsAccessDenied:
                                                  conversationsAccessDenied,
                                              conversationsHasLoaded:
                                                  conversationsHasLoaded,
                                              friendsLoading: friendsLoading ||
                                                  hiddenChatKeysLoading,
                                              friendsLoadFailed:
                                                  friendsLoadFailed,
                                              friendsAccessDenied:
                                                  friendsAccessDenied,
                                              friendsHasLoaded:
                                                  friendsHasLoaded &&
                                                      hiddenChatKeysHaveLoaded,
                                              friends: hiddenChatKeysHaveLoaded
                                                  ? friends
                                                  : const <DocumentReference>[],
                                              conversations: conversations,
                                              hiddenChatKeys: hiddenChatKeys,
                                            )
                                          : _buildMessagesTabContent(
                                              context,
                                              currentUid: currentUid,
                                              sourceEpoch: sourceEpoch,
                                              ownerMetadataLoading:
                                                  friendsLoading ||
                                                      hiddenChatKeysLoading,
                                              ownerMetadataLoadFailed:
                                                  friendsLoadFailed,
                                              ownerMetadataAccessDenied:
                                                  friendsAccessDenied,
                                              ownerMetadataCanDisplay:
                                                  hiddenChatKeysHaveLoaded,
                                              ownerMetadataHasLoaded:
                                                  friendsHasLoaded &&
                                                      hiddenChatKeysHaveLoaded,
                                              conversationsLoading:
                                                  conversationsLoading,
                                              conversationsLoadFailed:
                                                  conversationsLoadFailed,
                                              conversationsAccessDenied:
                                                  conversationsAccessDenied,
                                              conversationsHasLoaded:
                                                  conversationsHasLoaded,
                                              conversations: conversations,
                                              eventChatsLoading:
                                                  eventChatsLoading,
                                              eventChatsLoadFailed:
                                                  eventChatsLoadFailed,
                                              eventChatsAccessDenied:
                                                  eventChatsAccessDenied,
                                              eventChatsHasLoaded:
                                                  eventChatsHasLoaded,
                                              eventChats: eventChats,
                                              friends: friends,
                                              hiddenChatKeys: hiddenChatKeys,
                                            ),
                                    ),
                                  ],
                                ),
                                _buildHeader(context),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationUnreadBadge extends StatelessWidget {
  const _ConversationUnreadBadge({
    required this.badgeKey,
    required this.unreadCountStream,
  });

  final Key badgeKey;
  final Stream<int> unreadCountStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: unreadCountStream,
      initialData: 1,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 1;
        if (count <= 0) {
          return const SizedBox.shrink();
        }

        return _UnreadCountBadge(key: badgeKey, count: count);
      },
    );
  }
}

class _UnreadCountBadge extends StatelessWidget {
  const _UnreadCountBadge({
    super.key,
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = favoriteChatUnreadBadgeLabel(count);

    return SizedBox.square(
      dimension: _favoriteChatUnreadBadgeSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: ExpatlioDesign.textStyle(
              context,
              color: Colors.white,
              size: label.length > 2 ? 11.0 : 12.0,
              weight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteOwnerDocumentState {
  const _FavoriteOwnerDocumentState({
    required this.rawHiddenChatKeys,
    required this.hiddenChatKeysAreKnown,
  });

  final Object? rawHiddenChatKeys;
  final bool hiddenChatKeysAreKnown;
}

class _InboxChatItem {
  const _InboxChatItem._({
    required this.sortAt,
    required this.sortId,
    this.conversation,
    this.eventChat,
  });

  factory _InboxChatItem.conversation(ConversationsRecord conversation) {
    return _InboxChatItem._(
      conversation: conversation,
      sortAt: conversation.lastMessageAt ?? conversation.unlockedAt,
      sortId: conversation.lastMessageId ?? conversation.pairId,
    );
  }

  factory _InboxChatItem.eventChat(EventChatsRecord eventChat) {
    return _InboxChatItem._(
      eventChat: eventChat,
      sortAt: EventGroupChatRepository.inboxSortAt(eventChat),
      sortId: EventGroupChatRepository.eventIdForChat(eventChat),
    );
  }

  final ConversationsRecord? conversation;
  final EventChatsRecord? eventChat;
  final DateTime? sortAt;
  final String sortId;
}

int _compareInboxChatItems(_InboxChatItem a, _InboxChatItem b) {
  final sortAtCmp = _compareNullableDateTimesDescending(a.sortAt, b.sortAt);
  if (sortAtCmp != 0) {
    return sortAtCmp;
  }

  return b.sortId.compareTo(a.sortId);
}

int _compareNullableDateTimesDescending(DateTime? a, DateTime? b) {
  if (a == null && b == null) {
    return 0;
  }
  if (a == null) {
    return 1;
  }
  if (b == null) {
    return -1;
  }
  return b.compareTo(a);
}
