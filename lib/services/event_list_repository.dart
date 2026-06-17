import '/backend/backend.dart';
import 'event_list_date_bounds.dart';
import 'event_city_catalog.dart';

const activeEventStatus = 'active';
const eventLevelRanks = <String, int>{
  'A1': 0,
  'A2': 1,
  'B1': 2,
  'B2': 3,
  'C1': 4,
  'C2': 5,
};

typedef EventListPageLoader = Future<FFFirestorePage<EventsRecord>> Function(
  Query collection,
  RecordBuilder<EventsRecord> recordBuilder, {
  Query Function(Query)? queryBuilder,
  DocumentSnapshot? nextPageMarker,
  required int pageSize,
  required bool isStream,
});

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

class EventLevelRange {
  const EventLevelRange._({
    required this.levelMin,
    required this.levelMax,
    required this.minRank,
    required this.maxRank,
  });

  final String levelMin;
  final String levelMax;
  final int minRank;
  final int maxRank;

  bool overlaps(EventLevelRange other) =>
      minRank <= other.maxRank && other.minRank <= maxRank;
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

    return loader(
      EventsRecord.collection,
      EventsRecord.fromSnapshot,
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
    final selectedRange = _selectedEventLevelRange(selectedLevel);
    if (selectedRange == null) {
      return rawPage;
    }
    return FFFirestorePage<EventsRecord>(
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
      final eventRange = _tryEventLevelRange(
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
    final selectedRange = _selectedEventLevelRange(selectedLevel);
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
      if (rawNextPageMarker == null) {
        return FFFirestorePage<EventsRecord>(visibleEvents, null, null);
      }

      lastRawCursor = rawNextPageMarker;
      rawCursor = rawNextPageMarker;
    }

    return FFFirestorePage<EventsRecord>(
      visibleEvents,
      null,
      lastRawCursor,
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

EventLevelRange eventLevelRange({
  required String levelMin,
  required String levelMax,
}) {
  final minCode = _normalizeEventLevelCode(levelMin, 'levelMin');
  final maxCode = _normalizeEventLevelCode(levelMax, 'levelMax');
  final minRank = eventLevelRanks[minCode]!;
  final maxRank = eventLevelRanks[maxCode]!;
  if (minRank > maxRank) {
    throw ArgumentError.value(
      '$levelMin:$levelMax',
      'levelRange',
      'Expected levelMin to be less than or equal to levelMax.',
    );
  }
  return EventLevelRange._(
    levelMin: minCode,
    levelMax: maxCode,
    minRank: minRank,
    maxRank: maxRank,
  );
}

EventLevelRange? _selectedEventLevelRange(String? selectedLevel) {
  final normalizedLevel = selectedLevel?.trim();
  if (normalizedLevel == null || normalizedLevel.isEmpty) {
    return null;
  }
  return eventLevelRange(
    levelMin: normalizedLevel,
    levelMax: normalizedLevel,
  );
}

EventLevelRange? _tryEventLevelRange({
  required String levelMin,
  required String levelMax,
}) {
  try {
    return eventLevelRange(
      levelMin: levelMin,
      levelMax: levelMax,
    );
  } on ArgumentError {
    return null;
  }
}

String _normalizeEventLevelCode(String levelCode, String name) {
  final normalizedLevelCode = levelCode.trim().toUpperCase();
  if (!eventLevelRanks.containsKey(normalizedLevelCode)) {
    throw ArgumentError.value(
      levelCode,
      name,
      'Expected a canonical CEFR level code.',
    );
  }
  return normalizedLevelCode;
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
}) =>
    queryCollectionPage<EventsRecord>(
      collection,
      recordBuilder,
      queryBuilder: queryBuilder,
      nextPageMarker: nextPageMarker,
      pageSize: pageSize,
      isStream: isStream,
    );
