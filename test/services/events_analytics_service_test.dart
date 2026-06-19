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
}
