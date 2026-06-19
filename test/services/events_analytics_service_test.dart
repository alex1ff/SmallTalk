import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';
import 'package:small_talk/services/event_selected_city_state.dart';
import 'package:small_talk/services/events_analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  test('tracks selected-city analytics events with canonical payload only',
      () async {
    final loggedEvents = <String, Map<String, Object>>{};
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        loggedEvents[name] = parameters;
      },
    );
    final selectedCity = EventSelectedCity(
      city: const EventCity(
        countryCode: 'RU',
        cityKey: 'moscow',
        cityNameRu: 'Москва',
        cityNameEn: 'Moscow',
        regionCode: null,
        regionNameRu: null,
        regionNameEn: null,
        timeZoneId: 'Europe/Moscow',
        cityDisplayContext: 'Россия',
        aliases: ['мск'],
        transliterations: ['moskva'],
        priority: 100,
      ),
      source: EventCitySelectionSource.profile,
    );
    final event = EventsRecord.getDocumentFromData(
      {
        'countryCode': ' ru ',
        'cityKey': 'moscow',
        'cityNameRu': 'Москва',
        'cityDisplayContext': 'Россия',
      },
      EventsRecord.collection.doc('event-1'),
    );

    await service.trackEventListOpened(selectedCity);
    await service.trackCitySelected(selectedCity);
    await service.trackEventDetailOpened(event);
    for (final filter in EventListDateFilter.values) {
      await service.trackDateFilterSelected(filter);
      expect(
        loggedEvents[EventsAnalyticsService.dateFilterSelectedEventName],
        <String, Object>{
          'dateFilter': filter.analyticsValue,
        },
      );
    }
    for (final level in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']) {
      await service.trackLevelFilterSelected(level.toLowerCase());
      expect(
        loggedEvents[EventsAnalyticsService.levelFilterSelectedEventName],
        <String, Object>{
          'levelFilter': level,
        },
      );
    }
    await service.trackLevelFilterSelected(null);
    expect(
      loggedEvents[EventsAnalyticsService.levelFilterSelectedEventName],
      <String, Object>{
        'levelFilter': 'none',
      },
    );
    await service.trackLevelFilterSelected(' b2 ');
    expect(
      loggedEvents[EventsAnalyticsService.levelFilterSelectedEventName],
      <String, Object>{
        'levelFilter': 'B2',
      },
    );
    await service.trackLevelFilterSelected('');
    expect(
      loggedEvents[EventsAnalyticsService.levelFilterSelectedEventName],
      <String, Object>{
        'levelFilter': 'none',
      },
    );

    for (final eventName in [
      EventsAnalyticsService.eventListOpenedEventName,
      EventsAnalyticsService.citySelectedEventName,
    ]) {
      expect(loggedEvents[eventName], <String, Object>{
        'countryCode': 'RU',
        'cityKey': 'moscow',
        'citySource': 'profile',
      });
      expect(loggedEvents[eventName], isNot(contains('cityNameRu')));
      expect(loggedEvents[eventName], isNot(contains('cityNameEn')));
      expect(loggedEvents[eventName], isNot(contains('cityDisplayContext')));
      expect(loggedEvents[eventName], isNot(contains('aliases')));
    }
    expect(
      loggedEvents[EventsAnalyticsService.eventDetailOpenedEventName],
      <String, Object>{
        'countryCode': 'RU',
        'cityKey': 'moscow',
      },
    );
    expect(
      loggedEvents[EventsAnalyticsService.eventDetailOpenedEventName],
      isNot(contains('citySource')),
    );
    expect(
      loggedEvents[EventsAnalyticsService.eventDetailOpenedEventName],
      isNot(contains('cityDisplayContext')),
    );
  });

  test('tracks event detail city source only when known', () async {
    final loggedEvents = <String, Map<String, Object>>{};
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        loggedEvents[name] = parameters;
      },
    );
    final event = EventsRecord.getDocumentFromData(
      {
        'countryCode': ' ru ',
        'cityKey': ' moscow ',
      },
      EventsRecord.collection.doc('event-1'),
    );

    await service.trackEventDetailOpened(event, citySource: ' profile ');

    expect(
      loggedEvents[EventsAnalyticsService.eventDetailOpenedEventName],
      <String, Object>{
        'countryCode': 'RU',
        'cityKey': 'moscow',
        'citySource': 'profile',
      },
    );

    await service.trackEventDetailOpened(event, citySource: '   ');

    expect(
      loggedEvents[EventsAnalyticsService.eventDetailOpenedEventName],
      <String, Object>{
        'countryCode': 'RU',
        'cityKey': 'moscow',
      },
    );
  });

  test('tracks event created with canonical city payload only', () async {
    final loggedEvents = <String, Map<String, Object>>{};
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        loggedEvents[name] = parameters;
      },
    );

    await service.trackEventCreated(
      countryCode: ' it ',
      cityKey: ' rome ',
      citySource: ' manual ',
    );

    expect(
      loggedEvents[EventsAnalyticsService.eventCreatedEventName],
      <String, Object>{
        'countryCode': 'IT',
        'cityKey': 'rome',
        'citySource': 'manual',
      },
    );

    await service.trackEventCreated(
      countryCode: 'IT',
      cityKey: 'rome',
      citySource: '   ',
    );

    expect(
      loggedEvents[EventsAnalyticsService.eventCreatedEventName],
      <String, Object>{
        'countryCode': 'IT',
        'cityKey': 'rome',
      },
    );
  });

  test('tracks event edited with canonical city payload only', () async {
    final loggedEvents = <String, Map<String, Object>>{};
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        loggedEvents[name] = parameters;
      },
    );

    await service.trackEventEdited(
      countryCode: ' ru ',
      cityKey: ' moscow ',
      citySource: ' static ',
    );

    expect(
      loggedEvents[EventsAnalyticsService.eventEditedEventName],
      <String, Object>{
        'countryCode': 'RU',
        'cityKey': 'moscow',
        'citySource': 'static',
      },
    );

    await service.trackEventEdited(
      countryCode: 'RU',
      cityKey: 'moscow',
      citySource: '   ',
    );

    expect(
      loggedEvents[EventsAnalyticsService.eventEditedEventName],
      <String, Object>{
        'countryCode': 'RU',
        'cityKey': 'moscow',
      },
    );
  });

  test('tracks event canceled with canonical city payload only', () async {
    final loggedEvents = <String, Map<String, Object>>{};
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        loggedEvents[name] = parameters;
      },
    );
    final event = EventsRecord.getDocumentFromData(
      {
        'countryCode': ' ru ',
        'cityKey': ' moscow ',
        'cityNameRu': 'Москва',
        'locationName': 'Cafe',
        'status': 'active',
      },
      EventsRecord.collection.doc('event-1'),
    );

    await service.trackEventCanceled(event, citySource: ' profile ');

    expect(
      loggedEvents[EventsAnalyticsService.eventCanceledEventName],
      <String, Object>{
        'countryCode': 'RU',
        'cityKey': 'moscow',
        'citySource': 'profile',
      },
    );

    await service.trackEventCanceled(event, citySource: '   ');

    expect(
      loggedEvents[EventsAnalyticsService.eventCanceledEventName],
      <String, Object>{
        'countryCode': 'RU',
        'cityKey': 'moscow',
      },
    );
    expect(
      loggedEvents[EventsAnalyticsService.eventCanceledEventName],
      isNot(contains('cityNameRu')),
    );
    expect(
      loggedEvents[EventsAnalyticsService.eventCanceledEventName],
      isNot(contains('locationName')),
    );
    expect(
      loggedEvents[EventsAnalyticsService.eventCanceledEventName],
      isNot(contains('status')),
    );
  });

  test('tracks event joined with canonical city payload only', () async {
    final loggedEvents = <String, Map<String, Object>>{};
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        loggedEvents[name] = parameters;
      },
    );
    final event = EventsRecord.getDocumentFromData(
      {
        'countryCode': ' it ',
        'cityKey': ' rome ',
        'cityNameEn': 'Rome',
        'locationName': 'La Cucina',
        'participantsCount': 5,
      },
      EventsRecord.collection.doc('event-1'),
    );

    await service.trackEventJoined(event, citySource: ' profile ');

    expect(
      loggedEvents[EventsAnalyticsService.eventJoinedEventName],
      <String, Object>{
        'countryCode': 'IT',
        'cityKey': 'rome',
        'citySource': 'profile',
      },
    );

    await service.trackEventJoined(event, citySource: '   ');

    expect(
      loggedEvents[EventsAnalyticsService.eventJoinedEventName],
      <String, Object>{
        'countryCode': 'IT',
        'cityKey': 'rome',
      },
    );
    expect(
      loggedEvents[EventsAnalyticsService.eventJoinedEventName],
      isNot(contains('cityNameEn')),
    );
    expect(
      loggedEvents[EventsAnalyticsService.eventJoinedEventName],
      isNot(contains('locationName')),
    );
    expect(
      loggedEvents[EventsAnalyticsService.eventJoinedEventName],
      isNot(contains('participantsCount')),
    );
  });

  test('skips event joined analytics when city identity is missing', () async {
    var logCalls = 0;
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        logCalls += 1;
      },
    );
    final event = EventsRecord.getDocumentFromData(
      {
        'countryCode': '   ',
        'cityKey': '',
      },
      EventsRecord.collection.doc('event-1'),
    );

    await service.trackEventJoined(event);

    expect(logCalls, 0);
  });

  test('tracks event left with canonical city payload only', () async {
    final loggedEvents = <String, Map<String, Object>>{};
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        loggedEvents[name] = parameters;
      },
    );
    final event = EventsRecord.getDocumentFromData(
      {
        'countryCode': ' tr ',
        'cityKey': ' istanbul ',
        'cityNameEn': 'Istanbul',
        'locationName': 'Kadikoy Cafe',
        'participantsCount': 4,
      },
      EventsRecord.collection.doc('event-1'),
    );

    await service.trackEventLeft(event, citySource: ' manual ');

    expect(
      loggedEvents[EventsAnalyticsService.eventLeftEventName],
      <String, Object>{
        'countryCode': 'TR',
        'cityKey': 'istanbul',
        'citySource': 'manual',
      },
    );

    await service.trackEventLeft(event, citySource: '   ');

    expect(
      loggedEvents[EventsAnalyticsService.eventLeftEventName],
      <String, Object>{
        'countryCode': 'TR',
        'cityKey': 'istanbul',
      },
    );
    expect(
      loggedEvents[EventsAnalyticsService.eventLeftEventName],
      isNot(contains('cityNameEn')),
    );
    expect(
      loggedEvents[EventsAnalyticsService.eventLeftEventName],
      isNot(contains('locationName')),
    );
    expect(
      loggedEvents[EventsAnalyticsService.eventLeftEventName],
      isNot(contains('participantsCount')),
    );
  });

  test('skips event left analytics when city identity is missing', () async {
    var logCalls = 0;
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        logCalls += 1;
      },
    );
    final event = EventsRecord.getDocumentFromData(
      {
        'countryCode': '',
        'cityKey': '   ',
      },
      EventsRecord.collection.doc('event-1'),
    );

    await service.trackEventLeft(event);

    expect(logCalls, 0);
  });

  test('tracks event chat opened with canonical city payload only', () async {
    final loggedEvents = <String, Map<String, Object>>{};
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        loggedEvents[name] = parameters;
      },
    );

    await service.trackEventChatOpened(
      countryCode: ' es ',
      cityKey: ' madrid ',
      citySource: ' profile ',
    );

    expect(
      loggedEvents[EventsAnalyticsService.eventChatOpenedEventName],
      <String, Object>{
        'countryCode': 'ES',
        'cityKey': 'madrid',
        'citySource': 'profile',
      },
    );

    await service.trackEventChatOpened(
      countryCode: 'ES',
      cityKey: 'madrid',
      citySource: '   ',
    );

    expect(
      loggedEvents[EventsAnalyticsService.eventChatOpenedEventName],
      <String, Object>{
        'countryCode': 'ES',
        'cityKey': 'madrid',
      },
    );
  });

  test('skips event chat opened analytics when city identity is missing',
      () async {
    var logCalls = 0;
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        logCalls += 1;
      },
    );

    await service.trackEventChatOpened(
      countryCode: '',
      cityKey: '   ',
    );

    expect(logCalls, 0);
  });

  test('all city analytics events use canonical city identity keys only',
      () async {
    final loggedEvents = <String, Map<String, Object>>{};
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        loggedEvents[name] = parameters;
      },
    );
    final selectedCity = _selectedCityFixture(
      countryCode: 'RU',
      cityKey: 'moscow',
    );
    final event = _analyticsEventFixture(
      countryCode: ' ru ',
      cityKey: 'moscow',
    );
    final cases = <_CityAnalyticsCase>[
      _CityAnalyticsCase(
        eventName: EventsAnalyticsService.eventListOpenedEventName,
        track: () => service.trackEventListOpened(selectedCity),
        expectedSource: 'profile',
      ),
      _CityAnalyticsCase(
        eventName: EventsAnalyticsService.citySelectedEventName,
        track: () => service.trackCitySelected(selectedCity),
        expectedSource: 'profile',
      ),
      _CityAnalyticsCase(
        eventName: EventsAnalyticsService.eventDetailOpenedEventName,
        track: () => service.trackEventDetailOpened(event),
      ),
      _CityAnalyticsCase(
        eventName: EventsAnalyticsService.eventCreatedEventName,
        track: () => service.trackEventCreated(
          countryCode: ' ru ',
          cityKey: 'moscow',
          citySource: 'manual',
        ),
        expectedSource: 'manual',
      ),
      _CityAnalyticsCase(
        eventName: EventsAnalyticsService.eventEditedEventName,
        track: () => service.trackEventEdited(
          countryCode: ' ru ',
          cityKey: 'moscow',
          citySource: 'static',
        ),
        expectedSource: 'static',
      ),
      _CityAnalyticsCase(
        eventName: EventsAnalyticsService.eventCanceledEventName,
        track: () => service.trackEventCanceled(event),
      ),
      _CityAnalyticsCase(
        eventName: EventsAnalyticsService.eventJoinedEventName,
        track: () => service.trackEventJoined(event),
      ),
      _CityAnalyticsCase(
        eventName: EventsAnalyticsService.eventLeftEventName,
        track: () => service.trackEventLeft(event),
      ),
      _CityAnalyticsCase(
        eventName: EventsAnalyticsService.eventChatOpenedEventName,
        track: () => service.trackEventChatOpened(
          countryCode: ' ru ',
          cityKey: 'moscow',
          citySource: 'recent',
        ),
        expectedSource: 'recent',
      ),
    ];

    for (final cityCase in cases) {
      await cityCase.track();
      final expected = <String, Object>{
        'countryCode': 'RU',
        'cityKey': 'moscow',
        if (cityCase.expectedSource != null)
          'citySource': cityCase.expectedSource!,
      };
      expect(
        loggedEvents[cityCase.eventName],
        expected,
        reason: cityCase.eventName,
      );
      expect(
        loggedEvents[cityCase.eventName]!.keys,
        everyElement(
          isNot(
            isIn(<String>{
              'cityNameRu',
              'cityNameEn',
              'cityDisplayContext',
              'displayContext',
              'aliases',
              'transliterations',
              'regionNameRu',
              'regionNameEn',
            }),
          ),
        ),
        reason: cityCase.eventName,
      );
      expect(
        loggedEvents[cityCase.eventName]!.values,
        isNot(
          contains(
            anyOf('Москва', 'Moscow', 'Россия', 'мск', 'moskva'),
          ),
        ),
        reason: cityCase.eventName,
      );
    }
  });

  test('city analytics skips localized or display city identity values',
      () async {
    final loggedEvents = <String, Map<String, Object>>{};
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        loggedEvents[name] = parameters;
      },
    );
    final localizedCity = _selectedCityFixture(
      countryCode: 'RU',
      cityKey: 'Москва',
    );
    final transliteratedAliasCity = _selectedCityFixture(
      countryCode: 'RU',
      cityKey: 'moskva',
    );
    final displayCityEvent = _analyticsEventFixture(
      countryCode: 'RU',
      cityKey: 'Moscow · Россия',
    );
    final regexValidAliasEvent = _analyticsEventFixture(
      countryCode: 'US',
      cityKey: 'nyc',
    );

    await service.trackEventListOpened(localizedCity);
    await service.trackCitySelected(localizedCity);
    await service.trackEventListOpened(transliteratedAliasCity);
    await service.trackCitySelected(transliteratedAliasCity);
    await service.trackEventDetailOpened(displayCityEvent);
    await service.trackEventDetailOpened(regexValidAliasEvent);
    await service.trackEventCreated(
      countryCode: 'RU',
      cityKey: 'Moscow · Россия',
    );
    await service.trackEventCreated(
      countryCode: 'US',
      cityKey: 'nyc',
    );
    await service.trackEventEdited(
      countryCode: 'RU',
      cityKey: 'Москва',
    );
    await service.trackEventEdited(
      countryCode: 'RU',
      cityKey: 'moskva',
    );
    await service.trackEventCanceled(displayCityEvent);
    await service.trackEventCanceled(regexValidAliasEvent);
    await service.trackEventJoined(displayCityEvent);
    await service.trackEventJoined(regexValidAliasEvent);
    await service.trackEventLeft(displayCityEvent);
    await service.trackEventLeft(regexValidAliasEvent);
    await service.trackEventChatOpened(
      countryCode: 'RU',
      cityKey: 'Moscow · Россия',
    );
    await service.trackEventChatOpened(
      countryCode: 'RU',
      cityKey: 'moskva',
    );

    expect(loggedEvents, isEmpty);
  });
}

typedef _TrackCityAnalytics = Future<void> Function();

class _CityAnalyticsCase {
  const _CityAnalyticsCase({
    required this.eventName,
    required this.track,
    this.expectedSource,
  });

  final String eventName;
  final _TrackCityAnalytics track;
  final String? expectedSource;
}

EventSelectedCity _selectedCityFixture({
  required String countryCode,
  required String cityKey,
}) =>
    EventSelectedCity(
      city: EventCity(
        countryCode: countryCode,
        cityKey: cityKey,
        cityNameRu: 'Москва',
        cityNameEn: 'Moscow',
        regionCode: null,
        regionNameRu: null,
        regionNameEn: null,
        timeZoneId: 'Europe/Moscow',
        cityDisplayContext: 'Россия',
        aliases: const ['мск'],
        transliterations: const ['moskva'],
        priority: 100,
      ),
      source: EventCitySelectionSource.profile,
    );

EventsRecord _analyticsEventFixture({
  required String countryCode,
  required String cityKey,
}) =>
    EventsRecord.getDocumentFromData(
      {
        'countryCode': countryCode,
        'cityKey': cityKey,
        'cityNameRu': 'Москва',
        'cityNameEn': 'Moscow',
        'cityDisplayContext': 'Россия',
        'aliases': ['мск'],
        'transliterations': ['moskva'],
        'locationName': 'Cafe',
        'participantsCount': 5,
        'status': 'active',
      },
      EventsRecord.collection.doc('event-1'),
    );
