import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'edit_avatar_widget.dart' show EditAvatarWidget;
import 'package:flutter/material.dart';

class EditAvatarModel extends FlutterFlowModel<EditAvatarWidget> {
  ///  Local state fields for this component.

  DocumentReference? selectedavatar;

  FFUploadedFile? image;

  String? avatar;

  ///  State fields for stateful widgets in this component.

  // Model for button component.
  late ButtonModel buttonModel;
  bool isDataUploading_uploadDataJlx = false;
  FFUploadedFile uploadedLocalFile_uploadDataJlx =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_uploadDataJlx = '';

  @override
  void initState(BuildContext context) {
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    buttonModel.dispose();
  }
}
