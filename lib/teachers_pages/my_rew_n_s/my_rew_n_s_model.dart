import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'my_rew_n_s_widget.dart' show MyRewNSWidget;
import 'package:flutter/material.dart';

class MyRewNSModel extends FlutterFlowModel<MyRewNSWidget> {
  // Cached future so it is not recreated on every build().
  Future<List<ReviewsRecord>>? reviewsFuture;

  ///  Local state fields for this page.

  int rate = 0;

  ///  State fields for stateful widgets in this page.

  // State field(s) for RatingBar widget.
  double? ratingBarValue;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
