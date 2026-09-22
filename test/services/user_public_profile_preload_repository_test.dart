import 'dart:async';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/services/user_public_profile_preload_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('UserPublicProfilePreloadRepository', () {
    test('deduplicates, sorts, and skips invalid opaque user ids', () async {
      final batches = <List<String>>[];
      final repository = UserPublicProfilePreloadRepository(
        batchLoader: (userIds) async {
          batches.add(List<String>.of(userIds));
          return userIds.map(_profile).toList(growable: false);
        },
      );
      final longestValidUserId = List<String>.filled(128, 'v').join();
      final tooLongUserId = '${longestValidUserId}v';
      final expectedUserIds = <String>[
        'alpha',
        'beta',
        'middle value',
        longestValidUserId,
      ]..sort();

      final result = await repository.preload([
        ' beta ',
        '\talpha',
        'alpha\n',
        '\u00a0beta',
        '',
        'alpha',
        'alpha',
        'events/user',
        '   ',
        '.',
        '..',
        '__reserved__',
        '__\n__',
        tooLongUserId,
        'beta',
        'middle value',
        longestValidUserId,
      ]);

      expect(batches, [expectedUserIds]);
      expect(result.profilesByUserId.keys, orderedEquals(expectedUserIds));
      expect(result.missingUserIds, isEmpty);
      expect(result.failedUserIds, isEmpty);
      expect(result.isComplete, isTrue);
      expect(
        () => result.profilesByUserId.remove('alpha'),
        throwsUnsupportedError,
      );
      expect(
        () => result.missingUserIds.add('other'),
        throwsUnsupportedError,
      );
      expect(
        () => result.failedUserIds.add('other'),
        throwsUnsupportedError,
      );
    });

    test('uses two concurrent batches by default and rejects invalid limits',
        () {
      expect(
        UserPublicProfilePreloadRepository().maxConcurrentBatches,
        2,
      );
      expect(
        () => UserPublicProfilePreloadRepository(maxConcurrentBatches: 0),
        throwsArgumentError,
      );
      expect(
        () => UserPublicProfilePreloadRepository(maxConcurrentBatches: -1),
        throwsArgumentError,
      );
    });

    test('rejects unexpected returned document ids for the whole batch',
        () async {
      final repository = UserPublicProfilePreloadRepository(
        batchLoader: (_) async => <UserPublicProfilesRecord>[
          _profile('unexpected-user'),
        ],
      );

      final result = await repository.preload(['requested-user']);

      expect(result.profilesByUserId, isEmpty);
      expect(result.missingUserIds, isEmpty);
      expect(result.failedUserIds, {'requested-user'});
      expect(result.isComplete, isFalse);
    });

    test('rejects records outside the public profile collection', () async {
      final repository = UserPublicProfilePreloadRepository(
        batchLoader: (_) async => <UserPublicProfilesRecord>[
          _profile(
            'requested-user',
            reference: UsersRecord.collection.doc('requested-user'),
          ),
        ],
      );

      final result = await repository.preload(['requested-user']);

      expect(result.profilesByUserId, isEmpty);
      expect(result.missingUserIds, isEmpty);
      expect(result.failedUserIds, {'requested-user'});
    });

    test('rejects records whose embedded user id does not match the path',
        () async {
      final repository = UserPublicProfilePreloadRepository(
        batchLoader: (_) async => <UserPublicProfilesRecord>[
          _profile(
            'requested-user',
            storedUserId: 'different-user',
          ),
        ],
      );

      final result = await repository.preload(['requested-user']);

      expect(result.profilesByUserId, isEmpty);
      expect(result.missingUserIds, isEmpty);
      expect(result.failedUserIds, {'requested-user'});
    });

    test('splits a stable sorted request into 30, 30, and 5', () async {
      final batches = <List<String>>[];
      final repository = UserPublicProfilePreloadRepository(
        batchLoader: (userIds) async {
          batches.add(List<String>.of(userIds));
          return userIds.map(_profile).toList(growable: false);
        },
      );
      final sortedUserIds = List<String>.generate(
        65,
        (index) => 'user-${index.toString().padLeft(3, '0')}',
      );

      final result = await repository.preload(sortedUserIds.reversed);

      expect(batches.map((batch) => batch.length), orderedEquals([30, 30, 5]));
      expect(
        batches.expand((batch) => batch),
        orderedEquals(sortedUserIds),
      );
      expect(result.profilesByUserId.keys, orderedEquals(sortedUserIds));
      expect(result.isComplete, isTrue);
    });

    test('starts queued batches FIFO within the configured concurrency limit',
        () async {
      final releaseBatches = Completer<void>();
      final startedBatches = <List<String>>[];
      var activeBatches = 0;
      var maxActiveBatches = 0;
      final repository = UserPublicProfilePreloadRepository(
        maxConcurrentBatches: 2,
        batchLoader: (userIds) async {
          startedBatches.add(List<String>.of(userIds));
          activeBatches += 1;
          if (activeBatches > maxActiveBatches) {
            maxActiveBatches = activeBatches;
          }
          await releaseBatches.future;
          activeBatches -= 1;
          return userIds.map(_profile).toList(growable: false);
        },
      );
      final userIds = List<String>.generate(
        95,
        (index) => 'user-${index.toString().padLeft(3, '0')}',
      );

      final preload = repository.preload(userIds.reversed);

      expect(startedBatches.map((batch) => batch.first), [
        'user-000',
        'user-030',
      ]);
      expect(activeBatches, 2);

      releaseBatches.complete();
      final result = await preload;

      expect(startedBatches.map((batch) => batch.first), [
        'user-000',
        'user-030',
        'user-060',
        'user-090',
      ]);
      expect(maxActiveBatches, 2);
      expect(activeBatches, 0);
      expect(result.profilesByUserId.keys, orderedEquals(userIds));
      expect(result.isComplete, isTrue);
    });

    test('clear fails queued batches without starting them', () async {
      final activeBatch = Completer<List<UserPublicProfilesRecord>>();
      final startedBatches = <List<String>>[];
      final repository = UserPublicProfilePreloadRepository(
        maxConcurrentBatches: 1,
        batchLoader: (userIds) {
          startedBatches.add(List<String>.of(userIds));
          if (userIds.single == 'old-active') {
            return activeBatch.future;
          }
          return Future<List<UserPublicProfilesRecord>>.value(
            userIds.map(_profile).toList(growable: false),
          );
        },
      );

      final activeLoad = repository.preload(['old-active']);
      final queuedLoad = repository.preload(['old-queued']);

      expect(startedBatches, [
        <String>['old-active'],
      ]);

      repository.clear();
      final newLoad = repository.preload(['new-user']);
      final queuedResult = await queuedLoad;

      expect(startedBatches, [
        <String>['old-active'],
      ]);
      expect(queuedResult.profilesByUserId, isEmpty);
      expect(queuedResult.missingUserIds, isEmpty);
      expect(queuedResult.failedUserIds, {'old-queued'});
      expect(queuedResult.isComplete, isFalse);

      activeBatch.complete([_profile('old-active')]);
      final activeResult = await activeLoad;
      final newResult = await newLoad;

      expect(startedBatches, [
        <String>['old-active'],
        <String>['new-user'],
      ]);
      expect(activeResult.profilesByUserId.keys, ['old-active']);
      expect(activeResult.isComplete, isTrue);
      expect(newResult.profilesByUserId.keys, ['new-user']);
      expect(newResult.isComplete, isTrue);
    });

    test('keeps positive entries in a bounded LRU cache until TTL expires',
        () async {
      var nowUtc = DateTime.utc(2035, 6, 14, 9);
      final batches = <List<String>>[];
      final repository = UserPublicProfilePreloadRepository(
        maxCacheEntries: 2,
        cacheTtl: const Duration(minutes: 5),
        nowUtcProvider: () => nowUtc,
        batchLoader: (userIds) async {
          batches.add(List<String>.of(userIds));
          return userIds.map(_profile).toList(growable: false);
        },
      );

      await repository.preload(['alpha', 'beta']);
      await repository.preload(['alpha']);
      await repository.preload(['charlie']);
      await repository.preload(['alpha']);
      await repository.preload(['beta']);

      expect(batches, [
        <String>['alpha', 'beta'],
        <String>['charlie'],
        <String>['beta'],
      ]);

      nowUtc = nowUtc.add(const Duration(minutes: 6));
      await repository.preload(['alpha']);

      expect(batches.last, <String>['alpha']);
      expect(batches, hasLength(4));
    });

    test('refetches a positive cache entry after clock rollback', () async {
      var nowUtc = DateTime.utc(2035, 6, 14, 9);
      var calls = 0;
      final repository = UserPublicProfilePreloadRepository(
        nowUtcProvider: () => nowUtc,
        batchLoader: (userIds) async {
          calls += 1;
          return userIds
              .map(
                (userId) => _profile(
                  userId,
                  displayName: 'Profile version $calls',
                ),
              )
              .toList(growable: false);
        },
      );

      final first = await repository.preload(['rollback-user']);
      nowUtc = nowUtc.subtract(const Duration(minutes: 1));
      final refetched = await repository.preload(['rollback-user']);

      expect(calls, 2);
      expect(
        first.profilesByUserId['rollback-user']?.displayName,
        'Profile version 1',
      );
      expect(
        refetched.profilesByUserId['rollback-user']?.displayName,
        'Profile version 2',
      );
      expect(refetched.isComplete, isTrue);
    });

    test('clear removes positive cache entries', () async {
      var calls = 0;
      final repository = UserPublicProfilePreloadRepository(
        batchLoader: (userIds) async {
          calls += 1;
          return userIds
              .map(
                (userId) => _profile(
                  userId,
                  displayName: 'Profile version $calls',
                ),
              )
              .toList(growable: false);
        },
      );

      final first = await repository.preload(['cached-user']);
      final cached = await repository.preload(['cached-user']);

      expect(calls, 1);
      expect(
        first.profilesByUserId['cached-user']?.displayName,
        'Profile version 1',
      );
      expect(
        cached.profilesByUserId['cached-user']?.displayName,
        'Profile version 1',
      );

      repository.clear();
      final refreshed = await repository.preload(['cached-user']);

      expect(calls, 2);
      expect(
        refreshed.profilesByUserId['cached-user']?.displayName,
        'Profile version 2',
      );
      expect(refreshed.isComplete, isTrue);
    });

    test('does not negative-cache missing profiles', () async {
      var calls = 0;
      final repository = UserPublicProfilePreloadRepository(
        batchLoader: (userIds) async {
          calls += 1;
          if (calls == 1) {
            return const <UserPublicProfilesRecord>[];
          }
          return userIds.map(_profile).toList(growable: false);
        },
      );

      final missing = await repository.preload(['late-profile']);
      final found = await repository.preload(['late-profile']);

      expect(missing.profilesByUserId, isEmpty);
      expect(missing.missingUserIds, {'late-profile'});
      expect(missing.failedUserIds, isEmpty);
      expect(missing.isComplete, isTrue);
      expect(found.profilesByUserId.keys, ['late-profile']);
      expect(found.missingUserIds, isEmpty);
      expect(calls, 2);
    });

    test('preserves successful chunks and retries only failed ids', () async {
      final batches = <List<String>>[];
      var failMiddleBatch = true;
      final repository = UserPublicProfilePreloadRepository(
        batchLoader: (userIds) async {
          batches.add(List<String>.of(userIds));
          if (failMiddleBatch && userIds.first == 'user-030') {
            failMiddleBatch = false;
            throw StateError('middle batch failed');
          }
          return userIds.map(_profile).toList(growable: false);
        },
      );
      final userIds = List<String>.generate(
        65,
        (index) => 'user-${index.toString().padLeft(3, '0')}',
      );

      final partial = await repository.preload(userIds);

      expect(partial.profilesByUserId, hasLength(35));
      expect(partial.missingUserIds, isEmpty);
      expect(
        partial.failedUserIds,
        userIds.sublist(30, 60).toSet(),
      );
      expect(partial.isComplete, isFalse);

      final retried = await repository.preload(userIds);

      expect(batches, hasLength(4));
      expect(batches.last, orderedEquals(userIds.sublist(30, 60)));
      expect(retried.profilesByUserId.keys, orderedEquals(userIds));
      expect(retried.missingUserIds, isEmpty);
      expect(retried.failedUserIds, isEmpty);
      expect(retried.isComplete, isTrue);
    });

    test('deduplicates overlapping active and queued work per user id',
        () async {
      final firstBatch = Completer<List<UserPublicProfilesRecord>>();
      final secondBatch = Completer<List<UserPublicProfilesRecord>>();
      final batches = <List<String>>[];
      final repository = UserPublicProfilePreloadRepository(
        maxConcurrentBatches: 1,
        batchLoader: (userIds) {
          batches.add(List<String>.of(userIds));
          return userIds.contains('alpha')
              ? firstBatch.future
              : secondBatch.future;
        },
      );

      final firstLoad = repository.preload(['alpha', 'beta']);
      final overlappingLoad = repository.preload(['beta', 'charlie']);
      final queuedOverlap = repository.preload(['charlie']);

      expect(batches, [
        <String>['alpha', 'beta'],
      ]);

      firstBatch.complete([_profile('alpha'), _profile('beta')]);
      final firstResult = await firstLoad;
      expect(batches, [
        <String>['alpha', 'beta'],
        <String>['charlie'],
      ]);

      secondBatch.complete([_profile('charlie')]);
      final overlappingResult = await overlappingLoad;
      final queuedOverlapResult = await queuedOverlap;

      expect(
        firstResult.profilesByUserId.keys,
        orderedEquals(['alpha', 'beta']),
      );
      expect(
        overlappingResult.profilesByUserId.keys,
        orderedEquals(['beta', 'charlie']),
      );
      expect(queuedOverlapResult.profilesByUserId.keys, ['charlie']);
      expect(firstResult.isComplete, isTrue);
      expect(overlappingResult.isComplete, isTrue);
      expect(queuedOverlapResult.isComplete, isTrue);
    });

    test('clear epoch keeps new cache when old work completes last', () async {
      final oldBatch = Completer<List<UserPublicProfilesRecord>>();
      final newBatch = Completer<List<UserPublicProfilesRecord>>();
      var calls = 0;
      final repository = UserPublicProfilePreloadRepository(
        batchLoader: (_) {
          calls += 1;
          return calls == 1 ? oldBatch.future : newBatch.future;
        },
      );

      final oldLoad = repository.preload(['same-user']);
      repository.clear();
      final newLoad = repository.preload(['same-user']);

      expect(calls, 2);

      newBatch.complete([
        _profile('same-user', displayName: 'New profile'),
      ]);
      final newResult = await newLoad;
      expect(
          newResult.profilesByUserId['same-user']?.displayName, 'New profile');

      oldBatch.complete([
        _profile('same-user', displayName: 'Old profile'),
      ]);
      final oldResult = await oldLoad;
      expect(
          oldResult.profilesByUserId['same-user']?.displayName, 'Old profile');

      final cachedResult = await repository.preload(['same-user']);

      expect(calls, 2);
      expect(
        cachedResult.profilesByUserId['same-user']?.displayName,
        'New profile',
      );
    });

    test('old completion cannot remove a new in-flight lookup', () async {
      final oldBatch = Completer<List<UserPublicProfilesRecord>>();
      final newBatch = Completer<List<UserPublicProfilesRecord>>();
      var calls = 0;
      final repository = UserPublicProfilePreloadRepository(
        batchLoader: (_) {
          calls += 1;
          return calls == 1 ? oldBatch.future : newBatch.future;
        },
      );

      final oldLoad = repository.preload(['same-user']);
      repository.clear();
      final newLoad = repository.preload(['same-user']);

      expect(calls, 2);

      oldBatch.complete([
        _profile('same-user', displayName: 'Old profile'),
      ]);
      final oldResult = await oldLoad;
      expect(
          oldResult.profilesByUserId['same-user']?.displayName, 'Old profile');

      final overlappingLoad = repository.preload(['same-user']);
      expect(calls, 2);

      newBatch.complete([
        _profile('same-user', displayName: 'New profile'),
      ]);
      final newResult = await newLoad;
      final overlappingResult = await overlappingLoad;

      expect(
          newResult.profilesByUserId['same-user']?.displayName, 'New profile');
      expect(
        overlappingResult.profilesByUserId['same-user']?.displayName,
        'New profile',
      );
      expect(calls, 2);
    });
  });
}

UserPublicProfilesRecord _profile(
  String userId, {
  String? displayName,
  String? storedUserId,
  DocumentReference? reference,
}) {
  return UserPublicProfilesRecord.getDocumentFromData(
    {
      'userId': storedUserId ?? userId,
      'display_name': displayName ?? 'Profile $userId',
    },
    reference ?? UserPublicProfilesRecord.collection.doc(userId),
  );
}
