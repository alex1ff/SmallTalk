import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/students_pages/favorite/favorite_widget.dart';

void main() {
  test('remembered event chats unhide server-hidden event chat keys', () {
    final hiddenKeys = resolveFavoriteEffectiveHiddenChatKeys(
      rawHiddenChatKeys: const [
        'event:event-1',
        ' conversation:conversation-1 ',
        '',
        42,
      ],
      rememberedEventIds: const ['event-1'],
    );

    expect(hiddenKeys, isNot(contains('event:event-1')));
    expect(hiddenKeys, contains('conversation:conversation-1'));
  });

  test('optimistic hidden keys win over remembered event chat ids', () {
    final hiddenKeys = resolveFavoriteEffectiveHiddenChatKeys(
      rawHiddenChatKeys: const ['event:event-1'],
      rememberedEventIds: const ['event-1'],
      optimisticHiddenKeys: const [' event:event-1 '],
    );

    expect(hiddenKeys, contains('event:event-1'));
  });

  test('optimistic event chat hide works before server snapshot updates', () {
    final hiddenKeys = resolveFavoriteEffectiveHiddenChatKeys(
      rawHiddenChatKeys: const [],
      rememberedEventIds: const ['event-1'],
      optimisticHiddenKeys: const ['event:event-1'],
    );

    expect(hiddenKeys, contains('event:event-1'));
  });

  test('optimistic private chat hide works before server snapshot updates', () {
    final hiddenKeys = resolveFavoriteEffectiveHiddenChatKeys(
      rawHiddenChatKeys: const [],
      optimisticHiddenKeys: const ['conversation:conversation-1'],
    );

    expect(hiddenKeys, contains('conversation:conversation-1'));
  });

  test('removing optimistic hidden key makes rollback show chat again', () {
    final hiddenDuringDelete = resolveFavoriteEffectiveHiddenChatKeys(
      rawHiddenChatKeys: const ['event:event-1'],
      rememberedEventIds: const ['event-1'],
      optimisticHiddenKeys: const ['event:event-1'],
    );
    final hiddenAfterRollback = resolveFavoriteEffectiveHiddenChatKeys(
      rawHiddenChatKeys: const ['event:event-1'],
      rememberedEventIds: const ['event-1'],
    );

    expect(hiddenDuringDelete, contains('event:event-1'));
    expect(hiddenAfterRollback, isNot(contains('event:event-1')));
  });

  test('successful event chat hide survives remembered id until server unhide',
      () {
    var syncResult = syncFavoriteOptimisticHiddenChatKeys(
      optimisticHiddenKeys: const ['event:event-1'],
      serverConfirmedOptimisticHiddenKeys: const {},
      serverHiddenKeys: const {},
    );

    expect(syncResult.optimisticHiddenKeys, contains('event:event-1'));
    expect(syncResult.serverConfirmedOptimisticHiddenKeys, isEmpty);
    expect(
      resolveFavoriteEffectiveHiddenChatKeys(
        rawHiddenChatKeys: const [],
        rememberedEventIds: const ['event-1'],
        optimisticHiddenKeys: syncResult.optimisticHiddenKeys,
      ),
      contains('event:event-1'),
    );

    syncResult = syncFavoriteOptimisticHiddenChatKeys(
      optimisticHiddenKeys: syncResult.optimisticHiddenKeys,
      serverConfirmedOptimisticHiddenKeys:
          syncResult.serverConfirmedOptimisticHiddenKeys,
      serverHiddenKeys: const {'event:event-1'},
    );

    expect(syncResult.optimisticHiddenKeys, contains('event:event-1'));
    expect(
      syncResult.serverConfirmedOptimisticHiddenKeys,
      contains('event:event-1'),
    );
    expect(
      resolveFavoriteEffectiveHiddenChatKeys(
        rawHiddenChatKeys: const {'event:event-1'},
        rememberedEventIds: const ['event-1'],
        optimisticHiddenKeys: syncResult.optimisticHiddenKeys,
      ),
      contains('event:event-1'),
    );

    syncResult = syncFavoriteOptimisticHiddenChatKeys(
      optimisticHiddenKeys: syncResult.optimisticHiddenKeys,
      serverConfirmedOptimisticHiddenKeys:
          syncResult.serverConfirmedOptimisticHiddenKeys,
      serverHiddenKeys: const {},
    );

    expect(syncResult.optimisticHiddenKeys, isEmpty);
    expect(syncResult.serverConfirmedOptimisticHiddenKeys, isEmpty);
    expect(
      resolveFavoriteEffectiveHiddenChatKeys(
        rawHiddenChatKeys: const [],
        rememberedEventIds: const ['event-1'],
        optimisticHiddenKeys: syncResult.optimisticHiddenKeys,
      ),
      isNot(contains('event:event-1')),
    );
  });
}
