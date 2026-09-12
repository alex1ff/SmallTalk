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

  test('keeps analytics for actions on historical event locations', () async {
    final loggedEvents = <String, Map<String, Object>>{};
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        loggedEvents[name] = parameters;
      },
    );
    final catalog = await EventCityCatalog.loadFromAsset();
    expect(catalog.resolveSupported('RU', 'moscow'), isNull);
    final event = EventsRecord.getDocumentFromData(
      {'countryCode': 'RU', 'cityKey': 'moscow'},
      EventsRecord.collection.doc('historical-event'),
    );

    await service.trackEventDetailOpened(event);
    await service.trackEventJoined(event);
    await service.trackEventLeft(event);
    await service.trackEventCanceled(event);
    await service.trackEventChatOpened(
      countryCode: event.countryCode,
      cityKey: event.cityKey,
    );

    expect(
        loggedEvents.keys,
        unorderedEquals([
          EventsAnalyticsService.eventDetailOpenedEventName,
          EventsAnalyticsService.eventJoinedEventName,
          EventsAnalyticsService.eventLeftEventName,
          EventsAnalyticsService.eventCanceledEventName,
          EventsAnalyticsService.eventChatOpenedEventName,
        ]));
    for (final payload in loggedEvents.values) {
      expect(payload, {'countryCode': 'RU', 'cityKey': 'moscow'});
    }
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
        countryCode: 'US',
        cityKey: 'new_york',
        cityNameRu: 'New York',
        cityNameEn: 'New York',
        regionCode: null,
        regionNameRu: null,
        regionNameEn: null,
        timeZoneId: 'America/New_York',
        cityDisplayContext: 'US',
        aliases: ['NYC'],
        transliterations: ['new york'],
        priority: 100,
      ),
      source: EventCitySelectionSource.profile,
    );
    final event = EventsRecord.getDocumentFromData(
      {
        'countryCode': ' us ',
        'cityKey': 'new_york',
        'cityNameRu': 'New York',
        'cityDisplayContext': 'US',
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
        'countryCode': 'US',
        'cityKey': 'new_york',
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
        'countryCode': 'US',
        'cityKey': 'new_york',
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
        'countryCode': ' us ',
        'cityKey': ' new_york ',
      },
      EventsRecord.collection.doc('event-1'),
    );

    await service.trackEventDetailOpened(event, citySource: ' profile ');

    expect(
      loggedEvents[EventsAnalyticsService.eventDetailOpenedEventName],
      <String, Object>{
        'countryCode': 'US',
        'cityKey': 'new_york',
        'citySource': 'profile',
      },
    );

    await service.trackEventDetailOpened(event, citySource: '   ');

    expect(
      loggedEvents[EventsAnalyticsService.eventDetailOpenedEventName],
      <String, Object>{
        'countryCode': 'US',
        'cityKey': 'new_york',
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
      countryCode: ' id ',
      cityKey: ' bali ',
      citySource: ' manual ',
    );

    expect(
      loggedEvents[EventsAnalyticsService.eventCreatedEventName],
      <String, Object>{
        'countryCode': 'ID',
        'cityKey': 'bali',
        'citySource': 'manual',
      },
    );

    await service.trackEventCreated(
      countryCode: 'ID',
      cityKey: 'bali',
      citySource: '   ',
    );

    expect(
      loggedEvents[EventsAnalyticsService.eventCreatedEventName],
      <String, Object>{
        'countryCode': 'ID',
        'cityKey': 'bali',
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
      countryCode: ' ae ',
      cityKey: ' dubai ',
      citySource: ' static ',
    );

    expect(
      loggedEvents[EventsAnalyticsService.eventEditedEventName],
      <String, Object>{
        'countryCode': 'AE',
        'cityKey': 'dubai',
        'citySource': 'static',
      },
    );

    await service.trackEventEdited(
      countryCode: 'AE',
      cityKey: 'dubai',
      citySource: '   ',
    );

    expect(
      loggedEvents[EventsAnalyticsService.eventEditedEventName],
      <String, Object>{
        'countryCode': 'AE',
        'cityKey': 'dubai',
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
        'countryCode': ' us ',
        'cityKey': ' new_york ',
        'cityNameRu': 'New York',
        'locationName': 'Cafe',
        'status': 'active',
      },
      EventsRecord.collection.doc('event-1'),
    );

    await service.trackEventCanceled(event, citySource: ' profile ');

    expect(
      loggedEvents[EventsAnalyticsService.eventCanceledEventName],
      <String, Object>{
        'countryCode': 'US',
        'cityKey': 'new_york',
        'citySource': 'profile',
      },
    );

    await service.trackEventCanceled(event, citySource: '   ');

    expect(
      loggedEvents[EventsAnalyticsService.eventCanceledEventName],
      <String, Object>{
        'countryCode': 'US',
        'cityKey': 'new_york',
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
        'countryCode': ' id ',
        'cityKey': ' bali ',
        'cityNameEn': 'Bali',
        'locationName': 'Bali Cafe',
        'participantsCount': 5,
      },
      EventsRecord.collection.doc('event-1'),
    );

    await service.trackEventJoined(event, citySource: ' profile ');

    expect(
      loggedEvents[EventsAnalyticsService.eventJoinedEventName],
      <String, Object>{
        'countryCode': 'ID',
        'cityKey': 'bali',
        'citySource': 'profile',
      },
    );

    await service.trackEventJoined(event, citySource: '   ');

    expect(
      loggedEvents[EventsAnalyticsService.eventJoinedEventName],
      <String, Object>{
        'countryCode': 'ID',
        'cityKey': 'bali',
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
        'countryCode': ' th ',
        'cityKey': ' phuket ',
        'cityNameEn': 'Phuket',
        'locationName': 'Phuket Cafe',
        'participantsCount': 4,
      },
      EventsRecord.collection.doc('event-1'),
    );

    await service.trackEventLeft(event, citySource: ' manual ');

    expect(
      loggedEvents[EventsAnalyticsService.eventLeftEventName],
      <String, Object>{
        'countryCode': 'TH',
        'cityKey': 'phuket',
        'citySource': 'manual',
      },
    );

    await service.trackEventLeft(event, citySource: '   ');

    expect(
      loggedEvents[EventsAnalyticsService.eventLeftEventName],
      <String, Object>{
        'countryCode': 'TH',
        'cityKey': 'phuket',
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
      countryCode: ' ae ',
      cityKey: ' dubai ',
      citySource: ' profile ',
    );

    expect(
      loggedEvents[EventsAnalyticsService.eventChatOpenedEventName],
      <String, Object>{
        'countryCode': 'AE',
        'cityKey': 'dubai',
        'citySource': 'profile',
      },
    );

    await service.trackEventChatOpened(
      countryCode: 'AE',
      cityKey: 'dubai',
      citySource: '   ',
    );

    expect(
      loggedEvents[EventsAnalyticsService.eventChatOpenedEventName],
      <String, Object>{
        'countryCode': 'AE',
        'cityKey': 'dubai',
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
      countryCode: 'US',
      cityKey: 'new_york',
    );
    final event = _analyticsEventFixture(
      countryCode: ' us ',
      cityKey: 'new_york',
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
          countryCode: ' us ',
          cityKey: 'new_york',
          citySource: 'manual',
        ),
        expectedSource: 'manual',
      ),
      _CityAnalyticsCase(
        eventName: EventsAnalyticsService.eventEditedEventName,
        track: () => service.trackEventEdited(
          countryCode: ' us ',
          cityKey: 'new_york',
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
          countryCode: ' us ',
          cityKey: 'new_york',
          citySource: 'recent',
        ),
        expectedSource: 'recent',
      ),
    ];

    for (final cityCase in cases) {
      await cityCase.track();
      final expected = <String, Object>{
        'countryCode': 'US',
        'cityKey': 'new_york',
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
        cityNameRu: 'New York',
        cityNameEn: 'New York',
        regionCode: null,
        regionNameRu: null,
        regionNameEn: null,
        timeZoneId: 'America/New_York',
        cityDisplayContext: 'US',
        aliases: const ['NYC'],
        transliterations: const ['new york'],
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
        'cityNameRu': 'New York',
        'cityNameEn': 'New York',
        'cityDisplayContext': 'US',
        'aliases': ['NYC'],
        'transliterations': ['new york'],
        'locationName': 'Cafe',
        'participantsCount': 5,
        'status': 'active',
      },
      EventsRecord.collection.doc('event-1'),
    );
