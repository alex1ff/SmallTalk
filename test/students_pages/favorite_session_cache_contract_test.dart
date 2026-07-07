import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('favorite inbox stores loaded chat sources in typed session cache', () {
    final source = File('lib/students_pages/favorite/favorite_widget.dart')
        .readAsStringSync();

    expect(
      source,
      contains('UxSessionLoadedResultCache<_ConversationsLoadState>'),
    );
    expect(
      source,
      contains('UxSessionLoadedResultCache<_EventChatsLoadState>'),
    );
    expect(
      source,
      contains('UxLoadedResult<_ConversationsLoadState>.data'),
    );
    expect(
      source,
      contains('UxLoadedResult<_EventChatsLoadState>.data'),
    );
    expect(
      source,
      matches(
        RegExp(
          r'Object _conversationStateCacheKey\(String currentUid\) => \[\s*'
          r"'favoriteConversations',\s*currentUid,\s*\];",
        ),
      ),
    );
    expect(
      source,
      matches(
        RegExp(
          r'Object _eventChatsStateCacheKey\(String currentUid\) => \[\s*'
          r"'favoriteEventChats',\s*currentUid,\s*\];",
        ),
      ),
    );
    expect(
      source,
      isNot(contains('Map<String, _ConversationsLoadState>')),
    );
    expect(
      source,
      isNot(contains('Map<String, _EventChatsLoadState>')),
    );
    expect(source, isNot(contains('_inboxItemsCacheByUid')));
  });

  test('favorite inbox uses cached chat sources as first stream data', () {
    final source = File('lib/students_pages/favorite/favorite_widget.dart')
        .readAsStringSync();

    expect(
      source,
      contains('cachedState: _cachedConversationsStateForUser(currentUid)'),
    );
    expect(
      source,
      contains('cachedState: _cachedEventChatsStateForUser(currentUid)'),
    );
    expect(
      source,
      isNot(contains('cachedState: const _ConversationsLoadState()')),
    );
    expect(
      source,
      isNot(contains('cachedState: const _EventChatsLoadState()')),
    );
  });

  test('favorite inbox does not show empty before chat sources load', () {
    final source = File('lib/students_pages/favorite/favorite_widget.dart')
        .readAsStringSync();

    expect(
      source,
      contains(
        'final messagesInitialLoading = conversationsLoading || eventChatsLoading;',
      ),
    );
    expect(
      source,
      contains('if (messagesInitialLoading && inboxItems.isEmpty)'),
    );

    final loadingGuardIndex =
        source.indexOf('if (messagesInitialLoading && inboxItems.isEmpty)');
    final emptyGuardIndex = source.indexOf('if (inboxItems.isEmpty)');
    expect(loadingGuardIndex, isNonNegative);
    expect(emptyGuardIndex, isNonNegative);
    expect(loadingGuardIndex, lessThan(emptyGuardIndex));
  });
}
