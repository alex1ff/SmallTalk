import '/auth/firebase_auth/auth_util.dart';
import '/authorization/shared/social_auth_entry_logic.dart';
import '/authorization/shared/social_auth_progress_overlay.dart';
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

const loginAppleButtonKey = ValueKey<String>('login_apple_button');
const loginGoogleButtonKey = ValueKey<String>('login_google_button');

class LoginWidget extends StatefulWidget {
  const LoginWidget({
    super.key,
    this.emailSignInOverride,
  });

  final Future<BaseAuthUser?> Function(
    BuildContext context,
    String email,
    String password,
  )? emailSignInOverride;

  static String routeName = 'Login';
  static String routePath = '/login';

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  late LoginModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSubmittingEmailLogin = false;
  bool _isSubmittingSocialAuth = false;
  OverlayEntry? _socialAuthProgressEntry;

  void _showSocialAuthProgress() {
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: SocialAuthProgressOverlay(
          title: FFLocalizations.of(context).getVariableText(
            ruText: 'Завершаем вход…',
            enText: 'Finishing sign-in…',
          ),
          message: FFLocalizations.of(context).getVariableText(
            ruText: 'Загружаем ваш профиль. Это займет несколько секунд.',
            enText: 'Loading your profile. This may take a few seconds.',
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    _socialAuthProgressEntry = entry;
  }

  void _hideSocialAuthProgress() {
    final entry = _socialAuthProgressEntry;
    _socialAuthProgressEntry = null;
    entry?.remove();
    entry?.dispose();
  }

  Future<void> _handleSocialAuth({
    required Future<BaseAuthUser?> Function() signInAction,
    required String providerId,
  }) async {
    if (_isSubmittingSocialAuth || _isSubmittingEmailLogin) {
      return;
    }

    safeSetState(() => _isSubmittingSocialAuth = true);
    var navigationStarted = false;
    try {
      _showSocialAuthProgress();
      beginPendingSocialAuthContext(
        providerId: providerId,
        sourceScreen: LoginWidget.routeName,
        nativeSpeakerIntent: false,
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
          _localized(
            ru: 'Не удалось определить аккаунт',
            en: 'Could not identify the account',
          ),
          '',
          true,
        );
        return;
      }

      attachPendingSocialAuthUid(resolvedUserUid);
      final decision = await resolveAndPersistSocialAuthEntry(
        nativeSpeakerIntent: false,
        authUserUid: resolvedUserUid,
      );
      if (!mounted) {
        return;
      }
      if (decision == null) {
        clearPendingSocialAuthContext();
        await actions.showTopNotification(
          context,
          _localized(
            ru: 'Не удалось загрузить профиль',
            en: 'Could not load your profile',
          ),
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
          navigationStarted = true;
          return;
        case SocialAuthEntryDestination.acquaintanceNativeSpeaker:
          context.goNamedAuth(
            AcquaintanceNSWidget.routeName,
            context.mounted,
            queryParameters: {
              'index': serializeParam(0, ParamType.int),
            }.withoutNulls,
          );
          navigationStarted = true;
          return;
        case SocialAuthEntryDestination.acquaintanceStudent:
          context.goNamedAuth(
            AcquaintanceSTUDENTWidget.routeName,
            context.mounted,
            queryParameters: {
              'index': serializeParam(0, ParamType.int),
            }.withoutNulls,
          );
          navigationStarted = true;
          return;
      }
    } catch (_) {
      clearPendingSocialAuthContext();
      if (mounted) {
        await actions.showTopNotification(
          context,
          _localized(
            ru: 'Не удалось завершить вход',
            en: 'Could not complete sign-in',
          ),
          '',
          true,
        );
      }
    } finally {
      if (!navigationStarted) {
        _hideSocialAuthProgress();
        if (mounted) {
          safeSetState(() => _isSubmittingSocialAuth = false);
        }
      }
    }
  }

  String _localized({required String ru, required String en}) =>
      FFLocalizations.of(context).getVariableText(ruText: ru, enText: en);

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
    _hideSocialAuthProgress();
    _model.dispose();

    super.dispose();
  }

  Future<void> _submitEmailLogin() async {
    if (_isSubmittingEmailLogin || _isSubmittingSocialAuth) {
      return;
    }
    safeSetState(() => _isSubmittingEmailLogin = true);
    try {
      if (!functions.isValidEmail(_model.emailTextController.text)) {
        await actions.showTopNotification(
          context,
          _localized(ru: 'Неверный e-mail', en: 'Invalid email address'),
          '',
          true,
        );
        return;
      }

      final signIn = widget.emailSignInOverride;
      if (signIn == null) {
        GoRouter.of(context).prepareAuthEvent();
      }
      final user = signIn != null
          ? await signIn(
              context,
              _model.emailTextController.text,
              _model.passTextController.text,
            )
          : await authManager.signInWithEmail(
              context,
              _model.emailTextController.text,
              _model.passTextController.text,
            );
      if (user == null || !mounted) {
        return;
      }

      context.goNamedAuth(LoadingWidget.routeName, context.mounted);
    } finally {
      if (mounted) {
        safeSetState(() => _isSubmittingEmailLogin = false);
      }
    }
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
        const SizedBox(height: ExpatlioDesign.space8),
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
    required Key buttonKey,
    required Widget icon,
    required String label,
    required Future<void> Function() onTap,
    required bool enabled,
  }) {
    return Expanded(
      child: Semantics(
        key: buttonKey,
        container: true,
        button: true,
        enabled: enabled,
        label: label,
        onTap: enabled ? onTap : null,
        child: ExcludeSemantics(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: enabled ? 1 : 0.55,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(ExpatlioDesign.radiusMedium),
                onTap: enabled ? onTap : null,
                child: Container(
                  height: ExpatlioDesign.buttonHeight,
                  decoration: ExpatlioDesign.cardDecoration(radius: 12.0),
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space12,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space16,
                      ExpatlioDesign.space0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon,
                      const SizedBox(width: ExpatlioDesign.space8),
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
          ),
        ),
      ),
    );
  }

  bool get _isAuthBusy => _isSubmittingEmailLogin || _isSubmittingSocialAuth;

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
                    ExpatlioDesign.space16,
                    ExpatlioDesign.space24,
                    ExpatlioDesign.space16,
                    ExpatlioDesign.space24),
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
                        cacheWidth: 984,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: ExpatlioDesign.space32),
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
                            const SizedBox(height: ExpatlioDesign.space8),
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
                            const SizedBox(height: ExpatlioDesign.space20),
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
                                  const SizedBox(
                                      height: ExpatlioDesign.space12),
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
                                ],
                              ),
                            ),
                            Align(
                              alignment: AlignmentDirectional(1.0, 0.0),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                    ExpatlioDesign.radiusMedium),
                                onTap: () async {
                                  context
                                      .pushNamed(RecoverPassWidget.routeName);
                                },
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                    ExpatlioDesign.space12,
                                    ExpatlioDesign.space12,
                                    ExpatlioDesign.space0,
                                    ExpatlioDesign.space12,
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
                              busy: _isSubmittingEmailLogin,
                              action: _submitEmailLogin,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: ExpatlioDesign.space20),
                      Row(
                        children: [
                          _buildSocialButton(
                            buttonKey: loginAppleButtonKey,
                            icon: Icon(
                              Icons.apple,
                              color: ExpatlioDesign.text,
                              size: 22.0,
                            ),
                            label: FFLocalizations.of(context).getText(
                              'v2qj45ju' /* Apple */,
                            ),
                            enabled: !_isAuthBusy,
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
                          const SizedBox(width: ExpatlioDesign.space12),
                          _buildSocialButton(
                            buttonKey: loginGoogleButtonKey,
                            icon: const FaIcon(
                              FontAwesomeIcons.google,
                              color: ExpatlioDesign.text,
                              size: 18.0,
                            ),
                            label: FFLocalizations.of(context).getText(
                              'gfc8qlqz' /* Google */,
                            ),
                            enabled: !_isAuthBusy,
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
                      const SizedBox(height: ExpatlioDesign.space24),
                      InkWell(
                        borderRadius:
                            BorderRadius.circular(ExpatlioDesign.radiusMedium),
                        onTap: () async {
                          context.pushNamed(RegistrationWidget.routeName);
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
