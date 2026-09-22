import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'logout_widget.dart' show LogoutWidget;
import 'package:flutter/material.dart';

class LogoutModel extends FlutterFlowModel<LogoutWidget> {
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
