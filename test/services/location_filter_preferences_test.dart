import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
import 'package:small_talk/services/location_filter_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  test('stores independent home and Events selections per user', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = LocationFilterPreferences(preferences);

    await store.writeSelected(
      userId: 'user-a',
      scope: LocationFilterScope.homeSearch,
      countryCode: 'US',
      cityKey: 'new_york',
    );
    await store.writeSelected(
      userId: 'user-a',
      scope: LocationFilterScope.events,
      countryCode: 'ID',
      cityKey: 'bali',
      eventSource: EventCitySelectionSource.manual,
    );

    final home = store.read(
      userId: 'user-a',
      scope: LocationFilterScope.homeSearch,
    );
    final events = store.read(
      userId: 'user-a',
      scope: LocationFilterScope.events,
    );

    expect(home?.countryCode, 'US');
    expect(home?.cityKey, 'new_york');
    expect(events?.countryCode, 'ID');
    expect(events?.cityKey, 'bali');
    expect(events?.eventSource, EventCitySelectionSource.manual);
    expect(
      store.read(
        userId: 'user-b',
        scope: LocationFilterScope.homeSearch,
      ),
      isNull,
    );
  });

  test('keeps an explicit Any selection for home search', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = LocationFilterPreferences(preferences);

    await store.writeAny(userId: 'user-a');

    final value = store.read(
      userId: 'user-a',
      scope: LocationFilterScope.homeSearch,
    );
    expect(value?.isAny, isTrue);
  });

  test('ignores malformed values and unknown Events sources', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      '$locationFilterPreferencesPrefix|user-a|homeSearch': 'not-json',
      '$locationFilterPreferencesPrefix|user-a|events':
          '{"mode":"selected","countryCode":"US","cityKey":"new_york","source":"unknown"}',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = LocationFilterPreferences(preferences);

    expect(
      store.read(
        userId: 'user-a',
        scope: LocationFilterScope.homeSearch,
      ),
      isNull,
    );
    expect(
      store.read(
        userId: 'user-a',
        scope: LocationFilterScope.events,
      ),
      isNull,
    );
  });
}
