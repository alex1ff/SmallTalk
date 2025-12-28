import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/nav_bar/nav_bar_widget.dart';
import '/index.dart';
import 'students_dashboard_widget.dart' show StudentsDashboardWidget;
import 'package:flutter/material.dart';

class StudentsDashboardModel extends FlutterFlowModel<StudentsDashboardWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for NavBar component.
  late NavBarModel navBarModel;

  @override
  void initState(BuildContext context) {
    navBarModel = createModel(context, () => NavBarModel());
  }

  @override
  void dispose() {
    navBarModel.dispose();
  }
}
