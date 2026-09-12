import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'edit_about_widget.dart' show EditAboutWidget;
import 'package:flutter/material.dart';

class EditAboutModel extends FlutterFlowModel<EditAboutWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for aboutMe widget.
  FocusNode? aboutMeFocusNode;
  TextEditingController? aboutMeTextController;
  String? Function(BuildContext, String?)? aboutMeTextControllerValidator;
  // Model for button component.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    aboutMeFocusNode?.dispose();
    aboutMeTextController?.dispose();

    buttonModel.dispose();
  }
}
