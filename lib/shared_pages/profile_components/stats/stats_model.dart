import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'stats_widget.dart' show StatsWidget;
import 'package:flutter/material.dart';

class StatsModel extends FlutterFlowModel<StatsWidget> {
  // Cached queries so they are not recreated on every build().
  Stream<List<StatsRecord>>? statsStream;
  Future<int>? wordsCountFuture;

  ///  State fields for stateful widgets in this component.

  // Model for button component.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    buttonModel.dispose();
  }
}
