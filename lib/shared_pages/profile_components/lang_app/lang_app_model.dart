import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'lang_app_widget.dart' show LangAppWidget;
import 'package:flutter/material.dart';

class LangAppModel extends FlutterFlowModel<LangAppWidget> {
  ///  Local state fields for this component.

  LanguageStruct? selected;
  void updateSelectedStruct(Function(LanguageStruct) updateFn) {
    updateFn(selected ??= LanguageStruct());
  }

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
