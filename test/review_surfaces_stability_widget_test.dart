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
import 'package:small_talk/students_pages/native_speaker_page/native_speaker_page_widget.dart';
import 'package:small_talk/teachers_pages/my_rew_n_s/my_rew_n_s_widget.dart';

const _supportedLocales = [Locale('ru'), Locale('en')];

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

final class _ReviewLoadCall {
  _ReviewLoadCall(this.key) : completer = Completer<List<ReviewsRecord>>();

  final String key;
  final Completer<List<ReviewsRecord>> completer;
}

final class _ReviewLoadQueue {
  final calls = <_ReviewLoadCall>[];

  Future<List<ReviewsRecord>> load(String key) {
    final call = _ReviewLoadCall(key);
    calls.add(call);
    return call.completer.future;
  }
}

final class _ReviewResultStreamCall {
  _ReviewResultStreamCall(this.key)
      : controller = StreamController<ReviewsLoadResult>();

  final String key;
  final StreamController<ReviewsLoadResult> controller;
}

final class _ReviewResultStreamQueue {
  final calls = <_ReviewResultStreamCall>[];

  Stream<ReviewsLoadResult> load(String key) {
    final call = _ReviewResultStreamCall(key);
    calls.add(call);
    return call.controller.stream;
  }

  Future<void> close() async {
    for (final call in calls) {
      await call.controller.close();
    }
  }
}

final class _SurfaceKeys {
  const _SurfaceKeys({
    required this.loading,
    required this.empty,
    required this.error,
    required this.refreshError,
    required this.retry,
    required this.list,
    required this.reviewKey,
    required this.refreshSemanticsLabel,
  });

  final Key loading;
  final Key empty;
  final Key error;
  final Key refreshError;
  final Key retry;
  final Key list;
  final Key Function(ReviewsRecord review) reviewKey;
  final String refreshSemanticsLabel;
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

UsersRecord _approvedTeacher(String uid) {
  return UsersRecord.getDocumentFromData(
    <String, dynamic>{
      'uid': uid,
      'role': UserRole.native_speaker,
      'verif_NS': true,
      'rating': <String, dynamic>{
        'average': 5.0,
        'totalReviews': 1,
      },
    },
    UsersRecord.collection.doc(uid),
  );
}

UserPublicProfilesRecord _nativeSpeakerProfile(String uid) {
  return UserPublicProfilesRecord.getDocumentFromData(
    <String, dynamic>{
      'userId': uid,
      'display_name': 'Tutor $uid',
      'role': UserRole.native_speaker,
      'approvedTeacher': true,
      'ratingAverage': 0.0,
      'ratingCount': 1,
    },
    UserPublicProfilesRecord.collection.doc(uid),
  );
}

Future<void> _pumpAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void _invokeRetry(WidgetTester tester, Key retryKey) {
  final semantics = tester.widget<Semantics>(find.byKey(retryKey));
  final callback = semantics.properties.onTap;
  expect(callback, isNotNull);
  callback!();
}

Finder _liveRegion(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.liveRegion == true &&
        widget.properties.label == label,
  );
}

ScrollableState _ancestorVerticalScrollable(
  WidgetTester tester,
  Key descendantKey,
) {
  return tester
      .stateList<ScrollableState>(
        find.ancestor(
          of: find.byKey(descendantKey),
          matching: find.byType(Scrollable),
        ),
      )
      .firstWhere(
        (state) => axisDirectionToAxis(state.axisDirection) == Axis.vertical,
      );
}

void _expectRefreshIndicatorBelowChrome(
  WidgetTester tester,
  String semanticsLabel,
) {
  final indicatorRect = tester.getRect(_liveRegion(semanticsLabel));
  final pageHeader = find.byType(BasicPageHeader);
  if (pageHeader.evaluate().isNotEmpty) {
    expect(
      indicatorRect.top,
      greaterThanOrEqualTo(tester.getRect(pageHeader).bottom),
    );
    return;
  }

  final nativeReviewsSection = find.byKey(nativeSpeakerReviewsSectionKey);
  expect(nativeReviewsSection, findsOneWidget);
  final sectionRect = tester.getRect(nativeReviewsSection);
  expect(indicatorRect.top, greaterThanOrEqualTo(sectionRect.top));
  expect(indicatorRect.bottom, lessThanOrEqualTo(sectionRect.bottom));
}

Future<void> _exerciseStableLifecycle(
  WidgetTester tester, {
  required Widget Function() page,
  required _ReviewLoadQueue queue,
  required _SurfaceKeys keys,
}) async {
  final firstReview = _review('first');
  final initialReviews = <ReviewsRecord>[
    firstReview,
    for (var index = 0; index < 11; index++)
      _review('initial-$index', rating: (index % 5) + 1),
  ];
  final replacementReview = _review('replacement', rating: 4);

  await tester.pumpWidget(_testApp(page()));
  await _pumpAsync(tester);
  expect(queue.calls, hasLength(1));
  expect(find.byKey(keys.loading), findsOneWidget);
  expect(find.byKey(keys.empty), findsNothing);

  queue.calls[0].completer.completeError(StateError('cold failure'));
  await _pumpAsync(tester);
  expect(find.byKey(keys.error), findsOneWidget);
  expect(find.byKey(keys.refreshError), findsNothing);

  _invokeRetry(tester, keys.retry);
  await tester.pump();
  expect(queue.calls, hasLength(2));
  expect(find.byKey(keys.error), findsNothing);
  expect(find.byKey(keys.loading), findsOneWidget);

  queue.calls[1].completer.complete(initialReviews);
  await _pumpAsync(tester);
  final rowFinder = find.byKey(keys.reviewKey(firstReview));
  expect(rowFinder, findsOneWidget);
  final successfulRowRect = tester.getRect(rowFinder);

  await tester.pumpWidget(_testApp(const SizedBox.shrink()));
  await tester.pump();
  await tester.pumpWidget(_testApp(page()));
  await _pumpAsync(tester);
  expect(queue.calls, hasLength(3));
  expect(rowFinder, findsOneWidget);
  expect(tester.getRect(rowFinder), successfulRowRect);
  expect(
    _liveRegion(keys.refreshSemanticsLabel),
    findsOneWidget,
  );
  _expectRefreshIndicatorBelowChrome(
    tester,
    keys.refreshSemanticsLabel,
  );

  final scrollable = _ancestorVerticalScrollable(tester, keys.list);
  await tester.dragFrom(
    const Offset(400.0, 400.0),
    const Offset(0.0, -300.0),
  );
  await tester.pump(const Duration(milliseconds: 300));
  final refreshScrollOffset = scrollable.position.pixels;
  expect(refreshScrollOffset, greaterThan(0.0));

  queue.calls[2].completer.completeError(StateError('warm failure'));
  await _pumpAsync(tester);
  expect(find.byKey(keys.refreshError), findsOneWidget);
  expect(rowFinder, findsOneWidget);
  expect(scrollable.position.pixels, refreshScrollOffset);

  _invokeRetry(tester, keys.retry);
  await tester.pump();
  expect(queue.calls, hasLength(4));
  expect(find.byKey(keys.refreshError), findsNothing);
  expect(
    _liveRegion(keys.refreshSemanticsLabel),
    findsOneWidget,
  );
  expect(scrollable.position.pixels, refreshScrollOffset);

  queue.calls[3].completer.complete(const <ReviewsRecord>[]);
  await _pumpAsync(tester);
  expect(find.byKey(keys.empty), findsOneWidget);
  expect(rowFinder, findsNothing);
  final successfulEmptySize = tester.getSize(find.byKey(keys.empty));

  await tester.pumpWidget(_testApp(const SizedBox.shrink()));
  await tester.pump();
  await tester.pumpWidget(_testApp(page()));
  await _pumpAsync(tester);
  expect(queue.calls, hasLength(5));
  expect(find.byKey(keys.empty), findsOneWidget);
  expect(tester.getSize(find.byKey(keys.empty)), successfulEmptySize);
  expect(
    _liveRegion(keys.refreshSemanticsLabel),
    findsOneWidget,
  );

  queue.calls[4].completer.completeError(StateError('cached-empty failure'));
  await _pumpAsync(tester);
  expect(find.byKey(keys.refreshError), findsOneWidget);
  expect(find.byKey(keys.empty), findsOneWidget);

  _invokeRetry(tester, keys.retry);
  await tester.pump();
  expect(queue.calls, hasLength(6));
  expect(find.byKey(keys.refreshError), findsNothing);
  expect(find.byKey(keys.empty), findsOneWidget);
  expect(_liveRegion(keys.refreshSemanticsLabel), findsOneWidget);

  queue.calls[5].completer.complete([replacementReview]);
  await _pumpAsync(tester);
  expect(find.byKey(keys.empty), findsNothing);
  expect(find.byKey(keys.reviewKey(replacementReview)), findsOneWidget);
  expect(
    _liveRegion(keys.refreshSemanticsLabel),
    findsNothing,
  );
}

Future<void> _exerciseMetadataAwareRefresh(
  WidgetTester tester, {
  required Widget Function(_ReviewResultStreamQueue queue) page,
  required _SurfaceKeys keys,
}) async {
  final queue = _ReviewResultStreamQueue();
  addTearDown(queue.close);
  final cachedReview = _review('cached-partial');
  final pendingReview = _review('pending-partial', rating: 4);
  final serverReview = _review('server', rating: 3);

  await tester.pumpWidget(_testApp(page(queue)));
  await _pumpAsync(tester);
  expect(queue.calls, hasLength(1));
  expect(find.byKey(keys.loading), findsOneWidget);

  queue.calls.single.controller.add(
    const ReviewsLoadResult(
      reviews: <ReviewsRecord>[],
      isFromCache: true,
      hasPendingWrites: false,
    ),
  );
  await _pumpAsync(tester);
  expect(find.byKey(keys.loading), findsOneWidget);
  expect(find.byKey(keys.empty), findsNothing);

  queue.calls.single.controller.add(
    ReviewsLoadResult(
      reviews: <ReviewsRecord>[cachedReview],
      isFromCache: true,
      hasPendingWrites: false,
    ),
  );
  await _pumpAsync(tester);
  expect(find.byKey(keys.reviewKey(cachedReview)), findsOneWidget);
  expect(_liveRegion(keys.refreshSemanticsLabel), findsOneWidget);
  _expectRefreshIndicatorBelowChrome(tester, keys.refreshSemanticsLabel);

  queue.calls.single.controller.add(
    ReviewsLoadResult(
      reviews: <ReviewsRecord>[pendingReview],
      isFromCache: false,
      hasPendingWrites: true,
    ),
  );
  await _pumpAsync(tester);
  expect(find.byKey(keys.reviewKey(cachedReview)), findsOneWidget);
  expect(find.byKey(keys.reviewKey(pendingReview)), findsOneWidget);
  expect(_liveRegion(keys.refreshSemanticsLabel), findsOneWidget);

  queue.calls.single.controller.add(
    ReviewsLoadResult.authoritative(<ReviewsRecord>[serverReview]),
  );
  await _pumpAsync(tester);
  expect(find.byKey(keys.reviewKey(cachedReview)), findsNothing);
  expect(find.byKey(keys.reviewKey(pendingReview)), findsNothing);
  expect(find.byKey(keys.reviewKey(serverReview)), findsOneWidget);
  expect(_liveRegion(keys.refreshSemanticsLabel), findsNothing);
}

Future<void> _exerciseStaleOwnerCycle(
  WidgetTester tester, {
  required Widget Function() page,
  required void Function(String key) setActiveKey,
  required _ReviewLoadQueue queue,
  required Key Function(ReviewsRecord review) reviewKey,
}) async {
  final staleA = _review('stale-a');
  final staleB = _review('stale-b');
  final currentA = _review('current-a');

  await tester.pumpWidget(_testApp(page()));
  await _pumpAsync(tester);
  expect(queue.calls.single.key, 'owner-a');

  setActiveKey('owner-b');
  await tester.pumpWidget(_testApp(page()));
  await _pumpAsync(tester);
  expect(queue.calls[1].key, 'owner-b');

  setActiveKey('owner-a');
  await tester.pumpWidget(_testApp(page()));
  await _pumpAsync(tester);
  expect(queue.calls[2].key, 'owner-a');

  queue.calls[0].completer.complete([staleA]);
  queue.calls[1].completer.complete([staleB]);
  await _pumpAsync(tester);
  expect(find.byKey(reviewKey(staleA)), findsNothing);
  expect(find.byKey(reviewKey(staleB)), findsNothing);

  queue.calls[2].completer.complete([currentA]);
  await _pumpAsync(tester);
  expect(find.byKey(reviewKey(currentA)), findsOneWidget);
  expect(find.byKey(reviewKey(staleA)), findsNothing);
  expect(find.byKey(reviewKey(staleB)), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
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
    NativeSpeakerPageModel.debugClearReviewsSessionCache();
  });

  tearDown(() {
    currentUser = null;
    currentUserDocument = null;
  });

  group('MyRewWidget', () {
    const keys = _SurfaceKeys(
      loading: myRewLoadingKey,
      empty: myRewEmptyKey,
      error: myRewErrorKey,
      refreshError: myRewRefreshErrorKey,
      retry: myRewRetryButtonKey,
      list: myRewListKey,
      reviewKey: myRewReviewKey,
      refreshSemanticsLabel: 'Обновление моих отзывов',
    );

    testWidgets('retains rows and confirmed empty through refresh/retry',
        (tester) async {
      final queue = _ReviewLoadQueue();
      var ownerUid = 'owner-a';
      Widget page() => MyRewWidget(
            ownerUidProvider: () => ownerUid,
            reviewsLoader: queue.load,
          );

      await _exerciseStableLifecycle(
        tester,
        page: page,
        queue: queue,
        keys: keys,
      );
    });

    testWidgets('ignores stale A to B to A completions', (tester) async {
      final queue = _ReviewLoadQueue();
      var ownerUid = 'owner-a';
      Widget page() => MyRewWidget(
            ownerUidProvider: () => ownerUid,
            reviewsLoader: queue.load,
          );

      await _exerciseStaleOwnerCycle(
        tester,
        page: page,
        queue: queue,
        reviewKey: myRewReviewKey,
        setActiveKey: (value) => ownerUid = value,
      );
    });

    testWidgets('keeps cached and pending metadata until server authority',
        (tester) async {
      await _exerciseMetadataAwareRefresh(
        tester,
        keys: keys,
        page: (queue) => MyRewWidget(
          ownerUidProvider: () => 'owner-a',
          reviewsResultStreamLoader: queue.load,
        ),
      );
    });
  });

  group('MyRewNSWidget', () {
    const keys = _SurfaceKeys(
      loading: myRewNSLoadingKey,
      empty: myRewNSEmptyKey,
      error: myRewNSErrorKey,
      refreshError: myRewNSRefreshErrorKey,
      retry: myRewNSRetryButtonKey,
      list: myRewNSListKey,
      reviewKey: myRewNSReviewKey,
      refreshSemanticsLabel: 'Обновление отзывов преподавателя',
    );

    testWidgets('retains rows and confirmed empty through refresh/retry',
        (tester) async {
      final queue = _ReviewLoadQueue();
      var ownerUid = 'owner-a';
      currentUserDocument = _approvedTeacher(ownerUid);
      Widget page() => MyRewNSWidget(
            ownerUidProvider: () => ownerUid,
            reviewsLoader: queue.load,
          );

      await _exerciseStableLifecycle(
        tester,
        page: page,
        queue: queue,
        keys: keys,
      );
    });

    testWidgets('keeps same-uid content and rejects stale owner completions',
        (tester) async {
      final queue = _ReviewLoadQueue();
      var ownerUid = 'owner-a';
      currentUserDocument = _approvedTeacher(ownerUid);
      Widget page() => MyRewNSWidget(
            ownerUidProvider: () => ownerUid,
            reviewsLoader: queue.load,
          );

      await tester.pumpWidget(_testApp(page()));
      await _pumpAsync(tester);
      final retainedReview = _review('retained');
      queue.calls.single.completer.complete([retainedReview]);
      await _pumpAsync(tester);
      expect(find.byKey(myRewNSReviewKey(retainedReview)), findsOneWidget);

      currentUserDocument = null;
      await tester.pumpWidget(_testApp(page()));
      await _pumpAsync(tester);
      expect(find.byKey(myRewNSReviewKey(retainedReview)), findsOneWidget);
      expect(queue.calls, hasLength(1));

      currentUserDocument = _approvedTeacher(ownerUid);
      MyRewNSModel.debugClearSessionCache();
      await tester.pumpWidget(_testApp(const SizedBox.shrink()));
      await tester.pump();
      final staleQueue = _ReviewLoadQueue();
      Widget stalePage() => MyRewNSWidget(
            ownerUidProvider: () => ownerUid,
            reviewsLoader: staleQueue.load,
          );
      await _exerciseStaleOwnerCycle(
        tester,
        page: stalePage,
        queue: staleQueue,
        reviewKey: myRewNSReviewKey,
        setActiveKey: (value) {
          ownerUid = value;
          currentUserDocument = _approvedTeacher(value);
        },
      );
    });

    testWidgets('keeps cached and pending metadata until server authority',
        (tester) async {
      currentUserDocument = _approvedTeacher('owner-a');
      await _exerciseMetadataAwareRefresh(
        tester,
        keys: keys,
        page: (queue) => MyRewNSWidget(
          ownerUidProvider: () => 'owner-a',
          reviewsResultStreamLoader: queue.load,
        ),
      );
    });
  });

  group('NativeSpeakerPageWidget reviews', () {
    const keys = _SurfaceKeys(
      loading: nativeSpeakerReviewsLoadingKey,
      empty: nativeSpeakerReviewsEmptyKey,
      error: nativeSpeakerReviewsErrorKey,
      refreshError: nativeSpeakerReviewsRefreshErrorKey,
      retry: nativeSpeakerReviewsRetryButtonKey,
      list: nativeSpeakerReviewsListKey,
      reviewKey: nativeSpeakerReviewKey,
      refreshSemanticsLabel: 'Обновление отзывов преподавателя',
    );

    testWidgets('retains rows and confirmed empty through refresh/retry',
        (tester) async {
      final queue = _ReviewLoadQueue();
      var target = UsersRecord.collection.doc('owner-a');
      Stream<UserPublicProfilesRecord?> profileStream(
        DocumentReference? reference,
      ) =>
          Stream.value(_nativeSpeakerProfile(reference!.id));
      Widget page() => NativeSpeakerPageWidget(
            nsUserDocRef: target,
            hideDirectCallAction: true,
            reviewsLoader: (reference) => queue.load(reference.id),
            publicProfileStreamFactory: profileStream,
            statsLoader: (_) async => const <StatsRecord>[],
          );

      await _exerciseStableLifecycle(
        tester,
        page: page,
        queue: queue,
        keys: keys,
      );
    });

    testWidgets('ignores stale target A to B to A completions', (tester) async {
      final queue = _ReviewLoadQueue();
      var target = UsersRecord.collection.doc('owner-a');
      Stream<UserPublicProfilesRecord?> profileStream(
        DocumentReference? reference,
      ) =>
          Stream.value(_nativeSpeakerProfile(reference!.id));
      Widget page() => NativeSpeakerPageWidget(
            nsUserDocRef: target,
            hideDirectCallAction: true,
            reviewsLoader: (reference) => queue.load(reference.id),
            publicProfileStreamFactory: profileStream,
            statsLoader: (_) async => const <StatsRecord>[],
          );

      await _exerciseStaleOwnerCycle(
        tester,
        page: page,
        queue: queue,
        reviewKey: nativeSpeakerReviewKey,
        setActiveKey: (value) {
          target = UsersRecord.collection.doc(value);
        },
      );
    });

    testWidgets('keeps cached and pending metadata until server authority',
        (tester) async {
      final target = UsersRecord.collection.doc('owner-a');
      await _exerciseMetadataAwareRefresh(
        tester,
        keys: keys,
        page: (queue) => NativeSpeakerPageWidget(
          nsUserDocRef: target,
          hideDirectCallAction: true,
          reviewsResultStreamFactory: (reference) => queue.load(reference.id),
          publicProfileStreamFactory: (reference) =>
              Stream.value(_nativeSpeakerProfile(reference!.id)),
          statsLoader: (_) async => const <StatsRecord>[],
        ),
      );
    });
  });
}
