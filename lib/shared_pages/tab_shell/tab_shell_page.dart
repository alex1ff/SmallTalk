import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/user_match_profile.dart';
import '/components/nav_bar_widget.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

/// Persistent shell used as the builder for GoRouter's ShellRoute.
class TabShellPage extends StatefulWidget {
  const TabShellPage({
    super.key,
    required this.state,
    required this.child,
  });

  final GoRouterState state;
  final Widget child;

  @override
  State<TabShellPage> createState() => _TabShellPageState();
}

class _TabShellPageState extends State<TabShellPage> {
  GoRouteInformationProvider? _provider;
  GoRouterDelegate? _delegate;
  String _lastRoutePath = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);

    final provider = router.routeInformationProvider;
    if (_provider != provider) {
      _provider?.removeListener(_onProviderChanged);
      _provider = provider;
      _provider!.addListener(_onProviderChanged);
      _lastRoutePath = _normalizePath(_provider!.value.uri.path);
    }

    final delegate = router.routerDelegate;
    if (_delegate != delegate) {
      _delegate?.removeListener(_onDelegateChanged);
      _delegate = delegate;
      _delegate!.addListener(_onDelegateChanged);
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    _delegate?.removeListener(_onDelegateChanged);
    super.dispose();
  }

  /// Fires on push / go / replace — provider value is already correct.
  void _onProviderChanged() {
    if (!mounted || !_hasRoutePathChanged()) {
      return;
    }
    setState(() {});
  }

  /// Fires on pop — provider value is updated later in the frame by
  /// routerReportsNewRouteInformation, so defer the read.
  void _onDelegateChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasRoutePathChanged()) {
        return;
      }
      setState(() {});
    });
  }

  bool _hasRoutePathChanged() {
    if (_provider == null) {
      return false;
    }
    final nextPath = _normalizePath(_provider!.value.uri.path);
    if (nextPath == _lastRoutePath) {
      return false;
    }
    _lastRoutePath = nextPath;
    return true;
  }

  static String _normalizePath(String path) {
    if (path.endsWith('/') && path.length > 1) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  bool get _usesNativeSpeakerShell =>
      canUseNativeSpeakerShell(currentUserDocument);

  List<String> get _tabPathsOrdered => _usesNativeSpeakerShell
      ? [
          DashboardNSWidget.routePath,
          EventListWidget.routePath,
          FavoriteWidget.routePath,
          ProfileWidget.routePath,
        ]
      : [
          StudentsDashboardWidget.routePath,
          WordsWidget.routePath,
          FavoriteWidget.routePath,
          ProfileWidget.routePath,
          EventListWidget.routePath,
        ];

  List<String> get _pathsWithNavBar => _tabPathsOrdered;

  int? _indexCurrentPage(String currentPath) {
    final index = _tabPathsOrdered.indexOf(currentPath);
    return index >= 0 ? index : 0;
  }

  String _platformBranch() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    }
    if (PlatformInfo.isIOS26OrHigher()) {
      return 'ios26_native';
    }
    return 'cupertino';
  }

  @override
  Widget build(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) {
        final currentPath =
            _normalizePath(_provider?.value.uri.path ?? widget.state.uri.path);
        _lastRoutePath = currentPath;
        final isAwaitingUserDocument = loggedIn && currentUserDocument == null;
        final showNavBar =
            !isAwaitingUserDocument && _pathsWithNavBar.contains(currentPath);
        final indexCurrentPage = _indexCurrentPage(currentPath);

        if (kDebugMode) {
          debugPrint(
            '[TabShellPage] path=$currentPath '
            'showNavBar=$showNavBar '
            'awaitingUserDoc=$isAwaitingUserDocument '
            'indexCurrentPage=${indexCurrentPage ?? 'none'} '
            'role=${_usesNativeSpeakerShell ? 'teacher_shell' : 'student_shell'} '
            'platformBranch=${_platformBranch()}',
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: widget.child,
          bottomNavigationBar: showNavBar
              ? NavBarWidget(indexCurrentPage: indexCurrentPage)
              : null,
        );
      },
    );
  }
}
