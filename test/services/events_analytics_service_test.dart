import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
import 'package:small_talk/services/event_selected_city_state.dart';
import 'package:small_talk/services/events_analytics_service.dart';

void main() {
  test('tracks event list opened with canonical city payload only', () async {
    String? loggedName;
    Map<String, Object>? loggedParameters;
    final service = EventsAnalyticsService(
      logEvent: ({
        required String name,
        required Map<String, Object> parameters,
      }) async {
        loggedName = name;
        loggedParameters = parameters;
      },
    );

    await service.trackEventListOpened(
      EventSelectedCity(
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
      ),
    );

    expect(loggedName, EventsAnalyticsService.eventListOpenedEventName);
    expect(loggedParameters, <String, Object>{
      'countryCode': 'RU',
      'cityKey': 'moscow',
      'citySource': 'profile',
    });
    expect(loggedParameters, isNot(contains('cityNameRu')));
    expect(loggedParameters, isNot(contains('cityNameEn')));
    expect(loggedParameters, isNot(contains('cityDisplayContext')));
    expect(loggedParameters, isNot(contains('aliases')));
  });
}
