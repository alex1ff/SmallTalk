import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/components/call_history_card.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/my_calls/my_calls_widget.dart';

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

VideoSessionsRecord _session(String id, String counterpartName) {
  return VideoSessionsRecord.getDocumentFromData(
    <String, dynamic>{
      'status': 'ended',
      'duration': 60,
      'startedAt': DateTime.parse('2026-07-13T10:00:00.000Z'),
      'tutorInfo': <String, dynamic>{
        'name': counterpartName,
        'photo': '',
      },
    },
    VideoSessionsRecord.collection.doc(id),
  );
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
    await FFLocalizations.initialize();
  });

  tearDown(() {
    currentUser = null;
    currentUserDocument = null;
  });

  testWidgets(
    'keeps stable shell while pending and shows empty only after success',
    (tester) async {
      final completer = Completer<List<VideoSessionsRecord>>();
      var calls = 0;
      var userId = 'user-a';

      Future<List<VideoSessionsRecord>> loader(String requestedUserId) {
        calls += 1;
        expect(requestedUserId, userId);
        return completer.future;
      }

      Widget page() => MyCallsWidget(
            historyLoader: loader,
            userIdProvider: () => userId,
          );

      await tester.pumpWidget(_buildTestApp(home: page()));
      await tester.pump();

      expect(calls, 1);
      expect(find.text('Мои звонки'), findsOneWidget);
      expect(find.byKey(myCallsLoadingKey), findsOneWidget);
      expect(find.byKey(myCallsEmptyKey), findsNothing);
      expect(find.byKey(myCallsErrorKey), findsNothing);

      await tester.pumpWidget(_buildTestApp(home: page()));
      await tester.pump();
      expect(calls, 1);

      completer.complete(const <VideoSessionsRecord>[]);
      await tester.pumpAndSettle();

      expect(find.text('Мои звонки'), findsOneWidget);
      expect(find.byKey(myCallsLoadingKey), findsNothing);
      expect(find.byKey(myCallsEmptyKey), findsOneWidget);
      expect(find.byKey(myCallsErrorKey), findsNothing);
    },
  );

  testWidgets('loads history without a resolved profile document',
      (tester) async {
    var calls = 0;

    Future<List<VideoSessionsRecord>> loader(String userId) async {
      calls += 1;
      expect(userId, 'user-a');
      return const <VideoSessionsRecord>[];
    }

    expect(currentUserDocument, isNull);
    await tester.pumpWidget(
      _buildTestApp(
        home: MyCallsWidget(
          historyLoader: loader,
          userIdProvider: () => 'user-a',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byKey(myCallsLoadingKey), findsNothing);
    expect(find.byKey(myCallsEmptyKey), findsOneWidget);
  });

  testWidgets('shows localized live cold error without flashing empty',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    var calls = 0;
    try {
      for (final (locale, header, semanticsLabel) in <(Locale, String, String)>[
        (
          const Locale('ru'),
          'Мои звонки',
          'Не удалось загрузить историю звонков. Проверьте подключение и попробуйте еще раз.',
        ),
        (
          const Locale('en'),
          'My calls',
          'Unable to load call history. Check your connection and try again.',
        ),
      ]) {
        await tester.pumpWidget(
          _buildTestApp(
            locale: locale,
            home: MyCallsWidget(
              historyLoader: (_) async {
                calls += 1;
                throw StateError('network');
              },
              userIdProvider: () => 'user-a',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final errorSemantics = tester.getSemantics(
          find.byKey(myCallsErrorKey),
        );
        expect(find.text(header), findsOneWidget);
        expect(find.byKey(myCallsErrorKey), findsOneWidget);
        expect(errorSemantics.label, semanticsLabel);
        expect(errorSemantics.getSemanticsData().flagsCollection.isLiveRegion,
            isTrue);
        expect(find.byKey(myCallsErrorRetryButtonKey), findsOneWidget);
        expect(find.byKey(myCallsEmptyKey), findsNothing);
        expect(find.byKey(myCallsListKey), findsNothing);
      }
      expect(currentUserDocument, isNull);
      expect(calls, 2);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('loading is a localized live region', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final completer = Completer<List<VideoSessionsRecord>>();
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete(const <VideoSessionsRecord>[]);
      }
    });
    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: MyCallsWidget(
            historyLoader: (_) => completer.future,
            userIdProvider: () => 'user-a',
          ),
        ),
      );
      await tester.pump();

      final loadingSemantics = tester.getSemantics(
        find.byKey(myCallsLoadingKey),
      );
      expect(loadingSemantics.label, 'Загрузка истории звонков');
      expect(
        loadingSemantics.getSemanticsData().flagsCollection.isLiveRegion,
        isTrue,
      );
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('cold error retry starts a new history request', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: MyCallsWidget(
          historyLoader: (_) async {
            calls += 1;
            if (calls == 1) {
              throw StateError('network');
            }
            return const <VideoSessionsRecord>[];
          },
          userIdProvider: () => 'user-a',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(myCallsErrorKey), findsOneWidget);
    await tester.tap(find.byKey(myCallsErrorRetryButtonKey));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(myCallsEmptyKey), findsOneWidget);
    expect(find.byKey(myCallsErrorKey), findsNothing);
  });

  testWidgets('renders loaded call history', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: MyCallsWidget(
          historyLoader: (_) async => <VideoSessionsRecord>[
            _session('session-a', 'Собеседник A'),
          ],
          userIdProvider: () => 'user-a',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(myCallsListKey), findsOneWidget);
    expect(find.text('Собеседник A'), findsOneWidget);
    expect(find.byKey(myCallsLoadingKey), findsNothing);
    expect(find.byKey(myCallsEmptyKey), findsNothing);
    expect(find.byKey(myCallsErrorKey), findsNothing);
  });

  testWidgets('warm refresh keeps rows through error and retry',
      (tester) async {
    final refreshCompleter = Completer<List<VideoSessionsRecord>>();
    final retryCompleter = Completer<List<VideoSessionsRecord>>();
    var calls = 0;
    addTearDown(() {
      if (!refreshCompleter.isCompleted) {
        refreshCompleter.complete(const <VideoSessionsRecord>[]);
      }
      if (!retryCompleter.isCompleted) {
        retryCompleter.complete(const <VideoSessionsRecord>[]);
      }
    });

    Future<List<VideoSessionsRecord>> loader(String userId) {
      expect(userId, 'user-a');
      calls += 1;
      return switch (calls) {
        1 => Future<List<VideoSessionsRecord>>.value(
            <VideoSessionsRecord>[
              _session('stable-session', 'Стабильный собеседник'),
            ],
          ),
        2 => refreshCompleter.future,
        _ => retryCompleter.future,
      };
    }

    await tester.pumpWidget(
      _buildTestApp(
        home: MyCallsWidget(
          historyLoader: loader,
          userIdProvider: () => 'user-a',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rowFinder = find.text('Стабильный собеседник');
    final initialRowTop = tester.getTopLeft(rowFinder);
    expect(calls, 1);

    await tester.tap(find.byKey(myCallsRefreshButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(calls, 2);
    expect(rowFinder, findsOneWidget);
    expect(tester.getTopLeft(rowFinder), initialRowTop);
    expect(find.byKey(myCallsRefreshingKey), findsOneWidget);
    expect(find.byKey(myCallsLoadingKey), findsNothing);
    expect(find.byKey(myCallsErrorKey), findsNothing);

    refreshCompleter.completeError(StateError('refresh failed'));
    await tester.pumpAndSettle();

    expect(rowFinder, findsOneWidget);
    expect(tester.getTopLeft(rowFinder), initialRowTop);
    expect(find.byKey(myCallsRefreshErrorKey), findsOneWidget);
    expect(find.byKey(myCallsErrorRetryButtonKey), findsOneWidget);
    expect(find.byKey(myCallsLoadingKey), findsNothing);
    expect(find.byKey(myCallsErrorKey), findsNothing);

    await tester.tap(find.byKey(myCallsErrorRetryButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(calls, 3);
    expect(rowFinder, findsOneWidget);
    expect(tester.getTopLeft(rowFinder), initialRowTop);
    expect(find.byKey(myCallsRefreshingKey), findsOneWidget);
    expect(find.byKey(myCallsRefreshErrorKey), findsNothing);
    expect(find.byKey(myCallsLoadingKey), findsNothing);

    retryCompleter.complete(
      <VideoSessionsRecord>[
        _session('updated-session', 'Обновлённый собеседник'),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Обновлённый собеседник'), findsOneWidget);
    expect(find.text('Стабильный собеседник'), findsNothing);
    expect(find.byKey(myCallsRefreshingKey), findsNothing);
    expect(find.byKey(myCallsRefreshErrorKey), findsNothing);
  });

  testWidgets(
      'warm empty refresh stays empty through pending, error, and retry',
      (tester) async {
    final refreshCompleter = Completer<List<VideoSessionsRecord>>();
    final retryCompleter = Completer<List<VideoSessionsRecord>>();
    var calls = 0;
    addTearDown(() {
      if (!refreshCompleter.isCompleted) {
        refreshCompleter.complete(const <VideoSessionsRecord>[]);
      }
      if (!retryCompleter.isCompleted) {
        retryCompleter.complete(const <VideoSessionsRecord>[]);
      }
    });

    Future<List<VideoSessionsRecord>> loader(String userId) {
      expect(userId, 'user-a');
      calls += 1;
      return switch (calls) {
        1 => Future<List<VideoSessionsRecord>>.value(const []),
        2 => refreshCompleter.future,
        _ => retryCompleter.future,
      };
    }

    await tester.pumpWidget(
      _buildTestApp(
        home: MyCallsWidget(
          historyLoader: loader,
          userIdProvider: () => 'user-a',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(myCallsEmptyKey), findsOneWidget);

    await tester.tap(find.byKey(myCallsRefreshButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(calls, 2);
    expect(find.byKey(myCallsEmptyKey), findsOneWidget);
    expect(find.byKey(myCallsRefreshingKey), findsOneWidget);
    expect(find.byKey(myCallsLoadingKey), findsNothing);
    expect(find.byKey(myCallsErrorKey), findsNothing);

    refreshCompleter.completeError(StateError('refresh failed'));
    await tester.pumpAndSettle();

    expect(find.byKey(myCallsEmptyKey), findsOneWidget);
    expect(find.byKey(myCallsRefreshErrorKey), findsOneWidget);
    expect(find.byKey(myCallsErrorRetryButtonKey), findsOneWidget);
    expect(find.byKey(myCallsLoadingKey), findsNothing);
    expect(find.byKey(myCallsErrorKey), findsNothing);

    await tester.tap(find.byKey(myCallsErrorRetryButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(calls, 3);
    expect(find.byKey(myCallsEmptyKey), findsOneWidget);
    expect(find.byKey(myCallsRefreshingKey), findsOneWidget);
    expect(find.byKey(myCallsRefreshErrorKey), findsNothing);
    expect(find.byKey(myCallsLoadingKey), findsNothing);

    retryCompleter.complete(const <VideoSessionsRecord>[]);
    await tester.pumpAndSettle();
    expect(find.byKey(myCallsEmptyKey), findsOneWidget);
    expect(find.byKey(myCallsRefreshingKey), findsNothing);
  });

  testWidgets('auth UID event removes resolved A while B history is pending',
      (tester) async {
    final authUidController = StreamController<String>(sync: true);
    final bCompleter = Completer<List<VideoSessionsRecord>>();
    final requestedUserIds = <String>[];
    addTearDown(authUidController.close);
    addTearDown(() {
      if (!bCompleter.isCompleted) {
        bCompleter.complete(const <VideoSessionsRecord>[]);
      }
    });

    Future<List<VideoSessionsRecord>> loader(String requestedUserId) {
      requestedUserIds.add(requestedUserId);
      if (requestedUserId == 'user-a') {
        return Future<List<VideoSessionsRecord>>.value(
          <VideoSessionsRecord>[_session('session-a', 'Собеседник A')],
        );
      }
      return bCompleter.future;
    }

    await tester.pumpWidget(
      _buildTestApp(
        home: MyCallsWidget(
          historyLoader: loader,
          authUidStream: authUidController.stream,
        ),
      ),
    );
    authUidController.add('user-a');
    await tester.pumpAndSettle();
    expect(find.text('Собеседник A'), findsOneWidget);
    expect(requestedUserIds, <String>['user-a']);

    authUidController.add('user-b');
    await tester.pump();

    expect(find.text('Собеседник A'), findsNothing);
    expect(find.byKey(myCallsLoadingKey), findsOneWidget);
    expect(find.byKey(myCallsEmptyKey), findsNothing);
    expect(find.byKey(myCallsListKey), findsNothing);
    expect(requestedUserIds, <String>['user-a', 'user-b']);
  });

  testWidgets('auth UID events ignore late A after switching to B and logout',
      (tester) async {
    final authUidController = StreamController<String>(sync: true);
    final aCompleter = Completer<List<VideoSessionsRecord>>();
    final bCompleter = Completer<List<VideoSessionsRecord>>();
    final requestedUserIds = <String>[];
    addTearDown(authUidController.close);
    addTearDown(() {
      if (!aCompleter.isCompleted) {
        aCompleter.complete(const <VideoSessionsRecord>[]);
      }
      if (!bCompleter.isCompleted) {
        bCompleter.complete(const <VideoSessionsRecord>[]);
      }
    });

    Future<List<VideoSessionsRecord>> loader(String requestedUserId) {
      requestedUserIds.add(requestedUserId);
      return requestedUserId == 'user-a'
          ? aCompleter.future
          : bCompleter.future;
    }

    await tester.pumpWidget(
      _buildTestApp(
        home: MyCallsWidget(
          historyLoader: loader,
          authUidStream: authUidController.stream,
        ),
      ),
    );
    authUidController.add('user-a');
    await tester.pump();
    await tester.pump();
    expect(requestedUserIds, <String>['user-a']);

    authUidController.add('user-b');
    await tester.pump();
    await tester.pump();
    expect(requestedUserIds, <String>['user-a', 'user-b']);
    expect(find.byKey(myCallsLoadingKey), findsOneWidget);

    authUidController.add('');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(myCallsLoadingKey), findsOneWidget);

    aCompleter.complete(
      <VideoSessionsRecord>[_session('session-a', 'Поздний собеседник A')],
    );
    await tester.pump();

    expect(find.text('Поздний собеседник A'), findsNothing);
    expect(find.byKey(myCallsLoadingKey), findsOneWidget);
    expect(find.byKey(myCallsListKey), findsNothing);
    expect(find.byKey(myCallsEmptyKey), findsNothing);
    expect(find.byKey(myCallsErrorKey), findsNothing);
  });

  testWidgets('A1 success or error cannot mutate same-uid A2 history',
      (tester) async {
    for (final lateA1Fails in <bool>[false, true]) {
      final authUidController = StreamController<String>(sync: true);
      final a1Completer = Completer<List<VideoSessionsRecord>>();
      final a2Completer = Completer<List<VideoSessionsRecord>>();
      var aRequestCount = 0;

      Future<List<VideoSessionsRecord>> loader(String userId) {
        if (userId == 'user-b') {
          return Future<List<VideoSessionsRecord>>.value(
            <VideoSessionsRecord>[
              _session('session-b', 'Собеседник B'),
            ],
          );
        }
        aRequestCount += 1;
        return aRequestCount == 1 ? a1Completer.future : a2Completer.future;
      }

      await tester.pumpWidget(
        _buildTestApp(
          home: MyCallsWidget(
            historyLoader: loader,
            authUidStream: authUidController.stream,
          ),
        ),
      );
      authUidController.add('user-a');
      await tester.pump();
      await tester.pump();
      expect(aRequestCount, 1);

      authUidController.add('user-b');
      authUidController.add('user-a');
      await tester.pump();
      expect(aRequestCount, 2);
      expect(find.text('Собеседник B'), findsNothing);
      a2Completer.complete(
        <VideoSessionsRecord>[
          _session('session-a2', 'Актуальный собеседник A2'),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Актуальный собеседник A2'), findsOneWidget);

      if (lateA1Fails) {
        a1Completer.completeError(StateError('late A1 history error'));
      } else {
        a1Completer.complete(
          <VideoSessionsRecord>[
            _session('session-a1', 'Устаревший собеседник A1'),
          ],
        );
      }
      await tester.pump();

      expect(find.text('Актуальный собеседник A2'), findsOneWidget);
      expect(find.text('Устаревший собеседник A1'), findsNothing);
      expect(find.byKey(myCallsLoadingKey), findsNothing);
      expect(find.byKey(myCallsErrorKey), findsNothing);
      expect(find.byKey(myCallsRefreshErrorKey), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(authUidController.close());
    }
  });

  testWidgets('loaded row refuses navigation after direct uid change',
      (tester) async {
    final authUidController = StreamController<String>(sync: true);
    var directUid = 'user-a';
    addTearDown(authUidController.close);

    await tester.pumpWidget(
      _buildTestApp(
        home: MyCallsWidget(
          historyLoader: (_) async => <VideoSessionsRecord>[
            _session('guarded-session-a', 'Собеседник A'),
          ],
          authUidStream: authUidController.stream,
          userIdProvider: () => directUid,
        ),
      ),
    );
    authUidController.add('user-a');
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(CallHistoryCard), findsOneWidget);

    directUid = 'user-b';
    await tester.tap(find.byType(CallHistoryCard));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CallHistoryCard), findsNothing);
    expect(find.byKey(myCallsLoadingKey), findsOneWidget);
  });

  testWidgets(
      'direct auth switch invalidates pending A before the auth stream event',
      (tester) async {
    final authUidController = StreamController<String>(sync: true);
    final aCompleter = Completer<List<VideoSessionsRecord>>();
    final bCompleter = Completer<List<VideoSessionsRecord>>();
    final requestedUserIds = <String>[];
    var directUid = 'user-a';
    addTearDown(authUidController.close);
    addTearDown(() {
      if (!aCompleter.isCompleted) {
        aCompleter.complete(const <VideoSessionsRecord>[]);
      }
      if (!bCompleter.isCompleted) {
        bCompleter.complete(const <VideoSessionsRecord>[]);
      }
    });

    Future<List<VideoSessionsRecord>> loader(String requestedUserId) {
      requestedUserIds.add(requestedUserId);
      return requestedUserId == 'user-a'
          ? aCompleter.future
          : bCompleter.future;
    }

    Widget page() => MyCallsWidget(
          historyLoader: loader,
          authUidStream: authUidController.stream,
          userIdProvider: () => directUid,
        );

    await tester.pumpWidget(_buildTestApp(home: page()));
    authUidController.add('user-a');
    await tester.pump();
    await tester.pump();
    expect(requestedUserIds, <String>['user-a']);

    directUid = 'user-b';
    aCompleter.complete(
      <VideoSessionsRecord>[_session('late-a', 'Поздний собеседник A')],
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Поздний собеседник A'), findsNothing);
    expect(find.byKey(myCallsLoadingKey), findsOneWidget);
    expect(find.byKey(myCallsListKey), findsNothing);
    expect(find.byKey(myCallsEmptyKey), findsNothing);
    expect(find.byKey(myCallsErrorKey), findsNothing);
    expect(requestedUserIds, <String>['user-a']);

    authUidController.add('user-b');
    await tester.pump();
    expect(requestedUserIds, <String>['user-a', 'user-b']);
    expect(find.byKey(myCallsLoadingKey), findsOneWidget);

    bCompleter.complete(
      <VideoSessionsRecord>[_session('session-b', 'Собеседник B')],
    );
    await tester.pumpAndSettle();
    expect(find.text('Собеседник B'), findsOneWidget);

    directUid = '';
    await tester.pumpWidget(_buildTestApp(home: page()));
    await tester.pump();

    expect(find.text('Собеседник B'), findsNothing);
    expect(find.byKey(myCallsLoadingKey), findsOneWidget);
    expect(find.byKey(myCallsListKey), findsNothing);
    expect(find.byKey(myCallsEmptyKey), findsNothing);
    expect(find.byKey(myCallsErrorKey), findsNothing);
  });
}
