import '/backend/backend.dart';
import 'event_list_date_bounds.dart';
import 'event_city_catalog.dart';

const activeEventStatus = 'active';

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
