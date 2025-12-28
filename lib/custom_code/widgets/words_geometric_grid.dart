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

import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

class WordsGeometricGrid extends StatefulWidget {
  const WordsGeometricGrid({
    super.key,
    this.width,
    this.height,
    required this.words,
    this.onWordTap,
  });

  final double? width;
  final double? height;
  final List<UserWordsRecord>? words;
  final Future Function(UserWordsRecord? wordDoc)? onWordTap;

  @override
  State<WordsGeometricGrid> createState() => _WordsGeometricGridState();
}

class _WordsGeometricGridState extends State<WordsGeometricGrid> {
  int? selectedIndex;
  late List<GeometricConfig> configs;

  @override
  void initState() {
    super.initState();
    _initializeConfigs();
  }

  @override
  void didUpdateWidget(WordsGeometricGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.words?.length != widget.words?.length) {
      _initializeConfigs();
    }
  }

  void _initializeConfigs() {
    if (widget.words != null) {
      configs = List.generate(
        widget.words!.length,
        (index) => GeometricConfig.generate(index),
      );
    } else {
      configs = [];
    }
  }

  String _getWordText(UserWordsRecord word) {
    try {
      if (word.entry != null && word.entry!.isNotEmpty) {
        final text = word.entry!.first.text;
        if (text != null) return text.toString();
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  String _getTranslation(UserWordsRecord word) {
    try {
      if (word.entry != null && word.entry!.isNotEmpty) {
        final tr = word.entry!.first.tr;
        if (tr != null) return tr.toString();
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words == null || widget.words!.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      width: widget.width,
      height: widget.height ?? 280,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        physics: BouncingScrollPhysics(),
        child: MasonryGridView.count(
          crossAxisCount: 2, // 2 ряда
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: widget.words!.length,
          itemBuilder: (context, index) => _buildGeometricCard(index),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 64,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
            SizedBox(height: 16),
            Text(
              'No words yet',
              style: FlutterFlowTheme.of(context).headlineSmall.override(
                    fontFamily: 'Outfit',
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
            ),
            SizedBox(height: 8),
            Text(
              'Words you learn will appear here',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Readex Pro',
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeometricCard(int index) {
    final word = widget.words![index];
    final isSelected = selectedIndex == index;
    final config = configs[index];

    final wordText = _getWordText(word);
    final translation = _getTranslation(word);

    return GestureDetector(
      onTap: () {
        setState(() => selectedIndex = index);
        if (widget.onWordTap != null) {
          widget.onWordTap!(word);
        }
      },
      child: Transform(
        transform: config.transformMatrix,
        alignment: Alignment.center,
        child: AnimatedScale(
          scale: isSelected ? 1.05 : 1.0,
          duration: Duration(milliseconds: 200),
          child: Container(
            width: config.width,
            height: config.height,
            child: CustomPaint(
              painter: GeometricShapePainter(
                shapeType: config.shapeType,
                color: isSelected
                    ? FlutterFlowTheme.of(context).primary
                    : FlutterFlowTheme.of(context).secondaryBackground,
                borderColor: isSelected
                    ? FlutterFlowTheme.of(context).primary
                    : FlutterFlowTheme.of(context).alternate,
                isSelected: isSelected,
                shadowIntensity: config.shadowIntensity,
              ),
              child: Padding(
                padding: EdgeInsets.all(config.padding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      wordText.isNotEmpty ? wordText : '—',
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            fontFamily: 'Readex Pro',
                            color: isSelected
                                ? Colors.white
                                : FlutterFlowTheme.of(context).primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 1.5,
                      width: 35,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSelected
                              ? [Colors.white70, Colors.white30]
                              : [
                                  FlutterFlowTheme.of(context).secondaryText,
                                  FlutterFlowTheme.of(context)
                                      .secondaryText
                                      .withOpacity(0.3),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      translation.isNotEmpty ? translation : '—',
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            fontFamily: 'Readex Pro',
                            color: isSelected
                                ? Colors.white.withOpacity(0.85)
                                : FlutterFlowTheme.of(context).secondaryText,
                            fontSize: 13,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== КОНФИГУРАЦИЯ ГЕОМЕТРИИ ====================

class GeometricConfig {
  final ShapeType shapeType;
  final double width;
  final double height;
  final Matrix4 transformMatrix;
  final double padding;
  final double shadowIntensity;

  GeometricConfig({
    required this.shapeType,
    required this.width,
    required this.height,
    required this.transformMatrix,
    required this.padding,
    required this.shadowIntensity,
  });

  factory GeometricConfig.generate(int seed) {
    final random = math.Random(seed);
    final shapes = ShapeType.values;
    final selectedShape = shapes[seed % shapes.length];

    // Случайные размеры
    final width = 110.0 + random.nextDouble() * 35; // 110-145
    final height = 120.0 + random.nextDouble() * 40; // 120-160

    // Создаем Matrix4 для трансформаций
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001) // Perspective
      ..rotateZ((-0.12 + random.nextDouble() * 0.24)) // ±7° поворот
      ..scale(0.95 + random.nextDouble() * 0.1); // Небольшое масштабирование

    // Добавляем skew для некоторых фигур
    if (random.nextBool()) {
      final skewX = -0.1 + random.nextDouble() * 0.2;
      final skewY = -0.1 + random.nextDouble() * 0.2;
      matrix.setEntry(0, 1, skewX);
      matrix.setEntry(1, 0, skewY);
    }

    return GeometricConfig(
      shapeType: selectedShape,
      width: width,
      height: height,
      transformMatrix: matrix,
      padding: 14.0 + random.nextDouble() * 4,
      shadowIntensity: 0.7 + random.nextDouble() * 0.3,
    );
  }
}

// ==================== ТИПЫ ФОРМ ====================

enum ShapeType {
  trapezoid,
  invertedTrapezoid,
  diamond,
  parallelogramRight,
  parallelogramLeft,
  pentagon,
  hexagon,
  chevron,
  arrow,
  skewedRectangle,
  triangle,
  house,
}

// ==================== PAINTER ДЛЯ ГЕОМЕТРИЧЕСКИХ ФИГУР ====================

class GeometricShapePainter extends CustomPainter {
  final ShapeType shapeType;
  final Color color;
  final Color borderColor;
  final bool isSelected;
  final double shadowIntensity;

  GeometricShapePainter({
    required this.shapeType,
    required this.color,
    required this.borderColor,
    required this.isSelected,
    required this.shadowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _createPath(size);

    // Рисуем тень
    final shadowColor = isSelected
        ? borderColor.withOpacity(0.4 * shadowIntensity)
        : Colors.black.withOpacity(0.2 * shadowIntensity);
    final shadowBlur = isSelected ? 12.0 : 6.0;
    canvas.drawShadow(path, shadowColor, shadowBlur, true);

    // Градиент заливки
    final rect = path.getBounds();
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isSelected
          ? [color, color.withOpacity(0.85)]
          : [color, Color.lerp(color, Colors.black, 0.05)!],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Рисуем границу
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.5 : 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, borderPaint);

    // Добавляем внутреннее свечение для выбранной фигуры
    if (isSelected) {
      final innerGlowPaint = Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3);

      final innerPath = _createPath(Size(size.width - 6, size.height - 6));
      canvas.save();
      canvas.translate(3, 3);
      canvas.drawPath(innerPath, innerGlowPaint);
      canvas.restore();
    }
  }

  Path _createPath(Size size) {
    final w = size.width;
    final h = size.height;

    switch (shapeType) {
      case ShapeType.trapezoid:
        return Path()
          ..moveTo(w * 0.2, 0)
          ..lineTo(w * 0.8, 0)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();

      case ShapeType.invertedTrapezoid:
        return Path()
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..lineTo(w * 0.8, h)
          ..lineTo(w * 0.2, h)
          ..close();

      case ShapeType.diamond:
        return Path()
          ..moveTo(w * 0.5, 0)
          ..lineTo(w, h * 0.5)
          ..lineTo(w * 0.5, h)
          ..lineTo(0, h * 0.5)
          ..close();

      case ShapeType.parallelogramRight:
        return Path()
          ..moveTo(w * 0.25, 0)
          ..lineTo(w, 0)
          ..lineTo(w * 0.75, h)
          ..lineTo(0, h)
          ..close();

      case ShapeType.parallelogramLeft:
        return Path()
          ..moveTo(0, 0)
          ..lineTo(w * 0.75, 0)
          ..lineTo(w, h)
          ..lineTo(w * 0.25, h)
          ..close();

      case ShapeType.pentagon:
        return Path()
          ..moveTo(w * 0.5, 0)
          ..lineTo(w, h * 0.4)
          ..lineTo(w * 0.82, h)
          ..lineTo(w * 0.18, h)
          ..lineTo(0, h * 0.4)
          ..close();

      case ShapeType.hexagon:
        return Path()
          ..moveTo(w * 0.25, 0)
          ..lineTo(w * 0.75, 0)
          ..lineTo(w, h * 0.5)
          ..lineTo(w * 0.75, h)
          ..lineTo(w * 0.25, h)
          ..lineTo(0, h * 0.5)
          ..close();

      case ShapeType.chevron:
        return Path()
          ..moveTo(0, 0)
          ..lineTo(w * 0.7, 0)
          ..lineTo(w, h * 0.5)
          ..lineTo(w * 0.7, h)
          ..lineTo(0, h)
          ..lineTo(w * 0.3, h * 0.5)
          ..close();

      case ShapeType.arrow:
        return Path()
          ..moveTo(0, h * 0.3)
          ..lineTo(w * 0.7, h * 0.3)
          ..lineTo(w * 0.7, 0)
          ..lineTo(w, h * 0.5)
          ..lineTo(w * 0.7, h)
          ..lineTo(w * 0.7, h * 0.7)
          ..lineTo(0, h * 0.7)
          ..close();

      case ShapeType.skewedRectangle:
        return Path()
          ..moveTo(w * 0.15, 0)
          ..lineTo(w * 0.9, 0)
          ..lineTo(w * 0.85, h)
          ..lineTo(w * 0.1, h)
          ..close();

      case ShapeType.triangle:
        return Path()
          ..moveTo(w * 0.5, 0)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();

      case ShapeType.house:
        return Path()
          ..moveTo(w * 0.5, 0)
          ..lineTo(w, h * 0.35)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..lineTo(0, h * 0.35)
          ..close();
    }
  }

  @override
  bool shouldRepaint(GeometricShapePainter oldDelegate) =>
      oldDelegate.isSelected != isSelected ||
      oldDelegate.color != color ||
      oldDelegate.borderColor != borderColor;
}
