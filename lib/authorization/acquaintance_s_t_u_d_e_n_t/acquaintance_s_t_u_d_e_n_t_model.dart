import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'student_onboarding_logic.dart';
import 'acquaintance_s_t_u_d_e_n_t_widget.dart' show AcquaintanceSTUDENTWidget;
import 'package:flutter/material.dart';

class AcquaintanceSTUDENTModel
    extends FlutterFlowModel<AcquaintanceSTUDENTWidget> {
  /// Local state fields for this page.

  LanguageStruct? selectedLangLearn;

  CountryStruct? country;

  Level? level = defaultStudentOnboardingLevel;

  bool genderMALE = true;

  /// State fields for stateful widgets in this page.

  PageController? pageViewController;

  int get pageViewCurrentIndex => pageViewController != null &&
          pageViewController!.hasClients &&
          pageViewController!.page != null
      ? pageViewController!.page!.round()
      : 0;

  FocusNode? nameFocusNode;
  TextEditingController? nameTextController;
  String? Function(BuildContext, String?)? nameTextControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    pageViewController?.dispose();
    nameFocusNode?.dispose();
    nameTextController?.dispose();
  }
}
