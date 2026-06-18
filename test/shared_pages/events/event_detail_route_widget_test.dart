import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
import 'package:small_talk/shared_pages/events/event_detail_route_widget.dart';
import 'package:small_talk/shared_pages/events/event_detail_widget.dart';
import 'package:small_talk/services/event_actions_repository.dart';
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
  });

  testWidgets('organizer confirmation cancels event through callable once',
      (tester) async {
    var streamCalls = 0;
    var cancelCalls = 0;
    String? functionName;
    Map<String, dynamic>? payload;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: ' event-1 ',
          snapshotStream: (eventRef) {
            streamCalls += 1;
            return Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(),
              ),
            );
          },
          cancelEventInvoker: (calledFunctionName, calledPayload) async {
            cancelCalls += 1;
            functionName = calledFunctionName;
            payload = calledPayload;
            return _cancelEventResponse();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(streamCalls, 1);
    expect(find.text('Conversation club'), findsOneWidget);
    expect(find.byKey(eventDetailOrganizerControlsKey), findsOneWidget);

    await _tapVisible(tester, find.byKey(eventDetailOrganizerCancelButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventDetailCancelDialogConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(cancelCalls, 1);
    expect(functionName, cancelEventFunctionName);
    expect(payload, <String, dynamic>{'eventId': 'event-1'});
    expect(find.byKey(eventDetailCanceledBannerKey), findsOneWidget);
    expect(find.text('Событие отменено'), findsOneWidget);
    expect(find.byKey(eventDetailOrganizerControlsKey), findsNothing);
  });

  testWidgets('non-organizer cannot see cancel action or call backend',
      (tester) async {
    currentUser = _TestAuthUser('guest-1');
    var cancelCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(),
            ),
          ),
          cancelEventInvoker: (_, __) async {
            cancelCalls += 1;
            return _cancelEventResponse();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailOrganizerControlsKey), findsNothing);
    expect(find.byKey(eventDetailOrganizerCancelButtonKey), findsNothing);
    expect(cancelCalls, 0);
  });

  testWidgets('already canceled event renders canceled state without actions',
      (tester) async {
    var cancelCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(status: 'canceled'),
            ),
          ),
          cancelEventInvoker: (_, __) async {
            cancelCalls += 1;
            return _cancelEventResponse();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailCanceledBannerKey), findsOneWidget);
    expect(find.byKey(eventDetailOrganizerControlsKey), findsNothing);
    expect(cancelCalls, 0);
  });

  testWidgets('cancel failure shows mapped error and re-enables action',
      (tester) async {
    var cancelCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(),
            ),
          ),
          cancelEventInvoker: (_, __) async {
            cancelCalls += 1;
            throw _TestFirebaseFunctionsException(
              code: 'failed-precondition',
              message: 'Raw backend message',
              details: <String, dynamic>{
                'domainCode': 'event_not_cancelable',
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(eventDetailOrganizerCancelButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventDetailCancelDialogConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(cancelCalls, 1);
    expect(find.byKey(eventDetailCancelErrorSnackBarKey), findsOneWidget);
    expect(find.text('Событие больше нельзя отменить.'), findsOneWidget);
    expect(find.byKey(eventDetailCanceledBannerKey), findsNothing);
    expect(find.byKey(eventDetailOrganizerControlsKey), findsOneWidget);
  });

  testWidgets('in-flight cancel blocks duplicate callable calls',
      (tester) async {
    final completer = Completer<Object?>();
    var cancelCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(),
            ),
          ),
          cancelEventInvoker: (_, __) {
            cancelCalls += 1;
            return completer.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(eventDetailOrganizerCancelButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventDetailCancelDialogConfirmButtonKey));
    await tester.pump();

    expect(cancelCalls, 1);
    await _tapVisible(tester, find.byKey(eventDetailOrganizerCancelButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(eventDetailCancelDialogKey), findsNothing);
    expect(cancelCalls, 1);

    completer.complete(_cancelEventResponse());
    await tester.pumpAndSettle();

    expect(cancelCalls, 1);
    expect(find.byKey(eventDetailCanceledBannerKey), findsOneWidget);
  });

  testWidgets('join tap calls join callable and shows loading until completion',
      (tester) async {
    final completer = Completer<Object?>();
    var joinCalls = 0;
    String? functionName;
    Map<String, dynamic>? payload;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: ' event-1 ',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(),
            ),
          ),
          joinEventInvoker: (calledFunctionName, calledPayload) {
            joinCalls += 1;
            functionName = calledFunctionName;
            payload = calledPayload;
            return completer.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Присоединиться'), findsOneWidget);

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pump();

    expect(joinCalls, 1);
    expect(functionName, joinEventFunctionName);
    expect(payload, <String, dynamic>{'eventId': 'event-1'});
    expect(find.text('Присоединяемся...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(_joinEventResponse());
    await tester.pumpAndSettle();

    expect(joinCalls, 1);
    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.text('Присоединяемся...'), findsNothing);
  });

  testWidgets('in-flight join blocks repeated primary taps', (tester) async {
    final completer = Completer<Object?>();
    var joinCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(),
            ),
          ),
          joinEventInvoker: (_, __) {
            joinCalls += 1;
            return completer.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pump();
    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pump();

    expect(joinCalls, 1);
    expect(find.text('Присоединяемся...'), findsOneWidget);

    completer.complete(_joinEventResponse());
    await tester.pumpAndSettle();

    expect(joinCalls, 1);
    expect(find.text('Покинуть'), findsOneWidget);
  });

  testWidgets('successful join shows joined state with occupancy update',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    var joinCalls = 0;

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventDetailRouteWidget(
            eventId: 'event-1',
            snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(participantsCount: 5),
              ),
            ),
            joinEventInvoker: (_, __) async {
              joinCalls += 1;
              return _joinEventResponse(participantsCount: 6);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5/10 мест'), findsOneWidget);

      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pumpAndSettle();

      expect(joinCalls, 1);
      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('6/10 мест'), findsOneWidget);
      expect(find.text('5/10 мест'), findsNothing);

      final primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      final chatSemantics =
          tester.getSemantics(find.byKey(eventDetailChatCtaKey));
      expect(primarySemantics.flagsCollection.isEnabled, isTrue);
      expect(chatSemantics.flagsCollection.isEnabled, isFalse);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('joined participant can leave through primary CTA',
      (tester) async {
    var joinCalls = 0;
    var leaveCalls = 0;
    String? functionName;
    Map<String, dynamic>? payload;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: ' event-1 ',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(),
            ),
          ),
          joinEventInvoker: (_, __) async {
            joinCalls += 1;
            return _joinEventResponse();
          },
          leaveEventInvoker: (calledFunctionName, calledPayload) async {
            leaveCalls += 1;
            functionName = calledFunctionName;
            payload = calledPayload;
            return _leaveEventResponse();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(joinCalls, 1);
    expect(find.text('Покинуть'), findsOneWidget);

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailLeaveDialogKey), findsOneWidget);
    expect(leaveCalls, 0);

    await tester.tap(find.byKey(eventDetailLeaveDialogConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(leaveCalls, 1);
    expect(functionName, leaveEventFunctionName);
    expect(payload, <String, dynamic>{'eventId': 'event-1'});
    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('Покинуть'), findsNothing);
  });

  testWidgets('in-flight leave blocks repeated primary taps', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final leaveCompleter = Completer<Object?>();
    var leaveCalls = 0;

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventDetailRouteWidget(
            eventId: 'event-1',
            snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(),
              ),
            ),
            joinEventInvoker: (_, __) async => _joinEventResponse(),
            leaveEventInvoker: (_, __) {
              leaveCalls += 1;
              return leaveCompleter.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventDetailLeaveDialogConfirmButtonKey));
      await tester.pump();
      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pump();

      expect(leaveCalls, 1);
      expect(find.text('Покинуть'), findsOneWidget);

      final primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isEnabled, isFalse);

      leaveCompleter.complete(_leaveEventResponse());
      await tester.pumpAndSettle();

      expect(leaveCalls, 1);
      expect(find.text('Присоединиться'), findsOneWidget);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('leave failure clears loading state without changing CTA',
      (tester) async {
    var leaveCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(),
            ),
          ),
          joinEventInvoker: (_, __) async => _joinEventResponse(),
          leaveEventInvoker: (_, __) async {
            leaveCalls += 1;
            throw StateError('leave failed');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventDetailLeaveDialogConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(leaveCalls, 1);
    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.text('Присоединиться'), findsNothing);
  });

  testWidgets('snapshot occupancy replaces local join count after catch-up',
      (tester) async {
    final streamController = StreamController<DocumentSnapshot>();
    addTearDown(streamController.close);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => streamController.stream,
          joinEventInvoker: (_, __) async =>
              _joinEventResponse(participantsCount: 6),
        ),
      ),
    );
    await tester.pump();

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(participantsCount: 5),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5/10 мест'), findsOneWidget);

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.text('6/10 мест'), findsOneWidget);

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(participantsCount: 7),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7/10 мест'), findsOneWidget);
    expect(find.text('6/10 мест'), findsNothing);

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(participantsCount: 4),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4/10 мест'), findsOneWidget);
    expect(find.text('6/10 мест'), findsNothing);
  });

  testWidgets('join failure clears loading state without changing CTA',
      (tester) async {
    var joinCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(),
            ),
          ),
          joinEventInvoker: (_, __) async {
            joinCalls += 1;
            throw StateError('join failed');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(joinCalls, 1);
    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('Присоединяемся...'), findsNothing);
  });

  testWidgets('event change clears in-flight join loading state',
      (tester) async {
    final firstJoinCompleter = Completer<Object?>();
    final secondJoinCompleter = Completer<Object?>();
    final joinedEventIds = <String>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(title: 'First event'),
            ),
          ),
          joinEventInvoker: (_, payload) {
            joinedEventIds.add(payload['eventId'] as String);
            return firstJoinCompleter.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pump();

    expect(find.text('Присоединяемся...'), findsOneWidget);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-2',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(title: 'Second event'),
            ),
          ),
          joinEventInvoker: (_, payload) {
            joinedEventIds.add(payload['eventId'] as String);
            return secondJoinCompleter.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Second event'), findsOneWidget);
    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('Присоединяемся...'), findsNothing);

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pump();

    expect(joinedEventIds, <String>['event-1', 'event-2']);
    expect(find.text('Присоединяемся...'), findsOneWidget);

    firstJoinCompleter.complete(
      _joinEventResponse(
        eventId: 'event-1',
        participantsCount: 9,
      ),
    );
    await tester.pump();

    expect(find.text('Присоединяемся...'), findsOneWidget);
    expect(find.text('Покинуть'), findsNothing);
    expect(find.text('9/10 мест'), findsNothing);

    secondJoinCompleter.complete(_joinEventResponse(eventId: 'event-2'));
    await tester.pumpAndSettle();

    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.text('6/10 мест'), findsOneWidget);
  });

  testWidgets('event change ignores stale in-flight leave completion',
      (tester) async {
    final leaveCompleter = Completer<Object?>();
    var leaveCalls = 0;
    var secondJoinCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(title: 'First event'),
            ),
          ),
          joinEventInvoker: (_, __) async =>
              _joinEventResponse(eventId: 'event-1'),
          leaveEventInvoker: (_, __) {
            leaveCalls += 1;
            return leaveCompleter.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(find.text('Покинуть'), findsOneWidget);

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventDetailLeaveDialogConfirmButtonKey));
    await tester.pump();

    expect(leaveCalls, 1);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-2',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(title: 'Second event'),
            ),
          ),
          joinEventInvoker: (_, __) async {
            secondJoinCalls += 1;
            return _joinEventResponse(eventId: 'event-2');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Second event'), findsOneWidget);
    expect(find.text('Присоединиться'), findsOneWidget);

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(secondJoinCalls, 1);
    expect(find.text('Покинуть'), findsOneWidget);

    leaveCompleter.complete(_leaveEventResponse(eventId: 'event-1'));
    await tester.pumpAndSettle();

    expect(find.text('Second event'), findsOneWidget);
    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.text('Присоединиться'), findsNothing);
  });

  testWidgets('leave confirmation ignores confirm after leave becomes stale',
      (tester) async {
    final streamController = StreamController<DocumentSnapshot>();
    addTearDown(streamController.close);
    var leaveCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => streamController.stream,
          joinEventInvoker: (_, __) async => _joinEventResponse(),
          leaveEventInvoker: (_, __) async {
            leaveCalls += 1;
            return _leaveEventResponse();
          },
        ),
      ),
    );
    await tester.pump();

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(find.text('Покинуть'), findsOneWidget);

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailLeaveDialogKey), findsOneWidget);
    expect(leaveCalls, 0);

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(status: 'canceled'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailLeaveDialogConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(leaveCalls, 0);
    expect(find.byKey(eventDetailCanceledBannerKey), findsOneWidget);
  });

  testWidgets('leave confirmation survives active snapshot refresh',
      (tester) async {
    final streamController = StreamController<DocumentSnapshot>();
    addTearDown(streamController.close);
    var leaveCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => streamController.stream,
          joinEventInvoker: (_, __) async => _joinEventResponse(),
          leaveEventInvoker: (_, __) async {
            leaveCalls += 1;
            return _leaveEventResponse();
          },
        ),
      ),
    );
    await tester.pump();

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(title: 'First event'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailLeaveDialogKey), findsOneWidget);

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(title: 'Updated event'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailLeaveDialogConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(leaveCalls, 1);
    expect(find.text('Присоединиться'), findsOneWidget);
  });

  testWidgets('successful cancellation keeps organizer on detail route',
      (tester) async {
    var cancelCalls = 0;
    final router = GoRouter(
      initialLocation: '/events/event-1',
      routes: [
        GoRoute(
          path: EventDetailWidget.routePath,
          builder: (context, state) => EventDetailRouteWidget(
            eventId: state.pathParameters['eventId']!,
            snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(),
              ),
            ),
            cancelEventInvoker: (_, __) async {
              cancelCalls += 1;
              return _cancelEventResponse();
            },
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(eventDetailOrganizerCancelButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventDetailCancelDialogConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(cancelCalls, 1);
    expect(router.getCurrentLocation(), '/events/event-1');
    expect(find.byType(EventDetailRouteWidget), findsOneWidget);
    expect(find.byKey(eventDetailCanceledBannerKey), findsOneWidget);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.5,
    duration: Duration.zero,
  );
  await tester.pump();
  await tester.tap(finder);
}

Map<String, dynamic> _eventData({
  String title = 'Conversation club',
  String status = 'active',
  String organizerId = 'organizer-1',
  int participantsCount = 5,
}) =>
    <String, dynamic>{
      'title': title,
      'description': 'Casual practice',
      'languageCode': 'en',
      'languageNameEn': 'English',
      'languageNameRu': 'Английский',
      'levelMin': 'B1',
      'levelMax': 'C1',
      'locationName': 'Cafe on Arbat',
      'startsAt': DateTime.utc(2099, 6, 18, 15),
      'timeZoneId': 'Europe/Moscow',
      'capacity': 10,
      'participantsCount': participantsCount,
      'organizerId': organizerId,
      'organizerDisplayName': 'Anastasia Ivanova',
      'status': status,
    };

Map<String, dynamic> _cancelEventResponse() => <String, dynamic>{
      'eventId': 'event-1',
      'status': 'canceled',
      'canceledAt': '2026-06-14T12:00:00.000Z',
    };

Map<String, dynamic> _joinEventResponse({
  String eventId = 'event-1',
  int participantsCount = 6,
}) =>
    <String, dynamic>{
      'eventId': eventId,
      'participantStatus': 'active',
      'participantsCount': participantsCount,
      'joinedAt': '2026-06-14T12:01:00.000Z',
    };

Map<String, dynamic> _leaveEventResponse({
  String eventId = 'event-1',
  int participantsCount = 5,
}) =>
    <String, dynamic>{
      'eventId': eventId,
      'participantStatus': 'left',
      'participantsCount': participantsCount,
      'leftAt': '2026-06-14T12:02:00.000Z',
    };

// ignore: subtype_of_sealed_class
class _FakeEventDocumentSnapshot implements DocumentSnapshot<Object?> {
  _FakeEventDocumentSnapshot({
    required this.reference,
    Map<String, dynamic>? data,
  }) : _data = data;

  final Map<String, dynamic>? _data;

  @override
  final bool exists = true;

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

class _TestFirebaseFunctionsException extends FirebaseFunctionsException {
  _TestFirebaseFunctionsException({
    required super.code,
    required super.message,
    super.details,
  });
}
