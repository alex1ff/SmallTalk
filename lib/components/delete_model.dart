import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'delete_widget.dart' show DeleteWidget;
import 'package:flutter/material.dart';

class DeleteModel extends FlutterFlowModel<DeleteWidget> {
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
