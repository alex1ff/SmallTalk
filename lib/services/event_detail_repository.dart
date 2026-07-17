import 'dart:collection';
import 'dart:convert';

import 'package:rxdart/rxdart.dart';

import '/backend/backend.dart';
import '/services/ux_loading_state.dart';
import '/services/ux_session_cache_lifecycle.dart';
import '/services/ux_session_loaded_result_cache.dart';

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
typedef EventDetailSnapshotFlagReader = bool Function(
  DocumentSnapshot snapshot,
);
typedef _EventDetailCacheKey = ({String eventId, String userId});
typedef EventParticipantPublicProfilesStream
    = Stream<Map<String, UserPublicProfilesRecord?>> Function(
  List<String> userIds,
);

const int eventActiveParticipantsReadLimit = 50;

class EventDetailRepository {
  const EventDetailRepository._();

  static const int _maxEventDetailSessionEntries = 64;
  static final UxSessionLoadedResultCache<EventsRecord>
      _eventDetailSessionCache = UxSessionLoadedResultCache<EventsRecord>(
    maxEntries: _maxEventDetailSessionEntries,
  );
  static final LinkedHashMap<_EventDetailCacheKey, int>
      _eventDetailLatestRequestTokens =
      LinkedHashMap<_EventDetailCacheKey, int>();
  static final LinkedHashMap<_EventDetailCacheKey, int>
      _eventDetailCacheOwnerTokens = LinkedHashMap<_EventDetailCacheKey, int>();
  static int _eventDetailWatcherTokenSerial = 0;
  static bool _sessionCacheLifecycleRegistered = false;

  static DocumentReference eventReferenceForId(String eventId) =>
      EventsRecord.collection.doc(normalizeEventDetailId(eventId));

  static Stream<EventsRecord?> watchEventDetail({
    required String eventId,
    EventDetailSnapshotStream? snapshotStream,
    String? sessionCacheUserId,
    EventDetailSnapshotFlagReader? snapshotIsFromCache,
    EventDetailSnapshotFlagReader? snapshotHasPendingWrites,
  }) {
    _ensureSessionCacheLifecycleRegistered();
    final eventRef = eventReferenceForId(eventId);
    final loader = snapshotStream ?? _watchEventSnapshot;
    final cacheKey = _eventDetailCacheKey(
      userId: sessionCacheUserId,
      normalizedEventId: eventRef.id,
    );
    final cacheWatcherToken =
        cacheKey == null ? null : _registerEventDetailWatcherRequest(cacheKey);
    final usesInjectedSnapshots = snapshotStream != null;
    final isFromCache = snapshotIsFromCache ??
        (usesInjectedSnapshots ? _snapshotFlagIsFalse : _snapshotIsFromCache);
    final hasPendingWrites = snapshotHasPendingWrites ??
        (usesInjectedSnapshots
            ? _snapshotFlagIsFalse
            : _snapshotHasPendingWrites);

    return loader(eventRef)
        .map((snapshot) {
          if (snapshot.reference.path != eventRef.path) {
            throw StateError(
              'Event detail snapshot path "${snapshot.reference.path}" '
              'does not match requested path "${eventRef.path}".',
            );
          }
          return _EventDetailSnapshotEnvelope(
            snapshot: snapshot,
            isFromCache: isFromCache(snapshot),
            hasPendingWrites: hasPendingWrites(snapshot),
          );
        })
        .where(
          (envelope) =>
              envelope.snapshot.exists ||
              (!envelope.isFromCache && !envelope.hasPendingWrites),
        )
        .map((envelope) {
          final snapshot = envelope.snapshot;
          if (!snapshot.exists) {
            final authoritativeCacheKey = _authoritativeEventDetailCacheKey(
              cacheKey,
              cacheWatcherToken,
            );
            if (authoritativeCacheKey != null) {
              _eventDetailSessionCache.remove(authoritativeCacheKey);
            }
            return null;
          }

          final event = EventsRecord.fromSnapshot(snapshot);
          final isConfirmed =
              !envelope.isFromCache && !envelope.hasPendingWrites;
          if (isConfirmed) {
            final authoritativeCacheKey = _authoritativeEventDetailCacheKey(
              cacheKey,
              cacheWatcherToken,
            );
            if (authoritativeCacheKey == null) {
              return event;
            }
            _eventDetailSessionCache.write(
              UxLoadedResult<EventsRecord>.data(
                dataKey: authoritativeCacheKey,
                data: event,
              ),
            );
          }
          return event;
        });
  }

  static EventsRecord? cachedEventDetail({
    required String eventId,
    required String userId,
  }) {
    _ensureSessionCacheLifecycleRegistered();
    final normalizedEventId = normalizeEventDetailId(eventId);
    final cacheKey = _eventDetailCacheKey(
      userId: userId,
      normalizedEventId: normalizedEventId,
    );
    if (cacheKey == null) {
      return null;
    }
    final cachedResult = _eventDetailSessionCache.read(cacheKey);
    if (cachedResult == null) {
      return null;
    }
    final watcherToken = _eventDetailCacheOwnerTokens.remove(cacheKey);
    if (watcherToken == null) {
      _eventDetailSessionCache.remove(cacheKey);
      return null;
    }
    _eventDetailCacheOwnerTokens[cacheKey] = watcherToken;
    return cachedResult.data;
  }

  static void invalidateCachedEventDetail({
    required String eventId,
    required String userId,
  }) {
    _ensureSessionCacheLifecycleRegistered();
    final normalizedEventId = normalizeEventDetailId(eventId);
    final cacheKey = _eventDetailCacheKey(
      userId: userId,
      normalizedEventId: normalizedEventId,
    );
    if (cacheKey != null) {
      _eventDetailLatestRequestTokens.remove(cacheKey);
      _eventDetailCacheOwnerTokens.remove(cacheKey);
      _eventDetailSessionCache.remove(cacheKey);
    }
  }

  static void clearEventDetailSessionCache() {
    _ensureSessionCacheLifecycleRegistered();
    _clearEventDetailSessionCacheState();
  }

  static void _clearEventDetailSessionCacheState() {
    _eventDetailLatestRequestTokens.clear();
    _eventDetailCacheOwnerTokens.clear();
    _eventDetailSessionCache.clear();
  }

  static void _ensureSessionCacheLifecycleRegistered() {
    if (_sessionCacheLifecycleRegistered) {
      return;
    }
    _sessionCacheLifecycleRegistered = true;
    UxSessionCacheLifecycle.register(_clearEventDetailSessionCacheState);
  }

  static int _registerEventDetailWatcherRequest(
    _EventDetailCacheKey cacheKey,
  ) {
    final watcherToken = ++_eventDetailWatcherTokenSerial;
    _eventDetailLatestRequestTokens.remove(cacheKey);
    _eventDetailLatestRequestTokens[cacheKey] = watcherToken;
    while (_eventDetailLatestRequestTokens.length >
        _maxEventDetailSessionEntries) {
      _eventDetailLatestRequestTokens.remove(
        _eventDetailLatestRequestTokens.keys.first,
      );
    }
    return watcherToken;
  }

  static _EventDetailCacheKey? _authoritativeEventDetailCacheKey(
    _EventDetailCacheKey? cacheKey,
    int? watcherToken,
  ) {
    if (cacheKey == null || watcherToken == null) {
      return null;
    }
    if (_eventDetailCacheOwnerTokens[cacheKey] == watcherToken) {
      _eventDetailCacheOwnerTokens.remove(cacheKey);
      _eventDetailCacheOwnerTokens[cacheKey] = watcherToken;
      return cacheKey;
    }
    if (_eventDetailLatestRequestTokens[cacheKey] != watcherToken) {
      return null;
    }
    _eventDetailLatestRequestTokens.remove(cacheKey);
    _eventDetailCacheOwnerTokens.remove(cacheKey);
    _eventDetailCacheOwnerTokens[cacheKey] = watcherToken;
    while (
        _eventDetailCacheOwnerTokens.length > _maxEventDetailSessionEntries) {
      final evictedCacheKey = _eventDetailCacheOwnerTokens.keys.first;
      _eventDetailCacheOwnerTokens.remove(evictedCacheKey);
      _eventDetailSessionCache.remove(evictedCacheKey);
    }
    return cacheKey;
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

_EventDetailCacheKey? _eventDetailCacheKey({
  required String? userId,
  required String normalizedEventId,
}) {
  if (userId == null || userId.isEmpty) {
    return null;
  }
  return (userId: userId, eventId: normalizedEventId);
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
    eventRef.snapshots(includeMetadataChanges: true);

bool _snapshotIsFromCache(DocumentSnapshot snapshot) {
  return snapshot.metadata.isFromCache;
}

bool _snapshotHasPendingWrites(DocumentSnapshot snapshot) {
  return snapshot.metadata.hasPendingWrites;
}

bool _snapshotFlagIsFalse(DocumentSnapshot _) => false;

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

class _EventDetailSnapshotEnvelope {
  const _EventDetailSnapshotEnvelope({
    required this.snapshot,
    required this.isFromCache,
    required this.hasPendingWrites,
  });

  final DocumentSnapshot snapshot;
  final bool isFromCache;
  final bool hasPendingWrites;
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
