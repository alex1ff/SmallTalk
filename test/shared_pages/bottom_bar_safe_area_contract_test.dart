import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bottom bars use a keyboard-aware safe area padding helper', () {
    final designSource =
        File('lib/shared_pages/design/expatlio_design.dart').readAsStringSync();
    final chatComposerSource =
        File('lib/components/chat_composer.dart').readAsStringSync();
    final privateChatSource =
        File('lib/shared_pages/chat_thread/chat_thread_widget.dart')
            .readAsStringSync();
    final eventChatSource =
        File('lib/shared_pages/events/event_group_chat_widget.dart')
            .readAsStringSync();
    final eventCreateSource =
        File('lib/shared_pages/events/event_create_widget.dart')
            .readAsStringSync();
    final eventDetailSource =
        File('lib/shared_pages/events/event_detail_widget.dart')
            .readAsStringSync();

    expect(designSource, contains('bottomBarSafePadding'));
    expect(designSource, contains('mediaQuery.viewInsets.bottom > 0'));
    expect(designSource, contains('mediaQuery.viewPadding.bottom'));
    expect(chatComposerSource, contains('bottomBarSafePadding(context)'));
    expect(privateChatSource, contains('ChatComposer('));
    expect(eventChatSource, contains('ChatComposer('));
    expect(eventCreateSource, contains('bottomBarSafePadding(context)'));
    expect(eventDetailSource, contains('bottomBarSafePadding(context)'));
    expect(eventCreateSource, contains('bottom: false'));
    expect(eventDetailSource, contains('bottom: false'));
  });
}
