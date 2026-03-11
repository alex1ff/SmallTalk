import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/profile_components/chip/chip_widget.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'rate_app_model.dart';
export 'rate_app_model.dart';

class RateAppWidget extends StatefulWidget {
  const RateAppWidget({super.key});

  @override
  State<RateAppWidget> createState() => _RateAppWidgetState();
}

class _RateAppWidgetState extends State<RateAppWidget> {
  late RateAppModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RateAppModel());

    _model.nameTextController ??= TextEditingController();
    _model.nameFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

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
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        valueOrDefault<String>(
                          _model.pageViewCurrentIndex == 0
                              ? FFLocalizations.of(context).getVariableText(
                                  ruText: 'Как общее впечатление?',
                                  enText: 'What\'s the overall impression?',
                                )
                              : FFLocalizations.of(context).getVariableText(
                                  ruText: 'Спасибо, что поделились!',
                                  enText: 'Thanks!',
                                ),
                          'Как общее впечатление?',
                        ),
                        textAlign: TextAlign.start,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Cool',
                              fontSize: 26.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
                            ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 16.0, 0.0, 0.0),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 40.0),
                              child: PageView(
                                physics: const NeverScrollableScrollPhysics(),
                                controller: _model.pageViewController ??=
                                    PageController(initialPage: 0),
                                onPageChanged: (_) => safeSetState(() {}),
                                scrollDirection: Axis.horizontal,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        6.0, 0.0, 6.0, 0.0),
                                    child: SingleChildScrollView(
                                      primary: false,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          wrapWithModel(
                                            model: _model.chipModel1,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipWidget(
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                'zdoma2f2' /* Мне всё нравится */,
                                              ),
                                              currentSelected: _model.chips,
                                              img:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/m3l806hbtb67/%E2%9C%88%EF%B8%8F.png',
                                              callbackAction: (selected) async {
                                                _model.chips = selected;
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model.chipModel2,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipWidget(
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                'l6e566yv' /* Классный дизайн */,
                                              ),
                                              currentSelected: _model.chips,
                                              img:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/m3l806hbtb67/%E2%9C%88%EF%B8%8F.png',
                                              callbackAction: (selected) async {
                                                _model.chips = selected;
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model.chipModel3,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipWidget(
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                '5ptxzwam' /* В приложении сложно разобратьс... */,
                                              ),
                                              currentSelected: _model.chips,
                                              img:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/m3l806hbtb67/%E2%9C%88%EF%B8%8F.png',
                                              callbackAction: (selected) async {
                                                _model.chips = selected;
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model.chipModel4,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipWidget(
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                'j8iejnb0' /* Есть технические проблемы */,
                                              ),
                                              currentSelected: _model.chips,
                                              img:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/m3l806hbtb67/%E2%9C%88%EF%B8%8F.png',
                                              callbackAction: (selected) async {
                                                _model.chips = selected;
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model.chipModel5,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipWidget(
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                '95l4bk9r' /* Не хватает некоторых функций */,
                                              ),
                                              currentSelected: _model.chips,
                                              img:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/m3l806hbtb67/%E2%9C%88%EF%B8%8F.png',
                                              callbackAction: (selected) async {
                                                _model.chips = selected;
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 10.0, 0.0, 0.0),
                                            child: Container(
                                              width: double.infinity,
                                              child: TextFormField(
                                                controller:
                                                    _model.nameTextController,
                                                focusNode: _model.nameFocusNode,
                                                autofocus: false,
                                                textCapitalization:
                                                    TextCapitalization
                                                        .sentences,
                                                textInputAction:
                                                    TextInputAction.done,
                                                obscureText: false,
                                                decoration: InputDecoration(
                                                  isDense: false,
                                                  hintText: FFLocalizations.of(
                                                          context)
                                                      .getText(
                                                    'lu693psw' /* Что нравится, а что нет... */,
                                                  ),
                                                  hintStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 16.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            26.0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            26.0),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            26.0),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            26.0),
                                                  ),
                                                  filled: true,
                                                  fillColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground,
                                                  contentPadding:
                                                      EdgeInsets.all(16.0),
                                                  hoverColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          fontSize: 16.0,
                                                          letterSpacing: 0.0,
                                                        ),
                                                maxLines: 12,
                                                minLines: 4,
                                                cursorColor:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                enableInteractiveSelection:
                                                    true,
                                                validator: _model
                                                    .nameTextControllerValidator
                                                    .asValidator(context),
                                                inputFormatters: [
                                                  if (!isAndroid && !isiOS)
                                                    TextInputFormatter
                                                        .withFunction((oldValue,
                                                            newValue) {
                                                      return TextEditingValue(
                                                        selection:
                                                            newValue.selection,
                                                        text: newValue.text
                                                            .toCapitalization(
                                                                TextCapitalization
                                                                    .sentences),
                                                      );
                                                    }),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ].divide(SizedBox(height: 6.0)),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        24.0, 24.0, 24.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        'nymvvzvm' /* Мы читаем каждое сообщение. Ес... */,
                                      ),
                                      textAlign: TextAlign.start,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            lineHeight: 1.5,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ].addToStart(SizedBox(height: 16.0)),
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedPadding(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: EdgeInsetsDirectional.fromSTEB(
              0.0, 0.0, 6.0, keyboardVisible ? 6.0 : 35.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: wrapWithModel(
                  model: _model.buttonModel,
                  updateCallback: () => safeSetState(() {}),
                  child: ButtonWidget(
                    text: valueOrDefault<String>(
                      _model.pageViewCurrentIndex == 0
                          ? FFLocalizations.of(context).getVariableText(
                              ruText: 'Отправить',
                              enText: 'Send',
                            )
                          : FFLocalizations.of(context).getVariableText(
                              ruText: 'Всегда пожайлуста',
                              enText: 'Done',
                            ),
                      'Отправить',
                    ),
                    loadingText: _model.pageViewCurrentIndex == 0
                        ? FFLocalizations.of(context).getVariableText(
                            ruText: 'Отправляем...',
                            enText: 'Sending...',
                          )
                        : null,
                    keyboardAwarePadding: false,
                    padding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
                    busyStyle: _model.pageViewCurrentIndex == 0
                        ? ButtonBusyStyle.spinner
                        : ButtonBusyStyle.debounceOnly,
                    action: () async {
                      if (_model.nameTextController.text != '') {
                        if (_model.pageViewCurrentIndex == 0) {
                          await RewiewsOfTheAppRecord.collection
                              .doc()
                              .set(createRewiewsOfTheAppRecordData(
                                chips: _model.chips,
                                comment: _model.nameTextController.text,
                                date: getCurrentTimestamp,
                                user: currentUserReference,
                              ));
                          await _model.pageViewController?.nextPage(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.ease,
                          );
                        } else {
                          Navigator.pop(context);
                          return;
                        }
                      } else {
                        await actions.showTopNotification(
                          context,
                          'Напишите хотя бы пару слов',
                          '',
                          true,
                        );
                        return;
                      }
                    },
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 7.0,
                      color: Color(0x0D2C2C2C),
                      offset: Offset(
                        0.0,
                        2.0,
                      ),
                    )
                  ],
                  shape: BoxShape.circle,
                ),
                child: FlutterFlowIconButton(
                  borderRadius: 50.0,
                  buttonSize: 60.0,
                  fillColor: FlutterFlowTheme.of(context).primaryBackground,
                  icon: Icon(
                    Icons.close_sharp,
                    color: FlutterFlowTheme.of(context).error,
                    size: 20.0,
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
