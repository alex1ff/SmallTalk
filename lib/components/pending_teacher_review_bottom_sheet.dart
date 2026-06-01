import '/components/bottom_sheet_header.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class PendingTeacherReviewBottomSheet extends StatelessWidget {
  const PendingTeacherReviewBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: const AlignmentDirectional(0.0, 1.0),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space0,
              ExpatlioDesign.space56,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ExpatlioDesign.background,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BottomSheetHeader(
                      title: FFLocalizations.of(context).getVariableText(
                        ruText: 'Заявка на проверке',
                        enText: 'Request under review',
                      ),
                      onConfirm: () => Navigator.pop(context),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.space8,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space8,
                          ExpatlioDesign.space0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: ExpatlioDesign.card,
                          borderRadius: BorderRadius.circular(
                              ExpatlioDesign.radiusExtraLarge),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(ExpatlioDesign.space24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 132.0,
                                height: 132.0,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFF6B5E9),
                                      Color(0xFFEC5FC9),
                                    ],
                                    stops: [0.0, 1.0],
                                    begin: AlignmentDirectional(0.0, -1.0),
                                    end: AlignmentDirectional(0.0, 1.0),
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Align(
                                  alignment: AlignmentDirectional(0.0, 0.0),
                                  child: Icon(
                                    FFIcons.kclock,
                                    color: Colors.white,
                                    size: 54.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: ExpatlioDesign.space16),
                              Text(
                                FFLocalizations.of(context).getVariableText(
                                  ruText: 'Заявка ещё на проверке',
                                  enText: 'Request still under review',
                                ),
                                textAlign: TextAlign.center,
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'Cool',
                                      fontSize: 22.0,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                              const SizedBox(height: ExpatlioDesign.space12),
                              Text(
                                FFLocalizations.of(context).getVariableText(
                                  ruText:
                                      'Пока проверка не завершена, выйти онлайн и принимать звонки нельзя.',
                                  enText:
                                      'Until the review is complete, you cannot go online or accept calls.',
                                ),
                                textAlign: TextAlign.center,
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'sf pro display',
                                      fontSize: 16.0,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
