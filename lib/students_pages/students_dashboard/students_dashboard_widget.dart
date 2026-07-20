import '/auth/firebase_auth/auth_util.dart';
import '/components/celebration_s_t_widget.dart';
import '/components/celebration_top_up_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/dashboard_inline_filter_button.dart';
import '/components/orbiting_avatars_cta.dart';
import '/components/profile_dropdown_menu_item.dart';
import '/components/student_start_search_button.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/permissions_util.dart';
import '/services/user_match_profile.dart';
import '/services/active_search_recovery.dart';
import '/services/nearby_partner_count_cache.dart';
import '/services/nearby_partner_preview_cache.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/components/no_balance_widget.dart';
import '/components/promo_redeem_widget.dart';
import '/components/fav_widget.dart';
// ─── SUBSCRIPTION REWORK ─ subscription state helpers. Replaces gating by
// balanceST; call start uses canStartCall so promo gift minutes unlock access.
import '/utils/subscription_utils.dart';
import '/index.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'students_dashboard_model.dart';
export 'students_dashboard_model.dart';

enum StudentDashboardSearchState {
  idle,
  searching,
  connecting,
  noMatchFound,
  error,
}

enum StudentDashboardSearchErrorReason {
  authRequired,
  activeCall,
  usageLimitReached,
  mediaPermissionDenied,
  searchUnavailable,
  activeSessionUnavailable,
}

typedef SearchRequestInvoker = Future<dynamic> Function(
  Map<String, dynamic> payload,
);
typedef PartnerCountLoader = Future<int?> Function({
  required CountryStruct? preferredLocation,
  required Level? preferredPartnerLevel,
});
typedef PartnerPreviewLoader = Future<List<NearbyPartnerPreviewEntry>?>
    Function({
  required CountryStruct? preferredLocation,
  required Level? preferredPartnerLevel,
});
typedef StudentCallNavigator = FutureOr<void> Function(
  BuildContext context,
  DocumentReference videoDocRef, {
  String? roomUrl,
  String? meetingToken,
  String? roomName,
});

class StudentsDashboardWidget extends StatefulWidget {
  const StudentsDashboardWidget({
    super.key,
    bool? zn,
    this.done,
    bool? topUpSuccess,
    this.initialSearchState = StudentDashboardSearchState.idle,
    this.activeSessionStream,
    this.usageLimitReachedChecker,
    this.startSearchRequest,
    this.heartbeatSearchRequest,
    this.stopSearchRequest,
    this.activeSearchRecoveryReader,
    this.partnerCountLoader,
    this.partnerPreviewLoader,
  })  : this.zn = zn ?? false,
        this.topUpSuccess = topUpSuccess ?? false;

  final bool zn;
  final bool? done;
  final bool topUpSuccess;
  final StudentDashboardSearchState initialSearchState;
  final Stream<VideoSessionsRecord?>? activeSessionStream;
  final Future<bool> Function(UsersRecord user)? usageLimitReachedChecker;
  final SearchRequestInvoker? startSearchRequest;
  final SearchRequestInvoker? heartbeatSearchRequest;
  final Future<dynamic> Function(String? activeSessionId)? stopSearchRequest;
  final Future<ActiveSearchRecoveryState> Function(String userId)?
      activeSearchRecoveryReader;
  final PartnerCountLoader? partnerCountLoader;
  final PartnerPreviewLoader? partnerPreviewLoader;

  static Future<bool> Function(UsersRecord user)? debugUsageLimitReachedChecker;
  static Future<VideoSessionsRecord?> Function(DocumentReference sessionRef)?
      debugActiveSessionReader;
  static SearchRequestInvoker? debugStartSearchRequest;
  static SearchRequestInvoker? debugHeartbeatSearchRequest;
  static Future<dynamic> Function(String? activeSessionId)?
      debugStopSearchRequest;
  static Future<ActiveSearchRecoveryState> Function(String userId)?
      debugActiveSearchRecoveryReader;
  static void Function(Map<String, dynamic> payload)?
      debugStopSearchPayloadObserver;
  static Future<dynamic> Function(String sessionId)? debugAcceptCallRequest;
  static Future<dynamic> Function(String sessionId)?
      debugGetSessionTokensRequest;
  static StudentCallNavigator? debugAutoOpenSessionNavigator;
  static bool debugDisableAutoOpenSessionNavigation = false;
  static const Duration startSearchRequestTimeout = Duration(seconds: 25);
  static const Duration heartbeatSearchInterval = Duration(seconds: 30);
  static const Duration heartbeatSearchRequestTimeout = Duration(seconds: 10);
  static const Duration stopSearchRequestTimeout = Duration(seconds: 10);
  static const Duration acceptCallRequestTimeout = Duration(seconds: 20);
  static const Duration activeSearchRecoveryRetryDelay = Duration(seconds: 2);
  static const int activeSearchRecoveryMaxAttemptsAfterFailure = 3;

  static String routeName = 'Students_Dashboard';
  static String routePath = '/studentsDashboard';

  @override
  State<StudentsDashboardWidget> createState() =>
      _StudentsDashboardWidgetState();
}

class _StudentsDashboardWidgetState extends State<StudentsDashboardWidget>
    with WidgetsBindingObserver {
  late StudentsDashboardModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late final NearbyPartnerCountCache _partnerCountCache;
  late final NearbyPartnerPreviewCache _partnerPreviewCache;
  final Map<String, int> _partnerCountMemoryCache = <String, int>{};
  final Set<String> _partnerCountRefreshesStarted = <String>{};
  String? _activePartnerCountCacheKey;
  String? _partnerPreviewCacheKey;
  Future<List<OrbitingAvatarData>>? _partnerPreviewFuture;
  List<OrbitingAvatarData>? _partnerPreviewInitialData;
  bool _isLocationMenuOpen = false;
  bool _isLevelMenuOpen = false;
  StudentDashboardSearchState _searchState = StudentDashboardSearchState.idle;
  bool _isStartingSearch = false;
  bool _ignoreStartSearchUntilNextFrame = false;
  bool _ignoreStopSearchUntilNextFrame = false;
  bool _startSearchAfterStop = false;
  bool _queuedStartHasActiveCallSession = false;
  bool _stopFailureSinceLastDrain = false;
  bool _stopSearchWhenStartCompletes = false;
  final Set<String> _stoppingSearchKeys = <String>{};
  String? _suppressedActiveSessionId;
  String? _suppressedActiveSearchUserId;
  String? _lastActiveSessionId;
  Timer? _searchTimeoutTimer;
  Timer? _searchHeartbeatTimer;
  Timer? _activeSearchRecoveryRetryTimer;
  String? _activeSearchRequestId;
  String? _matchedSearchSessionId;
  String? _recoveredConnectionSessionId;
  String? _activeSearchRecoveryAttemptedUserId;
  bool _activeSearchRecoveryInFlight = false;
  bool _searchHeartbeatInFlight = false;
  bool _pendingLifecycleSearchHeartbeat = false;
  String _searchAppState = 'foreground';
  String? _autoOpenedSessionId;
  final Set<String> _foregroundAcceptStartedSessionIds = <String>{};
  final Set<String> _autoOpenCredentialStartedSessionIds = <String>{};
  StudentDashboardSearchErrorReason? _searchErrorReason;
  StudentDashboardSearchState _lastActiveSessionSearchState =
      StudentDashboardSearchState.idle;

  static const int _subscriberDailySearchLimitSeconds = 60 * 60;
  static const int _subscriberWeeklySearchLimitSeconds = 8 * 60 * 60;

  bool get _showLegacyDashboard => false;
  bool _isStopSearchState(StudentDashboardSearchState searchState) =>
      searchState == StudentDashboardSearchState.searching ||
      searchState == StudentDashboardSearchState.connecting;

  bool _showsSearchStatus(StudentDashboardSearchState searchState) =>
      searchState != StudentDashboardSearchState.idle;

  String? _normalizedSessionId(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return null;
    }
    return normalizedSessionId;
  }

  String? _normalizedNonEmptyString(Object? value) {
    final normalizedValue = value?.toString().trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }
    return normalizedValue;
  }

  String? _stopSessionIdFor(String? visibleSessionId) {
    return _normalizedSessionId(visibleSessionId) ??
        _normalizedSessionId(currentUserDocument?.currentSessionId);
  }

  bool _isStopSearchResponseSuccess(
    dynamic data, {
    required bool hasExplicitSessionId,
  }) {
    if (data is! Map) {
      return false;
    }

    final status = data['status']?.toString();
    final reason = data['reason']?.toString();
    if (hasExplicitSessionId) {
      final cancelledSessionId = data['cancelledSessionId']?.toString().trim();
      if (cancelledSessionId != null && cancelledSessionId.isNotEmpty) {
        return true;
      }

      final videoSession = data['videoSession'];
      if (videoSession is Map) {
        final videoSessionStatus = videoSession['status']?.toString();
        final videoSessionReason = videoSession['reason']?.toString();
        if (videoSession['stopped'] == true ||
            videoSessionStatus == 'cancelled') {
          return true;
        }
        if (videoSessionStatus == 'noop') {
          return videoSessionReason == 'session_not_found' ||
              videoSessionReason == 'session_already_inactive';
        }
      }

      return false;
    }

    if (data['stopped'] == true ||
        status == 'stopped' ||
        status == 'cancelled') {
      return true;
    }

    if (status == 'noop') {
      return reason == 'not_found' ||
          reason == 'already_inactive' ||
          reason == 'session_not_found' ||
          reason == 'session_already_inactive';
    }

    return false;
  }

  String _stopSearchKeyFor(String? activeSessionId) {
    final sessionId = _normalizedSessionId(activeSessionId);
    if (sessionId != null) {
      return 'session:$sessionId';
    }

    final userId = currentUserUid.trim();
    if (userId.isNotEmpty) {
      return 'user:$userId';
    }

    return 'user:unknown';
  }

  String? _currentSearchUserId() {
    final userId = currentUserUid.trim();
    if (userId.isEmpty) {
      return null;
    }
    return userId;
  }

  bool _isActiveSessionSuppressed(String? sessionId) {
    final normalizedSessionId = _normalizedSessionId(sessionId);
    if (normalizedSessionId != null &&
        normalizedSessionId == _suppressedActiveSessionId) {
      return true;
    }

    final userId = _currentSearchUserId();
    return userId != null && userId == _suppressedActiveSearchUserId;
  }

  void _queueStartSearchAfterStop({
    required bool hasActiveCallSession,
  }) {
    _startSearchAfterStop = true;
    _queuedStartHasActiveCallSession = hasActiveCallSession;
  }

  void _clearQueuedStartSearchAfterStop() {
    _startSearchAfterStop = false;
    _queuedStartHasActiveCallSession = false;
  }

  void _handleStopSearchFinished({required bool succeeded}) {
    if (!succeeded) {
      _stopFailureSinceLastDrain = true;
    }

    if (_stoppingSearchKeys.isNotEmpty) {
      return;
    }

    final hadStopFailure = _stopFailureSinceLastDrain;
    final shouldStartSearch = _startSearchAfterStop && !hadStopFailure;
    final hasActiveCallSession = _queuedStartHasActiveCallSession;
    _clearQueuedStartSearchAfterStop();
    _stopFailureSinceLastDrain = false;
    if (hadStopFailure) {
      _suppressedActiveSessionId = null;
    }
    _suppressedActiveSearchUserId = null;
    _ignoreStartSearchUntilNextFrame = false;

    if (!mounted) {
      return;
    }

    safeSetState(() {});

    if (!shouldStartSearch) {
      return;
    }

    unawaited(
      _handleStartConversation(
        StudentDashboardSearchState.idle,
        null,
        hasActiveCallSession,
      ),
    );
  }

  bool _canSurfaceActiveSessionError(String expectedSessionId) =>
      expectedSessionId.isNotEmpty &&
      !_isActiveSessionSuppressed(expectedSessionId) &&
      _searchState == StudentDashboardSearchState.idle &&
      (_lastActiveSessionId != expectedSessionId ||
          _lastActiveSessionSearchState == StudentDashboardSearchState.idle);

  void _clearSearchTimeoutTimer() {
    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = null;
  }

  void _clearSearchHeartbeatTimer() {
    _searchHeartbeatTimer?.cancel();
    _searchHeartbeatTimer = null;
    _activeSearchRequestId = null;
    _searchHeartbeatInFlight = false;
    _pendingLifecycleSearchHeartbeat = false;
  }

  void _clearActiveSearchRecoveryRetryTimer() {
    _activeSearchRecoveryRetryTimer?.cancel();
    _activeSearchRecoveryRetryTimer = null;
  }

  void _setSearchError(StudentDashboardSearchErrorReason reason) {
    _clearSearchTimeoutTimer();
    _clearSearchHeartbeatTimer();
    safeSetState(() {
      _searchState = StudentDashboardSearchState.error;
      _searchErrorReason = reason;
      _matchedSearchSessionId = null;
      _suppressedActiveSessionId = null;
      _suppressedActiveSearchUserId = null;
    });
  }

  void _startSearchTimeoutTimer([
    Duration duration = const Duration(minutes: 10),
    String? activeSearchRequestId,
  ]) {
    _clearSearchTimeoutTimer();
    if (duration <= Duration.zero) {
      if (mounted && _searchState == StudentDashboardSearchState.searching) {
        final expiredRequestId =
            activeSearchRequestId ?? _activeSearchRequestId;
        _clearSearchHeartbeatTimer();
        safeSetState(() {
          _searchState = StudentDashboardSearchState.noMatchFound;
          _matchedSearchSessionId = null;
        });
        unawaited(_stopActiveSearchRequest(
          null,
          activeSearchRequestId: expiredRequestId,
        ));
      }
      return;
    }
    _searchTimeoutTimer = Timer(duration, () {
      if (!mounted || _searchState != StudentDashboardSearchState.searching) {
        return;
      }

      final expiredRequestId = activeSearchRequestId ?? _activeSearchRequestId;
      _clearSearchHeartbeatTimer();
      safeSetState(() {
        _searchState = StudentDashboardSearchState.noMatchFound;
        _matchedSearchSessionId = null;
      });
      unawaited(_stopActiveSearchRequest(
        null,
        activeSearchRequestId: expiredRequestId,
      ));
    });
  }

  Map<String, dynamic> _normalizeCallableMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  String? _normalizedResponseString(Map<String, dynamic> data, String key) {
    final value = data[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool _responseBool(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.trim().toLowerCase() == 'true';
    }
    return false;
  }

  void _handleSearchHeartbeatResponse(
    String requestId,
    Map<String, dynamic> data,
  ) {
    if (_activeSearchRequestId != requestId ||
        _searchState != StudentDashboardSearchState.searching) {
      return;
    }

    final errorCode = _normalizedResponseString(data, 'errorCode');
    final reason = _normalizedResponseString(data, 'reason');
    final expiredReasons = <String>{
      'background_expired',
      'expired',
      'stale',
    };
    final inactiveReasons = <String>{
      'background_expired',
      'expired',
      'inactive',
      'not_found',
      'request_id_required',
      'request_mismatch',
      'stale',
    };
    if (!inactiveReasons.contains(errorCode) &&
        !inactiveReasons.contains(reason)) {
      return;
    }

    _clearSearchTimeoutTimer();
    _clearSearchHeartbeatTimer();
    if (!mounted) {
      return;
    }

    safeSetState(() {
      _searchState =
          expiredReasons.contains(errorCode) || expiredReasons.contains(reason)
              ? StudentDashboardSearchState.idle
              : StudentDashboardSearchState.noMatchFound;
      _matchedSearchSessionId = null;
    });
  }

  Map<String, dynamic> _buildStartSearchPayload(UsersRecord user) {
    final payload = <String, dynamic>{
      'appState': _searchAppState,
    };
    final language = resolveUserActiveConversationLanguage(user);
    if (language != null && language.trim().isNotEmpty) {
      payload['language'] = language.trim();
    }
    final preferredPartnerLevel = user.preferences.preferredPartnerLevel;
    if (preferredPartnerLevel != null) {
      payload['preferredPartnerLevel'] = _levelShortLabel(
        preferredPartnerLevel,
      );
    }
    final preferredLocation = _preferredLocation(user);
    final countryCode = preferredLocation?.code.trim();
    if (countryCode != null && countryCode.isNotEmpty) {
      payload['countryCode'] = countryCode;
    }
    return payload;
  }

  Future<Map<String, dynamic>> _startActiveSearchRequest(
    UsersRecord user,
  ) async {
    final payload = _buildStartSearchPayload(user);
    final startSearchRequest = widget.startSearchRequest ??
        StudentsDashboardWidget.debugStartSearchRequest;
    if (startSearchRequest != null) {
      return _normalizeCallableMap(
        await startSearchRequest(
          payload,
        ).timeout(StudentsDashboardWidget.startSearchRequestTimeout),
      );
    }

    final response = await FirebaseFunctions.instance
        .httpsCallable('startSearch')
        .call(payload)
        .timeout(StudentsDashboardWidget.startSearchRequestTimeout);
    return _normalizeCallableMap(response.data);
  }

  Future<ActiveSearchRecoveryState> _readDashboardActiveSearchRecoveryState(
    String userId,
  ) {
    final reader = widget.activeSearchRecoveryReader ??
        StudentsDashboardWidget.debugActiveSearchRecoveryReader;
    if (reader != null) {
      return reader(userId);
    }
    return readActiveSearchRecoveryState(userId);
  }

  void _maybeRecoverActiveSearchForUser(UsersRecord user) {
    final userId = _currentSearchUserId();
    if (userId == null ||
        _activeSearchRecoveryInFlight ||
        _activeSearchRecoveryAttemptedUserId == userId ||
        _searchState != StudentDashboardSearchState.idle ||
        user.isInCall ||
        _normalizedSessionId(user.currentSessionId) != null ||
        _suppressedActiveSearchUserId == userId) {
      return;
    }

    _activeSearchRecoveryAttemptedUserId = userId;
    _activeSearchRecoveryInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _activeSearchRecoveryInFlight = false;
        return;
      }
      unawaited(_recoverActiveSearchForUser(userId));
    });
  }

  void _scheduleActiveSearchRecoveryRetry(String userId) {
    _clearActiveSearchRecoveryRetryTimer();
    _activeSearchRecoveryRetryTimer = Timer(
      StudentsDashboardWidget.activeSearchRecoveryRetryDelay,
      () {
        _activeSearchRecoveryRetryTimer = null;
        if (!mounted ||
            _currentSearchUserId() != userId ||
            _searchState != StudentDashboardSearchState.idle) {
          return;
        }
        if (_activeSearchRecoveryAttemptedUserId == userId) {
          _activeSearchRecoveryAttemptedUserId = null;
        }
        safeSetState(() {});
      },
    );
  }

  Future<void> _recoverActiveSearchForUser(String userId) async {
    try {
      final state = await _readDashboardActiveSearchRecoveryState(userId);
      if (!mounted ||
          _currentSearchUserId() != userId ||
          _searchState != StudentDashboardSearchState.idle ||
          _suppressedActiveSearchUserId == userId) {
        return;
      }

      if (state.canResumeConnection) {
        final sessionId = _normalizedSessionId(state.sessionId);
        if (sessionId == null) {
          return;
        }
        final canRestoreConnection =
            await _canRestoreRecoveredConnectionSession(
          sessionId: sessionId,
          userId: userId,
        );
        if (!canRestoreConnection ||
            !mounted ||
            _currentSearchUserId() != userId ||
            _searchState != StudentDashboardSearchState.idle ||
            _suppressedActiveSearchUserId == userId) {
          return;
        }

        _clearActiveSearchRecoveryRetryTimer();
        _clearSearchTimeoutTimer();
        _clearSearchHeartbeatTimer();
        safeSetState(() {
          _searchState = StudentDashboardSearchState.connecting;
          _searchErrorReason = null;
          _matchedSearchSessionId = sessionId;
          _recoveredConnectionSessionId = sessionId;
          _suppressedActiveSessionId = null;
          _suppressedActiveSearchUserId = null;
          _isStartingSearch = false;
        });
        return;
      }

      if (state.canResumeUnboundSearch) {
        _resumeRecoveredUnboundSearch(state);
      }
      return;
    } catch (error, stackTrace) {
      if (error is FirebaseException && error.code == 'permission-denied') {
        debugPrint(
          'StudentsDashboard: active search recovery denied by Firestore rules '
          'for $userId: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        return;
      }

      _scheduleActiveSearchRecoveryRetry(userId);
      debugPrint(
        'StudentsDashboard: failed to recover active search: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _activeSearchRecoveryInFlight = false;
    }
  }

  void _resumeRecoveredUnboundSearch(ActiveSearchRecoveryState state) {
    final requestId = state.requestId;
    if (requestId == null) {
      return;
    }

    final remainingSearchDuration = state.remainingSearchDuration();
    _clearActiveSearchRecoveryRetryTimer();
    _clearSearchTimeoutTimer();
    _clearSearchHeartbeatTimer();
    safeSetState(() {
      _searchState = StudentDashboardSearchState.searching;
      _searchErrorReason = null;
      _matchedSearchSessionId = null;
      _recoveredConnectionSessionId = null;
      _suppressedActiveSessionId = null;
      _suppressedActiveSearchUserId = null;
      _isStartingSearch = false;
    });
    if (remainingSearchDuration <= Duration.zero) {
      _startSearchTimeoutTimer(remainingSearchDuration, requestId);
      return;
    }
    _startSearchTimeoutTimer(remainingSearchDuration);
    _startSearchHeartbeatTimer(requestId);
    unawaited(_sendSearchHeartbeat(requestId));
  }

  Future<bool> _recoverStartSearchRequestAfterFailure() async {
    final userId = _currentSearchUserId();
    if (userId == null || !mounted) {
      return false;
    }

    for (var attempt = 0;
        attempt <
            StudentsDashboardWidget.activeSearchRecoveryMaxAttemptsAfterFailure;
        attempt += 1) {
      if (attempt > 0) {
        await Future<void>.delayed(
          StudentsDashboardWidget.activeSearchRecoveryRetryDelay,
        );
      }
      if (!mounted || _currentSearchUserId() != userId) {
        return false;
      }

      try {
        final state = await _readDashboardActiveSearchRecoveryState(userId);
        if (!mounted || _currentSearchUserId() != userId) {
          return false;
        }
        if (!state.canResumeUnboundSearch) {
          continue;
        }

        _resumeRecoveredUnboundSearch(state);
        return true;
      } catch (error, stackTrace) {
        debugPrint(
          'StudentsDashboard: failed to recover search after start failure: '
          '$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return false;
  }

  Future<bool> _canRestoreRecoveredConnectionSession({
    required String sessionId,
    required String userId,
  }) async {
    try {
      final session = await _readActiveSessionOnce(sessionId);
      if (session == null) {
        return true;
      }
      return !_isTerminalSessionStatus(session.status) &&
          _sessionHasParticipant(session, userId);
    } catch (error) {
      debugPrint(
        'StudentsDashboard: failed to check recovered connection session '
        '$sessionId: $error',
      );
      return false;
    }
  }

  bool _sessionHasParticipant(VideoSessionsRecord session, String userId) {
    final normalizedUserId = _normalizedNonEmptyString(userId);
    if (normalizedUserId == null) {
      return false;
    }

    if (session.participantIds.any(
      (participantId) =>
          _normalizedNonEmptyString(participantId) == normalizedUserId,
    )) {
      return true;
    }

    return _sessionRequesterId(session) == normalizedUserId ||
        _sessionResponderId(session) == normalizedUserId ||
        _normalizedNonEmptyString(session.tutorId) == normalizedUserId;
  }

  Future<Map<String, dynamic>> _acceptForegroundSessionRequest(
    String sessionId,
  ) async {
    final acceptCallRequest = StudentsDashboardWidget.debugAcceptCallRequest;
    if (acceptCallRequest != null) {
      return _normalizeCallableMap(
        await acceptCallRequest(
          sessionId,
        ).timeout(StudentsDashboardWidget.acceptCallRequestTimeout),
      );
    }

    final response = await FirebaseFunctions.instance
        .httpsCallable('acceptCall')
        .call({'sessionId': sessionId}).timeout(
      StudentsDashboardWidget.acceptCallRequestTimeout,
    );
    return _normalizeCallableMap(response.data);
  }

  Future<Map<String, dynamic>> _getAutoOpenSessionTokens(
    String sessionId,
  ) async {
    final getSessionTokensRequest =
        StudentsDashboardWidget.debugGetSessionTokensRequest;
    if (getSessionTokensRequest != null) {
      return _normalizeCallableMap(
        await getSessionTokensRequest(
          sessionId,
        ).timeout(StudentsDashboardWidget.acceptCallRequestTimeout),
      );
    }

    final response = await FirebaseFunctions.instance
        .httpsCallable('getSessionTokens')
        .call({'sessionId': sessionId}).timeout(
      StudentsDashboardWidget.acceptCallRequestTimeout,
    );
    return _normalizeCallableMap(response.data);
  }

  void _startSearchHeartbeatTimer(String requestId) {
    _clearSearchHeartbeatTimer();
    _activeSearchRequestId = requestId;
    _searchHeartbeatTimer = Timer.periodic(
      StudentsDashboardWidget.heartbeatSearchInterval,
      (_) => unawaited(_sendSearchHeartbeat(requestId)),
    );
  }

  Future<void> _sendSearchHeartbeat(String requestId) async {
    if (_searchHeartbeatInFlight ||
        !mounted ||
        _activeSearchRequestId != requestId ||
        _searchState != StudentDashboardSearchState.searching) {
      return;
    }

    _searchHeartbeatInFlight = true;
    final payload = <String, dynamic>{
      'requestId': requestId,
      'appState': _searchAppState,
    };

    try {
      final heartbeatSearchRequest = widget.heartbeatSearchRequest ??
          StudentsDashboardWidget.debugHeartbeatSearchRequest;
      if (heartbeatSearchRequest != null) {
        final data = await heartbeatSearchRequest(
          payload,
        ).timeout(StudentsDashboardWidget.heartbeatSearchRequestTimeout);
        _handleSearchHeartbeatResponse(
          requestId,
          _normalizeCallableMap(data),
        );
        return;
      }

      final response = await FirebaseFunctions.instance
          .httpsCallable('heartbeatSearch')
          .call(payload)
          .timeout(StudentsDashboardWidget.heartbeatSearchRequestTimeout);
      _handleSearchHeartbeatResponse(
        requestId,
        _normalizeCallableMap(response.data),
      );
    } catch (error) {
      debugPrint('StudentsDashboard: failed to heartbeat search: $error');
    } finally {
      if (_activeSearchRequestId == requestId) {
        _searchHeartbeatInFlight = false;
        if (_pendingLifecycleSearchHeartbeat &&
            mounted &&
            _searchState == StudentDashboardSearchState.searching) {
          _pendingLifecycleSearchHeartbeat = false;
          unawaited(_sendSearchHeartbeat(requestId));
        }
      }
    }
  }

  String _searchAppStateForLifecycle(AppLifecycleState? state) {
    switch (state) {
      case null:
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        return 'foreground';
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        return 'background';
    }
  }

  void _sendLifecycleSearchHeartbeat() {
    final requestId = _activeSearchRequestId;
    if (requestId == null ||
        _searchState != StudentDashboardSearchState.searching) {
      return;
    }

    if (_searchHeartbeatInFlight) {
      _pendingLifecycleSearchHeartbeat = true;
      return;
    }

    unawaited(_sendSearchHeartbeat(requestId));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nextSearchAppState = _searchAppStateForLifecycle(state);
    if (_searchAppState == nextSearchAppState) {
      return;
    }

    _searchAppState = nextSearchAppState;
    _sendLifecycleSearchHeartbeat();
    if (mounted) {
      safeSetState(() {});
    }
  }

  Stream<VideoSessionsRecord?> _activeSessionStreamFor(UsersRecord user) {
    final override = widget.activeSessionStream;
    if (override != null) {
      return override;
    }

    final sessionId =
        _normalizedSessionId(user.currentSessionId) ?? _matchedSearchSessionId;
    if (sessionId == null) {
      return Stream<VideoSessionsRecord?>.value(null);
    }

    return VideoSessionsRecord.collection.doc(sessionId).snapshots().map(
      (snapshot) {
        if (!snapshot.exists) {
          return null;
        }
        return VideoSessionsRecord.fromSnapshot(snapshot);
      },
    );
  }

  StudentDashboardSearchState _searchStateForSession(
    VideoSessionsRecord? session,
  ) {
    switch (session?.status.trim()) {
      case 'searching':
        return StudentDashboardSearchState.searching;
      case 'no_tutors_available':
        return StudentDashboardSearchState.noMatchFound;
      case 'pending_confirmation':
      case 'connecting':
        return StudentDashboardSearchState.connecting;
      default:
        return StudentDashboardSearchState.idle;
    }
  }

  bool _isActiveCallSession(VideoSessionsRecord? session) {
    switch (session?.status.trim()) {
      case 'active':
      case 'connected':
        return true;
      default:
        return false;
    }
  }

  void _clearRecoveredActiveSessionError() {
    if (_searchState == StudentDashboardSearchState.error &&
        _searchErrorReason ==
            StudentDashboardSearchErrorReason.activeSessionUnavailable) {
      _searchState = StudentDashboardSearchState.idle;
      _searchErrorReason = null;
    }
  }

  bool _isRecoveredConnectionSession(String? sessionId) {
    final recoveredSessionId = _normalizedSessionId(
      _recoveredConnectionSessionId,
    );
    final normalizedSessionId = _normalizedSessionId(sessionId);
    return recoveredSessionId != null &&
        recoveredSessionId == normalizedSessionId;
  }

  bool _isTerminalSessionStatus(String? status) {
    switch (status?.trim()) {
      case 'cancelled':
      case 'ended':
      case 'expired':
      case 'failed':
      case 'completed':
      case 'no_tutors_available':
        return true;
      default:
        return false;
    }
  }

  void _clearRecoveredConnectionSession() {
    final recoveredSessionId = _recoveredConnectionSessionId;
    _recoveredConnectionSessionId = null;
    if (_matchedSearchSessionId == recoveredSessionId) {
      _matchedSearchSessionId = null;
    }
    if (_searchState == StudentDashboardSearchState.connecting) {
      _searchState = StudentDashboardSearchState.idle;
    }
  }

  void _rememberActiveSessionSnapshot(
    VideoSessionsRecord? session,
    String expectedSessionId,
  ) {
    _clearRecoveredActiveSessionError();
    final sessionSearchState = _searchStateForSession(session);
    final sessionId = session?.reference.id;
    if (expectedSessionId.isEmpty ||
        sessionId == null ||
        sessionId != expectedSessionId ||
        sessionSearchState == StudentDashboardSearchState.idle) {
      _lastActiveSessionSearchState = StudentDashboardSearchState.idle;
      _lastActiveSessionId = null;
      return;
    }

    _lastActiveSessionSearchState = sessionSearchState;
    _lastActiveSessionId = sessionId;
  }

  StudentDashboardSearchState? _cachedSearchStateForActiveSessionError(
    String expectedSessionId,
  ) {
    final cachedSessionId = _lastActiveSessionId;
    if (cachedSessionId == null ||
        expectedSessionId.isEmpty ||
        cachedSessionId != expectedSessionId ||
        _isActiveSessionSuppressed(cachedSessionId) ||
        _lastActiveSessionSearchState == StudentDashboardSearchState.idle ||
        (_searchState != StudentDashboardSearchState.idle &&
            _searchState != StudentDashboardSearchState.noMatchFound)) {
      return null;
    }

    return _lastActiveSessionSearchState;
  }

  StudentDashboardSearchState _effectiveSearchStateFor(
    VideoSessionsRecord? session, {
    bool activeSessionSnapshotSettled = false,
  }) {
    final sessionSearchState = _searchStateForSession(session);
    final sessionId = session?.reference.id;
    if (_isActiveCallSession(session)) {
      _clearSearchTimeoutTimer();
      _clearSearchHeartbeatTimer();
      _recoveredConnectionSessionId = null;
      if (_searchState == StudentDashboardSearchState.searching ||
          _searchState == StudentDashboardSearchState.connecting ||
          _searchState == StudentDashboardSearchState.noMatchFound) {
        _searchState = StudentDashboardSearchState.idle;
      }
      return _searchState;
    }
    if (_isRecoveredConnectionSession(_matchedSearchSessionId) &&
        activeSessionSnapshotSettled &&
        (session == null ||
            !session.hasStatus() ||
            _isTerminalSessionStatus(session.status) ||
            sessionSearchState == StudentDashboardSearchState.idle)) {
      _clearRecoveredConnectionSession();
      return _searchState;
    }

    if (sessionSearchState != StudentDashboardSearchState.idle &&
        sessionId != null &&
        !_isActiveSessionSuppressed(sessionId)) {
      if (sessionSearchState == StudentDashboardSearchState.searching &&
          _searchState == StudentDashboardSearchState.noMatchFound) {
        return _searchState;
      }

      final pairFound =
          sessionSearchState == StudentDashboardSearchState.connecting;
      final staleLocalResult =
          _searchState == StudentDashboardSearchState.searching ||
              _searchState == StudentDashboardSearchState.noMatchFound;
      if (pairFound && staleLocalResult) {
        _clearSearchTimeoutTimer();
        _clearSearchHeartbeatTimer();
        _searchState = StudentDashboardSearchState.idle;
      }
      if (sessionSearchState != StudentDashboardSearchState.searching) {
        _clearSearchHeartbeatTimer();
      }
      if (sessionId == _recoveredConnectionSessionId) {
        _recoveredConnectionSessionId = null;
      }
      return sessionSearchState;
    }

    return _searchState;
  }

  static const _searchAvatarMotion0 = OrbitingAvatarMotionSpec(
    radiusX: 122.0,
    radiusY: 88.0,
    phase: 3.85,
    speed: 1.0,
    drift: 0.16,
    scalePulse: 0.22,
  );
  static const _searchAvatarMotion1 = OrbitingAvatarMotionSpec(
    radiusX: 116.0,
    radiusY: 98.0,
    phase: 5.45,
    speed: -1.0,
    drift: 0.18,
    scalePulse: 0.24,
  );
  static const _searchAvatarMotion2 = OrbitingAvatarMotionSpec(
    radiusX: 142.0,
    radiusY: 86.0,
    phase: 0.14,
    speed: -2.0,
    drift: 0.14,
    scalePulse: 0.18,
  );
  static const _searchAvatarMotion3 = OrbitingAvatarMotionSpec(
    radiusX: 138.0,
    radiusY: 104.0,
    phase: 0.95,
    speed: 1.0,
    drift: 0.17,
    scalePulse: 0.22,
  );
  static const _searchAvatarMotion4 = OrbitingAvatarMotionSpec(
    radiusX: 118.0,
    radiusY: 110.0,
    phase: 2.15,
    speed: 2.0,
    drift: 0.15,
    scalePulse: 0.26,
  );
  static const _searchAvatarMotion5 = OrbitingAvatarMotionSpec(
    radiusX: 110.0,
    radiusY: 106.0,
    phase: 2.95,
    speed: -1.0,
    drift: 0.2,
    scalePulse: 0.24,
  );

  static const _searchAvatarMotions = <OrbitingAvatarMotionSpec>[
    _searchAvatarMotion0,
    _searchAvatarMotion1,
    _searchAvatarMotion2,
    _searchAvatarMotion3,
    _searchAvatarMotion4,
    _searchAvatarMotion5,
  ];

  static const _fallbackSearchAvatars = <OrbitingAvatarData>[
    OrbitingAvatarData(
      initials: 'AK',
      assetPath: 'assets/images/orbiting_avatar_1.jpg',
      size: 40.0,
      motion: _searchAvatarMotion0,
    ),
    OrbitingAvatarData(
      initials: 'MR',
      assetPath: 'assets/images/orbiting_avatar_2.jpg',
      size: 42.0,
      motion: _searchAvatarMotion1,
    ),
    OrbitingAvatarData(
      initials: 'JL',
      assetPath: 'assets/images/orbiting_avatar_3.jpg',
      size: 52.0,
      motion: _searchAvatarMotion2,
    ),
    OrbitingAvatarData(
      initials: 'EL',
      assetPath: 'assets/images/orbiting_avatar_4.jpg',
      size: 44.0,
      motion: _searchAvatarMotion3,
    ),
    OrbitingAvatarData(
      initials: 'KT',
      assetPath: 'assets/images/orbiting_avatar_5.jpg',
      size: 44.0,
      motion: _searchAvatarMotion4,
    ),
    OrbitingAvatarData(
      initials: 'ST',
      assetPath: 'assets/images/orbiting_avatar_6.jpg',
      size: 48.0,
      motion: _searchAvatarMotion5,
    ),
  ];

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 50.0,
        height: 50.0,
        child: SpinKitCircle(
          color: FlutterFlowTheme.of(context).secondary,
          size: 50.0,
        ),
      ),
    );
  }

  // ─── SUBSCRIPTION REWORK ─ legacy balanceST formatters removed; the
  // dashboard now reads subscription state via subscription_utils.dart. If
  // you need numeric formatting again, prefer `formatNumber` inline.

  Map<String, dynamic> _buildTimezoneMetadataUpdate() {
    final now = DateTime.now();
    return {
      'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
      'timezoneName': now.timeZoneName,
      'timezoneUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _syncTimezoneMetadata() async {
    final userRef = currentUserReference;
    if (userRef == null) {
      return;
    }

    try {
      await userRef.update(_studentUserUpdate(_buildTimezoneMetadataUpdate()));
    } catch (error) {
      debugPrint('StudentsDashboard: failed to sync timezone metadata: $error');
    }
  }

  Map<String, dynamic> _studentUserUpdate(Map<String, dynamic> data) {
    return {
      ...data,
      'availabilityToday': FieldValue.delete(),
    };
  }

  String _localizedText({
    required BuildContext context,
    required String ruText,
    required String enText,
  }) {
    return FFLocalizations.of(context).getVariableText(
      ruText: ruText,
      enText: enText,
    );
  }

  bool _hasCountryData(CountryStruct? country) {
    if (country == null) {
      return false;
    }

    return country.code.trim().isNotEmpty;
  }

  CountryStruct? _preferredLocation(UsersRecord? user) {
    if (user == null || !user.preferences.hasPreferredLocation()) {
      return null;
    }

    final preferredLocation = user.preferences.preferredLocation;
    return _hasCountryData(preferredLocation) ? preferredLocation : null;
  }

  String _preferredLocationLabel(BuildContext context, CountryStruct? country) {
    if (!_hasCountryData(country)) {
      return _localizedText(
        context: context,
        ruText: 'Любая',
        enText: 'Any',
      );
    }

    final isRu = FFLocalizations.of(context).languageCode == 'ru';
    final localizedName = isRu ? country!.nameRu : country!.nameEn;
    if (localizedName.trim().isNotEmpty) {
      return localizedName;
    }

    final fallbackName = isRu ? country.nameEn : country.nameRu;
    if (fallbackName.trim().isNotEmpty) {
      return fallbackName;
    }

    return country.code.toUpperCase();
  }

  String _levelShortLabel(Level level) {
    switch (level) {
      case Level.Beginner:
        return 'A1';
      case Level.Basic:
        return 'A2';
      case Level.Intermediate:
        return 'B1';
      case Level.Fluent:
        return 'C1';
    }
  }

  String _levelFilterLabel(BuildContext context, Level level) {
    final levelCode = _levelShortLabel(level);
    return _localizedText(
      context: context,
      ruText: 'От $levelCode',
      enText: 'From $levelCode',
    );
  }

  String _defaultPartnerLevelLabel(BuildContext context, UsersRecord? user) {
    final currentUserLevel = resolveUserMatchLevel(user);
    if (currentUserLevel == null) {
      return _localizedText(
        context: context,
        ruText: 'Любой',
        enText: 'Any',
      );
    }

    return _levelFilterLabel(context, currentUserLevel);
  }

  Future<void> _clearPreferredLocation() async {
    final userRef = currentUserReference;
    if (userRef == null) {
      return;
    }

    await userRef.update(
      _studentUserUpdate(createUsersRecordData(
        preferences: createPreferencesStruct(
          fieldValues: {
            'preferredLocation': FieldValue.delete(),
          },
          clearUnsetFields: false,
        ),
      )),
    );
  }

  Future<void> _setPreferredPartnerLevel(Level? level) async {
    final userRef = currentUserReference;
    if (userRef == null) {
      return;
    }

    await userRef.update(
      _studentUserUpdate(createUsersRecordData(
        preferences: level == null
            ? createPreferencesStruct(
                fieldValues: {
                  'preferredPartnerLevel': FieldValue.delete(),
                },
                clearUnsetFields: false,
              )
            : createPreferencesStruct(
                preferredPartnerLevel: level,
                clearUnsetFields: false,
              ),
      )),
    );
  }

  List<CountryStruct> _locationDropdownCountries() {
    final countries = functions.countriesList();
    return countries.toList()
      ..sort((left, right) => left.index.compareTo(right.index));
  }

  String _levelDropdownLabel(BuildContext context, Level level) {
    final levelFilterLabel = _levelFilterLabel(context, level);
    switch (level) {
      case Level.Beginner:
        return '$levelFilterLabel — Beginner';
      case Level.Basic:
        return '$levelFilterLabel — Basic';
      case Level.Intermediate:
        return '$levelFilterLabel — Intermediate';
      case Level.Fluent:
        return '$levelFilterLabel — Fluent';
    }
  }

  Future<void> _openPreferredPartnerLevelPicker(
    BuildContext anchorContext,
  ) async {
    const anyLevelValue = '__any__';
    final currentPartnerLevel =
        currentUserDocument?.preferences.preferredPartnerLevel;
    safeSetState(() => _isLevelMenuOpen = true);
    final selectedValue = await _showDashboardOptionsMenu<String>(
      anchorContext,
      options: [
        for (final level in Level.values)
          _DashboardMenuOption<String>(
            value: level.name,
            label: _levelDropdownLabel(context, level),
            selected: level == currentPartnerLevel,
          ),
        _DashboardMenuOption<String>(
          value: anyLevelValue,
          label: _localizedText(
            context: context,
            ruText: 'Любой',
            enText: 'Any',
          ),
          selected: currentPartnerLevel == null,
        ),
      ],
    );
    if (mounted) {
      safeSetState(() => _isLevelMenuOpen = false);
    }

    if (!mounted || selectedValue == null) {
      return;
    }

    final livePreferredPartnerLevel =
        currentUserDocument?.preferences.preferredPartnerLevel;
    if (selectedValue == anyLevelValue) {
      if (livePreferredPartnerLevel != null) {
        await _setPreferredPartnerLevel(null);
      }
      safeSetState(() {});
      return;
    }

    final selectedLevel = Level.values.firstWhere(
      (level) => level.name == selectedValue,
      orElse: () => livePreferredPartnerLevel ?? Level.Basic,
    );
    if (selectedLevel == livePreferredPartnerLevel) {
      safeSetState(() {});
      return;
    }

    await _setPreferredPartnerLevel(selectedLevel);
    safeSetState(() {});
  }

  Future<void> _openPreferredLocationPicker(
    BuildContext anchorContext,
  ) async {
    if (!mounted) {
      return;
    }

    final countries = _locationDropdownCountries();
    final anyLocationLabel = _localizedText(
      context: context,
      ruText: 'Любая',
      enText: 'Any',
    );
    final currentLocation = _preferredLocation(currentUserDocument);
    safeSetState(() => _isLocationMenuOpen = true);
    final selectedCode = await _showDashboardOptionsMenu<String>(
      anchorContext,
      options: [
        for (final country in countries)
          _DashboardMenuOption<String>(
            value: country.code,
            label: _preferredLocationLabel(context, country),
            selected: country.code == currentLocation?.code,
          ),
        _DashboardMenuOption<String>(
          value: '',
          label: anyLocationLabel,
          selected: currentLocation == null,
        ),
      ],
    );
    if (mounted) {
      safeSetState(() => _isLocationMenuOpen = false);
    }

    if (!mounted || selectedCode == null) {
      return;
    }

    final livePreferredLocation = _preferredLocation(currentUserDocument);
    if (selectedCode.isEmpty) {
      if (livePreferredLocation != null) {
        await _clearPreferredLocation();
      }
      safeSetState(() {});
      return;
    }

    if (selectedCode == livePreferredLocation?.code) {
      safeSetState(() {});
      return;
    }

    final selectedCountry = countries.firstWhere(
      (country) => country.code == selectedCode,
    );

    await currentUserReference!.update(
      _studentUserUpdate(createUsersRecordData(
        preferences: createPreferencesStruct(
          preferredLocation: updateCountryStruct(
            selectedCountry,
            clearUnsetFields: false,
          ),
          clearUnsetFields: false,
        ),
      )),
    );

    safeSetState(() {});
  }

  Future<T?> _showDashboardOptionsMenu<T>(
    BuildContext anchorContext, {
    required List<_DashboardMenuOption<T>> options,
  }) {
    final anchorBox = anchorContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;

    if (anchorBox == null || overlayBox == null || !anchorBox.attached) {
      return Future<T?>.value(null);
    }

    const viewportMargin = 16.0;
    const minMenuWidth = 206.0;
    const preferredMenuWidth = 280.0;
    final anchorOffset =
        anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final availableMenuWidth =
        math.max(0.0, overlayBox.size.width - (viewportMargin * 2));
    final menuWidth = math.max(
      math.min(minMenuWidth, availableMenuWidth),
      math.min(preferredMenuWidth, availableMenuWidth),
    );
    final maxMenuLeft = math.max(
        viewportMargin, overlayBox.size.width - menuWidth - viewportMargin);
    final menuLeft = (anchorOffset.dx + anchorBox.size.width - menuWidth)
        .clamp(viewportMargin, maxMenuLeft)
        .toDouble();
    final anchorRect = Rect.fromLTWH(
      menuLeft,
      anchorOffset.dy + anchorBox.size.height + 8.0,
      menuWidth,
      0.0,
    );

    return showMenu<T>(
      context: anchorContext,
      position:
          RelativeRect.fromRect(anchorRect, Offset.zero & overlayBox.size),
      color: ExpatlioDesign.card,
      elevation: 8.0,
      shadowColor: const Color(0x12000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
        side: const BorderSide(color: ExpatlioDesign.border),
      ),
      clipBehavior: Clip.antiAlias,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      constraints: BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth,
      ),
      items: [
        for (final option in options)
          PopupMenuItem<T>(
            value: option.value,
            height: 42.0,
            padding: EdgeInsets.zero,
            child: ProfileDropdownMenuItem(
              label: option.label,
              selected: option.selected,
            ),
          ),
      ],
    );
  }

  Query<Map<String, dynamic>> _filteredPartnerProfilesQuery({
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) {
    final activeLanguage =
        resolveUserActiveConversationLanguage(currentUserDocument);
    final preferredCountryCode = preferredLocation?.code.trim();

    var query = FirebaseFirestore.instance
        .collection('userPublicProfiles')
        .where('role', isEqualTo: UserRole.native_speaker.serialize())
        .where('isProfileComplete', isEqualTo: true);

    if (activeLanguage != null && activeLanguage.isNotEmpty) {
      query = query.where(
        'language_instruction_NS.code',
        isEqualTo: activeLanguage,
      );
    }
    if (preferredCountryCode != null && preferredCountryCode.isNotEmpty) {
      query = query.where(
        'Country_NS.code',
        isEqualTo: preferredCountryCode,
      );
    }
    if (preferredPartnerLevel != null) {
      query = query.where(
        'level',
        isEqualTo: preferredPartnerLevel.serialize(),
      );
    }

    return query;
  }

  Future<int?> _loadFilteredPartnerCount({
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) async {
    try {
      final loader = widget.partnerCountLoader;
      if (loader != null) {
        return loader(
          preferredLocation: preferredLocation,
          preferredPartnerLevel: preferredPartnerLevel,
        );
      }

      final query = _filteredPartnerProfilesQuery(
        preferredLocation: preferredLocation,
        preferredPartnerLevel: preferredPartnerLevel,
      );
      final countSnapshot = await query.count().get();
      return countSnapshot.count;
    } catch (error) {
      debugPrint('StudentsDashboard: failed to load partner count: $error');
      return null;
    }
  }

  Future<List<NearbyPartnerPreviewEntry>?> _loadFilteredPartnerPreviewEntries({
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) async {
    try {
      final loader = widget.partnerPreviewLoader;
      if (loader != null) {
        return loader(
          preferredLocation: preferredLocation,
          preferredPartnerLevel: preferredPartnerLevel,
        );
      }

      final snapshot = await _filteredPartnerProfilesQuery(
        preferredLocation: preferredLocation,
        preferredPartnerLevel: preferredPartnerLevel,
      ).limit(_searchAvatarMotions.length).get();

      return snapshot.docs
          .map(UserPublicProfilesRecord.fromSnapshot)
          .map(
            (profile) => NearbyPartnerPreviewEntry(
              displayName: profile.displayName,
              photoUrl: profile.photoUrl,
            ),
          )
          .toList(growable: false);
    } catch (error) {
      debugPrint('StudentsDashboard: failed to load partner avatars: $error');
      return null;
    }
  }

  String _partnerCountCacheKeyFor({
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) {
    final activeLanguage =
        resolveUserActiveConversationLanguage(currentUserDocument) ?? '';
    return nearbyPartnerCountCacheKey(
      languageCode: activeLanguage,
      countryCode: preferredLocation?.code ?? '',
      partnerLevel: preferredPartnerLevel?.name ?? '',
    );
  }

  int _partnerCountFor({
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) {
    final cacheKey = _partnerCountCacheKeyFor(
      preferredLocation: preferredLocation,
      preferredPartnerLevel: preferredPartnerLevel,
    );
    _activePartnerCountCacheKey = cacheKey;
    final cachedCount = _partnerCountCache.read(cacheKey);
    if (cachedCount != null) {
      _partnerCountMemoryCache.putIfAbsent(cacheKey, () => cachedCount);
    }
    _startPartnerCountRefresh(
      cacheKey: cacheKey,
      preferredLocation: preferredLocation,
      preferredPartnerLevel: preferredPartnerLevel,
    );
    return _partnerCountMemoryCache[cacheKey] ?? 0;
  }

  void _startPartnerCountRefresh({
    required String cacheKey,
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) {
    if (!_partnerCountRefreshesStarted.add(cacheKey)) {
      return;
    }

    unawaited(
      _refreshPartnerCount(
        cacheKey: cacheKey,
        preferredLocation: preferredLocation,
        preferredPartnerLevel: preferredPartnerLevel,
      ),
    );
  }

  Future<void> _refreshPartnerCount({
    required String cacheKey,
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) async {
    final freshCount = await _loadFilteredPartnerCount(
      preferredLocation: preferredLocation,
      preferredPartnerLevel: preferredPartnerLevel,
    );
    if (freshCount == null || freshCount < 0) {
      return;
    }

    _publishPartnerCount(cacheKey, freshCount);
    try {
      await _partnerCountCache.write(cacheKey, freshCount);
    } catch (error) {
      debugPrint('StudentsDashboard: failed to cache partner count: $error');
    }
  }

  void _publishPartnerCount(String cacheKey, int count) {
    if (_partnerCountMemoryCache[cacheKey] == count) {
      return;
    }
    _partnerCountMemoryCache[cacheKey] = count;

    if (mounted && _activePartnerCountCacheKey == cacheKey) {
      safeSetState(() {});
    }
  }

  String _partnerPreviewCacheKeyFor({
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) {
    final activeLanguage =
        resolveUserActiveConversationLanguage(currentUserDocument) ?? '';
    return nearbyPartnerPreviewCacheKey(
      languageCode: activeLanguage,
      countryCode: preferredLocation?.code ?? '',
      partnerLevel: preferredPartnerLevel?.name ?? '',
    );
  }

  void _ensurePartnerPreviewLoad({
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) {
    final cacheKey = _partnerPreviewCacheKeyFor(
      preferredLocation: preferredLocation,
      preferredPartnerLevel: preferredPartnerLevel,
    );

    if (_partnerPreviewCacheKey != cacheKey || _partnerPreviewFuture == null) {
      _partnerPreviewCacheKey = cacheKey;
      final cachedEntries = _partnerPreviewCache.read(cacheKey);
      _partnerPreviewInitialData = cachedEntries == null
          ? _fallbackSearchAvatars
          : _buildPartnerPreviewAvatars(cachedEntries);
      _partnerPreviewFuture = _refreshPartnerPreview(
        cacheKey: cacheKey,
        cachedAvatars: _partnerPreviewInitialData!,
        preferredLocation: preferredLocation,
        preferredPartnerLevel: preferredPartnerLevel,
      );
    }
  }

  Future<List<OrbitingAvatarData>> _partnerPreviewFutureFor({
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) {
    _ensurePartnerPreviewLoad(
      preferredLocation: preferredLocation,
      preferredPartnerLevel: preferredPartnerLevel,
    );

    return _partnerPreviewFuture!;
  }

  List<OrbitingAvatarData> _partnerPreviewInitialDataFor({
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) {
    _ensurePartnerPreviewLoad(
      preferredLocation: preferredLocation,
      preferredPartnerLevel: preferredPartnerLevel,
    );
    return _partnerPreviewInitialData ?? _fallbackSearchAvatars;
  }

  Future<List<OrbitingAvatarData>> _refreshPartnerPreview({
    required String cacheKey,
    required List<OrbitingAvatarData> cachedAvatars,
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) async {
    final freshEntries = await _loadFilteredPartnerPreviewEntries(
      preferredLocation: preferredLocation,
      preferredPartnerLevel: preferredPartnerLevel,
    );
    if (freshEntries == null) {
      return cachedAvatars;
    }

    final freshAvatars = _buildPartnerPreviewAvatars(freshEntries);
    try {
      await _partnerPreviewCache.write(cacheKey, freshEntries);
    } catch (error) {
      debugPrint('StudentsDashboard: failed to cache partner avatars: $error');
    }
    return freshAvatars;
  }

  List<OrbitingAvatarData> _buildPartnerPreviewAvatars(
    List<NearbyPartnerPreviewEntry> profiles,
  ) {
    final avatars = <OrbitingAvatarData>[];
    final maxCount = math.min(profiles.length, _searchAvatarMotions.length);

    for (var i = 0; i < maxCount; i++) {
      final profile = profiles[i];
      final photoUrl = profile.photoUrl.trim();
      avatars.add(
        OrbitingAvatarData(
          initials: _avatarInitials(profile.displayName, i),
          assetPath:
              photoUrl.isEmpty ? _fallbackSearchAvatars[i].assetPath : '',
          photoUrl: photoUrl,
          size: _fallbackSearchAvatars[i].size,
          motion: _searchAvatarMotions[i],
        ),
      );
    }

    for (var i = avatars.length; i < _fallbackSearchAvatars.length; i++) {
      avatars.add(_fallbackSearchAvatars[i]);
    }

    return avatars;
  }

  String _avatarInitials(String displayName, int index) {
    final nameParts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    if (nameParts.isNotEmpty) {
      final name = nameParts.first;
      return name.length >= 2
          ? name.substring(0, 2).toUpperCase()
          : name[0].toUpperCase();
    }

    return _fallbackSearchAvatars[index % _fallbackSearchAvatars.length]
        .initials;
  }

  String _partnerCountNoun(BuildContext context, int count) {
    if (FFLocalizations.of(context).languageCode != 'ru') {
      return count == 1 ? 'person' : 'people';
    }

    final lastTwo = count % 100;
    if (lastTwo >= 11 && lastTwo <= 14) {
      return 'человек';
    }

    switch (count % 10) {
      case 1:
        return 'человек';
      case 2:
      case 3:
      case 4:
        return 'человека';
      default:
        return 'человек';
    }
  }

  String _usageDayKeyUtc(DateTime value) {
    return value.toUtc().toIso8601String().split('T').first;
  }

  String _usageWeekKeyUtc(DateTime value) {
    final utc = value.toUtc();
    final day = DateTime.utc(utc.year, utc.month, utc.day);
    final thursday = day.add(Duration(days: 4 - day.weekday));
    final yearStart = DateTime.utc(thursday.year);
    final weekNo = ((thursday.difference(yearStart).inDays + 1) / 7).ceil();
    return '${thursday.year}-W${weekNo.toString().padLeft(2, '0')}';
  }

  int _usageSecondsForCurrentWindow(
    Map<String, dynamic> data, {
    required String keyField,
    required String expectedKey,
    required String secondsField,
  }) {
    if (data[keyField] != expectedKey) {
      return 0;
    }
    return (data[secondsField] as num?)?.toInt() ?? 0;
  }

  Future<bool> _hasKnownUsageLimitReached(UsersRecord user) async {
    if (!hasActiveSubscription(user)) {
      return false;
    }

    final checker = widget.usageLimitReachedChecker ??
        StudentsDashboardWidget.debugUsageLimitReachedChecker;
    if (checker != null) {
      return checker(user);
    }

    try {
      final usageSnapshot =
          await user.reference.collection('usage').doc('current').get();
      final usageData = usageSnapshot.data();
      if (usageData == null) {
        return false;
      }

      final now = DateTime.now();
      final dayDurationSeconds = _usageSecondsForCurrentWindow(
        usageData,
        keyField: 'dayKey',
        expectedKey: _usageDayKeyUtc(now),
        secondsField: 'dayDurationSeconds',
      );
      final weekDurationSeconds = _usageSecondsForCurrentWindow(
        usageData,
        keyField: 'weekKey',
        expectedKey: _usageWeekKeyUtc(now),
        secondsField: 'weekDurationSeconds',
      );
      return dayDurationSeconds >= _subscriberDailySearchLimitSeconds ||
          weekDurationSeconds >= _subscriberWeeklySearchLimitSeconds;
    } catch (error) {
      debugPrint(
        'StudentsDashboard: failed to check local usage limit: $error',
      );
      return false;
    }
  }

  bool _isVideoCallReadySession(VideoSessionsRecord session) {
    final roomUrl = _normalizedNonEmptyString(session.dailyRoomUrl);
    if (roomUrl == null) {
      return false;
    }

    switch (session.status.trim()) {
      case 'connecting':
      case 'active':
      case 'connected':
        return true;
      default:
        return false;
    }
  }

  String? _sessionMatchContextString(
    VideoSessionsRecord session,
    String key,
  ) {
    final matchContext =
        _normalizeCallableMap(session.snapshotData['matchContext']);
    return _normalizedNonEmptyString(matchContext[key]);
  }

  String? _sessionRequesterId(VideoSessionsRecord session) {
    return _normalizedNonEmptyString(session.snapshotData['requesterId']) ??
        _normalizedNonEmptyString(session.snapshotData['studentId']) ??
        _sessionMatchContextString(session, 'requesterId');
  }

  String? _sessionResponderId(VideoSessionsRecord session) {
    return _normalizedNonEmptyString(
            session.snapshotData['currentResponderId']) ??
        _normalizedNonEmptyString(session.snapshotData['currentTutorId']) ??
        _normalizedNonEmptyString(session.snapshotData['responderId']) ??
        _sessionMatchContextString(session, 'currentResponderId') ??
        _sessionMatchContextString(session, 'responderId') ??
        _sessionMatchContextString(session, 'acceptedResponderId');
  }

  bool _isCurrentUserForegroundResponder(VideoSessionsRecord session) {
    final userId = _normalizedNonEmptyString(currentUserUid);
    if (userId == null || _searchAppState != 'foreground') {
      return false;
    }

    final responderId = _sessionResponderId(session);
    if (responderId != userId) {
      return false;
    }

    return _sessionRequesterId(session) != userId;
  }

  void _handleForegroundActiveSession(VideoSessionsRecord? session) {
    if (session == null ||
        StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation) {
      return;
    }

    final sessionId = _normalizedSessionId(session.reference.id);
    if (sessionId == null ||
        _searchAppState != 'foreground' ||
        _isActiveSessionSuppressed(sessionId)) {
      return;
    }

    if (session.status.trim() == 'pending_confirmation') {
      _maybeAcceptForegroundStudentSession(session);
      return;
    }

    if (_isVideoCallReadySession(session)) {
      _maybeOpenReadyForegroundSession(session);
    }
  }

  void _maybeOpenReadyForegroundSession(VideoSessionsRecord session) {
    final sessionId = _normalizedSessionId(session.reference.id);
    if (sessionId == null ||
        _autoOpenedSessionId == sessionId ||
        _autoOpenCredentialStartedSessionIds.contains(sessionId)) {
      return;
    }

    _autoOpenCredentialStartedSessionIds.add(sessionId);
    unawaited(_openReadyForegroundSessionWithTokens(session.reference));
  }

  Future<void> _openReadyForegroundSessionWithTokens(
    DocumentReference videoDocRef,
  ) async {
    final sessionId = _normalizedSessionId(videoDocRef.id);
    if (sessionId == null) {
      return;
    }

    try {
      final response = await _getAutoOpenSessionTokens(sessionId);
      if (!mounted) {
        return;
      }
      if (_isActiveSessionSuppressed(sessionId)) {
        return;
      }
      if (_searchAppState != 'foreground') {
        _autoOpenCredentialStartedSessionIds.remove(sessionId);
        return;
      }

      final roomUrl = _normalizedResponseString(response, 'roomUrl');
      final meetingToken = _normalizedResponseString(response, 'meetingToken');
      if (roomUrl == null || meetingToken == null) {
        _autoOpenCredentialStartedSessionIds.remove(sessionId);
        return;
      }

      _scheduleAutoOpenSession(
        videoDocRef,
        roomUrl: roomUrl,
        meetingToken: meetingToken,
        roomName: _normalizedResponseString(response, 'roomName'),
      );
    } catch (error) {
      _autoOpenCredentialStartedSessionIds.remove(sessionId);
      debugPrint(
        'StudentsDashboard: failed to prepare foreground session tokens: $error',
      );
    }
  }

  void _maybeAcceptForegroundStudentSession(VideoSessionsRecord session) {
    final sessionId = _normalizedSessionId(session.reference.id);
    if (sessionId == null ||
        !_isCurrentUserForegroundResponder(session) ||
        _foregroundAcceptStartedSessionIds.contains(sessionId)) {
      return;
    }

    _foregroundAcceptStartedSessionIds.add(sessionId);
    _clearSearchTimeoutTimer();
    _clearSearchHeartbeatTimer();
    unawaited(_acceptForegroundStudentSession(sessionId));
  }

  Future<void> _acceptForegroundStudentSession(String sessionId) async {
    try {
      final response = await _acceptForegroundSessionRequest(sessionId);
      if (!mounted) {
        return;
      }
      if (_isActiveSessionSuppressed(sessionId)) {
        return;
      }
      if (_searchAppState != 'foreground') {
        _foregroundAcceptStartedSessionIds.remove(sessionId);
        return;
      }

      if (_normalizedResponseString(response, 'status') != 'connected') {
        _foregroundAcceptStartedSessionIds.remove(sessionId);
        return;
      }

      final roomUrl = _normalizedResponseString(response, 'roomUrl');
      final meetingToken = _normalizedResponseString(response, 'meetingToken');
      if (roomUrl == null || meetingToken == null) {
        _foregroundAcceptStartedSessionIds.remove(sessionId);
        return;
      }

      _scheduleAutoOpenSession(
        VideoSessionsRecord.collection.doc(sessionId),
        roomUrl: roomUrl,
        meetingToken: meetingToken,
        roomName: _normalizedResponseString(response, 'roomName'),
      );
    } catch (error) {
      _foregroundAcceptStartedSessionIds.remove(sessionId);
      debugPrint(
        'StudentsDashboard: failed to accept foreground session: $error',
      );
    }
  }

  void _scheduleAutoOpenSession(
    DocumentReference videoDocRef, {
    String? roomUrl,
    String? meetingToken,
    String? roomName,
  }) {
    final sessionId = _normalizedSessionId(videoDocRef.id);
    if (sessionId == null ||
        _autoOpenedSessionId == sessionId ||
        _searchAppState != 'foreground' ||
        _isActiveSessionSuppressed(sessionId)) {
      return;
    }

    _autoOpenedSessionId = sessionId;
    _clearSearchTimeoutTimer();
    _clearSearchHeartbeatTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoOpenedSessionId != sessionId) {
        return;
      }
      if (_searchAppState != 'foreground') {
        _autoOpenedSessionId = null;
        _autoOpenCredentialStartedSessionIds.remove(sessionId);
        return;
      }
      if (_isActiveSessionSuppressed(sessionId)) {
        return;
      }

      final debugNavigator =
          StudentsDashboardWidget.debugAutoOpenSessionNavigator;
      if (debugNavigator != null) {
        unawaited(
          Future<void>.sync(
            () => debugNavigator(
              this.context,
              videoDocRef,
              roomUrl: roomUrl,
              meetingToken: meetingToken,
              roomName: roomName,
            ),
          ).catchError((Object error) {
            debugPrint(
              'StudentsDashboard: failed to auto-open debug session: $error',
            );
          }),
        );
        return;
      }

      final router = GoRouter.of(this.context);
      if (router
          .getCurrentLocation()
          .startsWith(VideoCallPageWidget.routePath)) {
        return;
      }

      this.context.goNamed(
            VideoCallPageWidget.routeName,
            queryParameters: {
              'videoDocRef': serializeParam(
                videoDocRef,
                ParamType.DocumentReference,
              ),
              'roomUrl': serializeParam(roomUrl, ParamType.String),
              'meetingToken': serializeParam(meetingToken, ParamType.String),
              'roomName': serializeParam(roomName, ParamType.String),
            }.withoutNulls,
          );
    });
  }

  Future<VideoSessionsRecord?> _readActiveSessionOnce(String sessionId) {
    final sessionRef = VideoSessionsRecord.collection.doc(sessionId);
    final reader = StudentsDashboardWidget.debugActiveSessionReader;
    if (reader != null) {
      return reader(sessionRef);
    }
    return VideoSessionsRecord.getDocumentOnce(sessionRef);
  }

  Future<bool?> _hasActiveCallSessionForAccess(
    UsersRecord user,
    bool visibleActiveCallSession,
  ) async {
    if (visibleActiveCallSession) {
      return true;
    }

    final sessionId = user.currentSessionId.trim();
    if (sessionId.isEmpty) {
      return false;
    }

    try {
      final session = await _readActiveSessionOnce(sessionId);
      return _isActiveCallSession(session);
    } catch (error) {
      debugPrint(
        'StudentsDashboard: failed to check active session before search: '
        '$error',
      );
      _setSearchError(
        StudentDashboardSearchErrorReason.activeSessionUnavailable,
      );
      return null;
    }
  }

  Future<void> _showNoSearchAccessBottomSheet() async {
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
    ).then((value) => safeSetState(() {}));
  }

  Future<bool> _ensureStartSearchAccess({
    required bool hasActiveCallSession,
  }) async {
    final user = currentUserDocument;
    if (currentUser?.loggedIn != true ||
        user == null ||
        currentUserUid.trim().isEmpty ||
        !hasCurrentUserDocumentForUid(currentUserUid)) {
      _setSearchError(StudentDashboardSearchErrorReason.authRequired);
      return false;
    }

    if (!canStartCall(user)) {
      await _showNoSearchAccessBottomSheet();
      return false;
    }

    if (user.isInCall) {
      _setSearchError(StudentDashboardSearchErrorReason.activeCall);
      return false;
    }

    final hasCurrentActiveSession = await _hasActiveCallSessionForAccess(
      user,
      hasActiveCallSession,
    );
    if (hasCurrentActiveSession == null) {
      return false;
    }

    if (hasCurrentActiveSession) {
      _setSearchError(StudentDashboardSearchErrorReason.activeCall);
      return false;
    }

    if (await _hasKnownUsageLimitReached(user)) {
      _setSearchError(StudentDashboardSearchErrorReason.usageLimitReached);
      return false;
    }

    final hasMediaPermissions = await ensureCameraAndMicrophonePermissions();
    if (!hasMediaPermissions) {
      _setSearchError(
        StudentDashboardSearchErrorReason.mediaPermissionDenied,
      );
      return false;
    }

    return true;
  }

  Future<void> _stopActiveSearchRequest(
    String? activeSessionId, {
    String? activeSearchRequestId,
  }) async {
    final stopSearchKey = _stopSearchKeyFor(activeSessionId);
    if (_stoppingSearchKeys.contains(stopSearchKey)) {
      return;
    }

    _stoppingSearchKeys.add(stopSearchKey);
    var stopSucceeded = false;
    final stopSearchRequest = widget.stopSearchRequest ??
        StudentsDashboardWidget.debugStopSearchRequest;
    final normalizedSessionId = _normalizedSessionId(activeSessionId);
    final requestId = activeSearchRequestId ?? _activeSearchRequestId;
    final payload = <String, dynamic>{
      if (normalizedSessionId != null) 'sessionId': normalizedSessionId,
      if (requestId != null) 'requestId': requestId,
    };
    StudentsDashboardWidget.debugStopSearchPayloadObserver?.call(
      Map<String, dynamic>.from(payload),
    );

    try {
      if (stopSearchRequest != null) {
        final stopSearchResult = await stopSearchRequest(
          normalizedSessionId,
        ).timeout(StudentsDashboardWidget.stopSearchRequestTimeout);
        stopSucceeded = stopSearchResult == null
            ? true
            : _isStopSearchResponseSuccess(
                stopSearchResult,
                hasExplicitSessionId: normalizedSessionId != null,
              );
        return;
      }

      final stopSearchResult = await FirebaseFunctions.instance
          .httpsCallable('stopSearch')
          .call(
            payload,
          )
          .timeout(StudentsDashboardWidget.stopSearchRequestTimeout);
      stopSucceeded = _isStopSearchResponseSuccess(
        stopSearchResult.data,
        hasExplicitSessionId: normalizedSessionId != null,
      );
    } catch (error) {
      debugPrint(
        'StudentsDashboard: failed to stop active search: $error',
      );
    } finally {
      _stoppingSearchKeys.remove(stopSearchKey);
      _handleStopSearchFinished(succeeded: stopSucceeded);
    }
  }

  void _logStartSearchFailure(Object error, StackTrace stackTrace) {
    if (error is FirebaseFunctionsException) {
      debugPrint(
        'StudentsDashboard: failed to start search '
        '(${error.code}, details: ${error.details}): '
        '${error.message ?? error.toString()}',
      );
    } else {
      debugPrint('StudentsDashboard: failed to start search: $error');
    }
    debugPrintStack(stackTrace: stackTrace);
  }

  Future<void> _handleStartConversation(
    StudentDashboardSearchState visibleSearchState,
    String? visibleSessionId,
    bool hasActiveCallSession,
  ) async {
    if (_isStopSearchState(visibleSearchState)) {
      if (_ignoreStopSearchUntilNextFrame) {
        return;
      }

      _ignoreStopSearchUntilNextFrame = true;
      final stopSessionId = _stopSessionIdFor(visibleSessionId);
      final stopSearchRequestId = _activeSearchRequestId;
      final shouldStopWhenStartCompletes = _isStartingSearch &&
          stopSessionId == null &&
          stopSearchRequestId == null;
      _clearQueuedStartSearchAfterStop();
      if (shouldStopWhenStartCompletes) {
        _stopSearchWhenStartCompletes = true;
      }
      safeSetState(() {
        _searchState = StudentDashboardSearchState.idle;
        _searchErrorReason = null;
        _matchedSearchSessionId = null;
        _suppressedActiveSessionId = stopSessionId;
        _suppressedActiveSearchUserId =
            stopSessionId == null ? _currentSearchUserId() : null;
        _ignoreStartSearchUntilNextFrame = true;
      });
      _clearSearchTimeoutTimer();
      _clearSearchHeartbeatTimer();
      if (!shouldStopWhenStartCompletes) {
        unawaited(_stopActiveSearchRequest(
          stopSessionId,
          activeSearchRequestId: stopSearchRequestId,
        ));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ignoreStartSearchUntilNextFrame = false;
          _ignoreStopSearchUntilNextFrame = false;
        }
      });
      return;
    }

    if (_isStartingSearch) {
      return;
    }

    if (_stoppingSearchKeys.isNotEmpty) {
      _queueStartSearchAfterStop(
        hasActiveCallSession: hasActiveCallSession,
      );
      return;
    }

    if (_ignoreStartSearchUntilNextFrame) {
      return;
    }

    safeSetState(() {
      _isStartingSearch = true;
      _stopSearchWhenStartCompletes = false;
      _searchErrorReason = null;
      _suppressedActiveSessionId = null;
      _suppressedActiveSearchUserId = null;
    });
    _clearSearchTimeoutTimer();

    var startSearchRequestSent = false;
    var startSearchResponseReceived = false;
    try {
      if (!await _ensureStartSearchAccess(
        hasActiveCallSession: hasActiveCallSession,
      )) {
        return;
      }

      if (!mounted) {
        return;
      }

      safeSetState(() {
        _searchState = StudentDashboardSearchState.searching;
        _searchErrorReason = null;
        _matchedSearchSessionId = null;
        _suppressedActiveSessionId = null;
        _suppressedActiveSearchUserId = null;
      });

      startSearchRequestSent = true;
      final startSearchData = await _startActiveSearchRequest(
        currentUserDocument!,
      );
      startSearchResponseReceived = true;
      final requestId = _normalizedResponseString(startSearchData, 'requestId');
      if (requestId == null) {
        throw Exception('startSearch did not return requestId');
      }
      final sessionId = _normalizedResponseString(startSearchData, 'sessionId');
      final status = _normalizedResponseString(startSearchData, 'status');
      final reusedSearchRequest = _responseBool(startSearchData, 'reused');
      final nextSearchState = sessionId != null || status == 'matched'
          ? StudentDashboardSearchState.connecting
          : StudentDashboardSearchState.searching;

      if (_stopSearchWhenStartCompletes) {
        _stopSearchWhenStartCompletes = false;
        unawaited(_stopActiveSearchRequest(
          sessionId,
          activeSearchRequestId: requestId,
        ));
        return;
      }

      if (!mounted) {
        return;
      }

      safeSetState(() {
        _searchState = nextSearchState;
        _searchErrorReason = null;
        _matchedSearchSessionId = sessionId;
        _suppressedActiveSessionId = null;
        _suppressedActiveSearchUserId = null;
      });
      if (nextSearchState == StudentDashboardSearchState.searching) {
        _startSearchTimeoutTimer();
        _startSearchHeartbeatTimer(requestId);
        if (reusedSearchRequest) {
          unawaited(_sendSearchHeartbeat(requestId));
        }
      } else {
        _clearSearchTimeoutTimer();
        _clearSearchHeartbeatTimer();
      }
    } on Exception catch (error, stackTrace) {
      if (_stopSearchWhenStartCompletes) {
        _stopSearchWhenStartCompletes = false;
        return;
      }
      if (startSearchRequestSent &&
          !startSearchResponseReceived &&
          await _recoverStartSearchRequestAfterFailure()) {
        return;
      }
      _logStartSearchFailure(error, stackTrace);
      if (mounted) {
        _setSearchError(StudentDashboardSearchErrorReason.searchUnavailable);
      }
    } finally {
      if (mounted) {
        safeSetState(() => _isStartingSearch = false);
      }
    }
  }

  Widget _buildSearchCtaContent({
    required BuildContext context,
    required List<OrbitingAvatarData> avatars,
    required CountryStruct? preferredLocation,
    required Level? selectedPartnerLevel,
    required StudentDashboardSearchState searchState,
    required String? activeSessionId,
    required bool hasActiveCallSession,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.toDouble();
        final compact = availableHeight < 460.0;
        final orbitHeight = compact
            ? availableHeight.clamp(150.0, 180.0)
            : math.min(220.0, availableHeight * 0.42);
        final estimatedContentHeight = orbitHeight + ExpatlioDesign.space32;
        final topInset = math.max(
          ExpatlioDesign.space0,
          (availableHeight - estimatedContentHeight) / 2.0,
        );

        return SizedBox(
          width: double.infinity,
          height: availableHeight,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              SizedBox(height: topInset),
              SizedBox(
                height: orbitHeight,
                child: OrbitingAvatarsCta(
                  avatars: avatars,
                  action: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStartSearchButton(
                        context,
                        searchState,
                        activeSessionId,
                        hasActiveCallSession,
                      ),
                      if (_showsSearchStatus(searchState))
                        _buildSearchStatusBlock(context, searchState)
                      else
                        _buildPartnerCountText(
                          context: context,
                          preferredLocation: preferredLocation,
                          selectedPartnerLevel: selectedPartnerLevel,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchStatusBlock(
    BuildContext context,
    StudentDashboardSearchState searchState,
  ) {
    final label = switch (searchState) {
      StudentDashboardSearchState.connecting =>
        FFLocalizations.of(context).getVariableText(
          ruText: 'Соединяем',
          enText: 'Connecting',
        ),
      StudentDashboardSearchState.noMatchFound =>
        FFLocalizations.of(context).getVariableText(
          ruText: 'Пока никого не нашли',
          enText: 'No one found yet',
        ),
      StudentDashboardSearchState.error => _searchErrorText(context),
      StudentDashboardSearchState.searching =>
        FFLocalizations.of(context).getVariableText(
          ruText: 'Ищем собеседника',
          enText: 'Looking for a partner',
        ),
      StudentDashboardSearchState.idle => '',
    };
    final showProgress = _isStopSearchState(searchState);

    return Padding(
      padding: const EdgeInsets.only(top: ExpatlioDesign.itemSpacing),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ExpatlioDesign.card,
            borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
            border: Border.all(color: ExpatlioDesign.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 16.0,
                offset: Offset(0.0, 8.0),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ExpatlioDesign.space12,
              vertical: ExpatlioDesign.space8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showProgress) ...[
                  SizedBox(
                    width: 16.0,
                    height: 16.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: ExpatlioDesign.primary,
                      backgroundColor:
                          ExpatlioDesign.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  const SizedBox(width: ExpatlioDesign.space8),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: ExpatlioDesign.text,
                        size: 14.0,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _searchErrorText(BuildContext context) {
    switch (_searchErrorReason) {
      case StudentDashboardSearchErrorReason.authRequired:
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Войдите в аккаунт',
          enText: 'Sign in to continue',
        );
      case StudentDashboardSearchErrorReason.activeCall:
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Завершите текущий звонок',
          enText: 'Finish the current call',
        );
      case StudentDashboardSearchErrorReason.usageLimitReached:
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Лимит звонков исчерпан',
          enText: 'Call limit reached',
        );
      case StudentDashboardSearchErrorReason.mediaPermissionDenied:
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Разрешите камеру и микрофон',
          enText: 'Allow camera and microphone',
        );
      case StudentDashboardSearchErrorReason.activeSessionUnavailable:
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Не удалось обновить поиск',
          enText: 'Could not update search',
        );
      case StudentDashboardSearchErrorReason.searchUnavailable:
      case null:
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Не удалось начать поиск',
          enText: 'Could not start search',
        );
    }
  }

  Widget _buildStartSearchButton(
    BuildContext context,
    StudentDashboardSearchState searchState,
    String? activeSessionId,
    bool hasActiveCallSession,
  ) {
    return StudentStartSearchButton(
      isActive: _isStopSearchState(searchState),
      onTap: () => _handleStartConversation(
        searchState,
        activeSessionId,
        hasActiveCallSession,
      ),
    );
  }

  Widget _buildPartnerCountText({
    required BuildContext context,
    required CountryStruct? preferredLocation,
    required Level? selectedPartnerLevel,
  }) {
    final count = _partnerCountFor(
      preferredLocation: preferredLocation,
      preferredPartnerLevel: selectedPartnerLevel,
    );

    return Padding(
      padding: const EdgeInsets.only(top: ExpatlioDesign.itemSpacing),
      child: RichText(
        textScaler: MediaQuery.of(context).textScaler,
        text: TextSpan(
          children: [
            TextSpan(
              text: FFLocalizations.of(context).getVariableText(
                ruText: 'рядом с вами ',
                enText: 'near you ',
              ),
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.muted,
                size: 13.0,
                weight: FontWeight.w400,
              ),
            ),
            TextSpan(
              text: count.toString(),
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.success,
                size: 13.0,
                weight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: ' ${_partnerCountNoun(context, count)}',
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.muted,
                size: 13.0,
                weight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceSearchHero(
    BuildContext context, {
    required StudentDashboardSearchState searchState,
    required String? activeSessionId,
    required bool hasActiveCallSession,
  }) {
    final selectedPartnerLevel =
        currentUserDocument?.preferences.preferredPartnerLevel;
    final preferredLocation = _preferredLocation(currentUserDocument);
    final heroHeight =
        (MediaQuery.sizeOf(context).height - 190.0).clamp(560.0, 760.0);

    return SizedBox(
      height: heroHeight.toDouble(),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.pagePadding,
          ExpatlioDesign.space0,
          ExpatlioDesign.pagePadding,
          ExpatlioDesign.pagePaddingLarge,
        ),
        child: Column(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 246.0,
              height: 72.0,
              cacheWidth: 984,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: ExpatlioDesign.space24),
            Row(
              children: [
                Expanded(
                  child: DashboardInlineFilterButton(
                    title: preferredLocation == null
                        ? _localizedText(
                            context: context,
                            ruText: 'Локация',
                            enText: 'Location',
                          )
                        : '',
                    label: preferredLocation == null
                        ? ''
                        : _preferredLocationLabel(
                            context,
                            preferredLocation,
                          ),
                    selected: preferredLocation != null,
                    icon: Icons.location_on_outlined,
                    menuOpen: _isLocationMenuOpen,
                    onTap: _openPreferredLocationPicker,
                    onClear: preferredLocation == null
                        ? null
                        : () async {
                            await _clearPreferredLocation();
                            safeSetState(() {});
                          },
                  ),
                ),
                const SizedBox(width: ExpatlioDesign.itemSpacing),
                Expanded(
                  child: DashboardInlineFilterButton(
                    title: _localizedText(
                      context: context,
                      ruText: 'Уровень',
                      enText: 'Level',
                    ),
                    label: selectedPartnerLevel == null
                        ? ''
                        : _levelFilterLabel(context, selectedPartnerLevel),
                    selected: selectedPartnerLevel != null,
                    icon: Icons.school_outlined,
                    menuOpen: _isLevelMenuOpen,
                    onTap: _openPreferredPartnerLevelPicker,
                    onClear: selectedPartnerLevel == null
                        ? null
                        : () async {
                            await _setPreferredPartnerLevel(null);
                            safeSetState(() {});
                          },
                  ),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<OrbitingAvatarData>>(
                future: _partnerPreviewFutureFor(
                  preferredLocation: preferredLocation,
                  preferredPartnerLevel: selectedPartnerLevel,
                ),
                initialData: _partnerPreviewInitialDataFor(
                  preferredLocation: preferredLocation,
                  preferredPartnerLevel: selectedPartnerLevel,
                ),
                builder: (context, snapshot) {
                  final avatars = snapshot.data?.isNotEmpty == true
                      ? snapshot.data!
                      : _fallbackSearchAvatars;

                  return _buildSearchCtaContent(
                    context: context,
                    avatars: avatars,
                    preferredLocation: preferredLocation,
                    selectedPartnerLevel: selectedPartnerLevel,
                    searchState: searchState,
                    activeSessionId: activeSessionId,
                    hasActiveCallSession: hasActiveCallSession,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _partnerCountCache = NearbyPartnerCountCache(FFAppState().prefs);
    _partnerPreviewCache = NearbyPartnerPreviewCache(FFAppState().prefs);
    _searchAppState = _searchAppStateForLifecycle(
      WidgetsBinding.instance.lifecycleState,
    );
    WidgetsBinding.instance.addObserver(this);
    _searchState = widget.initialSearchState;
    _model = createModel(context, () => StudentsDashboardModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      unawaited(_syncTimezoneMetadata());
      if (widget.topUpSuccess) {
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
                child: CelebrationTopUpWidget(),
              ),
            );
          },
        ).then((value) => safeSetState(() {}));
      } else if (widget.zn) {
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
                child: CelebrationSTWidget(
                  done: widget.done ?? false,
                ),
              ),
            );
          },
        ).then((value) => safeSetState(() {}));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearSearchTimeoutTimer();
    _clearSearchHeartbeatTimer();
    _clearActiveSearchRecoveryRetryTimer();
    _model.dispose();

    super.dispose();
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
        body: AuthUserStreamWidget(
          builder: (context) {
            if (currentUserUid.isEmpty || currentUserDocument == null) {
              return _buildLoadingState(context);
            }

            final user = currentUserDocument!;
            _maybeRecoverActiveSearchForUser(user);
            return Stack(
              children: [
                SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamBuilder<VideoSessionsRecord?>(
                        stream: _activeSessionStreamFor(user),
                        builder: (context, activeSessionSnapshot) {
                          final activeSessionIdFromUser =
                              _normalizedSessionId(user.currentSessionId) ??
                                  _matchedSearchSessionId ??
                                  '';
                          final activeSession =
                              activeSessionSnapshot.data?.reference.id ==
                                      activeSessionIdFromUser
                                  ? activeSessionSnapshot.data
                                  : null;
                          if (!activeSessionSnapshot.hasError &&
                              activeSessionSnapshot.connectionState !=
                                  ConnectionState.waiting) {
                            _rememberActiveSessionSnapshot(
                              activeSession,
                              activeSessionIdFromUser,
                            );
                          }
                          final cachedSearchState =
                              activeSessionSnapshot.hasError &&
                                      activeSession == null
                                  ? _cachedSearchStateForActiveSessionError(
                                      activeSessionIdFromUser,
                                    )
                                  : null;
                          if (activeSessionSnapshot.hasError &&
                              activeSession == null &&
                              cachedSearchState == null &&
                              _canSurfaceActiveSessionError(
                                activeSessionIdFromUser,
                              )) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted &&
                                  _canSurfaceActiveSessionError(
                                    activeSessionIdFromUser,
                                  )) {
                                _setSearchError(
                                  StudentDashboardSearchErrorReason
                                      .activeSessionUnavailable,
                                );
                              }
                            });
                          }
                          final activeSessionSnapshotSettled =
                              !activeSessionSnapshot.hasError &&
                                  activeSessionSnapshot.connectionState !=
                                      ConnectionState.waiting;
                          final effectiveSearchState = cachedSearchState ??
                              _effectiveSearchStateFor(
                                activeSession,
                                activeSessionSnapshotSettled:
                                    activeSessionSnapshotSettled,
                              );
                          final activeSessionId = cachedSearchState == null
                              ? activeSession?.reference.id ??
                                  _matchedSearchSessionId
                              : _lastActiveSessionId;
                          final hasActiveCallSession =
                              _isActiveCallSession(activeSession);
                          _handleForegroundActiveSession(activeSession);

                          return _buildReferenceSearchHero(
                            context,
                            searchState: effectiveSearchState,
                            activeSessionId: activeSessionId,
                            hasActiveCallSession: hasActiveCallSession,
                          );
                        },
                      ),
                      if (_showLegacyDashboard) ...[
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space8,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space8,
                              ExpatlioDesign.space0),
                          child: Container(
                            height: 70,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              borderRadius: BorderRadius.circular(
                                  ExpatlioDesign.cardRadius),
                              border: Border.all(
                                color: ExpatlioDesign.border,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(ExpatlioDesign.space4),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Container(
                                    width: 66,
                                    height: 66,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: ExpatlioDesign.border,
                                        width: 1,
                                      ),
                                    ),
                                    child: Builder(
                                      builder: (context) {
                                        if (currentUserPhoto != '') {
                                          return ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                                ExpatlioDesign.radiusCapsule),
                                            child: CachedNetworkImage(
                                              fadeInDuration:
                                                  Duration(milliseconds: 0),
                                              fadeOutDuration:
                                                  Duration(milliseconds: 0),
                                              imageUrl: currentUserPhoto,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                              memCacheWidth: 132,
                                              memCacheHeight: 132,
                                            ),
                                          );
                                        } else {
                                          return Align(
                                            alignment:
                                                AlignmentDirectional(0, 0),
                                            child: AuthUserStreamWidget(
                                              builder: (context) {
                                                final displayName =
                                                    currentUserDisplayName
                                                        .trim();
                                                final firstLetter =
                                                    displayName.isNotEmpty
                                                        ? displayName[0]
                                                            .toUpperCase()
                                                        : '?';
                                                return Text(
                                                  firstLetter,
                                                  textAlign: TextAlign.center,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily: 'Cool',
                                                        fontSize: 22.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                );
                                              },
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          ExpatlioDesign.space12,
                                          ExpatlioDesign.space0,
                                          ExpatlioDesign.space0,
                                          ExpatlioDesign.space0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AuthUserStreamWidget(
                                            builder: (context) => Text(
                                              'Привет, ${currentUserDisplayName}',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 15,
                                                        letterSpacing: 0.0,
                                                      ),
                                            ),
                                          ),
                                          Text(
                                            FFLocalizations.of(context).getText(
                                              'xocrym2z' /* Welcome to Expatlio */,
                                            ),
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'sf pro display',
                                                  fontSize: 16,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space8,
                              ExpatlioDesign.space8,
                              ExpatlioDesign.space8,
                              ExpatlioDesign.space0),
                          child: InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              context.pushNamed(PayWidget.routeName);
                            },
                            child: Stack(
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      ExpatlioDesign.space56,
                                      ExpatlioDesign.space0,
                                      ExpatlioDesign.space56,
                                      ExpatlioDesign.space0),
                                  child: Container(
                                    width: double.infinity,
                                    height: 165,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                      borderRadius: BorderRadius.circular(
                                          ExpatlioDesign.radiusMedium),
                                      border: Border.all(
                                        color: ExpatlioDesign.border,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Image.asset(
                                      'assets/images/Group_1171275327_2.png',
                                      width: 65,
                                      fit: BoxFit.contain,
                                    ),
                                    Image.asset(
                                      'assets/images/Group_1171275327_1.png',
                                      width: 65,
                                      fit: BoxFit.contain,
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding:
                                      EdgeInsets.all(ExpatlioDesign.space16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // ─── SUBSCRIPTION REWORK ─────────
                                      // Was: "Текущий баланс" + "~ X минут".
                                      // Now: "Подписка" + active/expired hint.
                                      Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Подписка',
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'sf pro display',
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  fontSize: 15,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                          ),
                                          AuthUserStreamWidget(
                                            builder: (context) {
                                              final user = currentUserDocument;
                                              final active =
                                                  hasActiveSubscription(user);
                                              final hasGift =
                                                  hasUsableGiftMinutes(user);
                                              final String label;
                                              final bool highlight;
                                              if (active) {
                                                label = 'Активна';
                                                highlight = true;
                                              } else if (hasGift) {
                                                label = 'Подарок';
                                                highlight = true;
                                              } else {
                                                label = 'Не активна';
                                                highlight = false;
                                              }
                                              return Text(
                                                label,
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      fontFamily:
                                                          'sf pro display',
                                                      color: highlight
                                                          ? FlutterFlowTheme.of(
                                                                  context)
                                                              .primary
                                                          : FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      fontSize: 15,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      // ────────────────────────────────────
                                      // ─── SUBSCRIPTION REWORK ─────────
                                      // Was: big Expatlio counter.
                                      // Now: subscription expiry date or
                                      // "Нет активной подписки" copy.
                                      AuthUserStreamWidget(
                                        builder: (context) {
                                          final user = currentUserDocument;
                                          final active =
                                              hasActiveSubscription(user);
                                          final expires =
                                              subscriptionExpiresAt(user);
                                          if (active && expires != null) {
                                            return RichText(
                                              textScaler: MediaQuery.of(context)
                                                  .textScaler,
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'до ',
                                                    style: TextStyle(
                                                      fontFamily: 'Cool',
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      fontWeight:
                                                          FontWeight.w300,
                                                      fontSize: 22.0,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: formatExpiryDate(
                                                        expires),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          fontSize: 34.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w300,
                                                        ),
                                                  ),
                                                ],
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily: 'Cool',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          fontSize: 34.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.normal,
                                                        ),
                                              ),
                                            );
                                          }
                                          // Fallback: no subscription. Show
                                          // the unexpired gift bucket if any,
                                          // else "Нет активной подписки".
                                          final giftMinutes =
                                              remainingGiftMinutes(user);
                                          final giftExpiresAt =
                                              giftMinutesExpiresAt(user);
                                          if (giftMinutes > 0 &&
                                              giftExpiresAt != null) {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${formatGiftMinutes(giftMinutes)} мин в подарок',
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primary,
                                                        fontSize: 28,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                                const SizedBox(
                                                    height:
                                                        ExpatlioDesign.space4),
                                                Text(
                                                  'действуют ${formatGiftExpiry(giftExpiresAt)}',
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
                                              ],
                                            );
                                          }
                                          return Text(
                                            'Нет активной подписки',
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'sf pro display',
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  fontSize: 22.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                          );
                                        },
                                      ),
                                      // ────────────────────────────────────
                                      // ─── SUBSCRIPTION REWORK ─ promo CTA
                                      // Always visible so the user can top
                                      // up gift minutes any time.
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space12,
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space0),
                                        child: TextButton(
                                          onPressed: () async {
                                            await showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (_) =>
                                                  const PromoRedeemWidget(),
                                            );
                                            safeSetState(() {});
                                          },
                                          child: Text(
                                            'У меня есть промокод',
                                            style:
                                                ExpatlioDesign.buttonTextStyle(
                                              context,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // ────────────────────────────────────
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space24,
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space0),
                                        child: Container(
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            borderRadius: BorderRadius.circular(
                                                ExpatlioDesign.controlRadius),
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.all(
                                                ExpatlioDesign.space4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(16, 0, 12, 0),
                                                  child: Text(
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                      'nes89ax1' /* Пополнить */,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          fontSize: 16,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                  ),
                                                ),
                                                Container(
                                                  width: 41,
                                                  height: 41,
                                                  decoration: BoxDecoration(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryBackground,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Align(
                                                    alignment:
                                                        AlignmentDirectional(
                                                            0, 0),
                                                    child: Icon(
                                                      FFIcons.kchevronRight,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space8,
                              ExpatlioDesign.space12,
                              ExpatlioDesign.space8,
                              ExpatlioDesign.space0),
                          child: AuthUserStreamWidget(
                            builder: (context) {
                              final selectedPartnerLevel = currentUserDocument
                                  ?.preferences.preferredPartnerLevel;
                              final preferredLocation =
                                  _preferredLocation(currentUserDocument);

                              return Row(
                                children: [
                                  Expanded(
                                    child: DashboardInlineFilterButton(
                                      title: preferredLocation == null
                                          ? _localizedText(
                                              context: context,
                                              ruText: 'Локация',
                                              enText: 'Location',
                                            )
                                          : '',
                                      label: preferredLocation == null
                                          ? ''
                                          : _preferredLocationLabel(
                                              context,
                                              preferredLocation,
                                            ),
                                      selected: preferredLocation != null,
                                      icon: Icons.public_rounded,
                                      onTap: _openPreferredLocationPicker,
                                      onClear: preferredLocation == null
                                          ? null
                                          : () async {
                                              await _clearPreferredLocation();
                                              safeSetState(() {});
                                            },
                                    ),
                                  ),
                                  const SizedBox(width: ExpatlioDesign.space8),
                                  Expanded(
                                    child: DashboardInlineFilterButton(
                                      title: _localizedText(
                                        context: context,
                                        ruText: 'Уровень',
                                        enText: 'Level',
                                      ),
                                      label: selectedPartnerLevel == null
                                          ? _defaultPartnerLevelLabel(
                                              context,
                                              currentUserDocument,
                                            )
                                          : _levelFilterLabel(
                                              context,
                                              selectedPartnerLevel,
                                            ),
                                      selected: selectedPartnerLevel != null,
                                      icon: Icons.tune_rounded,
                                      onTap: _openPreferredPartnerLevelPicker,
                                      onClear: selectedPartnerLevel == null
                                          ? null
                                          : () async {
                                              await _setPreferredPartnerLevel(
                                                null,
                                              );
                                              safeSetState(() {});
                                            },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space40,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0),
                          child: Stack(
                            alignment: AlignmentDirectional(0, -1),
                            children: [
                              Image.asset(
                                'assets/images/group_11712750962.webp',
                                width: double.infinity,
                                height: 294.27,
                                fit: BoxFit.contain,
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    ExpatlioDesign.space64,
                                    ExpatlioDesign.space112,
                                    ExpatlioDesign.space64,
                                    ExpatlioDesign.space0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      FFLocalizations.of(context).getText(
                                        'a3nqo0ec' /* Найди собеседника
для практики */
                                        ,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            fontSize: 22.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            lineHeight: 1.1,
                                          ),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          ExpatlioDesign.space0,
                                          ExpatlioDesign.space12,
                                          ExpatlioDesign.space0,
                                          ExpatlioDesign.space0),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          'crtk35jr' /* Первая минута бесплатно! */,
                                        ),
                                        textAlign: TextAlign.center,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              fontSize: 15,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
                                            ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          ExpatlioDesign.space0,
                                          ExpatlioDesign.space32,
                                          ExpatlioDesign.space0,
                                          ExpatlioDesign.space0),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          // ─── SUBSCRIPTION REWORK ────
                                          // Gate by active subscription or gift
                                          // minutes instead of legacy balanceST.
                                          if (!canStartCall(
                                              currentUserDocument)) {
                                            // ──────────────────────────
                                            await showModalBottomSheet(
                                              useRootNavigator: true,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              context: context,
                                              builder: (context) {
                                                return GestureDetector(
                                                  onTap: () {
                                                    FocusScope.of(context)
                                                        .unfocus();
                                                    FocusManager
                                                        .instance.primaryFocus
                                                        ?.unfocus();
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        MediaQuery.viewInsetsOf(
                                                            context),
                                                    child: NoBalanceWidget(),
                                                  ),
                                                );
                                              },
                                            ).then(
                                                (value) => safeSetState(() {}));
                                            return;
                                          }

                                          if (!(await ensureCameraAndMicrophonePermissions())) {
                                            return;
                                          }

                                          if (!mounted) {
                                            return;
                                          }
                                          await _handleStartConversation(
                                            _searchState,
                                            _matchedSearchSessionId,
                                            false,
                                          );
                                        },
                                        child: Container(
                                          width: 233.9,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            gradient:
                                                ExpatlioDesign.primaryGradient,
                                            borderRadius: BorderRadius.circular(
                                                ExpatlioDesign.radiusLarge),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x227430E8),
                                                blurRadius: 18,
                                                offset: Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(20, 0, 20, 0),
                                              child: Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'flmz1vkr' /* Начать разговор */,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: Colors.white,
                                                          fontSize: 17,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (resolveFriendsForUser(currentUserDocument)
                            .isNotEmpty)
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space32,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: AuthUserStreamWidget(
                              builder: (context) => Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      context
                                          .pushNamed(FavoriteWidget.routeName);
                                    },
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              FFLocalizations.of(context)
                                                  .getText(
                                                'a4u0etcs' /* Друзья */,
                                              ),
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily: 'Cool',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        fontSize: 22.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                      ),
                                            ),
                                            Icon(
                                              FFIcons.kchevronRight,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              size: 18,
                                            ),
                                          ],
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
                                    child: Container(
                                      width: double.infinity,
                                      height: 180,
                                      decoration: BoxDecoration(),
                                      child: Builder(
                                        builder: (context) {
                                          final favs = resolveFriendsForUser(
                                                  currentUserDocument)
                                              .toList();

                                          return ListView.separated(
                                            padding: EdgeInsets.symmetric(
                                                horizontal:
                                                    ExpatlioDesign.space8),
                                            scrollDirection: Axis.horizontal,
                                            itemCount: favs.length,
                                            separatorBuilder: (_, __) =>
                                                SizedBox(
                                                    width:
                                                        ExpatlioDesign.space8),
                                            itemBuilder: (context, favsIndex) {
                                              final favsItem = favs[favsIndex];
                                              return FavWidget(
                                                key: Key(
                                                    'Keyy7d_${favsIndex}_of_${favs.length}'),
                                                nsUser: favsItem,
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space16,
                              ExpatlioDesign.space40,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0),
                          child: Text(
                            FFLocalizations.of(context).getText(
                              'lffx4k7x' /* Статистика за сегодня */,
                            ),
                            style: ExpatlioDesign.sectionTitleStyle(context)
                                .copyWith(
                              color: FlutterFlowTheme.of(context).primaryText,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space8,
                              ExpatlioDesign.space12,
                              ExpatlioDesign.space8,
                              ExpatlioDesign.space0),
                          child: StreamBuilder<List<StatsRecord>>(
                            stream: _model.statsStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return const SizedBox.shrink();
                              }
                              if (!snapshot.hasData) {
                                return Center(
                                  child: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: SpinKitCircle(
                                      color: FlutterFlowTheme.of(context)
                                          .secondary,
                                      size: 50,
                                    ),
                                  ),
                                );
                              }
                              List<StatsRecord>
                                  conditionalBuilderStatsRecordList =
                                  snapshot.data!;
                              final conditionalBuilderStatsRecord =
                                  conditionalBuilderStatsRecordList.isNotEmpty
                                      ? conditionalBuilderStatsRecordList.first
                                      : null;

                              return Builder(
                                builder: (context) {
                                  if (conditionalBuilderStatsRecord != null) {
                                    return Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        borderRadius: BorderRadius.circular(
                                            ExpatlioDesign.radiusExtraLarge),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(
                                            ExpatlioDesign.space16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      valueOrDefault<String>(
                                                        conditionalBuilderStatsRecord
                                                            .minutesToday
                                                            .toString(),
                                                        '0',
                                                      ),
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            fontFamily: 'Cool',
                                                            fontSize: 28.0,
                                                            letterSpacing: 0.0,
                                                          ),
                                                    ),
                                                    Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        '2dq1u1yc' /* Продолжительность звонков */,
                                                      ),
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 16,
                                                                letterSpacing:
                                                                    0.0,
                                                              ),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  width: 64,
                                                  height: 64,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius
                                                        .circular(ExpatlioDesign
                                                            .radiusExtraLarge),
                                                    border: Border.all(
                                                      color:
                                                          ExpatlioDesign.border,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    FFIcons.kclock,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText,
                                                    size: 20,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      valueOrDefault<String>(
                                                        conditionalBuilderStatsRecord
                                                            .callsToday
                                                            .toString(),
                                                        '0',
                                                      ),
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            fontFamily: 'Cool',
                                                            fontSize: 28.0,
                                                            letterSpacing: 0.0,
                                                          ),
                                                    ),
                                                    Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        'f4nn7fxp' /* Звонков всего */,
                                                      ),
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 16,
                                                                letterSpacing:
                                                                    0.0,
                                                              ),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  width: 64,
                                                  height: 64,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius
                                                        .circular(ExpatlioDesign
                                                            .radiusExtraLarge),
                                                    border: Border.all(
                                                      color:
                                                          ExpatlioDesign.border,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    FFIcons.kphone,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText,
                                                    size: 20,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ].divide(SizedBox(
                                              height: ExpatlioDesign.space16)),
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Container(
                                      width: double.infinity,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        borderRadius: BorderRadius.circular(
                                            ExpatlioDesign.radiusExtraLarge),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(
                                            ExpatlioDesign.space4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Image.asset(
                                              'assets/images/Group_21.png',
                                              width: 96,
                                              height: 96,
                                              fit: BoxFit.cover,
                                              alignment: Alignment(0, -1),
                                            ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(12, 0, 0, 0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                      'laxcndbb' /* Звонков ещё не было */,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          fontSize: 16,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(
                                                                0, 6, 0, 0),
                                                    child: Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        '0hw93aax' /* Самое время это исправить.
Нач... */
                                                        ,
                                                      ),
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 15.0,
                                                                letterSpacing:
                                                                    0.0,
                                                              ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ]
                        .addToStart(SizedBox(height: ExpatlioDesign.space56))
                        .addToEnd(SizedBox(height: ExpatlioDesign.space112)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardMenuOption<T> {
  const _DashboardMenuOption({
    required this.value,
    required this.label,
    this.selected = false,
  });

  final T value;
  final String label;
  final bool selected;
}
