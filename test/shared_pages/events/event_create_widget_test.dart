import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
import 'package:small_talk/shared_pages/events/event_create_widget.dart';

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
      _buildTestApp(home: const EventCreateWidget()),
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
        home: const EventCreateWidget(),
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

  testWidgets('fields expose localized semantics labels and hints',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _buildTestApp(home: const EventCreateWidget()),
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
          home: const EventCreateWidget(),
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
      _buildTestApp(home: const EventCreateWidget()),
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
      _buildTestApp(home: const EventCreateWidget()),
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
      _buildTestApp(home: const EventCreateWidget()),
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
          builder: (context, state) => const EventCreateWidget(),
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
        child: _buildTestApp(home: const EventCreateWidget()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateTitleFieldKey), findsOneWidget);
    expect(find.byKey(eventCreateDescriptionFieldKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('create form fields stay presentation-only before submit phase', () {
    final source = File('lib/shared_pages/events/event_create_widget.dart')
        .readAsStringSync();

    expect(source, isNot(contains('EventActionsRepository')));
    expect(source, isNot(contains('EventEditableFields')));
    expect(source, isNot(contains('createRequestId')));
    expect(source, isNot(contains('newEventCreateRequestId')));
    expect(source, isNot(contains('.createEvent(')));
    expect(source, isNot(contains('EventsRecord')));
    expect(source, isNot(contains('FirebaseFirestore')));
  });
}
