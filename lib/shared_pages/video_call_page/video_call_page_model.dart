import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import 'video_call_page_widget.dart' show VideoCallPageWidget;
import 'package:flutter/material.dart';

class VideoCallPageModel extends FlutterFlowModel<VideoCallPageWidget> {
  ///  State fields for stateful widgets in this page.

  @visibleForTesting
  static Stream<VideoSessionsRecord> Function(DocumentReference sessionRef)?
      debugSessionStream;

  // Cached session stream so it is not recreated on every build().
  Stream<VideoSessionsRecord>? sessionStream;
  DocumentReference? _sessionRef;

  void bindSession(DocumentReference? videoDocRef) {
    if (videoDocRef == null) {
      _sessionRef = null;
      sessionStream = null;
      return;
    }

    if (_sessionRef?.path == videoDocRef.path && sessionStream != null) {
      return;
    }

    _sessionRef = videoDocRef;
    final debugSessionStream = VideoCallPageModel.debugSessionStream;
    sessionStream = debugSessionStream != null
        ? debugSessionStream(videoDocRef)
        : VideoSessionsRecord.getDocument(videoDocRef);
  }

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
