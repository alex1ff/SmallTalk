import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/structs/index.dart';
import 'package:small_talk/components/edit_country_widget.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/services/supported_location_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final fixture in <({String name, CountryStruct selected})>[
    (
      name: 'supported selection',
      selected: supportedLocations.first.toCountryStruct(),
    ),
    (
      name: 'legacy selection',
      selected: CountryStruct(code: 'DE', nameEn: 'Germany'),
    ),
  ]) {
    testWidgets('Any location clears ${fixture.name} and closes the picker',
        (tester) async {
      var clearCalls = 0;

      await tester.pumpWidget(
        _testApp(
          EditCountryWidget(
            title: 'Partner location',
            selecte: fixture.selected,
            persistSelectedCountryToUserCountry: false,
            allowClear: true,
            clearAction: () async => clearCalls += 1,
            action: (_) async => fail('A location must not be saved'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Любая локация'), findsOneWidget);
      await tester.tap(find.text('Любая локация'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(clearCalls, 1);
      expect(find.byType(EditCountryWidget), findsNothing);
    });
  }

  test('filters delete the stored preferred location when clearing', () {
    final source =
        File('lib/components/filters_widget.dart').readAsStringSync();

    expect(
      source,
      matches(RegExp(
        r"'preferredLocation'\s*:\s*FieldValue\.delete\(\)",
      )),
    );
  });
}

Widget _testApp(Widget picker) {
  return MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      FFLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FallbackMaterialLocalizationDelegate(),
      FallbackCupertinoLocalizationDelegate(),
    ],
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(body: picker),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}
