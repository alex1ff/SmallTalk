import '/authorization/components/country_card/country_card_widget.dart';
import '/backend/backend.dart';
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

  @override
  Widget build(BuildContext context) {
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
                            safeSetState(() {
                              _model.simpleSearchResults = TextSearch(
                                      (FFLocalizations.of(context)
                                                      .languageCode ==
                                                  'ru'
                                              ? functions
                                                  .countriesList()
                                                  .map((e) => e.nameRu)
                                                  .toList()
                                              : functions
                                                  .countriesList()
                                                  .map((e) => e.nameEn)
                                                  .toList() as List)
                                          .cast<String>()
                                          .map((str) =>
                                              TextSearchItem.fromTerms(
                                                  str, [str]))
                                          .toList())
                                  .search(_model.search4TextController.text)
                                  .map((r) => r.object)
                                  .take(10)
                                  .toList();
                              ;
                            });
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
                          suffixIcon: _model
                                  .search4TextController!.text.isNotEmpty
                              ? InkWell(
                                  onTap: () async {
                                    _model.search4TextController?.clear();
                                    safeSetState(() {
                                      _model.simpleSearchResults = TextSearch(
                                              (FFLocalizations.of(context)
                                                              .languageCode ==
                                                          'ru'
                                                      ? functions
                                                          .countriesList()
                                                          .map((e) => e.nameRu)
                                                          .toList()
                                                      : functions
                                                          .countriesList()
                                                          .map((e) => e.nameEn)
                                                          .toList() as List)
                                                  .cast<String>()
                                                  .map((str) =>
                                                      TextSearchItem.fromTerms(
                                                          str, [str]))
                                                  .toList())
                                          .search(
                                              _model.search4TextController.text)
                                          .map((r) => r.object)
                                          .take(10)
                                          .toList();
                                      ;
                                    });
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
          child: Builder(
            builder: (context) {
              if (_model.search4TextController.text != '') {
                return Builder(
                  builder: (context) {
                    final lang4 = _model.simpleSearchResults.toList();

                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      primary: false,
                      shrinkWrap: true,
                      scrollDirection: Axis.vertical,
                      itemCount: lang4.length,
                      separatorBuilder: (_, __) => SizedBox(height: 6.0),
                      itemBuilder: (context, lang4Index) {
                        final lang4Item = lang4[lang4Index];
                        return CountryCardWidget(
                          key: Key('Key0co_${lang4Index}_of_${lang4.length}'),
                          lang: functions
                              .countriesList()
                              .where((e) =>
                                  (e.nameEn == lang4Item) ||
                                  (lang4Item == e.nameRu))
                              .toList()
                              .firstOrNull!,
                          currentSelected: widget.selected,
                          callbackAction: (selectedLangData) async {
                            await widget.action?.call(
                              selectedLangData,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              } else {
                return Builder(
                  builder: (context) {
                    final lang44 = functions
                        .countriesList()
                        .where((e) => e.isPopular)
                        .toList()
                        .sortedList(keyOf: (e) => e.index, desc: false)
                        .toList();

                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      primary: false,
                      shrinkWrap: true,
                      scrollDirection: Axis.vertical,
                      itemCount: lang44.length,
                      separatorBuilder: (_, __) => SizedBox(height: 6.0),
                      itemBuilder: (context, lang44Index) {
                        final lang44Item = lang44[lang44Index];
                        return CountryCardWidget(
                          key: Key('Keyyni_${lang44Index}_of_${lang44.length}'),
                          lang: lang44Item,
                          currentSelected: widget.selected,
                          callbackAction: (selectedLangData) async {
                            await widget.action?.call(
                              selectedLangData,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
