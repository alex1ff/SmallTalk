import 'dart:async';

import '/auth/firebase_auth/auth_util.dart';
import '/components/native_speaker_entry_toggle.dart';
import '/authorization/shared/social_auth_entry_logic.dart';
import '/authorization/shared/social_auth_progress_overlay.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import '/services/email_verification_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'registration_model.dart';
export 'registration_model.dart';

class RegistrationWidget extends StatefulWidget {
  const RegistrationWidget({super.key});

  static String routeName = 'Registration';
  static String routePath = '/registration';

  @override
  State<RegistrationWidget> createState() => _RegistrationWidgetState();
}

class _RegistrationWidgetState extends State<RegistrationWidget> {
  late RegistrationModel _model;
  bool _isSubmittingEmailRegistration = false;
  bool _isSubmittingSocialAuth = false;
  OverlayEntry? _socialAuthProgressEntry;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  void _showSocialAuthProgress() {
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: SocialAuthProgressOverlay(
          title: FFLocalizations.of(context).getVariableText(
            ruText: 'Создаем аккаунт…',
            enText: 'Creating your account…',
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

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RegistrationModel());

    _model.emailTextController ??= TextEditingController();
    _model.emailFocusNode ??= FocusNode();

    _model.passTextController ??= TextEditingController();
    _model.passFocusNode ??= FocusNode();

    _model.switchValue = false;
  }

  @override
  void dispose() {
    _hideSocialAuthProgress();
    _model.dispose();

    super.dispose();
  }

  Future<void> _sendInitialEmailVerification() async {
    try {
      final result = await sendCustomEmailVerification(
        locale: FFLocalizations.of(context).languageCode,
        fallbackToFirebaseDefault: true,
      );
      if (!mounted || !result.sent) {
        return;
      }

      await actions.showTopNotification(
        context,
        FFLocalizations.of(context).getVariableText(
          ruText: 'Письмо для подтверждения отправлено',
          enText: 'Verification email has been sent',
        ),
        '',
        false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      await actions.showTopNotification(
        context,
        FFLocalizations.of(context).getVariableText(
          ruText: 'Email можно подтвердить позже',
          enText: 'You can verify email later',
        ),
        FFLocalizations.of(context).getVariableText(
          ruText: 'Отправьте письмо вручную из профиля.',
          enText: 'Send the email manually from your profile.',
        ),
        true,
      );
    }
  }

  Future<void> _handleEmailRegistration() async {
    if (_isSubmittingEmailRegistration) {
      return;
    }

    final email = _model.emailTextController.text.trim();
    if (!functions.isValidEmail(email)) {
      await actions.showTopNotification(
        context,
        'Неверный e-mail',
        '',
        true,
      );
      return;
    }

    _isSubmittingEmailRegistration = true;
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      GoRouter.of(context).prepareAuthEvent();

      final user = await authManager.createAccountWithEmail(
        context,
        email,
        _model.passTextController.text,
      );
      if (user == null || !mounted) {
        return;
      }

      unawaited(_sendInitialEmailVerification());

      if (_model.switchValue == true) {
        await UsersRecord.collection.doc(user.uid).update(createUsersRecordData(
              role: UserRole.native_speaker,
            ));

        if (!mounted) {
          return;
        }

        context.goNamedAuth(
          AcquaintanceNSWidget.routeName,
          context.mounted,
          queryParameters: {
            'index': serializeParam(
              0,
              ParamType.int,
            ),
          }.withoutNulls,
        );
        return;
      }

      final studentRoleUpdate = createUsersRecordData(
        role: UserRole.student,
      );
      studentRoleUpdate['availabilityToday'] = FieldValue.delete();
      await UsersRecord.collection.doc(user.uid).update(studentRoleUpdate);
      try {
        await FirebaseFunctions.instance
            .httpsCallable('claimRegistrationGift')
            .call();
      } on FirebaseFunctionsException catch (error) {
        if (!mounted) {
          return;
        }
        await actions.showTopNotification(
          context,
          error.message ?? 'Бонусные минуты можно получить позже',
          '',
          true,
        );
      } catch (_) {
        if (!mounted) {
          return;
        }
        await actions.showTopNotification(
          context,
          'Бонусные минуты можно получить позже',
          '',
          true,
        );
      }

      if (!mounted) {
        return;
      }

      context.goNamedAuth(
        AcquaintanceSTUDENTWidget.routeName,
        context.mounted,
        queryParameters: {
          'index': serializeParam(
            0,
            ParamType.int,
          ),
        }.withoutNulls,
      );
    } finally {
      _isSubmittingEmailRegistration = false;
    }
  }

  Future<void> _handleSocialAuth({
    required Future<BaseAuthUser?> Function() signInAction,
    required String providerId,
  }) async {
    if (_isSubmittingSocialAuth) {
      return;
    }

    _isSubmittingSocialAuth = true;
    var navigationStarted = false;
    try {
      _showSocialAuthProgress();
      beginPendingSocialAuthContext(
        providerId: providerId,
        sourceScreen: RegistrationWidget.routeName,
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
          'Не удалось завершить регистрацию',
          '',
          true,
        );
      }
    } finally {
      if (!navigationStarted) {
        _hideSocialAuthProgress();
        _isSubmittingSocialAuth = false;
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
    required Widget icon,
    required String label,
    required Future<void> Function() onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
          onTap: onTap,
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
                                'swn14ivc' /* Регистрация */,
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
                                '2qzo58i1' /* Чтобы начать, нужно зарегестри... */,
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
                                      'omyv9gs9' /* E-mail */,
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
                                      'c91xmbbf' /* Пароль */,
                                    ),
                                    textInputAction: TextInputAction.go,
                                    obscureText: !_model.passVisibility,
                                    validator: _model
                                        .passTextControllerValidator
                                        .asValidator(context),
                                    onSubmitted: _handleEmailRegistration,
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
                                  const SizedBox(
                                      height: ExpatlioDesign.space12),
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
                            const SizedBox(height: ExpatlioDesign.space16),
                            ButtonWidget(
                              text: FFLocalizations.of(context).getText(
                                'ohbb27ah' /* Далее */,
                              ),
                              loadingText:
                                  FFLocalizations.of(context).getVariableText(
                                ruText: 'Создаем аккаунт...',
                                enText: 'Creating account...',
                              ),
                              busyStyle: ButtonBusyStyle.spinner,
                              action: _handleEmailRegistration,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: ExpatlioDesign.space20),
                      Row(
                        children: [
                          _buildSocialButton(
                            icon: Icon(
                              Icons.apple,
                              color: ExpatlioDesign.text,
                              size: 22.0,
                            ),
                            label: FFLocalizations.of(context).getText(
                              '4j9qbbqb' /* Apple */,
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
                          const SizedBox(width: ExpatlioDesign.space12),
                          _buildSocialButton(
                            icon: const FaIcon(
                              FontAwesomeIcons.google,
                              color: ExpatlioDesign.text,
                              size: 18.0,
                            ),
                            label: FFLocalizations.of(context).getText(
                              '9yanqfu5' /* Google */,
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
                                    '8s89x4ou' /* Пользуясь приложением, вы согл... */,
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
                                    '1r55b1dc' /* Политикой конфиденциальности  */,
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
                          context.pushNamed(LoginWidget.routeName);
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
                                    '4trgnrco' /* Есть аккаунт?  */,
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
                                    'ynyd41nj' /* Войти */,
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
