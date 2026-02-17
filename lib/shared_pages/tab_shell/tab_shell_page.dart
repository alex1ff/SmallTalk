import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/shared_pages/nav_bar/nav_bar_widget.dart';
import '/index.dart';

/// Persistent shell that keeps the NavBar alive across tab page transitions.
/// Used as the builder for GoRouter's ShellRoute.
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
    if (location.startsWith(ProfileWidget.routePath) ||
        location.startsWith(ProfileEditWidget.routePath)) {
      return 2;
    }
    if (location.startsWith(WordsWidget.routePath)) {
      return 3;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Align(
          alignment: Alignment.bottomCenter,
          child: NavBarWidget(
            indexCurrentPage: _indexCurrentPage,
          ),
        ),
      ],
    );
  }
}
