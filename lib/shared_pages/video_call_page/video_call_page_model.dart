import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/custom_cloud_functions/custom_cloud_function_response_manager.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/students_pages/components/new_word/new_word_widget.dart';
import 'dart:async';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'video_call_page_widget.dart' show VideoCallPageWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webviewx_plus/webviewx_plus.dart';

class VideoCallPageModel extends FlutterFlowModel<VideoCallPageWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Cloud Function - endSession] action in MinimalDailyWidget widget.
  EndSessionCloudFunctionCallResponse? cloudFunctiona1y;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}