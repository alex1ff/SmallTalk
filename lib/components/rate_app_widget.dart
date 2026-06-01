import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/components/wrapper.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/components/chip_widget.dart';
import '/custom_code/actions/index.dart' as actions;
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

  Future<void> _submitReview() async {
    if (_model.pageViewCurrentIndex != 0) {
      Navigator.pop(context);
      return;
    }
    if (_model.nameTextController.text == '') {
      await actions.showTopNotification(
        context,
        'Напишите хотя бы пару слов',
        '',
        true,
      );
      return;
    }
    await RewiewsOfTheAppRecord.collection.doc().set(
          createRewiewsOfTheAppRecordData(
            chips: _model.chips,
            comment: _model.nameTextController.text,
            date: getCurrentTimestamp,
            user: currentUserReference,
          ),
        );
    await _model.pageViewController?.nextPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional(0.0, 1.0),
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space0,
              ExpatlioDesign.space56,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: ExpatlioDesign.card,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      BottomSheetHeader(
                        title: valueOrDefault<String>(
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
                        onConfirm: _submitReview,
                        showConfirm: false,
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space16,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  ExpatlioDesign.space0,
                                  ExpatlioDesign.space0,
                                  ExpatlioDesign.space0,
                                  ExpatlioDesign.space112),
                              child: PageView(
                                physics: const NeverScrollableScrollPhysics(),
                                controller: _model.pageViewController ??=
                                    PageController(initialPage: 0),
                                onPageChanged: (_) => safeSetState(() {}),
                                scrollDirection: Axis.horizontal,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        ExpatlioDesign.space8,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space8,
                                        ExpatlioDesign.space0),
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
                                              icon: Icons.favorite_rounded,
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
                                              icon: Icons.palette_rounded,
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
                                              icon: Icons.help_outline_rounded,
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
                                              icon: Icons.bug_report_rounded,
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
                                              icon: Icons.extension_rounded,
                                              callbackAction: (selected) async {
                                                _model.chips = selected;
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    ExpatlioDesign.space0,
                                                    ExpatlioDesign.space12,
                                                    ExpatlioDesign.space0,
                                                    ExpatlioDesign.space0),
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
                                                decoration: ExpatlioDesign
                                                    .formFieldDecoration(
                                                  context,
                                                  hintText: FFLocalizations.of(
                                                          context)
                                                      .getText(
                                                    'lu693psw' /* Что нравится, а что нет... */,
                                                  ),
                                                  maxLines: 12,
                                                ),
                                                style: ExpatlioDesign
                                                    .formTextStyle(context),
                                                maxLines: 12,
                                                minLines: 4,
                                                cursorColor:
                                                    ExpatlioDesign.primary,
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
                                        ].divide(SizedBox(
                                            height: ExpatlioDesign.space8)),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        ExpatlioDesign.space24,
                                        ExpatlioDesign.space24,
                                        ExpatlioDesign.space24,
                                        ExpatlioDesign.space0),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        wrapWithModel(
          model: _model.buttonModel,
          updateCallback: () => safeSetState(() {}),
          child: Wrapper.keyboardAware(
            child: ButtonWidget(
              text: _model.pageViewCurrentIndex == 0
                  ? FFLocalizations.of(context).getVariableText(
                      ruText: 'Отправить',
                      enText: 'Send',
                    )
                  : FFLocalizations.of(context).getVariableText(
                      ruText: 'Готово',
                      enText: 'Done',
                    ),
              loadingText: _model.pageViewCurrentIndex == 0
                  ? FFLocalizations.of(context).getVariableText(
                      ruText: 'Отправляем...',
                      enText: 'Sending...',
                    )
                  : null,
              busyStyle: ButtonBusyStyle.spinner,
              action: _submitReview,
            ),
          ),
        ),
      ],
    );
  }
}
