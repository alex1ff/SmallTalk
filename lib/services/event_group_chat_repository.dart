import '/backend/backend.dart';
import '/services/event_detail_repository.dart';

typedef EventChatMessagesStream = Stream<List<EventChatMessagesRecord>>
    Function(DocumentReference chatRef);
typedef EventChatMetadataStream = Stream<EventChatsRecord?> Function(
  DocumentReference chatRef,
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

  static DocumentReference chatReferenceForEventId(String eventId) =>
      EventChatsRecord.collection.doc(normalizeEventDetailId(eventId));

  static Query buildMessagesQuery(Query messages) => messages
      .orderBy('createdAt', descending: false)
      .orderBy(FieldPath.documentId, descending: false);

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
