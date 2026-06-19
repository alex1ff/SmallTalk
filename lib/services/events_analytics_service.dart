import 'package:firebase_analytics/firebase_analytics.dart';

import '/backend/backend.dart';

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

  Future<void> trackEventDetailOpened(EventsRecord event, {String? citySource});

  Future<void> trackEventCreated({
    required String countryCode,
    required String cityKey,
    String? citySource,
  });

  Future<void> trackEventEdited({
    required String countryCode,
    required String cityKey,
    String? citySource,
  });

  Future<void> trackEventJoined(EventsRecord event, {String? citySource});

  Future<void> trackEventCanceled(EventsRecord event, {String? citySource});
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
  static const String eventDetailOpenedEventName = 'event_detail_opened';
  static const String eventCreatedEventName = 'event_created';
  static const String eventEditedEventName = 'event_edited';
  static const String eventJoinedEventName = 'event_joined';
  static const String eventCanceledEventName = 'event_canceled';

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

  @override
  Future<void> trackEventDetailOpened(
    EventsRecord event, {
    String? citySource,
  }) {
    final payload = eventCityAnalyticsPayload(
      countryCode: event.countryCode,
      cityKey: event.cityKey,
      citySource: citySource,
    );
    if (payload == null) {
      return Future<void>.value();
    }
    return _logEvent(
      name: eventDetailOpenedEventName,
      parameters: payload,
    );
  }

  @override
  Future<void> trackEventCreated({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) {
    final payload = eventCityAnalyticsPayload(
      countryCode: countryCode,
      cityKey: cityKey,
      citySource: citySource,
    );
    if (payload == null) {
      return Future<void>.value();
    }
    return _logEvent(
      name: eventCreatedEventName,
      parameters: payload,
    );
  }

  @override
  Future<void> trackEventEdited({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) {
    final payload = eventCityAnalyticsPayload(
      countryCode: countryCode,
      cityKey: cityKey,
      citySource: citySource,
    );
    if (payload == null) {
      return Future<void>.value();
    }
    return _logEvent(
      name: eventEditedEventName,
      parameters: payload,
    );
  }

  @override
  Future<void> trackEventCanceled(
    EventsRecord event, {
    String? citySource,
  }) {
    final payload = eventCityAnalyticsPayload(
      countryCode: event.countryCode,
      cityKey: event.cityKey,
      citySource: citySource,
    );
    if (payload == null) {
      return Future<void>.value();
    }
    return _logEvent(
      name: eventCanceledEventName,
      parameters: payload,
    );
  }

  @override
  Future<void> trackEventJoined(
    EventsRecord event, {
    String? citySource,
  }) {
    final payload = eventCityAnalyticsPayload(
      countryCode: event.countryCode,
      cityKey: event.cityKey,
      citySource: citySource,
    );
    if (payload == null) {
      return Future<void>.value();
    }
    return _logEvent(
      name: eventJoinedEventName,
      parameters: payload,
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

Map<String, Object>? eventCityAnalyticsPayload({
  required String countryCode,
  required String cityKey,
  String? citySource,
}) {
  final normalizedCountryCode = countryCode.trim().toUpperCase();
  final normalizedCityKey = cityKey.trim();
  if (normalizedCountryCode.isEmpty || normalizedCityKey.isEmpty) {
    return null;
  }
  final normalizedCitySource = citySource?.trim();
  return <String, Object>{
    'countryCode': normalizedCountryCode,
    'cityKey': normalizedCityKey,
    if (normalizedCitySource != null && normalizedCitySource.isNotEmpty)
      'citySource': normalizedCitySource,
  };
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
