import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'word_pos_chip_model.dart';
export 'word_pos_chip_model.dart';

class WordPosChipWidget extends StatefulWidget {
  const WordPosChipWidget({
    super.key,
    String? text,
    required this.pos,
    required this.action,
    this.selectedPos,
  }) : this.text = text ?? '';

  final String text;
  final String? pos;
  final Future Function(String pos)? action;
  final String? selectedPos;

  @override
  State<WordPosChipWidget> createState() => _WordPosChipWidgetState();
}

class _WordPosChipWidgetState extends State<WordPosChipWidget> {
  late WordPosChipModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WordPosChipModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        await widget.action?.call(
          widget.pos!,
        );
      },
      child: Container(
        height: 100.0,
        decoration: BoxDecoration(
          color: valueOrDefault<Color>(
            widget.pos == widget.selectedPos
                ? FlutterFlowTheme.of(context).primary
                : ExpatlioDesign.card,
            FlutterFlowTheme.of(context).primary,
          ),
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
          shape: BoxShape.rectangle,
        ),
        child: Align(
          alignment: AlignmentDirectional(0.0, 0.0),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space16,
                ExpatlioDesign.space0,
                ExpatlioDesign.space16,
                ExpatlioDesign.space0),
            child: Text(
              widget.text,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'sf pro display',
                    color: valueOrDefault<Color>(
                      widget.pos == widget.selectedPos
                          ? ExpatlioDesign.card
                          : ExpatlioDesign.text,
                      ExpatlioDesign.card,
                    ),
                    fontSize: 16.0,
                    letterSpacing: 0.0,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
