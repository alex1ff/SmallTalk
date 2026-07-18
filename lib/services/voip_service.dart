import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

// Импорт для навигации и backend
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/nav/nav.dart';
import '/flutter_flow/permissions_util.dart';

const int _incomingCallTimeoutMilliseconds = 45000;
const String _videoCallRoutePath = '/videoCallPage';

String? _voipNonEmptyString(dynamic value) {
  if (value == null) return null;
  final trimmed = value.toString().trim();
  return trimmed.isEmpty ? null : trimmed;
}

Map<String, dynamic> _voipMapFrom(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return <String, dynamic>{};
    try {
      return _voipMapFrom(jsonDecode(trimmed));
    } catch (_) {
      return <String, dynamic>{};
    }
  }
  return <String, dynamic>{};
}

const List<String> _voipIncomingCallExtraKeys = <String>[
  'type',
  'sessionId',
  'callerName',
  'callerId',
  'callerPhoto',
  'studentName',
  'studentId',
  'studentPhoto',
  'language',
  'scenario',
  'recipientId',
  'requesterId',
  'responderId',
  'requesterRole',
  'responderRole',
  'navRole',
  'acceptMode',
  'callKitId',
  'notificationId',
  'searchRequestId',
  'expiresAt',
  'roomUrl',
  'meetingToken',
  'roomName',
  'tokenStrategy',
];

Map<String, dynamic> voipIncomingCallExtraDataFromPayload(
  Map<String, dynamic> payload,
) {
  final extra = <String, dynamic>{};
  for (final key in _voipIncomingCallExtraKeys) {
    if (payload.containsKey(key) && payload[key] != null) {
      extra[key] = payload[key];
    }
  }
  return extra;
}

@visibleForTesting
Map<String, dynamic> voipBuildCallKitExtraData({
  required String sessionId,
  required String callerId,
  required String callKitId,
  Map<String, dynamic>? extraData,
}) {
  return <String, dynamic>{
    ...?extraData,
    'sessionId': sessionId,
    'callKitId': callKitId,
    'callerId': callerId,
  };
}

@visibleForTesting
class VoipRoomCredentials {
  const VoipRoomCredentials({
    required this.roomUrl,
    this.meetingToken,
    this.roomName,
  });

  final String roomUrl;
  final String? meetingToken;
  final String? roomName;
}

@visibleForTesting
enum VoipAcceptGateDecision {
  proceed,
  duplicateTimeWindow,
  duplicateCallKitId,
  alreadyAccepted,
  acceptInProgress,
}

@visibleForTesting
enum VoipAcceptPayloadAction {
  acceptCall,
  openSession,
}

dynamic _voipValueFromPayload(Map<String, dynamic> data, String key) {
  final extra = _voipMapFrom(data['extra']);
  final extraValue = extra[key];
  if (extraValue != null && _voipNonEmptyString(extraValue) != null) {
    return extraValue;
  }
  return data[key];
}

String? _voipStringFromPayload(Map<String, dynamic> data, String key) {
  return _voipNonEmptyString(_voipValueFromPayload(data, key));
}

DateTime? _voipDateTimeFromPayloadValue(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return parsed;
    final millis = int.tryParse(trimmed);
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  try {
    final dynamic dynamicValue = value;
    final converted = dynamicValue.toDate();
    if (converted is DateTime) {
      return converted;
    }
  } catch (_) {
    return null;
  }

  return null;
}

@visibleForTesting
VoipAcceptPayloadAction voipAcceptActionFromPayload(
  Map<String, dynamic> data,
) {
  if (voipRoomUrlFromAcceptPayload(data) != null) {
    return VoipAcceptPayloadAction.openSession;
  }

  final acceptMode = _voipStringFromPayload(data, 'acceptMode')?.toLowerCase();
  final tokenStrategy =
      _voipStringFromPayload(data, 'tokenStrategy')?.toLowerCase();
  if (acceptMode == 'open_session' ||
      tokenStrategy == 'payload_room' ||
      tokenStrategy == 'get_session_tokens') {
    return VoipAcceptPayloadAction.openSession;
  }

  return VoipAcceptPayloadAction.acceptCall;
}

@visibleForTesting
bool voipIncomingCallPayloadHasExpired(
  Map<String, dynamic> data, {
  DateTime? now,
}) {
  final parsedExpiresAt = _voipDateTimeFromPayloadValue(
    _voipValueFromPayload(data, 'expiresAt'),
  );
  if (parsedExpiresAt == null) {
    return false;
  }

  return !parsedExpiresAt.isAfter(now ?? DateTime.now());
}

@visibleForTesting
bool voipIncomingCallShouldUseInAppNavigation(
  Map<String, dynamic> data, {
  AppLifecycleState? lifecycleState,
}) {
  final isForeground = lifecycleState == AppLifecycleState.resumed ||
      lifecycleState == AppLifecycleState.inactive;
  if (!isForeground) {
    return false;
  }

  return true;
}

Iterable<dynamic> _voipActiveCallEntries(dynamic activeCalls) {
  if (activeCalls is Iterable) {
    return activeCalls;
  }
  if (activeCalls is Map) {
    return <dynamic>[activeCalls];
  }
  if (activeCalls is String) {
    final trimmed = activeCalls.trim();
    if (trimmed.isEmpty) return const <dynamic>[];
    try {
      return _voipActiveCallEntries(jsonDecode(trimmed));
    } catch (_) {
      return const <dynamic>[];
    }
  }
  return const <dynamic>[];
}

bool _voipBoolFrom(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

bool _voipIsAcceptedActiveCall(Map<String, dynamic> callData) {
  return _voipBoolFrom(callData['isAccepted']) ||
      _voipBoolFrom(callData['accepted']);
}

@visibleForTesting
Map<String, dynamic>? voipAcceptDataFromActiveCall(dynamic activeCall) {
  final callData = _voipMapFrom(activeCall);
  if (callData.isEmpty || !_voipIsAcceptedActiveCall(callData)) {
    return null;
  }

  final extra = _voipMapFrom(callData['extra']);
  final sessionId = _voipNonEmptyString(extra['sessionId']) ??
      _voipNonEmptyString(callData['sessionId']);
  if (sessionId == null) return null;

  final callKitId = _voipNonEmptyString(callData['id']) ??
      _voipNonEmptyString(callData['uuid']) ??
      _voipNonEmptyString(extra['callKitId']) ??
      _voipNonEmptyString(callData['callKitId']);
  final normalizedExtra = <String, dynamic>{
    ...extra,
    'sessionId': sessionId,
    if (callKitId != null) 'callKitId': callKitId,
  };

  return <String, dynamic>{
    ...callData,
    'sessionId': sessionId,
    if (callKitId != null) 'id': callKitId,
    'extra': normalizedExtra,
  };
}

@visibleForTesting
List<Map<String, dynamic>> voipAcceptDataFromActiveCalls(dynamic activeCalls) {
  return _voipActiveCallEntries(activeCalls)
      .map(voipAcceptDataFromActiveCall)
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}

@visibleForTesting
String? voipAssignedResponderIdForSession(Map<String, dynamic> sessionData) {
  return _voipNonEmptyString(sessionData['currentResponderId']) ??
      _voipNonEmptyString(sessionData['currentTutorId']);
}

@visibleForTesting
bool voipIncomingSessionMatchesResponder({
  required Map<String, dynamic> sessionData,
  required String userId,
}) {
  final status = _voipNonEmptyString(sessionData['status']);
  final isPendingIncomingSession =
      status == 'searching' || status == 'pending_confirmation';
  return isPendingIncomingSession &&
      voipAssignedResponderIdForSession(sessionData) == userId;
}

@visibleForTesting
String? voipRoomUrlFromAcceptPayload(Map<String, dynamic> data) {
  return _voipStringFromPayload(data, 'roomUrl');
}

@visibleForTesting
String? voipMeetingTokenFromAcceptPayload(Map<String, dynamic> data) {
  return _voipStringFromPayload(data, 'meetingToken');
}

@visibleForTesting
String? voipRoomNameFromAcceptPayload(Map<String, dynamic> data) {
  return _voipStringFromPayload(data, 'roomName');
}

@visibleForTesting
VoipRoomCredentials? voipRoomCredentialsFromAcceptedPayload(
  Map<String, dynamic> data,
) {
  final roomUrl = voipRoomUrlFromAcceptPayload(data);
  if (roomUrl == null) {
    return null;
  }
  return VoipRoomCredentials(
    roomUrl: roomUrl,
    meetingToken: voipMeetingTokenFromAcceptPayload(data),
    roomName: voipRoomNameFromAcceptPayload(data),
  );
}

@visibleForTesting
VoipRoomCredentials? voipRoomCredentialsFromAcceptCallResponse(
  Map<String, dynamic> data,
) {
  if (_voipNonEmptyString(data['status']) != 'connected') {
    return null;
  }
  final roomUrl = _voipNonEmptyString(data['roomUrl']);
  if (roomUrl == null) {
    return null;
  }
  return VoipRoomCredentials(
    roomUrl: roomUrl,
    meetingToken: _voipNonEmptyString(data['meetingToken']),
    roomName: _voipNonEmptyString(data['roomName']),
  );
}

@visibleForTesting
VoipAcceptGateDecision voipEvaluateAcceptGate({
  required DateTime now,
  required DateTime? lastAcceptAt,
  required bool handledCallKitAcceptId,
  required bool acceptedSession,
  required bool acceptInProgress,
  Duration recentAcceptWindow = const Duration(seconds: 30),
}) {
  if (lastAcceptAt != null &&
      now.difference(lastAcceptAt) < recentAcceptWindow) {
    return VoipAcceptGateDecision.duplicateTimeWindow;
  }
  if (handledCallKitAcceptId) {
    return VoipAcceptGateDecision.duplicateCallKitId;
  }
  if (acceptedSession) {
    return VoipAcceptGateDecision.alreadyAccepted;
  }
  if (acceptInProgress) {
    return VoipAcceptGateDecision.acceptInProgress;
  }
  return VoipAcceptGateDecision.proceed;
}

@visibleForTesting
bool voipAcceptGateRequiresProcessClaimRelease(
  VoipAcceptGateDecision decision,
) {
  return decision != VoipAcceptGateDecision.proceed;
}

enum _PendingCallKitActionType {
  accept,
  decline,
}

class _PendingCallKitAction {
  const _PendingCallKitAction({
    required this.type,
    required this.data,
    required this.queuedAt,
    required this.queuedForUserId,
  });

  final _PendingCallKitActionType type;
  final Map<String, dynamic> data;
  final DateTime queuedAt;
  final String? queuedForUserId;
}

/// VoIP сервис для обработки входящих звонков
/// Использует CallKit (iOS) и ConnectionService (Android)
class VoIPService {
  static final VoIPService _instance = VoIPService._internal();
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final Map<String, DateTime> _processAcceptClaimedAtBySession = {};
  static const Duration _processAcceptDedupeWindow = Duration(minutes: 2);
  static const Duration _declineDedupeWindow = Duration(minutes: 2);
  static const Duration _pendingNavigationRetryDelay =
      Duration(milliseconds: 100);
  static const int _pendingNavigationMaxAttempts = 600;
  static const Duration _pendingCallKitActionTtl = Duration(minutes: 2);
  static const int _pendingCallKitActionMaxCount = 16;
  factory VoIPService() => _instance;
  VoIPService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFunctions get _functions => FirebaseFunctions.instance;

  bool _initialized = false;
  bool _initializing = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _incomingNotificationSub;
  StreamSubscription<CallEvent?>? _callKitSubscription;
  Timer? _sessionPruneTimer;
  bool _callActionHandlingReady = false;
  bool _pendingCallKitActionsDraining = false;
  final Map<String, DateTime> _sessionStateTouchedAt = {};
  final List<_PendingCallKitAction> _pendingCallKitActions =
      <_PendingCallKitAction>[];
  final Set<String> _acceptInProgress = {};
  final Set<String> _acceptedSessions = {};
  final Set<String> _handledCallKitAcceptIds = {};
  final Map<String, DateTime> _recentAcceptBySession = {};
  final Set<String> _declineInProgress = {};
  final Map<String, DateTime> _recentDeclineBySession = {};
  final Map<String, int> _sessionStateGenerations = {};
  final Set<String> _handledNotificationIds = {};
  String? _lastAcceptedSessionId;
  bool _lastAcceptedIsTutor = false;
  String? _lastNavigatedSessionId;
  bool? _lastNavigatedIsTutor;
  String? _pendingSessionId;
  bool _pendingIsTutor = false;
  bool _navRetryInProgress = false;
  String? _pendingRoomUrl;
  String? _pendingMeetingToken;
  String? _pendingRoomName;
  String? _lastRoomUrl;
  String? _lastMeetingToken;
  String? _lastRoomName;
  String? _prefetchedSessionId;
  String? _prefetchedMeetingToken;
  String? _prefetchedRoomUrl;
  String? _prefetchedRoomName;
  DateTime? _prefetchedTokenFetchedAt;
  bool _prefetchInProgress = false;
  int _prefetchRequestGeneration = 0;
  final Map<String, String> _sessionCallKitIds = {};
  String? _lastCallKitId;
  String? _notificationListenerUserId;
  @visibleForTesting
  Future<bool> Function()? debugEnsureMediaPermissionsOverride;
  @visibleForTesting
  Future<Map<String, dynamic>> Function(String sessionId)?
      debugAcceptCallOverride;
  @visibleForTesting
  Future<dynamic> Function()? debugActiveCallsOverride;
  @visibleForTesting
  Future<void> Function(String sessionId)? debugDeclineCallOverride;
  @visibleForTesting
  Future<bool> Function(String sessionId)? debugRecoverActiveSessionOverride;
  @visibleForTesting
  Future<void> Function(String sessionId)? debugPrefetchSessionTokensOverride;
  @visibleForTesting
  Future<void> Function({
    required String sessionId,
    required String callKitId,
  })? debugEndCallKitCallOverride;
  @visibleForTesting
  String? debugCurrentUserIdOverride;
  @visibleForTesting
  Future<Map<String, dynamic>> Function(String sessionId)?
      debugGetSessionTokensOverride;
  @visibleForTesting
  Future<void> Function({
    required String sessionId,
    required bool isTutor,
  })? debugMarkNavigationTriggeredOverride;
  @visibleForTesting
  void Function({
    required String sessionId,
    required bool isTutor,
    String? roomUrl,
    String? meetingToken,
    String? roomName,
  })? debugNavigateToVideoCallOverride;
  static const Duration _sessionStateTtl = Duration(minutes: 10);
  static const Duration _sessionStatePruneInterval = Duration(minutes: 2);

  // Для навигации нужен context - сохраним глобальный navigatorKey
  //static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Whether a VoIP call is pending navigation (accepted but not yet navigated).
  bool hasPendingNavigation() =>
      _pendingSessionId != null || _lastAcceptedSessionId != null;

  bool get _canHandleCallKitActions => _callActionHandlingReady && _initialized;

  String? _currentUserIdOrNull() {
    final override = debugCurrentUserIdOverride;
    if (override != null) {
      return override;
    }
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Future<void> startEarlyCallKitEventHandling() async {
    if (kIsWeb) return;
    _ensureCallKitEventSubscription();
  }

  Future<void> setCallActionHandlingReady(bool ready, {DateTime? now}) async {
    _callActionHandlingReady = ready;
    if (!ready) {
      _pendingCallKitActions.clear();
      return;
    }
    await drainPendingCallKitActions(now: now);
  }

  Future<void> drainPendingCallKitActions({DateTime? now}) async {
    if (!_canHandleCallKitActions || _pendingCallKitActionsDraining) {
      return;
    }
    _pendingCallKitActionsDraining = true;
    try {
      _prunePendingCallKitActions(now: now);
      while (_canHandleCallKitActions && _pendingCallKitActions.isNotEmpty) {
        final action = _pendingCallKitActions.removeAt(0);
        if (_pendingCallKitActionHasExpired(action, now: now) ||
            !_pendingCallKitActionTargetsCurrentUser(action)) {
          continue;
        }
        switch (action.type) {
          case _PendingCallKitActionType.accept:
            await _handleCallAccept(action.data, now: now);
            break;
          case _PendingCallKitActionType.decline:
            await _handleCallDecline(action.data);
            break;
        }
      }
    } finally {
      _pendingCallKitActionsDraining = false;
    }
  }

  @visibleForTesting
  Duration get debugPendingNavigationRetryDelayForTesting =>
      _pendingNavigationRetryDelay;

  @visibleForTesting
  int get debugPendingNavigationMaxAttemptsForTesting =>
      _pendingNavigationMaxAttempts;

  @visibleForTesting
  bool get debugCallActionHandlingReadyForTesting => _callActionHandlingReady;

  @visibleForTesting
  int get debugPendingCallKitActionCountForTesting =>
      _pendingCallKitActions.length;

  @visibleForTesting
  int get debugPendingCallKitActionMaxCountForTesting =>
      _pendingCallKitActionMaxCount;

  @visibleForTesting
  void debugSetInitializedForTesting(bool initialized) {
    _initialized = initialized;
  }

  Future<void> recoverBackgroundAcceptedCalls() async {
    if (kIsWeb) return;
    try {
      final activeCalls = await _callActiveCalls();
      final acceptedCalls = voipAcceptDataFromActiveCalls(activeCalls);
      for (final acceptData in acceptedCalls) {
        final sessionId = _voipStringFromPayload(acceptData, 'sessionId') ??
            _voipNonEmptyString(acceptData['sessionId']);
        debugPrint(
          '📞 VoIPService: Replaying background accepted call: $sessionId',
        );
        if (_queueCallKitActionIfNotReady(
          type: _PendingCallKitActionType.accept,
          data: acceptData,
        )) {
          continue;
        }
        if (_shouldDropCallKitActionForCurrentUser(
          type: _PendingCallKitActionType.accept,
          data: acceptData,
        )) {
          continue;
        }
        await _handleCallAccept(acceptData);
      }
    } catch (e) {
      debugPrint('⚠️ VoIPService: Failed to replay background accept: $e');
    }
  }

  @visibleForTesting
  void debugResetInMemoryStateForTesting() {
    _initialized = false;
    _initializing = false;
    _resetInMemoryState();
    _resetTestingOverrides();
  }

  @visibleForTesting
  bool debugTryClaimProcessAcceptForTesting(String sessionId) {
    return _tryClaimProcessAccept(sessionId);
  }

  @visibleForTesting
  bool debugHasProcessAcceptClaimForTesting(String sessionId) {
    return _processAcceptClaimedAtBySession.containsKey(sessionId);
  }

  @visibleForTesting
  void debugReleaseProcessAcceptClaimForTesting(String sessionId) {
    _releaseProcessAcceptClaim(sessionId);
  }

  @visibleForTesting
  void debugMarkAcceptInProgressForTesting(String sessionId) {
    _acceptInProgress.add(sessionId);
  }

  @visibleForTesting
  bool debugAcceptInProgressForTesting(String sessionId) {
    return _acceptInProgress.contains(sessionId);
  }

  @visibleForTesting
  bool debugDeclineInProgressForTesting(String sessionId) {
    return _declineInProgress.contains(sessionId);
  }

  @visibleForTesting
  bool debugRecentlyDeclinedSessionForTesting(String sessionId) {
    _pruneRecentDeclineState(DateTime.now());
    return _recentDeclineBySession.containsKey(sessionId);
  }

  @visibleForTesting
  void debugMarkAcceptedSessionForTesting(String sessionId) {
    _acceptedSessions.add(sessionId);
  }

  @visibleForTesting
  bool debugAcceptedSessionForTesting(String sessionId) {
    return _acceptedSessions.contains(sessionId);
  }

  @visibleForTesting
  String? debugCallKitIdForSessionForTesting(String sessionId) {
    return _sessionCallKitIds[sessionId];
  }

  @visibleForTesting
  void debugTrackCallKitSessionForTesting({
    required String sessionId,
    required String callKitId,
  }) {
    final normalizedCallKitId = _normalizeCallKitId(callKitId);
    if (normalizedCallKitId == null) return;
    _sessionCallKitIds[sessionId] = normalizedCallKitId;
    _lastCallKitId = normalizedCallKitId;
  }

  @visibleForTesting
  void debugTrackHandledCallKitAcceptForTesting({
    required String sessionId,
    required String callKitId,
  }) {
    final normalizedCallKitId = _normalizeCallKitId(callKitId);
    if (normalizedCallKitId == null) return;
    _sessionCallKitIds[sessionId] = normalizedCallKitId;
    _handledCallKitAcceptIds.add(normalizedCallKitId);
    _lastCallKitId = normalizedCallKitId;
  }

  @visibleForTesting
  bool debugHandledCallKitAcceptForTesting(String callKitId) {
    final normalizedCallKitId = _normalizeCallKitId(callKitId);
    return normalizedCallKitId != null &&
        _handledCallKitAcceptIds.contains(normalizedCallKitId);
  }

  @visibleForTesting
  void debugSetLastRoomCredentialsForTesting({
    String? roomUrl,
    String? meetingToken,
    String? roomName,
  }) {
    _lastRoomUrl = roomUrl;
    _lastMeetingToken = meetingToken;
    _lastRoomName = roomName;
  }

  @visibleForTesting
  void debugMarkLastAcceptedSessionForTesting(String sessionId) {
    _lastAcceptedSessionId = sessionId;
  }

  @visibleForTesting
  void debugClearSessionStateForTesting(String sessionId) {
    _clearSessionState(sessionId);
  }

  @visibleForTesting
  Future<void> debugHandleCallAcceptForTesting(
    Map<String, dynamic> data, {
    DateTime? now,
  }) {
    return _handleCallAccept(data, now: now);
  }

  @visibleForTesting
  Future<void> debugHandleCallKitAcceptEventForTesting(
    Map<String, dynamic> data,
  ) {
    return _handleCallKitEvent(
      CallEvent(data, Event.actionCallAccept),
    );
  }

  @visibleForTesting
  Future<void> debugHandleCallDeclineForTesting(Map<String, dynamic> data) {
    return _handleCallDecline(data);
  }

  @visibleForTesting
  Future<void> debugHandleCallKitDeclineEventForTesting(
    Map<String, dynamic> data,
  ) {
    return _handleCallKitEvent(
      CallEvent(data, Event.actionCallDecline),
    );
  }

  @visibleForTesting
  Future<void> debugHandleCallTimeoutForTesting(Map<String, dynamic> data) {
    return _handleCallTimeout(data);
  }

  @visibleForTesting
  Future<void> debugHandleCallKitTimeoutEventForTesting(
    Map<String, dynamic> data,
  ) {
    return _handleCallKitEvent(
      CallEvent(data, Event.actionCallTimeout),
    );
  }

  @visibleForTesting
  Future<void> debugSetCallActionHandlingReadyForTesting(
    bool ready, {
    DateTime? now,
  }) {
    return setCallActionHandlingReady(ready, now: now);
  }

  @visibleForTesting
  Future<void> debugDrainPendingCallKitActionsForTesting({DateTime? now}) {
    return drainPendingCallKitActions(now: now);
  }

  @visibleForTesting
  Future<void> debugPrefetchSessionTokensForTesting(String sessionId) {
    return _prefetchSessionTokens(sessionId);
  }

  @visibleForTesting
  String? debugFreshPrefetchedTokenForTesting(String sessionId) {
    return _getFreshPrefetchedToken(sessionId);
  }

  @visibleForTesting
  String? debugPrefetchedRoomUrlForTesting(String sessionId) {
    return _getPrefetchedRoomUrl(sessionId);
  }

  @visibleForTesting
  String? debugPrefetchedRoomNameForTesting(String sessionId) {
    return _getPrefetchedRoomName(sessionId);
  }

  void _resetTestingOverrides() {
    debugEnsureMediaPermissionsOverride = null;
    debugAcceptCallOverride = null;
    debugActiveCallsOverride = null;
    debugDeclineCallOverride = null;
    debugRecoverActiveSessionOverride = null;
    debugPrefetchSessionTokensOverride = null;
    debugEndCallKitCallOverride = null;
    debugCurrentUserIdOverride = null;
    debugGetSessionTokensOverride = null;
    debugMarkNavigationTriggeredOverride = null;
    debugNavigateToVideoCallOverride = null;
  }

  Future<bool> _ensureAcceptMediaPermissions() {
    final override = debugEnsureMediaPermissionsOverride;
    if (override != null) {
      return override();
    }
    return ensureCameraAndMicrophonePermissions();
  }

  Future<Map<String, dynamic>> _callAcceptCallFunction(String sessionId) async {
    final override = debugAcceptCallOverride;
    if (override != null) {
      return override(sessionId);
    }
    final result = await _functions
        .httpsCallable('acceptCall')
        .call({'sessionId': sessionId});
    return _voipMapFrom(result.data);
  }

  Future<Map<String, dynamic>> _callGetSessionTokensFunction(
    String sessionId,
  ) async {
    final override = debugGetSessionTokensOverride;
    if (override != null) {
      return override(sessionId);
    }
    final result = await _functions
        .httpsCallable('getSessionTokens')
        .call({'sessionId': sessionId});
    return _voipMapFrom(result.data);
  }

  Future<dynamic> _callActiveCalls() {
    final override = debugActiveCallsOverride;
    if (override != null) {
      return override();
    }
    return FlutterCallkitIncoming.activeCalls();
  }

  Future<void> _callDeclineCallFunction(String sessionId) async {
    final override = debugDeclineCallOverride;
    if (override != null) {
      await override(sessionId);
      return;
    }
    await _functions
        .httpsCallable('declineCall')
        .call({'sessionId': sessionId});
  }

  Future<void> _prefetchSessionTokensForAccept(String sessionId) {
    final override = debugPrefetchSessionTokensOverride;
    if (override != null) {
      return override(sessionId);
    }
    return _prefetchSessionTokens(sessionId);
  }

  void _clearPrefetchedSessionCredentials() {
    _prefetchedMeetingToken = null;
    _prefetchedRoomUrl = null;
    _prefetchedRoomName = null;
    _prefetchedTokenFetchedAt = null;
  }

  Future<void> _markNavigationTriggeredForAccept({
    required String sessionId,
    required bool isTutor,
  }) async {
    final override = debugMarkNavigationTriggeredOverride;
    if (override != null) {
      await override(sessionId: sessionId, isTutor: isTutor);
      return;
    }
    final field =
        isTutor ? 'tutorNavigationTriggered' : 'studentNavigationTriggered';
    await _firestore.collection('videoSessions').doc(sessionId).update({
      field: true,
      'navigationTimestamp': FieldValue.serverTimestamp(),
    });
  }

  void _navigateToVideoCallForAccept({
    required String sessionId,
    required bool isTutor,
    String? roomUrl,
    String? meetingToken,
    String? roomName,
  }) {
    final override = debugNavigateToVideoCallOverride;
    if (override != null) {
      override(
        sessionId: sessionId,
        isTutor: isTutor,
        roomUrl: roomUrl,
        meetingToken: meetingToken,
        roomName: roomName,
      );
      return;
    }
    _tryNavigateToVideoCall(
      sessionId: sessionId,
      isTutor: isTutor,
      roomUrl: roomUrl,
      meetingToken: meetingToken,
      roomName: roomName,
    );
  }

  String _callKitIdForSession(String sessionId) {
    final trimmedSessionId = sessionId.trim();
    if (trimmedSessionId.isEmpty) {
      return const Uuid().v4();
    }
    if (_uuidPattern.hasMatch(trimmedSessionId)) {
      return trimmedSessionId.toLowerCase();
    }

    final digestBytes = md5
        .convert(utf8.encode('smalltalk-call:$trimmedSessionId'))
        .bytes
        .toList();
    digestBytes[6] = (digestBytes[6] & 0x0F) | 0x30;
    digestBytes[8] = (digestBytes[8] & 0x3F) | 0x80;
    final hex = digestBytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  String? _normalizeCallKitId(String? callKitId) {
    final trimmed = callKitId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed.toLowerCase();
  }

  bool _hasMismatchedTrackedCallKitId(String sessionId, String? callKitId) {
    if (callKitId == null) {
      return false;
    }
    final expectedCallKitId =
        _sessionCallKitIds[sessionId] ?? _callKitIdForSession(sessionId);
    return callKitId != expectedCallKitId;
  }

  bool _hasTrustedCallKitIdentity(String sessionId, String? callKitId) {
    return callKitId != null &&
        !_hasMismatchedTrackedCallKitId(sessionId, callKitId);
  }

  bool _hasProtectedLiveSessionState(String sessionId) {
    return sessionId == _lastAcceptedSessionId ||
        sessionId == _lastNavigatedSessionId ||
        sessionId == _pendingSessionId ||
        _acceptedSessions.contains(sessionId) ||
        _acceptInProgress.contains(sessionId);
  }

  bool _canEndSessionFromInMemoryState(String sessionId) {
    final hasResolvedRoomUrl = sessionId == _lastAcceptedSessionId &&
            _lastRoomUrl != null &&
            _lastRoomUrl!.isNotEmpty ||
        sessionId == _prefetchedSessionId &&
            _prefetchedRoomUrl != null &&
            _prefetchedRoomUrl!.isNotEmpty;
    return hasResolvedRoomUrl;
  }

  bool _hasTrackedSessionState(String sessionId) {
    return _sessionStateTouchedAt.containsKey(sessionId) ||
        _sessionCallKitIds.containsKey(sessionId) ||
        _recentAcceptBySession.containsKey(sessionId) ||
        _hasProtectedLiveSessionState(sessionId);
  }

  bool _tryClaimProcessAccept(String sessionId) {
    final now = DateTime.now();
    _processAcceptClaimedAtBySession.removeWhere(
      (_, claimedAt) => now.difference(claimedAt) >= _processAcceptDedupeWindow,
    );
    final lastClaim = _processAcceptClaimedAtBySession[sessionId];
    if (lastClaim != null &&
        now.difference(lastClaim) < _processAcceptDedupeWindow) {
      return false;
    }
    _processAcceptClaimedAtBySession[sessionId] = now;
    return true;
  }

  void _releaseProcessAcceptClaim(String sessionId) {
    _processAcceptClaimedAtBySession.remove(sessionId);
  }

  Future<bool> _shouldEndSessionViaFallbackLookup(String sessionId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return false;
      }
      final sessionDoc =
          await _firestore.collection('videoSessions').doc(sessionId).get();
      if (!sessionDoc.exists) {
        return false;
      }
      final data = sessionDoc.data();
      if (data == null) {
        return false;
      }

      final status = data['status'] as String?;
      final tutorId = data['tutorId'] as String?;
      final studentId = data['studentId'] as String?;
      final isParticipant = tutorId == userId || studentId == userId;
      final isEndableStatus =
          status == 'active' || status == 'connecting' || status == 'connected';
      return isParticipant && isEndableStatus;
    } catch (e) {
      debugPrint('⚠️ VoIPService: endSession fallback lookup failed: $e');
      return false;
    }
  }

  /// Инициализация VoIP сервиса
  /// Вызывается один раз при запуске приложения
  Future<void> initialize() async {
    if (_initialized || _initializing) {
      debugPrint('🔔 VoIPService: Initialize skipped (already running)');
      _ensureCallKitEventSubscription();
      await drainPendingCallKitActions();
      return;
    }
    _initializing = true;
    debugPrint('🔔 VoIPService: Initializing...');

    try {
      // 1. Запрашиваем разрешения для push уведомлений
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );

      debugPrint(
          '🔔 VoIPService: Permission status: ${settings.authorizationStatus}');

      // 2. Получаем FCM токен
      String? fcmToken = await _fcm.getToken();
      if (fcmToken != null) {
        debugPrint('🔔 VoIPService: Got FCM token');
        await _saveVoipToken(fcmToken);
      } else {
        debugPrint('⚠️ VoIPService: Failed to get FCM token');
      }

      // 3. Слушаем обновления токена
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('🔔 VoIPService: Token refreshed');
        _saveVoipToken(newToken);
      });

      // 3.1. Обработка входящих уведомлений в фореграунде
      await _foregroundMessageSub?.cancel();
      _foregroundMessageSub =
          FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        if (message.data['type'] == 'call_cancelled') {
          final sessionId = _voipNonEmptyString(message.data['sessionId']);
          if (sessionId != null) {
            await cancelIncomingCall(sessionId: sessionId);
          }
          return;
        }
        if (message.data['type'] != 'incoming_call') return;
        if (kIsWeb) return;

        debugPrint('📞 VoIPService: Foreground incoming call received');
        try {
          await showIncomingCall(
            sessionId: message.data['sessionId'] ?? '',
            callerName: message.data['callerName'] ?? 'Unknown Caller',
            callerId: message.data['callerId'] ?? '',
            callerPhoto: message.data['callerPhoto'],
            extraData: voipIncomingCallExtraDataFromPayload(message.data),
            lifecycleState: WidgetsBinding.instance.lifecycleState,
          );
        } catch (e) {
          debugPrint('❌ VoIPService: Failed to show CallKit in foreground: $e');
        }
      });

      // 4. Слушаем события CallKit/ConnectionService
      _ensureCallKitEventSubscription();
      await recoverBackgroundAcceptedCalls();
      _startSessionPruneTimer();

      // 5. Пытаемся получить PushKit токен (iOS) если доступен
      await _syncPushKitToken();
      _startIncomingNotificationListener();

      _initialized = true;
      await drainPendingCallKitActions();
      debugPrint('✅ VoIPService: Initialized successfully');
    } catch (e) {
      debugPrint('❌ VoIPService: Initialization error: $e');
    } finally {
      _initializing = false;
    }
  }

  void _startIncomingNotificationListener() {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      return;
    }
    if (_incomingNotificationSub != null &&
        _notificationListenerUserId == userId) {
      return;
    }

    unawaited(_incomingNotificationSub?.cancel());
    _notificationListenerUserId = userId;
    _incomingNotificationSub = _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .snapshots()
        .listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.removed) {
            continue;
          }
          unawaited(_handleIncomingNotification(change.doc, userId));
        }
      },
      onError: (error) {
        debugPrint(
            '⚠️ VoIPService: Incoming notification listener failed: $error');
      },
    );
  }

  String? _nonEmptyString(dynamic value) {
    return _voipNonEmptyString(value);
  }

  Map<String, dynamic> _mapFrom(dynamic value) {
    return _voipMapFrom(value);
  }

  DateTime? _dateTimeFromFirestoreValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String? _payloadExpiresAtForIncomingNotification(
    Map<String, dynamic> data,
  ) {
    for (final key in const ['payloadExpiresAt', 'expiresAt']) {
      final dateTime = _dateTimeFromFirestoreValue(data[key]);
      if (dateTime != null) {
        return dateTime.toUtc().toIso8601String();
      }

      final value = _nonEmptyString(data[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  bool _incomingNotificationIsCurrent(Map<String, dynamic> data) {
    final type = _nonEmptyString(data['type']);
    final status = _nonEmptyString(data['status']);
    if (type != NotificationType.incoming_call.name || status != 'sent') {
      return false;
    }

    final expiresAt = _dateTimeFromFirestoreValue(data['expiresAt']);
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
      return false;
    }

    return _nonEmptyString(data['sessionId']) != null;
  }

  bool _incomingNotificationCancellationIsFresh(
    Map<String, dynamic> data,
  ) {
    final cancelledAt = _dateTimeFromFirestoreValue(data['cancelledAt']) ??
        _dateTimeFromFirestoreValue(data['expiredAt']) ??
        _dateTimeFromFirestoreValue(data['expiresAt']);
    if (cancelledAt == null) {
      return false;
    }
    final age = DateTime.now().difference(cancelledAt);
    return !age.isNegative && age < const Duration(minutes: 2);
  }

  Future<Map<String, dynamic>?> _loadCurrentIncomingSessionData({
    required String sessionId,
    required String userId,
  }) async {
    try {
      final sessionDoc =
          await _firestore.collection('videoSessions').doc(sessionId).get();
      if (!sessionDoc.exists) {
        return null;
      }

      final sessionData = sessionDoc.data();
      if (sessionData == null) {
        return null;
      }

      if (!voipIncomingSessionMatchesResponder(
        sessionData: sessionData,
        userId: userId,
      )) {
        return null;
      }

      return sessionData;
    } catch (error) {
      debugPrint(
          '⚠️ VoIPService: Failed to validate incoming notification: $error');
      return null;
    }
  }

  Future<void> _handleIncomingNotification(
    DocumentSnapshot<Map<String, dynamic>> notificationDoc,
    String userId,
  ) async {
    final notificationData = notificationDoc.data();
    if (notificationData == null) {
      return;
    }

    final sessionId = _nonEmptyString(notificationData['sessionId']);
    final notificationType = _nonEmptyString(notificationData['type']);
    final notificationStatus = _nonEmptyString(notificationData['status']);
    if (notificationType == NotificationType.incoming_call.name &&
        sessionId != null &&
        (notificationStatus == 'cancelled' ||
            notificationStatus == 'expired') &&
        _incomingNotificationCancellationIsFresh(notificationData)) {
      final terminalEventKey = '${notificationDoc.id}:$notificationStatus';
      if (_handledNotificationIds.add(terminalEventKey)) {
        debugPrint(
          '📴 VoIPService: Incoming call cancelled for session $sessionId',
        );
        await cancelIncomingCall(sessionId: sessionId);
      }
      return;
    }

    if (!_incomingNotificationIsCurrent(notificationData)) {
      return;
    }

    if (sessionId == null ||
        _handledNotificationIds.contains(notificationDoc.id) ||
        _sessionCallKitIds.containsKey(sessionId) ||
        _hasProtectedLiveSessionState(sessionId)) {
      return;
    }

    final sessionData = await _loadCurrentIncomingSessionData(
      sessionId: sessionId,
      userId: userId,
    );
    if (sessionData == null) {
      return;
    }

    _handledNotificationIds.add(notificationDoc.id);
    final notificationStudentInfo = _mapFrom(notificationData['studentInfo']);
    final sessionStudentInfo = _mapFrom(sessionData['studentInfo']);
    final callerName = _nonEmptyString(notificationStudentInfo['name']) ??
        _nonEmptyString(sessionStudentInfo['name']) ??
        'Unknown Caller';
    final callerId = _nonEmptyString(sessionData['studentId']) ?? '';
    final callerPhoto = _nonEmptyString(notificationStudentInfo['photo']) ??
        _nonEmptyString(sessionStudentInfo['photo']);
    final payloadExpiresAt =
        _payloadExpiresAtForIncomingNotification(notificationData);

    debugPrint('📞 VoIPService: Firestore incoming call notification received');
    await showIncomingCall(
      sessionId: sessionId,
      callerName: callerName,
      callerId: callerId,
      callerPhoto: callerPhoto,
      extraData: voipIncomingCallExtraDataFromPayload({
        ...notificationData,
        'callerName': callerName,
        'callerId': callerId,
        if (callerPhoto != null) 'callerPhoto': callerPhoto,
        'studentName': callerName,
        'studentId': callerId,
        if (callerPhoto != null) 'studentPhoto': callerPhoto,
        if (payloadExpiresAt != null) 'expiresAt': payloadExpiresAt,
      }),
      lifecycleState: WidgetsBinding.instance.lifecycleState,
    );
  }

  void _resetInMemoryState() {
    _sessionPruneTimer?.cancel();
    _sessionPruneTimer = null;
    _sessionStateTouchedAt.clear();
    _acceptInProgress.clear();
    _acceptedSessions.clear();
    _handledCallKitAcceptIds.clear();
    _recentAcceptBySession.clear();
    _declineInProgress.clear();
    _recentDeclineBySession.clear();
    _sessionStateGenerations.clear();
    _handledNotificationIds.clear();
    _sessionCallKitIds.clear();
    _pendingCallKitActions.clear();
    _pendingCallKitActionsDraining = false;
    _callActionHandlingReady = false;
    _processAcceptClaimedAtBySession.clear();

    _lastAcceptedSessionId = null;
    _lastAcceptedIsTutor = false;
    _lastNavigatedSessionId = null;
    _lastNavigatedIsTutor = null;
    _pendingSessionId = null;
    _pendingIsTutor = false;
    _navRetryInProgress = false;
    _pendingRoomUrl = null;
    _pendingMeetingToken = null;
    _pendingRoomName = null;
    _lastRoomUrl = null;
    _lastMeetingToken = null;
    _lastRoomName = null;
    _prefetchedSessionId = null;
    _clearPrefetchedSessionCredentials();
    _prefetchInProgress = false;
    _prefetchRequestGeneration = 0;
    _lastCallKitId = null;
    _notificationListenerUserId = null;
  }

  void _startSessionPruneTimer() {
    _sessionPruneTimer?.cancel();
    _sessionPruneTimer = Timer.periodic(
      _sessionStatePruneInterval,
      (_) => _pruneStaleSessionState(),
    );
  }

  void _touchSessionState(String sessionId) {
    if (sessionId.isEmpty) return;
    _sessionStateTouchedAt[sessionId] = DateTime.now();
    _sessionStateGenerations[sessionId] =
        (_sessionStateGenerations[sessionId] ?? 0) + 1;
  }

  void _pruneStaleSessionState() {
    if (_sessionStateTouchedAt.isEmpty &&
        _recentAcceptBySession.isEmpty &&
        _recentDeclineBySession.isEmpty &&
        _acceptedSessions.isEmpty &&
        _sessionCallKitIds.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final staleSessionIds = <String>{};

    for (final entry in List<MapEntry<String, DateTime>>.from(
      _sessionStateTouchedAt.entries,
    )) {
      if (now.difference(entry.value) >= _sessionStateTtl) {
        staleSessionIds.add(entry.key);
      }
    }

    for (final entry in List<MapEntry<String, DateTime>>.from(
      _recentAcceptBySession.entries,
    )) {
      if (now.difference(entry.value) >= _sessionStateTtl) {
        staleSessionIds.add(entry.key);
      }
    }
    _pruneRecentDeclineState(now);

    for (final sessionId in List<String>.from(_acceptedSessions)) {
      final touchedAt = _sessionStateTouchedAt[sessionId];
      if (touchedAt == null || now.difference(touchedAt) >= _sessionStateTtl) {
        staleSessionIds.add(sessionId);
      }
    }

    for (final sessionId in List<String>.from(_sessionCallKitIds.keys)) {
      final touchedAt = _sessionStateTouchedAt[sessionId];
      if (touchedAt == null || now.difference(touchedAt) >= _sessionStateTtl) {
        staleSessionIds.add(sessionId);
      }
    }

    if (_lastAcceptedSessionId != null) {
      staleSessionIds.remove(_lastAcceptedSessionId);
    }
    if (_lastNavigatedSessionId != null) {
      staleSessionIds.remove(_lastNavigatedSessionId);
    }
    if (_pendingSessionId != null) {
      staleSessionIds.remove(_pendingSessionId);
    }
    if (_prefetchedSessionId != null) {
      staleSessionIds.remove(_prefetchedSessionId);
    }

    if (staleSessionIds.isEmpty) return;

    for (final sessionId in staleSessionIds) {
      _clearSessionState(sessionId);
    }
    debugPrint(
      '🧹 VoIPService: Pruned stale session state for ${staleSessionIds.length} session(s)',
    );
  }

  /// Деинициализация VoIP сервиса (например, при logout).
  Future<void> deinitialize() async {
    _callActionHandlingReady = false;
    _pendingCallKitActions.clear();
    _pendingCallKitActionsDraining = false;
    if (!_initialized &&
        !_initializing &&
        _tokenRefreshSub == null &&
        _foregroundMessageSub == null) {
      return;
    }

    debugPrint('🔔 VoIPService: Deinitializing...');
    _initializing = false;
    await _clearRegisteredVoipTokens();

    final tokenSub = _tokenRefreshSub;
    _tokenRefreshSub = null;
    if (tokenSub != null) {
      await tokenSub.cancel();
    }

    final foregroundSub = _foregroundMessageSub;
    _foregroundMessageSub = null;
    if (foregroundSub != null) {
      await foregroundSub.cancel();
    }

    final notificationSub = _incomingNotificationSub;
    _incomingNotificationSub = null;
    if (notificationSub != null) {
      await notificationSub.cancel();
    }

    _resetInMemoryState();
    _initialized = false;
    _ensureCallKitEventSubscription();
    debugPrint('✅ VoIPService: Deinitialized');
  }

  Future<void> _registerVoipToken({
    required String tokenType,
    required String token,
  }) async {
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) {
      return;
    }

    await _functions.httpsCallable('registerVoipToken').call({
      'tokenType': tokenType,
      'token': trimmedToken,
    });
  }

  Future<void> _clearRegisteredVoipTokens() async {
    if (_auth.currentUser == null) {
      return;
    }

    try {
      await _functions.httpsCallable('registerVoipToken').call({
        'clearAll': true,
      });
    } catch (e) {
      debugPrint('⚠️ VoIPService: Failed to clear registered tokens: $e');
    }
  }

  /// Сохранение FCM токена через серверный контракт.
  Future<void> _saveVoipToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint(
            '⚠️ VoIPService: No authenticated user, skipping token save');
        return;
      }

      await _registerVoipToken(tokenType: 'fcm', token: token);

      debugPrint('✅ VoIPService: Token saved for user ${user.uid}');
    } catch (e) {
      debugPrint('❌ VoIPService: Error saving token: $e');
    }
  }

  /// Сохранение PushKit токена через серверный контракт (iOS).
  Future<void> _savePushKitToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint(
            '⚠️ VoIPService: No authenticated user, skipping PushKit token save');
        return;
      }

      await _registerVoipToken(tokenType: 'pushkit', token: token);

      debugPrint('✅ VoIPService: PushKit token saved for user ${user.uid}');
    } catch (e) {
      debugPrint('❌ VoIPService: Error saving PushKit token: $e');
    }
  }

  /// Пробуем синхронизировать PushKit токен (iOS)
  Future<void> _syncPushKitToken() async {
    if (kIsWeb) return;

    try {
      final token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      if (token is String && token.isNotEmpty) {
        await _savePushKitToken(token);
      }
    } catch (e) {
      debugPrint('⚠️ VoIPService: PushKit token not available yet: $e');
    }
  }

  /// Показать входящий звонок (вызывается из push notification handler)
  Future<void> showIncomingCall({
    required String sessionId,
    required String callerName,
    required String callerId,
    String? callerPhoto,
    Map<String, dynamic>? extraData,
    AppLifecycleState? lifecycleState,
  }) async {
    try {
      if (extraData != null && voipIncomingCallPayloadHasExpired(extraData)) {
        debugPrint('ℹ️ VoIPService: Ignoring expired incoming call payload');
        return;
      }
      final callKitId = sessionId.isNotEmpty
          ? (_sessionCallKitIds[sessionId] ?? _callKitIdForSession(sessionId))
          : const Uuid().v4();
      if (extraData != null &&
          voipIncomingCallShouldUseInAppNavigation(
            extraData,
            lifecycleState: lifecycleState,
          )) {
        debugPrint(
          'ℹ️ VoIPService: Foreground incoming call uses in-app navigation',
        );
        await _handleCallAccept(<String, dynamic>{
          'id': callKitId,
          'extra': voipBuildCallKitExtraData(
            sessionId: sessionId,
            callerId: callerId,
            callKitId: callKitId,
            extraData: extraData,
          ),
        });
        return;
      }

      debugPrint('📞 VoIPService: Showing incoming call from $callerName');

      if (sessionId.isNotEmpty) {
        _sessionCallKitIds[sessionId] = callKitId;
        _touchSessionState(sessionId);
        _lastCallKitId = callKitId;
      }
      final callKitParams = CallKitParams(
        id: callKitId,
        nameCaller: callerName,
        appName: 'Expatlio',
        avatar: callerPhoto,
        handle: callerId,
        type: 1,
        textAccept: 'Accept',
        textDecline: 'Decline',
        duration: _incomingCallTimeoutMilliseconds,
        extra: voipBuildCallKitExtraData(
          sessionId: sessionId,
          callerId: callerId,
          callKitId: callKitId,
          extraData: extraData,
        ),
        headers: <String, dynamic>{
          'platform': 'flutter',
        },
        android: AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0955fa',
          backgroundUrl: callerPhoto ?? '',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: 'Incoming Call',
          missedCallNotificationChannelName: 'Missed Call',
        ),
        ios: IOSParams(
          iconName: 'CallKitLogo',
          handleType: 'generic',
          supportsVideo: true,
          maximumCallGroups: 1,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'videoChat',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          configureAudioSession: true,
          supportsDTMF: false,
          supportsHolding: false,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'system_ringtone_default',
        ),
      );

      await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
      debugPrint('✅ VoIPService: CallKit UI shown for session: $sessionId');
    } catch (e) {
      debugPrint('❌ VoIPService: Error showing incoming call: $e');
    }
  }

  /// Обработка событий CallKit/ConnectionService
  Future<void> _handleCallKitEvent(CallEvent? event) async {
    if (event == null) return;

    debugPrint('📞 VoIPService: CallKit Event: ${event.event}');

    try {
      switch (event.event) {
        case Event.actionDidUpdateDevicePushTokenVoip:
          await _handlePushKitTokenUpdate(event.body);
          break;
        case Event.actionCallAccept:
          if (_queueCallKitActionIfNotReady(
            type: _PendingCallKitActionType.accept,
            data: event.body,
          )) {
            return;
          }
          if (_shouldDropCallKitActionForCurrentUser(
            type: _PendingCallKitActionType.accept,
            data: event.body,
          )) {
            return;
          }
          await _handleCallAccept(event.body);
          break;
        case Event.actionCallDecline:
          if (_queueCallKitActionIfNotReady(
            type: _PendingCallKitActionType.decline,
            data: event.body,
          )) {
            return;
          }
          if (_shouldDropCallKitActionForCurrentUser(
            type: _PendingCallKitActionType.decline,
            data: event.body,
          )) {
            return;
          }
          await _handleCallDecline(event.body);
          break;
        case Event.actionCallEnded:
          await _handleCallEnded(event.body);
          break;
        case Event.actionCallTimeout:
          if (_shouldDropCallKitActionForAnotherKnownUser(
            actionName: 'timeout',
            data: event.body,
          )) {
            return;
          }
          await _handleCallTimeout(event.body);
          break;
        case Event.actionCallToggleAudioSession:
          _handleAudioSessionToggle(event.body);
          break;
        case Event.actionCallIncoming:
          debugPrint('📞 VoIPService: Call incoming (display state)');
          break;
        case Event.actionCallStart:
          debugPrint('📞 VoIPService: Call started');
          break;
        default:
          debugPrint('⚠️ VoIPService: Unhandled event: ${event.event}');
      }
    } catch (e) {
      debugPrint('❌ VoIPService: Error handling CallKit event: $e');
    }
  }

  Future<void> _handlePushKitTokenUpdate(dynamic body) async {
    try {
      if (kIsWeb) return;
      if (body is Map) {
        final token = body['deviceTokenVoIP'];
        if (token is String && token.isNotEmpty) {
          await _savePushKitToken(token);
        }
      }
    } catch (e) {
      debugPrint('⚠️ VoIPService: Failed to handle PushKit token update: $e');
    }
  }

  void _ensureCallKitEventSubscription() {
    if (kIsWeb || _callKitSubscription != null) {
      return;
    }
    _callKitSubscription =
        FlutterCallkitIncoming.onEvent.listen(_handleCallKitEvent);
  }

  bool _queueCallKitActionIfNotReady({
    required _PendingCallKitActionType type,
    required Map<String, dynamic>? data,
  }) {
    if (_canHandleCallKitActions) {
      return false;
    }
    if (data == null) {
      return true;
    }
    final normalizedData = _voipMapFrom(data);
    final sessionId = _voipStringFromPayload(normalizedData, 'sessionId');
    if (sessionId == null) {
      debugPrint(
          '⚠️ VoIPService: Dropping early CallKit action without sessionId');
      return true;
    }

    final callKitId = _normalizeCallKitId(
      _voipNonEmptyString(normalizedData['id']) ??
          _voipStringFromPayload(normalizedData, 'callKitId'),
    );
    final incomingKey = _pendingCallKitActionIdentityKey(
      sessionId: sessionId,
      callKitId: callKitId,
    );
    final existingIndex = _pendingCallKitActions.indexWhere((action) {
      final existingSessionId =
          _voipStringFromPayload(action.data, 'sessionId');
      final existingCallKitId = _normalizeCallKitId(
        _voipNonEmptyString(action.data['id']) ??
            _voipStringFromPayload(action.data, 'callKitId'),
      );
      return incomingKey ==
          _pendingCallKitActionIdentityKey(
            sessionId: existingSessionId,
            callKitId: existingCallKitId,
          );
    });
    final action = _PendingCallKitAction(
      type: type,
      data: normalizedData,
      queuedAt: DateTime.now(),
      queuedForUserId: _currentUserIdOrNull(),
    );
    if (existingIndex >= 0) {
      _pendingCallKitActions[existingIndex] = action;
    } else {
      _pendingCallKitActions.add(action);
      if (_pendingCallKitActions.length > _pendingCallKitActionMaxCount) {
        _pendingCallKitActions.removeAt(0);
      }
    }
    debugPrint(
      '📞 VoIPService: Queued early CallKit ${type.name} for $sessionId',
    );
    return true;
  }

  String _pendingCallKitActionIdentityKey({
    required String? sessionId,
    required String? callKitId,
  }) {
    return '${sessionId ?? ''}:${callKitId ?? ''}';
  }

  bool _pendingCallKitActionHasExpired(
    _PendingCallKitAction action, {
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    if (effectiveNow.difference(action.queuedAt) >= _pendingCallKitActionTtl) {
      return true;
    }
    return voipIncomingCallPayloadHasExpired(action.data, now: effectiveNow);
  }

  bool _pendingCallKitActionTargetsCurrentUser(_PendingCallKitAction action) {
    return _callKitActionTargetsCurrentUser(
      action.data,
      queuedForUserId: action.queuedForUserId,
      requireQueuedUserForUntargeted: true,
    );
  }

  bool _callKitActionTargetsCurrentUser(
    Map<String, dynamic> data, {
    String? queuedForUserId,
    bool requireQueuedUserForUntargeted = false,
  }) {
    final targetUserId = _voipStringFromPayload(data, 'recipientId');
    final currentUserId = _currentUserIdOrNull();
    if (targetUserId == null) {
      if (queuedForUserId != null) {
        return currentUserId != null && queuedForUserId == currentUserId;
      }
      return !requireQueuedUserForUntargeted && currentUserId != null;
    }
    return currentUserId != null && targetUserId == currentUserId;
  }

  void _pruneRecentDeclineState(DateTime now) {
    _recentDeclineBySession.removeWhere(
      (_, declinedAt) => now.difference(declinedAt) >= _declineDedupeWindow,
    );
  }

  bool _shouldDropCallKitActionForCurrentUser({
    required _PendingCallKitActionType type,
    required Map<String, dynamic>? data,
  }) {
    if (data == null) {
      return false;
    }
    final normalizedData = _voipMapFrom(data);
    if (_callKitActionTargetsCurrentUser(normalizedData)) {
      return false;
    }
    final sessionId =
        _voipStringFromPayload(normalizedData, 'sessionId') ?? 'unknown';
    debugPrint(
      '⚠️ VoIPService: Dropping CallKit ${type.name} for another user: $sessionId',
    );
    return true;
  }

  bool _shouldDropCallKitActionForAnotherKnownUser({
    required String actionName,
    required Map<String, dynamic>? data,
  }) {
    if (data == null) {
      return false;
    }
    final normalizedData = _voipMapFrom(data);
    final targetUserId = _voipStringFromPayload(normalizedData, 'recipientId');
    final currentUserId = _currentUserIdOrNull();
    if (targetUserId == null ||
        currentUserId == null ||
        targetUserId == currentUserId) {
      return false;
    }
    final sessionId =
        _voipStringFromPayload(normalizedData, 'sessionId') ?? 'unknown';
    debugPrint(
      '⚠️ VoIPService: Dropping CallKit $actionName for another user: $sessionId',
    );
    return true;
  }

  void _prunePendingCallKitActions({DateTime? now}) {
    _pendingCallKitActions.removeWhere((action) {
      return _pendingCallKitActionHasExpired(action, now: now) ||
          !_pendingCallKitActionTargetsCurrentUser(action);
    });
  }

  bool _stopAcceptForGateDecision({
    required String sessionId,
    required String effectiveCallKitId,
    required VoipAcceptGateDecision decision,
    required bool releaseProcessClaim,
  }) {
    switch (decision) {
      case VoipAcceptGateDecision.proceed:
        return false;
      case VoipAcceptGateDecision.duplicateTimeWindow:
        debugPrint('⚠️ VoIPService: Duplicate accept event (time window)');
        break;
      case VoipAcceptGateDecision.duplicateCallKitId:
        debugPrint(
            '⚠️ VoIPService: Duplicate accept event (callKitId): $effectiveCallKitId');
        break;
      case VoipAcceptGateDecision.alreadyAccepted:
        debugPrint('⚠️ VoIPService: Call already accepted: $sessionId');
        break;
      case VoipAcceptGateDecision.acceptInProgress:
        debugPrint('⚠️ VoIPService: Accept already in progress for $sessionId');
        break;
    }
    if (releaseProcessClaim) {
      _releaseProcessAcceptClaim(sessionId);
    }
    return true;
  }

  /// Пользователь принял звонок
  Future<void> _handleCallAccept(
    Map<String, dynamic>? data, {
    DateTime? now,
  }) async {
    if (data == null) return;

    final sessionId = _voipStringFromPayload(data, 'sessionId');
    final callKitId = _normalizeCallKitId(
      _voipNonEmptyString(data['id']) ??
          _voipStringFromPayload(data, 'callKitId'),
    );
    if (sessionId == null || sessionId.isEmpty) {
      debugPrint('❌ VoIPService: No sessionId in accept event');
      return;
    }

    final trackedCallKitId = _sessionCallKitIds[sessionId];
    final effectiveCallKitId =
        trackedCallKitId ?? _callKitIdForSession(sessionId);
    if (callKitId != null && callKitId != effectiveCallKitId) {
      debugPrint(
          'ℹ️ VoIPService: Ignoring accept for stale callKitId: $callKitId');
      return;
    }
    final acceptTime = now ?? DateTime.now();
    final preExpiredGateDecision = voipEvaluateAcceptGate(
      now: acceptTime,
      lastAcceptAt: _recentAcceptBySession[sessionId],
      handledCallKitAcceptId:
          _handledCallKitAcceptIds.contains(effectiveCallKitId),
      acceptedSession: _acceptedSessions.contains(sessionId),
      acceptInProgress: _acceptInProgress.contains(sessionId),
    );
    if (_stopAcceptForGateDecision(
      sessionId: sessionId,
      effectiveCallKitId: effectiveCallKitId,
      decision: preExpiredGateDecision,
      releaseProcessClaim: false,
    )) {
      return;
    }
    if (_hasProtectedLiveSessionState(sessionId)) {
      debugPrint(
          'ℹ️ VoIPService: Ignoring accept for protected session state: $sessionId');
      return;
    }
    if (voipIncomingCallPayloadHasExpired(data, now: acceptTime)) {
      debugPrint('ℹ️ VoIPService: Ignoring expired accept payload');
      if (callKitId == null) {
        debugPrint(
            'ℹ️ VoIPService: Expired accept has no callKitId; leaving system calls untouched');
        return;
      }
      _sessionCallKitIds[sessionId] = callKitId;
      await _endExpiredAcceptSystemCall(
        sessionId: sessionId,
        callKitId: callKitId,
      );
      return;
    }
    if (!_tryClaimProcessAccept(sessionId)) {
      debugPrint('⚠️ VoIPService: Duplicate accept event (process gate)');
      return;
    }
    _touchSessionState(sessionId);

    final acceptGateDecision = voipEvaluateAcceptGate(
      now: acceptTime,
      lastAcceptAt: _recentAcceptBySession[sessionId],
      handledCallKitAcceptId:
          _handledCallKitAcceptIds.contains(effectiveCallKitId),
      acceptedSession: _acceptedSessions.contains(sessionId),
      acceptInProgress: _acceptInProgress.contains(sessionId),
    );
    if (_stopAcceptForGateDecision(
      sessionId: sessionId,
      effectiveCallKitId: effectiveCallKitId,
      decision: acceptGateDecision,
      releaseProcessClaim: true,
    )) {
      return;
    }

    _recentAcceptBySession[sessionId] = acceptTime;
    _handledCallKitAcceptIds.add(effectiveCallKitId);
    _lastCallKitId = effectiveCallKitId;
    _sessionCallKitIds[sessionId] = effectiveCallKitId;

    _acceptInProgress.add(sessionId);

    try {
      if (!(await _ensureAcceptMediaPermissions())) {
        debugPrint(
          '⚠️ VoIPService: camera or microphone permission denied before accepting $sessionId',
        );
        _releaseProcessAcceptClaim(sessionId);
        await endCurrentCall(sessionId: sessionId);
        return;
      }

      final isSameSession = _lastAcceptedSessionId == sessionId;
      _lastAcceptedSessionId = sessionId;
      _lastAcceptedIsTutor = false;
      _lastRoomUrl = null;
      _lastMeetingToken = null;
      _lastRoomName = null;
      if (!isSameSession) {
        _lastNavigatedSessionId = null;
        _lastNavigatedIsTutor = null;
      }

      debugPrint('✅ VoIPService: Call accepted: $sessionId');

      final payloadCredentials = voipRoomCredentialsFromAcceptedPayload(data);
      final acceptAction = voipAcceptActionFromPayload(data);
      _lastAcceptedIsTutor = payloadCredentials == null;

      // open_session means backend already accepted the pair. Do not call
      // acceptCall again; VideoCallPage/getSessionTokens can resolve credentials.
      if (payloadCredentials != null ||
          acceptAction == VoipAcceptPayloadAction.openSession) {
        _lastAcceptedIsTutor = false;
        _lastRoomUrl = payloadCredentials?.roomUrl;
        _lastMeetingToken = null;
        _lastRoomName =
            payloadCredentials?.roomName ?? voipRoomNameFromAcceptPayload(data);
        unawaited(_prefetchSessionTokensForAccept(sessionId));
        _acceptedSessions.add(sessionId);

        // Navigate FIRST, then update Firestore in the background.
        _navigateToVideoCallForAccept(
          sessionId: sessionId,
          isTutor: false,
          roomUrl: _lastRoomUrl,
          meetingToken: null,
          roomName: _lastRoomName,
        );
        debugPrint(
            '✅ VoIPService: Student navigation triggered (no acceptCall)');

        // Firestore metadata write — fire-and-forget, not needed for navigation
        unawaited(_markNavigationTriggeredForAccept(
          sessionId: sessionId,
          isTutor: false,
        ).catchError((_) {}));
        return;
      }

      // Do not navigate before acceptCall completes. CallKit/FCM can deliver
      // duplicate accept events; navigating early creates multiple Daily clients
      // before the backend lock can collapse them.
      _lastAcceptedIsTutor = true;
      _acceptedSessions.add(sessionId);

      // Call acceptCall in the background — creates the Daily room and writes
      // dailyRoomUrl to the session document. VideoCallPage's StreamBuilder
      // reacts to this update and fetches a meeting token automatically.
      unawaited(() async {
        var didResolveAcceptedSession = false;
        try {
          debugPrint('☁️ VoIPService: Calling acceptCall function...');
          final responseData = await _callAcceptCallFunction(sessionId);
          final status = responseData['status'];
          final responseCredentials =
              voipRoomCredentialsFromAcceptCallResponse(responseData);

          debugPrint('✅ VoIPService: acceptCall response: status=$status');

          if (responseCredentials != null) {
            _lastRoomUrl = responseCredentials.roomUrl;
            _lastMeetingToken = responseCredentials.meetingToken;
            _lastRoomName = responseCredentials.roomName;
            _navigateToVideoCallForAccept(
              sessionId: sessionId,
              isTutor: true,
              roomUrl: _lastRoomUrl,
              meetingToken: _lastMeetingToken,
              roomName: _lastRoomName,
            );
            debugPrint(
                '🎬 VoIPService: Navigated to VideoCallPage (tutor, after acceptCall)');
            didResolveAcceptedSession = true;
          }
        } catch (e) {
          debugPrint('❌ VoIPService: acceptCall failed: $e');
          if (await _tryRecoverActiveSession(sessionId)) {
            _navigateToVideoCallForAccept(
              sessionId: sessionId,
              isTutor: true,
              roomUrl: _lastRoomUrl,
              meetingToken: _lastMeetingToken,
              roomName: _lastRoomName,
            );
            debugPrint(
                '🎬 VoIPService: Recovered accepted call after acceptCall error');
            didResolveAcceptedSession = true;
          } else {
            _clearSessionState(sessionId);
          }
        }

        if (!didResolveAcceptedSession) {
          _clearSessionState(sessionId);
          return;
        }
        unawaited(_prefetchSessionTokensForAccept(sessionId));
        unawaited(_markNavigationTriggeredForAccept(
          sessionId: sessionId,
          isTutor: true,
        ).catchError((_) {}));
      }());
    } catch (e) {
      debugPrint('❌ VoIPService: Error in call accept flow: $e');
      _clearSessionState(sessionId);
    } finally {
      _acceptInProgress.remove(sessionId);
    }
  }

  Future<bool> _tryRecoverActiveSession(String sessionId) async {
    try {
      final override = debugRecoverActiveSessionOverride;
      if (override != null) {
        return override(sessionId);
      }
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      final sessionDoc =
          await _firestore.collection('videoSessions').doc(sessionId).get();
      if (!sessionDoc.exists) return false;
      final data = sessionDoc.data();
      if (data == null) return false;
      final status = data['status'] as String?;
      final tutorId = data['tutorId'] as String?;
      final roomUrl = data['dailyRoomUrl'] as String?;
      if (roomUrl == null || roomUrl.isEmpty) return false;
      if (tutorId != userId) return false;
      if (status != 'active' && status != 'connecting') return false;

      _lastAcceptedIsTutor = true;
      _lastRoomUrl = roomUrl;
      _lastRoomName = data['dailyRoomName'] as String?;
      _lastMeetingToken = null;
      _touchSessionState(sessionId);
      unawaited(_prefetchSessionTokens(sessionId));
      return true;
    } catch (e) {
      debugPrint('⚠️ VoIPService: Recovery check failed: $e');
      return false;
    }
  }

  String? _getFreshPrefetchedToken(String sessionId) {
    if (_prefetchedSessionId != sessionId ||
        _prefetchedMeetingToken == null ||
        _prefetchedTokenFetchedAt == null) {
      return null;
    }
    final age = DateTime.now().difference(_prefetchedTokenFetchedAt!);
    if (age.inMinutes >= 2) {
      return null;
    }
    return _prefetchedMeetingToken;
  }

  String? _getPrefetchedRoomUrl(String sessionId) {
    if (_prefetchedSessionId != sessionId) return null;
    return _prefetchedRoomUrl;
  }

  String? _getPrefetchedRoomName(String sessionId) {
    if (_prefetchedSessionId != sessionId) return null;
    return _prefetchedRoomName;
  }

  void _tryNavigateToVideoCall({
    required String sessionId,
    required bool isTutor,
    String? roomUrl,
    String? meetingToken,
    String? roomName,
  }) {
    final navContext = appNavigatorKey.currentContext;
    if (navContext == null) {
      debugPrint('⚠️ VoIPService: Navigation context not ready');
      _queueNavigation(
        sessionId: sessionId,
        isTutor: isTutor,
        roomUrl: roomUrl,
        meetingToken: meetingToken,
        roomName: roomName,
      );
      return;
    }

    if (_lastNavigatedSessionId == sessionId &&
        _lastNavigatedIsTutor == isTutor) {
      return;
    }

    final prefetchedToken = _getFreshPrefetchedToken(sessionId);
    final prefetchedRoomUrl = _getPrefetchedRoomUrl(sessionId);
    final prefetchedRoomName = _getPrefetchedRoomName(sessionId);
    final usePrefetch = prefetchedToken != null && prefetchedRoomUrl != null;
    final effectiveMeetingToken = usePrefetch ? prefetchedToken : meetingToken;
    final effectiveRoomUrl =
        usePrefetch ? prefetchedRoomUrl : (roomUrl ?? prefetchedRoomUrl);
    final effectiveRoomName =
        usePrefetch ? prefetchedRoomName : (roomName ?? prefetchedRoomName);
    final params = <String, String>{
      'videoDocRef': sessionId,
    };
    if (effectiveRoomUrl != null && effectiveRoomUrl.isNotEmpty) {
      params['roomUrl'] = effectiveRoomUrl;
    }
    if (effectiveMeetingToken != null && effectiveMeetingToken.isNotEmpty) {
      params['meetingToken'] = effectiveMeetingToken;
    }
    if (effectiveRoomName != null && effectiveRoomName.isNotEmpty) {
      params['roomName'] = effectiveRoomName;
    }
    final target =
        Uri(path: _videoCallRoutePath, queryParameters: params).toString();

    final router = GoRouter.of(navContext);
    final currentLocation = router.getCurrentLocation();
    if (_isVideoCallLocationForSession(currentLocation, sessionId)) {
      _lastNavigatedSessionId = sessionId;
      _lastNavigatedIsTutor = isTutor;
      debugPrint(
          'ℹ️ VoIPService: Already on $_videoCallRoutePath for $sessionId, skip navigation');
      return;
    }

    _lastNavigatedSessionId = sessionId;
    _lastNavigatedIsTutor = isTutor;
    router.go(target);
    debugPrint('🎬 VoIPService: Navigated to VideoCallPage');
  }

  bool _isVideoCallLocationForSession(String location, String sessionId) {
    final uri = Uri.tryParse(location);
    if (uri == null || uri.path != _videoCallRoutePath) {
      return false;
    }
    final currentVideoDocRef = _voipNonEmptyString(
      uri.queryParameters['videoDocRef'],
    );
    if (currentVideoDocRef == null) {
      return false;
    }
    return currentVideoDocRef == sessionId;
  }

  void _queueNavigation({
    required String sessionId,
    required bool isTutor,
    String? roomUrl,
    String? meetingToken,
    String? roomName,
  }) {
    _touchSessionState(sessionId);
    _pendingSessionId = sessionId;
    _pendingIsTutor = isTutor;
    _pendingRoomUrl = roomUrl;
    _pendingMeetingToken = meetingToken;
    _pendingRoomName = roomName;
    if (_navRetryInProgress) {
      return;
    }
    _navRetryInProgress = true;
    _retryPendingNavigation();
  }

  Future<void> _retryPendingNavigation() async {
    int attempts = 0;
    while (
        _pendingSessionId != null && attempts < _pendingNavigationMaxAttempts) {
      final navContext = appNavigatorKey.currentContext;
      if (navContext != null) {
        final sessionId = _pendingSessionId!;
        final isTutor = _pendingIsTutor;
        final roomUrl = _pendingRoomUrl;
        final meetingToken = _pendingMeetingToken;
        final roomName = _pendingRoomName;
        _pendingSessionId = null;
        _navRetryInProgress = false;
        _tryNavigateToVideoCall(
          sessionId: sessionId,
          isTutor: isTutor,
          roomUrl: roomUrl,
          meetingToken: meetingToken,
          roomName: roomName,
        );
        return;
      }
      await Future.delayed(_pendingNavigationRetryDelay);
      attempts++;
    }
    if (_pendingSessionId != null) {
      debugPrint(
        '⚠️ VoIPService: Navigation context not ready after extended retries',
      );
    }
    _pendingSessionId = null;
    _navRetryInProgress = false;
  }

  void _handleAudioSessionToggle(dynamic body) {
    final isActive = body is Map && body['isActivate'] == true;
    debugPrint(
      '🔈 VoIPService: Audio session ${isActive ? 'activated' : 'deactivated'}',
    );
    // Only care about activation, and only if we haven't already navigated
    if (!isActive) return;
    if (_lastNavigatedSessionId != null) {
      debugPrint(
          'ℹ️ VoIPService: Already navigated, skipping audio session toggle');
      return;
    }
    if (_lastAcceptedSessionId != null &&
        _lastRoomUrl != null &&
        _lastRoomUrl!.isNotEmpty) {
      _tryNavigateToVideoCall(
        sessionId: _lastAcceptedSessionId!,
        isTutor: _lastAcceptedIsTutor,
        roomUrl: _lastRoomUrl,
        meetingToken: _getFreshPrefetchedToken(_lastAcceptedSessionId!) ??
            _lastMeetingToken,
        roomName: _lastRoomName,
      );
    }
  }

  /// Пользователь отклонил звонок
  Future<void> _handleCallDecline(Map<String, dynamic>? data) async {
    if (data == null) return;

    final sessionId = _voipStringFromPayload(data, 'sessionId');
    if (sessionId == null || sessionId.isEmpty) {
      debugPrint('❌ VoIPService: No sessionId in decline event');
      return;
    }
    final callKitId = _normalizeCallKitId(
      _voipNonEmptyString(data['id']) ??
          _voipStringFromPayload(data, 'callKitId'),
    );
    if (_hasMismatchedTrackedCallKitId(sessionId, callKitId)) {
      debugPrint(
          'ℹ️ VoIPService: Ignoring decline for stale callKitId: $callKitId');
      return;
    }
    if (_hasProtectedLiveSessionState(sessionId)) {
      debugPrint(
          'ℹ️ VoIPService: Ignoring decline for active session: $sessionId');
      return;
    }
    final declineTime = DateTime.now();
    _pruneRecentDeclineState(declineTime);
    if (_declineInProgress.contains(sessionId)) {
      debugPrint('⚠️ VoIPService: Decline already in progress for $sessionId');
      return;
    }
    final recentDeclineAt = _recentDeclineBySession[sessionId];
    if (recentDeclineAt != null &&
        declineTime.difference(recentDeclineAt) < _declineDedupeWindow) {
      debugPrint('⚠️ VoIPService: Duplicate decline event for $sessionId');
      return;
    }

    _declineInProgress.add(sessionId);
    _touchSessionState(sessionId);
    debugPrint('❌ VoIPService: Call declined: $sessionId');

    try {
      await _callDeclineCallFunction(sessionId);
      _recentDeclineBySession[sessionId] = DateTime.now();
      _clearSessionState(sessionId);

      debugPrint('✅ VoIPService: declineCall completed');
    } catch (e) {
      debugPrint('❌ VoIPService: Error declining call: $e');
    } finally {
      _declineInProgress.remove(sessionId);
    }
  }

  /// Звонок завершен
  Future<void> _handleCallEnded(Map<String, dynamic>? data) async {
    if (data == null) return;

    final extra = data['extra'] is Map
        ? Map<String, dynamic>.from(data['extra'] as Map)
        : <String, dynamic>{};
    final sessionId =
        extra['sessionId'] as String? ?? data['sessionId'] as String?;
    if (sessionId == null) {
      debugPrint('❌ VoIPService: No sessionId in ended event');
      return;
    }
    final callKitId = _normalizeCallKitId(
      data['id'] as String? ?? extra['callKitId'] as String?,
    );
    if (_hasMismatchedTrackedCallKitId(sessionId, callKitId)) {
      debugPrint(
          'ℹ️ VoIPService: Ignoring endSession for stale callKitId: $callKitId');
      return;
    }

    final canEndSessionFromMemory = _canEndSessionFromInMemoryState(sessionId);
    final fallbackStartGeneration = _sessionStateGenerations[sessionId];
    final shouldEndViaFallback = !canEndSessionFromMemory
        ? await _shouldEndSessionViaFallbackLookup(sessionId)
        : false;
    if (!canEndSessionFromMemory &&
        shouldEndViaFallback &&
        fallbackStartGeneration != _sessionStateGenerations[sessionId]) {
      debugPrint(
          'ℹ️ VoIPService: Ignoring endSession because session state changed during fallback: $sessionId');
      return;
    }

    if (!canEndSessionFromMemory && !shouldEndViaFallback) {
      debugPrint(
          'ℹ️ VoIPService: Ignoring endSession for unknown session: $sessionId');
      return;
    }

    _clearSessionState(sessionId);
    debugPrint('🔚 VoIPService: Call ended: $sessionId');

    try {
      // Вызываем Cloud Function endSession
      await _functions.httpsCallable('endSession').call({
        'sessionId': sessionId,
        'endReason': 'user_ended',
      });

      debugPrint('✅ VoIPService: endSession completed');
    } catch (e) {
      debugPrint('❌ VoIPService: Error ending session: $e');
    }
  }

  /// Таймаут звонка (45 секунд без ответа)
  Future<void> _handleCallTimeout(Map<String, dynamic>? data) async {
    if (data == null) return;

    final sessionId = _voipStringFromPayload(data, 'sessionId');
    if (sessionId == null || sessionId.isEmpty) {
      debugPrint('❌ VoIPService: No sessionId in timeout event');
      return;
    }
    final callKitId = _normalizeCallKitId(
      _voipNonEmptyString(data['id']) ??
          _voipStringFromPayload(data, 'callKitId'),
    );
    if (_hasMismatchedTrackedCallKitId(sessionId, callKitId)) {
      debugPrint(
          'ℹ️ VoIPService: Ignoring timeout for stale callKitId: $callKitId');
      return;
    }
    if (_hasProtectedLiveSessionState(sessionId)) {
      debugPrint(
          'ℹ️ VoIPService: Ignoring timeout for active session: $sessionId');
      return;
    }
    if (!_hasTrackedSessionState(sessionId) &&
        !_hasTrustedCallKitIdentity(sessionId, callKitId)) {
      debugPrint(
          'ℹ️ VoIPService: Ignoring timeout for unknown session: $sessionId');
      return;
    }

    _clearSessionState(sessionId);
    debugPrint('⏰ VoIPService: Call timeout: $sessionId');

    // Ничего не делаем - Cloud Function processExpiredNotifications обработает
  }

  void _clearSessionState(String sessionId) {
    _sessionStateTouchedAt.remove(sessionId);
    _sessionStateGenerations.remove(sessionId);
    _acceptInProgress.remove(sessionId);
    _acceptedSessions.remove(sessionId);
    _recentAcceptBySession.remove(sessionId);
    _declineInProgress.remove(sessionId);
    _processAcceptClaimedAtBySession.remove(sessionId);
    final callKitIdForSession = _sessionCallKitIds[sessionId];
    if (callKitIdForSession != null) {
      _handledCallKitAcceptIds.remove(callKitIdForSession);
      if (_lastCallKitId == callKitIdForSession) {
        _lastCallKitId = null;
      }
    }
    if (_lastAcceptedSessionId == sessionId) {
      _lastAcceptedSessionId = null;
      _lastAcceptedIsTutor = false;
      _lastRoomUrl = null;
      _lastMeetingToken = null;
      _lastRoomName = null;
      _lastNavigatedSessionId = null;
      _lastNavigatedIsTutor = null;
    }
    if (_pendingSessionId == sessionId) {
      _pendingSessionId = null;
      _pendingIsTutor = false;
      _pendingRoomUrl = null;
      _pendingMeetingToken = null;
      _pendingRoomName = null;
      _navRetryInProgress = false;
    }
    if (_prefetchedSessionId == sessionId) {
      _prefetchedSessionId = null;
      _clearPrefetchedSessionCredentials();
      _prefetchInProgress = false;
    }
    _sessionCallKitIds.remove(sessionId);
  }

  Future<void> _endExpiredAcceptSystemCall({
    required String sessionId,
    required String callKitId,
  }) async {
    try {
      final override = debugEndCallKitCallOverride;
      if (override != null) {
        await override(sessionId: sessionId, callKitId: callKitId);
      } else {
        await FlutterCallkitIncoming.endCall(callKitId);
      }
      _clearSessionState(sessionId);
      debugPrint('✅ VoIPService: Expired accept system call cleared');
    } catch (e) {
      debugPrint('❌ VoIPService: Error ending expired accept call: $e');
    }
  }

  Future<void> _prefetchSessionTokens(String sessionId) async {
    _touchSessionState(sessionId);
    if (_prefetchInProgress && _prefetchedSessionId == sessionId) return;
    final requestGeneration = ++_prefetchRequestGeneration;
    _prefetchInProgress = true;
    if (_prefetchedSessionId != sessionId) {
      _clearPrefetchedSessionCredentials();
    }
    _prefetchedSessionId = sessionId;
    try {
      final data = await _callGetSessionTokensFunction(sessionId);
      if (_prefetchedSessionId != sessionId ||
          _prefetchRequestGeneration != requestGeneration) {
        return;
      }
      final token = data['meetingToken'] as String?;
      final roomUrl = data['roomUrl'] as String?;
      final roomName = data['roomName'] as String?;

      if (token != null && token.isNotEmpty) {
        _prefetchedMeetingToken = token;
        _prefetchedTokenFetchedAt = DateTime.now();
      }
      if (roomUrl != null && roomUrl.isNotEmpty) {
        _prefetchedRoomUrl = roomUrl;
      }
      if (roomName != null && roomName.isNotEmpty) {
        _prefetchedRoomName = roomName;
      }
    } catch (e) {
      debugPrint('⚠️ VoIPService: Prefetch token failed: $e');
    } finally {
      if (_prefetchedSessionId == sessionId &&
          _prefetchRequestGeneration == requestGeneration) {
        _prefetchInProgress = false;
      }
    }
  }

  /// Отметить звонок как подключенный (CallKit)
  Future<void> markCallConnected({String? sessionId}) async {
    try {
      final callKitId =
          sessionId != null ? _sessionCallKitIds[sessionId] : _lastCallKitId;
      if (callKitId == null) return;
      await FlutterCallkitIncoming.setCallConnected(callKitId);
    } catch (e) {
      debugPrint('❌ VoIPService: Error marking call connected: $e');
    }
  }

  bool _hasActiveCallEntries(dynamic calls) {
    if (calls is Iterable) {
      return calls.isNotEmpty;
    }
    if (calls is Map) {
      return calls.isNotEmpty;
    }
    if (calls is String) {
      return calls.trim().isNotEmpty && calls.trim() != '[]';
    }
    return false;
  }

  /// Закрыть конкретный входящий системный звонок без затрагивания других.
  Future<void> cancelIncomingCall({required String sessionId}) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return;
    }
    final callKitId = _sessionCallKitIds[normalizedSessionId] ??
        _callKitIdForSession(normalizedSessionId);
    try {
      final override = debugEndCallKitCallOverride;
      if (override != null) {
        await override(
          sessionId: normalizedSessionId,
          callKitId: callKitId,
        );
      } else {
        await FlutterCallkitIncoming.endCall(callKitId);
      }
      _clearSessionState(normalizedSessionId);
      debugPrint('✅ VoIPService: Incoming system call cleared');
    } catch (e) {
      debugPrint('❌ VoIPService: Error clearing incoming call: $e');
    }
  }

  /// Завершить текущий активный звонок (программно)
  Future<void> endCurrentCall({String? sessionId}) async {
    try {
      final callKitId =
          sessionId != null ? _sessionCallKitIds[sessionId] : _lastCallKitId;
      if (callKitId != null) {
        await FlutterCallkitIncoming.endCall(callKitId);
      }

      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      if (_hasActiveCallEntries(activeCalls)) {
        await FlutterCallkitIncoming.endAllCalls();
      }

      if (sessionId != null) {
        _clearSessionState(sessionId);
        if (callKitId != null && _lastCallKitId == callKitId) {
          _lastCallKitId = null;
        }
      } else {
        _sessionCallKitIds.clear();
        _handledCallKitAcceptIds.clear();
        _lastCallKitId = null;
      }

      debugPrint('✅ VoIPService: System call UI cleared');
    } catch (e) {
      debugPrint('❌ VoIPService: Error ending calls: $e');
    }
  }

  /// Проверить, есть ли активные звонки
  Future<bool> hasActiveCalls() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      return _hasActiveCallEntries(calls);
    } catch (e) {
      debugPrint('❌ VoIPService: Error checking active calls: $e');
      return false;
    }
  }
}
