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

  String _normalizePath(String path) {
    if (path.endsWith('/') && path.length > 1) {
      return path.substring(0, path.length - 1);
    }
    return path;
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
    return currentPath == DashboardNSWidget.routePath ||
        currentPath == StudentsDashboardWidget.routePath ||
        currentPath == ProfileWidget.routePath ||
        currentPath == WordsWidget.routePath;
  }

  @override
  Widget build(BuildContext context) {
    final routerPath =
        GoRouter.of(context).routeInformationProvider.value.uri.path;
    final currentPath = _normalizePath(
      routerPath.isNotEmpty ? routerPath : state.uri.path,
    );

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: child,
      bottomNavigationBar: _showNavBar(currentPath)
          ? NavBarWidget(
              indexCurrentPage: _indexCurrentPage(currentPath),
            )
          : null,
    );
  }
}
