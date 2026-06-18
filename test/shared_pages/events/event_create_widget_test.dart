import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
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
              onLanguageDraftChanged:
                  callbackEnabled ? drafts.add : null,
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
  });
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
