import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth_manager.dart';
import '../../flutter_flow/flutter_flow_util.dart';

import '/backend/backend.dart';
import '/custom_code/actions/index.dart' as actions;
import '/services/new_account_inbox_bootstrap.dart';
import 'anonymous_auth.dart';
import 'apple_auth.dart';
import 'email_auth.dart';
import 'firebase_user_provider.dart';
import 'google_auth.dart';
import 'jwt_token_auth.dart';
import 'github_auth.dart';

export '../base_auth_user_provider.dart';

class FirebasePhoneAuthManager extends ChangeNotifier {
  bool? _triggerOnCodeSent;
  FirebaseAuthException? phoneAuthError;
  // Set when using phone verification (after phone number is provided).
  String? phoneAuthVerificationCode;
  // Set when using phone sign in in web mode (ignored otherwise).
  ConfirmationResult? webPhoneAuthConfirmationResult;
  // Used for handling verification codes for phone sign in.
  void Function(BuildContext)? _onCodeSent;

  bool get triggerOnCodeSent => _triggerOnCodeSent ?? false;
  set triggerOnCodeSent(bool val) => _triggerOnCodeSent = val;

  void Function(BuildContext) get onCodeSent =>
      _onCodeSent == null ? (_) {} : _onCodeSent!;
  set onCodeSent(void Function(BuildContext) func) => _onCodeSent = func;

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }
}

class FirebaseAuthManager extends AuthManager
    with
        EmailSignInManager,
        GoogleSignInManager,
        AppleSignInManager,
        AnonymousSignInManager,
        JwtSignInManager,
        GithubSignInManager,
        PhoneSignInManager {
  FirebasePhoneAuthManager phoneAuthManager = FirebasePhoneAuthManager();

  Future<void> _showAuthNotification(
    BuildContext context,
    String message, {
    bool isError = true,
  }) async {
    if (!context.mounted) {
      return;
    }
    await actions.showTopNotification(
      context,
      message,
      '',
      isError,
    );
  }

  @override
  Future signOut() {
    return FirebaseAuth.instance.signOut();
  }

  @override
  Future deleteUser(BuildContext context) async {
    try {
      if (!loggedIn) {
        print('Error: delete user attempted with no logged in user!');
        return;
      }
      await currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await _showAuthNotification(
          context,
          FFLocalizations.of(context).getText(
            '85lj4aua' /* Прошло много времени с последн... */,
          ),
        );
      }
    }
  }

  @override
  Future updateEmail({
    required String email,
    required BuildContext context,
  }) async {
    try {
      if (!loggedIn) {
        print('Error: update email attempted with no logged in user!');
        return;
      }
      await currentUser?.updateEmail(email);
      await updateUserDocument(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await _showAuthNotification(
          context,
          FFLocalizations.of(context).getText(
            'k3mw5pe7' /* Прошло много времени с последн... */,
          ),
        );
      }
    }
  }

  Future updatePassword({
    required String newPassword,
    required BuildContext context,
  }) async {
    try {
      if (!loggedIn) {
        print('Error: update password attempted with no logged in user!');
        return;
      }
      await currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await _showAuthNotification(
          context,
          FFLocalizations.of(context).getText(
            '60fb8f43' /* Ошибка */,
          ),
        );
      }
    }
  }

  @override
  Future resetPassword({
    required String email,
    required BuildContext context,
  }) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException {
      await _showAuthNotification(
        context,
        FFLocalizations.of(context).getText(
          '60fb8f43' /* Ошибка */,
        ),
      );
      return null;
    }
    await _showAuthNotification(
      context,
      FFLocalizations.of(context).getText(
        '7mczn45o' /* Ссылка на сборс пароля отправл... */,
      ),
      isError: false,
    );
  }

  @override
  Future<BaseAuthUser?> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  ) =>
      _signInOrCreateAccount(
        context,
        () => emailSignInFunc(email, password),
        'EMAIL',
      );

  @override
  Future<BaseAuthUser?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password,
  ) =>
      _signInOrCreateAccount(
        context,
        () => emailCreateAccountFunc(email, password),
        'EMAIL',
      );

  @override
  Future<BaseAuthUser?> signInAnonymously(
    BuildContext context,
  ) =>
      _signInOrCreateAccount(context, anonymousSignInFunc, 'ANONYMOUS');

  @override
  Future<BaseAuthUser?> signInWithApple(BuildContext context) =>
      _signInOrCreateAccount(context, appleSignIn, 'APPLE');

  @override
  Future<BaseAuthUser?> signInWithGoogle(BuildContext context) =>
      _signInOrCreateAccount(context, googleSignInFunc, 'GOOGLE');

  @override
  Future<BaseAuthUser?> signInWithGithub(BuildContext context) =>
      _signInOrCreateAccount(context, githubSignInFunc, 'GITHUB');

  @override
  Future<BaseAuthUser?> signInWithJwtToken(
    BuildContext context,
    String jwtToken,
  ) =>
      _signInOrCreateAccount(context, () => jwtTokenSignIn(jwtToken), 'JWT');

  void handlePhoneAuthStateChanges(BuildContext context) {
    phoneAuthManager.addListener(() {
      if (!context.mounted) {
        return;
      }

      if (phoneAuthManager.triggerOnCodeSent) {
        phoneAuthManager.onCodeSent(context);
        phoneAuthManager
            .update(() => phoneAuthManager.triggerOnCodeSent = false);
      } else if (phoneAuthManager.phoneAuthError != null) {
        unawaited(_showAuthNotification(
          context,
          FFLocalizations.of(context).getText(
            '60fb8f43' /* Ошибка */,
          ),
        ));
        phoneAuthManager.update(() => phoneAuthManager.phoneAuthError = null);
      }
    });
  }

  @override
  Future beginPhoneAuth({
    required BuildContext context,
    required String phoneNumber,
    required void Function(BuildContext) onCodeSent,
  }) async {
    phoneAuthManager.update(() => phoneAuthManager.onCodeSent = onCodeSent);
    if (kIsWeb) {
      phoneAuthManager.webPhoneAuthConfirmationResult =
          await FirebaseAuth.instance.signInWithPhoneNumber(phoneNumber);
      phoneAuthManager.update(() => phoneAuthManager.triggerOnCodeSent = true);
      return;
    }
    final completer = Completer<bool>();
    // If you'd like auto-verification, without the user having to enter the SMS
    // code manually. Follow these instructions:
    // * For Android: https://firebase.google.com/docs/auth/android/phone-auth?authuser=0#enable-app-verification (SafetyNet set up)
    // * For iOS: https://firebase.google.com/docs/auth/ios/phone-auth?authuser=0#start-receiving-silent-notifications
    // * Finally modify verificationCompleted below as instructed.
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout:
          Duration(seconds: 0), // Skips Android's default auto-verification
      verificationCompleted: (phoneAuthCredential) async {
        await FirebaseAuth.instance.signInWithCredential(phoneAuthCredential);
        phoneAuthManager.update(() {
          phoneAuthManager.triggerOnCodeSent = false;
          phoneAuthManager.phoneAuthError = null;
        });
        // If you've implemented auto-verification, navigate to home page or
        // onboarding page here manually. Uncomment the lines below and replace
        // DestinationPage() with the desired widget.
        // await Navigator.push(
        //   context,
        //   MaterialPageRoute(builder: (_) => DestinationPage()),
        // );
      },
      verificationFailed: (e) {
        phoneAuthManager.update(() {
          phoneAuthManager.triggerOnCodeSent = false;
          phoneAuthManager.phoneAuthError = e;
        });
        completer.complete(false);
      },
      codeSent: (verificationId, _) {
        phoneAuthManager.update(() {
          phoneAuthManager.phoneAuthVerificationCode = verificationId;
          phoneAuthManager.triggerOnCodeSent = true;
          phoneAuthManager.phoneAuthError = null;
        });
        completer.complete(true);
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  @override
  Future verifySmsCode({
    required BuildContext context,
    required String smsCode,
  }) {
    if (kIsWeb) {
      return _signInOrCreateAccount(
        context,
        () => phoneAuthManager.webPhoneAuthConfirmationResult!.confirm(smsCode),
        'PHONE',
      );
    } else {
      final authCredential = PhoneAuthProvider.credential(
        verificationId: phoneAuthManager.phoneAuthVerificationCode!,
        smsCode: smsCode,
      );
      return _signInOrCreateAccount(
        context,
        () => FirebaseAuth.instance.signInWithCredential(authCredential),
        'PHONE',
      );
    }
  }

  /// Tries to sign in or create an account using Firebase Auth.
  /// Returns the User object if sign in was successful.
  Future<BaseAuthUser?> _signInOrCreateAccount(
    BuildContext context,
    Future<UserCredential?> Function() signInFunc,
    String authProvider,
  ) async {
    try {
      final userCredential = await signInFunc();
      if (userCredential?.user != null) {
        final accountWasCreated = await maybeCreateUser(userCredential!.user!);
        if (accountWasCreated) {
          NewAccountInboxBootstrap.markAccountCreated(
            userCredential.user!.uid,
          );
        }
      }
      return userCredential == null
          ? null
          : SmallTalkFirebaseUser.fromUserCredential(userCredential);
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'FirebaseAuthException ($authProvider): code=${e.code}, message=${e.message}',
      );

      final langCode = FFLocalizations.of(context).languageCode;
      final isRu = langCode == 'ru';
      final errorCode = e.code.toLowerCase();
      final errorMsg = switch (errorCode) {
        'email-already-in-use' => FFLocalizations.of(context).getText(
            'qw84zdr4' /* Эта почта уже использовалась п... */,
          ),
        'invalid_login_credentials' ||
        'invalid-login-credentials' ||
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          FFLocalizations.of(context).getText(
            'euaras4g' /* Предоставленные учетные данные... */,
          ),
        'network-request-failed' => isRu
            ? 'Проблема с интернетом. Проверьте подключение.'
            : 'Network error. Check your internet connection.',
        'too-many-requests' => isRu
            ? 'Слишком много попыток. Попробуйте позже.'
            : 'Too many attempts. Try again later.',
        'user-disabled' =>
          isRu ? 'Этот аккаунт отключен.' : 'This account has been disabled.',
        'invalid-email' =>
          isRu ? 'Неверный формат e-mail.' : 'Invalid e-mail format.',
        _ => FFLocalizations.of(context).getText(
            '60fb8f43' /* Ошибка */,
          ),
      };
      await _showAuthNotification(context, errorMsg);
      return null;
    } catch (e) {
      debugPrint('Auth exception ($authProvider): $e');
      final langCode = FFLocalizations.of(context).languageCode;
      final isRu = langCode == 'ru';
      final raw = e.toString().toLowerCase();

      final isUserCancelled = raw.contains('canceled') ||
          raw.contains('cancelled') ||
          raw.contains('aborted_by_user') ||
          raw.contains('sign_in_canceled');
      if (isUserCancelled) {
        return null;
      }

      String errorMsg = FFLocalizations.of(context).getText(
        '60fb8f43' /* Ошибка */,
      );

      if (authProvider == 'GOOGLE') {
        final looksLikeGoogleConfigIssue = raw.contains('apiexception: 10') ||
            raw.contains('sign_in_failed') ||
            raw.contains('missing-client-id') ||
            raw.contains('reversed_client_id') ||
            raw.contains('12500');
        if (looksLikeGoogleConfigIssue) {
          errorMsg = isRu
              ? 'Google вход не настроен для этого приложения. Проверьте Firebase iOS/Android OAuth конфигурацию.'
              : 'Google Sign-In is not configured for this app. Check Firebase iOS/Android OAuth configuration.';
        } else {
          errorMsg = isRu
              ? 'Не удалось войти через Google. Попробуйте ещё раз.'
              : 'Google Sign-In failed. Please try again.';
        }
      } else if (authProvider == 'APPLE') {
        final looksLikeAppleConfigIssue = raw.contains('authorizationerror') ||
            raw.contains('not available') ||
            raw.contains('invalid response');
        errorMsg = looksLikeAppleConfigIssue
            ? (isRu
                ? 'Apple вход недоступен или не настроен. Проверьте Sign in with Apple capability и настройки Firebase.'
                : 'Apple Sign-In is unavailable or not configured. Check Sign in with Apple capability and Firebase settings.')
            : (isRu
                ? 'Не удалось войти через Apple. Попробуйте ещё раз.'
                : 'Apple Sign-In failed. Please try again.');
      }

      await _showAuthNotification(context, errorMsg);
      return null;
    }
  }
}
