import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/app_loading_indicator.dart';
import '/components/call_history_card.dart';
import '/components/empty/empty_widget.dart';
import '/components/ux_error_state.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/user_match_profile.dart';
import '/services/call_history_repository.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'my_calls_model.dart';
export 'my_calls_model.dart';

const ValueKey<String> myCallsLoadingKey = ValueKey<String>('my_calls_loading');
const ValueKey<String> myCallsEmptyKey = ValueKey<String>('my_calls_empty');
const ValueKey<String> myCallsErrorKey = ValueKey<String>('my_calls_error');
const ValueKey<String> myCallsErrorRetryButtonKey =
    ValueKey<String>('my_calls_error_retry_button');
const ValueKey<String> myCallsListKey = ValueKey<String>('my_calls_list');
const ValueKey<String> myCallsRefreshButtonKey =
    ValueKey<String>('my_calls_refresh_button');
const ValueKey<String> myCallsRefreshingKey =
    ValueKey<String>('my_calls_refreshing');
const ValueKey<String> myCallsRefreshErrorKey =
    ValueKey<String>('my_calls_refresh_error');

typedef CallHistoryLoader = Future<List<VideoSessionsRecord>> Function(
  String userId,
);

final class _StaleCallHistoryRequest implements Exception {
  const _StaleCallHistoryRequest();
}

final class _CallHistoryAuthEmission {
  const _CallHistoryAuthEmission({
    required this.userId,
    required this.epoch,
  });

  final String userId;
  final int epoch;
}

class MyCallsWidget extends StatefulWidget {
  const MyCallsWidget({
    super.key,
    this.historyLoader,
    this.authUidStream,
    this.userIdProvider,
  });

  static String routeName = 'myCalls';
  static String routePath = '/myCalls';

  @visibleForTesting
  final CallHistoryLoader? historyLoader;
  @visibleForTesting
  final Stream<String>? authUidStream;
  @visibleForTesting
  final String Function()? userIdProvider;

  @override
  State<MyCallsWidget> createState() => _MyCallsWidgetState();
}

class _MyCallsWidgetState extends State<MyCallsWidget> {
  late MyCallsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  Future<List<VideoSessionsRecord>>? _historyFuture;
  List<VideoSessionsRecord> _lastLoadedSessions = const [];
  bool _hasAuthoritativeHistory = false;
  Object? _historyError;
  late Stream<_CallHistoryAuthEmission> _authSessionStream;
  String _latestAuthStreamUserId = '';
  int _latestAuthSessionEpoch = 0;
  String _historyOwnerUserId = '';
  int _historyOwnerEpoch = 0;
  int _historyRequestSerial = 0;

  bool get _isTeacher =>
      hasCurrentUserDocumentForUid(_historyOwnerUserId) &&
      canAccessTeacherSurfaces(currentUserDocument);

  @override
  void initState() {
    super.initState();
    _latestAuthStreamUserId = _initialHistoryOwnerUserId();
    _authSessionStream = _trackAuthSessions(
      widget.authUidStream ?? _watchAuthenticatedUserIds(),
    );
    _model = createModel(context, () => MyCallsModel());
  }

  @override
  void didUpdateWidget(covariant MyCallsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final authUidStreamChanged =
        oldWidget.authUidStream != widget.authUidStream;
    if (authUidStreamChanged) {
      _authSessionStream = _trackAuthSessions(
        widget.authUidStream ?? _watchAuthenticatedUserIds(),
      );
      _latestAuthStreamUserId = '';
      _resetHistoryStateForOwner('', _latestAuthSessionEpoch);
    } else if (oldWidget.historyLoader != widget.historyLoader) {
      _restartHistoryRequestPreservingData();
    }
  }

  @override
  void dispose() {
    _historyRequestSerial += 1;
    _model.dispose();
    super.dispose();
  }

  Widget _buildLoadingState(BuildContext context) {
    final label = FFLocalizations.of(context).getVariableText(
      ruText: 'Загрузка истории звонков',
      enText: 'Loading call history',
    );
    return Center(
      child: Semantics(
        key: myCallsLoadingKey,
        container: true,
        liveRegion: true,
        label: label,
        child: const ExcludeSemantics(
          child: AppLoadingIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final title = FFLocalizations.of(context).getVariableText(
      ruText: 'Не удалось загрузить историю звонков',
      enText: 'Unable to load call history',
    );
    final message = FFLocalizations.of(context).getVariableText(
      ruText: 'Проверьте подключение и попробуйте еще раз.',
      enText: 'Check your connection and try again.',
    );
    final retryLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Повторить',
      enText: 'Retry',
    );
    final retrySemanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Повторить загрузку истории звонков',
      enText: 'Retry loading call history',
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ExpatlioDesign.pagePadding),
        child: UxErrorState(
          stateKey: myCallsErrorKey,
          title: title,
          message: message,
          semanticsLabel: '$title. $message',
          retryLabel: retryLabel,
          retrySemanticsLabel: retrySemanticsLabel,
          retryButtonKey: myCallsErrorRetryButtonKey,
          onRetry: _reloadHistory,
          showIcon: false,
          maxWidth: double.infinity,
          padding: const EdgeInsetsDirectional.all(ExpatlioDesign.space24),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return BasicPageHeader(
      title: FFLocalizations.of(context).getVariableText(
        ruText: 'Мои звонки',
        enText: 'My calls',
      ),
      trailing: SizedBox.square(
        dimension: 44.0,
        child: IconButton(
          key: myCallsRefreshButtonKey,
          tooltip: FFLocalizations.of(context).getVariableText(
            ruText: 'Обновить',
            enText: 'Refresh',
          ),
          onPressed: _reloadHistory,
          icon: const Icon(
            Icons.refresh_rounded,
            color: ExpatlioDesign.text,
            size: 22.0,
          ),
        ),
      ),
    );
  }

  bool get _hasIndependentDirectAuthUid =>
      widget.userIdProvider != null || widget.authUidStream == null;

  String _directAuthUid() => (widget.userIdProvider?.call() ??
          FirebaseAuth.instance.currentUser?.uid ??
          '')
      .trim();

  String _initialHistoryOwnerUserId() =>
      widget.authUidStream == null && _hasIndependentDirectAuthUid
          ? _directAuthUid()
          : '';

  Stream<_CallHistoryAuthEmission> _trackAuthSessions(
    Stream<String> authUidStream,
  ) {
    return authUidStream.map((rawUserId) {
      final userId = rawUserId.trim();
      _latestAuthStreamUserId = userId;
      final epoch = ++_latestAuthSessionEpoch;
      return _CallHistoryAuthEmission(userId: userId, epoch: epoch);
    });
  }

  _CallHistoryAuthEmission _initialAuthEmission() => _CallHistoryAuthEmission(
        userId: _initialHistoryOwnerUserId(),
        epoch: _latestAuthSessionEpoch,
      );

  String _historyOwnerUserIdForEmission(
    _CallHistoryAuthEmission emission,
  ) {
    final streamOwnerUserId = emission.userId;
    if (!_hasIndependentDirectAuthUid) {
      return streamOwnerUserId;
    }
    final directOwnerUserId = _directAuthUid();
    return streamOwnerUserId == directOwnerUserId ? directOwnerUserId : '';
  }

  bool _authBoundaryMatches(String ownerUserId, int ownerEpoch) {
    if (ownerUserId.isEmpty ||
        _latestAuthStreamUserId != ownerUserId ||
        _latestAuthSessionEpoch != ownerEpoch) {
      return false;
    }
    return !_hasIndependentDirectAuthUid || _directAuthUid() == ownerUserId;
  }

  bool _requestIsCurrent(
    int requestId,
    String ownerUserId,
    int ownerEpoch,
  ) =>
      mounted &&
      requestId == _historyRequestSerial &&
      ownerUserId == _historyOwnerUserId &&
      ownerEpoch == _historyOwnerEpoch &&
      ownerEpoch == _latestAuthSessionEpoch;

  void _invalidateForAuthBoundaryMismatch() {
    if (!mounted) {
      return;
    }
    if (_historyOwnerUserId.isEmpty &&
        _historyFuture == null &&
        !_hasAuthoritativeHistory &&
        _historyError == null) {
      return;
    }
    setState(
      () => _resetHistoryStateForOwner('', _latestAuthSessionEpoch),
    );
  }

  bool _canOpenCallHistory(String ownerUserId, int ownerEpoch) {
    final canOpen = _historyOwnerUserId == ownerUserId &&
        _historyOwnerEpoch == ownerEpoch &&
        _authBoundaryMatches(ownerUserId, ownerEpoch);
    if (!canOpen) {
      _invalidateForAuthBoundaryMismatch();
    }
    return canOpen;
  }

  void _resetHistoryStateForOwner(String ownerUserId, int ownerEpoch) {
    _historyOwnerUserId = ownerUserId;
    _historyOwnerEpoch = ownerEpoch;
    _lastLoadedSessions = const [];
    _hasAuthoritativeHistory = false;
    _historyError = null;
    final requestId = ++_historyRequestSerial;
    _historyFuture = ownerUserId.isEmpty
        ? null
        : _loadCallHistory(requestId, ownerUserId, ownerEpoch);
  }

  void _syncHistoryOwner(String ownerUserId, int ownerEpoch) {
    if (ownerUserId == _historyOwnerUserId &&
        ownerEpoch == _historyOwnerEpoch) {
      return;
    }
    _resetHistoryStateForOwner(ownerUserId, ownerEpoch);
  }

  void _restartHistoryRequestPreservingData() {
    final ownerUserId = _historyOwnerUserId;
    final ownerEpoch = _historyOwnerEpoch;
    if (!_authBoundaryMatches(ownerUserId, ownerEpoch)) {
      _resetHistoryStateForOwner('', _latestAuthSessionEpoch);
      return;
    }
    _historyError = null;
    final requestId = ++_historyRequestSerial;
    _historyFuture = _loadCallHistory(requestId, ownerUserId, ownerEpoch);
  }

  void _reloadHistory() {
    final ownerUserId = _historyOwnerUserId;
    final ownerEpoch = _historyOwnerEpoch;
    if (!_authBoundaryMatches(ownerUserId, ownerEpoch)) {
      _invalidateForAuthBoundaryMismatch();
      return;
    }
    final requestId = ++_historyRequestSerial;
    setState(() {
      _historyError = null;
      _historyFuture = Future<List<VideoSessionsRecord>>.delayed(
        Duration.zero,
        () => _loadCallHistory(requestId, ownerUserId, ownerEpoch),
      );
    });
  }

  Future<List<VideoSessionsRecord>> _loadCallHistory(
    int requestId,
    String ownerUserId,
    int ownerEpoch,
  ) async {
    try {
      final sessions = await (widget.historyLoader?.call(ownerUserId) ??
          CallHistoryRepository.loadCallHistorySessions(
            userId: ownerUserId,
          ));
      if (!_requestIsCurrent(requestId, ownerUserId, ownerEpoch)) {
        throw const _StaleCallHistoryRequest();
      }
      if (!_authBoundaryMatches(ownerUserId, ownerEpoch)) {
        _invalidateForAuthBoundaryMismatch();
        throw const _StaleCallHistoryRequest();
      }
      _historyError = null;
      _lastLoadedSessions = List<VideoSessionsRecord>.unmodifiable(sessions);
      _hasAuthoritativeHistory = true;
      return sessions;
    } catch (error) {
      if (error is _StaleCallHistoryRequest) {
        rethrow;
      }
      if (!_requestIsCurrent(requestId, ownerUserId, ownerEpoch)) {
        throw const _StaleCallHistoryRequest();
      }
      if (!_authBoundaryMatches(ownerUserId, ownerEpoch)) {
        _invalidateForAuthBoundaryMismatch();
        throw const _StaleCallHistoryRequest();
      }
      _historyError = error;
      if (_hasAuthoritativeHistory) {
        return _lastLoadedSessions;
      }
      rethrow;
    }
  }

  Widget _buildHistoryContent(
    BuildContext context,
    List<VideoSessionsRecord> sessions,
    String historyOwnerUserId,
    int historyOwnerEpoch,
  ) {
    if (sessions.isEmpty) {
      return Center(
        key: myCallsEmptyKey,
        child: SizedBox(
          height: 500.0,
          child: EmptyWidget(
            txt: FFLocalizations.of(context).getVariableText(
              ruText:
                  'Здесь появится история ваших завершенных звонков. После первого разговора вы сможете быстро вернуться к нему из этого раздела.',
              enText:
                  'Your completed call history will appear here. After your first conversation, you will be able to return to it from this section.',
            ),
          ),
        ),
      );
    }

    final contentTopPadding = MediaQuery.paddingOf(context).top +
        BasicPageHeader.height +
        ExpatlioDesign.sectionSpacing;
    return ListView.separated(
      key: myCallsListKey,
      padding: EdgeInsets.fromLTRB(
        ExpatlioDesign.space0,
        contentTopPadding,
        ExpatlioDesign.space0,
        ExpatlioDesign.pageBottomSpacing,
      ),
      itemCount: sessions.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: ExpatlioDesign.space0),
      itemBuilder: (context, index) {
        return CallHistoryCard(
          key: ValueKey<String>(sessions[index].reference.path),
          session: sessions[index],
          isTeacher: _isTeacher,
          canOpen: () => _canOpenCallHistory(
            historyOwnerUserId,
            historyOwnerEpoch,
          ),
        );
      },
    );
  }

  Widget _buildRefreshingHistory(
    BuildContext context,
    Widget content,
  ) {
    final label = FFLocalizations.of(context).getVariableText(
      ruText: 'Обновление истории звонков',
      enText: 'Refreshing call history',
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        PositionedDirectional(
          start: ExpatlioDesign.space0,
          end: ExpatlioDesign.space0,
          top: MediaQuery.paddingOf(context).top + BasicPageHeader.height,
          child: Semantics(
            key: myCallsRefreshingKey,
            container: true,
            liveRegion: true,
            label: label,
            child: const ExcludeSemantics(
              child: LinearProgressIndicator(
                minHeight: 2.0,
                color: ExpatlioDesign.primary,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryWithRefreshError(
    BuildContext context,
    Widget content,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        PositionedDirectional(
          start: ExpatlioDesign.space0,
          end: ExpatlioDesign.space0,
          bottom:
              MediaQuery.viewPaddingOf(context).bottom + ExpatlioDesign.space16,
          child: Material(
            color: Colors.transparent,
            elevation: 4.0,
            borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
            child: _MyCallsRefreshErrorState(onRetry: _reloadHistory),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryBody(BuildContext context) {
    final historyFuture = _historyFuture;
    final historyOwnerUserId = _historyOwnerUserId;
    final historyOwnerEpoch = _historyOwnerEpoch;
    if (historyFuture == null) {
      return _buildLoadingState(context);
    }

    return FutureBuilder<List<VideoSessionsRecord>>(
      key: ObjectKey(historyFuture),
      future: historyFuture,
      builder: (context, snapshot) {
        if (snapshot.error is _StaleCallHistoryRequest) {
          return _buildLoadingState(context);
        }
        if (snapshot.hasError) {
          if (_hasAuthoritativeHistory) {
            return _buildHistoryWithRefreshError(
              context,
              _buildHistoryContent(
                context,
                _lastLoadedSessions,
                historyOwnerUserId,
                historyOwnerEpoch,
              ),
            );
          }
          return _buildErrorState(context);
        }

        if (snapshot.connectionState != ConnectionState.done ||
            !snapshot.hasData) {
          if (_hasAuthoritativeHistory) {
            return _buildRefreshingHistory(
              context,
              _buildHistoryContent(
                context,
                _lastLoadedSessions,
                historyOwnerUserId,
                historyOwnerEpoch,
              ),
            );
          }
          return _buildLoadingState(context);
        }

        final sessions = snapshot.data!;
        final content = _buildHistoryContent(
          context,
          sessions,
          historyOwnerUserId,
          historyOwnerEpoch,
        );
        return _historyError == null
            ? content
            : _buildHistoryWithRefreshError(context, content);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: ExpatlioDesign.background,
        body: StreamBuilder<_CallHistoryAuthEmission>(
          key: ObjectKey(_authSessionStream),
          stream: _authSessionStream,
          initialData: _initialAuthEmission(),
          builder: (context, authSessionSnapshot) {
            final authEmission = authSessionSnapshot.data!;
            final ownerUserId = _historyOwnerUserIdForEmission(authEmission);
            _syncHistoryOwner(ownerUserId, authEmission.epoch);
            return AuthUserStreamWidget(
              builder: (context) {
                return Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        ExpatlioDesign.pagePadding,
                        ExpatlioDesign.space0,
                        ExpatlioDesign.pagePadding,
                        ExpatlioDesign.space0,
                      ),
                      child: _buildHistoryBody(context),
                    ),
                    _buildHeader(context),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MyCallsRefreshErrorState extends StatelessWidget {
  const _MyCallsRefreshErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final title = FFLocalizations.of(context).getVariableText(
      ruText: 'Не удалось обновить историю звонков',
      enText: 'Unable to refresh call history',
    );
    final retryLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Повторить',
      enText: 'Retry',
    );
    final retrySemanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Повторить обновление истории звонков',
      enText: 'Retry refreshing call history',
    );

    return Semantics(
      key: myCallsRefreshErrorKey,
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: title,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56.0),
        padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space12,
          ExpatlioDesign.space8,
          ExpatlioDesign.space8,
          ExpatlioDesign.space8,
        ),
        decoration: BoxDecoration(
          color: ExpatlioDesign.card,
          borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
          border: Border.all(color: ExpatlioDesign.danger),
        ),
        child: Row(
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ExpatlioDesign.textStyle(
                    context,
                    size: 14.0,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: ExpatlioDesign.space8),
            Semantics(
              button: true,
              label: retrySemanticsLabel,
              onTap: onRetry,
              excludeSemantics: true,
              child: TextButton(
                key: myCallsErrorRetryButtonKey,
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Stream<String> _watchAuthenticatedUserIds() =>
    FirebaseAuth.instance.authStateChanges().map(
          (user) => user?.uid.trim() ?? '',
        );
