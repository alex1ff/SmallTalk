import 'dart:async';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/app_loading_indicator.dart';
import '/components/empty/empty_widget.dart';
import '/components/review_card/review_card_widget.dart';
import '/components/ux_error_state.dart';
import '/components/ux_refreshing_indicator_overlay.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/user_match_profile.dart';
import '/services/reviews_load_result.dart';
import '/index.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'my_rew_n_s_model.dart';
export 'my_rew_n_s_model.dart';

const ValueKey<String> myRewNSLoadingKey =
    ValueKey<String>('my_rew_ns_loading');
const ValueKey<String> myRewNSEmptyKey = ValueKey<String>('my_rew_ns_empty');
const ValueKey<String> myRewNSListKey = ValueKey<String>('my_rew_ns_list');
const ValueKey<String> myRewNSErrorKey = ValueKey<String>('my_rew_ns_error');
const ValueKey<String> myRewNSRefreshErrorKey =
    ValueKey<String>('my_rew_ns_refresh_error');
const ValueKey<String> myRewNSRetryButtonKey =
    ValueKey<String>('my_rew_ns_retry_button');
const ValueKey<String> myRewNSRefreshingKey =
    ValueKey<String>('my_rew_ns_refreshing');
const ValueKey<String> myRewNSRefreshingIndicatorKey =
    ValueKey<String>('my_rew_ns_refreshing_indicator');
const ValueKey<String> myRewNSLoadMoreButtonKey =
    ValueKey<String>('my_rew_ns_load_more_button');
const ValueKey<String> myRewNSRatingDistributionKey =
    ValueKey<String>('my_rew_ns_rating_distribution');
const int myRewNSReviewsPageSize = 20;

ValueKey<String> myRewNSReviewKey(ReviewsRecord review) =>
    ValueKey<String>('my_rew_ns_review_${review.reference.path}');

typedef MyRewNSReviewsLoader = Future<List<ReviewsRecord>> Function(
  String ownerUid,
);
typedef MyRewNSReviewsResultLoader = Future<ReviewsLoadResult> Function(
  String ownerUid,
);
typedef MyRewNSReviewsResultStreamLoader = Stream<ReviewsLoadResult> Function(
  String ownerUid,
);
typedef MyRewNSAccessDeniedHandler = void Function(BuildContext context);

final class _MyRewNSAuthEmission {
  const _MyRewNSAuthEmission({required this.ownerUid, required this.epoch});

  final String ownerUid;
  final int epoch;
}

final class _BoundedMyRewNSReviewsResult {
  const _BoundedMyRewNSReviewsResult({
    required this.result,
    required this.hasMore,
    this.visibleLimit,
  });

  final ReviewsLoadResult result;
  final bool hasMore;
  final int? visibleLimit;
}

class MyRewNSWidget extends StatefulWidget {
  const MyRewNSWidget({
    super.key,
    this.reviewsLoader,
    this.reviewsResultLoader,
    this.reviewsResultStreamLoader,
    this.authUidStream,
    this.ownerUidProvider,
    this.accessDeniedHandler,
  });

  @visibleForTesting
  final MyRewNSReviewsLoader? reviewsLoader;
  @visibleForTesting
  final MyRewNSReviewsResultLoader? reviewsResultLoader;
  @visibleForTesting
  final MyRewNSReviewsResultStreamLoader? reviewsResultStreamLoader;
  @visibleForTesting
  final Stream<String>? authUidStream;
  @visibleForTesting
  final String Function()? ownerUidProvider;
  @visibleForTesting
  final MyRewNSAccessDeniedHandler? accessDeniedHandler;

  static String routeName = 'myRewNS';
  static String routePath = '/myRewNS';

  @override
  State<MyRewNSWidget> createState() => _MyRewNSWidgetState();
}

class _MyRewNSWidgetState extends State<MyRewNSWidget> {
  late MyRewNSModel _model;

  String _activeOwnerUid = '';
  int _activeOwnerEpoch = 0;
  bool _ownerAccessConfirmed = false;
  bool _ownerAccessDenied = false;
  UsersRecord? _lastAuthorizedOwnerDocument;
  bool _loadStartedForOwner = false;
  int _accessEpoch = 0;
  int? _scheduledDeniedRedirectEpoch;
  int _requestGeneration = 0;
  List<ReviewsRecord>? _lastSuccessfulReviews;
  Object? _reviewsError;
  bool _reviewsLoading = false;
  StreamSubscription<_BoundedMyRewNSReviewsResult>? _reviewsSubscription;
  int _reviewsLimit = myRewNSReviewsPageSize;
  bool _reviewsHasMore = false;
  Future<Map<int, int>>? _ratingCountsFuture;
  late Stream<_MyRewNSAuthEmission> _authSessionStream;
  String _latestAuthStreamOwnerUid = '';
  String? _lastObservedSessionCacheOwnerUid;
  int _latestAuthSessionEpoch = 0;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MyRewNSModel());
    MyRewNSModel.ensureSessionCacheLifecycleRegistered();
    final initialOwnerUid = _initialOwnerUid();
    _latestAuthStreamOwnerUid = initialOwnerUid;
    _lastObservedSessionCacheOwnerUid =
        initialOwnerUid.isEmpty ? null : initialOwnerUid;
    _authSessionStream = _trackAuthSessions(
      widget.authUidStream ?? _watchMyRewNSOwnerUids(),
    );
  }

  @override
  void didUpdateWidget(covariant MyRewNSWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authUidStream != widget.authUidStream) {
      final initialOwnerUid = _initialOwnerUid();
      _observeSessionCacheOwner(initialOwnerUid);
      _latestAuthStreamOwnerUid = initialOwnerUid;
      _authSessionStream = _trackAuthSessions(
        widget.authUidStream ?? _watchMyRewNSOwnerUids(),
      );
      _resetOwner('', ++_latestAuthSessionEpoch);
    }
  }

  bool get _hasIndependentDirectAuthUid =>
      widget.ownerUidProvider != null || widget.authUidStream == null;

  String _directAuthUid() => (widget.ownerUidProvider?.call() ??
          FirebaseAuth.instance.currentUser?.uid ??
          '')
      .trim();

  String _initialOwnerUid() =>
      widget.authUidStream == null && _hasIndependentDirectAuthUid
          ? _directAuthUid()
          : '';

  Stream<_MyRewNSAuthEmission> _trackAuthSessions(Stream<String> authUidStream) {
    return authUidStream.map((rawOwnerUid) {
      final ownerUid = rawOwnerUid.trim();
      _observeSessionCacheOwner(ownerUid);
      _latestAuthStreamOwnerUid = ownerUid;
      final epoch = ++_latestAuthSessionEpoch;
      return _MyRewNSAuthEmission(ownerUid: ownerUid, epoch: epoch);
    });
  }

  void _observeSessionCacheOwner(String ownerUid) {
    final previousOwnerUid = _lastObservedSessionCacheOwnerUid;
    if (previousOwnerUid != null && previousOwnerUid != ownerUid) {
      MyRewNSModel.debugClearSessionCache();
    }
    _lastObservedSessionCacheOwnerUid = ownerUid;
  }

  _MyRewNSAuthEmission _initialAuthEmission() => _MyRewNSAuthEmission(
        ownerUid: _initialOwnerUid(),
        epoch: _latestAuthSessionEpoch,
      );

  _MyRewNSAuthEmission _effectiveAuthEmission(
    _MyRewNSAuthEmission emission,
  ) {
    if (widget.authUidStream != null || widget.ownerUidProvider == null) {
      return emission;
    }
    final directOwnerUid = _directAuthUid();
    if (directOwnerUid != _latestAuthStreamOwnerUid) {
      _observeSessionCacheOwner(directOwnerUid);
      _latestAuthStreamOwnerUid = directOwnerUid;
      _latestAuthSessionEpoch += 1;
    }
    return _MyRewNSAuthEmission(
      ownerUid: directOwnerUid,
      epoch: _latestAuthSessionEpoch,
    );
  }

  String _ownerUidForEmission(_MyRewNSAuthEmission emission) {
    if (!_hasIndependentDirectAuthUid) {
      return emission.ownerUid;
    }
    final directOwnerUid = _directAuthUid();
    _observeSessionCacheOwner(directOwnerUid);
    return emission.ownerUid == directOwnerUid ? directOwnerUid : '';
  }

  bool _authBoundaryMatches(String ownerUid, int ownerEpoch) {
    if (ownerUid.isEmpty ||
        _latestAuthStreamOwnerUid != ownerUid ||
        _latestAuthSessionEpoch != ownerEpoch) {
      return false;
    }
    if (!_hasIndependentDirectAuthUid) {
      return true;
    }
    final directOwnerUid = _directAuthUid();
    _observeSessionCacheOwner(directOwnerUid);
    return directOwnerUid == ownerUid;
  }

  _BoundedMyRewNSReviewsResult _boundedReviewsResult(
    ReviewsLoadResult result,
    int visibleLimit,
  ) {
    return _BoundedMyRewNSReviewsResult(
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

  Stream<_BoundedMyRewNSReviewsResult> _defaultReviewsLoader(
    String ownerUid,
    int visibleLimit,
  ) {
    final query = ReviewsRecord.collection
        .where(
          'toUserId',
          isEqualTo: UsersRecord.collection.doc(ownerUid),
        )
        .orderBy('createdAt', descending: true)
        .limit(visibleLimit + 1);
    return query.snapshots(includeMetadataChanges: true).map(
      (snapshot) => _boundedReviewsResult(
        ReviewsLoadResult(
          reviews: snapshot.docs.map(ReviewsRecord.fromSnapshot).toList(),
          isFromCache: snapshot.metadata.isFromCache,
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
        ),
        visibleLimit,
      ),
    );
  }

  Stream<_BoundedMyRewNSReviewsResult> _loadReviews(
    String ownerUid,
    int visibleLimit,
  ) {
    final streamLoader = widget.reviewsResultStreamLoader;
    if (streamLoader != null) {
      return streamLoader(ownerUid)
          .map((result) => _boundedReviewsResult(result, visibleLimit));
    }
    final resultLoader = widget.reviewsResultLoader;
    if (resultLoader != null) {
      return Stream<ReviewsLoadResult>.fromFuture(resultLoader(ownerUid)).map(
        (result) => _BoundedMyRewNSReviewsResult(
          result: result,
          hasMore: false,
        ),
      );
    }
    final legacyLoader = widget.reviewsLoader;
    if (legacyLoader != null) {
      return Stream<ReviewsLoadResult>.fromFuture(
        legacyLoader(ownerUid).then(ReviewsLoadResult.authoritative),
      ).map(
        (result) => _BoundedMyRewNSReviewsResult(
          result: result,
          hasMore: false,
        ),
      );
    }
    return _defaultReviewsLoader(ownerUid, visibleLimit);
  }

  bool get _reviewsPaginationEnabled =>
      widget.reviewsResultStreamLoader != null ||
      (widget.reviewsResultLoader == null && widget.reviewsLoader == null);

  bool get _usesDefaultReviewsSource =>
      widget.reviewsResultStreamLoader == null &&
      widget.reviewsResultLoader == null &&
      widget.reviewsLoader == null;

  Future<Map<int, int>> _loadRatingCounts(String ownerUid) async {
    final ownerReference = UsersRecord.collection.doc(ownerUid);
    final baseQuery = ReviewsRecord.collection.where(
      'toUserId',
      isEqualTo: ownerReference,
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

  void _synchronizeOwner(String ownerUid, int ownerEpoch) {
    if (ownerUid == _activeOwnerUid && ownerEpoch == _activeOwnerEpoch) {
      return;
    }
    _resetOwner(ownerUid, ownerEpoch);
  }

  void _resetOwner(String ownerUid, int ownerEpoch) {
    final ownerBoundaryChanged =
        ownerUid != _activeOwnerUid || ownerEpoch != _activeOwnerEpoch;
    unawaited(_reviewsSubscription?.cancel());
    _reviewsSubscription = null;
    _requestGeneration += 1;
    _accessEpoch += 1;
    _activeOwnerUid = ownerUid;
    _activeOwnerEpoch = ownerEpoch;
    _ownerAccessConfirmed = false;
    _ownerAccessDenied = false;
    _lastAuthorizedOwnerDocument = null;
    _loadStartedForOwner = false;
    _scheduledDeniedRedirectEpoch = null;
    if (ownerBoundaryChanged) {
      _model.rate = 0;
      _model.ratingBarValue = null;
    }
    _reviewsLimit = myRewNSReviewsPageSize;
    _reviewsHasMore = false;
    _ratingCountsFuture = null;
    final cachedReviews =
        ownerUid.isEmpty ? null : MyRewNSModel.cachedReviews(ownerUid);
    _lastSuccessfulReviews = cachedReviews == null || !_reviewsPaginationEnabled
        ? cachedReviews
        : List<ReviewsRecord>.unmodifiable(
            cachedReviews.take(_reviewsLimit),
          );
    _reviewsError = null;
    _reviewsLoading = false;
  }

  void _confirmOwnerAccess(UsersRecord ownerDocument) {
    if (!_ownerAccessConfirmed || _ownerAccessDenied) {
      _accessEpoch += 1;
    }
    _ownerAccessConfirmed = true;
    _ownerAccessDenied = false;
    _lastAuthorizedOwnerDocument = ownerDocument;
    _scheduledDeniedRedirectEpoch = null;
    _ensureReviewsLoadStarted();
    if (_ratingCountsFuture == null && _usesDefaultReviewsSource) {
      _ratingCountsFuture = _loadRatingCounts(_activeOwnerUid);
    }
  }

  void _revokeOwnerAccess() {
    if (_ownerAccessDenied &&
        !_ownerAccessConfirmed &&
        _lastAuthorizedOwnerDocument == null &&
        _lastSuccessfulReviews == null &&
        !_reviewsLoading) {
      return;
    }
    unawaited(_reviewsSubscription?.cancel());
    _reviewsSubscription = null;
    _requestGeneration += 1;
    _accessEpoch += 1;
    _ownerAccessConfirmed = false;
    _ownerAccessDenied = true;
    _lastAuthorizedOwnerDocument = null;
    _loadStartedForOwner = false;
    _lastSuccessfulReviews = null;
    _reviewsError = null;
    _reviewsLoading = false;
    _reviewsLimit = myRewNSReviewsPageSize;
    _reviewsHasMore = false;
    _ratingCountsFuture = null;
    _model.rate = 0;
    _model.ratingBarValue = null;
    _scheduledDeniedRedirectEpoch = null;
    MyRewNSModel.debugClearSessionCache();
  }

  void _scheduleAccessDeniedRedirect(String ownerUid, int ownerEpoch) {
    final accessEpoch = _accessEpoch;
    if (_scheduledDeniedRedirectEpoch == accessEpoch) {
      return;
    }
    _scheduledDeniedRedirectEpoch = accessEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ownerDocument = currentUserDocument;
      final redirectIsCurrent = mounted &&
          ownerUid == _activeOwnerUid &&
          ownerEpoch == _activeOwnerEpoch &&
          accessEpoch == _accessEpoch &&
          _ownerAccessDenied &&
          !_ownerAccessConfirmed &&
          _authBoundaryMatches(ownerUid, ownerEpoch) &&
          hasCurrentUserDocumentForUid(ownerUid) &&
          !canAccessTeacherSurfaces(ownerDocument);
      if (!redirectIsCurrent) {
        if (mounted && accessEpoch == _accessEpoch) {
          _scheduledDeniedRedirectEpoch = null;
        }
        return;
      }
      final handler = widget.accessDeniedHandler;
      if (handler != null) {
        handler(context);
        return;
      }
      context.goNamed(
        StudentsDashboardWidget.routeName,
        queryParameters: {
          'zn': serializeParam(false, ParamType.bool),
        }.withoutNulls,
      );
    });
  }

  void _ensureReviewsLoadStarted() {
    if (_loadStartedForOwner || _activeOwnerUid.isEmpty) {
      return;
    }
    _loadStartedForOwner = true;
    _startReviewsLoad(notify: false);
  }

  void _startReviewsLoad({required bool notify}) {
    final ownerUid = _activeOwnerUid;
    if (ownerUid.isEmpty || !_ownerAccessConfirmed) {
      return;
    }

    final ownerEpoch = _activeOwnerEpoch;
    final accessEpoch = _accessEpoch;
    unawaited(_reviewsSubscription?.cancel());
    _reviewsSubscription = null;
    final requestGeneration = ++_requestGeneration;
    final cacheGeneration = MyRewNSModel.sessionCacheGeneration;
    final reviewsLimit = _reviewsLimit;
    _reviewsError = null;
    _reviewsLoading = true;
    if (notify && mounted) {
      setState(() {});
    }

    try {
      _reviewsSubscription = _loadReviews(ownerUid, reviewsLimit).listen(
        (boundedResult) {
          final result = boundedResult.result;
          if (!_requestIsCurrent(
            ownerUid,
            ownerEpoch,
            accessEpoch,
            requestGeneration,
          )) {
            return;
          }
          if (!_authBoundaryMatches(ownerUid, ownerEpoch)) {
            _invalidateForAuthBoundaryMismatch();
            return;
          }
          if (!result.isAuthoritative) {
            final previous =
                _lastSuccessfulReviews ?? const <ReviewsRecord>[];
            final mergedReviews = mergeUnconfirmedReviews(
              previous: previous,
              incoming: result.reviews,
            );
            final visibleReviews = boundedResult.visibleLimit == null
                ? mergedReviews
                : List<ReviewsRecord>.unmodifiable(
                    mergedReviews.take(boundedResult.visibleLimit!),
                  );
            setState(() {
              if (_lastSuccessfulReviews != null || visibleReviews.isNotEmpty) {
                _lastSuccessfulReviews = visibleReviews;
              }
              _reviewsError = null;
              _reviewsLoading = true;
            });
            return;
          }
          final stableReviews =
              List<ReviewsRecord>.unmodifiable(result.reviews);
          MyRewNSModel.cacheReviews(
            ownerUid,
            stableReviews,
            expectedGeneration: cacheGeneration,
          );
          setState(() {
            _lastSuccessfulReviews = stableReviews;
            _reviewsHasMore = boundedResult.hasMore;
            _reviewsError = null;
            _reviewsLoading = false;
          });
          unawaited(_reviewsSubscription?.cancel());
          _reviewsSubscription = null;
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!_requestIsCurrent(
            ownerUid,
            ownerEpoch,
            accessEpoch,
            requestGeneration,
          )) {
            return;
          }
          if (!_authBoundaryMatches(ownerUid, ownerEpoch)) {
            _invalidateForAuthBoundaryMismatch();
            return;
          }
          setState(() {
            _reviewsError = error;
            _reviewsLoading = false;
          });
          unawaited(_reviewsSubscription?.cancel());
          _reviewsSubscription = null;
        },
        onDone: () {
          if (!_requestIsCurrent(
                ownerUid,
                ownerEpoch,
                accessEpoch,
                requestGeneration,
              ) ||
              !_reviewsLoading) {
            return;
          }
          setState(() {
            _reviewsError =
                StateError('Could not confirm reviews with the server.');
            _reviewsLoading = false;
          });
          _reviewsSubscription = null;
        },
      );
    } catch (error) {
      if (_requestIsCurrent(
            ownerUid,
            ownerEpoch,
            accessEpoch,
            requestGeneration,
          ) &&
          _authBoundaryMatches(ownerUid, ownerEpoch)) {
        setState(() {
          _reviewsError = error;
          _reviewsLoading = false;
        });
      }
    }
  }

  bool _requestIsCurrent(
    String ownerUid,
    int ownerEpoch,
    int accessEpoch,
    int requestGeneration,
  ) {
    return mounted &&
        ownerUid == _activeOwnerUid &&
        ownerEpoch == _activeOwnerEpoch &&
        ownerEpoch == _latestAuthSessionEpoch &&
        accessEpoch == _accessEpoch &&
        _ownerAccessConfirmed &&
        !_ownerAccessDenied &&
        requestGeneration == _requestGeneration &&
        _authBoundaryMatches(ownerUid, ownerEpoch);
  }

  void _invalidateForAuthBoundaryMismatch() {
    if (!mounted) {
      return;
    }
    setState(() => _resetOwner('', _latestAuthSessionEpoch));
  }

  void _retryReviews() {
    _loadStartedForOwner = true;
    _ratingCountsFuture = _usesDefaultReviewsSource
        ? _loadRatingCounts(_activeOwnerUid)
        : null;
    _startReviewsLoad(notify: true);
  }

  void _loadMoreReviews() {
    if (!_reviewsPaginationEnabled ||
        !_reviewsHasMore ||
        _reviewsLoading ||
        _activeOwnerUid.isEmpty) {
      return;
    }
    _reviewsLimit += myRewNSReviewsPageSize;
    _startReviewsLoad(notify: true);
  }

  Widget _buildLoadMoreReviewsButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExpatlioDesign.space16,
        ExpatlioDesign.space16,
        ExpatlioDesign.space16,
        ExpatlioDesign.space0,
      ),
      child: Center(
        child: OutlinedButton(
          key: myRewNSLoadMoreButtonKey,
          onPressed: _reviewsLoading ? null : _loadMoreReviews,
          child: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'Показать ещё',
              enText: 'Show more',
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_reviewsSubscription?.cancel());
    _requestGeneration += 1;
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_MyRewNSAuthEmission>(
      key: ObjectKey(_authSessionStream),
      stream: _authSessionStream,
      initialData: _initialAuthEmission(),
      builder: (context, authSnapshot) {
        final authEmission = _effectiveAuthEmission(authSnapshot.data!);
        final ownerUid = _ownerUidForEmission(authEmission);
        final ownerEpoch = authEmission.epoch;
        _synchronizeOwner(ownerUid, ownerEpoch);
        return AuthUserStreamWidget(
          builder: (context) {
            final ownerDocumentMatches = hasCurrentUserDocumentForUid(ownerUid);
            if (ownerDocumentMatches &&
                !canAccessTeacherSurfaces(currentUserDocument)) {
              _revokeOwnerAccess();
              _scheduleAccessDeniedRedirect(ownerUid, ownerEpoch);

              return Scaffold(
                backgroundColor: ExpatlioDesign.background,
                body: Center(
                  child: Text(
                    FFLocalizations.of(context).getVariableText(
                      ruText:
                          'Отзывы преподавателя доступны после проверки заявки',
                      enText:
                          'Teacher reviews are available after approval',
                    ),
                    textAlign: TextAlign.center,
                    style: FlutterFlowTheme.of(context).bodyMedium,
                  ),
                ),
              );
            }

            if (ownerDocumentMatches &&
                canAccessTeacherSurfaces(currentUserDocument)) {
              _confirmOwnerAccess(currentUserDocument!);
            }

            if (ownerUid.isEmpty ||
                _ownerAccessDenied ||
                !_ownerAccessConfirmed) {
              return _buildColdState(context, isError: false);
            }

            final reviews = _lastSuccessfulReviews;
            if (reviews == null) {
              return _buildColdState(
                context,
                isError: _reviewsError != null,
              );
            }

            final ratingCountsFuture = _ratingCountsFuture;
            Widget content = ratingCountsFuture == null
                ? _buildReviewsContent(context, reviews)
                : FutureBuilder<Map<int, int>>(
                    future: ratingCountsFuture,
                    builder: (context, snapshot) => _buildReviewsContent(
                      context,
                      reviews,
                      authoritativeRatingCounts: snapshot.data,
                    ),
                  );
            content = UxRefreshingIndicatorOverlay(
              key: myRewNSRefreshingKey,
              isRefreshing: _reviewsLoading,
              padding: EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space8,
                MediaQuery.paddingOf(context).top +
                    BasicPageHeader.height +
                    ExpatlioDesign.space8,
                ExpatlioDesign.space8,
                ExpatlioDesign.space8,
              ),
              indicator: UxRefreshingIndicatorPill(
                key: myRewNSRefreshingIndicatorKey,
                semanticsLabel: null,
              ),
              semanticsLabel:
                  FFLocalizations.of(context).getVariableText(
                ruText: 'Обновление отзывов преподавателя',
                enText: 'Refreshing teacher reviews',
              ),
              child: content,
            );
            content = _buildWarmError(
              context,
              content,
              showError: _reviewsError != null,
            );
            return content;
          },
        );
      },
    );
  }

  Widget _buildColdState(
    BuildContext context, {
    required bool isError,
  }) {
    final state = isError
        ? _buildErrorState(context, stateKey: myRewNSErrorKey)
        : Semantics(
            key: myRewNSLoadingKey,
            container: true,
            liveRegion: true,
            label: FFLocalizations.of(context).getVariableText(
              ruText: 'Загрузка отзывов преподавателя',
              enText: 'Loading teacher reviews',
            ),
            child: const ExcludeSemantics(child: AppLoadingIndicator()),
        );
              return Scaffold(
                backgroundColor:
                    FlutterFlowTheme.of(context).secondaryBackground,
                body: Stack(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: ExpatlioDesign.space112,
                    ),
            child: Center(
                  child: state),
                  ),
          BasicPageHeader(
            title: FFLocalizations.of(context).getText(
              '6on93f38' /* Мои отзывы */,
            ),
          ),
        ],
                ),
              );
            }

  Widget _buildErrorState(BuildContext context, {required Key stateKey}) {
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
        enText: 'Retry loading teacher reviews',
      ),
      retryButtonKey: myRewNSRetryButtonKey,
      onRetry: _retryReviews,
      showIcon: false,
      maxWidth: 360.0,
    );
  }

  Widget _buildWarmError(
    BuildContext context,
    Widget content, {
    required bool showError,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (showError)
          PositionedDirectional(
            start: ExpatlioDesign.space16,
            end: ExpatlioDesign.space16,
            bottom: ExpatlioDesign.space16,
            child: Material(
              color: Colors.transparent,
              elevation: 4.0,
              child: _buildErrorState(
                context,
                stateKey: myRewNSRefreshErrorKey,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReviewsContent(
    BuildContext context,
    List<ReviewsRecord> myRewNSReviewsRecordList, {
    Map<int, int>? authoritativeRatingCounts,
  }) {
    final teacherDocument = _lastAuthorizedOwnerDocument;
    final loadedRatingCounts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final review in myRewNSReviewsRecordList) {
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

    int countForRating(int rating) => ratingCounts?[rating] ?? 0;

    double percentForRating(int rating) {
      if (ratingDistributionTotal <= 0) {
        return 0.0;
      }
      return (countForRating(rating) / ratingDistributionTotal)
          .clamp(0.0, 1.0)
          .toDouble();
    }

            return GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: Scaffold(
                key: scaffoldKey,
                backgroundColor:
                    FlutterFlowTheme.of(context).secondaryBackground,
                body: Stack(
                  children: [
                    if (myRewNSReviewsRecordList.isNotEmpty)
                      SingleChildScrollView(
                        primary: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.all(ExpatlioDesign.space16),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AuthUserStreamWidget(
                                        builder: (context) => Text(
                                          valueOrDefault<String>(
                                    teacherDocument?.rating.average
                                                .toString(),
                                            '0',
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
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space8,
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space0),
                                        child: AuthUserStreamWidget(
                                          builder: (context) =>
                                              RatingBar.builder(
                                            onRatingUpdate: (newValue) =>
                                                safeSetState(() => _model
                                                    .ratingBarValue = newValue),
                                            itemBuilder: (context, index) =>
                                                Icon(
                                              Icons.star_rounded,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .warning,
                                            ),
                                            direction: Axis.horizontal,
                                            initialRating:
                                                _model.ratingBarValue ??=
                                                    valueOrDefault<double>(
                                      teacherDocument
                                                  ?.rating.average,
                                              0.0,
                                            ),
                                            unratedColor:
                                                FlutterFlowTheme.of(context)
                                                    .primaryBackground,
                                            itemCount: 5,
                                            itemSize: 18.0,
                                            glowColor:
                                                FlutterFlowTheme.of(context)
                                                    .warning,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space4,
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space0),
                                        child: AuthUserStreamWidget(
                                          builder: (context) => Text(
                                            functions.getReviewString(
                                                valueOrDefault<String>(
                                      teacherDocument
                                                  ?.rating.totalReviews
                                                  .toString(),
                                              '0',
                                            )),
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'sf pro display',
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  fontSize: 15.0,
                                                  letterSpacing: 0.0,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (ratingCounts != null)
                                    Expanded(
                                      key: myRewNSRatingDistributionKey,
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          ExpatlioDesign.space12,
                                          ExpatlioDesign.space0,
                                          ExpatlioDesign.space0,
                                          ExpatlioDesign.space0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 11.0,
                                                decoration: BoxDecoration(),
                                                child: Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    'xw59o8hf' /* 5 */,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
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
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        2.0, 0.0, 2.0, 0.0),
                                                child: AuthUserStreamWidget(
                                                  builder: (context) =>
                                                      LinearPercentIndicator(
                                                    percent: percentForRating(
                                                                    5),
                                                    width: 106.0,
                                                    lineHeight: 4.0,
                                                    animation: true,
                                                    animateFromLastPercent:
                                                        true,
                                                    progressColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primary,
                                                    backgroundColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .accent4,
                                                    barRadius: Radius.circular(
                                                        ExpatlioDesign
                                                            .radiusSmall),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: 33.0,
                                                decoration: BoxDecoration(),
                                                child: AutoSizeText(
                                                  valueOrDefault<String>(
                                                    countForRating(5).toString(),
                                                    '0',
                                                  ),
                                                  maxLines: 1,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 15.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                ),
                                              ),
                                            ].divide(SizedBox(
                                                width: ExpatlioDesign.space4)),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 11.0,
                                                decoration: BoxDecoration(),
                                                child: Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    'oyswu6kn' /* 4 */,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
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
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        2.0, 0.0, 2.0, 0.0),
                                                child: AuthUserStreamWidget(
                                                  builder: (context) =>
                                                      LinearPercentIndicator(
                                                    percent: percentForRating(
                                                                    4),
                                                    width: 106.0,
                                                    lineHeight: 4.0,
                                                    animation: true,
                                                    animateFromLastPercent:
                                                        true,
                                                    progressColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primary,
                                                    backgroundColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .accent4,
                                                    barRadius: Radius.circular(
                                                        ExpatlioDesign
                                                            .radiusSmall),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: 33.0,
                                                decoration: BoxDecoration(),
                                                child: AutoSizeText(
                                                  valueOrDefault<String>(
                                                    countForRating(4).toString(),
                                                    '0',
                                                  ),
                                                  maxLines: 1,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 15.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                ),
                                              ),
                                            ].divide(SizedBox(
                                                width: ExpatlioDesign.space4)),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 11.0,
                                                decoration: BoxDecoration(),
                                                child: Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    '6r6bosmv' /* 3 */,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
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
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        2.0, 0.0, 2.0, 0.0),
                                                child: AuthUserStreamWidget(
                                                  builder: (context) =>
                                                      LinearPercentIndicator(
                                                    percent: percentForRating(
                                                                    3),
                                                    width: 106.0,
                                                    lineHeight: 4.0,
                                                    animation: true,
                                                    animateFromLastPercent:
                                                        true,
                                                    progressColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primary,
                                                    backgroundColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .accent4,
                                                    barRadius: Radius.circular(
                                                        ExpatlioDesign
                                                            .radiusSmall),
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
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 15.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                ),
                                              ),
                                            ].divide(SizedBox(
                                                width: ExpatlioDesign.space4)),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 11.0,
                                                decoration: BoxDecoration(),
                                                child: Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    'v1flzexo' /* 2 */,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
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
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        2.0, 0.0, 2.0, 0.0),
                                                child: AuthUserStreamWidget(
                                                  builder: (context) =>
                                                      LinearPercentIndicator(
                                                    percent: percentForRating(
                                                                    2),
                                                    width: 106.0,
                                                    lineHeight: 4.0,
                                                    animation: true,
                                                    animateFromLastPercent:
                                                        true,
                                                    progressColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primary,
                                                    backgroundColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .accent4,
                                                    barRadius: Radius.circular(
                                                        ExpatlioDesign
                                                            .radiusSmall),
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
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 15.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                ),
                                              ),
                                            ].divide(SizedBox(
                                                width: ExpatlioDesign.space4)),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 11.0,
                                                decoration: BoxDecoration(),
                                                child: Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    'rek4xcp6' /* 1 */,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
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
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        2.0, 0.0, 2.0, 0.0),
                                                child: AuthUserStreamWidget(
                                                  builder: (context) =>
                                                      LinearPercentIndicator(
                                                    percent: percentForRating(
                                                                    1),
                                                    width: 106.0,
                                                    lineHeight: 4.0,
                                                    animation: true,
                                                    animateFromLastPercent:
                                                        true,
                                                    progressColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primary,
                                                    backgroundColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .accent4,
                                                    barRadius: Radius.circular(
                                                        ExpatlioDesign
                                                            .radiusSmall),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: 33.0,
                                                decoration: BoxDecoration(),
                                                child: AutoSizeText(
                                                  valueOrDefault<String>(
                                                    countForRating(1).toString(),
                                                    '0',
                                                  ),
                                                  maxLines: 1,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 15.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                ),
                                              ),
                                            ].divide(SizedBox(
                                                width: ExpatlioDesign.space4)),
                                          ),
                                        ].divide(SizedBox(
                                            height: ExpatlioDesign.space4)),
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
                                                  ? FlutterFlowTheme.of(context)
                                                      .primary
                                                  : FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                                ExpatlioDesign.controlRadius),
                                          ),
                                          child: Align(
                                            alignment:
                                                AlignmentDirectional(0.0, 0.0),
                                            child: Text(
                                              FFLocalizations.of(context)
                                                  .getText(
                                                'qs8nwyrv' /* Все */,
                                              ),
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodyMedium
                                                  .override(
                                                    fontFamily:
                                                        'sf pro display',
                                                    color:
                                                        valueOrDefault<Color>(
                                                      _model.rate == 0
                                                          ? FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryBackground
                                                          : FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      FlutterFlowTheme.of(
                                                              context)
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
                                                  ? FlutterFlowTheme.of(context)
                                                      .primary
                                                  : FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                                ExpatlioDesign.controlRadius),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'xlaf7fli' /* 5 */,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: valueOrDefault<
                                                              Color>(
                                                            _model.rate == 5
                                                                ? FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground
                                                                : FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText,
                                                            FlutterFlowTheme.of(
                                                                    context)
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
                                            ].divide(SizedBox(
                                                width: ExpatlioDesign.space4)),
                                          ),
                                        ),
                                      ),
                                      InkWell(
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
                                                  ? FlutterFlowTheme.of(context)
                                                      .primary
                                                  : FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                                ExpatlioDesign.controlRadius),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'jw9lsb40' /* 4 */,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: valueOrDefault<
                                                              Color>(
                                                            _model.rate == 4
                                                                ? FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground
                                                                : FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText,
                                                            FlutterFlowTheme.of(
                                                                    context)
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
                                            ].divide(SizedBox(
                                                width: ExpatlioDesign.space4)),
                                          ),
                                        ),
                                      ),
                                      InkWell(
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
                                                  ? FlutterFlowTheme.of(context)
                                                      .primary
                                                  : FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                                ExpatlioDesign.controlRadius),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'ydhuju4o' /* 3 */,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: valueOrDefault<
                                                              Color>(
                                                            _model.rate == 3
                                                                ? FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground
                                                                : FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText,
                                                            FlutterFlowTheme.of(
                                                                    context)
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
                                            ].divide(SizedBox(
                                                width: ExpatlioDesign.space4)),
                                          ),
                                        ),
                                      ),
                                      InkWell(
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
                                                  ? FlutterFlowTheme.of(context)
                                                      .primary
                                                  : FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                                ExpatlioDesign.controlRadius),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'tcptiwm7' /* 2 */,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: valueOrDefault<
                                                              Color>(
                                                            _model.rate == 2
                                                                ? FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground
                                                                : FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText,
                                                            FlutterFlowTheme.of(
                                                                    context)
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
                                            ].divide(SizedBox(
                                                width: ExpatlioDesign.space4)),
                                          ),
                                        ),
                                      ),
                                      InkWell(
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
                                                  ? FlutterFlowTheme.of(context)
                                                      .primary
                                                  : FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                                ExpatlioDesign.controlRadius),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'kawozwy8' /* 1 */,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: valueOrDefault<
                                                              Color>(
                                                            _model.rate == 1
                                                                ? FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground
                                                                : FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText,
                                                            FlutterFlowTheme.of(
                                                                    context)
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
                                            ].divide(SizedBox(
                                                width: ExpatlioDesign.space4)),
                                          ),
                                        ),
                                      ),
                                    ]
                                        .divide(SizedBox(
                                            width: ExpatlioDesign.space8))
                                        .addToStart(SizedBox(
                                            width: ExpatlioDesign.space16))
                                        .addToEnd(SizedBox(
                                            width: ExpatlioDesign.space16)),
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
                                  final rew = myRewNSReviewsRecordList
                                      .where((e) => _model.rate == 0
                                          ? true
                                          : (_model.rate == e.rating))
                                      .toList();

                                  if (rew.isEmpty) {
                                    return Center(
                                      child: EmptyWidget(
                                        txt:
                                            'По выбранному рейтингу пока ничего нет. Попробуйте другую оценку.',
                                      ),
                                    );
                                  }

                                  return ListView.separated(
                            key: myRewNSListKey,
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
                                            ExpatlioDesign.space8,
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space8,
                                            ExpatlioDesign.space0),
                                        child: ReviewCardWidget(
                                          key: myRewNSReviewKey(rewItem),
                                          rewDoc: rewItem,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            if (_reviewsPaginationEnabled && _reviewsHasMore)
                              _buildLoadMoreReviewsButton(context),
                          ]
                              .addToStart(
                                  SizedBox(height: ExpatlioDesign.space112))
                              .addToEnd(
                                  SizedBox(height: ExpatlioDesign.space32)),
                        ),
                      ),
                    if (myRewNSReviewsRecordList.isEmpty)
                      Padding(
                key: myRewNSEmptyKey,
                        padding: EdgeInsetsDirectional.fromSTEB(
                            ExpatlioDesign.space0,
                            ExpatlioDesign.space136,
                            ExpatlioDesign.space0,
                            ExpatlioDesign.space0),
                        child: EmptyWidget(
                          txt:
                              'В этом разделе будут появляться отзывы учеников о ваших занятиях. Проведите первые звонки, и оценки с комментариями отобразятся здесь.',
                        ),
                      ),
                    BasicPageHeader(
                      title: FFLocalizations.of(context).getText(
                        '6on93f38' /* Мои отзывы */,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
      }

Stream<String> _watchMyRewNSOwnerUids() => FirebaseAuth.instance
    .authStateChanges()
    .map((user) => user?.uid.trim() ?? '');
