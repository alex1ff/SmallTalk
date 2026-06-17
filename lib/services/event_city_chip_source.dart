import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'event_city_catalog.dart';

const eventRecentCitySelectionsPrefsKey = 'ff_events_recent_city_selections_v1';

enum EventCitySelectionSource {
  profile,
  recent,
  static,
  manual,
}

class EventCityChip {
  const EventCityChip({
    required this.city,
    required this.source,
  });

  final EventCity city;
  final EventCitySelectionSource source;
}

abstract interface class EventRecentCityStore {
  Future<List<EventCityIdentity>> load();
  Future<void> save(List<EventCityIdentity> identities);
}

class SharedPreferencesEventRecentCityStore implements EventRecentCityStore {
  const SharedPreferencesEventRecentCityStore({
    required this.preferences,
    this.key = eventRecentCitySelectionsPrefsKey,
  });

  final SharedPreferences preferences;
  final String key;

  @override
  Future<List<EventCityIdentity>> load() async {
    final rawEntries = preferences.getStringList(key) ?? const <String>[];
    final identities = <EventCityIdentity>[];
    for (final rawEntry in rawEntries) {
      final identity = _decodeRecentCityIdentity(rawEntry);
      if (identity != null) {
        identities.add(identity);
      }
    }
    return identities;
  }

  @override
  Future<void> save(List<EventCityIdentity> identities) async {
    final encoded = <String>[];
    for (final identity in identities) {
      final normalized = _normalizeRecentCityIdentity(identity);
      if (normalized != null) {
        encoded.add(_encodeRecentCityIdentity(normalized));
      }
    }
    await preferences.setStringList(
      key,
      encoded,
    );
  }
}

class EventCityChipSource {
  const EventCityChipSource({
    required EventRecentCityStore recentStore,
  }) : _recentStore = recentStore;

  final EventRecentCityStore _recentStore;

  Future<List<EventCityChip>> loadChips({
    required EventCityCatalog catalog,
    EventCity? selectedCityToExclude,
    String? countryCodeHint,
    int maxChips = 8,
  }) async {
    if (maxChips <= 0) {
      return const [];
    }

    final selectedIdentity = selectedCityToExclude?.identity;
    final seen = <String>{};
    if (selectedIdentity != null) {
      seen.add(selectedIdentity);
    }

    final chips = <EventCityChip>[];
    final recentIdentities = await _recentStore.load();
    for (final identity in recentIdentities) {
      if (chips.length >= maxChips) {
        return List.unmodifiable(chips);
      }
      final city = catalog.resolve(identity.countryCode, identity.cityKey);
      if (city == null || !seen.add(city.identity)) {
        continue;
      }
      chips.add(
        EventCityChip(
          city: city,
          source: EventCitySelectionSource.recent,
        ),
      );
    }

    for (final city
        in catalog.popularCities(countryCodeHint: countryCodeHint)) {
      if (chips.length >= maxChips) {
        break;
      }
      if (!seen.add(city.identity)) {
        continue;
      }
      chips.add(
        EventCityChip(
          city: city,
          source: EventCitySelectionSource.static,
        ),
      );
    }

    return List.unmodifiable(chips);
  }

  Future<void> recordSelection({
    required EventCity city,
    int maxRecent = 10,
  }) async {
    if (maxRecent <= 0) {
      await _recentStore.save(const []);
      return;
    }

    final existing = await _recentStore.load();
    final next = <EventCityIdentity>[
      EventCityIdentity(
        countryCode: city.countryCode,
        cityKey: city.cityKey,
      ),
    ];
    final seen = <String>{city.identity};
    for (final identity in existing) {
      final normalized = normalizeEventCityIdentity(
        identity.countryCode,
        identity.cityKey,
      );
      if (normalized == null) {
        continue;
      }
      final identityKey = '${normalized.countryCode}:${normalized.cityKey}';
      if (!seen.add(identityKey)) {
        continue;
      }
      next.add(normalized);
      if (next.length >= maxRecent) {
        break;
      }
    }

    await _recentStore.save(next);
  }
}

EventCityIdentity? _decodeRecentCityIdentity(String rawEntry) {
  try {
    final decoded = jsonDecode(rawEntry);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final countryCode = decoded['countryCode'];
    final cityKey = decoded['cityKey'];
    if (countryCode is! String || cityKey is! String) {
      return null;
    }
    return normalizeEventCityIdentity(
      countryCode,
      cityKey,
    );
  } catch (_) {
    return null;
  }
}

EventCityIdentity? _normalizeRecentCityIdentity(EventCityIdentity identity) =>
    normalizeEventCityIdentity(identity.countryCode, identity.cityKey);

String _encodeRecentCityIdentity(EventCityIdentity identity) => jsonEncode(
      <String, String>{
        'countryCode': identity.countryCode,
        'cityKey': identity.cityKey,
      },
    );
