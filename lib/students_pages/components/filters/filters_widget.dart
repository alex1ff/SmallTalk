import '/auth/firebase_auth/auth_util.dart';
import '/authorization/components/country_card/country_card_widget.dart';
import '/authorization/components/language_card/language_card_widget.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/edit_components/edit_country/edit_country_widget.dart';
import '/shared_pages/edit_components/edit_lang/edit_lang_widget.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'filters_model.dart';
export 'filters_model.dart';

class FiltersWidget extends StatefulWidget {
  const FiltersWidget({super.key});

  @override
  State<FiltersWidget> createState() => _FiltersWidgetState();
}

class _FiltersWidgetState extends State<FiltersWidget> {
  late FiltersModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FiltersModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (FFLocalizations.of(context).languageCode == 'ru') {
        _model.addToSelected(FFAppState().languagesList.elementAtOrNull(1)!);
        safeSetState(() {});
      } else {
        _model.addToSelected(FFAppState().languagesList.firstOrNull!);
        safeSetState(() {});
      }
    });
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Stack(
      alignment: AlignmentDirectional(0.0, 1.0),
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 55.0, 0.0, 0.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 16.0,
                child: custom_widgets.NotchedClipper(
                  width: double.infinity,
                  height: 16.0,
                ),
              ),
              Flexible(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                  ),
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(6.0, 16.0, 6.0, 35.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: AlignmentDirectional(0.0, -1.0),
                          child: Text(
                            FFLocalizations.of(context).getText(
                              '507c1jln' /* Фильтры */,
                            ),
                            textAlign: TextAlign.start,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Cool',
                                  fontSize: 26.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 24.0, 0.0, 0.0),
                          child: Text(
                            FFLocalizations.of(context).getText(
                              'nu210379' /* Язык зучения */,
                            ),
                            textAlign: TextAlign.start,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Cool',
                                  fontSize: 20.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 12.0, 0.0, 0.0),
                          child: AuthUserStreamWidget(
                            builder: (context) => wrapWithModel(
                              model: _model.languageCardModel1,
                              updateCallback: () => safeSetState(() {}),
                              child: LanguageCardWidget(
                                lang: currentUserDocument!.learningLanguage,
                                callbackAction: (selectedLangData) async {
                                  await showModalBottomSheet(
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    context: context,
                                    builder: (context) {
                                      return WebViewAware(
                                        child: Padding(
                                          padding:
                                              MediaQuery.viewInsetsOf(context),
                                          child: EditLangWidget(
                                            selected: currentUserDocument!
                                                .learningLanguage,
                                            title: 'Язык изучения',
                                            action: (lang) async {
                                              await currentUserReference!
                                                  .update(createUsersRecordData(
                                                learningLanguage:
                                                    updateLanguageStruct(
                                                  lang,
                                                  clearUnsetFields: false,
                                                ),
                                              ));
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ).then((value) => safeSetState(() {}));
                                },
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 40.0, 0.0, 0.0),
                          child: Text(
                            FFLocalizations.of(context).getText(
                              'qdxe0ygf' /* Язык cобеседника */,
                            ),
                            textAlign: TextAlign.start,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Cool',
                                  fontSize: 20.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 12.0, 0.0, 0.0),
                          child: AuthUserStreamWidget(
                            builder: (context) => wrapWithModel(
                              model: _model.languageCardModel2,
                              updateCallback: () => safeSetState(() {}),
                              child: LanguageCardWidget(
                                lang: currentUserDocument!
                                    .preferences.preferredNativeLanguage,
                                callbackAction: (selectedLangData) async {
                                  await showModalBottomSheet(
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    context: context,
                                    builder: (context) {
                                      return WebViewAware(
                                        child: Padding(
                                          padding:
                                              MediaQuery.viewInsetsOf(context),
                                          child: EditLangWidget(
                                            selected: currentUserDocument!
                                                .preferences
                                                .preferredNativeLanguage,
                                            title: 'Язык cобеседника',
                                            action: (lang) async {
                                              await currentUserReference!
                                                  .update(createUsersRecordData(
                                                preferences:
                                                    createPreferencesStruct(
                                                  preferredNativeLanguage:
                                                      updateLanguageStruct(
                                                    lang,
                                                    clearUnsetFields: false,
                                                  ),
                                                  clearUnsetFields: false,
                                                ),
                                              ));
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ).then((value) => safeSetState(() {}));
                                },
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 40.0, 0.0, 0.0),
                          child: Text(
                            FFLocalizations.of(context).getText(
                              'dtstv5e7' /* Локация cобеседника */,
                            ),
                            textAlign: TextAlign.start,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Cool',
                                  fontSize: 20.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 12.0, 0.0, 0.0),
                          child: AuthUserStreamWidget(
                            builder: (context) => wrapWithModel(
                              model: _model.countryCardModel,
                              updateCallback: () => safeSetState(() {}),
                              child: CountryCardWidget(
                                lang: currentUserDocument!
                                    .preferences.preferredLocation,
                                callbackAction: (selectedLangData) async {
                                  await showModalBottomSheet(
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    context: context,
                                    builder: (context) {
                                      return WebViewAware(
                                        child: Padding(
                                          padding:
                                              MediaQuery.viewInsetsOf(context),
                                          child: EditCountryWidget(
                                            title: 'Локация cобеседника',
                                            selecte: currentUserDocument!
                                                .preferences.preferredLocation,
                                            action: (lang) async {
                                              await currentUserReference!
                                                  .update(createUsersRecordData(
                                                preferences:
                                                    createPreferencesStruct(
                                                  preferredLocation:
                                                      updateCountryStruct(
                                                    lang,
                                                    clearUnsetFields: false,
                                                  ),
                                                  clearUnsetFields: false,
                                                ),
                                              ));
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ).then((value) => safeSetState(() {}));
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
