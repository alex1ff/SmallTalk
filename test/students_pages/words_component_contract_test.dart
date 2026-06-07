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
    expect(modelSource, contains('static List<UserWordsRecord>? _cachedWords'));
    expect(
      modelSource,
      contains('static List<WordReviewsRecord>? _cachedWordReviews'),
    );
  });
}
