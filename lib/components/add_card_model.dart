import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'add_card_widget.dart' show AddCardWidget;
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class AddCardModel extends FlutterFlowModel<AddCardWidget> {
  ///  State fields for stateful widgets in this component.

  final formKey = GlobalKey<FormState>();
  // State field(s) for Name widget.
  FocusNode? nameFocusNode;
  TextEditingController? nameTextController;
  late MaskTextInputFormatter nameMask;
  String? Function(BuildContext, String?)? nameTextControllerValidator;
  String? _nameTextControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return FFLocalizations.of(context).getText(
        'vzfl7tbq' /* Поле должно содержать от 16 си... */,
      );
    }

    if (val.length < 16) {
      return FFLocalizations.of(context).getText(
        'un33x35j' /* Поле должно содержать от 16 си... */,
      );
    }
    if (val.length > 24) {
      return FFLocalizations.of(context).getText(
        '76606mzd' /* Поле должно содержать до 24 си... */,
      );
    }

    return null;
  }

  // Model for button component.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    nameTextControllerValidator = _nameTextControllerValidator;
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    nameFocusNode?.dispose();
    nameTextController?.dispose();

    buttonModel.dispose();
  }
}
