import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/ux_async_snapshot_state.dart';

void main() {
  test('display snapshot resolver keeps cached state during refresh/error', () {
    final freshResolution = uxResolveDisplayStateForSnapshot<String>(
      snapshot: const AsyncSnapshot<String>.withData(
        ConnectionState.active,
        'fresh',
      ),
      cachedState: 'cached',
    );
    expect(freshResolution.displayState, 'fresh');
    expect(freshResolution.isInitialLoading, isFalse);

    final notConnectedWithCacheResolution =
        uxResolveDisplayStateForSnapshot<String>(
      snapshot: const AsyncSnapshot<String>.nothing(),
      cachedState: 'cached',
    );
    expect(notConnectedWithCacheResolution.displayState, 'cached');
    expect(notConnectedWithCacheResolution.isInitialLoading, isFalse);

    final waitingWithCacheResolution = uxResolveDisplayStateForSnapshot<String>(
      snapshot: const AsyncSnapshot<String>.nothing()
          .inState(ConnectionState.waiting),
      cachedState: 'cached',
    );
    expect(waitingWithCacheResolution.displayState, 'cached');
    expect(waitingWithCacheResolution.isInitialLoading, isFalse);

    final waitingWithoutCacheResolution =
        uxResolveDisplayStateForSnapshot<String>(
      snapshot: const AsyncSnapshot<String>.nothing()
          .inState(ConnectionState.waiting),
      cachedState: null,
    );
    expect(waitingWithoutCacheResolution.displayState, isNull);
    expect(waitingWithoutCacheResolution.isInitialLoading, isTrue);

    final errorWithCacheResolution = uxResolveDisplayStateForSnapshot<String>(
      snapshot: AsyncSnapshot<String>.withError(
        ConnectionState.active,
        Exception('failed'),
      ),
      cachedState: 'cached',
    );
    expect(errorWithCacheResolution.displayState, 'cached');
    expect(errorWithCacheResolution.isInitialLoading, isFalse);

    final errorWithoutCacheResolution =
        uxResolveDisplayStateForSnapshot<String>(
      snapshot: AsyncSnapshot<String>.withError(
        ConnectionState.active,
        Exception('failed'),
      ),
      cachedState: null,
    );
    expect(errorWithoutCacheResolution.displayState, isNull);
    expect(errorWithoutCacheResolution.isInitialLoading, isFalse);

    final doneErrorWithCacheResolution =
        uxResolveDisplayStateForSnapshot<String>(
      snapshot: AsyncSnapshot<String>.withError(
        ConnectionState.done,
        Exception('failed'),
      ),
      cachedState: 'cached',
    );
    expect(doneErrorWithCacheResolution.displayState, 'cached');
    expect(doneErrorWithCacheResolution.isInitialLoading, isFalse);

    final doneWithoutDataResolution = uxResolveDisplayStateForSnapshot<String>(
      snapshot:
          const AsyncSnapshot<String>.nothing().inState(ConnectionState.done),
      cachedState: 'cached',
    );
    expect(doneWithoutDataResolution.displayState, isNull);
    expect(doneWithoutDataResolution.isInitialLoading, isFalse);

    final doneWithDataResolution = uxResolveDisplayStateForSnapshot<String>(
      snapshot: const AsyncSnapshot<String>.withData(
        ConnectionState.done,
        'done-data',
      ),
      cachedState: 'cached',
    );
    expect(doneWithDataResolution.displayState, 'done-data');
    expect(doneWithDataResolution.isInitialLoading, isFalse);
  });
}
