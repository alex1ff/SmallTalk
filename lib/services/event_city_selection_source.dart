enum EventCitySelectionSource {
  profile,
  recent,
  static,
  manual,
}

extension EventCitySelectionSourceAnalytics on EventCitySelectionSource {
  String get analyticsValue {
    switch (this) {
      case EventCitySelectionSource.profile:
        return 'profile';
      case EventCitySelectionSource.recent:
        return 'recent';
      case EventCitySelectionSource.static:
        return 'static';
      case EventCitySelectionSource.manual:
        return 'manual';
    }
  }
}
