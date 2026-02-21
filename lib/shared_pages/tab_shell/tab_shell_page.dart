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

  String _currentPath() {
    return _normalizePath(state.uri.path);
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
    final currentPath = _currentPath();
    final indexCurrentPage = _indexCurrentPage(currentPath);

    if (kDebugMode) {
      debugPrint(
        '[TabShellPage] path=$currentPath '
        'indexCurrentPage=$indexCurrentPage '
        'role=${_isTeacher ? 'teacher' : 'student'} '
        'platformBranch=${_platformBranch()}',
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: child,
      bottomNavigationBar: NavBarWidget(
        indexCurrentPage: indexCurrentPage,
      ),
    );
  }
}
