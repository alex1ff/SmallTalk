import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_chip_source.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
import 'package:small_talk/services/event_temporary_city_selection.dart';

void main() {
  late EventCityCatalog catalog;

  setUpAll(() {
    catalog = EventCityCatalog.fromJsonString(
      File(eventCityCatalogAssetPath).readAsStringSync(),
    );
  });

  group('EventTemporaryCitySelectionService', () {
    test('returns session-only selected city input and records recent city',
        () async {
      final store = _MemoryRecentCityStore();
      final service = EventTemporaryCitySelectionService(
        chipSource: EventCityChipSource(recentStore: store),
      );

      final input = await service.selectCity(
        city: catalog.resolve('US', 'new_york')!,
        source: EventCitySelectionSource.manual,
      );

      expect(input.countryCode, 'US');
      expect(input.cityKey, 'new_york');
      expect(input.source, EventCitySelectionSource.manual);
      expect(store.saved.map((identity) => identity.identity), ['US:new_york']);
    });

    test('rejects profile source before recording recent city', () async {
      final store = _MemoryRecentCityStore();
      final service = EventTemporaryCitySelectionService(
        chipSource: EventCityChipSource(recentStore: store),
      );

      await expectLater(
        service.selectCity(
          city: catalog.resolve('RU', 'moscow')!,
          source: EventCitySelectionSource.profile,
        ),
        throwsArgumentError,
      );

      expect(store.saved, isEmpty);
    });
  });
}

class _MemoryRecentCityStore implements EventRecentCityStore {
  List<EventCityIdentity> saved = const [];

  @override
  Future<List<EventCityIdentity>> load() async => saved;

  @override
  Future<void> save(List<EventCityIdentity> identities) async {
    saved = [...identities];
  }
}

extension on EventCityIdentity {
  String get identity => '$countryCode:$cityKey';
}
