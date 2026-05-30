import '/auth/firebase_auth/auth_util.dart';
import '/components/native_speaker_entry_toggle.dart';
import '/authorization/shared/social_auth_entry_logic.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import '/shared_pages/design/expatlio_design.dart';
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
  bool _isSubmittingSocialAuth = false;

  Future<void> _handleSocialAuth({
    required Future<BaseAuthUser?> Function() signInAction,
    required String providerId,
  }) async {
    if (_isSubmittingSocialAuth) {
      return;
    }

    _isSubmittingSocialAuth = true;
    try {
      beginPendingSocialAuthContext(
        providerId: providerId,
        sourceScreen: LoginWidget.routeName,
        nativeSpeakerIntent: _model.switchValue ?? false,
      );
      GoRouter.of(context).prepareAuthEvent();
      final user = await signInAction();
      if (user == null || !mounted) {
        clearPendingSocialAuthContext();
        return;
      }

      final resolvedUserUid = resolveAuthenticatedUserId(
        preferredUid: user.uid,
      );
      if (resolvedUserUid == null) {
        clearPendingSocialAuthContext();
        await actions.showTopNotification(
          context,
          'Не удалось определить аккаунт',
          '',
          true,
        );
        return;
      }

      attachPendingSocialAuthUid(resolvedUserUid);
      final decision = await resolveAndPersistSocialAuthEntry(
        nativeSpeakerIntent: _model.switchValue ?? false,
        authUserUid: resolvedUserUid,
      );
      if (!mounted) {
        return;
      }
      if (decision == null) {
        clearPendingSocialAuthContext();
        await actions.showTopNotification(
          context,
          'Не удалось загрузить профиль',
          '',
          true,
        );
        return;
      }

      await waitForAuthenticatedAppStateSync(
        authUserUid: resolvedUserUid,
      );
      if (!mounted) {
        return;
      }

      switch (decision.destination) {
        case SocialAuthEntryDestination.loading:
          context.goNamedAuth(LoadingWidget.routeName, context.mounted);
          return;
        case SocialAuthEntryDestination.acquaintanceNativeSpeaker:
          context.goNamedAuth(
            AcquaintanceNSWidget.routeName,
            context.mounted,
            queryParameters: {
              'index': serializeParam(0, ParamType.int),
            }.withoutNulls,
          );
          return;
        case SocialAuthEntryDestination.acquaintanceStudent:
          context.goNamedAuth(
            AcquaintanceSTUDENTWidget.routeName,
            context.mounted,
            queryParameters: {
              'index': serializeParam(0, ParamType.int),
            }.withoutNulls,
          );
          return;
      }
    } catch (_) {
      clearPendingSocialAuthContext();
      await actions.showTopNotification(
        context,
        'Не удалось завершить вход',
        '',
        true,
      );
    } finally {
      _isSubmittingSocialAuth = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginModel());

    _model.emailTextController ??= TextEditingController();
    _model.emailFocusNode ??= FocusNode();

    _model.passTextController ??= TextEditingController();
    _model.passFocusNode ??= FocusNode();
    _model.switchValue = false;
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<void> _submitEmailLogin() async {
    if (!functions.isValidEmail(_model.emailTextController.text)) {
      await actions.showTopNotification(
        context,
        'Неверный e-mail',
        '',
        true,
      );
      return;
    }

    GoRouter.of(context).prepareAuthEvent();
    final user = await authManager.signInWithEmail(
      context,
      _model.emailTextController.text,
      _model.passTextController.text,
    );
    if (user == null || !mounted) {
      return;
    }

    context.goNamedAuth(LoadingWidget.routeName, context.mounted);
  }

  Widget _buildAuthField({
    required TextEditingController? controller,
    required FocusNode? focusNode,
    required String label,
    required TextInputAction textInputAction,
    required String? Function(String?)? validator,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    Future<void> Function()? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ExpatlioDesign.formLabelStyle(context)),
        const SizedBox(height: 6.0),
        SizedBox(
          height: ExpatlioDesign.formFieldHeight,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            autofocus: false,
            textInputAction: textInputAction,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textAlignVertical: TextAlignVertical.center,
            onFieldSubmitted:
                onSubmitted == null ? null : (_) async => onSubmitted(),
            decoration: ExpatlioDesign.formFieldDecoration(
              context,
              suffixIcon: suffixIcon,
            ),
            style: ExpatlioDesign.formTextStyle(context),
            cursorColor: ExpatlioDesign.primary,
            enableInteractiveSelection: true,
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required Widget icon,
    required String label,
    required Future<void> Function() onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: onTap,
          child: Container(
            height: ExpatlioDesign.buttonHeight,
            decoration: ExpatlioDesign.cardDecoration(radius: 12.0),
            padding: const EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 14.0, 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 8.0),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: ExpatlioDesign.textStyle(
                      context,
                      size: 15.0,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        backgroundColor: ExpatlioDesign.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsetsDirectional.fromSTEB(
                    16.0, 22.0, 16.0, 24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 46.0,
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 226.0,
                        height: 82.0,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 28.0),
                      SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              FFLocalizations.of(context).getText(
                                '6941br49' /* Вход */,
                              ),
                              style: ExpatlioDesign.textStyle(
                                context,
                                size: 24.0,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6.0),
                            Text(
                              FFLocalizations.of(context).getText(
                                '0i8b54sx' /* Введи адрес электронной почты ... */,
                              ),
                              style: ExpatlioDesign.textStyle(
                                context,
                                color: ExpatlioDesign.muted,
                                size: 14.0,
                                weight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 18.0),
                            Container(
                              decoration: ExpatlioDesign.formGroupDecoration(),
                              padding: ExpatlioDesign.formGroupPadding,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildAuthField(
                                    controller: _model.emailTextController,
                                    focusNode: _model.emailFocusNode,
                                    label: FFLocalizations.of(context).getText(
                                      'vbj759aa' /* E-mail */,
                                    ),
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: _model
                                        .emailTextControllerValidator
                                        .asValidator(context),
                                  ),
                                  const SizedBox(height: 12.0),
                                  _buildAuthField(
                                    controller: _model.passTextController,
                                    focusNode: _model.passFocusNode,
                                    label: FFLocalizations.of(context).getText(
                                      'p6wbbfql' /* Пароль */,
                                    ),
                                    textInputAction: TextInputAction.done,
                                    obscureText: !_model.passVisibility,
                                    validator: _model
                                        .passTextControllerValidator
                                        .asValidator(context),
                                    onSubmitted: _submitEmailLogin,
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
                                        color: ExpatlioDesign.muted,
                                        size: 20.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12.0),
                                  NativeSpeakerEntryToggle(
                                    value: _model.switchValue ?? false,
                                    onChanged: (newValue) async {
                                      safeSetState(
                                          () => _model.switchValue = newValue);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Align(
                              alignment: AlignmentDirectional(1.0, 0.0),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12.0),
                                onTap: () async {
                                  context
                                      .pushNamed(RecoverPassWidget.routeName);
                                },
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                    12.0,
                                    10.0,
                                    0.0,
                                    12.0,
                                  ),
                                  child: Text(
                                    FFLocalizations.of(context).getText(
                                      'c1a5gcpy' /* Забыли пароль? */,
                                    ),
                                    style: ExpatlioDesign.textStyle(
                                      context,
                                      color: ExpatlioDesign.muted,
                                      size: 14.0,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ButtonWidget(
                              text: FFLocalizations.of(context).getText(
                                '8x9f21aa' /* Далее */,
                              ),
                              loadingText:
                                  FFLocalizations.of(context).getVariableText(
                                ruText: 'Входим...',
                                enText: 'Signing in...',
                              ),
                              busyStyle: ButtonBusyStyle.spinner,
                              action: _submitEmailLogin,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18.0),
                      Row(
                        children: [
                          _buildSocialButton(
                            icon: Icon(
                              Icons.apple,
                              color: ExpatlioDesign.text,
                              size: 22.0,
                            ),
                            label: FFLocalizations.of(context).getText(
                              'v2qj45ju' /* Apple */,
                            ),
                            onTap: () async {
                              if (isAndroid) {
                                showSnackbar(
                                  context,
                                  FFLocalizations.of(context).getVariableText(
                                    ruText:
                                        'Вход через Apple доступен только на iOS.',
                                    enText:
                                        'Apple Sign-In is available on iOS only.',
                                  ),
                                );
                                return;
                              }

                              await _handleSocialAuth(
                                signInAction: () =>
                                    authManager.signInWithApple(context),
                                providerId: 'apple.com',
                              );
                            },
                          ),
                          const SizedBox(width: 10.0),
                          _buildSocialButton(
                            icon: const FaIcon(
                              FontAwesomeIcons.google,
                              color: ExpatlioDesign.text,
                              size: 18.0,
                            ),
                            label: FFLocalizations.of(context).getText(
                              'gfc8qlqz' /* Google */,
                            ),
                            onTap: () async {
                              await _handleSocialAuth(
                                signInAction: () =>
                                    authManager.signInWithGoogle(context),
                                providerId: 'google.com',
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20.0),
                      InkWell(
                        borderRadius: BorderRadius.circular(12.0),
                        onTap: () async {
                          context.pushNamed(PolicyWidget.routeName);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: RichText(
                            textScaler: MediaQuery.of(context).textScaler,
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: FFLocalizations.of(context).getText(
                                    'tl1j359o' /* Пользуясь приложением, вы согл... */,
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
                                    '7ami3ujs' /* Политикой конфиденциальности  */,
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
                      const SizedBox(height: 22.0),
                      InkWell(
                        borderRadius: BorderRadius.circular(12.0),
                        onTap: () async {
                          context.pushNamed(RegistrationWidget.routeName);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: RichText(
                            textScaler: MediaQuery.of(context).textScaler,
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: FFLocalizations.of(context).getText(
                                    'cpw39y3y' /* Нет аккаунта?  */,
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
                                    'zdm7zlic' /* Зарегистрируйтесь */,
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
              );
            },
          ),
        ),
      ),
    );
  }
}
