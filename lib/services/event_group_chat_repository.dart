import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '/backend/backend.dart';
import '/services/event_detail_repository.dart';
import '/services/event_history_repository.dart';
import '/services/ux_session_cache_lifecycle.dart';

typedef EventChatMessagesStream = Stream<List<EventChatMessagesRecord>>
    Function(DocumentReference chatRef);
typedef EventChatMetadataStream = Stream<EventChatsRecord?> Function(
  DocumentReference chatRef,
);
typedef EventChatAccessStateStream = Stream<EventChatAccessLoadState> Function(
  DocumentReference chatRef,
  String ownerUid,
);
typedef EventChatMessagesStateStream = Stream<EventChatMessagesLoadState>
    Function(
  DocumentReference chatRef,
  String ownerUid,
);
typedef EventChatsStream = Stream<List<EventChatsRecord>> Function();
typedef EventChatsStateStream = Stream<EventChatInboxLoadState> Function();
typedef EventInboxEventIdsStream = Stream<EventInboxEventIdsLoadState>
    Function();
typedef EventChatByEventIdStream = Stream<EventChatsRecord?> Function(
  String eventId,
);
typedef EventChatOwnerMutationGuard = bool Function(String ownerUid);
typedef EventChatInboxUserSnapshot = ({bool exists, Object? data});
typedef EventChatInboxTransactionBody = Future<void> Function({
  required Future<EventChatInboxUserSnapshot> Function() readUser,
  required void Function(Map<String, Object?> data) updateUser,
});
typedef EventChatInboxTransactionRunner = Future<void> Function(
  EventChatInboxTransactionBody body,
);
typedef EventChatMessagesPageLoader
    = Future<FFFirestorePage<EventChatMessagesRecord>> Function(
  Query collection,
  RecordBuilder<EventChatMessagesRecord> recordBuilder, {
  Query Function(Query)? queryBuilder,
  DocumentSnapshot? nextPageMarker,
  required int pageSize,
  required bool isStream,
});

final class EventChatAccessLoadState {
  const EventChatAccessLoadState({
    required this.ownerUid,
    required this.chat,
    required this.accessGranted,
    required this.isFromCache,
    required this.hasPendingWrites,
  });

  final String ownerUid;
  final EventChatsRecord? chat;
  final bool accessGranted;
  final bool isFromCache;
  final bool hasPendingWrites;

  bool get isAuthoritative => !isFromCache && !hasPendingWrites;
}

final class EventChatMessagesLoadState {
  const EventChatMessagesLoadState({
    required this.ownerUid,
    required this.messages,
    required this.isFromCache,
    required this.hasPendingWrites,
  });

  final String ownerUid;
  final List<EventChatMessagesRecord> messages;
  final bool isFromCache;
  final bool hasPendingWrites;

  bool get isAuthoritative => !isFromCache && !hasPendingWrites;
  bool get canResolveEmpty => messages.isNotEmpty || isAuthoritative;
}

final class EventChatInboxLoadState {
  EventChatInboxLoadState({
    required this.ownerUid,
    required Iterable<EventChatsRecord> chats,
    required this.isAuthoritative,
  }) : chats = List<EventChatsRecord>.unmodifiable(chats);

  final String ownerUid;
  final List<EventChatsRecord> chats;
  final bool isAuthoritative;
}

final class EventInboxEventIdsLoadState {
  EventInboxEventIdsLoadState({
    String ownerUid = '',
    required Iterable<String> eventIds,
    this.isReady = true,
    required this.isAuthoritative,
  })  : assert(!isAuthoritative || isReady),
        ownerUid = ownerUid.trim(),
        eventIds = List<String>.unmodifiable(eventIds);

  final String ownerUid;
  final List<String> eventIds;
  final bool isReady;
  final bool isAuthoritative;
}

EventChatAccessLoadState resolveEventChatAccessSnapshot({
  required String ownerUid,
  required EventChatsRecord? chat,
  required bool isFromCache,
  required bool hasPendingWrites,
}) {
  final normalizedOwnerUid = ownerUid.trim();
  if (normalizedOwnerUid.isEmpty) {
    throw ArgumentError.value(ownerUid, 'ownerUid', 'must not be empty');
  }

  return EventChatAccessLoadState(
    ownerUid: normalizedOwnerUid,
    chat: chat,
    accessGranted:
        chat?.readAccessUserIds.contains(normalizedOwnerUid) ?? false,
    isFromCache: isFromCache,
    hasPendingWrites: hasPendingWrites,
  );
}

EventChatMessagesLoadState resolveEventChatMessagesSnapshot({
  required String ownerUid,
  required Iterable<EventChatMessagesRecord> messages,
  required bool isFromCache,
  required bool hasPendingWrites,
}) {
  final normalizedOwnerUid = ownerUid.trim();
  if (normalizedOwnerUid.isEmpty) {
    throw ArgumentError.value(ownerUid, 'ownerUid', 'must not be empty');
  }

  return EventChatMessagesLoadState(
    ownerUid: normalizedOwnerUid,
    messages: List<EventChatMessagesRecord>.unmodifiable(messages),
    isFromCache: isFromCache,
    hasPendingWrites: hasPendingWrites,
  );
}

class EventGroupChatRepository {
  const EventGroupChatRepository._();

  static const int defaultMessageLimit = 50;
  static const int maxMessageLimit = 100;
  static const int maxInboxChatCount = 50;
  // Remembered inbox entries are session hints, but still belong to one UID.
  static final Map<String, Set<String>> _rememberedInboxEventIdsByOwner =
      <String, Set<String>>{};
  static final StreamController<String?> _rememberedInboxOwnerChanges =
      StreamController<String?>.broadcast();

  static void _ensureSessionCacheLifecycleRegistered() {
    UxSessionCacheLifecycle.register(_clearRememberedInboxEventIds);
  }

  static void _clearRememberedInboxEventIds() {
    if (_rememberedInboxEventIdsByOwner.isEmpty) {
      return;
    }
    _rememberedInboxEventIdsByOwner.clear();
    _rememberedInboxOwnerChanges.add(null);
  }

  static DocumentReference chatReferenceForEventId(String eventId) =>
      EventChatsRecord.collection.doc(normalizeEventDetailId(eventId));

  static String eventIdForChat(EventChatsRecord chat) {
    final eventId = chat.eventId.trim();
    if (eventId.isNotEmpty) {
      return eventId;
    }

    return chat.reference.id.trim();
  }

  static Query buildMessagesQuery(Query messages) => messages
      .orderBy('createdAt', descending: false)
      .orderBy(FieldPath.documentId, descending: false);

  static Query buildLatestMessageQuery(Query messages) => messages
      .orderBy('createdAt', descending: true)
      .orderBy(FieldPath.documentId, descending: true);

  static Query buildInboxChatsQuery(Query chats, String currentUid) =>
      chats.where(
        'readAccessUserIds',
        arrayContains: currentUid,
      );

  static List<String> boundedInboxEventIds(
    Iterable<String> eventIds, {
    String? newestEventId,
  }) {
    final normalized = _normalizeInboxEventIds(eventIds).toList();
    final newest = newestEventId?.trim() ?? '';
    if (newest.isNotEmpty) {
      late final String normalizedNewest;
      try {
        normalizedNewest = normalizeEventDetailId(newest);
      } on ArgumentError {
        return List<String>.unmodifiable(
          normalized.length <= maxInboxChatCount
              ? normalized
              : normalized.sublist(normalized.length - maxInboxChatCount),
        );
      }
      normalized
        ..remove(normalizedNewest)
        ..add(normalizedNewest);
    }
    if (normalized.length > maxInboxChatCount) {
      normalized.removeRange(0, normalized.length - maxInboxChatCount);
    }
    return List<String>.unmodifiable(normalized);
  }

  static DateTime? inboxSortAt(EventChatsRecord chat) =>
      chat.updatedAt ?? chat.createdAt;

  static int compareChatsForInbox(EventChatsRecord a, EventChatsRecord b) {
    final sortAtCmp = _compareDateTimesDescending(
      inboxSortAt(a),
      inboxSortAt(b),
    );
    if (sortAtCmp != 0) {
      return sortAtCmp;
    }

    return eventIdForChat(b).compareTo(eventIdForChat(a));
  }

  static Stream<List<EventChatsRecord>> watchInboxChats({
    required String currentUid,
    EventChatsStream? chatsStream,
    EventChatsStateStream? chatsStateStream,
    EventInboxEventIdsStream? eventIdsStream,
    EventInboxEventIdsStream? rememberedEventIdsStream,
    EventChatByEventIdStream? chatByEventIdStream,
    EventChatAccessStateStream? chatAccessStateStream,
    EventChatOwnerMutationGuard? canMutateOwner,
    void Function(String eventId)? onInaccessibleEventId,
  }) =>
      watchInboxChatsState(
        currentUid: currentUid,
        chatsStream: chatsStream,
        chatsStateStream: chatsStateStream,
        eventIdsStream: eventIdsStream,
        rememberedEventIdsStream: rememberedEventIdsStream,
        chatByEventIdStream: chatByEventIdStream,
        chatAccessStateStream: chatAccessStateStream,
        canMutateOwner: canMutateOwner,
        onInaccessibleEventId: onInaccessibleEventId,
      ).map((state) => state.chats);

  static Stream<EventChatInboxLoadState> watchInboxChatsState({
    required String currentUid,
    EventChatsStream? chatsStream,
    EventChatsStateStream? chatsStateStream,
    EventInboxEventIdsStream? eventIdsStream,
    EventInboxEventIdsStream? rememberedEventIdsStream,
    EventChatByEventIdStream? chatByEventIdStream,
    EventChatAccessStateStream? chatAccessStateStream,
    EventChatOwnerMutationGuard? canMutateOwner,
    void Function(String eventId)? onInaccessibleEventId,
  }) {
    final normalizedUid = currentUid.trim();
    if (normalizedUid.isEmpty) {
      return Stream.value(
        EventChatInboxLoadState(
          ownerUid: '',
          chats: const <EventChatsRecord>[],
          isAuthoritative: true,
        ),
      );
    }

    final injectedStream = chatsStream;
    final injectedStateStream = chatsStateStream;
    Stream<EventChatInboxLoadState>? readAccessChatsStateStream;
    if (injectedStateStream != null) {
      EventChatInboxLoadState? lastState;
      readAccessChatsStateStream = injectedStateStream().map((state) {
        if (state.ownerUid != normalizedUid) {
          throw StateError('Event inbox chats belong to another owner');
        }
        final normalizedState = EventChatInboxLoadState(
          ownerUid: normalizedUid,
          chats: _sortedVisibleInboxChats(state.chats),
          isAuthoritative: state.isAuthoritative,
        );
        final mergedState = _mergeInboxChatsLoadState(
          lastState,
          normalizedState,
        );
        lastState = mergedState;
        return mergedState;
      });
    } else if (injectedStream != null) {
      readAccessChatsStateStream = injectedStream().map(
        (chats) => EventChatInboxLoadState(
          ownerUid: normalizedUid,
          chats: _sortedVisibleInboxChats(chats),
          isAuthoritative: true,
        ),
      );
    }
    if (readAccessChatsStateStream != null &&
        eventIdsStream == null &&
        rememberedEventIdsStream == null &&
        chatByEventIdStream == null &&
        chatAccessStateStream == null) {
      return readAccessChatsStateStream;
    }

    final eventIdSources = <Stream<EventInboxEventIdsLoadState>>[
      eventIdsStream?.call() ??
          _watchInboxEventIdsFromHistory(ownerUid: normalizedUid),
      watchRememberedInboxEventIds(ownerUid: normalizedUid),
    ];
    if (rememberedEventIdsStream != null) {
      eventIdSources.add(rememberedEventIdsStream());
    }
    final eventIds = _combineInboxEventIdSources(
      ownerUid: normalizedUid,
      sources: eventIdSources,
    );

    final eventHistoryChatsStream = _watchInboxChatsByEventIds(
      ownerUid: normalizedUid,
      eventIdsStream: eventIds,
      chatByEventIdStream: chatByEventIdStream ??
          (eventId) => _watchAccessibleChatByEventId(
                eventId: eventId,
                ownerUid: normalizedUid,
                accessStateStream: chatAccessStateStream,
                canMutateOwner: canMutateOwner,
                onInaccessibleEventId: onInaccessibleEventId,
              ),
    );
    if (readAccessChatsStateStream == null) {
      return eventHistoryChatsStream;
    }

    return _combineInboxChatSources(
      ownerUid: normalizedUid,
      readAccessChatsStream: readAccessChatsStateStream,
      eventHistoryChatsStream: eventHistoryChatsStream,
    );
  }

  static Stream<EventChatAccessLoadState> watchChatAccessState({
    required String eventId,
    required String ownerUid,
    EventChatMetadataStream? chatStream,
    EventChatAccessStateStream? accessStateStream,
  }) {
    final chatRef = chatReferenceForEventId(eventId);
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return const Stream<EventChatAccessLoadState>.empty();
    }
    final injectedStateStream = accessStateStream;
    if (injectedStateStream != null) {
      return injectedStateStream(chatRef, normalizedOwnerUid);
    }
    final injectedStream = chatStream;
    if (injectedStream != null) {
      return injectedStream(chatRef).map((chat) {
        if (chat != null &&
            (chat.reference.id != chatRef.id ||
                chat.eventId.trim() != chatRef.id)) {
          throw StateError('Event chat metadata does not match its document');
        }
        return EventChatAccessLoadState(
          ownerUid: normalizedOwnerUid,
          chat: chat,
          accessGranted: chat != null,
          isFromCache: false,
          hasPendingWrites: false,
        );
      });
    }

    return chatRef.snapshots(includeMetadataChanges: true).map((snapshot) {
      final chat =
          snapshot.exists ? EventChatsRecord.fromSnapshot(snapshot) : null;
      if (chat != null && chat.eventId.trim() != chatRef.id) {
        throw StateError('Event chat metadata does not match its document');
      }
      return resolveEventChatAccessSnapshot(
        ownerUid: normalizedOwnerUid,
        chat: chat,
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      );
    });
  }

  // Use FirebaseAuth directly so a stale profile cache cannot select an owner.
  static List<String> get rememberedInboxEventIds =>
      rememberedInboxEventIdsForOwner(
        FirebaseAuth.instance.currentUser?.uid ?? '',
      );

  static List<String> rememberedInboxEventIdsForOwner(String ownerUid) {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return const <String>[];
    }
    return List<String>.unmodifiable(
      _rememberedInboxEventIdsByOwner[normalizedOwnerUid] ?? const <String>{},
    );
  }

  static void rememberInboxEventId(
    String eventId, {
    required String ownerUid,
  }) {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return;
    }

    late final String normalizedEventId;
    try {
      normalizedEventId = normalizeEventDetailId(eventId);
    } on ArgumentError {
      return;
    }

    _ensureSessionCacheLifecycleRegistered();
    if (UxSessionCacheLifecycle.sessionUserIdOrFallback(normalizedOwnerUid) !=
        normalizedOwnerUid) {
      return;
    }
    final ownerEventIds = _rememberedInboxEventIdsByOwner.putIfAbsent(
      normalizedOwnerUid,
      () => <String>{},
    );
    ownerEventIds
      ..remove(normalizedEventId)
      ..add(normalizedEventId);
    while (ownerEventIds.length > maxInboxChatCount) {
      ownerEventIds.remove(ownerEventIds.first);
    }
    _rememberedInboxOwnerChanges.add(normalizedOwnerUid);
  }

  static Future<void> persistInboxEventId({
    required String ownerUid,
    required DocumentReference userReference,
    required String eventId,
    bool Function()? isStillCurrent,
    EventChatInboxTransactionRunner? transactionRunner,
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    final normalizedEventId = normalizeEventDetailId(eventId);
    if (normalizedOwnerUid.isEmpty) {
      throw ArgumentError.value(ownerUid, 'ownerUid', 'must not be empty');
    }
    if (userReference.parent.path != UsersRecord.collection.path ||
        userReference.id != normalizedOwnerUid) {
      throw StateError('Event chat inbox owner reference does not match');
    }

    final EventChatInboxTransactionRunner runTransaction = transactionRunner ??
        (body) => FirebaseFirestore.instance.runTransaction(
              (transaction) => body(
                readUser: () async {
                  final snapshot = await transaction.get(userReference);
                  return (
                    exists: snapshot.exists,
                    data: snapshot.data(),
                  );
                },
                updateUser: (data) => transaction.update(userReference, data),
              ),
            );

    await runTransaction(({
      required Future<EventChatInboxUserSnapshot> Function() readUser,
      required void Function(Map<String, Object?> data) updateUser,
    }) async {
      if (!(isStillCurrent?.call() ?? true)) {
        return;
      }
      final userSnapshot = await readUser();
      if (!userSnapshot.exists || !(isStillCurrent?.call() ?? true)) {
        return;
      }
      final data = userSnapshot.data;
      final rawEventIds =
          data is Map ? data['eventChatInboxEventIds'] : const <Object?>[];
      final eventIds = boundedInboxEventIds(
        rawEventIds is Iterable
            ? rawEventIds.whereType<String>()
            : const <String>[],
        newestEventId: normalizedEventId,
      );
      updateUser({
        'eventChatInboxEventIds': eventIds,
        'hiddenChatKeys': FieldValue.arrayRemove([
          'event:$normalizedEventId',
        ]),
      });
    });
  }

  static void forgetInboxEventId(
    String eventId, {
    required String ownerUid,
  }) {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return;
    }
    late final String normalizedEventId;
    try {
      normalizedEventId = normalizeEventDetailId(eventId);
    } on ArgumentError {
      return;
    }
    final ownerEventIds = _rememberedInboxEventIdsByOwner[normalizedOwnerUid];
    if (ownerEventIds?.remove(normalizedEventId) ?? false) {
      _rememberedInboxOwnerChanges.add(normalizedOwnerUid);
    }
  }

  static Stream<EventInboxEventIdsLoadState> watchRememberedInboxEventIds({
    required String ownerUid,
  }) {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return Stream.value(
        EventInboxEventIdsLoadState(
          ownerUid: '',
          eventIds: const <String>[],
          isReady: true,
          isAuthoritative: true,
        ),
      );
    }

    _ensureSessionCacheLifecycleRegistered();
    late final StreamController<EventInboxEventIdsLoadState> controller;
    StreamSubscription<String?>? ownerChangesSubscription;
    controller = StreamController<EventInboxEventIdsLoadState>(
      onListen: () {
        ownerChangesSubscription = _rememberedInboxOwnerChanges.stream.listen(
          (changedOwnerUid) {
            if (changedOwnerUid == null ||
                changedOwnerUid == normalizedOwnerUid) {
              controller.add(
                EventInboxEventIdsLoadState(
                  ownerUid: normalizedOwnerUid,
                  eventIds: rememberedInboxEventIdsForOwner(normalizedOwnerUid),
                  isReady: true,
                  isAuthoritative: true,
                ),
              );
            }
          },
          onError: controller.addError,
        );
        controller.add(
          EventInboxEventIdsLoadState(
            ownerUid: normalizedOwnerUid,
            eventIds: rememberedInboxEventIdsForOwner(normalizedOwnerUid),
            isReady: true,
            isAuthoritative: true,
          ),
        );
      },
      onCancel: () async {
        await ownerChangesSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  static void resetRememberedInboxEventIdsForTesting() {
    _rememberedInboxEventIdsByOwner.clear();
    _rememberedInboxOwnerChanges.add(null);
  }

  static Stream<EventChatMessagesLoadState> watchMessagesState({
    required String eventId,
    required String ownerUid,
    EventChatMessagesStream? messagesStream,
    EventChatMessagesStateStream? messagesStateStream,
    int limit = defaultMessageLimit,
  }) {
    final chatRef = chatReferenceForEventId(eventId);
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return const Stream<EventChatMessagesLoadState>.empty();
    }
    final injectedStateStream = messagesStateStream;
    if (injectedStateStream != null) {
      return injectedStateStream(chatRef, normalizedOwnerUid).map((state) {
        if (state.ownerUid != normalizedOwnerUid) {
          throw StateError('Event chat messages belong to another owner');
        }
        return state;
      });
    }
    final injectedStream = messagesStream;
    if (injectedStream != null) {
      return injectedStream(chatRef).map(
        (messages) => resolveEventChatMessagesSnapshot(
          ownerUid: normalizedOwnerUid,
          messages: messages,
          isFromCache: false,
          hasPendingWrites: false,
        ),
      );
    }

    final query = buildMessagesQuery(
      EventChatMessagesRecord.collection(chatRef),
    ).limit(_normalizeMessageLimit(limit));
    return query.snapshots(includeMetadataChanges: true).map((snapshot) {
      return resolveEventChatMessagesSnapshot(
        ownerUid: normalizedOwnerUid,
        messages: snapshot.docs.map(EventChatMessagesRecord.fromSnapshot),
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      );
    }).where((state) => state.canResolveEmpty);
  }

  static Stream<EventChatMessagesLoadState> watchLatestMessageState({
    required String eventId,
    required String ownerUid,
    EventChatMessagesStream? messagesStream,
    EventChatMessagesStateStream? messagesStateStream,
  }) {
    final chatRef = chatReferenceForEventId(eventId);
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return const Stream<EventChatMessagesLoadState>.empty();
    }
    final injectedStateStream = messagesStateStream;
    if (injectedStateStream != null) {
      return injectedStateStream(chatRef, normalizedOwnerUid).map((state) {
        if (state.ownerUid != normalizedOwnerUid) {
          throw StateError('Event chat preview belongs to another owner');
        }
        return state;
      });
    }
    final injectedStream = messagesStream;
    if (injectedStream != null) {
      return injectedStream(chatRef).map(
        (messages) => resolveEventChatMessagesSnapshot(
          ownerUid: normalizedOwnerUid,
          messages: messages,
          isFromCache: false,
          hasPendingWrites: false,
        ),
      );
    }

    final query = buildLatestMessageQuery(
      EventChatMessagesRecord.collection(chatRef),
    ).limit(1);
    return query.snapshots(includeMetadataChanges: true).map((snapshot) {
      return resolveEventChatMessagesSnapshot(
        ownerUid: normalizedOwnerUid,
        messages: snapshot.docs.map(EventChatMessagesRecord.fromSnapshot),
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      );
    }).where((state) => state.canResolveEmpty);
  }

  static Future<FFFirestorePage<EventChatMessagesRecord>> loadMessagesPage({
    required String eventId,
    int pageSize = defaultMessageLimit,
    DocumentSnapshot? nextPageMarker,
    EventChatMessagesPageLoader? pageLoader,
  }) {
    final chatRef = chatReferenceForEventId(eventId);
    final loader = pageLoader ?? _loadEventChatMessagesPage;

    return loader(
      EventChatMessagesRecord.collection(chatRef),
      EventChatMessagesRecord.fromSnapshot,
      queryBuilder: buildMessagesQuery,
      nextPageMarker: nextPageMarker,
      pageSize: _normalizeMessageLimit(pageSize),
      isStream: false,
    );
  }

  static int _normalizeMessageLimit(int limit) {
    if (limit < 1) {
      return defaultMessageLimit;
    }
    if (limit > maxMessageLimit) {
      return maxMessageLimit;
    }
    return limit;
  }
}

Stream<EventInboxEventIdsLoadState> _watchInboxEventIdsFromHistory({
  required String ownerUid,
}) async* {
  final history = await EventHistoryRepository.loadEventHistory(
    limit: eventHistoryMaxLimit,
  );
  yield EventInboxEventIdsLoadState(
    ownerUid: ownerUid,
    eventIds: _normalizeInboxEventIds(
      history.items
          .where(_historyItemCanHaveInboxChat)
          .map((item) => item.eventId),
    ),
    isReady: true,
    isAuthoritative: true,
  );
}

bool _historyItemCanHaveInboxChat(EventHistoryItem item) =>
    item.status == 'canceled' || item.participantStatus == 'active';

Stream<EventChatsRecord?> _watchAccessibleChatByEventId({
  required String eventId,
  required String ownerUid,
  EventChatAccessStateStream? accessStateStream,
  EventChatOwnerMutationGuard? canMutateOwner,
  void Function(String eventId)? onInaccessibleEventId,
}) {
  late final StreamController<EventChatsRecord?> controller;
  StreamSubscription<EventChatAccessLoadState>? subscription;
  var inaccessibleWasMarked = false;

  void markInaccessible() {
    if (inaccessibleWasMarked) {
      return;
    }
    inaccessibleWasMarked = true;
    if (!(canMutateOwner?.call(ownerUid) ?? true)) {
      if (!controller.isClosed) {
        controller.add(null);
      }
      return;
    }
    EventGroupChatRepository.forgetInboxEventId(
      eventId,
      ownerUid: ownerUid,
    );
    onInaccessibleEventId?.call(eventId);
    if (!controller.isClosed) {
      controller.add(null);
    }
  }

  controller = StreamController<EventChatsRecord?>(
    onListen: () {
      subscription = EventGroupChatRepository.watchChatAccessState(
        eventId: eventId,
        ownerUid: ownerUid,
        accessStateStream: accessStateStream,
      ).listen(
        (state) {
          if (!state.isAuthoritative) {
            return;
          }
          final chat = state.chat;
          if (state.accessGranted && chat != null) {
            if (!controller.isClosed) {
              controller.add(chat);
            }
            return;
          }
          markInaccessible();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (error is FirebaseException && error.code == 'permission-denied') {
            markInaccessible();
            return;
          }
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
        onDone: () {
          if (!controller.isClosed) {
            unawaited(controller.close());
          }
        },
      );
    },
    onCancel: () => subscription?.cancel(),
  );
  return controller.stream;
}

Stream<EventInboxEventIdsLoadState> _combineInboxEventIdSources({
  required String ownerUid,
  required List<Stream<EventInboxEventIdsLoadState>> sources,
}) {
  final normalizedSources = sources.toList(growable: false);
  if (normalizedSources.isEmpty) {
    return Stream.value(
      EventInboxEventIdsLoadState(
        ownerUid: ownerUid,
        eventIds: <String>[],
        isReady: true,
        isAuthoritative: true,
      ),
    );
  }

  late final StreamController<EventInboxEventIdsLoadState> controller;
  final subscriptions = <StreamSubscription<EventInboxEventIdsLoadState>>[];
  final latestStates =
      List<EventInboxEventIdsLoadState?>.filled(normalizedSources.length, null);
  var completedSources = 0;

  void emitIfReadyOrNonEmpty() {
    if (controller.isClosed) {
      return;
    }
    final eventIds = EventGroupChatRepository.boundedInboxEventIds(
      latestStates
          .whereType<EventInboxEventIdsLoadState>()
          .expand((state) => state.eventIds),
    );
    final isReady = latestStates.every((state) => state?.isReady ?? false);
    final isAuthoritative = isReady &&
        latestStates.every((state) => state?.isAuthoritative ?? false);
    if (eventIds.isEmpty && !isAuthoritative) {
      return;
    }
    controller.add(
      EventInboxEventIdsLoadState(
        ownerUid: ownerUid,
        eventIds: eventIds,
        isReady: isReady,
        isAuthoritative: isAuthoritative,
      ),
    );
  }

  controller = StreamController<EventInboxEventIdsLoadState>(
    onListen: () {
      for (var index = 0; index < normalizedSources.length; index += 1) {
        final sourceIndex = index;
        subscriptions.add(
          normalizedSources[sourceIndex].listen(
            (incomingState) {
              if (incomingState.ownerUid.isNotEmpty &&
                  incomingState.ownerUid != ownerUid) {
                controller.addError(
                  StateError('Event inbox IDs belong to another owner'),
                );
                return;
              }
              latestStates[sourceIndex] = _mergeInboxEventIdsLoadState(
                latestStates[sourceIndex],
                incomingState,
              );
              emitIfReadyOrNonEmpty();
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!controller.isClosed) {
                controller.addError(error, stackTrace);
              }
            },
            onDone: () {
              completedSources += 1;
              if (completedSources == normalizedSources.length &&
                  !controller.isClosed) {
                unawaited(controller.close());
              }
            },
          ),
        );
      }
    },
    onCancel: () async {
      await Future.wait(
        subscriptions.map((subscription) => subscription.cancel()),
      );
    },
  );

  return controller.stream;
}

Stream<EventChatInboxLoadState> _watchInboxChatsByEventIds({
  required String ownerUid,
  required Stream<EventInboxEventIdsLoadState> eventIdsStream,
  required EventChatByEventIdStream chatByEventIdStream,
}) {
  late final StreamController<EventChatInboxLoadState> controller;
  late final StreamSubscription<EventInboxEventIdsLoadState>
      eventIdsSubscription;
  final chatSourcesByEventId = <String, _InboxEventChatSourceState>{};
  var currentEventIds = const <String>[];
  var eventIdsAreAuthoritative = false;
  var eventIdsDone = false;

  void emitIfReadyOrNonEmpty() {
    if (controller.isClosed) {
      return;
    }
    final chats = _sortedVisibleInboxChats(
      currentEventIds
          .map((eventId) => chatSourcesByEventId[eventId]?.chat)
          .whereType<EventChatsRecord>(),
    );
    final chatSourcesAreReady = currentEventIds.every(
      (eventId) => chatSourcesByEventId[eventId]?.hasValue ?? false,
    );
    final isAuthoritative = eventIdsAreAuthoritative && chatSourcesAreReady;
    if (chats.isEmpty && !isAuthoritative) {
      return;
    }
    controller.add(
      EventChatInboxLoadState(
        ownerUid: ownerUid,
        chats: chats,
        isAuthoritative: isAuthoritative,
      ),
    );
  }

  void closeIfDone() {
    final chatSourcesDone = chatSourcesByEventId.values.every(
      (source) => source.isDone,
    );
    if (eventIdsDone && chatSourcesDone && !controller.isClosed) {
      unawaited(controller.close());
    }
  }

  void syncEventIds(EventInboxEventIdsLoadState snapshot) {
    if (snapshot.ownerUid.isNotEmpty && snapshot.ownerUid != ownerUid) {
      controller.addError(
        StateError('Event inbox IDs belong to another owner'),
      );
      return;
    }
    final eventIds = snapshot.eventIds;
    final eventIdSet = eventIds.toSet();
    final removedEventIds = chatSourcesByEventId.keys
        .where((eventId) => !eventIdSet.contains(eventId))
        .toList(growable: false);

    for (final eventId in removedEventIds) {
      final source = chatSourcesByEventId.remove(eventId);
      final subscription = source?.subscription;
      if (subscription != null) {
        unawaited(subscription.cancel());
      }
    }

    currentEventIds = eventIds;
    eventIdsAreAuthoritative = snapshot.isAuthoritative;

    for (final eventId in eventIds) {
      if (chatSourcesByEventId.containsKey(eventId)) {
        continue;
      }

      final source = _InboxEventChatSourceState();
      chatSourcesByEventId[eventId] = source;
      source.subscription = chatByEventIdStream(eventId).listen(
        (chat) {
          if (chatSourcesByEventId[eventId] != source) {
            return;
          }
          source
            ..hasValue = true
            ..chat = chat;
          emitIfReadyOrNonEmpty();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (chatSourcesByEventId[eventId] != source) {
            return;
          }
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
        onDone: () {
          if (chatSourcesByEventId[eventId] != source) {
            return;
          }
          source.isDone = true;
          closeIfDone();
        },
      );
    }

    emitIfReadyOrNonEmpty();
  }

  controller = StreamController<EventChatInboxLoadState>(
    onListen: () {
      eventIdsSubscription = eventIdsStream.listen(
        syncEventIds,
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
        onDone: () {
          eventIdsDone = true;
          closeIfDone();
        },
      );
    },
    onCancel: () async {
      await eventIdsSubscription.cancel();
      await Future.wait(
        chatSourcesByEventId.values
            .map((source) => source.subscription)
            .whereType<StreamSubscription<EventChatsRecord?>>()
            .map((subscription) => subscription.cancel()),
      );
      chatSourcesByEventId.clear();
    },
  );

  return controller.stream;
}

Stream<EventChatInboxLoadState> _combineInboxChatSources({
  required String ownerUid,
  required Stream<EventChatInboxLoadState> readAccessChatsStream,
  required Stream<EventChatInboxLoadState> eventHistoryChatsStream,
}) {
  late final StreamController<EventChatInboxLoadState> controller;
  late final StreamSubscription<EventChatInboxLoadState> readAccessSubscription;
  late final StreamSubscription<EventChatInboxLoadState>
      eventHistorySubscription;
  var hasReadAccessChats = false;
  var hasEventHistoryChats = false;
  var readAccessDone = false;
  var eventHistoryDone = false;
  EventChatInboxLoadState? latestReadAccessState;
  EventChatInboxLoadState? latestEventHistoryState;

  void emitIfReadyOrNonEmpty() {
    if (controller.isClosed) {
      return;
    }
    final chats = _sortedVisibleInboxChats([
      ...?latestReadAccessState?.chats,
      ...?latestEventHistoryState?.chats,
    ]);
    final isAuthoritative = hasReadAccessChats &&
        hasEventHistoryChats &&
        (latestReadAccessState?.isAuthoritative ?? false) &&
        (latestEventHistoryState?.isAuthoritative ?? false);
    if (chats.isEmpty && !isAuthoritative) {
      return;
    }
    controller.add(
      EventChatInboxLoadState(
        ownerUid: ownerUid,
        chats: chats,
        isAuthoritative: isAuthoritative,
      ),
    );
  }

  void closeIfDone() {
    if (readAccessDone && eventHistoryDone && !controller.isClosed) {
      unawaited(controller.close());
    }
  }

  controller = StreamController<EventChatInboxLoadState>(
    onListen: () {
      readAccessSubscription = readAccessChatsStream.listen(
        (state) {
          if (state.ownerUid != ownerUid) {
            controller.addError(
              StateError('Event inbox chats belong to another owner'),
            );
            return;
          }
          hasReadAccessChats = true;
          latestReadAccessState = _mergeInboxChatsLoadState(
            latestReadAccessState,
            state,
          );
          emitIfReadyOrNonEmpty();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
        onDone: () {
          readAccessDone = true;
          closeIfDone();
        },
      );
      eventHistorySubscription = eventHistoryChatsStream.listen(
        (state) {
          if (state.ownerUid != ownerUid) {
            controller.addError(
              StateError('Event inbox chats belong to another owner'),
            );
            return;
          }
          hasEventHistoryChats = true;
          latestEventHistoryState = _mergeInboxChatsLoadState(
            latestEventHistoryState,
            state,
          );
          emitIfReadyOrNonEmpty();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
        onDone: () {
          eventHistoryDone = true;
          closeIfDone();
        },
      );
    },
    onCancel: () async {
      await readAccessSubscription.cancel();
      await eventHistorySubscription.cancel();
    },
  );

  return controller.stream;
}

final class _InboxEventChatSourceState {
  StreamSubscription<EventChatsRecord?>? subscription;
  EventChatsRecord? chat;
  bool hasValue = false;
  bool isDone = false;
}

EventInboxEventIdsLoadState _mergeInboxEventIdsLoadState(
  EventInboxEventIdsLoadState? previousState,
  EventInboxEventIdsLoadState incomingState,
) {
  if (previousState == null || incomingState.isAuthoritative) {
    return incomingState;
  }
  if (previousState.ownerUid.isNotEmpty &&
      incomingState.ownerUid.isNotEmpty &&
      previousState.ownerUid != incomingState.ownerUid) {
    throw StateError('Event inbox IDs belong to another owner');
  }

  return EventInboxEventIdsLoadState(
    ownerUid: incomingState.ownerUid.isNotEmpty
        ? incomingState.ownerUid
        : previousState.ownerUid,
    eventIds: EventGroupChatRepository.boundedInboxEventIds([
      ...previousState.eventIds,
      ...incomingState.eventIds,
    ]),
    isReady: incomingState.isReady,
    isAuthoritative: false,
  );
}

EventChatInboxLoadState _mergeInboxChatsLoadState(
  EventChatInboxLoadState? previousState,
  EventChatInboxLoadState incomingState,
) {
  if (previousState == null || incomingState.isAuthoritative) {
    return incomingState;
  }
  if (previousState.ownerUid != incomingState.ownerUid) {
    throw StateError('Event inbox chats belong to another owner');
  }

  final incomingByEventId = <String, EventChatsRecord>{
    for (final chat in incomingState.chats)
      EventGroupChatRepository.eventIdForChat(chat): chat,
  };
  final merged = <EventChatsRecord>[];
  final seenEventIds = <String>{};
  for (final previousChat in previousState.chats) {
    final eventId = EventGroupChatRepository.eventIdForChat(previousChat);
    if (eventId.isEmpty || !seenEventIds.add(eventId)) {
      continue;
    }
    merged.add(incomingByEventId.remove(eventId) ?? previousChat);
  }
  for (final entry in incomingByEventId.entries) {
    if (entry.key.isNotEmpty && seenEventIds.add(entry.key)) {
      merged.add(entry.value);
    }
  }

  return EventChatInboxLoadState(
    ownerUid: incomingState.ownerUid,
    chats: merged,
    isAuthoritative: false,
  );
}

List<String> _normalizeInboxEventIds(Iterable<String> eventIds) {
  final normalizedEventIds = <String>[];
  final seen = <String>{};

  for (final eventId in eventIds) {
    late final String normalizedEventId;
    try {
      normalizedEventId = normalizeEventDetailId(eventId);
    } on ArgumentError {
      continue;
    }
    if (!seen.add(normalizedEventId)) {
      normalizedEventIds.remove(normalizedEventId);
    }
    normalizedEventIds.add(normalizedEventId);
  }

  return List<String>.unmodifiable(normalizedEventIds);
}

List<EventChatsRecord> _sortedVisibleInboxChats(
  Iterable<EventChatsRecord> chats,
) {
  final chatsByEventId = <String, EventChatsRecord>{};

  for (final chat in chats) {
    final eventId = EventGroupChatRepository.eventIdForChat(chat);
    if (eventId.isEmpty) {
      continue;
    }

    final currentChat = chatsByEventId[eventId];
    if (currentChat == null ||
        EventGroupChatRepository.compareChatsForInbox(chat, currentChat) < 0) {
      chatsByEventId[eventId] = chat;
    }
  }

  final visibleChats = chatsByEventId.values.toList();
  visibleChats.sort(EventGroupChatRepository.compareChatsForInbox);
  return List<EventChatsRecord>.unmodifiable(visibleChats);
}

int _compareDateTimesDescending(DateTime? a, DateTime? b) {
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

Future<FFFirestorePage<EventChatMessagesRecord>> _loadEventChatMessagesPage(
  Query collection,
  RecordBuilder<EventChatMessagesRecord> recordBuilder, {
  Query Function(Query)? queryBuilder,
  DocumentSnapshot? nextPageMarker,
  required int pageSize,
  required bool isStream,
}) =>
    queryCollectionPage<EventChatMessagesRecord>(
      collection,
      recordBuilder,
      queryBuilder: queryBuilder,
      nextPageMarker: nextPageMarker,
      pageSize: pageSize,
      isStream: isStream,
    );
