import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';
import 'package:small_talk/services/event_level_helper.dart';
import 'package:small_talk/services/event_list_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    initializeEventListTimeZones();
  });

  group('EventListRepository', () {
    final lowerBoundUtc = DateTime.parse('2026-06-18T00:00:00Z');
    final upperBoundUtc = DateTime.parse('2026-06-19T00:00:00Z');

    test('normalizes active event list query input', () {
      final spec = EventListRepository.normalizeActiveEventListQuery(
        countryCode: ' ru ',
        cityKey: 'moscow',
        lowerBoundUtc: lowerBoundUtc,
        upperBoundUtc: upperBoundUtc,
        pageSize: 20,
      );

      expect(spec.countryCode, 'RU');
      expect(spec.cityKey, 'moscow');
      expect(spec.lowerBoundUtc, lowerBoundUtc);
      expect(spec.upperBoundUtc, upperBoundUtc);
      expect(spec.pageSize, 20);
    });

    test('rejects invalid query input before hitting Firestore', () {
      expect(
        () => EventListRepository.normalizeActiveEventListQuery(
          countryCode: 'Russia',
          cityKey: 'moscow',
          lowerBoundUtc: lowerBoundUtc,
          upperBoundUtc: upperBoundUtc,
          pageSize: 20,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => EventListRepository.normalizeActiveEventListQuery(
          countryCode: 'RU',
          cityKey: 'Moscow',
          lowerBoundUtc: lowerBoundUtc,
          upperBoundUtc: upperBoundUtc,
          pageSize: 20,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => EventListRepository.normalizeActiveEventListQuery(
          countryCode: 'RU',
          cityKey: 'moscow',
          lowerBoundUtc: DateTime(2026, 6, 18),
          upperBoundUtc: upperBoundUtc,
          pageSize: 20,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => EventListRepository.normalizeActiveEventListQuery(
          countryCode: 'RU',
          cityKey: 'moscow',
          lowerBoundUtc: upperBoundUtc,
          upperBoundUtc: lowerBoundUtc,
          pageSize: 20,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => EventListRepository.normalizeActiveEventListQuery(
          countryCode: 'RU',
          cityKey: 'moscow',
          lowerBoundUtc: lowerBoundUtc,
          upperBoundUtc: upperBoundUtc,
          pageSize: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('builds exact raw active event list query', () {
      final query = EventListRepository.buildActiveEventListQuery(
        EventsRecord.collection,
        countryCode: 'ru',
        cityKey: 'moscow',
        lowerBoundUtc: lowerBoundUtc,
        upperBoundUtc: upperBoundUtc,
      );
      final where = query.parameters['where'] as List<dynamic>;
      final orderBy = query.parameters['orderBy'] as List<dynamic>;

      expect(where, hasLength(5));
      expectWhereCondition(where, 'status', '==', activeEventStatus);
      expectWhereCondition(where, 'countryCode', '==', 'RU');
      expectWhereCondition(where, 'cityKey', '==', 'moscow');
      expectWhereCondition(where, 'startsAt', '>=', lowerBoundUtc);
      expectWhereCondition(where, 'startsAt', '<', upperBoundUtc);
      expect(orderBy, hasLength(1));
      expect(orderBy.single, [FieldPath.fromString('startsAt'), false]);
      expect(query.parameters['limit'], isNull);
      expect(query.parameters['startAfter'], isNull);
    });

    test('delegates raw page loading through the shared page helper', () async {
      Query? capturedCollection;
      RecordBuilder<EventsRecord>? capturedRecordBuilder;
      Query Function(Query)? capturedQueryBuilder;
      DocumentSnapshot? capturedNextPageMarker;
      int? capturedPageSize;
      bool? capturedIsStream;
      final marker = _FakeDocumentSnapshot();

      final page = await EventListRepository.loadRawActiveEventPage(
        countryCode: ' ru ',
        cityKey: 'moscow',
        lowerBoundUtc: lowerBoundUtc,
        upperBoundUtc: upperBoundUtc,
        pageSize: 5,
        nextPageMarker: marker,
        pageLoader: (
          collection,
          recordBuilder, {
          queryBuilder,
          nextPageMarker,
          required pageSize,
          required isStream,
        }) async {
          capturedCollection = collection;
          capturedRecordBuilder = recordBuilder;
          capturedQueryBuilder = queryBuilder;
          capturedNextPageMarker = nextPageMarker;
          capturedPageSize = pageSize;
          capturedIsStream = isStream;

          return FFFirestorePage<EventsRecord>(const [], null, null);
        },
      );

      expect((capturedCollection as CollectionReference).path, 'events');
      expect(capturedRecordBuilder, isNotNull);
      expect(capturedQueryBuilder, isNotNull);
      expect(capturedNextPageMarker, same(marker));
      expect(capturedPageSize, 5);
      expect(capturedIsStream, isFalse);
      expect(page.data, isEmpty);

      final delegatedQuery = capturedQueryBuilder!(EventsRecord.collection);
      final delegatedWhere =
          delegatedQuery.parameters['where'] as List<dynamic>;
      expectWhereCondition(delegatedWhere, 'countryCode', '==', 'RU');
      expectWhereCondition(delegatedWhere, 'cityKey', '==', 'moscow');
    });

    test('connects selected city date bounds to the raw Firestore query',
        () async {
      Query Function(Query)? capturedQueryBuilder;

      await EventListRepository.loadRawActiveEventPageForDateRange(
        countryCode: 'US',
        cityKey: 'new_york',
        timeZoneId: 'America/New_York',
        localDateRange: eventListSingleLocalDateRange(DateTime(2026, 3, 8)),
        nowUtc: DateTime.parse('2026-03-01T00:00:00Z'),
        pageSize: 5,
        pageLoader: (
          collection,
          recordBuilder, {
          queryBuilder,
          nextPageMarker,
          required pageSize,
          required isStream,
        }) async {
          capturedQueryBuilder = queryBuilder;
          return FFFirestorePage<EventsRecord>(const [], null, null);
        },
      );

      final query = capturedQueryBuilder!(EventsRecord.collection);
      final where = query.parameters['where'] as List<dynamic>;

      expectWhereCondition(where, 'status', '==', activeEventStatus);
      expectWhereCondition(where, 'countryCode', '==', 'US');
      expectWhereCondition(where, 'cityKey', '==', 'new_york');
      expectWhereCondition(
        where,
        'startsAt',
        '>=',
        DateTime.parse('2026-03-08T05:00:00Z'),
      );
      expectWhereCondition(
        where,
        'startsAt',
        '<',
        DateTime.parse('2026-03-09T04:00:00Z'),
      );
    });

    test('filters event level ranges inclusively after raw fetch', () {
      final filtered = EventListRepository.filterEventsBySelectedLevel(
        [
          eventFixture('a1-only', levelMin: 'A1', levelMax: 'A1'),
          eventFixture('a2-b1', levelMin: 'A2', levelMax: 'B1'),
          eventFixture('b2-c1', levelMin: 'B2', levelMax: 'C1'),
          eventFixture('c2-only', levelMin: 'C2', levelMax: 'C2'),
        ],
        selectedRange: eventLevelRange(levelMin: ' b1 ', levelMax: ' b1 '),
      );

      expect(eventIds(filtered), ['a2-b1']);
      expect(
        eventLevelRange(levelMin: 'B1', levelMax: 'B2').overlaps(
          eventLevelRange(levelMin: 'B2', levelMax: 'C1'),
        ),
        isTrue,
      );
    });

    test('rejects invalid selected level filters', () {
      expect(
        () => EventListRepository.filterRawActiveEventPageByLevel(
          FFFirestorePage<EventsRecord>(const [], null, null),
          selectedLevel: 'D1',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('hides invalid event levels without failing the list', () {
      final filtered = EventListRepository.filterEventsBySelectedLevel(
        [
          eventFixture('valid', levelMin: 'B1', levelMax: 'C1'),
          eventFixture('unknown', levelMin: 'B1', levelMax: 'D1'),
          eventFixture('reversed', levelMin: 'C1', levelMax: 'B1'),
          eventFixture('missing-min', levelMax: 'C1'),
        ],
        selectedRange: eventLevelRange(levelMin: 'B2', levelMax: 'B2'),
      );

      expect(eventIds(filtered), ['valid']);
    });

    test('does not filter by levels when selected level is empty', () {
      final rawEvents = [
        eventFixture('valid', levelMin: 'B1', levelMax: 'C1'),
        eventFixture('unknown', levelMin: 'B1', levelMax: 'D1'),
        eventFixture('reversed', levelMin: 'C1', levelMax: 'B1'),
        eventFixture('missing-min', levelMax: 'C1'),
      ];

      expect(
        eventIds(EventListRepository.filterEventsBySelectedLevel(rawEvents)),
        ['valid', 'unknown', 'reversed', 'missing-min'],
      );
      expect(
        eventIds(
          EventListRepository.filterRawActiveEventPageByLevel(
            FFFirestorePage<EventsRecord>(rawEvents, null, null),
            selectedLevel: ' ',
          ).data,
        ),
        ['valid', 'unknown', 'reversed', 'missing-min'],
      );
      expect(
        eventIds(
          EventListRepository.filterRawActiveEventPageByLevel(
            FFFirestorePage<EventsRecord>(rawEvents, null, null),
          ).data,
        ),
        ['valid', 'unknown', 'reversed', 'missing-min'],
      );
    });

    test('filters a raw page while preserving raw cursor and raw order', () {
      final marker = _FakeQueryDocumentSnapshot();
      final page = EventListRepository.filterRawActiveEventPageByLevel(
        FFFirestorePage<EventsRecord>(
          [
            eventFixture('hidden-low', levelMin: 'A1', levelMax: 'A2'),
            eventFixture('visible-first', levelMin: 'B1', levelMax: 'C1'),
            eventFixture('invalid', levelMin: 'C2', levelMax: 'B1'),
            eventFixture('visible-second', levelMin: 'B2', levelMax: 'B2'),
          ],
          null,
          marker,
        ),
        selectedLevel: ' b2 ',
      );

      expect(eventIds(page.data), ['visible-first', 'visible-second']);
      expect(page.nextPageMarker, same(marker));
    });

    test('loads one level-filtered page without adding level Firestore filters',
        () async {
      Query Function(Query)? capturedQueryBuilder;

      final page = await EventListRepository.loadLevelFilteredActiveEventPage(
        countryCode: 'RU',
        cityKey: 'moscow',
        lowerBoundUtc: lowerBoundUtc,
        upperBoundUtc: upperBoundUtc,
        pageSize: 5,
        selectedLevel: 'C1',
        pageLoader: (
          collection,
          recordBuilder, {
          queryBuilder,
          nextPageMarker,
          required pageSize,
          required isStream,
        }) async {
          capturedQueryBuilder = queryBuilder;
          return FFFirestorePage<EventsRecord>(
            [
              eventFixture('hidden', levelMin: 'A1', levelMax: 'B2'),
              eventFixture('visible', levelMin: 'B2', levelMax: 'C2'),
            ],
            null,
            null,
          );
        },
      );

      expect(eventIds(page.data), ['visible']);
      final query = capturedQueryBuilder!(EventsRecord.collection);
      final where = query.parameters['where'] as List<dynamic>;
      expect(where, hasLength(5));
      expectWhereCondition(where, 'startsAt', '>=', lowerBoundUtc);
      expectWhereCondition(where, 'startsAt', '<', upperBoundUtc);
      expectNoWhereCondition(where, 'levelMin');
      expectNoWhereCondition(where, 'levelMax');
    });

    test('continues raw pages until enough visible level matches are collected',
        () async {
      final initialMarker = _FakeDocumentSnapshot();
      final marker1 = _FakeQueryDocumentSnapshot();
      final marker2 = _FakeQueryDocumentSnapshot();
      final marker3 = _FakeQueryDocumentSnapshot();
      final receivedCursors = <DocumentSnapshot?>[];
      final rawPages = <FFFirestorePage<EventsRecord>>[
        FFFirestorePage<EventsRecord>(
          [eventFixture('hidden-low', levelMin: 'A1', levelMax: 'A2')],
          null,
          marker1,
        ),
        FFFirestorePage<EventsRecord>(
          [
            eventFixture('invalid', levelMin: 'C1', levelMax: 'B1'),
            eventFixture('visible-first', levelMin: 'B1', levelMax: 'B2'),
          ],
          null,
          marker2,
        ),
        FFFirestorePage<EventsRecord>(
          [
            eventFixture('visible-second', levelMin: 'B2', levelMax: 'C1'),
            eventFixture('hidden-trailing', levelMin: 'C2', levelMax: 'C2'),
          ],
          null,
          marker3,
        ),
      ];
      var rawPageIndex = 0;

      final page = await EventListRepository.loadLevelFilteredActiveEventPage(
        countryCode: 'RU',
        cityKey: 'moscow',
        lowerBoundUtc: lowerBoundUtc,
        upperBoundUtc: upperBoundUtc,
        pageSize: 2,
        selectedLevel: 'B2',
        nextPageMarker: initialMarker,
        pageLoader: (
          collection,
          recordBuilder, {
          queryBuilder,
          nextPageMarker,
          required pageSize,
          required isStream,
        }) async {
          receivedCursors.add(nextPageMarker);
          return rawPages[rawPageIndex++];
        },
      );

      expect(eventIds(page.data), ['visible-first', 'visible-second']);
      expect(page.nextPageMarker, same(marker3));
      expect(receivedCursors, hasLength(3));
      expect(receivedCursors[0], same(initialMarker));
      expect(receivedCursors[1], same(marker1));
      expect(receivedCursors[2], same(marker2));
      expect(rawPageIndex, 3);
    });

    test('stops when raw query is exhausted before enough level matches',
        () async {
      final marker1 = _FakeQueryDocumentSnapshot();
      final rawPages = <FFFirestorePage<EventsRecord>>[
        FFFirestorePage<EventsRecord>(
          [eventFixture('hidden-low', levelMin: 'A1', levelMax: 'A2')],
          null,
          marker1,
        ),
        FFFirestorePage<EventsRecord>(const [], null, null),
      ];
      var rawPageIndex = 0;

      final page = await EventListRepository.loadLevelFilteredActiveEventPage(
        countryCode: 'RU',
        cityKey: 'moscow',
        lowerBoundUtc: lowerBoundUtc,
        upperBoundUtc: upperBoundUtc,
        pageSize: 2,
        selectedLevel: 'B2',
        pageLoader: (
          collection,
          recordBuilder, {
          queryBuilder,
          nextPageMarker,
          required pageSize,
          required isStream,
        }) async =>
            rawPages[rawPageIndex++],
      );

      expect(page.data, isEmpty);
      expect(page.nextPageMarker, isNull);
      expect(rawPageIndex, 2);
    });

    test('keeps overfilled visible page so filtered events are not skipped',
        () async {
      final marker = _FakeQueryDocumentSnapshot();
      var rawPageLoads = 0;

      final page = await EventListRepository.loadLevelFilteredActiveEventPage(
        countryCode: 'RU',
        cityKey: 'moscow',
        lowerBoundUtc: lowerBoundUtc,
        upperBoundUtc: upperBoundUtc,
        pageSize: 1,
        selectedLevel: 'B2',
        pageLoader: (
          collection,
          recordBuilder, {
          queryBuilder,
          nextPageMarker,
          required pageSize,
          required isStream,
        }) async {
          rawPageLoads += 1;
          return FFFirestorePage<EventsRecord>(
            [
              eventFixture('visible-first', levelMin: 'B1', levelMax: 'B2'),
              eventFixture('visible-second', levelMin: 'B2', levelMax: 'C1'),
            ],
            null,
            marker,
          );
        },
      );

      expect(eventIds(page.data), ['visible-first', 'visible-second']);
      expect(page.nextPageMarker, same(marker));
      expect(rawPageLoads, 1);
    });

    test('does not fetch additional raw pages without a selected level',
        () async {
      final marker = _FakeQueryDocumentSnapshot();
      var rawPageLoads = 0;

      final page = await EventListRepository.loadLevelFilteredActiveEventPage(
        countryCode: 'RU',
        cityKey: 'moscow',
        lowerBoundUtc: lowerBoundUtc,
        upperBoundUtc: upperBoundUtc,
        pageSize: 5,
        selectedLevel: ' ',
        pageLoader: (
          collection,
          recordBuilder, {
          queryBuilder,
          nextPageMarker,
          required pageSize,
          required isStream,
        }) async {
          rawPageLoads += 1;
          return FFFirestorePage<EventsRecord>(
            [
              eventFixture('raw-first', levelMin: 'B1', levelMax: 'C1'),
              eventFixture('raw-invalid', levelMin: 'C1', levelMax: 'B1'),
            ],
            null,
            marker,
          );
        },
      );

      expect(eventIds(page.data), ['raw-first', 'raw-invalid']);
      expect(page.nextPageMarker, same(marker));
      expect(rawPageLoads, 1);
    });

    test('rejects invalid selected level before loading raw pages', () async {
      var rawPageLoads = 0;

      await expectLater(
        EventListRepository.loadLevelFilteredActiveEventPage(
          countryCode: 'RU',
          cityKey: 'moscow',
          lowerBoundUtc: lowerBoundUtc,
          upperBoundUtc: upperBoundUtc,
          pageSize: 5,
          selectedLevel: 'D1',
          pageLoader: (
            collection,
            recordBuilder, {
            queryBuilder,
            nextPageMarker,
            required pageSize,
            required isStream,
          }) async {
            rawPageLoads += 1;
            return FFFirestorePage<EventsRecord>(const [], null, null);
          },
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(rawPageLoads, 0);
    });

    test('combines date-range bounds and level filtering for one raw page',
        () async {
      Query Function(Query)? capturedQueryBuilder;

      final page = await EventListRepository
          .loadLevelFilteredActiveEventPageForDateRange(
        countryCode: 'US',
        cityKey: 'new_york',
        timeZoneId: 'America/New_York',
        localDateRange: eventListSingleLocalDateRange(DateTime(2026, 3, 8)),
        nowUtc: DateTime.parse('2026-03-01T00:00:00Z'),
        pageSize: 5,
        selectedLevel: 'B2',
        pageLoader: (
          collection,
          recordBuilder, {
          queryBuilder,
          nextPageMarker,
          required pageSize,
          required isStream,
        }) async {
          capturedQueryBuilder = queryBuilder;
          return FFFirestorePage<EventsRecord>(
            [
              eventFixture('visible', levelMin: 'B1', levelMax: 'C1'),
              eventFixture('hidden', levelMin: 'C2', levelMax: 'C2'),
            ],
            null,
            null,
          );
        },
      );

      expect(eventIds(page.data), ['visible']);
      final query = capturedQueryBuilder!(EventsRecord.collection);
      final where = query.parameters['where'] as List<dynamic>;
      expectWhereCondition(
        where,
        'startsAt',
        '>=',
        DateTime.parse('2026-03-08T05:00:00Z'),
      );
      expectWhereCondition(
        where,
        'startsAt',
        '<',
        DateTime.parse('2026-03-09T04:00:00Z'),
      );
      expectNoWhereCondition(where, 'levelMin');
      expectNoWhereCondition(where, 'levelMax');
    });
  });
}

void expectWhereCondition(
  List<dynamic> conditions,
  String field,
  String operator,
  Object? value,
) {
  final expectedField = FieldPath.fromString(field);
  final hasCondition = conditions.any(
    (condition) =>
        condition is List<dynamic> &&
        condition.length == 3 &&
        condition[0] == expectedField &&
        condition[1] == operator &&
        condition[2] == value,
  );

  expect(
    hasCondition,
    isTrue,
    reason: 'Expected where($field $operator $value).',
  );
}

void expectNoWhereCondition(List<dynamic> conditions, String field) {
  final expectedField = FieldPath.fromString(field);
  final hasCondition = conditions.any(
    (condition) =>
        condition is List<dynamic> &&
        condition.isNotEmpty &&
        condition[0] == expectedField,
  );

  expect(
    hasCondition,
    isFalse,
    reason: 'Expected no where($field ...).',
  );
}

EventsRecord eventFixture(
  String id, {
  String? levelMin,
  String? levelMax,
}) {
  return EventsRecord.getDocumentFromData(
    {
      if (levelMin != null) 'levelMin': levelMin,
      if (levelMax != null) 'levelMax': levelMax,
    },
    EventsRecord.collection.doc(id),
  );
}

List<String> eventIds(Iterable<EventsRecord> events) =>
    events.map((event) => event.reference.id).toList(growable: false);

// Test-only cursor token used to verify that the injected page loader receives
// the exact marker instance. It is never passed to the real Firestore SDK.
// ignore: subtype_of_sealed_class
class _FakeDocumentSnapshot implements DocumentSnapshot<Object?> {
  @override
  String get id => 'cursor';

  @override
  bool get exists => true;

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  DocumentReference<Object?> get reference => throw UnimplementedError();

  @override
  Object? data() => const <String, Object?>{};

  @override
  Object? get(Object field) => throw UnimplementedError();

  @override
  Object? operator [](Object field) => get(field);
}

// ignore: subtype_of_sealed_class
class _FakeQueryDocumentSnapshot implements QueryDocumentSnapshot<Object?> {
  @override
  String get id => 'query-cursor';

  @override
  bool get exists => true;

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  DocumentReference<Object?> get reference => throw UnimplementedError();

  @override
  Object? data() => const <String, Object?>{};

  @override
  Object? get(Object field) => throw UnimplementedError();

  @override
  Object? operator [](Object field) => get(field);
}
