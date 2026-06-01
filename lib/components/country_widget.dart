import '/components/country_card_widget.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/shared_pages/design/expatlio_design.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:text_search/text_search.dart';
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
  late final List<CountryStruct> _countries = functions.countriesList();
  late final List<CountryStruct> _popularCountries = _buildPopularCountries();
  TextSearch<CountryStruct>? _countrySearchIndex;
  String? _countrySearchLocaleCode;
  String? _cachedSearchQuery;
  String? _cachedSearchLocaleCode;
  List<CountryStruct> _cachedSearchResults = const [];

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CountryModel());

    _model.search4TextController ??= TextEditingController();
    _model.search4FocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  void _ensureCountrySearchIndex(BuildContext context) {
    final localeCode = FFLocalizations.of(context).languageCode;
    if (_countrySearchIndex != null && _countrySearchLocaleCode == localeCode) {
      return;
    }

    _countrySearchIndex = TextSearch(
      _countries
          .map(
            (country) => TextSearchItem.fromTerms(
              country,
              [
                localeCode == 'ru' ? country.nameRu : country.nameEn,
              ],
            ),
          )
          .toList(),
    );
    _countrySearchLocaleCode = localeCode;
    _cachedSearchQuery = null;
    _cachedSearchLocaleCode = null;
  }

  List<CountryStruct> _searchCountries(BuildContext context, String query) {
    _ensureCountrySearchIndex(context);

    final localeCode = _countrySearchLocaleCode;
    if (_cachedSearchQuery == query && _cachedSearchLocaleCode == localeCode) {
      return _cachedSearchResults;
    }

    final results = _countrySearchIndex!.fastSearch(query).take(10).toList();
    _cachedSearchQuery = query;
    _cachedSearchLocaleCode = localeCode;
    _cachedSearchResults = results;
    return results;
  }

  List<CountryStruct> _buildPopularCountries() {
    return _countries
        .where((country) => country.isPopular)
        .toList()
        .sortedList(keyOf: (country) => country.index, desc: false)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final searchText = (_model.search4TextController?.text ?? '').trim();
    final countriesToDisplay = searchText.isNotEmpty
        ? _searchCountries(context, searchText)
        : _popularCountries;

    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 58.0,
          decoration: ExpatlioDesign.cardDecoration(radius: 16.0),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space8,
                ExpatlioDesign.space4,
                ExpatlioDesign.space12,
                ExpatlioDesign.space4),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  width: 48.0,
                  height: 48.0,
                  decoration: ExpatlioDesign.softPrimaryDecoration(),
                  child: Align(
                    alignment: AlignmentDirectional(0.0, 0.0),
                    child: Icon(
                      FFIcons.ksearchLg,
                      color: ExpatlioDesign.primary,
                      size: 18.0,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                        ExpatlioDesign.space8,
                        ExpatlioDesign.space0,
                        ExpatlioDesign.space8,
                        ExpatlioDesign.space0),
                    child: Container(
                      width: 200.0,
                      child: TextFormField(
                        controller: _model.search4TextController,
                        focusNode: _model.search4FocusNode,
                        onChanged: (_) => EasyDebounce.debounce(
                          '_model.search4TextController',
                          Duration(milliseconds: 0),
                          () async {
                            safeSetState(() {});
                          },
                        ),
                        autofocus: false,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        textAlignVertical: TextAlignVertical.center,
                        obscureText: false,
                        decoration: ExpatlioDesign.formFieldDecoration(
                          context,
                          hintText: FFLocalizations.of(context).getText(
                            'gx50uyoo' /* Поиск */,
                          ),
                          suffixIcon: searchText.isNotEmpty
                              ? InkWell(
                                  onTap: () async {
                                    _model.search4TextController?.clear();
                                    safeSetState(() {});
                                  },
                                  child: Icon(
                                    Icons.clear,
                                    color: ExpatlioDesign.muted,
                                    size: 16.0,
                                  ),
                                )
                              : null,
                        ),
                        style: ExpatlioDesign.formTextStyle(context),
                        cursorColor: ExpatlioDesign.primary,
                        enableInteractiveSelection: true,
                        validator: _model.search4TextControllerValidator
                            .asValidator(context),
                        inputFormatters: [
                          if (!isAndroid && !isiOS)
                            TextInputFormatter.withFunction(
                                (oldValue, newValue) {
                              return TextEditingValue(
                                selection: newValue.selection,
                                text: newValue.text.toCapitalization(
                                    TextCapitalization.sentences),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space0,
              ExpatlioDesign.space12,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            primary: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.vertical,
            itemCount: countriesToDisplay.length,
            separatorBuilder: (_, __) =>
                SizedBox(height: ExpatlioDesign.space8),
            itemBuilder: (context, countryIndex) {
              final countryItem = countriesToDisplay[countryIndex];
              return CountryCardWidget(
                key: ValueKey<String>(
                  '${countryItem.code}|${countryItem.nameEn}|${countryItem.nameRu}',
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
        ),
      ],
    );
  }
}
