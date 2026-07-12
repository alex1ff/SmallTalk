import 'dart:async';
import 'dart:collection';

import '/backend/backend.dart';

typedef UserPublicProfileBatchLoader = Future<List<UserPublicProfilesRecord>>
    Function(List<String> userIds);

final class UserPublicProfilePreloadResult {
  UserPublicProfilePreloadResult({
    Map<String, UserPublicProfilesRecord> profilesByUserId =
        const <String, UserPublicProfilesRecord>{},
    Set<String> missingUserIds = const <String>{},
    Set<String> failedUserIds = const <String>{},
  })  : profilesByUserId = Map<String, UserPublicProfilesRecord>.unmodifiable(
            profilesByUserId),
        missingUserIds = Set<String>.unmodifiable(missingUserIds),
        failedUserIds = Set<String>.unmodifiable(failedUserIds);

  final Map<String, UserPublicProfilesRecord> profilesByUserId;
  final Set<String> missingUserIds;
  final Set<String> failedUserIds;

  bool get isComplete => failedUserIds.isEmpty;
}

final class UserPublicProfilePreloadRepository {
  UserPublicProfilePreloadRepository({
    UserPublicProfileBatchLoader? batchLoader,
    this.maxCacheEntries = 256,
    this.cacheTtl = const Duration(minutes: 5),
    this.maxConcurrentBatches = 2,
    DateTime Function()? nowUtcProvider,
  })  : _batchLoader = batchLoader ?? _loadUserPublicProfileBatch,
        _nowUtcProvider = nowUtcProvider {
    if (maxCacheEntries <= 0) {
      throw ArgumentError.value(
        maxCacheEntries,
        'maxCacheEntries',
        'Expected a positive cache entry limit.',
      );
    }
    if (cacheTtl.inMicroseconds <= 0) {
      throw ArgumentError.value(
        cacheTtl,
        'cacheTtl',
        'Expected a positive cache TTL.',
      );
    }
    if (maxConcurrentBatches <= 0) {
      throw ArgumentError.value(
        maxConcurrentBatches,
        'maxConcurrentBatches',
        'Expected a positive concurrent batch limit.',
      );
    }
  }

  static const int maxBatchSize = 30;

  final int maxCacheEntries;
  final Duration cacheTtl;
  final int maxConcurrentBatches;
  final UserPublicProfileBatchLoader _batchLoader;
  final DateTime Function()? _nowUtcProvider;
  final LinkedHashMap<String, _CachedUserPublicProfile> _cache =
      LinkedHashMap<String, _CachedUserPublicProfile>();
  final Map<String, _InFlightUserPublicProfile> _inFlightByUserId =
      <String, _InFlightUserPublicProfile>{};
  final Queue<_QueuedUserPublicProfileBatch> _batchQueue =
      Queue<_QueuedUserPublicProfileBatch>();
  int _activeBatchCount = 0;
  int _epoch = 0;

  Future<UserPublicProfilePreloadResult> preload(
    Iterable<String> userIds,
  ) async {
    final requestedUserIds = _normalizedUserIds(userIds);
    if (requestedUserIds.isEmpty) {
      return UserPublicProfilePreloadResult();
    }

    final resolved = <String, _UserPublicProfileLookup>{};
    final pending = <String, Future<_UserPublicProfileLookup>>{};
    final uncachedUserIds = <String>[];

    for (final userId in requestedUserIds) {
      final cachedProfile = _readCachedProfile(userId);
      if (cachedProfile != null) {
        resolved[userId] = _UserPublicProfileLookup.found(
          userId,
          cachedProfile,
        );
        continue;
      }

      final inFlight = _inFlightByUserId[userId];
      if (inFlight != null && inFlight.epoch == _epoch) {
        pending[userId] = inFlight.future;
        continue;
      }
      uncachedUserIds.add(userId);
    }

    for (var start = 0; start < uncachedUserIds.length; start += maxBatchSize) {
      final end = (start + maxBatchSize < uncachedUserIds.length)
          ? start + maxBatchSize
          : uncachedUserIds.length;
      final batch = List<String>.unmodifiable(
        uncachedUserIds.sublist(start, end),
      );
      _startBatch(batch, pending);
    }

    final completed = await Future.wait(
      pending.entries.map((entry) async {
        return MapEntry(entry.key, await entry.value);
      }),
    );
    resolved.addEntries(completed);

    final profilesByUserId = <String, UserPublicProfilesRecord>{};
    final missingUserIds = LinkedHashSet<String>();
    final failedUserIds = LinkedHashSet<String>();
    for (final userId in requestedUserIds) {
      final lookup = resolved[userId];
      if (lookup == null) {
        failedUserIds.add(userId);
        continue;
      }
      switch (lookup.outcome) {
        case _UserPublicProfileOutcome.found:
          profilesByUserId[userId] = lookup.profile!;
        case _UserPublicProfileOutcome.missing:
          missingUserIds.add(userId);
        case _UserPublicProfileOutcome.failed:
          failedUserIds.add(userId);
      }
    }

    return UserPublicProfilePreloadResult(
      profilesByUserId: profilesByUserId,
      missingUserIds: missingUserIds,
      failedUserIds: failedUserIds,
    );
  }

  void clear() {
    _epoch += 1;
    _cache.clear();
    _inFlightByUserId.clear();
    while (_batchQueue.isNotEmpty) {
      final batch = _batchQueue.removeFirst();
      batch.completer.complete(
        _ValidatedUserPublicProfileBatch.failed(batch.userIds),
      );
    }
  }

  void _startBatch(
    List<String> userIds,
    Map<String, Future<_UserPublicProfileLookup>> pending,
  ) {
    final requestEpoch = _epoch;
    final batchCompleter = Completer<_ValidatedUserPublicProfileBatch>();
    final batchFuture = batchCompleter.future;

    for (final userId in userIds) {
      late final _InFlightUserPublicProfile inFlight;
      final lookupFuture = batchFuture.then((batchResult) {
        final lookup = batchResult.lookup(userId);
        final profile = lookup.profile;
        if (profile != null && _epoch == requestEpoch) {
          _writeCachedProfile(userId, profile);
        }
        return lookup;
      }).whenComplete(() {
        if (identical(_inFlightByUserId[userId], inFlight)) {
          _inFlightByUserId.remove(userId);
        }
      });
      inFlight = _InFlightUserPublicProfile(
        epoch: requestEpoch,
        future: lookupFuture,
      );
      _inFlightByUserId[userId] = inFlight;
      pending[userId] = lookupFuture;
    }

    _batchQueue.addLast(
      _QueuedUserPublicProfileBatch(
        userIds: userIds,
        completer: batchCompleter,
      ),
    );
    _drainBatchQueue();
  }

  void _drainBatchQueue() {
    while (_activeBatchCount < maxConcurrentBatches && _batchQueue.isNotEmpty) {
      final batch = _batchQueue.removeFirst();
      _activeBatchCount += 1;
      unawaited(_runBatch(batch));
    }
  }

  Future<void> _runBatch(_QueuedUserPublicProfileBatch batch) async {
    try {
      final result = await _loadValidatedBatch(batch.userIds);
      batch.completer.complete(result);
    } catch (_) {
      batch.completer.complete(
        _ValidatedUserPublicProfileBatch.failed(batch.userIds),
      );
    } finally {
      _activeBatchCount -= 1;
      _drainBatchQueue();
    }
  }

  Future<_ValidatedUserPublicProfileBatch> _loadValidatedBatch(
    List<String> requestedUserIds,
  ) async {
    try {
      final loadedProfiles = await Future<List<UserPublicProfilesRecord>>.sync(
        () => _batchLoader(requestedUserIds),
      );
      final requestedSet = requestedUserIds.toSet();
      final profilesByUserId = <String, UserPublicProfilesRecord>{};
      for (final profile in loadedProfiles) {
        final returnedUserId = profile.reference.id;
        if (!isValidUserPublicProfileRecordForUserId(
              profile,
              returnedUserId,
            ) ||
            !requestedSet.contains(returnedUserId) ||
            profilesByUserId.containsKey(returnedUserId)) {
          return _ValidatedUserPublicProfileBatch.failed(requestedUserIds);
        }
        profilesByUserId[returnedUserId] = profile;
      }
      return _ValidatedUserPublicProfileBatch.success(
        requestedUserIds: requestedUserIds,
        profilesByUserId: profilesByUserId,
      );
    } catch (_) {
      return _ValidatedUserPublicProfileBatch.failed(requestedUserIds);
    }
  }

  UserPublicProfilesRecord? _readCachedProfile(String userId) {
    final entry = _cache.remove(userId);
    if (entry == null) {
      return null;
    }
    if (!entry.isFresh(nowUtc: _nowUtc(), ttl: cacheTtl)) {
      return null;
    }
    _cache[userId] = entry;
    return entry.profile;
  }

  void _writeCachedProfile(
    String userId,
    UserPublicProfilesRecord profile,
  ) {
    _cache.remove(userId);
    _cache[userId] = _CachedUserPublicProfile(
      profile: profile,
      fetchedAtUtc: _nowUtc(),
    );
    while (_cache.length > maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  DateTime _nowUtc() {
    final now = _nowUtcProvider?.call() ?? DateTime.now().toUtc();
    return now.isUtc ? now : now.toUtc();
  }
}

Future<List<UserPublicProfilesRecord>> _loadUserPublicProfileBatch(
  List<String> userIds,
) async {
  final snapshot = await UserPublicProfilesRecord.collection
      .where(FieldPath.documentId, whereIn: userIds)
      .get();
  return snapshot.docs
      .map(UserPublicProfilesRecord.fromSnapshot)
      .toList(growable: false);
}

List<String> _normalizedUserIds(Iterable<String> userIds) {
  final uniqueUserIds = <String>{};
  for (final userId in userIds) {
    final normalized = _normalizeUserId(userId);
    if (normalized != null) {
      uniqueUserIds.add(normalized);
    }
  }
  return uniqueUserIds.toList(growable: false)..sort();
}

String? _normalizeUserId(String userId) {
  if (!isValidUserPublicProfileUserId(userId)) {
    return null;
  }
  return userId;
}

bool isValidUserPublicProfileUserId(String userId) {
  return userId.isNotEmpty &&
      userId.length <= 128 &&
      userId == userId.trim() &&
      !userId.contains('/') &&
      userId != '.' &&
      userId != '..' &&
      !(userId.startsWith('__') && userId.endsWith('__'));
}

bool isValidUserPublicProfileRecordForUserId(
  UserPublicProfilesRecord profile,
  String userId,
) {
  return isValidUserPublicProfileUserId(userId) &&
      profile.reference.id == userId &&
      profile.reference.parent.path ==
          UserPublicProfilesRecord.collection.path &&
      (!profile.hasUserId() || profile.userId == userId);
}

enum _UserPublicProfileOutcome {
  found,
  missing,
  failed,
}

final class _UserPublicProfileLookup {
  const _UserPublicProfileLookup._({
    required this.userId,
    required this.outcome,
    this.profile,
  });

  factory _UserPublicProfileLookup.found(
    String userId,
    UserPublicProfilesRecord profile,
  ) {
    return _UserPublicProfileLookup._(
      userId: userId,
      outcome: _UserPublicProfileOutcome.found,
      profile: profile,
    );
  }

  factory _UserPublicProfileLookup.missing(String userId) {
    return _UserPublicProfileLookup._(
      userId: userId,
      outcome: _UserPublicProfileOutcome.missing,
    );
  }

  factory _UserPublicProfileLookup.failed(String userId) {
    return _UserPublicProfileLookup._(
      userId: userId,
      outcome: _UserPublicProfileOutcome.failed,
    );
  }

  final String userId;
  final _UserPublicProfileOutcome outcome;
  final UserPublicProfilesRecord? profile;
}

final class _ValidatedUserPublicProfileBatch {
  _ValidatedUserPublicProfileBatch._({
    required Map<String, _UserPublicProfileLookup> lookupsByUserId,
  }) : _lookupsByUserId =
            Map<String, _UserPublicProfileLookup>.unmodifiable(lookupsByUserId);

  factory _ValidatedUserPublicProfileBatch.success({
    required List<String> requestedUserIds,
    required Map<String, UserPublicProfilesRecord> profilesByUserId,
  }) {
    return _ValidatedUserPublicProfileBatch._(
      lookupsByUserId: {
        for (final userId in requestedUserIds)
          userId: profilesByUserId[userId] == null
              ? _UserPublicProfileLookup.missing(userId)
              : _UserPublicProfileLookup.found(
                  userId,
                  profilesByUserId[userId]!,
                ),
      },
    );
  }

  factory _ValidatedUserPublicProfileBatch.failed(
    List<String> requestedUserIds,
  ) {
    return _ValidatedUserPublicProfileBatch._(
      lookupsByUserId: {
        for (final userId in requestedUserIds)
          userId: _UserPublicProfileLookup.failed(userId),
      },
    );
  }

  final Map<String, _UserPublicProfileLookup> _lookupsByUserId;

  _UserPublicProfileLookup lookup(String userId) {
    return _lookupsByUserId[userId] ?? _UserPublicProfileLookup.failed(userId);
  }
}

final class _InFlightUserPublicProfile {
  const _InFlightUserPublicProfile({
    required this.epoch,
    required this.future,
  });

  final int epoch;
  final Future<_UserPublicProfileLookup> future;
}

final class _QueuedUserPublicProfileBatch {
  const _QueuedUserPublicProfileBatch({
    required this.userIds,
    required this.completer,
  });

  final List<String> userIds;
  final Completer<_ValidatedUserPublicProfileBatch> completer;
}

final class _CachedUserPublicProfile {
  const _CachedUserPublicProfile({
    required this.profile,
    required this.fetchedAtUtc,
  });

  final UserPublicProfilesRecord profile;
  final DateTime fetchedAtUtc;

  bool isFresh({
    required DateTime nowUtc,
    required Duration ttl,
  }) {
    final age = nowUtc.difference(fetchedAtUtc);
    return !age.isNegative && age < ttl;
  }
}
