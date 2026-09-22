import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/ux_session_cache_lifecycle.dart';
import '/services/ux_session_loaded_result_cache.dart';
import 'my_rew_widget.dart' show MyRewWidget;
import 'package:flutter/material.dart';

class MyRewModel extends FlutterFlowModel<MyRewWidget> {
  static final UxSessionLoadedResultCache<List<ReviewsRecord>> _reviewsCache =
      UxSessionLoadedResultCache<List<ReviewsRecord>>();
  static int _sessionCacheGeneration = 0;

  static int get sessionCacheGeneration => _sessionCacheGeneration;

  static Object _cacheKey(String ownerUid) => ['myRew', ownerUid];

  static void ensureSessionCacheLifecycleRegistered() {
    UxSessionCacheLifecycle.register(debugClearSessionCache);
  }

  static List<ReviewsRecord>? cachedReviews(String ownerUid) =>
      _reviewsCache.readItems(_cacheKey(ownerUid));

  static void cacheReviews(
    String ownerUid,
    List<ReviewsRecord> reviews, {
    required int expectedGeneration,
  }) {
    if (expectedGeneration != _sessionCacheGeneration) {
      return;
    }
    _reviewsCache.writeItems(
      dataKey: _cacheKey(ownerUid),
      items: reviews,
    );
  }

  static void debugClearSessionCache() {
    _sessionCacheGeneration += 1;
    _reviewsCache.clear();
  }

  ///  Local state fields for this page.

  int rate = 0;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
