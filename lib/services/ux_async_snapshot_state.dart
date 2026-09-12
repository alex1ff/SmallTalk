import 'package:flutter/widgets.dart';

final class UxSnapshotDisplayResolution<T extends Object> {
  const UxSnapshotDisplayResolution({
    required this.displayState,
    required this.isInitialLoading,
  });

  final T? displayState;
  final bool isInitialLoading;
}

/// Returns the state that should stay visible for a `StreamBuilder` snapshot.
///
/// Fresh snapshot data always wins. While the stream is not connected yet,
/// waiting, or reports an error without data, the cached state remains visible.
/// A finished snapshot without data clears the display state unless it reports
/// an error, in which case stale cache remains visible. If a finished snapshot
/// still carries data, that snapshot data remains the display state.
T? uxDisplayStateForSnapshot<T extends Object>({
  required AsyncSnapshot<T> snapshot,
  required T? cachedState,
}) {
  final snapshotState = snapshot.data;
  if (snapshotState != null) {
    return snapshotState;
  }

  if (snapshot.connectionState == ConnectionState.none ||
      snapshot.connectionState == ConnectionState.waiting ||
      snapshot.hasError) {
    return cachedState;
  }

  return null;
}

/// Resolves both display state and initial loading for a stream snapshot.
///
/// Use this when the UI must keep stale content visible during refresh/error,
/// while still treating a first waiting snapshot without cached data as initial
/// loading.
UxSnapshotDisplayResolution<T>
    uxResolveDisplayStateForSnapshot<T extends Object>({
  required AsyncSnapshot<T> snapshot,
  required T? cachedState,
}) {
  final displayState = uxDisplayStateForSnapshot(
    snapshot: snapshot,
    cachedState: cachedState,
  );

  return UxSnapshotDisplayResolution<T>(
    displayState: displayState,
    isInitialLoading: snapshot.connectionState == ConnectionState.waiting &&
        displayState == null &&
        !snapshot.hasError,
  );
}
