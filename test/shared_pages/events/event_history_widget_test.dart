import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/services/event_history_repository.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';
import 'package:small_talk/shared_pages/events/event_history_widget.dart';

const _supportedLocales = [
  Locale('ru'),
  Locale('en'),
];

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  FFLocalizationsDelegate(),
  FallbackMaterialLocalizationDelegate(),
  FallbackCupertinoLocalizationDelegate(),
];

Widget _buildTestApp({required Widget home}) {
  return MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: _supportedLocales,
    localizationsDelegates: _localizationsDelegates,
    home: home,
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
  Future<void> delete() async {}

  @override
  Future<void> updateEmail(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> sendEmailVerification() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _TestFirebaseAuthPlatform();
    await initializeDateFormatting('ru');
    await initializeDateFormatting('en');
    initializeEventListTimeZones();
    await FFLocalizations.initialize();
  });

  tearDown(() {
    currentUser = null;
    currentUserDocument = null;
  });

  testWidgets('shows loading while event history is pending', (tester) async {
    final completer = Completer<EventHistoryResult>();
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete(historyResult(items: const <EventHistoryItem>[]));
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: EventHistoryWidget(
          historyLoader: () => completer.future,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(eventHistoryLoadingKey), findsOneWidget);
    completer.complete(historyResult(items: const <EventHistoryItem>[]));
    await tester.pump();
  });

  testWidgets('shows empty state when history has no events', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventHistoryWidget(
          historyLoader: () async =>
              historyResult(items: const <EventHistoryItem>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventHistoryEmptyKey), findsOneWidget);
    expect(find.text('Мои события'), findsOneWidget);
    expect(
      find.textContaining('Здесь появятся события'),
      findsOneWidget,
    );
  });

  testWidgets('shows error state and retries loading history', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventHistoryWidget(
          historyLoader: () async {
            calls += 1;
            if (calls == 1) {
              throw StateError('network');
            }
            return historyResult(items: const <EventHistoryItem>[]);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventHistoryErrorKey), findsOneWidget);
    expect(find.text('Не удалось загрузить события'), findsOneWidget);

    await tester.tap(find.byKey(eventHistoryErrorRetryButtonKey));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(eventHistoryEmptyKey), findsOneWidget);
  });

  testWidgets('renders history cards and opens selected event', (tester) async {
    EventHistoryItem? openedItem;
    final items = <EventHistoryItem>[
      historyItem(
        eventId: 'event-1',
        title: 'Разговорный клуб',
        startsAt: DateTime.parse('2026-06-20T10:00:00.000Z'),
        timelineStatus: EventHistoryTimelineStatus.upcoming,
      ),
      historyItem(
        eventId: 'event-2',
        title: 'Прошедший ужин',
        startsAt: DateTime.parse('2026-06-01T10:00:00.000Z'),
        participantRole: 'organizer',
        timelineStatus: EventHistoryTimelineStatus.past,
        locationName: null,
      ),
    ];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventHistoryWidget(
          historyLoader: () async => historyResult(items: items),
          eventOpener: (_, item) => openedItem = item,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventHistoryListKey), findsOneWidget);
    expect(find.text('Разговорный клуб'), findsOneWidget);
    expect(find.text('Запланировано'), findsOneWidget);
    expect(find.text('Участник'), findsOneWidget);
    expect(find.text('Starbucks, Arbat 5'), findsOneWidget);
    expect(find.text('B1-C1'), findsWidgets);
    expect(find.text('Английский'), findsWidgets);
    expect(find.text('Прошедший ужин'), findsOneWidget);
    expect(find.text('Организатор'), findsOneWidget);

    await tester.tap(find.byKey(eventHistoryItemKey('event-1')));

    expect(openedItem?.eventId, 'event-1');
  });

  testWidgets('refresh button reloads event history', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventHistoryWidget(
          historyLoader: () async {
            calls += 1;
            return historyResult(
              items: calls == 1
                  ? const <EventHistoryItem>[]
                  : <EventHistoryItem>[historyItem()],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(eventHistoryEmptyKey), findsOneWidget);

    await tester.tap(find.byKey(eventHistoryRefreshButtonKey));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(eventHistoryListKey), findsOneWidget);
  });

  testWidgets('keeps previous history visible when refresh fails',
      (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventHistoryWidget(
          historyLoader: () async {
            calls += 1;
            if (calls > 1) {
              throw StateError('network');
            }
            return historyResult(
              items: <EventHistoryItem>[
                historyItem(title: 'Разговорный клуб'),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventHistoryListKey), findsOneWidget);
    expect(find.text('Разговорный клуб'), findsOneWidget);

    await tester.tap(find.byKey(eventHistoryRefreshButtonKey));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(eventHistoryErrorKey), findsOneWidget);
    expect(find.byKey(eventHistoryListKey), findsOneWidget);
    expect(find.text('Разговорный клуб'), findsOneWidget);
  });

  testWidgets('keeps previous empty history visible when refresh fails',
      (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventHistoryWidget(
          historyLoader: () async {
            calls += 1;
            if (calls > 1) {
              throw StateError('network');
            }
            return historyResult(items: const <EventHistoryItem>[]);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventHistoryEmptyKey), findsOneWidget);

    await tester.tap(find.byKey(eventHistoryRefreshButtonKey));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(eventHistoryErrorKey), findsOneWidget);
    expect(find.byKey(eventHistoryEmptyKey), findsOneWidget);
    expect(find.textContaining('Здесь появятся события'), findsOneWidget);
  });

  testWidgets('does not reuse previous history after user changes',
      (tester) async {
    var calls = 0;
    currentUser = _TestAuthUser('user-a');

    Future<EventHistoryResult> loadHistory() async {
      calls += 1;
      if (currentUserUid == 'user-a') {
        return historyResult(
          items: <EventHistoryItem>[
            historyItem(title: 'История пользователя A'),
          ],
        );
      }
      throw StateError('network');
    }

    await tester.pumpWidget(
      _buildTestApp(
        home: EventHistoryWidget(
          historyLoader: loadHistory,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('История пользователя A'), findsOneWidget);

    currentUser = _TestAuthUser('user-b');
    await tester.pumpWidget(
      _buildTestApp(
        home: EventHistoryWidget(
          historyLoader: loadHistory,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(eventHistoryErrorKey), findsOneWidget);
    expect(find.text('История пользователя A'), findsNothing);
  });
}

EventHistoryResult historyResult({
  required List<EventHistoryItem> items,
}) =>
    EventHistoryResult(
      items: List.unmodifiable(items),
      limit: eventHistoryMaxLimit,
      generatedAt: DateTime.parse('2026-06-16T10:00:00.000Z'),
    );

EventHistoryItem historyItem({
  String eventId = 'event-1',
  String title = 'Conversation club',
  DateTime? startsAt,
  String participantRole = 'participant',
  EventHistoryTimelineStatus timelineStatus =
      EventHistoryTimelineStatus.upcoming,
  String? locationName = 'Starbucks, Arbat 5',
}) =>
    EventHistoryItem(
      eventId: eventId,
      title: title,
      startsAt: startsAt ?? DateTime.parse('2026-06-20T10:00:00.000Z'),
      timeZoneId: 'Europe/Moscow',
      status: timelineStatus == EventHistoryTimelineStatus.canceled
          ? 'canceled'
          : 'active',
      participantRole: participantRole,
      participantStatus:
          timelineStatus == EventHistoryTimelineStatus.left ? 'left' : 'active',
      joinedAt: DateTime.parse('2026-06-10T10:00:00.000Z'),
      timelineStatus: timelineStatus,
      locationName: locationName,
      cityNameRu: 'Москва',
      cityNameEn: 'Moscow',
      languageCode: 'en',
      languageNameRu: 'Английский',
      languageNameEn: 'English',
      levelMin: 'B1',
      levelMax: 'C1',
    );
