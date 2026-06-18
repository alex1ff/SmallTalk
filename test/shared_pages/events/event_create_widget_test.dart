import 'dart:async';
import 'dart:io';

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
import 'package:small_talk/services/event_city_catalog.dart';
import 'package:small_talk/services/event_city_selection_source.dart';
import 'package:small_talk/services/event_selected_city_state.dart';
import 'package:small_talk/services/event_language_catalog.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';

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

  tearDown(() {
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

  testWidgets('valid required fields submit without backend side effects',
      (tester) async {
    EventSelectedCity? selectedCity;
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

  test('create form avoids backend submit before submit phase', () {
    final source = File('lib/shared_pages/events/event_create_widget.dart')
        .readAsStringSync();

    expect(source, contains('AuthUserStreamWidget'));
    expect(source, isNot(contains('EventActionsRepository')));
    expect(source, isNot(contains('EventEditableFields')));
    expect(source, isNot(contains('createRequestId')));
    expect(source, isNot(contains('newEventCreateRequestId')));
    expect(source, isNot(contains('.createEvent(')));
    expect(source, isNot(contains('EventsRecord')));
    expect(source, isNot(contains('FirebaseFirestore')));
    expect(source, isNot(contains('ProfileCitySaveService')));
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
