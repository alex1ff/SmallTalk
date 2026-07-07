import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/students_pages/favorite/favorite_chat_source_state.dart';

void main() {
  test('favorite chat source resolver keeps cached state during refresh/error',
      () {
    final freshResolution = resolveFavoriteChatSourceSnapshot<String>(
      snapshot: const AsyncSnapshot<String>.withData(
        ConnectionState.active,
        'fresh',
      ),
      cachedState: 'cached',
    );
    expect(freshResolution.displayState, 'fresh');
    expect(freshResolution.isInitialLoading, isFalse);

    final waitingWithCacheResolution =
        resolveFavoriteChatSourceSnapshot<String>(
      snapshot: const AsyncSnapshot<String>.nothing()
          .inState(ConnectionState.waiting),
      cachedState: 'cached',
    );
    expect(waitingWithCacheResolution.displayState, 'cached');
    expect(waitingWithCacheResolution.isInitialLoading, isFalse);

    final waitingWithoutCacheResolution =
        resolveFavoriteChatSourceSnapshot<String>(
      snapshot: const AsyncSnapshot<String>.nothing()
          .inState(ConnectionState.waiting),
      cachedState: null,
    );
    expect(waitingWithoutCacheResolution.displayState, isNull);
    expect(waitingWithoutCacheResolution.isInitialLoading, isTrue);

    final errorWithCacheResolution = resolveFavoriteChatSourceSnapshot<String>(
      snapshot: AsyncSnapshot<String>.withError(
        ConnectionState.active,
        Exception('failed'),
      ),
      cachedState: 'cached',
    );
    expect(errorWithCacheResolution.displayState, 'cached');
    expect(errorWithCacheResolution.isInitialLoading, isFalse);
  });

  Widget harness({
    String sourceId = 'conversations',
    required String uid,
    required Stream<String> stream,
    required String? cachedState,
    void Function(AsyncSnapshot<String> snapshot)? onSnapshot,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: FavoriteChatSourceBuilder<String>(
        sourceId: sourceId,
        currentUid: uid,
        stream: stream,
        cachedState: cachedState,
        builder: (context, snapshot, resolution) {
          onSnapshot?.call(snapshot);
          final displayState = resolution.displayState;
          if (displayState != null) {
            return Text(displayState);
          }
          if (resolution.isInitialLoading) {
            return const Text('loading');
          }
          return const Text('empty');
        },
      ),
    );
  }

  testWidgets(
      'favorite chat source StreamBuilder keeps cached content on error',
      (tester) async {
    final controller = StreamController<String>(sync: true);
    final connectionStates = <ConnectionState>[];
    final hasErrors = <bool>[];
    addTearDown(controller.close);

    await tester.pumpWidget(
      harness(
        uid: 'user-a',
        stream: controller.stream,
        cachedState: 'cached',
        onSnapshot: (snapshot) {
          connectionStates.add(snapshot.connectionState);
          hasErrors.add(snapshot.hasError);
        },
      ),
    );

    expect(find.text('cached'), findsOneWidget);
    expect(connectionStates, contains(ConnectionState.waiting));

    controller.addError(Exception('failed'));
    await tester.pump();
    await tester.pump();

    expect(find.text('cached'), findsOneWidget);
    expect(find.text('loading'), findsNothing);
    expect(find.text('empty'), findsNothing);
    expect(hasErrors, contains(isTrue));

    controller.add('fresh');
    await tester.pump();

    expect(find.text('fresh'), findsOneWidget);
    expect(find.text('cached'), findsNothing);
    expect(connectionStates, contains(ConnectionState.active));
  });

  testWidgets('favorite chat source keeps fresh state after later error',
      (tester) async {
    final controller = StreamController<String>(sync: true);
    addTearDown(controller.close);

    await tester.pumpWidget(
      harness(
        uid: 'user-a',
        stream: controller.stream,
        cachedState: null,
      ),
    );
    expect(find.text('loading'), findsOneWidget);

    controller.add('fresh-a');
    await tester.pump();
    expect(find.text('fresh-a'), findsOneWidget);

    controller.addError(Exception('failed'));
    await tester.pump();
    await tester.pump();

    expect(find.text('fresh-a'), findsOneWidget);
    expect(find.text('loading'), findsNothing);
    expect(find.text('empty'), findsNothing);
  });

  testWidgets(
      'favorite chat source does not roll back to old cache after error',
      (tester) async {
    final controller = StreamController<String>(sync: true);
    addTearDown(controller.close);

    await tester.pumpWidget(
      harness(
        uid: 'user-a',
        stream: controller.stream,
        cachedState: 'old-cache',
      ),
    );
    expect(find.text('old-cache'), findsOneWidget);

    controller.add('fresh-a');
    await tester.pump();
    expect(find.text('fresh-a'), findsOneWidget);
    expect(find.text('old-cache'), findsNothing);

    controller.addError(Exception('failed'));
    await tester.pump();
    await tester.pump();

    expect(find.text('fresh-a'), findsOneWidget);
    expect(find.text('old-cache'), findsNothing);
  });

  testWidgets('favorite chat source key prevents stale data after uid change',
      (tester) async {
    final userAController = StreamController<String>(sync: true);
    final userBController = StreamController<String>(sync: true);
    addTearDown(userAController.close);
    addTearDown(userBController.close);

    await tester.pumpWidget(
      harness(
        uid: 'user-a',
        stream: userAController.stream,
        cachedState: 'cached-a',
      ),
    );
    expect(find.text('cached-a'), findsOneWidget);

    userAController.add('fresh-a');
    await tester.pump();
    expect(find.text('fresh-a'), findsOneWidget);

    await tester.pumpWidget(
      harness(
        uid: 'user-b',
        stream: userBController.stream,
        cachedState: null,
      ),
    );

    expect(find.text('fresh-a'), findsNothing);
    expect(find.text('cached-a'), findsNothing);
    expect(find.text('loading'), findsOneWidget);

    userBController.add('fresh-b');
    await tester.pump();
    expect(find.text('fresh-b'), findsOneWidget);
  });

  testWidgets(
      'favorite chat source key prevents stale data after source change',
      (tester) async {
    final conversationsController = StreamController<String>(sync: true);
    final eventChatsController = StreamController<String>(sync: true);
    addTearDown(conversationsController.close);
    addTearDown(eventChatsController.close);

    await tester.pumpWidget(
      harness(
        sourceId: 'conversations',
        uid: 'user-a',
        stream: conversationsController.stream,
        cachedState: 'cached-conversations',
      ),
    );
    expect(find.text('cached-conversations'), findsOneWidget);

    conversationsController.add('fresh-conversations');
    await tester.pump();
    expect(find.text('fresh-conversations'), findsOneWidget);

    await tester.pumpWidget(
      harness(
        sourceId: 'event-chats',
        uid: 'user-a',
        stream: eventChatsController.stream,
        cachedState: null,
      ),
    );

    expect(find.text('fresh-conversations'), findsNothing);
    expect(find.text('cached-conversations'), findsNothing);
    expect(find.text('loading'), findsOneWidget);

    eventChatsController.add('fresh-event-chats');
    await tester.pump();
    expect(find.text('fresh-event-chats'), findsOneWidget);
  });
}
