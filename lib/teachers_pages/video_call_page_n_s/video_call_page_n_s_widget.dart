import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'video_call_page_n_s_model.dart';
export 'video_call_page_n_s_model.dart';

class VideoCallPageNSWidget extends StatefulWidget {
  const VideoCallPageNSWidget({
    super.key,
    required this.videoDocRef,
  });

  final DocumentReference? videoDocRef;

  static String routeName = 'VideoCallPage_NS';
  static String routePath = '/videoCallPageNS';

  @override
  State<VideoCallPageNSWidget> createState() => _VideoCallPageNSWidgetState();
}

class _VideoCallPageNSWidgetState extends State<VideoCallPageNSWidget> {
  late VideoCallPageNSModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => VideoCallPageNSModel());
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

        final videoCallPageNSVideoSessionsRecord = snapshot.data!;

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          ),
        );
      },
    );
  }
}
