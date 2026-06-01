import '/components/button/button_widget.dart';
import '/components/wrapper.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'acquaintance_n_s_s_t_a_r_t_model.dart';
export 'acquaintance_n_s_s_t_a_r_t_model.dart';

class AcquaintanceNSSTARTWidget extends StatefulWidget {
  const AcquaintanceNSSTARTWidget({super.key});

  @override
  State<AcquaintanceNSSTARTWidget> createState() =>
      _AcquaintanceNSSTARTWidgetState();
}

class _AcquaintanceNSSTARTWidgetState extends State<AcquaintanceNSSTARTWidget> {
  late AcquaintanceNSSTARTModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AcquaintanceNSSTARTModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  void _openQuestionnaire() {
    final navigatorState = appNavigatorKey.currentState;
    final navigatorContext = appNavigatorKey.currentContext;
    navigatorState?.pop();

    if (navigatorContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!navigatorContext.mounted) {
          return;
        }
        navigatorContext.pushNamed(
          AcquaintanceNSWidget.routeName,
          queryParameters: {
            'index': serializeParam(
              0,
              ParamType.int,
            ),
            'entrySource': serializeParam(
              'profile',
              ParamType.String,
            ),
          }.withoutNulls,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional(0.0, 1.0),
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space0,
              ExpatlioDesign.space56,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ExpatlioDesign.background,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    BottomSheetHeader(
                      title: FFLocalizations.of(context).getText(
                        'zngmaqpc' /* Станьте носителем языка */,
                      ),
                      showConfirm: false,
                    ),
                    Stack(
                      alignment: AlignmentDirectional(1.15, -1.2),
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space8,
                              ExpatlioDesign.space20,
                              ExpatlioDesign.space8,
                              ExpatlioDesign.space0),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              borderRadius: BorderRadius.circular(
                                  ExpatlioDesign.radiusCapsule),
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
                                              FFLocalizations.of(context)
                                                  .getText(
                                                'fwacgl87' /* Помогайте другим практиковать ... */,
                                              ),
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
                                        decoration: BoxDecoration(
                                          shape: BoxShape.rectangle,
                                        ),
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
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  ExpatlioDesign.space0,
                                                  ExpatlioDesign.space0,
                                                  ExpatlioDesign.space8,
                                                  ExpatlioDesign.space0),
                                          child: Container(
                                            width: 20.0,
                                            height: 20.0,
                                            decoration: BoxDecoration(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Align(
                                              alignment: AlignmentDirectional(
                                                  0.0, 0.0),
                                              child: Icon(
                                                FFIcons.kcheck,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryBackground,
                                                size: 12.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          FFLocalizations.of(context).getText(
                                            'dkjkpn0t' /* Гибкий график */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space12,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  ExpatlioDesign.space0,
                                                  ExpatlioDesign.space0,
                                                  ExpatlioDesign.space8,
                                                  ExpatlioDesign.space0),
                                          child: Container(
                                            width: 20.0,
                                            height: 20.0,
                                            decoration: BoxDecoration(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Align(
                                              alignment: AlignmentDirectional(
                                                  0.0, 0.0),
                                              child: Icon(
                                                FFIcons.kcheck,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryBackground,
                                                size: 12.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          FFLocalizations.of(context).getText(
                                            'ieg9smx1' /* Общайтесь из любой точки мира */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space12,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  ExpatlioDesign.space0,
                                                  ExpatlioDesign.space0,
                                                  ExpatlioDesign.space8,
                                                  ExpatlioDesign.space0),
                                          child: Container(
                                            width: 20.0,
                                            height: 20.0,
                                            decoration: BoxDecoration(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Align(
                                              alignment: AlignmentDirectional(
                                                  0.0, 0.0),
                                              child: Icon(
                                                FFIcons.kcheck,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryBackground,
                                                size: 12.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          FFLocalizations.of(context).getText(
                                            'w2jb61uy' /* Получайте оплату за разговоры */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
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
                    wrapWithModel(
                      model: _model.buttonModel,
                      updateCallback: () => safeSetState(() {}),
                      child: Wrapper.keyboardAware(
                        child: ButtonWidget(
                          text: FFLocalizations.of(context).getText(
                            'fzpcok5b' /* Заполнить анкету */,
                          ),
                          action: () async {
                            _openQuestionnaire();
                          },
                        ),
                      ),
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
