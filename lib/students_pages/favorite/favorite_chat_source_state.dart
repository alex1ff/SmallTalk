import 'package:flutter/widgets.dart';

import '/services/ux_async_snapshot_state.dart';

typedef FavoriteChatSourceWidgetBuilder<T extends Object> = Widget Function(
  BuildContext context,
  AsyncSnapshot<T> snapshot,
  UxSnapshotDisplayResolution<T> resolution,
);

Key favoriteChatSourceKey({
  required String sourceId,
  required String currentUid,
}) =>
    ValueKey((sourceId, currentUid));

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
  });

  final String sourceId;
  final String currentUid;
  final Stream<T> stream;
  final T? cachedState;
  final FavoriteChatSourceWidgetBuilder<T> builder;

  @override
  State<FavoriteChatSourceBuilder<T>> createState() =>
      _FavoriteChatSourceBuilderState<T>();
}

class _FavoriteChatSourceBuilderState<T extends Object>
    extends State<FavoriteChatSourceBuilder<T>> {
  T? _lastSuccessfulState;

  @override
  void initState() {
    super.initState();
    _lastSuccessfulState = widget.cachedState;
  }

  @override
  void didUpdateWidget(FavoriteChatSourceBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceId != widget.sourceId ||
        oldWidget.currentUid != widget.currentUid) {
      _lastSuccessfulState = widget.cachedState;
    } else if (widget.cachedState != null && _lastSuccessfulState == null) {
      _lastSuccessfulState = widget.cachedState;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      key: favoriteChatSourceKey(
        sourceId: widget.sourceId,
        currentUid: widget.currentUid,
      ),
      stream: widget.stream,
      initialData: widget.cachedState,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _lastSuccessfulState = snapshot.data;
        }

        return widget.builder(
          context,
          snapshot,
          resolveFavoriteChatSourceSnapshot(
            snapshot: snapshot,
            cachedState: _lastSuccessfulState ?? widget.cachedState,
          ),
        );
      },
    );
  }
}
