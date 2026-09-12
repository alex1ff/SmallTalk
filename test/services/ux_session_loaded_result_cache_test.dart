import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/ux_loading_state.dart';
import 'package:small_talk/services/ux_session_loaded_result_cache.dart';

void main() {
  group('UxSessionLoadedResultCache', () {
    test('rejects invalid cache limits and ttl', () {
      expect(
        () => UxSessionLoadedResultCache<String>(maxEntries: 0),
        throwsArgumentError,
      );
      expect(
        () => UxSessionLoadedResultCache<String>(ttl: Duration.zero),
        throwsArgumentError,
      );
      expect(
        () => UxSessionLoadedResultCache<String>(
          ttl: const Duration(microseconds: -1),
        ),
        throwsArgumentError,
      );
    });

    test('stores and reads loaded results by deep data key equality', () {
      final cache = UxSessionLoadedResultCache<String>();
      final result = UxLoadedResult<String>.data(
        dataKey: {
          'screen': 'events',
          'filters': ['today', 'B1'],
        },
        data: 'club',
      );

      cache.write(result);

      expect(
        cache.read({
          'screen': 'events',
          'filters': ['today', 'B1'],
        }),
        result,
      );
      expect(cache.read('events'), isNull);
    });

    test('freezes collection keys when writing entries', () {
      final cache = UxSessionLoadedResultCache<String>();
      final filters = <String>['today'];
      final dataKey = <String, Object>{
        'screen': 'events',
        'filters': filters,
      };

      cache.write(
        UxLoadedResult<String>.data(
          dataKey: dataKey,
          data: 'club',
        ),
      );

      filters.add('B1');

      expect(
        cache.read({
          'screen': 'events',
          'filters': ['today'],
        })?.data,
        'club',
      );
      expect(
        cache.read({
          'screen': 'events',
          'filters': ['today', 'B1'],
        }),
        isNull,
      );
    });

    test('keeps confirmed empty as a typed cache result', () {
      final cache = UxSessionLoadedResultCache<List<String>>();

      cache.writeItems(
        dataKey: 'words:user-a',
        items: const <String>[],
      );

      final result = cache.read('words:user-a');
      expect(result, isNotNull);
      expect(result!.kind, UxLoadedResultKind.empty);
      expect(cache.readItems('words:user-a'), isEmpty);
    });

    test('does not turn domain state without payload into empty list', () {
      final cache = UxSessionLoadedResultCache<List<String>>();

      cache.write(
        UxLoadedResult<List<String>>.domain(
          dataKey: 'event:deleted',
          state: 'deleted',
        ),
      );

      expect(cache.readItems('event:deleted'), isNull);
    });

    test('expires entries after ttl', () {
      var now = DateTime.utc(2035, 1, 1, 12);
      final cache = UxSessionLoadedResultCache<String>(
        ttl: const Duration(minutes: 5),
        nowUtcProvider: () => now,
      );
      cache.write(
        UxLoadedResult<String>.data(
          dataKey: 'profile:stats',
          data: 'fresh',
        ),
      );

      now = now.add(const Duration(minutes: 5));
      expect(cache.read('profile:stats')?.data, 'fresh');

      now = now.add(const Duration(microseconds: 1));
      expect(cache.read('profile:stats'), isNull);
      expect(cache.isEmpty, true);
    });

    test('public length and empty state ignore expired entries', () {
      var now = DateTime.utc(2035, 1, 1, 12);
      final cache = UxSessionLoadedResultCache<String>(
        ttl: const Duration(minutes: 5),
        nowUtcProvider: () => now,
      );
      cache.write(
        UxLoadedResult<String>.data(
          dataKey: 'profile:stats',
          data: 'fresh',
        ),
      );

      expect(cache.length, 1);
      expect(cache.isNotEmpty, true);

      now = now.add(const Duration(minutes: 6));

      expect(cache.length, 0);
      expect(cache.isEmpty, true);
    });

    test('evicts least recently used entries after maxEntries', () {
      final cache = UxSessionLoadedResultCache<String>(maxEntries: 2);
      cache.write(
        UxLoadedResult<String>.data(dataKey: 'a', data: 'A'),
      );
      cache.write(
        UxLoadedResult<String>.data(dataKey: 'b', data: 'B'),
      );

      expect(cache.read('a')?.data, 'A');

      cache.write(
        UxLoadedResult<String>.data(dataKey: 'c', data: 'C'),
      );

      expect(cache.read('b'), isNull);
      expect(cache.read('a')?.data, 'A');
      expect(cache.read('c')?.data, 'C');
    });

    test('remove and clear drop entries explicitly', () {
      final cache = UxSessionLoadedResultCache<String>();
      cache.write(
        UxLoadedResult<String>.data(dataKey: 'chat:a', data: 'A'),
      );
      cache.write(
        UxLoadedResult<String>.data(dataKey: 'chat:b', data: 'B'),
      );

      cache.remove('chat:a');

      expect(cache.read('chat:a'), isNull);
      expect(cache.read('chat:b')?.data, 'B');

      cache.clear();

      expect(cache.isEmpty, true);
      expect(cache.read('chat:b'), isNull);
    });
  });
}
