import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('words page delegates visual rows and review bar to flat components',
      () {
    final pageSource =
        File('lib/students_pages/words/words_widget.dart').readAsStringSync();

    expect(pageSource, contains("'/components/dictionary_word_row.dart'"));
    expect(pageSource, contains("'/components/review_words_bar.dart'"));
    expect(pageSource, contains('DictionaryWordRow('));
    expect(pageSource, contains('ReviewWordsBar('));
    expect(pageSource, isNot(contains('class _DictionaryWordRow')));
    expect(pageSource, isNot(contains('class _ReviewWordsBar')));
  });

  test('words page uses retained cache before a cold-only loading state', () {
    final pageSource =
        File('lib/students_pages/words/words_widget.dart').readAsStringSync();
    final modelSource =
        File('lib/students_pages/words/words_model.dart').readAsStringSync();

    expect(pageSource, contains("'/components/app_loading_indicator.dart'"));
    expect(pageSource, contains('wordsInitialLoadingKey'));
    expect(pageSource, contains('_RetainedWordsQueryBuilder'));
    expect(pageSource, contains('initialItems: _model.cachedWords'));
    expect(pageSource, contains('initialItems: _model.cachedWordReviews'));
    expect(
      pageSource,
      contains('onAcceptedItems: _model.cacheWordReviews'),
    );
    expect(
      pageSource,
      contains('onAcceptedItems: _model.cacheWords'),
    );
    expect(pageSource, contains('UxLoadingState<List<T>>.resolve'));
    expect(
      modelSource,
      contains('UxSessionLoadedResultCache<List<UserWordsRecord>>'),
    );
    expect(
      modelSource,
      contains('UxSessionLoadedResultCache<List<WordReviewsRecord>>'),
    );
    expect(
      modelSource,
      isNot(contains('static List<UserWordsRecord>? _cachedWords')),
    );
    expect(
      modelSource,
      isNot(contains('static List<WordReviewsRecord>? _cachedWordReviews')),
    );
  });

  test('words review bar uses a compact count label', () {
    final pageSource =
        File('lib/students_pages/words/words_widget.dart').readAsStringSync();

    expect(pageSource, isNot(contains('к повторению')));
  });

  test('words page reserves the named review bar height', () {
    final pageSource =
        File('lib/students_pages/words/words_widget.dart').readAsStringSync();

    expect(
      pageSource,
      contains('reviewWordsBarHeight +\n        ExpatlioDesign.space16'),
    );
    expect(
      pageSource,
      contains('_reviewBarFadeExtraHeight'),
    );
    expect(pageSource, isNot(contains('+ 76.0')));
    expect(pageSource, isNot(contains('+ 96.0')));
  });

  test('words page separates rows with a simple divider', () {
    final pageSource =
        File('lib/students_pages/words/words_widget.dart').readAsStringSync();

    expect(pageSource, contains('content = ListView.separated('));
    expect(pageSource, contains('itemCount: words.length'));
    expect(pageSource, contains('separatorBuilder:'));
    expect(pageSource, contains('Divider('));
    expect(pageSource, contains('height: 1.0'));
    expect(pageSource, contains('thickness: 1.0'));
    expect(pageSource, contains('ExpatlioDesign.border'));
  });
}
