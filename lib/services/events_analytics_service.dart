import 'package:firebase_analytics/firebase_analytics.dart';

import 'event_selected_city_state.dart';

typedef EventsAnalyticsLogEvent = Future<void> Function({
  required String name,
  required Map<String, Object> parameters,
});

abstract interface class EventsAnalyticsTracker {
  Future<void> trackEventListOpened(EventSelectedCity selectedCity);
}

class EventsAnalyticsService implements EventsAnalyticsTracker {
  EventsAnalyticsService({
    EventsAnalyticsLogEvent? logEvent,
  }) : _logEvent = logEvent ?? _firebaseLogEvent;

  static final EventsAnalyticsService instance = EventsAnalyticsService();
  static EventsAnalyticsTracker defaultTracker = instance;

  static const String eventListOpenedEventName = 'event_list_opened';

  final EventsAnalyticsLogEvent _logEvent;

  @override
  Future<void> trackEventListOpened(EventSelectedCity selectedCity) {
    return _logEvent(
      name: eventListOpenedEventName,
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
