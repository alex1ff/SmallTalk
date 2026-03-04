import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'login_model.dart';
export 'login_model.dart';

class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  static String routeName = 'Login';
  static String routePath = '/login';

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  late LoginModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginModel());

    _model.emailTextController ??= TextEditingController();
    _model.emailFocusNode ??= FocusNode();

    _model.passTextController ??= TextEditingController();
    _model.passFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(6.0, 55.0, 6.0, 0.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                height: 70.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  borderRadius: BorderRadius.circular(100.0),
                ),
                child: Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 66.0,
                        height: 66.0,
                        decoration: BoxDecoration(
                          color: Color(0xFFE88CD4),
                          shape: BoxShape.circle,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                10.0, 8.0, 10.0, 2.0),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                              alignment: Alignment(0.0, -0.2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 6.0, 0.0, 0.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primaryBackground,
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FFLocalizations.of(context).getText(
                            '6941br49' /* Вход */,
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Cool',
                                    color: FlutterFlowTheme.of(context).primary,
                                    fontSize: 55.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                    lineHeight: 1.0,
                                  ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 12.0, 0.0, 0.0),
                          child: AutoSizeText(
                            FFLocalizations.of(context).getText(
                              '0i8b54sx' /* Введи адрес электронной почты ... */,
                            ),
                            maxLines: 2,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'sf pro display',
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  fontSize: 15.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 6.0, 0.0, 0.0),
                child: Container(
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
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            shape: BoxShape.circle,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional(0.0, 0.0),
                            child: Icon(
                              FFIcons.kmail01,
                              color: FlutterFlowTheme.of(context).primaryText,
                              size: 20.0,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                8.0, 0.0, 8.0, 0.0),
                            child: Container(
                              width: double.infinity,
                              child: TextFormField(
                                controller: _model.emailTextController,
                                focusNode: _model.emailFocusNode,
                                autofocus: false,
                                textInputAction: TextInputAction.next,
                                obscureText: false,
                                decoration: InputDecoration(
                                  isDense: false,
                                  labelText:
                                      FFLocalizations.of(context).getText(
                                    'vbj759aa' /* E-mail */,
                                  ),
                                  labelStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'sf pro display',
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        fontSize: 16.0,
                                        letterSpacing: 0.0,
                                      ),
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'sf pro display',
                                      fontSize: 16.0,
                                      letterSpacing: 0.0,
                                    ),
                                keyboardType: TextInputType.emailAddress,
                                cursorColor:
                                    FlutterFlowTheme.of(context).primaryText,
                                enableInteractiveSelection: true,
                                validator: _model.emailTextControllerValidator
                                    .asValidator(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 6.0, 0.0, 0.0),
                child: Container(
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
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            shape: BoxShape.circle,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional(0.0, 0.0),
                            child: Icon(
                              FFIcons.klockUnlocked01,
                              color: FlutterFlowTheme.of(context).primaryText,
                              size: 20.0,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                8.0, 0.0, 8.0, 0.0),
                            child: Container(
                              width: double.infinity,
                              child: TextFormField(
                                controller: _model.passTextController,
                                focusNode: _model.passFocusNode,
                                onFieldSubmitted: (_) async {
                                  Function() _navigate = () {};
                                  if (functions.isValidEmail(
                                      _model.emailTextController.text)) {
                                    GoRouter.of(context).prepareAuthEvent();

                                    final user =
                                        await authManager.signInWithEmail(
                                      context,
                                      _model.emailTextController.text,
                                      _model.passTextController.text,
                                    );
                                    if (user == null) {
                                      return;
                                    }

                                    _navigate = () => context.goNamedAuth(
                                        LoadingWidget.routeName,
                                        context.mounted);
                                  } else {
                                    await actions.showTopNotification(
                                      context,
                                      'Неверный e-mail',
                                      '',
                                      true,
                                    );
                                    return;
                                  }

                                  _navigate();
                                },
                                autofocus: false,
                                textInputAction: TextInputAction.done,
                                obscureText: !_model.passVisibility,
                                decoration: InputDecoration(
                                  isDense: false,
                                  labelText:
                                      FFLocalizations.of(context).getText(
                                    'p6wbbfql' /* Пароль */,
                                  ),
                                  labelStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'sf pro display',
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        fontSize: 16.0,
                                        letterSpacing: 0.0,
                                      ),
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  suffixIcon: InkWell(
                                    onTap: () => safeSetState(
                                      () => _model.passVisibility =
                                          !_model.passVisibility,
                                    ),
                                    focusNode: FocusNode(skipTraversal: true),
                                    child: Icon(
                                      _model.passVisibility
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      size: 20.0,
                                    ),
                                  ),
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'sf pro display',
                                      fontSize: 16.0,
                                      letterSpacing: 0.0,
                                    ),
                                cursorColor:
                                    FlutterFlowTheme.of(context).primaryText,
                                enableInteractiveSelection: true,
                                validator: _model.passTextControllerValidator
                                    .asValidator(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional(1.0, 0.0),
                child: FFButtonWidget(
                  onPressed: () async {
                    context.pushNamed(RecoverPassWidget.routeName);
                  },
                  text: FFLocalizations.of(context).getText(
                    'c1a5gcpy' /* Забыли пароль? */,
                  ),
                  options: FFButtonOptions(
                    height: 35.0,
                    padding:
                        EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 12.0, 0.0),
                    iconPadding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                    color: Colors.transparent,
                    textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                          fontFamily: 'sf pro display',
                          color: FlutterFlowTheme.of(context).secondaryText,
                          fontSize: 14.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.normal,
                        ),
                    elevation: 0.0,
                    borderRadius: BorderRadius.circular(60.0),
                  ),
                  showLoadingIndicator: false,
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 60.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryText,
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    16.0, 0.0, 0.0, 0.0),
                                child: Text(
                                  FFLocalizations.of(context).getText(
                                    '8x9f21aa' /* Далее */,
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'Cool',
                                        color: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        fontSize: 20.0,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                              ),
                            ),
                            Container(
                              width: 56.0,
                              height: 56.0,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                shape: BoxShape.circle,
                              ),
                              child: Align(
                                alignment: AlignmentDirectional(0.0, 0.0),
                                child: Icon(
                                  FFIcons.karrowRight,
                                  color: Colors.black,
                                  size: 20.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FFButtonWidget(
                      onPressed: () async {
                        Function() _navigate = () {};
                        if (functions
                            .isValidEmail(_model.emailTextController.text)) {
                          GoRouter.of(context).prepareAuthEvent();

                          final user = await authManager.signInWithEmail(
                            context,
                            _model.emailTextController.text,
                            _model.passTextController.text,
                          );
                          if (user == null) {
                            return;
                          }

                          _navigate = () => context.goNamedAuth(
                              LoadingWidget.routeName, context.mounted);
                        } else {
                          await actions.showTopNotification(
                            context,
                            'Неверный e-mail',
                            '',
                            true,
                          );
                          return;
                        }

                        _navigate();
                      },
                      text: FFLocalizations.of(context).getText(
                        'b7eijuxv' /*   */,
                      ),
                      options: FFButtonOptions(
                        width: double.infinity,
                        height: 60.0,
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        iconPadding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color: Colors.transparent,
                        textStyle:
                            FlutterFlowTheme.of(context).titleSmall.override(
                                  fontFamily: 'sf pro display',
                                  color: Colors.white,
                                  letterSpacing: 0.0,
                                ),
                        elevation: 0.0,
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      showLoadingIndicator: false,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    InkWell(
                      splashColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () async {
                        context.pushNamed(PolicyWidget.routeName);
                      },
                      child: RichText(
                        textScaler: MediaQuery.of(context).textScaler,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: FFLocalizations.of(context).getText(
                                'tl1j359o' /* Пользуясь приложением, вы согл... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    fontSize: 14.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                            TextSpan(
                              text: FFLocalizations.of(context).getText(
                                '7ami3ujs' /* Политикой конфиденциальности  */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 14.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                            )
                          ],
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: 'sf pro display',
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                              ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 60.0,
                          decoration: BoxDecoration(
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(100.0),
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56.0,
                                      height: 56.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Align(
                                        alignment: AlignmentDirectional(0.0, 0.0),
                                        child: Icon(
                                          Icons.apple,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 24.0,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          8.0, 0.0, 18.0, 0.0),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          'v2qj45ju' /* Apple */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color: FlutterFlowTheme.of(context)
                                                  .primaryText,
                                              fontSize: 16.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FFButtonWidget(
                                onPressed: () async {
                                  if (isAndroid) {
                                    showSnackbar(
                                      context,
                                      FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText:
                                            'Вход через Apple доступен только на iOS.',
                                        enText:
                                            'Apple Sign-In is available on iOS only.',
                                      ),
                                    );
                                    return;
                                  }

                                  GoRouter.of(context).prepareAuthEvent();
                                  final user =
                                      await authManager.signInWithApple(context);
                                  if (user == null) {
                                    return;
                                  }

                                  context.goNamedAuth(
                                      LoadingWidget.routeName, context.mounted);
                                },
                                text: FFLocalizations.of(context).getText(
                                  'zga53c5g' /*  */,
                                ),
                                options: FFButtonOptions(
                                  width: 125.0,
                                  height: 60.0,
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 0.0),
                                  iconPadding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 0.0),
                                  color: Colors.transparent,
                                  textStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .override(
                                        fontFamily: 'sf pro display',
                                        color: Colors.transparent,
                                        letterSpacing: 0.0,
                                      ),
                                  elevation: 0.0,
                                  borderRadius: BorderRadius.circular(50.0),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 60.0,
                          decoration: BoxDecoration(
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(100.0),
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56.0,
                                      height: 56.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Align(
                                        alignment: AlignmentDirectional(0.0, 0.0),
                                        child: FaIcon(
                                          FontAwesomeIcons.google,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 18.0,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          8.0, 0.0, 18.0, 0.0),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          'gfc8qlqz' /* Google */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color: FlutterFlowTheme.of(context)
                                                  .primaryText,
                                              fontSize: 16.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FFButtonWidget(
                                onPressed: () async {
                                  GoRouter.of(context).prepareAuthEvent();
                                  final user =
                                      await authManager.signInWithGoogle(context);
                                  if (user == null) {
                                    return;
                                  }

                                  context.goNamedAuth(LoadingWidget.routeName,
                                      context.mounted);
                                },
                                text: FFLocalizations.of(context).getText(
                                  'vj9omtyq' /*  */,
                                ),
                                options: FFButtonOptions(
                                  width: 131.03,
                                  height: 60.0,
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 0.0),
                                  iconPadding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 0.0),
                                  color: Colors.transparent,
                                  textStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .override(
                                        fontFamily: 'sf pro display',
                                        color: Colors.transparent,
                                        letterSpacing: 0.0,
                                      ),
                                  elevation: 0.0,
                                  borderRadius: BorderRadius.circular(50.0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ].divide(SizedBox(width: 6.0)),
                    ),
                    Spacer(),
                    InkWell(
                      splashColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () async {
                        context.pushNamed(RegistrationWidget.routeName);
                      },
                      child: RichText(
                        textScaler: MediaQuery.of(context).textScaler,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: FFLocalizations.of(context).getText(
                                'cpw39y3y' /* Нет аккаунта?  */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                            TextSpan(
                              text: FFLocalizations.of(context).getText(
                                'zdm7zlic' /* Зарегистрируйтесь */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context).primary,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                            )
                          ],
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: 'sf pro display',
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 16.0,
                                letterSpacing: 0.0,
                              ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
