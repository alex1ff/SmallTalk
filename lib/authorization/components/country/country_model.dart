import '/flutter_flow/flutter_flow_util.dart';
import 'country_widget.dart' show CountryWidget;
import 'package:flutter/material.dart';

class CountryModel extends FlutterFlowModel<CountryWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for Search4 widget.
  FocusNode? search4FocusNode;
  TextEditingController? search4TextController;
  String? Function(BuildContext, String?)? search4TextControllerValidator;
  List<String> simpleSearchResults = [];

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    search4FocusNode?.dispose();
    search4TextController?.dispose();
  }
}
