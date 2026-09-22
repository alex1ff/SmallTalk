import '/components/country_card_widget.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'country_model.dart';
export 'country_model.dart';

class CountryWidget extends StatefulWidget {
  const CountryWidget({
    super.key,
    required this.action,
    this.selected,
  });

  final Future Function(CountryStruct lang)? action;
  final CountryStruct? selected;

  @override
  State<CountryWidget> createState() => _CountryWidgetState();
}

class _CountryWidgetState extends State<CountryWidget> {
  late CountryModel _model;
  late final List<CountryStruct> _locations = functions.countriesList()
    ..sort((left, right) => left.index.compareTo(right.index));

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CountryModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.separated(
          padding: EdgeInsets.zero,
          primary: false,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          scrollDirection: Axis.vertical,
          itemCount: _locations.length,
          separatorBuilder: (_, __) => SizedBox(height: ExpatlioDesign.space8),
          itemBuilder: (context, countryIndex) {
            final countryItem = _locations[countryIndex];
            return CountryCardWidget(
              key: ValueKey<String>(
                '${countryItem.code}|${countryItem.cityKey}',
              ),
              lang: countryItem,
              currentSelected: widget.selected,
              callbackAction: (selectedLangData) async {
                await widget.action?.call(
                  selectedLangData,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
