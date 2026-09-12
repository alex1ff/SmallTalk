import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'students_dashboard_widget.dart' show StudentsDashboardWidget;
import 'package:flutter/material.dart';

class StudentsDashboardModel extends FlutterFlowModel<StudentsDashboardWidget> {
  ///  State fields for stateful widgets in this page.

  // Cached stats stream so it is not recreated on every build().
  Stream<List<StatsRecord>>? statsStream;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
