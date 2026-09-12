import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'pay_copy_widget.dart' show PayCopyWidget;
import 'package:flutter/material.dart';

class PayCopyModel extends FlutterFlowModel<PayCopyWidget> {
  // Cached queries so they are not recreated on every build().
  Stream<List<CardsRecord>>? cardsStream;
  Stream<List<TransactionsRecord>>? transactionsStream;

  ///  Local state fields for this page.

  int replenishment = 0;

  String tarif = '20 Expatlio';

  DocumentReference? selectedCard;
  bool shouldAutoSelectFirstCard = true;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
