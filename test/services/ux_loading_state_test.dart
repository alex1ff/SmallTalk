import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/ux_loading_state.dart';

void main() {
  group('UxLoadingState', () {
    test('uses initialLoading before a confirmed result exists', () {
      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'events:today',
        isLoading: true,
      );

      expect(state.status, UxLoadingStatus.initialLoading);
      expect(state.canShowFullScreenLoader, true);
      expect(state.hasDisplayResult, false);
    });

    test('uses initialLoading while idle before a confirmed result exists', () {
      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'events:today',
        isLoading: false,
      );

      expect(state.status, UxLoadingStatus.initialLoading);
      expect(state.hasDisplayResult, false);
    });

    test('turns confirmed data into hasData', () {
      final result = UxLoadedResult<String>.data(
        dataKey: 'chat:1',
        data: 'hello',
      );

      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'chat:1',
        isLoading: false,
        newResult: result,
      );

      expect(state.status, UxLoadingStatus.hasData);
      expect(state.displayedResult, same(result));
      expect(state.dataOrNull, 'hello');
    });

    test('matches collection data keys by value', () {
      final result = UxLoadedResult<String>.data(
        dataKey: ['events', 'today'],
        data: 'fresh',
      );

      final state = UxLoadingState<String>.resolve(
        activeDataKey: ['events', 'today'],
        isLoading: false,
        newResult: result,
      );

      expect(state.status, UxLoadingStatus.hasData);
      expect(state.displayedResult, same(result));
    });

    test('matches nested collection data keys by value', () {
      final result = UxLoadedResult<String>.data(
        dataKey: {
          'screen': 'events',
          'filters': ['today', 'B1'],
        },
        data: 'fresh',
      );

      final state = UxLoadingState<String>.resolve(
        activeDataKey: {
          'screen': 'events',
          'filters': ['today', 'B1'],
        },
        isLoading: false,
        newResult: result,
      );

      expect(state.status, UxLoadingStatus.hasData);
      expect(state.displayedResult, same(result));
    });

    test('matches set data keys by value', () {
      final result = UxLoadedResult<String>.data(
        dataKey: {'events', 'today'},
        data: 'fresh',
      );

      final state = UxLoadingState<String>.resolve(
        activeDataKey: {'today', 'events'},
        isLoading: false,
        newResult: result,
      );

      expect(state.status, UxLoadingStatus.hasData);
      expect(state.displayedResult, same(result));
    });

    test('uses matching confirmed result before active error state', () {
      final result = UxLoadedResult<String>.data(
        dataKey: 'chat:1',
        data: 'fresh',
      );

      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'chat:1',
        isLoading: false,
        newResult: result,
        error: StateError('previous request failed'),
        errorDataKey: 'chat:1',
      );

      expect(state.status, UxLoadingStatus.hasData);
      expect(state.displayedResult, same(result));
      expect(state.error, isNull);
    });

    test('uses matching confirmed result before loading state', () {
      final result = UxLoadedResult<String>.data(
        dataKey: 'chat:1',
        data: 'fresh',
      );

      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'chat:1',
        isLoading: true,
        newResult: result,
      );

      expect(state.status, UxLoadingStatus.hasData);
      expect(state.displayedResult, same(result));
      expect(state.isRefreshing, false);
    });

    test('turns confirmed empty into empty', () {
      final result = UxLoadedResult<List<String>>.empty(
        dataKey: 'events:empty',
      );

      final state = UxLoadingState<List<String>>.resolve(
        activeDataKey: 'events:empty',
        isLoading: false,
        newResult: result,
      );

      expect(state.status, UxLoadingStatus.empty);
      expect(state.canShowEmptyState, true);
      expect(state.displayedResult, same(result));
    });

    test('turns confirmed domain result into domain state', () {
      final result = UxLoadedResult<String>.domain(
        dataKey: 'event:deleted',
        state: 'deleted',
      );

      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'event:deleted',
        isLoading: false,
        newResult: result,
      );

      expect(state.status, UxLoadingStatus.domain);
      expect(state.isDomainState, true);
      expect(state.hasData, false);
      expect(state.displayedResult, same(result));
    });

    test('keeps optional domain payload available without hasData status', () {
      final result = UxLoadedResult<String>.domain(
        dataKey: 'event:deleted',
        state: 'deleted',
        data: 'event snapshot',
      );

      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'event:deleted',
        isLoading: false,
        newResult: result,
      );

      expect(state.status, UxLoadingStatus.domain);
      expect(state.hasData, false);
      expect(state.dataOrNull, 'event snapshot');
    });

    test('ignores a confirmed result from an inactive data key', () {
      final staleResult = UxLoadedResult<String>.data(
        dataKey: 'events:today',
        data: 'stale',
      );

      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'events:week',
        isLoading: true,
        newResult: staleResult,
      );

      expect(state.status, UxLoadingStatus.initialLoading);
      expect(state.hasDisplayResult, false);
    });

    test('ignores stale confirmed result and keeps compatible previous data',
        () {
      final staleResult = UxLoadedResult<String>.data(
        dataKey: 'events:today',
        data: 'stale',
      );
      final previous = UxLoadedResult<String>.data(
        dataKey: 'events:cached',
        data: 'previous',
      );

      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'events:week',
        isLoading: true,
        newResult: staleResult,
        lastSuccessfulResult: previous,
        isCompatibleDataKey: (previousKey, _) => previousKey == 'events:cached',
      );

      expect(state.status, UxLoadingStatus.refreshing);
      expect(state.displayedResult, same(previous));
      expect(state.dataOrNull, 'previous');
    });

    test('ignores stale same-filter result from previous request generation',
        () {
      final previousKey = {
        'filter': 'events:today',
        'request': 1,
      };
      final activeKey = {
        'filter': 'events:today',
        'request': 2,
      };
      final staleResult = UxLoadedResult<String>.data(
        dataKey: previousKey,
        data: 'stale',
      );
      final previous = UxLoadedResult<String>.data(
        dataKey: previousKey,
        data: 'previous',
      );

      final state = UxLoadingState<String>.resolve(
        activeDataKey: activeKey,
        isLoading: true,
        newResult: staleResult,
        lastSuccessfulResult: previous,
        isCompatibleDataKey: (previousKey, activeKey) {
          final previousMap = previousKey as Map<Object?, Object?>;
          final activeMap = activeKey as Map<Object?, Object?>;
          return previousMap['filter'] == activeMap['filter'];
        },
      );

      expect(state.status, UxLoadingStatus.refreshing);
      expect(state.displayedResult, same(previous));
      expect(state.dataOrNull, 'previous');
    });

    test('ignores stale confirmed result and stale error together', () {
      final staleResult = UxLoadedResult<String>.data(
        dataKey: 'events:today',
        data: 'stale',
      );
      final previous = UxLoadedResult<String>.data(
        dataKey: 'events:cached',
        data: 'previous',
      );

      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'events:week',
        isLoading: true,
        newResult: staleResult,
        lastSuccessfulResult: previous,
        error: StateError('old filter failed'),
        errorDataKey: 'events:today',
        isCompatibleDataKey: (_, __) => true,
      );

      expect(state.status, UxLoadingStatus.refreshing);
      expect(state.displayedResult, same(previous));
      expect(state.error, isNull);
    });

    test('keeps previous data while refreshing', () {
      final previous = UxLoadedResult<List<String>>.data(
        dataKey: 'events:today',
        data: const <String>['club'],
      );

      final state = UxLoadingState<List<String>>.resolve(
        activeDataKey: 'events:today',
        isLoading: true,
        lastSuccessfulResult: previous,
      );

      expect(state.status, UxLoadingStatus.refreshing);
      expect(state.displayedResult, same(previous));
      expect(state.canShowFullScreenLoader, false);
    });

    test('keeps compatible stale data for a new key refresh', () {
      final previous = UxLoadedResult<List<String>>.data(
        dataKey: 'events:today',
        data: const <String>['club'],
      );

      final state = UxLoadingState<List<String>>.resolve(
        activeDataKey: 'events:week',
        isLoading: true,
        lastSuccessfulResult: previous,
        isCompatibleDataKey: (_, __) => true,
      );

      expect(state.status, UxLoadingStatus.refreshing);
      expect(state.displayedResult, same(previous));
    });

    test('does not keep incompatible stale data', () {
      final previous = UxLoadedResult<String>.data(
        dataKey: 'conversation:1',
        data: 'hello',
      );

      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'conversation:2',
        isLoading: true,
        lastSuccessfulResult: previous,
      );

      expect(state.status, UxLoadingStatus.initialLoading);
      expect(state.hasDisplayResult, false);
    });

    test('keeps previous data when refresh fails', () {
      final previous = UxLoadedResult<List<String>>.data(
        dataKey: 'events:today',
        data: const <String>['club'],
      );
      final error = StateError('network');

      final state = UxLoadingState<List<String>>.resolve(
        activeDataKey: 'events:today',
        isLoading: false,
        lastSuccessfulResult: previous,
        error: error,
        errorDataKey: 'events:today',
      );

      expect(state.status, UxLoadingStatus.errorWithData);
      expect(state.isErrorWithData, true);
      expect(state.isErrorWithPreviousResult, true);
      expect(state.displayedResult, same(previous));
      expect(state.error, same(error));
    });

    test('uses errorWithData for active error with compatible previous key',
        () {
      final previous = UxLoadedResult<List<String>>.data(
        dataKey: 'events:cached',
        data: const <String>['club'],
      );
      final error = StateError('network');

      final state = UxLoadingState<List<String>>.resolve(
        activeDataKey: 'events:week',
        isLoading: false,
        lastSuccessfulResult: previous,
        error: error,
        errorDataKey: 'events:week',
        isCompatibleDataKey: (_, __) => true,
      );

      expect(state.status, UxLoadingStatus.errorWithData);
      expect(state.displayedResult, same(previous));
      expect(state.error, same(error));
    });

    test('keeps previous empty when refresh fails', () {
      final previous = UxLoadedResult<List<String>>.empty(
        dataKey: 'events:today',
      );

      final state = UxLoadingState<List<String>>.resolve(
        activeDataKey: 'events:today',
        isLoading: false,
        lastSuccessfulResult: previous,
        error: StateError('network'),
        errorDataKey: 'events:today',
      );

      expect(state.status, UxLoadingStatus.errorWithData);
      expect(state.displayedResult, same(previous));
      expect(state.displayedResult?.isEmpty, true);
    });

    test('keeps previous domain state when refresh fails', () {
      final previous = UxLoadedResult<String>.domain(
        dataKey: 'event:deleted',
        state: 'deleted',
      );

      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'event:deleted',
        isLoading: false,
        lastSuccessfulResult: previous,
        error: StateError('network'),
        errorDataKey: 'event:deleted',
      );

      expect(state.status, UxLoadingStatus.errorWithData);
      expect(state.displayedResult, same(previous));
      expect(state.displayedResult?.domainState, 'deleted');
    });

    test('keeps previous result refreshing while retry is in progress', () {
      final previous = UxLoadedResult<List<String>>.data(
        dataKey: 'chats',
        data: const <String>['message'],
      );

      final state = UxLoadingState<List<String>>.resolve(
        activeDataKey: 'chats',
        isLoading: true,
        lastSuccessfulResult: previous,
        error: StateError('network'),
        errorDataKey: 'chats',
      );

      expect(state.status, UxLoadingStatus.refreshing);
      expect(state.displayedResult, same(previous));
      expect(state.error, isNull);
    });

    test('uses initialLoading for retry in progress without previous result',
        () {
      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'events',
        isLoading: true,
        error: StateError('previous attempt failed'),
        errorDataKey: 'events',
      );

      expect(state.status, UxLoadingStatus.initialLoading);
      expect(state.error, isNull);
    });

    test('uses previous result while idle without a new result', () {
      final previous = UxLoadedResult<List<String>>.data(
        dataKey: 'events:today',
        data: const <String>['club'],
      );

      final state = UxLoadingState<List<String>>.resolve(
        activeDataKey: 'events:today',
        isLoading: false,
        lastSuccessfulResult: previous,
      );

      expect(state.status, UxLoadingStatus.hasData);
      expect(state.displayedResult, same(previous));
    });

    test('uses compatible previous result while idle for a new key', () {
      final previous = UxLoadedResult<List<String>>.data(
        dataKey: 'events:today',
        data: const <String>['club'],
      );

      final state = UxLoadingState<List<String>>.resolve(
        activeDataKey: 'events:week',
        isLoading: false,
        lastSuccessfulResult: previous,
        isCompatibleDataKey: (_, __) => true,
      );

      expect(state.status, UxLoadingStatus.hasData);
      expect(state.displayedResult, same(previous));
    });

    test('passes frozen active data key to compatibility callback', () {
      final previous = UxLoadedResult<List<String>>.data(
        dataKey: {
          'screen': 'events',
          'filters': ['today'],
        },
        data: const <String>['club'],
      );
      late Object receivedActiveKey;

      final state = UxLoadingState<List<String>>.resolve(
        activeDataKey: {
          'screen': 'events',
          'filters': ['week'],
        },
        isLoading: false,
        lastSuccessfulResult: previous,
        isCompatibleDataKey: (_, activeKey) {
          receivedActiveKey = activeKey;
          final activeMap = activeKey as Map<Object?, Object?>;
          final filters = activeMap['filters'] as List<Object?>;
          expect(
            () => activeMap['screen'] = 'changed',
            throwsUnsupportedError,
          );
          expect(
            () => filters.add('mutated'),
            throwsUnsupportedError,
          );
          return true;
        },
      );

      expect(state.status, UxLoadingStatus.hasData);
      expect(receivedActiveKey, {
        'screen': 'events',
        'filters': ['week'],
      });
    });

    test('uses errorWithoutData when first load fails', () {
      final error = StateError('network');

      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'events:today',
        isLoading: false,
        error: error,
        errorDataKey: 'events:today',
      );

      expect(state.status, UxLoadingStatus.errorWithoutData);
      expect(state.error, same(error));
      expect(state.hasError, true);
      expect(state.hasDisplayResult, false);
    });

    test('matches collection error keys by value', () {
      final error = StateError('network');

      final state = UxLoadingState<String>.resolve(
        activeDataKey: ['events', 'today'],
        isLoading: false,
        error: error,
        errorDataKey: ['events', 'today'],
      );

      expect(state.status, UxLoadingStatus.errorWithoutData);
      expect(state.error, same(error));
    });

    test('ignores stale error without previous data while idle', () {
      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'events:week',
        isLoading: false,
        error: StateError('old filter failed'),
        errorDataKey: 'events:today',
      );

      expect(state.status, UxLoadingStatus.initialLoading);
      expect(state.hasDisplayResult, false);
      expect(state.error, isNull);
    });

    test('ignores stale error and keeps compatible previous data', () {
      final previous = UxLoadedResult<List<String>>.data(
        dataKey: 'events:cached',
        data: const <String>['club'],
      );

      final state = UxLoadingState<List<String>>.resolve(
        activeDataKey: 'events:week',
        isLoading: true,
        lastSuccessfulResult: previous,
        error: StateError('old filter failed'),
        errorDataKey: 'events:today',
        isCompatibleDataKey: (_, __) => true,
      );

      expect(state.status, UxLoadingStatus.refreshing);
      expect(state.displayedResult, same(previous));
      expect(state.error, isNull);
    });

    test('ignores stale error and keeps compatible previous data while idle',
        () {
      final previous = UxLoadedResult<List<String>>.data(
        dataKey: 'events:cached',
        data: const <String>['club'],
      );

      final state = UxLoadingState<List<String>>.resolve(
        activeDataKey: 'events:week',
        isLoading: false,
        lastSuccessfulResult: previous,
        error: StateError('old filter failed'),
        errorDataKey: 'events:today',
        isCompatibleDataKey: (_, __) => true,
      );

      expect(state.status, UxLoadingStatus.hasData);
      expect(state.displayedResult, same(previous));
      expect(state.error, isNull);
    });

    test('rejects an unkeyed error', () {
      expect(
        () => UxLoadingState<String>.resolve(
          activeDataKey: 'events:today',
          isLoading: false,
          error: StateError('network'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('list helper does not treat fallback empty list as confirmed empty',
        () {
      final state = uxResolveListLoadingState<String>(
        activeDataKey: 'chats',
        isLoading: true,
        hasConfirmedResult: false,
        items: const <String>[],
      );

      expect(state.status, UxLoadingStatus.initialLoading);
      expect(state.canShowEmptyState, false);
    });

    test('list helper turns confirmed empty list into empty', () {
      final state = uxResolveListLoadingState<String>(
        activeDataKey: 'chats',
        isLoading: false,
        hasConfirmedResult: true,
        items: const <String>[],
      );

      expect(state.status, UxLoadingStatus.empty);
      expect(state.canShowEmptyState, true);
    });

    test('list helper treats non-empty default result key as active data', () {
      final state = uxResolveListLoadingState<String>(
        activeDataKey: 'chats',
        isLoading: false,
        hasConfirmedResult: true,
        items: const <String>['hello'],
      );

      expect(state.status, UxLoadingStatus.hasData);
      expect(state.displayedResult?.dataKey, 'chats');
      expect(state.dataOrNull, const <String>['hello']);
    });

    test('list helper ignores confirmed items from inactive data key', () {
      final previous = UxLoadedResult<List<String>>.data(
        dataKey: 'events:cached',
        data: const <String>['previous'],
      );

      final state = uxResolveListLoadingState<String>(
        activeDataKey: 'events:week',
        isLoading: true,
        hasConfirmedResult: true,
        resultDataKey: 'events:today',
        items: const <String>['stale'],
        lastSuccessfulResult: previous,
        isCompatibleDataKey: (_, __) => true,
      );

      expect(state.status, UxLoadingStatus.refreshing);
      expect(state.displayedResult, same(previous));
      expect(state.dataOrNull, const <String>['previous']);
    });

    test('list helper rejects confirmed result without items', () {
      expect(
        () => uxResolveListLoadingState<String>(
          activeDataKey: 'chats',
          isLoading: false,
          hasConfirmedResult: true,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('list helper protects returned data from mutation', () {
      final items = <String>['hello'];
      final result = uxLoadedListResult<String>(
        dataKey: 'words',
        items: items,
      );
      items.add('wait');

      expect(result.data, const <String>['hello']);
      expect(
        () => result.data!.add('fail'),
        throwsUnsupportedError,
      );
    });
  });

  group('UxLoadedResult', () {
    test('rejects blank domain state', () {
      expect(
        () => UxLoadedResult<String>.domain(
          dataKey: 'event:1',
          state: ' ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('normalizes domain state whitespace', () {
      final result = UxLoadedResult<String>.domain(
        dataKey: 'event:1',
        state: ' deleted ',
      );

      expect(result.domainState, 'deleted');
    });

    test('supports value equality for list data', () {
      final first = UxLoadedResult<List<String>>.data(
        dataKey: const ['events', 'today'],
        data: const <String>['club'],
      );
      final second = UxLoadedResult<List<String>>.data(
        dataKey: const ['events', 'today'],
        data: const <String>['club'],
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('freezes mutable collection data keys', () {
      final key = ['events', 'today'];
      final result = UxLoadedResult<String>.data(
        dataKey: key,
        data: 'club',
      );
      final hashBeforeMutation = result.hashCode;

      key.add('mutated');

      expect(result.dataKey, const ['events', 'today']);
      expect(result.hashCode, hashBeforeMutation);
    });

    test('freezes nested mutable collection data keys', () {
      final nestedFilters = ['today', 'B1'];
      final key = {
        'screen': 'events',
        'filters': nestedFilters,
      };
      final result = UxLoadedResult<String>.data(
        dataKey: key,
        data: 'club',
      );
      final hashBeforeMutation = result.hashCode;

      nestedFilters.add('mutated');
      key['screen'] = 'changed';

      expect(
        result.dataKey,
        {
          'screen': 'events',
          'filters': ['today', 'B1'],
        },
      );
      expect(result.hashCode, hashBeforeMutation);
    });

    test('exposes data key collections as unmodifiable values', () {
      final result = UxLoadedResult<String>.data(
        dataKey: {
          'screen': 'events',
          'filters': ['today', 'B1'],
        },
        data: 'club',
      );
      final dataKey = result.dataKey as Map<Object?, Object?>;
      final filters = dataKey['filters'] as List<Object?>;

      expect(
        () => dataKey['screen'] = 'changed',
        throwsUnsupportedError,
      );
      expect(
        () => filters.add('mutated'),
        throwsUnsupportedError,
      );
    });

    test('freezes set data keys as unmodifiable values', () {
      final key = {'events', 'today'};
      final result = UxLoadedResult<String>.data(
        dataKey: key,
        data: 'club',
      );
      final hashBeforeMutation = result.hashCode;
      final dataKey = result.dataKey as Set<Object?>;

      key.add('mutated');

      expect(result.dataKey, {'events', 'today'});
      expect(result.hashCode, hashBeforeMutation);
      expect(
        () => dataKey.add('changed'),
        throwsUnsupportedError,
      );
    });

    test('freezes nested mutable collection inside set data keys', () {
      final nestedFilters = ['today', 'B1'];
      final key = {nestedFilters};
      final result = UxLoadedResult<String>.data(
        dataKey: key,
        data: 'club',
      );
      final hashBeforeMutation = result.hashCode;
      final dataKey = result.dataKey as Set<Object?>;
      final frozenFilters = dataKey.single as List<Object?>;

      nestedFilters.add('mutated');
      key.add(['changed']);

      expect(dataKey.length, 1);
      expect(frozenFilters, const ['today', 'B1']);
      expect(result.hashCode, hashBeforeMutation);
      expect(
        () => dataKey.add(['changed']),
        throwsUnsupportedError,
      );
      expect(
        () => frozenFilters.add('changed'),
        throwsUnsupportedError,
      );
    });

    test('keeps value equality symmetric for different generic types', () {
      final stringResult = UxLoadedResult<List<String>>.data(
        dataKey: 'events',
        data: const <String>['club'],
      );
      final objectResult = UxLoadedResult<List<Object>>.data(
        dataKey: 'events',
        data: const <Object>['club'],
      );

      expect(stringResult == objectResult, false);
      expect(objectResult == stringResult, false);
    });

    test('prints diagnostic fields', () {
      final result = UxLoadedResult<String>.domain(
        dataKey: 'event:1',
        state: 'deleted',
        data: 'snapshot',
      );

      expect(result.toString(), contains('event:1'));
      expect(result.toString(), contains('deleted'));
      expect(result.toString(), contains('snapshot'));
    });
  });

  group('UxLoadingState equality', () {
    test('supports value equality for displayed list result', () {
      final first = UxLoadingState<List<String>>.resolve(
        activeDataKey: const ['events', 'today'],
        isLoading: false,
        newResult: UxLoadedResult<List<String>>.data(
          dataKey: const ['events', 'today'],
          data: const <String>['club'],
        ),
      );
      final second = UxLoadingState<List<String>>.resolve(
        activeDataKey: const ['events', 'today'],
        isLoading: false,
        newResult: UxLoadedResult<List<String>>.data(
          dataKey: const ['events', 'today'],
          data: const <String>['club'],
        ),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('freezes mutable collection active data keys', () {
      final key = ['events', 'today'];
      final state = UxLoadingState<String>.resolve(
        activeDataKey: key,
        isLoading: true,
      );
      final hashBeforeMutation = state.hashCode;

      key.add('mutated');

      expect(state.activeDataKey, const ['events', 'today']);
      expect(state.hashCode, hashBeforeMutation);
    });

    test('freezes nested mutable collection active data keys', () {
      final nestedFilters = ['today', 'B1'];
      final key = {
        'screen': 'events',
        'filters': nestedFilters,
      };
      final state = UxLoadingState<String>.resolve(
        activeDataKey: key,
        isLoading: true,
      );
      final hashBeforeMutation = state.hashCode;

      nestedFilters.add('mutated');
      key['screen'] = 'changed';

      expect(
        state.activeDataKey,
        {
          'screen': 'events',
          'filters': ['today', 'B1'],
        },
      );
      expect(state.hashCode, hashBeforeMutation);
    });

    test('exposes active data key collections as unmodifiable values', () {
      final state = UxLoadingState<String>.resolve(
        activeDataKey: {
          'screen': 'events',
          'filters': ['today', 'B1'],
        },
        isLoading: true,
      );
      final activeKey = state.activeDataKey as Map<Object?, Object?>;
      final filters = activeKey['filters'] as List<Object?>;

      expect(
        () => activeKey['screen'] = 'changed',
        throwsUnsupportedError,
      );
      expect(
        () => filters.add('mutated'),
        throwsUnsupportedError,
      );
    });

    test('freezes set active data keys as unmodifiable values', () {
      final key = {'events', 'today'};
      final state = UxLoadingState<String>.resolve(
        activeDataKey: key,
        isLoading: true,
      );
      final hashBeforeMutation = state.hashCode;
      final activeKey = state.activeDataKey as Set<Object?>;

      key.add('mutated');

      expect(state.activeDataKey, {'events', 'today'});
      expect(state.hashCode, hashBeforeMutation);
      expect(
        () => activeKey.add('changed'),
        throwsUnsupportedError,
      );
    });

    test('freezes nested mutable collection inside set active data keys', () {
      final nestedFilters = ['today', 'B1'];
      final key = {nestedFilters};
      final state = UxLoadingState<String>.resolve(
        activeDataKey: key,
        isLoading: true,
      );
      final hashBeforeMutation = state.hashCode;
      final activeKey = state.activeDataKey as Set<Object?>;
      final frozenFilters = activeKey.single as List<Object?>;

      nestedFilters.add('mutated');
      key.add(['changed']);

      expect(activeKey.length, 1);
      expect(frozenFilters, const ['today', 'B1']);
      expect(state.hashCode, hashBeforeMutation);
      expect(
        () => activeKey.add(['changed']),
        throwsUnsupportedError,
      );
      expect(
        () => frozenFilters.add('changed'),
        throwsUnsupportedError,
      );
    });

    test('keeps value equality symmetric for different generic types', () {
      final stringState = UxLoadingState<List<String>>.resolve(
        activeDataKey: 'events',
        isLoading: false,
        newResult: UxLoadedResult<List<String>>.data(
          dataKey: 'events',
          data: const <String>['club'],
        ),
      );
      final objectState = UxLoadingState<List<Object>>.resolve(
        activeDataKey: 'events',
        isLoading: false,
        newResult: UxLoadedResult<List<Object>>.data(
          dataKey: 'events',
          data: const <Object>['club'],
        ),
      );

      expect(stringState == objectState, false);
      expect(objectState == stringState, false);
    });

    test('supports value equality for same error instance', () {
      final error = StateError('network');

      final first = UxLoadingState<String>.resolve(
        activeDataKey: 'events',
        isLoading: false,
        error: error,
        errorDataKey: 'events',
      );
      final second = UxLoadingState<String>.resolve(
        activeDataKey: 'events',
        isLoading: false,
        error: error,
        errorDataKey: 'events',
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('uses error identity for value equality', () {
      final first = UxLoadingState<String>.resolve(
        activeDataKey: 'events',
        isLoading: false,
        error: ['network'],
        errorDataKey: 'events',
      );
      final second = UxLoadingState<String>.resolve(
        activeDataKey: 'events',
        isLoading: false,
        error: ['network'],
        errorDataKey: 'events',
      );

      expect(first == second, false);
    });

    test('prints diagnostic fields', () {
      final state = UxLoadingState<String>.resolve(
        activeDataKey: 'events',
        isLoading: false,
        newResult: UxLoadedResult<String>.data(
          dataKey: 'events',
          data: 'club',
        ),
      );

      expect(state.toString(), contains('events'));
      expect(state.toString(), contains('hasData'));
      expect(state.toString(), contains('club'));
    });
  });
}
