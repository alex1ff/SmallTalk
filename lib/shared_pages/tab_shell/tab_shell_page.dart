import 'package:flutter/material.dart';

/// Persistent shell used as the builder for GoRouter's ShellRoute.
class TabShellPage extends StatelessWidget {
  const TabShellPage({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
