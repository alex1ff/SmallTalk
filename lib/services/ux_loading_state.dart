import 'package:collection/collection.dart';

const _uxEquality = DeepCollectionEquality();

Object _freezeDataKey(Object value) {
  return _freezeValue(value) as Object;
}

// Collection keys are copied into unmodifiable Object?/Map/List/Set values.
// Custom mutable key objects remain caller responsibility.
// Use defensive casts when reading keys in custom compatibility callbacks.
Object? _freezeValue(Object? value) {
  if (value is Map) {
    return Map<Object?, Object?>.unmodifiable(
      value.map(
        (key, mapValue) => MapEntry(
          _freezeValue(key),
          _freezeValue(mapValue),
        ),
      ),
    );
  }

  if (value is Set) {
    return Set<Object?>.unmodifiable(value.map(_freezeValue));
  }

  if (value is Iterable) {
    return List<Object?>.unmodifiable(value.map(_freezeValue));
  }

  return value;
}

enum UxLoadingStatus {
  initialLoading,
  refreshing,
  hasData,
  empty,
  domain,
  errorWithData,
  errorWithoutData,
}

enum UxLoadedResultKind {
  data,
  empty,
  domain,
}

/// Checks whether a previous result key may stay visible for an active key.
/// Collection keys are already frozen; use defensive casts for custom shapes.
typedef UxDataKeyCompatibility = bool Function(
  Object previousKey,
  Object activeKey,
);

bool uxSameDataKey(Object previousKey, Object activeKey) {
  return _uxEquality.equals(previousKey, activeKey);
}

final class UxLoadedResult<T extends Object> {
  UxLoadedResult._({
    required Object dataKey,
    required this.kind,
    this.data,
    this.domainState,
  }) : dataKey = _freezeDataKey(dataKey);

  factory UxLoadedResult.data({
    required Object dataKey,
    required T data,
  }) {
    return UxLoadedResult<T>._(
      dataKey: dataKey,
      kind: UxLoadedResultKind.data,
      data: data,
    );
  }

  factory UxLoadedResult.empty({
    required Object dataKey,
  }) {
    return UxLoadedResult<T>._(
      dataKey: dataKey,
      kind: UxLoadedResultKind.empty,
    );
  }

  factory UxLoadedResult.domain({
    required Object dataKey,
    required String state,
    T? data,
  }) {
    final normalizedState = state.trim();
    if (normalizedState.isEmpty) {
      throw ArgumentError.value(
        state,
        'state',
        'Expected a non-empty domain state.',
      );
    }

    return UxLoadedResult<T>._(
      dataKey: dataKey,
      kind: UxLoadedResultKind.domain,
      domainState: normalizedState,
      data: data,
    );
  }

  /// Result identity. Collection keys are frozen; custom mutable key objects
  /// remain caller responsibility.
  final Object dataKey;
  final UxLoadedResultKind kind;

  /// Loaded payload for data results and optional payload for domain results.
  /// Generic payloads are not deep-frozen; keep collection payloads immutable
  /// after creation or use [uxLoadedListResult] for list payloads.
  final T? data;
  final String? domainState;

  bool get hasData => kind == UxLoadedResultKind.data;
  bool get isEmpty => kind == UxLoadedResultKind.empty;
  bool get isDomainState => kind == UxLoadedResultKind.domain;

  @override
  String toString() {
    return 'UxLoadedResult<$T>('
        'dataKey: $dataKey, '
        'kind: $kind, '
        'data: $data, '
        'domainState: $domainState'
        ')';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UxLoadedResult<T> &&
            runtimeType == other.runtimeType &&
            _uxEquality.equals(other.dataKey, dataKey) &&
            other.kind == kind &&
            _uxEquality.equals(other.data, data) &&
            other.domainState == domainState;
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      _uxEquality.hash(dataKey),
      kind,
      _uxEquality.hash(data),
      domainState,
    );
  }
}

final class UxLoadingState<T extends Object> {
  UxLoadingState._({
    required this.status,
    required Object activeDataKey,
    this.displayedResult,
    this.error,
  }) : activeDataKey = _freezeDataKey(activeDataKey);

  /// Resolves UI loading state for one active request key.
  /// Confirmed results and errors from inactive keys are ignored.
  /// A matching [newResult] wins over [isLoading] and [error].
  /// While [isLoading] is true, compatible previous data wins over active error.
  factory UxLoadingState.resolve({
    required Object activeDataKey,
    required bool isLoading,
    UxLoadedResult<T>? newResult,
    UxLoadedResult<T>? lastSuccessfulResult,
    Object? error,
    Object? errorDataKey,
    // Applied only to lastSuccessfulResult. Fresh results and errors must
    // match activeDataKey exactly.
    UxDataKeyCompatibility isCompatibleDataKey = uxSameDataKey,
  }) {
    final frozenActiveDataKey = _freezeDataKey(activeDataKey);

    if (error != null && errorDataKey == null) {
      throw ArgumentError.value(
        errorDataKey,
        'errorDataKey',
        'Expected errorDataKey when error is set.',
      );
    }

    if (newResult != null &&
        uxSameDataKey(newResult.dataKey, frozenActiveDataKey)) {
      return UxLoadingState<T>._(
        status: _statusForResult(newResult),
        activeDataKey: frozenActiveDataKey,
        displayedResult: newResult,
      );
    }

    final previousResult = _compatibleResult(
      activeDataKey: frozenActiveDataKey,
      lastSuccessfulResult: lastSuccessfulResult,
      isCompatibleDataKey: isCompatibleDataKey,
    );

    final activeError = error != null &&
        errorDataKey != null &&
        uxSameDataKey(errorDataKey, frozenActiveDataKey);

    if (isLoading) {
      if (previousResult != null) {
        return UxLoadingState<T>._(
          status: UxLoadingStatus.refreshing,
          activeDataKey: frozenActiveDataKey,
          displayedResult: previousResult,
        );
      }

      return UxLoadingState<T>._(
        status: UxLoadingStatus.initialLoading,
        activeDataKey: frozenActiveDataKey,
      );
    }

    if (activeError) {
      if (previousResult != null) {
        return UxLoadingState<T>._(
          status: UxLoadingStatus.errorWithData,
          activeDataKey: frozenActiveDataKey,
          displayedResult: previousResult,
          error: error,
        );
      }

      return UxLoadingState<T>._(
        status: UxLoadingStatus.errorWithoutData,
        activeDataKey: frozenActiveDataKey,
        error: error,
      );
    }

    if (previousResult != null) {
      return UxLoadingState<T>._(
        status: _statusForResult(previousResult),
        activeDataKey: frozenActiveDataKey,
        displayedResult: previousResult,
      );
    }

    return UxLoadingState<T>._(
      status: UxLoadingStatus.initialLoading,
      activeDataKey: frozenActiveDataKey,
    );
  }

  final UxLoadingStatus status;

  /// Active request identity. Compatible cached result keys can differ.
  /// Include a request generation when same-filter requests can overlap.
  /// Prefer immutable value keys. Collection keys are frozen; custom mutable
  /// key objects remain caller responsibility.
  final Object activeDataKey;
  final UxLoadedResult<T>? displayedResult;
  final Object? error;

  bool get isInitialLoading => status == UxLoadingStatus.initialLoading;
  bool get isRefreshing => status == UxLoadingStatus.refreshing;
  bool get hasData => status == UxLoadingStatus.hasData;
  bool get isEmpty => status == UxLoadingStatus.empty;
  bool get isDomainState => status == UxLoadingStatus.domain;

  /// Error state with any previous loaded result: data, empty, or domain.
  bool get isErrorWithData => status == UxLoadingStatus.errorWithData;
  bool get isErrorWithPreviousResult => isErrorWithData;
  bool get isErrorWithoutData => status == UxLoadingStatus.errorWithoutData;
  bool get hasError => error != null;

  bool get canShowFullScreenLoader => isInitialLoading;
  bool get canShowEmptyState => isEmpty;
  bool get hasDisplayResult => displayedResult != null;

  /// Displayed payload, if the current displayed result carries one.
  /// Can be non-null for [UxLoadingStatus.domain] while [hasData] is false.
  T? get dataOrNull => displayedResult?.data;

  @override
  String toString() {
    return 'UxLoadingState<$T>('
        'status: $status, '
        'activeDataKey: $activeDataKey, '
        'displayedResult: $displayedResult, '
        'error: $error'
        ')';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UxLoadingState<T> &&
            runtimeType == other.runtimeType &&
            other.status == status &&
            _uxEquality.equals(other.activeDataKey, activeDataKey) &&
            other.displayedResult == displayedResult &&
            identical(other.error, error);
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      status,
      _uxEquality.hash(activeDataKey),
      displayedResult,
      identityHashCode(error),
    );
  }
}

UxLoadingStatus _statusForResult<T extends Object>(UxLoadedResult<T> result) {
  return switch (result.kind) {
    UxLoadedResultKind.data => UxLoadingStatus.hasData,
    UxLoadedResultKind.empty => UxLoadingStatus.empty,
    UxLoadedResultKind.domain => UxLoadingStatus.domain,
  };
}

UxLoadedResult<T>? _compatibleResult<T extends Object>({
  required Object activeDataKey,
  required UxLoadedResult<T>? lastSuccessfulResult,
  required UxDataKeyCompatibility isCompatibleDataKey,
}) {
  if (lastSuccessfulResult == null) {
    return null;
  }

  if (!isCompatibleDataKey(lastSuccessfulResult.dataKey, activeDataKey)) {
    return null;
  }

  return lastSuccessfulResult;
}

UxLoadedResult<List<T>> uxLoadedListResult<T extends Object>({
  required Object dataKey,
  required List<T> items,
}) {
  if (items.isEmpty) {
    return UxLoadedResult<List<T>>.empty(dataKey: dataKey);
  }

  return UxLoadedResult<List<T>>.data(
    dataKey: dataKey,
    data: List<T>.unmodifiable(items),
  );
}

/// Resolves list state for a confirmed result key.
/// If [resultDataKey] is omitted, [items] are treated as active-key data.
UxLoadingState<List<T>> uxResolveListLoadingState<T extends Object>({
  required Object activeDataKey,
  required bool isLoading,
  required bool hasConfirmedResult,
  List<T>? items,
  Object? resultDataKey,
  UxLoadedResult<List<T>>? lastSuccessfulResult,
  Object? error,
  Object? errorDataKey,
  UxDataKeyCompatibility isCompatibleDataKey = uxSameDataKey,
}) {
  if (hasConfirmedResult && items == null) {
    throw ArgumentError.value(
      items,
      'items',
      'Expected items when hasConfirmedResult is true.',
    );
  }

  final newResult = hasConfirmedResult && items != null
      ? uxLoadedListResult<T>(
          dataKey: resultDataKey ?? activeDataKey,
          items: items,
        )
      : null;

  return UxLoadingState<List<T>>.resolve(
    activeDataKey: activeDataKey,
    isLoading: isLoading,
    newResult: newResult,
    lastSuccessfulResult: lastSuccessfulResult,
    error: error,
    errorDataKey: errorDataKey,
    isCompatibleDataKey: isCompatibleDataKey,
  );
}
