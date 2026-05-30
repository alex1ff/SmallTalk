import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'button_model.dart';
export 'button_model.dart';

enum ButtonBusyStyle {
  spinner,
  debounceOnly,
}

class ButtonWidget extends StatefulWidget {
  const ButtonWidget({
    super.key,
    this.action,
    required this.text,
    this.loadingText,
    this.busyStyle = ButtonBusyStyle.debounceOnly,
    this.trailingContent,
    this.enabled = true,
  });

  final Future Function()? action;
  final String? text;
  final String? loadingText;
  final ButtonBusyStyle busyStyle;
  final Widget? trailingContent;
  final bool enabled;

  @override
  State<ButtonWidget> createState() => _ButtonWidgetState();
}

class _ButtonWidgetState extends State<ButtonWidget> {
  static const _spinnerKey = ValueKey<String>('button_widget_spinner');
  static const _animationDuration = Duration(milliseconds: 160);

  late ButtonModel _model;
  bool _isBusy = false;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (!widget.enabled || _isBusy || widget.action == null) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      await widget.action!.call();
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.enabled && widget.action != null;
    final showsSpinner = _isBusy && widget.busyStyle == ButtonBusyStyle.spinner;
    final displayedText = valueOrDefault<String>(
      showsSpinner ? widget.loadingText ?? widget.text : widget.text,
      '-',
    );
    final opacity = !widget.enabled
        ? 0.45
        : showsSpinner
            ? 0.75
            : _isBusy
                ? 0.9
                : 1.0;
    return AnimatedOpacity(
      duration: _animationDuration,
      opacity: opacity,
      child: InkWell(
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: isInteractive ? _handleTap : null,
        child: Container(
          height: ExpatlioDesign.buttonHeight,
          decoration: BoxDecoration(
            gradient: ExpatlioDesign.primaryGradient,
            borderRadius: BorderRadius.circular(ExpatlioDesign.buttonRadius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x227430E8),
                blurRadius: 18.0,
                offset: Offset(0.0, 8.0),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
            child: Row(
              mainAxisAlignment: widget.trailingContent != null && !showsSpinner
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
              children: [
                if (showsSpinner) ...[
                  SizedBox(
                    key: _spinnerKey,
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10.0),
                ],
                Flexible(
                  fit: widget.trailingContent != null && !showsSpinner
                      ? FlexFit.tight
                      : FlexFit.loose,
                  child: Text(
                    displayedText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: widget.trailingContent != null && !showsSpinner
                        ? TextAlign.start
                        : TextAlign.center,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'sf pro display',
                          color: Colors.white,
                          fontSize: 17.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (widget.trailingContent != null && !showsSpinner) ...[
                  const SizedBox(width: 12.0),
                  widget.trailingContent!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
