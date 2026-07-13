import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/ux_loading_state.dart';
import '/services/ux_session_cache_lifecycle.dart';
import '/services/ux_session_loaded_result_cache.dart';
import 'profile_widget.dart' show ProfileWidget;
import 'package:flutter/material.dart';

class ProfileModel extends FlutterFlowModel<ProfileWidget> {
  static final UxSessionLoadedResultCache<UsersRecord> _userDocumentCache =
      UxSessionLoadedResultCache<UsersRecord>();
  static final UxSessionLoadedResultCache<List<UserWordsRecord>> _wordsCache =
      UxSessionLoadedResultCache<List<UserWordsRecord>>();
  static final UxSessionLoadedResultCache<List<StatsRecord>> _statsCache =
      UxSessionLoadedResultCache<List<StatsRecord>>();

  static void ensureSessionCacheLifecycleRegistered() {
    UxSessionCacheLifecycle.register(debugClearSessionCache);
  }

  static UsersRecord? cachedUserDocument(String userId) =>
      _userDocumentCache.read('profile:$userId:primary')?.data;

  static List<UserWordsRecord>? cachedWords(String userId) =>
      _wordsCache.readItems('profile:$userId:words');

  static List<StatsRecord>? cachedStats(String userId) =>
      _statsCache.readItems('profile:$userId:stats');

  static void cacheUserDocument(UsersRecord user) {
    _userDocumentCache.write(
      UxLoadedResult<UsersRecord>.data(
        dataKey: 'profile:${user.reference.id}:primary',
        data: user,
      ),
    );
  }

  static void cacheWords(String userId, List<UserWordsRecord> words) {
    _wordsCache.writeItems(
      dataKey: 'profile:$userId:words',
      items: words,
    );
  }

  static void cacheStats(String userId, List<StatsRecord> stats) {
    _statsCache.writeItems(
      dataKey: 'profile:$userId:stats',
      items: stats,
    );
  }

  static void debugClearSessionCache() {
    _userDocumentCache.clear();
    _wordsCache.clear();
    _statsCache.clear();
  }

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
