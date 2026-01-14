import '/backend/custom_cloud_functions/custom_cloud_function_response_manager.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'waiting_for_teacher_page_widget.dart' show WaitingForTeacherPageWidget;
import 'package:flutter/material.dart';

class WaitingForTeacherPageModel
    extends FlutterFlowModel<WaitingForTeacherPageWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Cloud Function - createVideoSession] action in WaitingForTeacherPage widget.
  CreateVideoSessionCloudFunctionCallResponse? newSession;
  // Stores action output result for [Cloud Function - cancelCall] action in Button widget.
  CancelCallCloudFunctionCallResponse? cloudFunction5c0;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
