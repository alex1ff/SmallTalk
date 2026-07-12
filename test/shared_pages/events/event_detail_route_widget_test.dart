import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/components/ux_refreshing_indicator_overlay.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
import 'package:small_talk/shared_pages/design/expatlio_design.dart';
import 'package:small_talk/shared_pages/events/event_detail_route_widget.dart';
import 'package:small_talk/shared_pages/events/event_detail_widget.dart';
import 'package:small_talk/shared_pages/events/event_group_chat_widget.dart';
import 'package:small_talk/services/event_actions_repository.dart';
import 'package:small_talk/services/event_detail_repository.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';
import 'package:small_talk/services/event_selected_city_state.dart';
import 'package:small_talk/services/events_analytics_service.dart';
import 'package:small_talk/services/user_public_profile_preload_repository.dart';
import 'package:small_talk/services/ux_session_cache_lifecycle.dart';

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

Widget _buildDetailRouteTestApp({
  required String eventId,
  required EventDetailSnapshotStream snapshotStream,
  EventsAnalyticsTracker? analyticsTracker,
  Locale locale = const Locale('ru'),
  EdgeInsets mediaQueryPadding = EdgeInsets.zero,
}) {
  Widget route = EventDetailRouteWidget(
    eventId: eventId,
    snapshotStream: snapshotStream,
    participantSnapshotStream: (participantRef) =>
        Stream<DocumentSnapshot>.value(
      _FakeEventDocumentSnapshot(
        reference: participantRef,
        exists: false,
      ),
    ),
    participantsStream: (_) => Stream<List<EventParticipantsRecord>>.value(
      const <EventParticipantsRecord>[],
    ),
    analyticsTracker: analyticsTracker,
  );
  if (mediaQueryPadding != EdgeInsets.zero) {
    route = MediaQuery(
      data: MediaQueryData(padding: mediaQueryPadding),
      child: route,
    );
  }
  return _buildTestApp(home: route, locale: locale);
}

Future<void> _cacheEventDetailForTest({
  required String eventId,
  required String userId,
  required String title,
}) =>
    EventDetailRepository.watchEventDetail(
      eventId: eventId,
      sessionCacheUserId: userId,
      snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
        _FakeEventDocumentSnapshot(
          reference: eventRef,
          data: _eventData(title: title),
        ),
      ),
    ).drain<void>();

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
    EventDetailRepository.clearEventDetailSessionCache();
    currentUser = _TestAuthUser('organizer-1');
    UxSessionCacheLifecycle.updateAuthenticatedUser('organizer-1');
    EventsAnalyticsService.defaultTracker = const _NoopEventsAnalyticsTracker();
  });

  tearDown(() {
    EventsAnalyticsService.defaultTracker = EventsAnalyticsService.instance;
    UxSessionCacheLifecycle.updateAuthenticatedUser(null);
    currentUser = null;
    currentUserDocument = null;
  });

  testWidgets('route stores confirmed detail for the current session user',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: ' event-1 ',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(title: 'Cached conversation club'),
            ),
          ),
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
          participantsStream: (_) =>
              Stream<List<EventParticipantsRecord>>.value(
            const <EventParticipantsRecord>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cached conversation club'), findsOneWidget);
    expect(
      EventDetailRepository.cachedEventDetail(
        eventId: 'event-1',
        userId: 'organizer-1',
      )?.title,
      'Cached conversation club',
    );
    expect(
      EventDetailRepository.cachedEventDetail(
        eventId: 'event-1',
        userId: 'another-user',
      ),
      isNull,
    );
  });

  testWidgets('route recreates its detail stream when the user changes',
      (tester) async {
    var streamCalls = 0;
    Stream<DocumentSnapshot> detailStream(DocumentReference eventRef) {
      streamCalls += 1;
      final userId = currentUser?.uid ?? '';
      return Stream<DocumentSnapshot>.value(
        _FakeEventDocumentSnapshot(
          reference: eventRef,
          data: _eventData(title: '$userId event'),
        ),
      );
    }

    Widget buildRoute() => _buildTestApp(
          home: EventDetailRouteWidget(
            eventId: 'event-1',
            snapshotStream: detailStream,
            participantSnapshotStream: (participantRef) =>
                Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: participantRef,
                data: _participantData(
                  userId: currentUser?.uid ?? '',
                  status: 'active',
                ),
              ),
            ),
            participantsStream: (_) =>
                Stream<List<EventParticipantsRecord>>.value(
              const <EventParticipantsRecord>[],
            ),
          ),
        );

    currentUser = _TestAuthUser('user-a');
    UxSessionCacheLifecycle.updateAuthenticatedUser('user-a');
    await tester.pumpWidget(buildRoute());
    await tester.pumpAndSettle();
    expect(
      EventDetailRepository.cachedEventDetail(
        eventId: 'event-1',
        userId: 'user-a',
      )?.title,
      'user-a event',
    );

    currentUser = _TestAuthUser('user-b');
    UxSessionCacheLifecycle.updateAuthenticatedUser('user-b');
    await tester.pumpWidget(buildRoute());
    await tester.pumpAndSettle();
    expect(streamCalls, 2);

    expect(
      EventDetailRepository.cachedEventDetail(
        eventId: 'event-1',
        userId: 'user-a',
      ),
      isNull,
    );
    expect(
      EventDetailRepository.cachedEventDetail(
        eventId: 'event-1',
        userId: 'user-b',
      )?.title,
      'user-b event',
    );
  });

  testWidgets('cold detail load keeps the full loading state', (tester) async {
    final controller = StreamController<DocumentSnapshot>.broadcast(sync: true);

    await tester.pumpWidget(
      _buildDetailRouteTestApp(
        eventId: 'event-1',
        snapshotStream: (_) => controller.stream,
      ),
    );
    await tester.pump();

    expect(find.byKey(eventDetailRouteLoadingKey), findsOneWidget);
    expect(
      find.byKey(eventDetailRouteRefreshingIndicatorKey),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await controller.close();
  });

  testWidgets('warm detail cache replaces full loader with refresh indicator',
      (tester) async {
    await _cacheEventDetailForTest(
      eventId: 'event-1',
      userId: 'organizer-1',
      title: 'Cached event title',
    );
    final controller = StreamController<DocumentSnapshot>.broadcast(sync: true);

    await tester.pumpWidget(
      _buildDetailRouteTestApp(
        eventId: 'event-1',
        snapshotStream: (_) => controller.stream,
      ),
    );
    await tester.pump();

    expect(find.text('Cached event title'), findsOneWidget);
    expect(find.byKey(eventDetailRouteLoadingKey), findsNothing);
    var refreshOverlay = tester.widget<UxRefreshingIndicatorOverlay>(
      find.byKey(eventDetailRouteRefreshingIndicatorKey),
    );
    expect(refreshOverlay.isRefreshing, isTrue);
    expect(find.bySemanticsLabel('Обновляем событие'), findsOneWidget);

    controller.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(title: 'Fresh event title'),
      ),
    );
    await tester.pump();

    expect(find.text('Fresh event title'), findsOneWidget);
    expect(find.text('Cached event title'), findsNothing);
    refreshOverlay = tester.widget<UxRefreshingIndicatorOverlay>(
      find.byKey(eventDetailRouteRefreshingIndicatorKey),
    );
    expect(refreshOverlay.isRefreshing, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await controller.close();
  });

  testWidgets('refresh indicator respects safe area and English semantics',
      (tester) async {
    await _cacheEventDetailForTest(
      eventId: 'event-1',
      userId: 'organizer-1',
      title: 'Cached event title',
    );
    final controller = StreamController<DocumentSnapshot>.broadcast(sync: true);
    const systemTopInset = 44.0;

    await tester.pumpWidget(
      _buildDetailRouteTestApp(
        eventId: 'event-1',
        snapshotStream: (_) => controller.stream,
        locale: const Locale('en'),
        mediaQueryPadding: const EdgeInsets.only(top: systemTopInset),
      ),
    );
    await tester.pump();

    final refreshOverlay = tester.widget<UxRefreshingIndicatorOverlay>(
      find.byKey(eventDetailRouteRefreshingIndicatorKey),
    );
    final resolvedPadding = refreshOverlay.padding.resolve(TextDirection.ltr);
    expect(
      resolvedPadding.top,
      systemTopInset + ExpatlioDesign.space8,
    );
    expect(find.bySemanticsLabel('Refreshing event'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await controller.close();
  });

  testWidgets('same-key stream restart keeps the shown detail', (tester) async {
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    await tester.pumpWidget(
      _buildDetailRouteTestApp(
        eventId: 'event-1',
        analyticsTracker: analyticsTracker,
        snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
          _FakeEventDocumentSnapshot(
            reference: eventRef,
            data: _eventData(title: 'Shown event title'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      analyticsTracker.payloadsFor('event_detail_opened'),
      hasLength(1),
    );
    final refreshController =
        StreamController<DocumentSnapshot>.broadcast(sync: true);

    await tester.pumpWidget(
      _buildDetailRouteTestApp(
        eventId: 'event-1',
        analyticsTracker: analyticsTracker,
        snapshotStream: (_) => refreshController.stream,
      ),
    );
    await tester.pump();

    expect(find.text('Shown event title'), findsOneWidget);
    expect(find.byKey(eventDetailRouteLoadingKey), findsNothing);
    expect(
      tester
          .widget<UxRefreshingIndicatorOverlay>(
            find.byKey(eventDetailRouteRefreshingIndicatorKey),
          )
          .isRefreshing,
      isTrue,
    );

    refreshController.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(title: 'Refreshed event title'),
      ),
    );
    await tester.pump();

    expect(find.text('Refreshed event title'), findsOneWidget);
    expect(find.text('Shown event title'), findsNothing);
    expect(
      analyticsTracker.payloadsFor('event_detail_opened'),
      hasLength(1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await refreshController.close();
  });

  testWidgets('event key change never shows the previous event',
      (tester) async {
    await tester.pumpWidget(
      _buildDetailRouteTestApp(
        eventId: 'event-1',
        snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
          _FakeEventDocumentSnapshot(
            reference: eventRef,
            data: _eventData(title: 'Event one title'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final nextEventController =
        StreamController<DocumentSnapshot>.broadcast(sync: true);

    await tester.pumpWidget(
      _buildDetailRouteTestApp(
        eventId: 'event-2',
        snapshotStream: (_) => nextEventController.stream,
      ),
    );
    await tester.pump();

    expect(find.text('Event one title'), findsNothing);
    expect(find.byKey(eventDetailRouteLoadingKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await nextEventController.close();
  });

  testWidgets('user key change never shows the previous user detail',
      (tester) async {
    currentUser = _TestAuthUser('user-a');
    UxSessionCacheLifecycle.updateAuthenticatedUser('user-a');
    await tester.pumpWidget(
      _buildDetailRouteTestApp(
        eventId: 'event-1',
        snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
          _FakeEventDocumentSnapshot(
            reference: eventRef,
            data: _eventData(title: 'User A detail'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final userBController =
        StreamController<DocumentSnapshot>.broadcast(sync: true);

    currentUser = _TestAuthUser('user-b');
    UxSessionCacheLifecycle.updateAuthenticatedUser('user-b');
    await tester.pumpWidget(
      _buildDetailRouteTestApp(
        eventId: 'event-1',
        snapshotStream: (_) => userBController.stream,
      ),
    );
    await tester.pump();

    expect(find.text('User A detail'), findsNothing);
    expect(find.byKey(eventDetailRouteLoadingKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await userBController.close();
  });

  testWidgets('auth lifecycle wins when auth sources temporarily disagree',
      (tester) async {
    currentUser = _TestAuthUser('stale-user');
    UxSessionCacheLifecycle.updateAuthenticatedUser('active-user');
    await _cacheEventDetailForTest(
      eventId: 'event-1',
      userId: 'stale-user',
      title: 'Stale user detail',
    );
    final controller = StreamController<DocumentSnapshot>.broadcast(sync: true);

    await tester.pumpWidget(
      _buildDetailRouteTestApp(
        eventId: 'event-1',
        snapshotStream: (_) => controller.stream,
      ),
    );
    await tester.pump();

    expect(find.text('Stale user detail'), findsNothing);
    expect(find.byKey(eventDetailRouteLoadingKey), findsOneWidget);

    controller.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        data: _eventData(title: 'Active user detail'),
      ),
    );
    await tester.pump();
    expect(
      EventDetailRepository.cachedEventDetail(
        eventId: 'event-1',
        userId: 'active-user',
      )?.title,
      'Active user detail',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await controller.close();
  });

  testWidgets('confirmed missing replaces cached detail', (tester) async {
    await _cacheEventDetailForTest(
      eventId: 'event-1',
      userId: 'organizer-1',
      title: 'Cached before missing',
    );
    final controller = StreamController<DocumentSnapshot>.broadcast(sync: true);

    await tester.pumpWidget(
      _buildDetailRouteTestApp(
        eventId: 'event-1',
        snapshotStream: (_) => controller.stream,
      ),
    );
    await tester.pump();
    expect(find.text('Cached before missing'), findsOneWidget);

    controller.add(
      _FakeEventDocumentSnapshot(
        reference: EventsRecord.collection.doc('event-1'),
        exists: false,
      ),
    );
    await tester.pump();

    expect(find.text('Cached before missing'), findsNothing);
    expect(find.byKey(eventDetailRouteMissingKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await controller.close();
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

  testWidgets('enriches participant snapshot in one public profile batch',
      (tester) async {
    currentUser = _TestAuthUser('viewer-1');
    UxSessionCacheLifecycle.updateAuthenticatedUser('viewer-1');
    final participantsController =
        StreamController<List<EventParticipantsRecord>>.broadcast(sync: true);
    final profilesCompleter = Completer<UserPublicProfilePreloadResult>();
    final requestedUserIds = <List<String>>[];
    addTearDown(participantsController.close);

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
          participantSnapshotStream: (participantRef) =>
              Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: participantRef,
              data: _participantData(
                userId: 'viewer-1',
                status: 'left',
              ),
            ),
          ),
          participantsStream: (_) => participantsController.stream,
          publicProfilesLoader: (userIds) {
            requestedUserIds.add(userIds.toList(growable: false)..sort());
            return profilesCompleter.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    participantsController.add([
      EventParticipantsRecord.getDocumentFromData(
        _participantData(
          userId: 'organizer-1',
          status: 'active',
          displayName: 'Snapshot Organizer',
          photoUrl: 'https://example.test/snapshot-organizer.png',
          joinedAt: DateTime.utc(2026, 1, 1),
        ),
        EventParticipantsRecord.createDoc(
          EventsRecord.collection.doc('event-1'),
          id: 'organizer-1',
        ),
      ),
      EventParticipantsRecord.getDocumentFromData(
        _participantData(
          userId: 'student-2',
          status: 'active',
          displayName: 'Snapshot Student',
          photoUrl: 'https://example.test/snapshot-student.png',
          joinedAt: DateTime.utc(2026, 1, 2),
        ),
        EventParticipantsRecord.createDoc(
          EventsRecord.collection.doc('event-1'),
          id: 'student-2',
        ),
      ),
    ]);
    await tester.pump();
    await tester.pump();

    expect(requestedUserIds, [
      <String>['organizer-1', 'student-2']
    ]);
    expect(find.text('Snapshot Organizer'), findsOneWidget);
    expect(find.text('Snapshot Student'), findsOneWidget);
    expect(find.text('2/10 мест'), findsOneWidget);
    var organizerImage = tester.widget<CachedNetworkImage>(
      find.descendant(
        of: find.byKey(eventDetailParticipantTileKey(0)),
        matching: find.byType(CachedNetworkImage),
      ),
    );
    var studentImage = tester.widget<CachedNetworkImage>(
      find.descendant(
        of: find.byKey(eventDetailParticipantTileKey(1)),
        matching: find.byType(CachedNetworkImage),
      ),
    );
    expect(
      organizerImage.imageUrl,
      'https://example.test/snapshot-organizer.png',
    );
    expect(studentImage.imageUrl, 'https://example.test/snapshot-student.png');

    profilesCompleter.complete(
      UserPublicProfilePreloadResult(
        profilesByUserId: {
          'organizer-1': _userPublicProfile(
            userId: 'organizer-1',
            displayName: '',
            photoUrl: '',
          ),
          'student-2': _userPublicProfile(
            userId: 'student-2',
            displayName: 'Public Student',
            photoUrl: 'https://example.test/public-student.png',
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Snapshot Organizer'), findsOneWidget);
    expect(find.text('Snapshot Student'), findsNothing);
    expect(find.text('Public Student'), findsOneWidget);
    expect(find.text('2/10 мест'), findsOneWidget);
    organizerImage = tester.widget<CachedNetworkImage>(
      find.descendant(
        of: find.byKey(eventDetailParticipantTileKey(0)),
        matching: find.byType(CachedNetworkImage),
      ),
    );
    studentImage = tester.widget<CachedNetworkImage>(
      find.descendant(
        of: find.byKey(eventDetailParticipantTileKey(1)),
        matching: find.byType(CachedNetworkImage),
      ),
    );
    expect(
      organizerImage.imageUrl,
      'https://example.test/snapshot-organizer.png',
    );
    expect(studentImage.imageUrl, 'https://example.test/public-student.png');

    participantsController.add([
      EventParticipantsRecord.getDocumentFromData(
        _participantData(
          userId: 'organizer-1',
          status: 'active',
          displayName: 'Refreshed Organizer',
          joinedAt: DateTime.utc(2026, 1, 1),
        ),
        EventParticipantsRecord.createDoc(
          EventsRecord.collection.doc('event-1'),
          id: 'organizer-1',
        ),
      ),
      EventParticipantsRecord.getDocumentFromData(
        _participantData(
          userId: 'student-2',
          status: 'active',
          displayName: 'Refreshed Student',
          joinedAt: DateTime.utc(2026, 1, 2),
        ),
        EventParticipantsRecord.createDoc(
          EventsRecord.collection.doc('event-1'),
          id: 'student-2',
        ),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(requestedUserIds, hasLength(1));
    expect(find.text('Refreshed Organizer'), findsOneWidget);
    expect(find.text('Public Student'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(eventDetailParticipantTileKey(0)),
        matching: find.text('Refreshed Organizer'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(eventDetailParticipantTileKey(1)),
        matching: find.text('Public Student'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('public profile failure keeps participant snapshot usable',
      (tester) async {
    currentUser = _TestAuthUser('viewer-1');
    UxSessionCacheLifecycle.updateAuthenticatedUser('viewer-1');
    var profileCalls = 0;

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
          participantSnapshotStream: (participantRef) =>
              Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: participantRef,
              data: _participantData(
                userId: 'viewer-1',
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
                displayName: 'Snapshot Student',
              ),
              EventParticipantsRecord.createDoc(
                eventRef,
                id: 'student-2',
              ),
            ),
          ]),
          publicProfilesLoader: (_) {
            profileCalls += 1;
            throw StateError('profile lookup failed');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(profileCalls, 1);
    expect(find.text('Snapshot Student'), findsOneWidget);
    expect(find.text('2/10 мест'), findsOneWidget);
    expect(find.byKey(eventDetailRouteErrorKey), findsNothing);
    expect(find.text('Присоединиться'), findsOneWidget);
  });

  testWidgets('filters invalid profile ids and injected profile records',
      (tester) async {
    currentUser = _TestAuthUser('viewer-1');
    UxSessionCacheLifecycle.updateAuthenticatedUser('viewer-1');
    List<String>? requestedUserIds;

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData(participantsCount: 3),
            ),
          ),
          participantSnapshotStream: (participantRef) =>
              Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: participantRef,
              data: _participantData(
                userId: 'viewer-1',
                status: 'left',
              ),
            ),
          ),
          participantsStream: (eventRef) =>
              Stream<List<EventParticipantsRecord>>.value([
            EventParticipantsRecord.getDocumentFromData(
              _participantData(
                userId: 'bad/id',
                status: 'active',
                displayName: 'Snapshot Invalid Id',
              ),
              EventParticipantsRecord.createDoc(
                eventRef,
                id: 'invalid-record',
              ),
            ),
            EventParticipantsRecord.getDocumentFromData(
              _participantData(
                userId: 'student-2',
                status: 'active',
                displayName: 'Snapshot Mismatched Ref',
              ),
              EventParticipantsRecord.createDoc(
                eventRef,
                id: 'different-user',
              ),
            ),
          ]),
          publicProfilesLoader: (userIds) async {
            requestedUserIds = userIds.toList(growable: false)..sort();
            return UserPublicProfilePreloadResult(
              profilesByUserId: {
                'organizer-1': _userPublicProfile(
                  userId: 'organizer-1',
                  displayName: 'Wrong Collection Profile',
                  photoUrl: '',
                  reference: UsersRecord.collection.doc('organizer-1'),
                ),
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedUserIds, <String>['organizer-1']);
    expect(find.text('Wrong Collection Profile'), findsNothing);
    expect(find.text('Anastasia Ivanova'), findsWidgets);
    expect(find.text('Snapshot Invalid Id'), findsOneWidget);
    expect(find.text('Snapshot Mismatched Ref'), findsOneWidget);
  });

  testWidgets('profile enrichment ignores stale user and event completions',
      (tester) async {
    final firstUserCompleter = Completer<UserPublicProfilePreloadResult>();
    final secondUserCompleter = Completer<UserPublicProfilePreloadResult>();
    final secondEventCompleter = Completer<UserPublicProfilePreloadResult>();
    final completers = [
      firstUserCompleter,
      secondUserCompleter,
      secondEventCompleter,
    ];
    final requestedUserIds = <List<String>>[];

    Future<UserPublicProfilePreloadResult> publicProfilesLoader(
      Iterable<String> userIds,
    ) {
      requestedUserIds.add(userIds.toList(growable: false)..sort());
      return completers[requestedUserIds.length - 1].future;
    }

    Widget buildRoute(String eventId) => _buildTestApp(
          home: EventDetailRouteWidget(
            eventId: eventId,
            snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: eventRef,
                data: _eventData(
                  title: 'Title $eventId',
                  participantsCount: 2,
                ),
              ),
            ),
            participantSnapshotStream: (participantRef) =>
                Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: participantRef,
                data: _participantData(
                  userId: currentUser?.uid ?? '',
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
                  displayName: 'Snapshot $eventId',
                ),
                EventParticipantsRecord.createDoc(
                  eventRef,
                  id: 'student-2',
                ),
              ),
            ]),
            publicProfilesLoader: publicProfilesLoader,
          ),
        );

    currentUser = _TestAuthUser('viewer-a');
    UxSessionCacheLifecycle.updateAuthenticatedUser('viewer-a');
    await tester.pumpWidget(buildRoute('event-1'));
    await tester.pumpAndSettle();
    expect(requestedUserIds, hasLength(1));

    currentUser = _TestAuthUser('viewer-b');
    UxSessionCacheLifecycle.updateAuthenticatedUser('viewer-b');
    await tester.pumpWidget(buildRoute('event-1'));
    await tester.pumpAndSettle();
    expect(requestedUserIds, hasLength(2));

    firstUserCompleter.complete(
      UserPublicProfilePreloadResult(
        profilesByUserId: {
          'student-2': _userPublicProfile(
            userId: 'student-2',
            displayName: 'Stale User A',
            photoUrl: '',
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stale User A'), findsNothing);
    expect(find.text('Snapshot event-1'), findsOneWidget);

    await tester.pumpWidget(buildRoute('event-2'));
    await tester.pumpAndSettle();
    expect(requestedUserIds, hasLength(3));
    expect(find.text('Snapshot event-2'), findsOneWidget);

    secondEventCompleter.complete(
      UserPublicProfilePreloadResult(
        profilesByUserId: {
          'student-2': _userPublicProfile(
            userId: 'student-2',
            displayName: 'Current Event 2',
            photoUrl: '',
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current Event 2'), findsOneWidget);

    secondUserCompleter.complete(
      UserPublicProfilePreloadResult(
        profilesByUserId: {
          'student-2': _userPublicProfile(
            userId: 'student-2',
            displayName: 'Stale Event 1',
            photoUrl: '',
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current Event 2'), findsOneWidget);
    expect(find.text('Stale Event 1'), findsNothing);
    expect(
      requestedUserIds,
      everyElement(<String>['organizer-1', 'student-2']),
    );
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

  testWidgets('opens organizer private chat optimistically while callable runs',
      (tester) async {
    currentUser = _TestAuthUser('student-1');
    final openCompleter = Completer<Map<String, dynamic>>();
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
          openOrganizerChatInvoker: (_, __) => openCompleter.future,
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

    await tester.tap(find.byKey(eventDetailOrganizerMessageButtonKey));
    await tester.pump();

    expect(openedConversationPath, 'conversations/organizer-1_student-1');
    expect(find.byKey(eventDetailOrganizerMessageButtonKey), findsOneWidget);

    openCompleter.complete(<String, dynamic>{
      'conversationId': 'organizer-1_student-1',
      'conversationPath': 'conversations/organizer-1_student-1',
    });
    await tester.pumpAndSettle();
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

  testWidgets('join tap optimistically shows joined target until completion',
      (tester) async {
    currentUser = _TestAuthUser('student-1');
    UxSessionCacheLifecycle.updateAuthenticatedUser('student-1');
    currentUserDocument = UsersRecord.getDocumentFromData(
      {
        'display_name': 'Марко Росси',
        'photo_url': 'https://example.test/marco.jpg',
      },
      UsersRecord.collection.doc('student-1'),
    );
    final semanticsHandle = tester.ensureSemantics();
    final completer = Completer<Object?>();
    final profilesCompleter = Completer<UserPublicProfilePreloadResult>();
    final snapshotController = StreamController<DocumentSnapshot>();
    final participantsController =
        StreamController<List<EventParticipantsRecord>>.broadcast(sync: true);
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    var joinCalls = 0;
    String? functionName;
    Map<String, dynamic>? payload;
    final profileRequests = <List<String>>[];
    addTearDown(snapshotController.close);
    addTearDown(participantsController.close);

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventDetailRouteWidget(
            eventId: ' event-1 ',
            analyticsTracker: analyticsTracker,
            snapshotStream: (_) => snapshotController.stream,
            participantSnapshotStream: (participantRef) =>
                Stream<DocumentSnapshot>.value(
              _FakeEventDocumentSnapshot(
                reference: participantRef,
                exists: false,
              ),
            ),
            participantsStream: (_) => participantsController.stream,
            publicProfilesLoader: (userIds) {
              final requested = userIds.toList(growable: false)..sort();
              profileRequests.add(requested);
              if (requested.contains('student-1')) {
                return profilesCompleter.future;
              }
              return Future<UserPublicProfilePreloadResult>.value(
                UserPublicProfilePreloadResult(),
              );
            },
            joinEventInvoker: (calledFunctionName, calledPayload) {
              joinCalls += 1;
              functionName = calledFunctionName;
              payload = calledPayload;
              return completer.future;
            },
          ),
        ),
      );
      await tester.pump();
      snapshotController.add(
        _FakeEventDocumentSnapshot(
          reference: EventsRecord.collection.doc('event-1'),
          data: _eventData(participantsCount: 5),
        ),
      );
      await tester.pump();
      participantsController.add([
        EventParticipantsRecord.getDocumentFromData(
          _participantData(
            userId: 'organizer-1',
            status: 'active',
            displayName: 'Anastasia Ivanova',
          ),
          EventParticipantsRecord.createDoc(
            EventsRecord.collection.doc('event-1'),
            id: 'organizer-1',
          ),
        ),
      ]);
      await tester.pump();

      expect(find.text('Присоединиться'), findsOneWidget);
      expect(find.text('5/10 мест'), findsOneWidget);
      expect(find.text('Марко Росси'), findsNothing);

      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pump();

      expect(joinCalls, 1);
      expect(functionName, joinEventFunctionName);
      expect(payload, <String, dynamic>{'eventId': 'event-1'});
      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('6/10 мест'), findsOneWidget);
      expect(find.text('5/10 мест'), findsNothing);
      expect(find.text('Марко Росси'), findsOneWidget);
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
      expect(find.byKey(eventDetailChatCtaKey), findsNothing);
      expect(profileRequests, [
        <String>['organizer-1'],
        <String>['organizer-1', 'student-1'],
      ]);
      expect(
        analyticsTracker.payloadsFor(
          EventsAnalyticsService.eventJoinedEventName,
        ),
        isEmpty,
      );
      var primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isEnabled, isFalse);
      expect(primarySemantics.label, 'Присоединяемся к событию');

      profilesCompleter.complete(
        UserPublicProfilePreloadResult(
          profilesByUserId: {
            'student-1': _userPublicProfile(
              userId: 'student-1',
              displayName: 'Марко Росси',
              photoUrl: 'https://example.test/public-marco.png',
            ),
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      final optimisticParticipantImage = tester.widget<CachedNetworkImage>(
        find.descendant(
          of: find.byKey(eventDetailParticipantTileKey(1)),
          matching: find.byType(CachedNetworkImage),
        ),
      );
      expect(
        optimisticParticipantImage.imageUrl,
        'https://example.test/public-marco.png',
      );
      expect(find.text('6/10 мест'), findsOneWidget);
      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.byKey(eventDetailChatCtaKey), findsNothing);

      snapshotController.add(
        _FakeEventDocumentSnapshot(
          reference: EventsRecord.collection.doc('event-1'),
          data: _eventData(
            title: 'Updated conversation club',
            participantsCount: 6,
          ),
        ),
      );
      participantsController.add([
        EventParticipantsRecord.getDocumentFromData(
          _participantData(
            userId: 'organizer-1',
            status: 'active',
            displayName: 'Anastasia Ivanova',
          ),
          EventParticipantsRecord.createDoc(
            EventsRecord.collection.doc('event-1'),
            id: 'organizer-1',
          ),
        ),
        EventParticipantsRecord.getDocumentFromData(
          _participantData(
            userId: 'student-1',
            status: 'active',
            displayName: 'Марко Росси',
          ),
          EventParticipantsRecord.createDoc(
            EventsRecord.collection.doc('event-1'),
            id: 'student-1',
          ),
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Updated conversation club'), findsOneWidget);
      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('6/10 мест'), findsOneWidget);
      expect(find.text('Марко Росси'), findsOneWidget);

      completer.complete(_joinEventResponse());
      await tester.pumpAndSettle();

      expect(joinCalls, 1);
      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('6/10 мест'), findsOneWidget);
      expect(find.text('Марко Росси'), findsOneWidget);
      expect(find.byKey(eventDetailChatCtaKey), findsOneWidget);
      primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isEnabled, isTrue);
      expect(
        analyticsTracker.payloadsFor(
          EventsAnalyticsService.eventJoinedEventName,
        ),
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

  testWidgets('pending join derives missing count from visible participants',
      (tester) async {
    currentUser = _TestAuthUser('student-1');
    UxSessionCacheLifecycle.updateAuthenticatedUser('student-1');
    currentUserDocument = UsersRecord.getDocumentFromData(
      {'display_name': 'Марко Росси'},
      UsersRecord.collection.doc('student-1'),
    );
    final joinCompleter = Completer<Object?>();

    await tester.pumpWidget(
      _buildTestApp(
        home: EventDetailRouteWidget(
          eventId: 'event-1',
          snapshotStream: (eventRef) => Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventRef,
              data: _eventData()..remove('participantsCount'),
            ),
          ),
          participantSnapshotStream: (participantRef) =>
              Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: participantRef,
              exists: false,
            ),
          ),
          participantsStream: (eventRef) =>
              Stream<List<EventParticipantsRecord>>.value([
            EventParticipantsRecord.getDocumentFromData(
              _participantData(
                userId: 'organizer-1',
                status: 'active',
                displayName: 'Anastasia Ivanova',
              ),
              EventParticipantsRecord.createDoc(
                eventRef,
                id: 'organizer-1',
              ),
            ),
            EventParticipantsRecord.getDocumentFromData(
              _participantData(
                userId: 'student-2',
                status: 'active',
                displayName: 'Лена',
              ),
              EventParticipantsRecord.createDoc(
                eventRef,
                id: 'student-2',
              ),
            ),
          ]),
          joinEventInvoker: (_, __) => joinCompleter.future,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2/10 мест'), findsOneWidget);

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pump();

    expect(find.text('3/10 мест'), findsOneWidget);
    expect(find.text('2/10 мест'), findsNothing);
    expect(find.text('Марко Росси'), findsOneWidget);

    joinCompleter.complete(_joinEventResponse(participantsCount: 3));
    await tester.pumpAndSettle();

    expect(find.text('3/10 мест'), findsOneWidget);
    expect(find.text('Марко Росси'), findsOneWidget);
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
    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

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
    currentUser = _TestAuthUser('uid-1');
    UxSessionCacheLifecycle.updateAuthenticatedUser('uid-1');
    final semanticsHandle = tester.ensureSemantics();
    final leaveCompleter = Completer<Object?>();
    final eventController =
        StreamController<DocumentSnapshot>.broadcast(sync: true);
    final participantController =
        StreamController<DocumentSnapshot>.broadcast(sync: true);
    final participantsController =
        StreamController<List<EventParticipantsRecord>>.broadcast(sync: true);
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    var leaveCalls = 0;
    addTearDown(eventController.close);
    addTearDown(participantController.close);
    addTearDown(participantsController.close);

    try {
      await tester.pumpWidget(
        _buildTestApp(
          home: EventDetailRouteWidget(
            eventId: 'event-1',
            analyticsTracker: analyticsTracker,
            snapshotStream: (_) => eventController.stream,
            participantSnapshotStream: (_) => participantController.stream,
            participantsStream: (_) => participantsController.stream,
            leaveEventInvoker: (_, __) {
              leaveCalls += 1;
              return leaveCompleter.future;
            },
          ),
        ),
      );
      await tester.pump();
      eventController.add(
        _FakeEventDocumentSnapshot(
          reference: EventsRecord.collection.doc('event-1'),
          data: _eventData(participantsCount: 5),
        ),
      );
      await tester.pump();
      participantController.add(
        _FakeEventDocumentSnapshot(
          reference: EventParticipantsRecord.createDoc(
            EventsRecord.collection.doc('event-1'),
            id: 'uid-1',
          ),
          data: _participantData(
            userId: 'uid-1',
            status: 'active',
            displayName: 'Нина',
          ),
        ),
      );
      participantsController.add([
        EventParticipantsRecord.getDocumentFromData(
          _participantData(
            userId: 'organizer-1',
            status: 'active',
            displayName: 'Anastasia Ivanova',
          ),
          EventParticipantsRecord.createDoc(
            EventsRecord.collection.doc('event-1'),
            id: 'organizer-1',
          ),
        ),
        EventParticipantsRecord.getDocumentFromData(
          _participantData(
            userId: 'uid-1',
            status: 'active',
            displayName: 'Нина',
          ),
          EventParticipantsRecord.createDoc(
            EventsRecord.collection.doc('event-1'),
            id: 'uid-1',
          ),
        ),
      ]);
      await tester.pump();

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('5/10 мест'), findsOneWidget);
      expect(find.text('Нина'), findsOneWidget);
      expect(find.byKey(eventDetailChatCtaKey), findsOneWidget);

      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventDetailLeaveDialogConfirmButtonKey));
      await tester.pump();
      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pump();

      expect(leaveCalls, 1);
      expect(find.text('Присоединиться'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('4/10 мест'), findsOneWidget);
      expect(find.text('5/10 мест'), findsNothing);
      expect(find.text('Нина'), findsNothing);
      expect(find.byKey(eventDetailChatCtaKey), findsOneWidget);
      expect(
        analyticsTracker.payloadsFor(
          EventsAnalyticsService.eventLeftEventName,
        ),
        isEmpty,
      );

      final primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isEnabled, isFalse);
      expect(primarySemantics.label, 'Покидаем событие');

      eventController.add(
        _FakeEventDocumentSnapshot(
          reference: EventsRecord.collection.doc('event-1'),
          data: _eventData(participantsCount: 4),
        ),
      );
      participantController.add(
        _FakeEventDocumentSnapshot(
          reference: EventParticipantsRecord.createDoc(
            EventsRecord.collection.doc('event-1'),
            id: 'uid-1',
          ),
          data: _participantData(
            userId: 'uid-1',
            status: 'left',
            displayName: 'Нина',
          ),
        ),
      );
      participantsController.add([
        EventParticipantsRecord.getDocumentFromData(
          _participantData(
            userId: 'organizer-1',
            status: 'active',
            displayName: 'Anastasia Ivanova',
          ),
          EventParticipantsRecord.createDoc(
            EventsRecord.collection.doc('event-1'),
            id: 'organizer-1',
          ),
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('4/10 мест'), findsOneWidget);
      expect(find.text('3/10 мест'), findsNothing);
      expect(find.text('Нина'), findsNothing);

      leaveCompleter.complete(_leaveEventResponse(participantsCount: 4));
      await tester.pumpAndSettle();

      expect(leaveCalls, 1);
      expect(find.text('Присоединиться'), findsOneWidget);
      expect(find.text('4/10 мест'), findsOneWidget);
      expect(find.text('Нина'), findsNothing);
      expect(find.byKey(eventDetailChatCtaKey), findsNothing);
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

  testWidgets('leave failure rolls back optimistic membership state',
      (tester) async {
    currentUser = _TestAuthUser('student-1');
    UxSessionCacheLifecycle.updateAuthenticatedUser('student-1');
    currentUserDocument = UsersRecord.getDocumentFromData(
      {'display_name': 'Марко Росси'},
      UsersRecord.collection.doc('student-1'),
    );
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

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('6/10 мест'), findsOneWidget);
      expect(find.text('Марко Росси'), findsOneWidget);
      expect(find.byKey(eventDetailChatCtaKey), findsOneWidget);

      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(eventDetailLeaveDialogConfirmButtonKey));
      await tester.pump();

      expect(leaveCalls, 1);
      expect(find.text('Присоединиться'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('5/10 мест'), findsOneWidget);
      expect(find.text('6/10 мест'), findsNothing);
      expect(find.text('Марко Росси'), findsNothing);
      expect(find.byKey(eventDetailChatCtaKey), findsOneWidget);
      expect(find.byKey(eventDetailLeaveErrorSnackBarKey), findsNothing);
      var primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isEnabled, isFalse);
      expect(primarySemantics.label, 'Покидаем событие');
      expect(
        analyticsTracker.payloadsFor(
          EventsAnalyticsService.eventLeftEventName,
        ),
        isEmpty,
      );

      leaveCompleter.completeError(StateError('leave failed'));
      await tester.pumpAndSettle();

      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.text('Присоединиться'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('6/10 мест'), findsOneWidget);
      expect(find.text('Марко Росси'), findsOneWidget);
      expect(find.byKey(eventDetailChatCtaKey), findsOneWidget);
      expect(find.byKey(eventDetailLeaveErrorSnackBarKey), findsOneWidget);
      primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isEnabled, isTrue);
      expect(
        analyticsTracker.payloadsFor(
          EventsAnalyticsService.eventLeftEventName,
        ),
        isEmpty,
      );
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('mismatched leave response rolls back without analytics',
      (tester) async {
    final leaveCompleter = Completer<Object?>();
    final analyticsTracker = _RecordingEventsAnalyticsTracker();

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
          leaveEventInvoker: (_, __) => leaveCompleter.future,
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

    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    leaveCompleter.complete(_leaveEventResponse(eventId: 'event-2'));
    await tester.pumpAndSettle();

    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.text('Присоединиться'), findsNothing);
    expect(find.text('6/10 мест'), findsOneWidget);
    expect(find.byKey(eventDetailLeaveErrorSnackBarKey), findsOneWidget);
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

  testWidgets('join failure rolls back optimistic membership state',
      (tester) async {
    currentUser = _TestAuthUser('student-1');
    UxSessionCacheLifecycle.updateAuthenticatedUser('student-1');
    currentUserDocument = UsersRecord.getDocumentFromData(
      {'display_name': 'Марко Росси'},
      UsersRecord.collection.doc('student-1'),
    );
    final semanticsHandle = tester.ensureSemantics();
    final joinCompleter = Completer<Object?>();
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    var joinCalls = 0;

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
            joinEventInvoker: (_, __) {
              joinCalls += 1;
              return joinCompleter.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
      await tester.pump();

      expect(joinCalls, 1);
      expect(find.text('Покинуть'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('6/10 мест'), findsOneWidget);
      expect(find.text('5/10 мест'), findsNothing);
      expect(find.text('Марко Росси'), findsOneWidget);
      expect(find.byKey(eventDetailChatCtaKey), findsNothing);
      expect(find.byKey(eventDetailJoinErrorSnackBarKey), findsNothing);
      var primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isEnabled, isFalse);
      expect(primarySemantics.label, 'Присоединяемся к событию');
      expect(
        analyticsTracker.payloadsFor(
          EventsAnalyticsService.eventJoinedEventName,
        ),
        isEmpty,
      );

      joinCompleter.completeError(StateError('join failed'));
      await tester.pumpAndSettle();

      expect(find.text('Присоединиться'), findsOneWidget);
      expect(find.text('Покинуть'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('5/10 мест'), findsOneWidget);
      expect(find.text('Марко Росси'), findsNothing);
      expect(find.byKey(eventDetailChatCtaKey), findsNothing);
      expect(find.byKey(eventDetailJoinErrorSnackBarKey), findsOneWidget);
      primarySemantics =
          tester.getSemantics(find.byKey(eventDetailPrimaryCtaKey));
      expect(primarySemantics.flagsCollection.isEnabled, isTrue);
      expect(
        analyticsTracker.payloadsFor(
          EventsAnalyticsService.eventJoinedEventName,
        ),
        isEmpty,
      );
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('mismatched join response rolls back without analytics',
      (tester) async {
    final joinCompleter = Completer<Object?>();
    final analyticsTracker = _RecordingEventsAnalyticsTracker();

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
          joinEventInvoker: (_, __) => joinCompleter.future,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pump();

    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    joinCompleter.complete(_joinEventResponse(eventId: 'event-2'));
    await tester.pumpAndSettle();

    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('Покинуть'), findsNothing);
    expect(find.text('5/10 мест'), findsOneWidget);
    expect(find.byKey(eventDetailJoinErrorSnackBarKey), findsOneWidget);
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

    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

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
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pump();

    expect(joinedEventIds, <String>['event-1', 'event-2']);
    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    firstJoinCompleter.complete(
      _joinEventResponse(
        eventId: 'event-1',
        participantsCount: 9,
      ),
    );
    await tester.pump();

    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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

  testWidgets('user change clears pending join and ignores stale completion',
      (tester) async {
    final joinCompleter = Completer<Object?>();
    final analyticsTracker = _RecordingEventsAnalyticsTracker();
    var joinCalls = 0;

    Stream<DocumentSnapshot> detailStream(DocumentReference eventRef) =>
        Stream<DocumentSnapshot>.value(
          _FakeEventDocumentSnapshot(
            reference: eventRef,
            data: _eventData(),
          ),
        );
    Stream<DocumentSnapshot> participantStream(
      DocumentReference participantRef,
    ) =>
        Stream<DocumentSnapshot>.value(
          _FakeEventDocumentSnapshot(
            reference: participantRef,
            exists: false,
          ),
        );
    Stream<List<EventParticipantsRecord>> participantsStream(
      DocumentReference _,
    ) =>
        Stream<List<EventParticipantsRecord>>.value(
          const <EventParticipantsRecord>[],
        );
    Future<Object?> joinInvoker(String _, Map<String, dynamic> __) {
      joinCalls += 1;
      return joinCompleter.future;
    }

    Widget buildRoute() => _buildTestApp(
          home: EventDetailRouteWidget(
            eventId: 'event-1',
            analyticsTracker: analyticsTracker,
            snapshotStream: detailStream,
            participantSnapshotStream: participantStream,
            participantsStream: participantsStream,
            joinEventInvoker: joinInvoker,
          ),
        );

    currentUser = _TestAuthUser('user-a');
    UxSessionCacheLifecycle.updateAuthenticatedUser('user-a');
    await tester.pumpWidget(buildRoute());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventDetailPrimaryCtaKey));
    await tester.pump();

    expect(joinCalls, 1);
    expect(find.text('Покинуть'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    currentUser = _TestAuthUser('user-b');
    UxSessionCacheLifecycle.updateAuthenticatedUser('user-b');
    await tester.pumpWidget(buildRoute());
    await tester.pumpAndSettle();

    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('Покинуть'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    joinCompleter.complete(
      _joinEventResponse(
        eventId: 'event-1',
        participantsCount: 9,
      ),
    );
    await tester.pumpAndSettle();

    expect(joinCalls, 1);
    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('Покинуть'), findsNothing);
    expect(find.text('5/10 мест'), findsOneWidget);
    expect(find.text('9/10 мест'), findsNothing);
    expect(
      analyticsTracker.payloadsFor(EventsAnalyticsService.eventJoinedEventName),
      isEmpty,
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

UserPublicProfilesRecord _userPublicProfile({
  required String userId,
  required String displayName,
  required String photoUrl,
  DocumentReference? reference,
}) =>
    UserPublicProfilesRecord.getDocumentFromData(
      {
        'userId': userId,
        'display_name': displayName,
        'photo_url': photoUrl,
      },
      reference ?? UserPublicProfilesRecord.collection.doc(userId),
    );

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
