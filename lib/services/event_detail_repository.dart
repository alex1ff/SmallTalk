import 'dart:convert';

import 'package:rxdart/rxdart.dart';

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
typedef EventParticipantPublicProfilesStream
    = Stream<Map<String, UserPublicProfilesRecord?>> Function(
  List<String> userIds,
);

const int eventActiveParticipantsReadLimit = 50;

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

  static Query activeParticipantsQuery(
    DocumentReference eventRef, {
    int limit = eventActiveParticipantsReadLimit,
  }) {
    if (limit <= 0 || limit > eventActiveParticipantsReadLimit) {
      throw RangeError.range(
        limit,
        1,
        eventActiveParticipantsReadLimit,
        'limit',
      );
    }

    return EventParticipantsRecord.collection(eventRef)
        .where('status', isEqualTo: 'active')
        .limit(limit);
  }

  static Future<List<EventParticipantsRecord>> loadActiveParticipants({
    required DocumentReference eventRef,
    int limit = eventActiveParticipantsReadLimit,
  }) async {
    final snapshot = await activeParticipantsQuery(
      eventRef,
      limit: limit,
    ).get();
    return _normalizedActiveParticipants(
      snapshot.docs
          .map(EventParticipantsRecord.fromSnapshot)
          .toList(growable: false),
    );
  }

  static Stream<Map<String, UserPublicProfilesRecord?>>
      watchParticipantPublicProfiles({
    required Iterable<String> userIds,
    EventParticipantPublicProfilesStream? profilesStream,
  }) {
    final normalizedUserIds = _normalizedProfileUserIds(userIds);
    if (normalizedUserIds.isEmpty) {
      return Stream<Map<String, UserPublicProfilesRecord?>>.value(
        const <String, UserPublicProfilesRecord?>{},
      );
    }

    final loader = profilesStream ?? _watchPublicProfileRecords;
    return loader(normalizedUserIds);
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
    EventDetailRepository.activeParticipantsQuery(eventRef).snapshots().map(
          (snapshot) => snapshot.docs
              .map(EventParticipantsRecord.fromSnapshot)
              .toList(growable: false),
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

List<String> _normalizedProfileUserIds(Iterable<String> userIds) {
  final seenUserIds = <String>{};
  final normalizedUserIds = <String>[];
  for (final rawUserId in userIds) {
    final userId = rawUserId.trim();
    if (userId.isEmpty || seenUserIds.contains(userId)) {
      continue;
    }
    seenUserIds.add(userId);
    normalizedUserIds.add(userId);
  }
  return List.unmodifiable(normalizedUserIds);
}

Stream<Map<String, UserPublicProfilesRecord?>> _watchPublicProfileRecords(
  List<String> userIds,
) {
  final profileStreams = userIds.map((userId) {
    return UserPublicProfilesRecord.maybeGetDocument(
      UserPublicProfilesRecord.collection.doc(userId),
    ).map((profile) => MapEntry(userId, profile));
  }).toList(growable: false);

  return Rx.combineLatestList<MapEntry<String, UserPublicProfilesRecord?>>(
    profileStreams,
  ).map(
    (entries) => Map.unmodifiable(
      <String, UserPublicProfilesRecord?>{
        for (final entry in entries) entry.key: entry.value,
      },
    ),
  );
}
