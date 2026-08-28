import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'auth/firebase_auth/firebase_user_provider.dart';
import 'auth/firebase_auth/auth_util.dart';

import 'backend/firebase/firebase_config.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/internationalization.dart';
import 'shared_pages/design/expatlio_design.dart';

// 🔔 VoIP imports
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/voip_service.dart';
import 'services/match_coordinator.dart';
import 'services/firebase_app_check_service.dart';
import 'services/user_presence_service.dart';
import 'custom_code/actions/check_active_session_and_navigate.dart' as actions;
import 'shared_pages/video_call_page/video_call_page_widget.dart';

// 💳 Subscription (RevenueCat) imports
import 'services/subscription_service.dart';

// 🔔 Background VoIP handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await initFirebase();

  debugPrint('🔔 Background message received: ${message.messageId}');
  debugPrint(
    '🔔 Background message type: ${message.data['type']}, '
    'hasSessionId: ${message.data['sessionId'] != null}',
  );

  if (message.data['type'] == 'call_cancelled') {
    final sessionId = message.data['sessionId']?.trim();
    if (sessionId != null && sessionId.isNotEmpty) {
      await VoIPService().cancelIncomingCall(
        sessionId: sessionId,
        callKitId: message.data['callKitId']?.toString(),
        pairAttemptId: message.data['pairAttemptId']?.toString(),
      );
      debugPrint('✅ Cancelled CallKit UI for session $sessionId');
    }
    return;
  }

  if (message.data['type'] == 'incoming_call') {
    debugPrint('📞 Incoming VoIP call detected in background');

    try {
      await VoIPService().showIncomingCall(
        sessionId: message.data['sessionId'] ?? '',
        callerName: message.data['callerName'] ?? 'Unknown Caller',
        callerId: message.data['callerId'] ?? '',
        callerPhoto: message.data['callerPhoto'],
        extraData: voipIncomingCallExtraDataFromPayload(message.data),
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

  // 🔔 Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  unawaited(VoIPService().startEarlyCallKitEventHandling());
  debugPrint('🔔 VoIP background handler registered');

  await initFirebase();
  await initializeFirebaseAppCheck();

  // 💳 Configure RevenueCat as soon as Firebase is up. Safe to ignore
  // failure: the service degrades gracefully and the auth stream
  // (firebase_user_provider.dart) will retry logInUser on next signal.
  unawaited(SubscriptionService.instance
      .configure(initialAppUserId: FirebaseAuth.instance.currentUser?.uid)
      .catchError((Object e) {
    debugPrint('⚠️ main: SubscriptionService.configure failed: $e');
  }));

  final appState = FFAppState();
  await Future.wait([
    FFLocalizations.initialize(),
    initializeDateFormatting(),
    appState.initializePersistedState(),
  ]);

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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Locale? _locale = FFLocalizations.getStoredLocale();

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
  StreamSubscription<BaseAuthUser>? _userStreamSub;
  bool _activeSessionRecoveryInProgress = false;
  int _authServiceGeneration = 0;
  String? _authServiceUserId;

  final authUserSub = authenticatedUserStream.listen((_) {});
  StreamSubscription? _jwtTokenSub;

  bool _isCurrentAuthServiceUser(String userId, int generation) =>
      mounted &&
      generation == _authServiceGeneration &&
      _authServiceUserId == userId;

  Future<void> _initializeVoipService(
    String userId,
    int generation,
  ) async {
    try {
      // CallKit actions may drain immediately after VoIP initialization. The
      // coordinator must already own this user so an Accept can be persisted
      // and retried with the correct identity.
      await MatchCoordinator.instance.startForUser(userId);
      if (!_isCurrentAuthServiceUser(userId, generation)) return;
      await VoIPService().initialize();
      if (_isCurrentAuthServiceUser(userId, generation) && loggedIn) {
        await VoIPService().setCallActionHandlingReady(true);
      }
      debugPrint('✅ VoIP Service initialized successfully');
    } catch (e) {
      debugPrint('❌ VoIP Service initialization failed: $e');
    }
  }

  Future<void> _deinitializeVoipService() async {
    try {
      await VoIPService().deinitialize();
      debugPrint('✅ VoIP Service deinitialized successfully');
    } catch (e) {
      debugPrint('❌ VoIP Service deinitialization failed: $e');
    }
  }

  Future<void> _refreshAuthUserOnResume() async {
    if (!loggedIn) {
      return;
    }

    try {
      await authManager.refreshUser();
      if (mounted) {
        safeSetState(() {});
      }
    } catch (e) {
      debugPrint('⚠️ Failed to refresh Firebase Auth user on resume: $e');
    }
  }

  Future<void> _recoverActiveSessionOnResume() async {
    if (!loggedIn || _activeSessionRecoveryInProgress) {
      return;
    }
    if (_router
        .getCurrentLocation()
        .startsWith(VideoCallPageWidget.routePath)) {
      return;
    }

    final navContext = appNavigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) {
      return;
    }

    _activeSessionRecoveryInProgress = true;
    try {
      await actions.checkActiveSessionAndNavigate(navContext);
    } catch (error) {
      debugPrint('⚠️ main: active session recovery on resume failed: $error');
    } finally {
      _activeSessionRecoveryInProgress = false;
    }
  }

  void _scheduleActiveSessionRecoveryAfterAuth() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_recoverActiveSessionOnResume());
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    userStream = smallTalkFirebaseUserStream();
    _userStreamSub = userStream.listen((user) {
      final wasLoggedIn = _appStateNotifier.loggedIn;
      if (!user.loggedIn) {
        _authServiceGeneration += 1;
        _authServiceUserId = null;
        FFAppState().clearPendingSocialAuthContext();
        UserPresenceService.instance.stop();
        unawaited(MatchCoordinator.instance.stop());
        if (wasLoggedIn) {
          unawaited(VoIPService().setCallActionHandlingReady(false));
          unawaited(_deinitializeVoipService());
        }
      }
      final userId = user.uid;
      if (user.loggedIn && userId != null && userId.isNotEmpty) {
        if (!wasLoggedIn) {
          UserPresenceService.instance.start();
        }
        if (_authServiceUserId != userId) {
          _authServiceUserId = userId;
          final generation = ++_authServiceGeneration;
          unawaited(VoIPService().setCallActionHandlingReady(false));
          unawaited(_initializeVoipService(userId, generation));
        } else {
          unawaited(MatchCoordinator.instance.startForUser(userId));
        }
      }
      _appStateNotifier.update(user);
      _appStateNotifier.stopShowingSplashImage();
      if (user.loggedIn && !wasLoggedIn) {
        _scheduleActiveSessionRecoveryAfterAuth();
      }
    });
    _jwtTokenSub = jwtTokenStream.listen((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAuthUserOnResume());
      unawaited(UserPresenceService.instance.markSeen(force: true));
      if (loggedIn) {
        final userId = _authServiceUserId;
        if (userId != null) {
          unawaited(_initializeVoipService(
            userId,
            _authServiceGeneration,
          ));
        }
      }
      unawaited(_recoverActiveSessionOnResume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    authUserSub.cancel();
    _userStreamSub?.cancel();
    _jwtTokenSub?.cancel();
    UserPresenceService.instance.stop();
    _authServiceGeneration += 1;
    _authServiceUserId = null;
    unawaited(VoIPService().setCallActionHandlingReady(false));
    unawaited(MatchCoordinator.instance.stop());

    super.dispose();
  }

  void setLocale(String language) {
    safeSetState(() => _locale = createLocale(language));
    FFLocalizations.storeLocale(language);
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
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
      title: 'Expatlio',
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
      theme: ExpatlioDesign.lightTheme(),
      themeMode: _themeMode,
      routerConfig: _router,
      builder: (_, child) => ColoredBox(
        color: ExpatlioDesign.background,
        child: MediaQuery(
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
      ),
    );
  }
}
