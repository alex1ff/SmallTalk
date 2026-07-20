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
    expect(source, contains('UxSessionCacheLifecycle.register'));
    expect(source, contains('UxSessionCacheLifecycle.updateAuthenticatedUser'));
    expect(source, contains('_messagesCacheKey(ownerUid, eventId)'));
    expect(source, contains('_authenticatedOwnerUid() == ownerUid'));
    expect(
      source,
      contains('initialData: _cachedMessagesState(ownerUid, eventId)'),
    );
    expect(source, contains('if (messages == null)'));
    expect(source, contains('debugResetMessageCacheForTesting'));
    expect(
      source,
      contains('final messageState = _displayedMessagesState('),
    );
    expect(source, contains('incomingState: snapshot.data'));
    expect(source, contains('cachedState: cachedState'));
    expect(source, contains('_lastDisplayedMessagesScope == scope'));
    expect(
      source,
      contains('_rememberMessages('),
    );
    expect(source, contains('_schedulePruneConfirmedPendingMessages'));
    expect(source, contains('ChatLocalMessageStatus.sending'));
    expect(source, contains('ChatLocalMessageStatus.sent'));
    expect(source, contains('ChatLocalMessageStatus.failed'));
    expect(source, contains('ChatLocalMessageStatusIcon'));
    expect(source, isNot(contains('accessStateInvoker')));
    expect(source, contains('eventGroupChatMessageItemKey'));
    expect(
        source, contains('key: eventGroupChatMessageItemKey(message.itemKey)'));
    expect(source, contains('id: message.localId'));
    expect(source, contains('itemKey: message.localId'));
    expect(source, contains('eventGroupChatMessageRetryButtonKey'));
    expect(source, contains('_retryPendingMessage'));
    expect(source, contains('ruText: \'Повторить\''));
    expect(source, contains('enText: \'Retry\''));
    expect(source, contains('if (snapshot.hasData)'));
    expect(source, contains('if (messageState!.isAuthoritative)'));
    expect(source, contains('eventGroupChatMessagesInlineErrorKey'));
    expect(source, contains('_retryMessages'));
  });
}
