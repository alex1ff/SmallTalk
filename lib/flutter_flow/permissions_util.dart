import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '/flutter_flow/flutter_flow_util.dart';

const kPermissionStateToBool = {
  PermissionStatus.granted: true,
  PermissionStatus.limited: true,
  PermissionStatus.denied: false,
  PermissionStatus.restricted: false,
  PermissionStatus.permanentlyDenied: false,
};

final cameraPermission = Permission.camera;
final photoLibraryPermission = Permission.photos;
final microphonePermission = Permission.microphone;

Future<bool> getPermissionStatus(Permission setting) async {
  final status = await setting.status;
  return kPermissionStateToBool[status]!;
}

Future<void> requestPermission(Permission setting) async {
  if (setting == Permission.photos && isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt <= 32) {
      await Permission.storage.request();
    } else {
      await Permission.photos.request();
    }
  }
  await setting.request();
}

Future<bool> ensureCameraAndMicrophonePermissions() async {
  if (!(await getPermissionStatus(cameraPermission))) {
    await requestPermission(cameraPermission);
  }

  if (!(await getPermissionStatus(microphonePermission))) {
    await requestPermission(microphonePermission);
  }

  final hasCameraPermission = await getPermissionStatus(cameraPermission);
  final hasMicrophonePermission =
      await getPermissionStatus(microphonePermission);
  return hasCameraPermission && hasMicrophonePermission;
}
