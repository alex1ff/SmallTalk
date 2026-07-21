import 'dart:async';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/components/review_words_bar.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/students_pages/words/words_widget.dart';

void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
    await FFLocalizations.initialize();
  });

  setUp(WordsModel.debugClearSessionCache);

  test('server confirmation rejects cache and pending-write snapshots', () {
    expect(
      wordsSnapshotIsServerConfirmed(
        isFromCache: false,
        hasPendingWrites: false,
      ),
      isTrue,
    );
    expect(
      wordsSnapshotIsServerConfirmed(
        isFromCache: true,
        hasPendingWrites: false,
      ),
      isFalse,
    );
    expect(
      wordsSnapshotIsServerConfirmed(
        isFromCache: false,
        hasPendingWrites: true,
      ),
      isFalse,
    );
  });

  testWidgets('cold loading waits for a server-confirmed empty result',
      (tester) async {
    final sources = _WordsTestSources();
    addTearDown(sources.close);

    await tester.pumpWidget(_buildWordsTestApp(sources, cacheKey: 'cold'));
    await tester.pump();

    final headerRect = tester.getRect(find.byKey(wordsHeaderKey));
    final viewportRect = tester.getRect(find.byKey(wordsContentViewportKey));

    expect(find.byKey(wordsInitialLoadingKey), findsOneWidget);
    expect(find.byKey(wordsEmptyStateKey), findsNothing);
    expect(find.byKey(wordsFullErrorStateKey), findsNothing);
    expect(find.byKey(reviewWordsBarSurfaceKey), findsNothing);

    sources.reviews.single.add(_queryResult(const [], confirmed: true));
    sources.words.single.add(_queryResult(const [], confirmed: false));
    await tester.pump();

    expect(find.byKey(wordsInitialLoadingKey), findsOneWidget);
    expect(find.byKey(wordsEmptyStateKey), findsNothing);

    sources.words.single.add(_queryResult(const [], confirmed: true));
    await tester.pump();

    expect(find.byKey(wordsInitialLoadingKey), findsNothing);
    expect(find.byKey(wordsEmptyStateKey), findsOneWidget);
    expect(tester.getRect(find.byKey(wordsHeaderKey)), headerRect);
    expect(tester.getRect(find.byKey(wordsContentViewportKey)), viewportRect);
    expect(find.byKey(reviewWordsBarSurfaceKey), findsNothing);
  });

  testWidgets('cold error retries inside the stable content viewport',
      (tester) async {
    final sources = _WordsTestSources();
    addTearDown(sources.close);

    await tester.pumpWidget(
      _buildWordsTestApp(sources, cacheKey: 'cold-error'),
    );
    await tester.pump();
    final viewportRect = tester.getRect(find.byKey(wordsContentViewportKey));
    expect(find.byKey(reviewWordsBarSurfaceKey), findsNothing);

    sources.words.single.addError(StateError('words failed'));
    await tester.pump();

    expect(find.byKey(wordsFullErrorStateKey), findsOneWidget);
    expect(find.byKey(wordsRetryButtonKey), findsOneWidget);
    expect(find.byKey(wordsEmptyStateKey), findsNothing);

    await tester.tap(find.byKey(wordsRetryButtonKey));
    await tester.pump();

    expect(sources.words, hasLength(2));
    expect(sources.reviews, hasLength(2));
    expect(find.byKey(wordsInitialLoadingKey), findsOneWidget);
    expect(find.byKey(wordsFullErrorStateKey), findsNothing);

    sources.reviews.last.add(_queryResult(const [], confirmed: true));
    sources.words.last.add(
      _queryResult([_word('fresh', 'fresh word', 'свежее слово')]),
    );
    await tester.pump();

    expect(find.text('fresh word'), findsOneWidget);
    expect(find.byKey(wordsFullErrorStateKey), findsNothing);
    expect(tester.getRect(find.byKey(wordsContentViewportKey)), viewportRect);
    expect(find.byKey(reviewWordsBarSurfaceKey), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(reviewWordsBarCountTextKey)).data,
      '0 слов',
    );
    expect(find.byKey(reviewWordsBarActionKey), findsNothing);
  });

  testWidgets('warm error and retry keep the shown word row', (tester) async {
    final sources = _WordsTestSources();
    addTearDown(sources.close);

    await tester.pumpWidget(_buildWordsTestApp(sources, cacheKey: 'warm'));
    await tester.pump();
    sources.reviews.single.add(_queryResult(const [], confirmed: true));
    sources.words.single.add(
      _queryResult([_word('shown', 'shown word', 'показанное слово')]),
    );
    await tester.pump();

    final viewportRect = tester.getRect(find.byKey(wordsContentViewportKey));
    final rowRect = tester.getRect(find.byKey(wordsRowKey(_wordPath('shown'))));
    final reviewBarRect = tester.getRect(find.byKey(reviewWordsBarSurfaceKey));
    expect(
      tester.widget<Text>(find.byKey(reviewWordsBarCountTextKey)).data,
      '0 слов',
    );
    expect(find.byKey(reviewWordsBarActionKey), findsNothing);

    sources.words.single.addError(StateError('refresh failed'));
    await tester.pump();

    expect(find.text('shown word'), findsOneWidget);
    expect(find.byKey(wordsFullErrorStateKey), findsNothing);
    expect(find.byKey(wordsRefreshErrorIndicatorKey), findsOneWidget);
    expect(
      tester.getSize(find.byKey(wordsRefreshErrorIndicatorKey)).height,
      greaterThanOrEqualTo(48.0),
    );
    expect(tester.getRect(find.byKey(wordsContentViewportKey)), viewportRect);
    expect(
        tester.getRect(find.byKey(wordsRowKey(_wordPath('shown')))), rowRect);
    expect(tester.getRect(find.byKey(reviewWordsBarSurfaceKey)), reviewBarRect);

    sources.words.single.addError(StateError('refresh failed again'));
    await tester.pump();
    expect(find.byKey(wordsRefreshErrorIndicatorKey), findsOneWidget);

    await tester.tap(find.byKey(wordsRefreshErrorIndicatorKey));
    await tester.pump();

    expect(sources.words, hasLength(2));
    expect(find.text('shown word'), findsOneWidget);
    expect(find.byKey(wordsRefreshErrorIndicatorKey), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
        tester.getRect(find.byKey(wordsRowKey(_wordPath('shown')))), rowRect);

    sources.reviews.last.add(_queryResult(const [], confirmed: true));
    sources.words.last.add(
      _queryResult([_word('updated', 'updated word', 'обновлённое слово')]),
    );
    await tester.pump();

    expect(find.text('shown word'), findsNothing);
    expect(find.text('updated word'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('refresh error and retry preserve the list scroll position',
      (tester) async {
    final sources = _WordsTestSources();
    addTearDown(sources.close);

    await tester.pumpWidget(
      _buildWordsTestApp(sources, cacheKey: 'scroll-position'),
    );
    await tester.pump();
    sources.reviews.single.add(_queryResult(const [], confirmed: true));
    sources.words.single.add(
      _queryResult(
        List.generate(
          24,
          (index) => _word(
            'scroll-$index',
            'scroll word $index',
            'слово $index',
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.byKey(wordsListKey), const Offset(0.0, -420.0));
    await tester.pump();
    final listScrollable = find.descendant(
      of: find.byKey(wordsListKey),
      matching: find.byType(Scrollable),
    );
    final beforeError =
        tester.state<ScrollableState>(listScrollable).position.pixels;
    expect(beforeError, greaterThan(0.0));

    sources.words.single.addError(StateError('refresh failed'));
    await tester.pump();

    expect(find.byKey(wordsRefreshErrorIndicatorKey), findsOneWidget);
    expect(
      tester.state<ScrollableState>(listScrollable).position.pixels,
      closeTo(beforeError, 0.01),
    );

    await tester.tap(find.byKey(wordsRefreshErrorIndicatorKey));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.state<ScrollableState>(listScrollable).position.pixels,
      closeTo(beforeError, 0.01),
    );
  });

  testWidgets('pending empty keeps data until the server confirms it',
      (tester) async {
    final sources = _WordsTestSources();
    addTearDown(sources.close);

    await tester.pumpWidget(
      _buildWordsTestApp(sources, cacheKey: 'pending-empty'),
    );
    await tester.pump();
    sources.reviews.single.add(_queryResult(const [], confirmed: true));
    sources.words.single.add(
      _queryResult([_word('kept', 'kept word', 'сохранённое слово')]),
    );
    await tester.pump();

    sources.words.single.add(_queryResult(const [], confirmed: false));
    await tester.pump();

    expect(find.text('kept word'), findsOneWidget);
    expect(find.byKey(wordsEmptyStateKey), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    sources.words.single.add(_queryResult(const [], confirmed: true));
    await tester.pump();

    expect(find.text('kept word'), findsNothing);
    expect(find.byKey(wordsEmptyStateKey), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('cold error fits a compact viewport without a review bar',
      (tester) async {
    tester.view.physicalSize = const Size(360.0, 600.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sources = _WordsTestSources();
    addTearDown(sources.close);
    await tester.pumpWidget(
      _buildWordsTestApp(
        sources,
        cacheKey: 'compact-error',
        textScaler: const TextScaler.linear(2.0),
        bottomInset: 24.0,
      ),
    );
    await tester.pump();
    sources.words.single.addError(StateError('compact error'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(wordsFullErrorStateKey), findsOneWidget);
    expect(find.byKey(wordsRetryButtonKey), findsOneWidget);
    await tester.ensureVisible(find.byKey(wordsRetryButtonKey));
    await tester.pump();
    final retryRect = tester.getRect(find.byKey(wordsRetryButtonKey));
    final viewportRect = tester.getRect(find.byKey(wordsContentViewportKey));
    expect(find.byKey(reviewWordsBarSurfaceKey), findsNothing);
    expect(retryRect.bottom, lessThanOrEqualTo(viewportRect.bottom));
  });

  testWidgets('empty state stays scrollable without a review bar',
      (tester) async {
    tester.view.physicalSize = const Size(360.0, 600.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sources = _WordsTestSources();
    addTearDown(sources.close);
    await tester.pumpWidget(
      _buildWordsTestApp(
        sources,
        cacheKey: 'compact-empty',
        textScaler: const TextScaler.linear(2.0),
        bottomInset: 24.0,
      ),
    );
    await tester.pump();
    sources.reviews.single.add(_queryResult(const [], confirmed: true));
    sources.words.single.add(_queryResult(const [], confirmed: true));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(wordsEmptyStateKey), findsOneWidget);
    expect(find.byKey(reviewWordsBarSurfaceKey), findsNothing);
    final message = find.textContaining('Сохраните первое слово');
    expect(message, findsOneWidget);
    final emptyScrollView = find.descendant(
      of: find.byKey(wordsEmptyStateKey),
      matching: find.byType(SingleChildScrollView),
    );
    final emptyScrollable = find.descendant(
      of: emptyScrollView,
      matching: find.byType(Scrollable),
    );
    await tester.drag(
      emptyScrollView,
      const Offset(0.0, -1200.0),
    );
    await tester.pump();
    final messageRect = tester.getRect(message);
    final viewportRect = tester.getRect(find.byKey(wordsContentViewportKey));
    expect(messageRect.bottom, lessThanOrEqualTo(viewportRect.bottom));

    final beforeError =
        tester.state<ScrollableState>(emptyScrollable).position.pixels;
    sources.words.single.addError(StateError('empty refresh failed'));
    await tester.pump();

    expect(find.byKey(wordsRefreshErrorIndicatorKey), findsOneWidget);
    expect(
      tester.state<ScrollableState>(emptyScrollable).position.pixels,
      closeTo(beforeError, 0.01),
    );
  });

  testWidgets('empty dictionary hides the review bar even with review data',
      (tester) async {
    final sources = _WordsTestSources();
    addTearDown(sources.close);

    await tester.pumpWidget(_buildWordsTestApp(sources, cacheKey: 'empty'));
    await tester.pump();
    sources.words.single.add(_queryResult(const [], confirmed: true));
    sources.reviews.single.add(
      _queryResult([_dueReview('due')], confirmed: true),
    );
    await tester.pump();

    final emptyRect = tester.getRect(find.byKey(wordsEmptyStateKey));
    expect(find.byKey(wordsEmptyStateKey), findsOneWidget);
    expect(find.byKey(reviewWordsBarSurfaceKey), findsNothing);
    expect(find.byKey(reviewWordsBarCountTextKey), findsNothing);
    expect(find.byKey(reviewWordsBarActionKey), findsNothing);

    sources.words.single.addError(StateError('empty refresh failed'));
    sources.reviews.single.addError(StateError('reviews refresh failed'));
    await tester.pump();

    expect(find.byKey(wordsEmptyStateKey), findsOneWidget);
    expect(find.byKey(wordsRefreshErrorIndicatorKey), findsOneWidget);
    expect(tester.getRect(find.byKey(wordsEmptyStateKey)), emptyRect);
    expect(find.byKey(reviewWordsBarSurfaceKey), findsNothing);
    expect(find.byKey(reviewWordsBarCountTextKey), findsNothing);
    expect(find.byKey(reviewWordsBarActionKey), findsNothing);
  });

  testWidgets('large review count keeps the repeat panel and CTA fixed',
      (tester) async {
    tester.view.physicalSize = const Size(240.0, 640.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sources = _WordsTestSources();
    addTearDown(sources.close);
    final reviews = List<WordReviewsRecord>.generate(
      100,
      (index) => _dueReview('large-$index'),
    );

    await tester.pumpWidget(
      _buildWordsTestApp(
        sources,
        cacheKey: 'large-review-count',
        textScaler: const TextScaler.linear(2.0),
      ),
    );
    await tester.pump();
    sources.words.single.add(
      _queryResult([_word('large', 'large word', 'большое слово')]),
    );
    sources.reviews.single.add(
      _queryResult(reviews.take(99).toList(), confirmed: true),
    );
    await tester.pump();

    final surfaceFinder = find.byKey(reviewWordsBarSurfaceKey);
    final actionFinder = find.byKey(reviewWordsBarActionKey);
    final countSlotFinder = find.byKey(reviewWordsBarCountSlotKey);
    final countFinder = find.byKey(reviewWordsBarCountTextKey);
    final surfaceRect = tester.getRect(surfaceFinder);
    final actionRect = tester.getRect(actionFinder);
    final countSlotRect = tester.getRect(countSlotFinder);

    expect(tester.widget<Text>(countFinder).data, '99 слов');
    expect(surfaceRect.size, const Size(208.0, reviewWordsBarHeight));
    expect(
      actionRect.size,
      const Size(reviewWordsBarActionWidth, reviewWordsBarActionHeight),
    );
    expect(actionRect.left, greaterThanOrEqualTo(countSlotRect.right));
    expect(actionRect.right, lessThanOrEqualTo(surfaceRect.right));
    expect(actionRect.top, greaterThanOrEqualTo(surfaceRect.top));
    expect(actionRect.bottom, lessThanOrEqualTo(surfaceRect.bottom));

    final actionTextFinder = find.descendant(
      of: actionFinder,
      matching: find.text('Повторить'),
    );
    final actionParagraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: actionTextFinder,
        matching: find.byType(RichText),
      ),
    );
    expect(actionParagraph.didExceedMaxLines, isFalse);

    sources.reviews.single.add(_queryResult(reviews, confirmed: true));
    await tester.pump();

    expect(tester.widget<Text>(countFinder).data, '99+ слов');
    expect(tester.getRect(surfaceFinder), surfaceRect);
    expect(tester.getRect(actionFinder), actionRect);
    expect(tester.getRect(countSlotFinder), countSlotRect);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeat panel consumes safe area once around keyboard insets',
      (tester) async {
    const outerScaffoldKey = ValueKey<String>('words_test_outer_scaffold');
    const bottomBarKey = ValueKey<String>('words_test_bottom_bar');
    const bottomBarHeight = 96.0;
    tester.view.physicalSize = const Size(390.0, 844.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sources = _WordsTestSources();
    addTearDown(sources.close);

    Widget buildWords({required bool keyboardOpen}) {
      return _buildWordsTestApp(
        sources,
        cacheKey: 'repeat-panel-insets',
        bottomInset: keyboardOpen ? 0 : 34,
        viewPaddingBottom: 34,
        viewInsetBottom: keyboardOpen ? 320 : 0,
        homeBuilder: (words) => Scaffold(
          key: outerScaffoldKey,
          extendBody: true,
          body: words,
          bottomNavigationBar: const SizedBox(
            key: bottomBarKey,
            height: bottomBarHeight,
          ),
        ),
      );
    }

    await tester.pumpWidget(buildWords(keyboardOpen: false));
    await tester.pump();
    sources.words.single.add(
      _queryResult([_word('insets', 'insets word', 'слово')]),
    );
    sources.reviews.single.add(
      _queryResult([_dueReview('insets')], confirmed: true),
    );
    await tester.pump();

    final scaffoldFinder = find.byKey(outerScaffoldKey);
    final bottomBarFinder = find.byKey(bottomBarKey);
    final surfaceFinder = find.byKey(reviewWordsBarSurfaceKey);
    final actionFinder = find.byKey(reviewWordsBarActionKey);
    final closedScaffoldRect = tester.getRect(scaffoldFinder);
    final closedBottomBarRect = tester.getRect(bottomBarFinder);
    final closedSurfaceRect = tester.getRect(surfaceFinder);
    final closedActionRect = tester.getRect(actionFinder);
    final platform = Theme.of(tester.element(surfaceFinder)).platform;
    final navClearance = platform == TargetPlatform.android ? 12.0 : 10.0;

    expect(
      closedSurfaceRect.size,
      const Size(358.0, reviewWordsBarHeight),
    );
    expect(
      closedActionRect.size,
      const Size(reviewWordsBarActionWidth, reviewWordsBarActionHeight),
    );
    expect(
      closedBottomBarRect.top - closedSurfaceRect.bottom,
      navClearance,
    );
    expect(closedBottomBarRect.bottom, closedScaffoldRect.bottom);

    await tester.pumpWidget(buildWords(keyboardOpen: true));
    await tester.pump();
    final openScaffoldRect = tester.getRect(scaffoldFinder);
    final openSurfaceRect = tester.getRect(surfaceFinder);
    final openActionRect = tester.getRect(actionFinder);

    expect(openSurfaceRect.size, closedSurfaceRect.size);
    expect(openActionRect.size, closedActionRect.size);
    expect(
      openScaffoldRect.bottom - 320 - openSurfaceRect.bottom,
      navClearance,
    );
    expect(
      closedSurfaceRect.bottom - openSurfaceRect.bottom,
      320 - bottomBarHeight,
    );
    expect(
      openActionRect.shift(-openSurfaceRect.topLeft),
      closedActionRect.shift(-closedSurfaceRect.topLeft),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('session cache is shown while refresh stays silent',
      (tester) async {
    final firstSources = _WordsTestSources();
    final secondSources = _WordsTestSources();
    addTearDown(firstSources.close);
    addTearDown(secondSources.close);

    await tester.pumpWidget(
      _buildWordsTestApp(firstSources, cacheKey: 'cached'),
    );
    await tester.pump();
    firstSources.reviews.single.add(_queryResult(const [], confirmed: true));
    firstSources.words.single.add(
      _queryResult([_word('cached', 'cached word', 'слово из кэша')]),
    );
    await tester.pump();
    expect(find.text('cached word'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      _buildWordsTestApp(secondSources, cacheKey: 'cached'),
    );
    await tester.pump();

    expect(find.text('cached word'), findsOneWidget);
    expect(find.byKey(wordsInitialLoadingKey), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('user data key change drops old rows and stale stream events',
      (tester) async {
    final sources = _WordsTestSources();
    addTearDown(sources.close);

    await tester.pumpWidget(_buildWordsTestApp(sources, cacheKey: 'user-a'));
    await tester.pump();
    sources.reviews.single.add(_queryResult(const [], confirmed: true));
    sources.words.single.add(
      _queryResult([_word('user-a', 'user A word', 'слово A')]),
    );
    await tester.pump();
    expect(find.text('user A word'), findsOneWidget);

    await tester.pumpWidget(_buildWordsTestApp(sources, cacheKey: 'user-b'));
    await tester.pump();

    expect(sources.words, hasLength(2));
    expect(find.text('user A word'), findsNothing);
    expect(find.byKey(wordsInitialLoadingKey), findsOneWidget);

    sources.words.first.add(
      _queryResult([_word('stale-a', 'stale A word', 'старое слово A')]),
    );
    sources.words.first.addError(StateError('stale user A error'));
    await tester.pump();

    expect(find.text('stale A word'), findsNothing);
    expect(find.byKey(wordsFullErrorStateKey), findsNothing);
    expect(find.byKey(wordsRefreshErrorIndicatorKey), findsNothing);

    sources.reviews.last.add(_queryResult(const [], confirmed: true));
    sources.words.last.add(
      _queryResult([_word('user-b', 'user B word', 'слово B')]),
    );
    await tester.pump();

    expect(find.text('user B word'), findsOneWidget);
    expect(find.text('user A word'), findsNothing);
  });
}

class _WordsTestSources {
  final List<StreamController<WordsQueryResult<UserWordsRecord>>> words = [];
  final List<StreamController<WordsQueryResult<WordReviewsRecord>>> reviews =
      [];

  Stream<WordsQueryResult<UserWordsRecord>> wordsFactory(
    DocumentReference? _,
  ) {
    final controller =
        StreamController<WordsQueryResult<UserWordsRecord>>.broadcast(
      sync: true,
    );
    words.add(controller);
    return controller.stream;
  }

  Stream<WordsQueryResult<WordReviewsRecord>> reviewsFactory(
    DocumentReference? _,
  ) {
    final controller =
        StreamController<WordsQueryResult<WordReviewsRecord>>.broadcast(
      sync: true,
    );
    reviews.add(controller);
    return controller.stream;
  }

  Future<void> close() async {
    for (final controller in [...words, ...reviews]) {
      await controller.close();
    }
  }
}

Widget _buildWordsTestApp(
  _WordsTestSources sources, {
  required String cacheKey,
  TextScaler textScaler = TextScaler.noScaling,
  double bottomInset = 0.0,
  double viewPaddingBottom = 0.0,
  double viewInsetBottom = 0.0,
  Widget Function(Widget words)? homeBuilder,
}) {
  final words = WordsWidget(
    sessionCacheKeyOverride: cacheKey,
    userReferenceProvider: _noUserReference,
    wordsStreamFactory: sources.wordsFactory,
    wordReviewsStreamFactory: sources.reviewsFactory,
  );
  return MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      FFLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FallbackMaterialLocalizationDelegate(),
      FallbackCupertinoLocalizationDelegate(),
    ],
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.only(bottom: bottomInset),
          viewPadding: EdgeInsets.only(bottom: viewPaddingBottom),
          viewInsets: EdgeInsets.only(bottom: viewInsetBottom),
          textScaler: textScaler,
        ),
        child: child!,
      );
    },
    home: homeBuilder?.call(words) ?? words,
  );
}

DocumentReference? _noUserReference() => null;

WordsQueryResult<T> _queryResult<T extends Object>(
  List<T> items, {
  bool confirmed = true,
}) {
  return WordsQueryResult<T>(
    items: items,
    isServerConfirmed: confirmed,
  );
}

String _wordPath(String id) => 'users/test/userWords/$id';

UserWordsRecord _word(
  String id,
  String source,
  String translation,
) {
  return UserWordsRecord.getDocumentFromData(
    <String, dynamic>{
      'entry': <Map<String, dynamic>>[
        <String, dynamic>{
          'text': source,
          'tr': <Map<String, dynamic>>[
            <String, dynamic>{'text': translation},
          ],
        },
      ],
    },
    FirebaseFirestore.instance.doc(_wordPath(id)),
  );
}

WordReviewsRecord _dueReview(String id) {
  return WordReviewsRecord.getDocumentFromData(
    <String, dynamic>{
      'dueAt': DateTime.now().subtract(const Duration(minutes: 1)),
    },
    FirebaseFirestore.instance.doc('users/test/wordReviews/$id'),
  );
}
