import 'dart:collection';

import 'package:collection/collection.dart';

import 'ux_loading_state.dart';

const _uxSessionCacheEquality = DeepCollectionEquality();

Object _freezeSessionDataKey(Object value) {
  return _freezeSessionValue(value) as Object;
}

Object? _freezeSessionValue(Object? value) {
  if (value is Map) {
    return Map<Object?, Object?>.unmodifiable(
      value.map(
        (key, mapValue) => MapEntry(
          _freezeSessionValue(key),
          _freezeSessionValue(mapValue),
        ),
      ),
    );
  }

  if (value is Set) {
    return Set<Object?>.unmodifiable(value.map(_freezeSessionValue));
  }

  if (value is Iterable) {
    return List<Object?>.unmodifiable(value.map(_freezeSessionValue));
  }

  return value;
}

DateTime _normalizeUtc(DateTime dateTime) {
  return dateTime.isUtc ? dateTime : dateTime.toUtc();
}

final class UxSessionLoadedResultCache<T extends Object> {
  UxSessionLoadedResultCache({
    this.maxEntries = 64,
    this.ttl = const Duration(minutes: 30),
    DateTime Function()? nowUtcProvider,
  }) : _nowUtcProvider = nowUtcProvider {
    if (maxEntries <= 0) {
      throw ArgumentError.value(
        maxEntries,
        'maxEntries',
        'Expected a positive entry limit.',
      );
    }
    if (ttl.inMicroseconds <= 0) {
      throw ArgumentError.value(
        ttl,
        'ttl',
        'Expected a positive cache TTL.',
      );
    }
  }

  final int maxEntries;
  final Duration ttl;
  final DateTime Function()? _nowUtcProvider;
  final LinkedHashMap<_UxSessionCacheKey, _UxSessionCacheEntry<T>> _entries =
      LinkedHashMap<_UxSessionCacheKey, _UxSessionCacheEntry<T>>();

  int get length {
    _pruneExpiredEntries();
    return _entries.length;
  }

  bool get isEmpty => length == 0;
  bool get isNotEmpty => length > 0;

  UxLoadedResult<T>? read(Object dataKey) {
    final key = _UxSessionCacheKey(dataKey);
    final entry = _entries.remove(key);
    if (entry == null) {
      return null;
    }

    if (!entry.isFresh(nowUtc: _nowUtc(), ttl: ttl)) {
      return null;
    }

    _entries[key] = entry;
    return entry.result;
  }

  void write(UxLoadedResult<T> result) {
    final key = _UxSessionCacheKey(result.dataKey);
    _entries.remove(key);
    _entries[key] = _UxSessionCacheEntry<T>(
      result: result,
      fetchedAtUtc: _nowUtc(),
    );
    _pruneOldestEntries();
  }

  void remove(Object dataKey) {
    _entries.remove(_UxSessionCacheKey(dataKey));
  }

  void clear() {
    _entries.clear();
  }

  DateTime _nowUtc() {
    final now = _nowUtcProvider?.call() ?? DateTime.now().toUtc();
    return _normalizeUtc(now);
  }

  void _pruneOldestEntries() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void _pruneExpiredEntries() {
    final nowUtc = _nowUtc();
    _entries.removeWhere(
      (_, entry) => !entry.isFresh(nowUtc: nowUtc, ttl: ttl),
    );
  }
}

extension UxSessionLoadedListCache<T extends Object>
    on UxSessionLoadedResultCache<List<T>> {
  List<T>? readItems(Object dataKey) {
    final result = read(dataKey);
    if (result == null) {
      return null;
    }

    return switch (result.kind) {
      UxLoadedResultKind.data => result.data ?? List<T>.empty(growable: false),
      UxLoadedResultKind.empty => List<T>.empty(growable: false),
      UxLoadedResultKind.domain => result.data,
    };
  }

  void writeItems({
    required Object dataKey,
    required List<T> items,
  }) {
    write(
      uxLoadedListResult<T>(
        dataKey: dataKey,
        items: items,
      ),
    );
  }
}

final class _UxSessionCacheKey {
  _UxSessionCacheKey(Object dataKey) : dataKey = _freezeSessionDataKey(dataKey);

  final Object dataKey;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _UxSessionCacheKey &&
            _uxSessionCacheEquality.equals(other.dataKey, dataKey);
  }

  @override
  int get hashCode => _uxSessionCacheEquality.hash(dataKey);
}

final class _UxSessionCacheEntry<T extends Object> {
  const _UxSessionCacheEntry({
    required this.result,
    required this.fetchedAtUtc,
  });

  final UxLoadedResult<T> result;
  final DateTime fetchedAtUtc;

  bool isFresh({
    required DateTime nowUtc,
    required Duration ttl,
  }) {
    return !fetchedAtUtc.add(ttl).isBefore(nowUtc);
  }
}
