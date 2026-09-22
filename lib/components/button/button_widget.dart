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
    this.busy = false,
  });

  final Future Function()? action;
  final String? text;
  final String? loadingText;
  final ButtonBusyStyle busyStyle;
  final Widget? trailingContent;
  final bool enabled;
  final bool busy;

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
    if (!widget.enabled || widget.busy || _isBusy || widget.action == null) {
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
    final isBusy = widget.busy || _isBusy;
    final isInteractive = widget.enabled && !isBusy && widget.action != null;
    final showsSpinner = isBusy && widget.busyStyle == ButtonBusyStyle.spinner;
    final displayedText = valueOrDefault<String>(
      showsSpinner ? widget.loadingText ?? widget.text : widget.text,
      '-',
    );
    final opacity = showsSpinner
        ? 0.75
        : isBusy
            ? 0.9
            : 1.0;
    final backgroundColor = widget.enabled
        ? ExpatlioDesign.primary
        : ExpatlioDesign.inactive.withValues(alpha: 0.30);
    return Semantics(
      container: true,
      button: true,
      enabled: isInteractive,
      label: displayedText,
      liveRegion: isBusy,
      onTap: isInteractive ? _handleTap : null,
      child: ExcludeSemantics(
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
              height: ExpatlioDesign.buttonHeight,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius:
                    BorderRadius.circular(ExpatlioDesign.buttonRadius),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.space20,
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space20,
                    ExpatlioDesign.space0),
                child: Row(
                  mainAxisAlignment:
                      widget.trailingContent != null && !showsSpinner
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
                      const SizedBox(width: ExpatlioDesign.space12),
                    ],
                    Flexible(
                      fit: widget.trailingContent != null && !showsSpinner
                          ? FlexFit.tight
                          : FlexFit.loose,
                      child: Text(
                        displayedText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                            widget.trailingContent != null && !showsSpinner
                                ? TextAlign.start
                                : TextAlign.center,
                        style: ExpatlioDesign.buttonTextStyle(context),
                      ),
                    ),
                    if (widget.trailingContent != null && !showsSpinner) ...[
                      const SizedBox(width: ExpatlioDesign.space12),
                      widget.trailingContent!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
