import 'package:firebase_analytics/firebase_analytics.dart';

import '/backend/backend.dart';

import 'event_city_catalog.dart';
import 'event_city_selection_source.dart';
import 'event_level_helper.dart';
import 'event_list_date_bounds.dart';
import 'event_selected_city_state.dart';

typedef EventsAnalyticsLogEvent = Future<void> Function({
  required String name,
  required Map<String, Object> parameters,
});

typedef EventsAnalyticsCityCatalogLoader = Future<EventCityCatalog> Function();

typedef EventsAnalyticsCityIdentityExists = Future<bool> Function(
  EventCityIdentity identity,
);

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

  Future<void> trackEventLeft(EventsRecord event, {String? citySource});

  Future<void> trackEventChatOpened({
    required String countryCode,
    required String cityKey,
    String? citySource,
  });

  Future<void> trackEventCanceled(EventsRecord event, {String? citySource});
}

class EventsAnalyticsService implements EventsAnalyticsTracker {
  EventsAnalyticsService({
    EventsAnalyticsLogEvent? logEvent,
    EventsAnalyticsCityCatalogLoader? cityCatalogLoader,
    EventsAnalyticsCityIdentityExists? cityIdentityExists,
  })  : _logEvent = logEvent ?? _firebaseLogEvent,
        _cityCatalogLoader = cityCatalogLoader ?? _loadDefaultCityCatalog,
        _cityIdentityExistsOverride = cityIdentityExists;

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
  static const String eventLeftEventName = 'event_left';
  static const String eventChatOpenedEventName = 'event_chat_opened';
  static const String eventCanceledEventName = 'event_canceled';

  final EventsAnalyticsLogEvent _logEvent;
  final EventsAnalyticsCityCatalogLoader _cityCatalogLoader;
  final EventsAnalyticsCityIdentityExists? _cityIdentityExistsOverride;
  Future<EventCityCatalog>? _cityCatalogFuture;

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
    return _trackCityEvent(
      eventName: eventDetailOpenedEventName,
      countryCode: event.countryCode,
      cityKey: event.cityKey,
      citySource: citySource,
    );
  }

  @override
  Future<void> trackEventCreated({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) {
    return _trackCityEvent(
      eventName: eventCreatedEventName,
      countryCode: countryCode,
      cityKey: cityKey,
      citySource: citySource,
    );
  }

  @override
  Future<void> trackEventEdited({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) {
    return _trackCityEvent(
      eventName: eventEditedEventName,
      countryCode: countryCode,
      cityKey: cityKey,
      citySource: citySource,
    );
  }

  @override
  Future<void> trackEventCanceled(
    EventsRecord event, {
    String? citySource,
  }) {
    return _trackCityEvent(
      eventName: eventCanceledEventName,
      countryCode: event.countryCode,
      cityKey: event.cityKey,
      citySource: citySource,
    );
  }

  @override
  Future<void> trackEventJoined(
    EventsRecord event, {
    String? citySource,
  }) {
    return _trackCityEvent(
      eventName: eventJoinedEventName,
      countryCode: event.countryCode,
      cityKey: event.cityKey,
      citySource: citySource,
    );
  }

  @override
  Future<void> trackEventLeft(
    EventsRecord event, {
    String? citySource,
  }) {
    return _trackCityEvent(
      eventName: eventLeftEventName,
      countryCode: event.countryCode,
      cityKey: event.cityKey,
      citySource: citySource,
    );
  }

  @override
  Future<void> trackEventChatOpened({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) {
    return _trackCityEvent(
      eventName: eventChatOpenedEventName,
      countryCode: countryCode,
      cityKey: cityKey,
      citySource: citySource,
    );
  }

  Future<void> _trackSelectedCityEvent({
    required String eventName,
    required EventSelectedCity selectedCity,
  }) {
    return _trackCityEvent(
      eventName: eventName,
      countryCode: selectedCity.city.countryCode,
      cityKey: selectedCity.city.cityKey,
      citySource: selectedCity.source.analyticsValue,
    );
  }

  Future<void> _trackCityEvent({
    required String eventName,
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) async {
    final payload = await _validatedEventCityAnalyticsPayload(
      countryCode: countryCode,
      cityKey: cityKey,
      citySource: citySource,
    );
    if (payload == null) {
      return;
    }
    return _logEvent(
      name: eventName,
      parameters: payload,
    );
  }

  Future<Map<String, Object>?> _validatedEventCityAnalyticsPayload({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) async {
    final normalizedIdentity = normalizeEventCityIdentity(countryCode, cityKey);
    if (normalizedIdentity == null ||
        !await _isKnownCityIdentity(normalizedIdentity)) {
      return null;
    }
    return _eventCityAnalyticsPayloadFromIdentity(
      normalizedIdentity,
      citySource: citySource,
    );
  }

  Future<bool> _isKnownCityIdentity(EventCityIdentity identity) async {
    final override = _cityIdentityExistsOverride;
    if (override != null) {
      return override(identity);
    }
    final catalog = await (_cityCatalogFuture ??= _cityCatalogLoader());
    return catalog.resolve(identity.countryCode, identity.cityKey) != null;
  }

  static Future<EventCityCatalog> _loadDefaultCityCatalog() {
    return EventCityCatalog.loadFromAsset();
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
  final normalizedIdentity = normalizeEventCityIdentity(countryCode, cityKey);
  if (normalizedIdentity == null) {
    return null;
  }
  return _eventCityAnalyticsPayloadFromIdentity(
    normalizedIdentity,
    citySource: citySource,
  );
}

Map<String, Object> _eventCityAnalyticsPayloadFromIdentity(
  EventCityIdentity identity, {
  String? citySource,
}) {
  final normalizedCitySource = citySource?.trim();
  return <String, Object>{
    'countryCode': identity.countryCode,
    'cityKey': identity.cityKey,
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
