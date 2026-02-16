import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'edit_card_widget.dart' show EditCardWidget;
import 'package:flutter/material.dart';

class EditCardModel extends FlutterFlowModel<EditCardWidget> {
  // Cached stream so it is not recreated on every build().
  Stream<List<CardsRecord>>? cardsStream;

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
