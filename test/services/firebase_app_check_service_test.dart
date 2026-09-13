import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/firebase_app_check_service.dart';

void main() {
  group('resolveAppCheckProviderKind', () {
    test('uses DeviceCheck on physical iOS devices in every build mode', () {
      for (final isDebugMode in <bool>[true, false]) {
        expect(
          resolveAppCheckProviderKind(
            isWeb: false,
            platform: TargetPlatform.iOS,
            isDebugMode: isDebugMode,
            isPhysicalIosDevice: true,
          ),
          AppCheckProviderKind.appleDeviceCheck,
        );
      }
    });

    test('uses debug provider on the iOS simulator', () {
      expect(
        resolveAppCheckProviderKind(
          isWeb: false,
          platform: TargetPlatform.iOS,
          isDebugMode: true,
          isPhysicalIosDevice: false,
        ),
        AppCheckProviderKind.appleDebug,
      );
    });

    test('uses explicit lookup fallbacks on iOS', () {
      expect(
        resolveAppCheckProviderKind(
          isWeb: false,
          platform: TargetPlatform.iOS,
          isDebugMode: true,
        ),
        AppCheckProviderKind.appleDebug,
      );
      expect(
        resolveAppCheckProviderKind(
          isWeb: false,
          platform: TargetPlatform.iOS,
          isDebugMode: false,
        ),
        AppCheckProviderKind.appleDeviceCheck,
      );
    });

    test('preserves Android, macOS, web and unsupported behavior', () {
      expect(
        resolveAppCheckProviderKind(
          isWeb: false,
          platform: TargetPlatform.android,
          isDebugMode: true,
        ),
        AppCheckProviderKind.androidDebug,
      );
      expect(
        resolveAppCheckProviderKind(
          isWeb: false,
          platform: TargetPlatform.android,
          isDebugMode: false,
        ),
        AppCheckProviderKind.androidPlayIntegrity,
      );
      expect(
        resolveAppCheckProviderKind(
          isWeb: false,
          platform: TargetPlatform.macOS,
          isDebugMode: true,
        ),
        AppCheckProviderKind.appleDebug,
      );
      expect(
        resolveAppCheckProviderKind(
          isWeb: false,
          platform: TargetPlatform.macOS,
          isDebugMode: false,
        ),
        AppCheckProviderKind.appleDeviceCheck,
      );
      expect(
        resolveAppCheckProviderKind(
          isWeb: true,
          platform: TargetPlatform.linux,
          isDebugMode: true,
        ),
        AppCheckProviderKind.webRecaptcha,
      );
      expect(
        resolveAppCheckProviderKind(
          isWeb: false,
          platform: TargetPlatform.linux,
          isDebugMode: true,
        ),
        AppCheckProviderKind.unsupported,
      );
    });
  });
}
