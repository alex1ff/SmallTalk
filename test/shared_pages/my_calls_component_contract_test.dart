import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('my calls page delegates call row visuals to flat component', () {
    final pageSource =
        File('lib/shared_pages/my_calls/my_calls_widget.dart')
            .readAsStringSync();

    expect(pageSource, contains("'/components/call_history_card.dart'"));
    expect(pageSource, contains('CallHistoryCard('));
    expect(pageSource, isNot(contains('class _CallHistoryCard')));
    expect(pageSource, contains('AppLoadingIndicator()'));
  });
}
