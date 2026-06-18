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
import 'services/voip_service.dart';
import 'services/user_presence_service.dart';
import 'services/event_list_date_bounds.dart';

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

  if (message.data['type'] == 'incoming_call') {
    debugPrint('📞 Incoming VoIP call detected in background');

    try {
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
  initializeEventListTimeZones();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  // 🔔 Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  debugPrint('🔔 VoIP background handler registered');

  await initFirebase();

  // 💳 Configure RevenueCat as soon as Firebase is up. Safe to ignore
  // failure: the service degrades gracefully and the auth stream
  // (firebase_user_provider.dart) will retry logInUser on next signal.
  unawaited(SubscriptionService.instance.configure().catchError((Object e) {
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

  final authUserSub = authenticatedUserStream.listen((_) {});
  StreamSubscription? _jwtTokenSub;

  Future<void> _initializeVoipService() async {
    try {
      await VoIPService().initialize();
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
        FFAppState().clearPendingSocialAuthContext();
        UserPresenceService.instance.stop();
        if (wasLoggedIn) {
          unawaited(_deinitializeVoipService());
        }
      } else if (!wasLoggedIn) {
        UserPresenceService.instance.start();
        unawaited(_initializeVoipService());
      }
      _appStateNotifier.update(user);
      _appStateNotifier.stopShowingSplashImage();
    });
    _jwtTokenSub = jwtTokenStream.listen((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAuthUserOnResume());
      unawaited(UserPresenceService.instance.markSeen(force: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    authUserSub.cancel();
    _userStreamSub?.cancel();
    _jwtTokenSub?.cancel();
    UserPresenceService.instance.stop();

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
