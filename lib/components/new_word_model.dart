import '/backend/api_requests/api_calls.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'new_word_widget.dart' show NewWordWidget;
import 'package:flutter/material.dart';

class NewWordModel extends FlutterFlowModel<NewWordWidget> {
  ///  Local state fields for this component.

  double size = 250.0;

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Backend Call - API (yandex)] action in newWord widget.
  ApiCallResponse? worrd;
  // Stores action output result for [Backend Call - API (tatoeba)] action in newWord widget.
  ApiCallResponse? ssss;
  // Stores action output result for [Backend Call - Create Document] action in Stack widget.
  UserWordsRecord? erweerw;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
