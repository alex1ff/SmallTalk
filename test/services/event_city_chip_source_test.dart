import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_chip_source.dart';
import 'package:small_talk/services/event_city_selection_source.dart';

void main() {
  late EventCityCatalog catalog;

  setUpAll(() {
    catalog = EventCityCatalog.fromJsonString(
      File(eventCityCatalogAssetPath).readAsStringSync(),
    );
  });

  group('EventCityChipSource', () {
    test('returns product order while preserving recent analytics sources',
        () async {
      final source = EventCityChipSource(
        recentStore: _MemoryRecentCityStore(
          [
            identity('US', 'new_york'),
            identity('ID', 'bali'),
          ],
        ),
      );

      final chips = await source.loadChips(
        catalog: catalog,
        maxChips: 4,
      );

      expect(chips.map((chip) => chip.city.cityKey), [
        'new_york',
        'bali',
        'dubai',
        'phuket',
      ]);
      expect(chips.map((chip) => chip.source), [
        EventCitySelectionSource.recent,
        EventCitySelectionSource.recent,
        EventCitySelectionSource.static,
        EventCitySelectionSource.static,
      ]);
    });

    test('keeps product order despite a supported country hint', () async {
      final source = EventCityChipSource(
        recentStore: _MemoryRecentCityStore(),
      );

      final chips = await source.loadChips(
        catalog: catalog,
        countryCodeHint: 'AE',
        maxChips: 3,
      );

      expect(chips.map((chip) => chip.city.identity), [
        'US:new_york',
        'ID:bali',
        'AE:dubai',
      ]);
      expect(
        chips.map((chip) => chip.source).toSet(),
        {EventCitySelectionSource.static},
      );
    });

    test('history and country hint never reorder the supported locations',
        () async {
      final source = EventCityChipSource(
        recentStore: _MemoryRecentCityStore(
          [
            identity('AE', 'dubai'),
            identity('US', 'new_york'),
          ],
        ),
      );

      final chips = await source.loadChips(
        catalog: catalog,
        countryCodeHint: 'TH',
        maxChips: 4,
      );

      expect(chips.map((chip) => chip.city.identity), [
        'US:new_york',
        'ID:bali',
        'AE:dubai',
        'TH:phuket',
      ]);
      expect(chips.map((chip) => chip.source), [
        EventCitySelectionSource.recent,
        EventCitySelectionSource.static,
        EventCitySelectionSource.recent,
        EventCitySelectionSource.static,
      ]);
    });

    test('dedupes recent and static cities by canonical identity', () async {
      final source = EventCityChipSource(
        recentStore: _MemoryRecentCityStore(
          [
            identity('ID', 'bali'),
            identity('ID', 'bali'),
            identity('US', 'new_york'),
          ],
        ),
      );

      final chips = await source.loadChips(
        catalog: catalog,
        maxChips: 4,
      );

      expect(chips.map((chip) => chip.city.identity), [
        'US:new_york',
        'ID:bali',
        'AE:dubai',
        'TH:phuket',
      ]);
      expect(chips.first.source, EventCitySelectionSource.recent);
      expect(
        chips.where((chip) => chip.city.identity == 'ID:bali'),
        hasLength(1),
      );
    });

    test('dedupes recent entries while keeping only supported locations',
        () async {
      final duplicateCityKeyCatalog = EventCityCatalog.fromMap({
        'catalogVersion': 'test',
        'cities': [
          cityFixture(
            countryCode: 'US',
            cityKey: 'new_york',
            displayContext: 'US',
            priority: 30,
          ),
          cityFixture(
            countryCode: 'ID',
            cityKey: 'bali',
            displayContext: 'Indonesia',
            priority: 20,
          ),
          cityFixture(
            countryCode: 'AE',
            cityKey: 'dubai',
            displayContext: 'UAE',
            priority: 10,
          ),
        ],
      });
      final source = EventCityChipSource(
        recentStore: _MemoryRecentCityStore(
          [
            identity('US', 'new_york'),
            identity('US', 'new_york'),
          ],
        ),
      );

      final chips = await source.loadChips(
        catalog: duplicateCityKeyCatalog,
        maxChips: 3,
      );

      expect(chips.map((chip) => chip.city.identity), [
        'US:new_york',
        'ID:bali',
        'AE:dubai',
      ]);
      expect(chips.map((chip) => chip.source), [
        EventCitySelectionSource.recent,
        EventCitySelectionSource.static,
        EventCitySelectionSource.static,
      ]);
    });

    test('excludes selected profile city from recent and static chips',
        () async {
      final selectedCity = catalog.resolve('US', 'new_york')!;
      final source = EventCityChipSource(
        recentStore: _MemoryRecentCityStore(
          [
            identity('US', 'new_york'),
            identity('ID', 'bali'),
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
        isNot(contains('US:new_york')),
      );
      expect(chips.first.city.identity, 'ID:bali');
      expect(chips.first.source, EventCitySelectionSource.recent);
    });

    test('ignores stale unknown and malformed recent identities', () async {
      final source = EventCityChipSource(
        recentStore: _MemoryRecentCityStore(
          [
            identity('RU', 'unknown_city'),
            identity('RUS', 'moscow'),
            identity('RU', 'Moscow'),
            identity('AE', 'dubai'),
          ],
        ),
      );

      final chips = await source.loadChips(
        catalog: catalog,
        maxChips: 3,
      );

      expect(chips.map((chip) => chip.city.identity), [
        'US:new_york',
        'ID:bali',
        'AE:dubai',
      ]);
      expect(chips.last.source, EventCitySelectionSource.recent);
    });

    test(
        'falls back to static popular cities when all recent entries are stale',
        () async {
      final source = EventCityChipSource(
        recentStore: _MemoryRecentCityStore(
          [
            identity('RU', 'unknown_city'),
            identity('RUS', 'moscow'),
            identity('RU', 'Moscow'),
          ],
        ),
      );

      final chips = await source.loadChips(
        catalog: catalog,
        maxChips: 2,
      );

      expect(
        chips.map((chip) => chip.city.identity).toList(),
        ['US:new_york', 'ID:bali'],
      );
      expect(
        chips.map((chip) => chip.source).toSet(),
        {EventCitySelectionSource.static},
      );
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

Map<String, Object?> cityFixture({
  required String countryCode,
  required String cityKey,
  required String displayContext,
  required int priority,
}) =>
    {
      'countryCode': countryCode,
      'cityKey': cityKey,
      'nameRu': cityKey,
      'nameEn': cityKey,
      'regionCode': null,
      'regionNameRu': null,
      'regionNameEn': null,
      'timeZoneId': 'UTC/Test',
      'displayContext': displayContext,
      'aliases': [cityKey],
      'transliterations': [cityKey],
      'priority': priority,
    };

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
