import '/authorization/components/language_card/language_card_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'native_speaker_page_widget.dart' show NativeSpeakerPageWidget;
import 'package:flutter/material.dart';

class NativeSpeakerPageModel extends FlutterFlowModel<NativeSpeakerPageWidget> {
  ///  Local state fields for this page.

  int numMaxLineAbout = 4;

  int rate = 0;

  ///  State fields for stateful widgets in this page.

  // State field(s) for PageView widget.
  PageController? pageViewController1;

  int get pageViewCurrentIndex1 => pageViewController1 != null &&
          pageViewController1!.hasClients &&
          pageViewController1!.page != null
      ? pageViewController1!.page!.round()
      : 0;
  // State field(s) for PageView widget.
  PageController? pageViewController2;

  int get pageViewCurrentIndex2 => pageViewController2 != null &&
          pageViewController2!.hasClients &&
          pageViewController2!.page != null
      ? pageViewController2!.page!.round()
      : 0;
  // Model for Language_Card component.
  late LanguageCardModel languageCardModel;
  // State field(s) for RatingBar widget.
  double? ratingBarValue;

  @override
  void initState(BuildContext context) {
    languageCardModel = createModel(context, () => LanguageCardModel());
  }

  @override
  void dispose() {
    languageCardModel.dispose();
  }
}
