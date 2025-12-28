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

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!

import 'package:visibility_detector/visibility_detector.dart';

class ReadMessage extends StatefulWidget {
  const ReadMessage({
    super.key,
    this.width,
    this.height,
    this.action,
    required this.messageId,
  });

  final double? width;
  final double? height;
  final Future Function()? action;
  final String messageId;

  @override
  State<ReadMessage> createState() => _ReadMessageState();
}

class _ReadMessageState extends State<ReadMessage> {
  bool _actionExecuted = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('visibility_detector_${widget.messageId}'),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction > 0 && !_actionExecuted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _executeAction();
            }
          });
        }
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        // Здесь вы можете добавить дополнительное
      ),
    );
  }

  void _executeAction() {
    if (widget.action != null && !_actionExecuted) {
      widget.action!();
      setState(() {
        _actionExecuted = true;
      });
    }
  }
}
