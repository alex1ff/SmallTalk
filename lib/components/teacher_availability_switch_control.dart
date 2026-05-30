import '/flutter_flow/flutter_flow_theme.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

class AvailabilitySwitchControl extends StatelessWidget {
  const AvailabilitySwitchControl({
    super.key,
    required this.value,
    required this.isPendingTeacherReview,
    required this.onChanged,
    this.onPendingTap,
  });

  final bool value;
  final bool isPendingTeacherReview;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onPendingTap;

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
            onTap: () {
              if (isPendingTeacherReview) {
                onPendingTap?.call();
                return;
              }

              onChanged(!value);
            },
          ),
        ),
      ],
    );
  }
}
