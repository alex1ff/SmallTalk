import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'pay_widget.dart' show PayWidget;
import 'package:flutter/material.dart';

class PayModel extends FlutterFlowModel<PayWidget> {
  ///  Local state fields for this page.

  int replenishment = 0;

  PackagesRecord? tarifDoc;

  ///  State fields for stateful widgets in this page.

  // State field(s) for Name widget.
  FocusNode? nameFocusNode;
  TextEditingController? nameTextController;
  String? Function(BuildContext, String?)? nameTextControllerValidator;
  // Stores action output result for [Firestore Query - Query a collection] action in IconButton widget.
  PromoCodesRecord? codeCopy;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    nameFocusNode?.dispose();
    nameTextController?.dispose();
  }
}
