import '/components/language_card_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'native_speaker_page_widget.dart' show NativeSpeakerPageWidget;
import 'package:flutter/material.dart';

class NativeSpeakerPageModel extends FlutterFlowModel<NativeSpeakerPageWidget> {
  ///  Local state fields for this page.

  int numMaxLineAbout = 4;

  int rate = 0;

  ///  State fields for stateful widgets in this page.

  // Model for Language_Card component.
  late LanguageCardModel languageCardModel1;
  // Model for Language_Card component.
  late LanguageCardModel languageCardModel2;
  // State field(s) for RatingBar widget.
  double? ratingBarValue;

  @override
  void initState(BuildContext context) {
    languageCardModel1 = createModel(context, () => LanguageCardModel());
    languageCardModel2 = createModel(context, () => LanguageCardModel());
  }

  @override
  void dispose() {
    languageCardModel1.dispose();
    languageCardModel2.dispose();
  }
}
