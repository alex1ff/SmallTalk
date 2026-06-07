import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'words_widget.dart' show WordsWidget;
import 'package:flutter/material.dart';

class WordsModel extends FlutterFlowModel<WordsWidget> {
  static String? _cachedWordsUserPath;
  static String? _cachedWordReviewsUserPath;
  static List<UserWordsRecord>? _cachedWords;
  static List<WordReviewsRecord>? _cachedWordReviews;

  // Cached stream so it is not recreated on every build().
  Stream<List<UserWordsRecord>>? wordsStream;
  Stream<List<WordReviewsRecord>>? wordReviewsStream;
  String? userCacheKey;

  List<UserWordsRecord>? get cachedWords {
    final cacheKey = userCacheKey;
    if (cacheKey == null || cacheKey != _cachedWordsUserPath) {
      return null;
    }
    return _cachedWords;
  }

  List<WordReviewsRecord>? get cachedWordReviews {
    final cacheKey = userCacheKey;
    if (cacheKey == null || cacheKey != _cachedWordReviewsUserPath) {
      return null;
    }
    return _cachedWordReviews;
  }

  void cacheWords(List<UserWordsRecord> words) {
    final cacheKey = userCacheKey;
    if (cacheKey == null) {
      return;
    }
    _cachedWordsUserPath = cacheKey;
    _cachedWords = List.unmodifiable(words);
  }

  void cacheWordReviews(List<WordReviewsRecord> reviews) {
    final cacheKey = userCacheKey;
    if (cacheKey == null) {
      return;
    }
    _cachedWordReviewsUserPath = cacheKey;
    _cachedWordReviews = List.unmodifiable(reviews);
  }

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
