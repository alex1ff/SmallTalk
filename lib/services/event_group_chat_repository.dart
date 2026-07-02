import 'dart:async';

import '/backend/backend.dart';
import '/services/event_detail_repository.dart';
import '/services/event_history_repository.dart';

typedef EventChatMessagesStream = Stream<List<EventChatMessagesRecord>>
    Function(DocumentReference chatRef);
typedef EventChatMetadataStream = Stream<EventChatsRecord?> Function(
  DocumentReference chatRef,
);
typedef EventChatsStream = Stream<List<EventChatsRecord>> Function();
typedef EventInboxEventIdsStream = Stream<List<String>> Function();
typedef EventChatByEventIdStream = Stream<EventChatsRecord?> Function(
  String eventId,
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

class EventGroupChatRepository {
  const EventGroupChatRepository._();

  static const int defaultMessageLimit = 50;
  static const int maxMessageLimit = 100;
  static final Set<String> _rememberedInboxEventIds = <String>{};
  static final StreamController<List<String>> _rememberedInboxEventIdsStream =
      StreamController<List<String>>.broadcast();

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
    EventInboxEventIdsStream? eventIdsStream,
    EventInboxEventIdsStream? rememberedEventIdsStream,
    EventChatByEventIdStream? chatByEventIdStream,
  }) {
    final normalizedUid = currentUid.trim();
    if (normalizedUid.isEmpty) {
      return Stream.value(const <EventChatsRecord>[]);
    }

    final injectedStream = chatsStream;
    if (injectedStream != null &&
        eventIdsStream == null &&
        rememberedEventIdsStream == null &&
        chatByEventIdStream == null) {
      return injectedStream().map(_sortedVisibleInboxChats);
    }

    final eventIdSources = <Stream<List<String>>>[
      eventIdsStream?.call() ?? _watchInboxEventIdsFromHistory(),
      watchRememberedInboxEventIds(),
    ];
    if (rememberedEventIdsStream != null) {
      eventIdSources.add(rememberedEventIdsStream());
    }
    final eventIds = _combineInboxEventIdSources(eventIdSources);

    final eventHistoryChatsStream = _watchInboxChatsByEventIds(
      eventIdsStream: eventIds,
      chatByEventIdStream: chatByEventIdStream ?? _watchChatByEventId,
    );
    if (injectedStream == null) {
      return eventHistoryChatsStream;
    }

    return _combineInboxChatSources(
      injectedStream(),
      eventHistoryChatsStream,
    );
  }

  static Stream<EventChatsRecord?> watchChatAccess({
    required String eventId,
    EventChatMetadataStream? chatStream,
  }) {
    final chatRef = chatReferenceForEventId(eventId);
    final injectedStream = chatStream;
    if (injectedStream != null) {
      return injectedStream(chatRef);
    }

    return chatRef.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return EventChatsRecord.fromSnapshot(snapshot);
    });
  }

  static List<String> get rememberedInboxEventIds =>
      List<String>.unmodifiable(_rememberedInboxEventIds);

  static void rememberInboxEventId(String eventId) {
    late final String normalizedEventId;
    try {
      normalizedEventId = normalizeEventDetailId(eventId);
    } on ArgumentError {
      return;
    }

    if (_rememberedInboxEventIds.add(normalizedEventId)) {
      _rememberedInboxEventIdsStream.add(rememberedInboxEventIds);
    }
  }

  static Stream<List<String>> watchRememberedInboxEventIds() async* {
    yield rememberedInboxEventIds;
    yield* _rememberedInboxEventIdsStream.stream;
  }

  static void resetRememberedInboxEventIdsForTesting() {
    _rememberedInboxEventIds.clear();
    _rememberedInboxEventIdsStream.add(rememberedInboxEventIds);
  }

  static Stream<List<EventChatMessagesRecord>> watchMessages({
    required String eventId,
    EventChatMessagesStream? messagesStream,
    int limit = defaultMessageLimit,
  }) {
    final chatRef = chatReferenceForEventId(eventId);
    final injectedStream = messagesStream;
    if (injectedStream != null) {
      return injectedStream(chatRef);
    }

    return queryEventChatMessagesRecord(
      parent: chatRef,
      queryBuilder: buildMessagesQuery,
      limit: _normalizeMessageLimit(limit),
    );
  }

  static Stream<List<EventChatMessagesRecord>> watchLatestMessage({
    required String eventId,
    EventChatMessagesStream? messagesStream,
  }) {
    final chatRef = chatReferenceForEventId(eventId);
    final injectedStream = messagesStream;
    if (injectedStream != null) {
      return injectedStream(chatRef);
    }

    return queryEventChatMessagesRecord(
      parent: chatRef,
      queryBuilder: buildLatestMessageQuery,
      limit: 1,
    );
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

Stream<List<String>> _watchInboxEventIdsFromHistory() async* {
  final history = await EventHistoryRepository.loadEventHistory(
    limit: eventHistoryMaxLimit,
  );
  yield _normalizeInboxEventIds(
    history.items
        .where(_historyItemCanHaveInboxChat)
        .map((item) => item.eventId),
  );
}

bool _historyItemCanHaveInboxChat(EventHistoryItem item) =>
    item.status == 'canceled' || item.participantStatus == 'active';

Stream<EventChatsRecord?> _watchChatByEventId(String eventId) =>
    EventGroupChatRepository.watchChatAccess(eventId: eventId);

Stream<List<String>> _combineInboxEventIdSources(
  List<Stream<List<String>>> sources,
) {
  final normalizedSources = sources.toList(growable: false);
  if (normalizedSources.isEmpty) {
    return Stream.value(const <String>[]);
  }

  late final StreamController<List<String>> controller;
  final subscriptions = <StreamSubscription<List<String>>>[];
  final latestValues = List<List<String>>.filled(
    normalizedSources.length,
    const <String>[],
  );
  var completedSources = 0;

  void emit() {
    if (controller.isClosed) {
      return;
    }
    controller.add(
      _normalizeInboxEventIds(
        latestValues.expand((eventIds) => eventIds),
      ),
    );
  }

  controller = StreamController<List<String>>(
    onListen: () {
      for (var index = 0; index < normalizedSources.length; index += 1) {
        final sourceIndex = index;
        subscriptions.add(
          normalizedSources[sourceIndex].listen(
            (eventIds) {
              latestValues[sourceIndex] = eventIds;
              emit();
            },
            onError: (_, __) {
              latestValues[sourceIndex] = const <String>[];
              emit();
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

Stream<List<EventChatsRecord>> _watchInboxChatsByEventIds({
  required Stream<List<String>> eventIdsStream,
  required EventChatByEventIdStream chatByEventIdStream,
}) {
  late final StreamController<List<EventChatsRecord>> controller;
  late final StreamSubscription<List<String>> eventIdsSubscription;
  final chatSubscriptions = <String, StreamSubscription<EventChatsRecord?>>{};
  final chatsByEventId = <String, EventChatsRecord>{};
  var eventIdsDone = false;

  void emit() {
    if (!controller.isClosed) {
      controller.add(_sortedVisibleInboxChats(chatsByEventId.values));
    }
  }

  void closeIfDone() {
    if (eventIdsDone && chatSubscriptions.isEmpty && !controller.isClosed) {
      unawaited(controller.close());
    }
  }

  void syncEventIds(List<String> rawEventIds) {
    final eventIds = _normalizeInboxEventIds(rawEventIds);
    final eventIdSet = eventIds.toSet();
    final removedEventIds = chatSubscriptions.keys
        .where((eventId) => !eventIdSet.contains(eventId))
        .toList(growable: false);

    for (final eventId in removedEventIds) {
      final subscription = chatSubscriptions.remove(eventId);
      chatsByEventId.remove(eventId);
      if (subscription != null) {
        unawaited(subscription.cancel());
      }
    }

    for (final eventId in eventIds) {
      if (chatSubscriptions.containsKey(eventId)) {
        continue;
      }

      chatSubscriptions[eventId] = chatByEventIdStream(eventId).listen(
        (chat) {
          if (chat == null) {
            chatsByEventId.remove(eventId);
          } else {
            chatsByEventId[eventId] = chat;
          }
          emit();
        },
        onError: (_, __) {
          chatsByEventId.remove(eventId);
          emit();
        },
        onDone: () {
          chatSubscriptions.remove(eventId);
          closeIfDone();
        },
      );
    }

    emit();
  }

  controller = StreamController<List<EventChatsRecord>>(
    onListen: () {
      eventIdsSubscription = eventIdsStream.listen(
        syncEventIds,
        onError: (_, __) => syncEventIds(const <String>[]),
        onDone: () {
          eventIdsDone = true;
          closeIfDone();
        },
      );
    },
    onCancel: () async {
      await eventIdsSubscription.cancel();
      await Future.wait(
        chatSubscriptions.values.map((subscription) => subscription.cancel()),
      );
      chatSubscriptions.clear();
    },
  );

  return controller.stream;
}

Stream<List<EventChatsRecord>> _combineInboxChatSources(
  Stream<List<EventChatsRecord>> readAccessChatsStream,
  Stream<List<EventChatsRecord>> eventHistoryChatsStream,
) {
  late final StreamController<List<EventChatsRecord>> controller;
  late final StreamSubscription<List<EventChatsRecord>> readAccessSubscription;
  late final StreamSubscription<List<EventChatsRecord>>
      eventHistorySubscription;
  var hasReadAccessChats = false;
  var hasEventHistoryChats = false;
  var latestReadAccessChats = const <EventChatsRecord>[];
  var latestEventHistoryChats = const <EventChatsRecord>[];

  void emitIfReady() {
    if (!hasReadAccessChats || !hasEventHistoryChats || controller.isClosed) {
      return;
    }
    controller.add(
      _sortedVisibleInboxChats([
        ...latestReadAccessChats,
        ...latestEventHistoryChats,
      ]),
    );
  }

  controller = StreamController<List<EventChatsRecord>>(
    onListen: () {
      readAccessSubscription = readAccessChatsStream.listen(
        (chats) {
          hasReadAccessChats = true;
          latestReadAccessChats = chats;
          emitIfReady();
        },
        onError: controller.addError,
      );
      eventHistorySubscription = eventHistoryChatsStream.listen(
        (chats) {
          hasEventHistoryChats = true;
          latestEventHistoryChats = chats;
          emitIfReady();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await readAccessSubscription.cancel();
      await eventHistorySubscription.cancel();
    },
  );

  return controller.stream;
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
    if (seen.add(normalizedEventId)) {
      normalizedEventIds.add(normalizedEventId);
    }
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
