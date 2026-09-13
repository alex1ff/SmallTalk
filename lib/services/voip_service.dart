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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// Импорт для навигации и backend
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/nav/nav.dart';
import '/flutter_flow/permissions_util.dart';
import '/services/match_coordinator.dart';
import '/services/safe_debug_log.dart';
import '/services/voip_accept_lifecycle.dart';
import '/services/voip_accepted_session_resolver.dart';
import '/services/voip_navigation_coordinator.dart';
import '/services/voip_pending_callkit_action_queue.dart';
import '/services/voip_token_registry.dart';

const int _incomingCallTimeoutMilliseconds = 45000;
const String _videoCallRoutePath = '/videoCallPage';

@visibleForTesting
bool voipIsDefinitiveV2AcceptFailure(Object error) {
  if (error is! FirebaseFunctionsException) return false;
  return const <String>{
    'invalid-argument',
    'unauthenticated',
    'permission-denied',
    'not-found',
  }.contains(error.code);
}

@visibleForTesting
String voipClientPlatform({
  bool? isWeb,
  TargetPlatform? targetPlatform,
}) {
  if (isWeb ?? kIsWeb) return 'web';
  switch (targetPlatform ?? defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}

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
  'matchProtocolVersion',
  'confirmationVersion',
  'pairAttemptId',
  'surface',
  'delivery',
  'deliveryFailureKind',
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
int voipIncomingCallDurationMilliseconds(
  Map<String, dynamic> data, {
  DateTime? now,
}) {
  final parsedExpiresAt = _voipDateTimeFromPayloadValue(
    _voipValueFromPayload(data, 'expiresAt'),
  );
  if (parsedExpiresAt == null) {
    return _incomingCallTimeoutMilliseconds;
  }
  return parsedExpiresAt
      .difference(now ?? DateTime.now())
      .inMilliseconds
      .clamp(1, _incomingCallTimeoutMilliseconds);
}

@visibleForTesting
bool voipIncomingCallShouldUseInAppNavigation(
  Map<String, dynamic> data, {
  AppLifecycleState? lifecycleState,
}) {
  final isForeground = lifecycleState == AppLifecycleState.resumed;
  if (!isForeground) {
    return false;
  }
  // A delivered v2 incoming_call is already committed to CallKit by the
  // server. Foreground delivery must never be converted into an accept.
  if (_voipUsesMatchProtocolV2(data)) {
    return false;
  }

  final navRole = _voipStringFromPayload(data, 'navRole')?.toLowerCase();
  final responderRole =
      _voipStringFromPayload(data, 'responderRole')?.toLowerCase();
  final recipientId = _voipStringFromPayload(data, 'recipientId');
  final responderId = _voipStringFromPayload(data, 'responderId');
  final targetsNativeSpeakerResponder = navRole == 'tutor' ||
      (responderRole == 'native_speaker' &&
          recipientId != null &&
          recipientId == responderId);

  final surface = _voipStringFromPayload(data, 'surface')?.toLowerCase();
  final delivery = _voipStringFromPayload(data, 'delivery')?.toLowerCase();
  final callKitLocked =
      surface == 'callkit' || delivery == 'dispatching' || delivery == 'sent';

  return !targetsNativeSpeakerResponder && !callKitLocked;
}

bool _voipUsesMatchProtocolV2(Map<String, dynamic> data) {
  final version = int.tryParse(
        (_voipValueFromPayload(data, 'matchProtocolVersion') ??
                _voipValueFromPayload(data, 'confirmationVersion') ??
                '')
            .toString(),
      ) ??
      0;
  final acceptMode = _voipStringFromPayload(data, 'acceptMode')?.toLowerCase();
  return version >= matchProtocolVersion || acceptMode == 'respond_to_match';
}

@visibleForTesting
bool voipV2NotificationMatchesSession({
  required Map<String, dynamic> notificationData,
  required Map<String, dynamic> sessionData,
  required String userId,
}) {
  if (!_voipUsesMatchProtocolV2(notificationData)) return true;
  final sessionStatus =
      _voipNonEmptyString(sessionData['status'])?.toLowerCase();
  if (sessionStatus != 'searching' && sessionStatus != 'pending_confirmation') {
    return false;
  }
  final notificationAttempt =
      _voipStringFromPayload(notificationData, 'pairAttemptId');
  final sessionAttempt = _voipNonEmptyString(sessionData['pairAttemptId']) ??
      _voipNonEmptyString(
          _voipMapFrom(sessionData['matchContext'])['pairAttemptId']);
  if (notificationAttempt == null ||
      sessionAttempt == null ||
      notificationAttempt != sessionAttempt) {
    return false;
  }
  final participantStates = _voipMapFrom(sessionData['participantStates']);
  final participant = _voipMapFrom(participantStates[userId]);
  final surface = _voipNonEmptyString(participant['surface'])?.toLowerCase();
  final delivery = _voipNonEmptyString(participant['delivery'])?.toLowerCase();
  final decision = _voipNonEmptyString(participant['decision'])?.toLowerCase();
  if (surface != 'callkit' ||
      decision != 'pending' ||
      (delivery != 'dispatching' && delivery != 'sent')) {
    return false;
  }
  final notificationCallKitId =
      _voipStringFromPayload(notificationData, 'callKitId');
  final sessionCallKitId = _voipNonEmptyString(participant['callKitId']);
  if (notificationCallKitId == null || sessionCallKitId == null) {
    return false;
  }
  return _normalizeStandaloneCallKitId(notificationCallKitId) ==
      _normalizeStandaloneCallKitId(sessionCallKitId);
}

String _normalizeStandaloneCallKitId(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized;
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
  final callData = activeCall is CallKitParams
      ? _voipMapFrom(activeCall.toJson())
      : _voipMapFrom(activeCall);
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

/// VoIP сервис для обработки входящих звонков
/// Использует CallKit (iOS) и ConnectionService (Android)
class VoIPService {
  static final VoIPService _instance = VoIPService._internal();
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final VoipProcessAcceptGate _processAcceptGate =
      VoipProcessAcceptGate();
  static const Duration _declineDedupeWindow = Duration(minutes: 2);
  static const Duration _pendingNavigationRetryDelay =
      Duration(milliseconds: 100);
  static const int _pendingNavigationMaxAttempts = 600;
  static const Duration _pendingCallKitActionTtl = Duration(minutes: 2);
  static const int _pendingCallKitActionMaxCount = 16;
  static const Duration _serverEndedCallKitTombstoneTtl = Duration(minutes: 10);
  static const String _serverEndedCallKitTombstonesPreferenceKey =
      'smalltalk.serverEndedCallKitTombstones';
  factory VoIPService() => _instance;
  VoIPService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFunctions get _functions => FirebaseFunctions.instance;

  bool _initialized = false;
  bool _initializing = false;
  Completer<void>? _initializeCompleter;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _incomingNotificationSub;
  StreamSubscription<CallEvent?>? _callKitSubscription;
  Timer? _sessionPruneTimer;
  bool _callActionHandlingReady = false;
  bool _pendingCallKitActionsDraining = false;
  final Map<String, DateTime> _sessionStateTouchedAt = {};
  final VoipPendingCallKitActionQueue _pendingCallKitActions =
      VoipPendingCallKitActionQueue(
    ttl: _pendingCallKitActionTtl,
    maxCount: _pendingCallKitActionMaxCount,
  );
  final Set<String> _declineInProgress = {};
  final Map<String, DateTime> _recentDeclineBySession = {};
  final Map<String, int> _sessionStateGenerations = {};
  final Set<String> _handledNotificationIds = {};
  String? _lastAcceptedSessionId;
  bool _lastAcceptedIsTutor = false;
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
  final Map<String, String> _sessionPairAttemptIds = {};
  final Map<String, Map<String, dynamic>> _callKitEventDataById = {};
  final Map<String, DateTime> _serverEndedCallKitTombstones = {};
  String? _lastCallKitId;
  String? _notificationListenerUserId;
  late final VoipTokenRegistry _tokenRegistry = VoipTokenRegistry(
    currentUserId: _currentUserIdOrNull,
    invokeRegistration: _invokeVoipTokenRegistration,
    readPushKitToken: FlutterCallkitIncoming.getDevicePushTokenVoIP,
    clientPlatform: voipClientPlatform,
    matchProtocolVersion: () => matchProtocolVersion,
    log: debugPrint,
  );
  late final VoipAcceptedSessionResolver _acceptedSessionResolver =
      VoipAcceptedSessionResolver(currentUserId: _currentUserIdOrNull);
  late final VoipAcceptLifecycle _acceptLifecycle = VoipAcceptLifecycle(
    processGate: _processAcceptGate,
    sessionStateTtl: _sessionStateTtl,
  );
  final Map<String, VoipAcceptAttemptToken> _debugAcceptAttempts =
      <String, VoipAcceptAttemptToken>{};
  late final VoipNavigationCoordinator _navigationCoordinator =
      VoipNavigationCoordinator(
    attempt: _attemptVideoCallNavigation,
    onRetryExhausted: _logNavigationRetryExhausted,
    retryDelay: _pendingNavigationRetryDelay,
    maxAttempts: _pendingNavigationMaxAttempts,
    routePath: _videoCallRoutePath,
  );
  String? get _lastNavigatedSessionId =>
      _navigationCoordinator.lastNavigatedSessionId;
  String? get _pendingSessionId => _navigationCoordinator.pendingSessionId;
  @visibleForTesting
  MatchCoordinator? debugMatchCoordinatorOverride;
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
  Future<void> Function(String sessionId)? debugEndSessionOverride;
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
      _pendingCallKitActions.prune(
        now: now ?? DateTime.now(),
        currentUserId: _currentUserIdOrNull(),
        acceptPayloadHasExpired: (data, effectiveNow) =>
            voipIncomingCallPayloadHasExpired(data, now: effectiveNow),
      );
      while (_canHandleCallKitActions && _pendingCallKitActions.isNotEmpty) {
        final action = _pendingCallKitActions.removeFirst();
        if (!_pendingCallKitActions.isEligible(
          action,
          now: now ?? DateTime.now(),
          currentUserId: _currentUserIdOrNull(),
          acceptPayloadHasExpired: (data, effectiveNow) =>
              voipIncomingCallPayloadHasExpired(data, now: effectiveNow),
        )) {
          continue;
        }
        switch (action.type) {
          case VoipPendingCallKitActionType.accept:
            await _handleCallAccept(action.data, now: now);
            break;
          case VoipPendingCallKitActionType.decline:
            await _handleCallDecline(action.data);
            break;
          case VoipPendingCallKitActionType.timeout:
            await _handleCallTimeout(action.data);
            break;
          case VoipPendingCallKitActionType.ended:
            await _handleCallEnded(action.data);
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
        safeDebugLog(
          '📞 VoIPService: Replaying background accepted call: $sessionId',
        );
        if (_queueCallKitActionIfNotReady(
          type: VoipPendingCallKitActionType.accept,
          data: acceptData,
        )) {
          continue;
        }
        if (_shouldDropCallKitActionForCurrentUser(
          type: VoipPendingCallKitActionType.accept,
          data: acceptData,
        )) {
          continue;
        }
        await _handleCallAccept(acceptData);
      }
    } catch (e) {
      safeDebugLog('⚠️ VoIPService: Failed to replay background accept: $e');
    }
  }

  @visibleForTesting
  void debugResetInMemoryStateForTesting() {
    _initialized = false;
    _initializing = false;
    _initializeCompleter = null;
    _resetInMemoryState();
    _resetTestingOverrides();
  }

  @visibleForTesting
  bool debugTryClaimProcessAcceptForTesting(String sessionId) {
    final result = _acceptLifecycle.begin(
      VoipAcceptIdentity(
        sessionId: sessionId,
        callKitId: _callKitIdForSession('debug-process:$sessionId'),
      ),
      now: DateTime.now(),
    );
    final token = result.token;
    if (token == null) return false;
    _debugAcceptAttempts[sessionId] = token;
    return true;
  }

  @visibleForTesting
  bool debugHasProcessAcceptClaimForTesting(String sessionId) {
    return _processAcceptGate.hasClaim(sessionId, now: DateTime.now());
  }

  @visibleForTesting
  void debugReleaseProcessAcceptClaimForTesting(String sessionId) {
    final token = _debugAcceptAttempts.remove(sessionId);
    if (token != null) {
      _acceptLifecycle.releaseForRetry(token);
    }
  }

  @visibleForTesting
  void debugMarkAcceptInProgressForTesting(String sessionId) {
    _debugEnsureAcceptAttempt(sessionId);
  }

  @visibleForTesting
  bool debugAcceptInProgressForTesting(String sessionId) {
    return _acceptLifecycle.isAcceptInProgress(sessionId);
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
    final token = _debugEnsureAcceptAttempt(sessionId);
    if (token != null) {
      _acceptLifecycle.markAccepted(token);
    }
  }

  @visibleForTesting
  bool debugAcceptedSessionForTesting(String sessionId) {
    return _acceptLifecycle.isAccepted(sessionId);
  }

  @visibleForTesting
  String? debugCallKitIdForSessionForTesting(String sessionId) {
    return _sessionCallKitIds[sessionId];
  }

  @visibleForTesting
  void debugTrackCallKitSessionForTesting({
    required String sessionId,
    required String callKitId,
    String? pairAttemptId,
  }) {
    final normalizedCallKitId = _normalizeCallKitId(callKitId);
    if (normalizedCallKitId == null) return;
    _sessionCallKitIds[sessionId] = normalizedCallKitId;
    final normalizedPairAttemptId = _voipNonEmptyString(pairAttemptId);
    if (normalizedPairAttemptId != null) {
      _sessionPairAttemptIds[sessionId] = normalizedPairAttemptId;
    }
    _lastCallKitId = normalizedCallKitId;
  }

  @visibleForTesting
  void debugTrackHandledCallKitAcceptForTesting({
    required String sessionId,
    required String callKitId,
  }) {
    final normalizedCallKitId = _normalizeCallKitId(callKitId);
    if (normalizedCallKitId == null) return;
    final existing = _debugAcceptAttempts[sessionId];
    final hadActiveAttempt =
        existing != null && _acceptLifecycle.isCurrent(existing);
    _sessionCallKitIds[sessionId] = normalizedCallKitId;
    final token = _debugEnsureAcceptAttempt(
      sessionId,
      callKitId: normalizedCallKitId,
    );
    if (!hadActiveAttempt && token != null) {
      _acceptLifecycle.finish(token);
      _debugAcceptAttempts.remove(sessionId);
    }
    _lastCallKitId = normalizedCallKitId;
  }

  @visibleForTesting
  bool debugHandledCallKitAcceptForTesting(String callKitId) {
    final normalizedCallKitId = _normalizeCallKitId(callKitId);
    return normalizedCallKitId != null &&
        _acceptLifecycle.hasHandledCallKitId(normalizedCallKitId);
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
      CallEventActionCallAccept(_callKitParamsForTesting(data)),
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
      CallEventActionCallDecline(_callKitParamsForTesting(data)),
    );
  }

  @visibleForTesting
  Future<void> debugHandleCallTimeoutForTesting(Map<String, dynamic> data) {
    return _handleCallTimeout(data);
  }

  @visibleForTesting
  Future<void> debugHandleCallEndedForTesting(Map<String, dynamic> data) {
    return _handleCallEnded(data);
  }

  VoipAcceptAttemptToken? _debugEnsureAcceptAttempt(
    String sessionId, {
    String? callKitId,
  }) {
    final existing = _debugAcceptAttempts[sessionId];
    final effectiveCallKitId = callKitId ??
        existing?.identity.callKitId ??
        _callKitIdForSession('debug-accept:$sessionId');
    if (existing != null &&
        _acceptLifecycle.isCurrent(existing) &&
        existing.identity.callKitId == effectiveCallKitId) {
      return existing;
    }

    final wasAccepted = _acceptLifecycle.isAccepted(sessionId);
    if (existing != null && _acceptLifecycle.isCurrent(existing)) {
      _acceptLifecycle.releaseForRetry(existing);
    } else if (_acceptLifecycle.hasSessionState(sessionId)) {
      _acceptLifecycle.invalidate(sessionId);
    }
    final result = _acceptLifecycle.begin(
      VoipAcceptIdentity(
        sessionId: sessionId,
        callKitId: effectiveCallKitId,
      ),
      now: DateTime.now(),
    );
    final token = result.token;
    if (token == null) return null;
    _debugAcceptAttempts[sessionId] = token;
    if (wasAccepted) {
      _acceptLifecycle.markAccepted(token);
    }
    return token;
  }

  @visibleForTesting
  Future<void> debugHandleCallKitTimeoutEventForTesting(
    Map<String, dynamic> data,
  ) {
    final params = _callKitParamsForTesting(data);
    _rememberCallKitEventData(params);
    return _handleCallKitEvent(
      CallEventActionCallTimeout(params.id),
    );
  }

  CallKitParams _callKitParamsForTesting(Map<String, dynamic> data) {
    final normalized = _voipMapFrom(data);
    final nestedExtra = _voipMapFrom(normalized['extra']);
    final sessionId = _voipNonEmptyString(nestedExtra['sessionId']) ??
        _voipNonEmptyString(normalized['sessionId']);
    final callKitId = _voipNonEmptyString(normalized['id']) ??
        _voipNonEmptyString(nestedExtra['callKitId']) ??
        (sessionId == null
            ? const Uuid().v4()
            : _callKitIdForSession(sessionId));
    final extra = <String, dynamic>{
      ...voipIncomingCallExtraDataFromPayload(normalized),
      ...nestedExtra,
      if (sessionId != null) 'sessionId': sessionId,
      'callKitId': callKitId,
    };
    return CallKitParams(
      id: callKitId,
      isAccepted: _voipBoolFrom(normalized['isAccepted']),
      extra: extra,
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
    debugEndSessionOverride = null;
    debugCurrentUserIdOverride = null;
    debugGetSessionTokensOverride = null;
    debugMarkNavigationTriggeredOverride = null;
    debugNavigateToVideoCallOverride = null;
    debugMatchCoordinatorOverride = null;
  }

  MatchCoordinator get _matchCoordinator =>
      debugMatchCoordinatorOverride ?? MatchCoordinator.instance;

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

  bool _hasMismatchedTrackedPairAttempt(
    String sessionId,
    Map<String, dynamic> data,
  ) {
    final incomingAttempt = _voipStringFromPayload(data, 'pairAttemptId');
    final trackedAttempt = _sessionPairAttemptIds[sessionId];
    return incomingAttempt != null &&
        trackedAttempt != null &&
        incomingAttempt != trackedAttempt;
  }

  bool _adoptExactV2CallKitIdentity(
    String sessionId,
    Map<String, dynamic> data,
    String? eventCallKitId,
  ) {
    if (!_voipUsesMatchProtocolV2(data)) return true;
    final pairAttemptId = _voipStringFromPayload(data, 'pairAttemptId');
    final payloadCallKitId = _normalizeCallKitId(
      _voipStringFromPayload(data, 'callKitId'),
    );
    final recipientId = _voipStringFromPayload(data, 'recipientId');
    final currentUserId = _currentUserIdOrNull();
    if (pairAttemptId == null ||
        payloadCallKitId == null ||
        eventCallKitId == null ||
        payloadCallKitId != eventCallKitId ||
        recipientId == null ||
        currentUserId == null ||
        recipientId != currentUserId) {
      return false;
    }

    final trackedAttempt = _sessionPairAttemptIds[sessionId];
    final trackedCallKitId = _sessionCallKitIds[sessionId];
    if ((trackedAttempt != null && trackedAttempt != pairAttemptId) ||
        (trackedCallKitId != null && trackedCallKitId != payloadCallKitId)) {
      return false;
    }

    _sessionPairAttemptIds[sessionId] = pairAttemptId;
    _sessionCallKitIds[sessionId] = payloadCallKitId;
    _lastCallKitId = payloadCallKitId;
    _touchSessionState(sessionId);
    return true;
  }

  bool _v2EndedCallMatchesTrackedIdentity(
    String sessionId,
    Map<String, dynamic> data,
    String? callKitId,
  ) {
    final incomingAttempt = _voipStringFromPayload(data, 'pairAttemptId');
    final trackedAttempt = _sessionPairAttemptIds[sessionId];
    final trackedCallKitId = _sessionCallKitIds[sessionId];
    return incomingAttempt != null &&
        trackedAttempt != null &&
        incomingAttempt == trackedAttempt &&
        callKitId != null &&
        trackedCallKitId != null &&
        callKitId == trackedCallKitId;
  }

  bool _hasTrustedCallKitIdentity(String sessionId, String? callKitId) {
    return callKitId != null &&
        !_hasMismatchedTrackedCallKitId(sessionId, callKitId);
  }

  bool _hasProtectedLiveSessionState(String sessionId) {
    return sessionId == _lastAcceptedSessionId ||
        sessionId == _lastNavigatedSessionId ||
        sessionId == _pendingSessionId ||
        _acceptLifecycle.isAccepted(sessionId) ||
        _acceptLifecycle.isAcceptInProgress(sessionId);
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
        _acceptLifecycle.hasSessionState(sessionId) ||
        _hasProtectedLiveSessionState(sessionId);
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
      safeDebugLog('⚠️ VoIPService: endSession fallback lookup failed: $e');
      return false;
    }
  }

  /// Инициализация VoIP сервиса
  /// Вызывается один раз при запуске приложения
  Future<void> initialize() async {
    if (_initialized) {
      safeDebugLog('🔔 VoIPService: Initialize skipped (already running)');
      _ensureCallKitEventSubscription();
      _startIncomingNotificationListener();
      unawaited(_refreshPushRegistrationsBestEffort());
      await recoverBackgroundAcceptedCalls();
      await drainPendingCallKitActions();
      return;
    }
    if (_initializing) {
      safeDebugLog('🔔 VoIPService: Initialize already in progress');
      _ensureCallKitEventSubscription();
      await _initializeCompleter?.future;
      if (!_initialized) {
        // The concurrent attempt may have failed before the essential
        // CallKit pipeline became ready. Retry instead of silently leaving
        // queued Accept/Decline actions unhandled.
        return initialize();
      }
      await drainPendingCallKitActions();
      return;
    }
    _initializing = true;
    final initializeCompleter = Completer<void>();
    _initializeCompleter = initializeCompleter;
    safeDebugLog('🔔 VoIPService: Initializing...');

    try {
      // CallKit action handling is essential. It must become ready even when
      // Firebase Messaging has not received the APNs token yet on cold start.
      _ensureCallKitEventSubscription();

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) {
        safeDebugLog('🔔 VoIPService: Token refreshed');
        unawaited(_saveVoipToken(newToken));
      });

      await _foregroundMessageSub?.cancel();
      _foregroundMessageSub =
          FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        if (message.data['type'] == 'call_cancelled') {
          final sessionId = _voipNonEmptyString(message.data['sessionId']);
          if (sessionId != null) {
            await cancelIncomingCall(
              sessionId: sessionId,
              callKitId: _voipNonEmptyString(message.data['callKitId']),
              pairAttemptId: _voipNonEmptyString(message.data['pairAttemptId']),
            );
          }
          return;
        }
        if (message.data['type'] != 'incoming_call') return;
        if (kIsWeb) return;

        safeDebugLog('📞 VoIPService: Foreground incoming call received');
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
          safeDebugLog(
              '❌ VoIPService: Failed to show CallKit in foreground: $e');
        }
      });

      _startSessionPruneTimer();
      _startIncomingNotificationListener();
      _initialized = true;

      await recoverBackgroundAcceptedCalls();
      await drainPendingCallKitActions();
      unawaited(_refreshPushRegistrationsBestEffort());
      safeDebugLog('✅ VoIPService: Initialized successfully');
    } catch (e) {
      safeDebugLog('❌ VoIPService: Initialization error: $e');
    } finally {
      _initializing = false;
      if (!initializeCompleter.isCompleted) {
        initializeCompleter.complete();
      }
      if (identical(_initializeCompleter, initializeCompleter)) {
        _initializeCompleter = null;
      }
    }
  }

  Future<void> _refreshPushRegistrationsBestEffort() async {
    final expectedUserId = _currentUserIdOrNull();
    if (expectedUserId == null) return;

    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );
      safeDebugLog(
        '🔔 VoIPService: Permission status: ${settings.authorizationStatus}',
      );
    } catch (error) {
      safeDebugLog('⚠️ VoIPService: Push permission sync failed: $error');
    }

    try {
      final platform = voipClientPlatform();
      if (platform == 'ios' || platform == 'macos') {
        final apnsToken = await _fcm.getAPNSToken();
        if (apnsToken == null || apnsToken.trim().isEmpty) {
          safeDebugLog(
            'ℹ️ VoIPService: APNs token is not ready; FCM sync deferred',
          );
        } else {
          await _syncFcmTokenForUser(expectedUserId);
        }
      } else {
        await _syncFcmTokenForUser(expectedUserId);
      }
    } catch (error) {
      safeDebugLog('⚠️ VoIPService: FCM token sync deferred: $error');
    }

    await _syncPushKitToken();
  }

  Future<void> _syncFcmTokenForUser(String expectedUserId) async {
    final fcmToken = await _fcm.getToken();
    if (_currentUserIdOrNull() != expectedUserId) return;
    if (fcmToken == null || fcmToken.trim().isEmpty) {
      safeDebugLog('⚠️ VoIPService: Failed to get FCM token');
      return;
    }
    safeDebugLog('🔔 VoIPService: Got FCM token');
    await _saveVoipToken(fcmToken);
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
        safeDebugLog(
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
    required Map<String, dynamic> notificationData,
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

      final matchesRecipient = _voipUsesMatchProtocolV2(notificationData)
          ? voipV2NotificationMatchesSession(
              notificationData: notificationData,
              sessionData: sessionData,
              userId: userId,
            )
          : voipIncomingSessionMatchesResponder(
              sessionData: sessionData,
              userId: userId,
            );
      if (!matchesRecipient) {
        return null;
      }

      return sessionData;
    } catch (error) {
      safeDebugLog(
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
        safeDebugLog(
          '📴 VoIPService: Incoming call cancelled for session $sessionId',
        );
        await cancelIncomingCall(
          sessionId: sessionId,
          callKitId: _nonEmptyString(notificationData['callKitId']),
          pairAttemptId: _nonEmptyString(notificationData['pairAttemptId']),
        );
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
      notificationData: notificationData,
    );
    if (sessionData == null) {
      return;
    }
    if (!voipV2NotificationMatchesSession(
      notificationData: notificationData,
      sessionData: sessionData,
      userId: userId,
    )) {
      safeDebugLog(
        'ℹ️ VoIPService: Ignoring stale or non-CallKit v2 notification',
      );
      return;
    }

    _handledNotificationIds.add(notificationDoc.id);
    final notificationStudentInfo = _mapFrom(notificationData['studentInfo']);
    final sessionStudentInfo = _mapFrom(sessionData['studentInfo']);
    final callerName = _nonEmptyString(notificationData['callerName']) ??
        _nonEmptyString(notificationData['studentName']) ??
        _nonEmptyString(notificationStudentInfo['name']) ??
        _nonEmptyString(sessionStudentInfo['name']) ??
        'Unknown Caller';
    final participantIds = sessionData['participantIds'];
    String? otherParticipantId;
    if (participantIds is Iterable) {
      for (final candidate in participantIds) {
        final candidateId = _nonEmptyString(candidate);
        if (candidateId != null && candidateId != userId) {
          otherParticipantId = candidateId;
          break;
        }
      }
    }
    otherParticipantId ??= _nonEmptyString(sessionData['requesterId']) == userId
        ? _nonEmptyString(sessionData['responderId'])
        : _nonEmptyString(sessionData['requesterId']);
    final explicitCallerId = _nonEmptyString(notificationData['callerId']);
    final notificationStudentId =
        _nonEmptyString(notificationData['studentId']);
    final callerId = _voipUsesMatchProtocolV2(notificationData)
        ? explicitCallerId ?? otherParticipantId ?? notificationStudentId ?? ''
        : explicitCallerId ?? notificationStudentId ?? otherParticipantId ?? '';
    final callerPhoto = _nonEmptyString(notificationData['callerPhoto']) ??
        _nonEmptyString(notificationData['studentPhoto']) ??
        _nonEmptyString(notificationStudentInfo['photo']) ??
        _nonEmptyString(sessionStudentInfo['photo']);
    final payloadExpiresAt =
        _payloadExpiresAtForIncomingNotification(notificationData);

    safeDebugLog(
        '📞 VoIPService: Firestore incoming call notification received');
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
    _acceptLifecycle.reset();
    _debugAcceptAttempts.clear();
    _acceptedSessionResolver.reset();
    _navigationCoordinator.reset();
    _sessionPruneTimer?.cancel();
    _sessionPruneTimer = null;
    _sessionStateTouchedAt.clear();
    _declineInProgress.clear();
    _recentDeclineBySession.clear();
    _sessionStateGenerations.clear();
    _handledNotificationIds.clear();
    _sessionCallKitIds.clear();
    _sessionPairAttemptIds.clear();
    _callKitEventDataById.clear();
    _pendingCallKitActions.clear();
    _pendingCallKitActionsDraining = false;
    _callActionHandlingReady = false;
    _lastAcceptedSessionId = null;
    _lastAcceptedIsTutor = false;
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
        _recentDeclineBySession.isEmpty &&
        !_acceptLifecycle.hasAnyState &&
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

    _pruneRecentDeclineState(now);

    for (final sessionId in List<String>.from(_sessionCallKitIds.keys)) {
      final touchedAt = _sessionStateTouchedAt[sessionId];
      if (touchedAt == null || now.difference(touchedAt) >= _sessionStateTtl) {
        staleSessionIds.add(sessionId);
      }
    }

    final retainedSessionIds = <String>{
      if (_lastAcceptedSessionId != null) _lastAcceptedSessionId!,
      if (_lastNavigatedSessionId != null) _lastNavigatedSessionId!,
      if (_pendingSessionId != null) _pendingSessionId!,
      if (_prefetchedSessionId != null) _prefetchedSessionId!,
    };
    staleSessionIds.addAll(
      _acceptLifecycle.prune(
        now: now,
        retainedSessionIds: retainedSessionIds,
      ),
    );
    staleSessionIds.removeAll(retainedSessionIds);

    if (staleSessionIds.isEmpty) return;

    for (final sessionId in staleSessionIds) {
      _clearSessionState(sessionId);
    }
    safeDebugLog(
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

    safeDebugLog('🔔 VoIPService: Deinitializing...');
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
    safeDebugLog('✅ VoIPService: Deinitialized');
  }

  Future<void> _invokeVoipTokenRegistration(
    Map<String, dynamic> payload,
  ) async {
    await _functions.httpsCallable('registerVoipToken').call(payload);
  }

  Future<void> _clearRegisteredVoipTokens() async {
    await _tokenRegistry.clearRegisteredTokens();
  }

  /// Сохранение FCM токена через серверный контракт.
  Future<void> _saveVoipToken(String token) async {
    try {
      await _tokenRegistry.saveFcmToken(token);
    } catch (e) {
      safeDebugLog('❌ VoIPService: Error saving token: $e');
    }
  }

  /// Пробуем синхронизировать PushKit токен (iOS)
  Future<void> _syncPushKitToken() async {
    if (kIsWeb) return;
    await _tokenRegistry.syncPushKitToken();
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
        safeDebugLog('ℹ️ VoIPService: Ignoring expired incoming call payload');
        return;
      }
      final payloadCallKitId = extraData == null
          ? null
          : _normalizeCallKitId(
              _voipStringFromPayload(extraData, 'callKitId'),
            );
      final callKitId = payloadCallKitId ??
          (sessionId.isNotEmpty
              ? (_sessionCallKitIds[sessionId] ??
                  _callKitIdForSession(sessionId))
              : const Uuid().v4());
      final pairAttemptId = extraData == null
          ? null
          : _voipStringFromPayload(extraData, 'pairAttemptId');
      if (extraData != null &&
          _voipUsesMatchProtocolV2(extraData) &&
          pairAttemptId != null &&
          await _wasCallKitEndedByServer(
            sessionId: sessionId,
            pairAttemptId: pairAttemptId,
            callKitId: callKitId,
          )) {
        safeDebugLog(
          'ℹ️ VoIPService: Ignoring incoming call already ended by server',
        );
        return;
      }
      if (extraData != null &&
          voipIncomingCallShouldUseInAppNavigation(
            extraData,
            lifecycleState: lifecycleState,
          )) {
        // Rollout fallback for a legacy peer. V2 never reaches this branch:
        // its foreground acceptance is owned by MatchCoordinator/Firestore.
        safeDebugLog('ℹ️ VoIPService: Legacy foreground call uses in-app flow');
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

      safeDebugLog('📞 VoIPService: Showing incoming call from $callerName');

      if (sessionId.isNotEmpty) {
        _sessionCallKitIds[sessionId] = callKitId;
        if (pairAttemptId != null) {
          _sessionPairAttemptIds[sessionId] = pairAttemptId;
        }
        _touchSessionState(sessionId);
        _lastCallKitId = callKitId;
      }
      if (extraData != null) {
        _matchCoordinator.noteIncomingCallKit(extraData);
      }
      final callKitParams = CallKitParams(
        id: callKitId,
        nameCaller: callerName,
        appName: 'Expatlio',
        avatar: callerPhoto,
        handle: callerId,
        type: 1,
        duration: voipIncomingCallDurationMilliseconds(extraData ?? const {}),
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
          textAccept: 'Accept',
          textDecline: 'Decline',
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

      _rememberCallKitEventData(callKitParams);
      await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
      safeDebugLog('✅ VoIPService: CallKit UI shown for session: $sessionId');
    } catch (e) {
      safeDebugLog('❌ VoIPService: Error showing incoming call: $e');
    }
  }

  /// Обработка событий CallKit/ConnectionService
  Future<void> _handleCallKitEvent(CallEvent? event) async {
    if (event == null) return;

    safeDebugLog('📞 VoIPService: CallKit Event: ${event.eventName}');

    try {
      if (event is CallEventActionDidUpdateDevicePushTokenVoip) {
        await _syncPushKitToken();
      } else if (event is CallEventActionCallAccept) {
        await _dispatchCallKitAction(
          type: VoipPendingCallKitActionType.accept,
          data: _callKitEventData(event.callKitParams),
        );
      } else if (event is CallEventActionCallDecline) {
        await _dispatchCallKitAction(
          type: VoipPendingCallKitActionType.decline,
          data: _callKitEventData(event.callKitParams),
        );
      } else if (event is CallEventActionCallEnded) {
        await _dispatchCallKitAction(
          type: VoipPendingCallKitActionType.ended,
          data: _callKitEventData(event.callKitParams),
        );
      } else if (event is CallEventActionCallTimeout) {
        final callKitId = _normalizeCallKitId(event.id);
        final data =
            callKitId == null ? null : _callKitEventDataById[callKitId];
        if (data == null) {
          // Version 3.1.3 exposes only the UUID for timeout events. Never
          // guess a session: server-side expiry remains the source of truth.
          safeDebugLog(
            'ℹ️ VoIPService: Timeout has no exact cached call identity',
          );
          return;
        }
        await _dispatchCallKitAction(
          type: VoipPendingCallKitActionType.timeout,
          data: data,
        );
      } else if (event is CallEventActionCallToggleAudioSession) {
        _handleAudioSessionToggle(<String, dynamic>{
          'isActivate': event.isActive,
        });
      } else if (event is CallEventActionCallIncoming) {
        final data = _callKitEventData(event.callKitParams);
        _matchCoordinator.noteIncomingCallKit(data);
        safeDebugLog('📞 VoIPService: Call incoming (display state)');
      } else if (event is CallEventActionCallStart) {
        _rememberCallKitEventData(event.callKitParams);
        safeDebugLog('📞 VoIPService: Call started');
      } else {
        safeDebugLog('⚠️ VoIPService: Unhandled event: ${event.eventName}');
      }
    } catch (e) {
      safeDebugLog('❌ VoIPService: Error handling CallKit event: $e');
    }
  }

  Map<String, dynamic> _callKitEventData(CallKitParams params) {
    final data = _voipMapFrom(params.toJson());
    _rememberCallKitEventData(params, data: data);
    return data;
  }

  void _rememberCallKitEventData(
    CallKitParams params, {
    Map<String, dynamic>? data,
  }) {
    final callKitId = _normalizeCallKitId(params.id);
    if (callKitId == null) return;
    _callKitEventDataById[callKitId] =
        data == null ? _voipMapFrom(params.toJson()) : _voipMapFrom(data);
  }

  Future<void> _dispatchCallKitAction({
    required VoipPendingCallKitActionType type,
    required Map<String, dynamic> data,
  }) async {
    if (_queueCallKitActionIfNotReady(type: type, data: data) ||
        _shouldDropCallKitActionForCurrentUser(type: type, data: data)) {
      return;
    }
    switch (type) {
      case VoipPendingCallKitActionType.accept:
        await _handleCallAccept(data);
        break;
      case VoipPendingCallKitActionType.decline:
        await _handleCallDecline(data);
        break;
      case VoipPendingCallKitActionType.ended:
        await _handleCallEnded(data);
        break;
      case VoipPendingCallKitActionType.timeout:
        await _handleCallTimeout(data);
        break;
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
    required VoipPendingCallKitActionType type,
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
      safeDebugLog(
          '⚠️ VoIPService: Dropping early CallKit action without sessionId');
      return true;
    }

    final callKitId = _normalizeCallKitId(
      _voipNonEmptyString(normalizedData['id']) ??
          _voipStringFromPayload(normalizedData, 'callKitId'),
    );
    _pendingCallKitActions.enqueue(
      VoipPendingCallKitAction(
        type: type,
        data: normalizedData,
        sessionId: sessionId,
        callKitId: callKitId,
        targetUserId: _voipStringFromPayload(normalizedData, 'recipientId'),
        queuedAt: DateTime.now(),
        queuedForUserId: _currentUserIdOrNull(),
      ),
    );
    safeDebugLog(
      '📞 VoIPService: Queued early CallKit ${type.name} for $sessionId',
    );
    return true;
  }

  String? _serverEndedCallKitIdentityKey({
    required String sessionId,
    required String? pairAttemptId,
    required String? callKitId,
  }) {
    final normalizedSessionId = _voipNonEmptyString(sessionId);
    final normalizedPairAttemptId = _voipNonEmptyString(pairAttemptId);
    final normalizedCallKitId = _normalizeCallKitId(callKitId);
    if (normalizedSessionId == null ||
        normalizedPairAttemptId == null ||
        normalizedCallKitId == null) {
      return null;
    }
    return '$normalizedSessionId:$normalizedPairAttemptId:$normalizedCallKitId';
  }

  void _pruneServerEndedCallKitTombstones(DateTime now) {
    _serverEndedCallKitTombstones.removeWhere(
      (_, endedAt) =>
          now.difference(endedAt) >= _serverEndedCallKitTombstoneTtl,
    );
  }

  Future<void> _persistServerEndedCallKitId(
    String callKitId,
    DateTime endedAt,
  ) async {
    if (kIsWeb) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final stored = preferences.getString(
        _serverEndedCallKitTombstonesPreferenceKey,
      );
      final decoded = stored == null
          ? <String, dynamic>{}
          : _voipMapFrom(jsonDecode(stored));
      final nowSeconds = endedAt.millisecondsSinceEpoch / 1000;
      decoded.removeWhere((_, value) {
        final seconds = value is num
            ? value.toDouble()
            : double.tryParse(value?.toString() ?? '');
        return seconds == null ||
            nowSeconds - seconds >= _serverEndedCallKitTombstoneTtl.inSeconds;
      });
      decoded[callKitId] = nowSeconds;
      await preferences.setString(
        _serverEndedCallKitTombstonesPreferenceKey,
        jsonEncode(decoded),
      );
    } catch (error) {
      safeDebugLog(
        '⚠️ VoIPService: Failed to persist server-ended CallKit tombstone: '
        '$error',
      );
    }
  }

  Future<void> _rememberServerEndedCallKit({
    required String sessionId,
    required String pairAttemptId,
    required String callKitId,
  }) async {
    final identityKey = _serverEndedCallKitIdentityKey(
      sessionId: sessionId,
      pairAttemptId: pairAttemptId,
      callKitId: callKitId,
    );
    if (identityKey == null) return;
    final now = DateTime.now();
    _pruneServerEndedCallKitTombstones(now);
    _serverEndedCallKitTombstones[identityKey] = now;
    await _persistServerEndedCallKitId(callKitId, now);
  }

  Future<bool> _wasCallKitEndedByServer({
    required String sessionId,
    required String? pairAttemptId,
    required String? callKitId,
  }) async {
    final identityKey = _serverEndedCallKitIdentityKey(
      sessionId: sessionId,
      pairAttemptId: pairAttemptId,
      callKitId: callKitId,
    );
    if (identityKey == null) return false;
    final now = DateTime.now();
    _pruneServerEndedCallKitTombstones(now);
    if (_serverEndedCallKitTombstones.containsKey(identityKey)) return true;
    if (kIsWeb) return false;

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final stored = preferences.getString(
        _serverEndedCallKitTombstonesPreferenceKey,
      );
      if (stored == null) return false;
      final decoded = _voipMapFrom(jsonDecode(stored));
      final value = decoded[_normalizeCallKitId(callKitId)];
      final seconds = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      if (seconds == null) return false;
      final endedAt = DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
      );
      if (now.difference(endedAt) >= _serverEndedCallKitTombstoneTtl) {
        return false;
      }
      _serverEndedCallKitTombstones[identityKey] = endedAt;
      return true;
    } catch (error) {
      safeDebugLog(
        '⚠️ VoIPService: Failed to read server-ended CallKit tombstone: '
        '$error',
      );
      return false;
    }
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
    required VoipPendingCallKitActionType type,
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
    safeDebugLog(
      '⚠️ VoIPService: Dropping CallKit ${type.name} for another user: $sessionId',
    );
    return true;
  }

  bool _stopAcceptForLifecycleDecision({
    required String sessionId,
    required String effectiveCallKitId,
    required VoipAcceptDecision decision,
  }) {
    switch (decision) {
      case VoipAcceptDecision.proceed:
      case VoipAcceptDecision.started:
        return false;
      case VoipAcceptDecision.duplicateTimeWindow:
        safeDebugLog('⚠️ VoIPService: Duplicate accept event (time window)');
        break;
      case VoipAcceptDecision.duplicateCallKitId:
        safeDebugLog(
            '⚠️ VoIPService: Duplicate accept event (callKitId): $effectiveCallKitId');
        break;
      case VoipAcceptDecision.alreadyAccepted:
        safeDebugLog('⚠️ VoIPService: Call already accepted: $sessionId');
        break;
      case VoipAcceptDecision.acceptInProgress:
        safeDebugLog(
            '⚠️ VoIPService: Accept already in progress for $sessionId');
        break;
      case VoipAcceptDecision.duplicateProcessClaim:
        safeDebugLog('⚠️ VoIPService: Duplicate accept event (process gate)');
        break;
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
      safeDebugLog('❌ VoIPService: No sessionId in accept event');
      return;
    }
    if (!_adoptExactV2CallKitIdentity(sessionId, data, callKitId)) {
      safeDebugLog(
        'ℹ️ VoIPService: Ignoring v2 accept without exact CallKit identity',
      );
      return;
    }
    if (_hasMismatchedTrackedPairAttempt(sessionId, data)) {
      safeDebugLog('ℹ️ VoIPService: Ignoring accept for stale pair attempt');
      return;
    }

    final trackedCallKitId = _sessionCallKitIds[sessionId];
    final effectiveCallKitId =
        trackedCallKitId ?? _callKitIdForSession(sessionId);
    if (callKitId != null && callKitId != effectiveCallKitId) {
      safeDebugLog(
          'ℹ️ VoIPService: Ignoring accept for stale callKitId: $callKitId');
      return;
    }
    final acceptTime = now ?? DateTime.now();
    final acceptIdentity = VoipAcceptIdentity(
      sessionId: sessionId,
      callKitId: effectiveCallKitId,
    );
    final duplicateDecision = _acceptLifecycle.evaluate(
      acceptIdentity,
      now: acceptTime,
    );
    if (_stopAcceptForLifecycleDecision(
      sessionId: sessionId,
      effectiveCallKitId: effectiveCallKitId,
      decision: duplicateDecision,
    )) {
      return;
    }
    if (_hasProtectedLiveSessionState(sessionId)) {
      safeDebugLog(
          'ℹ️ VoIPService: Ignoring accept for protected session state: $sessionId');
      return;
    }
    if (voipIncomingCallPayloadHasExpired(data, now: acceptTime)) {
      safeDebugLog('ℹ️ VoIPService: Ignoring expired accept payload');
      if (callKitId == null) {
        safeDebugLog(
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
    final startResult = _acceptLifecycle.begin(
      acceptIdentity,
      now: acceptTime,
    );
    if (_stopAcceptForLifecycleDecision(
      sessionId: sessionId,
      effectiveCallKitId: effectiveCallKitId,
      decision: startResult.decision,
    )) {
      return;
    }
    final acceptAttempt = startResult.token!;
    _touchSessionState(sessionId);

    _lastCallKitId = effectiveCallKitId;
    _sessionCallKitIds[sessionId] = effectiveCallKitId;
    final pairAttemptId = _voipStringFromPayload(data, 'pairAttemptId');
    if (pairAttemptId != null) {
      _sessionPairAttemptIds[sessionId] = pairAttemptId;
    }

    var finishAcceptAttempt = true;
    try {
      final hasPermissions = await _ensureAcceptMediaPermissions();
      if (!_acceptLifecycle.isCurrent(acceptAttempt)) return;
      if (!hasPermissions) {
        safeDebugLog(
          '⚠️ VoIPService: camera or microphone permission denied before accepting $sessionId',
        );
        final permissionDeniedGeneration = _sessionStateGenerations[sessionId];
        _acceptLifecycle.releaseForRetry(acceptAttempt);
        if (_voipUsesMatchProtocolV2(data)) {
          try {
            await _matchCoordinator.handleCallKitDecline(data);
          } catch (error) {
            safeDebugLog('⚠️ VoIPService: permission decline failed: $error');
          }
          await _endExpiredAcceptSystemCall(
            sessionId: sessionId,
            callKitId: effectiveCallKitId,
            expectedSessionGeneration: permissionDeniedGeneration,
          );
        } else {
          await _endCurrentCall(
            sessionId: sessionId,
            expectedSessionGeneration: permissionDeniedGeneration,
          );
        }
        return;
      }

      if (_voipUsesMatchProtocolV2(data)) {
        try {
          final handled = await _matchCoordinator.handleCallKitAccept(data);
          if (!_acceptLifecycle.isCurrent(acceptAttempt)) return;
          if (!handled) {
            await _endExpiredAcceptSystemCall(
              sessionId: sessionId,
              callKitId: effectiveCallKitId,
            );
            return;
          }
          if (!_acceptLifecycle.markAccepted(acceptAttempt)) return;
          _lastAcceptedSessionId = sessionId;
          _lastAcceptedIsTutor = false;
          safeDebugLog('✅ VoIPService: v2 CallKit accept submitted');
        } catch (error) {
          if (!_acceptLifecycle.isCurrent(acceptAttempt)) return;
          safeDebugLog('❌ VoIPService: v2 accept failed: $error');
          if (voipIsDefinitiveV2AcceptFailure(error)) {
            await _endExpiredAcceptSystemCall(
              sessionId: sessionId,
              callKitId: effectiveCallKitId,
            );
          } else {
            safeDebugLog(
              'ℹ️ VoIPService: v2 accept outcome is unknown; '
              'keeping CallKit bound to server reconciliation',
            );
          }
        }
        return;
      }

      final isSameSession = _lastAcceptedSessionId == sessionId;
      _lastAcceptedSessionId = sessionId;
      _lastAcceptedIsTutor = false;
      _lastRoomUrl = null;
      _lastMeetingToken = null;
      _lastRoomName = null;
      if (!isSameSession) {
        _navigationCoordinator.clearLastNavigation();
      }

      safeDebugLog('✅ VoIPService: Call accepted: $sessionId');

      final payloadCredentials = voipRoomCredentialsFromAcceptedPayload(data);
      final acceptAction = voipAcceptActionFromPayload(data);
      _lastAcceptedIsTutor = payloadCredentials == null;
      final acceptedUserId = _currentUserIdOrNull()?.trim();
      if (acceptedUserId == null || acceptedUserId.isEmpty) {
        _clearSessionState(sessionId);
        return;
      }
      final resolutionAttempt = _acceptedSessionResolver.begin(
        sessionId: sessionId,
        userId: acceptedUserId,
      );

      // open_session means backend already accepted the pair. Do not call
      // acceptCall again; VideoCallPage/getSessionTokens can resolve credentials.
      if (payloadCredentials != null ||
          acceptAction == VoipAcceptPayloadAction.openSession) {
        final resolution = await _acceptedSessionResolver.resolve(
          attempt: resolutionAttempt,
          alreadyAccepted: VoipAcceptedSession(
            isTutor: false,
            roomUrl: payloadCredentials?.roomUrl,
            roomName: payloadCredentials?.roomName ??
                voipRoomNameFromAcceptPayload(data),
          ),
          accept: () async => null,
          recover: () async => null,
        );
        _applyAcceptedSessionResolution(
          attempt: resolutionAttempt,
          acceptAttempt: acceptAttempt,
          resolution: resolution,
        );
        return;
      }

      // Do not navigate before acceptCall completes. CallKit/FCM can deliver
      // duplicate accept events; navigating early creates multiple Daily clients
      // before the backend lock can collapse them.
      _lastAcceptedIsTutor = true;
      if (!_acceptLifecycle.markAccepted(acceptAttempt)) return;

      // Call acceptCall in the background — creates the Daily room and writes
      // dailyRoomUrl to the session document. VideoCallPage's StreamBuilder
      // reacts to this update and fetches a meeting token automatically.
      finishAcceptAttempt = false;
      unawaited(_resolveAcceptedSession(
        resolutionAttempt,
        acceptAttempt,
      ));
    } catch (e) {
      if (!_acceptLifecycle.isCurrent(acceptAttempt)) return;
      safeDebugLog('❌ VoIPService: Error in call accept flow: $e');
      _clearSessionState(sessionId);
    } finally {
      if (finishAcceptAttempt) {
        _acceptLifecycle.finish(acceptAttempt);
      }
    }
  }

  Future<void> _resolveAcceptedSession(
    VoipAcceptedSessionAttempt attempt,
    VoipAcceptAttemptToken acceptAttempt,
  ) async {
    try {
      final resolution = await _acceptedSessionResolver.resolve(
        attempt: attempt,
        accept: () async {
          final response = await _callAcceptCallFunction(attempt.sessionId);
          final credentials =
              voipRoomCredentialsFromAcceptCallResponse(response);
          if (credentials == null) return null;
          return VoipAcceptedSession(
            isTutor: true,
            roomUrl: credentials.roomUrl,
            meetingToken: credentials.meetingToken,
            roomName: credentials.roomName,
          );
        },
        recover: () => _recoverActiveSession(attempt.sessionId),
      );
      _applyAcceptedSessionResolution(
        attempt: attempt,
        acceptAttempt: acceptAttempt,
        resolution: resolution,
      );
    } finally {
      _acceptLifecycle.finish(acceptAttempt);
    }
  }

  void _applyAcceptedSessionResolution({
    required VoipAcceptedSessionAttempt attempt,
    required VoipAcceptAttemptToken acceptAttempt,
    required VoipAcceptedSessionResolution resolution,
  }) {
    if (!_acceptedSessionResolver.isCurrent(attempt) ||
        !_acceptLifecycle.isCurrent(acceptAttempt)) {
      return;
    }
    final accepted = resolution.session;
    if (resolution.state != VoipAcceptedSessionResolutionState.resolved ||
        accepted == null) {
      if (resolution.state == VoipAcceptedSessionResolutionState.unresolved) {
        _clearSessionState(attempt.sessionId);
      }
      return;
    }

    _lastAcceptedSessionId = attempt.sessionId;
    _lastAcceptedIsTutor = accepted.isTutor;
    _lastRoomUrl = accepted.roomUrl;
    _lastMeetingToken = accepted.meetingToken;
    _lastRoomName = accepted.roomName;
    if (!_acceptLifecycle.markAccepted(acceptAttempt)) return;
    _navigateToVideoCallForAccept(
      sessionId: attempt.sessionId,
      isTutor: accepted.isTutor,
      roomUrl: accepted.roomUrl,
      meetingToken: accepted.meetingToken,
      roomName: accepted.roomName,
    );
    unawaited(_prefetchSessionTokensForAccept(attempt.sessionId));
    unawaited(_markNavigationTriggeredForAccept(
      sessionId: attempt.sessionId,
      isTutor: accepted.isTutor,
    ).catchError((_) {}));
  }

  Future<VoipAcceptedSession?> _recoverActiveSession(String sessionId) async {
    try {
      final override = debugRecoverActiveSessionOverride;
      if (override != null) {
        if (!(await override(sessionId))) return null;
        return VoipAcceptedSession(
          isTutor: true,
          roomUrl: _lastRoomUrl,
          roomName: _lastRoomName,
        );
      }
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;
      final sessionDoc =
          await _firestore.collection('videoSessions').doc(sessionId).get();
      if (!sessionDoc.exists) return null;
      final data = sessionDoc.data();
      if (data == null) return null;
      final status = data['status'] as String?;
      final tutorId = data['tutorId'] as String?;
      final roomUrl = data['dailyRoomUrl'] as String?;
      if (roomUrl == null || roomUrl.isEmpty) return null;
      if (tutorId != userId) return null;
      if (status != 'active' && status != 'connecting') return null;
      return VoipAcceptedSession(
        isTutor: true,
        roomUrl: roomUrl,
        roomName: data['dailyRoomName'] as String?,
      );
    } catch (e) {
      safeDebugLog('⚠️ VoIPService: Recovery check failed: $e');
      return null;
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
    if (appNavigatorKey.currentContext == null) {
      safeDebugLog('⚠️ VoIPService: Navigation context not ready');
      _touchSessionState(sessionId);
    }

    unawaited(
      _navigationCoordinator.requestNavigation(
        VoipNavigationRequest(
          sessionId: sessionId,
          isTutor: isTutor,
          roomUrl: roomUrl,
          meetingToken: meetingToken,
          roomName: roomName,
        ),
      ),
    );
  }

  bool _attemptVideoCallNavigation(VoipNavigationTarget queuedTarget) {
    final navContext = appNavigatorKey.currentContext;
    if (navContext == null) return false;

    final request = queuedTarget.request;
    final target = _effectiveVideoCallTarget(request);
    final router = GoRouter.of(navContext);
    final currentLocation = router.getCurrentLocation();
    if (_isVideoCallLocationForSession(currentLocation, request.sessionId)) {
      safeDebugLog(
        'ℹ️ VoIPService: Already on $_videoCallRoutePath for '
        '${request.sessionId}, skip navigation',
      );
      return true;
    }

    router.go(target.location);
    safeDebugLog('🎬 VoIPService: Navigated to VideoCallPage');
    return true;
  }

  void _logNavigationRetryExhausted() {
    safeDebugLog(
      '⚠️ VoIPService: Navigation context not ready after extended retries',
    );
  }

  VoipNavigationTarget _effectiveVideoCallTarget(
    VoipNavigationRequest request,
  ) {
    final prefetchedToken = _getFreshPrefetchedToken(request.sessionId);
    final prefetchedRoomUrl = _getPrefetchedRoomUrl(request.sessionId);
    final prefetchedRoomName = _getPrefetchedRoomName(request.sessionId);
    final usePrefetch = prefetchedToken != null && prefetchedRoomUrl != null;
    final effectiveMeetingToken =
        usePrefetch ? prefetchedToken : request.meetingToken;
    final effectiveRoomUrl = usePrefetch
        ? prefetchedRoomUrl
        : (request.roomUrl ?? prefetchedRoomUrl);
    final effectiveRoomName = usePrefetch
        ? prefetchedRoomName
        : (request.roomName ?? prefetchedRoomName);
    return VoipNavigationTarget.fromRequest(
      request,
      path: _videoCallRoutePath,
      effectiveRoomUrl: effectiveRoomUrl,
      effectiveMeetingToken: effectiveMeetingToken,
      effectiveRoomName: effectiveRoomName,
    );
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

  void _handleAudioSessionToggle(dynamic body) {
    final isActive = body is Map && body['isActivate'] == true;
    safeDebugLog(
      '🔈 VoIPService: Audio session ${isActive ? 'activated' : 'deactivated'}',
    );
    // Only care about activation, and only if we haven't already navigated
    if (!isActive) return;
    if (_lastNavigatedSessionId != null) {
      safeDebugLog(
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
      safeDebugLog('❌ VoIPService: No sessionId in decline event');
      return;
    }
    final callKitId = _normalizeCallKitId(
      _voipNonEmptyString(data['id']) ??
          _voipStringFromPayload(data, 'callKitId'),
    );
    if (!_adoptExactV2CallKitIdentity(sessionId, data, callKitId)) {
      safeDebugLog(
        'ℹ️ VoIPService: Ignoring v2 decline without exact CallKit identity',
      );
      return;
    }
    if (_hasMismatchedTrackedPairAttempt(sessionId, data)) {
      safeDebugLog('ℹ️ VoIPService: Ignoring decline for stale pair attempt');
      return;
    }
    if (_hasMismatchedTrackedCallKitId(sessionId, callKitId)) {
      safeDebugLog(
          'ℹ️ VoIPService: Ignoring decline for stale callKitId: $callKitId');
      return;
    }
    if (_voipUsesMatchProtocolV2(data)) {
      if (await _wasCallKitEndedByServer(
        sessionId: sessionId,
        pairAttemptId: _voipStringFromPayload(data, 'pairAttemptId'),
        callKitId: callKitId,
      )) {
        _clearSessionState(sessionId);
        safeDebugLog(
          'ℹ️ VoIPService: Ignoring server-driven CallKit decline',
        );
        return;
      }
      try {
        await _matchCoordinator.handleCallKitDecline(data);
      } catch (error) {
        safeDebugLog('❌ VoIPService: v2 decline failed: $error');
      } finally {
        _clearSessionState(sessionId);
      }
      return;
    }
    if (_hasProtectedLiveSessionState(sessionId)) {
      safeDebugLog(
          'ℹ️ VoIPService: Ignoring decline for active session: $sessionId');
      return;
    }
    final declineTime = DateTime.now();
    _pruneRecentDeclineState(declineTime);
    if (_declineInProgress.contains(sessionId)) {
      safeDebugLog(
          '⚠️ VoIPService: Decline already in progress for $sessionId');
      return;
    }
    final recentDeclineAt = _recentDeclineBySession[sessionId];
    if (recentDeclineAt != null &&
        declineTime.difference(recentDeclineAt) < _declineDedupeWindow) {
      safeDebugLog('⚠️ VoIPService: Duplicate decline event for $sessionId');
      return;
    }

    _declineInProgress.add(sessionId);
    _touchSessionState(sessionId);
    safeDebugLog('❌ VoIPService: Call declined: $sessionId');

    try {
      await _callDeclineCallFunction(sessionId);
      _recentDeclineBySession[sessionId] = DateTime.now();
      _clearSessionState(sessionId);

      safeDebugLog('✅ VoIPService: declineCall completed');
    } catch (e) {
      safeDebugLog('❌ VoIPService: Error declining call: $e');
    } finally {
      _declineInProgress.remove(sessionId);
    }
  }

  /// Звонок завершен
  Future<void> _handleCallEnded(Map<String, dynamic>? data) async {
    if (data == null) return;

    final sessionId = _voipStringFromPayload(data, 'sessionId');
    if (sessionId == null) {
      safeDebugLog('❌ VoIPService: No sessionId in ended event');
      return;
    }
    final callKitId = _normalizeCallKitId(
      _voipNonEmptyString(data['id']) ??
          _voipStringFromPayload(data, 'callKitId'),
    );
    if (!_adoptExactV2CallKitIdentity(sessionId, data, callKitId)) {
      safeDebugLog(
        'ℹ️ VoIPService: Ignoring v2 end without exact CallKit identity',
      );
      return;
    }
    if (_hasMismatchedTrackedCallKitId(sessionId, callKitId)) {
      safeDebugLog(
          'ℹ️ VoIPService: Ignoring endSession for stale callKitId: $callKitId');
      return;
    }

    var v2ConnectedSession = false;
    if (_voipUsesMatchProtocolV2(data)) {
      if (!_v2EndedCallMatchesTrackedIdentity(sessionId, data, callKitId)) {
        safeDebugLog(
          'ℹ️ VoIPService: Ignoring v2 end without exact pair/callKit identity',
        );
        return;
      }
      if (await _wasCallKitEndedByServer(
        sessionId: sessionId,
        pairAttemptId: _voipStringFromPayload(data, 'pairAttemptId'),
        callKitId: callKitId,
      )) {
        _clearSessionState(sessionId);
        safeDebugLog(
          'ℹ️ VoIPService: Ignoring server-driven CallKit end',
        );
        return;
      }
      try {
        final disposition = await _matchCoordinator.handleCallKitEnd(data);
        if (disposition == MatchCallKitEndDisposition.ignored) return;
        v2ConnectedSession =
            disposition == MatchCallKitEndDisposition.endConnectedSession;
      } catch (error) {
        safeDebugLog('⚠️ VoIPService: v2 CallKit end response failed: $error');
        return;
      } finally {
        _clearSessionState(sessionId);
      }
      if (!v2ConnectedSession) {
        safeDebugLog('✅ VoIPService: pending v2 match cancelled on hang-up');
        return;
      }
    }

    final canEndSessionFromMemory =
        v2ConnectedSession || _canEndSessionFromInMemoryState(sessionId);
    final fallbackStartGeneration = _sessionStateGenerations[sessionId];
    final shouldEndViaFallback = !canEndSessionFromMemory
        ? await _shouldEndSessionViaFallbackLookup(sessionId)
        : false;
    if (!canEndSessionFromMemory &&
        shouldEndViaFallback &&
        fallbackStartGeneration != _sessionStateGenerations[sessionId]) {
      safeDebugLog(
          'ℹ️ VoIPService: Ignoring endSession because session state changed during fallback: $sessionId');
      return;
    }

    if (!canEndSessionFromMemory && !shouldEndViaFallback) {
      safeDebugLog(
          'ℹ️ VoIPService: Ignoring endSession for unknown session: $sessionId');
      return;
    }

    _clearSessionState(sessionId);
    safeDebugLog('🔚 VoIPService: Call ended: $sessionId');

    try {
      final override = debugEndSessionOverride;
      if (override != null) {
        await override(sessionId);
      } else {
        await _functions.httpsCallable('endSession').call({
          'sessionId': sessionId,
          'endReason': 'user_ended',
        });
      }

      safeDebugLog('✅ VoIPService: endSession completed');
    } catch (e) {
      safeDebugLog('❌ VoIPService: Error ending session: $e');
    }
  }

  /// Таймаут звонка (45 секунд без ответа)
  Future<void> _handleCallTimeout(Map<String, dynamic>? data) async {
    if (data == null) return;

    final sessionId = _voipStringFromPayload(data, 'sessionId');
    if (sessionId == null || sessionId.isEmpty) {
      safeDebugLog('❌ VoIPService: No sessionId in timeout event');
      return;
    }
    final callKitId = _normalizeCallKitId(
      _voipNonEmptyString(data['id']) ??
          _voipStringFromPayload(data, 'callKitId'),
    );
    if (!_adoptExactV2CallKitIdentity(sessionId, data, callKitId)) {
      safeDebugLog(
        'ℹ️ VoIPService: Ignoring v2 timeout without exact CallKit identity',
      );
      return;
    }
    if (_hasMismatchedTrackedPairAttempt(sessionId, data)) {
      safeDebugLog('ℹ️ VoIPService: Ignoring timeout for stale pair attempt');
      return;
    }
    if (_hasMismatchedTrackedCallKitId(sessionId, callKitId)) {
      safeDebugLog(
          'ℹ️ VoIPService: Ignoring timeout for stale callKitId: $callKitId');
      return;
    }
    if (_voipUsesMatchProtocolV2(data)) {
      if (await _wasCallKitEndedByServer(
        sessionId: sessionId,
        pairAttemptId: _voipStringFromPayload(data, 'pairAttemptId'),
        callKitId: callKitId,
      )) {
        _clearSessionState(sessionId);
        safeDebugLog(
          'ℹ️ VoIPService: Ignoring server-driven CallKit timeout',
        );
        return;
      }
      try {
        await _matchCoordinator.handleCallKitTimeout(data);
      } catch (error) {
        safeDebugLog('⚠️ VoIPService: v2 timeout response failed: $error');
      }
      _clearSessionState(sessionId);
      return;
    }
    if (_hasProtectedLiveSessionState(sessionId)) {
      safeDebugLog(
          'ℹ️ VoIPService: Ignoring timeout for active session: $sessionId');
      return;
    }
    if (!_hasTrackedSessionState(sessionId) &&
        !_hasTrustedCallKitIdentity(sessionId, callKitId)) {
      safeDebugLog(
          'ℹ️ VoIPService: Ignoring timeout for unknown session: $sessionId');
      return;
    }

    _clearSessionState(sessionId);
    safeDebugLog('⏰ VoIPService: Call timeout: $sessionId');

    // Ничего не делаем - Cloud Function processExpiredNotifications обработает
  }

  void _clearSessionState(String sessionId) {
    _acceptLifecycle.invalidate(sessionId);
    _debugAcceptAttempts.remove(sessionId);
    _acceptedSessionResolver.invalidateSession(sessionId);
    _sessionStateTouchedAt.remove(sessionId);
    _sessionStateGenerations.remove(sessionId);
    _declineInProgress.remove(sessionId);
    final callKitIdForSession = _sessionCallKitIds[sessionId];
    if (callKitIdForSession != null) {
      _callKitEventDataById.remove(callKitIdForSession);
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
      _navigationCoordinator.clearLastNavigation();
    }
    _navigationCoordinator.clearPending(sessionId: sessionId);
    if (_prefetchedSessionId == sessionId) {
      _prefetchedSessionId = null;
      _clearPrefetchedSessionCredentials();
      _prefetchInProgress = false;
    }
    _sessionCallKitIds.remove(sessionId);
    _sessionPairAttemptIds.remove(sessionId);
  }

  Future<void> _endExpiredAcceptSystemCall({
    required String sessionId,
    required String callKitId,
    int? expectedSessionGeneration,
  }) async {
    try {
      final override = debugEndCallKitCallOverride;
      if (override != null) {
        await override(sessionId: sessionId, callKitId: callKitId);
      } else {
        await FlutterCallkitIncoming.endCall(callKitId);
      }
      if (expectedSessionGeneration != null &&
          _sessionStateGenerations[sessionId] != expectedSessionGeneration) {
        return;
      }
      _clearSessionState(sessionId);
      safeDebugLog('✅ VoIPService: Expired accept system call cleared');
    } catch (e) {
      safeDebugLog('❌ VoIPService: Error ending expired accept call: $e');
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
      safeDebugLog('⚠️ VoIPService: Prefetch token failed: $e');
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
      safeDebugLog('❌ VoIPService: Error marking call connected: $e');
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
  Future<void> cancelIncomingCall({
    required String sessionId,
    String? callKitId,
    String? pairAttemptId,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return;
    }
    final normalizedPairAttemptId = _voipNonEmptyString(pairAttemptId);
    final trackedPairAttemptId = _sessionPairAttemptIds[normalizedSessionId];
    if (normalizedPairAttemptId != null &&
        trackedPairAttemptId != null &&
        normalizedPairAttemptId != trackedPairAttemptId) {
      safeDebugLog('ℹ️ VoIPService: Ignoring stale attempt cancellation');
      return;
    }
    final explicitCallKitId = _normalizeCallKitId(callKitId);
    final trackedCallKitId = _sessionCallKitIds[normalizedSessionId];
    if (explicitCallKitId != null &&
        trackedCallKitId != null &&
        explicitCallKitId != trackedCallKitId) {
      safeDebugLog('ℹ️ VoIPService: Ignoring stale CallKit cancellation');
      return;
    }
    if (normalizedPairAttemptId != null && explicitCallKitId == null) {
      safeDebugLog('ℹ️ VoIPService: V2 cancellation has no exact callKitId');
      return;
    }
    final effectiveCallKitId = explicitCallKitId ??
        trackedCallKitId ??
        _callKitIdForSession(normalizedSessionId);
    try {
      if (normalizedPairAttemptId != null && explicitCallKitId != null) {
        await _rememberServerEndedCallKit(
          sessionId: normalizedSessionId,
          pairAttemptId: normalizedPairAttemptId,
          callKitId: explicitCallKitId,
        );
      }
      final override = debugEndCallKitCallOverride;
      if (override != null) {
        await override(
          sessionId: normalizedSessionId,
          callKitId: effectiveCallKitId,
        );
      } else {
        await FlutterCallkitIncoming.endCall(effectiveCallKitId);
      }
      _clearSessionState(normalizedSessionId);
      safeDebugLog('✅ VoIPService: Incoming system call cleared');
    } catch (e) {
      safeDebugLog('❌ VoIPService: Error clearing incoming call: $e');
    }
  }

  /// Завершить текущий активный звонок (программно)
  Future<void> endCurrentCall({String? sessionId}) {
    return _endCurrentCall(sessionId: sessionId);
  }

  Future<void> _endCurrentCall({
    String? sessionId,
    int? expectedSessionGeneration,
  }) async {
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
        if (expectedSessionGeneration != null &&
            _sessionStateGenerations[sessionId] != expectedSessionGeneration) {
          return;
        }
        _clearSessionState(sessionId);
        if (callKitId != null && _lastCallKitId == callKitId) {
          _lastCallKitId = null;
        }
      } else {
        _sessionCallKitIds.clear();
        _sessionPairAttemptIds.clear();
        _acceptLifecycle.clearHandledCallKitIds();
        _lastCallKitId = null;
      }

      safeDebugLog('✅ VoIPService: System call UI cleared');
    } catch (e) {
      safeDebugLog('❌ VoIPService: Error ending calls: $e');
    }
  }

  /// Проверить, есть ли активные звонки
  Future<bool> hasActiveCalls() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      return _hasActiveCallEntries(calls);
    } catch (e) {
      safeDebugLog('❌ VoIPService: Error checking active calls: $e');
      return false;
    }
  }
}
