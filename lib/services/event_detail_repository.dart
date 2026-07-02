import 'dart:convert';

import '/backend/backend.dart';

typedef EventDetailSnapshotStream = Stream<DocumentSnapshot> Function(
  DocumentReference eventRef,
);
typedef EventParticipantSnapshotStream = Stream<DocumentSnapshot> Function(
  DocumentReference participantRef,
);
typedef EventActiveParticipantsStream = Stream<List<EventParticipantsRecord>>
    Function(
  DocumentReference eventRef,
);

class EventDetailRepository {
  const EventDetailRepository._();

  static DocumentReference eventReferenceForId(String eventId) =>
      EventsRecord.collection.doc(normalizeEventDetailId(eventId));

  static Stream<EventsRecord?> watchEventDetail({
    required String eventId,
    EventDetailSnapshotStream? snapshotStream,
  }) {
    final eventRef = eventReferenceForId(eventId);
    final loader = snapshotStream ?? _watchEventSnapshot;

    return loader(eventRef).map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return EventsRecord.fromSnapshot(snapshot);
    });
  }

  static DocumentReference currentUserParticipantReference({
    required String eventId,
    required String userId,
  }) {
    final eventRef = eventReferenceForId(eventId);
    return EventParticipantsRecord.createDoc(
      eventRef,
      id: normalizeEventDetailId(userId),
    );
  }

  static Stream<EventParticipantsRecord?> watchCurrentUserParticipant({
    required String eventId,
    required String userId,
    EventParticipantSnapshotStream? snapshotStream,
  }) {
    final participantRef = currentUserParticipantReference(
      eventId: eventId,
      userId: userId,
    );
    final loader = snapshotStream ?? _watchParticipantSnapshot;

    return loader(participantRef).map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return EventParticipantsRecord.fromSnapshot(snapshot);
    });
  }

  static Stream<List<EventParticipantsRecord>> watchActiveParticipants({
    required String eventId,
    EventActiveParticipantsStream? participantsStream,
  }) {
    final eventRef = eventReferenceForId(eventId);
    final loader = participantsStream ?? _watchActiveParticipantRecords;

    return loader(eventRef).map(_normalizedActiveParticipants);
  }
}

String normalizeEventDetailId(String eventId) {
  final normalizedEventId = eventId.trim();
  if (normalizedEventId.isEmpty) {
    throw ArgumentError.value(
      eventId,
      'eventId',
      'Expected a non-empty event id.',
    );
  }
  if (normalizedEventId == '.' || normalizedEventId == '..') {
    throw ArgumentError.value(
      eventId,
      'eventId',
      'Expected a Firestore document id.',
    );
  }
  if (normalizedEventId.contains('/')) {
    throw ArgumentError.value(
      eventId,
      'eventId',
      'Expected an event id without path separators.',
    );
  }
  if (RegExp(r'^__.*__$').hasMatch(normalizedEventId)) {
    throw ArgumentError.value(
      eventId,
      'eventId',
      'Expected a non-reserved Firestore document id.',
    );
  }
  if (utf8.encode(normalizedEventId).length > 1500) {
    throw ArgumentError.value(
      eventId,
      'eventId',
      'Expected an event id no longer than 1500 UTF-8 bytes.',
    );
  }

  return normalizedEventId;
}

Stream<DocumentSnapshot> _watchEventSnapshot(DocumentReference eventRef) =>
    eventRef.snapshots();

Stream<DocumentSnapshot> _watchParticipantSnapshot(
  DocumentReference participantRef,
) =>
    participantRef.snapshots();

Stream<List<EventParticipantsRecord>> _watchActiveParticipantRecords(
  DocumentReference eventRef,
) =>
    queryEventParticipantsRecord(
      parent: eventRef,
      queryBuilder: (participantsQuery) => participantsQuery
          .where('status', isEqualTo: 'active')
          .orderBy('joinedAt'),
    );

List<EventParticipantsRecord> _normalizedActiveParticipants(
  List<EventParticipantsRecord> participants,
) {
  final activeParticipants = participants
      .where((participant) => participant.status.trim() == 'active')
      .toList(growable: false)
    ..sort(_compareActiveParticipants);
  return List.unmodifiable(activeParticipants);
}

int _compareActiveParticipants(
  EventParticipantsRecord left,
  EventParticipantsRecord right,
) {
  final leftJoinedAt = left.joinedAt;
  final rightJoinedAt = right.joinedAt;
  if (leftJoinedAt != null && rightJoinedAt != null) {
    final joinedAtComparison = leftJoinedAt.compareTo(rightJoinedAt);
    if (joinedAtComparison != 0) {
      return joinedAtComparison;
    }
  } else if (leftJoinedAt != null) {
    return -1;
  } else if (rightJoinedAt != null) {
    return 1;
  }

  return left.reference.id.compareTo(right.reference.id);
}
