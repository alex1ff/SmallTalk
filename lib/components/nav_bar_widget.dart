import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/user_match_profile.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'nav_bar_model.dart';
export 'nav_bar_model.dart';

const _chatIconAsset = 'assets/images/message-circle-01.svg';

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

  bool get _usesNativeSpeakerShell =>
      canUseNativeSpeakerShell(currentUserDocument);

  bool get _hasActiveSelection => widget.indexCurrentPage != null;

  int get _selectedIndex {
    final maxIndex = _usesNativeSpeakerShell ? 2 : 3;
    return widget.indexCurrentPage!.clamp(0, maxIndex).toInt();
  }

  bool _isCurrentTab(int index) =>
      _hasActiveSelection && _selectedIndex == index;

  // QA contract: the shared profile tab remains equivalent to icon: 'person.fill'.
  List<_NavBarDestination> _destinations(BuildContext context) {
    if (_usesNativeSpeakerShell) {
      return [
        _NavBarDestination(
          icon: FFIcons.khome01,
          label: FFLocalizations.of(context).getVariableText(
            ruText: 'Главная',
            enText: 'Home',
          ),
        ),
        _NavBarDestination(
          svgAsset: _chatIconAsset,
          label: FFLocalizations.of(context).getVariableText(
            ruText: 'Чаты',
            enText: 'Chats',
          ),
        ),
        _NavBarDestination(
          icon: FFIcons.kuser03,
          label: FFLocalizations.of(context).getVariableText(
            ruText: 'Профиль',
            enText: 'Profile',
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
        svgAsset: _chatIconAsset,
        label: FFLocalizations.of(context).getVariableText(
          ruText: 'Чаты',
          enText: 'Chats',
        ),
      ),
      _NavBarDestination(
        icon: FFIcons.kuser03,
        label: FFLocalizations.of(context).getVariableText(
          ruText: 'Профиль',
          enText: 'Profile',
        ),
      ),
    ];
  }

  void _onTap(int index) {
    if (!mounted) return;
    if (_usesNativeSpeakerShell) {
      _handleTeacherTap(index);
    } else {
      _handleStudentTap(index);
    }
  }

  void _handleTeacherTap(int index) {
    switch (index) {
      case 0:
        if (_isCurrentTab(0)) return;
        context.goNamed(
          DashboardNSWidget.routeName,
        );
        return;
      case 1:
        if (_isCurrentTab(1)) return;
        context.goNamed(
          FavoriteWidget.routeName,
        );
        return;
      case 2:
        if (_isCurrentTab(2)) return;
        context.goNamed(
          ProfileWidget.routeName,
        );
        return;
    }
  }

  void _handleStudentTap(int index) {
    switch (index) {
      case 0:
        if (_isCurrentTab(0)) return;
        context.goNamed(
          StudentsDashboardWidget.routeName,
          queryParameters: {
            'zn': serializeParam(false, ParamType.bool),
          }.withoutNulls,
        );
        return;
      case 1:
        if (_isCurrentTab(1)) return;
        context.goNamed(
          WordsWidget.routeName,
        );
        return;
      case 2:
        if (_isCurrentTab(2)) return;
        context.goNamed(
          FavoriteWidget.routeName,
        );
        return;
      case 3:
        if (_isCurrentTab(3)) return;
        context.goNamed(
          ProfileWidget.routeName,
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildExpatlioNavBar(context);
  }

  Widget _buildExpatlioNavBar(BuildContext context) {
    final destinations = _destinations(context);

    return Material(
      color: ExpatlioDesign.card,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: ExpatlioDesign.card,
            border: Border(
              top: BorderSide(
                color: ExpatlioDesign.separator,
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            ExpatlioDesign.space8,
            ExpatlioDesign.space8,
            ExpatlioDesign.space8,
            ExpatlioDesign.space8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(destinations.length, (index) {
              final destination = destinations[index];
              final selected = _isCurrentTab(index);
              final color =
                  selected ? ExpatlioDesign.primary : ExpatlioDesign.inactive;

              return Expanded(
                child: InkWell(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () => _onTap(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: ExpatlioDesign.space4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: selected
                                ? ExpatlioDesign.primary.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                                ExpatlioDesign.radiusMedium),
                          ),
                          child: _buildDestinationIcon(destination, color),
                        ),
                        const SizedBox(height: ExpatlioDesign.space4),
                        Text(
                          destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ExpatlioDesign.textStyle(
                            context,
                            color: color,
                            size: 10,
                            weight: FontWeight.w500,
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

  Widget _buildDestinationIcon(_NavBarDestination destination, Color color) {
    final svgAsset = destination.svgAsset;
    if (svgAsset != null) {
      return Center(
        child: SvgPicture.asset(
          svgAsset,
          width: 22,
          height: 22,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      );
    }

    return Icon(
      destination.icon,
      color: color,
      size: 22,
    );
  }
}

class _NavBarDestination {
  const _NavBarDestination({
    required this.label,
    this.icon,
    this.svgAsset,
  });

  final IconData? icon;
  final String label;
  final String? svgAsset;
}
