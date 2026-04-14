import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/user_match_profile.dart';
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
    this.indexCurrentPage,
  });

  final int? indexCurrentPage;

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

  bool get _isTeacher => canAccessTeacherSurfaces(currentUserDocument);

  bool get _hasActiveSelection => widget.indexCurrentPage != null;

  int get _selectedIndex {
    final maxIndex = _isTeacher ? 1 : 2;
    return widget.indexCurrentPage!.clamp(0, maxIndex).toInt();
  }

  List<_NavBarDestination> _destinations(BuildContext context) {
    if (_isTeacher) {
      return [
        _NavBarDestination(
          icon: FFIcons.khome01,
          label: FFLocalizations.of(context).getVariableText(
            ruText: 'Главная',
            enText: 'Home',
          ),
        ),
        _NavBarDestination(
          icon: FFIcons.kusers02,
          label: FFLocalizations.of(context).getVariableText(
            ruText: 'Чаты',
            enText: 'Chats',
          ),
        ),
      ];
    }

    return [
      _NavBarDestination(
        icon: FFIcons.khome01,
        label: FFLocalizations.of(context).getVariableText(
          ruText: 'Главная',
          enText: 'Home',
        ),
      ),
      _NavBarDestination(
        icon: FFIcons.kbookOpen01,
        label: FFLocalizations.of(context).getVariableText(
          ruText: 'Словарь',
          enText: 'Words',
        ),
      ),
      _NavBarDestination(
        icon: FFIcons.kusers02,
        label: FFLocalizations.of(context).getVariableText(
          ruText: 'Чаты',
          enText: 'Chats',
        ),
      ),
    ];
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
          icon: 'ellipsis.message.fill',
          label: FFLocalizations.of(context).getVariableText(
            ruText: 'Чаты',
            enText: 'Chats',
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
        icon: 'ellipsis.message.fill',
        label: FFLocalizations.of(context).getVariableText(
          ruText: 'Чаты',
          enText: 'Chats',
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
          FavoriteWidget.routeName,
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
          FavoriteWidget.routeName,
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasActiveSelection) {
      return _buildPassiveNavBar(context);
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _buildMaterialNavBar(context);
    }

    if (PlatformInfo.isIOS26OrHigher()) {
      return _buildNativeIOS26TabBar();
    }

    return _buildCupertinoTabBar(context);
  }

  Widget _buildPassiveNavBar(BuildContext context) {
    final destinations = _destinations(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final iconColor = FlutterFlowTheme.of(context).secondaryText;
    final dividerColor = FlutterFlowTheme.of(context).alternate;

    return Material(
      color: FlutterFlowTheme.of(context).primaryBackground,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primaryBackground,
            border: Border(
              top: BorderSide(
                color: dividerColor,
                width: 1,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(8, 8, 8, bottomPadding > 0 ? 8 : 10),
          child: Row(
            children: List.generate(destinations.length, (index) {
              final destination = destinations[index];
              return Expanded(
                child: InkWell(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () => _onTap(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          destination.icon,
                          color: iconColor,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'SF Pro Display',
                                    color: iconColor,
                                    fontSize: 12,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
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
              icon: Icon(FFIcons.kusers02),
              label: FFLocalizations.of(context).getVariableText(
                ruText: 'Чаты',
                enText: 'Chats',
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
              icon: Icon(FFIcons.kusers02),
              label: FFLocalizations.of(context).getVariableText(
                ruText: 'Чаты',
                enText: 'Chats',
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
              icon: Icon(FFIcons.kusers02),
              selectedIcon:
                  Icon(FFIcons.kusers02, color: const Color(0xFF008BFF)),
              label: FFLocalizations.of(context).getVariableText(
                ruText: 'Чаты',
                enText: 'Chats',
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
              icon: Icon(FFIcons.kusers02),
              selectedIcon:
                  Icon(FFIcons.kusers02, color: const Color(0xFF008BFF)),
              label: FFLocalizations.of(context).getVariableText(
                ruText: 'Чаты',
                enText: 'Chats',
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

class _NavBarDestination {
  const _NavBarDestination({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}
