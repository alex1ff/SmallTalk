import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/custom_cloud_functions/custom_cloud_function_response_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/students_pages/components/new_word/new_word_widget.dart';
import 'dart:async';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'video_call_page_student_model.dart';
export 'video_call_page_student_model.dart';

class VideoCallPageStudentWidget extends StatefulWidget {
  const VideoCallPageStudentWidget({
    super.key,
    required this.videoDocRef,
  });

  final DocumentReference? videoDocRef;

  static String routeName = 'VideoCallPageStudent';
  static String routePath = '/videoCallPageStudent';

  @override
  State<VideoCallPageStudentWidget> createState() =>
      _VideoCallPageStudentWidgetState();
}

class _VideoCallPageStudentWidgetState
    extends State<VideoCallPageStudentWidget> {
  late VideoCallPageStudentModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => VideoCallPageStudentModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VideoSessionsRecord>(
      stream: VideoSessionsRecord.getDocument(widget.videoDocRef!),
      builder: (context, snapshot) {
        // Customize what your widget looks like when it's loading.
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
            body: Center(
              child: SizedBox(
                width: 50.0,
                height: 50.0,
                child: SpinKitCircle(
                  color: FlutterFlowTheme.of(context).secondary,
                  size: 50.0,
                ),
              ),
            ),
          );
        }

        final videoCallPageStudentVideoSessionsRecord = snapshot.data!;

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
            body: AuthUserStreamWidget(
              builder: (context) => Container(
                width: double.infinity,
                height: double.infinity,
                child: custom_widgets.MinimalDailyWidget(
                  width: double.infinity,
                  height: double.infinity,
                  roomUrl: videoCallPageStudentVideoSessionsRecord.dailyRoomUrl,
                  meetingToken:
                      videoCallPageStudentVideoSessionsRecord.meetingToken,
                  deepgramApiKey: 'REDACTED_DEEPGRAM_KEY',
                  deepgramLanguage:
                      videoCallPageStudentVideoSessionsRecord.language,
                  username: currentUserDisplayName,
                  actionCallback: (word, sentence) async {
                    await showModalBottomSheet(
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      context: context,
                      builder: (context) {
                        return WebViewAware(
                          child: GestureDetector(
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            child: Padding(
                              padding: MediaQuery.viewInsetsOf(context),
                              child: NewWordWidget(
                                word: word,
                                langCode:
                                    videoCallPageStudentVideoSessionsRecord
                                        .language,
                              ),
                            ),
                          ),
                        );
                      },
                    ).then((value) => safeSetState(() {}));
                  },
                  endCallCallback: () async {
                    unawaited(
                      () async {
                        try {
                          final result = await FirebaseFunctions.instance
                              .httpsCallable('endSession')
                              .call({
                            "sessionId": widget.videoDocRef!.id,
                          });
                          _model.cloudFunctiona1y =
                              EndSessionCloudFunctionCallResponse(
                            succeeded: true,
                          );
                        } on FirebaseFunctionsException catch (error) {
                          _model.cloudFunctiona1y =
                              EndSessionCloudFunctionCallResponse(
                            errorCode: error.code,
                            succeeded: false,
                          );
                        }
                      }(),
                    );

                    context.goNamed(
                      CallSummaryWidget.routeName,
                      queryParameters: {
                        'userRef': serializeParam(
                          functions.stringToRef(
                              videoCallPageStudentVideoSessionsRecord
                                  .currentTutorId),
                          ParamType.DocumentReference,
                        ),
                        'sessionID': serializeParam(
                          widget.videoDocRef,
                          ParamType.DocumentReference,
                        ),
                        'lang': serializeParam(
                          videoCallPageStudentVideoSessionsRecord.language,
                          ParamType.String,
                        ),
                        'dur': serializeParam(
                          videoCallPageStudentVideoSessionsRecord.duration,
                          ParamType.int,
                        ),
                      }.withoutNulls,
                    );

                    safeSetState(() {});
                  },
                  participantLeftCallback: () async {
                    context.goNamed(
                      CallSummaryWidget.routeName,
                      queryParameters: {
                        'userRef': serializeParam(
                          functions.stringToRef(
                              videoCallPageStudentVideoSessionsRecord
                                  .currentTutorId),
                          ParamType.DocumentReference,
                        ),
                        'sessionID': serializeParam(
                          widget.videoDocRef,
                          ParamType.DocumentReference,
                        ),
                        'lang': serializeParam(
                          videoCallPageStudentVideoSessionsRecord.language,
                          ParamType.String,
                        ),
                        'dur': serializeParam(
                          videoCallPageStudentVideoSessionsRecord.duration,
                          ParamType.int,
                        ),
                      }.withoutNulls,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
