import '/authorization/components/chips/chips_widget.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'edit_target_widget.dart' show EditTargetWidget;
import 'package:flutter/material.dart';

class EditTargetModel extends FlutterFlowModel<EditTargetWidget> {
  ///  Local state fields for this component.

  List<String> purpose = [];
  void addToPurpose(String item) => purpose.add(item);
  void removeFromPurpose(String item) => purpose.remove(item);
  void removeAtIndexFromPurpose(int index) => purpose.removeAt(index);
  void insertAtIndexInPurpose(int index, String item) =>
      purpose.insert(index, item);
  void updatePurposeAtIndex(int index, Function(String) updateFn) =>
      purpose[index] = updateFn(purpose[index]);

  ///  State fields for stateful widgets in this component.

  // Model for chips component.
  late ChipsModel chipsModel1;
  // Model for chips component.
  late ChipsModel chipsModel2;
  // Model for chips component.
  late ChipsModel chipsModel3;
  // Model for chips component.
  late ChipsModel chipsModel4;
  // Model for chips component.
  late ChipsModel chipsModel5;
  // Model for chips component.
  late ChipsModel chipsModel6;
  // Model for button component.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    chipsModel1 = createModel(context, () => ChipsModel());
    chipsModel2 = createModel(context, () => ChipsModel());
    chipsModel3 = createModel(context, () => ChipsModel());
    chipsModel4 = createModel(context, () => ChipsModel());
    chipsModel5 = createModel(context, () => ChipsModel());
    chipsModel6 = createModel(context, () => ChipsModel());
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    chipsModel1.dispose();
    chipsModel2.dispose();
    chipsModel3.dispose();
    chipsModel4.dispose();
    chipsModel5.dispose();
    chipsModel6.dispose();
    buttonModel.dispose();
  }
}
