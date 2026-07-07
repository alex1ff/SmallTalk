import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/ux_session_loaded_result_cache.dart';
import 'words_widget.dart' show WordsWidget;
import 'package:flutter/material.dart';

class WordsModel extends FlutterFlowModel<WordsWidget> {
  static final UxSessionLoadedResultCache<List<UserWordsRecord>> _wordsCache =
      UxSessionLoadedResultCache<List<UserWordsRecord>>();
  static final UxSessionLoadedResultCache<List<WordReviewsRecord>>
      _wordReviewsCache = UxSessionLoadedResultCache<List<WordReviewsRecord>>();

  // Cached stream so it is not recreated on every build().
  Stream<List<UserWordsRecord>>? wordsStream;
  Stream<List<WordReviewsRecord>>? wordReviewsStream;
  String? userCacheKey;

  List<UserWordsRecord>? get cachedWords {
    final cacheKey = userCacheKey;
    if (cacheKey == null) {
      return null;
    }
    return _wordsCache.readItems(cacheKey);
  }

  List<WordReviewsRecord>? get cachedWordReviews {
    final cacheKey = userCacheKey;
    if (cacheKey == null) {
      return null;
    }
    return _wordReviewsCache.readItems(cacheKey);
  }

  void cacheWords(List<UserWordsRecord> words) {
    final cacheKey = userCacheKey;
    if (cacheKey == null) {
      return;
    }
    _wordsCache.writeItems(dataKey: cacheKey, items: words);
  }

  void cacheWordReviews(List<WordReviewsRecord> reviews) {
    final cacheKey = userCacheKey;
    if (cacheKey == null) {
      return;
    }
    _wordReviewsCache.writeItems(dataKey: cacheKey, items: reviews);
  }

  static void debugClearSessionCache() {
    _wordsCache.clear();
    _wordReviewsCache.clear();
  }

  static bool shouldCacheStreamSnapshot<T>(
    AsyncSnapshot<List<T>> snapshot,
  ) {
    return snapshot.hasData &&
        snapshot.connectionState != ConnectionState.waiting;
  }

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
