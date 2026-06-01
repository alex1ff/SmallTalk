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
      padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space8,
          ExpatlioDesign.space24,
          ExpatlioDesign.space8,
          ExpatlioDesign.space16),
      child: Row(
        children: [
          _HeaderCircleButton(
            role: _HeaderCircleButtonRole.close,
            onTap: () => unawaited(_handleClose()),
          ),
          Expanded(
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.bottomSheetTitleStyle(context),
            ),
          ),
          if (showConfirm)
            _HeaderCircleButton(
              role: widget.confirmEnabled
                  ? _HeaderCircleButtonRole.confirm
                  : _HeaderCircleButtonRole.confirmDisabled,
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

enum _HeaderCircleButtonRole {
  close,
  confirm,
  confirmDisabled,
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.role,
    this.onTap,
    this.busy = false,
  });

  final _HeaderCircleButtonRole role;
  final VoidCallback? onTap;
  final bool busy;

  IconData get _icon {
    return switch (role) {
      _HeaderCircleButtonRole.close => Icons.close_rounded,
      _HeaderCircleButtonRole.confirm ||
      _HeaderCircleButtonRole.confirmDisabled =>
        Icons.check_rounded,
    };
  }

  Color _background(BuildContext context) {
    return switch (role) {
      _HeaderCircleButtonRole.close => ExpatlioDesign.card,
      _HeaderCircleButtonRole.confirm => ExpatlioDesign.primary,
      _HeaderCircleButtonRole.confirmDisabled => const Color(0xFFD1D1D6),
    };
  }

  Color _foreground(BuildContext context) {
    return switch (role) {
      _HeaderCircleButtonRole.close => FlutterFlowTheme.of(context).primaryText,
      _HeaderCircleButtonRole.confirm ||
      _HeaderCircleButtonRole.confirmDisabled =>
        Colors.white,
    };
  }

  @override
  Widget build(BuildContext context) {
    final foreground = _foreground(context);

    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      customBorder: const CircleBorder(),
      onTap: busy ? null : onTap,
      child: Container(
        width: _BottomSheetHeaderState._buttonSize,
        height: _BottomSheetHeaderState._buttonSize,
        decoration: BoxDecoration(
          color: _background(context),
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
                  valueColor: AlwaysStoppedAnimation<Color>(foreground),
                ),
              )
            : Icon(
                _icon,
                color: foreground,
                size: 28.0,
              ),
      ),
    );
  }
}
