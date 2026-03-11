import '/auth/firebase_auth/auth_util.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'nav_bar_model.dart';
export 'nav_bar_model.dart';

class NavBarWidget extends StatefulWidget {
  const NavBarWidget({
    super.key,
    int? indexCurrentPage,
  }) : this.indexCurrentPage = indexCurrentPage ?? 0;

  final int indexCurrentPage;

  @override
  State<NavBarWidget> createState() => _NavBarWidgetState();
}

class _NavBarWidgetState extends State<NavBarWidget> {
  late NavBarModel _model;

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

  int get _selectedIndex {
    final maxIndex = _isTeacher ? 2 : 3;
    return widget.indexCurrentPage.clamp(0, maxIndex).toInt();
  }

  List<AdaptiveNavigationDestination> _adaptiveDestinations(
    BuildContext context,
  ) {
    if (_isTeacher) {
      return [
        AdaptiveNavigationDestination(
          icon: 'house.fill',
          label: FFLocalizations.of(context).getVariableText(
            ruText: 'Главная',
            enText: 'Home',
          ),
        ),
        AdaptiveNavigationDestination(
          icon: 'person.fill',
          label: FFLocalizations.of(context).getVariableText(
            ruText: 'Профиль',
            enText: 'Profile',
          ),
        ),
        AdaptiveNavigationDestination(
          icon: 'phone.fill',
          label: FFLocalizations.of(context).getVariableText(
            ruText: 'Мои звонки',
            enText: 'My calls',
          ),
        ),
      ];
    }

    return [
      AdaptiveNavigationDestination(
        icon: 'house.fill',
        label: FFLocalizations.of(context).getVariableText(
          ruText: 'Главная',
          enText: 'Home',
        ),
      ),
      AdaptiveNavigationDestination(
        icon: 'book.fill',
        label: FFLocalizations.of(context).getVariableText(
          ruText: 'Словарь',
          enText: 'Words',
        ),
      ),
      AdaptiveNavigationDestination(
        icon: 'person.fill',
        label: FFLocalizations.of(context).getVariableText(
          ruText: 'Профиль',
          enText: 'Profile',
        ),
      ),
      AdaptiveNavigationDestination(
        icon: 'phone.fill',
        label: FFLocalizations.of(context).getVariableText(
          ruText: 'Мои звонки',
          enText: 'My calls',
        ),
      ),
    ];
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
        if (_selectedIndex == 0) return;
        context.goNamed(
          DashboardNSWidget.routeName,
        );
        return;
      case 1:
        if (_selectedIndex == 1) return;
        context.goNamed(
          ProfileWidget.routeName,
        );
        return;
      case 2:
        if (_selectedIndex == 2) return;
        context.goNamed(
          MyCallsWidget.routeName,
        );
        return;
    }
  }

  void _handleStudentTap(int index) {
    switch (index) {
      case 0:
        if (_selectedIndex == 0) return;
        context.goNamed(
          StudentsDashboardWidget.routeName,
          queryParameters: {
            'zn': serializeParam(false, ParamType.bool),
          }.withoutNulls,
        );
        return;
      case 1:
        if (_selectedIndex == 1) return;
        context.goNamed(
          WordsWidget.routeName,
        );
        return;
      case 2:
        if (_selectedIndex == 2) return;
        context.goNamed(
          ProfileWidget.routeName,
        );
        return;
      case 3:
        if (_selectedIndex == 3) return;
        context.goNamed(
          MyCallsWidget.routeName,
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _buildMaterialNavBar(context);
    }

    if (PlatformInfo.isIOS26OrHigher()) {
      return _buildNativeIOS26TabBar();
    }

    return _buildCupertinoTabBar(context);
  }

  Widget _buildNativeIOS26TabBar() {
    final destinations = _adaptiveDestinations(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom > 0 ? 0.0 : 8.0;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: IOS26NativeTabBar(
          destinations: destinations,
          selectedIndex: _selectedIndex,
          onTap: _onTap,
          tint: const Color(0xFF008BFF),
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          minimizeBehavior: TabBarMinimizeBehavior.never,
        ),
      ),
    );
  }

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
            BottomNavigationBarItem(
              icon: Icon(FFIcons.kphone),
              label: FFLocalizations.of(context).getVariableText(
                ruText: 'Мои звонки',
                enText: 'My calls',
              ),
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
            BottomNavigationBarItem(
              icon: Icon(FFIcons.kphone),
              label: FFLocalizations.of(context).getVariableText(
                ruText: 'Мои звонки',
                enText: 'My calls',
              ),
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
            NavigationDestination(
              icon: Icon(FFIcons.kphone),
              selectedIcon:
                  Icon(FFIcons.kphone, color: const Color(0xFF008BFF)),
              label: FFLocalizations.of(context).getVariableText(
                ruText: 'Мои звонки',
                enText: 'My calls',
              ),
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
            NavigationDestination(
              icon: Icon(FFIcons.kphone),
              selectedIcon:
                  Icon(FFIcons.kphone, color: const Color(0xFF008BFF)),
              label: FFLocalizations.of(context).getVariableText(
                ruText: 'Мои звонки',
                enText: 'My calls',
              ),
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
