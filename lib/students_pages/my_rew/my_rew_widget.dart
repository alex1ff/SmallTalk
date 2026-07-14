import 'dart:async';

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
import '/services/reviews_load_result.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'my_rew_model.dart';
export 'my_rew_model.dart';

const ValueKey<String> myRewLoadingKey = ValueKey<String>('my_rew_loading');
const ValueKey<String> myRewEmptyKey = ValueKey<String>('my_rew_empty');
const ValueKey<String> myRewListKey = ValueKey<String>('my_rew_list');
const ValueKey<String> myRewErrorKey = ValueKey<String>('my_rew_error');
const ValueKey<String> myRewRefreshErrorKey =
    ValueKey<String>('my_rew_refresh_error');
const ValueKey<String> myRewRetryButtonKey =
    ValueKey<String>('my_rew_retry_button');
const ValueKey<String> myRewRefreshingKey =
    ValueKey<String>('my_rew_refreshing');
const ValueKey<String> myRewRefreshingIndicatorKey =
    ValueKey<String>('my_rew_refreshing_indicator');

ValueKey<String> myRewReviewKey(ReviewsRecord review) =>
    ValueKey<String>('my_rew_review_${review.reference.path}');

typedef MyRewReviewsLoader = Future<List<ReviewsRecord>> Function(
  String ownerUid,
);
typedef MyRewReviewsResultLoader = Future<ReviewsLoadResult> Function(
  String ownerUid,
);
typedef MyRewReviewsResultStreamLoader = Stream<ReviewsLoadResult> Function(
  String ownerUid,
);

final class _MyRewAuthEmission {
  const _MyRewAuthEmission({required this.ownerUid, required this.epoch});

  final String ownerUid;
  final int epoch;
}

class MyRewWidget extends StatefulWidget {
  const MyRewWidget({
    super.key,
    this.reviewsLoader,
    this.reviewsResultLoader,
    this.reviewsResultStreamLoader,
    this.authUidStream,
    this.ownerUidProvider,
  });

  @visibleForTesting
  final MyRewReviewsLoader? reviewsLoader;
  @visibleForTesting
  final MyRewReviewsResultLoader? reviewsResultLoader;
  @visibleForTesting
  final MyRewReviewsResultStreamLoader? reviewsResultStreamLoader;
  @visibleForTesting
  final Stream<String>? authUidStream;
  @visibleForTesting
  final String Function()? ownerUidProvider;

  static String routeName = 'myRew';
  static String routePath = '/myRew';

  @override
  State<MyRewWidget> createState() => _MyRewWidgetState();
}

class _MyRewWidgetState extends State<MyRewWidget> {
  late MyRewModel _model;

  String _activeOwnerUid = '';
  int _activeOwnerEpoch = 0;
  int _requestGeneration = 0;
  List<ReviewsRecord>? _lastSuccessfulReviews;
  Object? _reviewsError;
  bool _reviewsLoading = false;
  StreamSubscription<ReviewsLoadResult>? _reviewsSubscription;
  late Stream<_MyRewAuthEmission> _authSessionStream;
  String _latestAuthStreamOwnerUid = '';
  String? _lastObservedSessionCacheOwnerUid;
  int _latestAuthSessionEpoch = 0;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MyRewModel());
    MyRewModel.ensureSessionCacheLifecycleRegistered();
    final initialOwnerUid = _initialOwnerUid();
    _latestAuthStreamOwnerUid = initialOwnerUid;
    _lastObservedSessionCacheOwnerUid =
        initialOwnerUid.isEmpty ? null : initialOwnerUid;
    _authSessionStream = _trackAuthSessions(
      widget.authUidStream ?? _watchMyRewOwnerUids(),
    );
  }

  @override
  void didUpdateWidget(covariant MyRewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authUidStream != widget.authUidStream) {
      final initialOwnerUid = _initialOwnerUid();
      _observeSessionCacheOwner(initialOwnerUid);
      _latestAuthStreamOwnerUid = initialOwnerUid;
      _authSessionStream = _trackAuthSessions(
        widget.authUidStream ?? _watchMyRewOwnerUids(),
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

  Stream<_MyRewAuthEmission> _trackAuthSessions(Stream<String> authUidStream) {
    return authUidStream.map((rawOwnerUid) {
      final ownerUid = rawOwnerUid.trim();
      _observeSessionCacheOwner(ownerUid);
      _latestAuthStreamOwnerUid = ownerUid;
      final epoch = ++_latestAuthSessionEpoch;
      return _MyRewAuthEmission(ownerUid: ownerUid, epoch: epoch);
    });
  }

  void _observeSessionCacheOwner(String ownerUid) {
    final previousOwnerUid = _lastObservedSessionCacheOwnerUid;
    if (previousOwnerUid != null && previousOwnerUid != ownerUid) {
      MyRewModel.debugClearSessionCache();
    }
    _lastObservedSessionCacheOwnerUid = ownerUid;
  }

  _MyRewAuthEmission _initialAuthEmission() => _MyRewAuthEmission(
        ownerUid: _initialOwnerUid(),
        epoch: _latestAuthSessionEpoch,
      );

  _MyRewAuthEmission _effectiveAuthEmission(
    _MyRewAuthEmission emission,
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
    return _MyRewAuthEmission(
      ownerUid: directOwnerUid,
      epoch: _latestAuthSessionEpoch,
    );
  }

  String _ownerUidForEmission(_MyRewAuthEmission emission) {
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

  Stream<ReviewsLoadResult> _defaultReviewsLoader(String ownerUid) {
    final query = ReviewsRecord.collection
        .where(
          'fromUserId',
          isEqualTo: UsersRecord.collection.doc(ownerUid),
        )
        .orderBy('createdAt', descending: true);
    return query.snapshots(includeMetadataChanges: true).map(
      (snapshot) => ReviewsLoadResult(
        reviews: snapshot.docs.map(ReviewsRecord.fromSnapshot).toList(),
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      ),
    );
  }

  Stream<ReviewsLoadResult> _loadReviews(String ownerUid) {
    final streamLoader = widget.reviewsResultStreamLoader;
    if (streamLoader != null) {
      return streamLoader(ownerUid);
    }
    final resultLoader = widget.reviewsResultLoader;
    if (resultLoader != null) {
      return Stream<ReviewsLoadResult>.fromFuture(resultLoader(ownerUid));
    }
    final legacyLoader = widget.reviewsLoader;
    if (legacyLoader != null) {
      return Stream<ReviewsLoadResult>.fromFuture(
        legacyLoader(ownerUid).then(ReviewsLoadResult.authoritative),
      );
    }
    return _defaultReviewsLoader(ownerUid);
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
    _activeOwnerUid = ownerUid;
    _activeOwnerEpoch = ownerEpoch;
    if (ownerBoundaryChanged) {
      _model.rate = 0;
    }
    _lastSuccessfulReviews =
        ownerUid.isEmpty ? null : MyRewModel.cachedReviews(ownerUid);
    _reviewsError = null;
    _reviewsLoading = ownerUid.isNotEmpty;
    if (ownerUid.isNotEmpty) {
      _startReviewsLoad(notify: false);
    }
  }

  void _startReviewsLoad({required bool notify}) {
    final ownerUid = _activeOwnerUid;
    if (ownerUid.isEmpty) {
      return;
    }

    final ownerEpoch = _activeOwnerEpoch;
    unawaited(_reviewsSubscription?.cancel());
    _reviewsSubscription = null;
    final requestGeneration = ++_requestGeneration;
    final cacheGeneration = MyRewModel.sessionCacheGeneration;
    _reviewsError = null;
    _reviewsLoading = true;
    if (notify && mounted) {
      setState(() {});
    }

    try {
      _reviewsSubscription = _loadReviews(ownerUid).listen(
        (result) {
          if (!_requestIsCurrent(
            ownerUid,
            ownerEpoch,
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
            setState(() {
              if (_lastSuccessfulReviews != null || mergedReviews.isNotEmpty) {
                _lastSuccessfulReviews = mergedReviews;
              }
              _reviewsError = null;
              _reviewsLoading = true;
            });
            return;
          }
          final stableReviews =
              List<ReviewsRecord>.unmodifiable(result.reviews);
          MyRewModel.cacheReviews(
            ownerUid,
            stableReviews,
            expectedGeneration: cacheGeneration,
          );
          setState(() {
            _lastSuccessfulReviews = stableReviews;
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
      if (_requestIsCurrent(ownerUid, ownerEpoch, requestGeneration) &&
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
    int requestGeneration,
  ) {
    return mounted &&
        ownerUid == _activeOwnerUid &&
        ownerEpoch == _activeOwnerEpoch &&
        ownerEpoch == _latestAuthSessionEpoch &&
        requestGeneration == _requestGeneration;
  }

  void _invalidateForAuthBoundaryMismatch() {
    if (!mounted) {
      return;
    }
    setState(() => _resetOwner('', _latestAuthSessionEpoch));
  }

  void _retryReviews() => _startReviewsLoad(notify: true);

  @override
  void dispose() {
    unawaited(_reviewsSubscription?.cancel());
    _requestGeneration += 1;
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_MyRewAuthEmission>(
      key: ObjectKey(_authSessionStream),
      stream: _authSessionStream,
      initialData: _initialAuthEmission(),
      builder: (context, authSnapshot) {
        final authEmission = _effectiveAuthEmission(authSnapshot.data!);
        _synchronizeOwner(
          _ownerUidForEmission(authEmission),
          authEmission.epoch,
        );
        final reviews = _lastSuccessfulReviews;
        if (reviews == null) {
          return _buildColdState(
            context,
            isError: _reviewsError != null,
          );
        }

        Widget content = _buildReviewsContent(context, reviews);
        content = UxRefreshingIndicatorOverlay(
          key: myRewRefreshingKey,
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
            key: myRewRefreshingIndicatorKey,
            semanticsLabel: null,
          ),
          semanticsLabel: FFLocalizations.of(context).getVariableText(
            ruText: 'Обновление моих отзывов',
            enText: 'Refreshing my reviews',
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
  }

  Widget _buildColdState(
    BuildContext context, {
    required bool isError,
  }) {
    final state = isError
        ? _buildErrorState(context, stateKey: myRewErrorKey)
        : Semantics(
            key: myRewLoadingKey,
            container: true,
            liveRegion: true,
            label: FFLocalizations.of(context).getVariableText(
              ruText: 'Загрузка моих отзывов',
              enText: 'Loading my reviews',
            ),
            child: const ExcludeSemantics(child: AppLoadingIndicator()),
          );
          return Scaffold(
            backgroundColor: ExpatlioDesign.background,
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
              'r4c8ksc9' /* Мои отзывы */,
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
        ruText: 'Повторить загрузку моих отзывов',
        enText: 'Retry loading my reviews',
      ),
      retryButtonKey: myRewRetryButtonKey,
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
                stateKey: myRewRefreshErrorKey,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReviewsContent(
    BuildContext context,
        List<ReviewsRecord> myRewReviewsRecordList,
  ) {

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
                SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                        FlutterFlowTheme.of(context).primary,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                          ExpatlioDesign.controlRadius),
                                    ),
                                    child: Align(
                                      alignment: AlignmentDirectional(0.0, 0.0),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          '15c59bwa' /* Все */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color: valueOrDefault<Color>(
                                                _model.rate == 0
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .primaryBackground
                                                    : FlutterFlowTheme.of(
                                                            context)
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
                                        FlutterFlowTheme.of(context).primary,
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
                                          FFLocalizations.of(context).getText(
                                            'q7mf0a7y' /* 5 */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color: valueOrDefault<Color>(
                                                  _model.rate == 5
                                                      ? FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground
                                                      : FlutterFlowTheme.of(
                                                              context)
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
                                        FlutterFlowTheme.of(context).primary,
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
                                          FFLocalizations.of(context).getText(
                                            'nq0k4jpp' /* 4 */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color: valueOrDefault<Color>(
                                                  _model.rate == 4
                                                      ? FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground
                                                      : FlutterFlowTheme.of(
                                                              context)
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
                                        FlutterFlowTheme.of(context).primary,
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
                                          FFLocalizations.of(context).getText(
                                            '4jivq2w2' /* 3 */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color: valueOrDefault<Color>(
                                                  _model.rate == 3
                                                      ? FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground
                                                      : FlutterFlowTheme.of(
                                                              context)
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
                                        FlutterFlowTheme.of(context).primary,
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
                                          FFLocalizations.of(context).getText(
                                            'ojmpi3dm' /* 2 */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color: valueOrDefault<Color>(
                                                  _model.rate == 2
                                                      ? FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground
                                                      : FlutterFlowTheme.of(
                                                              context)
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
                                        FlutterFlowTheme.of(context).primary,
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
                                          FFLocalizations.of(context).getText(
                                            'wn2mqzpv' /* 1 */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color: valueOrDefault<Color>(
                                                  _model.rate == 1
                                                      ? FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground
                                                      : FlutterFlowTheme.of(
                                                              context)
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
                                      ].divide(SizedBox(
                                          width: ExpatlioDesign.space4)),
                                    ),
                                  ),
                                ),
                              ]
                                  .divide(
                                      SizedBox(width: ExpatlioDesign.space8))
                                  .addToStart(
                                      SizedBox(width: ExpatlioDesign.space16))
                                  .addToEnd(
                                      SizedBox(width: ExpatlioDesign.space16)),
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
                            final rew = myRewReviewsRecordList
                                .where((e) => _model.rate == 0
                                    ? true
                                    : (_model.rate == e.rating))
                                .toList();
                            if (rew.isEmpty) {
                              return Center(
                            key: myRewEmptyKey,
                                child: EmptyWidget(
                                  txt:
                                      'В этом разделе будут появляться отзывы, которые вы оставляете после занятий. Напишите первый отзыв после звонка, и он отобразится здесь.',
                                ),
                              );
                            }

                            return ListView.separated(
                          key: myRewListKey,
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
                                    key: myRewReviewKey(rewItem),
                                    rewDoc: rewItem,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ]
                        .addToStart(SizedBox(height: ExpatlioDesign.space112))
                        .addToEnd(SizedBox(height: ExpatlioDesign.space32)),
                  ),
                ),
                BasicPageHeader(
                  title: FFLocalizations.of(context).getText(
                    'r4c8ksc9' /* Мои отзывы */,
                  ),
                ),
              ],
            ),
          ),
        );
      }
  }

Stream<String> _watchMyRewOwnerUids() => FirebaseAuth.instance
    .authStateChanges()
    .map((user) => user?.uid.trim() ?? '');
