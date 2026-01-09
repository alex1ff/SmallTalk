import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/custom_cloud_functions/custom_cloud_function_response_manager.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/instant_timer.dart';
import 'dart:async';
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'waiting_for_teacher_page_model.dart';
export 'waiting_for_teacher_page_model.dart';

class WaitingForTeacherPageWidget extends StatefulWidget {
  const WaitingForTeacherPageWidget({super.key});

  static String routeName = 'WaitingForTeacherPage';
  static String routePath = '/waitingForTeacherPage';

  @override
  State<WaitingForTeacherPageWidget> createState() =>
      _WaitingForTeacherPageWidgetState();
}

class _WaitingForTeacherPageWidgetState
    extends State<WaitingForTeacherPageWidget> {
  late WaitingForTeacherPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WaitingForTeacherPageModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('createVideoSession')
            .call({
          "language": currentUserDocument!.learningLanguage.code,
          "preferredNativeLanguage":
              currentUserDocument!.preferences.preferredNativeLanguage.code,
          "preferredCountry":
              currentUserDocument!.preferences.preferredLocation.code,
        });
        _model.newSession = CreateVideoSessionCloudFunctionCallResponse(
          data: CallRequestResponseStruct.fromMap(result.data),
          succeeded: true,
          resultAsString: result.data.toString(),
          jsonBody: result.data,
        );
      } on FirebaseFunctionsException catch (error) {
        _model.newSession = CreateVideoSessionCloudFunctionCallResponse(
          errorCode: error.code,
          succeeded: false,
        );
      }

      _model.instantTimer = InstantTimer.periodic(
        duration: Duration(milliseconds: 3000),
        callback: (timer) async {
          _model.videosession = await VideoSessionsRecord.getDocumentOnce(
              functions.videoSessionsToRef(_model.newSession!.data!.sessionId));
          if (_model.videosession?.status == CallStatus.active.name) {
            _model.instantTimer?.cancel();

            context.goNamed(
              VideoCallPageStudentWidget.routeName,
              queryParameters: {
                'videoDocRef': serializeParam(
                  _model.videosession?.reference,
                  ParamType.DocumentReference,
                ),
              }.withoutNulls,
            );

            return;
          }
        },
        startImmediately: false,
      );
    });
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 35.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 12.0),
                child: FFButtonWidget(
                  onPressed: () async {
                    unawaited(
                      () async {
                        try {
                          final result = await FirebaseFunctions.instance
                              .httpsCallable('cancelCall')
                              .call({
                            "sessionId": _model.newSession!.data!.sessionId,
                          });
                          _model.cloudFunction5c0 =
                              CancelCallCloudFunctionCallResponse(
                            data: CancelCallResponseStruct.fromMap(result.data),
                            succeeded: true,
                            resultAsString: result.data.toString(),
                            jsonBody: result.data,
                          );
                        } on FirebaseFunctionsException catch (error) {
                          _model.cloudFunction5c0 =
                              CancelCallCloudFunctionCallResponse(
                            errorCode: error.code,
                            succeeded: false,
                          );
                        }
                      }(),
                    );
                    context.safePop();

                    safeSetState(() {});
                  },
                  text: FFLocalizations.of(context).getText(
                    'o2wt8jr9' /* Отменить */,
                  ),
                  icon: Icon(
                    FFIcons.kchevronRight,
                    size: 15.0,
                  ),
                  options: FFButtonOptions(
                    height: 40.0,
                    padding:
                        EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                    iconAlignment: IconAlignment.end,
                    iconPadding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                    color: Colors.transparent,
                    textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                          fontFamily: 'sf pro display',
                          color: FlutterFlowTheme.of(context).error,
                          fontSize: 15.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w500,
                        ),
                    elevation: 0.0,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  showLoadingIndicator: false,
                ),
              ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        () {
                          if (_model.newSession?.data?.status ==
                              CallStatus.searching) {
                            return FFLocalizations.of(context).getVariableText(
                              ruText: 'Дозваниваемся',
                              enText: 'Connecting…',
                            );
                          } else if (_model.newSession?.data?.status ==
                              CallStatus.connecting) {
                            return FFLocalizations.of(context).getVariableText(
                              ruText: 'Никого не нашли',
                              enText: 'No one was found',
                            );
                          } else {
                            return FFLocalizations.of(context).getVariableText(
                              ruText: 'Small Talk начинается',
                              enText: 'Small Talk begins',
                            );
                          }
                        }(),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Cool',
                              color: FlutterFlowTheme.of(context).primaryText,
                              fontSize: 21.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
                            ),
                      ),
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
                        child: Text(
                          () {
                            if (_model.newSession?.data?.status ==
                                CallStatus.searching) {
                              return FFLocalizations.of(context)
                                  .getVariableText(
                                ruText: 'Ждём, пока собеседник примет звонок',
                                enText:
                                    'We are waiting for the interlocutor to accept the call.',
                              );
                            } else if (_model.newSession?.data?.status ==
                                CallStatus.connecting) {
                              return FFLocalizations.of(context)
                                  .getVariableText(
                                ruText:
                                    'Все собеседники сейчас заняты. Попробуйте позже',
                                enText:
                                    'All the interlocutors are busy right now. Try again later',
                              );
                            } else {
                              return FFLocalizations.of(context)
                                  .getVariableText(
                                ruText: 'Ищем идеального собеседника',
                                enText: 'Looking for the perfect companion',
                              );
                            }
                          }(),
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: 'sf pro display',
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 16.0,
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
    );
  }
}
