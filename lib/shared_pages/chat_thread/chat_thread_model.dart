import '/flutter_flow/flutter_flow_util.dart';
import 'chat_thread_widget.dart' show ChatThreadWidget;
import 'package:flutter/material.dart';

class ChatThreadModel extends FlutterFlowModel<ChatThreadWidget> {
  TextEditingController? messageTextController;
  FocusNode? messageFocusNode;

  @override
  void initState(BuildContext context) {
    messageTextController = TextEditingController();
    messageFocusNode = FocusNode();
  }

  @override
  void dispose() {
    messageTextController?.dispose();
    messageFocusNode?.dispose();
  }
}
