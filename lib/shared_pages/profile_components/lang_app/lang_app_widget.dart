import '/authorization/components/language_card/language_card_widget.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'lang_app_model.dart';
export 'lang_app_model.dart';

class LangAppWidget extends StatefulWidget {
  const LangAppWidget({super.key});

  @override
  State<LangAppWidget> createState() => _LangAppWidgetState();
}

class _LangAppWidgetState extends State<LangAppWidget> {
  late LangAppModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LangAppModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (FFLocalizations.of(context).languageCode == 'ru') {
        _model.selected = FFAppState().languagesList.elementAtOrNull(1);
        safeSetState(() {});
      } else {
        _model.selected = FFAppState().languagesList.firstOrNull;
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
                        EdgeInsetsDirectional.fromSTEB(6.0, 16.0, 6.0, 122.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          FFLocalizations.of(context).getText(
                            '2wr6p6ar' /* Язык приложения */,
                          ),
                          textAlign: TextAlign.start,
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Cool',
                                    fontSize: 26.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 24.0, 0.0, 0.0),
                          child: Builder(
                            builder: (context) {
                              final la =
                                  FFAppState().languagesList.take(2).toList();

                              return ListView.separated(
                                padding: EdgeInsets.zero,
                                primary: false,
                                shrinkWrap: true,
                                scrollDirection: Axis.vertical,
                                itemCount: la.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: 6.0),
                                itemBuilder: (context, laIndex) {
                                  final laItem = la[laIndex];
                                  return LanguageCardWidget(
                                    key: Key(
                                        'Key5kh_${laIndex}_of_${la.length}'),
                                    lang: laItem,
                                    currentSelected: _model.selected,
                                    callbackAction: (selectedLangData) async {
                                      _model.selected = null;
                                      _model.selected = selectedLangData;
                                      safeSetState(() {});
                                    },
                                  );
                                },
                              );
                            },
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
        wrapWithModel(
          model: _model.buttonModel,
          updateCallback: () => safeSetState(() {}),
          child: ButtonWidget(
            text: 'Сохранить',
            action: () async {
              setAppLanguage(context, _model.selected!.code);
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}
