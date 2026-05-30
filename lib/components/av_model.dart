import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'av_widget.dart' show AvWidget;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

class AvModel extends FlutterFlowModel<AvWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for Carousel widget.
  CarouselSliderController? carouselController;
  int carouselCurrentIndex = 0;

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
