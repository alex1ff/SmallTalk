import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'edit_gendeer_widget.dart' show EditGendeerWidget;
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

class EditGendeerModel extends FlutterFlowModel<EditGendeerWidget> {
  ///  Local state fields for this component.

  bool genderISMALE = true;

  ///  State fields for stateful widgets in this component.

  // State field(s) for SwipeableStack widget.
  late CardSwiperController swipeableStackController;
  // Model for button component.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    swipeableStackController = CardSwiperController();
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    buttonModel.dispose();
  }
}
