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

  test('words page renders cached stream data instead of a loading spinner',
      () {
    final pageSource =
        File('lib/students_pages/words/words_widget.dart').readAsStringSync();
    final modelSource =
        File('lib/students_pages/words/words_model.dart').readAsStringSync();

    expect(pageSource,
        isNot(contains("'/components/app_loading_indicator.dart'")));
    expect(pageSource, isNot(contains('AppLoadingIndicator')));
    expect(pageSource, contains('initialData: _model.cachedWords'));
    expect(pageSource, contains('initialData: _model.cachedWordReviews'));
    expect(
      pageSource,
      contains('WordsModel.shouldCacheStreamSnapshot(reviewSnapshot)'),
    );
    expect(
      pageSource,
      contains('WordsModel.shouldCacheStreamSnapshot(snapshot)'),
    );
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

  test('words page separates rows with a simple divider', () {
    final pageSource =
        File('lib/students_pages/words/words_widget.dart').readAsStringSync();

    expect(pageSource, contains('return ListView.separated('));
    expect(pageSource, contains('itemCount: words.length'));
    expect(pageSource, contains('separatorBuilder:'));
    expect(pageSource, contains('Divider('));
    expect(pageSource, contains('height: 1.0'));
    expect(pageSource, contains('thickness: 1.0'));
    expect(pageSource, contains('ExpatlioDesign.border'));
  });
}
