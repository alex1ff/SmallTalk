import 'package:flutter/material.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.alignment,
  })  : children = null,
        direction = Axis.vertical,
        gap = 0.0,
        mainAxisAlignment = MainAxisAlignment.start,
        crossAxisAlignment = CrossAxisAlignment.center,
        mainAxisSize = MainAxisSize.max,
        _keyboardAware = false,
        _keyboardPadding = EdgeInsets.zero;

  const Wrapper.row({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.gap = 0.0,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.alignment,
  })  : child = null,
        direction = Axis.horizontal,
        _keyboardAware = false,
        _keyboardPadding = EdgeInsets.zero;

  const Wrapper.column({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.gap = 0.0,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.alignment,
  })  : child = null,
        direction = Axis.vertical,
        _keyboardAware = false,
        _keyboardPadding = EdgeInsets.zero;

  const Wrapper.keyboardAware({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 35.0),
    EdgeInsetsGeometry keyboardPadding =
        const EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 6.0),
    this.margin = EdgeInsets.zero,
    this.alignment,
  })  : children = null,
        direction = Axis.vertical,
        gap = 0.0,
        mainAxisAlignment = MainAxisAlignment.start,
        crossAxisAlignment = CrossAxisAlignment.center,
        mainAxisSize = MainAxisSize.max,
        _keyboardAware = true,
        _keyboardPadding = keyboardPadding;

  static const animationDuration = Duration(milliseconds: 160);

  final Widget? child;
  final List<Widget>? children;
  final Axis direction;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double gap;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final AlignmentGeometry? alignment;
  final bool _keyboardAware;
  final EdgeInsetsGeometry _keyboardPadding;

  @override
  Widget build(BuildContext context) {
    Widget current = _content();

    if (alignment != null) {
      current = Align(
        alignment: alignment!,
        child: current,
      );
    }

    if (_keyboardAware) {
      final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
      current = AnimatedPadding(
        duration: animationDuration,
        curve: Curves.easeOutCubic,
        padding: isKeyboardVisible ? _keyboardPadding : padding,
        child: current,
      );
    } else {
      current = Padding(
        padding: padding,
        child: current,
      );
    }

    return Container(
      margin: margin,
      child: current,
    );
  }

  Widget _content() {
    final childWidget = child;
    if (childWidget != null) {
      return childWidget;
    }

    final childWidgets = children ?? const <Widget>[];
    final spacedChildren = _withGap(childWidgets);

    if (direction == Axis.horizontal) {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: spacedChildren,
      );
    }

    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: spacedChildren,
    );
  }

  List<Widget> _withGap(List<Widget> childWidgets) {
    if (gap <= 0 || childWidgets.length < 2) {
      return childWidgets;
    }

    final gapWidget = direction == Axis.horizontal
        ? SizedBox(width: gap)
        : SizedBox(height: gap);
    final spacedChildren = <Widget>[];

    for (var index = 0; index < childWidgets.length; index++) {
      spacedChildren.add(childWidgets[index]);
      if (index < childWidgets.length - 1) {
        spacedChildren.add(gapWidget);
      }
    }

    return spacedChildren;
  }
}
