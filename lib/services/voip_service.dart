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
  String? _lastNavigatedSessionId;

  // Для навигации нужен context - сохраним глобальный navigatorKey
  //static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Инициализация VoIP сервиса
  /// Вызывается один раз при запуске приложения
  Future<void> initialize() async {
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
            },
          );
        } catch (e) {
          debugPrint('❌ VoIPService: Failed to show CallKit in foreground: $e');
        }
      });

      // 4. Слушаем события CallKit/ConnectionService
      FlutterCallkitIncoming.onEvent.listen(_handleCallKitEvent);

      // 5. Пытаемся получить PushKit токен (iOS) если доступен
      await _syncPushKitToken();

      debugPrint('✅ VoIPService: Initialized successfully');
    } catch (e) {
      debugPrint('❌ VoIPService: Initialization error: $e');
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
  final sessionId =
      extra['sessionId'] as String? ??
      data['sessionId'] as String? ??
      data['id'] as String?;
  if (sessionId == null) {
    debugPrint('❌ VoIPService: No sessionId in accept event');
    return;
  }

  debugPrint('✅ VoIPService: Call accepted: $sessionId');

  try {
    final payloadRoomUrl = extra['roomUrl'] ?? data['roomUrl'];
    final payloadMeetingToken = extra['meetingToken'] ?? data['meetingToken'];

    // Если в payload уже есть данные комнаты, значит это студент
    if ((payloadRoomUrl is String && payloadRoomUrl.isNotEmpty) ||
        (payloadMeetingToken is String && payloadMeetingToken.isNotEmpty)) {
      final videoDocRef = _firestore.collection('videoSessions').doc(sessionId);
      await videoDocRef.update({
        'studentNavigationTriggered': true,
        'navigationTimestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ VoIPService: Student navigation triggered (no acceptCall)');
      _tryNavigateToVideoCall(sessionId: sessionId, isTutor: false);
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

    debugPrint('📊 VoIPService: Status: $status, Room URL: ${responseRoomUrl != null ? "present" : "missing"}');

    if (status != 'connected' || responseRoomUrl == null) {
      debugPrint('❌ VoIPService: Invalid response from acceptCall');
      return;
    }

    // Создаем DocumentReference на videoSession
    final videoDocRef = _firestore.collection('videoSessions').doc(sessionId);

    debugPrint('🎬 VoIPService: Scheduling tutor navigation...');

    // Сохраняем данные в Firestore для последующей навигации
    await videoDocRef.update({
      'tutorNavigationTriggered': true,
      'navigationTimestamp': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ VoIPService: Tutor navigation data saved to Firestore');
    debugPrint('⚠️ VoIPService: App will navigate to VideoCallPageNS when opened');
    _tryNavigateToVideoCall(sessionId: sessionId, isTutor: true);

  } catch (e) {
    debugPrint('❌ VoIPService: Error accepting call: $e');
  }
}

  void _tryNavigateToVideoCall({
    required String sessionId,
    required bool isTutor,
  }) {
    final navContext = appNavigatorKey.currentContext;
    if (navContext == null) {
      debugPrint('⚠️ VoIPService: Navigation context not ready');
      return;
    }

    if (_lastNavigatedSessionId == sessionId) {
      return;
    }

    final route = isTutor ? '/videoCallPageNS' : '/videoCallPageStudent';
    final target = '$route?videoDocRef=$sessionId';

    final router = GoRouter.of(navContext);
    final currentLocation = router.getCurrentLocation();
    if (currentLocation.startsWith(route)) {
      _lastNavigatedSessionId = sessionId;
      debugPrint('ℹ️ VoIPService: Already on $route, skip navigation');
      return;
    }

    _lastNavigatedSessionId = sessionId;
    router.go(target);
    debugPrint(
      '🎬 VoIPService: Navigated to ${isTutor ? 'VideoCallPageNS' : 'VideoCallPageStudent'}',
    );
  }

  /// Пользователь отклонил звонок
  Future<void> _handleCallDecline(Map<String, dynamic>? data) async {
    if (data == null) return;

    final extra = data['extra'] is Map
        ? Map<String, dynamic>.from(data['extra'] as Map)
        : <String, dynamic>{};
    final sessionId =
        extra['sessionId'] as String? ??
        data['sessionId'] as String? ??
        data['id'] as String?;
    if (sessionId == null) {
      debugPrint('❌ VoIPService: No sessionId in decline event');
      return;
    }

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
        extra['sessionId'] as String? ??
        data['sessionId'] as String? ??
        data['id'] as String?;
    if (sessionId == null) {
      debugPrint('❌ VoIPService: No sessionId in ended event');
      return;
    }

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
        extra['sessionId'] as String? ??
        data['sessionId'] as String? ??
        data['id'] as String?;
    if (sessionId == null) {
      debugPrint('❌ VoIPService: No sessionId in timeout event');
      return;
    }

    debugPrint('⏰ VoIPService: Call timeout: $sessionId');

    // Ничего не делаем - Cloud Function processExpiredNotifications обработает
  }

  /// Завершить текущий активный звонок (программно)
  Future<void> endCurrentCall() async {
    try {
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
