import '/auth/firebase_auth/auth_util.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/shared_pages/nav_bar/nav_bar_widget.dart';
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

  bool get _isTeacher => currentUserDocument?.role == UserRole.native_speaker;

  List<String> get _tabPathsOrdered => _isTeacher
      ? [
          DashboardNSWidget.routePath,
          ProfileWidget.routePath,
          MyCallsWidget.routePath,
        ]
      : [
          StudentsDashboardWidget.routePath,
          WordsWidget.routePath,
          ProfileWidget.routePath,
          MyCallsWidget.routePath,
        ];

  int _indexCurrentPage(String currentPath) {
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
        final showNavBar = _tabPathsOrdered.contains(currentPath);
        final indexCurrentPage = _indexCurrentPage(currentPath);

        if (kDebugMode) {
          debugPrint(
            '[TabShellPage] path=$currentPath '
            'showNavBar=$showNavBar '
            'indexCurrentPage=$indexCurrentPage '
            'role=${_isTeacher ? 'teacher' : 'student'} '
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
