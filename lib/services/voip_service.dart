import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

// Импорт для навигации и backend
import '/backend/backend.dart';
import '/flutter_flow/nav/nav.dart';

/// VoIP сервис для обработки входящих звонков
/// Использует CallKit (iOS) и ConnectionService (Android)
class VoIPService {
  static final VoIPService _instance = VoIPService._internal();
  factory VoIPService() => _instance;
  VoIPService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  bool _initialized = false;
  bool _initializing = false;
  StreamSubscription<CallEvent?>? _callKitSubscription;
  final Set<String> _acceptInProgress = {};
  final Set<String> _acceptedSessions = {};
  final Set<String> _handledCallKitAcceptIds = {};
  final Map<String, DateTime> _recentAcceptBySession = {};
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
  final Map<String, String> _sessionCallKitIds = {};
  String? _lastCallKitId;

  // Для навигации нужен context - сохраним глобальный navigatorKey
  //static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Инициализация VoIP сервиса
  /// Вызывается один раз при запуске приложения
  Future<void> initialize() async {
    if (_initialized || _initializing) {
      debugPrint('🔔 VoIPService: Initialize skipped (already running)');
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

      debugPrint('🔔 VoIPService: Permission status: ${settings.authorizationStatus}');

      // 2. Получаем FCM токен
      String? fcmToken = await _fcm.getToken();
      if (fcmToken != null) {
        debugPrint('🔔 VoIPService: Got FCM token: ${fcmToken.substring(0, 20)}...');
        await _saveVoipToken(fcmToken);
      } else {
        debugPrint('⚠️ VoIPService: Failed to get FCM token');
      }

      // 3. Слушаем обновления токена
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('🔔 VoIPService: Token refreshed');
        _saveVoipToken(newToken);
      });

      // 3.1. Обработка входящих уведомлений в фореграунде
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        if (message.data['type'] != 'incoming_call') return;
        if (kIsWeb) return;

        debugPrint('📞 VoIPService: Foreground incoming call received');
        try {
          await showIncomingCall(
            sessionId: message.data['sessionId'] ?? '',
            callerName: message.data['callerName'] ?? 'Unknown Caller',
            callerId: message.data['callerId'] ?? '',
            callerPhoto: message.data['callerPhoto'],
            extraData: {
              'roomUrl': message.data['roomUrl'],
              'meetingToken': message.data['meetingToken'],
              'roomName': message.data['roomName'],
            },
          );
        } catch (e) {
          debugPrint('❌ VoIPService: Failed to show CallKit in foreground: $e');
        }
      });

      // 4. Слушаем события CallKit/ConnectionService
      _callKitSubscription ??=
          FlutterCallkitIncoming.onEvent.listen(_handleCallKitEvent);

      // 5. Пытаемся получить PushKit токен (iOS) если доступен
      await _syncPushKitToken();

      _initialized = true;
      debugPrint('✅ VoIPService: Initialized successfully');
    } catch (e) {
      debugPrint('❌ VoIPService: Initialization error: $e');
    } finally {
      _initializing = false;
    }
  }

  /// Сохранение FCM токена в Firestore
  Future<void> _saveVoipToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ VoIPService: No authenticated user, skipping token save');
        return;
      }

      await _firestore.collection('users').doc(user.uid).update({
        'voipToken': token,
        'voipTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ VoIPService: Token saved for user ${user.uid}');
    } catch (e) {
      debugPrint('❌ VoIPService: Error saving token: $e');
    }
  }

  /// Сохранение PushKit токена в Firestore (iOS)
  Future<void> _savePushKitToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ VoIPService: No authenticated user, skipping PushKit token save');
        return;
      }

      await _firestore.collection('users').doc(user.uid).update({
        'voipPushToken': token,
        'voipPushTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

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
  }) async {
    try {
      debugPrint('📞 VoIPService: Showing incoming call from $callerName');

      final callKitId = const Uuid().v4();
      if (sessionId.isNotEmpty) {
        _sessionCallKitIds[sessionId] = callKitId;
        _lastCallKitId = callKitId;
      }
      final callKitParams = CallKitParams(
        id: callKitId,
        nameCaller: callerName,
        appName: 'Small Talk',
        avatar: callerPhoto,
        handle: callerId,
        type: 1,
        textAccept: 'Accept',
        textDecline: 'Decline',
        duration: 45000,
        extra: <String, dynamic>{
          'sessionId': sessionId,
          'callKitId': callKitId,
          'callerId': callerId,
          ...?extraData,
        },
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
          await _handleCallAccept(event.body);
          break;
        case Event.actionCallDecline:
          await _handleCallDecline(event.body);
          break;
        case Event.actionCallEnded:
          await _handleCallEnded(event.body);
          break;
        case Event.actionCallTimeout:
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

  /// Пользователь принял звонок
  /// Пользователь принял звонок
  Future<void> _handleCallAccept(Map<String, dynamic>? data) async {
  if (data == null) return;

  final extra = data['extra'] is Map
      ? Map<String, dynamic>.from(data['extra'] as Map)
      : <String, dynamic>{};
  final rawSessionId =
      extra['sessionId'] as String? ?? data['sessionId'] as String?;
  final sessionId = rawSessionId?.trim();
  final callKitId =
      data['id'] as String? ?? extra['callKitId'] as String?;
  if (callKitId != null) {
    _lastCallKitId = callKitId;
  }
  if (sessionId != null && callKitId != null) {
    _sessionCallKitIds[sessionId] = callKitId;
  }
  if (sessionId == null || sessionId.isEmpty) {
    debugPrint('❌ VoIPService: No sessionId in accept event');
    return;
  }

  if (callKitId != null && _handledCallKitAcceptIds.contains(callKitId)) {
    debugPrint('⚠️ VoIPService: Duplicate accept event (callKitId): $callKitId');
    return;
  }

  final lastAccept = _recentAcceptBySession[sessionId];
  if (lastAccept != null &&
      DateTime.now().difference(lastAccept) <
          const Duration(seconds: 30)) {
    debugPrint('⚠️ VoIPService: Duplicate accept event (time window)');
    return;
  }

  if (_acceptedSessions.contains(sessionId)) {
    debugPrint('⚠️ VoIPService: Call already accepted: $sessionId');
    return;
  }
  if (_acceptInProgress.contains(sessionId)) {
    debugPrint('⚠️ VoIPService: Accept already in progress for $sessionId');
    return;
  }
  if (callKitId != null) {
    _handledCallKitAcceptIds.add(callKitId);
  }
  _recentAcceptBySession[sessionId] = DateTime.now();
  _acceptInProgress.add(sessionId);
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

  try {
    final payloadRoomUrl = extra['roomUrl'] ?? data['roomUrl'];
    final payloadMeetingToken = extra['meetingToken'] ?? data['meetingToken'];
    final payloadRoomName = extra['roomName'] ?? data['roomName'];
    final hasPayloadRoomUrl =
        payloadRoomUrl is String && payloadRoomUrl.isNotEmpty;
    final hasPayloadMeetingToken =
        payloadMeetingToken is String && payloadMeetingToken.isNotEmpty;
    _lastAcceptedIsTutor = !(hasPayloadRoomUrl || hasPayloadMeetingToken);

    // Если в payload уже есть данные комнаты, значит это студент
    if (hasPayloadRoomUrl || hasPayloadMeetingToken) {
      _lastAcceptedIsTutor = false;
      _lastRoomUrl = hasPayloadRoomUrl ? payloadRoomUrl as String : null;
      _lastMeetingToken =
          hasPayloadMeetingToken ? payloadMeetingToken as String : null;
      _lastRoomName = payloadRoomName is String ? payloadRoomName : null;
      unawaited(_prefetchSessionTokens(sessionId));
      final videoDocRef = _firestore.collection('videoSessions').doc(sessionId);
      await videoDocRef.update({
        'studentNavigationTriggered': true,
        'navigationTimestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ VoIPService: Student navigation triggered (no acceptCall)');
      _acceptedSessions.add(sessionId);
      _tryNavigateToVideoCall(
        sessionId: sessionId,
        isTutor: false,
        roomUrl: _lastRoomUrl,
        meetingToken: _lastMeetingToken,
        roomName: _lastRoomName,
      );
      return;
    }

    // Перед acceptCall проверим, не активна ли уже сессия для этого преподавателя
    final recovered = await _tryRecoverActiveSession(sessionId);
    if (recovered) {
      _acceptedSessions.add(sessionId);
      _tryNavigateToVideoCall(
        sessionId: sessionId,
        isTutor: true,
        roomUrl: _lastRoomUrl,
        meetingToken: _lastMeetingToken,
        roomName: _lastRoomName,
      );
      return;
    }

    // Вызываем Cloud Function acceptCall
    debugPrint('☁️ VoIPService: Calling acceptCall function...');
    final result = await _functions
        .httpsCallable('acceptCall')
        .call({'sessionId': sessionId});

    debugPrint('✅ VoIPService: acceptCall response received');

    // Получаем данные из ответа
    final responseData = result.data as Map<String, dynamic>;
    final status = responseData['status'];
    final responseRoomUrl = responseData['roomUrl'];
    final responseRoomName = responseData['roomName'];
    final responseMeetingToken = responseData['meetingToken'];

    debugPrint('📊 VoIPService: Status: $status, Room URL: ${responseRoomUrl != null ? "present" : "missing"}');

    if (status != 'connected' || responseRoomUrl == null) {
      debugPrint('❌ VoIPService: Invalid response from acceptCall');
      return;
    }

    _lastAcceptedIsTutor = true;
    _lastRoomUrl = responseRoomUrl is String ? responseRoomUrl : null;
    _lastMeetingToken =
        responseMeetingToken is String ? responseMeetingToken : null;
    _lastRoomName = responseRoomName is String ? responseRoomName : null;
    unawaited(_prefetchSessionTokens(sessionId));

    // Создаем DocumentReference на videoSession
    final videoDocRef = _firestore.collection('videoSessions').doc(sessionId);

    debugPrint('🎬 VoIPService: Scheduling tutor navigation...');

    // Сохраняем данные в Firestore для последующей навигации
    await videoDocRef.update({
      'tutorNavigationTriggered': true,
      'navigationTimestamp': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ VoIPService: Tutor navigation data saved to Firestore');
    debugPrint('⚠️ VoIPService: App will navigate to VideoCallPage when opened');
    _acceptedSessions.add(sessionId);
    _tryNavigateToVideoCall(
      sessionId: sessionId,
      isTutor: true,
      roomUrl: _lastRoomUrl,
      meetingToken: _lastMeetingToken,
      roomName: _lastRoomName,
    );

  } catch (e) {
    debugPrint('❌ VoIPService: Error accepting call: $e');
    final recovered = await _tryRecoverActiveSession(sessionId);
    if (recovered) {
      _acceptedSessions.add(sessionId);
      _tryNavigateToVideoCall(
        sessionId: sessionId,
        isTutor: true,
        roomUrl: _lastRoomUrl,
        meetingToken: _lastMeetingToken,
        roomName: _lastRoomName,
      );
    }
  } finally {
    _acceptInProgress.remove(sessionId);
  }
}

  Future<bool> _tryRecoverActiveSession(String sessionId) async {
    try {
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

    const route = '/videoCallPage';
    final effectiveMeetingToken =
        _getFreshPrefetchedToken(sessionId) ?? meetingToken;
    final effectiveRoomUrl =
        roomUrl ?? _getPrefetchedRoomUrl(sessionId);
    final effectiveRoomName =
        roomName ?? _getPrefetchedRoomName(sessionId);
    final params = <String, String>{
      'videoDocRef': sessionId,
    };
    if (effectiveRoomUrl != null && effectiveRoomUrl.isNotEmpty) {
      params['roomUrl'] = Uri.encodeComponent(effectiveRoomUrl);
    }
    if (effectiveMeetingToken != null && effectiveMeetingToken.isNotEmpty) {
      params['meetingToken'] = Uri.encodeComponent(effectiveMeetingToken);
    }
    if (effectiveRoomName != null && effectiveRoomName.isNotEmpty) {
      params['roomName'] = Uri.encodeComponent(effectiveRoomName);
    }
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final target = '$route?$query';

    final router = GoRouter.of(navContext);
    final currentLocation = router.getCurrentLocation();
    if (currentLocation.startsWith(route)) {
      _lastNavigatedSessionId = sessionId;
      _lastNavigatedIsTutor = isTutor;
      debugPrint('ℹ️ VoIPService: Already on $route, skip navigation');
      return;
    }

    _lastNavigatedSessionId = sessionId;
    _lastNavigatedIsTutor = isTutor;
    router.go(target);
    debugPrint('🎬 VoIPService: Navigated to VideoCallPage');
  }

  void _queueNavigation({
    required String sessionId,
    required bool isTutor,
    String? roomUrl,
    String? meetingToken,
    String? roomName,
  }) {
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
    while (_pendingSessionId != null && attempts < 10) {
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
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
    if (_pendingSessionId != null) {
      debugPrint('⚠️ VoIPService: Navigation context not ready after retries');
    }
    _pendingSessionId = null;
    _navRetryInProgress = false;
  }

  void _handleAudioSessionToggle(dynamic body) {
    final isActive = body is Map && body['isActivate'] == true;
    debugPrint(
      '🔈 VoIPService: Audio session ${isActive ? 'activated' : 'deactivated'}',
    );
    if (isActive &&
        _lastAcceptedSessionId != null &&
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

  final extra = data['extra'] is Map
      ? Map<String, dynamic>.from(data['extra'] as Map)
      : <String, dynamic>{};
  final sessionId =
      extra['sessionId'] as String? ?? data['sessionId'] as String?;
  if (sessionId == null) {
    debugPrint('❌ VoIPService: No sessionId in decline event');
    return;
  }

    _clearSessionState(sessionId);
    debugPrint('❌ VoIPService: Call declined: $sessionId');

    try {
      // Вызываем Cloud Function declineCall
      await _functions
          .httpsCallable('declineCall')
          .call({'sessionId': sessionId});

    debugPrint('✅ VoIPService: declineCall completed');
  } catch (e) {
    debugPrint('❌ VoIPService: Error declining call: $e');
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

    _clearSessionState(sessionId);
    debugPrint('🔚 VoIPService: Call ended: $sessionId');

    try {
      // Вызываем Cloud Function endSession
      await _functions
          .httpsCallable('endSession')
          .call({
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

  final extra = data['extra'] is Map
      ? Map<String, dynamic>.from(data['extra'] as Map)
      : <String, dynamic>{};
  final sessionId =
      extra['sessionId'] as String? ?? data['sessionId'] as String?;
  if (sessionId == null) {
    debugPrint('❌ VoIPService: No sessionId in timeout event');
    return;
  }

    _clearSessionState(sessionId);
    debugPrint('⏰ VoIPService: Call timeout: $sessionId');

    // Ничего не делаем - Cloud Function processExpiredNotifications обработает
  }

  void _clearSessionState(String sessionId) {
    _acceptInProgress.remove(sessionId);
    _acceptedSessions.remove(sessionId);
    _recentAcceptBySession.remove(sessionId);
    final callKitIdForSession = _sessionCallKitIds[sessionId];
    if (callKitIdForSession != null) {
      _handledCallKitAcceptIds.remove(callKitIdForSession);
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
      _prefetchedMeetingToken = null;
      _prefetchedRoomUrl = null;
      _prefetchedRoomName = null;
      _prefetchedTokenFetchedAt = null;
      _prefetchInProgress = false;
    }
    _sessionCallKitIds.remove(sessionId);
  }

  Future<void> _prefetchSessionTokens(String sessionId) async {
    if (_prefetchInProgress && _prefetchedSessionId == sessionId) return;
    _prefetchInProgress = true;
    _prefetchedSessionId = sessionId;
    try {
      final result = await _functions
          .httpsCallable('getSessionTokens')
          .call({'sessionId': sessionId});
      final data = result.data as Map<String, dynamic>? ?? {};
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
      _prefetchInProgress = false;
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

  /// Завершить текущий активный звонок (программно)
  Future<void> endCurrentCall({String? sessionId}) async {
    try {
      final callKitId =
          sessionId != null ? _sessionCallKitIds[sessionId] : _lastCallKitId;
      if (callKitId != null) {
        await FlutterCallkitIncoming.endCall(callKitId);
        if (sessionId != null) {
          _sessionCallKitIds.remove(sessionId);
        }
        if (_lastCallKitId == callKitId) {
          _lastCallKitId = null;
        }
        debugPrint('✅ VoIPService: Call ended via CallKit');
        return;
      }
      await FlutterCallkitIncoming.endAllCalls();
      debugPrint('✅ VoIPService: All calls ended');
    } catch (e) {
      debugPrint('❌ VoIPService: Error ending calls: $e');
    }
  }

  /// Проверить, есть ли активные звонки
  Future<bool> hasActiveCalls() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      return calls.isNotEmpty;
    } catch (e) {
      debugPrint('❌ VoIPService: Error checking active calls: $e');
      return false;
    }
  }
}
