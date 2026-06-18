import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/flutter_flow/flutter_flow_util.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/events/event_create_widget.dart';
import 'package:small_talk/shared_pages/events/event_edit_widget.dart';
import 'package:small_talk/services/event_city_catalog.dart';
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
    currentUser = _TestAuthUser('organizer-1');
  });

  tearDown(() {
    currentUser = null;
    currentUserDocument = null;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('prefills existing event values before rendering edit form',
      (tester) async {
    var streamCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventEditWidget(
          eventId: 'event-1',
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          snapshotStream: (eventRef) {
            streamCalls += 1;
            return Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(
                  title: 'Conversation club',
                  description: 'Casual practice in a cafe.',
                  languageCode: 'en',
                  levelMin: 'A2',
                  levelMax: 'B2',
                  countryCode: 'RU',
                  cityKey: 'moscow',
                  locationName: 'Starbucks, ул. Арбат, 5',
                  startsAt: DateTime.parse('2026-06-18T15:30:00Z'),
                  timeZoneId: 'Europe/Moscow',
                  capacity: 8,
                  participantsCount: 5,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(streamCalls, 1);
    expect(find.byType(EventCreateWidget), findsOneWidget);
    expect(find.byKey(eventEditLoadingKey), findsNothing);
    expect(find.text('Редактировать событие'), findsOneWidget);
    expect(find.text('Conversation club'), findsOneWidget);
    expect(find.text('Casual practice in a cafe.'), findsOneWidget);
    expect(_languageSelectorText('Английский'), findsOneWidget);
    expect(_levelSelectorText('A2-B2'), findsOneWidget);
    expect(_citySelectorText('Москва · Россия'), findsOneWidget);
    expect(find.text('Starbucks, ул. Арбат, 5'), findsOneWidget);
    expect(
      _dateSelectorText(_dateLabel(DateTime(2026, 6, 18))),
      findsOneWidget,
    );
    expect(_timeSelectorText('18:30'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(eventCreateSubmitButtonKey))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('blocks capacity below active participant count', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventEditWidget(
          eventId: 'event-1',
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          snapshotStream: (eventRef) {
            return Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(
                  capacity: 8,
                  participantsCount: 5,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(eventCreateCapacityFieldKey), '4');
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Лимит не может быть меньше текущих участников (5)'),
      findsOneWidget,
    );
    expect(find.text('Укажите минимум 2 участника'), findsNothing);

    await tester.enterText(find.byKey(eventCreateCapacityFieldKey), '5');
    await tester.tap(find.byKey(eventCreateSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Лимит не может быть меньше текущих участников (5)'),
      findsNothing,
    );
  });

  testWidgets('keeps form hidden while the event snapshot is loading',
      (tester) async {
    final snapshotCompleter = Completer<DocumentSnapshot>();

    await tester.pumpWidget(
      _buildTestApp(
        home: EventEditWidget(
          eventId: 'event-1',
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          snapshotStream: (_) => snapshotCompleter.future.asStream(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(eventEditLoadingKey), findsOneWidget);
    expect(find.byType(EventCreateWidget), findsNothing);

    snapshotCompleter.complete(
      _FakeEventDocumentSnapshot(
        reference: eventObjectRef('event-1'),
        data: _eventData(title: 'Loaded club'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventEditLoadingKey), findsNothing);
    expect(find.byType(EventCreateWidget), findsOneWidget);
    expect(find.text('Loaded club'), findsOneWidget);
  });

  testWidgets('shows loading instead of stale form when the event id changes',
      (tester) async {
    var eventId = 'event-1';
    late StateSetter setHostState;
    final snapshots = <String, Completer<DocumentSnapshot>>{
      'event-1': Completer<DocumentSnapshot>(),
      'event-2': Completer<DocumentSnapshot>(),
    };

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventEditWidget(
              eventId: eventId,
              languageCatalogOverride: _languageCatalog,
              cityCatalogOverride: _cityCatalog,
              snapshotStream: (eventRef) =>
                  snapshots[eventRef.id]!.future.asStream(),
            );
          },
        ),
      ),
    );
    await tester.pump();

    snapshots['event-1']!.complete(
      _FakeEventDocumentSnapshot(
        reference: eventObjectRef('event-1'),
        data: _eventData(title: 'First club'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First club'), findsOneWidget);
    expect(find.byType(EventCreateWidget), findsOneWidget);

    setHostState(() {
      eventId = 'event-2';
    });
    await tester.pump();

    expect(find.byKey(eventEditLoadingKey), findsOneWidget);
    expect(find.byType(EventCreateWidget), findsNothing);
    expect(find.text('First club'), findsNothing);

    snapshots['event-2']!.complete(
      _FakeEventDocumentSnapshot(
        reference: eventObjectRef('event-2'),
        data: _eventData(title: 'Second club'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventEditLoadingKey), findsNothing);
    expect(find.text('Second club'), findsOneWidget);
  });

  testWidgets('switching to unauthorized event clears stale edit form',
      (tester) async {
    var eventId = 'event-1';
    late StateSetter setHostState;
    final snapshots = <String, Completer<DocumentSnapshot>>{
      'event-1': Completer<DocumentSnapshot>(),
      'event-2': Completer<DocumentSnapshot>(),
    };

    await tester.pumpWidget(
      _buildTestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return EventEditWidget(
              eventId: eventId,
              languageCatalogOverride: _languageCatalog,
              cityCatalogOverride: _cityCatalog,
              snapshotStream: (eventRef) =>
                  snapshots[eventRef.id]!.future.asStream(),
            );
          },
        ),
      ),
    );
    await tester.pump();

    snapshots['event-1']!.complete(
      _FakeEventDocumentSnapshot(
        reference: eventObjectRef('event-1'),
        data: _eventData(title: 'Organizer club'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Organizer club'), findsOneWidget);
    expect(find.byType(EventCreateWidget), findsOneWidget);

    setHostState(() {
      eventId = 'event-2';
    });
    await tester.pump();

    expect(find.byKey(eventEditLoadingKey), findsOneWidget);
    expect(find.byType(EventCreateWidget), findsNothing);

    snapshots['event-2']!.complete(
      _FakeEventDocumentSnapshot(
        reference: eventObjectRef('event-2'),
        data: _eventData(
          title: 'Guest club',
          organizerId: 'other-organizer',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventEditForbiddenKey), findsOneWidget);
    expect(find.byType(EventCreateWidget), findsNothing);
    expect(find.text('Organizer club'), findsNothing);
    expect(find.text('Guest club'), findsNothing);
  });

  testWidgets(
      'falls back to the selected city timezone when event timezone is empty',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventEditWidget(
          eventId: 'event-1',
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(
                countryCode: 'US',
                cityKey: 'new_york',
                startsAt: DateTime.parse('2026-06-18T22:05:00Z'),
                timeZoneId: '',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_citySelectorText('Нью-Йорк · United States'), findsOneWidget);
    expect(_timeSelectorText('18:05'), findsOneWidget);
  });

  testWidgets('unknown event city does not crash the edit form',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventEditWidget(
          eventId: 'event-1',
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(
                countryCode: 'ZZ',
                cityKey: 'unknown_city',
                startsAt: DateTime.parse('2026-06-18T16:00:00Z'),
                timeZoneId: 'Europe/Rome',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EventCreateWidget), findsOneWidget);
    expect(_citySelectorText('Выберите город'), findsOneWidget);
    expect(_timeSelectorText('18:00'), findsOneWidget);
  });

  testWidgets('unknown event city does not fall back to profile city',
      (tester) async {
    currentUserDocument = _userFixture(
      uid: 'profile-city-user',
      data: {
        'profileCity': _profileCityFixture(
          countryCode: 'RU',
          cityKey: 'moscow',
          catalogVersion: _cityCatalog.catalogVersion,
        ).toMap(),
      },
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventEditWidget(
          eventId: 'event-1',
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(
                countryCode: 'ZZ',
                cityKey: 'unknown_city',
                startsAt: DateTime.parse('2026-06-18T16:00:00Z'),
                timeZoneId: 'Europe/Rome',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_citySelectorText('Выберите город'), findsOneWidget);
    expect(_citySelectorText('Москва · Россия'), findsNothing);
  });

  testWidgets('hides edit form from non-organizers', (tester) async {
    currentUser = _TestAuthUser('guest-1');

    await tester.pumpWidget(
      _buildTestApp(
        home: EventEditWidget(
          eventId: 'event-1',
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(organizerId: 'organizer-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventEditForbiddenKey), findsOneWidget);
    expect(find.text('Редактирование недоступно'), findsOneWidget);
    expect(
      find.text('Редактировать событие может только организатор.'),
      findsOneWidget,
    );
    expect(find.byType(EventCreateWidget), findsNothing);
    expect(find.byKey(eventCreateSubmitButtonKey), findsNothing);
  });

  testWidgets('fails closed when current user or organizer id is missing',
      (tester) async {
    currentUser = null;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventEditWidget(
          eventId: 'event-1',
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(organizerId: 'organizer-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventEditForbiddenKey), findsOneWidget);
    expect(find.byType(EventCreateWidget), findsNothing);

    currentUser = _TestAuthUser('organizer-1');
    await tester.pumpWidget(
      _buildTestApp(
        home: EventEditWidget(
          eventId: 'event-2',
          languageCatalogOverride: _languageCatalog,
          cityCatalogOverride: _cityCatalog,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(organizerId: ' '),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventEditForbiddenKey), findsOneWidget);
    expect(find.byType(EventCreateWidget), findsNothing);
  });

  testWidgets('shows a missing state when the event document does not exist',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventEditWidget(
          eventId: 'missing-event',
          cityCatalogOverride: _cityCatalog,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              exists: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventEditMissingKey), findsOneWidget);
    expect(find.text('Событие не найдено'), findsOneWidget);
    expect(find.byType(EventCreateWidget), findsNothing);
  });

  testWidgets('shows an error state when event loading fails', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventEditWidget(
          eventId: 'event-1',
          cityCatalogOverride: _cityCatalog,
          snapshotStream: (_) => Stream<DocumentSnapshot>.error(
            StateError('detail stream failed'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventEditErrorKey), findsOneWidget);
    expect(find.text('Не удалось загрузить событие'), findsOneWidget);
    expect(find.byType(EventCreateWidget), findsNothing);
  });
}

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
  Future<void> delete() async {}

  @override
  Future<void> updateEmail(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> sendEmailVerification() async {}
}

Map<String, dynamic> _eventData({
  String title = 'Conversation club',
  String description = 'Casual practice',
  String languageCode = 'en',
  String levelMin = 'B1',
  String levelMax = 'C1',
  String countryCode = 'RU',
  String cityKey = 'moscow',
  String locationName = 'Cafe on Arbat',
  DateTime? startsAt,
  String timeZoneId = 'Europe/Moscow',
  int capacity = 10,
  int participantsCount = 0,
  String organizerId = 'organizer-1',
}) =>
    <String, dynamic>{
      'title': title,
      'description': description,
      'languageCode': languageCode,
      'levelMin': levelMin,
      'levelMax': levelMax,
      'countryCode': countryCode,
      'cityKey': cityKey,
      'locationName': locationName,
      'startsAt': startsAt ?? DateTime.parse('2026-06-18T15:00:00Z'),
      'timeZoneId': timeZoneId,
      'capacity': capacity,
      'participantsCount': participantsCount,
      'organizerId': organizerId,
      'status': 'active',
    };

DocumentReference<Object?> eventObjectRef(String eventId) =>
    FirebaseFirestore.instance.doc('events/$eventId').withConverter<Object?>(
          fromFirestore: (snapshot, _) => snapshot.data(),
          toFirestore: (value, _) {
            if (value is Map<String, Object?>) {
              return value;
            }
            return const <String, Object?>{};
          },
        );

// ignore: subtype_of_sealed_class
class _FakeEventDocumentSnapshot implements DocumentSnapshot<Object?> {
  _FakeEventDocumentSnapshot({
    required this.reference,
    this.exists = true,
    Map<String, dynamic>? data,
  }) : _data = data;

  final Map<String, dynamic>? _data;

  @override
  final bool exists;

  @override
  final DocumentReference<Object?> reference;

  @override
  String get id => reference.id;

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  Object? data() => _data;

  @override
  Object? get(Object field) => _data?[field];

  @override
  Object? operator [](Object field) => get(field);
}

Finder _languageSelectorText(String text) {
  return find.descendant(
    of: find.byKey(eventCreateLanguageSelectorKey),
    matching: find.text(text),
  );
}

Finder _levelSelectorText(String text) => find.descendant(
      of: find.byKey(eventCreateLevelSelectorKey),
      matching: find.text(text),
    );

Finder _citySelectorText(String text) => find.descendant(
      of: find.byKey(eventCreateCitySelectorKey),
      matching: find.text(text),
    );

Finder _dateSelectorText(String text) => find.descendant(
      of: find.byKey(eventCreateDateSelectorKey),
      matching: find.text(text),
    );

String _dateLabel(DateTime date, {Locale locale = const Locale('ru')}) {
  return dateTimeFormat(
    'd MMM y',
    DateTime(date.year, date.month, date.day),
    locale: locale.languageCode,
  );
}

Finder _timeSelectorText(String text) => find.descendant(
      of: find.byKey(eventCreateTimeSelectorKey),
      matching: find.text(text),
    );

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
