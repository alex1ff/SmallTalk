import '/authorization/components/language_card/language_card_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:text_search/text_search.dart';
import 'lang_model.dart';
export 'lang_model.dart';

class LangWidget extends StatefulWidget {
  const LangWidget({
    super.key,
    required this.action,
    this.selected,
  });

  final Future Function(LanguageStruct lang)? action;
  final LanguageStruct? selected;

  @override
  State<LangWidget> createState() => _LangWidgetState();
}

class _LangWidgetState extends State<LangWidget> {
  late LangModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LangModel());

    _model.searchL2TextController ??= TextEditingController();
    _model.searchL2FocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Column(
      mainAxisSize: MainAxisSize.min,
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
                        controller: _model.searchL2TextController,
                        focusNode: _model.searchL2FocusNode,
                        onChanged: (_) => EasyDebounce.debounce(
                          '_model.searchL2TextController',
                          Duration(milliseconds: 0),
                          () async {
                            safeSetState(() {
                              _model.simpleSearchResults = TextSearch(
                                      (FFLocalizations.of(context)
                                                      .languageCode ==
                                                  'ru'
                                              ? FFAppState()
                                                  .languagesList
                                                  .map((e) => e.nameRu)
                                                  .toList()
                                              : FFAppState()
                                                  .languagesList
                                                  .map((e) => e.nameEn)
                                                  .toList() as List)
                                          .cast<String>()
                                          .map((str) =>
                                              TextSearchItem.fromTerms(
                                                  str, [str]))
                                          .toList())
                                  .search(_model.searchL2TextController.text)
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
                            'fo4zvvcg' /* Поиск */,
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
                                  .searchL2TextController!.text.isNotEmpty
                              ? InkWell(
                                  onTap: () async {
                                    _model.searchL2TextController?.clear();
                                    safeSetState(() {
                                      _model.simpleSearchResults = TextSearch(
                                              (FFLocalizations.of(context)
                                                              .languageCode ==
                                                          'ru'
                                                      ? FFAppState()
                                                          .languagesList
                                                          .map((e) => e.nameRu)
                                                          .toList()
                                                      : FFAppState()
                                                          .languagesList
                                                          .map((e) => e.nameEn)
                                                          .toList() as List)
                                                  .cast<String>()
                                                  .map((str) =>
                                                      TextSearchItem.fromTerms(
                                                          str, [str]))
                                                  .toList())
                                          .search(_model
                                              .searchL2TextController.text)
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
                        validator: _model.searchL2TextControllerValidator
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
              if (valueOrDefault<bool>(
                _model.searchL2TextController.text != '',
                false,
              )) {
                return Builder(
                  builder: (context) {
                    final lang = _model.simpleSearchResults.toList();

                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      primary: false,
                      shrinkWrap: true,
                      scrollDirection: Axis.vertical,
                      itemCount: lang.length,
                      separatorBuilder: (_, __) => SizedBox(height: 6.0),
                      itemBuilder: (context, langIndex) {
                        final langItem = lang[langIndex];
                        return LanguageCardWidget(
                          key: Key('Key3z0_${langIndex}_of_${lang.length}'),
                          lang: FFAppState()
                              .languagesList
                              .where((e) =>
                                  (langItem == e.nameEn) ||
                                  (langItem == e.nameRu))
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
                    final lang1 = FFAppState().languagesList.toList();

                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      primary: false,
                      shrinkWrap: true,
                      scrollDirection: Axis.vertical,
                      itemCount: lang1.length,
                      separatorBuilder: (_, __) => SizedBox(height: 6.0),
                      itemBuilder: (context, lang1Index) {
                        final lang1Item = lang1[lang1Index];
                        return LanguageCardWidget(
                          key: Key('Keyqrn_${lang1Index}_of_${lang1.length}'),
                          lang: lang1Item,
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
