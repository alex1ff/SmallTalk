import '/auth/firebase_auth/auth_util.dart';
import '/components/bottom_sheet_header.dart';
import '/components/button/button_widget.dart';
import '/components/wrapper.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/services/voip_service.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'logout_model.dart';
export 'logout_model.dart';

class LogoutWidget extends StatefulWidget {
  const LogoutWidget({super.key});

  @override
  State<LogoutWidget> createState() => _LogoutWidgetState();
}

class _LogoutWidgetState extends State<LogoutWidget> {
  late LogoutModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LogoutModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
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
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: ExpatlioDesign.sheetDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        ExpatlioDesign.space24,
                        ExpatlioDesign.space16,
                        ExpatlioDesign.space24,
                        ExpatlioDesign.space0,
                      ),
                      child: BottomSheetHandle(),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.pagePadding,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.pagePadding,
                          ExpatlioDesign.space0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: ExpatlioDesign.card,
                          borderRadius: BorderRadius.circular(
                              ExpatlioDesign.radiusExtraLarge),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(ExpatlioDesign.space24),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 150.0,
                                height: 150.0,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      FlutterFlowTheme.of(context).error,
                                      ExpatlioDesign.warning
                                    ],
                                    stops: [0.0, 1.0],
                                    begin: AlignmentDirectional(0.0, -1.0),
                                    end: AlignmentDirectional(0, 1.0),
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional(0.0, 0.0),
                                  child: Image.asset(
                                    'assets/images/sticker_50.png',
                                    width: 150.0,
                                    height: 135.0,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    ExpatlioDesign.space0,
                                    ExpatlioDesign.space16,
                                    ExpatlioDesign.space0,
                                    ExpatlioDesign.space0),
                                child: Text(
                                  FFLocalizations.of(context).getText(
                                    'zd4lq385' /* Вы уверены, что хотите выйти */,
                                  ),
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
                                child: Text(
                                  FFLocalizations.of(context).getText(
                                    'j9kmlyfd' /* Это действие нельзя отменить, ... */,
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
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space24,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space0),
                      child: FFButtonWidget(
                        onPressed: () async {
                          GoRouter.of(context).prepareAuthEvent();
                          await VoIPService().deinitialize();
                          await authManager.signOut();
                          GoRouter.of(context).clearRedirectLocation();

                          context.goNamedAuth(
                              OnboardingWidget.routeName, context.mounted);
                        },
                        text: FFLocalizations.of(context).getText(
                          '8iuccsuc' /* Выйти */,
                        ),
                        icon: Icon(
                          FFIcons.kchevronRight,
                          size: 15.0,
                        ),
                        options: FFButtonOptions(
                          height: ExpatlioDesign.buttonHeight,
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space16,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space16,
                              ExpatlioDesign.space0),
                          iconAlignment: IconAlignment.end,
                          iconPadding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0),
                          color: Colors.transparent,
                          textStyle:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context).error,
                                    fontSize: 15.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                          elevation: 0.0,
                          borderRadius:
                              BorderRadius.circular(ExpatlioDesign.radiusSmall),
                        ),
                        showLoadingIndicator: false,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space12,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space0),
                      child: wrapWithModel(
                        model: _model.buttonModel,
                        updateCallback: () => safeSetState(() {}),
                        child: Wrapper.keyboardAware(
                          child: ButtonWidget(
                            text: FFLocalizations.of(context).getText(
                              'op5siu4w' /* Отменить */,
                            ),
                            action: () async {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ),
                    ),
                  ].divide(SizedBox(height: ExpatlioDesign.space4)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
