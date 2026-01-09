import '/authorization/components/country_card/country_card_widget.dart';
import '/authorization/components/language_card/language_card_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'filters_widget.dart' show FiltersWidget;
import 'package:flutter/material.dart';

class FiltersModel extends FlutterFlowModel<FiltersWidget> {
  ///  Local state fields for this component.

  List<LanguageStruct> selected = [];
  void addToSelected(LanguageStruct item) => selected.add(item);
  void removeFromSelected(LanguageStruct item) => selected.remove(item);
  void removeAtIndexFromSelected(int index) => selected.removeAt(index);
  void insertAtIndexInSelected(int index, LanguageStruct item) =>
      selected.insert(index, item);
  void updateSelectedAtIndex(int index, Function(LanguageStruct) updateFn) =>
      selected[index] = updateFn(selected[index]);

  ///  State fields for stateful widgets in this component.

  // Model for Language_Card component.
  late LanguageCardModel languageCardModel1;
  // Model for Language_Card component.
  late LanguageCardModel languageCardModel2;
  // Model for countryCard component.
  late CountryCardModel countryCardModel;
  // Model for button component.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    languageCardModel1 = createModel(context, () => LanguageCardModel());
    languageCardModel2 = createModel(context, () => LanguageCardModel());
    countryCardModel = createModel(context, () => CountryCardModel());
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    languageCardModel1.dispose();
    languageCardModel2.dispose();
    countryCardModel.dispose();
    buttonModel.dispose();
  }
}
