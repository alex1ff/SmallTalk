import 'dart:async';

import '/flutter_flow/flutter_flow_widgets.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class BottomSheetHeader extends StatefulWidget {
  const BottomSheetHeader({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<BottomSheetHeader> createState() => _BottomSheetHeaderState();
}

class _BottomSheetHeaderState extends State<BottomSheetHeader> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.pagePadding,
          ExpatlioDesign.space16,
          ExpatlioDesign.pagePadding,
          ExpatlioDesign.space0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const BottomSheetHandle(),
            const SizedBox(height: ExpatlioDesign.space16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.bottomSheetTitleStyle(context),
            ),
          ],
        ),
      ),
    );
  }
}

class BottomSheetHandle extends StatelessWidget {
  const BottomSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.0,
      height: 4.0,
      decoration: BoxDecoration(
        color: ExpatlioDesign.border,
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
      ),
    );
  }
}

class BottomSheetPrimaryButton extends StatefulWidget {
  const BottomSheetPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.enabled = true,
    this.busyText,
  });

  final String text;
  final FutureOr<void> Function()? onPressed;
  final bool enabled;
  final String? busyText;

  @override
  State<BottomSheetPrimaryButton> createState() =>
      _BottomSheetPrimaryButtonState();
}

class _BottomSheetPrimaryButtonState extends State<BottomSheetPrimaryButton> {
  bool _busy = false;

  Future<void> _handlePressed() async {
    if (_busy || !widget.enabled || widget.onPressed == null) {
      return;
    }

    setState(() => _busy = true);
    await widget.onPressed!();
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_busy && widget.onPressed != null;

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.pagePadding,
          ExpatlioDesign.space16,
          ExpatlioDesign.pagePadding,
          ExpatlioDesign.space24,
        ),
        child: FFButtonWidget(
          onPressed: enabled ? _handlePressed : null,
          text: _busy ? widget.busyText ?? widget.text : widget.text,
          options: FFButtonOptions(
            height: ExpatlioDesign.buttonHeight,
            width: double.infinity,
            color: ExpatlioDesign.primary,
            disabledColor: ExpatlioDesign.inactive.withValues(alpha: 0.30),
            textStyle: ExpatlioDesign.buttonTextStyle(context),
            elevation: 0,
            borderRadius: BorderRadius.circular(ExpatlioDesign.buttonRadius),
          ),
        ),
      ),
    );
  }
}
