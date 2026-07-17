import 'dart:async';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/services/event_detail_repository.dart';
import 'package:small_talk/services/ux_session_cache_lifecycle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    EventDetailRepository.clearEventDetailSessionCache();
    UxSessionCacheLifecycle.updateAuthenticatedUser(null);
  });

  group('EventDetailRepository', () {
    test('normalizes event id and subscribes to the event document', () async {
      DocumentReference? capturedEventRef;

      final events = await EventDetailRepository.watchEventDetail(
        eventId: ' event-1 ',
        snapshotStream: (eventRef) {
          capturedEventRef = eventRef;
          return Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-1'),
              data: eventDetailData(title: 'Conversation club'),
            ),
          );
        },
      ).toList();

      expect(capturedEventRef?.path, 'events/event-1');
      expect(events, hasLength(1));
      expect(events.single?.reference.path, 'events/event-1');
      expect(events.single?.title, 'Conversation club');
    });

    test('emits null when the event document is missing or deleted', () async {
      final events = await EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        snapshotStream: (_) => Stream<DocumentSnapshot>.fromIterable([
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            data: eventDetailData(title: 'Conversation club'),
          ),
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            exists: false,
          ),
        ]),
      ).toList();

      expect(events, hasLength(2));
      expect(events.first?.title, 'Conversation club');
      expect(events.last, isNull);
    });

    test('rejects invalid event ids before subscribing', () {
      for (final eventId in <String>[
        '',
        ' ',
        '.',
        '..',
        'events/event-1',
        '__reserved__',
        'a' * 1501,
      ]) {
        var streamCalls = 0;

        expect(
          () => EventDetailRepository.watchEventDetail(
            eventId: eventId,
            snapshotStream: (_) {
              streamCalls += 1;
              return const Stream<DocumentSnapshot>.empty();
            },
          ),
          throwsA(isA<ArgumentError>()),
          reason: 'Expected "$eventId" to be rejected.',
        );
        expect(streamCalls, 0);
      }
    });

    test('passes detail stream errors through', () async {
      final error = StateError('detail stream failed');

      await expectLater(
        EventDetailRepository.watchEventDetail(
          eventId: 'event-1',
          snapshotStream: (_) => Stream<DocumentSnapshot>.error(error),
        ),
        emitsError(same(error)),
      );
    });

    test('stores the latest confirmed detail by user and event', () async {
      await EventDetailRepository.watchEventDetail(
        eventId: ' event-1 ',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => Stream<DocumentSnapshot>.fromIterable([
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            data: eventDetailData(title: 'Initial title'),
          ),
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            data: eventDetailData(title: 'Updated title'),
          ),
        ]),
      ).drain<void>();

      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-1',
          userId: 'user-a',
        )?.title,
        'Updated title',
      );
    });

    test('isolates cached details by user and event id', () async {
      Future<void> remember({
        required String eventId,
        required String userId,
        required String title,
      }) async {
        await EventDetailRepository.watchEventDetail(
          eventId: eventId,
          sessionCacheUserId: userId,
          snapshotStream: (_) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef(eventId),
              data: eventDetailData(title: title),
            ),
          ),
        ).drain<void>();
      }

      await remember(
        eventId: 'event-1',
        userId: 'user-a',
        title: 'User A event 1',
      );
      await remember(
        eventId: 'event-2',
        userId: 'user-a',
        title: 'User A event 2',
      );
      await remember(
        eventId: 'event-1',
        userId: 'user-b',
        title: 'User B event 1',
      );
      await remember(
        eventId: 'event-3',
        userId: '',
        title: 'Signed out event',
      );
      await remember(
        eventId: 'event-1',
        userId: ' user-a ',
        title: 'Whitespace UID event',
      );

      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-1',
          userId: 'user-a',
        )?.title,
        'User A event 1',
      );
      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-2',
          userId: 'user-a',
        )?.title,
        'User A event 2',
      );
      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-1',
          userId: 'user-b',
        )?.title,
        'User B event 1',
      );
      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-3',
          userId: '',
        ),
        isNull,
      );
      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-1',
          userId: ' user-a ',
        )?.title,
        'Whitespace UID event',
      );
    });

    test('does not replace confirmed cache with local or pending snapshots',
        () async {
      final confirmed = _FakeEventDocumentSnapshot(
        reference: eventObjectRef('event-1'),
        data: eventDetailData(title: 'Confirmed title'),
      );
      final cached = _FakeEventDocumentSnapshot(
        reference: eventObjectRef('event-1'),
        data: eventDetailData(title: 'Local cached title'),
      );
      final pending = _FakeEventDocumentSnapshot(
        reference: eventObjectRef('event-1'),
        data: eventDetailData(title: 'Pending write title'),
      );

      final events = await EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => Stream<DocumentSnapshot>.fromIterable([
          confirmed,
          cached,
          pending,
        ]),
        snapshotIsFromCache: (snapshot) => identical(snapshot, cached),
        snapshotHasPendingWrites: (snapshot) => identical(snapshot, pending),
      ).toList();

      expect(
        events.map((event) => event?.title),
        ['Confirmed title', 'Local cached title', 'Pending write title'],
      );
      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-1',
          userId: 'user-a',
        )?.title,
        'Confirmed title',
      );
    });

    test('keeps last detail for local missing and clears on server missing',
        () async {
      await EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => Stream<DocumentSnapshot>.value(
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            data: eventDetailData(title: 'Confirmed title'),
          ),
        ),
      ).drain<void>();
      final cachedMissing = _FakeEventDocumentSnapshot(
        reference: eventObjectRef('event-1'),
        exists: false,
      );

      final cachedMissingEvents = await EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => Stream<DocumentSnapshot>.value(cachedMissing),
        snapshotIsFromCache: (snapshot) => identical(snapshot, cachedMissing),
      ).toList();

      expect(cachedMissingEvents, isEmpty);
      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-1',
          userId: 'user-a',
        )?.title,
        'Confirmed title',
      );

      final pendingMissing = _FakeEventDocumentSnapshot(
        reference: eventObjectRef('event-1'),
        exists: false,
      );
      final pendingMissingEvents = await EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => Stream<DocumentSnapshot>.value(pendingMissing),
        snapshotHasPendingWrites: (snapshot) =>
            identical(snapshot, pendingMissing),
      ).toList();

      expect(pendingMissingEvents, isEmpty);
      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-1',
          userId: 'user-a',
        )?.title,
        'Confirmed title',
      );

      final serverMissingEvents = await EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => Stream<DocumentSnapshot>.value(
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            exists: false,
          ),
        ),
      ).toList();

      expect(serverMissingEvents, <EventsRecord?>[null]);
      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-1',
          userId: 'user-a',
        ),
        isNull,
      );
    });

    test('stream errors preserve the last confirmed cached detail', () async {
      await EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => Stream<DocumentSnapshot>.value(
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            data: eventDetailData(title: 'Confirmed title'),
          ),
        ),
      ).drain<void>();

      await expectLater(
        EventDetailRepository.watchEventDetail(
          eventId: 'event-1',
          sessionCacheUserId: 'user-a',
          snapshotStream: (_) => Stream<DocumentSnapshot>.error(
            StateError('refresh failed'),
          ),
        ),
        emitsError(isA<StateError>()),
      );

      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-1',
          userId: 'user-a',
        )?.title,
        'Confirmed title',
      );
    });

    test('malformed snapshots do not replace the last confirmed cache',
        () async {
      await EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => Stream<DocumentSnapshot>.value(
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            data: eventDetailData(title: 'Confirmed title'),
          ),
        ),
      ).drain<void>();

      await expectLater(
        EventDetailRepository.watchEventDetail(
          eventId: 'event-1',
          sessionCacheUserId: 'user-a',
          snapshotStream: (_) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-1'),
            ),
          ),
        ),
        emitsError(anything),
      );

      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-1',
          userId: 'user-a',
        )?.title,
        'Confirmed title',
      );
    });

    test('provisional successors do not block a confirmed owner', () async {
      final ownerController = StreamController<DocumentSnapshot>(sync: true);
      final pendingController = StreamController<DocumentSnapshot>(sync: true);
      final ownerSubscription = EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => ownerController.stream,
      ).listen((_) {});

      try {
        ownerController.add(
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            data: eventDetailData(title: 'Confirmed owner title'),
          ),
        );
        await expectLater(
          EventDetailRepository.watchEventDetail(
            eventId: 'event-1',
            sessionCacheUserId: 'user-a',
            snapshotStream: (_) => Stream<DocumentSnapshot>.error(
              StateError('successor failed'),
            ),
          ),
          emitsError(isA<StateError>()),
        );
        await expectLater(
          EventDetailRepository.watchEventDetail(
            eventId: 'event-1',
            sessionCacheUserId: 'user-a',
            snapshotStream: (_) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventObjectRef('event-1'),
              ),
            ),
          ),
          emitsError(anything),
        );

        final cachedSnapshot = _FakeEventDocumentSnapshot(
          reference: eventObjectRef('event-1'),
          data: eventDetailData(title: 'Cache-only successor'),
        );
        await EventDetailRepository.watchEventDetail(
          eventId: 'event-1',
          sessionCacheUserId: 'user-a',
          snapshotStream: (_) => Stream<DocumentSnapshot>.value(cachedSnapshot),
          snapshotIsFromCache: (snapshot) =>
              identical(snapshot, cachedSnapshot),
        ).drain<void>();

        final pendingSnapshot = _FakeEventDocumentSnapshot(
          reference: eventObjectRef('event-1'),
          data: eventDetailData(title: 'Pending successor'),
        );
        await EventDetailRepository.watchEventDetail(
          eventId: 'event-1',
          sessionCacheUserId: 'user-a',
          snapshotStream: (_) => Stream<DocumentSnapshot>.value(
            pendingSnapshot,
          ),
          snapshotHasPendingWrites: (snapshot) =>
              identical(snapshot, pendingSnapshot),
        ).drain<void>();

        final pendingSubscription = EventDetailRepository.watchEventDetail(
          eventId: 'event-1',
          sessionCacheUserId: 'user-a',
          snapshotStream: (_) => pendingController.stream,
        ).listen((_) {});
        try {
          ownerController.add(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-1'),
              data: eventDetailData(title: 'Owner refresh title'),
            ),
          );
          expect(
            EventDetailRepository.cachedEventDetail(
              eventId: 'event-1',
              userId: 'user-a',
            )?.title,
            'Owner refresh title',
          );

          ownerController.add(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-1'),
              exists: false,
            ),
          );
          expect(
            EventDetailRepository.cachedEventDetail(
              eventId: 'event-1',
              userId: 'user-a',
            ),
            isNull,
          );
        } finally {
          await pendingSubscription.cancel();
        }
        ownerController.add(
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            data: eventDetailData(title: 'Owner title after cancel'),
          ),
        );
        expect(
          EventDetailRepository.cachedEventDetail(
            eventId: 'event-1',
            userId: 'user-a',
          )?.title,
          'Owner title after cancel',
        );
      } finally {
        await ownerSubscription.cancel();
        await ownerController.close();
        await pendingController.close();
      }
    });

    test('newest watcher wins before the older watcher first emits', () async {
      final firstController = StreamController<DocumentSnapshot>(sync: true);
      final secondController = StreamController<DocumentSnapshot>(sync: true);
      final firstSubscription = EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => firstController.stream,
      ).listen((_) {});

      try {
        final secondSubscription = EventDetailRepository.watchEventDetail(
          eventId: 'event-1',
          sessionCacheUserId: 'user-a',
          snapshotStream: (_) => secondController.stream,
        ).listen((_) {});
        try {
          firstController
            ..add(
              _FakeEventDocumentSnapshot(
                reference: eventObjectRef('event-1'),
                data: eventDetailData(title: 'Late stale title'),
              ),
            )
            ..add(
              _FakeEventDocumentSnapshot(
                reference: eventObjectRef('event-1'),
                exists: false,
              ),
            );
          expect(
            EventDetailRepository.cachedEventDetail(
              eventId: 'event-1',
              userId: 'user-a',
            ),
            isNull,
          );

          secondController.add(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-1'),
              data: eventDetailData(title: 'Current watcher title'),
            ),
          );
          firstController.add(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-1'),
              data: eventDetailData(title: 'Later stale title'),
            ),
          );

          expect(
            EventDetailRepository.cachedEventDetail(
              eventId: 'event-1',
              userId: 'user-a',
            )?.title,
            'Current watcher title',
          );
        } finally {
          await secondSubscription.cancel();
        }
      } finally {
        await firstSubscription.cancel();
        await firstController.close();
        await secondController.close();
      }
    });

    test('confirmed successor replaces and blocks the previous owner',
        () async {
      final ownerController = StreamController<DocumentSnapshot>(sync: true);
      final successorController =
          StreamController<DocumentSnapshot>(sync: true);
      final ownerSubscription = EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => ownerController.stream,
      ).listen((_) {});

      try {
        ownerController.add(
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            data: eventDetailData(title: 'Previous owner title'),
          ),
        );
        final successorSubscription = EventDetailRepository.watchEventDetail(
          eventId: 'event-1',
          sessionCacheUserId: 'user-a',
          snapshotStream: (_) => successorController.stream,
        ).listen((_) {});
        try {
          successorController.add(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-1'),
              data: eventDetailData(title: 'Confirmed successor title'),
            ),
          );
          ownerController
            ..add(
              _FakeEventDocumentSnapshot(
                reference: eventObjectRef('event-1'),
                data: eventDetailData(title: 'Late previous owner title'),
              ),
            )
            ..add(
              _FakeEventDocumentSnapshot(
                reference: eventObjectRef('event-1'),
                exists: false,
              ),
            );

          expect(
            EventDetailRepository.cachedEventDetail(
              eventId: 'event-1',
              userId: 'user-a',
            )?.title,
            'Confirmed successor title',
          );
        } finally {
          await successorSubscription.cancel();
        }
      } finally {
        await ownerSubscription.cancel();
        await ownerController.close();
        await successorController.close();
      }
    });

    test('cache reads keep watcher tokens aligned with LRU eviction', () async {
      final firstController = StreamController<DocumentSnapshot>(sync: true);
      final firstSubscription = EventDetailRepository.watchEventDetail(
        eventId: 'event-0',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => firstController.stream,
      ).listen((_) {});

      try {
        firstController.add(
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-0'),
            data: eventDetailData(title: 'First title'),
          ),
        );
        for (var index = 1; index <= 63; index += 1) {
          final eventId = 'event-$index';
          await EventDetailRepository.watchEventDetail(
            eventId: eventId,
            sessionCacheUserId: 'user-a',
            snapshotStream: (_) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventObjectRef(eventId),
                data: eventDetailData(title: 'Title $index'),
              ),
            ),
          ).drain<void>();
        }

        expect(
          EventDetailRepository.cachedEventDetail(
            eventId: 'event-0',
            userId: 'user-a',
          )?.title,
          'First title',
        );
        await EventDetailRepository.watchEventDetail(
          eventId: 'event-64',
          sessionCacheUserId: 'user-a',
          snapshotStream: (_) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-64'),
              data: eventDetailData(title: 'Title 64'),
            ),
          ),
        ).drain<void>();
        expect(
          EventDetailRepository.cachedEventDetail(
            eventId: 'event-1',
            userId: 'user-a',
          ),
          isNull,
        );

        firstController.add(
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-0'),
            data: eventDetailData(title: 'Updated first title'),
          ),
        );
        expect(
          EventDetailRepository.cachedEventDetail(
            eventId: 'event-0',
            userId: 'user-a',
          )?.title,
          'Updated first title',
        );
      } finally {
        await firstSubscription.cancel();
        await firstController.close();
      }
    });

    test('provisional watchers do not evict confirmed LRU entries', () async {
      for (var index = 0; index < 64; index += 1) {
        final eventId = 'confirmed-$index';
        await EventDetailRepository.watchEventDetail(
          eventId: eventId,
          sessionCacheUserId: 'user-a',
          snapshotStream: (_) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef(eventId),
              data: eventDetailData(title: 'Confirmed $index'),
            ),
          ),
        ).drain<void>();
      }

      for (var index = 0; index < 65; index += 1) {
        await EventDetailRepository.watchEventDetail(
          eventId: 'provisional-$index',
          sessionCacheUserId: 'user-a',
          snapshotStream: (_) => const Stream<DocumentSnapshot>.empty(),
        ).drain<void>();
      }

      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'confirmed-0',
          userId: 'user-a',
        )?.title,
        'Confirmed 0',
      );
      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'confirmed-63',
          userId: 'user-a',
        )?.title,
        'Confirmed 63',
      );
    });

    test('auth changes clear cache and reject late writes from old sessions',
        () async {
      UxSessionCacheLifecycle.updateAuthenticatedUser('user-a');
      final controller = StreamController<DocumentSnapshot>(sync: true);
      final subscription = EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => controller.stream,
      ).listen((_) {});

      try {
        controller.add(
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            data: eventDetailData(title: 'User A title'),
          ),
        );
        expect(
          EventDetailRepository.cachedEventDetail(
            eventId: 'event-1',
            userId: 'user-a',
          )?.title,
          'User A title',
        );

        UxSessionCacheLifecycle.updateAuthenticatedUser('user-b');
        expect(
          EventDetailRepository.cachedEventDetail(
            eventId: 'event-1',
            userId: 'user-a',
          ),
          isNull,
        );

        controller.add(
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            data: eventDetailData(title: 'Late user A title'),
          ),
        );
        expect(
          EventDetailRepository.cachedEventDetail(
            eventId: 'event-1',
            userId: 'user-a',
          ),
          isNull,
        );

        UxSessionCacheLifecycle.updateAuthenticatedUser(null);
        expect(
          EventDetailRepository.cachedEventDetail(
            eventId: 'event-1',
            userId: 'user-b',
          ),
          isNull,
        );
      } finally {
        await subscription.cancel();
        await controller.close();
      }
    });

    test('auth change rejects a watcher before its first snapshot', () async {
      UxSessionCacheLifecycle.updateAuthenticatedUser('user-a');
      final controller = StreamController<DocumentSnapshot>(sync: true);
      final subscription = EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => controller.stream,
      ).listen((_) {});

      try {
        UxSessionCacheLifecycle.updateAuthenticatedUser('user-b');
        controller
          ..add(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-1'),
              data: eventDetailData(title: 'Late user A title'),
            ),
          )
          ..add(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-1'),
              exists: false,
            ),
          );

        expect(
          EventDetailRepository.cachedEventDetail(
            eventId: 'event-1',
            userId: 'user-a',
          ),
          isNull,
        );
      } finally {
        await subscription.cancel();
        await controller.close();
      }
    });

    test('rejects mismatched snapshot references without poisoning cache',
        () async {
      await expectLater(
        EventDetailRepository.watchEventDetail(
          eventId: 'event-1',
          sessionCacheUserId: 'user-a',
          snapshotStream: (_) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-2'),
              data: eventDetailData(title: 'Wrong event'),
            ),
          ),
        ),
        emitsError(isA<StateError>()),
      );

      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-1',
          userId: 'user-a',
        ),
        isNull,
      );
    });

    test('supports scoped invalidation and full session cache clear', () async {
      for (final eventId in ['event-1', 'event-2']) {
        await EventDetailRepository.watchEventDetail(
          eventId: eventId,
          sessionCacheUserId: 'user-a',
          snapshotStream: (_) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef(eventId),
              data: eventDetailData(title: eventId),
            ),
          ),
        ).drain<void>();
      }

      EventDetailRepository.invalidateCachedEventDetail(
        eventId: 'event-1',
        userId: 'user-a',
      );
      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-1',
          userId: 'user-a',
        ),
        isNull,
      );
      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-2',
          userId: 'user-a',
        ),
        isNotNull,
      );

      EventDetailRepository.clearEventDetailSessionCache();
      expect(
        EventDetailRepository.cachedEventDetail(
          eventId: 'event-2',
          userId: 'user-a',
        ),
        isNull,
      );
    });

    test('invalidation and clear reject late writes from active watchers',
        () async {
      final firstController = StreamController<DocumentSnapshot>(sync: true);
      final secondController = StreamController<DocumentSnapshot>(sync: true);
      final firstSubscription = EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => firstController.stream,
      ).listen((_) {});

      try {
        firstController.add(
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            data: eventDetailData(title: 'Before invalidate'),
          ),
        );
        EventDetailRepository.invalidateCachedEventDetail(
          eventId: 'event-1',
          userId: 'user-a',
        );
        firstController.add(
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            data: eventDetailData(title: 'After invalidate'),
          ),
        );
        expect(
          EventDetailRepository.cachedEventDetail(
            eventId: 'event-1',
            userId: 'user-a',
          ),
          isNull,
        );

        final secondSubscription = EventDetailRepository.watchEventDetail(
          eventId: 'event-1',
          sessionCacheUserId: 'user-a',
          snapshotStream: (_) => secondController.stream,
        ).listen((_) {});
        try {
          secondController.add(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-1'),
              data: eventDetailData(title: 'Before clear'),
            ),
          );
          EventDetailRepository.clearEventDetailSessionCache();
          secondController.add(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-1'),
              data: eventDetailData(title: 'After clear'),
            ),
          );
          expect(
            EventDetailRepository.cachedEventDetail(
              eventId: 'event-1',
              userId: 'user-a',
            ),
            isNull,
          );
        } finally {
          await secondSubscription.cancel();
        }
      } finally {
        await firstSubscription.cancel();
        await firstController.close();
        await secondController.close();
      }
    });

    test('invalidation and clear reject watchers before first snapshot',
        () async {
      final invalidatedController =
          StreamController<DocumentSnapshot>(sync: true);
      final clearedController = StreamController<DocumentSnapshot>(sync: true);
      final invalidatedSubscription = EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        sessionCacheUserId: 'user-a',
        snapshotStream: (_) => invalidatedController.stream,
      ).listen((_) {});

      try {
        EventDetailRepository.invalidateCachedEventDetail(
          eventId: 'event-1',
          userId: 'user-a',
        );
        invalidatedController
          ..add(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-1'),
              data: eventDetailData(title: 'After early invalidate'),
            ),
          )
          ..add(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-1'),
              exists: false,
            ),
          );
        expect(
          EventDetailRepository.cachedEventDetail(
            eventId: 'event-1',
            userId: 'user-a',
          ),
          isNull,
        );

        final clearedSubscription = EventDetailRepository.watchEventDetail(
          eventId: 'event-2',
          sessionCacheUserId: 'user-a',
          snapshotStream: (_) => clearedController.stream,
        ).listen((_) {});
        try {
          EventDetailRepository.clearEventDetailSessionCache();
          clearedController
            ..add(
              _FakeEventDocumentSnapshot(
                reference: eventObjectRef('event-2'),
                data: eventDetailData(title: 'After early clear'),
              ),
            )
            ..add(
              _FakeEventDocumentSnapshot(
                reference: eventObjectRef('event-2'),
                exists: false,
              ),
            );
          expect(
            EventDetailRepository.cachedEventDetail(
              eventId: 'event-2',
              userId: 'user-a',
            ),
            isNull,
          );
        } finally {
          await clearedSubscription.cancel();
        }
      } finally {
        await invalidatedSubscription.cancel();
        await invalidatedController.close();
        await clearedController.close();
      }
    });

    test('watches the current user participant document', () async {
      DocumentReference? capturedParticipantRef;

      final participants =
          await EventDetailRepository.watchCurrentUserParticipant(
        eventId: ' event-1 ',
        userId: ' uid-1 ',
        snapshotStream: (participantRef) {
          capturedParticipantRef = participantRef;
          return Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: participantObjectRef('event-1', 'uid-1'),
              data: participantData(
                userId: 'uid-1',
                status: 'active',
              ),
            ),
          );
        },
      ).toList();

      expect(capturedParticipantRef?.path, 'events/event-1/participants/uid-1');
      expect(participants, hasLength(1));
      expect(participants.single?.reference.path,
          'events/event-1/participants/uid-1');
      expect(participants.single?.userId, 'uid-1');
      expect(participants.single?.status, 'active');
    });

    test('emits null when the current user participant document is missing',
        () async {
      final participants =
          await EventDetailRepository.watchCurrentUserParticipant(
        eventId: 'event-1',
        userId: 'uid-1',
        snapshotStream: (_) => Stream<DocumentSnapshot>.value(
          _FakeEventDocumentSnapshot(
            reference: participantObjectRef('event-1', 'uid-1'),
            exists: false,
          ),
        ),
      ).toList();

      expect(participants, <EventParticipantsRecord?>[null]);
    });

    test('watches active participants and normalizes known records', () async {
      DocumentReference? capturedEventRef;

      final participants = await EventDetailRepository.watchActiveParticipants(
        eventId: ' event-1 ',
        participantsStream: (eventRef) {
          capturedEventRef = eventRef;
          return Stream<List<EventParticipantsRecord>>.value([
            EventParticipantsRecord.getDocumentFromData(
              participantData(
                userId: 'left-user',
                status: 'left',
                displayName: 'Left User',
              ),
              participantObjectRef('event-1', 'left-user'),
            ),
            EventParticipantsRecord.getDocumentFromData(
              participantData(
                userId: 'second-user',
                status: 'active',
                displayName: 'Second User',
                joinedAt: DateTime.utc(2026, 6, 14, 12, 2),
              ),
              participantObjectRef('event-1', 'second-user'),
            ),
            EventParticipantsRecord.getDocumentFromData(
              participantData(
                userId: 'first-user',
                status: 'active',
                displayName: 'First User',
                joinedAt: DateTime.utc(2026, 6, 14, 12),
              ),
              participantObjectRef('event-1', 'first-user'),
            ),
          ]);
        },
      ).toList();

      expect(capturedEventRef?.path, 'events/event-1');
      expect(participants, hasLength(1));
      expect(
        participants.single.map((participant) => participant.userId),
        ['first-user', 'second-user'],
      );
    });

    test('active participants query satisfies Firestore read rules', () {
      final query = EventDetailRepository.activeParticipantsQuery(
        eventObjectRef('event-1'),
      );
      final where = query.parameters['where'] as List<dynamic>;

      expect(where, hasLength(1));
      expect(where.single, [
        FieldPath.fromString('status'),
        '==',
        'active',
      ]);
      expect(query.parameters['limit'], eventActiveParticipantsReadLimit);
      expect(query.parameters['orderBy'], isEmpty);
    });

    test('active participants preview uses a bounded index-free query', () {
      final query = EventDetailRepository.activeParticipantsQuery(
        eventObjectRef('event-1'),
        limit: 6,
      );

      expect(query.parameters['limit'], 6);
      expect(query.parameters['orderBy'], isEmpty);
    });

    test('active participants query rejects limits forbidden by rules', () {
      expect(
        () => EventDetailRepository.activeParticipantsQuery(
          eventObjectRef('event-1'),
          limit: eventActiveParticipantsReadLimit + 1,
        ),
        throwsRangeError,
      );
    });
  });
}

Map<String, dynamic> eventDetailData({
  required String title,
  String status = 'active',
}) =>
    <String, dynamic>{
      'title': title,
      'description': 'Casual practice',
      'languageCode': 'en',
      'levelMin': 'B1',
      'levelMax': 'C1',
      'status': status,
    };

DocumentReference<Object?> eventObjectRef(String eventId) =>
    FirebaseFirestore.instance.doc('events/$eventId').withConverter<Object?>(
          fromFirestore: (snapshot, _) => snapshot.data(),
          toFirestore: (value, _) {
            if (value is Map<String, Object?>) {
              return value;
            }
            return const <String, Object?>{};
          },
        );

DocumentReference<Object?> participantObjectRef(
        String eventId, String userId) =>
    FirebaseFirestore.instance
        .doc('events/$eventId/participants/$userId')
        .withConverter<Object?>(
          fromFirestore: (snapshot, _) => snapshot.data(),
          toFirestore: (value, _) {
            if (value is Map<String, Object?>) {
              return value;
            }
            return const <String, Object?>{};
          },
        );

Map<String, dynamic> participantData({
  required String userId,
  required String status,
  String displayName = 'Participant',
  String? photoUrl,
  DateTime? joinedAt,
}) =>
    <String, dynamic>{
      'userId': userId,
      'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'role': 'participant',
      'status': status,
      if (joinedAt != null) 'joinedAt': joinedAt,
    };

// ignore: subtype_of_sealed_class
class _FakeEventDocumentSnapshot implements DocumentSnapshot<Object?> {
  _FakeEventDocumentSnapshot({
    required this.reference,
    this.exists = true,
    Map<String, dynamic>? data,
  }) : _data = data;

  final Map<String, dynamic>? _data;

  @override
  final bool exists;

  @override
  final DocumentReference<Object?> reference;

  @override
  String get id => reference.id;

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  Object? data() => _data;

  @override
  Object? get(Object field) => _data?[field];

  @override
  Object? operator [](Object field) => get(field);
}
