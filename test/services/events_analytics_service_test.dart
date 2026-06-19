import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
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
