import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/flutter_flow/flutter_flow_util.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/events/event_create_widget.dart';
import 'package:small_talk/shared_pages/events/event_detail_widget.dart';
import 'package:small_talk/services/event_action_error_mapper.dart';
import 'package:small_talk/services/event_actions_repository.dart';
import 'package:small_talk/services/event_city_chip_source.dart';
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
import 'package:small_talk/services/event_selected_city_state.dart';
import 'package:small_talk/services/event_language_catalog.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';
import 'package:small_talk/services/events_analytics_service.dart';

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

GoRouter _buildEventCreateRouter({
  EventFormMode formMode = EventFormMode.create,
  String eventId = 'event-1',
  String? initialTitle,
  String? initialDescription,
  String? initialLanguageCode,
  String? initialLevelMin,
  String? initialLevelMax,
  EventSelectedCity? initialSelectedCity,
  String? initialLocationName,
  DateTime? initialDate,
  TimeOfDay? initialTime,
  int? initialCapacity,
  int? minimumCapacity,
  DateTime Function()? currentUtcProvider,
  EventCallableInvoker? createEventInvoker,
  EventCallableInvoker? editEventInvoker,
  EventsAnalyticsTracker? analyticsTracker,
  String Function()? createRequestIdGenerator,
}) {
  return GoRouter(
    initialLocation: EventCreateWidget.routePath,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Text('Events home'),
        ),
      ),
      GoRoute(
        name: EventCreateWidget.routeName,
        path: EventCreateWidget.routePath,
        builder: (context, state) => EventCreateWidget(
          formMode: formMode,
          eventId: eventId,
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialTitle: initialTitle,
          initialDescription: initialDescription,
          initialLanguageCode: initialLanguageCode,
          initialLevelMin: initialLevelMin,
          initialLevelMax: initialLevelMax,
          initialSelectedCity: initialSelectedCity,
          initialLocationName: initialLocationName,
          initialDate: initialDate,
          initialTime: initialTime,
          initialCapacity: initialCapacity,
          minimumCapacity: minimumCapacity,
          currentUtcProvider: currentUtcProvider,
          createEventInvoker: createEventInvoker,
          editEventInvoker: editEventInvoker,
          analyticsTracker: analyticsTracker,
          createRequestIdGenerator: createRequestIdGenerator,
        ),
      ),
      GoRoute(
        name: EventDetailWidget.routeName,
        path: EventDetailWidget.routePath,
        builder: (context, state) => EventDetailWidget(
          eventId: state.pathParameters['eventId']!,
        ),
      ),
    ],
  );
}

class _TestFirebaseAuthPlatform extends FirebaseAuthPlatform {
  _TestFirebaseAuthPlatform({FirebaseApp? app}) : super(appInstance: app);

  UserPlatform? _currentUser;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) {
    return _TestFirebaseAuthPlatform(app: app).._currentUser = _currentUser;
  }

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) {
    this.languageCode = languageCode;
    return this;
  }

  @override
  UserPlatform? get currentUser => _currentUser;

  @override
  set currentUser(UserPlatform? userPlatform) {
    _currentUser = userPlatform;
  }

  @override
  String? languageCode;

  @override
  Stream<UserPlatform?> authStateChanges() =>
      const Stream<UserPlatform?>.empty();

  @override
  Stream<UserPlatform?> idTokenChanges() => const Stream<UserPlatform?>.empty();

  @override
  Stream<UserPlatform?> userChanges() => const Stream<UserPlatform?>.empty();
}

class _TestAuthUser extends BaseAuthUser {
  _TestAuthUser(this._uid);

  final String _uid;

  @override
  bool get loggedIn => true;

  @override
  bool get emailVerified => true;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(uid: _uid);

  @override
  Future? delete() => null;

  @override
  Future? sendEmailVerification() => null;

  @override
  Future? updateEmail(String email) => null;

  @override
  Future? updatePassword(String newPassword) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ru');
    await initializeDateFormatting('en');
    initializeEventListTimeZones();
    setupFirebaseCoreMocks();
    await FFLocalizations.initialize();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _TestFirebaseAuthPlatform();
  });

  setUp(() {
    EventsAnalyticsService.defaultTracker = const _NoopEventsAnalyticsTracker();
  });

  tearDown(() {
    EventsAnalyticsService.defaultTracker = EventsAnalyticsService.instance;
    currentUser = null;
    currentUserDocument = null;
    SharedPreferences.setMockInitialValues({});
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
    expect(find.byKey(eventCreateCityLabelKey), findsOneWidget);
    expect(find.byKey(eventCreateCitySelectorKey), findsOneWidget);
    expect(find.text('Город'), findsOneWidget);
    expect(find.byKey(eventCreateLocationLabelKey), findsOneWidget);
    expect(find.byKey(eventCreateLocationFieldKey), findsOneWidget);
    expect(find.text('Место'), findsOneWidget);
    expect(find.text('Кафе, адрес или ориентир'), findsOneWidget);
    expect(find.byKey(eventCreateDateLabelKey), findsOneWidget);
    expect(find.byKey(eventCreateDateSelectorKey), findsOneWidget);
    expect(find.text('Дата'), findsOneWidget);
    expect(find.byKey(eventCreateTimeLabelKey), findsOneWidget);
    expect(find.byKey(eventCreateTimeSelectorKey), findsOneWidget);
    expect(find.text('Время'), findsOneWidget);
    expect(_timeSelectorText('18:00'), findsOneWidget);
    expect(find.byKey(eventCreateCapacityLabelKey), findsOneWidget);
    expect(find.byKey(eventCreateCapacityFieldKey), findsOneWidget);
    expect(find.text('Лимит участников'), findsOneWidget);
    expect(find.byKey(eventCreateSubmitButtonKey), findsOneWidget);
    expect(find.text('Создать'), findsOneWidget);

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
    final locationField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(eventCreateLocationFieldKey),
        matching: find.byType(TextField),
      ),
    );
    expect(locationField.minLines, 1);
    expect(locationField.maxLines, 2);
    expect(locationField.keyboardType, TextInputType.streetAddress);
    expect(locationField.textInputAction, TextInputAction.done);
    final capacityField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(eventCreateCapacityFieldKey),
        matching: find.byType(TextField),
      ),
    );
    expect(capacityField.maxLines, 1);
    expect(capacityField.keyboardType, TextInputType.number);
    expect(capacityField.textInputAction, TextInputAction.done);
    expect(capacityField.controller?.text, '10');
    expect(capacityField.inputFormatters, hasLength(1));
    expect(
      capacityField.inputFormatters!.single,
      isA<FilteringTextInputFormatter>(),
    );
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
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Place'), findsOneWidget);
    expect(find.text('Cafe, address, or landmark'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(_timeSelectorText('18:00'), findsOneWidget);
    expect(find.text('Participant limit'), findsOneWidget);
    expect(find.byKey(eventCreateSubmitButtonKey), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    final capacityField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(eventCreateCapacityFieldKey),
        matching: find.byType(TextField),
      ),
    );
    expect(capacityField.controller?.text, '10');
  });

  testWidgets('emits title and description drafts locally', (tester) async {
    final titleDrafts = <EventCreateTitleDraft>[];
    final descriptionDrafts = <EventCreateDescriptionDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          initialTitle: '  Клуб выходного дня  ',
          initialDescription: 'Первая строка\nВторая строка',
          onTitleDraftChanged: titleDrafts.add,
          onDescriptionDraftChanged: descriptionDrafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(titleDrafts.map(_titleDraftValue), ['  Клуб выходного дня  ']);
    expect(
      descriptionDrafts.map(_descriptionDraftValue),
      ['Первая строка\nВторая строка'],
    );

    await tester.enterText(
      find.byKey(eventCreateTitleFieldKey),
      'Разговорная встреча',
    );
    await tester.enterText(
      find.byKey(eventCreateDescriptionFieldKey),
      'Говорим о фильмах и путешествиях.',
    );
    await tester.pump();

    expect(titleDrafts.map(_titleDraftValue),
        ['  Клуб выходного дня  ', 'Разговорная встреча']);
    expect(
      descriptionDrafts.map(_descriptionDraftValue),
      ['Первая строка\nВторая строка', 'Говорим о фильмах и путешествиях.'],
    );
  });

  testWidgets('emits text drafts when callbacks are added later',
      (tester) async {
    final titleDrafts = <EventCreateTitleDraft>[];
    final descriptionDrafts = <EventCreateDescriptionDraft>[];
    var callbackEnabled = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventCreateWidget(
              languageCatalogOverride: _languageCatalog,
              onTitleDraftChanged: callbackEnabled ? titleDrafts.add : null,
              onDescriptionDraftChanged:
                  callbackEnabled ? descriptionDrafts.add : null,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(eventCreateTitleFieldKey),
      'Книжный клуб',
    );
    await tester.enterText(
      find.byKey(eventCreateDescriptionFieldKey),
      'Обсуждаем короткий рассказ.',
    );
    await tester.pump();

    expect(titleDrafts, isEmpty);
    expect(descriptionDrafts, isEmpty);

    setHostState(() {
      callbackEnabled = true;
    });
    await tester.pumpAndSettle();

    expect(titleDrafts.map(_titleDraftValue), ['Книжный клуб']);
    expect(descriptionDrafts.map(_descriptionDraftValue),
        ['Обсуждаем короткий рассказ.']);
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

  testWidgets('shows missing city selector and quick city chips',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateCityLabelKey), findsOneWidget);
    expect(find.text('Город'), findsOneWidget);
    expect(_citySelectorText('Выберите город'), findsOneWidget);
    expect(
      find.text('Выберите город события или нажмите один из вариантов ниже.'),
      findsOneWidget,
    );
    expect(find.byKey(eventCreateCityChipKey(_moscowCity)), findsOneWidget);
    expect(find.byKey(eventCreateCityChipKey(_newYorkCity)), findsOneWidget);
  });

  testWidgets('uses country hint to order city chips', (tester) async {
    currentUserDocument = _userFixture(
      uid: 'country-hint-user',
      data: const {
        'Country_NS': {'code': 'US'},
      },
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _widgetIndex(tester, find.byKey(eventCreateCityChipKey(_newYorkCity))),
      lessThan(
        _widgetIndex(tester, find.byKey(eventCreateCityChipKey(_moscowCity))),
      ),
    );
  });

  testWidgets('uses resolved profile city as default submit draft',
      (tester) async {
    final drafts = <EventCreateCityDraft>[];
    currentUserDocument = _userFixture(
      uid: 'profile-city-user',
      data: {
        'Country_NS': {'code': 'US'},
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _cityCatalog.catalogVersion,
        ).toMap(),
      },
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          onCityDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_citySelectorText('Москва · Россия'), findsOneWidget);
    expect(find.textContaining('Stored city'), findsNothing);
    expect(find.byKey(eventCreateCityChipKey(_moscowCity)), findsNothing);
    expect(drafts.map(_cityDraftValue), ['RU:moscow:Europe/Moscow:profile']);
  });

  testWidgets('shows stale profile city prompt without draft', (tester) async {
    final drafts = <EventCreateCityDraft>[];
    currentUserDocument = _userFixture(
      uid: 'stale-profile-city-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: 'old-version',
        ).toMap(),
      },
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          onCityDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_citySelectorText('Выберите город заново'), findsOneWidget);
    expect(
      find.text(
        'Сохранённый город больше недоступен. Выберите актуальный город для события.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(eventCreateCityChipKey(_moscowCity)), findsNothing);
    expect(drafts, isEmpty);
  });

  testWidgets('waits for current user document before showing city chips',
      (tester) async {
    currentUser = _TestAuthUser('loading-profile-user');

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_citySelectorText('Загрузка городов...'), findsOneWidget);
    expect(find.byKey(eventCreateCityChipKey(_moscowCity)), findsNothing);
    expect(find.byKey(eventCreateCityChipKey(_newYorkCity)), findsNothing);
  });

  testWidgets('updates city selector when profile city arrives later',
      (tester) async {
    final drafts = <EventCreateCityDraft>[];
    currentUser = _TestAuthUser('late-profile-city-user');
    late StateSetter setHostState;

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventCreateWidget(
              languageCatalogOverride: _languageCatalog,
              cityCatalogOverride: _cityCatalog,
              onCityDraftChanged: drafts.add,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_citySelectorText('Загрузка городов...'), findsOneWidget);
    expect(drafts, isEmpty);

    setHostState(() {
      currentUserDocument = _userFixture(
        uid: 'late-profile-city-user',
        data: {
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: _cityCatalog.catalogVersion,
          ).toMap(),
        },
      );
    });
    await tester.pumpAndSettle();

    expect(_citySelectorText('Москва · Россия'), findsOneWidget);
    expect(drafts.map(_cityDraftValue), ['RU:moscow:Europe/Moscow:profile']);
  });

  testWidgets('updates stale profile prompt when user document arrives later',
      (tester) async {
    final drafts = <EventCreateCityDraft>[];
    currentUser = _TestAuthUser('late-stale-profile-city-user');
    late StateSetter setHostState;

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventCreateWidget(
              languageCatalogOverride: _languageCatalog,
              cityCatalogOverride: _cityCatalog,
              onCityDraftChanged: drafts.add,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_citySelectorText('Загрузка городов...'), findsOneWidget);

    setHostState(() {
      currentUserDocument = _userFixture(
        uid: 'late-stale-profile-city-user',
        data: {
          'profileCity': _profileCityFixture(
            countryCode: 'RU',
            cityKey: 'moscow',
            catalogVersion: 'old-version',
          ).toMap(),
        },
      );
    });
    await tester.pumpAndSettle();

    expect(_citySelectorText('Выберите город заново'), findsOneWidget);
    expect(
      find.text(
        'Сохранённый город больше недоступен. Выберите актуальный город для события.',
      ),
      findsOneWidget,
    );
    expect(drafts, isEmpty);
  });

  testWidgets('selects city chip and emits submit draft', (tester) async {
    final drafts = <EventCreateCityDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          onCityDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(eventCreateCityChipKey(_moscowCity)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventCreateCityChipKey(_moscowCity)));
    await tester.pumpAndSettle();

    expect(_citySelectorText('Москва · Россия'), findsOneWidget);
    expect(drafts.map(_cityDraftValue), ['RU:moscow:Europe/Moscow:static']);
  });

  testWidgets('opens city sheet and selects manual city search result',
      (tester) async {
    final drafts = <EventCreateCityDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          onCityDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _ensureVisibleInForm(
      tester,
      find.byKey(eventCreateCitySelectorKey),
    );
    await tester.tap(find.byKey(eventCreateCitySelectorKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateCitySheetKey), findsOneWidget);
    expect(find.text('Поиск города'), findsOneWidget);

    await tester.enterText(find.byKey(eventCreateCitySearchFieldKey), 'rome');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventCreateCityOptionKey(_romeCity)));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateCitySheetKey), findsNothing);
    expect(_citySelectorText('Рим · Italia'), findsOneWidget);
    expect(drafts.map(_cityDraftValue), ['IT:rome:Europe/Rome:manual']);
  });

  testWidgets('edit mode city selection does not update recent city store',
      (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final recentStore = SharedPreferencesEventRecentCityStore(
      preferences: preferences,
    );
    await recentStore.save(
      const [
        EventCityIdentity(countryCode: 'US', cityKey: 'new_york'),
      ],
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          formMode: EventFormMode.edit,
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _ensureVisibleInForm(
      tester,
      find.byKey(eventCreateCitySelectorKey),
    );
    await tester.tap(find.byKey(eventCreateCitySelectorKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(eventCreateCitySearchFieldKey), 'rome');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventCreateCityOptionKey(_romeCity)));
    await tester.pumpAndSettle();

    expect(_citySelectorText('Рим · Italia'), findsOneWidget);
    expect(
      (await recentStore.load()).map(
        (city) => '${city.countryCode}:${city.cityKey}',
      ),
      ['US:new_york'],
    );
  });

  testWidgets('emits initial city draft when callback is added later',
      (tester) async {
    final drafts = <EventCreateCityDraft>[];
    var callbackEnabled = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventCreateWidget(
              languageCatalogOverride: _languageCatalog,
              cityCatalogOverride: _cityCatalog,
              initialSelectedCity: const EventSelectedCity(
                city: _romeCity,
                source: EventCitySelectionSource.manual,
              ),
              onCityDraftChanged: callbackEnabled ? drafts.add : null,
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

    expect(drafts.map(_cityDraftValue), ['IT:rome:Europe/Rome:manual']);
  });

  testWidgets('emits default empty location draft for submit handoff',
      (tester) async {
    final drafts = <EventCreateLocationDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          onLocationDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(drafts.map(_locationDraftValue), ['']);
    expect(drafts.single.locationGeoPoint, isNull);
  });

  testWidgets('normalizes initial location for submit handoff', (tester) async {
    final drafts = <EventCreateLocationDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          initialLocationName: '  Starbucks,   ул. Арбат, 5  ',
          onLocationDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Starbucks, ул. Арбат, 5'), findsOneWidget);
    expect(drafts.map(_locationDraftValue), ['Starbucks, ул. Арбат, 5']);
  });

  testWidgets('emits location draft when handoff callback is added later',
      (tester) async {
    final drafts = <EventCreateLocationDraft>[];
    var callbackEnabled = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventCreateWidget(
              languageCatalogOverride: _languageCatalog,
              initialLocationName: 'Коворкинг на Ленина',
              onLocationDraftChanged: callbackEnabled ? drafts.add : null,
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

    expect(drafts.map(_locationDraftValue), ['Коворкинг на Ленина']);
  });

  testWidgets('edits place field and emits normalized location draft',
      (tester) async {
    final drafts = <EventCreateLocationDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          onLocationDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(eventCreateLocationFieldKey),
      '  Starbucks,\n  ул.   Арбат, 5  ',
    );
    await tester.pumpAndSettle();

    expect(find.text('  Starbucks,\n  ул.   Арбат, 5  '), findsOneWidget);
    expect(
      drafts.map(_locationDraftValue),
      ['', 'Starbucks, ул. Арбат, 5'],
    );
  });

  testWidgets('emits default capacity draft for submit handoff',
      (tester) async {
    final drafts = <EventCreateCapacityDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          onCapacityDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(drafts.map(_capacityDraftValue), [10]);
  });

  testWidgets('uses initial capacity for submit handoff', (tester) async {
    final drafts = <EventCreateCapacityDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          initialCapacity: 8,
          onCapacityDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('8'), findsOneWidget);
    expect(drafts.map(_capacityDraftValue), [8]);
  });

  testWidgets('emits capacity draft when handoff callback is added later',
      (tester) async {
    final drafts = <EventCreateCapacityDraft>[];
    var callbackEnabled = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventCreateWidget(
              languageCatalogOverride: _languageCatalog,
              initialCapacity: 12,
              onCapacityDraftChanged: callbackEnabled ? drafts.add : null,
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

    expect(drafts.map(_capacityDraftValue), [12]);
  });

  testWidgets('edits participant limit field and emits capacity draft',
      (tester) async {
    final drafts = <EventCreateCapacityDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          onCapacityDraftChanged: drafts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventCreateCapacityFieldKey), '24');
    await tester.pumpAndSettle();

    expect(find.text('24'), findsOneWidget);
    expect(drafts.map(_capacityDraftValue), [10, 24]);
  });

  testWidgets('submit shows required field errors in Russian', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Введите название'), findsNothing);
    expect(find.text('Введите описание'), findsNothing);
    expect(find.text('Выберите город события'), findsNothing);
    expect(find.text('Введите место'), findsNothing);

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Введите название'), findsOneWidget);
    expect(find.text('Введите описание'), findsOneWidget);
    expect(find.text('Выберите город события'), findsOneWidget);
    expect(find.text('Введите место'), findsOneWidget);
    expect(find.text('Введите лимит участников'), findsNothing);
  });

  testWidgets('submit shows required field errors in English', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        locale: const Locale('en'),
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Enter title'), findsOneWidget);
    expect(find.text('Enter description'), findsOneWidget);
    expect(find.text('Choose event city'), findsOneWidget);
    expect(find.text('Enter place'), findsOneWidget);
  });

  testWidgets('cleared participant limit is required on submit',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventCreateTitleFieldKey), 'Клуб');
    await tester.enterText(
      find.byKey(eventCreateDescriptionFieldKey),
      'Говорим на английском.',
    );
    await tester.enterText(
      find.byKey(eventCreateLocationFieldKey),
      'Кафе на Арбате',
    );
    await tester.enterText(find.byKey(eventCreateCapacityFieldKey), '');
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Введите лимит участников'), findsOneWidget);
    expect(find.text('Введите название'), findsNothing);
    expect(find.text('Введите описание'), findsNothing);
    expect(find.text('Выберите город события'), findsNothing);
    expect(find.text('Введите место'), findsNothing);
  });

  testWidgets('participant limit below 2 is blocked on submit', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          createEventInvoker: (_, __) async => throw _dailyLimitError(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.enterText(find.byKey(eventCreateCapacityFieldKey), '1');
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Укажите минимум 2 участника'), findsOneWidget);
    expect(find.text('Введите лимит участников'), findsNothing);
    expect(find.text('Введите название'), findsNothing);
    expect(find.text('Введите описание'), findsNothing);
    expect(find.text('Выберите город события'), findsNothing);
    expect(find.text('Введите место'), findsNothing);
  });

  testWidgets('participant limit below 2 error is localized in English',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        locale: const Locale('en'),
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          createEventInvoker: (_, __) async => throw _dailyLimitError(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.enterText(find.byKey(eventCreateCapacityFieldKey), '1');
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Enter at least 2 participants'), findsOneWidget);
    expect(find.text('Enter participant limit'), findsNothing);
  });

  testWidgets('participant limit above 50 is blocked on submit',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.enterText(find.byKey(eventCreateCapacityFieldKey), '51');
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Укажите максимум 50 участников'), findsOneWidget);
    expect(find.text('Введите лимит участников'), findsNothing);
    expect(find.text('Укажите минимум 2 участника'), findsNothing);
    expect(find.text('Введите название'), findsNothing);
    expect(find.text('Введите описание'), findsNothing);
    expect(find.text('Выберите город события'), findsNothing);
    expect(find.text('Введите место'), findsNothing);
  });

  testWidgets('participant limit above 50 error is localized in English',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        locale: const Locale('en'),
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.enterText(find.byKey(eventCreateCapacityFieldKey), '51');
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Enter no more than 50 participants'), findsOneWidget);
    expect(find.text('Enter participant limit'), findsNothing);
    expect(find.text('Enter at least 2 participants'), findsNothing);
  });

  testWidgets('participant limit accepts 2 and 50 boundaries', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          createEventInvoker: (_, __) async => throw _dailyLimitError(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.enterText(find.byKey(eventCreateCapacityFieldKey), '2');
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Укажите минимум 2 участника'), findsNothing);
    expect(find.text('Укажите максимум 50 участников'), findsNothing);

    await tester.enterText(find.byKey(eventCreateCapacityFieldKey), '50');
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Укажите минимум 2 участника'), findsNothing);
    expect(find.text('Укажите максимум 50 участников'), findsNothing);
  });

  testWidgets('edit mode blocks participant limit below active participants',
      (tester) async {
    var submitCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          formMode: EventFormMode.edit,
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialTitle: 'Conversation club',
          initialDescription: 'Casual practice in a cafe.',
          initialSelectedCity: const EventSelectedCity(
            city: _moscowCity,
            source: EventCitySelectionSource.static,
          ),
          initialLocationName: 'Starbucks, ул. Арбат, 5',
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          initialCapacity: 8,
          minimumCapacity: 5,
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          createEventInvoker: (_, __) async {
            submitCount += 1;
            return _createEventResponse();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventCreateCapacityFieldKey), '4');
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(submitCount, 0);
    expect(
      find.text('Лимит не может быть меньше текущих участников (5)'),
      findsOneWidget,
    );
    expect(find.text('Укажите минимум 2 участника'), findsNothing);
    expect(find.text('Укажите максимум 50 участников'), findsNothing);

    await tester.enterText(find.byKey(eventCreateCapacityFieldKey), '5');
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(submitCount, 0);
    expect(
      find.text('Лимит не может быть меньше текущих участников (5)'),
      findsNothing,
    );
  });

  testWidgets('active participant capacity error is localized in English',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        locale: const Locale('en'),
        home: EventCreateWidget(
          formMode: EventFormMode.edit,
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialTitle: 'Conversation club',
          initialDescription: 'Casual practice in a cafe.',
          initialSelectedCity: const EventSelectedCity(
            city: _moscowCity,
            source: EventCitySelectionSource.static,
          ),
          initialLocationName: 'Starbucks, Arbat 5',
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          initialCapacity: 8,
          minimumCapacity: 5,
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventCreateCapacityFieldKey), '4');
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Capacity cannot be below current participants (5)'),
      findsOneWidget,
    );
    expect(find.text('Enter at least 2 participants'), findsNothing);
    expect(find.text('Enter no more than 50 participants'), findsNothing);
  });

  testWidgets('valid required fields submit through create callable',
      (tester) async {
    EventSelectedCity? selectedCity;
    var submitCount = 0;
    late StateSetter setHostState;

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventCreateWidget(
              languageCatalogOverride: _languageCatalog,
              cityCatalogOverride: _cityCatalog,
              initialDate: DateTime(2026, 6, 20),
              initialTime: const TimeOfDay(hour: 18, minute: 0),
              initialSelectedCity: selectedCity,
              currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
              createEventInvoker: (functionName, payload) async {
                submitCount += 1;
                throw _dailyLimitError();
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Введите название'), findsOneWidget);
    expect(find.text('Введите описание'), findsOneWidget);
    expect(find.text('Выберите город события'), findsOneWidget);
    expect(find.text('Введите место'), findsOneWidget);
    expect(submitCount, 0);

    await tester.enterText(find.byKey(eventCreateTitleFieldKey), 'Клуб');
    await tester.enterText(
      find.byKey(eventCreateDescriptionFieldKey),
      'Говорим на английском.',
    );
    setHostState(() {
      selectedCity = const EventSelectedCity(
        city: _moscowCity,
        source: EventCitySelectionSource.static,
      );
    });
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(eventCreateLocationFieldKey),
      'Кафе на Арбате',
    );
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Введите название'), findsNothing);
    expect(find.text('Введите описание'), findsNothing);
    expect(find.text('Выберите город события'), findsNothing);
    expect(find.text('Введите место'), findsNothing);
    expect(find.text('Введите лимит участников'), findsNothing);
    expect(find.byType(EventCreateWidget), findsOneWidget);
    expect(submitCount, 1);
  });

  testWidgets('submit is disabled while create request is in flight',
      (tester) async {
    final createCompleter = Completer<Object?>();
    final requestIds = <String>[];
    final generatedRequestIds = <String>[];
    var nextId = 0;
    var submitCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          createRequestIdGenerator: () {
            final id = _requestId(nextId);
            nextId += 1;
            generatedRequestIds.add(id);
            return id;
          },
          createEventInvoker: (_, payload) {
            submitCount += 1;
            requestIds.add(payload['createRequestId']! as String);
            return createCompleter.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pump();

    expect(submitCount, 1);
    expect(requestIds, <String>[_requestId(0)]);
    expect(generatedRequestIds, <String>[_requestId(0)]);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(eventCreateSubmitButtonKey))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pump();

    expect(submitCount, 1);
    expect(requestIds, <String>[_requestId(0)]);
    expect(generatedRequestIds, <String>[_requestId(0)]);

    createCompleter.completeError(_dailyLimitError());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.byKey(eventCreateSubmitButtonKey))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('successful create opens created event detail', (tester) async {
    var submitCount = 0;
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    final router = _buildEventCreateRouter(
      initialSelectedCity: const EventSelectedCity(
        city: _romeCity,
        source: EventCitySelectionSource.manual,
      ),
      initialDate: DateTime(2026, 6, 20),
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
      createEventInvoker: (_, __) async {
        submitCount += 1;
        return _createEventResponse();
      },
      analyticsTracker: analyticsTracker,
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(submitCount, 1);
    expect(
      analyticsTracker
          .payloadsFor(EventsAnalyticsService.eventCreatedEventName),
      [
        <String, String>{
          'countryCode': 'IT',
          'cityKey': 'rome',
          'citySource': 'manual',
        },
      ],
    );
    expect(
      analyticsTracker.payloadsFor(EventsAnalyticsService.eventEditedEventName),
      isEmpty,
    );
    expect(router.getCurrentLocation(), '/events/event-1');
    expect(find.byType(EventCreateWidget), findsNothing);
    expect(find.byType(EventDetailWidget), findsOneWidget);
    expect(find.text('event-1'), findsOneWidget);

    await tester.tap(find.byKey(eventDetailBackButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/');
    expect(find.byType(EventCreateWidget), findsNothing);
    expect(find.text('Events home'), findsOneWidget);
  });

  testWidgets('failed create does not track event created', (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          createEventInvoker: (_, __) async => throw _dailyLimitError(),
          analyticsTracker: analyticsTracker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(
      analyticsTracker
          .payloadsFor(EventsAnalyticsService.eventCreatedEventName),
      isEmpty,
    );
  });

  testWidgets('event created analytics failure does not block create success',
      (tester) async {
    final router = _buildEventCreateRouter(
      initialSelectedCity: const EventSelectedCity(
        city: _romeCity,
        source: EventCitySelectionSource.manual,
      ),
      initialDate: DateTime(2026, 6, 20),
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
      createEventInvoker: (_, __) async => _createEventResponse(),
      analyticsTracker: const _ThrowingEventCreatedAnalyticsTracker(),
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/events/event-1');
    expect(find.byType(EventDetailWidget), findsOneWidget);
  });

  testWidgets('create completion after leaving form does not open detail',
      (tester) async {
    final createCompleter = Completer<Object?>();
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    final router = _buildEventCreateRouter(
      initialSelectedCity: const EventSelectedCity(
        city: _romeCity,
        source: EventCitySelectionSource.manual,
      ),
      initialDate: DateTime(2026, 6, 20),
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
      createEventInvoker: (_, __) => createCompleter.future,
      analyticsTracker: analyticsTracker,
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    createCompleter.complete(_createEventResponse());
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/');
    expect(find.byType(EventDetailWidget), findsNothing);
    expect(find.text('Events home'), findsOneWidget);
    expect(
      analyticsTracker
          .payloadsFor(EventsAnalyticsService.eventCreatedEventName),
      [
        <String, String>{
          'countryCode': 'IT',
          'cityKey': 'rome',
          'citySource': 'manual',
        },
      ],
    );
  });

  testWidgets('create completion after confirmed discard does not open detail',
      (tester) async {
    final createCompleter = Completer<Object?>();
    final router = _buildEventCreateRouter(
      initialSelectedCity: const EventSelectedCity(
        city: _romeCity,
        source: EventCitySelectionSource.manual,
      ),
      initialDate: DateTime(2026, 6, 20),
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
      createEventInvoker: (_, __) => createCompleter.future,
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(eventCreateBackButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(eventCreateDiscardDialogKey), findsOneWidget);

    await tester.tap(find.byKey(eventCreateDiscardConfirmButtonKey));
    createCompleter.complete(_createEventResponse());
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(router.getCurrentLocation(), '/');
    expect(find.byType(EventDetailWidget), findsNothing);
    expect(find.text('Events home'), findsOneWidget);
  });

  testWidgets('daily creation limit error is shown on submit in Russian',
      (tester) async {
    final failures = <EventActionFailure?>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          createEventInvoker: (_, __) async => throw _dailyLimitError(),
          onSubmitFailureChanged: failures.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateSubmitErrorKey), findsOneWidget);
    expect(
      find.text(
          'Сегодня можно создать не больше 5 событий. Попробуйте завтра.'),
      findsOneWidget,
    );
    expect(find.text('Raw backend message'), findsNothing);
    expect(failures, hasLength(2));
    expect(failures.first, isNull);
    final failure = failures.last!;
    expect(failure.kind, EventActionFailureKind.dailyLimitReached);
    expect(failure.dailyLimit?.resetAtUtc,
        DateTime.parse('2026-06-15T00:00:00.000Z'));
    expect(failure.dailyLimit?.dayKeyUtc, '2026-06-14');
    expect(failure.dailyLimit?.count, 5);
    expect(failure.dailyLimit?.limit, 5);
  });

  testWidgets('daily creation limit error is shown on submit in English',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        locale: const Locale('en'),
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          createEventInvoker: (_, __) async => throw _dailyLimitError(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateSubmitErrorKey), findsOneWidget);
    expect(
      find.text('You can create up to 5 events per day. Try again tomorrow.'),
      findsOneWidget,
    );
    expect(find.text('Raw backend message'), findsNothing);
  });

  testWidgets('create request conflict error is shown on submit in Russian',
      (tester) async {
    final failures = <EventActionFailure?>[];
    var submitCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          createEventInvoker: (_, __) async {
            submitCount += 1;
            throw _createRequestConflictError();
          },
          onSubmitFailureChanged: failures.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(EventCreateWidget), findsOneWidget);
    expect(find.byKey(eventCreateSubmitErrorKey), findsOneWidget);
    expect(
      find.text(
        'Не удалось повторно отправить форму: данные события изменились. '
        'Проверьте форму и попробуйте снова.',
      ),
      findsOneWidget,
    );
    expect(find.text('Raw backend message'), findsNothing);
    expect(submitCount, 1);
    expect(failures, hasLength(2));
    expect(failures.first, isNull);
    final failure = failures.last!;
    expect(failure.kind, EventActionFailureKind.createRequestConflict);
    expect(failure.createRequestConflict?.eventId, 'event-1');
    expect(failure.createRequestConflict?.createRequestId, _requestId(0));
    expect(failure.createRequestConflict?.dayKeyUtc, '2026-06-14');
  });

  testWidgets('create request conflict discards id until next manual submit',
      (tester) async {
    final requestIds = <String>[];
    final generatedRequestIds = <String>[];
    var nextId = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          createRequestIdGenerator: () {
            final id = _requestId(nextId);
            nextId += 1;
            generatedRequestIds.add(id);
            return id;
          },
          createEventInvoker: (_, payload) async {
            requestIds.add(payload['createRequestId']! as String);
            throw _createRequestConflictError();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateSubmitErrorKey), findsOneWidget);
    expect(requestIds, <String>[_requestId(0)]);
    expect(generatedRequestIds, <String>[_requestId(0)]);

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(requestIds, <String>[_requestId(0), _requestId(1)]);
    expect(generatedRequestIds, <String>[_requestId(0), _requestId(1)]);
  });

  testWidgets('retries the same create payload with one createRequestId',
      (tester) async {
    final requestIds = <String>[];
    final generatedRequestIds = <String>[];
    var nextId = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          createRequestIdGenerator: () {
            final id = _requestId(nextId);
            nextId += 1;
            generatedRequestIds.add(id);
            return id;
          },
          createEventInvoker: (_, payload) async {
            requestIds.add(payload['createRequestId']! as String);
            throw _dailyLimitError();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(requestIds, <String>[_requestId(0), _requestId(0)]);
    expect(generatedRequestIds, <String>[_requestId(0)]);
  });

  testWidgets('retryable create failure succeeds with same UUID v4 request id',
      (tester) async {
    final requestIds = <String>[];
    final generatedRequestIds = <String>[];
    var nextId = 0;
    var submitCount = 0;
    final router = _buildEventCreateRouter(
      initialSelectedCity: const EventSelectedCity(
        city: _romeCity,
        source: EventCitySelectionSource.manual,
      ),
      initialDate: DateTime(2026, 6, 20),
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
      createRequestIdGenerator: () {
        final id = _requestId(nextId);
        nextId += 1;
        generatedRequestIds.add(id);
        return id;
      },
      createEventInvoker: (_, payload) async {
        submitCount += 1;
        requestIds.add(payload['createRequestId']! as String);
        if (submitCount == 1) {
          throw _unavailableError();
        }
        return _createEventResponse();
      },
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateSubmitErrorKey), findsOneWidget);
    expect(submitCount, 1);
    expect(requestIds, <String>[_requestId(0)]);
    expect(generatedRequestIds, <String>[_requestId(0)]);
    expect(normalizeEventCreateRequestId(generatedRequestIds.single),
        generatedRequestIds.single);

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(submitCount, 2);
    expect(requestIds, <String>[_requestId(0), _requestId(0)]);
    expect(generatedRequestIds, <String>[_requestId(0)]);
    expect(router.getCurrentLocation(), '/events/event-1');
    expect(find.byType(EventDetailWidget), findsOneWidget);
  });

  testWidgets('changed create payload uses a new createRequestId',
      (tester) async {
    final requestIds = <String>[];
    final generatedRequestIds = <String>[];
    var nextId = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          createRequestIdGenerator: () {
            final id = _requestId(nextId);
            nextId += 1;
            generatedRequestIds.add(id);
            return id;
          },
          createEventInvoker: (_, payload) async {
            requestIds.add(payload['createRequestId']! as String);
            throw _dailyLimitError();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(eventCreateDescriptionFieldKey),
      'Говорим на английском и обсуждаем путешествия.',
    );
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(requestIds, <String>[_requestId(0), _requestId(1)]);
    expect(generatedRequestIds, <String>[_requestId(0), _requestId(1)]);
  });

  testWidgets('invalid create form does not generate createRequestId',
      (tester) async {
    final generatedRequestIds = <String>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _romeCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          createRequestIdGenerator: () {
            final id = _requestId(generatedRequestIds.length);
            generatedRequestIds.add(id);
            return id;
          },
          createEventInvoker: _successfulCreateEventInvoker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(generatedRequestIds, isEmpty);
  });

  testWidgets('submit blocks past start time in selected city timezone',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _moscowCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 18),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T15:00:00Z'),
          createEventInvoker: _successfulCreateEventInvoker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateStartTimeErrorKey), findsOneWidget);
    expect(find.text('Выберите будущие дату и время.'), findsOneWidget);
  });

  testWidgets('same local wall time can be valid in another city timezone',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialSelectedCity: const EventSelectedCity(
            city: _newYorkCity,
            source: EventCitySelectionSource.manual,
          ),
          initialDate: DateTime(2026, 6, 18),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T15:00:00Z'),
          createEventInvoker: (_, __) async => throw _dailyLimitError(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateStartTimeErrorKey), findsNothing);
    expect(find.text('Choose a future date and time.'), findsNothing);
    expect(find.text('Выберите будущие дату и время.'), findsNothing);
  });

  testWidgets('future initial time clears previous start time error',
      (tester) async {
    var initialTime = const TimeOfDay(hour: 18, minute: 0);
    late StateSetter setHostState;

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventCreateWidget(
              languageCatalogOverride: _languageCatalog,
              cityCatalogOverride: _cityCatalog,
              initialSelectedCity: const EventSelectedCity(
                city: _moscowCity,
                source: EventCitySelectionSource.manual,
              ),
              initialDate: DateTime(2026, 6, 18),
              initialTime: initialTime,
              currentUtcProvider: () => DateTime.parse('2026-06-18T15:00:00Z'),
              createEventInvoker: (_, __) async => throw _dailyLimitError(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Выберите будущие дату и время.'), findsOneWidget);

    setHostState(() {
      initialTime = const TimeOfDay(hour: 18, minute: 1);
    });
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateStartTimeErrorKey), findsNothing);

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateStartTimeErrorKey), findsNothing);
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

    await tester.ensureVisible(find.byKey(eventCreateDateSelectorKey));
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

    await tester.ensureVisible(find.byKey(eventCreateDateSelectorKey));
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
            cityCatalogOverride: _cityCatalog,
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
      final citySemantics =
          tester.getSemantics(find.byKey(eventCreateCitySelectorSemanticsKey));
      expect(citySemantics.flagsCollection.isButton, isTrue);
      expect(citySemantics.flagsCollection.isEnabled, isTrue);
      expect(citySemantics.label, contains('Город события'));
      expect(citySemantics.value, isNotEmpty);
      final locationSemantics =
          tester.getSemantics(find.byKey(eventCreateLocationFieldSemanticsKey));
      expect(locationSemantics.flagsCollection.isTextField, isTrue);
      expect(locationSemantics.flagsCollection.isMultiline, isTrue);
      expect(locationSemantics.label, contains('Место'));
      expect(
        locationSemantics.hint,
        contains('Кафе, адрес или ориентир'),
      );
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
      final capacitySemantics =
          tester.getSemantics(find.byKey(eventCreateCapacityFieldSemanticsKey));
      expect(capacitySemantics.flagsCollection.isTextField, isTrue);
      expect(capacitySemantics.flagsCollection.isMultiline, isFalse);
      expect(capacitySemantics.label, contains('Лимит участников'));
      expect(capacitySemantics.hint, contains('10'));
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
            cityCatalogOverride: _cityCatalog,
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
      final citySemantics =
          tester.getSemantics(find.byKey(eventCreateCitySelectorSemanticsKey));
      expect(citySemantics.flagsCollection.isButton, isTrue);
      expect(citySemantics.flagsCollection.isEnabled, isTrue);
      expect(citySemantics.label, contains('Event city'));
      expect(citySemantics.value, isNotEmpty);
      final locationSemantics =
          tester.getSemantics(find.byKey(eventCreateLocationFieldSemanticsKey));
      expect(locationSemantics.flagsCollection.isTextField, isTrue);
      expect(locationSemantics.flagsCollection.isMultiline, isTrue);
      expect(locationSemantics.label, contains('Place'));
      expect(
        locationSemantics.hint,
        contains('Cafe, address, or landmark'),
      );
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
      final capacitySemantics =
          tester.getSemantics(find.byKey(eventCreateCapacityFieldSemanticsKey));
      expect(capacitySemantics.flagsCollection.isTextField, isTrue);
      expect(capacitySemantics.flagsCollection.isMultiline, isFalse);
      expect(capacitySemantics.label, contains('Participant limit'));
      expect(capacitySemantics.hint, contains('10'));
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
    await tester.enterText(
      find.byKey(eventCreateLocationFieldKey),
      'Лофт на Ленина',
    );
    await tester.enterText(
      find.byKey(eventCreateCapacityFieldKey),
      '18',
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
    expect(find.text('Лофт на Ленина'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
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
    expect(find.byKey(eventCreateCitySelectorKey), findsOneWidget);
    expect(find.byKey(eventCreateLocationFieldKey), findsOneWidget);
    expect(find.byKey(eventCreateDateSelectorKey), findsOneWidget);
    expect(find.byKey(eventCreateTimeSelectorKey), findsOneWidget);
    expect(find.byKey(eventCreateCapacityFieldKey), findsOneWidget);
    expect(find.byKey(eventCreateSubmitButtonKey), findsOneWidget);
  });

  testWidgets('clean create form leaves without discard confirmation',
      (tester) async {
    var submitCount = 0;
    final generatedRequestIds = <String>[];
    final router = _buildEventCreateRouter(
      createRequestIdGenerator: () {
        final id = _requestId(generatedRequestIds.length);
        generatedRequestIds.add(id);
        return id;
      },
      createEventInvoker: (_, __) async {
        submitCount += 1;
        return _createEventResponse();
      },
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateBackButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/');
    expect(find.byKey(eventCreateDiscardDialogKey), findsNothing);
    expect(find.text('Events home'), findsOneWidget);
    expect(submitCount, 0);
    expect(generatedRequestIds, isEmpty);
  });

  testWidgets('dirty create form confirms discard before leaving',
      (tester) async {
    var submitCount = 0;
    final generatedRequestIds = <String>[];
    final router = _buildEventCreateRouter(
      createRequestIdGenerator: () {
        final id = _requestId(generatedRequestIds.length);
        generatedRequestIds.add(id);
        return id;
      },
      createEventInvoker: (_, __) async {
        submitCount += 1;
        return _createEventResponse();
      },
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(eventCreateTitleFieldKey),
      'Клуб перед выходными',
    );
    await tester.tap(find.byKey(eventCreateBackButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), EventCreateWidget.routePath);
    expect(find.byKey(eventCreateDiscardDialogKey), findsOneWidget);
    expect(find.text('Закрыть форму?'), findsOneWidget);
    expect(find.text('Заполненные данные будут потеряны.'), findsOneWidget);

    await tester.tap(find.byKey(eventCreateDiscardKeepEditingButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), EventCreateWidget.routePath);
    expect(find.byKey(eventCreateDiscardDialogKey), findsNothing);
    expect(find.text('Клуб перед выходными'), findsOneWidget);
    expect(submitCount, 0);
    expect(generatedRequestIds, isEmpty);

    await tester.tap(find.byKey(eventCreateBackButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventCreateDiscardConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/');
    expect(find.text('Events home'), findsOneWidget);
    expect(submitCount, 0);
    expect(generatedRequestIds, isEmpty);
  });

  testWidgets('discard before submit does not call event creation',
      (tester) async {
    var submitCount = 0;
    final generatedRequestIds = <String>[];
    final router = _buildEventCreateRouter(
      createRequestIdGenerator: () {
        final id = _requestId(generatedRequestIds.length);
        generatedRequestIds.add(id);
        return id;
      },
      createEventInvoker: (_, __) async {
        submitCount += 1;
        return _createEventResponse();
      },
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(eventCreateTitleFieldKey),
      'Local-only draft',
    );
    await tester.tap(find.byKey(eventCreateBackButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventCreateDiscardConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/');
    expect(submitCount, 0);
    expect(generatedRequestIds, isEmpty);
  });

  testWidgets('valid form discard before submit does not call event creation',
      (tester) async {
    final generatedRequestIds = <String>[];
    final serverWrites = _EventCreateServerWriteProbe();
    final router = _buildEventCreateRouter(
      initialSelectedCity: const EventSelectedCity(
        city: _moscowCity,
        source: EventCitySelectionSource.manual,
      ),
      initialDate: DateTime(2026, 6, 20),
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
      createRequestIdGenerator: () {
        final id = _requestId(generatedRequestIds.length);
        generatedRequestIds.add(id);
        return id;
      },
      createEventInvoker: (_, __) async {
        serverWrites.recordSubmittedCreate();
        return _createEventResponse();
      },
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await _fillRequiredCreateFields(tester);
    await tester.tap(find.byKey(eventCreateBackButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventCreateDiscardConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/');
    expect(generatedRequestIds, isEmpty);
    expect(serverWrites.events, isEmpty);
    expect(serverWrites.eventParticipants, isEmpty);
    expect(serverWrites.eventChats, isEmpty);
    expect(serverWrites.eventCreationCounters, isEmpty);
    expect(serverWrites.eventCreateRequests, isEmpty);
  });

  testWidgets('discard confirmation copy does not promise draft restore',
      (tester) async {
    final router = _buildEventCreateRouter();

    await tester.pumpWidget(
      _buildRouterTestApp(
        router,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(eventCreateTitleFieldKey),
      'Weekend club',
    );
    await tester.tap(find.byKey(eventCreateBackButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateDiscardDialogKey), findsOneWidget);
    expect(find.text('Leave create form?'), findsOneWidget);
    expect(find.text('Entered details will be lost.'), findsOneWidget);
    expect(find.text('Keep editing'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(
      find.textContaining(
        RegExp(
          r'\b(saved|restore|draft|restart|logout|reinstall)\b',
          caseSensitive: false,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('cleared capacity confirms discard before leaving',
      (tester) async {
    final router = _buildEventCreateRouter();

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventCreateCapacityFieldKey), '');
    await tester.tap(find.byKey(eventCreateBackButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), EventCreateWidget.routePath);
    expect(find.byKey(eventCreateDiscardDialogKey), findsOneWidget);
  });

  testWidgets('system back shows dirty create form discard confirmation',
      (tester) async {
    var submitCount = 0;
    final generatedRequestIds = <String>[];
    final router = _buildEventCreateRouter(
      createRequestIdGenerator: () {
        final id = _requestId(generatedRequestIds.length);
        generatedRequestIds.add(id);
        return id;
      },
      createEventInvoker: (_, __) async {
        submitCount += 1;
        return _createEventResponse();
      },
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(eventCreateTitleFieldKey),
      'Системный back',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), EventCreateWidget.routePath);
    expect(find.byKey(eventCreateDiscardDialogKey), findsOneWidget);

    await tester.tap(find.byKey(eventCreateDiscardConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/');
    expect(submitCount, 0);
    expect(generatedRequestIds, isEmpty);
  });

  testWidgets('submit validation errors do not make clean form dirty',
      (tester) async {
    final router = _buildEventCreateRouter();

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Введите название'), findsOneWidget);

    await tester.tap(find.byKey(eventCreateBackButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/');
    expect(find.byKey(eventCreateDiscardDialogKey), findsNothing);
    expect(find.text('Events home'), findsOneWidget);
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
    expect(find.byKey(eventCreateCitySelectorKey), findsOneWidget);
    expect(find.byKey(eventCreateLocationFieldKey), findsOneWidget);
    expect(find.byKey(eventCreateDateSelectorKey), findsOneWidget);
    expect(find.byKey(eventCreateTimeSelectorKey), findsOneWidget);
    expect(find.byKey(eventCreateCapacityFieldKey), findsOneWidget);
    expect(find.byKey(eventCreateSubmitButtonKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'edit mode reuses create form fields and validates without create submit',
      (tester) async {
    var submitCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          formMode: EventFormMode.edit,
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          createEventInvoker: (_, __) async {
            submitCount += 1;
            return _createEventResponse();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Редактировать событие'), findsOneWidget);
    expect(find.text('Создать событие'), findsNothing);
    expect(find.text('Сохранить'), findsOneWidget);
    expect(find.text('Создать'), findsNothing);
    expect(find.byKey(eventCreateTitleFieldKey), findsOneWidget);
    expect(find.byKey(eventCreateDescriptionFieldKey), findsOneWidget);
    expect(find.byKey(eventCreateLevelSelectorKey), findsOneWidget);
    expect(find.byKey(eventCreateCitySelectorKey), findsOneWidget);
    expect(find.byKey(eventCreateLocationFieldKey), findsOneWidget);
    expect(find.byKey(eventCreateDateSelectorKey), findsOneWidget);
    expect(find.byKey(eventCreateTimeSelectorKey), findsOneWidget);
    expect(find.byKey(eventCreateCapacityFieldKey), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(eventCreateSubmitButtonKey))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(submitCount, 0);
    expect(find.text('Введите название'), findsOneWidget);
    expect(find.text('Введите описание'), findsOneWidget);
    expect(find.text('Выберите город события'), findsOneWidget);
    expect(find.text('Введите место'), findsOneWidget);
  });

  testWidgets('edit mode renders English title and enabled validation save',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        locale: const Locale('en'),
        home: EventCreateWidget(
          formMode: EventFormMode.edit,
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit event'), findsOneWidget);
    expect(find.text('Create event'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Create'), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.byKey(eventCreateSubmitButtonKey))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('valid edit mode save calls edit backend without create submit',
      (tester) async {
    var createSubmitCount = 0;
    var editSubmitCount = 0;
    final analyticsTracker = _RecordingEventsAnalyticsTracker();

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          formMode: EventFormMode.edit,
          eventId: 'event-1',
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialTitle: 'Conversation club',
          initialDescription: 'Casual practice in a cafe.',
          initialLanguageCode: 'en',
          initialLevelMin: 'A2',
          initialLevelMax: 'B2',
          initialSelectedCity: const EventSelectedCity(
            city: _moscowCity,
            source: EventCitySelectionSource.static,
          ),
          initialLocationName: 'Starbucks, ул. Арбат, 5',
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          createEventInvoker: (_, __) async {
            createSubmitCount += 1;
            return _createEventResponse();
          },
          editEventInvoker: (_, __) async {
            editSubmitCount += 1;
            throw _eventNotEditableError();
          },
          analyticsTracker: analyticsTracker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(createSubmitCount, 0);
    expect(editSubmitCount, 1);
    expect(
      analyticsTracker.payloadsFor(EventsAnalyticsService.eventEditedEventName),
      isEmpty,
    );
    expect(find.text('Введите название'), findsNothing);
    expect(find.text('Введите описание'), findsNothing);
    expect(find.text('Выберите город события'), findsNothing);
    expect(find.text('Введите место'), findsNothing);
    expect(find.byKey(eventCreateStartTimeErrorKey), findsNothing);
    expect(find.byKey(eventCreateSubmitErrorKey), findsOneWidget);
    expect(find.text('Событие больше нельзя редактировать.'), findsOneWidget);
  });

  testWidgets('successful edit sends payload and opens event detail',
      (tester) async {
    String? functionName;
    Map<String, dynamic>? payload;
    var createSubmitCount = 0;
    var editSubmitCount = 0;
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    final router = _buildEventCreateRouter(
      formMode: EventFormMode.edit,
      eventId: ' event-1 ',
      initialTitle: 'Conversation club',
      initialDescription: 'Casual practice in a cafe.',
      initialLanguageCode: 'en',
      initialLevelMin: 'A2',
      initialLevelMax: 'B2',
      initialSelectedCity: const EventSelectedCity(
        city: _moscowCity,
        source: EventCitySelectionSource.static,
      ),
      initialLocationName: 'Starbucks, ул. Арбат, 5',
      initialDate: DateTime(2026, 6, 20),
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      initialCapacity: 8,
      currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
      createEventInvoker: (_, __) async {
        createSubmitCount += 1;
        return _createEventResponse();
      },
      editEventInvoker: (calledFunctionName, calledPayload) async {
        editSubmitCount += 1;
        functionName = calledFunctionName;
        payload = calledPayload;
        return _editEventResponse();
      },
      analyticsTracker: analyticsTracker,
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(createSubmitCount, 0);
    expect(editSubmitCount, 1);
    expect(
      analyticsTracker
          .payloadsFor(EventsAnalyticsService.eventCreatedEventName),
      isEmpty,
    );
    expect(
      analyticsTracker.payloadsFor(EventsAnalyticsService.eventEditedEventName),
      [
        <String, String>{
          'countryCode': 'RU',
          'cityKey': 'moscow',
        },
      ],
    );
    expect(
      analyticsTracker
          .payloadsFor(EventsAnalyticsService.eventEditedEventName)
          .single,
      isNot(contains('citySource')),
    );
    expect(functionName, editEventFunctionName);
    expect(payload, <String, dynamic>{
      'eventId': 'event-1',
      'title': 'Conversation club',
      'description': 'Casual practice in a cafe.',
      'languageCode': 'en',
      'levelMin': 'A2',
      'levelMax': 'B2',
      'countryCode': 'RU',
      'cityKey': 'moscow',
      'locationName': 'Starbucks, ул. Арбат, 5',
      'locationGeoPoint': null,
      'startsAt': '2026-06-20T15:00:00.000Z',
      'capacity': 8,
    });
    expect(payload, isNot(containsPair('createRequestId', anything)));
    expect(router.getCurrentLocation(), '/events/event-1');
    expect(find.byType(EventCreateWidget), findsNothing);
    expect(find.byType(EventDetailWidget), findsOneWidget);
  });

  testWidgets('event edited analytics failure does not block edit success',
      (tester) async {
    final router = _buildEventCreateRouter(
      formMode: EventFormMode.edit,
      eventId: 'event-1',
      initialTitle: 'Conversation club',
      initialDescription: 'Casual practice in a cafe.',
      initialLanguageCode: 'en',
      initialLevelMin: 'A2',
      initialLevelMax: 'B2',
      initialSelectedCity: const EventSelectedCity(
        city: _moscowCity,
        source: EventCitySelectionSource.static,
      ),
      initialLocationName: 'Starbucks, ул. Арбат, 5',
      initialDate: DateTime(2026, 6, 20),
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      initialCapacity: 8,
      currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
      editEventInvoker: (_, __) async => _editEventResponse(),
      analyticsTracker: const _ThrowingEventEditedAnalyticsTracker(),
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/events/event-1');
    expect(find.byType(EventDetailWidget), findsOneWidget);
  });

  testWidgets('edit submit is disabled while request is in flight',
      (tester) async {
    final editCompleter = Completer<Object?>();
    var submitCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          formMode: EventFormMode.edit,
          eventId: 'event-1',
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          initialTitle: 'Conversation club',
          initialDescription: 'Casual practice in a cafe.',
          initialSelectedCity: const EventSelectedCity(
            city: _moscowCity,
            source: EventCitySelectionSource.static,
          ),
          initialLocationName: 'Starbucks, ул. Арбат, 5',
          initialDate: DateTime(2026, 6, 20),
          initialTime: const TimeOfDay(hour: 18, minute: 0),
          currentUtcProvider: () => DateTime.parse('2026-06-18T12:00:00Z'),
          editEventInvoker: (_, __) {
            submitCount += 1;
            return editCompleter.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pump();

    expect(submitCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(eventCreateSubmitButtonKey))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pump();

    expect(submitCount, 1);

    editCompleter.completeError(_eventNotEditableError());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.byKey(eventCreateSubmitButtonKey))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('clean prefilled edit mode leaves without discard confirmation',
      (tester) async {
    final router = _buildEventCreateRouter(
      formMode: EventFormMode.edit,
      initialTitle: 'Conversation club',
      initialDescription: 'Casual practice in a cafe.',
      initialLanguageCode: 'en',
      initialLevelMin: 'A2',
      initialLevelMax: 'B2',
      initialSelectedCity: const EventSelectedCity(
        city: _moscowCity,
        source: EventCitySelectionSource.static,
      ),
      initialLocationName: 'Starbucks, ул. Арбат, 5',
      initialDate: DateTime(2026, 6, 18),
      initialTime: const TimeOfDay(hour: 18, minute: 30),
      initialCapacity: 8,
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventCreateBackButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), '/');
    expect(find.byKey(eventCreateDiscardDialogKey), findsNothing);
    expect(find.text('Events home'), findsOneWidget);
  });

  testWidgets('dirty prefilled edit mode shows edit discard copy',
      (tester) async {
    final router = _buildEventCreateRouter(
      formMode: EventFormMode.edit,
      initialTitle: 'Conversation club',
      initialDescription: 'Casual practice in a cafe.',
      initialLanguageCode: 'en',
      initialLevelMin: 'A2',
      initialLevelMax: 'B2',
      initialSelectedCity: const EventSelectedCity(
        city: _moscowCity,
        source: EventCitySelectionSource.static,
      ),
      initialLocationName: 'Starbucks, ул. Арбат, 5',
      initialDate: DateTime(2026, 6, 18),
      initialTime: const TimeOfDay(hour: 18, minute: 30),
      initialCapacity: 8,
    );

    await tester.pumpWidget(
      _buildRouterTestApp(
        router,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventCreateTitleFieldKey), 'Edited club');
    await tester.tap(find.byKey(eventCreateBackButtonKey));
    await tester.pumpAndSettle();

    expect(router.getCurrentLocation(), EventCreateWidget.routePath);
    expect(find.byKey(eventCreateDiscardDialogKey), findsOneWidget);
    expect(find.text('Leave edit form?'), findsOneWidget);
    expect(find.text('Entered changes will be lost.'), findsOneWidget);
  });

  testWidgets('dirty edit mode shows edit discard copy', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        locale: const Locale('en'),
        home: EventCreateWidget(
          formMode: EventFormMode.edit,
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventCreateTitleFieldKey), 'Edited club');
    await tester.tap(find.byKey(eventCreateBackButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventCreateDiscardDialogKey), findsOneWidget);
    expect(find.text('Leave edit form?'), findsOneWidget);
    expect(find.text('Entered changes will be lost.'), findsOneWidget);
    expect(find.text('Leave create form?'), findsNothing);
    expect(find.text('Entered details will be lost.'), findsNothing);
  });

  testWidgets('create form avoids backend submit before user submits',
      (tester) async {
    var submitCount = 0;
    final generatedRequestIds = <String>[];
    final titleDrafts = <EventCreateTitleDraft>[];
    final descriptionDrafts = <EventCreateDescriptionDraft>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventCreateWidget(
          languageCatalogOverride: _languageCatalog,
          onTitleDraftChanged: titleDrafts.add,
          onDescriptionDraftChanged: descriptionDrafts.add,
          createRequestIdGenerator: () {
            final id = _requestId(generatedRequestIds.length);
            generatedRequestIds.add(id);
            return id;
          },
          createEventInvoker: (_, __) async {
            submitCount += 1;
            return _createEventResponse();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(eventCreateTitleFieldKey),
      'Частично заполненная встреча',
    );
    await tester.enterText(
      find.byKey(eventCreateDescriptionFieldKey),
      'Описание пока без остальных обязательных полей.',
    );
    await tester.pump();

    expect(titleDrafts.map(_titleDraftValue),
        ['', 'Частично заполненная встреча']);
    expect(descriptionDrafts.map(_descriptionDraftValue),
        ['', 'Описание пока без остальных обязательных полей.']);
    expect(submitCount, 0);
    expect(generatedRequestIds, isEmpty);
  });
}

Finder _levelSelectorText(String text) => find.descendant(
      of: find.byKey(eventCreateLevelSelectorKey),
      matching: find.text(text),
    );

String _titleDraftValue(EventCreateTitleDraft draft) => draft.title;

String _descriptionDraftValue(EventCreateDescriptionDraft draft) =>
    draft.description;

String _levelDraftValue(EventCreateLevelDraft draft) =>
    '${draft.levelMin}:${draft.levelMax}';

Finder _citySelectorText(String text) => find.descendant(
      of: find.byKey(eventCreateCitySelectorKey),
      matching: find.text(text),
    );

String _cityDraftValue(EventCreateCityDraft draft) =>
    '${draft.countryCode}:${draft.cityKey}:${draft.timeZoneId}:'
    '${draft.citySource}';

String _locationDraftValue(EventCreateLocationDraft draft) =>
    draft.locationName;

int _capacityDraftValue(EventCreateCapacityDraft draft) => draft.capacity;

String _requestId(int index) =>
    '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}';

class _EventCreateServerWriteProbe {
  final events = <String>[];
  final eventParticipants = <String>[];
  final eventChats = <String>[];
  final eventCreationCounters = <String>[];
  final eventCreateRequests = <String>[];

  void recordSubmittedCreate() {
    events.add('events/event-1');
    eventParticipants.add('events/event-1/participants/current-user');
    eventChats.add('eventChats/event-1');
    eventCreationCounters.add('eventCreationCounters/current-user');
    eventCreateRequests.add('eventCreateRequests/current-user');
  }
}

Future<Object?> _successfulCreateEventInvoker(
  String functionName,
  Map<String, dynamic> payload,
) async =>
    _createEventResponse();

Map<String, dynamic> _createEventResponse() => <String, dynamic>{
      'eventId': 'event-1',
      'createdAt': '2026-06-14T10:00:00.000Z',
      'dailyCreation': <String, dynamic>{
        'dayKeyUtc': '2026-06-14',
        'count': 2,
        'remaining': 3,
        'resetAtUtc': '2026-06-15T00:00:00.000Z',
      },
    };

Map<String, dynamic> _editEventResponse() => <String, dynamic>{
      'eventId': 'event-1',
      'updatedAt': '2026-06-14T11:00:00.000Z',
    };

FirebaseFunctionsException _dailyLimitError() =>
    _TestFirebaseFunctionsException(
      code: 'resource-exhausted',
      message: 'Raw backend message',
      details: <String, dynamic>{
        'domainCode': 'daily_limit_reached',
        'limit': 5,
        'count': 5,
        'dayKeyUtc': '2026-06-14',
        'resetAtUtc': '2026-06-15T00:00:00.000Z',
      },
    );

FirebaseFunctionsException _eventNotEditableError() =>
    _TestFirebaseFunctionsException(
      code: 'failed-precondition',
      message: 'Raw backend message',
      details: <String, dynamic>{
        'domainCode': 'event_not_editable',
      },
    );

FirebaseFunctionsException _createRequestConflictError() =>
    _TestFirebaseFunctionsException(
      code: 'already-exists',
      message: 'Raw backend message',
      details: <String, dynamic>{
        'domainCode': 'create_request_conflict',
        'eventId': 'event-1',
        'createRequestId': _requestId(0),
        'dayKeyUtc': '2026-06-14',
      },
    );

FirebaseFunctionsException _unavailableError() =>
    _TestFirebaseFunctionsException(
      code: 'unavailable',
      message: 'Raw backend message',
    );

class _TestFirebaseFunctionsException extends FirebaseFunctionsException {
  _TestFirebaseFunctionsException({
    required super.code,
    required super.message,
    super.details,
  });
}

class _RecordingEventsAnalyticsTracker implements EventsAnalyticsTracker {
  final List<_RecordedAnalyticsEvent> events = <_RecordedAnalyticsEvent>[];

  List<Map<String, String>> payloadsFor(String name) => events
      .where((event) => event.name == name)
      .map((event) => event.payload)
      .toList(growable: false);

  @override
  Future<void> trackEventListOpened(EventSelectedCity selectedCity) async {}

  @override
  Future<void> trackCitySelected(EventSelectedCity selectedCity) async {}

  @override
  Future<void> trackDateFilterSelected(EventListDateFilter dateFilter) async {}

  @override
  Future<void> trackLevelFilterSelected(String? selectedLevel) async {}

  @override
  Future<void> trackEventDetailOpened(
    EventsRecord event, {
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventCreated({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) async {
    final payload = eventCityAnalyticsPayload(
      countryCode: countryCode,
      cityKey: cityKey,
      citySource: citySource,
    );
    if (payload == null) {
      return;
    }
    events.add(
      _RecordedAnalyticsEvent(
        name: EventsAnalyticsService.eventCreatedEventName,
        payload: payload.cast<String, String>(),
      ),
    );
  }

  @override
  Future<void> trackEventEdited({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) async {
    final payload = eventCityAnalyticsPayload(
      countryCode: countryCode,
      cityKey: cityKey,
      citySource: citySource,
    );
    if (payload == null) {
      return;
    }
    events.add(
      _RecordedAnalyticsEvent(
        name: EventsAnalyticsService.eventEditedEventName,
        payload: payload.cast<String, String>(),
      ),
    );
  }

  @override
  Future<void> trackEventJoined(
    EventsRecord event, {
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventLeft(
    EventsRecord event, {
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventChatOpened({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventCanceled(
    EventsRecord event, {
    String? citySource,
  }) async {}
}

class _NoopEventsAnalyticsTracker implements EventsAnalyticsTracker {
  const _NoopEventsAnalyticsTracker();

  @override
  Future<void> trackEventListOpened(EventSelectedCity selectedCity) async {}

  @override
  Future<void> trackCitySelected(EventSelectedCity selectedCity) async {}

  @override
  Future<void> trackDateFilterSelected(EventListDateFilter dateFilter) async {}

  @override
  Future<void> trackLevelFilterSelected(String? selectedLevel) async {}

  @override
  Future<void> trackEventDetailOpened(
    EventsRecord event, {
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventCreated({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventEdited({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventJoined(
    EventsRecord event, {
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventLeft(
    EventsRecord event, {
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventChatOpened({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) async {}

  @override
  Future<void> trackEventCanceled(
    EventsRecord event, {
    String? citySource,
  }) async {}
}

class _ThrowingEventCreatedAnalyticsTracker
    extends _NoopEventsAnalyticsTracker {
  const _ThrowingEventCreatedAnalyticsTracker();

  @override
  Future<void> trackEventCreated({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) {
    throw StateError('analytics failed');
  }
}

class _ThrowingEventEditedAnalyticsTracker extends _NoopEventsAnalyticsTracker {
  const _ThrowingEventEditedAnalyticsTracker();

  @override
  Future<void> trackEventEdited({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) {
    throw StateError('analytics failed');
  }
}

class _RecordedAnalyticsEvent {
  const _RecordedAnalyticsEvent({
    required this.name,
    required this.payload,
  });

  final String name;
  final Map<String, String> payload;
}

Future<void> _fillRequiredCreateFields(WidgetTester tester) async {
  await tester.enterText(find.byKey(eventCreateTitleFieldKey), 'Клуб');
  await tester.enterText(
    find.byKey(eventCreateDescriptionFieldKey),
    'Говорим на английском.',
  );
  await tester.enterText(
    find.byKey(eventCreateLocationFieldKey),
    'Кафе на Арбате',
  );
}

Future<void> _ensureVisibleInForm(
  WidgetTester tester,
  Finder finder,
) async {
  expect(finder, findsOneWidget);
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.25,
    duration: Duration.zero,
  );
  await tester.pumpAndSettle();
}

int _widgetIndex(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  return tester.allWidgets
      .toList(growable: false)
      .indexOf(tester.widget(finder));
}

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

const _moscowCity = EventCity(
  countryCode: 'RU',
  cityKey: 'moscow',
  cityNameRu: 'Москва',
  cityNameEn: 'Moscow',
  regionCode: null,
  regionNameRu: null,
  regionNameEn: null,
  timeZoneId: 'Europe/Moscow',
  cityDisplayContext: 'Россия',
  aliases: [],
  transliterations: [],
  priority: 100,
);

const _newYorkCity = EventCity(
  countryCode: 'US',
  cityKey: 'new_york',
  cityNameRu: 'Нью-Йорк',
  cityNameEn: 'New York',
  regionCode: 'NY',
  regionNameRu: 'Нью-Йорк',
  regionNameEn: 'New York',
  timeZoneId: 'America/New_York',
  cityDisplayContext: 'United States',
  aliases: ['NYC'],
  transliterations: [],
  priority: 95,
);

const _romeCity = EventCity(
  countryCode: 'IT',
  cityKey: 'rome',
  cityNameRu: 'Рим',
  cityNameEn: 'Rome',
  regionCode: 'LAZ',
  regionNameRu: 'Лацио',
  regionNameEn: 'Lazio',
  timeZoneId: 'Europe/Rome',
  cityDisplayContext: 'Italia',
  aliases: [],
  transliterations: [],
  priority: 90,
);

const _cityCatalog = EventCityCatalog(
  catalogVersion: '2026-06-01',
  cities: [_moscowCity, _newYorkCity, _romeCity],
);

ProfileCityStruct _profileCityFixture({
  required String countryCode,
  required String cityKey,
  required String catalogVersion,
}) {
  return ProfileCityStruct(
    countryCode: countryCode,
    cityKey: cityKey,
    cityNameRu: 'Stored city',
    cityNameEn: 'Stored city',
    cityDisplayContext: 'Stored context',
    catalogVersion: catalogVersion,
  );
}

UsersRecord _userFixture({
  required String uid,
  required Map<String, dynamic> data,
}) {
  return UsersRecord.getDocumentFromData(
    {
      'uid': uid,
      ..._mutableFirestoreMap(data),
    },
    UsersRecord.collection.doc(uid),
  );
}

Map<String, dynamic> _mutableFirestoreMap(Map<String, dynamic> data) {
  return data.map(
    (key, value) => MapEntry(key, _mutableFirestoreValue(value)),
  );
}

dynamic _mutableFirestoreValue(dynamic value) {
  if (value is Map) {
    return value.map(
      (key, nestedValue) => MapEntry(
        key.toString(),
        _mutableFirestoreValue(nestedValue),
      ),
    );
  }
  if (value is List) {
    return value.map(_mutableFirestoreValue).toList(growable: true);
  }
  return value;
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
