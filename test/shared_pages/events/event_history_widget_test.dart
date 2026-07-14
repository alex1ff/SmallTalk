import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

EventHistoryWidget _historyWidget({
  required EventHistoryLoader historyLoader,
  EventHistoryEventOpener? eventOpener,
  Stream<String>? authUidStream,
  String initialUserId = 'user-a',
  String Function()? userIdProvider,
}) =>
    EventHistoryWidget(
      historyLoader: historyLoader,
      eventOpener: eventOpener,
      authUidStream: authUidStream,
      userIdProvider: userIdProvider ??
          (authUidStream == null ? () => initialUserId : null),
    );

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

  testWidgets('shows loading while event history is pending', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final completer = Completer<EventHistoryResult>();
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete(historyResult(items: const <EventHistoryItem>[]));
      }
    });

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: _historyWidget(
            historyLoader: (_) => completer.future,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(eventHistoryLoadingKey), findsOneWidget);
      final loadingSemantics = tester.getSemantics(
        find.byKey(eventHistoryLoadingKey),
      );
      expect(loadingSemantics.label, 'Загрузка истории событий');
      expect(
        loadingSemantics.getSemanticsData().flagsCollection.isLiveRegion,
        isTrue,
      );
      completer.complete(historyResult(items: const <EventHistoryItem>[]));
      await tester.pump();
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('shows empty state when history has no events', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: _historyWidget(
          historyLoader: (_) async =>
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
    final semanticsHandle = tester.ensureSemantics();
    var calls = 0;
    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: _historyWidget(
            historyLoader: (_) async {
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
      final errorSemantics = tester.getSemantics(
        find.byKey(eventHistoryErrorKey),
      );
      expect(
        errorSemantics.getSemanticsData().flagsCollection.isLiveRegion,
        isTrue,
      );

      await tester.tap(find.byKey(eventHistoryErrorRetryButtonKey));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.byKey(eventHistoryEmptyKey), findsOneWidget);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('cold error is localized and live in English', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _buildTestApp(
          locale: const Locale('en'),
          home: _historyWidget(
            historyLoader: (_) async => throw StateError('network'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final errorSemantics = tester.getSemantics(
        find.byKey(eventHistoryErrorKey),
      );
      expect(
        errorSemantics.label,
        'Could not load events. Check your connection and try again.',
      );
      expect(
        errorSemantics.getSemanticsData().flagsCollection.isLiveRegion,
        isTrue,
      );
      expect(find.text('Retry'), findsOneWidget);
    } finally {
      semanticsHandle.dispose();
    }
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
        home: _historyWidget(
          historyLoader: (_) async => historyResult(items: items),
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
        home: _historyWidget(
          historyLoader: (_) async {
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
        home: _historyWidget(
          historyLoader: (_) async {
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

  testWidgets('refresh and refresh error do not move loaded event rows',
      (tester) async {
    final refreshCompleter = Completer<EventHistoryResult>();
    var calls = 0;
    EventHistoryItem? openedItem;
    addTearDown(() {
      if (!refreshCompleter.isCompleted) {
        refreshCompleter.complete(historyResult(items: const []));
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: _historyWidget(
          historyLoader: (_) {
            calls += 1;
            if (calls == 1) {
              return Future<EventHistoryResult>.value(
                historyResult(
                  items: <EventHistoryItem>[
                    historyItem(title: 'Стабильная строка'),
                  ],
                ),
              );
            }
            if (calls == 2) {
              return refreshCompleter.future;
            }
            return Future<EventHistoryResult>.value(
              historyResult(
                items: <EventHistoryItem>[
                  historyItem(title: 'Стабильная строка'),
                ],
              ),
            );
          },
          eventOpener: (_, item) => openedItem = item,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final itemFinder = find.byKey(eventHistoryItemKey('event-1'));
    final initialTopLeft = tester.getTopLeft(itemFinder);

    await tester.tap(find.byKey(eventHistoryRefreshButtonKey));
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 2);
    expect(tester.getTopLeft(itemFinder), initialTopLeft);

    refreshCompleter.completeError(StateError('network'));
    await tester.pumpAndSettle();

    expect(find.byKey(eventHistoryErrorKey), findsOneWidget);
    expect(find.text('Стабильная строка'), findsOneWidget);
    expect(tester.getTopLeft(itemFinder), initialTopLeft);
    expect(
      tester
          .getRect(find.byKey(eventHistoryErrorKey))
          .overlaps(tester.getRect(itemFinder)),
      isFalse,
    );
    expect(itemFinder.hitTestable(), findsOneWidget);

    final retryButton = find.byKey(eventHistoryErrorRetryButtonKey);
    expect(retryButton.hitTestable(), findsOneWidget);
    await tester.tap(retryButton);
    await tester.pump();
    expect(tester.getTopLeft(itemFinder), initialTopLeft);
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 3);
    await tester.pumpAndSettle();
    expect(find.byKey(eventHistoryErrorKey), findsNothing);
    expect(tester.getTopLeft(itemFinder), initialTopLeft);

    await tester.tap(itemFinder);
    await tester.pump();
    expect(openedItem?.eventId, 'event-1');
  });

  testWidgets('keeps previous empty history visible when refresh fails',
      (tester) async {
    final refreshCompleter = Completer<EventHistoryResult>();
    final retryCompleter = Completer<EventHistoryResult>();
    var calls = 0;
    addTearDown(() {
      if (!refreshCompleter.isCompleted) {
        refreshCompleter.complete(historyResult(items: const []));
      }
      if (!retryCompleter.isCompleted) {
        retryCompleter.complete(historyResult(items: const []));
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        home: _historyWidget(
          historyLoader: (_) {
            calls += 1;
            return switch (calls) {
              1 => Future<EventHistoryResult>.value(
                  historyResult(items: const <EventHistoryItem>[]),
                ),
              2 => refreshCompleter.future,
              _ => retryCompleter.future,
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventHistoryEmptyKey), findsOneWidget);

    await tester.tap(find.byKey(eventHistoryRefreshButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(calls, 2);
    expect(find.byKey(eventHistoryEmptyKey), findsOneWidget);
    expect(find.byKey(eventHistoryRefreshingKey), findsOneWidget);
    expect(find.byKey(eventHistoryLoadingKey), findsNothing);
    expect(find.byKey(eventHistoryErrorKey), findsNothing);

    refreshCompleter.completeError(StateError('network'));
    await tester.pumpAndSettle();

    expect(find.byKey(eventHistoryEmptyKey), findsOneWidget);
    expect(find.byKey(eventHistoryErrorKey), findsOneWidget);
    expect(find.byKey(eventHistoryErrorRetryButtonKey), findsOneWidget);
    expect(find.byKey(eventHistoryLoadingKey), findsNothing);
    expect(find.textContaining('Здесь появятся события'), findsOneWidget);

    await tester.tap(find.byKey(eventHistoryErrorRetryButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(calls, 3);
    expect(find.byKey(eventHistoryEmptyKey), findsOneWidget);
    expect(find.byKey(eventHistoryRefreshingKey), findsOneWidget);
    expect(find.byKey(eventHistoryErrorKey), findsNothing);
    expect(find.byKey(eventHistoryLoadingKey), findsNothing);

    retryCompleter.complete(historyResult(items: const []));
    await tester.pumpAndSettle();
    expect(find.byKey(eventHistoryEmptyKey), findsOneWidget);
    expect(find.byKey(eventHistoryRefreshingKey), findsNothing);
  });

  testWidgets('auth UID clears loaded A while B is pending and on logout',
      (tester) async {
    final authUidController = StreamController<String>(sync: true);
    final bCompleter = Completer<EventHistoryResult>();
    final requestedUserIds = <String>[];
    addTearDown(authUidController.close);
    addTearDown(() {
      if (!bCompleter.isCompleted) {
        bCompleter.complete(historyResult(items: const <EventHistoryItem>[]));
      }
    });

    Future<EventHistoryResult> loadHistory(String userId) {
      requestedUserIds.add(userId);
      if (userId == 'user-a') {
        return Future<EventHistoryResult>.value(
          historyResult(
            items: <EventHistoryItem>[
              historyItem(title: 'История пользователя A'),
            ],
          ),
        );
      }
      return bCompleter.future;
    }

    await tester.pumpWidget(
      _buildTestApp(
        home: _historyWidget(
          historyLoader: loadHistory,
          authUidStream: authUidController.stream,
          initialUserId: '',
        ),
      ),
    );

    authUidController.add('user-a');
    await tester.pumpAndSettle();
    expect(find.text('История пользователя A'), findsOneWidget);

    authUidController.add('user-b');
    await tester.pump();

    expect(requestedUserIds, <String>['user-a', 'user-b']);
    expect(find.text('История пользователя A'), findsNothing);
    expect(find.byKey(eventHistoryLoadingKey), findsOneWidget);
    expect(find.byKey(eventHistoryEmptyKey), findsNothing);
    expect(find.byKey(eventHistoryListKey), findsNothing);

    authUidController.add('');
    await tester.pump();
    bCompleter.complete(
      historyResult(
        items: <EventHistoryItem>[
          historyItem(title: 'Поздняя история пользователя B'),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Поздняя история пользователя B'), findsNothing);
    expect(find.byKey(eventHistoryLoadingKey), findsOneWidget);
    expect(find.byKey(eventHistoryListKey), findsNothing);
  });

  testWidgets('auth UID ignores late A after switching to loaded B',
      (tester) async {
    final authUidController = StreamController<String>(sync: true);
    final aCompleter = Completer<EventHistoryResult>();
    final requestedUserIds = <String>[];
    addTearDown(authUidController.close);
    addTearDown(() {
      if (!aCompleter.isCompleted) {
        aCompleter.complete(historyResult(items: const <EventHistoryItem>[]));
      }
    });

    Future<EventHistoryResult> loadHistory(String userId) {
      requestedUserIds.add(userId);
      if (userId == 'user-a') {
        return aCompleter.future;
      }
      return Future<EventHistoryResult>.value(
        historyResult(
          items: <EventHistoryItem>[
            historyItem(title: 'История пользователя B'),
          ],
        ),
      );
    }

    await tester.pumpWidget(
      _buildTestApp(
        home: _historyWidget(
          historyLoader: loadHistory,
          authUidStream: authUidController.stream,
          initialUserId: '',
        ),
      ),
    );

    authUidController.add('user-a');
    await tester.pump();
    await tester.pump();
    expect(requestedUserIds, <String>['user-a']);
    authUidController.add('user-b');
    await tester.pumpAndSettle();

    expect(requestedUserIds, <String>['user-a', 'user-b']);
    expect(find.text('История пользователя B'), findsOneWidget);

    aCompleter.complete(
      historyResult(
        items: <EventHistoryItem>[
          historyItem(title: 'Поздняя история пользователя A'),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('История пользователя B'), findsOneWidget);
    expect(find.text('Поздняя история пользователя A'), findsNothing);
  });

  testWidgets('A1 success or error cannot mutate same-uid A2 history',
      (tester) async {
    for (final lateA1Fails in <bool>[false, true]) {
      final authUidController = StreamController<String>(sync: true);
      final a1Completer = Completer<EventHistoryResult>();
      final a2Completer = Completer<EventHistoryResult>();
      var aRequestCount = 0;

      Future<EventHistoryResult> loadHistory(String userId) {
        if (userId == 'user-b') {
          return Future<EventHistoryResult>.value(
            historyResult(
              items: <EventHistoryItem>[
                historyItem(
                  eventId: 'event-b',
                  title: 'История пользователя B',
                ),
              ],
            ),
          );
        }
        aRequestCount += 1;
        return aRequestCount == 1 ? a1Completer.future : a2Completer.future;
      }

      await tester.pumpWidget(
        _buildTestApp(
          home: _historyWidget(
            historyLoader: loadHistory,
            authUidStream: authUidController.stream,
            initialUserId: '',
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
      expect(find.text('История пользователя B'), findsNothing);
      a2Completer.complete(
        historyResult(
          items: <EventHistoryItem>[
            historyItem(
              eventId: 'event-a2',
              title: 'Актуальная история пользователя A2',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Актуальная история пользователя A2'), findsOneWidget);

      if (lateA1Fails) {
        a1Completer.completeError(StateError('late A1 history error'));
      } else {
        a1Completer.complete(
          historyResult(
            items: <EventHistoryItem>[
              historyItem(
                eventId: 'event-a1',
                title: 'Устаревшая история пользователя A1',
              ),
            ],
          ),
        );
      }
      await tester.pump();

      expect(find.text('Актуальная история пользователя A2'), findsOneWidget);
      expect(find.text('Устаревшая история пользователя A1'), findsNothing);
      expect(find.byKey(eventHistoryLoadingKey), findsNothing);
      expect(find.byKey(eventHistoryErrorKey), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(authUidController.close());
    }
  });

  testWidgets(
      'direct auth switch rejects pending A before the auth stream event',
      (tester) async {
    final authUidController = StreamController<String>(sync: true);
    final aCompleter = Completer<EventHistoryResult>();
    final bCompleter = Completer<EventHistoryResult>();
    final requestedUserIds = <String>[];
    final openedEventIds = <String>[];
    var directUid = 'user-a';
    addTearDown(authUidController.close);
    addTearDown(() {
      if (!aCompleter.isCompleted) {
        aCompleter.complete(historyResult(items: const <EventHistoryItem>[]));
      }
      if (!bCompleter.isCompleted) {
        bCompleter.complete(historyResult(items: const <EventHistoryItem>[]));
      }
    });

    Future<EventHistoryResult> loadHistory(String userId) {
      requestedUserIds.add(userId);
      return userId == 'user-a' ? aCompleter.future : bCompleter.future;
    }

    await tester.pumpWidget(
      _buildTestApp(
        home: _historyWidget(
          historyLoader: loadHistory,
          authUidStream: authUidController.stream,
          userIdProvider: () => directUid,
          eventOpener: (_, item) => openedEventIds.add(item.eventId),
        ),
      ),
    );
    authUidController.add('user-a');
    await tester.pump();
    await tester.pump();
    expect(requestedUserIds, <String>['user-a']);

    directUid = 'user-b';
    aCompleter.complete(
      historyResult(
        items: <EventHistoryItem>[
          historyItem(
            eventId: 'late-event-a',
            title: 'Поздняя история пользователя A',
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Поздняя история пользователя A'), findsNothing);
    expect(find.byKey(eventHistoryLoadingKey), findsOneWidget);
    expect(find.byKey(eventHistoryListKey), findsNothing);
    expect(find.byKey(eventHistoryEmptyKey), findsNothing);
    expect(find.byKey(eventHistoryErrorKey), findsNothing);
    expect(requestedUserIds, <String>['user-a']);

    authUidController.add('user-b');
    await tester.pump();
    expect(requestedUserIds, <String>['user-a', 'user-b']);

    bCompleter.complete(
      historyResult(
        items: <EventHistoryItem>[
          historyItem(
            eventId: 'event-b',
            title: 'История пользователя B',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('История пользователя B'), findsOneWidget);

    directUid = '';
    await tester.tap(find.byKey(eventHistoryItemKey('event-b')));
    await tester.pump();

    expect(openedEventIds, isEmpty);
    expect(find.text('История пользователя B'), findsNothing);
    expect(find.byKey(eventHistoryLoadingKey), findsOneWidget);
    expect(find.byKey(eventHistoryListKey), findsNothing);
    expect(find.byKey(eventHistoryEmptyKey), findsNothing);
    expect(find.byKey(eventHistoryErrorKey), findsNothing);
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
