import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const _webAppCheckSiteKey = String.fromEnvironment(
  'FIREBASE_APP_CHECK_WEB_SITE_KEY',
);

enum AppCheckProviderKind {
  webRecaptcha,
  androidDebug,
  androidPlayIntegrity,
  appleDebug,
  appleDeviceCheck,
  unsupported,
}

AppCheckProviderKind resolveAppCheckProviderKind({
  required bool isWeb,
  required TargetPlatform platform,
  required bool isDebugMode,
  bool? isPhysicalIosDevice,
}) {
  if (isWeb) {
    return AppCheckProviderKind.webRecaptcha;
  }

  switch (platform) {
    case TargetPlatform.android:
      return isDebugMode
          ? AppCheckProviderKind.androidDebug
          : AppCheckProviderKind.androidPlayIntegrity;
    case TargetPlatform.iOS:
      if (isPhysicalIosDevice == true) {
        return AppCheckProviderKind.appleDeviceCheck;
      }
      if (isPhysicalIosDevice == false) {
        return AppCheckProviderKind.appleDebug;
      }
      return isDebugMode
          ? AppCheckProviderKind.appleDebug
          : AppCheckProviderKind.appleDeviceCheck;
    case TargetPlatform.macOS:
      return isDebugMode
          ? AppCheckProviderKind.appleDebug
          : AppCheckProviderKind.appleDeviceCheck;
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return AppCheckProviderKind.unsupported;
  }
}

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

    bool? isPhysicalIosDevice;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        isPhysicalIosDevice =
            (await DeviceInfoPlugin().iosInfo).isPhysicalDevice;
      } catch (error) {
        debugPrint('Firebase App Check iOS device lookup failed: $error');
      }
    }

    final providerKind = resolveAppCheckProviderKind(
      isWeb: false,
      platform: defaultTargetPlatform,
      isDebugMode: kDebugMode,
      isPhysicalIosDevice: isPhysicalIosDevice,
    );
    if (providerKind == AppCheckProviderKind.unsupported) {
      return;
    }

    await FirebaseAppCheck.instance.activate(
      androidProvider: providerKind == AppCheckProviderKind.androidDebug
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: providerKind == AppCheckProviderKind.appleDebug
          ? AppleProvider.debug
          : AppleProvider.deviceCheck,
    );
    if (kDebugMode) {
      unawaited(_probeFirebaseAppCheckToken());
    }
  } catch (error) {
    debugPrint('Firebase App Check activation failed: $error');
  }
}

Future<void> _probeFirebaseAppCheckToken() async {
  try {
    final token = await FirebaseAppCheck.instance.getToken(true);
    debugPrint(
      token != null && token.trim().isNotEmpty
          ? 'Firebase App Check readiness probe succeeded.'
          : 'Firebase App Check readiness probe returned no token.',
    );
  } catch (error) {
    debugPrint('Firebase App Check readiness probe failed: $error');
  }
}
