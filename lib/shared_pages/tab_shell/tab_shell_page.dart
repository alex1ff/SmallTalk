import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/shared_pages/nav_bar/nav_bar_widget.dart';
import '/index.dart';

/// Persistent shell used as the builder for GoRouter's ShellRoute.
class TabShellPage extends StatelessWidget {
  const TabShellPage({
    super.key,
    required this.state,
    required this.child,
  });

  final GoRouterState state;
  final Widget child;

  static final Set<String> _tabPaths = {
    DashboardNSWidget.routePath,
    StudentsDashboardWidget.routePath,
    ProfileWidget.routePath,
    WordsWidget.routePath,
  };

  String _normalizePath(String path) {
    if (path.endsWith('/') && path.length > 1) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  String _currentPath(BuildContext context) {
    try {
      final router = GoRouter.of(context);
      final RouteMatch lastMatch =
          router.routerDelegate.currentConfiguration.last;
      final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
          ? lastMatch.matches
          : router.routerDelegate.currentConfiguration;
      return _normalizePath(matchList.uri.path);
    } catch (_) {
      return _normalizePath(state.uri.path);
    }
  }

  int _indexCurrentPage(String currentPath) {
    if (currentPath == ProfileWidget.routePath) {
      return 2;
    }
    if (currentPath == WordsWidget.routePath) {
      return 3;
    }
    return 1;
  }

  bool _showNavBar(String currentPath) {
    return _tabPaths.contains(currentPath);
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = _currentPath(context);
    final showNavBar = _showNavBar(currentPath);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: child,
      bottomNavigationBar: IgnorePointer(
        ignoring: !showNavBar,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          offset: showNavBar ? Offset.zero : const Offset(0.0, 1.0),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            opacity: showNavBar ? 1.0 : 0.0,
            child: NavBarWidget(
              indexCurrentPage: _indexCurrentPage(currentPath),
            ),
          ),
        ),
      ),
    );
  }
}
