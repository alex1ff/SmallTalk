import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class PendingTeacherReviewCard extends StatelessWidget {
  const PendingTeacherReviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(ExpatlioDesign.space0,
          ExpatlioDesign.space8, ExpatlioDesign.space0, ExpatlioDesign.space0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: ExpatlioDesign.card,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ExpatlioDesign.space16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48.0,
                height: 48.0,
                decoration: BoxDecoration(
                  color: ExpatlioDesign.background,
                  borderRadius:
                      BorderRadius.circular(ExpatlioDesign.radiusLarge),
                ),
                child: Icon(
                  Icons.pending_outlined,
                  color: FlutterFlowTheme.of(context).primaryText,
                  size: 22.0,
                ),
              ),
              const SizedBox(width: ExpatlioDesign.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      FFLocalizations.of(context).getVariableText(
                        ruText: 'Заявка на проверке',
                        enText: 'Request under review',
                      ),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Cool',
                            fontSize: 22.0,
                            letterSpacing: 0.0,
                          ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space8),
                    Text(
                      FFLocalizations.of(context).getVariableText(
                        ruText:
                            'Мы проверяем вашу заявку. Принимать звонки и выходить онлайн пока нельзя.',
                        enText:
                            'We are reviewing your request. You cannot accept calls or go online yet.',
                      ),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'sf pro display',
                            color: FlutterFlowTheme.of(context).secondaryText,
                            fontSize: 15.0,
                            letterSpacing: 0.0,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
