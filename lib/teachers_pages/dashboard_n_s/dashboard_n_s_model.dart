import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'dashboard_n_s_widget.dart' show DashboardNSWidget;
import 'package:flutter/material.dart';

class DashboardNSModel extends FlutterFlowModel<DashboardNSWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for Switch widget.
  bool? switchValue;

  // Cached stats stream so it is not recreated on every build().
  Stream<List<StatsRecord>>? statsStream;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
