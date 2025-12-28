import '/authorization/components/chips/chips_widget.dart';
import '/authorization/components/country/country_widget.dart';
import '/authorization/components/lang/lang_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'acquaintance_s_t_u_d_e_n_t_widget.dart' show AcquaintanceSTUDENTWidget;
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

class AcquaintanceSTUDENTModel
    extends FlutterFlowModel<AcquaintanceSTUDENTWidget> {
  ///  Local state fields for this page.

  LanguageStruct? selectedLangLearn;
  void updateSelectedLangLearnStruct(Function(LanguageStruct) updateFn) {
    updateFn(selectedLangLearn ??= LanguageStruct());
  }

  List<String> purpose = [];
  void addToPurpose(String item) => purpose.add(item);
  void removeFromPurpose(String item) => purpose.remove(item);
  void removeAtIndexFromPurpose(int index) => purpose.removeAt(index);
  void insertAtIndexInPurpose(int index, String item) =>
      purpose.insert(index, item);
  void updatePurposeAtIndex(int index, Function(String) updateFn) =>
      purpose[index] = updateFn(purpose[index]);

  Level? level = Level.Basic;

  FFUploadedFile? avatarPhooto;

  String? avatar;

  bool genderMALE = true;

  DocumentReference? selectedAvatar;

  LanguageStruct? langNS;
  void updateLangNSStruct(Function(LanguageStruct) updateFn) {
    updateFn(langNS ??= LanguageStruct());
  }

  CountryStruct? counntryNS;
  void updateCounntryNSStruct(Function(CountryStruct) updateFn) {
    updateFn(counntryNS ??= CountryStruct());
  }

  ///  State fields for stateful widgets in this page.

  bool isDataUploading_uploadDataY2w2 = false;
  FFUploadedFile uploadedLocalFile_uploadDataY2w2 =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_uploadDataY2w2 = '';

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
  // State field(s) for SwipeableStack widget.
  late CardSwiperController swipeableStackController;
  // Model for lang component.
  late LangModel langModel1;
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
  // Model for lang component.
  late LangModel langModel2;
  // Model for country component.
  late CountryModel countryModel;
  bool isDataUploading_uploadDataY2w = false;
  FFUploadedFile uploadedLocalFile_uploadDataY2w =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_uploadDataY2w = '';

  // Model for button component.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    swipeableStackController = CardSwiperController();
    langModel1 = createModel(context, () => LangModel());
    chipsModel1 = createModel(context, () => ChipsModel());
    chipsModel2 = createModel(context, () => ChipsModel());
    chipsModel3 = createModel(context, () => ChipsModel());
    chipsModel4 = createModel(context, () => ChipsModel());
    chipsModel5 = createModel(context, () => ChipsModel());
    chipsModel6 = createModel(context, () => ChipsModel());
    langModel2 = createModel(context, () => LangModel());
    countryModel = createModel(context, () => CountryModel());
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    nameFocusNode?.dispose();
    nameTextController?.dispose();

    langModel1.dispose();
    chipsModel1.dispose();
    chipsModel2.dispose();
    chipsModel3.dispose();
    chipsModel4.dispose();
    chipsModel5.dispose();
    chipsModel6.dispose();
    langModel2.dispose();
    countryModel.dispose();
    buttonModel.dispose();
  }
}
