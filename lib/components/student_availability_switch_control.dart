import '/flutter_flow/flutter_flow_theme.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

class StudentAvailabilitySwitchControl extends StatelessWidget {
  const StudentAvailabilitySwitchControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          child: AdaptiveSwitch(
            value: value,
            onChanged: null,
            activeColor: FlutterFlowTheme.of(context).success,
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!value),
          ),
        ),
      ],
    );
  }
}
