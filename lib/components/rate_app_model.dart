import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/chip_widget.dart';
import 'rate_app_widget.dart' show RateAppWidget;
import 'package:flutter/material.dart';

class RateAppModel extends FlutterFlowModel<RateAppWidget> {
  ///  Local state fields for this component.

  String? chips;

  ///  State fields for stateful widgets in this component.

  // State field(s) for PageView widget.
  PageController? pageViewController;

  int get pageViewCurrentIndex => pageViewController != null &&
          pageViewController!.hasClients &&
          pageViewController!.page != null
      ? pageViewController!.page!.round()
      : 0;
  // Model for chip component.
  late ChipModel chipModel1;
  // Model for chip component.
  late ChipModel chipModel2;
  // Model for chip component.
  late ChipModel chipModel3;
  // Model for chip component.
  late ChipModel chipModel4;
  // Model for chip component.
  late ChipModel chipModel5;
  // State field(s) for Name widget.
  FocusNode? nameFocusNode;
  TextEditingController? nameTextController;
  String? Function(BuildContext, String?)? nameTextControllerValidator;
  // Model for button component.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    chipModel1 = createModel(context, () => ChipModel());
    chipModel2 = createModel(context, () => ChipModel());
    chipModel3 = createModel(context, () => ChipModel());
    chipModel4 = createModel(context, () => ChipModel());
    chipModel5 = createModel(context, () => ChipModel());
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    chipModel1.dispose();
    chipModel2.dispose();
    chipModel3.dispose();
    chipModel4.dispose();
    chipModel5.dispose();
    nameFocusNode?.dispose();
    nameTextController?.dispose();

    buttonModel.dispose();
  }
}
