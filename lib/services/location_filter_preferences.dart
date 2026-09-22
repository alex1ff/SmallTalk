import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'event_city_selection_source.dart';

const locationFilterPreferencesPrefix = 'ff_location_filter_v1';

enum LocationFilterScope {
  homeSearch,
  events,
}

enum LocationFilterMode {
  any,
  selected,
}

class LocationFilterPreference {
  const LocationFilterPreference._({
    required this.mode,
    this.countryCode,
    this.cityKey,
    this.eventSource,
  });

  const LocationFilterPreference.any() : this._(mode: LocationFilterMode.any);

  const LocationFilterPreference.selected({
    required String countryCode,
    required String cityKey,
    EventCitySelectionSource? eventSource,
  }) : this._(
          mode: LocationFilterMode.selected,
          countryCode: countryCode,
          cityKey: cityKey,
          eventSource: eventSource,
        );

  final LocationFilterMode mode;
  final String? countryCode;
  final String? cityKey;
  final EventCitySelectionSource? eventSource;

  bool get isAny => mode == LocationFilterMode.any;
}

class LocationFilterPreferences {
  const LocationFilterPreferences(this._preferences);

  final SharedPreferences _preferences;

  LocationFilterPreference? read({
    required String userId,
    required LocationFilterScope scope,
  }) {
    final key = _key(userId: userId, scope: scope);
    if (key == null) {
      return null;
    }

    try {
      final rawValue = _preferences.getString(key);
      if (rawValue == null || rawValue.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map) {
        return null;
      }
      final data = Map<String, dynamic>.from(decoded);
      final mode = data['mode'];
      if (mode == 'any') {
        return scope == LocationFilterScope.homeSearch
            ? const LocationFilterPreference.any()
            : null;
      }
      if (mode != 'selected') {
        return null;
      }

      final countryCode = data['countryCode']?.toString().trim().toUpperCase();
      final cityKey = data['cityKey']?.toString().trim().toLowerCase();
      if (countryCode == null ||
          countryCode.length != 2 ||
          cityKey == null ||
          cityKey.isEmpty) {
        return null;
      }

      EventCitySelectionSource? eventSource;
      if (scope == LocationFilterScope.events) {
        eventSource = _eventSourceFromValue(data['source']);
        if (eventSource == null) {
          return null;
        }
      }

      return LocationFilterPreference.selected(
        countryCode: countryCode,
        cityKey: cityKey,
        eventSource: eventSource,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<bool> writeAny({required String userId}) => _write(
        userId: userId,
        scope: LocationFilterScope.homeSearch,
        value: const <String, String>{'mode': 'any'},
      );

  Future<bool> writeSelected({
    required String userId,
    required LocationFilterScope scope,
    required String countryCode,
    required String cityKey,
    EventCitySelectionSource? eventSource,
  }) {
    final normalizedCountryCode = countryCode.trim().toUpperCase();
    final normalizedCityKey = cityKey.trim().toLowerCase();
    if (normalizedCountryCode.length != 2 || normalizedCityKey.isEmpty) {
      return Future<bool>.value(false);
    }
    if (scope == LocationFilterScope.events && eventSource == null) {
      return Future<bool>.value(false);
    }

    return _write(
      userId: userId,
      scope: scope,
      value: <String, String>{
        'mode': 'selected',
        'countryCode': normalizedCountryCode,
        'cityKey': normalizedCityKey,
        if (eventSource != null) 'source': eventSource.analyticsValue,
      },
    );
  }

  Future<bool> _write({
    required String userId,
    required LocationFilterScope scope,
    required Map<String, String> value,
  }) async {
    final key = _key(userId: userId, scope: scope);
    if (key == null) {
      return false;
    }
    try {
      return await _preferences.setString(key, jsonEncode(value));
    } catch (_) {
      return false;
    }
  }

  String? _key({
    required String userId,
    required LocationFilterScope scope,
  }) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return null;
    }
    return <String>[
      locationFilterPreferencesPrefix,
      Uri.encodeComponent(normalizedUserId),
      scope.name,
    ].join('|');
  }
}

EventCitySelectionSource? _eventSourceFromValue(Object? value) {
  return switch (value?.toString()) {
    'profile' => EventCitySelectionSource.profile,
    'recent' => EventCitySelectionSource.recent,
    'static' => EventCitySelectionSource.static,
    'manual' => EventCitySelectionSource.manual,
    _ => null,
  };
}
