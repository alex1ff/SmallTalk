import '/flutter_flow/flutter_flow_util.dart';
import 'lang_widget.dart' show LangWidget;
import 'package:flutter/material.dart';

class LangModel extends FlutterFlowModel<LangWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for SearchL2 widget.
  FocusNode? searchL2FocusNode;
  TextEditingController? searchL2TextController;
  String? Function(BuildContext, String?)? searchL2TextControllerValidator;
  List<String> simpleSearchResults = [];

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    searchL2FocusNode?.dispose();
    searchL2TextController?.dispose();
  }
}
