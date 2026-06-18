import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/flutter_flow/flutter_flow_util.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/events/event_create_widget.dart';
import 'package:small_talk/services/event_language_catalog.dart';

const _supportedLocales = [
  Locale('ru'),
  Locale('en'),
];

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  FFLocalizationsDelegate(),
  FallbackMaterialLocalizationDelegate(),
  FallbackCupertinoLocalizationDelegate(),
];

Widget _buildTestApp({
  required Widget home,
  Locale locale = const Locale('ru'),
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: _supportedLocales,
    localizationsDelegates: _localizationsDelegates,
    home: home,
  );
}

Widget _buildRouterTestApp(
  GoRouter router, {
  Locale locale = const Locale('ru'),
}) {
  return MaterialApp.router(
    locale: locale,
    supportedLocales: _supportedLocales,
    localizationsDelegates: _localizationsDelegates,
    routerConfig: router,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ru');
    await initializeDateFormatting('en');
    await FFLocalizations.initialize();
  });

  testWidgets('renders title and description fields in Russian',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Создать событие'), findsOneWidget);
    expect(find.byKey(eventCreateTitleLabelKey), findsOneWidget);
    expect(find.byKey(eventCreateTitleFieldKey), findsOneWidget);
    expect(find.text('Название'), findsOneWidget);
    expect(find.text('Разговорный клуб: кофе и английский'), findsOneWidget);
    expect(find.byKey(eventCreateDescriptionLabelKey), findsOneWidget);
    expect(find.byKey(eventCreateDescriptionFieldKey), findsOneWidget);
    expect(find.text('Описание'), findsOneWidget);
    expect(find.text('Расскажите, что будет на встрече'), findsOneWidget);
    expect(find.byKey(eventCreateLevelLabelKey), findsOneWidget);
    expect(find.byKey(eventCreateLevelSelectorKey), findsOneWidget);
    expect(find.text('Уровень'), findsOneWidget);
    expect(_levelSelectorText('B1-C1'), findsOneWidget);
    expect(find.byKey(eventCreateDateLabelKey), findsOneWidget);
    expect(find.byKey(eventCreateDateSelectorKey), findsOneWidget);
    expect(find.text('Дата'), findsOneWidget);
    expect(find.byKey(eventCreateTimeLabelKey), findsOneWidget);
    expect(find.byKey(eventCreateTimeSelectorKey), findsOneWidget);
    expect(find.text('Время'), findsOneWidget);
    expect(_timeSelectorText('18:00'), findsOneWidget);

    final titleField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(eventCreateTitleFieldKey),
        matching: find.byType(TextField),
      ),
    );
    final descriptionField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(eventCreateDescriptionFieldKey),
        matching: find.byType(TextField),
      ),
    );

    expect(titleField.maxLines, 1);
    expect(titleField.textInputAction, TextInputAction.next);
    expect(descriptionField.minLines, 4);
    expect(descriptionField.maxLines, 8);
    expect(descriptionField.keyboardType, TextInputType.multiline);
    expect(descriptionField.textInputAction, TextInputAction.newline);
  });

  testWidgets('renders title and description fields in English',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        locale: const Locale('en'),
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create event'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(
      find.text('Conversation club: coffee and English'),
      findsOneWidget,
    );
    expect(find.text('Description'), findsOneWidget);
    expect(
      find.text('Tell people what will happen at the meetup'),
      findsOneWidget,
    );
    expect(find.text('Level'), findsOneWidget);
    expect(_levelSelectorText('B1-C1'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(_timeSelectorText('18:00'), findsOneWidget);
  });

  testWidgets('renders language selector from catalog in Russian',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventCreateWidget(
            languageCatalogOverride: _languageCatalog,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(eventCreateLanguageLabelKey), findsOneWidget);
      expect(find.text('Язык'), findsOneWidget);
      expect(find.byKey(eventCreateLanguageSelectorKey), findsOneWidget);
      expect(_languageSelectorText('Английский'), findsOneWidget);

      final semantics = tester
          .getSemantics(find.byKey(eventCreateLanguageSelectorSemanticsKey));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isEnabled, isTrue);
      expect(semantics.label, contains('Язык события'));
      expect(semantics.value, contains('Английский'));
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('renders language selector from catalog in English',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          locale: const Locale('en'),
          home: EventCreateWidget(
            languageCatalogOverride: _languageCatalog,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Language'), findsOneWidget);
      expect(_languageSelectorText('English'), findsOneWidget);

      final semantics = tester
          .getSemantics(find.byKey(eventCreateLanguageSelectorSemanticsKey));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isEnabled, isTrue);
      expect(semantics.label, contains('Event language'));
      expect(semantics.value, contains('English'));
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('normalizes initial alternate language code', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          initialLanguageCode: ' ES-419 ',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_languageSelectorText('Испанский'), findsOneWidget);
    expect(_languageSelectorText('Английский'), findsNothing);
  });

  testWidgets('emits normalized initial language draft for submit handoff',
      (tester) async {
    final drafts = <EventCreateLanguageDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          initialLanguageCode: ' ES-419 ',
          onLanguageDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(drafts.map((draft) => draft.languageCode), ['es']);
  });

  testWidgets('emits language draft when handoff callback is added later',
      (tester) async {
    final drafts = <EventCreateLanguageDraft>[];
    var callbackEnabled = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventCreateWidget(
              languageCatalogOverride: _languageCatalog,
              onLanguageDraftChanged: callbackEnabled ? drafts.add : null,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(drafts, isEmpty);

    setHostState(() {
      callbackEnabled = true;
    });
    await tester.pumpAndSettle();

    expect(drafts.map((draft) => draft.languageCode), ['en']);
  });

  testWidgets('opens language sheet and selects primary language code',
      (tester) async {
    final selectedCodes = <String>[];
    final drafts = <EventCreateLanguageDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          onLanguageCodeChanged: selectedCodes.add,
          onLanguageDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateLanguageSelectorKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateLanguageSheetKey), findsOneWidget);
    expect(find.text('Выберите язык'), findsOneWidget);
    expect(find.byKey(eventCreateLanguageOptionKey('en')), findsOneWidget);
    expect(find.byKey(eventCreateLanguageOptionKey('es')), findsOneWidget);

    await tester.tap(find.byKey(eventCreateLanguageOptionKey('es')));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateLanguageSheetKey), findsNothing);
    expect(_languageSelectorText('Испанский'), findsOneWidget);
    expect(selectedCodes, ['es']);
    expect(drafts.map((draft) => draft.languageCode), ['en', 'es']);
  });

  testWidgets('emits default level draft for submit handoff', (tester) async {
    final drafts = <EventCreateLevelDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          onLevelDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(drafts.map(_levelDraftValue), ['B1:C1']);
  });

  testWidgets('emits level draft when handoff callback is added later',
      (tester) async {
    final drafts = <EventCreateLevelDraft>[];
    var callbackEnabled = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventCreateWidget(
              languageCatalogOverride: _languageCatalog,
              onLevelDraftChanged: callbackEnabled ? drafts.add : null,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(drafts, isEmpty);

    setHostState(() {
      callbackEnabled = true;
    });
    await tester.pumpAndSettle();

    expect(drafts.map(_levelDraftValue), ['B1:C1']);
  });

  testWidgets('normalizes initial level range for submit handoff',
      (tester) async {
    final drafts = <EventCreateLevelDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          initialLevelMin: ' a2 ',
          initialLevelMax: ' c1 ',
          onLevelDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_levelSelectorText('A2-C1'), findsOneWidget);
    expect(drafts.map(_levelDraftValue), ['A2:C1']);
  });

  testWidgets('shows same-level range as one level', (tester) async {
    final drafts = <EventCreateLevelDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          initialLevelMin: ' b2 ',
          initialLevelMax: ' b2 ',
          onLevelDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_levelSelectorText('B2'), findsOneWidget);
    expect(_levelSelectorText('B2-B2'), findsNothing);
    expect(drafts.map(_levelDraftValue), ['B2:B2']);
  });

  testWidgets('opens level sheet and selects range', (tester) async {
    final drafts = <EventCreateLevelDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          onLevelDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateLevelSelectorKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateLevelSheetKey), findsOneWidget);
    expect(find.text('Выберите уровень'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(eventCreateLevelMinOptionKey('B1')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(eventCreateLevelMaxOptionKey('C1')))
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(eventCreateLevelMinOptionKey('A2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventCreateLevelMaxOptionKey('B2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventCreateLevelDoneButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateLevelSheetKey), findsNothing);
    expect(_levelSelectorText('A2-B2'), findsOneWidget);
    expect(drafts.map(_levelDraftValue), ['B1:C1', 'A2:B2']);
  });

  testWidgets('keeps level range ordered when selecting reversed bounds',
      (tester) async {
    final drafts = <EventCreateLevelDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          onLevelDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateLevelSelectorKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventCreateLevelMaxOptionKey('A2')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChoiceChip>(find.byKey(eventCreateLevelMinOptionKey('A2')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(eventCreateLevelMaxOptionKey('A2')))
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(eventCreateLevelDoneButtonKey));
    await tester.pumpAndSettle();

    expect(_levelSelectorText('A2'), findsOneWidget);
    expect(drafts.map(_levelDraftValue), ['B1:C1', 'A2:A2']);
  });

  testWidgets('keeps level range ordered when min is above max',
      (tester) async {
    final drafts = <EventCreateLevelDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          onLevelDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateLevelSelectorKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventCreateLevelMinOptionKey('C2')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChoiceChip>(find.byKey(eventCreateLevelMinOptionKey('C2')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(eventCreateLevelMaxOptionKey('C2')))
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(eventCreateLevelDoneButtonKey));
    await tester.pumpAndSettle();

    expect(_levelSelectorText('C2'), findsOneWidget);
    expect(drafts.map(_levelDraftValue), ['B1:C1', 'C2:C2']);
  });

  testWidgets('emits default date draft for submit handoff', (tester) async {
    final drafts = <EventCreateDateDraft>[];
    final todayBefore = _dateOnly(DateTime.now());

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          onDateDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final todayAfter = _dateOnly(DateTime.now());
    expect(drafts, hasLength(1));
    expect(drafts.single.localDate.hour, 0);
    expect(drafts.single.localDate.minute, 0);
    expect(
      <DateTime>{todayBefore, todayAfter},
      contains(drafts.single.localDate),
    );
  });

  testWidgets('emits date draft when handoff callback is added later',
      (tester) async {
    final drafts = <EventCreateDateDraft>[];
    var callbackEnabled = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventCreateWidget(
              languageCatalogOverride: _languageCatalog,
              initialDate: DateTime(2026, 6, 20, 18, 30),
              onDateDraftChanged: callbackEnabled ? drafts.add : null,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(drafts, isEmpty);

    setHostState(() {
      callbackEnabled = true;
    });
    await tester.pumpAndSettle();

    expect(drafts.map(_dateDraftValue), ['2026-06-20']);
  });

  testWidgets('normalizes initial date for submit handoff', (tester) async {
    final drafts = <EventCreateDateDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          initialDate: DateTime(2026, 6, 20, 18, 30),
          onDateDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        _dateSelectorText(_dateLabel(DateTime(2026, 6, 20))), findsOneWidget);
    expect(drafts.map(_dateDraftValue), ['2026-06-20']);
  });

  testWidgets('opens date picker and selects local calendar date',
      (tester) async {
    final drafts = <EventCreateDateDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          initialDate: DateTime(2026, 6, 15),
          onDateDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateDateSelectorKey));
    await tester.pumpAndSettle();

    expect(find.text('Выберите дату'), findsOneWidget);

    await tester.tap(find.text('20').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    expect(
        _dateSelectorText(_dateLabel(DateTime(2026, 6, 20))), findsOneWidget);
    expect(drafts.map(_dateDraftValue), ['2026-06-15', '2026-06-20']);
  });

  testWidgets('cancels date picker without changing date draft',
      (tester) async {
    final drafts = <EventCreateDateDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          initialDate: DateTime(2026, 6, 15),
          onDateDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateDateSelectorKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(
        _dateSelectorText(_dateLabel(DateTime(2026, 6, 15))), findsOneWidget);
    expect(drafts.map(_dateDraftValue), ['2026-06-15']);
  });

  testWidgets('emits default time draft for submit handoff', (tester) async {
    final drafts = <EventCreateTimeDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          onTimeDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(drafts.map(_timeDraftValue), ['18:00']);
  });

  testWidgets('emits time draft when handoff callback is added later',
      (tester) async {
    final drafts = <EventCreateTimeDraft>[];
    var callbackEnabled = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventCreateWidget(
              languageCatalogOverride: _languageCatalog,
              initialTime: const TimeOfDay(hour: 19, minute: 30),
              onTimeDraftChanged: callbackEnabled ? drafts.add : null,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(drafts, isEmpty);

    setHostState(() {
      callbackEnabled = true;
    });
    await tester.pumpAndSettle();

    expect(drafts.map(_timeDraftValue), ['19:30']);
  });

  testWidgets('uses initial time for submit handoff', (tester) async {
    final drafts = <EventCreateTimeDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          initialDate: DateTime(2026, 6, 20, 18, 30),
          initialTime: const TimeOfDay(hour: 7, minute: 5),
          onTimeDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_timeSelectorText('07:05'), findsOneWidget);
    expect(drafts.map(_timeDraftValue), ['07:05']);
  });

  testWidgets('opens time picker and selects local time', (tester) async {
    final drafts = <EventCreateTimeDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          onTimeDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(eventCreateTimeSelectorKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventCreateTimeSelectorKey));
    await tester.pumpAndSettle();

    expect(find.text('Выберите время'), findsOneWidget);
    expect(find.byIcon(Icons.access_time), findsNothing);
    final timeFields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    expect(timeFields, findsNWidgets(2));

    await tester.enterText(timeFields.at(0), '20');
    await tester.enterText(timeFields.at(1), '30');
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    expect(_timeSelectorText('20:30'), findsOneWidget);
    expect(drafts.map(_timeDraftValue), ['18:00', '20:30']);
  });

  testWidgets('cancels time picker without changing time draft',
      (tester) async {
    final drafts = <EventCreateTimeDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          onTimeDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(eventCreateTimeSelectorKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventCreateTimeSelectorKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(_timeSelectorText('18:00'), findsOneWidget);
    expect(drafts.map(_timeDraftValue), ['18:00']);
  });

  testWidgets('shows language loading state before catalog resolves',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final catalogCompleter = Completer<String>();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: DefaultAssetBundle(
            bundle: _PendingLanguageCatalogBundle(catalogCompleter.future),
            child: const EventCreateWidget(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Загрузка языков...'), findsOneWidget);
      final semantics = tester
          .getSemantics(find.byKey(eventCreateLanguageSelectorSemanticsKey));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isEnabled, isFalse);

      catalogCompleter.complete(_languageCatalogJson);
      await tester.pumpAndSettle();
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('shows language loading error without crashing', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: DefaultAssetBundle(
            bundle: _ThrowingLanguageCatalogBundle(),
            child: const EventCreateWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Не удалось загрузить языки'), findsOneWidget);
      final semantics = tester
          .getSemantics(find.byKey(eventCreateLanguageSelectorSemanticsKey));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isEnabled, isFalse);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('reloads language catalog when DefaultAssetBundle changes',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: DefaultAssetBundle(
          bundle: _StaticLanguageCatalogBundle(_languageCatalogJson),
          child: const EventCreateWidget(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_languageSelectorText('Английский'), findsOneWidget);

    await tester.pumpWidget(
      _buildTestApp(
        home: DefaultAssetBundle(
          bundle: _StaticLanguageCatalogBundle(_alternateLanguageCatalogJson),
          child: const EventCreateWidget(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_languageSelectorText('Немецкий'), findsOneWidget);
    expect(_languageSelectorText('Английский'), findsNothing);
  });

  testWidgets('uses latest bundle after language override is removed',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: DefaultAssetBundle(
          bundle: _StaticLanguageCatalogBundle(_languageCatalogJson),
          child: EventCreateWidget(
            languageCatalogOverride: _languageCatalog,
            initialLanguageCode: 'es',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_languageSelectorText('Испанский'), findsOneWidget);

    await tester.pumpWidget(
      _buildTestApp(
        home: DefaultAssetBundle(
          bundle: _StaticLanguageCatalogBundle(_alternateLanguageCatalogJson),
          child: EventCreateWidget(
            languageCatalogOverride: _languageCatalog,
            initialLanguageCode: 'es',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_languageSelectorText('Испанский'), findsOneWidget);

    await tester.pumpWidget(
      _buildTestApp(
        home: DefaultAssetBundle(
          bundle: _StaticLanguageCatalogBundle(_alternateLanguageCatalogJson),
          child: const EventCreateWidget(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_languageSelectorText('Немецкий'), findsOneWidget);
    expect(_languageSelectorText('Испанский'), findsNothing);
  });

  testWidgets('fields expose localized semantics labels and hints',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventCreateWidget(
            languageCatalogOverride: _languageCatalog,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleSemantics =
          tester.getSemantics(find.byKey(eventCreateTitleFieldSemanticsKey));
      expect(titleSemantics.flagsCollection.isTextField, isTrue);
      expect(titleSemantics.flagsCollection.isMultiline, isFalse);
      expect(titleSemantics.label, contains('Название'));
      expect(
        titleSemantics.hint,
        contains('Разговорный клуб: кофе и английский'),
      );

      final descriptionSemantics = tester
          .getSemantics(find.byKey(eventCreateDescriptionFieldSemanticsKey));
      expect(descriptionSemantics.flagsCollection.isTextField, isTrue);
      expect(descriptionSemantics.flagsCollection.isMultiline, isTrue);
      expect(descriptionSemantics.label, contains('Описание'));
      expect(
        descriptionSemantics.hint,
        contains('Расскажите, что будет на встрече'),
      );
      final levelSemantics =
          tester.getSemantics(find.byKey(eventCreateLevelSelectorSemanticsKey));
      expect(levelSemantics.flagsCollection.isButton, isTrue);
      expect(levelSemantics.flagsCollection.isEnabled, isTrue);
      expect(levelSemantics.label, contains('Уровень события'));
      expect(levelSemantics.value, contains('B1-C1'));
      final dateSemantics =
          tester.getSemantics(find.byKey(eventCreateDateSelectorSemanticsKey));
      expect(dateSemantics.flagsCollection.isButton, isTrue);
      expect(dateSemantics.flagsCollection.isEnabled, isTrue);
      expect(dateSemantics.label, contains('Дата события'));
      expect(dateSemantics.value, isNotEmpty);
      final timeSemantics =
          tester.getSemantics(find.byKey(eventCreateTimeSelectorSemanticsKey));
      expect(timeSemantics.flagsCollection.isButton, isTrue);
      expect(timeSemantics.flagsCollection.isEnabled, isTrue);
      expect(timeSemantics.label, contains('Время события'));
      expect(timeSemantics.value, contains('18:00'));
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('fields expose English semantics labels and hints',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(
          locale: const Locale('en'),
          home: EventCreateWidget(
            languageCatalogOverride: _languageCatalog,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleSemantics =
          tester.getSemantics(find.byKey(eventCreateTitleFieldSemanticsKey));
      expect(titleSemantics.flagsCollection.isTextField, isTrue);
      expect(titleSemantics.flagsCollection.isMultiline, isFalse);
      expect(titleSemantics.label, contains('Title'));
      expect(
        titleSemantics.hint,
        contains('Conversation club: coffee and English'),
      );

      final descriptionSemantics = tester
          .getSemantics(find.byKey(eventCreateDescriptionFieldSemanticsKey));
      expect(descriptionSemantics.flagsCollection.isTextField, isTrue);
      expect(descriptionSemantics.flagsCollection.isMultiline, isTrue);
      expect(descriptionSemantics.label, contains('Description'));
      expect(
        descriptionSemantics.hint,
        contains('Tell people what will happen at the meetup'),
      );
      final levelSemantics =
          tester.getSemantics(find.byKey(eventCreateLevelSelectorSemanticsKey));
      expect(levelSemantics.flagsCollection.isButton, isTrue);
      expect(levelSemantics.flagsCollection.isEnabled, isTrue);
      expect(levelSemantics.label, contains('Event level'));
      expect(levelSemantics.value, contains('B1-C1'));
      final dateSemantics =
          tester.getSemantics(find.byKey(eventCreateDateSelectorSemanticsKey));
      expect(dateSemantics.flagsCollection.isButton, isTrue);
      expect(dateSemantics.flagsCollection.isEnabled, isTrue);
      expect(dateSemantics.label, contains('Event date'));
      expect(dateSemantics.value, isNotEmpty);
      final timeSemantics =
          tester.getSemantics(find.byKey(eventCreateTimeSelectorSemanticsKey));
      expect(timeSemantics.flagsCollection.isButton, isTrue);
      expect(timeSemantics.flagsCollection.isEnabled, isTrue);
      expect(timeSemantics.label, contains('Event time'));
      expect(timeSemantics.value, contains('18:00'));
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('title submit moves focus to description field', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateTitleFieldKey));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    final descriptionField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(eventCreateDescriptionFieldKey),
        matching: find.byType(TextField),
      ),
    );
    expect(descriptionField.focusNode?.hasFocus, isTrue);
  });

  testWidgets('keeps entered title and description across rebuilds',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(eventCreateTitleFieldKey),
      'Киновечер на английском',
    );
    await tester.enterText(
      find.byKey(eventCreateDescriptionFieldKey),
      'Смотрим короткий фильм и обсуждаем лексику.',
    );
    await tester.pump();

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Киновечер на английском'), findsOneWidget);
    expect(
      find.text('Смотрим короткий фильм и обсуждаем лексику.'),
      findsOneWidget,
    );
  });

  testWidgets('create route renders the form fields', (tester) async {
    final router = GoRouter(
      initialLocation: EventCreateWidget.routePath,
      routes: [
        GoRoute(
          name: EventCreateWidget.routeName,
          path: EventCreateWidget.routePath,
          builder: (context, state) => EventCreateWidget(
            languageCatalogOverride: _languageCatalog,
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/events/create');
    expect(find.byType(EventCreateWidget), findsOneWidget);
    expect(find.byKey(eventCreateTitleFieldKey), findsOneWidget);
    expect(find.byKey(eventCreateDescriptionFieldKey), findsOneWidget);
    expect(find.byKey(eventCreateLevelSelectorKey), findsOneWidget);
    expect(find.byKey(eventCreateDateSelectorKey), findsOneWidget);
    expect(find.byKey(eventCreateTimeSelectorKey), findsOneWidget);
  });

  testWidgets('form fields fit narrow large-text layouts', (tester) async {
    tester.view.physicalSize = const Size(640, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: _buildTestApp(
          home: EventCreateWidget(
            languageCatalogOverride: _languageCatalog,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateTitleFieldKey), findsOneWidget);
    expect(find.byKey(eventCreateDescriptionFieldKey), findsOneWidget);
    expect(find.byKey(eventCreateLevelSelectorKey), findsOneWidget);
    expect(find.byKey(eventCreateDateSelectorKey), findsOneWidget);
    expect(find.byKey(eventCreateTimeSelectorKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('create form avoids backend submit before submit phase', () {
    final source = File('lib/shared_pages/events/event_create_widget.dart')
        .readAsStringSync();

    expect(source, isNot(contains('EventActionsRepository')));
    expect(source, isNot(contains('EventEditableFields')));
    expect(source, isNot(contains('createRequestId')));
    expect(source, isNot(contains('newEventCreateRequestId')));
    expect(source, isNot(contains('.createEvent(')));
    expect(source, isNot(contains('EventsRecord')));
    expect(source, isNot(contains('FirebaseFirestore')));
    expect(source, isNot(contains('languageNameEn')));
    expect(source, isNot(contains('languageNameRu')));
    expect(source, isNot(contains('startsAt')));
  });
}

Finder _levelSelectorText(String text) => find.descendant(
      of: find.byKey(eventCreateLevelSelectorKey),
      matching: find.text(text),
    );

String _levelDraftValue(EventCreateLevelDraft draft) =>
    '${draft.levelMin}:${draft.levelMax}';

Finder _dateSelectorText(String text) => find.descendant(
      of: find.byKey(eventCreateDateSelectorKey),
      matching: find.text(text),
    );

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dateDraftValue(EventCreateDateDraft draft) =>
    _dateValue(draft.localDate);

String _dateValue(DateTime date) {
  final normalizedDate = _dateOnly(date);
  final month = normalizedDate.month.toString().padLeft(2, '0');
  final day = normalizedDate.day.toString().padLeft(2, '0');
  return '${normalizedDate.year}-$month-$day';
}

String _dateLabel(DateTime date, {Locale locale = const Locale('ru')}) {
  return dateTimeFormat(
    'd MMM y',
    _dateOnly(date),
    locale: locale.languageCode,
  );
}

Finder _timeSelectorText(String text) => find.descendant(
      of: find.byKey(eventCreateTimeSelectorKey),
      matching: find.text(text),
    );

String _timeDraftValue(EventCreateTimeDraft draft) =>
    _timeValue(draft.localTime);

String _timeValue(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

final _languageCatalog = EventLanguageCatalog(
  languages: [
    EventLanguage(
      code: 'en',
      alternateCodes: const ['en', 'en-US'],
      nameEn: 'English',
      nameRu: 'Английский',
      model: 'nova-3',
      isPopular: true,
      iconUrl: 'https://example.com/english.png',
    ),
    EventLanguage(
      code: 'es',
      alternateCodes: const ['es', 'es-419'],
      nameEn: 'Spanish',
      nameRu: 'Испанский',
      model: 'nova-3',
      isPopular: true,
      iconUrl: 'https://example.com/spanish.png',
    ),
  ],
);

const _languageCatalogJson = '''
[
  {
    "code": "en",
    "alternateCodes": ["en", "en-US"],
    "nameEn": "English",
    "nameRu": "Английский",
    "model": "nova-3",
    "isPopular": true,
    "ss": "https://example.com/english.png"
  },
  {
    "code": "es",
    "alternateCodes": ["es", "es-419"],
    "nameEn": "Spanish",
    "nameRu": "Испанский",
    "model": "nova-3",
    "isPopular": true,
    "ss": "https://example.com/spanish.png"
  }
]
''';

const _alternateLanguageCatalogJson = '''
[
  {
    "code": "de",
    "alternateCodes": ["de", "de-DE"],
    "nameEn": "German",
    "nameRu": "Немецкий",
    "model": "nova-3",
    "isPopular": true,
    "ss": "https://example.com/german.png"
  }
]
''';

Finder _languageSelectorText(String text) {
  return find.descendant(
    of: find.byKey(eventCreateLanguageSelectorKey),
    matching: find.text(text),
  );
}

class _StaticLanguageCatalogBundle extends CachingAssetBundle {
  _StaticLanguageCatalogBundle(this.rawCatalog);

  final String rawCatalog;

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError();
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return rawCatalog;
  }
}

class _PendingLanguageCatalogBundle extends CachingAssetBundle {
  _PendingLanguageCatalogBundle(this.rawCatalog);

  final Future<String> rawCatalog;

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError();
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    return rawCatalog;
  }
}

class _ThrowingLanguageCatalogBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError();
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    throw FlutterError('Language catalog failed');
  }
}
