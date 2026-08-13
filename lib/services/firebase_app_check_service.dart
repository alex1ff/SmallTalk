import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const _webAppCheckSiteKey = String.fromEnvironment(
  'FIREBASE_APP_CHECK_WEB_SITE_KEY',
);

Future<void> initializeFirebaseAppCheck() async {
  try {
    if (kIsWeb) {
      if (_webAppCheckSiteKey.isEmpty) {
        debugPrint(
          'Firebase App Check is not activated on web: '
          'FIREBASE_APP_CHECK_WEB_SITE_KEY is missing.',
        );
        return;
      }
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(_webAppCheckSiteKey),
      );
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.deviceCheck,
    );
  } catch (error) {
    debugPrint('Firebase App Check activation failed: $error');
  }
}
