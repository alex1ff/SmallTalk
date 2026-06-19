import 'package:firebase_analytics/firebase_analytics.dart';

import 'event_level_helper.dart';
import 'event_list_date_bounds.dart';
import 'event_selected_city_state.dart';

typedef EventsAnalyticsLogEvent = Future<void> Function({
  required String name,
  required Map<String, Object> parameters,
});

abstract interface class EventsAnalyticsTracker {
  Future<void> trackEventListOpened(EventSelectedCity selectedCity);

  Future<void> trackCitySelected(EventSelectedCity selectedCity);

  Future<void> trackDateFilterSelected(EventListDateFilter dateFilter);

  Future<void> trackLevelFilterSelected(String? selectedLevel);
}

class EventsAnalyticsService implements EventsAnalyticsTracker {
  EventsAnalyticsService({
    EventsAnalyticsLogEvent? logEvent,
  }) : _logEvent = logEvent ?? _firebaseLogEvent;

  static final EventsAnalyticsService instance = EventsAnalyticsService();
  static EventsAnalyticsTracker defaultTracker = instance;

  static const String eventListOpenedEventName = 'event_list_opened';
  static const String citySelectedEventName = 'city_selected';
  static const String dateFilterSelectedEventName = 'date_filter_selected';
  static const String levelFilterSelectedEventName = 'level_filter_selected';

  final EventsAnalyticsLogEvent _logEvent;

  @override
  Future<void> trackEventListOpened(EventSelectedCity selectedCity) {
    return _trackSelectedCityEvent(
      eventName: eventListOpenedEventName,
      selectedCity: selectedCity,
    );
  }

  @override
  Future<void> trackCitySelected(EventSelectedCity selectedCity) {
    return _trackSelectedCityEvent(
      eventName: citySelectedEventName,
      selectedCity: selectedCity,
    );
  }

  @override
  Future<void> trackDateFilterSelected(EventListDateFilter dateFilter) {
    return _logEvent(
      name: dateFilterSelectedEventName,
      parameters: <String, Object>{
        'dateFilter': dateFilter.analyticsValue,
      },
    );
  }

  @override
  Future<void> trackLevelFilterSelected(String? selectedLevel) {
    return _logEvent(
      name: levelFilterSelectedEventName,
      parameters: <String, Object>{
        'levelFilter': eventLevelFilterAnalyticsValue(selectedLevel),
      },
    );
  }

  Future<void> _trackSelectedCityEvent({
    required String eventName,
    required EventSelectedCity selectedCity,
  }) {
    return _logEvent(
      name: eventName,
      parameters: <String, Object>{
        for (final entry in selectedCity.analyticsPayload.entries)
          entry.key: entry.value,
      },
    );
  }

  static Future<void> _firebaseLogEvent({
    required String name,
    required Map<String, Object> parameters,
  }) {
    return FirebaseAnalytics.instance.logEvent(
      name: name,
      parameters: parameters,
    );
  }
}

String eventLevelFilterAnalyticsValue(String? selectedLevel) {
  final normalizedLevel = selectedLevel?.trim();
  if (normalizedLevel == null || normalizedLevel.isEmpty) {
    return 'none';
  }
  return normalizeEventLevelCode(normalizedLevel, 'selectedLevel');
}

extension EventListDateFilterAnalytics on EventListDateFilter {
  String get analyticsValue {
    return switch (this) {
      EventListDateFilter.today => 'today',
      EventListDateFilter.tomorrow => 'tomorrow',
      EventListDateFilter.currentWeek => 'current_week',
      EventListDateFilter.currentMonth => 'current_month',
    };
  }
}
