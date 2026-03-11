import '/flutter_flow/flutter_flow_util.dart';
import 'call_details_widget.dart' show CallDetailsWidget;
import 'package:flutter/material.dart';

class CallDetailsModel extends FlutterFlowModel<CallDetailsWidget> {
  /// Local state fields for this page.

  int rating = 0;

  bool isSubmittingReview = false;

  bool? hasReviewedOverride;

  DocumentReference? reviewRefOverride;

  /// State fields for stateful widgets in this page.

  FocusNode? reviewCommentFocusNode;
  TextEditingController? reviewCommentTextController;
  String? Function(BuildContext, String?)? reviewCommentTextControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    reviewCommentFocusNode?.dispose();
    reviewCommentTextController?.dispose();
  }
}
