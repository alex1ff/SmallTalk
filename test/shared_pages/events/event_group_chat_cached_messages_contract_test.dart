import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event group chat messages use session cache as initial stream data',
      () {
    final source = File('lib/shared_pages/events/event_group_chat_widget.dart')
        .readAsStringSync();

    expect(
      source,
      contains('UxSessionLoadedResultCache<List<EventChatMessagesRecord>>'),
    );
    expect(source, contains('_messagesCacheByEventId.readItems'));
    expect(source, contains('_messagesCacheByEventId.writeItems'));
    expect(source, contains('currentUserUid'));
    expect(source, contains('initialData: _cachedMessages(widget.eventId)'));
    expect(source, contains('messages == null || messages.isEmpty'));
    expect(source, contains('debugResetMessageCacheForTesting'));
    expect(
        source, contains('snapshot.data ?? _cachedMessages(widget.eventId)'));
    expect(
        source, contains('_rememberMessages(widget.eventId, messageRecords)'));
    expect(source, contains('_schedulePruneConfirmedPendingMessages'));
    expect(source, contains('ChatLocalMessageStatus.sending'));
    expect(source, contains('ChatLocalMessageStatus.sent'));
    expect(source, contains('ChatLocalMessageStatus.failed'));
    expect(source, contains('ChatLocalMessageStatusIcon'));
    expect(source, contains('eventGroupChatMessageItemKey'));
    expect(
        source, contains('key: eventGroupChatMessageItemKey(message.itemKey)'));
    expect(source, contains('id: message.localId'));
    expect(source, contains('itemKey: message.localId'));
    expect(source, contains('eventGroupChatMessageRetryButtonKey'));
    expect(source, contains('_retryPendingMessage'));
    expect(source, contains('ruText: \'Повторить\''));
    expect(source, contains('enText: \'Retry\''));
    expect(
      source,
      matches(
        RegExp(
          r'snapshot\.connectionState\s*!=\s*ConnectionState\.waiting',
        ),
      ),
    );
  });
}
