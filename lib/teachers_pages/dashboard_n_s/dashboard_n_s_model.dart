import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/nav_bar/nav_bar_widget.dart';
import '/index.dart';
import 'dashboard_n_s_widget.dart' show DashboardNSWidget;
import 'package:flutter/material.dart';

class DashboardNSModel extends FlutterFlowModel<DashboardNSWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for Switch widget.
  bool? switchValue;
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
