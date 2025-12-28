import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'add_inter_widget.dart' show AddInterWidget;
import 'package:flutter/material.dart';

class AddInterModel extends FlutterFlowModel<AddInterWidget> {
  ///  Local state fields for this component.

  String? timeStart;

  String? timeEnd;

  ///  State fields for stateful widgets in this component.

  // Model for button component.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    buttonModel.dispose();
  }
}
