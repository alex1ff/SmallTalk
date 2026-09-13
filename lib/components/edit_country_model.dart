import '/components/country_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'edit_country_widget.dart' show EditCountryWidget;
import 'package:flutter/material.dart';

class EditCountryModel extends FlutterFlowModel<EditCountryWidget> {
  ///  Local state fields for this component.

  CountryStruct? selected;
  void updateSelectedStruct(Function(CountryStruct) updateFn) {
    updateFn(selected ??= CountryStruct());
  }

  ///  State fields for stateful widgets in this component.

  // Model for country component.
  late CountryModel countryModel;
  // Model for button component.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    countryModel = createModel(context, () => CountryModel());
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    countryModel.dispose();
    buttonModel.dispose();
  }
}
