import '/backend/backend.dart';
import '/backend/custom_cloud_functions/custom_cloud_function_response_manager.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import 'video_call_page_widget.dart' show VideoCallPageWidget;
import 'package:flutter/material.dart';

class VideoCallPageModel extends FlutterFlowModel<VideoCallPageWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Cloud Function - endSession] action in MinimalDailyWidget widget.
  EndSessionCloudFunctionCallResponse? cloudFunctiona1y;

  // Cached session stream so it is not recreated on every build().
  Stream<VideoSessionsRecord>? sessionStream;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
