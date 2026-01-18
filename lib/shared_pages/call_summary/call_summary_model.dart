import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'call_summary_widget.dart' show CallSummaryWidget;
import 'package:flutter/material.dart';

class CallSummaryModel extends FlutterFlowModel<CallSummaryWidget> {
  ///  Local state fields for this page.

  int rait = 0;

  bool fav = false;

  bool black = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - Read Document] action in Stack widget.
  UsersRecord? user;
  // State field(s) for aboutMe widget.
  FocusNode? aboutMeFocusNode;
  TextEditingController? aboutMeTextController;
  String? Function(BuildContext, String?)? aboutMeTextControllerValidator;
  // Model for button component.
  late ButtonModel buttonModel;

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
