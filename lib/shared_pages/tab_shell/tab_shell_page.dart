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

  int get _indexCurrentPage {
    final location = state.uri.toString();
    if (location.startsWith(ProfileWidget.routePath)) {
      return 2;
    }
    if (location.startsWith(WordsWidget.routePath)) {
      return 3;
    }
    return 1;
  }

  bool get _showNavBar {
    final location = state.uri.toString();
    return location.startsWith(DashboardNSWidget.routePath) ||
        location.startsWith(StudentsDashboardWidget.routePath) ||
        location.startsWith(ProfileWidget.routePath) ||
        location.startsWith(WordsWidget.routePath);
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
