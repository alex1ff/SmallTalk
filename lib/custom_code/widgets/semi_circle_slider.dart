// Automatic FlutterFlow imports
import '/backend/schema/enums/enums.dart';
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:math' as math;

class SemiCircleSlider extends StatefulWidget {
  const SemiCircleSlider({
    super.key,
    this.width,
    this.height,
    this.onChanged,
    this.initialLevel,
  });

  final double? width;
  final double? height;
  final Future Function(Level level)? onChanged;
  final Level? initialLevel;

  @override
  State<SemiCircleSlider> createState() => _SemiCircleSliderState();
}

class _SemiCircleSliderState extends State<SemiCircleSlider> {
  double _currentAngle = math.pi;
  Level? _lastLevel;
  bool _isDragging = false;

  static const double sweepPercent = 0.63;
  static const double strokeWidth = 30.0;
  static const snapPoints = [0.0, 33.33, 66.66, 100.0];

  @override
  void initState() {
    super.initState();
    if (widget.initialLevel != null) {
      _currentAngle = _levelToAngle(widget.initialLevel!);
      _lastLevel = widget.initialLevel;
    }
  }

  @override
  void didUpdateWidget(SemiCircleSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLevel != oldWidget.initialLevel &&
        widget.initialLevel != null &&
        !_isDragging) {
      setState(() {
        _currentAngle = _levelToAngle(widget.initialLevel!);
        _lastLevel = widget.initialLevel;
      });
    }
  }

  double _levelToAngle(Level level) {
    final sweepAngle = 2 * math.pi * sweepPercent;
    int index;

    switch (level) {
      case Level.Beginner:
        index = 0;
        break;
      case Level.Basic:
        index = 1;
        break;
      case Level.Intermediate:
        index = 2;
        break;
      case Level.Fluent:
        index = 3;
        break;
    }

    return (snapPoints[index] / 100) * sweepAngle;
  }

  Level _indexToLevel(int index) {
    switch (index) {
      case 1:
        return Level.Beginner;
      case 2:
        return Level.Basic;
      case 3:
        return Level.Intermediate;
      case 4:
        return Level.Fluent;
      default:
        return Level.Beginner;
    }
  }

  Level _getCurrentLevel() {
    final sweepAngle = 2 * math.pi * sweepPercent;
    final progress = (_currentAngle / sweepAngle) * 100;

    double nearest = snapPoints[0];
    double minDist = (progress - nearest).abs();
    int idx = 0;

    for (int i = 0; i < snapPoints.length; i++) {
      final dist = (progress - snapPoints[i]).abs();
      if (dist < minDist) {
        minDist = dist;
        nearest = snapPoints[i];
        idx = i;
      }
    }

    return _indexToLevel(idx + 1);
  }

  double coordinatesToRadians(Offset center, Offset coords) {
    var a = coords.dx - center.dx;
    var b = coords.dy - center.dy;
    return math.atan2(b, a);
  }

  Offset radiansToCoordinates(Offset center, double radians, double radius) {
    var dx = center.dx + radius * math.cos(radians);
    var dy = center.dy + radius * math.sin(radians);
    return Offset(dx, dy);
  }

  bool isPointAlongCircle(
      Offset point, Offset center, double radius, double width) {
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    return (distance - radius).abs() <= width;
  }

  void _handlePan(Offset globalPosition) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(globalPosition);
    final size = box.size;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - strokeWidth;

    if (!isPointAlongCircle(localPosition, center, radius, 50.0)) {
      return;
    }

    double touchAngle = coordinatesToRadians(center, localPosition);

    final sweepAngle = 2 * math.pi * sweepPercent;
    final startAngle = (3 * math.pi / 2) - (sweepAngle / 2);

    if (touchAngle < 0) touchAngle += 2 * math.pi;

    double normalizedStart = startAngle;
    while (normalizedStart < 0) normalizedStart += 2 * math.pi;
    while (normalizedStart >= 2 * math.pi) normalizedStart -= 2 * math.pi;

    double relativeAngle = touchAngle - normalizedStart;

    if (relativeAngle < 0) relativeAngle += 2 * math.pi;

    if (relativeAngle <= sweepAngle) {
      setState(() {
        _currentAngle = relativeAngle;
      });

      final currentLevel = _getCurrentLevel();
      if (_lastLevel != currentLevel) {
        _lastLevel = currentLevel;
        widget.onChanged?.call(currentLevel);
      }
    } else if (!_isDragging) {
      double distToStart = relativeAngle;
      double distToEnd = 2 * math.pi - relativeAngle;

      setState(() {
        _currentAngle = distToStart < distToEnd ? 0.0 : sweepAngle;
      });

      final currentLevel = _getCurrentLevel();
      if (_lastLevel != currentLevel) {
        _lastLevel = currentLevel;
        widget.onChanged?.call(currentLevel);
      }
    }
  }

  void _snapToNearest() {
    _isDragging = false;

    final sweepAngle = 2 * math.pi * sweepPercent;
    final progress = (_currentAngle / sweepAngle) * 100;

    double nearest = snapPoints[0];
    double minDist = (progress - nearest).abs();
    int idx = 0;

    for (int i = 0; i < snapPoints.length; i++) {
      final dist = (progress - snapPoints[i]).abs();
      if (dist < minDist) {
        minDist = dist;
        nearest = snapPoints[i];
        idx = i;
      }
    }

    final snappedAngle = (nearest / 100) * sweepAngle;
    final level = _indexToLevel(idx + 1);

    setState(() {
      _currentAngle = snappedAngle;
    });

    if (_lastLevel != level) {
      _lastLevel = level;
      widget.onChanged?.call(level);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        _isDragging = true;
        _handlePan(details.globalPosition);
      },
      onPanUpdate: (details) => _handlePan(details.globalPosition),
      onPanEnd: (_) => _snapToNearest(),
      child: CustomPaint(
        size: Size(widget.width ?? 0, widget.height ?? 0),
        painter: _SliderPainter(_currentAngle),
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  final double currentAngle;

  static const strokeWidth = 30.0;
  static const sweepPercent = 0.63;
  static const thumbRadius = 11.0; // Размер 22 (диаметр)

  _SliderPainter(this.currentAngle);

  Offset radiansToCoordinates(Offset center, double radians, double radius) {
    var dx = center.dx + radius * math.cos(radians);
    var dy = center.dy + radius * math.sin(radians);
    return Offset(dx, dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - strokeWidth;

    final sweepAngle = 2 * math.pi * sweepPercent;
    final startAngle = (3 * math.pi / 2) - (sweepAngle / 2);

    // Неактивная дорожка
    final inactivePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      inactivePaint,
    );

    // Активная дорожка с градиентом
    if (currentAngle > 0.01) {
      final gradientStart = radiansToCoordinates(center, startAngle, radius);
      final gradientEnd =
          radiansToCoordinates(center, startAngle + currentAngle, radius);

      final rect = Rect.fromCircle(center: center, radius: radius);

      final gradient = LinearGradient(
        begin: Alignment(
          (gradientStart.dx - center.dx) / radius,
          (gradientStart.dy - center.dy) / radius,
        ),
        end: Alignment(
          (gradientEnd.dx - center.dx) / radius,
          (gradientEnd.dy - center.dy) / radius,
        ),
        colors: const [
          Color(0xFFC9C3F6),
          Color(0xFF3E2AF3),
        ],
      );

      final activePaint = Paint()
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..shader = gradient.createShader(rect);

      canvas.drawArc(
        rect,
        startAngle,
        currentAngle,
        false,
        activePaint,
      );
    }

    // Thumb
    final thumbAngle = startAngle + currentAngle;
    final thumbPos = radiansToCoordinates(center, thumbAngle, radius);

    final thumbPaint = Paint()
      ..color = const Color(0xFF4AFF5F)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(thumbPos, thumbRadius, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
