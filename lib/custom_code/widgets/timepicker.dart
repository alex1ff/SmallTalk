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

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class Timepicker extends StatefulWidget {
  const Timepicker({
    super.key,
    this.width,
    this.height,
    required this.action,
    this.timestart,
  });

  final double? width;
  final double? height;
  final Future Function(String currentTime) action;
  final String? timestart;

  @override
  State<Timepicker> createState() => _TimepickerState();
}

class _TimepickerState extends State<Timepicker> {
  final double itemExtent = 40.0;
  final double selectionAreaHeight = 31.0;
  final double wheelWidth = 80.0;

  late int selectedHour;
  late int selectedMinute;

  @override
  void initState() {
    super.initState();
    if (widget.timestart != null && widget.timestart!.contains(':')) {
      final parts = widget.timestart!.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          selectedHour = hour;
          selectedMinute = minute;
          return;
        }
      }
    }
    final now = DateTime.now();
    selectedHour = now.hour;
    selectedMinute = now.minute;
  }

  List<String> get hours => List.generate(24, (index) => index.toString());
  List<String> get minutes => List.generate(60, (index) => index.toString());

  Future<void> _onTimeChanged() async {
    final formattedTime =
        '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}';
    await widget.action(formattedTime);
  }

  @override
  Widget build(BuildContext context) {
    final double containerHeight = widget.height ?? 200.0;
    final double topLinePosition =
        containerHeight / 2 - selectionAreaHeight / 2;
    final double bottomLinePosition =
        containerHeight / 2 + selectionAreaHeight / 2;
    final double lineThickness = 1 / MediaQuery.of(context).devicePixelRatio;

    return Container(
      width: widget.width,
      height: containerHeight,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: wheelWidth,
                  child: CupertinoPicker(
                    scrollController:
                        FixedExtentScrollController(initialItem: selectedHour),
                    itemExtent: itemExtent,
                    looping: true,
                    selectionOverlay: Container(),
                    onSelectedItemChanged: (index) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        selectedHour = index;
                      });
                      _onTimeChanged();
                    },
                    children: hours
                        .map((hour) => Container(
                              height: itemExtent,
                              alignment: Alignment.center,
                              child: Text(
                                hour,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(width: 0),
                Container(
                  width: wheelWidth,
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                        initialItem: selectedMinute),
                    itemExtent: itemExtent,
                    looping: true,
                    selectionOverlay: Container(),
                    onSelectedItemChanged: (index) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        selectedMinute = index;
                      });
                      _onTimeChanged();
                    },
                    children: minutes
                        .map((minute) => Container(
                              height: itemExtent,
                              alignment: Alignment.center,
                              child: Text(
                                minute,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: topLinePosition,
            left: 0,
            right: 0,
            child: Container(
              height: lineThickness,
              color: const Color(0xFFCCCCCC),
            ),
          ),
          Positioned(
            top: bottomLinePosition,
            left: 0,
            right: 0,
            child: Container(
              height: lineThickness,
              color: const Color(0xFFCCCCCC),
            ),
          ),
        ],
      ),
    );
  }
}
