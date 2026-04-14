import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/conversations_record.dart';
import '/backend/schema/messages_record.dart';
import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/video_sessions_record.dart';

const String kConversationMessageTypeText = 'text';

String canonicalConversationPairId(String uidA, String uidB) {
  if (uidA == uidB) {
    throw ArgumentError.value(
      uidA,
      'uidB',
      'A conversation pair requires two distinct participant UIDs.',
    );
  }

  final sorted = [uidA, uidB]..sort();
  return '${sorted[0]}_${sorted[1]}';
}

DocumentReference conversationReferenceForPairId(String pairId) =>
    FirebaseFirestore.instance.collection('conversations').doc(pairId);

Map<String, dynamic> buildConversationReadMarkerUpdateData(
  String currentUserUid,
  DateTime readAt,
) =>
    mapToFirestore(
      <String, dynamic>{
        'lastReadAtByUserId.$currentUserUid': readAt,
      },
    );

DateTime? conversationSortAt(ConversationsRecord? conversation) =>
    conversation?.lastMessageAt ?? conversation?.unlockedAt;

String conversationSortId(ConversationsRecord? conversation) =>
    conversation?.lastMessageId ?? conversation?.pairId ?? '';

DateTime? conversationReadAtForUser(
  ConversationsRecord? conversation,
  String currentUserUid,
) =>
    conversation?.lastReadAtByUserId[currentUserUid];

bool conversationIsUnreadForUser(
  ConversationsRecord? conversation,
  String currentUserUid,
) {
  if (conversation == null || !conversation.hasLastMessageAt()) {
    return false;
  }

  if (conversation.lastMessageSenderId == currentUserUid) {
    return false;
  }

  final readAt = conversationReadAtForUser(conversation, currentUserUid);
  if (readAt == null) {
    return true;
  }

  return readAt.isBefore(conversation.lastMessageAt!);
}

int compareConversationsForInbox(
  ConversationsRecord a,
  ConversationsRecord b,
) {
  final sortAtCmp = _compareDateTimesDescending(
    conversationSortAt(a),
    conversationSortAt(b),
  );
  if (sortAtCmp != 0) {
    return sortAtCmp;
  }

  final sortIdCmp = _compareStringsDescending(
    conversationSortId(a),
    conversationSortId(b),
  );
  if (sortIdCmp != 0) {
    return sortIdCmp;
  }

  return _compareStringsDescending(a.pairId, b.pairId);
}

int compareMessagesForThread(MessagesRecord a, MessagesRecord b) {
  final createdAtCmp = _compareDateTimesAscending(a.createdAt, b.createdAt);
  if (createdAtCmp != 0) {
    return createdAtCmp;
  }

  return _compareStringsAscending(a.reference.id, b.reference.id);
}

DateTime? videoSessionHubRecencyAt(VideoSessionsRecord session) {
  final sessionMetadata = session.snapshotData['sessionMetadata'];
  if (sessionMetadata is Map) {
    final connectedAt = sessionMetadata['callConnectedAt'] ??
        sessionMetadata['callConnectedAtTimestamp'];
    if (connectedAt is DateTime) {
      return connectedAt;
    }
  }

  final topLevelConnectedAt = session.snapshotData['callConnectedAt'];
  if (topLevelConnectedAt is DateTime) {
    return topLevelConnectedAt;
  }

  return session.startedAt ?? session.createdAt;
}

int compareVideoSessionsForHub(
  VideoSessionsRecord a,
  VideoSessionsRecord b,
) {
  final recencyCmp = _compareDateTimesDescending(
    videoSessionHubRecencyAt(a),
    videoSessionHubRecencyAt(b),
  );
  if (recencyCmp != 0) {
    return recencyCmp;
  }

  final endedAtCmp = _compareDateTimesDescending(a.endedAt, b.endedAt);
  if (endedAtCmp != 0) {
    return endedAtCmp;
  }

  return _compareStringsDescending(a.reference.path, b.reference.path);
}

int _compareDateTimesDescending(DateTime? left, DateTime? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return right.compareTo(left);
}

int _compareDateTimesAscending(DateTime? left, DateTime? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return -1;
  }
  if (right == null) {
    return 1;
  }
  return left.compareTo(right);
}

int _compareStringsDescending(String left, String right) =>
    right.compareTo(left);

int _compareStringsAscending(String left, String right) =>
    left.compareTo(right);
