import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';
import 'package:small_talk/services/event_selected_city_state.dart';
import 'package:small_talk/services/events_analytics_service.dart';

void main() {
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

    await service.trackEventListOpened(selectedCity);
    await service.trackCitySelected(selectedCity);
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
  });
}
