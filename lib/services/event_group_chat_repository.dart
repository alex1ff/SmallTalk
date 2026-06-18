import '/backend/backend.dart';
import '/services/event_detail_repository.dart';

typedef EventChatMessagesStream = Stream<List<EventChatMessagesRecord>>
    Function(DocumentReference chatRef);
typedef EventChatMetadataStream = Stream<EventChatsRecord?> Function(
  DocumentReference chatRef,
);

class EventGroupChatRepository {
  const EventGroupChatRepository._();

  static const int defaultMessageLimit = 50;
  static const int maxMessageLimit = 100;

  static DocumentReference chatReferenceForEventId(String eventId) =>
      EventChatsRecord.collection.doc(normalizeEventDetailId(eventId));

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
      queryBuilder: (messages) => messages
          .orderBy('createdAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true),
      limit: _normalizeMessageLimit(limit),
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
