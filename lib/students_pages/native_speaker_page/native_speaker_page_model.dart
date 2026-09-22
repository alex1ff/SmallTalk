import '/backend/backend.dart';
import '/components/language_card_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/ux_session_cache_lifecycle.dart';
import '/services/ux_session_loaded_result_cache.dart';
import 'native_speaker_page_widget.dart' show NativeSpeakerPageWidget;
import 'package:flutter/material.dart';

class NativeSpeakerPageModel extends FlutterFlowModel<NativeSpeakerPageWidget> {
  static final UxSessionLoadedResultCache<List<ReviewsRecord>> _reviewsCache =
      UxSessionLoadedResultCache<List<ReviewsRecord>>();
  static int _sessionCacheGeneration = 0;

  static int get sessionCacheGeneration => _sessionCacheGeneration;

  static Object _cacheKey(String targetPath) => [
        'nativeSpeakerPageReviews',
        targetPath,
      ];

  static void ensureSessionCacheLifecycleRegistered() {
    UxSessionCacheLifecycle.register(debugClearReviewsSessionCache);
  }

  static List<ReviewsRecord>? cachedReviews(String targetPath) =>
      _reviewsCache.readItems(_cacheKey(targetPath));

  static void cacheReviews(
    String targetPath,
    List<ReviewsRecord> reviews, {
    required int expectedGeneration,
  }) {
    if (expectedGeneration != _sessionCacheGeneration) {
      return;
    }
    _reviewsCache.writeItems(
      dataKey: _cacheKey(targetPath),
      items: reviews,
    );
  }

  static void debugClearReviewsSessionCache() {
    _sessionCacheGeneration += 1;
    _reviewsCache.clear();
  }

  ///  Local state fields for this page.

  int numMaxLineAbout = 4;

  int rate = 0;

  ///  State fields for stateful widgets in this page.

  // Model for Language_Card component.
  late LanguageCardModel languageCardModel1;
  // Model for Language_Card component.
  late LanguageCardModel languageCardModel2;
  // State field(s) for RatingBar widget.
  double? ratingBarValue;

  @override
  void initState(BuildContext context) {
    languageCardModel1 = createModel(context, () => LanguageCardModel());
    languageCardModel2 = createModel(context, () => LanguageCardModel());
  }

  @override
  void dispose() {
    languageCardModel1.dispose();
    languageCardModel2.dispose();
  }
}
