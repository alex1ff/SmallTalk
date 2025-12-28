import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/nav_bar/nav_bar_widget.dart';
import 'profile_edit_widget.dart' show ProfileEditWidget;
import 'package:flutter/material.dart';

class ProfileEditModel extends FlutterFlowModel<ProfileEditWidget> {
  ///  State fields for stateful widgets in this page.

  bool isDataUploading_uploadData4bs = false;
  FFUploadedFile uploadedLocalFile_uploadData4bs =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_uploadData4bs = '';

  // State field(s) for Name widget.
  FocusNode? nameFocusNode1;
  TextEditingController? nameTextController1;
  String? Function(BuildContext, String?)? nameTextController1Validator;
  // State field(s) for Gender widget.
  FocusNode? genderFocusNode1;
  TextEditingController? genderTextController1;
  String? Function(BuildContext, String?)? genderTextController1Validator;
  // State field(s) for langL widget.
  FocusNode? langLFocusNode;
  TextEditingController? langLTextController;
  String? Function(BuildContext, String?)? langLTextControllerValidator;
  // State field(s) for levelL widget.
  FocusNode? levelLFocusNode;
  TextEditingController? levelLTextController;
  String? Function(BuildContext, String?)? levelLTextControllerValidator;
  // State field(s) for targ widget.
  FocusNode? targFocusNode;
  TextEditingController? targTextController;
  String? Function(BuildContext, String?)? targTextControllerValidator;
  // State field(s) for Name widget.
  FocusNode? nameFocusNode2;
  TextEditingController? nameTextController2;
  String? Function(BuildContext, String?)? nameTextController2Validator;
  // State field(s) for Gender widget.
  FocusNode? genderFocusNode2;
  TextEditingController? genderTextController2;
  String? Function(BuildContext, String?)? genderTextController2Validator;
  // State field(s) for about widget.
  FocusNode? aboutFocusNode;
  TextEditingController? aboutTextController;
  String? Function(BuildContext, String?)? aboutTextControllerValidator;
  // State field(s) for NSLang widget.
  FocusNode? nSLangFocusNode;
  TextEditingController? nSLangTextController;
  String? Function(BuildContext, String?)? nSLangTextControllerValidator;
  // State field(s) for countryNS widget.
  FocusNode? countryNSFocusNode;
  TextEditingController? countryNSTextController;
  String? Function(BuildContext, String?)? countryNSTextControllerValidator;
  // Model for NavBar component.
  late NavBarModel navBarModel;

  @override
  void initState(BuildContext context) {
    navBarModel = createModel(context, () => NavBarModel());
  }

  @override
  void dispose() {
    nameFocusNode1?.dispose();
    nameTextController1?.dispose();

    genderFocusNode1?.dispose();
    genderTextController1?.dispose();

    langLFocusNode?.dispose();
    langLTextController?.dispose();

    levelLFocusNode?.dispose();
    levelLTextController?.dispose();

    targFocusNode?.dispose();
    targTextController?.dispose();

    nameFocusNode2?.dispose();
    nameTextController2?.dispose();

    genderFocusNode2?.dispose();
    genderTextController2?.dispose();

    aboutFocusNode?.dispose();
    aboutTextController?.dispose();

    nSLangFocusNode?.dispose();
    nSLangTextController?.dispose();

    countryNSFocusNode?.dispose();
    countryNSTextController?.dispose();

    navBarModel.dispose();
  }
}
