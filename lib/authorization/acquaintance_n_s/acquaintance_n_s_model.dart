import '/flutter_flow/flutter_flow_util.dart';
import 'acquaintance_n_s_widget.dart' show AcquaintanceNSWidget;
import 'package:flutter/material.dart';

class AcquaintanceNSModel extends FlutterFlowModel<AcquaintanceNSWidget> {
  PageController? pageViewController;

  FocusNode? nameFocusNode;
  TextEditingController? nameTextController;
  String? Function(BuildContext, String?)? nameTextControllerValidator;

  FocusNode? aboutMeFocusNode;
  TextEditingController? aboutMeTextController;
  String? Function(BuildContext, String?)? aboutMeTextControllerValidator;

  bool isPickingAvatar = false;
  FFUploadedFile pickedAvatarFile =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');

  bool isUploadingAvatar = false;
  FFUploadedFile uploadedAvatarFile =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedAvatarUrl = '';

  FFUploadedFile? avatar;
  bool isPickingQualificationFiles = false;
  bool isUploadingQualificationFiles = false;
  List<FFUploadedFile> qualificationProofFiles = <FFUploadedFile>[];

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    nameFocusNode?.dispose();
    nameTextController?.dispose();
    aboutMeFocusNode?.dispose();
    aboutMeTextController?.dispose();
  }
}
