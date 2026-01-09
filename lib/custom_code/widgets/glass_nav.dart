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

import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class GlassNav extends StatefulWidget {
  const GlassNav({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 16,
    this.glassColor = const Color.fromARGB(156, 209, 209, 209),
  });

  final double? width;
  final double? height;
  final int borderRadius;
  final Color glassColor;

  @override
  State<GlassNav> createState() => _GlassNavState();
}

class _GlassNavState extends State<GlassNav> {
  @override
  Widget build(BuildContext context) {
    return LiquidGlassLayer(
      settings: LiquidGlassSettings(
        thickness: 30.0,
        glassColor: widget.glassColor,
        lightIntensity: 2.0,
        saturation: 0.8,
        blur: 2.0,
        chromaticAberration: 0.1,
      ),
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(
          borderRadius: widget.borderRadius.toDouble(),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: widget.width ?? 300,
          height: widget.height ?? 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(widget.borderRadius.toDouble()),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 40,
                      offset: Offset(0, 30),
                      spreadRadius: -15,
                    ),
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(widget.borderRadius.toDouble()),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.55),
                      width: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
