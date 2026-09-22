import 'package:flutter/material.dart';

import '/services/ux_loading_state.dart';
import '/shared_pages/design/expatlio_design.dart';

enum UxRefreshIndicatorPosition {
  top,
  bottom,
}

class UxPreviousDataRefreshLayer<T extends Object> extends StatelessWidget {
  const UxPreviousDataRefreshLayer({
    super.key,
    required this.state,
    required this.child,
    this.position = UxRefreshIndicatorPosition.top,
    this.indicator,
    this.semanticsLabel = 'Обновление',
    this.curve = Curves.easeOut,
    this.padding = const EdgeInsets.all(ExpatlioDesign.space8),
    this.duration = const Duration(milliseconds: 180),
  });

  final UxLoadingState<T> state;
  final Widget child;
  final UxRefreshIndicatorPosition position;
  final Widget? indicator;
  final String? semanticsLabel;
  final Curve curve;
  final EdgeInsetsGeometry padding;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return UxRefreshingIndicatorOverlay(
      isRefreshing: state.isRefreshing,
      position: position,
      indicator: indicator,
      semanticsLabel: semanticsLabel,
      curve: curve,
      padding: padding,
      duration: duration,
      child: child,
    );
  }
}

class UxRefreshingIndicatorOverlay extends StatelessWidget {
  const UxRefreshingIndicatorOverlay({
    super.key,
    required this.isRefreshing,
    required this.child,
    this.position = UxRefreshIndicatorPosition.top,
    this.indicator,
    this.semanticsLabel = 'Обновление',
    this.curve = Curves.easeOut,
    this.padding = const EdgeInsets.all(ExpatlioDesign.space8),
    this.duration = const Duration(milliseconds: 180),
  });

  final bool isRefreshing;
  final Widget child;
  final UxRefreshIndicatorPosition position;
  final Widget? indicator;
  final String? semanticsLabel;
  final Curve curve;
  final EdgeInsetsGeometry padding;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final visibleIndicator = isRefreshing
        ? indicator == null
            ? UxRefreshingIndicatorPill(
                semanticsLabel: semanticsLabel,
              )
            : Semantics(
                liveRegion: semanticsLabel != null,
                label: semanticsLabel,
                child: indicator!,
              )
        : const SizedBox.shrink();

    final overlay = IgnorePointer(
      child: AnimatedOpacity(
        opacity: isRefreshing ? 1.0 : 0.0,
        duration: duration,
        curve: curve,
        child: Padding(
          padding: padding,
          child: Center(
            heightFactor: 1.0,
            child: TickerMode(
              enabled: isRefreshing,
              child: visibleIndicator,
            ),
          ),
        ),
      ),
    );

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: 0.0,
          right: 0.0,
          top: position == UxRefreshIndicatorPosition.top ? 0.0 : null,
          bottom: position == UxRefreshIndicatorPosition.bottom ? 0.0 : null,
          child: overlay,
        ),
      ],
    );
  }
}

class UxRefreshingIndicatorPill extends StatelessWidget {
  const UxRefreshingIndicatorPill({
    super.key,
    this.dimension = 26.0,
    this.strokeWidth = 2.0,
    this.semanticsLabel = 'Обновление',
  });

  final double dimension;
  final double strokeWidth;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: semanticsLabel != null,
      label: semanticsLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ExpatlioDesign.card,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
          border: Border.all(color: ExpatlioDesign.border),
          boxShadow: ExpatlioDesign.cardShadow,
        ),
        child: SizedBox(
          width: dimension,
          height: dimension,
          child: Padding(
            padding: const EdgeInsets.all(ExpatlioDesign.space8),
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              color: ExpatlioDesign.primary,
              backgroundColor: ExpatlioDesign.quaternaryLabel,
            ),
          ),
        ),
      ),
    );
  }
}
