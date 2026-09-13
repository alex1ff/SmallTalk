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
import 'package:small_talk/components/ux_refreshing_indicator_overlay.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/services/reviews_load_result.dart';
import 'package:small_talk/services/ux_session_cache_lifecycle.dart';
import 'package:small_talk/students_pages/native_speaker_page/native_speaker_page_widget.dart';

const _supportedLocales = <Locale>[Locale('ru'), Locale('en')];

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
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

class _TestAuthUser extends BaseAuthUser {
  _TestAuthUser(this.userId);

  final String userId;

  @override
  bool get loggedIn => true;

  @override
  bool get emailVerified => true;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(uid: userId);

  @override
  Future<void> delete() async {}

  @override
  Future<void> updateEmail(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> sendEmailVerification() async {}
}

final class _ResultStreamCall {
  _ResultStreamCall(this.targetPath)
      : controller = StreamController<ReviewsLoadResult>();

  final String targetPath;
  final StreamController<ReviewsLoadResult> controller;
}

final class _ResultStreamQueue {
  final calls = <_ResultStreamCall>[];

  Stream<ReviewsLoadResult> load(DocumentReference target) {
    final call = _ResultStreamCall(target.path);
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

final class _ResultLoadCall {
  _ResultLoadCall(this.targetPath) : completer = Completer<ReviewsLoadResult>();

  final String targetPath;
  final Completer<ReviewsLoadResult> completer;
}

final class _ResultLoadQueue {
  final calls = <_ResultLoadCall>[];

  Future<ReviewsLoadResult> load(DocumentReference target) {
    final call = _ResultLoadCall(target.path);
    calls.add(call);
    return call.completer.future;
  }
}

Widget _testApp(Widget home) {
  return MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: _supportedLocales,
    localizationsDelegates: _localizationsDelegates,
    home: home,
  );
}

ReviewsRecord _review(String id, {int rating = 5}) {
  return ReviewsRecord.getDocumentFromData(
    <String, dynamic>{
      'rating': rating,
      'comment': 'review-$id',
    },
    ReviewsRecord.collection.doc(id),
  );
}

UserPublicProfilesRecord _profile(String uid) {
  return UserPublicProfilesRecord.getDocumentFromData(
    <String, dynamic>{
      'userId': uid,
      'display_name': 'Tutor $uid',
      'role': UserRole.native_speaker,
      'approvedTeacher': true,
      'ratingAverage': 0.0,
      'ratingCount': 2,
    },
    UserPublicProfilesRecord.collection.doc(uid),
  );
}

StatsRecord _stats(String uid, String id, {String totalCalls = '7'}) {
  return StatsRecord.getDocumentFromData(
    <String, dynamic>{
      'isAllTime': true,
      'totalCalls': totalCalls,
    },
    StatsRecord.createDoc(UsersRecord.collection.doc(uid), id: id),
  );
}

UsersRecord _student(String uid, {bool withGiftMinutes = false}) {
  return UsersRecord.getDocumentFromData(
    <String, dynamic>{
      'uid': uid,
      if (withGiftMinutes)
        'giftMinutes': GiftMinutesStruct(
          minutes: 10.0,
          expiresAt: DateTime.now().add(const Duration(days: 1)),
        ),
    },
    UsersRecord.collection.doc(uid),
  );
}

Stream<UserPublicProfilesRecord?> _profileStream(
  DocumentReference? target,
) =>
    Stream<UserPublicProfilesRecord?>.value(_profile(target!.id));

Future<void> _pumpAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void _invokeRetry(WidgetTester tester) {
  final semantics = tester.widget<Semantics>(
    find.byKey(nativeSpeakerReviewsRetryButtonKey),
  );
  semantics.properties.onTap!();
}

NativeSpeakerPageWidget _page({
  required DocumentReference target,
  NativeSpeakerReviewsLoader? reviewsLoader,
  NativeSpeakerReviewsResultLoader? reviewsResultLoader,
  NativeSpeakerReviewsResultStreamFactory? reviewsResultStreamFactory,
  NativeSpeakerPublicProfileStreamFactory? publicProfileStreamFactory,
  NativeSpeakerStatsLoader? statsLoader,
  Stream<String>? authUidStream,
  NativeSpeakerAuthUidProvider? authUidProvider,
  NativeSpeakerDirectCallStatusChecker? directCallStatusChecker,
  NativeSpeakerMediaPermissionRequester? mediaPermissionRequester,
  NativeSpeakerDirectCallNavigator? directCallNavigator,
  bool hideDirectCallAction = true,
}) {
  return NativeSpeakerPageWidget(
    nsUserDocRef: target,
    hideDirectCallAction: hideDirectCallAction,
    reviewsLoader: reviewsLoader,
    reviewsResultLoader: reviewsResultLoader,
    reviewsResultStreamFactory: reviewsResultStreamFactory,
    publicProfileStreamFactory: publicProfileStreamFactory ?? _profileStream,
    statsLoader: statsLoader ?? (_) async => const <StatsRecord>[],
    authUidStream: authUidStream ?? const Stream<String>.empty(),
    authUidProvider: authUidProvider ?? () => 'student-a',
    directCallStatusChecker: directCallStatusChecker,
    mediaPermissionRequester: mediaPermissionRequester,
    directCallNavigator: directCallNavigator,
  );
}

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
    UxSessionCacheLifecycle.debugResetForTesting();
    NativeSpeakerPageModel.debugClearReviewsSessionCache();
    currentUser = _TestAuthUser('student-a');
    currentUserDocument = _student('student-a');
  });

  tearDown(() {
    currentUser = null;
    currentUserDocument = null;
  });

  testWidgets(
    'cached and pending metadata merge until an authoritative stream result',
    (tester) async {
      final queue = _ResultStreamQueue();
      addTearDown(queue.close);
      final target = UsersRecord.collection.doc('tutor-a');
      final partial = _review('partial');
      final authoritative = _review('authoritative', rating: 4);

      await tester.pumpWidget(
        _testApp(
          _page(
            target: target,
            reviewsResultStreamFactory: queue.load,
          ),
        ),
      );
      await _pumpAsync(tester);

      expect(queue.calls, hasLength(1));
      expect(find.byKey(nativeSpeakerReviewsLoadingKey), findsOneWidget);

      queue.calls.single.controller.add(
        const ReviewsLoadResult(
          reviews: <ReviewsRecord>[],
          isFromCache: true,
          hasPendingWrites: false,
        ),
      );
      await _pumpAsync(tester);

      expect(find.byKey(nativeSpeakerReviewsEmptyKey), findsNothing);
      expect(find.byKey(nativeSpeakerReviewsLoadingKey), findsOneWidget);
      expect(NativeSpeakerPageModel.cachedReviews(target.path), isNull);

      queue.calls.single.controller.add(
        ReviewsLoadResult(
          reviews: <ReviewsRecord>[partial],
          isFromCache: false,
          hasPendingWrites: true,
        ),
      );
      await _pumpAsync(tester);

      expect(find.byKey(nativeSpeakerReviewKey(partial)), findsOneWidget);
      expect(find.byType(UxRefreshingIndicatorPill), findsOneWidget);
      expect(NativeSpeakerPageModel.cachedReviews(target.path), isNull);

      queue.calls.single.controller.add(
        ReviewsLoadResult.authoritative(<ReviewsRecord>[authoritative]),
      );
      await _pumpAsync(tester);

      expect(find.byKey(nativeSpeakerReviewKey(partial)), findsNothing);
      expect(find.byKey(nativeSpeakerReviewKey(authoritative)), findsOneWidget);
      expect(find.byType(UxRefreshingIndicatorPill), findsNothing);
      expect(queue.calls.single.controller.hasListener, isFalse);
      expect(
        NativeSpeakerPageModel.cachedReviews(target.path)
            ?.map((review) => review.reference.path),
        <String>[authoritative.reference.path],
      );
    },
  );

  testWidgets('stream completion without authority becomes a cold error',
      (tester) async {
    final queue = _ResultStreamQueue();
    addTearDown(queue.close);
    final target = UsersRecord.collection.doc('tutor-a');

    await tester.pumpWidget(
      _testApp(
        _page(
          target: target,
          reviewsResultStreamFactory: queue.load,
        ),
      ),
    );
    await _pumpAsync(tester);

    queue.calls.single.controller.add(
      const ReviewsLoadResult(
        reviews: <ReviewsRecord>[],
        isFromCache: true,
        hasPendingWrites: false,
      ),
    );
    await _pumpAsync(tester);
    await queue.calls.single.controller.close();
    await _pumpAsync(tester);

    expect(find.byKey(nativeSpeakerReviewsEmptyKey), findsNothing);
    expect(find.byKey(nativeSpeakerReviewsLoadingKey), findsNothing);
    expect(find.byKey(nativeSpeakerReviewsErrorKey), findsOneWidget);
    expect(NativeSpeakerPageModel.cachedReviews(target.path), isNull);
  });

  testWidgets('cached empty survives error, retry, and successful replacement',
      (tester) async {
    final target = UsersRecord.collection.doc('tutor-a');
    NativeSpeakerPageModel.cacheReviews(
      target.path,
      const <ReviewsRecord>[],
      expectedGeneration: NativeSpeakerPageModel.sessionCacheGeneration,
    );
    final queue = _ResultLoadQueue();
    final replacement = _review('replacement');

    await tester.pumpWidget(
      _testApp(
        _page(
          target: target,
          reviewsResultLoader: queue.load,
        ),
      ),
    );
    await _pumpAsync(tester);

    expect(find.byKey(nativeSpeakerReviewsEmptyKey), findsOneWidget);
    expect(find.byType(UxRefreshingIndicatorPill), findsOneWidget);

    queue.calls.single.completer.completeError(StateError('offline'));
    await _pumpAsync(tester);

    expect(find.byKey(nativeSpeakerReviewsEmptyKey), findsOneWidget);
    expect(find.byKey(nativeSpeakerReviewsRefreshErrorKey), findsOneWidget);

    _invokeRetry(tester);
    await tester.pump();

    expect(queue.calls, hasLength(2));
    expect(find.byKey(nativeSpeakerReviewsRefreshErrorKey), findsNothing);
    expect(find.byKey(nativeSpeakerReviewsEmptyKey), findsOneWidget);
    expect(find.byType(UxRefreshingIndicatorPill), findsOneWidget);

    queue.calls[1].completer.complete(
      ReviewsLoadResult.authoritative(<ReviewsRecord>[replacement]),
    );
    await _pumpAsync(tester);

    expect(find.byKey(nativeSpeakerReviewsEmptyKey), findsNothing);
    expect(find.byKey(nativeSpeakerReviewKey(replacement)), findsOneWidget);
    expect(find.byType(UxRefreshingIndicatorPill), findsNothing);
  });

  testWidgets('second non-authoritative Future becomes a retryable error',
      (tester) async {
    final target = UsersRecord.collection.doc('tutor-a');
    final retained = _review('retained');
    final pending = _review('pending', rating: 4);
    NativeSpeakerPageModel.cacheReviews(
      target.path,
      <ReviewsRecord>[retained],
      expectedGeneration: NativeSpeakerPageModel.sessionCacheGeneration,
    );
    final queue = _ResultLoadQueue();

    await tester.pumpWidget(
      _testApp(_page(target: target, reviewsResultLoader: queue.load)),
    );
    await _pumpAsync(tester);

    queue.calls.single.completer.complete(
      ReviewsLoadResult(
        reviews: <ReviewsRecord>[pending],
        isFromCache: true,
        hasPendingWrites: false,
      ),
    );
    await _pumpAsync(tester);

    expect(queue.calls, hasLength(2));
    expect(find.byKey(nativeSpeakerReviewKey(retained)), findsOneWidget);
    expect(find.byKey(nativeSpeakerReviewKey(pending)), findsOneWidget);

    queue.calls[1].completer.complete(
      ReviewsLoadResult(
        reviews: <ReviewsRecord>[pending],
        isFromCache: false,
        hasPendingWrites: true,
      ),
    );
    await _pumpAsync(tester);

    expect(find.byKey(nativeSpeakerReviewsRefreshErrorKey), findsOneWidget);
    expect(find.byType(UxRefreshingIndicatorPill), findsNothing);
    expect(
      NativeSpeakerPageModel.cachedReviews(target.path)
          ?.map((review) => review.reference.path),
      <String>[retained.reference.path],
    );

    _invokeRetry(tester);
    await tester.pump();
    expect(queue.calls, hasLength(3));
  });

  testWidgets('coalesced auth events restart a pending request',
      (tester) async {
    final authEvents = StreamController<String>();
    addTearDown(authEvents.close);
    var ownerUid = 'student-a';
    final queue = _ResultLoadQueue();
    final target = UsersRecord.collection.doc('tutor-a');
    final staleFirst = _review('stale-first');
    final staleSecond = _review('stale-second');
    final current = _review('current');

    await tester.pumpWidget(
      _testApp(
        _page(
          target: target,
          reviewsResultLoader: queue.load,
          authUidStream: authEvents.stream,
          authUidProvider: () => ownerUid,
        ),
      ),
    );
    await _pumpAsync(tester);
    expect(queue.calls, hasLength(1));

    ownerUid = 'student-b';
    authEvents.add('student-b');
    ownerUid = 'student-a';
    authEvents.add('student-a');
    await tester.pump();

    expect(queue.calls, hasLength(3));
    queue.calls[0].completer.complete(
      ReviewsLoadResult.authoritative(<ReviewsRecord>[staleFirst]),
    );
    queue.calls[1].completer.complete(
      ReviewsLoadResult.authoritative(<ReviewsRecord>[staleSecond]),
    );
    await _pumpAsync(tester);

    expect(find.byKey(nativeSpeakerReviewKey(staleFirst)), findsNothing);
    expect(find.byKey(nativeSpeakerReviewKey(staleSecond)), findsNothing);
    expect(find.byKey(nativeSpeakerReviewsLoadingKey), findsOneWidget);

    queue.calls[2].completer.complete(
      ReviewsLoadResult.authoritative(<ReviewsRecord>[current]),
    );
    await _pumpAsync(tester);

    expect(find.byKey(nativeSpeakerReviewKey(current)), findsOneWidget);
    expect(find.byType(UxRefreshingIndicatorPill), findsNothing);
  });

  testWidgets('target switch rejects old profile and stats while B resolves',
      (tester) async {
    final profileControllers =
        <String, StreamController<UserPublicProfilesRecord?>>{
      'tutor-a': StreamController<UserPublicProfilesRecord?>(),
      'tutor-b': StreamController<UserPublicProfilesRecord?>(),
    };
    addTearDown(() async {
      await tester.pumpWidget(_testApp(const SizedBox.shrink()));
      await tester.pump();
      for (final controller in profileControllers.values) {
        await controller.close();
      }
    });
    final tutorBStatsCompleter = Completer<List<StatsRecord>>();
    final tutorAStats = _stats('tutor-a', 'all-time-a');
    final profileFactory =
        (DocumentReference? target) => profileControllers[target!.id]!.stream;
    final statsLoader = (DocumentReference? target) => target!.id == 'tutor-a'
        ? Future<List<StatsRecord>>.value(<StatsRecord>[tutorAStats])
        : tutorBStatsCompleter.future;
    Future<List<ReviewsRecord>> reviewsLoader(DocumentReference _) async =>
        const <ReviewsRecord>[];
    var target = UsersRecord.collection.doc('tutor-a');

    Widget page() => _page(
          target: target,
          reviewsLoader: reviewsLoader,
          publicProfileStreamFactory: profileFactory,
          statsLoader: statsLoader,
          hideDirectCallAction: false,
        );

    await tester.pumpWidget(_testApp(page()));
    profileControllers['tutor-a']!.add(_profile('tutor-a'));
    expect(tutorAStats.reference.parent.parent?.path, target.path);
    await _pumpAsync(tester);
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('Tutor tutor-a'), findsWidgets);
    expect(find.byKey(nativeSpeakerStatsValueKey), findsOneWidget);
    expect(find.byKey(nativeSpeakerFavoriteActionKey), findsOneWidget);

    target = UsersRecord.collection.doc('tutor-b');
    await tester.pumpWidget(_testApp(page()));
    await tester.pump();

    expect(find.text('Tutor tutor-a'), findsNothing);
    expect(find.byKey(nativeSpeakerStatsValueKey), findsNothing);
    expect(find.byKey(nativeSpeakerFavoriteActionKey), findsNothing);
    expect(find.byKey(nativeSpeakerDirectCallActionKey), findsNothing);

    profileControllers['tutor-b']!.add(null);
    await _pumpAsync(tester);
    expect(find.text('Tutor tutor-a'), findsNothing);
    expect(find.byKey(nativeSpeakerFavoriteActionKey), findsNothing);

    profileControllers['tutor-b']!.add(_profile('tutor-a'));
    await _pumpAsync(tester);
    expect(find.text('Tutor tutor-a'), findsNothing);
    expect(find.byKey(nativeSpeakerFavoriteActionKey), findsNothing);

    profileControllers['tutor-b']!.add(_profile('tutor-b'));
    tutorBStatsCompleter.complete(
      <StatsRecord>[_stats('tutor-a', 'wrong-target')],
    );
    await _pumpAsync(tester);
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('Tutor tutor-b'), findsWidgets);
    expect(find.byKey(nativeSpeakerStatsValueKey), findsNothing);
  });

  testWidgets('target switch blocks a pending direct-call continuation',
      (tester) async {
    currentUserDocument = _student('student-a', withGiftMinutes: true);
    final statusCompleter = Completer<bool>();
    var permissionRequests = 0;
    var navigations = 0;
    var target = UsersRecord.collection.doc('tutor-a');
    Future<List<ReviewsRecord>> reviewsLoader(DocumentReference _) async =>
        const <ReviewsRecord>[];

    Widget page() => _page(
          target: target,
          reviewsLoader: reviewsLoader,
          hideDirectCallAction: false,
          directCallStatusChecker: (_) => statusCompleter.future,
          mediaPermissionRequester: () async {
            permissionRequests += 1;
            return true;
          },
          directCallNavigator: (_, __) async {
            navigations += 1;
          },
        );

    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    expect(find.byKey(nativeSpeakerDirectCallActionKey), findsOneWidget);

    await tester.tap(find.byKey(nativeSpeakerDirectCallActionKey));
    await tester.pump();

    target = UsersRecord.collection.doc('tutor-b');
    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);

    statusCompleter.complete(true);
    await _pumpAsync(tester);

    expect(permissionRequests, 0);
    expect(navigations, 0);
  });

  testWidgets('auth switch blocks a stale unavailable snackbar and call flow',
      (tester) async {
    final authEvents = StreamController<String>();
    addTearDown(authEvents.close);
    var ownerUid = 'student-a';
    currentUserDocument = _student(ownerUid, withGiftMinutes: true);
    final statusCompleter = Completer<bool>();
    var permissionRequests = 0;
    var navigations = 0;
    final target = UsersRecord.collection.doc('tutor-a');

    await tester.pumpWidget(
      _testApp(
        _page(
          target: target,
          reviewsLoader: (_) async => const <ReviewsRecord>[],
          hideDirectCallAction: false,
          authUidStream: authEvents.stream,
          authUidProvider: () => ownerUid,
          directCallStatusChecker: (_) => statusCompleter.future,
          mediaPermissionRequester: () async {
            permissionRequests += 1;
            return true;
          },
          directCallNavigator: (_, __) async {
            navigations += 1;
          },
        ),
      ),
    );
    await _pumpAsync(tester);

    await tester.tap(find.byKey(nativeSpeakerDirectCallActionKey));
    await tester.pump();

    ownerUid = 'student-b';
    currentUserDocument = _student(ownerUid, withGiftMinutes: true);
    authEvents.add(ownerUid);
    await _pumpAsync(tester);

    statusCompleter.complete(false);
    await _pumpAsync(tester);

    expect(find.byType(SnackBar), findsNothing);
    expect(permissionRequests, 0);
    expect(navigations, 0);
  });

  testWidgets('selected rating filter resets when the target changes',
      (tester) async {
    final aFive = _review('a-five', rating: 5);
    final aFour = _review('a-four', rating: 4);
    final bFour = _review('b-four', rating: 4);
    var target = UsersRecord.collection.doc('tutor-a');
    Future<List<ReviewsRecord>> reviewsLoader(
        DocumentReference reference) async {
      return reference.id == 'tutor-a'
          ? <ReviewsRecord>[aFive, aFour]
          : <ReviewsRecord>[bFour];
    }

    Widget page() => _page(target: target, reviewsLoader: reviewsLoader);

    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    await tester.ensureVisible(find.byKey(nativeSpeakerRatingFilterKey(5)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(nativeSpeakerRatingFilterKey(5)));
    await tester.pump();

    expect(find.byKey(nativeSpeakerReviewKey(aFive)), findsOneWidget);
    expect(find.byKey(nativeSpeakerReviewKey(aFour)), findsNothing);

    target = UsersRecord.collection.doc('tutor-b');
    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);

    expect(find.byKey(nativeSpeakerReviewKey(bFour)), findsOneWidget);
  });

  testWidgets('refresh keeps review scroll offset and pill below the header',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final target = UsersRecord.collection.doc('tutor-a');
    final reviews = List<ReviewsRecord>.generate(
      8,
      (index) => _review('scroll-$index', rating: 5 - (index % 2)),
    );
    final firstQueue = _ResultStreamQueue();
    final refreshQueue = _ResultStreamQueue();
    addTearDown(firstQueue.close);
    addTearDown(refreshQueue.close);
    NativeSpeakerReviewsResultStreamFactory factory = firstQueue.load;

    Widget page() => _page(
          target: target,
          reviewsResultStreamFactory: factory,
        );

    await tester.pumpWidget(_testApp(page()));
    await _pumpAsync(tester);
    firstQueue.calls.single.controller.add(
      ReviewsLoadResult.authoritative(reviews),
    );
    await _pumpAsync(tester);

    final scrollView = tester.widget<CustomScrollView>(
      find.byKey(nativeSpeakerPageScrollKey),
    );
    scrollView.controller!.jumpTo(280.0);
    await tester.pumpAndSettle();
    final offsetBeforeRefresh = scrollView.controller!.offset;
    expect(offsetBeforeRefresh, greaterThan(0.0));

    factory = refreshQueue.load;
    await tester.pumpWidget(_testApp(page()));
    await tester.pump();

    final refreshedScrollView = tester.widget<CustomScrollView>(
      find.byKey(nativeSpeakerPageScrollKey),
    );
    expect(refreshedScrollView.controller, same(scrollView.controller));
    expect(
      refreshedScrollView.controller!.offset,
      moreOrLessEquals(offsetBeforeRefresh, epsilon: 0.5),
    );
    expect(find.byType(UxRefreshingIndicatorPill), findsOneWidget);
    final pillRect = tester.getRect(find.byType(UxRefreshingIndicatorPill));
    final headerRect = tester.getRect(find.byType(BasicPageHeader));
    expect(pillRect.top, greaterThanOrEqualTo(headerRect.bottom));

    refreshQueue.calls.single.controller.addError(StateError('offline'));
    await _pumpAsync(tester);
    expect(find.byType(UxRefreshingIndicatorPill), findsNothing);
    expect(refreshQueue.calls.single.controller.hasListener, isFalse);
    expect(find.byKey(nativeSpeakerReviewsRefreshErrorKey), findsOneWidget);
    final errorRect = tester.getRect(
      find.byKey(nativeSpeakerReviewsRefreshErrorKey),
    );
    expect(errorRect.top, greaterThanOrEqualTo(headerRect.bottom));
    expect(
        errorRect.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
    expect(
      refreshedScrollView.controller!.offset,
      moreOrLessEquals(offsetBeforeRefresh, epsilon: 0.5),
    );

    _invokeRetry(tester);
    await tester.pump();
    expect(refreshQueue.calls, hasLength(2));
    refreshQueue.calls[1].controller.add(
      ReviewsLoadResult.authoritative(reviews),
    );
    await _pumpAsync(tester);
    expect(find.byKey(nativeSpeakerReviewsRefreshErrorKey), findsNothing);
  });
}
