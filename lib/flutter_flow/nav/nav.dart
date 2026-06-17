import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';

import '/auth/base_auth_user_provider.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

import '/index.dart';
import '/shared_pages/tab_shell/tab_shell_page.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._();

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  BaseAuthUser? initialUser;
  BaseAuthUser? user;
  bool showSplashImage = true;
  String? _redirectLocation;

  /// Determines whether the app will refresh and build again when a sign
  /// in or sign out happens. This is useful when the app is launched or
  /// on an unexpected logout. However, this must be turned off when we
  /// intend to sign in/out and then navigate or perform any actions after.
  /// Otherwise, this will trigger a refresh and interrupt the action(s).
  bool notifyOnAuthChange = true;

  bool get loading => user == null || showSplashImage;
  bool get loggedIn => user?.loggedIn ?? false;
  bool get initiallyLoggedIn => initialUser?.loggedIn ?? false;
  bool get shouldRedirect => loggedIn && _redirectLocation != null;

  String getRedirectLocation() => _redirectLocation!;
  bool hasRedirect() => _redirectLocation != null;
  void setRedirectLocationIfUnset(String loc) => _redirectLocation ??= loc;
  void clearRedirectLocation() => _redirectLocation = null;

  /// Mark as not needing to notify on a sign in / out when we intend
  /// to perform subsequent actions (such as navigation) afterwards.
  void updateNotifyOnAuthChange(bool notify) => notifyOnAuthChange = notify;

  void update(BaseAuthUser newUser) {
    final shouldUpdate =
        user?.uid == null || newUser.uid == null || user?.uid != newUser.uid;
    initialUser ??= newUser;
    user = newUser;
    // Refresh the app on auth change unless explicitly marked otherwise.
    // No need to update unless the user has changed.
    if (notifyOnAuthChange && shouldUpdate) {
      notifyListeners();
    }
    // Once again mark the notifier as needing to update on auth change
    // (in order to catch sign in / out events).
    updateNotifyOnAuthChange(true);
  }

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

GoRouter createRouter(AppStateNotifier appStateNotifier) => GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: kDebugMode,
      refreshListenable: appStateNotifier,
      navigatorKey: appNavigatorKey,
      errorBuilder: (context, state) =>
          appStateNotifier.loggedIn ? LoadingWidget() : OnboardingWidget(),
      routes: <RouteBase>[
        // ── Non-tab routes ──
        ...[
          FFRoute(
            name: '_initialize',
            path: '/',
            builder: (context, _) => appStateNotifier.loggedIn
                ? LoadingWidget()
                : OnboardingWidget(),
          ),
          FFRoute(
            name: OnboardingWidget.routeName,
            path: OnboardingWidget.routePath,
            builder: (context, params) => OnboardingWidget(),
          ),
          FFRoute(
            name: LoginWidget.routeName,
            path: LoginWidget.routePath,
            builder: (context, params) => LoginWidget(),
          ),
          FFRoute(
            name: RegistrationWidget.routeName,
            path: RegistrationWidget.routePath,
            builder: (context, params) => RegistrationWidget(),
          ),
          FFRoute(
            name: AcquaintanceSTUDENTWidget.routeName,
            path: AcquaintanceSTUDENTWidget.routePath,
            requireAuth: true,
            builder: (context, params) => AcquaintanceSTUDENTWidget(
              index: params.getParam(
                'index',
                ParamType.int,
              ),
            ),
          ),
          FFRoute(
            name: LoadingWidget.routeName,
            path: LoadingWidget.routePath,
            requireAuth: true,
            builder: (context, params) => LoadingWidget(),
          ),
          FFRoute(
            name: CallSummaryWidget.routeName,
            path: CallSummaryWidget.routePath,
            requireAuth: true,
            builder: (context, params) => CallSummaryWidget(
              userRef: params.getParam(
                'userRef',
                ParamType.DocumentReference,
                isList: false,
                collectionNamePath: ['users'],
              ),
              sessionID: params.getParam(
                'sessionID',
                ParamType.DocumentReference,
                isList: false,
                collectionNamePath: ['videoSessions'],
              ),
              lang: params.getParam(
                'lang',
                ParamType.String,
              ),
              dur: params.getParam(
                'dur',
                ParamType.int,
              ),
            ),
          ),
          FFRoute(
            name: CallDetailsWidget.routeName,
            path: CallDetailsWidget.routePath,
            requireAuth: true,
            builder: (context, params) => CallDetailsWidget(
              videoDocRef: params.getParam(
                'videoDocRef',
                ParamType.DocumentReference,
                isList: false,
                collectionNamePath: ['videoSessions'],
              ),
            ),
          ),
          FFRoute(
            name: VideoCallPageWidget.routeName,
            path: VideoCallPageWidget.routePath,
            requireAuth: true,
            builder: (context, params) => VideoCallPageWidget(
              videoDocRef: params.getParam(
                'videoDocRef',
                ParamType.DocumentReference,
                isList: false,
                collectionNamePath: ['videoSessions'],
              ),
              initialRoomUrl: params.getParam(
                'roomUrl',
                ParamType.String,
              ),
              initialMeetingToken: params.getParam(
                'meetingToken',
                ParamType.String,
              ),
              initialRoomName: params.getParam(
                'roomName',
                ParamType.String,
              ),
            ),
          ),
          FFRoute(
            name: WaitingForTeacherPageWidget.routeName,
            path: WaitingForTeacherPageWidget.routePath,
            requireAuth: true,
            builder: (context, params) => WaitingForTeacherPageWidget(),
          ),
          FFRoute(
            name: NativeSpeakerPageWidget.routeName,
            path: NativeSpeakerPageWidget.routePath,
            requireAuth: true,
            builder: (context, params) => NativeSpeakerPageWidget(
              nsUserDocRef: params.getParam(
                'nsUserDocRef',
                ParamType.DocumentReference,
                isList: false,
                collectionNamePath: ['users'],
              ),
            ),
          ),
          FFRoute(
            name: MyRewWidget.routeName,
            path: MyRewWidget.routePath,
            requireAuth: true,
            builder: (context, params) => MyRewWidget(),
          ),
          FFRoute(
            name: PayWidget.routeName,
            path: PayWidget.routePath,
            requireAuth: true,
            builder: (context, params) => PayWidget(),
          ),
          FFRoute(
            name: AcquaintanceNSWidget.routeName,
            path: AcquaintanceNSWidget.routePath,
            requireAuth: true,
            builder: (context, params) => AcquaintanceNSWidget(
              index: params.getParam(
                'index',
                ParamType.int,
              ),
              entrySource: params.getParam(
                'entrySource',
                ParamType.String,
              ),
            ),
          ),
          FFRoute(
            name: RecoverPassWidget.routeName,
            path: RecoverPassWidget.routePath,
            builder: (context, params) => RecoverPassWidget(),
          ),
          FFRoute(
            name: PolicyWidget.routeName,
            path: PolicyWidget.routePath,
            builder: (context, params) => PolicyWidget(),
          ),
          FFRoute(
            name: PayCopyWidget.routeName,
            path: PayCopyWidget.routePath,
            requireAuth: true,
            builder: (context, params) => PayCopyWidget(),
          ),
          FFRoute(
            name: 'PayWebWiew',
            path: '/payWebWiew',
            requireAuth: true,
            builder: (context, params) => PayWidget(),
          ),
          FFRoute(
            name: BlackListWidget.routeName,
            path: BlackListWidget.routePath,
            requireAuth: true,
            builder: (context, params) => BlackListWidget(),
          ),
          FFRoute(
            name: MyCallsWidget.routeName,
            path: MyCallsWidget.routePath,
            requireAuth: true,
            builder: (context, params) => MyCallsWidget(),
          ),
          FFRoute(
            name: MyRewNSWidget.routeName,
            path: MyRewNSWidget.routePath,
            requireAuth: true,
            builder: (context, params) => MyRewNSWidget(),
          ),
          FFRoute(
            name: FlashcardWidget.routeName,
            path: FlashcardWidget.routePath,
            requireAuth: true,
            builder: (context, params) => FlashcardWidget(),
          ),
          FFRoute(
            name: ProfileEditWidget.routeName,
            path: ProfileEditWidget.routePath,
            requireAuth: true,
            builder: (context, params) => ProfileEditWidget(),
          ),
          FFRoute(
            name: EventCreateWidget.routeName,
            path: EventCreateWidget.routePath,
            requireAuth: true,
            builder: (context, params) => EventCreateWidget(),
          ),
          FFRoute(
            name: EventEditWidget.routeName,
            path: EventEditWidget.routePath,
            requireAuth: true,
            builder: (context, params) => EventEditWidget(
              eventId: params.getParam(
                'eventId',
                ParamType.String,
              ),
            ),
          ),
          FFRoute(
            name: EventGroupChatWidget.routeName,
            path: EventGroupChatWidget.routePath,
            requireAuth: true,
            builder: (context, params) => EventGroupChatWidget(
              eventId: params.getParam(
                'eventId',
                ParamType.String,
              ),
            ),
          ),
          FFRoute(
            name: EventDetailWidget.routeName,
            path: EventDetailWidget.routePath,
            requireAuth: true,
            builder: (context, params) => EventDetailWidget(
              eventId: params.getParam(
                'eventId',
                ParamType.String,
              ),
            ),
          ),
        ].map((r) => r.toRoute(appStateNotifier)),

        // ── Tab pages wrapped in ShellRoute ──
        ShellRoute(
          builder: (context, state, child) =>
              TabShellPage(state: state, child: child),
          routes: [
            FFRoute(
              name: DashboardNSWidget.routeName,
              path: DashboardNSWidget.routePath,
              requireAuth: true,
              noTransition: true,
              builder: (context, params) => DashboardNSWidget(
                zn: params.getParam(
                  'zn',
                  ParamType.bool,
                ),
              ),
            ),
            FFRoute(
              name: StudentsDashboardWidget.routeName,
              path: StudentsDashboardWidget.routePath,
              requireAuth: true,
              noTransition: true,
              builder: (context, params) => StudentsDashboardWidget(
                zn: params.getParam(
                  'zn',
                  ParamType.bool,
                ),
                done: params.getParam(
                  'done',
                  ParamType.bool,
                ),
                topUpSuccess: params.getParam(
                  'topUpSuccess',
                  ParamType.bool,
                ),
              ),
            ),
            FFRoute(
              name: EventListWidget.routeName,
              path: EventListWidget.routePath,
              requireAuth: true,
              noTransition: true,
              builder: (context, params) => EventListWidget(),
            ),
            FFRoute(
              name: ProfileWidget.routeName,
              path: ProfileWidget.routePath,
              requireAuth: true,
              noTransition: true,
              builder: (context, params) => ProfileWidget(),
            ),
            FFRoute(
              name: WordsWidget.routeName,
              path: WordsWidget.routePath,
              requireAuth: true,
              noTransition: true,
              builder: (context, params) => WordsWidget(),
            ),
            FFRoute(
              name: FavoriteWidget.routeName,
              path: FavoriteWidget.routePath,
              requireAuth: true,
              noTransition: true,
              builder: (context, params) => FavoriteWidget(),
            ),
          ].map((r) => r.toRoute(appStateNotifier)).toList(),
        ),
      ],
    );

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
        entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
}

extension NavigationExtensions on BuildContext {
  void goNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : goNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void pushNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : pushNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void safePop() {
    // If there is only one route on the stack, navigate to the initial
    // page instead of popping.
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension GoRouterExtensions on GoRouter {
  AppStateNotifier get appState => AppStateNotifier.instance;
  void prepareAuthEvent([bool ignoreRedirect = false]) =>
      appState.hasRedirect() && !ignoreRedirect
          ? null
          : appState.updateNotifyOnAuthChange(false);
  bool shouldRedirect(bool ignoreRedirect) =>
      !ignoreRedirect && appState.hasRedirect();
  void clearRedirectLocation() => appState.clearRedirectLocation();
  void setRedirectLocationIfUnset(String location) =>
      appState.setRedirectLocationIfUnset(location);
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap =>
      extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo => extraMap.containsKey(kTransitionInfoKey)
      ? extraMap[kTransitionInfoKey] as TransitionInfo
      : TransitionInfo.appDefault();
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  // Parameters are empty if the params map is empty or if the only parameter
  // present is the special extra parameter reserved for the transition info.
  bool get isEmpty =>
      state.allParams.isEmpty ||
      (state.allParams.length == 1 &&
          state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
        state.allParams.entries.where(isAsyncParam).map(
          (param) async {
            final doc = await asyncParams[param.key]!(param.value)
                .onError((_, __) => null);
            if (doc != null) {
              futureParamValues[param.key] = doc;
              return true;
            }
            return false;
          },
        ),
      ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(
    String paramName,
    ParamType type, {
    bool isList = false,
    List<String>? collectionNamePath,
    StructBuilder<T>? structBuilder,
  }) {
    if (futureParamValues.containsKey(paramName)) {
      return futureParamValues[paramName];
    }
    if (!state.allParams.containsKey(paramName)) {
      return null;
    }
    final param = state.allParams[paramName];
    // Got parameter from `extras`, so just directly return it.
    if (param is! String) {
      return param;
    }
    // Return serialized value.
    return deserializeParam<T>(
      param,
      type,
      isList,
      collectionNamePath: collectionNamePath,
      structBuilder: structBuilder,
    );
  }
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
    this.noTransition = false,
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;
  final bool noTransition;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
        name: name,
        path: path,
        redirect: (context, state) {
          if (appStateNotifier.shouldRedirect) {
            final redirectLocation = appStateNotifier.getRedirectLocation();
            appStateNotifier.clearRedirectLocation();
            return redirectLocation;
          }

          if (requireAuth && !appStateNotifier.loggedIn) {
            appStateNotifier.setRedirectLocationIfUnset(state.uri.toString());
            return '/onboarding';
          }
          return null;
        },
        pageBuilder: (context, state) {
          fixStatusBarOniOS16AndBelow(context);
          final ffParams = FFParameters(state, asyncParams);
          final page = ffParams.hasFutures
              ? FutureBuilder(
                  future: ffParams.completeFutures(),
                  builder: (context, _) => builder(context, ffParams),
                )
              : builder(context, ffParams);
          final child = appStateNotifier.loading
              ? Center(
                  child: SizedBox(
                    width: 50.0,
                    height: 50.0,
                    child: SpinKitCircle(
                      color: FlutterFlowTheme.of(context).secondary,
                      size: 50.0,
                    ),
                  ),
                )
              : page;

          if (noTransition) {
            return NoTransitionPage(key: state.pageKey, child: child);
          }

          final transitionInfo = state.transitionInfo;
          return transitionInfo.hasTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  child: child,
                  transitionDuration: transitionInfo.duration,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          PageTransition(
                    type: transitionInfo.transitionType,
                    duration: transitionInfo.duration,
                    reverseDuration: transitionInfo.duration,
                    alignment: transitionInfo.alignment,
                    child: child,
                  ).buildTransitions(
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ),
                )
              : MaterialPage(key: state.pageKey, child: child);
        },
        routes: routes,
      );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() => TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage &&
        location != '/' &&
        location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) => Provider.value(
        value: RootPageContext(true, errorRoute),
        child: child,
      );
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
