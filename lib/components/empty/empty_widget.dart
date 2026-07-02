import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'empty_model.dart';
export 'empty_model.dart';

class EmptyWidget extends StatefulWidget {
  const EmptyWidget({
    super.key,
    required this.txt,
    this.shrinkWrap = false,
    this.topPadding = ExpatlioDesign.space64,
  });

  final String? txt;
  final bool shrinkWrap;
  final double topPadding;

  @override
  State<EmptyWidget> createState() => _EmptyWidgetState();
}

class _EmptyWidgetState extends State<EmptyWidget> {
  late EmptyModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EmptyModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(ExpatlioDesign.space24,
            widget.topPadding, ExpatlioDesign.space24, ExpatlioDesign.space0),
        child: Column(
          mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
          children: [
            SizedBox(
              width: 104.0,
              height: 104.0,
              child: Image.asset(
                'assets/images/Group_1171275321.png',
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space16,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0),
              child: Text(
                FFLocalizations.of(context).getVariableText(
                  ruText: 'Здесь пока пусто',
                  enText: 'Nothing here yet',
                ),
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: ExpatlioDesign.text,
                      fontSize: 17.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space8,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0),
              child: Text(
                valueOrDefault<String>(
                  widget.txt,
                  '-',
                ),
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: ExpatlioDesign.muted,
                      fontSize: 15.0,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
