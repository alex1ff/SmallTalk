import '/authorization/components/country_card/country_card_widget.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/custom_functions.dart' as functions;
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
          height: 60.0,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primaryBackground,
            borderRadius: BorderRadius.circular(100.0),
          ),
          child: Padding(
            padding: EdgeInsets.all(2.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  width: 56.0,
                  height: 56.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional(0.0, 0.0),
                    child: Icon(
                      FFIcons.ksearchLg,
                      color: FlutterFlowTheme.of(context).primaryText,
                      size: 18.0,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 8.0, 0.0),
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
                        obscureText: false,
                        decoration: InputDecoration(
                          isDense: false,
                          labelText: FFLocalizations.of(context).getText(
                            'gx50uyoo' /* Поиск */,
                          ),
                          labelStyle: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: 'sf pro display',
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 16.0,
                                letterSpacing: 0.0,
                              ),
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          suffixIcon: searchText.isNotEmpty
                              ? InkWell(
                                  onTap: () async {
                                    _model.search4TextController?.clear();
                                    safeSetState(() {});
                                  },
                                  child: Icon(
                                    Icons.clear,
                                    size: 16.0,
                                  ),
                                )
                              : null,
                        ),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'sf pro display',
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                            ),
                        cursorColor: FlutterFlowTheme.of(context).primaryText,
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
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 0.0),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            primary: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.vertical,
            itemCount: countriesToDisplay.length,
            separatorBuilder: (_, __) => SizedBox(height: 6.0),
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
