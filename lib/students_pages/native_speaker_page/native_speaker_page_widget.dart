import '/auth/firebase_auth/auth_util.dart';
import '/components/language_card_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/components/app_loading_indicator.dart';
import '/components/empty/empty_widget.dart';
import '/components/review_card/review_card_widget.dart';
import '/components/ux_error_state.dart';
import '/components/ux_refreshing_indicator_overlay.dart';
import '/components/wrapper.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/permissions_util.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/components/no_balance_widget.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/chat_thread/open_chat_thread.dart';
import '/services/reviews_load_result.dart';
import '/services/safe_debug_log.dart';
import '/services/user_match_profile.dart';
import '/services/ux_session_cache_lifecycle.dart';
// ─── SUBSCRIPTION REWORK ─ gating helper. Replaces balanceST < 0 check.
import '/utils/subscription_utils.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'native_speaker_page_model.dart';
export 'native_speaker_page_model.dart';

const ValueKey<String> nativeSpeakerReviewsLoadingKey =
    ValueKey<String>('native_speaker_reviews_loading');
const ValueKey<String> nativeSpeakerReviewsEmptyKey =
    ValueKey<String>('native_speaker_reviews_empty');
const ValueKey<String> nativeSpeakerReviewsSectionKey =
    ValueKey<String>('native_speaker_reviews_section');
const ValueKey<String> nativeSpeakerReviewsListKey =
    ValueKey<String>('native_speaker_reviews_list');
const ValueKey<String> nativeSpeakerReviewsErrorKey =
    ValueKey<String>('native_speaker_reviews_error');
const ValueKey<String> nativeSpeakerReviewsRefreshErrorKey =
    ValueKey<String>('native_speaker_reviews_refresh_error');
const ValueKey<String> nativeSpeakerReviewsRetryButtonKey =
    ValueKey<String>('native_speaker_reviews_retry_button');
const ValueKey<String> nativeSpeakerReviewsRefreshingKey =
    ValueKey<String>('native_speaker_reviews_refreshing');
const ValueKey<String> nativeSpeakerReviewsLoadMoreButtonKey =
    ValueKey<String>('native_speaker_reviews_load_more_button');
const int nativeSpeakerReviewsPageSize = 20;
const ValueKey<String> nativeSpeakerPageScrollKey =
    ValueKey<String>('native_speaker_page_scroll');
const ValueKey<String> nativeSpeakerFavoriteActionKey =
    ValueKey<String>('native_speaker_favorite_action');
const ValueKey<String> nativeSpeakerDirectCallActionKey =
    ValueKey<String>('native_speaker_direct_call_action');
const ValueKey<String> nativeSpeakerStatsValueKey =
    ValueKey<String>('native_speaker_stats_value');
const ValueKey<String> nativeSpeakerRatingDistributionKey =
    ValueKey<String>('native_speaker_rating_distribution');

ValueKey<String> nativeSpeakerReviewKey(ReviewsRecord review) =>
    ValueKey<String>('native_speaker_review_${review.reference.path}');
ValueKey<String> nativeSpeakerRatingFilterKey(int rating) =>
    ValueKey<String>('native_speaker_rating_filter_$rating');

typedef NativeSpeakerReviewsLoader = Future<List<ReviewsRecord>> Function(
  DocumentReference targetReference,
);
typedef NativeSpeakerReviewsResultLoader = Future<ReviewsLoadResult> Function(
  DocumentReference targetReference,
);
typedef NativeSpeakerReviewsResultStreamFactory = Stream<ReviewsLoadResult>
    Function(
  DocumentReference targetReference,
);
typedef NativeSpeakerPublicProfileStreamFactory
    = Stream<UserPublicProfilesRecord?> Function(
  DocumentReference? targetReference,
);
typedef NativeSpeakerStatsLoader = Future<List<StatsRecord>> Function(
  DocumentReference? targetReference,
);
typedef NativeSpeakerAuthUidProvider = String Function();
typedef NativeSpeakerDirectCallStatusChecker = Future<bool> Function(
  String targetTutorId,
);
typedef NativeSpeakerMediaPermissionRequester = Future<bool> Function();
typedef NativeSpeakerDirectCallNavigator = Future<void> Function(
  BuildContext context,
  String targetTutorId,
);

final class _BoundedNativeSpeakerReviewsResult {
  const _BoundedNativeSpeakerReviewsResult({
    required this.result,
    required this.hasMore,
    this.visibleLimit,
  });

  final ReviewsLoadResult result;
  final bool hasMore;
  final int? visibleLimit;
}

class NativeSpeakerPageWidget extends StatefulWidget {
  const NativeSpeakerPageWidget({
    super.key,
    required this.nsUserDocRef,
    this.hideDirectCallAction = false,
    this.reviewsLoader,
    this.reviewsResultLoader,
    this.reviewsResultStreamFactory,
    this.publicProfileStreamFactory,
    this.statsLoader,
    this.authUidStream,
    this.authUidProvider,
    this.directCallStatusChecker,
    this.mediaPermissionRequester,
    this.directCallNavigator,
  });

  final DocumentReference? nsUserDocRef;
  final bool hideDirectCallAction;
  @visibleForTesting
  final NativeSpeakerReviewsLoader? reviewsLoader;
  @visibleForTesting
  final NativeSpeakerReviewsResultLoader? reviewsResultLoader;
  @visibleForTesting
  final NativeSpeakerReviewsResultStreamFactory? reviewsResultStreamFactory;
  @visibleForTesting
  final NativeSpeakerPublicProfileStreamFactory? publicProfileStreamFactory;
  @visibleForTesting
  final NativeSpeakerStatsLoader? statsLoader;
  @visibleForTesting
  final Stream<String>? authUidStream;
  @visibleForTesting
  final NativeSpeakerAuthUidProvider? authUidProvider;
  @visibleForTesting
  final NativeSpeakerDirectCallStatusChecker? directCallStatusChecker;
  @visibleForTesting
  final NativeSpeakerMediaPermissionRequester? mediaPermissionRequester;
  @visibleForTesting
  final NativeSpeakerDirectCallNavigator? directCallNavigator;

  static String routeName = 'NativeSpeakerPage';
  static String routePath = '/nativeSpeakerPage';

  @override
  State<NativeSpeakerPageWidget> createState() =>
      _NativeSpeakerPageWidgetState();
}

class _NativeSpeakerPageWidgetState extends State<NativeSpeakerPageWidget> {
  late NativeSpeakerPageModel _model;
  late Stream<UserPublicProfilesRecord?> _publicProfileStream;
  late Future<List<StatsRecord>> _statsFuture;

  String _activeReviewsTargetPath = '';
  String _boundTargetPath = '';
  int _targetEpoch = 0;
  int _authEpoch = 0;
  int _authSubscriptionGeneration = 0;
  int _reviewsRequestGeneration = 0;
  StreamSubscription<String>? _authLifecycleSubscription;
  StreamSubscription<_BoundedNativeSpeakerReviewsResult>?
      _reviewsResultSubscription;
  String? _latestAuthStreamUid;
  List<ReviewsRecord>? _lastSuccessfulReviews;
  Object? _reviewsError;
  bool _reviewsLoading = false;
  int _reviewsLimit = nativeSpeakerReviewsPageSize;
  bool _reviewsHasMore = false;
  Future<Map<int, int>>? _ratingCountsFuture;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  bool _hapticFired = false;
  bool _isSnapping = false;

  String _localizedText({
    required String ruText,
    required String enText,
  }) {
    return FFLocalizations.of(context).getVariableText(
      ruText: ruText,
      enText: enText,
    );
  }

  String _localizedCountryName(CountryStruct country) {
    final countryName = FFLocalizations.of(context)
        .getVariableText(
          ruText: country.nameRu.isNotEmpty ? country.nameRu : country.nameEn,
          enText: country.nameEn.isNotEmpty ? country.nameEn : country.nameRu,
        )
        .trim();
    if (countryName.isNotEmpty) {
      return countryName;
    }
    return country.code;
  }

  String _profileDisplayName(UserPublicProfilesRecord tutorProfile) {
    final displayName = tutorProfile.displayName.trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }

    return _localizedText(
      ruText: 'Пользователь',
      enText: 'User',
    );
  }

  String _profileCountryAndStatus(UserPublicProfilesRecord tutorProfile) {
    final countryName = _localizedCountryName(tutorProfile.countryNS);
    final status = _buildTutorStatusLabel(tutorProfile);
    if (countryName.isEmpty) {
      return status;
    }

    return '$countryName | $status';
  }

  String _buildTutorStatusLabel(UserPublicProfilesRecord tutorProfile) {
    if (tutorProfile.approvedTeacher) {
      return _localizedText(
        ruText: 'Проверенный преподаватель',
        enText: 'Verified tutor',
      );
    }

    return _localizedText(
      ruText: 'Носитель языка',
      enText: 'Native speaker',
    );
  }

  bool _isVerifiedNativeSpeaker(UserPublicProfilesRecord tutorProfile) {
    return tutorProfile.role == UserRole.native_speaker &&
        tutorProfile.approvedTeacher;
  }

  Stream<UserPublicProfilesRecord?> _nativeSpeakerPublicProfileStream(
    DocumentReference? targetRef,
  ) {
    if (targetRef == null || targetRef.id.isEmpty) {
      return Stream<UserPublicProfilesRecord?>.value(null);
    }

    return UserPublicProfilesRecord.maybeGetDocument(
      UserPublicProfilesRecord.collection.doc(targetRef.id),
    );
  }

  void _bindNativeSpeakerRef(DocumentReference? targetRef) {
    _targetEpoch += 1;
    _boundTargetPath = targetRef?.path ?? '';
    _publicProfileStream = widget.publicProfileStreamFactory?.call(targetRef) ??
        _nativeSpeakerPublicProfileStream(targetRef);
    _statsFuture = widget.statsLoader?.call(targetRef) ??
        queryStatsRecordOnce(
          parent: targetRef,
          queryBuilder: (statsRecord) => statsRecord.where(
            'isAllTime',
            isEqualTo: true,
          ),
          singleRecord: true,
        );
    _activateReviewsTarget(targetRef);
    _model.numMaxLineAbout = 4;
    _model.rate = 0;
    _model.ratingBarValue = null;
  }

  Query _reviewsQuery(
    DocumentReference targetReference, {
    int? fetchLimit,
  }) {
    final query = ReviewsRecord.collection
        .where(
          'toUserId',
          isEqualTo: targetReference,
        )
        .orderBy('createdAt', descending: true);
    return fetchLimit == null ? query : query.limit(fetchLimit);
  }

  ReviewsLoadResult _reviewsResultFromSnapshot(
    QuerySnapshot snapshot,
  ) {
    return ReviewsLoadResult(
      reviews: List<ReviewsRecord>.unmodifiable(
        snapshot.docs.map(ReviewsRecord.fromSnapshot),
      ),
      isFromCache: snapshot.metadata.isFromCache,
      hasPendingWrites: snapshot.metadata.hasPendingWrites,
    );
  }

  _BoundedNativeSpeakerReviewsResult _boundedReviewsResult(
    ReviewsLoadResult result,
    int visibleLimit,
  ) {
    return _BoundedNativeSpeakerReviewsResult(
      result: ReviewsLoadResult(
        reviews: List<ReviewsRecord>.unmodifiable(
          result.reviews.take(visibleLimit),
        ),
        isFromCache: result.isFromCache,
        hasPendingWrites: result.hasPendingWrites,
      ),
      hasMore: result.reviews.length > visibleLimit,
      visibleLimit: visibleLimit,
    );
  }

  Stream<_BoundedNativeSpeakerReviewsResult> _defaultReviewsResultStream(
    DocumentReference targetReference,
    int visibleLimit,
  ) {
    return _reviewsQuery(
      targetReference,
      fetchLimit: visibleLimit + 1,
    )
        .snapshots(includeMetadataChanges: true)
        .map(_reviewsResultFromSnapshot)
        .map((result) => _boundedReviewsResult(result, visibleLimit));
  }

  Stream<_BoundedNativeSpeakerReviewsResult> _reviewsResultStream(
    DocumentReference targetReference,
    int visibleLimit,
  ) {
    final streamFactory = widget.reviewsResultStreamFactory;
    if (streamFactory != null) {
      return streamFactory(targetReference)
          .map((result) => _boundedReviewsResult(result, visibleLimit));
    }
    return _defaultReviewsResultStream(targetReference, visibleLimit);
  }

  bool get _reviewsPaginationEnabled =>
      widget.reviewsResultStreamFactory != null ||
      (widget.reviewsResultLoader == null && widget.reviewsLoader == null);

  bool get _usesDefaultReviewsSource =>
      widget.reviewsResultStreamFactory == null &&
      widget.reviewsResultLoader == null &&
      widget.reviewsLoader == null;

  Future<Map<int, int>> _loadRatingCounts(
    DocumentReference targetReference,
  ) async {
    final baseQuery = ReviewsRecord.collection.where(
      'toUserId',
      isEqualTo: targetReference,
    );
    final snapshots = await Future.wait([
      for (var rating = 1; rating <= 5; rating++)
        baseQuery.where('rating', isEqualTo: rating).count().get(),
    ]);
    return <int, int>{
      for (var index = 0; index < snapshots.length; index++)
        index + 1: snapshots[index].count ?? 0,
    };
  }

  bool get _usesReviewsResultStream =>
      widget.reviewsResultStreamFactory != null ||
      (widget.reviewsResultLoader == null && widget.reviewsLoader == null);

  Future<ReviewsLoadResult> _loadReviews(
    DocumentReference targetReference,
  ) async {
    final resultLoader = widget.reviewsResultLoader;
    if (resultLoader != null) {
      return resultLoader(targetReference);
    }

    final legacyLoader = widget.reviewsLoader;
    if (legacyLoader != null) {
      return ReviewsLoadResult.authoritative(
        await legacyLoader(targetReference),
      );
    }

    throw StateError('A reviews loader is not configured.');
  }

  Future<ReviewsLoadResult> _loadReviewsFromServer(
    DocumentReference targetReference,
  ) async {
    final resultLoader = widget.reviewsResultLoader;
    if (resultLoader != null) {
      return resultLoader(targetReference);
    }

    final snapshot = await _reviewsQuery(targetReference).get(
      const GetOptions(source: Source.server),
    );
    return _reviewsResultFromSnapshot(snapshot);
  }

  void _activateReviewsTarget(DocumentReference? targetReference) {
    _reviewsResultSubscription?.cancel();
    _reviewsResultSubscription = null;
    _reviewsRequestGeneration += 1;
    final targetPath = targetReference?.path ?? '';
    _activeReviewsTargetPath = targetPath;
    _reviewsLimit = nativeSpeakerReviewsPageSize;
    _reviewsHasMore = false;
    _ratingCountsFuture = targetReference != null &&
            targetPath.isNotEmpty &&
            _usesDefaultReviewsSource
        ? _loadRatingCounts(targetReference)
        : null;
    final cachedReviews = targetPath.isEmpty
        ? null
        : NativeSpeakerPageModel.cachedReviews(targetPath);
    _lastSuccessfulReviews = cachedReviews == null || !_reviewsPaginationEnabled
        ? cachedReviews
        : List<ReviewsRecord>.unmodifiable(
            cachedReviews.take(_reviewsLimit),
          );
    _reviewsError = null;
    _reviewsLoading = targetReference != null && targetPath.isNotEmpty;
    if (targetReference != null && targetPath.isNotEmpty) {
      _startReviewsLoad(targetReference, notify: false);
    }
  }

  void _startReviewsLoad(
    DocumentReference targetReference, {
    required bool notify,
    bool authoritativeFollowUp = false,
  }) {
    final targetPath = targetReference.path;
    if (targetPath.isEmpty || targetPath != _activeReviewsTargetPath) {
      return;
    }

    _reviewsResultSubscription?.cancel();
    _reviewsResultSubscription = null;
    final requestGeneration = ++_reviewsRequestGeneration;
    final cacheGeneration = NativeSpeakerPageModel.sessionCacheGeneration;
    final targetEpoch = _targetEpoch;
    final authEpoch = _authEpoch;
    final reviewsLimit = _reviewsLimit;
    _reviewsError = null;
    _reviewsLoading = true;
    if (notify && mounted) {
      setState(() {});
    }

    if (_usesReviewsResultStream) {
      _startReviewsResultStream(
        targetReference: targetReference,
        targetPath: targetPath,
        requestGeneration: requestGeneration,
        cacheGeneration: cacheGeneration,
        targetEpoch: targetEpoch,
        authEpoch: authEpoch,
        reviewsLimit: reviewsLimit,
      );
      return;
    }

    Future<ReviewsLoadResult>.sync(
      () => authoritativeFollowUp
          ? _loadReviewsFromServer(targetReference)
          : _loadReviews(targetReference),
    ).then<void>(
      (result) {
        if (!_reviewsRequestIsCurrent(
          targetPath,
          requestGeneration,
          targetEpoch,
          authEpoch,
        )) {
          return;
        }

        if (!result.isAuthoritative) {
          final previous = _lastSuccessfulReviews;
          final mergedReviews = mergeUnconfirmedReviews(
            previous: previous ?? const <ReviewsRecord>[],
            incoming: result.reviews,
          );
          final confirmationError = authoritativeFollowUp
              ? StateError('Could not confirm reviews with the server.')
              : null;
          setState(() {
            if (previous != null || mergedReviews.isNotEmpty) {
              _lastSuccessfulReviews = mergedReviews;
            }
            _reviewsError = confirmationError;
            _reviewsLoading = !authoritativeFollowUp;
          });
          if (!authoritativeFollowUp) {
            _startReviewsLoad(
              targetReference,
              notify: false,
              authoritativeFollowUp: true,
            );
          }
          return;
        }

        final stableReviews = List<ReviewsRecord>.unmodifiable(result.reviews);
        NativeSpeakerPageModel.cacheReviews(
          targetPath,
          stableReviews,
          expectedGeneration: cacheGeneration,
        );
        setState(() {
          _lastSuccessfulReviews = stableReviews;
          _reviewsError = null;
          _reviewsLoading = false;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_reviewsRequestIsCurrent(
          targetPath,
          requestGeneration,
          targetEpoch,
          authEpoch,
        )) {
          return;
        }
        setState(() {
          _reviewsError = error;
          _reviewsLoading = false;
        });
      },
    );
  }

  void _startReviewsResultStream({
    required DocumentReference targetReference,
    required String targetPath,
    required int requestGeneration,
    required int cacheGeneration,
    required int targetEpoch,
    required int authEpoch,
    required int reviewsLimit,
  }) {
    var receivedAuthoritativeResult = false;
    _reviewsResultSubscription =
        _reviewsResultStream(targetReference, reviewsLimit).listen(
      (boundedResult) {
        final result = boundedResult.result;
        if (!_reviewsRequestIsCurrent(
          targetPath,
          requestGeneration,
          targetEpoch,
          authEpoch,
        )) {
          return;
        }

        if (!result.isAuthoritative) {
          final previous = _lastSuccessfulReviews;
          final mergedReviews = mergeUnconfirmedReviews(
            previous: previous ?? const <ReviewsRecord>[],
            incoming: result.reviews,
          );
          final visibleReviews = boundedResult.visibleLimit == null
              ? mergedReviews
              : List<ReviewsRecord>.unmodifiable(
                  mergedReviews.take(boundedResult.visibleLimit!),
                );
          setState(() {
            if (previous != null || visibleReviews.isNotEmpty) {
              _lastSuccessfulReviews = visibleReviews;
            }
            _reviewsError = null;
            _reviewsLoading = true;
          });
          return;
        }

        receivedAuthoritativeResult = true;
        final stableReviews = List<ReviewsRecord>.unmodifiable(result.reviews);
        NativeSpeakerPageModel.cacheReviews(
          targetPath,
          stableReviews,
          expectedGeneration: cacheGeneration,
        );
        setState(() {
          _lastSuccessfulReviews = stableReviews;
          _reviewsHasMore = boundedResult.hasMore;
          _reviewsError = null;
          _reviewsLoading = false;
        });
        _reviewsResultSubscription?.cancel();
        _reviewsResultSubscription = null;
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_reviewsRequestIsCurrent(
          targetPath,
          requestGeneration,
          targetEpoch,
          authEpoch,
        )) {
          return;
        }
        setState(() {
          _reviewsError = error;
          _reviewsLoading = false;
        });
        _reviewsResultSubscription?.cancel();
        _reviewsResultSubscription = null;
      },
      onDone: () {
        if (receivedAuthoritativeResult ||
            !_reviewsRequestIsCurrent(
              targetPath,
              requestGeneration,
              targetEpoch,
              authEpoch,
            )) {
          return;
        }
        setState(() {
          _reviewsError =
              StateError('Could not confirm reviews with the server.');
          _reviewsLoading = false;
        });
        _reviewsResultSubscription = null;
      },
    );
  }

  bool _reviewsRequestIsCurrent(
    String targetPath,
    int requestGeneration,
    int targetEpoch,
    int authEpoch,
  ) {
    return mounted &&
        targetPath == _activeReviewsTargetPath &&
        requestGeneration == _reviewsRequestGeneration &&
        targetEpoch == _targetEpoch &&
        authEpoch == _authEpoch;
  }

  void _retryReviews() {
    final targetReference = widget.nsUserDocRef;
    if (targetReference != null) {
      _ratingCountsFuture =
          _usesDefaultReviewsSource ? _loadRatingCounts(targetReference) : null;
      _startReviewsLoad(targetReference, notify: true);
    }
  }

  void _loadMoreReviews() {
    final targetReference = widget.nsUserDocRef;
    if (targetReference == null ||
        !_reviewsPaginationEnabled ||
        !_reviewsHasMore ||
        _reviewsLoading) {
      return;
    }
    _reviewsLimit += nativeSpeakerReviewsPageSize;
    _startReviewsLoad(targetReference, notify: true);
  }

  Widget _buildLoadMoreReviewsButton() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExpatlioDesign.space16,
        ExpatlioDesign.space16,
        ExpatlioDesign.space16,
        ExpatlioDesign.space0,
      ),
      child: Center(
        child: OutlinedButton(
          key: nativeSpeakerReviewsLoadMoreButtonKey,
          onPressed: _reviewsLoading ? null : _loadMoreReviews,
          child: Text(
            _localizedText(
              ruText: 'Показать ещё',
              enText: 'Show more',
            ),
          ),
        ),
      ),
    );
  }

  String _directAuthUid() {
    final providedUid = widget.authUidProvider?.call().trim();
    if (providedUid != null) {
      return providedUid;
    }
    return FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
  }

  Stream<String> _defaultAuthLifecycleStream() => FirebaseAuth.instance
      .authStateChanges()
      .skip(1)
      .map((user) => user?.uid.trim() ?? '');

  void _subscribeToAuthLifecycle({bool invalidatePending = false}) {
    if (invalidatePending) {
      _authEpoch += 1;
      _reviewsRequestGeneration += 1;
      _latestAuthStreamUid = null;
    }
    final subscriptionGeneration = ++_authSubscriptionGeneration;
    _authLifecycleSubscription?.cancel();
    final stream = widget.authUidStream ?? _defaultAuthLifecycleStream();
    _authLifecycleSubscription = stream.listen((uid) {
      if (!mounted || subscriptionGeneration != _authSubscriptionGeneration) {
        return;
      }

      final normalizedUid = uid.trim();
      _latestAuthStreamUid = normalizedUid;
      _authEpoch += 1;
      UxSessionCacheLifecycle.updateAuthenticatedUser(
        normalizedUid.isEmpty ? null : normalizedUid,
      );
      _reviewsRequestGeneration += 1;

      final targetReference = widget.nsUserDocRef;
      if (targetReference == null || targetReference.path.isEmpty) {
        setState(() {
          _reviewsError = null;
          _reviewsLoading = false;
        });
        return;
      }

      _startReviewsLoad(targetReference, notify: true);
    });
    if (invalidatePending) {
      final targetReference = widget.nsUserDocRef;
      if (targetReference != null && targetReference.path.isNotEmpty) {
        _startReviewsLoad(targetReference, notify: false);
      }
    }
  }

  bool _profileMatchesTarget(
    UserPublicProfilesRecord profile,
    DocumentReference targetReference,
  ) {
    final profileUserId = profile.userId.trim();
    return profile.reference.id == targetReference.id &&
        (profileUserId.isEmpty || profileUserId == targetReference.id);
  }

  bool _actionContextIsCurrent({
    required DocumentReference targetReference,
    required int targetEpoch,
    required int authEpoch,
    required String ownerUid,
  }) {
    return mounted &&
        ownerUid.isNotEmpty &&
        ownerUid == _directAuthUid() &&
        ownerUid == _latestAuthStreamUid &&
        targetReference.path == widget.nsUserDocRef?.path &&
        targetReference.path == _boundTargetPath &&
        targetEpoch == _targetEpoch &&
        authEpoch == _authEpoch;
  }

  UsersRecord? _currentOwnerDocument(String ownerUid) {
    final user = currentUserDocument;
    if (user == null || user.reference.id != ownerUid) {
      return null;
    }
    final storedUid = user.uid.trim();
    return storedUid.isEmpty || storedUid == ownerUid ? user : null;
  }

  Widget _buildProfileUnavailableState() {
    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: Center(
        child: EmptyWidget(
          txt: _localizedText(
            ruText: 'Профиль преподавателя недоступен.',
            enText: 'Tutor profile is unavailable.',
          ),
        ),
      ),
    );
  }

  DocumentReference? _conversationRefForPeer(
    DocumentReference? peerRef,
    String ownerUid,
  ) {
    if (ownerUid.isEmpty || peerRef == null || peerRef.id.isEmpty) {
      return null;
    }

    return conversationReferenceForPairId(
      canonicalConversationPairId(ownerUid, peerRef.id),
    );
  }

  Map<String, dynamic> _stringKeyedMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  void _showDirectCallUnavailableSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _localizedText(
            ruText: 'Преподаватель сейчас недоступен.',
            enText: 'Tutor is unavailable right now.',
          ),
        ),
      ),
    );
  }

  Future<bool> _ensureDirectCallStatus({
    required DocumentReference targetReference,
    required int targetEpoch,
    required int authEpoch,
    required String ownerUid,
  }) async {
    final targetTutorId = targetReference.id;
    var canStartDirectCall = false;
    try {
      final checker = widget.directCallStatusChecker;
      if (checker != null) {
        canStartDirectCall = await checker(targetTutorId);
      } else {
        final activeLanguage = resolveUserActiveConversationLanguage(
          _currentOwnerDocument(ownerUid),
        );
        final payload = <String, dynamic>{
          'targetUserId': targetTutorId,
          if (activeLanguage != null && activeLanguage.isNotEmpty)
            'language': activeLanguage,
        };
        final result = await FirebaseFunctions.instance
            .httpsCallable('getDirectCallStatus')
            .call(payload);
        final statusData = _stringKeyedMap(result.data);
        canStartDirectCall = statusData['canStartDirectCall'] == true;
      }
    } on FirebaseFunctionsException catch (error) {
      safeDebugLog(
        'NativeSpeakerPage: getDirectCallStatus failed: '
        '${error.code} ${error.message ?? ''}',
      );
    } catch (error) {
      safeDebugLog('NativeSpeakerPage: direct call status failed: $error');
    }

    if (!_actionContextIsCurrent(
      targetReference: targetReference,
      targetEpoch: targetEpoch,
      authEpoch: authEpoch,
      ownerUid: ownerUid,
    )) {
      return false;
    }
    if (canStartDirectCall) {
      return true;
    }
    if (mounted) {
      _showDirectCallUnavailableSnackBar();
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NativeSpeakerPageModel());
    NativeSpeakerPageModel.ensureSessionCacheLifecycleRegistered();
    _latestAuthStreamUid = _directAuthUid();
    _scrollController.addListener(_onScroll);
    _bindNativeSpeakerRef(widget.nsUserDocRef);
    _subscribeToAuthLifecycle();
  }

  @override
  void didUpdateWidget(NativeSpeakerPageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bindingChanged =
        oldWidget.nsUserDocRef?.path != widget.nsUserDocRef?.path ||
            oldWidget.publicProfileStreamFactory !=
                widget.publicProfileStreamFactory ||
            oldWidget.statsLoader != widget.statsLoader;
    if (bindingChanged) {
      _bindNativeSpeakerRef(widget.nsUserDocRef);
    } else if ((oldWidget.reviewsLoader != widget.reviewsLoader ||
            oldWidget.reviewsResultLoader != widget.reviewsResultLoader ||
            oldWidget.reviewsResultStreamFactory !=
                widget.reviewsResultStreamFactory) &&
        widget.nsUserDocRef != null) {
      _reviewsLimit = nativeSpeakerReviewsPageSize;
      _reviewsHasMore = false;
      _ratingCountsFuture = _usesDefaultReviewsSource
          ? _loadRatingCounts(widget.nsUserDocRef!)
          : null;
      _startReviewsLoad(widget.nsUserDocRef!, notify: false);
    }
    if (oldWidget.authUidStream != widget.authUidStream) {
      _subscribeToAuthLifecycle(invalidatePending: true);
    }
  }

  double get _snapOffset {
    final statusBarH = MediaQuery.of(context).padding.top;
    final maxExt = MediaQuery.sizeOf(context).height * 0.5;
    final snapHeaderHeight = statusBarH + 8 + 110 + 8 + 42 + 16;
    final minExt = statusBarH + kToolbarHeight;
    return (maxExt - snapHeaderHeight).clamp(0.0, maxExt - minExt);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final snap = _snapOffset;

    if (offset > 1.0 && !_hapticFired && !_isSnapping) {
      _hapticFired = true;
      _isSnapping = true;
      HapticFeedback.mediumImpact();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (!_scrollController.hasClients) {
          _isSnapping = false;
          return;
        }
        _scrollController
            .animateTo(
          snap,
          duration: Duration(milliseconds: 160),
          curve: Curves.easeOut,
        )
            .then((_) {
          if (mounted) {
            _isSnapping = false;
          }
        });
      });
    } else if (_hapticFired && !_isSnapping && offset < snap - 3) {
      _hapticFired = false;
      _isSnapping = true;
      HapticFeedback.mediumImpact();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (!_scrollController.hasClients) {
          _isSnapping = false;
          return;
        }
        _scrollController
            .animateTo(
          0.0,
          duration: Duration(milliseconds: 160),
          curve: Curves.easeOut,
        )
            .then((_) {
          if (mounted) {
            _isSnapping = false;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _authSubscriptionGeneration += 1;
    _authLifecycleSubscription?.cancel();
    _reviewsResultSubscription?.cancel();
    _reviewsRequestGeneration += 1;
    _scrollController.dispose();
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetReference = widget.nsUserDocRef;
    final targetPath = targetReference?.path ?? '';
    return StreamBuilder<UserPublicProfilesRecord?>(
      key: ValueKey<String>('native_speaker_profile_$targetPath'),
      stream: _publicProfileStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Scaffold(
            backgroundColor: ExpatlioDesign.background,
            body: Center(
              child: SizedBox(
                width: 50.0,
                height: 50.0,
                child: SpinKitCircle(
                  color: FlutterFlowTheme.of(context).secondary,
                  size: 50.0,
                ),
              ),
            ),
          );
        }

        final nativeSpeakerPublicProfile = snapshot.data;
        if (snapshot.hasError ||
            targetReference == null ||
            nativeSpeakerPublicProfile == null ||
            !_profileMatchesTarget(
              nativeSpeakerPublicProfile,
              targetReference,
            )) {
          return _buildProfileUnavailableState();
        }

        final actionTargetEpoch = _targetEpoch;
        final actionAuthEpoch = _authEpoch;
        final directOwnerUid = _directAuthUid();
        final ownerUid =
            directOwnerUid == _latestAuthStreamUid ? directOwnerUid : '';
        final ownerDocument = _currentOwnerDocument(ownerUid);
        final hasInstructionLanguage = _hasLanguageData(
          nativeSpeakerPublicProfile.languageInstructionNS,
        );
        final hasNativeLanguage = _hasLanguageData(
          nativeSpeakerPublicProfile.nativeLanguageNS,
        );
        final isVerifiedNativeSpeaker =
            _isVerifiedNativeSpeaker(nativeSpeakerPublicProfile);
        final isBlockedByStudent = (ownerDocument?.blockedUsers.toList() ?? [])
            .contains(widget.nsUserDocRef);
        final canStartDirectCall = ownerUid.isNotEmpty &&
            ownerDocument != null &&
            !widget.hideDirectCallAction &&
            isVerifiedNativeSpeaker &&
            !isBlockedByStudent;
        final conversationRef = _conversationRefForPeer(
          targetReference,
          ownerUid,
        );
        final canOpenChat = ownerUid.isNotEmpty &&
            widget.hideDirectCallAction &&
            userHasFriend(ownerDocument, targetReference) &&
            (conversationRef?.path.isNotEmpty ?? false);

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: ExpatlioDesign.background,
            body: Stack(
              children: [
                CustomScrollView(
                  key: nativeSpeakerPageScrollKey,
                  controller: _scrollController,
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ProfileHeaderDelegate(
                        maxHeaderExtent:
                            MediaQuery.sizeOf(context).height * 0.5,
                        minHeaderExtent:
                            MediaQuery.of(context).padding.top + kToolbarHeight,
                        photoUrl: nativeSpeakerPublicProfile.photoUrl,
                        displayName:
                            _profileDisplayName(nativeSpeakerPublicProfile),
                        cityAndStatus: _profileCountryAndStatus(
                            nativeSpeakerPublicProfile),
                        ratingAverage: nativeSpeakerPublicProfile.ratingAverage,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space16,
                                ExpatlioDesign.space24,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'd7d95pj7' /* О себе */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space16,
                                ExpatlioDesign.space12,
                                ExpatlioDesign.space16,
                                ExpatlioDesign.space0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Flexible(
                                  child: FutureBuilder<List<StatsRecord>>(
                                    key: ValueKey<String>(
                                      'native_speaker_stats_$targetPath',
                                    ),
                                    future: _statsFuture,
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return Center(
                                          child: SizedBox(
                                            width: 50.0,
                                            height: 50.0,
                                            child: SpinKitCircle(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondary,
                                              size: 50.0,
                                            ),
                                          ),
                                        );
                                      }
                                      final containerStatsRecordList =
                                          snapshot.data!
                                              .where(
                                                (stats) =>
                                                    stats.reference.parent
                                                        .parent?.path ==
                                                    targetPath,
                                              )
                                              .toList(growable: false);
                                      if (containerStatsRecordList.isEmpty) {
                                        return Container();
                                      }
                                      final containerStatsRecord =
                                          containerStatsRecordList.isNotEmpty
                                              ? containerStatsRecordList.first
                                              : null;
                                      return Container(
                                        key: nativeSpeakerStatsValueKey,
                                        decoration: BoxDecoration(),
                                        child: Text(
                                          functions.getcallNumbString(
                                              containerStatsRecord!.totalCalls
                                                  .toString()),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(
                                  height: 10.0,
                                  child: VerticalDivider(
                                    thickness: 2.0,
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    functions.getReviewString(
                                        nativeSpeakerPublicProfile.ratingCount
                                            .toString()),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          fontSize: 15.0,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space16,
                                ExpatlioDesign.space12,
                                ExpatlioDesign.space16,
                                ExpatlioDesign.space0),
                            child: Text(
                              nativeSpeakerPublicProfile.aboutMe,
                              maxLines: _model.numMaxLineAbout,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    fontSize: 15.0,
                                    letterSpacing: 0.0,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (functions.aboutt(
                                  nativeSpeakerPublicProfile.aboutMe,
                                  MediaQuery.sizeOf(context).width) ==
                              true)
                            FFButtonWidget(
                              onPressed: () async {
                                if (_model.numMaxLineAbout == 4) {
                                  _model.numMaxLineAbout = 15;
                                  safeSetState(() {});
                                } else {
                                  _model.numMaxLineAbout = 4;
                                  safeSetState(() {});
                                }
                              },
                              text: _model.numMaxLineAbout == 4
                                  ? FFLocalizations.of(context).getVariableText(
                                      ruText: 'Показать еще',
                                      enText: 'Show more',
                                    )
                                  : FFLocalizations.of(context).getVariableText(
                                      ruText: 'Скрыть',
                                      enText: 'Hide',
                                    ),
                              options: FFButtonOptions(
                                height: ExpatlioDesign.buttonHeight,
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    ExpatlioDesign.space16,
                                    ExpatlioDesign.space0,
                                    ExpatlioDesign.space16,
                                    ExpatlioDesign.space0),
                                iconPadding: EdgeInsetsDirectional.fromSTEB(
                                    ExpatlioDesign.space0,
                                    ExpatlioDesign.space0,
                                    ExpatlioDesign.space0,
                                    ExpatlioDesign.space0),
                                color: Colors.transparent,
                                textStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'sf pro display',
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      fontSize: 15.0,
                                      letterSpacing: 0.0,
                                    ),
                                elevation: 0.0,
                                borderRadius: BorderRadius.circular(
                                    ExpatlioDesign.radiusSmall),
                              ),
                            ),
                          if (hasInstructionLanguage)
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  ExpatlioDesign.space16,
                                  ExpatlioDesign.space24,
                                  ExpatlioDesign.space0,
                                  ExpatlioDesign.space0),
                              child: Text(
                                FFLocalizations.of(context).getVariableText(
                                  ruText: 'Я преподаю',
                                  enText: 'I teach',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'Cool',
                                      fontSize: 22.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.normal,
                                    ),
                              ),
                            ),
                          if (hasInstructionLanguage)
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  ExpatlioDesign.space8,
                                  ExpatlioDesign.space12,
                                  ExpatlioDesign.space8,
                                  ExpatlioDesign.space0),
                              child: wrapWithModel(
                                model: _model.languageCardModel1,
                                updateCallback: () => safeSetState(() {}),
                                child: LanguageCardWidget(
                                  lang: nativeSpeakerPublicProfile
                                      .languageInstructionNS,
                                  callbackAction: (selectedLangData) async {},
                                ),
                              ),
                            ),
                          if (hasNativeLanguage)
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  ExpatlioDesign.space16,
                                  ExpatlioDesign.space24,
                                  ExpatlioDesign.space0,
                                  ExpatlioDesign.space0),
                              child: Text(
                                FFLocalizations.of(context).getVariableText(
                                  ruText: 'Мой родной язык',
                                  enText: 'My native language',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'Cool',
                                      fontSize: 22.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.normal,
                                    ),
                              ),
                            ),
                          if (hasNativeLanguage)
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  ExpatlioDesign.space8,
                                  ExpatlioDesign.space12,
                                  ExpatlioDesign.space8,
                                  ExpatlioDesign.space0),
                              child: wrapWithModel(
                                model: _model.languageCardModel2,
                                updateCallback: () => safeSetState(() {}),
                                child: LanguageCardWidget(
                                  lang: nativeSpeakerPublicProfile
                                      .nativeLanguageNS,
                                  callbackAction: (selectedLangData) async {},
                                ),
                              ),
                            ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space16,
                                ExpatlioDesign.space24,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getVariableText(
                                ruText: 'Отзывы',
                                enText: 'Reviews',
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space12,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: _buildReviewsSection(
                                nativeSpeakerPublicProfile),
                          ),
                          SizedBox(
                            height: canStartDirectCall && canOpenChat
                                ? 220.0
                                : (canStartDirectCall || canOpenChat)
                                    ? 140.0
                                    : 32.0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (canStartDirectCall || canOpenChat)
                  Align(
                    alignment: AlignmentDirectional(0.0, 1.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canOpenChat)
                          StreamBuilder<List<ConversationsRecord>>(
                            key: ValueKey<String>(
                              'native_speaker_conversation_${targetReference.path}_$ownerUid',
                            ),
                            stream: queryConversationsRecord(
                              queryBuilder: (query) => query.where(
                                FieldPath(['participantMap', ownerUid]),
                                isEqualTo: true,
                              ),
                            ),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox.shrink();
                              }

                              ConversationsRecord? conversation;
                              for (final candidate in snapshot.data!) {
                                if (candidate.pairId == conversationRef!.id) {
                                  conversation = candidate;
                                  break;
                                }
                              }

                              if (conversation == null ||
                                  !conversation.isUnlocked) {
                                return const SizedBox.shrink();
                              }

                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      ExpatlioDesign.background
                                          .withValues(alpha: 0.0),
                                      ExpatlioDesign.background
                                          .withValues(alpha: 0.84),
                                      ExpatlioDesign.background
                                    ],
                                    stops: [0.0, 0.2, 1.0],
                                    begin: AlignmentDirectional(0.0, -1.0),
                                    end: AlignmentDirectional(0, 1.0),
                                  ),
                                ),
                                child: Wrapper(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                    ExpatlioDesign.pagePadding,
                                    ExpatlioDesign.space12,
                                    ExpatlioDesign.pagePadding,
                                    ExpatlioDesign.space12,
                                  ),
                                  child: ButtonWidget(
                                    text: FFLocalizations.of(context)
                                        .getVariableText(
                                      ruText: 'Открыть чат',
                                      enText: 'Open chat',
                                    ),
                                    loadingText: FFLocalizations.of(context)
                                        .getVariableText(
                                      ruText: 'Открываем...',
                                      enText: 'Opening...',
                                    ),
                                    busyStyle: ButtonBusyStyle.spinner,
                                    action: () async {
                                      if (!_actionContextIsCurrent(
                                        targetReference: targetReference,
                                        targetEpoch: actionTargetEpoch,
                                        authEpoch: actionAuthEpoch,
                                        ownerUid: ownerUid,
                                      )) {
                                        return;
                                      }
                                      await openChatThread(
                                        context,
                                        conversationRef: conversationRef,
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        if (canStartDirectCall)
                          _buildBottomCallToAction(
                            targetReference: targetReference,
                            targetEpoch: actionTargetEpoch,
                            authEpoch: actionAuthEpoch,
                            ownerUid: ownerUid,
                          ),
                      ],
                    ),
                  ),
                AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, _) {
                    return _buildTopActionButtons(
                      _profileDisplayName(nativeSpeakerPublicProfile),
                      targetReference: targetReference,
                      targetEpoch: actionTargetEpoch,
                      authEpoch: actionAuthEpoch,
                      ownerUid: ownerUid,
                    );
                  },
                ),
                if (_lastSuccessfulReviews != null && _reviewsError != null)
                  PositionedDirectional(
                    start: ExpatlioDesign.space16,
                    end: ExpatlioDesign.space16,
                    top: MediaQuery.viewPaddingOf(context).top +
                        BasicPageHeader.height +
                        ExpatlioDesign.space8,
                    child: Material(
                      color: Colors.transparent,
                      elevation: 4.0,
                      child: _buildReviewsErrorState(
                        nativeSpeakerReviewsRefreshErrorKey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _hasLanguageData(LanguageStruct language) {
    return language.code.isNotEmpty ||
        language.nameEn.isNotEmpty ||
        language.nameRu.isNotEmpty;
  }

  Widget _buildTopActionButtons(
    String title, {
    required DocumentReference targetReference,
    required int targetEpoch,
    required int authEpoch,
    required String ownerUid,
  }) {
    return BasicPageHeader(
      title: title,
      trailing: AuthUserStreamWidget(
        builder: (context) {
          final ownerDocument = _currentOwnerDocument(ownerUid);
          if (ownerDocument == null) {
            return const SizedBox.shrink();
          }
          final isFriend = userHasFriend(
            ownerDocument,
            targetReference,
          );
          return IconButton(
            key: nativeSpeakerFavoriteActionKey,
            onPressed: () async {
              if (!_actionContextIsCurrent(
                targetReference: targetReference,
                targetEpoch: targetEpoch,
                authEpoch: authEpoch,
                ownerUid: ownerUid,
              )) {
                return;
              }

              final latestOwnerDocument = _currentOwnerDocument(ownerUid);
              if (latestOwnerDocument == null) {
                return;
              }
              final latestIsFriend = userHasFriend(
                latestOwnerDocument,
                targetReference,
              );
              final userRef = UsersRecord.collection.doc(ownerUid);
              await userRef.update({
                if (latestIsFriend)
                  ...buildRemoveFriendUpdateData(targetReference)
                else
                  ...buildAddFriendUpdateData(targetReference),
              });
              if (!_actionContextIsCurrent(
                targetReference: targetReference,
                targetEpoch: targetEpoch,
                authEpoch: authEpoch,
                ownerUid: ownerUid,
              )) {
                return;
              }
              safeSetState(() {});
            },
            icon: Icon(
              isFriend ? Icons.favorite_rounded : FFIcons.kheart,
              color: isFriend
                  ? FlutterFlowTheme.of(context).error
                  : ExpatlioDesign.text,
              size: 22.0,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomCallToAction({
    required DocumentReference targetReference,
    required int targetEpoch,
    required int authEpoch,
    required String ownerUid,
  }) {
    return AuthUserStreamWidget(
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0x00F2F2F7),
              Color(0xACF2F2F7),
              FlutterFlowTheme.of(context).secondaryBackground
            ],
            stops: [0.0, 0.2, 1.0],
            begin: AlignmentDirectional(0.0, -1.0),
            end: AlignmentDirectional(0, 1.0),
          ),
        ),
        child: Wrapper(
          padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.pagePadding,
              ExpatlioDesign.space12,
              ExpatlioDesign.pagePadding,
              ExpatlioDesign.space32),
          child: ButtonWidget(
            key: nativeSpeakerDirectCallActionKey,
            text: FFLocalizations.of(context).getText(
              '2sabsnp2' /* Начать разговор */,
            ),
            loadingText: FFLocalizations.of(context).getVariableText(
              ruText: 'Подключаем...',
              enText: 'Connecting...',
            ),
            busyStyle: ButtonBusyStyle.spinner,
            action: () async {
              if (!_actionContextIsCurrent(
                targetReference: targetReference,
                targetEpoch: targetEpoch,
                authEpoch: authEpoch,
                ownerUid: ownerUid,
              )) {
                return;
              }
              final targetTutorId = targetReference.id;
              if (targetTutorId.isEmpty) {
                safeDebugLog(
                    'NativeSpeakerPage: missing target tutor id for direct call');
                return;
              }

              // ─── SUBSCRIPTION REWORK ─ gate by subscription or gift minutes
              // instead of legacy balanceST > 0.
              if (!canStartCall(_currentOwnerDocument(ownerUid))) {
                // ───────────────────────────────────────────────────────
                await showModalBottomSheet(
                  useRootNavigator: true,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  context: context,
                  builder: (context) {
                    return GestureDetector(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      child: Padding(
                        padding: MediaQuery.viewInsetsOf(context),
                        child: NoBalanceWidget(),
                      ),
                    );
                  },
                );
                if (!_actionContextIsCurrent(
                  targetReference: targetReference,
                  targetEpoch: targetEpoch,
                  authEpoch: authEpoch,
                  ownerUid: ownerUid,
                )) {
                  return;
                }
                safeSetState(() {});
                return;
              }

              if (!await _ensureDirectCallStatus(
                targetReference: targetReference,
                targetEpoch: targetEpoch,
                authEpoch: authEpoch,
                ownerUid: ownerUid,
              )) {
                return;
              }
              if (!_actionContextIsCurrent(
                targetReference: targetReference,
                targetEpoch: targetEpoch,
                authEpoch: authEpoch,
                ownerUid: ownerUid,
              )) {
                return;
              }

              final permissionRequester = widget.mediaPermissionRequester ??
                  ensureCameraAndMicrophonePermissions;
              final hasMediaPermissions = await permissionRequester();
              if (!hasMediaPermissions ||
                  !_actionContextIsCurrent(
                    targetReference: targetReference,
                    targetEpoch: targetEpoch,
                    authEpoch: authEpoch,
                    ownerUid: ownerUid,
                  )) {
                return;
              }

              final navigator = widget.directCallNavigator;
              if (navigator != null) {
                await navigator(context, targetTutorId);
              } else {
                final activeLanguage = resolveUserActiveConversationLanguage(
                  _currentOwnerDocument(ownerUid),
                );
                if (activeLanguage == null || activeLanguage.trim().isEmpty) {
                  return;
                }
                try {
                  await FirebaseFunctions.instance
                      .httpsCallable('createVideoSession')
                      .call(<String, dynamic>{
                    'language': activeLanguage.trim(),
                    'directTutorId': targetTutorId,
                  });
                } on FirebaseFunctionsException catch (error) {
                  safeDebugLog(
                    'NativeSpeakerPage: direct call failed: '
                    '${error.code} ${error.message}',
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection(UserPublicProfilesRecord nativeSpeakerProfile) {
    final reviews = _lastSuccessfulReviews;
    if (reviews == null) {
      if (_reviewsError != null) {
        return Padding(
          padding: const EdgeInsets.all(ExpatlioDesign.space16),
          child: _buildReviewsErrorState(
            nativeSpeakerReviewsErrorKey,
          ),
        );
      }

      return Center(
        child: Semantics(
          key: nativeSpeakerReviewsLoadingKey,
          container: true,
          liveRegion: true,
          label: FFLocalizations.of(context).getVariableText(
            ruText: 'Загрузка отзывов преподавателя',
            enText: 'Loading tutor reviews',
          ),
          child: const ExcludeSemantics(
            child: AppLoadingIndicator(),
          ),
        ),
      );
    }

    final ratingCountsFuture = _ratingCountsFuture;
    Widget content = ratingCountsFuture == null
        ? _buildReviewsContent(nativeSpeakerProfile, reviews)
        : FutureBuilder<Map<int, int>>(
            future: ratingCountsFuture,
            builder: (context, snapshot) => _buildReviewsContent(
              nativeSpeakerProfile,
              reviews,
              authoritativeRatingCounts: snapshot.data,
            ),
          );
    content = UxRefreshingIndicatorOverlay(
      key: nativeSpeakerReviewsRefreshingKey,
      isRefreshing: _reviewsLoading,
      semanticsLabel: FFLocalizations.of(context).getVariableText(
        ruText: 'Обновление отзывов преподавателя',
        enText: 'Refreshing tutor reviews',
      ),
      child: content,
    );
    return content;
  }

  Widget _buildReviewsErrorState(Key stateKey) {
    final title = FFLocalizations.of(context).getVariableText(
      ruText: 'Не удалось загрузить отзывы',
      enText: 'Could not load reviews',
    );
    final message = FFLocalizations.of(context).getVariableText(
      ruText: 'Проверьте подключение и попробуйте еще раз.',
      enText: 'Check your connection and try again.',
    );
    return UxErrorState(
      stateKey: stateKey,
      title: title,
      message: message,
      retryLabel: FFLocalizations.of(context).getVariableText(
        ruText: 'Повторить',
        enText: 'Retry',
      ),
      retrySemanticsLabel: FFLocalizations.of(context).getVariableText(
        ruText: 'Повторить загрузку отзывов преподавателя',
        enText: 'Retry loading tutor reviews',
      ),
      retryButtonKey: nativeSpeakerReviewsRetryButtonKey,
      onRetry: _retryReviews,
      showIcon: false,
      contained: true,
      maxWidth: double.infinity,
      padding: const EdgeInsets.all(ExpatlioDesign.space12),
      titleSize: 15.0,
      messageSize: 13.0,
      retryMinHeight: 40.0,
    );
  }

  Widget _buildReviewsContent(
    UserPublicProfilesRecord nativeSpeakerProfile,
    List<ReviewsRecord> containerReviewsRecordList, {
    Map<int, int>? authoritativeRatingCounts,
  }) {
    final loadedRatingCounts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final review in containerReviewsRecordList) {
      if (loadedRatingCounts.containsKey(review.rating)) {
        loadedRatingCounts[review.rating] =
            loadedRatingCounts[review.rating]! + 1;
      }
    }
    final loadedReviewsAreComplete =
        !_reviewsPaginationEnabled || (!_reviewsLoading && !_reviewsHasMore);
    final ratingCounts = authoritativeRatingCounts ??
        (loadedReviewsAreComplete ? loadedRatingCounts : null);
    final ratingDistributionTotal =
        ratingCounts?.values.fold<int>(0, (sum, count) => sum + count) ?? 0;

    int countForRating(int ratingValue) => ratingCounts?[ratingValue] ?? 0;

    double percentForRating(int ratingValue) {
      if (ratingDistributionTotal <= 0) {
        return 0.0;
      }
      final percent = countForRating(ratingValue) / ratingDistributionTotal;
      return percent.clamp(0.0, 1.0).toDouble();
    }

    return Container(
      key: nativeSpeakerReviewsSectionKey,
      decoration: BoxDecoration(),
      child: Builder(
        builder: (context) {
          if (containerReviewsRecordList.isNotEmpty) {
            return Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(ExpatlioDesign.space16),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatNumber(
                              nativeSpeakerProfile.ratingAverage,
                              formatType: FormatType.custom,
                              format: '0.0',
                              locale: '',
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Cool',
                                  fontSize: 34.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space8,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: RatingBar.builder(
                              onRatingUpdate: (newValue) => safeSetState(
                                  () => _model.ratingBarValue = newValue),
                              itemBuilder: (context, index) => Icon(
                                Icons.star_rounded,
                                color: FlutterFlowTheme.of(context).warning,
                              ),
                              direction: Axis.horizontal,
                              initialRating: _model.ratingBarValue ??=
                                  nativeSpeakerProfile.ratingAverage,
                              unratedColor: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              itemCount: 5,
                              itemSize: 18.0,
                              glowColor: FlutterFlowTheme.of(context).warning,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space4,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              functions.getReviewString(valueOrDefault<String>(
                                nativeSpeakerProfile.ratingCount.toString(),
                                '0',
                              )),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    fontSize: 15.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (ratingCounts != null)
                        Expanded(
                          key: nativeSpeakerRatingDistributionKey,
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space12,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 11.0,
                                      decoration: BoxDecoration(),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          'clkcguct' /* 5 */,
                                        ),
                                        textAlign: TextAlign.center,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                    Icon(
                                      FFIcons.kstar012,
                                      color: Color(0xFFFFCC31),
                                      size: 13.0,
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          ExpatlioDesign.space4,
                                          ExpatlioDesign.space0,
                                          ExpatlioDesign.space4,
                                          ExpatlioDesign.space0),
                                      child: AuthUserStreamWidget(
                                        builder: (context) =>
                                            LinearPercentIndicator(
                                          percent: percentForRating(5),
                                          width: 106.0,
                                          lineHeight: 4.0,
                                          animation: true,
                                          animateFromLastPercent: true,
                                          progressColor:
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                          backgroundColor:
                                              FlutterFlowTheme.of(context)
                                                  .accent4,
                                          barRadius: Radius.circular(
                                              ExpatlioDesign.radiusSmall),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 33.0,
                                      decoration: BoxDecoration(),
                                      child: AutoSizeText(
                                        countForRating(5).toString(),
                                        maxLines: 1,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                  ].divide(
                                      SizedBox(width: ExpatlioDesign.space4)),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 11.0,
                                      decoration: BoxDecoration(),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          '10vod9dp' /* 4 */,
                                        ),
                                        textAlign: TextAlign.center,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                    Icon(
                                      FFIcons.kstar012,
                                      color: Color(0xFFFFCC31),
                                      size: 13.0,
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          ExpatlioDesign.space4,
                                          ExpatlioDesign.space0,
                                          ExpatlioDesign.space4,
                                          ExpatlioDesign.space0),
                                      child: AuthUserStreamWidget(
                                        builder: (context) =>
                                            LinearPercentIndicator(
                                          percent: percentForRating(4),
                                          width: 106.0,
                                          lineHeight: 4.0,
                                          animation: true,
                                          animateFromLastPercent: true,
                                          progressColor:
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                          backgroundColor:
                                              FlutterFlowTheme.of(context)
                                                  .accent4,
                                          barRadius: Radius.circular(
                                              ExpatlioDesign.radiusSmall),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 33.0,
                                      decoration: BoxDecoration(),
                                      child: AutoSizeText(
                                        countForRating(4).toString(),
                                        maxLines: 1,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                  ].divide(
                                      SizedBox(width: ExpatlioDesign.space4)),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 11.0,
                                      decoration: BoxDecoration(),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          's89a9grf' /* 3 */,
                                        ),
                                        textAlign: TextAlign.center,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                    Icon(
                                      FFIcons.kstar012,
                                      color: Color(0xFFFFCC31),
                                      size: 13.0,
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          ExpatlioDesign.space4,
                                          ExpatlioDesign.space0,
                                          ExpatlioDesign.space4,
                                          ExpatlioDesign.space0),
                                      child: AuthUserStreamWidget(
                                        builder: (context) =>
                                            LinearPercentIndicator(
                                          percent: percentForRating(3),
                                          width: 106.0,
                                          lineHeight: 4.0,
                                          animation: true,
                                          animateFromLastPercent: true,
                                          progressColor:
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                          backgroundColor:
                                              FlutterFlowTheme.of(context)
                                                  .accent4,
                                          barRadius: Radius.circular(
                                              ExpatlioDesign.radiusSmall),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 33.0,
                                      decoration: BoxDecoration(),
                                      child: AutoSizeText(
                                        countForRating(3).toString(),
                                        maxLines: 1,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                  ].divide(
                                      SizedBox(width: ExpatlioDesign.space4)),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 11.0,
                                      decoration: BoxDecoration(),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          'n8svbjr0' /* 2 */,
                                        ),
                                        textAlign: TextAlign.center,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                    Icon(
                                      FFIcons.kstar012,
                                      color: Color(0xFFFFCC31),
                                      size: 13.0,
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          ExpatlioDesign.space4,
                                          ExpatlioDesign.space0,
                                          ExpatlioDesign.space4,
                                          ExpatlioDesign.space0),
                                      child: AuthUserStreamWidget(
                                        builder: (context) =>
                                            LinearPercentIndicator(
                                          percent: percentForRating(2),
                                          width: 106.0,
                                          lineHeight: 4.0,
                                          animation: true,
                                          animateFromLastPercent: true,
                                          progressColor:
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                          backgroundColor:
                                              FlutterFlowTheme.of(context)
                                                  .accent4,
                                          barRadius: Radius.circular(
                                              ExpatlioDesign.radiusSmall),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 33.0,
                                      decoration: BoxDecoration(),
                                      child: AutoSizeText(
                                        countForRating(2).toString(),
                                        maxLines: 1,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                  ].divide(
                                      SizedBox(width: ExpatlioDesign.space4)),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 11.0,
                                      decoration: BoxDecoration(),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          'g8kj6pac' /* 1 */,
                                        ),
                                        textAlign: TextAlign.center,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                    Icon(
                                      FFIcons.kstar012,
                                      color: Color(0xFFFFCC31),
                                      size: 13.0,
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          ExpatlioDesign.space4,
                                          ExpatlioDesign.space0,
                                          ExpatlioDesign.space4,
                                          ExpatlioDesign.space0),
                                      child: AuthUserStreamWidget(
                                        builder: (context) =>
                                            LinearPercentIndicator(
                                          percent: percentForRating(1),
                                          width: 106.0,
                                          lineHeight: 4.0,
                                          animation: true,
                                          animateFromLastPercent: true,
                                          progressColor:
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                          backgroundColor:
                                              FlutterFlowTheme.of(context)
                                                  .accent4,
                                          barRadius: Radius.circular(
                                              ExpatlioDesign.radiusSmall),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 33.0,
                                      decoration: BoxDecoration(),
                                      child: AutoSizeText(
                                        countForRating(1).toString(),
                                        maxLines: 1,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                  ].divide(
                                      SizedBox(width: ExpatlioDesign.space4)),
                                ),
                              ].divide(SizedBox(height: ExpatlioDesign.space4)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space12,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0),
                  child: Container(
                    width: double.infinity,
                    height: 45.0,
                    decoration: BoxDecoration(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          InkWell(
                            key: nativeSpeakerRatingFilterKey(0),
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              _model.rate = 0;
                              safeSetState(() {});
                            },
                            child: Container(
                              width: 75.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: valueOrDefault<Color>(
                                  _model.rate == 0
                                      ? FlutterFlowTheme.of(context).primary
                                      : FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                  FlutterFlowTheme.of(context).primary,
                                ),
                                borderRadius: BorderRadius.circular(
                                    ExpatlioDesign.radiusLarge),
                              ),
                              child: Align(
                                alignment: AlignmentDirectional(0.0, 0.0),
                                child: Text(
                                  FFLocalizations.of(context).getText(
                                    'ovjwud7w' /* Все */,
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'sf pro display',
                                        color: valueOrDefault<Color>(
                                          _model.rate == 0
                                              ? FlutterFlowTheme.of(context)
                                                  .primaryBackground
                                              : FlutterFlowTheme.of(context)
                                                  .primaryText,
                                          FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                        ),
                                        fontSize: 15.0,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            key: nativeSpeakerRatingFilterKey(5),
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              _model.rate = 5;
                              safeSetState(() {});
                            },
                            child: Container(
                              width: 75.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: valueOrDefault<Color>(
                                  _model.rate == 5
                                      ? FlutterFlowTheme.of(context).primary
                                      : FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                  FlutterFlowTheme.of(context).primary,
                                ),
                                borderRadius: BorderRadius.circular(
                                    ExpatlioDesign.radiusLarge),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    FFLocalizations.of(context).getText(
                                      'h6yocea2' /* 5 */,
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: valueOrDefault<Color>(
                                            _model.rate == 5
                                                ? FlutterFlowTheme.of(context)
                                                    .primaryBackground
                                                : FlutterFlowTheme.of(context)
                                                    .primaryText,
                                            FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                          ),
                                          fontSize: 15.0,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                  Icon(
                                    FFIcons.kstar012,
                                    color: Color(0xFFFFCC31),
                                    size: 13.0,
                                  ),
                                ].divide(
                                    SizedBox(width: ExpatlioDesign.space4)),
                              ),
                            ),
                          ),
                          InkWell(
                            key: nativeSpeakerRatingFilterKey(4),
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              _model.rate = 4;
                              safeSetState(() {});
                            },
                            child: Container(
                              width: 75.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: valueOrDefault<Color>(
                                  _model.rate == 4
                                      ? FlutterFlowTheme.of(context).primary
                                      : FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                  FlutterFlowTheme.of(context).primary,
                                ),
                                borderRadius: BorderRadius.circular(
                                    ExpatlioDesign.radiusLarge),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    FFLocalizations.of(context).getText(
                                      'm2hjxtoq' /* 4 */,
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: valueOrDefault<Color>(
                                            _model.rate == 4
                                                ? FlutterFlowTheme.of(context)
                                                    .primaryBackground
                                                : FlutterFlowTheme.of(context)
                                                    .primaryText,
                                            FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                          ),
                                          fontSize: 15.0,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                  Icon(
                                    FFIcons.kstar012,
                                    color: Color(0xFFFFCC31),
                                    size: 13.0,
                                  ),
                                ].divide(
                                    SizedBox(width: ExpatlioDesign.space4)),
                              ),
                            ),
                          ),
                          InkWell(
                            key: nativeSpeakerRatingFilterKey(3),
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              _model.rate = 3;
                              safeSetState(() {});
                            },
                            child: Container(
                              width: 75.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: valueOrDefault<Color>(
                                  _model.rate == 3
                                      ? FlutterFlowTheme.of(context).primary
                                      : FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                  FlutterFlowTheme.of(context).primary,
                                ),
                                borderRadius: BorderRadius.circular(
                                    ExpatlioDesign.radiusLarge),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    FFLocalizations.of(context).getText(
                                      '19bs787g' /* 3 */,
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: valueOrDefault<Color>(
                                            _model.rate == 3
                                                ? FlutterFlowTheme.of(context)
                                                    .primaryBackground
                                                : FlutterFlowTheme.of(context)
                                                    .primaryText,
                                            FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                          ),
                                          fontSize: 15.0,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                  Icon(
                                    FFIcons.kstar012,
                                    color: Color(0xFFFFCC31),
                                    size: 13.0,
                                  ),
                                ].divide(
                                    SizedBox(width: ExpatlioDesign.space4)),
                              ),
                            ),
                          ),
                          InkWell(
                            key: nativeSpeakerRatingFilterKey(2),
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              _model.rate = 2;
                              safeSetState(() {});
                            },
                            child: Container(
                              width: 75.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: valueOrDefault<Color>(
                                  _model.rate == 2
                                      ? FlutterFlowTheme.of(context).primary
                                      : FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                  FlutterFlowTheme.of(context).primary,
                                ),
                                borderRadius: BorderRadius.circular(
                                    ExpatlioDesign.radiusLarge),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    FFLocalizations.of(context).getText(
                                      'is2w8qlp' /* 2 */,
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: valueOrDefault<Color>(
                                            _model.rate == 2
                                                ? FlutterFlowTheme.of(context)
                                                    .primaryBackground
                                                : FlutterFlowTheme.of(context)
                                                    .primaryText,
                                            FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                          ),
                                          fontSize: 15.0,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                  Icon(
                                    FFIcons.kstar012,
                                    color: Color(0xFFFFCC31),
                                    size: 13.0,
                                  ),
                                ].divide(
                                    SizedBox(width: ExpatlioDesign.space4)),
                              ),
                            ),
                          ),
                          InkWell(
                            key: nativeSpeakerRatingFilterKey(1),
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              _model.rate = 1;
                              safeSetState(() {});
                            },
                            child: Container(
                              width: 75.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: valueOrDefault<Color>(
                                  _model.rate == 1
                                      ? FlutterFlowTheme.of(context).primary
                                      : FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                  FlutterFlowTheme.of(context).primary,
                                ),
                                borderRadius: BorderRadius.circular(
                                    ExpatlioDesign.radiusLarge),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    FFLocalizations.of(context).getText(
                                      'bk4ndath' /* 1 */,
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: valueOrDefault<Color>(
                                            _model.rate == 1
                                                ? FlutterFlowTheme.of(context)
                                                    .primaryBackground
                                                : FlutterFlowTheme.of(context)
                                                    .primaryText,
                                            FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                          ),
                                          fontSize: 15.0,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                  Icon(
                                    FFIcons.kstar012,
                                    color: Color(0xFFFFCC31),
                                    size: 13.0,
                                  ),
                                ].divide(
                                    SizedBox(width: ExpatlioDesign.space4)),
                              ),
                            ),
                          ),
                        ]
                            .divide(SizedBox(width: ExpatlioDesign.space8))
                            .addToStart(SizedBox(width: ExpatlioDesign.space16))
                            .addToEnd(SizedBox(width: ExpatlioDesign.space16)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space12,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0),
                  child: Builder(
                    builder: (context) {
                      final rew = containerReviewsRecordList
                          .where((e) => _model.rate == 0
                              ? true
                              : (e.rating == _model.rate))
                          .toList();

                      if (rew.isEmpty) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
                              child: EmptyWidget(
                                txt:
                                    'По выбранному рейтингу пока ничего нет. Попробуйте другую оценку.',
                              ),
                            ),
                            if (_reviewsPaginationEnabled && _reviewsHasMore)
                              _buildLoadMoreReviewsButton(),
                          ],
                        );
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListView.separated(
                            key: nativeSpeakerReviewsListKey,
                            padding: EdgeInsets.zero,
                            primary: false,
                            shrinkWrap: true,
                            scrollDirection: Axis.vertical,
                            itemCount: rew.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: ExpatlioDesign.space8),
                            itemBuilder: (context, rewIndex) {
                              final rewItem = rew[rewIndex];
                              return Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    ExpatlioDesign.space16,
                                    ExpatlioDesign.space0,
                                    ExpatlioDesign.space16,
                                    ExpatlioDesign.space0),
                                child: ReviewCardWidget(
                                  key: nativeSpeakerReviewKey(rewItem),
                                  rewDoc: rewItem,
                                ),
                              );
                            },
                          ),
                          if (_reviewsPaginationEnabled && _reviewsHasMore)
                            _buildLoadMoreReviewsButton(),
                        ],
                      );
                    },
                  ),
                ),
              ].addToEnd(SizedBox(height: ExpatlioDesign.space24)),
            );
          } else {
            return EmptyWidget(
              key: nativeSpeakerReviewsEmptyKey,
              txt:
                  'У этого преподавателя пока нет оценок и отзывов. После первых занятий студенты смогут поделиться впечатлениями, и отзывы появятся здесь.',
            );
          }
        },
      ),
    );
  }
}

class _ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  _ProfileHeaderDelegate({
    required this.maxHeaderExtent,
    required this.minHeaderExtent,
    required this.photoUrl,
    required this.displayName,
    required this.cityAndStatus,
    required this.ratingAverage,
  });

  final double maxHeaderExtent;
  final double minHeaderExtent;
  final String photoUrl;
  final String displayName;
  final String cityAndStatus;
  final double ratingAverage;

  @override
  double get maxExtent => maxHeaderExtent;

  @override
  double get minExtent => minHeaderExtent;

  @override
  bool shouldRebuild(covariant _ProfileHeaderDelegate oldDelegate) {
    return photoUrl != oldDelegate.photoUrl ||
        displayName != oldDelegate.displayName ||
        cityAndStatus != oldDelegate.cityAndStatus ||
        ratingAverage != oldDelegate.ratingAverage;
  }

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = FlutterFlowTheme.of(context);
    final totalShrink = maxExtent - minExtent;
    final progress = (shrinkOffset / totalShrink).clamp(0.0, 1.0);
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final currentExtent =
        (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);

    final snapHeaderHeight = statusBarHeight + 8 + 110 + 8 + 42 + 16;
    final phase1End =
        ((maxExtent - snapHeaderHeight) / totalShrink).clamp(0.05, 0.9);
    const phase2End = 0.88;

    final p1 = (progress / phase1End).clamp(0.0, 1.0);
    final p2 =
        ((progress - phase1End) / (phase2End - phase1End)).clamp(0.0, 1.0);
    final p3 = ((progress - phase2End) / (1.0 - phase2End)).clamp(0.0, 1.0);

    const circleMaxSize = 110.0;
    const circleMinSize = 32.0;
    final circleTop = statusBarHeight + 8.0;

    final double circleSize;
    if (progress <= phase1End) {
      circleSize = circleMaxSize;
    } else if (progress <= phase2End) {
      circleSize = ui.lerpDouble(circleMaxSize, circleMinSize, p2)!;
    } else {
      circleSize = ui.lerpDouble(circleMinSize, 0.0, p3)!;
    }

    // --- Single morphing photo ---
    double photoW, photoH, photoL, photoT;
    BorderRadius photoBR;
    double photoOpacity;

    if (progress <= phase1End) {
      photoW = ui.lerpDouble(screenWidth, circleMaxSize, p1)!;
      photoH = ui.lerpDouble(currentExtent, circleMaxSize, p1)!;
      photoL = ui.lerpDouble(0.0, (screenWidth - circleMaxSize) / 2, p1)!;
      photoT = ui.lerpDouble(0.0, circleTop, p1)!;
      photoBR = BorderRadius.lerp(
        BorderRadius.only(
          bottomLeft: Radius.circular(ExpatlioDesign.radiusExtraLarge),
          bottomRight: Radius.circular(ExpatlioDesign.radiusExtraLarge),
        ),
        BorderRadius.circular(circleMaxSize / 2),
        p1,
      )!;
      photoOpacity = 1.0;
    } else if (progress <= phase2End) {
      photoW = circleSize;
      photoH = circleSize;
      photoL = (screenWidth - circleSize) / 2;
      photoT = circleTop;
      photoBR = BorderRadius.circular(circleSize / 2);
      photoOpacity = 1.0;
    } else {
      final s = circleSize.clamp(1.0, circleMaxSize);
      photoW = s;
      photoH = s;
      photoL = (screenWidth - s) / 2;
      photoT = circleTop;
      photoBR = BorderRadius.circular(s / 2);
      photoOpacity = (1.0 - p3).clamp(0.0, 1.0);
    }

    // --- Rating badge ---
    final ratingOpacity = (1.0 - p1 * 2.0).clamp(0.0, 1.0);

    // --- Single sliding text block ---
    const estimatedTextHeight = 42.0;
    final expandedTextTop = currentExtent - 16.0 - estimatedTextHeight;
    final collapsedTextTop = circleTop + circleSize + 8.0;

    double textTop;
    double textPadLeft, textPadRight;
    Alignment textAlign;
    double textOpacity;

    if (progress <= phase1End) {
      textTop = ui.lerpDouble(expandedTextTop, collapsedTextTop, p1)!;
      textPadLeft = ui.lerpDouble(16.0, 0.0, p1)!;
      textPadRight = ui.lerpDouble(100.0, 0.0, p1)!;
      textAlign = Alignment.lerp(Alignment.centerLeft, Alignment.center, p1)!;
      textOpacity = 1.0;
    } else if (progress <= phase2End) {
      textTop = collapsedTextTop;
      textPadLeft = 0.0;
      textPadRight = 0.0;
      textAlign = Alignment.center;
      textOpacity = (1.0 - p2).clamp(0.0, 1.0);
    } else {
      textTop = collapsedTextTop;
      textPadLeft = 0.0;
      textPadRight = 0.0;
      textAlign = Alignment.center;
      textOpacity = 0.0;
    }

    final subtitleOpacity =
        progress <= phase1End ? 1.0 : (1.0 - p2 * 1.5).clamp(0.0, 1.0);
    final compactNameOpacity = p3.clamp(0.0, 1.0);

    final nameFontSize =
        progress <= phase1End ? 17.0 : ui.lerpDouble(17.0, 15.0, p2)!;
    final subtitleFontSize =
        progress <= phase1End ? 15.0 : ui.lerpDouble(15.0, 12.0, p2)!;
    final nameColor = Color.lerp(Colors.white, theme.primaryText, p1)!;
    final subtitleColor =
        Color.lerp(Color(0xFFEDEDED), theme.secondaryText, p1)!;
    final bgColor = Colors.transparent;
    final hasPhoto = photoUrl.trim().isNotEmpty;

    return Container(
      color: bgColor,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          // Single morphing photo
          if (photoOpacity > 0.01 && photoW > 1)
            Positioned(
              left: photoL,
              top: photoT,
              width: photoW,
              height: photoH,
              child: Opacity(
                opacity: photoOpacity,
                child: ClipRRect(
                  borderRadius: photoBR,
                  child: hasPhoto
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          width: photoW,
                          height: photoH,
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          memCacheWidth: 800,
                        )
                      : Container(
                          width: photoW,
                          height: photoH,
                          color: FlutterFlowTheme.of(context).primaryBackground,
                          child: Icon(
                            Icons.person_rounded,
                            color: FlutterFlowTheme.of(context).secondaryText,
                            size: (photoW * 0.38).clamp(18.0, 44.0).toDouble(),
                          ),
                        ),
                ),
              ),
            ),

          // Rating badge (fades early)
          if (ratingOpacity > 0.01 && ratingAverage > 0.0)
            Positioned(
              right: 16.0,
              bottom: 16.0,
              child: Opacity(
                opacity: ratingOpacity,
                child: Container(
                  width: 82.0,
                  height: 45.0,
                  decoration: BoxDecoration(
                    color: Color(0x3CFFFFFF),
                    borderRadius:
                        BorderRadius.circular(ExpatlioDesign.radiusLarge),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(ExpatlioDesign.space4),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          width: 41.0,
                          height: 41.0,
                          decoration: BoxDecoration(
                            color: Color(0x58FFFFFF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            FFIcons.kstar012,
                            color: Color(0xFFFDFF00),
                            size: 18.0,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space8,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0),
                          child: Text(
                            formatNumber(
                              ratingAverage,
                              formatType: FormatType.custom,
                              format: '0.0',
                              locale: '',
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'sf pro display',
                                  color: Colors.white,
                                  fontSize: 15.0,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Single sliding name + city/status
          if (textOpacity > 0.01)
            Positioned(
              left: 0,
              right: 0,
              top: textTop,
              child: Opacity(
                opacity: textOpacity,
                child: Padding(
                  padding:
                      EdgeInsets.only(left: textPadLeft, right: textPadRight),
                  child: Align(
                    alignment: textAlign,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: p1 < 0.5
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign:
                              p1 < 0.5 ? TextAlign.left : TextAlign.center,
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'sf pro display',
                                    color: nameColor,
                                    fontSize: nameFontSize,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        if (subtitleOpacity > 0.01)
                          Opacity(
                            opacity: subtitleOpacity,
                            child: Padding(
                              padding:
                                  EdgeInsets.only(top: ExpatlioDesign.space4),
                              child: Text(
                                cityAndStatus,
                                textAlign: p1 < 0.5
                                    ? TextAlign.left
                                    : TextAlign.center,
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'sf pro display',
                                      color: subtitleColor,
                                      fontSize: subtitleFontSize,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (compactNameOpacity > 0.01)
            Positioned(
              top: 0.0,
              left: 0.0,
              right: 0.0,
              child: Opacity(
                opacity: compactNameOpacity,
                child: Container(
                  height: statusBarHeight + kToolbarHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ExpatlioDesign.background,
                        ExpatlioDesign.background.withValues(alpha: 0.94),
                        ExpatlioDesign.background.withValues(alpha: 0.0)
                      ],
                      stops: [0.0, 0.8, 1.0],
                      begin: AlignmentDirectional(0.0, -1.0),
                      end: AlignmentDirectional(0.0, 1.0),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                        top: statusBarHeight,
                        left: ExpatlioDesign.space64,
                        right: ExpatlioDesign.space64),
                    child: Center(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'sf pro display',
                              color: theme.primaryText,
                              fontSize: 17.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
