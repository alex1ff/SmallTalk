import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/components/basic_page_header.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/services/reviews_load_result.dart';
import 'package:small_talk/students_pages/my_rew/my_rew_widget.dart';
import 'package:small_talk/teachers_pages/my_rew_n_s/my_rew_n_s_widget.dart';

const _supportedLocales = <Locale>[Locale('ru'), Locale('en')];

const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  FFLocalizationsDelegate(),
  FallbackMaterialLocalizationDelegate(),
  FallbackCupertinoLocalizationDelegate(),
];

class _TestFirebaseAuthPlatform extends FirebaseAuthPlatform {
  _TestFirebaseAuthPlatform({FirebaseApp? app}) : super(appInstance: app);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) =>
      _TestFirebaseAuthPlatform(app: app);

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) {
    this.languageCode = languageCode;
    return this;
  }

  @override
  UserPlatform? get currentUser => null;

  @override
  set currentUser(UserPlatform? userPlatform) {}

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

final class _FutureCall {
  _FutureCall(this.ownerUid) : completer = Completer<List<ReviewsRecord>>();

  final String ownerUid;
  final Completer<List<ReviewsRecord>> completer;
}

final class _FutureQueue {
  final calls = <_FutureCall>[];

  Future<List<ReviewsRecord>> load(String ownerUid) {
    final call = _FutureCall(ownerUid);
    calls.add(call);
    return call.completer.future;
  }
}

final class _ResultStreamCall {
  _ResultStreamCall(this.ownerUid) {
    controller = StreamController<ReviewsLoadResult>(
      sync: true,
      onCancel: () => cancelCount += 1,
    );
  }

  final String ownerUid;
  late final StreamController<ReviewsLoadResult> controller;
  int cancelCount = 0;
}

final class _ResultStreamQueue {
  final calls = <_ResultStreamCall>[];

  Stream<ReviewsLoadResult> load(String ownerUid) {
    final call = _ResultStreamCall(ownerUid);
    calls.add(call);
    return call.controller.stream;
  }

  Future<void> close() async {
    for (final call in calls) {
      if (!call.controller.isClosed) {
        await call.controller.close();
      }
    }
  }
}

Widget _testApp(Widget home) => MaterialApp(
      locale: const Locale('ru'),
      supportedLocales: _supportedLocales,
      localizationsDelegates: _localizationsDelegates,
      home: home,
    );

ReviewsRecord _review(String id, {int rating = 5}) =>
    ReviewsRecord.getDocumentFromData(
      <String, dynamic>{
        'rating': rating,
        'comment': 'review-$id',
      },
      ReviewsRecord.collection.doc(id),
    );

UsersRecord _teacher(
  String uid, {
  TeacherAccreditationStatus status = TeacherAccreditationStatus.approved,
}) =>
    UsersRecord.getDocumentFromData(
      <String, dynamic>{
        'uid': uid,
        'role': UserRole.native_speaker,
        'teacherAccreditationStatus': status,
        'verif_NS': status == TeacherAccreditationStatus.approved,
        'rating': <String, dynamic>{
          'average': 4.8,
          'totalReviews': 12,
        },
      },
      UsersRecord.collection.doc(uid),
    );

ReviewsLoadResult _authoritative(List<ReviewsRecord> reviews) =>
    ReviewsLoadResult.authoritative(reviews);

ReviewsLoadResult _unconfirmed(
  List<ReviewsRecord> reviews, {
  bool pendingWrites = false,
}) =>
    ReviewsLoadResult(
      reviews: reviews,
      isFromCache: !pendingWrites,
      hasPendingWrites: pendingWrites,
    );

Future<void> _pumpAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void _invokeRetry(WidgetTester tester, Key retryKey) {
  final semantics = tester.widget<Semantics>(find.byKey(retryKey));
  semantics.properties.onTap!();
}

Finder _verticalScrollable() => find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _TestFirebaseAuthPlatform();
    await FFLocalizations.initialize();
  });

  setUp(() {
    currentUser = null;
    currentUserDocument = null;
    MyRewModel.debugClearSessionCache();
    MyRewNSModel.debugClearSessionCache();
  });

  tearDown(() {
    currentUser = null;
    currentUserDocument = null;
  });

  testWidgets(
      'student keeps cached empty through error and retry until success',
      (tester) async {
    final queue = _FutureQueue();
    Widget page() => MyRewWidget(
          ownerUidProvider: () => 'owner-a',
          reviewsLoader: queue.load,
        );

    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    queue.calls.single.completer.complete(const <ReviewsRecord>[]);
    await _pumpAsync(tester);
    expect(find.byKey(myRewEmptyKey), findsOneWidget);

    await tester.pumpWidget(_testApp(const SizedBox.shrink()));
    await tester.pump();
    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    expect(queue.calls, hasLength(2));
    expect(find.byKey(myRewEmptyKey), findsOneWidget);
    expect(find.byKey(myRewRefreshingIndicatorKey), findsOneWidget);

    queue.calls[1].completer.completeError(StateError('offline'));
    await _pumpAsync(tester);
    expect(find.byKey(myRewRefreshErrorKey), findsOneWidget);
    expect(find.byKey(myRewEmptyKey), findsOneWidget);

    _invokeRetry(tester, myRewRetryButtonKey);
    await tester.pump();
    expect(queue.calls, hasLength(3));
    expect(find.byKey(myRewRefreshErrorKey), findsNothing);
    expect(find.byKey(myRewEmptyKey), findsOneWidget);
    expect(find.byKey(myRewRefreshingIndicatorKey), findsOneWidget);

    final recovered = _review('student-recovered');
    queue.calls[2].completer.complete(<ReviewsRecord>[recovered]);
    await _pumpAsync(tester);
    expect(find.byKey(myRewReviewKey(recovered)), findsOneWidget);
    expect(find.byKey(myRewRefreshingIndicatorKey), findsNothing);
  });

  testWidgets(
      'teacher keeps cached empty through error and retry until success',
      (tester) async {
    const ownerUid = 'owner-a';
    currentUserDocument = _teacher(ownerUid);
    final queue = _FutureQueue();
    Widget page() => MyRewNSWidget(
          ownerUidProvider: () => ownerUid,
          reviewsLoader: queue.load,
        );

    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    queue.calls.single.completer.complete(const <ReviewsRecord>[]);
    await _pumpAsync(tester);
    expect(find.byKey(myRewNSEmptyKey), findsOneWidget);

    await tester.pumpWidget(_testApp(const SizedBox.shrink()));
    await tester.pump();
    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    expect(queue.calls, hasLength(2));
    expect(find.byKey(myRewNSEmptyKey), findsOneWidget);
    expect(find.byKey(myRewNSRefreshingIndicatorKey), findsOneWidget);

    queue.calls[1].completer.completeError(StateError('offline'));
    await _pumpAsync(tester);
    expect(find.byKey(myRewNSRefreshErrorKey), findsOneWidget);
    expect(find.byKey(myRewNSEmptyKey), findsOneWidget);

    _invokeRetry(tester, myRewNSRetryButtonKey);
    await tester.pump();
    expect(queue.calls, hasLength(3));
    expect(find.byKey(myRewNSEmptyKey), findsOneWidget);
    expect(find.byKey(myRewNSRefreshingIndicatorKey), findsOneWidget);

    final recovered = _review('teacher-recovered');
    queue.calls[2].completer.complete(<ReviewsRecord>[recovered]);
    await _pumpAsync(tester);
    expect(find.byKey(myRewNSReviewKey(recovered)), findsOneWidget);
    expect(find.byKey(myRewNSRefreshingIndicatorKey), findsNothing);
  });

  testWidgets('student merges unconfirmed snapshots but only confirms server',
      (tester) async {
    final queue = _ResultStreamQueue();
    addTearDown(queue.close);
    final baseline = _review('baseline', rating: 5);
    final pending = _review('pending', rating: 4);
    Widget page() => MyRewWidget(
          ownerUidProvider: () => 'owner-a',
          reviewsResultStreamLoader: queue.load,
        );

    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    queue.calls.single.controller
        .add(_authoritative(<ReviewsRecord>[baseline]));
    await _pumpAsync(tester);

    await tester.pumpWidget(_testApp(const SizedBox.shrink()));
    await tester.pump();
    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    final refresh = queue.calls[1].controller;
    refresh.add(_unconfirmed(const <ReviewsRecord>[]));
    await _pumpAsync(tester);
    expect(find.byKey(myRewReviewKey(baseline)), findsOneWidget);
    expect(find.byKey(myRewEmptyKey), findsNothing);
    expect(find.byKey(myRewRefreshingIndicatorKey), findsOneWidget);

    refresh.add(_unconfirmed(<ReviewsRecord>[pending], pendingWrites: true));
    await _pumpAsync(tester);
    expect(find.byKey(myRewReviewKey(pending)), findsOneWidget);
    expect(find.byKey(myRewReviewKey(baseline)), findsOneWidget);
    expect(find.byKey(myRewRefreshingIndicatorKey), findsOneWidget);

    refresh.add(_authoritative(const <ReviewsRecord>[]));
    await _pumpAsync(tester);
    expect(find.byKey(myRewEmptyKey), findsOneWidget);
    expect(find.byKey(myRewReviewKey(pending)), findsNothing);
    expect(find.byKey(myRewReviewKey(baseline)), findsNothing);
    expect(find.byKey(myRewRefreshingIndicatorKey), findsNothing);
    expect(queue.calls[1].cancelCount, 1);
  });

  testWidgets('teacher merges unconfirmed snapshots but only confirms server',
      (tester) async {
    const ownerUid = 'owner-a';
    currentUserDocument = _teacher(ownerUid);
    final queue = _ResultStreamQueue();
    addTearDown(queue.close);
    final baseline = _review('baseline', rating: 5);
    final pending = _review('pending', rating: 4);
    Widget page() => MyRewNSWidget(
          ownerUidProvider: () => ownerUid,
          reviewsResultStreamLoader: queue.load,
        );

    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    queue.calls.single.controller
        .add(_authoritative(<ReviewsRecord>[baseline]));
    await _pumpAsync(tester);

    await tester.pumpWidget(_testApp(const SizedBox.shrink()));
    await tester.pump();
    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    final refresh = queue.calls[1].controller;
    refresh.add(_unconfirmed(const <ReviewsRecord>[]));
    await _pumpAsync(tester);
    expect(find.byKey(myRewNSReviewKey(baseline)), findsOneWidget);
    expect(find.byKey(myRewNSEmptyKey), findsNothing);
    expect(find.byKey(myRewNSRefreshingIndicatorKey), findsOneWidget);

    refresh.add(_unconfirmed(<ReviewsRecord>[pending], pendingWrites: true));
    await _pumpAsync(tester);
    expect(find.byKey(myRewNSReviewKey(pending)), findsOneWidget);
    expect(find.byKey(myRewNSReviewKey(baseline)), findsOneWidget);
    expect(find.byKey(myRewNSRefreshingIndicatorKey), findsOneWidget);

    refresh.add(_authoritative(const <ReviewsRecord>[]));
    await _pumpAsync(tester);
    expect(find.byKey(myRewNSEmptyKey), findsOneWidget);
    expect(find.byKey(myRewNSReviewKey(pending)), findsNothing);
    expect(find.byKey(myRewNSReviewKey(baseline)), findsNothing);
    expect(find.byKey(myRewNSRefreshingIndicatorKey), findsNothing);
    expect(queue.calls[1].cancelCount, 1);
  });

  testWidgets('student incomplete metadata stream becomes retryable error',
      (tester) async {
    final queue = _ResultStreamQueue();
    addTearDown(queue.close);

    await tester.pumpWidget(
      _testApp(
        MyRewWidget(
          ownerUidProvider: () => 'owner-a',
          reviewsResultStreamLoader: queue.load,
        ),
      ),
    );
    await _pumpAsync(tester);
    queue.calls.single.controller.add(
      _unconfirmed(const <ReviewsRecord>[]),
    );
    await _pumpAsync(tester);
    expect(find.byKey(myRewLoadingKey), findsOneWidget);

    unawaited(queue.calls.single.controller.close());
    await _pumpAsync(tester);
    expect(find.byKey(myRewErrorKey), findsOneWidget);
    expect(find.byKey(myRewEmptyKey), findsNothing);
  });

  testWidgets('teacher incomplete metadata stream becomes retryable error',
      (tester) async {
    const ownerUid = 'owner-a';
    currentUserDocument = _teacher(ownerUid);
    final queue = _ResultStreamQueue();
    addTearDown(queue.close);

    await tester.pumpWidget(
      _testApp(
        MyRewNSWidget(
          ownerUidProvider: () => ownerUid,
          reviewsResultStreamLoader: queue.load,
        ),
      ),
    );
    await _pumpAsync(tester);
    queue.calls.single.controller.add(
      _unconfirmed(const <ReviewsRecord>[]),
    );
    await _pumpAsync(tester);
    expect(find.byKey(myRewNSLoadingKey), findsOneWidget);

    unawaited(queue.calls.single.controller.close());
    await _pumpAsync(tester);
    expect(find.byKey(myRewNSErrorKey), findsOneWidget);
    expect(find.byKey(myRewNSEmptyKey), findsNothing);
  });

  testWidgets('student raw A-B-A without a frame clears A1 cache',
      (tester) async {
    final auth = StreamController<String>(sync: true);
    final queue = _ResultStreamQueue();
    addTearDown(auth.close);
    addTearDown(queue.close);
    var directUid = 'owner-a';
    final stale = _review('student-a1');
    final current = _review('student-a2', rating: 4);

    await tester.pumpWidget(
      _testApp(
        MyRewWidget(
          authUidStream: auth.stream,
          ownerUidProvider: () => directUid,
          reviewsResultStreamLoader: queue.load,
        ),
      ),
    );
    auth.add('owner-a');
    await _pumpAsync(tester);
    queue.calls.single.controller.add(_authoritative(<ReviewsRecord>[stale]));
    await _pumpAsync(tester);
    expect(find.byKey(myRewReviewKey(stale)), findsOneWidget);
    await tester.tap(
      find
          .ancestor(
            of: find.text('5').first,
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pump();

    auth.add('owner-b');
    auth.add('owner-a');
    await tester.pump();
    expect(queue.calls, hasLength(2));
    expect(queue.calls.last.ownerUid, 'owner-a');
    expect(find.byKey(myRewReviewKey(stale)), findsNothing);
    expect(find.byKey(myRewLoadingKey), findsOneWidget);

    queue.calls.last.controller.add(_authoritative(<ReviewsRecord>[current]));
    await _pumpAsync(tester);
    expect(find.byKey(myRewReviewKey(current)), findsOneWidget);
  });

  testWidgets('teacher raw A-B-A without a frame revokes A1 access and cache',
      (tester) async {
    final auth = StreamController<String>(sync: true);
    final queue = _ResultStreamQueue();
    addTearDown(auth.close);
    addTearDown(queue.close);
    var directUid = 'owner-a';
    currentUserDocument = _teacher(directUid);
    final stale = _review('teacher-a1');
    final current = _review('teacher-a2', rating: 4);

    await tester.pumpWidget(
      _testApp(
        MyRewNSWidget(
          authUidStream: auth.stream,
          ownerUidProvider: () => directUid,
          reviewsResultStreamLoader: queue.load,
        ),
      ),
    );
    auth.add('owner-a');
    await _pumpAsync(tester);
    queue.calls.single.controller.add(_authoritative(<ReviewsRecord>[stale]));
    await _pumpAsync(tester);
    expect(find.byKey(myRewNSReviewKey(stale)), findsOneWidget);
    await tester.tap(
      find
          .ancestor(
            of: find.text('5').last,
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pump();

    auth.add('owner-b');
    auth.add('owner-a');
    await tester.pump();
    expect(queue.calls, hasLength(2));
    expect(queue.calls.last.ownerUid, 'owner-a');
    expect(find.byKey(myRewNSReviewKey(stale)), findsNothing);
    expect(find.byKey(myRewNSLoadingKey), findsOneWidget);

    queue.calls.last.controller.add(_authoritative(<ReviewsRecord>[current]));
    await _pumpAsync(tester);
    expect(find.byKey(myRewNSReviewKey(current)), findsOneWidget);
  });

  testWidgets('teacher denial survives null reconnect and invalidates request',
      (tester) async {
    const ownerUid = 'owner-a';
    final queue = _FutureQueue();
    var redirects = 0;
    currentUserDocument = _teacher(ownerUid);
    Widget page() => MyRewNSWidget(
          ownerUidProvider: () => ownerUid,
          reviewsLoader: queue.load,
          accessDeniedHandler: (_) => redirects += 1,
        );

    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    final retained = _review('must-be-revoked');
    queue.calls.single.completer.complete(<ReviewsRecord>[retained]);
    await _pumpAsync(tester);
    expect(find.byKey(myRewNSReviewKey(retained)), findsOneWidget);

    currentUserDocument = _teacher(
      ownerUid,
      status: TeacherAccreditationStatus.rejected,
    );
    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    expect(redirects, 1);
    expect(find.byKey(myRewNSReviewKey(retained)), findsNothing);
    expect(queue.calls, hasLength(1));

    currentUserDocument = null;
    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    expect(find.byKey(myRewNSReviewKey(retained)), findsNothing);
    expect(queue.calls, hasLength(1));

    currentUserDocument = _teacher(ownerUid);
    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    expect(queue.calls, hasLength(2));
    expect(find.byKey(myRewNSReviewKey(retained)), findsNothing);

    final lateReview = _review('late-after-denial');
    currentUserDocument = _teacher(
      ownerUid,
      status: TeacherAccreditationStatus.rejected,
    );
    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    queue.calls[1].completer.complete(<ReviewsRecord>[lateReview]);
    await _pumpAsync(tester);
    expect(find.byKey(myRewNSReviewKey(lateReview)), findsNothing);
  });

  testWidgets('teacher guarded denial redirect is cancelled by approval',
      (tester) async {
    const ownerUid = 'owner-a';
    var redirects = 0;
    currentUserDocument = _teacher(
      ownerUid,
      status: TeacherAccreditationStatus.rejected,
    );
    tester.binding.addPostFrameCallback((_) {
      currentUserDocument = _teacher(ownerUid);
    });

    await tester.pumpWidget(
      _testApp(
        MyRewNSWidget(
          ownerUidProvider: () => ownerUid,
          reviewsLoader: (_) => Completer<List<ReviewsRecord>>().future,
          accessDeniedHandler: (_) => redirects += 1,
        ),
      ),
    );
    await tester.pump();
    expect(redirects, 0);
  });

  testWidgets('student owner switch resets selected rating filter',
      (tester) async {
    final queue = _FutureQueue();
    var ownerUid = 'owner-a';
    Widget page() => MyRewWidget(
          ownerUidProvider: () => ownerUid,
          reviewsLoader: queue.load,
        );

    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    queue.calls.single.completer.complete(<ReviewsRecord>[
      _review('a-five', rating: 5),
      _review('a-four', rating: 4),
    ]);
    await _pumpAsync(tester);
    await tester.tap(
      find
          .ancestor(
            of: find.text('5').first,
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pump();

    ownerUid = 'owner-b';
    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    final visibleAfterReset = _review('b-four', rating: 4);
    queue.calls.last.completer.complete(<ReviewsRecord>[visibleAfterReset]);
    await _pumpAsync(tester);
    expect(find.byKey(myRewReviewKey(visibleAfterReset)), findsOneWidget);
  });

  testWidgets('teacher owner switch resets selected rating filter',
      (tester) async {
    final queue = _FutureQueue();
    var ownerUid = 'owner-a';
    currentUserDocument = _teacher(ownerUid);
    Widget page() => MyRewNSWidget(
          ownerUidProvider: () => ownerUid,
          reviewsLoader: queue.load,
        );

    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    queue.calls.single.completer.complete(<ReviewsRecord>[
      _review('a-five', rating: 5),
      _review('a-four', rating: 4),
    ]);
    await _pumpAsync(tester);
    await tester.tap(
      find
          .ancestor(
            of: find.text('5').last,
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pump();

    ownerUid = 'owner-b';
    currentUserDocument = _teacher(ownerUid);
    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    final visibleAfterReset = _review('b-four', rating: 4);
    queue.calls.last.completer.complete(<ReviewsRecord>[visibleAfterReset]);
    await _pumpAsync(tester);
    expect(find.byKey(myRewNSReviewKey(visibleAfterReset)), findsOneWidget);
  });

  testWidgets('student refresh stays below header and preserves scroll offset',
      (tester) async {
    final queue = _FutureQueue();
    final reviews = List<ReviewsRecord>.generate(
      18,
      (index) => _review('student-scroll-$index'),
    );
    Widget page() => MyRewWidget(
          ownerUidProvider: () => 'owner-a',
          reviewsLoader: queue.load,
        );

    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    queue.calls.single.completer.complete(reviews);
    await _pumpAsync(tester);
    await tester.pumpWidget(_testApp(const SizedBox.shrink()));
    await tester.pump();
    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);

    final headerBottom = tester.getRect(find.byType(BasicPageHeader)).bottom;
    final indicatorTop =
        tester.getRect(find.byKey(myRewRefreshingIndicatorKey)).top;
    expect(indicatorTop, greaterThanOrEqualTo(headerBottom));

    final scrollable = _verticalScrollable().first;
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pump();
    final scrollableState = tester.state<ScrollableState>(scrollable);
    final position = scrollableState.position;
    final offset = position.pixels;
    expect(offset, greaterThan(0));

    queue.calls[1].completer.completeError(StateError('offline'));
    await _pumpAsync(tester);
    final stateAfterError = tester.state<ScrollableState>(scrollable);
    expect(stateAfterError, same(scrollableState));
    expect(stateAfterError.position.pixels, closeTo(offset, 0.01));
    _invokeRetry(tester, myRewRetryButtonKey);
    await tester.pump();
    final stateAfterRetry = tester.state<ScrollableState>(scrollable);
    expect(stateAfterRetry, same(scrollableState));
    expect(stateAfterRetry.position.pixels, closeTo(offset, 0.01));
  });

  testWidgets('teacher refresh stays below header and preserves scroll offset',
      (tester) async {
    const ownerUid = 'owner-a';
    currentUserDocument = _teacher(ownerUid);
    final queue = _FutureQueue();
    final reviews = List<ReviewsRecord>.generate(
      18,
      (index) => _review('teacher-scroll-$index'),
    );
    Widget page() => MyRewNSWidget(
          ownerUidProvider: () => ownerUid,
          reviewsLoader: queue.load,
        );

    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    queue.calls.single.completer.complete(reviews);
    await _pumpAsync(tester);
    await tester.pumpWidget(_testApp(const SizedBox.shrink()));
    await tester.pump();
    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);

    final headerBottom = tester.getRect(find.byType(BasicPageHeader)).bottom;
    final indicatorTop =
        tester.getRect(find.byKey(myRewNSRefreshingIndicatorKey)).top;
    expect(indicatorTop, greaterThanOrEqualTo(headerBottom));

    final scrollable = _verticalScrollable().first;
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pump();
    final scrollableState = tester.state<ScrollableState>(scrollable);
    final position = scrollableState.position;
    final offset = position.pixels;
    expect(offset, greaterThan(0));

    queue.calls[1].completer.completeError(StateError('offline'));
    await _pumpAsync(tester);
    final stateAfterError = tester.state<ScrollableState>(scrollable);
    expect(stateAfterError, same(scrollableState));
    expect(stateAfterError.position.pixels, closeTo(offset, 0.01));
    _invokeRetry(tester, myRewNSRetryButtonKey);
    await tester.pump();
    final stateAfterRetry = tester.state<ScrollableState>(scrollable);
    expect(stateAfterRetry, same(scrollableState));
    expect(stateAfterRetry.position.pixels, closeTo(offset, 0.01));
  });
}
