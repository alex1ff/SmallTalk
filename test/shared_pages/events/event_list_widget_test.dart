import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:small_talk/flutter_flow/custom_icons.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/events/event_create_widget.dart';
import 'package:small_talk/shared_pages/events/event_list_widget.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
import 'package:small_talk/services/event_selected_city_state.dart';

const _supportedLocales = [
  Locale('ru'),
  Locale('en'),
];

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  FFLocalizationsDelegate(),
  FallbackMaterialLocalizationDelegate(),
  FallbackCupertinoLocalizationDelegate(),
];

Widget _buildTestApp({Widget home = const EventListWidget()}) {
  return MaterialApp(
    locale: Locale('ru'),
    supportedLocales: _supportedLocales,
    localizationsDelegates: _localizationsDelegates,
    home: home,
  );
}

Widget _buildRouterTestApp(GoRouter router) {
  return MaterialApp.router(
    locale: const Locale('ru'),
    supportedLocales: _supportedLocales,
    localizationsDelegates: _localizationsDelegates,
    routerConfig: router,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the events screen header title', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    final title = find.text('События');

    expect(title, findsOneWidget);

    final titleText = tester.widget<Text>(title);
    expect(titleText.style?.fontSize, 34);
    expect(titleText.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('shows the create event button in the header', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    expect(find.byKey(eventListCreateButtonKey), findsOneWidget);
    expect(find.byIcon(Icons.add_sharp), findsOneWidget);
  });

  testWidgets('shows a city selector placeholder below the header',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());

    expect(find.byKey(eventListCitySelectorKey), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.byIcon(FFIcons.kchevronDown), findsOneWidget);
    expect(find.text('Выберите город'), findsOneWidget);
  });

  testWidgets('shows selected city display name without identity',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          initialSelectedCity: EventSelectedCity(
            city: _cityFixture(
              countryCode: 'RU',
              cityKey: 'moscow',
              cityNameRu: 'Москва',
              cityNameEn: 'Moscow',
              cityDisplayContext: 'Россия',
            ),
            source: EventCitySelectionSource.manual,
          ),
        ),
      ),
    );

    expect(find.text('Москва · Россия'), findsOneWidget);
    expect(find.textContaining('RU:moscow'), findsNothing);
  });

  testWidgets('city selector delegates taps when a callback is provided',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _buildTestApp(
        home: EventListWidget(
          onCitySelectorPressed: () => taps += 1,
        ),
      ),
    );

    await tester.tap(find.byKey(eventListCitySelectorKey));

    expect(taps, 1);
  });

  testWidgets('opens event create as a pushed screen from the header',
      (tester) async {
    final router = GoRouter(
      initialLocation: EventListWidget.routePath,
      routes: [
        GoRoute(
          name: EventListWidget.routeName,
          path: EventListWidget.routePath,
          builder: (context, state) => const EventListWidget(),
        ),
        GoRoute(
          name: EventCreateWidget.routeName,
          path: EventCreateWidget.routePath,
          builder: (context, state) => const EventCreateWidget(),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventListCreateButtonKey));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/events/create');
    expect(find.byType(EventCreateWidget), findsOneWidget);

    await tester.tap(find.byIcon(FFIcons.kchevronLeft));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/events');
    expect(find.byType(EventListWidget), findsOneWidget);
  });

  test('event list city selector state avoids loading event data early', () {
    final source = File('lib/shared_pages/events/event_list_widget.dart')
        .readAsStringSync();

    expect(source, isNot(contains('EventListRepository')));
    expect(source, isNot(contains('EventsRecord')));
    expect(source, isNot(contains('queryEventsRecord')));
    expect(source, isNot(contains('resolveEventSelectedCityState')));
    expect(source, isNot(contains('currentUserDocument')));
  });
}

EventCity _cityFixture({
  required String countryCode,
  required String cityKey,
  required String cityNameRu,
  required String cityNameEn,
  required String cityDisplayContext,
}) {
  return EventCity(
    countryCode: countryCode,
    cityKey: cityKey,
    cityNameRu: cityNameRu,
    cityNameEn: cityNameEn,
    regionCode: null,
    regionNameRu: null,
    regionNameEn: null,
    timeZoneId: 'Europe/Moscow',
    cityDisplayContext: cityDisplayContext,
    aliases: const [],
    transliterations: const [],
    priority: 100,
  );
}
