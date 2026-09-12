import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/students_pages/favorite/favorite_chat_source_state.dart';

typedef _OwnedValue = ({String ownerUid, String value});

void main() {
  test('owner-scoped source drops late A1 data and error after A to B to A2',
      () async {
    final a1 = StreamController<_OwnedValue>(sync: true);
    final b = StreamController<_OwnedValue>(sync: true);
    final a2 = StreamController<_OwnedValue>(sync: true);
    addTearDown(a1.close);
    addTearDown(b.close);
    addTearDown(a2.close);
    var generation = 1;
    var activeOwnerUid = 'user-a';
    final values = <String>[];
    final errors = <Object>[];

    StreamSubscription<_OwnedValue> subscribe(
      StreamController<_OwnedValue> controller,
      String ownerUid,
    ) {
      final sourceGeneration = generation;
      return guardFavoriteOwnerScopedSource<_OwnedValue>(
        source: controller.stream,
        expectedOwnerUid: ownerUid,
        sourceGeneration: sourceGeneration,
        currentGeneration: () => generation,
        ownerIsCurrent: (candidate) => candidate == activeOwnerUid,
        ownerUidOf: (value) => value.ownerUid,
      ).listen(
        (value) => values.add(value.value),
        onError: errors.add,
      );
    }

    final a1Subscription = subscribe(a1, 'user-a');
    addTearDown(a1Subscription.cancel);
    generation = 2;
    activeOwnerUid = 'user-b';
    final bSubscription = subscribe(b, 'user-b');
    addTearDown(bSubscription.cancel);
    generation = 3;
    activeOwnerUid = 'user-a';
    final a2Subscription = subscribe(a2, 'user-a');
    addTearDown(a2Subscription.cancel);

    a1.add((ownerUid: 'user-a', value: 'late-a1'));
    a1.addError(StateError('late A1 error'));
    b.add((ownerUid: 'user-b', value: 'late-b'));
    a2.add((ownerUid: 'user-a', value: 'fresh-a2'));
    await pumpEventQueue();

    expect(values, ['fresh-a2']);
    expect(errors, isEmpty);
  });

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

  testWidgets('cached empty stays loading until server-confirmed empty',
      (tester) async {
    final controller =
        StreamController<FavoriteFirestoreSourceSnapshot<List<String>>>(
            sync: true);
    addTearDown(controller.close);
    final stream = transformFavoriteFirestoreSnapshots(controller.stream)
        .map((snapshot) => snapshot.value);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: FavoriteChatSourceBuilder<List<String>>(
          sourceId: 'friends',
          currentUid: 'user-a',
          stream: stream,
          cachedState: null,
          builder: (context, snapshot, resolution) {
            if (snapshot.hasError) {
              return const Text('error');
            }
            final state = resolution.displayState;
            if (state != null) {
              return Text(state.isEmpty ? 'empty' : 'data');
            }
            return const Text('loading');
          },
        ),
      ),
    );
    expect(find.text('loading'), findsOneWidget);

    controller.add(
      const FavoriteFirestoreSourceSnapshot<List<String>>(
        value: <String>[],
        isEmpty: true,
        isFromCache: true,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.text('loading'), findsOneWidget);
    expect(find.text('empty'), findsNothing);

    controller.add(
      const FavoriteFirestoreSourceSnapshot<List<String>>(
        value: <String>[],
        isEmpty: true,
        isFromCache: false,
        hasPendingWrites: true,
      ),
    );
    await tester.pump();
    expect(find.text('loading'), findsOneWidget);
    expect(find.text('empty'), findsNothing);

    controller.add(
      const FavoriteFirestoreSourceSnapshot<List<String>>(
        value: <String>[],
        isEmpty: true,
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
    await tester.pump();
    expect(find.text('loading'), findsNothing);
    expect(find.text('empty'), findsOneWidget);
  });

  testWidgets('cold transformed source error remains an error, not empty',
      (tester) async {
    final controller =
        StreamController<FavoriteFirestoreSourceSnapshot<List<String>>>(
            sync: true);
    addTearDown(controller.close);
    final stream = transformFavoriteFirestoreSnapshots(controller.stream)
        .map((snapshot) => snapshot.value);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: FavoriteChatSourceBuilder<List<String>>(
          sourceId: 'conversations',
          currentUid: 'user-a',
          stream: stream,
          cachedState: null,
          builder: (context, snapshot, resolution) {
            if (snapshot.hasError) {
              return const Text('error');
            }
            if (resolution.displayState != null) {
              return const Text('empty');
            }
            return const Text('loading');
          },
        ),
      ),
    );

    controller.addError(StateError('source failed'));
    await tester.pump();
    expect(find.text('error'), findsOneWidget);
    expect(find.text('empty'), findsNothing);
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
    final logoutController = StreamController<String>(sync: true);
    addTearDown(userAController.close);
    addTearDown(userBController.close);
    addTearDown(logoutController.close);

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

    userAController.add('late-a');
    await tester.pump();
    expect(find.text('late-a'), findsNothing);
    expect(find.text('loading'), findsOneWidget);

    userBController.add('fresh-b');
    await tester.pump();
    expect(find.text('fresh-b'), findsOneWidget);

    await tester.pumpWidget(
      harness(
        uid: '',
        stream: logoutController.stream,
        cachedState: null,
      ),
    );
    expect(find.text('fresh-b'), findsNothing);
    expect(find.text('loading'), findsOneWidget);

    userBController.add('late-b');
    await tester.pump();
    expect(find.text('late-b'), findsNothing);
    expect(find.text('loading'), findsOneWidget);
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
