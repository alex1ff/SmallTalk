import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/shared_pages/chat_thread/chat_thread_widget.dart';

void main() {
  test('chat thread messages use session cache as initial stream data', () {
    final source = File('lib/shared_pages/chat_thread/chat_thread_widget.dart')
        .readAsStringSync();

    expect(
      source,
      contains('UxSessionLoadedResultCache<List<MessagesRecord>>'),
    );
    expect(
      source,
      contains('_messagesCacheByConversationPath.readItems'),
    );
    expect(
      source,
      contains('_messagesCacheByConversationPath.writeItems'),
    );
    expect(source, contains('currentUserUid'));
    expect(
      source,
      contains('initialData: _cachedMessages(conversation.reference)'),
    );
    expect(
      source,
      matches(
        RegExp(
          r'_rememberMessages\(\s*conversation\.reference,\s*confirmedMessages,',
        ),
      ),
    );
    expect(source, contains('messages == null || messages.isEmpty'));
    expect(source, contains('debugResetMessageCacheForTesting'));
    expect(source, contains('messagesSnapshot.data ??'));
    expect(source, contains('_cachedMessages(conversation.reference)'));
    expect(
        source, contains('final List<_PendingChatMessage> _pendingMessages'));
    expect(source, contains('_pendingMessages.add(pendingMessage)'));
    expect(
        source, contains('MessagesRecord.createDoc(conversation.reference)'));
    expect(source, contains('messageRef.set('));
    expect(source, contains('_displayMessages(serverMessages)'));
    expect(source, contains('_buildPendingMessageBubble('));
    expect(source, contains('_ChatThreadDisplayMessage.pending'));
    expect(
        source, contains('_schedulePruneConfirmedPendingMessages(messages)'));
    expect(source, contains('messages == null && _pendingMessages.isEmpty'));
    expect(
        source,
        contains(
            "record.createdAt != null || !pendingKeys.contains(record.key)"));
    expect(source, contains('final confirmedMessages = messages'));
    expect(source, contains('.where((message) => message.createdAt != null)'));
    expect(
      source,
      matches(
        RegExp(
          r'messagesSnapshot\.connectionState\s*!=\s*ConnectionState\.waiting',
        ),
      ),
    );
  });

  test('chat thread merge prunes confirmed pending and keeps newest first', () {
    final older = DateTime.utc(2026, 1, 1, 12);
    final middle = DateTime.utc(2026, 1, 1, 13);
    final newest = DateTime.utc(2026, 1, 1, 14);

    final merged = mergeChatThreadMessageItemsForTesting(
      records: <ChatThreadMessageMergeItem>[
        ChatThreadMessageMergeItem(
          key: 'conversations/1/messages/confirmed-pending',
          createdAt: middle,
          isPending: false,
        ),
        ChatThreadMessageMergeItem(
          key: 'conversations/1/messages/older-server',
          createdAt: older,
          isPending: false,
        ),
      ],
      pending: <ChatThreadMessageMergeItem>[
        ChatThreadMessageMergeItem(
          key: 'conversations/1/messages/confirmed-pending',
          createdAt: newest,
          isPending: true,
        ),
        ChatThreadMessageMergeItem(
          key: 'conversations/1/messages/new-pending',
          createdAt: newest,
          isPending: true,
        ),
      ],
    );

    expect(
      merged.map((item) => '${item.isPending}:${item.key}'),
      <String>[
        'true:conversations/1/messages/new-pending',
        'false:conversations/1/messages/confirmed-pending',
        'false:conversations/1/messages/older-server',
      ],
    );
  });

  test('chat thread merge keeps pending while local echo is unconfirmed', () {
    final createdAt = DateTime.utc(2026, 1, 1, 14);

    final merged = mergeChatThreadMessageItemsForTesting(
      records: const <ChatThreadMessageMergeItem>[
        ChatThreadMessageMergeItem(
          key: 'conversations/1/messages/local-echo',
          createdAt: null,
          isPending: false,
        ),
      ],
      pending: <ChatThreadMessageMergeItem>[
        ChatThreadMessageMergeItem(
          key: 'conversations/1/messages/local-echo',
          createdAt: createdAt,
          isPending: true,
        ),
      ],
    );

    expect(merged, hasLength(1));
    expect(merged.single.isPending, isTrue);
    expect(merged.single.key, 'conversations/1/messages/local-echo');
  });
}
