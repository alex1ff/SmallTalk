import '/authorization/components/country/country_widget.dart';
import '/authorization/components/lang/lang_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'acquaintance_n_s_widget.dart' show AcquaintanceNSWidget;
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

class AcquaintanceNSModel extends FlutterFlowModel<AcquaintanceNSWidget> {
  ///  Local state fields for this page.

  bool genderISMALE = true;

  LanguageStruct? langLearn;
  void updateLangLearnStruct(Function(LanguageStruct) updateFn) {
    updateFn(langLearn ??= LanguageStruct());
  }

  CountryStruct? country;
  void updateCountryStruct(Function(CountryStruct) updateFn) {
    updateFn(country ??= CountryStruct());
  }

  FFUploadedFile? avatar;

  LanguageStruct? nativeLang;
  void updateNativeLangStruct(Function(LanguageStruct) updateFn) {
    updateFn(nativeLang ??= LanguageStruct());
  }

  ///  State fields for stateful widgets in this page.

  // State field(s) for PageView widget.
  PageController? pageViewController;

  int get pageViewCurrentIndex => pageViewController != null &&
          pageViewController!.hasClients &&
          pageViewController!.page != null
      ? pageViewController!.page!.round()
      : 0;
  // State field(s) for Name widget.
  FocusNode? nameFocusNode;
  TextEditingController? nameTextController;
  String? Function(BuildContext, String?)? nameTextControllerValidator;
  // Model for lang component.
  late LangModel langModel1;
  // Model for lang component.
  late LangModel langModel2;
  // State field(s) for SwipeableStack widget.
  late CardSwiperController swipeableStackController;
  // Model for country component.
  late CountryModel countryModel;
  // State field(s) for aboutMe widget.
  FocusNode? aboutMeFocusNode;
  TextEditingController? aboutMeTextController;
  String? Function(BuildContext, String?)? aboutMeTextControllerValidator;
  bool isDataUploading_uploadDataIyo2 = false;
  FFUploadedFile uploadedLocalFile_uploadDataIyo2 =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  bool isDataUploading_uploadData5az = false;
  FFUploadedFile uploadedLocalFile_uploadData5az =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_uploadData5az = '';

  @override
  void initState(BuildContext context) {
    langModel1 = createModel(context, () => LangModel());
    langModel2 = createModel(context, () => LangModel());
    swipeableStackController = CardSwiperController();
    countryModel = createModel(context, () => CountryModel());
  }

  @override
  void dispose() {
    nameFocusNode?.dispose();
    nameTextController?.dispose();

    langModel1.dispose();
    langModel2.dispose();
    countryModel.dispose();
    aboutMeFocusNode?.dispose();
    aboutMeTextController?.dispose();
  }
}
