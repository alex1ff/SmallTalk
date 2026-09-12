import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'no_balance_widget.dart' show NoBalanceWidget;
import 'package:flutter/material.dart';

class NoBalanceModel extends FlutterFlowModel<NoBalanceWidget> {
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
