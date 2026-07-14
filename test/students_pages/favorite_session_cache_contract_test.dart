import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('favorite required sources use metadata-aware raw snapshots', () {
    final source = File('lib/students_pages/favorite/favorite_widget.dart')
        .readAsStringSync();

    expect(
      RegExp(r'\.snapshots\(includeMetadataChanges: true\)').allMatches(source),
      hasLength(3),
    );
    expect(
      source,
      isNot(contains('transformFavoriteFirestoreSnapshots(sourceSnapshots)')),
    );
    expect(source, contains('_friendsStream = sourceSnapshots.map'));
    expect(
      source,
      contains('_conversationsStream = sourceSnapshots.map'),
    );
    expect(
      source,
      matches(
        RegExp(
          r'return snapshots\.map\(\s*'
          r'\(snapshot\) => EventInboxEventIdsLoadState\(',
        ),
      ),
    );
    expect(
      source,
      matches(
        RegExp(
          r'isAuthoritative:\s*'
          r'!snapshot\.isFromCache && !snapshot\.hasPendingWrites',
        ),
      ),
    );
    expect(source, isNot(contains('queryConversationsRecord(')));
    expect(
      source,
      contains('FirebaseAuth.instance.currentUser?.uid'),
    );
    expect(source, isNot(contains('initialData: currentUserUid')));
  });

  test('favorite inbox stores loaded chat sources in typed session cache', () {
    final source = File('lib/students_pages/favorite/favorite_widget.dart')
        .readAsStringSync();

    expect(
      source,
      contains('UxSessionLoadedResultCache<FavoriteConversationsLoadState>'),
    );
    expect(
      source,
      contains('UxSessionLoadedResultCache<FavoriteEventChatsLoadState>'),
    );
    expect(
      source,
      contains('UxLoadedResult<FavoriteConversationsLoadState>.data'),
    );
    expect(
      source,
      contains('UxLoadedResult<FavoriteEventChatsLoadState>.data'),
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
        source, isNot(contains('Map<String, FavoriteConversationsLoadState>')));
    expect(source, isNot(contains('Map<String, FavoriteEventChatsLoadState>')));
    expect(source, isNot(contains('_inboxItemsCacheByUid')));
  });

  test('favorite inbox uses cached chat sources as first stream data', () {
    final source = File('lib/students_pages/favorite/favorite_widget.dart')
        .readAsStringSync();

    expect(
      source,
      matches(
        RegExp(
          r'cachedState:\s*_initialConversationsStateForUser\(currentUid\)',
        ),
      ),
    );
    expect(
      source,
      matches(
        RegExp(
          r'cachedState:\s*_initialEventChatsStateForUser\(currentUid\)',
        ),
      ),
    );
    expect(
      source,
      matches(
        RegExp(
          r'cachedState:\s*_initialFriendsStateForUser\(currentUid\)',
        ),
      ),
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
      matches(
        RegExp(
          r'final messagesInitialLoading =\s*ownerMetadataLoading \|\|\s*'
          r'conversationsLoading \|\| eventChatsLoading;',
        ),
      ),
    );
    expect(
      source,
      matches(
        RegExp(
          r'if \(!ownerMetadataHasLoaded\) \{\s*'
          r'if \(!ownerMetadataLoadFailed\) \{\s*'
          r'return const SizedBox\.shrink\(\);',
        ),
      ),
    );
    expect(
      source,
      matches(
        RegExp(
          r'if \(messagesInitialLoading && inboxItems\.isEmpty\) \{\s*'
          r'return const SizedBox\.shrink\(\);',
        ),
      ),
    );

    final ownerGuardIndex = source.indexOf('if (!ownerMetadataHasLoaded)');
    final loadingGuardIndex =
        source.indexOf('if (messagesInitialLoading && inboxItems.isEmpty)');
    final emptyGuardIndex =
        source.indexOf('final content = inboxItems.isEmpty');
    expect(ownerGuardIndex, isNonNegative);
    expect(loadingGuardIndex, isNonNegative);
    expect(emptyGuardIndex, isNonNegative);
    expect(ownerGuardIndex, lessThan(loadingGuardIndex));
    expect(loadingGuardIndex, lessThan(emptyGuardIndex));
  });
}
