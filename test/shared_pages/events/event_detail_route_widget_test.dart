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
  String status = 'active',
  String organizerId = 'organizer-1',
}) =>
    <String, dynamic>{
      'title': 'Conversation club',
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
      'participantsCount': 5,
      'organizerId': organizerId,
      'organizerDisplayName': 'Anastasia Ivanova',
      'status': status,
    };

Map<String, dynamic> _cancelEventResponse() => <String, dynamic>{
      'eventId': 'event-1',
      'status': 'canceled',
      'canceledAt': '2026-06-14T12:00:00.000Z',
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
