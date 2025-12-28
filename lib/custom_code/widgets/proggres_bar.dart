// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:math' as math;

class ProggresBar extends StatefulWidget {
  const ProggresBar({
    super.key,
    this.width,
    this.height,
    required this.currentStep,
    required this.totalSteps,
  });

  final double? width;
  final double? height;
  final int currentStep; // Текущий шаг (1-based: 1, 2, 3...)
  final int totalSteps; // Общее количество шагов

  @override
  State<ProggresBar> createState() => _ProggresBarState();
}

class _ProggresBarState extends State<ProggresBar> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? 64,
      height: widget.height ?? 64,
      child: CustomPaint(
        painter: _CircularProgressPainter(
          currentStep: widget.currentStep,
          totalSteps: widget.totalSteps,
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final int currentStep;
  final int totalSteps;

  _CircularProgressPainter({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalSteps <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = 2.0;

    // Радиус с учетом толщины линии, чтобы полностью вписаться в размеры
    final radius = (size.width / 2) - (strokeWidth / 2);

    final gapDegrees = 8.0;

    // Угол одного сегмента (без учета gap)
    final totalDegrees = 360.0;
    final segmentWithGap = totalDegrees / totalSteps;
    final segmentDegrees = segmentWithGap - gapDegrees;

    // Краска для активных делений (зеленая)
    final activePaint = Paint()
      ..color = const Color(0xFF4AFF5F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Краска для неактивных делений (серая)
    final inactivePaint = Paint()
      ..color = const Color(0xFFE5E5E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Рисуем все сегменты
    for (int i = 0; i < totalSteps; i++) {
      // Начинаем с -90 градусов (верх круга, 12 часов)
      final startAngleDegrees = -90 + (i * segmentWithGap);
      final startAngleRadians = startAngleDegrees * (math.pi / 180);
      final sweepAngleRadians = segmentDegrees * (math.pi / 180);

      // Выбираем краску: активную если i < currentStep
      final paint = i < currentStep ? activePaint : inactivePaint;

      // Рисуем дугу
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngleRadians,
        sweepAngleRadians,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.currentStep != currentStep ||
        oldDelegate.totalSteps != totalSteps;
  }
}
