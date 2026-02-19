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

  String get _currentPath => state.uri.path;
<<<<<<< ours

<<<<<<< ours
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
=======
  int get _indexCurrentPage {
    if (_currentPath == ProfileWidget.routePath) {
>>>>>>> theirs
=======

  int get _indexCurrentPage {
    if (_currentPath == ProfileWidget.routePath) {
>>>>>>> theirs
      return 2;
    }
    if (_currentPath == WordsWidget.routePath) {
      return 3;
    }
    return 1;
  }

<<<<<<< ours
<<<<<<< ours
  bool _showNavBar(String currentPath) {
    return _tabPaths.contains(currentPath);
=======
=======
>>>>>>> theirs
  bool get _showNavBar {
    return _currentPath == DashboardNSWidget.routePath ||
        _currentPath == StudentsDashboardWidget.routePath ||
        _currentPath == ProfileWidget.routePath ||
        _currentPath == WordsWidget.routePath;
<<<<<<< ours
>>>>>>> theirs
=======
>>>>>>> theirs
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< ours
<<<<<<< ours
    final currentPath = _currentPath(context);

=======
>>>>>>> theirs
=======
>>>>>>> theirs
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: child,
      bottomNavigationBar: _showNavBar
          ? NavBarWidget(
              indexCurrentPage: _indexCurrentPage,
            )
          : null,
    );
  }
}
