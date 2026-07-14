import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/ux_session_cache_lifecycle.dart';
import '/services/ux_session_loaded_result_cache.dart';
import 'my_calls_widget.dart' show MyCallsWidget;
import 'package:flutter/material.dart';

class MyCallsModel extends FlutterFlowModel<MyCallsWidget> {
  static final UxSessionLoadedResultCache<List<VideoSessionsRecord>>
      _historyCache = UxSessionLoadedResultCache<List<VideoSessionsRecord>>();
  static int _sessionCacheGeneration = 0;

  static int get sessionCacheGeneration => _sessionCacheGeneration;

  static Object _cacheKey(String ownerUid) => ['myCalls', ownerUid];

  static void ensureSessionCacheLifecycleRegistered() {
    UxSessionCacheLifecycle.register(debugClearSessionCache);
  }

  static List<VideoSessionsRecord>? cachedHistory(String ownerUid) =>
      _historyCache.readItems(_cacheKey(ownerUid));

  static void cacheHistory(
    String ownerUid,
    List<VideoSessionsRecord> sessions, {
    required int expectedGeneration,
  }) {
    if (expectedGeneration != _sessionCacheGeneration) {
      return;
    }
    _historyCache.writeItems(
      dataKey: _cacheKey(ownerUid),
      items: sessions,
    );
  }

  static void debugClearSessionCache() {
    _sessionCacheGeneration += 1;
    _historyCache.clear();
  }

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
