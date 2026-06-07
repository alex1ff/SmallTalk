import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'celebration_top_up_model.dart';
export 'celebration_top_up_model.dart';

class CelebrationTopUpWidget extends StatefulWidget {
  const CelebrationTopUpWidget({super.key});

  @override
  State<CelebrationTopUpWidget> createState() => _CelebrationTopUpWidgetState();
}

class _CelebrationTopUpWidgetState extends State<CelebrationTopUpWidget> {
  late CelebrationTopUpModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CelebrationTopUpModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  Widget _buildBullet(BuildContext context, String text) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space0,
              ExpatlioDesign.space4,
              ExpatlioDesign.space8,
              ExpatlioDesign.space0),
          child: Container(
            width: 20.0,
            height: 20.0,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primary,
              shape: BoxShape.circle,
            ),
            child: Align(
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Icon(
                FFIcons.kcheck,
                color: ExpatlioDesign.card,
                size: 12.0,
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  fontSize: 15.0,
                  letterSpacing: 0.0,
                ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional(0.0, 1.0),
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space0,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                decoration: ExpatlioDesign.sheetDecoration(
                    color: ExpatlioDesign.background),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BottomSheetHeader(
                      title: 'Юх-ху!',
                    ),
                    Stack(
                      alignment: AlignmentDirectional(1.15, -1.2),
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.pagePadding,
                              ExpatlioDesign.space20,
                              ExpatlioDesign.pagePadding,
                              ExpatlioDesign.space0),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              borderRadius: BorderRadius.circular(
                                  ExpatlioDesign.cardRadius),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(ExpatlioDesign.space24),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Flexible(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Баланс пополнен',
                                              textAlign: TextAlign.start,
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily: 'Cool',
                                                        fontSize: 22.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                            ),
                                            AuthUserStreamWidget(
                                              builder: (context) {
                                                final displayName =
                                                    currentUserDisplayName
                                                        .trim();
                                                if (displayName.isEmpty) {
                                                  return SizedBox.shrink();
                                                }

                                                return Text(
                                                  '$displayName,',
                                                  textAlign: TextAlign.start,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily: 'Cool',
                                                        fontSize: 22.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                );
                                              },
                                            ),
                                            Text(
                                              'можете начинать общение в Expatlio',
                                              textAlign: TextAlign.start,
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily: 'Cool',
                                                        fontSize: 22.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 96.9,
                                        height: 63.8,
                                        decoration: BoxDecoration(),
                                      ),
                                    ].divide(SizedBox(
                                        width: ExpatlioDesign.space16)),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space24,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0),
                                    child: Text(
                                      'Что дальше?',
                                      textAlign: TextAlign.start,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            fontSize: 22.0,
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space12,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0),
                                    child: _buildBullet(
                                      context,
                                      'Минуты в Expatlio уже доступны на балансе',
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space12,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0),
                                    child: _buildBullet(
                                      context,
                                      'Выберите преподавателя и начните разговор',
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space12,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0),
                                    child: _buildBullet(
                                      context,
                                      'История пополнения уже сохранена в Финансах',
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space24,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0),
                                    child: Text(
                                      'Все готово для нового разговора. Открывайте подбор и начинайте практику.',
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            fontSize: 15.0,
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 150.0,
                          height: 150.0,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFF6B5E9), Color(0xFFEC5FC9)],
                              stops: [0.0, 1.0],
                              begin: AlignmentDirectional(0.0, -1.0),
                              end: AlignmentDirectional(0, 1.0),
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional(0.0, 0.0),
                            child: Image.asset(
                              'assets/images/sticker_32.png',
                              width: 115.0,
                              height: 120.0,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                    BottomSheetPrimaryButton(
                      text: FFLocalizations.of(context).getVariableText(
                        ruText: 'Готово',
                        enText: 'Done',
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ].divide(SizedBox(height: ExpatlioDesign.space24)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
