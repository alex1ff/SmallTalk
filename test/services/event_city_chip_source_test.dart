import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_chip_source.dart';

void main() {
  late EventCityCatalog catalog;

  setUpAll(() {
    catalog = EventCityCatalog.fromJsonString(
      File(eventCityCatalogAssetPath).readAsStringSync(),
    );
  });

  group('EventCityChipSource', () {
    test('returns recent city chips first and fills with static popular cities',
        () async {
      final source = EventCityChipSource(
        recentStore: _MemoryRecentCityStore(
          [
            identity('IT', 'rome'),
            identity('US', 'new_york'),
          ],
        ),
      );

      final chips = await source.loadChips(
        catalog: catalog,
        maxChips: 4,
      );

      expect(chips.map((chip) => chip.city.cityKey), [
        'rome',
        'new_york',
        'moscow',
        'saint_petersburg',
      ]);
      expect(chips.map((chip) => chip.source), [
        EventCitySelectionSource.recent,
        EventCitySelectionSource.recent,
        EventCitySelectionSource.static,
        EventCitySelectionSource.static,
      ]);
    });

    test('uses static popular fallback and country hint when recent is empty',
        () async {
      final source = EventCityChipSource(
        recentStore: _MemoryRecentCityStore(),
      );

      final chips = await source.loadChips(
        catalog: catalog,
        countryCodeHint: ' it ',
        maxChips: 3,
      );

      expect(chips.map((chip) => chip.city.identity), [
        'IT:rome',
        'RU:moscow',
        'US:new_york',
      ]);
      expect(
        chips.map((chip) => chip.source).toSet(),
        {EventCitySelectionSource.static},
      );
    });

    test('country hint ranks only static chips and keeps recent order',
        () async {
      final source = EventCityChipSource(
        recentStore: _MemoryRecentCityStore(
          [
            identity('US', 'new_york'),
            identity('IT', 'rome'),
          ],
        ),
      );

      final chips = await source.loadChips(
        catalog: catalog,
        countryCodeHint: 'RU',
        maxChips: 4,
      );

      expect(chips.map((chip) => chip.city.identity), [
        'US:new_york',
        'IT:rome',
        'RU:moscow',
        'RU:saint_petersburg',
      ]);
      expect(chips.map((chip) => chip.source), [
        EventCitySelectionSource.recent,
        EventCitySelectionSource.recent,
        EventCitySelectionSource.static,
        EventCitySelectionSource.static,
      ]);
    });

    test('dedupes recent and static cities by canonical identity', () async {
      final source = EventCityChipSource(
        recentStore: _MemoryRecentCityStore(
          [
            identity('RU', 'moscow'),
            identity('RU', 'moscow'),
            identity('US', 'new_york'),
          ],
        ),
      );

      final chips = await source.loadChips(
        catalog: catalog,
        maxChips: 4,
      );

      expect(chips.map((chip) => chip.city.identity), [
        'RU:moscow',
        'US:new_york',
        'RU:saint_petersburg',
        'GB:london',
      ]);
      expect(chips.first.source, EventCitySelectionSource.recent);
      expect(
        chips.where((chip) => chip.city.identity == 'RU:moscow'),
        hasLength(1),
      );
    });

    test('excludes selected profile city from recent and static chips',
        () async {
      final selectedCity = catalog.resolve('RU', 'moscow')!;
      final source = EventCityChipSource(
        recentStore: _MemoryRecentCityStore(
          [
            identity('RU', 'moscow'),
            identity('IT', 'rome'),
          ],
        ),
      );

      final chips = await source.loadChips(
        catalog: catalog,
        selectedCityToExclude: selectedCity,
        maxChips: 4,
      );

      expect(
        chips.map((chip) => chip.city.identity),
        isNot(contains('RU:moscow')),
      );
      expect(chips.first.city.identity, 'IT:rome');
      expect(chips.first.source, EventCitySelectionSource.recent);
    });

    test('ignores stale unknown and malformed recent identities', () async {
      final source = EventCityChipSource(
        recentStore: _MemoryRecentCityStore(
          [
            identity('RU', 'unknown_city'),
            identity('RUS', 'moscow'),
            identity('RU', 'Moscow'),
            identity('IT', 'rome'),
          ],
        ),
      );

      final chips = await source.loadChips(
        catalog: catalog,
        maxChips: 3,
      );

      expect(chips.map((chip) => chip.city.identity), [
        'IT:rome',
        'RU:moscow',
        'US:new_york',
      ]);
      expect(chips.first.source, EventCitySelectionSource.recent);
    });

    test('returns no chips for non-positive limits', () async {
      final store = _MemoryRecentCityStore([identity('IT', 'rome')]);
      final source = EventCityChipSource(recentStore: store);

      expect(
        await source.loadChips(catalog: catalog, maxChips: 0),
        isEmpty,
      );
    });

    test('records selections by moving existing city to front and capping',
        () async {
      final store = _MemoryRecentCityStore(
        [
          identity('RU', 'moscow'),
          identity('IT', 'rome'),
          identity('US', 'new_york'),
        ],
      );
      final source = EventCityChipSource(recentStore: store);

      await source.recordSelection(
        city: catalog.resolve('IT', 'rome')!,
        maxRecent: 2,
      );

      expect(store.saved.map((identity) => identity.identity), [
        'IT:rome',
        'RU:moscow',
      ]);
    });

    test('clears recent selections when maxRecent is non-positive', () async {
      final store = _MemoryRecentCityStore(
        [
          identity('RU', 'moscow'),
          identity('IT', 'rome'),
        ],
      );
      final source = EventCityChipSource(recentStore: store);

      await source.recordSelection(
        city: catalog.resolve('IT', 'rome')!,
        maxRecent: 0,
      );

      expect(store.saved, isEmpty);
      expect(await store.load(), isEmpty);
    });
  });

  group('SharedPreferencesEventRecentCityStore', () {
    test('stores only canonical identity fields and ignores malformed entries',
        () async {
      SharedPreferences.setMockInitialValues({
        eventRecentCitySelectionsPrefsKey: <String>[
          '{"countryCode":"IT","cityKey":"rome","cityNameRu":"fake"}',
          '{"countryCode":"RU"}',
          'not-json',
          '{"countryCode":"RU","cityKey":"Moscow"}',
        ],
      });
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesEventRecentCityStore(
        preferences: preferences,
      );

      expect(
        (await store.load()).map((identity) => identity.identity),
        ['IT:rome'],
      );

      await store.save([
        identity('US', 'new_york'),
        identity('RU', 'moscow'),
        identity('RUS', 'moscow'),
        identity('RU', 'Moscow'),
      ]);

      expect(preferences.getStringList(eventRecentCitySelectionsPrefsKey), [
        '{"countryCode":"US","cityKey":"new_york"}',
        '{"countryCode":"RU","cityKey":"moscow"}',
      ]);
    });
  });
}

EventCityIdentity identity(String countryCode, String cityKey) =>
    EventCityIdentity(
      countryCode: countryCode,
      cityKey: cityKey,
    );

class _MemoryRecentCityStore implements EventRecentCityStore {
  _MemoryRecentCityStore([List<EventCityIdentity> identities = const []])
      : _identities = [...identities];

  List<EventCityIdentity> _identities;
  List<EventCityIdentity> saved = const [];

  @override
  Future<List<EventCityIdentity>> load() async => [..._identities];

  @override
  Future<void> save(List<EventCityIdentity> identities) async {
    saved = [...identities];
    _identities = [...identities];
  }
}

extension on EventCityIdentity {
  String get identity => '$countryCode:$cityKey';
}
