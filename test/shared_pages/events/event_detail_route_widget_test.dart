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
import 'package:small_talk/shared_pages/events/event_group_chat_widget.dart';
import 'package:small_talk/services/event_actions_repository.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';
import 'package:small_talk/services/event_selected_city_state.dart';
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
    EventsAnalyticsService.defaultTracker = const _NoopEventsAnalyticsTracker();
  });

  tearDown(() {
    EventsAnalyticsService.defaultTracker = EventsAnalyticsService.instance;
    currentUser = null;
    currentUserDocument = null;
  });

  testWidgets('organizer confirmation cancels event through callable once',
      (tester) async {
    var streamCalls = 0;
    var cancelCalls = 0;
    String? functionName;
    Map<String, dynamic>? payload;
    final analyticsTracker = _RecordingEventsAnalyticsTracker();

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
          participantSnapshotStream: (participantRef) =>
              Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: participantRef,
              data: _participantData(
                userId: 'organizer-1',
                status: 'active',
              ),
            ),
          ),
          cancelEventInvoker: (calledFunctionName, calledPayload) async {
            cancelCalls += 1;
            functionName = calledFunctionName;
            payload = calledPayload;
            return _cancelEventResponse();
          },
          analyticsTracker: analyticsTracker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(streamCalls, 1);
    expect(find.text('Conversation club'), findsOneWidget);
    expect(find.byKey(eventDetailOrganizerControlsKey), findsOneWidget);
    expect(find.byKey(eventDetailReportButtonKey), findsNothing);
    expect(find.text('Вы участвуете'), findsOneWidget);
    expect(find.text('Покинуть'), findsNothing);

    await _tapVisible(tester, find.byKey(eventDetailOrganizerCancelButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventDetailCancelDialogConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(cancelCalls, 1);
    expect(functionName, cancelEventFunctionName);
    expect(payload, <String, dynamic>{'eventId': 'event-1'});
    expect(
      analyticsTracker
          .payloadsFor(EventsAnalyticsService.eventCanceledEventName),
      [
        <String, String>{
          'countryCode': 'RU',
          'cityKey': 'moscow',
        },
      ],
    );
    expect(
      analyticsTracker
          .payloadsFor(EventsAnalyticsService.eventCanceledEventName)
          .single,
      isNot(contains('citySource')),
    );
    expect(find.byKey(eventDetailCanceledBannerKey), findsOneWidget);
    expect(find.text('Событие отменено'), findsOneWidget);
    expect(find.byKey(eventDetailOrganizerControlsKey), findsNothing);
  });

  testWidgets('maps active participant stream with organizer fallback',
      (tester) async {
    currentUser = _TestAuthUser('student-1');

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(
                organizerId: 'organizer-1',
                participantsCount: 2,
              ),
            ),
          ),
          participantSnapshotStream: (participantRef) =>
              Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: participantRef,
              data: _participantData(
                userId: 'student-1',
                status: 'left',
              ),
            ),
          ),
          participantsStream: (eventRef) =>
              Stream<List<EventParticipantsRecord>>.value([
            EventParticipantsRecord.getDocumentFromData(
              _participantData(
                userId: 'organizer-1',
                status: 'active',
                displayName: '',
              ),
              EventParticipantsRecord.createDoc(eventRef, id: 'organizer-1'),
            ),
            EventParticipantsRecord.getDocumentFromData(
              _participantData(
                userId: 'student-2',
                status: 'active',
                displayName: 'Марко Росси',
                photoUrl: 'https://example.com/marco.png',
              ),
              EventParticipantsRecord.createDoc(eventRef, id: 'student-2'),
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Anastasia Ivanova'), findsWidgets);
    expect(find.text('Марко Росси'), findsOneWidget);
    expect(find.byKey(eventDetailParticipantTileKey(0)), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(eventDetailParticipantTileKey(0)),
        matching: find.text('Anastasia Ivanova'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'uses event organizer as occupied participant when stream omits it',
      (tester) async {
    currentUser = _TestAuthUser('student-1');

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(
                organizerId: 'organizer-1',
                participantsCount: 2,
              ),
            ),
          ),
          participantSnapshotStream: (participantRef) =>
              Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: participantRef,
              data: _participantData(
                userId: 'student-1',
                status: 'left',
              ),
            ),
          ),
          participantsStream: (eventRef) =>
              Stream<List<EventParticipantsRecord>>.value([
            EventParticipantsRecord.getDocumentFromData(
              _participantData(
                userId: 'student-2',
                status: 'active',
                displayName: 'Марко Росси',
              ),
              EventParticipantsRecord.createDoc(eventRef, id: 'student-2'),
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(eventDetailParticipantTileKey(0)),
        matching: find.text('Anastasia Ivanova'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(eventDetailParticipantTileKey(1)),
        matching: find.text('Марко Росси'),
      ),
      findsOneWidget,
    );
    expect(find.text('2/10 мест'), findsOneWidget);
  });

  testWidgets('opens organizer private chat before joining', (tester) async {
    currentUser = _TestAuthUser('student-1');
    String? functionName;
    Map<String, dynamic>? payload;
    String? openedConversationPath;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(organizerId: 'organizer-1'),
            ),
          ),
          participantSnapshotStream: (participantRef) =>
              Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: participantRef,
              data: _participantData(
                userId: 'student-1',
                status: 'left',
              ),
            ),
          ),
          openOrganizerChatInvoker: (calledFunctionName, calledPayload) async {
            functionName = calledFunctionName;
            payload = calledPayload;
            return <String, dynamic>{
              'conversationId': 'organizer-1_student-1',
              'conversationPath': 'conversations/organizer-1_student-1',
            };
          },
          chatThreadOpener: (
            context, {
            required conversationRef,
            initialConversation,
          }) async {
            openedConversationPath = conversationRef?.path;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailOrganizerMessageButtonKey), findsOneWidget);
    expect(find.text('Присоединиться'), findsOneWidget);

    await tester.tap(find.byKey(eventDetailOrganizerMessageButtonKey));
    await tester.pumpAndSettle();

    expect(functionName, openEventOrganizerChatFunctionName);
    expect(payload, <String, dynamic>{'eventId': 'event-1'});
    expect(openedConversationPath, 'conversations/organizer-1_student-1');
  });

  testWidgets('non-organizer reports event through callable', (tester) async {
    currentUser = _TestAuthUser('student-1');
    String? functionName;
    Map<String, dynamic>? payload;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(organizerId: 'organizer-1'),
            ),
          ),
          participantSnapshotStream: (participantRef) =>
              Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: participantRef,
              data: _participantData(
                userId: 'student-1',
                status: 'active',
              ),
            ),
          ),
          reportEventInvoker: (calledFunctionName, calledPayload) async {
            functionName = calledFunctionName;
            payload = calledPayload;
            return <String, dynamic>{
              'eventId': 'event-1',
              'reportId': 'report-1',
              'status': 'submitted',
              'reportedAt': '2026-06-16T10:00:00.000Z',
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailReportButtonKey), findsOneWidget);

    await tester.tap(find.byKey(eventDetailReportButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailReportDialogKey), findsOneWidget);
    expect(find.byKey(eventDetailReportSubmitButtonKey), findsOneWidget);

    await tester.tap(find.byKey(eventDetailReportReasonKey('unsafe')));
    await tester.enterText(
      find.byKey(eventDetailReportDetailsFieldKey),
      '  Venue looks unsafe  ',
    );
    await tester.tap(find.byKey(eventDetailReportSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(functionName, reportEventFunctionName);
    expect(payload, <String, dynamic>{
      'eventId': 'event-1',
      'reasonCode': 'unsafe',
      'details': 'Venue looks unsafe',
    });
    expect(find.byKey(eventDetailReportSuccessSnackBarKey), findsOneWidget);
  });

  testWidgets('report event failure shows mapped error snackbar',
      (tester) async {
    currentUser = _TestAuthUser('student-1');

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(organizerId: 'organizer-1'),
            ),
          ),
          participantSnapshotStream: (participantRef) =>
              Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: participantRef,
              data: _participantData(
                userId: 'student-1',
                status: 'active',
              ),
            ),
          ),
          reportEventInvoker: (_, __) async {
            throw _TestFirebaseFunctionsException(
              code: 'failed-precondition',
              message: 'Raw backend message',
              details: <String, dynamic>{
                'domainCode': 'event_report_self',
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailReportButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventDetailReportReasonKey('spam')));
    await tester.pump();
    await tester.tap(find.byKey(eventDetailReportSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailReportErrorSnackBarKey), findsOneWidget);
    expect(find.text('Нельзя пожаловаться на своё событие.'), findsOneWidget);
  });

  testWidgets('report dialog ignores submit after route event changes',
      (tester) async {
    currentUser = _TestAuthUser('student-1');
    final streamController = StreamController<DocumentSnapshot>();
    addTearDown(streamController.close);
    var reportCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => streamController.stream,
          participantSnapshotStream: (participantRef) =>
              Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: participantRef,
              data: _participantData(
                userId: 'student-1',
                status: 'active',
              ),
            ),
          ),
          reportEventInvoker: (_, __) async {
            reportCalls += 1;
            return <String, dynamic>{
              'eventId': 'event-1',
              'reportId': 'report-1',
              'status': 'submitted',
              'reportedAt': '2026-06-16T10:00:00.000Z',
            };
          },
        ),
      ),
    );
    await tester.pump();

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(organizerId: 'organizer-1'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailReportButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(eventDetailReportDialogKey), findsOneWidget);

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-2'),
        data: _eventData(title: 'Updated event', organizerId: 'organizer-1'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailReportReasonKey('spam')));
    await tester.pump();
    await tester.tap(find.byKey(eventDetailReportSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(reportCalls, 0);
    expect(find.byKey(eventDetailReportSuccessSnackBarKey), findsNothing);
    expect(find.byKey(eventDetailReportErrorSnackBarKey), findsNothing);
  });

  testWidgets('non-organizer cannot see cancel action or call backend',
      (tester) async {
    currentUser = _TestAuthUser('guest-1');
    var cancelCalls = 0;
    final analyticsTracker = _RecordingEventsAnalyticsTracker();

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
          analyticsTracker: analyticsTracker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailOrganizerControlsKey), findsNothing);
    expect(find.byKey(eventDetailOrganizerCancelButtonKey), findsNothing);
    expect(cancelCalls, 0);
    expect(
      analyticsTracker
          .payloadsFor(EventsAnalyticsService.eventCanceledEventName),
      isEmpty,
    );
  });

  testWidgets('already canceled event renders canceled state without actions',
      (tester) async {
    var cancelCalls = 0;
    final analyticsTracker = _RecordingEventsAnalyticsTracker();

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
          analyticsTracker: analyticsTracker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailCanceledBannerKey), findsOneWidget);
    expect(find.byKey(eventDetailOrganizerControlsKey), findsNothing);
    expect(cancelCalls, 0);
    expect(
      analyticsTracker
          .payloadsFor(EventsAnalyticsService.eventCanceledEventName),
      isEmpty,
    );
  });

  testWidgets('cancel failure shows mapped error and re-enables action',
      (tester) async {
    var cancelCalls = 0;
    final analyticsTracker = _RecordingEventsAnalyticsTracker();

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
          analyticsTracker: analyticsTracker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(eventDetailOrganizerCancelButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventDetailCancelDialogConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(cancelCalls, 1);
    expect(
      analyticsTracker
          .payloadsFor(EventsAnalyticsService.eventCanceledEventName),
      isEmpty,
    );
    expect(find.byKey(eventDetailCancelErrorSnackBarKey), findsOneWidget);
    expect(find.text('Событие больше нельзя отменить.'), findsOneWidget);
    expect(find.byKey(eventDetailCanceledBannerKey), findsNothing);
    expect(find.byKey(eventDetailOrganizerControlsKey), findsOneWidget);
  });

  testWidgets('in-flight cancel blocks duplicate callable calls',
      (tester) async {
    final completer = Completer<Object?>();
    var cancelCalls = 0;
    final analyticsTracker = _RecordingEventsAnalyticsTracker();

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
          analyticsTracker: analyticsTracker,
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
    expect(
      analyticsTracker
          .payloadsFor(EventsAnalyticsService.eventCanceledEventName),
      hasLength(1),
    );
    expect(find.byKey(eventDetailCanceledBannerKey), findsOneWidget);
  });

  testWidgets('event canceled analytics failure does not block cancel success',
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
            return _cancelEventResponse();
          },
          analyticsTracker: const _ThrowingEventCanceledAnalyticsTracker(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(eventDetailOrganizerCancelButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventDetailCancelDialogConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(cancelCalls, 1);
    expect(find.byKey(eventDetailCanceledBannerKey), findsOneWidget);
  });

  testWidgets('join tap calls join callable and shows loading until completion',
      (tester) async {
    final completer = Completer<Object?>();
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    var joinCalls = 0;
    String? functionName;
    Map<String, dynamic>? payload;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: ' event-1 ',
          analyticsTracker: analyticsTracker,
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
    expect(
      analyticsTracker.payloadsFor(EventsAnalyticsService.eventJoinedEventName),
      [
        <String, String>{
          'countryCode': 'RU',
          'cityKey': 'moscow',
        },
      ],
    );
  });

  testWidgets('in-flight join blocks repeated primary taps', (tester) async {
    final completer = Completer<Object?>();
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    var joinCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          analyticsTracker: analyticsTracker,
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
    expect(
      analyticsTracker.payloadsFor(EventsAnalyticsService.eventJoinedEventName),
      [
        <String, String>{
          'countryCode': 'RU',
          'cityKey': 'moscow',
        },
      ],
    );
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
      expect(chatSemantics.flagsCollection.isEnabled, isTrue);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('successful join appends current user participant preview',
      (tester) async {
    currentUser = _TestAuthUser('student-1');
    currentUserDocument = UsersRecord.getDocumentFromData(
      {
        'display_name': 'Марко Росси',
        'photo_url': 'https://example.test/marco.jpg',
      },
      UsersRecord.collection.doc('student-1'),
    );

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(participantsCount: 2),
            ),
          ),
          participantsStream: (eventRef) =>
              Stream<List<EventParticipantsRecord>>.value([
            EventParticipantsRecord.getDocumentFromData(
              _participantData(
                userId: 'organizer-1',
                status: 'active',
                displayName: 'Anastasia Ivanova',
                joinedAt: DateTime.utc(2099, 6, 18, 12),
              ),
              EventParticipantsRecord.createDoc(eventRef, id: 'organizer-1'),
            ),
            EventParticipantsRecord.getDocumentFromData(
              _participantData(
                userId: 'student-2',
                status: 'active',
                displayName: 'hjk',
                joinedAt: DateTime.utc(2099, 6, 18, 13),
              ),
              EventParticipantsRecord.createDoc(eventRef, id: 'student-2'),
            ),
          ]),
          joinEventInvoker: (_, __) async =>
              _joinEventResponse(participantsCount: 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(find.text('3/10 мест'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(eventDetailParticipantTileKey(2)),
        matching: find.text('Марко Росси'),
      ),
      findsOneWidget,
    );
    expect(find.text('Участник'), findsNothing);
  });

  testWidgets('join analytics failure does not block successful join',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          analyticsTracker: const _ThrowingEventJoinedAnalyticsTracker(),
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(participantsCount: 5),
            ),
          ),
          joinEventInvoker: (_, __) async =>
              _joinEventResponse(participantsCount: 6),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.text('6/10 мест'), findsOneWidget);
  });

  testWidgets('joined participant can open chat from detail CTA',
      (tester) async {
    currentUser = _TestAuthUser('guest-1');
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    final router = GoRouter(
      initialLocation: '/events/event-1',
      routes: [
        GoRoute(
          name: EventDetailWidget.routeName,
          path: EventDetailWidget.routePath,
          builder: (context, state) => EventDetailRouteWidget(
            eventId: state.pathParameters['eventId']!,
            analyticsTracker: analyticsTracker,
            snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(),
              ),
            ),
            joinEventInvoker: (_, __) async => _joinEventResponse(),
          ),
        ),
        GoRoute(
          name: EventGroupChatWidget.routeName,
          path: EventGroupChatWidget.routePath,
          builder: (context, state) => EventGroupChatWidget(
            eventId: state.pathParameters['eventId']!,
            messagesStream: (_) =>
                Stream.value(const <EventChatMessagesRecord>[]),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailChatCtaKey), findsNothing);
    expect(router.getCurrentLocation(), '/events/event-1');
    expect(find.byType(EventGroupChatWidget), findsNothing);
    expect(
      analyticsTracker.payloadsFor(
        EventsAnalyticsService.eventChatOpenedEventName,
      ),
      isEmpty,
    );

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailChatCtaKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(router.getCurrentLocation(), '/events/event-1/chat');
    expect(find.byType(EventGroupChatWidget), findsOneWidget);
    expect(find.text('Чат события'), findsOneWidget);
    expect(
      analyticsTracker.payloadsFor(
        EventsAnalyticsService.eventChatOpenedEventName,
      ),
      [
        <String, String>{
          'countryCode': 'RU',
          'cityKey': 'moscow',
        },
      ],
    );
  });

  testWidgets('active participant can open chat from direct detail',
      (tester) async {
    currentUser = _TestAuthUser('uid-1');
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    final router = GoRouter(
      initialLocation: '/events/event-1',
      routes: [
        GoRoute(
          name: EventDetailWidget.routeName,
          path: EventDetailWidget.routePath,
          builder: (context, state) => EventDetailRouteWidget(
            eventId: state.pathParameters['eventId']!,
            analyticsTracker: analyticsTracker,
            snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(organizerId: 'organizer-1'),
              ),
            ),
            participantSnapshotStream: (participantRef) =>
                Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: participantRef,
                data: _participantData(
                  userId: 'uid-1',
                  status: 'active',
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          name: EventGroupChatWidget.routeName,
          path: EventGroupChatWidget.routePath,
          builder: (context, state) => EventGroupChatWidget(
            eventId: state.pathParameters['eventId']!,
            messagesStream: (_) =>
                Stream.value(const <EventChatMessagesRecord>[]),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailChatCtaKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(router.getCurrentLocation(), '/events/event-1/chat');
    expect(find.byType(EventGroupChatWidget), findsOneWidget);
    expect(
      analyticsTracker.payloadsFor(
        EventsAnalyticsService.eventChatOpenedEventName,
      ),
      [
        <String, String>{
          'countryCode': 'RU',
          'cityKey': 'moscow',
        },
      ],
    );
  });

  testWidgets('active participant can leave through primary CTA',
      (tester) async {
    currentUser = _TestAuthUser('uid-1');
    final semanticsHandle = tester.ensureSemantics();
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    var leaveCalls = 0;
    String? functionName;
    Map<String, dynamic>? payload;

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventDetailRouteWidget(
            eventId: ' event-1 ',
            analyticsTracker: analyticsTracker,
            snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(organizerId: 'organizer-1'),
              ),
            ),
            participantSnapshotStream: (participantRef) =>
                Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: participantRef,
                data: _participantData(
                  userId: 'uid-1',
                  status: 'active',
                ),
              ),
            ),
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

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('Присоединиться'), findsNothing);
      var primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isEnabled, isTrue);

      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventDetailLeaveDialogConfirmButtonKey));
      await tester.pumpAndSettle();

      expect(leaveCalls, 1);
      expect(functionName, leaveEventFunctionName);
      expect(payload, <String, dynamic>{'eventId': 'event-1'});
      expect(find.text('Присоединиться'), findsOneWidget);
      expect(find.text('Покинуть'), findsNothing);
      expect(
        analyticsTracker.payloadsFor(EventsAnalyticsService.eventLeftEventName),
        [
          <String, String>{
            'countryCode': 'RU',
            'cityKey': 'moscow',
          },
        ],
      );

      primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isEnabled, isTrue);
      expect(find.byKey(eventDetailChatCtaKey), findsNothing);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('started active participant keeps primary CTA locked',
      (tester) async {
    currentUser = _TestAuthUser('uid-1');
    final semanticsHandle = tester.ensureSemantics();
    var leaveCalls = 0;

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventDetailRouteWidget(
            eventId: 'event-1',
            snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(
                  organizerId: 'organizer-1',
                  startsAt: DateTime.utc(2000),
                ),
              ),
            ),
            participantSnapshotStream: (participantRef) =>
                Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: participantRef,
                data: _participantData(
                  userId: 'uid-1',
                  status: 'active',
                ),
              ),
            ),
            leaveEventInvoker: (_, __) async {
              leaveCalls += 1;
              return _leaveEventResponse();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Вы участвуете'), findsOneWidget);
      expect(find.text('Покинуть'), findsNothing);

      final primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isEnabled, isFalse);
      expect(primarySemantics.label, 'Вы участвуете');

      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pumpAndSettle();

      expect(leaveCalls, 0);
      expect(find.byKey(eventDetailLeaveDialogKey), findsNothing);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('active participant leave action locks automatically at startsAt',
      (tester) async {
    currentUser = _TestAuthUser('uid-1');
    const startsAfter = Duration(seconds: 30);
    final startsAt = DateTime.now().toUtc().add(startsAfter);
    var leaveCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(
                organizerId: 'organizer-1',
                startsAt: startsAt,
              ),
            ),
          ),
          participantSnapshotStream: (participantRef) =>
              Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: participantRef,
              data: _participantData(
                userId: 'uid-1',
                status: 'active',
              ),
            ),
          ),
          leaveEventInvoker: (_, __) async {
            leaveCalls += 1;
            return _leaveEventResponse();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Покинуть'), findsOneWidget);

    await tester.pump(startsAfter + const Duration(milliseconds: 1));

    expect(find.text('Вы участвуете'), findsOneWidget);
    expect(find.text('Покинуть'), findsNothing);

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(leaveCalls, 0);
    expect(find.byKey(eventDetailLeaveDialogKey), findsNothing);
  });

  testWidgets('server-side disabled CTA states do not call join',
      (tester) async {
    currentUser = null;
    final semanticsHandle = tester.ensureSemantics();
    final cases = <({
      String label,
      String semanticsReason,
      Map<String, dynamic> eventData,
    })>[
      (
        label: 'Мест нет',
        semanticsReason: 'Мест нет',
        eventData: _eventData(participantsCount: 10),
      ),
      (
        label: 'Отменено',
        semanticsReason: 'Событие отменено',
        eventData: _eventData(status: 'canceled'),
      ),
      (
        label: 'Уже началось',
        semanticsReason: 'Событие уже началось',
        eventData: _eventData(startsAt: DateTime.utc(2000)),
      ),
    ];

    try {
      for (final testCase in cases) {
        var joinCalls = 0;

        await tester.pumpWidget(
          _buildTestApp(
            home: EventDetailRouteWidget(
              eventId: 'event-1',
              snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
                _FakeEventDocumentSnapshot(
                  reference: eventRef,
                  data: testCase.eventData,
                ),
              ),
              joinEventInvoker: (_, __) async {
                joinCalls += 1;
                return _joinEventResponse();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(testCase.label), findsOneWidget);

        final primarySemantics =
            tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
        expect(primarySemantics.flagsCollection.isEnabled, isFalse);
        expect(primarySemantics.label, contains(testCase.semanticsReason));

        await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
        await tester.pumpAndSettle();

        expect(joinCalls, 0);
      }
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('event change ignores stale active participant snapshot',
      (tester) async {
    currentUser = _TestAuthUser('uid-1');
    final firstParticipantController = StreamController<DocumentSnapshot>();
    final secondParticipantController = StreamController<DocumentSnapshot>();
    addTearDown(firstParticipantController.close);
    addTearDown(secondParticipantController.close);
    var leaveCalls = 0;

    Stream<DocumentSnapshot> Function(DocumentReference) snapshotStreamFor(
      String title,
    ) =>
        (eventRef) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(
                  title: title,
                  organizerId: 'organizer-1',
                ),
              ),
            ).asBroadcastStream();

    Stream<DocumentSnapshot> participantSnapshotStream(
      DocumentReference participantRef,
    ) {
      final eventId = participantRef.parent.parent!.id;
      if (eventId == 'event-1') {
        return firstParticipantController.stream;
      }
      return secondParticipantController.stream;
    }

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: snapshotStreamFor('First event'),
          participantSnapshotStream: participantSnapshotStream,
          joinEventInvoker: (_, __) async => _joinEventResponse(),
          leaveEventInvoker: (_, __) async {
            leaveCalls += 1;
            return _leaveEventResponse();
          },
        ),
      ),
    );
    await tester.pump();

    firstParticipantController.add(
      _FakeEventDocumentSnapshot(
        reference: EventParticipantsRecord.createDoc(
          EventsRecord.collection.doc('event-1'),
          id: 'uid-1',
        ),
        data: _participantData(
          userId: 'uid-1',
          status: 'active',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First event'), findsOneWidget);
    expect(find.text('Покинуть'), findsOneWidget);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-2',
          snapshotStream: snapshotStreamFor('Second event'),
          participantSnapshotStream: participantSnapshotStream,
          joinEventInvoker: (_, __) async =>
              _joinEventResponse(eventId: 'event-2'),
          leaveEventInvoker: (_, __) async {
            leaveCalls += 1;
            return _leaveEventResponse(eventId: 'event-2');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Second event'), findsOneWidget);
    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('Покинуть'), findsNothing);
    expect(leaveCalls, 0);
    expect(find.byKey(eventDetailLeaveDialogKey), findsNothing);
  });

  testWidgets('organizer can open chat from detail and logs analytics',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    final router = GoRouter(
      initialLocation: '/events/event-1',
      routes: [
        GoRoute(
          name: EventDetailWidget.routeName,
          path: EventDetailWidget.routePath,
          builder: (context, state) => EventDetailRouteWidget(
            eventId: state.pathParameters['eventId']!,
            analyticsTracker: analyticsTracker,
            snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(
                  countryCode: ' it ',
                  cityKey: ' rome ',
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          name: EventGroupChatWidget.routeName,
          path: EventGroupChatWidget.routePath,
          builder: (context, state) => EventGroupChatWidget(
            eventId: state.pathParameters['eventId']!,
            messagesStream: (_) =>
                Stream.value(const <EventChatMessagesRecord>[]),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailChatCtaKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(router.getCurrentLocation(), '/events/event-1/chat');
    expect(
      analyticsTracker.payloadsFor(
        EventsAnalyticsService.eventChatOpenedEventName,
      ),
      [
        <String, String>{
          'countryCode': 'IT',
          'cityKey': 'rome',
        },
      ],
    );
  });

  testWidgets('chat opened analytics failure does not block navigation',
      (tester) async {
    currentUser = _TestAuthUser('uid-1');
    final router = GoRouter(
      initialLocation: '/events/event-1',
      routes: [
        GoRoute(
          name: EventDetailWidget.routeName,
          path: EventDetailWidget.routePath,
          builder: (context, state) => EventDetailRouteWidget(
            eventId: state.pathParameters['eventId']!,
            analyticsTracker: const _ThrowingEventChatOpenedAnalyticsTracker(),
            snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(organizerId: 'organizer-1'),
              ),
            ),
            participantSnapshotStream: (participantRef) =>
                Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: participantRef,
                data: _participantData(
                  userId: 'uid-1',
                  status: 'active',
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          name: EventGroupChatWidget.routeName,
          path: EventGroupChatWidget.routePath,
          builder: (context, state) => EventGroupChatWidget(
            eventId: state.pathParameters['eventId']!,
            messagesStream: (_) =>
                Stream.value(const <EventChatMessagesRecord>[]),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailChatCtaKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(router.getCurrentLocation(), '/events/event-1/chat');
    expect(find.byType(EventGroupChatWidget), findsOneWidget);
  });

  testWidgets('left participant cannot open chat from direct detail',
      (tester) async {
    currentUser = _TestAuthUser('uid-1');
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    final router = GoRouter(
      initialLocation: '/events/event-1',
      routes: [
        GoRoute(
          name: EventDetailWidget.routeName,
          path: EventDetailWidget.routePath,
          builder: (context, state) => EventDetailRouteWidget(
            eventId: state.pathParameters['eventId']!,
            analyticsTracker: analyticsTracker,
            snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(organizerId: 'organizer-1'),
              ),
            ),
            participantSnapshotStream: (participantRef) =>
                Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: participantRef,
                data: _participantData(
                  userId: 'uid-1',
                  status: 'left',
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          name: EventGroupChatWidget.routeName,
          path: EventGroupChatWidget.routePath,
          builder: (context, state) => EventGroupChatWidget(
            eventId: state.pathParameters['eventId']!,
            messagesStream: (_) =>
                Stream.value(const <EventChatMessagesRecord>[]),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pumpAndSettle();

    expect(find.byKey(eventDetailChatCtaKey), findsNothing);
    expect(router.getCurrentLocation(), '/events/event-1');
    expect(find.byType(EventGroupChatWidget), findsNothing);
    expect(
      analyticsTracker.payloadsFor(
        EventsAnalyticsService.eventChatOpenedEventName,
      ),
      isEmpty,
    );
  });

  testWidgets('joined participant can leave through primary CTA',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      final analyticsTracker = _RecordingEventsAnalyticsTracker();
      var joinCalls = 0;
      var leaveCalls = 0;
      String? functionName;
      Map<String, dynamic>? payload;

      await tester.pumpWidget(
        _buildTestApp(
          home: EventDetailRouteWidget(
            eventId: ' event-1 ',
            analyticsTracker: analyticsTracker,
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
      expect(find.text('5/10 мест'), findsOneWidget);
      expect(find.text('6/10 мест'), findsNothing);
      expect(
        analyticsTracker.payloadsFor(EventsAnalyticsService.eventLeftEventName),
        [
          <String, String>{
            'countryCode': 'RU',
            'cityKey': 'moscow',
          },
        ],
      );

      expect(find.byKey(eventDetailChatCtaKey), findsNothing);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('leave updates occupancy until snapshot catches up',
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
          leaveEventInvoker: (_, __) async =>
              _leaveEventResponse(participantsCount: 5),
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

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(find.text('6/10 мест'), findsOneWidget);

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventDetailLeaveDialogConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('5/10 мест'), findsOneWidget);
    expect(find.text('6/10 мест'), findsNothing);

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(participantsCount: 4),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4/10 мест'), findsOneWidget);
    expect(find.text('5/10 мест'), findsNothing);

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(participantsCount: 7),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7/10 мест'), findsOneWidget);
    expect(find.text('5/10 мест'), findsNothing);
  });

  testWidgets('leave count re-enables join when stale snapshot was full',
      (tester) async {
    final streamController = StreamController<DocumentSnapshot>();
    addTearDown(streamController.close);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => streamController.stream,
          joinEventInvoker: (_, __) async =>
              _joinEventResponse(participantsCount: 10),
          leaveEventInvoker: (_, __) async =>
              _leaveEventResponse(participantsCount: 9),
        ),
      ),
    );
    await tester.pump();

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(participantsCount: 9),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.text('10/10 мест'), findsOneWidget);

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(participantsCount: 10),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(eventDetailLeaveDialogConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('9/10 мест'), findsOneWidget);
    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('Мест нет'), findsNothing);
  });

  testWidgets('in-flight leave blocks repeated primary taps', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final leaveCompleter = Completer<Object?>();
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    var leaveCalls = 0;

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventDetailRouteWidget(
            eventId: 'event-1',
            analyticsTracker: analyticsTracker,
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
      expect(
        analyticsTracker.payloadsFor(EventsAnalyticsService.eventLeftEventName),
        [
          <String, String>{
            'countryCode': 'RU',
            'cityKey': 'moscow',
          },
        ],
      );
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('leave analytics failure does not block successful leave',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          analyticsTracker: const _ThrowingEventLeftAnalyticsTracker(),
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(participantsCount: 5),
            ),
          ),
          joinEventInvoker: (_, __) async =>
              _joinEventResponse(participantsCount: 6),
          leaveEventInvoker: (_, __) async =>
              _leaveEventResponse(participantsCount: 5),
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

    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('5/10 мест'), findsOneWidget);
  });

  testWidgets('leave analytics tracks again after rejoining same event',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    var leaveCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          analyticsTracker: analyticsTracker,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(participantsCount: 5),
            ),
          ),
          joinEventInvoker: (_, __) async =>
              _joinEventResponse(participantsCount: 6),
          leaveEventInvoker: (_, __) async {
            leaveCalls += 1;
            return _leaveEventResponse(participantsCount: 5);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i += 1) {
      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventDetailLeaveDialogConfirmButtonKey));
      await tester.pumpAndSettle();
    }

    expect(leaveCalls, 2);
    expect(
      analyticsTracker.payloadsFor(EventsAnalyticsService.eventLeftEventName),
      [
        <String, String>{
          'countryCode': 'RU',
          'cityKey': 'moscow',
        },
        <String, String>{
          'countryCode': 'RU',
          'cityKey': 'moscow',
        },
      ],
    );
  });

  testWidgets('leave failure clears loading state without changing CTA',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    var leaveCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          analyticsTracker: analyticsTracker,
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
    expect(
      analyticsTracker.payloadsFor(EventsAnalyticsService.eventLeftEventName),
      isEmpty,
    );
  });

  testWidgets('leave race with event start shows clear error', (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    var leaveCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          analyticsTracker: analyticsTracker,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(
                startsAt: DateTime.now().toUtc().add(
                      const Duration(minutes: 5),
                    ),
              ),
            ),
          ),
          joinEventInvoker: (_, __) async => _joinEventResponse(),
          leaveEventInvoker: (_, __) async {
            leaveCalls += 1;
            throw _leaveDomainError(
              'event_not_leaveable',
              reason: 'event_started',
            );
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
    expect(find.byKey(eventDetailLeaveErrorSnackBarKey), findsOneWidget);
    expect(find.text('Событие уже началось, выйти из него нельзя.'),
        findsOneWidget);
    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.text('Присоединиться'), findsNothing);
    expect(
      analyticsTracker.payloadsFor(EventsAnalyticsService.eventLeftEventName),
      isEmpty,
    );
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
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    var joinCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          analyticsTracker: analyticsTracker,
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
    expect(
      analyticsTracker.payloadsFor(EventsAnalyticsService.eventJoinedEventName),
      isEmpty,
    );
  });

  for (final scenario in [
    (
      name: 'full event',
      error: _joinDomainError('event_full'),
      message: 'В этом событии уже нет свободных мест.',
    ),
    (
      name: 'canceled event',
      error: _joinDomainError(
        'event_not_joinable',
        reason: 'not_active',
      ),
      message: 'Событие отменено, присоединиться нельзя.',
    ),
    (
      name: 'past event',
      error: _joinDomainError(
        'event_not_joinable',
        reason: 'past_event',
      ),
      message: 'Событие уже началось, присоединиться нельзя.',
    ),
    (
      name: 'duplicate join',
      error: _joinDomainError('already_joined'),
      message: 'Вы уже присоединились к этому событию.',
    ),
  ]) {
    testWidgets('join failure shows clear ${scenario.name} error',
        (tester) async {
      final analyticsTracker = _RecordingEventsAnalyticsTracker();
      var joinCalls = 0;

      await tester.pumpWidget(
        _buildTestApp(
          home: EventDetailRouteWidget(
            eventId: 'event-1',
            analyticsTracker: analyticsTracker,
            snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(),
              ),
            ),
            joinEventInvoker: (_, __) async {
              joinCalls += 1;
              throw scenario.error;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pumpAndSettle();

      expect(joinCalls, 1);
      expect(find.byKey(eventDetailJoinErrorSnackBarKey), findsOneWidget);
      expect(find.text(scenario.message), findsOneWidget);
      expect(find.text('Присоединиться'), findsOneWidget);
      expect(find.text('Присоединяемся...'), findsNothing);
      expect(
        analyticsTracker.payloadsFor(
          EventsAnalyticsService.eventJoinedEventName,
        ),
        isEmpty,
      );
    });
  }

  testWidgets('event change clears in-flight join loading state',
      (tester) async {
    final firstJoinCompleter = Completer<Object?>();
    final secondJoinCompleter = Completer<Object?>();
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    final joinedEventIds = <String>[];

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          analyticsTracker: analyticsTracker,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(
                title: 'First event',
                countryCode: 'RU',
                cityKey: 'moscow',
              ),
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
          analyticsTracker: analyticsTracker,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(
                title: 'Second event',
                countryCode: 'US',
                cityKey: 'new_york',
              ),
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
    expect(
      analyticsTracker.payloadsFor(EventsAnalyticsService.eventJoinedEventName),
      [
        <String, String>{
          'countryCode': 'US',
          'cityKey': 'new_york',
        },
      ],
    );
  });

  testWidgets('tracks event detail opened once with canonical city payload',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    final controller = StreamController<DocumentSnapshot>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          analyticsTracker: analyticsTracker,
          snapshotStream: (eventRef) => controller.stream,
        ),
      ),
    );
    await tester.pump();

    expect(analyticsTracker.payloadsFor('event_detail_opened'), isEmpty);

    controller.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(countryCode: ' ru ', cityKey: 'moscow'),
      ),
    );
    await tester.pumpAndSettle();

    controller.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(
          title: 'Updated title',
          countryCode: 'RU',
          cityKey: 'moscow',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(analyticsTracker.payloadsFor('event_detail_opened'), [
      <String, String>{
        'countryCode': 'RU',
        'cityKey': 'moscow',
      },
    ]);
  });

  testWidgets('does not track event detail opened for missing city identity',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          analyticsTracker: analyticsTracker,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(countryCode: '', cityKey: ''),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(analyticsTracker.eventDetailOpenedCallCount, 0);
    expect(analyticsTracker.payloadsFor('event_detail_opened'), isEmpty);
  });

  testWidgets('tracks event detail opened again when route event changes',
      (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          analyticsTracker: analyticsTracker,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(countryCode: 'RU', cityKey: 'moscow'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-2',
          analyticsTracker: analyticsTracker,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(countryCode: 'US', cityKey: 'new_york'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(analyticsTracker.payloadsFor('event_detail_opened'), [
      <String, String>{'countryCode': 'RU', 'cityKey': 'moscow'},
      <String, String>{'countryCode': 'US', 'cityKey': 'new_york'},
    ]);
  });

  testWidgets('event change ignores stale in-flight leave completion',
      (tester) async {
    final leaveCompleter = Completer<Object?>();
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    var leaveCalls = 0;
    var secondJoinCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          analyticsTracker: analyticsTracker,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(
                title: 'First event',
                countryCode: 'RU',
                cityKey: 'moscow',
              ),
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
          analyticsTracker: analyticsTracker,
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(
                title: 'Second event',
                countryCode: 'US',
                cityKey: 'new_york',
              ),
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

    leaveCompleter.complete(
      _leaveEventResponse(
        eventId: 'event-1',
        participantsCount: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Second event'), findsOneWidget);
    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.text('Присоединиться'), findsNothing);
    expect(find.text('2/10 мест'), findsNothing);
    expect(
      analyticsTracker.payloadsFor(EventsAnalyticsService.eventLeftEventName),
      isEmpty,
    );
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

  testWidgets('started joined event disables leave action', (tester) async {
    final streamController = StreamController<DocumentSnapshot>();
    addTearDown(streamController.close);
    var leaveCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-2',
          snapshotStream: (eventRef) => streamController.stream,
          joinEventInvoker: (_, __) async =>
              _joinEventResponse(eventId: 'event-2'),
          leaveEventInvoker: (_, __) async {
            leaveCalls += 1;
            return _leaveEventResponse(eventId: 'event-2');
          },
        ),
      ),
    );
    await tester.pump();

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-2'),
        data: _eventData(
          startsAt: DateTime.utc(2099, 6, 18, 15),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(find.text('Покинуть'), findsOneWidget);

    streamController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-2'),
        data: _eventData(startsAt: DateTime.utc(2000)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Вы участвуете'), findsOneWidget);
    expect(find.text('Покинуть'), findsNothing);
    expect(find.byKey(eventDetailLeaveDialogKey), findsNothing);

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(leaveCalls, 0);
    expect(find.byKey(eventDetailLeaveDialogKey), findsNothing);
  });

  testWidgets('leave confirmation confirm is ignored after event starts',
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
        data: _eventData(startsAt: DateTime.utc(2099, 6, 18, 15)),
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
        data: _eventData(startsAt: DateTime.utc(2000)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailLeaveDialogConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(leaveCalls, 0);
    expect(find.text('Вы участвуете'), findsOneWidget);
  });

  testWidgets('joined leave action locks automatically at startsAt',
      (tester) async {
    const startsAfter = Duration(seconds: 30);
    final startsAt = DateTime.now().toUtc().add(startsAfter);
    var leaveCalls = 0;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(startsAt: startsAt),
            ),
          ),
          joinEventInvoker: (_, __) async => _joinEventResponse(),
          leaveEventInvoker: (_, __) async {
            leaveCalls += 1;
            return _leaveEventResponse();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(find.text('Покинуть'), findsOneWidget);

    await tester.pump(startsAfter + const Duration(milliseconds: 1));

    expect(find.text('Вы участвуете'), findsOneWidget);
    expect(find.text('Покинуть'), findsNothing);

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pumpAndSettle();

    expect(leaveCalls, 0);
    expect(find.byKey(eventDetailLeaveDialogKey), findsNothing);
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
  String countryCode = 'RU',
  String cityKey = 'moscow',
  DateTime? startsAt,
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
      'countryCode': countryCode,
      'cityKey': cityKey,
      'startsAt': startsAt ?? DateTime.utc(2099, 6, 18, 15),
      'timeZoneId': 'Europe/Moscow',
      'capacity': 10,
      'participantsCount': participantsCount,
      'organizerId': organizerId,
      'organizerDisplayName': 'Anastasia Ivanova',
      'organizerPhotoUrl': 'https://example.com/anastasia.png',
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

Map<String, dynamic> _participantData({
  required String userId,
  required String status,
  String displayName = 'Participant',
  String? photoUrl,
  DateTime? joinedAt,
}) =>
    <String, dynamic>{
      'userId': userId,
      'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'role': 'participant',
      'status': status,
      if (joinedAt != null) 'joinedAt': joinedAt,
    };

FirebaseFunctionsException _joinDomainError(
  String domainCode, {
  String? reason,
}) =>
    _TestFirebaseFunctionsException(
      code: 'failed-precondition',
      message: 'Raw backend message',
      details: <String, dynamic>{
        'domainCode': domainCode,
        if (reason != null) 'reason': reason,
      },
    );

FirebaseFunctionsException _leaveDomainError(
  String domainCode, {
  String? reason,
}) =>
    _TestFirebaseFunctionsException(
      code: 'failed-precondition',
      message: 'Raw backend message',
      details: <String, dynamic>{
        'domainCode': domainCode,
        if (reason != null) 'reason': reason,
      },
    );

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

class _RecordingEventsAnalyticsTracker implements EventsAnalyticsTracker {
  final List<_RecordedAnalyticsEvent> events = <_RecordedAnalyticsEvent>[];
  int eventDetailOpenedCallCount = 0;

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
  }) async {
    eventDetailOpenedCallCount += 1;
    final payload = eventCityAnalyticsPayload(
      countryCode: event.countryCode,
      cityKey: event.cityKey,
      citySource: citySource,
    );
    if (payload == null) {
      return;
    }
    events.add(
      _RecordedAnalyticsEvent(
        name: EventsAnalyticsService.eventDetailOpenedEventName,
        payload: payload.cast<String, String>(),
      ),
    );
  }

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
  }) async {
    final payload = eventCityAnalyticsPayload(
      countryCode: event.countryCode,
      cityKey: event.cityKey,
      citySource: citySource,
    );
    if (payload == null) {
      return;
    }
    events.add(
      _RecordedAnalyticsEvent(
        name: EventsAnalyticsService.eventJoinedEventName,
        payload: payload.cast<String, String>(),
      ),
    );
  }

  @override
  Future<void> trackEventLeft(
    EventsRecord event, {
    String? citySource,
  }) async {
    final payload = eventCityAnalyticsPayload(
      countryCode: event.countryCode,
      cityKey: event.cityKey,
      citySource: citySource,
    );
    if (payload == null) {
      return;
    }
    events.add(
      _RecordedAnalyticsEvent(
        name: EventsAnalyticsService.eventLeftEventName,
        payload: payload.cast<String, String>(),
      ),
    );
  }

  @override
  Future<void> trackEventChatOpened({
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
        name: EventsAnalyticsService.eventChatOpenedEventName,
        payload: payload.cast<String, String>(),
      ),
    );
  }

  @override
  Future<void> trackEventCanceled(
    EventsRecord event, {
    String? citySource,
  }) async {
    final payload = eventCityAnalyticsPayload(
      countryCode: event.countryCode,
      cityKey: event.cityKey,
      citySource: citySource,
    );
    if (payload == null) {
      return;
    }
    events.add(
      _RecordedAnalyticsEvent(
        name: EventsAnalyticsService.eventCanceledEventName,
        payload: payload.cast<String, String>(),
      ),
    );
  }
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

class _ThrowingEventJoinedAnalyticsTracker extends _NoopEventsAnalyticsTracker {
  const _ThrowingEventJoinedAnalyticsTracker();

  @override
  Future<void> trackEventJoined(
    EventsRecord event, {
    String? citySource,
  }) {
    throw StateError('analytics failed');
  }
}

class _ThrowingEventLeftAnalyticsTracker extends _NoopEventsAnalyticsTracker {
  const _ThrowingEventLeftAnalyticsTracker();

  @override
  Future<void> trackEventLeft(
    EventsRecord event, {
    String? citySource,
  }) {
    throw StateError('analytics failed');
  }
}

class _ThrowingEventChatOpenedAnalyticsTracker
    extends _NoopEventsAnalyticsTracker {
  const _ThrowingEventChatOpenedAnalyticsTracker();

  @override
  Future<void> trackEventChatOpened({
    required String countryCode,
    required String cityKey,
    String? citySource,
  }) {
    throw StateError('analytics failed');
  }
}

class _ThrowingEventCanceledAnalyticsTracker
    extends _NoopEventsAnalyticsTracker {
  const _ThrowingEventCanceledAnalyticsTracker();

  @override
  Future<void> trackEventCanceled(
    EventsRecord event, {
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

class _TestFirebaseFunctionsException extends FirebaseFunctionsException {
  _TestFirebaseFunctionsException({
    required super.code,
    required super.message,
    super.details,
  });
}
