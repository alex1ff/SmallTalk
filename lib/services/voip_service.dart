import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart'; // ← ДОБАВИЛИ ЭТУ СТРОКУ!
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// VoIP сервис для обработки входящих звонков
/// Использует CallKit (iOS) и ConnectionService (Android)
class VoIPService {
  static final VoIPService _instance = VoIPService._internal();
  factory VoIPService() => _instance;
  VoIPService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
        criticalAlert: true, // Для iOS важные уведомления
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

      // 4. Слушаем события CallKit/ConnectionService
      FlutterCallkitIncoming.onEvent.listen(_handleCallKitEvent);

      debugPrint('✅ VoIPService: Initialized successfully');
    } catch (e) {
      debugPrint('❌ VoIPService: Initialization error: $e');
    }
  }

  /// Сохранение VoIP токена в Firestore
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
        'platform': Theme.of(
          // Определяем платформу
          WidgetsBinding.instance.rootElement!,
        ).platform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      });

      debugPrint('✅ VoIPService: Token saved for user ${user.uid}');
    } catch (e) {
      debugPrint('❌ VoIPService: Error saving token: $e');
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

      final callKitParams = CallKitParams(
        id: sessionId,
        nameCaller: callerName,
        appName: 'Small Talk',
        avatar: callerPhoto,
        handle: callerId,
        type: 1, // 0: audio only, 1: video call
        textAccept: 'Accept',
        textDecline: 'Decline',
        duration: 45000, // 45 секунд таймаут (в миллисекундах)
        extra: <String, dynamic>{
          'sessionId': sessionId,
          'callerId': callerId,
          ...?extraData, // Дополнительные данные (roomUrl, token и т.д.)
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

  /// Пользователь принял звонок
  Future<void> _handleCallAccept(Map<String, dynamic>? data) async {
    if (data == null) return;

    final sessionId = data['sessionId'] as String?;
    if (sessionId == null) {
      debugPrint('❌ VoIPService: No sessionId in accept event');
      return;
    }

    debugPrint('✅ VoIPService: Call accepted: $sessionId');

    // TODO: Вызвать вашу Cloud Function acceptCall
    // Пример:
    // final result = await FirebaseFunctions.instance
    //     .httpsCallable('acceptCall')
    //     .call({'sessionId': sessionId});

    // TODO: Перейти на экран видеозвонка
    // Пример:
    // final extraData = data['extra'] as Map<String, dynamic>?;
    // final roomUrl = extraData?['roomUrl'] as String?;
    // if (roomUrl != null) {
    //   // Навигация на VideoCallPage с roomUrl
    // }

    debugPrint('⚠️ VoIPService: TODO - Navigate to call screen');
  }

  /// Пользователь отклонил звонок
  Future<void> _handleCallDecline(Map<String, dynamic>? data) async {
    if (data == null) return;

    final sessionId = data['sessionId'] as String?;
    if (sessionId == null) {
      debugPrint('❌ VoIPService: No sessionId in decline event');
      return;
    }

    debugPrint('❌ VoIPService: Call declined: $sessionId');

    // TODO: Вызвать вашу Cloud Function declineCall
    // Пример:
    // await FirebaseFunctions.instance
    //     .httpsCallable('declineCall')
    //     .call({'sessionId': sessionId});

    debugPrint('⚠️ VoIPService: TODO - Call declineCall function');
  }

  /// Звонок завершен
  Future<void> _handleCallEnded(Map<String, dynamic>? data) async {
    if (data == null) return;

    final sessionId = data['sessionId'] as String?;
    if (sessionId == null) {
      debugPrint('❌ VoIPService: No sessionId in ended event');
      return;
    }

    debugPrint('🔚 VoIPService: Call ended: $sessionId');

    // TODO: Вызвать вашу Cloud Function endSession
    // Пример:
    // await FirebaseFunctions.instance
    //     .httpsCallable('endSession')
    //     .call({
    //       'sessionId': sessionId,
    //       'endReason': 'user_ended',
    //     });

    debugPrint('⚠️ VoIPService: TODO - Call endSession function');
  }

  /// Таймаут звонка (45 секунд без ответа)
  Future<void> _handleCallTimeout(Map<String, dynamic>? data) async {
    if (data == null) return;

    final sessionId = data['sessionId'] as String?;
    if (sessionId == null) {
      debugPrint('❌ VoIPService: No sessionId in timeout event');
      return;
    }

    debugPrint('⏰ VoIPService: Call timeout: $sessionId');

    // Ничего не делаем - ваша Cloud Function processExpiredNotifications
    // уже обработает это через Firestore
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