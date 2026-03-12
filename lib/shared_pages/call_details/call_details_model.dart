import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/review_flow/review_submission_helper.dart';
import 'call_details_widget.dart' show CallDetailsWidget;
import 'package:flutter/material.dart';

class CallDetailsModel extends FlutterFlowModel<CallDetailsWidget> {
  /// Local state fields for this page.

  int rating = 0;

  bool isSubmittingReview = false;

  DocumentReference? reviewRefOverride;

  Future<PairReviewState>? pairReviewFuture;

  String? pairReviewTargetPath;

  bool areCaptionLogsExpanded = false;

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
