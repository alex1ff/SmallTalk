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

class NotchedClipper extends StatelessWidget {
  const NotchedClipper({
    super.key,
    this.width,
    this.height,
  });
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        ClipPath(
          clipper: _SheetClipper(),
          child: Container(
            width: width,
            height: height,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F7),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
          ),
        ),

        // 🔥 ПАЛОЧКА — теперь поверх и в цвет контейнера
        Positioned(
          top: 3,
          child: Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        )
      ],
    );
  }
}

class _SheetClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const notchWidth = 65.0;
    const notchHeight = 13.0;
    const radius = 12.0;

    final path = Path();
    final start = (size.width - notchWidth) / 2;
    final end = start + notchWidth;

    // Левый верхний угол
    path.moveTo(0, 20);
    path.quadraticBezierTo(0, 0, 20, 0);

    // До выемки
    path.lineTo(start, 0);

    // Выемка
    path.lineTo(start, notchHeight - radius); // вниз
    path.quadraticBezierTo(start, notchHeight, start + radius, notchHeight);
    path.lineTo(end - radius, notchHeight);
    path.quadraticBezierTo(end, notchHeight, end, notchHeight - radius);
    path.lineTo(end, 0);

    // Правый верхний угол
    path.lineTo(size.width - 20, 0);
    path.quadraticBezierTo(size.width, 0, size.width, 20);

    // Низ
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(_) => false;
}
