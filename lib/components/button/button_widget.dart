import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
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
    this.keyboardAwarePadding = true,
    this.enabled = true,
    this.padding,
  });

  final Future Function()? action;
  final String? text;
  final String? loadingText;
  final ButtonBusyStyle busyStyle;
  final Widget? trailingContent;
  final bool keyboardAwarePadding;
  final bool enabled;
  final EdgeInsetsGeometry? padding;

  @override
  State<ButtonWidget> createState() => _ButtonWidgetState();
}

class _ButtonWidgetState extends State<ButtonWidget> {
  static const _circleKey = ValueKey<String>('button_widget_circle');
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
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    final resolvedPadding = widget.padding ??
        EdgeInsetsDirectional.fromSTEB(
          6.0,
          0.0,
          6.0,
          widget.keyboardAwarePadding
              ? valueOrDefault<double>(
                  isKeyboardVisible ? 6.0 : 35.0,
                  6.0,
                )
              : 0.0,
        );

    return AnimatedPadding(
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      padding: resolvedPadding,
      child: AnimatedOpacity(
        duration: _animationDuration,
        opacity: opacity,
        child: InkWell(
          splashColor: Colors.transparent,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: isInteractive ? _handleTap : null,
          child: Container(
            height: 60.0,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primaryText,
              borderRadius: BorderRadius.circular(50.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          16.0, 0.0, 0.0, 0.0),
                      child: Text(
                        displayedText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Cool',
                              color: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              fontSize: 20.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
                            ),
                      ),
                    ),
                  ),
                  if (widget.trailingContent != null && !showsSpinner) ...[
                    widget.trailingContent!,
                    const SizedBox(width: 12.0),
                  ],
                  Container(
                    key: _circleKey,
                    width: 56.0,
                    height: 56.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Align(
                      alignment: const AlignmentDirectional(0.0, 0.0),
                      child: showsSpinner
                          ? SizedBox(
                              key: _spinnerKey,
                              width: 20.0,
                              height: 20.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  FlutterFlowTheme.of(context).primaryText,
                                ),
                              ),
                            )
                          : const Icon(
                              FFIcons.karrowRight,
                              color: Colors.black,
                              size: 20.0,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
