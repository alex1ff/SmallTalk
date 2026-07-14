import 'dart:async';

import 'package:flutter/widgets.dart';

import '/services/ux_async_snapshot_state.dart';

typedef FavoriteChatSourceWidgetBuilder<T extends Object> = Widget Function(
  BuildContext context,
  AsyncSnapshot<T> snapshot,
  UxSnapshotDisplayResolution<T> resolution,
);
typedef FavoriteChatSourceStateReducer<T extends Object> = T Function(
  T? previousState,
  T incomingState,
);

String favoriteAuthOwnerUid(String? firebaseUserId) =>
    firebaseUserId?.trim() ?? '';

final class FavoriteFirestoreSourceSnapshot<T extends Object> {
  const FavoriteFirestoreSourceSnapshot({
    required this.value,
    required this.isEmpty,
    required this.isFromCache,
    required this.hasPendingWrites,
  });

  final T value;
  final bool isEmpty;
  final bool isFromCache;
  final bool hasPendingWrites;

  bool get hasServerConfirmedEmpty =>
      isEmpty && !isFromCache && !hasPendingWrites;
}

Stream<FavoriteFirestoreSourceSnapshot<T>>
    transformFavoriteFirestoreSnapshots<T extends Object>(
  Stream<FavoriteFirestoreSourceSnapshot<T>> snapshots,
) {
  return snapshots.where(
    (snapshot) => !snapshot.isEmpty || snapshot.hasServerConfirmedEmpty,
  );
}

Stream<T> guardFavoriteOwnerScopedSource<T extends Object>({
  required Stream<T> source,
  required String expectedOwnerUid,
  required int sourceGeneration,
  required int Function() currentGeneration,
  required bool Function(String ownerUid) ownerIsCurrent,
  required String Function(T value) ownerUidOf,
}) {
  bool sourceIsCurrent() =>
      sourceGeneration == currentGeneration() &&
      ownerIsCurrent(expectedOwnerUid);

  return source.transform(
    StreamTransformer<T, T>.fromHandlers(
      handleData: (value, sink) {
        if (!sourceIsCurrent()) {
          return;
        }
        if (ownerUidOf(value) != expectedOwnerUid) {
          sink.addError(
            StateError('Favorite source value belongs to another owner'),
          );
          return;
        }
        sink.add(value);
      },
      handleError: (error, stackTrace, sink) {
        if (sourceIsCurrent()) {
          sink.addError(error, stackTrace);
        }
      },
    ),
  );
}

enum FavoriteFriendsTabViewState {
  initialLoading,
  data,
  empty,
  errorWithoutData,
}

const ValueKey<String> favoriteFriendsInitialLoadingKey =
    ValueKey<String>('favorite_friends_initial_loading');
const ValueKey<String> favoriteFriendsDataKey =
    ValueKey<String>('favorite_friends_data');
const ValueKey<String> favoriteFriendsEmptyKey =
    ValueKey<String>('favorite_friends_empty');
const ValueKey<String> favoriteFriendsLoadErrorKey =
    ValueKey<String>('favorite_friends_load_error');
const ValueKey<String> favoriteFriendsInlineErrorKey =
    ValueKey<String>('favorite_friends_inline_error');
const ValueKey<String> favoriteFriendsRetryButtonKey =
    ValueKey<String>('favorite_friends_retry_button');

bool favoriteUserDocumentMatchesUid({
  required String currentUid,
  required String? documentOwnerUid,
}) =>
    currentUid.isNotEmpty && documentOwnerUid == currentUid;

T? favoriteOwnedUserDocumentValue<T>({
  required String currentUid,
  required String? documentOwnerUid,
  required T? value,
}) =>
    favoriteUserDocumentMatchesUid(
      currentUid: currentUid,
      documentOwnerUid: documentOwnerUid,
    )
        ? value
        : null;

FavoriteFriendsTabViewState resolveFavoriteFriendsTabViewState({
  required bool conversationsLoading,
  required bool conversationsLoadFailed,
  required bool conversationsHasLoaded,
  required bool friendsLoading,
  required bool friendsLoadFailed,
  required bool friendsHasLoaded,
  required bool hasFriendConversations,
}) {
  if (hasFriendConversations) {
    return FavoriteFriendsTabViewState.data;
  }

  if ((conversationsLoadFailed && !conversationsHasLoaded) ||
      (friendsLoadFailed && !friendsHasLoaded)) {
    return FavoriteFriendsTabViewState.errorWithoutData;
  }

  if (conversationsLoading ||
      friendsLoading ||
      !conversationsHasLoaded ||
      !friendsHasLoaded) {
    return FavoriteFriendsTabViewState.initialLoading;
  }

  return FavoriteFriendsTabViewState.empty;
}

class FavoriteFriendsTabStateSlot extends StatelessWidget {
  const FavoriteFriendsTabStateSlot({
    super.key,
    required this.state,
    required this.initialLoading,
    required this.data,
    required this.empty,
    required this.errorWithoutData,
  });

  final FavoriteFriendsTabViewState state;
  final Widget initialLoading;
  final Widget data;
  final Widget empty;
  final Widget errorWithoutData;

  @override
  Widget build(BuildContext context) => switch (state) {
        FavoriteFriendsTabViewState.initialLoading => KeyedSubtree(
            key: favoriteFriendsInitialLoadingKey,
            child: initialLoading,
          ),
        FavoriteFriendsTabViewState.data => KeyedSubtree(
            key: favoriteFriendsDataKey,
            child: data,
          ),
        FavoriteFriendsTabViewState.empty => KeyedSubtree(
            key: favoriteFriendsEmptyKey,
            child: empty,
          ),
        FavoriteFriendsTabViewState.errorWithoutData => KeyedSubtree(
            key: favoriteFriendsLoadErrorKey,
            child: errorWithoutData,
          ),
      };
}

Key favoriteChatSourceKey({
  required String sourceId,
  required String currentUid,
  int sourceEpoch = 0,
}) =>
    ValueKey((sourceId, currentUid, sourceEpoch));

UxSnapshotDisplayResolution<T>
    resolveFavoriteChatSourceSnapshot<T extends Object>({
  required AsyncSnapshot<T> snapshot,
  required T? cachedState,
}) =>
        uxResolveDisplayStateForSnapshot(
          snapshot: snapshot,
          cachedState: cachedState,
        );

class FavoriteChatSourceBuilder<T extends Object> extends StatefulWidget {
  const FavoriteChatSourceBuilder({
    super.key,
    required this.sourceId,
    required this.currentUid,
    required this.stream,
    required this.cachedState,
    required this.builder,
    this.sourceEpoch = 0,
    this.retryToken = 0,
    this.stateReducer,
  });

  final String sourceId;
  final String currentUid;
  final Stream<T> stream;
  final T? cachedState;
  final FavoriteChatSourceWidgetBuilder<T> builder;
  final int sourceEpoch;
  final int retryToken;
  final FavoriteChatSourceStateReducer<T>? stateReducer;

  @override
  State<FavoriteChatSourceBuilder<T>> createState() =>
      _FavoriteChatSourceBuilderState<T>();
}

class _FavoriteChatSourceBuilderState<T extends Object>
    extends State<FavoriteChatSourceBuilder<T>> {
  T? _lastSuccessfulState;
  late Stream<T> _effectiveStream;

  @override
  void initState() {
    super.initState();
    _lastSuccessfulState = widget.cachedState;
    _effectiveStream = _newSubscriptionStream(widget.stream);
  }

  @override
  void didUpdateWidget(FavoriteChatSourceBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceId != widget.sourceId ||
        oldWidget.currentUid != widget.currentUid ||
        oldWidget.sourceEpoch != widget.sourceEpoch) {
      _lastSuccessfulState = widget.cachedState;
    } else if (widget.cachedState != null && _lastSuccessfulState == null) {
      _lastSuccessfulState = widget.cachedState;
    }
    if (oldWidget.stream != widget.stream ||
        oldWidget.sourceEpoch != widget.sourceEpoch ||
        oldWidget.retryToken != widget.retryToken) {
      _effectiveStream = _newSubscriptionStream(widget.stream);
    }
  }

  Stream<T> _newSubscriptionStream(Stream<T> source) =>
      source.map((value) => value);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      key: favoriteChatSourceKey(
        sourceId: widget.sourceId,
        currentUid: widget.currentUid,
        sourceEpoch: widget.sourceEpoch,
      ),
      stream: _effectiveStream,
      initialData: widget.cachedState,
      builder: (context, snapshot) {
        var displaySnapshot = snapshot;
        if (snapshot.hasData && snapshot.data != null) {
          final incomingState = snapshot.data!;
          _lastSuccessfulState = widget.stateReducer?.call(
                _lastSuccessfulState,
                incomingState,
              ) ??
              incomingState;
          displaySnapshot = AsyncSnapshot<T>.withData(
            snapshot.connectionState,
            _lastSuccessfulState!,
          );
        }

        return widget.builder(
          context,
          snapshot,
          resolveFavoriteChatSourceSnapshot(
            snapshot: displaySnapshot,
            cachedState: _lastSuccessfulState ?? widget.cachedState,
          ),
        );
      },
    );
  }
}
