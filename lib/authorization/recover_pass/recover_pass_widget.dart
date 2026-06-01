import '/auth/firebase_auth/auth_util.dart';
import '/components/send_widget.dart';
import '/components/button/button_widget.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'recover_pass_model.dart';
export 'recover_pass_model.dart';

class RecoverPassWidget extends StatefulWidget {
  const RecoverPassWidget({super.key});

  static String routeName = 'Recover_pass';
  static String routePath = '/recoverPass';

  @override
  State<RecoverPassWidget> createState() => _RecoverPassWidgetState();
}

class _RecoverPassWidgetState extends State<RecoverPassWidget> {
  late RecoverPassModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RecoverPassModel());

    _model.emailTextController ??= TextEditingController();
    _model.emailFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<void> _submitPasswordReset() async {
    if (_model.emailTextController.text.isEmpty) {
      await actions.showTopNotification(
        context,
        FFLocalizations.of(context).getText(
          'rizvdi40' /* Почта не заполнена */,
        ),
        '',
        true,
      );
      return;
    }

    if (!functions.isValidEmail(_model.emailTextController.text)) {
      await actions.showTopNotification(
        context,
        'Неверный e-mail',
        '',
        true,
      );
      return;
    }

    await authManager.resetPassword(
      email: _model.emailTextController.text,
      context: context,
    );
    if (!mounted) {
      return;
    }

    await showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Padding(
            padding: MediaQuery.viewInsetsOf(context),
            child: SendWidget(),
          ),
        );
      },
    ).then((value) => safeSetState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final title = FFLocalizations.of(context)
        .getText(
          'hu56u2hq' /* Восстановить пароль */,
        )
        .replaceAll('\n', ' ');

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: ExpatlioDesign.background,
        body: Column(
          children: [
            BasicPageHeader(title: title),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space16,
                  ExpatlioDesign.space24,
                  ExpatlioDesign.space16,
                  ExpatlioDesign.space24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      FFLocalizations.of(context).getText(
                        '8ty2g5mk' /* Введите e-mail, указанный при регистрации */,
                      ),
                      textAlign: TextAlign.center,
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: ExpatlioDesign.muted,
                        size: 15.0,
                        weight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space20),
                    Container(
                      decoration: ExpatlioDesign.formGroupDecoration(),
                      padding: ExpatlioDesign.formGroupPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            FFLocalizations.of(context).getText(
                              'w8edaady' /* E-mail */,
                            ),
                            style: ExpatlioDesign.formLabelStyle(context),
                          ),
                          const SizedBox(height: ExpatlioDesign.space8),
                          SizedBox(
                            height: ExpatlioDesign.formFieldHeight,
                            child: TextFormField(
                              controller: _model.emailTextController,
                              focusNode: _model.emailFocusNode,
                              onFieldSubmitted: (_) async {
                                await _submitPasswordReset();
                              },
                              autofocus: false,
                              textInputAction: TextInputAction.done,
                              textAlignVertical: TextAlignVertical.center,
                              obscureText: false,
                              decoration:
                                  ExpatlioDesign.formFieldDecoration(context),
                              style: ExpatlioDesign.formTextStyle(context),
                              keyboardType: TextInputType.emailAddress,
                              cursorColor: ExpatlioDesign.primary,
                              enableInteractiveSelection: true,
                              validator: _model.emailTextControllerValidator
                                  .asValidator(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space16),
                    wrapWithModel(
                      model: _model.buttonModel,
                      updateCallback: () => safeSetState(() {}),
                      child: ButtonWidget(
                        text: FFLocalizations.of(context).getText(
                          '4rn5krnl' /* Отправить */,
                        ),
                        loadingText:
                            FFLocalizations.of(context).getVariableText(
                          ruText: 'Отправляем...',
                          enText: 'Sending...',
                        ),
                        busyStyle: ButtonBusyStyle.spinner,
                        action: _submitPasswordReset,
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space20),
                    InkWell(
                      borderRadius:
                          BorderRadius.circular(ExpatlioDesign.radiusMedium),
                      onTap: () async {
                        context.pushNamed(PolicyWidget.routeName);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ExpatlioDesign.space8),
                        child: RichText(
                          textScaler: MediaQuery.of(context).textScaler,
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: FFLocalizations.of(context).getText(
                                  'bzzxmn6e' /* Нажимая кнопку "Отправить", вы соглашаетесь с */,
                                ),
                                style: ExpatlioDesign.textStyle(
                                  context,
                                  color: ExpatlioDesign.muted,
                                  size: 13.0,
                                  weight: FontWeight.w400,
                                ),
                              ),
                              TextSpan(
                                text: FFLocalizations.of(context).getText(
                                  'vgscvvlj' /* Политики конфиденциальности */,
                                ),
                                style: ExpatlioDesign.textStyle(
                                  context,
                                  size: 13.0,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space24),
                    InkWell(
                      borderRadius:
                          BorderRadius.circular(ExpatlioDesign.radiusMedium),
                      onTap: () async {
                        context.safePop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(ExpatlioDesign.space8),
                        child: RichText(
                          textScaler: MediaQuery.of(context).textScaler,
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: FFLocalizations.of(context).getText(
                                  '5judxscj' /* Вспомнили пароль?  */,
                                ),
                                style: ExpatlioDesign.textStyle(
                                  context,
                                  color: ExpatlioDesign.muted,
                                  size: 15.0,
                                  weight: FontWeight.w400,
                                ),
                              ),
                              TextSpan(
                                text: FFLocalizations.of(context).getText(
                                  '7r35sif1' /* Вернуться */,
                                ),
                                style: ExpatlioDesign.textStyle(
                                  context,
                                  color: ExpatlioDesign.primary,
                                  size: 15.0,
                                  weight: FontWeight.w700,
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
            ),
          ],
        ),
      ),
    );
  }
}
