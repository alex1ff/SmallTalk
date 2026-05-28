import 'dart:async';

import '/flutter_flow/flutter_flow_theme.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class BottomSheetHeader extends StatefulWidget {
  const BottomSheetHeader({
    super.key,
    required this.title,
    this.onClose,
    this.onConfirm,
    this.confirmEnabled = true,
    this.showConfirm,
  });

  final String title;
  final VoidCallback? onClose;
  final FutureOr<void> Function()? onConfirm;
  final bool confirmEnabled;
  final bool? showConfirm;

  @override
  State<BottomSheetHeader> createState() => _BottomSheetHeaderState();
}

class _BottomSheetHeaderState extends State<BottomSheetHeader> {
  static const double _buttonSize = 48.0;
  bool _busy = false;

  Future<void> _handleConfirm() async {
    if (_busy || !widget.confirmEnabled || widget.onConfirm == null) {
      return;
    }

    setState(() => _busy = true);
    await widget.onConfirm!();
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _handleClose() async {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    if (!mounted) {
      return;
    }

    final rootNavigator = Navigator.maybeOf(context, rootNavigator: true);
    if (rootNavigator != null && rootNavigator.canPop()) {
      await rootNavigator.maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showConfirm = widget.showConfirm ?? widget.onConfirm != null;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6.0, 24.0, 6.0, 16.0),
      child: Row(
        children: [
          _HeaderCircleButton(
            icon: Icons.close_rounded,
            fillColor: ExpatlioDesign.card,
            iconColor: FlutterFlowTheme.of(context).primaryText,
            onTap: () => unawaited(_handleClose()),
          ),
          Expanded(
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Cool',
                    fontSize: 24.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.normal,
                  ),
            ),
          ),
          if (showConfirm)
            _HeaderCircleButton(
              icon: Icons.check_rounded,
              fillColor: widget.confirmEnabled
                  ? ExpatlioDesign.primary
                  : const Color(0xFFD1D1D6),
              iconColor: Colors.white,
              onTap: widget.confirmEnabled ? _handleConfirm : null,
              busy: _busy,
            )
          else
            const SizedBox(width: _buttonSize, height: _buttonSize),
        ],
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.icon,
    required this.fillColor,
    required this.iconColor,
    this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final Color fillColor;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      customBorder: const CircleBorder(),
      onTap: busy ? null : onTap,
      child: Container(
        width: _BottomSheetHeaderState._buttonSize,
        height: _BottomSheetHeaderState._buttonSize,
        decoration: BoxDecoration(
          color: fillColor,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              blurRadius: 18.0,
              color: Color(0x102C2C2C),
              offset: Offset(0.0, 8.0),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: busy
            ? SizedBox(
                width: 18.0,
                height: 18.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              )
            : Icon(
                icon,
                color: iconColor,
                size: 28.0,
              ),
      ),
    );
  }
}
