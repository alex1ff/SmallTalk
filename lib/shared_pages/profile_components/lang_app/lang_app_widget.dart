import '/authorization/components/language_card/language_card_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
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

  void _saveLanguage() {
    setAppLanguage(context, _model.selected!.code);
    Navigator.pop(context);
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
                    color: ExpatlioDesign.card,
                  ),
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 35.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        BottomSheetHeader(
                          title: FFLocalizations.of(context).getText(
                            '2wr6p6ar' /* Язык приложения */,
                          ),
                          onConfirm: _saveLanguage,
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
      ],
    );
  }
}
