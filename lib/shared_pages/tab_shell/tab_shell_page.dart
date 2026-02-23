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
  static const _tabPaths = {
    '/dashboardNS',
    '/studentsDashboard',
    '/profile',
    '/words',
  };

  GoRouteInformationProvider? _provider;
  GoRouterDelegate? _delegate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);

    final provider = router.routeInformationProvider;
    if (_provider != provider) {
      _provider?.removeListener(_onProviderChanged);
      _provider = provider;
      _provider!.addListener(_onProviderChanged);
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
    if (mounted) setState(() {});
  }

  /// Fires on pop — provider value is updated later in the frame by
  /// routerReportsNewRouteInformation, so defer the read.
  void _onDelegateChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  static String _normalizePath(String path) {
    if (path.endsWith('/') && path.length > 1) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  bool get _isTeacher => currentUserDocument?.role == UserRole.native_speaker;

  int _indexCurrentPage(String currentPath) {
    if (currentPath == ProfileWidget.routePath) {
      return 2;
    }
    if (currentPath == WordsWidget.routePath) {
      return 3;
    }
    return 1;
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
    final currentPath = _normalizePath(
      _provider!.value.uri.path,
    );
    final showNavBar = _tabPaths.contains(currentPath);
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
  }
}
