import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '/flutter_flow/nav/nav.dart';

const int matchProtocolVersion = 2;

enum MatchCallKitEndDisposition {
  ignored,
  handledPending,
  endConnectedSession,
}

typedef MatchDocumentStream = Stream<Map<String, dynamic>?> Function(String id);
typedef MatchCallable = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> payload,
);
typedef MatchEndInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> payload,
);
typedef MatchTokenLoader = Future<Map<String, dynamic>> Function(
    String sessionId);
typedef MatchHeartbeatInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> payload,
);
typedef MatchNavigator = void Function({
  required String sessionId,
  required String roomUrl,
  required String meetingToken,
  String? roomName,
});
typedef MatchLifecycleStateReader = AppLifecycleState? Function();

String? _matchString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

Map<String, dynamic> _matchMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return const <String, dynamic>{};
    try {
      return _matchMap(jsonDecode(text));
    } catch (_) {
      return const <String, dynamic>{};
    }
  }
  return const <String, dynamic>{};
}

int _matchInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _matchDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is num) {
    final milliseconds = value > 10000000000 ? value.toInt() : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt());
  }
  final text = _matchString(value);
  if (text == null) return null;
  final numeric = num.tryParse(text);
  if (numeric != null) return _matchDateTime(numeric);
  return DateTime.tryParse(text);
}

class _MatchActionIntent {
  const _MatchActionIntent({
    required this.userId,
    required this.sessionId,
    required this.pairAttemptId,
    required this.action,
    required this.actionId,
    required this.expiresAt,
  });

  factory _MatchActionIntent.fromJson(Map<String, dynamic> data) {
    return _MatchActionIntent(
      userId: _matchString(data['userId']) ?? '',
      sessionId: _matchString(data['sessionId']) ?? '',
      pairAttemptId: _matchString(data['pairAttemptId']) ?? '',
      action: _matchString(data['action']) ?? '',
      actionId: _matchString(data['actionId']) ?? '',
      expiresAt: _matchDateTime(data['expiresAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String userId;
  final String sessionId;
  final String pairAttemptId;
  final String action;
  final String actionId;
  final DateTime expiresAt;

  String get pairKey => '$sessionId:$pairAttemptId';
  bool get isCompleteIdentity =>
      userId.isNotEmpty &&
      sessionId.isNotEmpty &&
      pairAttemptId.isNotEmpty &&
      action.isNotEmpty &&
      actionId.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userId': userId,
        'sessionId': sessionId,
        'pairAttemptId': pairAttemptId,
        'action': action,
        'actionId': actionId,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };
}

@visibleForTesting
String? matchLinkedSessionId(Map<String, dynamic> data) {
  for (final key in const [
    'currentSessionId',
    'matchedSessionId',
    'activeSessionId',
  ]) {
    final value = _matchString(data[key]);
    if (value != null) return value;
  }
  return null;
}

@immutable
class MatchSessionState {
  const MatchSessionState({
    required this.sessionId,
    required this.userId,
    required this.raw,
    required this.protocolVersion,
    required this.pairAttemptId,
    required this.status,
    required this.matchStage,
    required this.scenario,
    required this.hasTeacherParticipant,
    required this.role,
    required this.surface,
    required this.decision,
    required this.delivery,
    required this.deliveryFailureKind,
    required this.callKitId,
    required this.isParticipant,
  });

  factory MatchSessionState.fromData({
    required String sessionId,
    required String userId,
    required Map<String, dynamic> data,
  }) {
    final matchContext = _matchMap(data['matchContext']);
    final protocol = _matchMap(data['matchProtocol']);
    final participantStates = _matchMap(data['participantStates']);
    final participantRoles = _matchMap(data['participantRoles']);
    final participant = _matchMap(participantStates[userId]);
    final participantIds = data['participantIds'];
    final requesterId = _matchString(data['requesterId']) ??
        _matchString(data['studentId']) ??
        _matchString(matchContext['requesterId']);
    final responderId = _matchString(data['currentResponderId']) ??
        _matchString(data['responderId']) ??
        _matchString(data['currentTutorId']) ??
        _matchString(matchContext['currentResponderId']) ??
        _matchString(matchContext['selectedResponderId']) ??
        _matchString(matchContext['responderId']);
    final listedParticipant = participantIds is Iterable &&
        participantIds.any((value) => _matchString(value) == userId);
    final role = _matchString(participant['role']) ??
        (responderId == userId
            ? (_matchString(data['currentResponderRole']) ??
                _matchString(data['responderRole']) ??
                _matchString(matchContext['selectedResponderRole']) ??
                _matchString(matchContext['responderRole']))
            : (_matchString(data['requesterRole']) ??
                _matchString(matchContext['requesterRole'])));
    final hasTeacherParticipant = <dynamic>[
      ...participantRoles.values,
      ...participantStates.values.map(
        (value) => _matchMap(value)['role'],
      ),
    ].any((value) {
      final normalizedRole = (_matchString(value) ?? '').toLowerCase();
      return normalizedRole == 'native_speaker' || normalizedRole == 'teacher';
    });

    return MatchSessionState(
      sessionId: sessionId,
      userId: userId,
      raw: data,
      protocolVersion: _matchInt(data['matchProtocolVersion'] ??
          data['confirmationVersion'] ??
          protocol['version']),
      pairAttemptId: _matchString(data['pairAttemptId']) ??
          _matchString(matchContext['pairAttemptId']) ??
          _matchString(protocol['pairAttemptId']),
      status: (_matchString(data['status']) ?? '').toLowerCase(),
      matchStage: (_matchString(data['matchStage']) ?? '').toLowerCase(),
      scenario: (_matchString(data['scenario']) ?? '').toLowerCase(),
      hasTeacherParticipant: hasTeacherParticipant,
      role: (role ?? '').toLowerCase(),
      surface:
          (_matchString(participant['surface']) ?? 'pending').toLowerCase(),
      decision:
          (_matchString(participant['decision']) ?? 'pending').toLowerCase(),
      delivery: (_matchString(participant['delivery']) ?? 'not_required')
          .toLowerCase(),
      deliveryFailureKind:
          (_matchString(participant['deliveryFailureKind']) ?? '')
              .toLowerCase(),
      callKitId: _matchString(participant['callKitId']),
      isParticipant: participant.isNotEmpty ||
          listedParticipant ||
          requesterId == userId ||
          responderId == userId,
    );
  }

  final String sessionId;
  final String userId;
  final Map<String, dynamic> raw;
  final int protocolVersion;
  final String? pairAttemptId;
  final String status;
  final String matchStage;
  final String scenario;
  final bool hasTeacherParticipant;
  final String role;
  final String surface;
  final String decision;
  final String delivery;
  final String deliveryFailureKind;
  final String? callKitId;
  final bool isParticipant;

  bool get isV2 => protocolVersion >= matchProtocolVersion;
  bool get isTeacher => role == 'native_speaker' || role == 'teacher';
  bool get isTeacherMatch =>
      scenario == 'student_teacher' || hasTeacherParticipant;
  bool get canStudentClaimCurrentStage =>
      !isTeacherMatch ||
      const {'awaiting_student_dispatch', 'awaiting_acceptance'}
          .contains(matchStage);
  bool get isPending => status == 'pending_confirmation';
  bool get isJoinable => status == 'connecting' || status == 'active';
  bool get isLegacyJoinable => isJoinable || status == 'connected';
  bool get isAccepted => decision == 'accepted';
  bool get canRecoverFailedCallKit =>
      delivery == 'failed' && deliveryFailureKind == 'definitive';
  bool get isCallKitLocked =>
      !canRecoverFailedCallKit &&
      (surface == 'callkit' ||
          delivery == 'dispatching' ||
          delivery == 'sent' ||
          delivery == 'failed');
}

@visibleForTesting
bool matchShouldClaimInApp({
  required MatchSessionState session,
  required AppLifecycleState? lifecycleState,
  bool locallyLockedToCallKit = false,
}) {
  return session.isV2 &&
      session.isParticipant &&
      session.isPending &&
      session.pairAttemptId != null &&
      lifecycleState == AppLifecycleState.resumed &&
      !session.isTeacher &&
      session.canStudentClaimCurrentStage &&
      !session.isAccepted &&
      !session.isCallKitLocked &&
      !locallyLockedToCallKit &&
      session.surface != 'in_app';
}

@visibleForTesting
bool matchCanNavigate({
  required MatchSessionState session,
  required AppLifecycleState? lifecycleState,
  bool locallyAcceptedCallKit = false,
}) {
  if (!session.isParticipant || lifecycleState != AppLifecycleState.resumed) {
    return false;
  }
  if (!session.isV2 || !session.isJoinable) return false;
  if (session.isCallKitLocked &&
      !session.isAccepted &&
      !locallyAcceptedCallKit) {
    return false;
  }
  return true;
}

/// Owns matchmaking presentation and navigation. Firestore session state is
/// the source of truth; push delivery only chooses the presentation surface.
class MatchCoordinator extends ChangeNotifier with WidgetsBindingObserver {
  static const Duration searchHeartbeatInterval = Duration(seconds: 30);
  static const Duration networkRequestTimeout = Duration(seconds: 10);
  static const Duration actionIntentRetention = Duration(minutes: 2);
  static const Duration actionRetryDelay = Duration(seconds: 2);
  static const String _actionIntentPreferenceKey =
      'smalltalk.matchActionIntents.v2';
  static const List<Duration> navigationRetryDelays = <Duration>[
    Duration.zero,
    Duration(milliseconds: 250),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  MatchCoordinator._()
      : userStream = null,
        searchStream = null,
        sessionStream = null,
        respondInvoker = null,
        endInvoker = null,
        heartbeatInvoker = null,
        tokenLoader = null,
        navigator = null,
        lifecycleStateReader = null,
        heartbeatInterval = searchHeartbeatInterval,
        heartbeatTimeout = networkRequestTimeout,
        tokenLoadTimeout = networkRequestTimeout,
        actionRetryInterval = actionRetryDelay,
        tokenRetryDelays = navigationRetryDelays;

  @visibleForTesting
  MatchCoordinator.forTesting({
    this.userStream,
    this.searchStream,
    this.sessionStream,
    this.respondInvoker,
    this.endInvoker,
    this.heartbeatInvoker,
    this.tokenLoader,
    this.navigator,
    AppLifecycleState? initialLifecycleState,
    MatchLifecycleStateReader? lifecycleStateReader,
    this.heartbeatInterval = searchHeartbeatInterval,
    this.heartbeatTimeout = networkRequestTimeout,
    this.tokenLoadTimeout = networkRequestTimeout,
    this.actionRetryInterval = actionRetryDelay,
    List<Duration>? tokenRetryDelays,
  })  : lifecycleStateReader =
            lifecycleStateReader ?? (() => initialLifecycleState),
        tokenRetryDelays = tokenRetryDelays ?? navigationRetryDelays,
        _lifecycleState = initialLifecycleState;

  static final MatchCoordinator instance = MatchCoordinator._();

  final MatchDocumentStream? userStream;
  final MatchDocumentStream? searchStream;
  final MatchDocumentStream? sessionStream;
  final MatchCallable? respondInvoker;
  final MatchEndInvoker? endInvoker;
  final MatchHeartbeatInvoker? heartbeatInvoker;
  final MatchTokenLoader? tokenLoader;
  final MatchNavigator? navigator;
  final MatchLifecycleStateReader? lifecycleStateReader;
  final Duration heartbeatInterval;
  final Duration heartbeatTimeout;
  final Duration tokenLoadTimeout;
  final Duration actionRetryInterval;
  final List<Duration> tokenRetryDelays;

  StreamSubscription<Map<String, dynamic>?>? _userSubscription;
  StreamSubscription<Map<String, dynamic>?>? _searchSubscription;
  StreamSubscription<Map<String, dynamic>?>? _sessionSubscription;
  Future<void> _userOperationTail = Future<void>.value();
  int _userOperationGeneration = 0;
  String? _userId;
  String? _userLinkedSessionId;
  String? _searchLinkedSessionId;
  String? _activeV2SearchRequestId;
  String? _sessionId;
  int _sessionGeneration = 0;
  bool _observingLifecycle = false;
  AppLifecycleState? _lifecycleState;
  MatchSessionState? _session;
  Timer? _searchHeartbeatTimer;
  bool _searchHeartbeatInFlight = false;
  bool _searchHeartbeatPending = false;
  final Set<String> _claimInFlight = <String>{};
  final Set<String> _claimedPairs = <String>{};
  final Set<String> _callKitLockedPairs = <String>{};
  final Set<String> _locallyAcceptedPairs = <String>{};
  final Set<String> _locallyCancelledPairs = <String>{};
  final Set<String> _locallyCancelledSessionIds = <String>{};
  final Set<String> _locallyCancelledSearchRequestIds = <String>{};
  final Set<String> _navigationInFlight = <String>{};
  final Set<String> _navigatedPairs = <String>{};
  final Map<String, _MatchActionIntent> _actionIntents =
      <String, _MatchActionIntent>{};
  final Map<String, String> _actionRetryInFlight = <String, String>{};

  MatchSessionState? get currentSession => _session;
  AppLifecycleState? get lifecycleState => _lifecycleState;
  bool get hasCancellableV2Match {
    final session = _session;
    return session != null &&
        session.isV2 &&
        session.isParticipant &&
        (session.status == 'searching' ||
            session.isPending ||
            session.isJoinable);
  }

  String _pairKey(String sessionId, String? pairAttemptId) =>
      '$sessionId:${pairAttemptId ?? '*'}';

  Future<void> startForUser(String userId) {
    final normalizedUserId = _matchString(userId);
    if (normalizedUserId == null) return Future<void>.value();
    final generation = ++_userOperationGeneration;
    return _enqueueUserOperation(() async {
      if (generation != _userOperationGeneration ||
          _userId == normalizedUserId) {
        return;
      }
      await _stopState();
      if (generation != _userOperationGeneration) return;
      _userId = normalizedUserId;
      _lifecycleState = lifecycleStateReader?.call() ??
          WidgetsBinding.instance.lifecycleState;
      if (!_observingLifecycle) {
        WidgetsBinding.instance.addObserver(this);
        _observingLifecycle = true;
      }
      // Restore local decisions before cached Firestore snapshots can trigger
      // navigation or a competing in-app claim.
      await _restoreActionIntents(normalizedUserId);
      if (generation != _userOperationGeneration ||
          _userId != normalizedUserId) {
        return;
      }
      _userSubscription = _userDocumentStream(normalizedUserId).listen(
        _handleUserDocument,
        onError: (Object error) =>
            debugPrint('MatchCoordinator: user listener failed: $error'),
      );
      _searchSubscription = _searchDocumentStream(normalizedUserId).listen(
        _handleSearchDocument,
        onError: (Object error) =>
            debugPrint('MatchCoordinator: search listener failed: $error'),
      );
    });
  }

  Future<void> stop() {
    final generation = ++_userOperationGeneration;
    return _enqueueUserOperation(() async {
      if (generation != _userOperationGeneration) return;
      await _stopState();
    });
  }

  Future<void> _enqueueUserOperation(Future<void> Function() operation) {
    final result = _userOperationTail.then((_) => operation());
    _userOperationTail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('MatchCoordinator: user operation failed: $error');
      },
    );
    return result;
  }

  Future<void> _stopState() async {
    await _userSubscription?.cancel();
    await _searchSubscription?.cancel();
    await _sessionSubscription?.cancel();
    _userSubscription = null;
    _searchSubscription = null;
    _sessionSubscription = null;
    _userId = null;
    _userLinkedSessionId = null;
    _searchLinkedSessionId = null;
    _clearSearchHeartbeat();
    _sessionId = null;
    _session = null;
    _lifecycleState = null;
    _sessionGeneration += 1;
    _claimInFlight.clear();
    _claimedPairs.clear();
    _callKitLockedPairs.clear();
    _locallyAcceptedPairs.clear();
    _locallyCancelledPairs.clear();
    _locallyCancelledSessionIds.clear();
    _locallyCancelledSearchRequestIds.clear();
    _navigationInFlight.clear();
    _navigatedPairs.clear();
    _actionIntents.clear();
    _actionRetryInFlight.clear();
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
  }

  Stream<Map<String, dynamic>?> _userDocumentStream(String userId) {
    final override = userStream;
    if (override != null) return override(userId);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  Stream<Map<String, dynamic>?> _searchDocumentStream(String userId) {
    final override = searchStream;
    if (override != null) return override(userId);
    return FirebaseFirestore.instance
        .collection('searchRequests')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  Stream<Map<String, dynamic>?> _sessionDocumentStream(String sessionId) {
    final override = sessionStream;
    if (override != null) return override(sessionId);
    return FirebaseFirestore.instance
        .collection('videoSessions')
        .doc(sessionId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  void _handleUserDocument(Map<String, dynamic>? data) {
    _userLinkedSessionId = data == null ? null : matchLinkedSessionId(data);
    _reconcileLinkedSession();
  }

  void _handleSearchDocument(Map<String, dynamic>? data) {
    _searchLinkedSessionId = data == null ? null : matchLinkedSessionId(data);
    _reconcileSearchHeartbeat(data);
    _reconcileLinkedSession();
  }

  void _reconcileSearchHeartbeat(Map<String, dynamic>? data) {
    final requestId = data == null ? null : _matchString(data['requestId']);
    final status =
        data == null ? '' : (_matchString(data['status']) ?? '').toLowerCase();
    final ownerId = data == null ? null : _matchString(data['userId']);
    final isCurrentUser = ownerId == null || ownerId == _userId;
    final hasExactMatchedBinding = status == 'matched' &&
        matchLinkedSessionId(data ?? const <String, dynamic>{}) != null &&
        _matchString(data?['pairAttemptId']) != null;
    final isActiveV2 = data != null &&
        _matchInt(data['matchProtocolVersion']) >= matchProtocolVersion &&
        requestId != null &&
        isCurrentUser &&
        _matchString(data['stopReason']) == null &&
        (const {'active', 'matching', 'searching'}.contains(status) ||
            hasExactMatchedBinding);

    if (!isActiveV2) {
      _clearSearchHeartbeat();
      return;
    }
    if (_activeV2SearchRequestId == requestId) return;

    _clearSearchHeartbeat();
    _activeV2SearchRequestId = requestId;
    _searchHeartbeatTimer = Timer.periodic(
      heartbeatInterval,
      (_) => unawaited(_sendSearchHeartbeat(requestId)),
    );
    unawaited(_sendSearchHeartbeat(requestId));
  }

  void _clearSearchHeartbeat() {
    _searchHeartbeatTimer?.cancel();
    _searchHeartbeatTimer = null;
    _activeV2SearchRequestId = null;
    _searchHeartbeatInFlight = false;
    _searchHeartbeatPending = false;
  }

  String get _searchAppState {
    switch (_lifecycleState) {
      case AppLifecycleState.resumed:
        return 'foreground';
      case AppLifecycleState.inactive:
        return 'inactive';
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case null:
        return 'background';
    }
  }

  void _sendLifecycleSearchHeartbeat() {
    final requestId = _activeV2SearchRequestId;
    if (requestId == null) return;
    if (_searchHeartbeatInFlight) {
      _searchHeartbeatPending = true;
      return;
    }
    unawaited(_sendSearchHeartbeat(requestId));
  }

  Future<void> _sendSearchHeartbeat(String requestId) async {
    if (_searchHeartbeatInFlight ||
        _activeV2SearchRequestId != requestId ||
        _userId == null) {
      return;
    }

    _searchHeartbeatInFlight = true;
    var heartbeatStored = false;
    final payload = <String, dynamic>{
      'requestId': requestId,
      'appState': _searchAppState,
      'matchProtocolVersion': matchProtocolVersion,
    };
    try {
      final override = heartbeatInvoker;
      if (override != null) {
        final response = await override(payload).timeout(heartbeatTimeout);
        heartbeatStored =
            response['heartbeat'] == true || response['ok'] == true;
      } else {
        final response = await FirebaseFunctions.instance
            .httpsCallable('heartbeatSearch')
            .call(payload)
            .timeout(heartbeatTimeout);
        heartbeatStored = _matchMap(response.data)['heartbeat'] == true;
      }
    } catch (error) {
      debugPrint('MatchCoordinator: search heartbeat failed: $error');
    } finally {
      if (_activeV2SearchRequestId == requestId) {
        _searchHeartbeatInFlight = false;
        if (_searchHeartbeatPending) {
          _searchHeartbeatPending = false;
          unawaited(_sendSearchHeartbeat(requestId));
        }
        if (heartbeatStored) {
          unawaited(_evaluateSession());
        }
      }
    }
  }

  void _reconcileLinkedSession() {
    final linkedSessionId = _userLinkedSessionId ?? _searchLinkedSessionId;
    if (linkedSessionId != null) {
      _watchSession(linkedSessionId);
      return;
    }
    _unwatchSession();
  }

  void _unwatchSession() {
    if (_sessionId == null && _session == null) return;
    final previousSessionId = _sessionId;
    _sessionId = null;
    _session = null;
    _sessionGeneration += 1;
    unawaited(_sessionSubscription?.cancel());
    _sessionSubscription = null;
    if (previousSessionId != null) {
      _locallyCancelledSessionIds.remove(previousSessionId);
    }
    notifyListeners();
  }

  void _watchSession(String sessionId) {
    final normalized = _matchString(sessionId);
    if (normalized == null || _sessionId == normalized) return;
    _sessionId = normalized;
    _session = null;
    final generation = ++_sessionGeneration;
    unawaited(_sessionSubscription?.cancel());
    _sessionSubscription = _sessionDocumentStream(normalized).listen(
      (data) {
        if (generation != _sessionGeneration || data == null) return;
        _handleSessionData(normalized, data);
      },
      onError: (Object error) =>
          debugPrint('MatchCoordinator: session listener failed: $error'),
    );
  }

  void _handleSessionData(String sessionId, Map<String, dynamic> data) {
    final userId = _userId;
    if (userId == null) return;
    _session = MatchSessionState.fromData(
      sessionId: sessionId,
      userId: userId,
      data: data,
    );
    _reconcileActionIntent(_session!);
    notifyListeners();
    unawaited(_evaluateSession());
  }

  void _reconcileActionIntent(MatchSessionState session) {
    final pairKey = _pairKey(session.sessionId, session.pairAttemptId);
    final intent = _actionIntents[pairKey];
    if (intent == null) return;
    final terminal = const <String>{
      'cancelled',
      'ended',
      'expired',
      'failed',
      'completed',
    }.contains(session.status);
    final accepted = intent.action == 'accept' && session.isAccepted;
    if (!terminal && !accepted) return;
    unawaited(_removeActionIntentIfCurrent(
      intent,
      clearLocalAccept: terminal && !session.isJoinable,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previousSearchAppState = _searchAppState;
    _lifecycleState = state;
    if (_searchAppState != previousSearchAppState) {
      _sendLifecycleSearchHeartbeat();
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_evaluateSession());
    }
  }

  Future<void> _evaluateSession() async {
    final session = _session;
    if (session == null) return;
    final pairKey = _pairKey(session.sessionId, session.pairAttemptId);
    if (_locallyCancelledPairs.contains(pairKey) ||
        _locallyCancelledSessionIds.contains(session.sessionId) ||
        _searchWasLocallyCancelled(session)) {
      return;
    }
    if (matchShouldClaimInApp(
      session: session,
      lifecycleState: _lifecycleState,
      locallyLockedToCallKit: _callKitLockedPairs.contains(pairKey),
    )) {
      // A matched request must have a fresh foreground heartbeat before the
      // server can atomically grant the in-app surface. Let the heartbeat
      // finish first; its success re-evaluates this exact session below.
      if (_searchHeartbeatInFlight) return;
      if (!_claimedPairs.contains(pairKey) && _claimInFlight.add(pairKey)) {
        try {
          final response = await _respond(
            session: session,
            action: 'claim_in_app',
          );
          final ok = response['ok'] == true;
          final stale = response['stale'] == true;
          final reason = _matchString(response['reason']);
          if (ok && !stale && reason != 'surface_locked') {
            _claimedPairs.add(pairKey);
          }
        } catch (error) {
          debugPrint('MatchCoordinator: claim_in_app failed: $error');
        } finally {
          _claimInFlight.remove(pairKey);
        }
      }
      return;
    }

    if (matchCanNavigate(
      session: session,
      lifecycleState: _lifecycleState,
      locallyAcceptedCallKit: _locallyAcceptedPairs.contains(pairKey),
    )) {
      await _navigateWhenReady(session);
    }
  }

  Future<Map<String, dynamic>> _respond({
    required MatchSessionState session,
    required String action,
    String? actionId,
  }) {
    final pairAttemptId = session.pairAttemptId;
    if (!session.isV2 || pairAttemptId == null) {
      throw StateError('respondToMatch requires a v2 pair attempt');
    }
    final payload = <String, dynamic>{
      'sessionId': session.sessionId,
      'pairAttemptId': pairAttemptId,
      'action': action,
      'actionId': actionId ?? const Uuid().v4(),
    };
    final override = respondInvoker;
    if (override != null) return override(payload);
    return FirebaseFunctions.instance
        .httpsCallable('respondToMatch')
        .call(payload)
        .then((result) => _matchMap(result.data));
  }

  int _actionIntentPriority(String action) {
    switch (action) {
      case 'decline':
      case 'cancel':
      case 'end_session':
        return 3;
      case 'accept':
        return 2;
      case 'timeout':
        return 1;
      default:
        return 0;
    }
  }

  bool _isDefinitiveActionFailure(Object error) {
    if (error is! FirebaseFunctionsException) return false;
    return const <String>{
      'invalid-argument',
      'unauthenticated',
      'permission-denied',
      'not-found',
    }.contains(error.code);
  }

  DateTime _intentExpiryForAction(
    String action,
    Map<String, dynamic> payload,
  ) {
    final now = DateTime.now();
    if (action == 'accept') {
      final extra = _matchMap(payload['extra']);
      final payloadExpiry = _matchDateTime(
        extra['expiresAt'] ?? payload['expiresAt'],
      );
      if (payloadExpiry != null && payloadExpiry.isAfter(now)) {
        return payloadExpiry;
      }
    }
    return now.add(actionIntentRetention);
  }

  Future<_MatchActionIntent> _rememberActionIntent({
    required MatchSessionState session,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final pairAttemptId = session.pairAttemptId!;
    final pairKey = _pairKey(session.sessionId, pairAttemptId);
    final existing = _actionIntents[pairKey];
    if (existing != null &&
        _actionIntentPriority(existing.action) >
            _actionIntentPriority(action)) {
      return existing;
    }
    if (existing != null && existing.action == action) return existing;

    final intent = _MatchActionIntent(
      userId: session.userId,
      sessionId: session.sessionId,
      pairAttemptId: pairAttemptId,
      action: action,
      actionId: const Uuid().v4(),
      expiresAt: _intentExpiryForAction(action, payload),
    );
    _actionIntents[pairKey] = intent;
    await _persistActionIntents();
    return intent;
  }

  Future<void> _persistActionIntents() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = <String, dynamic>{
        for (final entry in _actionIntents.entries)
          entry.key: entry.value.toJson(),
      };
      await preferences.setString(
        _actionIntentPreferenceKey,
        jsonEncode(encoded),
      );
    } catch (error) {
      debugPrint('MatchCoordinator: failed to persist action intents: $error');
    }
  }

  Future<void> _restoreActionIntents(String userId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final stored = preferences.getString(_actionIntentPreferenceKey);
      if (stored == null) return;
      final decoded = _matchMap(jsonDecode(stored));
      final now = DateTime.now();
      for (final value in decoded.values) {
        final intent = _MatchActionIntent.fromJson(_matchMap(value));
        if (!intent.isCompleteIdentity ||
            intent.userId != userId ||
            !intent.expiresAt.isAfter(now)) {
          continue;
        }
        _actionIntents[intent.pairKey] = intent;
        if (intent.action == 'accept') {
          _locallyAcceptedPairs.add(intent.pairKey);
        } else if (const {'cancel', 'decline', 'end_session', 'timeout'}
            .contains(intent.action)) {
          _locallyCancelledPairs.add(intent.pairKey);
          _locallyCancelledSessionIds.add(intent.sessionId);
        }
        _scheduleActionIntentRetry(intent);
      }
      await _persistActionIntents();
    } catch (error) {
      debugPrint('MatchCoordinator: failed to restore action intents: $error');
    }
  }

  Future<void> _removeActionIntentIfCurrent(
    _MatchActionIntent intent, {
    bool clearLocalAccept = false,
  }) async {
    final current = _actionIntents[intent.pairKey];
    if (current?.actionId != intent.actionId) return;
    _actionIntents.remove(intent.pairKey);
    if (clearLocalAccept) {
      _locallyAcceptedPairs.remove(intent.pairKey);
    }
    await _persistActionIntents();
  }

  Future<Map<String, dynamic>> _invokeActionIntent(
    _MatchActionIntent intent,
  ) async {
    if (intent.action == 'end_session') {
      return _endSessionById(
        intent.sessionId,
        actionId: intent.actionId,
      ).timeout(networkRequestTimeout);
    }
    final payload = <String, dynamic>{
      'sessionId': intent.sessionId,
      'pairAttemptId': intent.pairAttemptId,
      'action': intent.action,
      'actionId': intent.actionId,
    };
    final override = respondInvoker;
    if (override != null) {
      return override(payload).timeout(networkRequestTimeout);
    }
    return FirebaseFunctions.instance
        .httpsCallable('respondToMatch')
        .call(payload)
        .timeout(networkRequestTimeout)
        .then((result) => _matchMap(result.data));
  }

  Future<void> _handleActionIntentResponse(
    _MatchActionIntent intent,
    Map<String, dynamic> response, {
    bool endConnectingForCancel = true,
  }) async {
    final status = (_matchString(response['status']) ?? '').toLowerCase();
    if (endConnectingForCancel &&
        intent.action == 'cancel' &&
        const {'connecting', 'active', 'connected'}.contains(status)) {
      final session = MatchSessionState.fromData(
        sessionId: intent.sessionId,
        userId: intent.userId,
        data: <String, dynamic>{
          'matchProtocolVersion': matchProtocolVersion,
          'pairAttemptId': intent.pairAttemptId,
          'status': status,
          'participantIds': <String>[intent.userId],
          'participantStates': <String, dynamic>{
            intent.userId: const <String, dynamic>{
              'decision': 'accepted',
              'surface': 'callkit',
              'delivery': 'sent',
            },
          },
        },
      );
      await _endConnectingSession(
        session,
        actionId: intent.actionId,
      ).timeout(networkRequestTimeout);
    }
    await _removeActionIntentIfCurrent(
      intent,
      clearLocalAccept: intent.action == 'accept' &&
          (response['stale'] == true || response['ok'] == false),
    );
  }

  Future<Map<String, dynamic>?> _submitActionIntent(
    _MatchActionIntent intent, {
    bool endConnectingForCancel = true,
  }) async {
    try {
      final response = await _invokeActionIntent(intent);
      await _handleActionIntentResponse(
        intent,
        response,
        endConnectingForCancel: endConnectingForCancel,
      );
      return response;
    } catch (error) {
      if (_isDefinitiveActionFailure(error)) {
        await _removeActionIntentIfCurrent(
          intent,
          clearLocalAccept: intent.action == 'accept',
        );
        rethrow;
      }
      debugPrint(
        'MatchCoordinator: ${intent.action} outcome unknown; retrying: $error',
      );
      _scheduleActionIntentRetry(intent);
      return null;
    }
  }

  void _scheduleActionIntentRetry(_MatchActionIntent intent) {
    if (_actionRetryInFlight[intent.pairKey] == intent.actionId) return;
    _actionRetryInFlight[intent.pairKey] = intent.actionId;
    unawaited(() async {
      try {
        while (_userId == intent.userId &&
            DateTime.now().isBefore(intent.expiresAt)) {
          await Future<void>.delayed(actionRetryInterval);
          final current = _actionIntents[intent.pairKey];
          if (current?.actionId != intent.actionId ||
              _userId != intent.userId) {
            return;
          }
          try {
            final response = await _invokeActionIntent(intent);
            await _handleActionIntentResponse(intent, response);
            return;
          } catch (error) {
            if (_isDefinitiveActionFailure(error)) {
              await _removeActionIntentIfCurrent(
                intent,
                clearLocalAccept: intent.action == 'accept',
              );
              return;
            }
            debugPrint(
              'MatchCoordinator: retry for ${intent.action} failed: $error',
            );
          }
        }
        await _removeActionIntentIfCurrent(
          intent,
          clearLocalAccept: intent.action == 'accept',
        );
      } finally {
        if (_actionRetryInFlight[intent.pairKey] == intent.actionId) {
          _actionRetryInFlight.remove(intent.pairKey);
        }
      }
    }());
  }

  Future<Map<String, dynamic>> _endConnectingSession(
    MatchSessionState session, {
    String? actionId,
  }) =>
      _endSessionById(session.sessionId, actionId: actionId);

  Future<Map<String, dynamic>> _endSessionById(
    String sessionId, {
    String? actionId,
  }) {
    final payload = <String, dynamic>{
      'sessionId': sessionId,
      'endReason': 'user_cancelled_connecting',
      if (actionId != null) 'actionId': actionId,
    };
    final override = endInvoker;
    if (override != null) return override(payload);
    return FirebaseFunctions.instance
        .httpsCallable('endSession')
        .call(payload)
        .then((result) => _matchMap(result.data));
  }

  Future<bool> handleCallKitAccept(Map<String, dynamic> payload) async {
    final parsed = _sessionFromCallKitPayload(payload);
    if (parsed == null) return false;
    final pairKey = _pairKey(parsed.sessionId, parsed.pairAttemptId);
    _callKitLockedPairs.add(pairKey);
    _locallyAcceptedPairs.add(pairKey);
    _watchSession(parsed.sessionId);
    final intent = await _rememberActionIntent(
      session: parsed,
      action: 'accept',
      payload: payload,
    );
    if (intent.action != 'accept') {
      _locallyAcceptedPairs.remove(pairKey);
      return false;
    }
    final response = await _submitActionIntent(intent);
    if (response == null) return true;
    if (response['stale'] == true || response['ok'] == false) {
      _locallyAcceptedPairs.remove(pairKey);
      return false;
    }
    return true;
  }

  Future<bool> handleCallKitDecline(Map<String, dynamic> payload) async {
    final parsed = _sessionFromCallKitPayload(payload);
    if (parsed == null) return false;
    _markLocallyCancelled(parsed);
    _watchSession(parsed.sessionId);
    final intent = await _rememberActionIntent(
      session: parsed,
      action: 'decline',
      payload: payload,
    );
    final response = await _submitActionIntent(intent);
    return response == null || response['ok'] != false;
  }

  Future<bool> handleCallKitTimeout(Map<String, dynamic> payload) async {
    final parsed = _sessionFromCallKitPayload(payload);
    if (parsed == null) return false;
    final pairKey = _pairKey(parsed.sessionId, parsed.pairAttemptId);
    final existingIntent = _actionIntents[pairKey];
    if (_locallyAcceptedPairs.contains(pairKey) ||
        existingIntent?.action == 'accept') {
      _callKitLockedPairs.add(pairKey);
      _watchSession(parsed.sessionId);
      return true;
    }
    if (existingIntent != null &&
        _actionIntentPriority(existingIntent.action) >
            _actionIntentPriority('timeout')) {
      _markLocallyCancelled(parsed);
      _watchSession(parsed.sessionId);
      return true;
    }

    // A system timeout is terminal for this participant. Install the local
    // barrier before the first await so a delayed connecting snapshot cannot
    // navigate while the server response is still in flight.
    _markLocallyCancelled(parsed);
    _watchSession(parsed.sessionId);
    final intent = await _rememberActionIntent(
      session: parsed,
      action: 'timeout',
      payload: payload,
    );
    if (intent.action != 'timeout') return true;
    final response = await _submitActionIntent(intent);
    return response == null ||
        (response['stale'] != true && response['ok'] != false);
  }

  Future<MatchCallKitEndDisposition> handleCallKitEnd(
    Map<String, dynamic> payload,
  ) async {
    final parsed = _sessionFromCallKitPayload(payload);
    if (parsed == null) return MatchCallKitEndDisposition.ignored;
    _markLocallyCancelled(parsed);
    _watchSession(parsed.sessionId);
    final intent = await _rememberActionIntent(
      session: parsed,
      action: 'cancel',
      payload: payload,
    );
    await _submitActionIntent(intent);
    return MatchCallKitEndDisposition.handledPending;
  }

  Future<bool> cancelCurrentMatch() async {
    final session = _session;
    if (session == null || !hasCancellableV2Match) return false;
    _markLocallyCancelled(session);
    try {
      if (session.isJoinable) {
        final intent = await _rememberActionIntent(
          session: session,
          action: 'end_session',
          payload: const <String, dynamic>{},
        );
        final response = await _submitActionIntent(intent);
        if (response == null) return true;
        return response['ok'] != false;
      }
      final intent = await _rememberActionIntent(
        session: session,
        action: 'cancel',
        payload: const <String, dynamic>{},
      );
      final response = await _submitActionIntent(intent);
      return response == null || response['ok'] != false;
    } catch (error) {
      debugPrint('MatchCoordinator: cancel failed: $error');
      return false;
    }
  }

  void _markLocallyCancelled(MatchSessionState session) {
    final pairKey = _pairKey(session.sessionId, session.pairAttemptId);
    _callKitLockedPairs.add(pairKey);
    _locallyAcceptedPairs.remove(pairKey);
    _locallyCancelledPairs.add(pairKey);
    _locallyCancelledSessionIds.add(session.sessionId);
  }

  /// Prevents a session already cancelled by the UI from navigating while the
  /// coordinator's Firestore listener catches up with the dashboard snapshot.
  void noteLocalCancellation(String sessionId) {
    final normalized = _matchString(sessionId);
    if (normalized != null) {
      _locallyCancelledSessionIds.add(normalized);
    }
  }

  /// Stop can precede the transaction that creates a passive responder's
  /// session. Bind cancellation to the consent/request id before a session id
  /// exists, so later user/session snapshots cannot start navigation.
  void noteLocalSearchCancellation(String requestId) {
    final normalized = _matchString(requestId);
    if (normalized != null) _locallyCancelledSearchRequestIds.add(normalized);
  }

  bool isSearchLocallyCancelled(String requestId) =>
      _locallyCancelledSearchRequestIds.contains(requestId);

  bool _searchWasLocallyCancelled(MatchSessionState session) {
    final requesterId = _matchString(session.raw['requesterId']) ??
        _matchString(session.raw['studentId']);
    final ids = _matchMap(session.raw['searchRequestIds']);
    final requestId = _matchString(
        ids[requesterId == session.userId ? 'requester' : 'responder']);
    return requestId != null &&
        _locallyCancelledSearchRequestIds.contains(requestId);
  }

  void noteIncomingCallKit(Map<String, dynamic> payload) {
    final sessionId = _payloadString(payload, 'sessionId');
    if (sessionId == null) return;
    final pairAttemptId = _payloadString(payload, 'pairAttemptId');
    _callKitLockedPairs.add(_pairKey(sessionId, pairAttemptId));
    _watchSession(sessionId);
  }

  void noteIncomingInApp(Map<String, dynamic> payload) {
    final sessionId = _payloadString(payload, 'sessionId');
    if (sessionId != null) _watchSession(sessionId);
  }

  MatchSessionState? _sessionFromCallKitPayload(Map<String, dynamic> payload) {
    final version = _matchInt(_payloadValue(payload, 'matchProtocolVersion') ??
        _payloadValue(payload, 'confirmationVersion'));
    final acceptMode = _payloadString(payload, 'acceptMode')?.toLowerCase();
    final sessionId = _payloadString(payload, 'sessionId');
    final pairAttemptId = _payloadString(payload, 'pairAttemptId');
    if (sessionId == null ||
        pairAttemptId == null ||
        (version < matchProtocolVersion && acceptMode != 'respond_to_match')) {
      return null;
    }
    final userId = _userId ?? _payloadString(payload, 'recipientId') ?? '';
    return MatchSessionState.fromData(
      sessionId: sessionId,
      userId: userId,
      data: <String, dynamic>{
        'matchProtocolVersion': matchProtocolVersion,
        'pairAttemptId': pairAttemptId,
        'status': 'pending_confirmation',
        'participantStates': {
          userId: {
            'role': _payloadString(payload, 'responderRole') ?? '',
            'surface': 'callkit',
            'decision': 'pending',
            'delivery': 'sent',
            'callKitId': _payloadString(payload, 'callKitId'),
          },
        },
      },
    );
  }

  dynamic _payloadValue(Map<String, dynamic> payload, String key) {
    final extra = _matchMap(payload['extra']);
    return extra[key] ?? payload[key];
  }

  String? _payloadString(Map<String, dynamic> payload, String key) =>
      _matchString(_payloadValue(payload, key));

  Future<Map<String, dynamic>> _loadTokens(String sessionId) {
    final override = tokenLoader;
    if (override != null) return override(sessionId);
    return FirebaseFunctions.instance.httpsCallable('getSessionTokens').call(
        {'sessionId': sessionId}).then((result) => _matchMap(result.data));
  }

  Future<void> _navigateWhenReady(MatchSessionState session) async {
    final pairKey = _pairKey(session.sessionId, session.pairAttemptId);
    if (_navigatedPairs.contains(pairKey) ||
        !_navigationInFlight.add(pairKey)) {
      return;
    }
    Object? lastTokenError;
    try {
      for (final retryDelay in tokenRetryDelays) {
        if (retryDelay > Duration.zero) {
          await Future<void>.delayed(retryDelay);
        }
        final beforeLoad = _currentNavigableSession(
          session: session,
          pairKey: pairKey,
        );
        if (beforeLoad == null) return;

        Map<String, dynamic> credentials;
        try {
          credentials = await _loadTokens(session.sessionId).timeout(
            tokenLoadTimeout,
          );
        } catch (error) {
          lastTokenError = error;
          continue;
        }

        final current = _currentNavigableSession(
          session: session,
          pairKey: pairKey,
        );
        if (current == null) return;
        final roomUrl = _matchString(credentials['roomUrl']) ??
            _matchString(current.raw['dailyRoomUrl']);
        final meetingToken = _matchString(credentials['meetingToken']);
        final roomName = _matchString(credentials['roomName']) ??
            _matchString(current.raw['dailyRoomName']);
        if (roomUrl == null || meetingToken == null) {
          lastTokenError = StateError('session credentials are incomplete');
          continue;
        }
        final override = navigator;
        if (override != null) {
          override(
            sessionId: current.sessionId,
            roomUrl: roomUrl,
            meetingToken: meetingToken,
            roomName: roomName,
          );
        } else {
          final context = appNavigatorKey.currentContext;
          if (context == null) return;
          final router = GoRouter.of(context);
          final params = <String, String>{
            'videoDocRef': current.sessionId,
            'roomUrl': roomUrl,
            'meetingToken': meetingToken,
            if (roomName != null) 'roomName': roomName,
          };
          final target = Uri(
            path: '/videoCallPage',
            queryParameters: params,
          ).toString();
          if (!router.getCurrentLocation().startsWith('/videoCallPage')) {
            router.go(target);
          }
        }
        _navigatedPairs.add(pairKey);
        return;
      }
      if (lastTokenError != null) {
        debugPrint(
          'MatchCoordinator: navigation preparation failed after retries: '
          '$lastTokenError',
        );
      }
    } catch (error) {
      debugPrint('MatchCoordinator: navigation failed: $error');
    } finally {
      _navigationInFlight.remove(pairKey);
    }
  }

  MatchSessionState? _currentNavigableSession({
    required MatchSessionState session,
    required String pairKey,
  }) {
    final current = _session;
    if (current == null ||
        _locallyCancelledPairs.contains(pairKey) ||
        _locallyCancelledSessionIds.contains(session.sessionId) ||
        _searchWasLocallyCancelled(current) ||
        current.sessionId != session.sessionId ||
        current.pairAttemptId != session.pairAttemptId ||
        !matchCanNavigate(
          session: current,
          lifecycleState: _lifecycleState,
          locallyAcceptedCallKit: _locallyAcceptedPairs.contains(pairKey),
        )) {
      return null;
    }
    return current;
  }

  @visibleForTesting
  void debugHandleSession(String sessionId, Map<String, dynamic> data) {
    _handleSessionData(sessionId, data);
  }

  @visibleForTesting
  void debugSetLifecycleState(AppLifecycleState state) {
    didChangeAppLifecycleState(state);
  }
}
