import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'celebration_n_s_model.dart';
export 'celebration_n_s_model.dart';

class CelebrationNSWidget extends StatefulWidget {
  const CelebrationNSWidget({super.key});

  @override
  State<CelebrationNSWidget> createState() => _CelebrationNSWidgetState();
}

class _CelebrationNSWidgetState extends State<CelebrationNSWidget> {
  late CelebrationNSModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CelebrationNSModel());
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
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 55.0, 0.0, 0.0),
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
                        'r89oxs81' /* Юх-ху! */,
                      ),
                      onConfirm: () => Navigator.pop(context),
                    ),
                    Stack(
                      alignment: AlignmentDirectional(1.15, -1.2),
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              6.0, 20.0, 6.0, 0.0),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              borderRadius: BorderRadius.circular(38.0),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
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
                                                'lnkpv25r' /* Поздравляем 🎉  */,
                                              ),
                                              textAlign: TextAlign.start,
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily: 'Cool',
                                                        fontSize: 21.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                            ),
                                            AuthUserStreamWidget(
                                              builder: (context) => Text(
                                                '${currentUserDisplayName},',
                                                textAlign: TextAlign.start,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily: 'Cool',
                                                          fontSize: 21.0,
                                                          letterSpacing: 0.0,
                                                        ),
                                              ),
                                            ),
                                            Text(
                                              FFLocalizations.of(context)
                                                  .getVariableText(
                                                ruText:
                                                    'ваша заявка отправлена',
                                                enText:
                                                    'your application has been submitted',
                                              ),
                                              textAlign: TextAlign.start,
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily: 'Cool',
                                                        fontSize: 21.0,
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
                                    ].divide(SizedBox(width: 16.0)),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 24.0, 0.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: 'Что дальше:',
                                        enText: 'What happens next:',
                                      ),
                                      textAlign: TextAlign.start,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            fontSize: 21.0,
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 12.0, 0.0, 0.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 8.0, 0.0),
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
                                          FFLocalizations.of(context)
                                              .getVariableText(
                                            ruText: 'Мы проверяем вашу заявку',
                                            enText:
                                                'We’re reviewing your application',
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
                                        0.0, 12.0, 0.0, 0.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 8.0, 0.0),
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
                                          FFLocalizations.of(context)
                                              .getVariableText(
                                            ruText:
                                                'После одобрения вы сможете зарабатывать на разговорах',
                                            enText:
                                                'After approval, you’ll be able to earn from calls',
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
                                        0.0, 12.0, 0.0, 0.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 8.0, 0.0),
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
                                          FFLocalizations.of(context)
                                              .getVariableText(
                                            ruText:
                                                'После одобрения вы сможете получать отзывы и рейтинг',
                                            enText:
                                                'After approval, you’ll be able to receive reviews and ratings',
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
                                        0.0, 24.0, 0.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText:
                                            'Мы сообщим, когда проверка завершится и вы сможете выйти онлайн, принимать звонки, выводить деньги и зарабатывать в приложении.',
                                        enText:
                                            'We’ll notify you once the review is complete and you can go online, accept calls, withdraw earnings, and work in the app.',
                                      ),
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
                    const SizedBox(height: 35.0),
                  ].divide(SizedBox(height: 24.0)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 100.0),
          child: IgnorePointer(
            child: Lottie.asset(
              'assets/jsons/Confetti_Animation.json',
              width: MediaQuery.sizeOf(context).width * 1.0,
              height: MediaQuery.sizeOf(context).height * 1.0,
              fit: BoxFit.contain,
              repeat: false,
              animate: true,
            ),
          ),
        ),
      ],
    );
  }
}
