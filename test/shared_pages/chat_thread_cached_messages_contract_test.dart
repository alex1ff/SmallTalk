import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
      contains('_rememberMessages(conversation.reference, messages)'),
    );
    expect(source, contains('messages == null || messages.isEmpty'));
    expect(source, contains('debugResetMessageCacheForTesting'));
    expect(
      source,
      matches(
        RegExp(
          r'messagesSnapshot\.connectionState\s*!=\s*ConnectionState\.waiting',
        ),
      ),
    );
  });
}
