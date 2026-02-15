import '/auth/firebase_auth/auth_util.dart';
import '/backend/custom_cloud_functions/custom_cloud_function_response_manager.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '/index.dart' as app;
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

  bool _navigationHandled = false;
  bool _tokenFetchInProgress = false;

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
        _model.sessionId = _model.newSession!.data!.sessionId;
      } on FirebaseFunctionsException catch (error) {
        _model.newSession = CreateVideoSessionCloudFunctionCallResponse(
          errorCode: error.code,
          succeeded: false,
        );
      }

      if (mounted) {
        safeSetState(() {});
      }
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  String? _nonEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final lowered = trimmed.toLowerCase();
    if (lowered == 'null' || lowered == 'undefined' || lowered == 'false') {
      return null;
    }
    return trimmed;
  }

  void _handleSnapshot(Map<String, dynamic>? data) {
    if (_navigationHandled || data == null || !mounted) return;

    final status = data['status'] as String?;
    final roomUrl = _nonEmpty(data['dailyRoomUrl'] as String?);
    final roomName = _nonEmpty(data['dailyRoomName'] as String?);
    final studentMeetingToken =
        _nonEmpty(data['studentMeetingToken'] as String?);
    final studentTriggered = data['studentNavigationTriggered'] == true;

    final isActive = status == 'active' || status == 'connected';

    // Navigate when session is active and we have room data
    if ((isActive || studentTriggered) && roomUrl != null) {
      if (studentMeetingToken != null) {
        _navigateToVideoCall(
          roomUrl: roomUrl,
          meetingToken: studentMeetingToken,
          roomName: roomName,
        );
      } else if (!_tokenFetchInProgress) {
        _fetchTokenAndNavigate(roomUrl: roomUrl, roomName: roomName);
      }
    }

    // Auto-pop on terminal statuses
    if (status == 'cancelled' || status == 'ended') {
      _navigationHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.safePop();
      });
    }
  }

  void _navigateToVideoCall({
    required String roomUrl,
    required String meetingToken,
    String? roomName,
  }) {
    if (_navigationHandled || !mounted) return;
    _navigationHandled = true;

    final sessionId = _model.sessionId;
    if (sessionId == null) return;

    final sessionRef =
        FirebaseFirestore.instance.collection('videoSessions').doc(sessionId);

    // Reset the navigation trigger flag in background
    unawaited(sessionRef.update({
      'studentNavigationTriggered': false,
      'navigationCompletedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {}));

    context.goNamed(
      app.VideoCallPageWidget.routeName,
      queryParameters: {
        'videoDocRef': serializeParam(
          sessionRef,
          ParamType.DocumentReference,
        ),
        'roomUrl': serializeParam(roomUrl, ParamType.String),
        'roomName': serializeParam(roomName, ParamType.String),
        'meetingToken': serializeParam(meetingToken, ParamType.String),
      }.withoutNulls,
    );
  }

  Future<void> _fetchTokenAndNavigate({
    required String roomUrl,
    String? roomName,
  }) async {
    if (_tokenFetchInProgress || _navigationHandled) return;
    _tokenFetchInProgress = true;

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getSessionTokens')
          .call({'sessionId': _model.sessionId});
      final data = result.data as Map<String, dynamic>? ?? {};
      final token = _nonEmpty(data['meetingToken'] as String?);
      if (token != null && mounted && !_navigationHandled) {
        _navigateToVideoCall(
          roomUrl: roomUrl,
          meetingToken: token,
          roomName: roomName,
        );
      }
    } catch (e) {
      debugPrint(
          'WaitingForTeacher: getSessionTokens failed: $e');
    } finally {
      _tokenFetchInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = _model.sessionId;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: sessionId == null
            ? _buildStatusBody(context, status: null, isLoading: true)
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('videoSessions')
                    .doc(sessionId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data();
                  final status = data?['status'] as String?;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _handleSnapshot(data);
                  });

                  return _buildStatusBody(context, status: status);
                },
              ),
      ),
    );
  }

  Widget _buildStatusBody(
    BuildContext context, {
    String? status,
    bool isLoading = false,
  }) {
    String title;
    String subtitle;

    if (isLoading || status == null) {
      title = FFLocalizations.of(context).getVariableText(
        ruText: 'Small Talk начинается',
        enText: 'Small Talk begins',
      );
      subtitle = FFLocalizations.of(context).getVariableText(
        ruText: 'Ищем идеального собеседника',
        enText: 'Looking for the perfect companion',
      );
    } else if (status == 'searching') {
      title = FFLocalizations.of(context).getVariableText(
        ruText: 'Дозваниваемся',
        enText: 'Connecting…',
      );
      subtitle = FFLocalizations.of(context).getVariableText(
        ruText: 'Ждём, пока собеседник примет звонок',
        enText: 'We are waiting for the interlocutor to accept the call.',
      );
    } else if (status == 'connecting') {
      title = FFLocalizations.of(context).getVariableText(
        ruText: 'Собеседник найден',
        enText: 'Partner found',
      );
      subtitle = FFLocalizations.of(context).getVariableText(
        ruText: 'Подключаемся к звонку…',
        enText: 'Connecting to the call…',
      );
    } else if (status == 'no_tutors_available') {
      title = FFLocalizations.of(context).getVariableText(
        ruText: 'Никого не нашли',
        enText: 'No one was found',
      );
      subtitle = FFLocalizations.of(context).getVariableText(
        ruText: 'Все собеседники сейчас заняты. Попробуйте позже',
        enText:
            'All the interlocutors are busy right now. Try again later',
      );
    } else if (status == 'active' || status == 'connected') {
      title = FFLocalizations.of(context).getVariableText(
        ruText: 'Подключаемся',
        enText: 'Connecting',
      );
      subtitle = FFLocalizations.of(context).getVariableText(
        ruText: 'Сейчас начнётся звонок…',
        enText: 'The call is about to start…',
      );
    } else {
      title = FFLocalizations.of(context).getVariableText(
        ruText: 'Small Talk начинается',
        enText: 'Small Talk begins',
      );
      subtitle = FFLocalizations.of(context).getVariableText(
        ruText: 'Ищем идеального собеседника',
        enText: 'Looking for the perfect companion',
      );
    }

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 35.0),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 12.0),
            child: FFButtonWidget(
              onPressed: () async {
                final currentSessionId = _model.sessionId;
                if (currentSessionId != null) {
                  unawaited(
                    () async {
                      try {
                        final result = await FirebaseFunctions.instance
                            .httpsCallable('cancelCall')
                            .call({
                          "sessionId": currentSessionId,
                        });
                        _model.cloudFunction5c0 =
                            CancelCallCloudFunctionCallResponse(
                          data:
                              CancelCallResponseStruct.fromMap(result.data),
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
                }
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
                textStyle:
                    FlutterFlowTheme.of(context).titleSmall.override(
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
                    title,
                    style:
                        FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Cool',
                              color:
                                  FlutterFlowTheme.of(context).primaryText,
                              fontSize: 21.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
                            ),
                  ),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                        0.0, 8.0, 0.0, 0.0),
                    child: Text(
                      subtitle,
                      style: FlutterFlowTheme.of(context)
                          .bodyMedium
                          .override(
                            fontFamily: 'sf pro display',
                            color: FlutterFlowTheme.of(context)
                                .secondaryText,
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
    );
  }
}
