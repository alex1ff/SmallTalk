import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/ux_session_cache_lifecycle.dart';
import '/services/ux_session_loaded_result_cache.dart';
import 'black_list_widget.dart' show BlackListWidget;
import 'package:flutter/material.dart';

class BlackListModel extends FlutterFlowModel<BlackListWidget> {
  static final UxSessionLoadedResultCache<List<DocumentReference>>
      _blockedUsersCache =
      UxSessionLoadedResultCache<List<DocumentReference>>();
  static int _sessionCacheGeneration = 0;

  static int get sessionCacheGeneration => _sessionCacheGeneration;

  static Object _cacheKey(String ownerUid) => ['blackList', ownerUid];

  static void ensureSessionCacheLifecycleRegistered() {
    UxSessionCacheLifecycle.register(debugClearSessionCache);
  }

  static List<DocumentReference>? cachedBlockedUsers(String ownerUid) =>
      _blockedUsersCache.readItems(_cacheKey(ownerUid));

  static void cacheBlockedUsers(
    String ownerUid,
    List<DocumentReference> blockedUsers, {
    required int expectedGeneration,
  }) {
    if (expectedGeneration != _sessionCacheGeneration) {
      return;
    }
    _blockedUsersCache.writeItems(
      dataKey: _cacheKey(ownerUid),
      items: blockedUsers,
    );
  }

  static void debugClearSessionCache() {
    _sessionCacheGeneration += 1;
    _blockedUsersCache.clear();
  }

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
