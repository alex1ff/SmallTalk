import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'edit_level_widget.dart' show EditLevelWidget;
import 'package:flutter/material.dart';

class EditLevelModel extends FlutterFlowModel<EditLevelWidget> {
  ///  Local state fields for this component.

  Level? level = Level.Beginner;

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
