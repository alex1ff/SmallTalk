import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/review_flow/review_submission_helper.dart';
import 'call_summary_widget.dart' show CallSummaryWidget;
import 'package:flutter/material.dart';

class CallSummaryModel extends FlutterFlowModel<CallSummaryWidget> {
  ///  Local state fields for this page.

  int rait = 0;

  bool fav = false;

  bool black = false;

  bool skipToday = false;

  bool favTouched = false;

  bool blackTouched = false;

  DocumentReference? reviewRefOverride;

  Future<PairReviewState>? pairReviewFuture;

  String? pairReviewTargetPath;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - Read Document] action in CallSummary widget.
  UsersRecord? user;
  // State field(s) for aboutMe widget.
  FocusNode? aboutMeFocusNode;
  TextEditingController? aboutMeTextController;
  String? Function(BuildContext, String?)? aboutMeTextControllerValidator;
  // Model for button component.
  late ButtonModel buttonModel;

  // Cached future so it is not recreated on every build().
  Future<UserPublicProfilesRecord?>? userFuture;

  @override
  void initState(BuildContext context) {
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    aboutMeFocusNode?.dispose();
    aboutMeTextController?.dispose();

    buttonModel.dispose();
  }
}
