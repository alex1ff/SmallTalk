import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/services/event_list_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
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
