import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'my_rew_widget.dart' show MyRewWidget;
import 'package:flutter/material.dart';

class MyRewModel extends FlutterFlowModel<MyRewWidget> {
  // Cached future so it is not recreated on every build().
  Future<List<ReviewsRecord>>? reviewsFuture;

  ///  Local state fields for this page.

  int rate = 0;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
