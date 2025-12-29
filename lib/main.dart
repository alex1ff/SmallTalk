import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'auth/firebase_auth/firebase_user_provider.dart';
import 'auth/firebase_auth/auth_util.dart';

import 'backend/firebase/firebase_config.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/internationalization.dart';

// 🔔 VoIP импорты
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/voip_service.dart';

// 🔔 Обработчик VoIP уведомлений в фоновом режиме
// Вызывается когда приложение закрыто или в фоне
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await initFirebase();
  
  debugPrint('🔔 Background message received: ${message.messageId}');
  debugPrint('🔔 Message data: ${message.data}');
  
  // Проверяем тип уведомления
  if (message.data['type'] == 'incoming_call') {
    debugPrint('📞 Incoming VoIP call detected in background');
    
    try {
      // Показываем CallKit UI
      await VoIPService().showIncomingCall(
        sessionId: message.data['sessionId'] ?? '',
        callerName: message.data['callerName'] ?? 'Unknown Caller',
        callerId: message.data['callerId'] ?? '',
        callerPhoto: message.data['callerPhoto'],
        extraData: {
          'roomUrl': message.data['roomUrl'],
          'meetingToken': message.data['meetingToken'],
        },
      );
      debugPrint('✅ CallKit UI shown successfully');
    } catch (e) {
      debugPrint('❌ Error showing CallKit: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  // 🔔 Регистрация обработчика фоновых VoIP уведомлений
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  debugPrint('🔔 VoIP background handler registered');

  await initFirebase();

  // 🔔 Инициализация VoIP сервиса
  try {
    await VoIPService().initialize();
    debugPrint('✅ VoIP Service initialized successfully');
  } catch (e) {
    debugPrint('❌ VoIP Service initialization failed: $e');
  }

  final appState = FFAppState(); // Initialize FFAppState
  await appState.initializePersistedState();

  runApp(ChangeNotifierProvider(
    create: (context) => appState,
    child: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  ThemeMode _themeMode = ThemeMode.system;
  double _textScaleFactor = 1.0;

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  late Stream<BaseAuthUser> userStream;

  final authUserSub = authenticatedUserStream.listen((_) {});

  @override
  void initState() {
    super.initState();

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    userStream = smallTalkFirebaseUserStream()
      ..listen((user) {
        _appStateNotifier.update(user);
        
// 🔔 Проверяем активные видео-сессии при смене пользователя
if (user.loggedIn) {
  final userId = user.uid;
  if (userId != null && userId.isNotEmpty) {
    _checkForActiveVideoSession(userId);
  }
}
      });
    jwtTokenStream.listen((_) {});
    Future.delayed(
      Duration(milliseconds: 1000),
      () => _appStateNotifier.stopShowingSplashImage(),
    );
  }

  // 🔔 Проверка активной видео-сессии для автоматической навигации
  Future<void> _checkForActiveVideoSession(String userId) async {
    try {
      debugPrint('🔍 Checking for active video session for user: $userId');
      
      // Получаем пользователя из Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        debugPrint('⚠️ User document not found');
        return;
      }
      
      final userData = userDoc.data();
      final userRole = userData?['role'] as String?;
      
      // Проверяем только для студентов
      if (userRole != 'student') {
        debugPrint('ℹ️ User is not a student, skipping session check');
        return;
      }
      
      // Ищем активную сессию для этого студента
      final activeSessions = await FirebaseFirestore.instance
          .collection('videoSessions')
          .where('studentId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .where('studentNavigationTriggered', isEqualTo: true)
          .limit(1)
          .get();
      
      if (activeSessions.docs.isEmpty) {
        debugPrint('📭 No active sessions requiring navigation');
        return;
      }
      
      final sessionDoc = activeSessions.docs.first;
      final sessionId = sessionDoc.id;
      
      debugPrint('✅ Found active session requiring navigation: $sessionId');
      
      // Сбрасываем флаг навигации
      await sessionDoc.reference.update({
        'studentNavigationTriggered': false,
        'navigationCompletedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('🎬 Navigating to VideoCallPageStudent...');
      
      // Даем время на инициализацию роутера
      await Future.delayed(Duration(milliseconds: 1500));
      
      // Переходим на страницу видеозвонка
      final videoDocRef = sessionDoc.reference;
      
      // Используем query parameters для навигации (совместимо с FlutterFlow)
      _router.go(
        '/videoCallPageStudent?videoDocRef=${Uri.encodeComponent(videoDocRef.path)}',
      );
      
      debugPrint('✅ Navigation triggered successfully');
      
    } catch (e) {
      debugPrint('❌ Error checking for active video session: $e');
    }
  }

  @override
  void dispose() {
    authUserSub.cancel();

    super.dispose();
  }

  void setLocale(String language) {
    safeSetState(() => _locale = createLocale(language));
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;  // ← Исправлено: точка с запятой
      });

  void setTextScaleFactor(double updatedFactor) {
    if (updatedFactor < FlutterFlowTheme.minTextScaleFactor ||
        updatedFactor > FlutterFlowTheme.maxTextScaleFactor) {
      return;
    }
    safeSetState(() {
      _textScaleFactor = updatedFactor;
    });
  }

  void incrementTextScaleFactor(double incrementValue) {
    final updatedFactor = _textScaleFactor + incrementValue;
    if (updatedFactor < FlutterFlowTheme.minTextScaleFactor ||
        updatedFactor > FlutterFlowTheme.maxTextScaleFactor) {
      return;
    }
    safeSetState(() {
      _textScaleFactor = updatedFactor;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Small Talk',
      localizationsDelegates: [
        FFLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
      ],
      locale: _locale,
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
      ),
      themeMode: _themeMode,
      routerConfig: _router,
      builder: (_, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler:
              _textScaleFactor == FlutterFlowTheme.defaultTextScaleFactor
                  ? MediaQuery.of(context).textScaler.clamp(
                        minScaleFactor: FlutterFlowTheme.minTextScaleFactor,
                        maxScaleFactor: FlutterFlowTheme.maxTextScaleFactor,
                      )
                  : TextScaler.linear(_textScaleFactor).clamp(
                      minScaleFactor: FlutterFlowTheme.minTextScaleFactor,
                      maxScaleFactor: FlutterFlowTheme.maxTextScaleFactor,
                    ),
        ),
        child: child!,
      ),
    );
  }
}