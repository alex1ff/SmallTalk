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
      contains('initialData: _cachedConversationsStateForUser(currentUid)'),
    );
    expect(
      source,
      contains('initialData: _cachedEventChatsStateForUser(currentUid)'),
    );
    expect(
      source,
      matches(
        RegExp(
          r'final conversationsLoading =\s*'
          r'conversationsSnapshot\.connectionState ==\s*'
          r'ConnectionState\.waiting &&\s*'
          r'conversationsState == null &&\s*'
          r'!conversationsSnapshot\.hasError;',
        ),
      ),
    );
    expect(
      source,
      isNot(contains('initialData: const _ConversationsLoadState()')),
    );
    expect(
      source,
      isNot(contains('initialData: const _EventChatsLoadState()')),
    );
  });
}
