import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'acquaintance_n_s_s_t_a_r_t_widget.dart' show AcquaintanceNSSTARTWidget;
import 'package:flutter/material.dart';

class AcquaintanceNSSTARTModel
    extends FlutterFlowModel<AcquaintanceNSSTARTWidget> {
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
