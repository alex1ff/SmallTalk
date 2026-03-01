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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
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
  bool _isCreating = false;
  bool _createFailed = false;
  String? _createMessage;
  bool _cancelRequested = false;
  bool _isCancelling = false;
  Completer<void>? _createSessionCompleter;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WaitingForTeacherPageModel());
    unawaited(_startCreateSession());
  }

  @override
  void dispose() {
    if (_createSessionCompleter != null &&
        !_createSessionCompleter!.isCompleted) {
      _createSessionCompleter!.complete();
    }
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

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  String _localizedText({
    required String ruText,
    required String enText,
  }) {
    return FFLocalizations.of(context).getVariableText(
      ruText: ruText,
      enText: enText,
    );
  }

  String _createFailureMessage({
    String? status,
    String? fallbackMessage,
    String? errorCode,
  }) {
    if (status == 'no_tutors_available') {
      return _localizedText(
        ruText: 'Сейчас нет свободных преподавателей. Попробуйте позже.',
        enText: 'No tutors are available right now. Please try again later.',
      );
    }

    if (fallbackMessage != null) {
      return fallbackMessage;
    }

    if (errorCode != null) {
      return _localizedText(
        ruText: 'Не удалось начать поиск собеседника ($errorCode).',
        enText: 'Failed to start matching ($errorCode).',
      );
    }

    return _localizedText(
      ruText: 'Не удалось начать поиск собеседника. Попробуйте позже.',
      enText: 'Failed to start matching. Please try again later.',
    );
  }

  void _showToastAndPop(String message) {
    if (!mounted || _navigationHandled) return;
    _navigationHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showSnackbar(context, message);
      context.safePop();
    });
  }

  Map<String, dynamic>? _buildCreateSessionPayload() {
    final user = currentUserDocument;
    if (user == null) return null;

    final language = _nonEmpty(user.learningLanguage.code);
    if (language == null) return null;

    final preferredNativeLanguage =
        _nonEmpty(user.preferences.preferredNativeLanguage.code);
    final preferredCountry = _nonEmpty(user.preferences.preferredLocation.code);

    return {
      'language': language,
      if (preferredNativeLanguage != null)
        'preferredNativeLanguage': preferredNativeLanguage,
      if (preferredCountry != null) 'preferredCountry': preferredCountry,
    };
  }

  Future<void> _startCreateSession() async {
    if (_isCreating) return;

    _isCreating = true;
    _createFailed = false;
    _createMessage = null;
    _createSessionCompleter = Completer<void>();
    if (mounted) {
      safeSetState(() {});
    }

    try {
      final payload = _buildCreateSessionPayload();
      if (payload == null) {
        _model.sessionId = null;
        _createFailed = true;
        _createMessage = _createFailureMessage(
          fallbackMessage: _localizedText(
            ruText: 'Профиль заполнен не полностью. Проверьте язык обучения.',
            enText: 'Your profile is incomplete. Check your learning language.',
          ),
        );
        debugPrint(
            'WaitingForTeacher: missing user data for createVideoSession');
        if (!_cancelRequested && _createMessage != null) {
          _showToastAndPop(_createMessage!);
        }
        return;
      }

      final result = await FirebaseFunctions.instance
          .httpsCallable('createVideoSession')
          .call(payload);

      final resultMap = _asMap(result.data);
      _model.newSession = CreateVideoSessionCloudFunctionCallResponse(
        data: CallRequestResponseStruct.fromMap(resultMap),
        succeeded: true,
        resultAsString: result.data.toString(),
        jsonBody: result.data,
      );

      final sessionId = _nonEmpty(_model.newSession?.data?.sessionId);
      _model.sessionId = sessionId;

      // If cancel was requested while createVideoSession was in-flight,
      // immediately cancel the newly created session on the server.
      if (_cancelRequested && sessionId != null) {
        debugPrint(
          'WaitingForTeacher: cancel was requested while creating session. '
          'Cancelling session $sessionId now.',
        );
        unawaited(_cancelSession(sessionId));
        return;
      }

      if (sessionId == null) {
        final status = _nonEmpty(resultMap['status']?.toString());
        final backendMessage = _nonEmpty(resultMap['message']?.toString());
        _createFailed = true;
        _createMessage = _createFailureMessage(
          status: status,
          fallbackMessage: backendMessage,
        );
        debugPrint(
          'WaitingForTeacher: createVideoSession returned without sessionId '
          '(status: ${status ?? "unknown"})',
        );
        if (!_cancelRequested && _createMessage != null) {
          _showToastAndPop(_createMessage!);
        }
      }
    } on FirebaseFunctionsException catch (error) {
      _model.newSession = CreateVideoSessionCloudFunctionCallResponse(
        errorCode: error.code,
        succeeded: false,
      );
      _model.sessionId = null;
      _createFailed = true;
      _createMessage = _createFailureMessage(
        fallbackMessage: _nonEmpty(error.message),
        errorCode: error.code,
      );
      debugPrint(
        'WaitingForTeacher: createVideoSession failed: '
        '${error.code} ${error.message}',
      );
      if (!_cancelRequested && _createMessage != null) {
        _showToastAndPop(_createMessage!);
      }
    } catch (error) {
      _model.sessionId = null;
      _createFailed = true;
      _createMessage = _createFailureMessage(
        fallbackMessage: _nonEmpty(error.toString()),
      );
      debugPrint(
          'WaitingForTeacher: unexpected createVideoSession error: $error');
      if (!_cancelRequested && _createMessage != null) {
        _showToastAndPop(_createMessage!);
      }
    } finally {
      _isCreating = false;
      final completer = _createSessionCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
      if (mounted) {
        safeSetState(() {});
      }
    }
  }

  Future<void> _cancelSession(String sessionId) async {
    try {
      final result =
          await FirebaseFunctions.instance.httpsCallable('cancelCall').call({
        'sessionId': sessionId,
      });
      _model.cloudFunction5c0 = CancelCallCloudFunctionCallResponse(
        data: CancelCallResponseStruct.fromMap(_asMap(result.data)),
        succeeded: true,
        resultAsString: result.data.toString(),
        jsonBody: result.data,
      );
    } on FirebaseFunctionsException catch (error) {
      _model.cloudFunction5c0 = CancelCallCloudFunctionCallResponse(
        errorCode: error.code,
        succeeded: false,
      );
      debugPrint(
        'WaitingForTeacher: cancelCall failed: ${error.code} ${error.message}',
      );
    } catch (error) {
      debugPrint('WaitingForTeacher: unexpected cancelCall error: $error');
    }
  }

  Future<void> _handleCancelPressed() async {
    if (_isCancelling || _navigationHandled) return;
    _cancelRequested = true;
    _isCancelling = true;
    if (mounted) {
      safeSetState(() {});
    }

    try {
      final completer = _createSessionCompleter;
      if (_isCreating && completer != null) {
        try {
          await completer.future.timeout(const Duration(seconds: 8));
        } on TimeoutException {
          debugPrint(
            'WaitingForTeacher: cancel timeout while waiting createVideoSession',
          );
        }
      }

      final currentSessionId = _nonEmpty(_model.sessionId);
      if (currentSessionId != null) {
        await _cancelSession(currentSessionId);
      } else {
        debugPrint(
          'WaitingForTeacher: cancel requested before sessionId was created. '
          'Skipping cancelCall.',
        );
      }
    } finally {
      if (mounted && !_navigationHandled) {
        _navigationHandled = true;
        context.safePop();
      }
      if (mounted) {
        safeSetState(() {
          _isCancelling = false;
        });
      }
    }
  }

  void _handleSnapshot(Map<String, dynamic>? data) {
    if (_navigationHandled || _cancelRequested || data == null || !mounted) {
      return;
    }

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
    if (_navigationHandled || _cancelRequested || !mounted) return;
    _navigationHandled = true;

    final sessionId = _nonEmpty(_model.sessionId);
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
    if (_tokenFetchInProgress || _navigationHandled || _cancelRequested) return;
    final sessionId = _nonEmpty(_model.sessionId);
    if (sessionId == null) return;
    _tokenFetchInProgress = true;

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getSessionTokens')
          .call({'sessionId': sessionId});
      final data = _asMap(result.data);
      final token = _nonEmpty(data['meetingToken']?.toString());
      if (token != null &&
          mounted &&
          !_navigationHandled &&
          !_cancelRequested) {
        _navigateToVideoCall(
          roomUrl: roomUrl,
          meetingToken: token,
          roomName: roomName,
        );
      }
    } catch (e) {
      debugPrint('WaitingForTeacher: getSessionTokens failed: $e');
    } finally {
      _tokenFetchInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = _nonEmpty(_model.sessionId);
    final isLoading = sessionId == null && !_createFailed;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: sessionId == null
            ? _buildStatusBody(context,
                status: null, isLoading: isLoading, data: null)
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('videoSessions')
                    .doc(sessionId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildStatusBody(context,
                        status: null, data: null);
                  }
                  final data = snapshot.data?.data();
                  final status = data?['status'] as String?;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _handleSnapshot(data);
                  });

                  return _buildStatusBody(context,
                      status: status, data: data);
                },
              ),
      ),
    );
  }

  Widget _buildStatusBody(
    BuildContext context, {
    String? status,
    bool isLoading = false,
    Map<String, dynamic>? data,
  }) {
    final tutorInfoRaw = data?['tutorInfo'];
    final tutorInfoMap =
        tutorInfoRaw is Map ? _asMap(tutorInfoRaw) : null;
    final tutorName = _nonEmpty(tutorInfoMap?['name'] as String?);
    final tutorPhoto = _nonEmpty(tutorInfoMap?['photo'] as String?);
    final isDialingTutor = tutorName != null &&
        (status == 'searching' || status == 'connecting');

    String title;
    String subtitle;

    if (_createFailed && status == null) {
      title = _localizedText(
        ruText: 'Не удалось начать Small Talk',
        enText: 'Unable to start Small Talk',
      );
      subtitle = _createMessage ??
          _localizedText(
            ruText: 'Проблема при запуске поиска собеседника.',
            enText: 'There was a problem starting matchmaking.',
          );
    } else if (isLoading || status == null) {
      title = FFLocalizations.of(context).getVariableText(
        ruText: 'Small Talk начинается',
        enText: 'Small Talk begins',
      );
      subtitle = FFLocalizations.of(context).getVariableText(
        ruText: 'Ищем идеального собеседника',
        enText: 'Looking for the perfect companion',
      );
    } else if (isDialingTutor) {
      title = tutorName;
      subtitle = _localizedText(
        ruText: 'Дозваниваемся до собеседника…',
        enText: 'Connecting to your partner…',
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
        enText: 'All the interlocutors are busy right now. Try again later',
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

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FlutterFlowTheme.of(context).secondaryBackground,
                  Color(0xFFF4F4FA),
                ],
                begin: AlignmentDirectional(0.0, -1.0),
                end: AlignmentDirectional(0.0, 1.0),
              ),
            ),
          ),
        ),
        if (!isDialingTutor && !_createFailed)
          Positioned.fill(
            child: Center(
              child: Lottie.asset(
                'assets/jsons/World_Map_Pinging_Animation.json',
                fit: BoxFit.contain,
                animate: true,
              ),
            ),
          ),
        if (isDialingTutor && tutorPhoto != null)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: tutorPhoto,
              fit: BoxFit.cover,
              memCacheWidth: 800,
              placeholder: (context, url) => const SizedBox.shrink(),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
          ),
        Align(
          alignment: AlignmentDirectional(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x00F2F2F7),
                  Color(0xEFF2F2F7),
                  FlutterFlowTheme.of(context).secondaryBackground,
                ],
                stops: [0.0, 0.8, 1.0],
                begin: AlignmentDirectional(0.0, -1.0),
                end: AlignmentDirectional(0.0, 1.0),
              ),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(6.0, 35.0, 6.0, 35.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 6.0),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(26.0),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
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
                                textAlign: TextAlign.center,
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
                            Lottie.asset(
                              'assets/jsons/waiting_for_teacher_loading.json',
                              width: 50.0,
                              height: 117.52,
                              fit: BoxFit.contain,
                              animate: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  FFButtonWidget(
                    onPressed: (_isCancelling || _navigationHandled)
                        ? null
                        : () async {
                            await _handleCancelPressed();
                          },
                    text: FFLocalizations.of(context).getText(
                      'o2wt8jr9' /* Отменить */,
                    ),
                    options: FFButtonOptions(
                      width: double.infinity,
                      height: 50.0,
                      padding:
                          EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                      iconAlignment: IconAlignment.end,
                      iconPadding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      color: Color(0xFF6E6CFA),
                      textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                            fontFamily: 'sf pro display',
                            color: FlutterFlowTheme.of(context).primaryBackground,
                            fontSize: 16.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w500,
                          ),
                      elevation: 0.0,
                      borderRadius: BorderRadius.circular(50.0),
                    ),
                    showLoadingIndicator: _isCancelling,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
