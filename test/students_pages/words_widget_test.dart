import 'dart:async';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
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
    final reviewBarRect = tester.getRect(find.byKey(reviewWordsBarSurfaceKey));

    expect(find.byKey(wordsInitialLoadingKey), findsOneWidget);
    expect(find.byKey(wordsEmptyStateKey), findsNothing);
    expect(find.byKey(wordsFullErrorStateKey), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(reviewWordsBarCountTextKey)).data,
      '—',
    );

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
    expect(tester.getRect(find.byKey(reviewWordsBarSurfaceKey)), reviewBarRect);
    expect(
      tester.widget<Text>(find.byKey(reviewWordsBarCountTextKey)).data,
      '0',
    );
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
    final reviewBarRect = tester.getRect(find.byKey(reviewWordsBarSurfaceKey));

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
    expect(tester.getRect(find.byKey(reviewWordsBarSurfaceKey)), reviewBarRect);
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
    expect(find.byKey(wordsRefreshingIndicatorKey), findsOneWidget);
    expect(
        tester.getRect(find.byKey(wordsRowKey(_wordPath('shown')))), rowRect);

    sources.reviews.last.add(_queryResult(const [], confirmed: true));
    sources.words.last.add(
      _queryResult([_word('updated', 'updated word', 'обновлённое слово')]),
    );
    await tester.pump();

    expect(find.text('shown word'), findsNothing);
    expect(find.text('updated word'), findsOneWidget);
    expect(find.byKey(wordsRefreshingIndicatorKey), findsNothing);
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

    expect(find.byKey(wordsRefreshingIndicatorKey), findsOneWidget);
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
    expect(find.byKey(wordsRefreshingIndicatorKey), findsOneWidget);

    sources.words.single.add(_queryResult(const [], confirmed: true));
    await tester.pump();

    expect(find.text('kept word'), findsNothing);
    expect(find.byKey(wordsEmptyStateKey), findsOneWidget);
    expect(find.byKey(wordsRefreshingIndicatorKey), findsNothing);
  });

  testWidgets('cold error stays above the review bar in a compact viewport',
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
    final reviewBarRect = tester.getRect(find.byKey(reviewWordsBarSurfaceKey));
    expect(retryRect.bottom, lessThanOrEqualTo(reviewBarRect.top));
  });

  testWidgets('empty state stays scrollable above the compact review bar',
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
    final reviewBarRect = tester.getRect(find.byKey(reviewWordsBarSurfaceKey));
    expect(messageRect.bottom, lessThanOrEqualTo(reviewBarRect.top));

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

  testWidgets('empty and review data survive their stream errors',
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
    expect(
      tester.widget<Text>(find.byKey(reviewWordsBarCountTextKey)).data,
      '1',
    );
    expect(find.byKey(reviewWordsBarActionKey), findsOneWidget);

    sources.words.single.addError(StateError('empty refresh failed'));
    sources.reviews.single.addError(StateError('reviews refresh failed'));
    await tester.pump();

    expect(find.byKey(wordsEmptyStateKey), findsOneWidget);
    expect(find.byKey(wordsRefreshErrorIndicatorKey), findsOneWidget);
    expect(tester.getRect(find.byKey(wordsEmptyStateKey)), emptyRect);
    expect(
      tester.widget<Text>(find.byKey(reviewWordsBarCountTextKey)).data,
      '1',
    );
    expect(find.byKey(reviewWordsBarActionKey), findsOneWidget);
  });

  testWidgets('session cache is shown while replacement streams reconnect',
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
    expect(find.byKey(wordsRefreshingIndicatorKey), findsOneWidget);
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
}) {
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
          textScaler: textScaler,
        ),
        child: child!,
      );
    },
    home: WordsWidget(
      sessionCacheKeyOverride: cacheKey,
      userReferenceProvider: _noUserReference,
      wordsStreamFactory: sources.wordsFactory,
      wordReviewsStreamFactory: sources.reviewsFactory,
    ),
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
