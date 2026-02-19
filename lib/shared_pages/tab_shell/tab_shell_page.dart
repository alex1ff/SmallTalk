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

  String get _currentPath => state.uri.path;

  int get _indexCurrentPage {
    if (_currentPath == ProfileWidget.routePath) {
      return 2;
    }
    if (_currentPath == WordsWidget.routePath) {
      return 3;
    }
    return 1;
  }

  bool get _showNavBar {
    return _currentPath == DashboardNSWidget.routePath ||
        _currentPath == StudentsDashboardWidget.routePath ||
        _currentPath == ProfileWidget.routePath ||
        _currentPath == WordsWidget.routePath;
  }

  @override
  Widget build(BuildContext context) {
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
