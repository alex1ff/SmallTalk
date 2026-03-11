import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'pop_model.dart';
export 'pop_model.dart';

class PopWidget extends StatefulWidget {
  const PopWidget({
    super.key,
    required this.header,
    this.text,
    required this.isError,
  });

  final String? header;
  final String? text;
  final bool? isError;

  @override
  State<PopWidget> createState() => _PopWidgetState();
}

class _PopWidgetState extends State<PopWidget> {
  late PopModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PopModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header?.trim() ?? '';
    final text = widget.text?.trim() ?? '';
    final hasHeader = header.isNotEmpty;
    final hasText = text.isNotEmpty;
    final primaryText = hasHeader ? header : text;
    final secondaryText = hasHeader && hasText ? text : null;
    final cardBorderRadius = BorderRadius.circular(24.0);

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: 60.0),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).primaryBackground,
          boxShadow: [
            BoxShadow(
              blurRadius: 24.0,
              color: Color(0x15000000),
              offset: Offset(
                0.0,
                20.0,
              ),
              spreadRadius: 0.0,
            )
          ],
          borderRadius: cardBorderRadius,
          border: Border.all(
            color: FlutterFlowTheme.of(context).secondaryBackground,
          ),
        ),
        child: ClipRRect(
          borderRadius: cardBorderRadius,
          child: Padding(
            padding: EdgeInsets.all(4.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  width: 52.0,
                  height: 52.0,
                  decoration: BoxDecoration(
                    color: Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                  child: Builder(
                    builder: (context) {
                      if (widget.isError ?? false) {
                        return Icon(
                          FFIcons.kalertHexagon,
                          color: FlutterFlowTheme.of(context).error,
                          size: 24.0,
                        );
                      } else {
                        return Align(
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Container(
                            width: 25.0,
                            height: 25.0,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).success,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              FFIcons.kcheck,
                              color: FlutterFlowTheme.of(context).primaryText,
                              size: 14.0,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(12.0, 9.0, 12.0, 9.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (primaryText.isNotEmpty)
                          Text(
                            primaryText,
                            maxLines: secondaryText != null ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Cool',
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  fontSize: 16.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                ),
                          ),
                        if (secondaryText != null)
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 3.0, 0.0, 0.0),
                            child: Text(
                              secondaryText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    fontSize: 13.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
