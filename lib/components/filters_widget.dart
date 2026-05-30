import '/auth/firebase_auth/auth_util.dart';
import '/components/country_card_widget.dart';
import '/components/language_card_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/components/edit_country_widget.dart';
import '/components/edit_lang_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'filters_model.dart';
export 'filters_model.dart';

class FiltersWidget extends StatefulWidget {
  const FiltersWidget({super.key});

  @override
  State<FiltersWidget> createState() => _FiltersWidgetState();
}

class _FiltersWidgetState extends State<FiltersWidget> {
  late FiltersModel _model;

  bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

  bool _hasLanguageData(LanguageStruct? language) {
    if (language == null) return false;
    return _hasValue(language.code) ||
        _hasValue(language.nameRu) ||
        _hasValue(language.nameEn) ||
        _hasValue(language.ss);
  }

  bool _hasCountryData(CountryStruct? country) {
    if (country == null) return false;
    return _hasValue(country.code) ||
        _hasValue(country.nameRu) ||
        _hasValue(country.nameEn) ||
        _hasValue(country.flag);
  }

  LanguageStruct _languageOrPlaceholder(
    LanguageStruct? language, {
    required String ruText,
    required String enText,
  }) {
    if (_hasLanguageData(language)) {
      return language!;
    }

    return LanguageStruct(
      nameRu: ruText,
      nameEn: enText,
    );
  }

  CountryStruct _countryOrPlaceholder(
    CountryStruct? country, {
    required String ruText,
    required String enText,
  }) {
    if (_hasCountryData(country)) {
      return country!;
    }

    return CountryStruct(
      nameRu: ruText,
      nameEn: enText,
    );
  }

  String _levelLabel(BuildContext context, Level? level) {
    final isRu = FFLocalizations.of(context).languageCode == 'ru';
    switch (level) {
      case Level.Beginner:
        return isRu ? 'Начинающий' : 'Beginner';
      case Level.Basic:
        return isRu ? 'Базовый' : 'Basic';
      case Level.Intermediate:
        return isRu ? 'Средний' : 'Intermediate';
      case Level.Fluent:
        return isRu ? 'Свободный' : 'Fluent';
      case null:
        return isRu ? 'Любой' : 'Any';
    }
  }

  Future<void> _setPreferredPartnerLevel(Level? level) async {
    final userRef = currentUserReference;
    if (userRef == null) return;

    await userRef.update(createUsersRecordData(
      preferences: level == null
          ? createPreferencesStruct(
              fieldValues: {
                'preferredPartnerLevel': FieldValue.delete(),
              },
              clearUnsetFields: false,
            )
          : createPreferencesStruct(
              preferredPartnerLevel: level,
              clearUnsetFields: false,
            ),
    ));
  }

  Widget _buildLevelChoice(
    BuildContext context, {
    required Level? level,
    required Level? selectedLevel,
  }) {
    final selected = level == selectedLevel;
    final theme = FlutterFlowTheme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18.0),
      onTap: () async {
        await _setPreferredPartnerLevel(level);
        safeSetState(() {});
      },
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(14.0, 8.0, 14.0, 8.0),
        decoration: BoxDecoration(
          color: selected ? theme.primary : theme.secondaryBackground,
          borderRadius: BorderRadius.circular(18.0),
          border: Border.all(
            color: selected ? theme.primary : theme.alternate,
          ),
        ),
        child: Text(
          _levelLabel(context, level),
          style: theme.bodyMedium.override(
            fontFamily: 'Cool',
            color: selected ? theme.primaryBackground : theme.primaryText,
            fontSize: 16.0,
            letterSpacing: 0.0,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPreferredPartnerLevelSelector(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) {
        final selectedLevel =
            currentUserDocument?.preferences.preferredPartnerLevel;

        return Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            _buildLevelChoice(
              context,
              level: null,
              selectedLevel: selectedLevel,
            ),
            for (final level in Level.values)
              _buildLevelChoice(
                context,
                level: level,
                selectedLevel: selectedLevel,
              ),
          ],
        );
      },
    );
  }

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
              Flexible(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: ExpatlioDesign.background,
                  ),
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 35.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BottomSheetHeader(
                          title: FFLocalizations.of(context).getText(
                            '507c1jln' /* Фильтры */,
                          ),
                          onConfirm: () => Navigator.pop(context),
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
                                lang: _languageOrPlaceholder(
                                  currentUserDocument?.learningLanguage,
                                  ruText: 'Язык изучения не выбран.',
                                  enText: 'Learning language is not selected.',
                                ),
                                callbackAction: (selectedLangData) async {
                                  await showModalBottomSheet(
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    context: context,
                                    builder: (context) {
                                      return Padding(
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
                                lang: _countryOrPlaceholder(
                                  currentUserDocument
                                      ?.preferences.preferredLocation,
                                  ruText: 'Страна собеседника не выбрана.',
                                  enText:
                                      'Interlocutor country is not selected.',
                                ),
                                callbackAction: (selectedLangData) async {
                                  await showModalBottomSheet(
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    context: context,
                                    builder: (context) {
                                      return Padding(
                                        padding:
                                            MediaQuery.viewInsetsOf(context),
                                        child: EditCountryWidget(
                                          title: 'Локация cобеседника',
                                          selecte: currentUserDocument!
                                              .preferences.preferredLocation,
                                          persistSelectedCountryToUserCountry:
                                              false,
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
                            FFLocalizations.of(context).getVariableText(
                              ruText: 'Уровень собеседника',
                              enText: 'Partner level',
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
                              10.0, 12.0, 10.0, 0.0),
                          child: _buildPreferredPartnerLevelSelector(context),
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
