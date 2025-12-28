import '/authorization/components/lang/lang_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'edit_lang_widget.dart' show EditLangWidget;
import 'package:flutter/material.dart';

class EditLangModel extends FlutterFlowModel<EditLangWidget> {
  ///  Local state fields for this component.

  LanguageStruct? selectedLang;
  void updateSelectedLangStruct(Function(LanguageStruct) updateFn) {
    updateFn(selectedLang ??= LanguageStruct());
  }

  ///  State fields for stateful widgets in this component.

  // Model for lang component.
  late LangModel langModel;
  // Model for button component.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    langModel = createModel(context, () => LangModel());
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    langModel.dispose();
    buttonModel.dispose();
  }
}
