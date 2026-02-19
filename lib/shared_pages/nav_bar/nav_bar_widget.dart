import '/auth/firebase_auth/auth_util.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'nav_bar_model.dart';
export 'nav_bar_model.dart';

class NavBarWidget extends StatefulWidget {
  const NavBarWidget({
    super.key,
    int? indexCurrentPage,
  }) : this.indexCurrentPage = indexCurrentPage ?? 1;

  final int indexCurrentPage;

  @override
  State<NavBarWidget> createState() => _NavBarWidgetState();
}

class _NavBarWidgetState extends State<NavBarWidget> {
  late NavBarModel _model;
  static const _instantTransition = <String, dynamic>{
    kTransitionInfoKey: TransitionInfo(
      hasTransition: true,
      transitionType: PageTransitionType.fade,
      duration: Duration.zero,
    ),
  };

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NavBarModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  bool get _isTeacher => currentUserDocument?.role == UserRole.native_speaker;

  /// Maps the page-level index (1 = Home, 2 = Profile, 3 = Dictionary)
  /// to the 0-based tab bar index.
  int get _selectedIndex {
    if (_isTeacher) {
      return widget.indexCurrentPage == 2 ? 1 : 0;
    } else {
      switch (widget.indexCurrentPage) {
        case 3:
          return 1;
        case 2:
          return 2;
        default:
          return 0;
      }
    }
  }

  void _onTap(int index) {
    if (!mounted) return;
    if (_isTeacher) {
      _handleTeacherTap(index);
    } else {
      _handleStudentTap(index);
    }
  }

  void _handleTeacherTap(int index) {
    switch (index) {
      case 0:
        if (widget.indexCurrentPage == 1) return;
        context.goNamed(
          DashboardNSWidget.routeName,
          extra: _instantTransition,
        );
        return;
      case 1:
        if (widget.indexCurrentPage == 2) return;
        context.goNamed(
          ProfileWidget.routeName,
          extra: _instantTransition,
        );
        return;
    }
  }

  void _handleStudentTap(int index) {
    switch (index) {
      case 0:
        if (widget.indexCurrentPage == 1) return;
        context.goNamed(
          StudentsDashboardWidget.routeName,
          queryParameters: {
            'zn': serializeParam(false, ParamType.bool),
          }.withoutNulls,
          extra: _instantTransition,
        );
        return;
      case 1:
        if (widget.indexCurrentPage == 3) return;
        context.goNamed(
          WordsWidget.routeName,
          extra: _instantTransition,
        );
        return;
      case 2:
        if (widget.indexCurrentPage == 2) return;
        context.goNamed(
          ProfileWidget.routeName,
          extra: _instantTransition,
        );
        return;
    }
  }

  // ──────────────────── Build ────────────────────

  @override
  Widget build(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          return _buildMaterialNavBar(context);
        }

        if (PlatformInfo.isIOS26OrHigher()) {
          return _buildNativeIOS26TabBar();
        }
        return _buildCupertinoTabBar(context);
      },
    );
  }

  // ─────── iOS 26+ — native Liquid Glass tab bar + Flutter tap overlay ───────

  Widget _buildNativeIOS26TabBar() {
    final destinations = _isTeacher
        ? const [
            AdaptiveNavigationDestination(
              icon: 'house.fill',
              label: 'Главная',
            ),
            AdaptiveNavigationDestination(
              icon: 'person.fill',
              label: 'Профиль',
            ),
          ]
        : const [
            AdaptiveNavigationDestination(
              icon: 'house.fill',
              label: 'Главная',
            ),
            AdaptiveNavigationDestination(
              icon: 'book.fill',
              label: 'Словарь',
            ),
            AdaptiveNavigationDestination(
              icon: 'person.fill',
              label: 'Профиль',
            ),
          ];

    final bottomPadding = MediaQuery.of(context).padding.bottom > 0 ? 0.0 : 8.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: IOS26NativeTabBar(
        destinations: destinations,
        selectedIndex: _selectedIndex,
        onTap: _onTap,
        tint: const Color(0xFF008BFF),
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      ),
    );
  }

  // ─────── iOS < 26 — CupertinoTabBar ───────

  Widget _buildCupertinoTabBar(BuildContext context) {
    final items = _isTeacher
        ? [
            BottomNavigationBarItem(
              icon: Icon(FFIcons.khome01),
              label: FFLocalizations.of(context).getText('2hh3j18i'),
            ),
            BottomNavigationBarItem(
              icon: Icon(FFIcons.kuser03),
              label: FFLocalizations.of(context).getText('j96epnpj'),
            ),
          ]
        : [
            BottomNavigationBarItem(
              icon: Icon(FFIcons.khome01),
              label: FFLocalizations.of(context).getText('3ste14ts'),
            ),
            BottomNavigationBarItem(
              icon: Icon(FFIcons.kbookOpen01),
              label: FFLocalizations.of(context).getText('bhpm1ddo'),
            ),
            BottomNavigationBarItem(
              icon: Icon(FFIcons.kuser03),
              label: FFLocalizations.of(context).getText('04sylp8f'),
            ),
          ];

    return CupertinoTabBar(
      currentIndex: _selectedIndex,
      onTap: _onTap,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      activeColor: const Color(0xFF008BFF),
      items: items,
    );
  }

  // ─────── Android / other — Material NavigationBar ───────

  Widget _buildMaterialNavBar(BuildContext context) {
    final destinations = _isTeacher
        ? [
            NavigationDestination(
              icon: Icon(FFIcons.khome01),
              selectedIcon:
                  Icon(FFIcons.khome01, color: const Color(0xFF008BFF)),
              label: FFLocalizations.of(context).getText('2hh3j18i'),
            ),
            NavigationDestination(
              icon: Icon(FFIcons.kuser03),
              selectedIcon:
                  Icon(FFIcons.kuser03, color: const Color(0xFF008BFF)),
              label: FFLocalizations.of(context).getText('j96epnpj'),
            ),
          ]
        : [
            NavigationDestination(
              icon: Icon(FFIcons.khome01),
              selectedIcon:
                  Icon(FFIcons.khome01, color: const Color(0xFF008BFF)),
              label: FFLocalizations.of(context).getText('3ste14ts'),
            ),
            NavigationDestination(
              icon: Icon(FFIcons.kbookOpen01),
              selectedIcon:
                  Icon(FFIcons.kbookOpen01, color: const Color(0xFF008BFF)),
              label: FFLocalizations.of(context).getText('bhpm1ddo'),
            ),
            NavigationDestination(
              icon: Icon(FFIcons.kuser03),
              selectedIcon:
                  Icon(FFIcons.kuser03, color: const Color(0xFF008BFF)),
              label: FFLocalizations.of(context).getText('04sylp8f'),
            ),
          ];

    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onTap,
      animationDuration: Duration.zero,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      indicatorColor: const Color(0xFF008BFF).withValues(alpha: 0.12),
      destinations: destinations,
    );
  }
}
