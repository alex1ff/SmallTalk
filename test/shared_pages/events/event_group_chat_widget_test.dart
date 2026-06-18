import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/shared_pages/events/event_group_chat_widget.dart';

void main() {
  test('event group chat is an event-specific wrapper', () {
    expect(EventGroupChatWidget.routeName, 'eventGroupChat');
    expect(EventGroupChatWidget.routePath, '/events/:eventId/chat');

    final source = File('lib/shared_pages/events/event_group_chat_widget.dart')
        .readAsStringSync();

    expect(source, contains('event-specific surface'));
    expect(source, isNot(contains('openChatThread')));
    expect(source, isNot(contains('ChatThreadWidget')));
    expect(source, isNot(contains('ConversationsRecord')));
    expect(source, isNot(contains('MessagesRecord')));
  });
}
