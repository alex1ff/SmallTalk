import '/authorization/components/language_card/language_card_widget.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'native_speaker_page_widget.dart' show NativeSpeakerPageWidget;
import 'package:flutter/material.dart';

class NativeSpeakerPageModel extends FlutterFlowModel<NativeSpeakerPageWidget> {
  ///  Local state fields for this page.

  int numMaxLineAbout = 4;

  int rate = 0;

  // Cached queries so they are not recreated on every build().
  Stream<UsersRecord>? userStream;
  Future<List<ReviewsRecord>>? reviewsFuture;

  ///  State fields for stateful widgets in this page.

  // State field(s) for PageView widget.
  PageController? pageViewController;

  int get pageViewCurrentIndex => pageViewController != null &&
          pageViewController!.hasClients &&
          pageViewController!.page != null
      ? pageViewController!.page!.round()
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
