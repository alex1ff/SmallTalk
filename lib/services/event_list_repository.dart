import '/backend/backend.dart';
import 'event_list_date_bounds.dart';
import 'event_city_catalog.dart';
import 'event_level_helper.dart';

const activeEventStatus = 'active';

typedef EventListPageLoader = Future<FFFirestorePage<EventsRecord>> Function(
  Query collection,
  RecordBuilder<EventsRecord> recordBuilder, {
  Query Function(Query)? queryBuilder,
  DocumentSnapshot? nextPageMarker,
  required int pageSize,
  required bool isStream,
});

class EventListFirestorePage extends FFFirestorePage<EventsRecord> {
  EventListFirestorePage(
    super.data,
    super.dataStream,
    super.nextPageMarker, {
    required this.hasMore,
  });

  final bool hasMore;
}

class EventListQuerySpec {
  const EventListQuerySpec({
    required this.countryCode,
    required this.cityKey,
    required this.lowerBoundUtc,
    required this.upperBoundUtc,
    required this.pageSize,
  });

  final String countryCode;
  final String cityKey;
  final DateTime lowerBoundUtc;
  final DateTime upperBoundUtc;
  final int pageSize;
}

class _EventListQueryScope {
  const _EventListQueryScope({
    required this.countryCode,
    required this.cityKey,
    required this.lowerBoundUtc,
    required this.upperBoundUtc,
  });

  final String countryCode;
  final String cityKey;
  final DateTime lowerBoundUtc;
  final DateTime upperBoundUtc;
}

class EventListRepository {
  const EventListRepository._();

  static CollectionReference get _publicEventsCollection =>
      FirebaseFirestore.instance.collection('events_public');

  static bool pageHasMore(FFFirestorePage<EventsRecord> page) =>
      page is EventListFirestorePage
          ? page.hasMore
          : page.nextPageMarker != null;

  static EventsRecord _publicEventFromSnapshot(DocumentSnapshot snapshot) =>
      EventsRecord.getDocumentFromData(
        snapshot.data() as Map<String, dynamic>,
        EventsRecord.collection.doc(snapshot.id),
      );

  static EventListQuerySpec normalizeActiveEventListQuery({
    required String countryCode,
    required String cityKey,
    required DateTime lowerBoundUtc,
    required DateTime upperBoundUtc,
    required int pageSize,
  }) {
    final scope = _normalizeActiveEventListScope(
      countryCode: countryCode,
      cityKey: cityKey,
      lowerBoundUtc: lowerBoundUtc,
      upperBoundUtc: upperBoundUtc,
    );
    if (pageSize <= 0) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'Expected a positive page size.',
      );
    }

    return EventListQuerySpec(
      countryCode: scope.countryCode,
      cityKey: scope.cityKey,
      lowerBoundUtc: scope.lowerBoundUtc,
      upperBoundUtc: scope.upperBoundUtc,
      pageSize: pageSize,
    );
  }

  static Query buildActiveEventListQuery(
    Query query, {
    required String countryCode,
    required String cityKey,
    required DateTime lowerBoundUtc,
    required DateTime upperBoundUtc,
  }) {
    final scope = _normalizeActiveEventListScope(
      countryCode: countryCode,
      cityKey: cityKey,
      lowerBoundUtc: lowerBoundUtc,
      upperBoundUtc: upperBoundUtc,
    );

    return query
        .where('status', isEqualTo: activeEventStatus)
        .where('countryCode', isEqualTo: scope.countryCode)
        .where('cityKey', isEqualTo: scope.cityKey)
        .where('startsAt', isGreaterThanOrEqualTo: scope.lowerBoundUtc)
        .where('startsAt', isLessThan: scope.upperBoundUtc)
        .orderBy('startsAt');
  }

  static Query buildActiveEventListQueryForDateRange(
    Query query, {
    required String countryCode,
    required String cityKey,
    required String timeZoneId,
    required EventListLocalDateRange localDateRange,
    required DateTime nowUtc,
  }) {
    final bounds = computeEventListDateBounds(
      timeZoneId: timeZoneId,
      localDateRange: localDateRange,
      nowUtc: nowUtc,
    );
    return buildActiveEventListQuery(
      query,
      countryCode: countryCode,
      cityKey: cityKey,
      lowerBoundUtc: bounds.lowerBoundUtc,
      upperBoundUtc: bounds.upperBoundUtc,
    );
  }

  static Future<FFFirestorePage<EventsRecord>> loadRawActiveEventPage({
    required String countryCode,
    required String cityKey,
    required DateTime lowerBoundUtc,
    required DateTime upperBoundUtc,
    required int pageSize,
    DocumentSnapshot? nextPageMarker,
    EventListPageLoader? pageLoader,
  }) {
    final spec = normalizeActiveEventListQuery(
      countryCode: countryCode,
      cityKey: cityKey,
      lowerBoundUtc: lowerBoundUtc,
      upperBoundUtc: upperBoundUtc,
      pageSize: pageSize,
    );
    final loader = pageLoader ?? _loadEventCollectionPage;
    final usesInjectedLoader = pageLoader != null;

    return loader(
      usesInjectedLoader ? EventsRecord.collection : _publicEventsCollection,
      usesInjectedLoader ? EventsRecord.fromSnapshot : _publicEventFromSnapshot,
      queryBuilder: (query) => buildActiveEventListQuery(
        query,
        countryCode: spec.countryCode,
        cityKey: spec.cityKey,
        lowerBoundUtc: spec.lowerBoundUtc,
        upperBoundUtc: spec.upperBoundUtc,
      ),
      nextPageMarker: nextPageMarker,
      pageSize: spec.pageSize,
      isStream: false,
    );
  }

  static Future<FFFirestorePage<EventsRecord>>
      loadRawActiveEventPageForDateRange({
    required String countryCode,
    required String cityKey,
    required String timeZoneId,
    required EventListLocalDateRange localDateRange,
    required DateTime nowUtc,
    required int pageSize,
    DocumentSnapshot? nextPageMarker,
    EventListPageLoader? pageLoader,
  }) {
    final bounds = computeEventListDateBounds(
      timeZoneId: timeZoneId,
      localDateRange: localDateRange,
      nowUtc: nowUtc,
    );
    return loadRawActiveEventPage(
      countryCode: countryCode,
      cityKey: cityKey,
      lowerBoundUtc: bounds.lowerBoundUtc,
      upperBoundUtc: bounds.upperBoundUtc,
      pageSize: pageSize,
      nextPageMarker: nextPageMarker,
      pageLoader: pageLoader,
    );
  }

  static FFFirestorePage<EventsRecord> filterRawActiveEventPageByLevel(
    FFFirestorePage<EventsRecord> rawPage, {
    String? selectedLevel,
  }) {
    final selectedRange = selectedEventLevelRange(selectedLevel);
    if (selectedRange == null) {
      return rawPage;
    }
    return EventListFirestorePage(
      filterEventsBySelectedLevel(
        rawPage.data,
        selectedRange: selectedRange,
      ),
      rawPage.dataStream?.map(
        (events) => filterEventsBySelectedLevel(
          events,
          selectedRange: selectedRange,
        ),
      ),
      rawPage.nextPageMarker,
      hasMore: pageHasMore(rawPage),
    );
  }

  static List<EventsRecord> filterEventsBySelectedLevel(
    Iterable<EventsRecord> events, {
    EventLevelRange? selectedRange,
  }) {
    if (selectedRange == null) {
      return events.toList(growable: false);
    }
    return events.where((event) {
      final eventRange = tryEventLevelRange(
        levelMin: event.levelMin,
        levelMax: event.levelMax,
      );
      if (eventRange == null) {
        return false;
      }
      return eventRange.overlaps(selectedRange);
    }).toList(growable: false);
  }

  static Future<FFFirestorePage<EventsRecord>>
      loadLevelFilteredActiveEventPage({
    required String countryCode,
    required String cityKey,
    required DateTime lowerBoundUtc,
    required DateTime upperBoundUtc,
    required int pageSize,
    String? selectedLevel,
    DocumentSnapshot? nextPageMarker,
    EventListPageLoader? pageLoader,
  }) async {
    final selectedRange = selectedEventLevelRange(selectedLevel);
    if (selectedRange == null) {
      return loadRawActiveEventPage(
        countryCode: countryCode,
        cityKey: cityKey,
        lowerBoundUtc: lowerBoundUtc,
        upperBoundUtc: upperBoundUtc,
        pageSize: pageSize,
        nextPageMarker: nextPageMarker,
        pageLoader: pageLoader,
      );
    }

    final spec = normalizeActiveEventListQuery(
      countryCode: countryCode,
      cityKey: cityKey,
      lowerBoundUtc: lowerBoundUtc,
      upperBoundUtc: upperBoundUtc,
      pageSize: pageSize,
    );

    final visibleEvents = <EventsRecord>[];
    DocumentSnapshot? rawCursor = nextPageMarker;
    QueryDocumentSnapshot? lastRawCursor;

    while (visibleEvents.length < spec.pageSize) {
      final rawPage = await loadRawActiveEventPage(
        countryCode: spec.countryCode,
        cityKey: spec.cityKey,
        lowerBoundUtc: spec.lowerBoundUtc,
        upperBoundUtc: spec.upperBoundUtc,
        pageSize: spec.pageSize,
        nextPageMarker: rawCursor,
        pageLoader: pageLoader,
      );
      visibleEvents.addAll(
        filterEventsBySelectedLevel(
          rawPage.data,
          selectedRange: selectedRange,
        ),
      );

      final rawNextPageMarker = rawPage.nextPageMarker;
      if (!pageHasMore(rawPage) || rawNextPageMarker == null) {
        return EventListFirestorePage(
          visibleEvents,
          null,
          rawNextPageMarker,
          hasMore: false,
        );
      }

      lastRawCursor = rawNextPageMarker;
      rawCursor = rawNextPageMarker;
    }

    return EventListFirestorePage(
      visibleEvents,
      null,
      lastRawCursor,
      hasMore: true,
    );
  }

  static Future<FFFirestorePage<EventsRecord>>
      loadLevelFilteredActiveEventPageForDateRange({
    required String countryCode,
    required String cityKey,
    required String timeZoneId,
    required EventListLocalDateRange localDateRange,
    required DateTime nowUtc,
    required int pageSize,
    String? selectedLevel,
    DocumentSnapshot? nextPageMarker,
    EventListPageLoader? pageLoader,
  }) async {
    final bounds = computeEventListDateBounds(
      timeZoneId: timeZoneId,
      localDateRange: localDateRange,
      nowUtc: nowUtc,
    );
    return loadLevelFilteredActiveEventPage(
      countryCode: countryCode,
      cityKey: cityKey,
      lowerBoundUtc: bounds.lowerBoundUtc,
      upperBoundUtc: bounds.upperBoundUtc,
      pageSize: pageSize,
      nextPageMarker: nextPageMarker,
      selectedLevel: selectedLevel,
      pageLoader: pageLoader,
    );
  }
}

_EventListQueryScope _normalizeActiveEventListScope({
  required String countryCode,
  required String cityKey,
  required DateTime lowerBoundUtc,
  required DateTime upperBoundUtc,
}) {
  final cityIdentity = normalizeEventCityIdentity(countryCode, cityKey);
  if (cityIdentity == null) {
    throw ArgumentError.value(
      '$countryCode:$cityKey',
      'countryCode/cityKey',
      'Expected a well-formed event city identity.',
    );
  }
  if (!lowerBoundUtc.isUtc) {
    throw ArgumentError.value(
      lowerBoundUtc,
      'lowerBoundUtc',
      'Expected a UTC DateTime.',
    );
  }
  if (!upperBoundUtc.isUtc) {
    throw ArgumentError.value(
      upperBoundUtc,
      'upperBoundUtc',
      'Expected a UTC DateTime.',
    );
  }
  if (!lowerBoundUtc.isBefore(upperBoundUtc)) {
    throw ArgumentError.value(
      upperBoundUtc,
      'upperBoundUtc',
      'Expected upperBoundUtc to be after lowerBoundUtc.',
    );
  }

  return _EventListQueryScope(
    countryCode: cityIdentity.countryCode,
    cityKey: cityIdentity.cityKey,
    lowerBoundUtc: lowerBoundUtc,
    upperBoundUtc: upperBoundUtc,
  );
}

Future<FFFirestorePage<EventsRecord>> _loadEventCollectionPage(
  Query collection,
  RecordBuilder<EventsRecord> recordBuilder, {
  Query Function(Query)? queryBuilder,
  DocumentSnapshot? nextPageMarker,
  required int pageSize,
  required bool isStream,
}) async {
  final builder = queryBuilder ?? (Query query) => query;
  var query = builder(collection).limit(pageSize);
  if (nextPageMarker != null) {
    query = query.startAfterDocument(nextPageMarker);
  }
  Stream<QuerySnapshot>? snapshotStream;
  final QuerySnapshot snapshot;
  if (isStream) {
    snapshotStream = query.snapshots();
    snapshot = await snapshotStream.first;
  } else {
    snapshot = await query.get();
  }
  List<EventsRecord> records(QuerySnapshot source) => source.docs
      .map(
        (document) => safeGet(
          () => recordBuilder(document),
          (error) => print(
            'Error serializing event ${document.reference.path}: $error',
          ),
        ),
      )
      .whereType<EventsRecord>()
      .toList(growable: false);

  return EventListFirestorePage(
    records(snapshot),
    snapshotStream?.map(records),
    snapshot.docs.isEmpty ? null : snapshot.docs.last,
    hasMore: snapshot.docs.length >= pageSize,
  );
}
