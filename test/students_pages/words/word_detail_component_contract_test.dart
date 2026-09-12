import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('word detail page delegates visual body to flat component', () {
    final pageSource =
        File('lib/students_pages/words/word_detail_widget.dart')
            .readAsStringSync();

    expect(pageSource, contains("'/components/word_detail_body.dart'"));
    expect(pageSource, contains('WordDetailBody(content: content)'));
    expect(pageSource, isNot(contains('class _WordDetailBody')));
    expect(pageSource, isNot(contains('class _TranslationDetails')));
    expect(pageSource, isNot(contains('class _SynonymChip')));
    expect(pageSource, isNot(contains('class _ExampleCard')));
  });
}
