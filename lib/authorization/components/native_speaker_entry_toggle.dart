import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

class NativeSpeakerEntryToggle extends StatelessWidget {
  const NativeSpeakerEntryToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(26.0),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4.0, 4.0, 16.0, 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 52.0,
              height: 52.0,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(22.0),
                shape: BoxShape.rectangle,
              ),
              child: Align(
                alignment: AlignmentDirectional(0.0, 0.0),
                child: Icon(
                  FFIcons.kglobe01,
                  color: FlutterFlowTheme.of(context).primaryText,
                  size: 19.0,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  10.0,
                  0.0,
                  0.0,
                  0.0,
                ),
                child: Text(
                  'Войти как Native Speaker',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'sf pro display',
                        color: FlutterFlowTheme.of(context).primaryText,
                        fontSize: 16.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.normal,
                      ),
                ),
              ),
            ),
            AdaptiveSwitch(
              value: value,
              onChanged: onChanged,
              activeColor: FlutterFlowTheme.of(context).success,
            ),
          ],
        ),
      ),
    );
  }
}
