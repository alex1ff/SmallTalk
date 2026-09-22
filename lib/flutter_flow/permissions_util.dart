import 'dart:async';

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

typedef MediaPermissionStatusCheck = Future<bool> Function();
typedef MediaPermissionRequest = Future<void> Function();

/// Collapses concurrent camera/microphone checks and briefly reuses a confirmed
/// grant while the app moves from search or CallKit to the Daily call screen.
/// Denials are never cached, so a retry can immediately observe changed access.
class MediaPermissionCoordinator {
  MediaPermissionCoordinator({
    this.successCacheTtl = const Duration(seconds: 30),
    this.statusCheckTimeout = const Duration(seconds: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration successCacheTtl;
  final Duration statusCheckTimeout;
  final DateTime Function() _now;

  Future<bool>? _inFlight;
  DateTime? _confirmedAt;
  int _cacheGeneration = 0;

  void invalidateSuccess() {
    _cacheGeneration++;
    _confirmedAt = null;
  }

  Future<bool> ensure({
    required MediaPermissionStatusCheck cameraStatus,
    required MediaPermissionStatusCheck microphoneStatus,
    required MediaPermissionRequest requestCamera,
    required MediaPermissionRequest requestMicrophone,
  }) {
    final confirmedAt = _confirmedAt;
    if (confirmedAt != null) {
      final elapsed = _now().difference(confirmedAt);
      if (!elapsed.isNegative && elapsed <= successCacheTtl) {
        return Future<bool>.value(true);
      }
    }

    final current = _inFlight;
    if (current != null) return current;

    final cacheGeneration = _cacheGeneration;
    late final Future<bool> operation;
    operation = _ensureFresh(
      cameraStatus: cameraStatus,
      microphoneStatus: microphoneStatus,
      requestCamera: requestCamera,
      requestMicrophone: requestMicrophone,
      cacheGeneration: cacheGeneration,
    ).whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
    _inFlight = operation;
    return operation;
  }

  Future<bool> _ensureFresh({
    required MediaPermissionStatusCheck cameraStatus,
    required MediaPermissionStatusCheck microphoneStatus,
    required MediaPermissionRequest requestCamera,
    required MediaPermissionRequest requestMicrophone,
    required int cacheGeneration,
  }) async {
    late final List<bool> initial;
    try {
      initial = await Future.wait<bool>([
        cameraStatus(),
        microphoneStatus(),
      ]).timeout(statusCheckTimeout);
    } on TimeoutException {
      return false;
    }
    var hasCameraPermission = initial[0];
    var hasMicrophonePermission = initial[1];

    // Permission dialogs must remain sequential. Only independent status reads
    // are parallelized.
    if (!hasCameraPermission) {
      await requestCamera();
      hasCameraPermission = await _statusAfterRequest(cameraStatus);
    }
    if (!hasMicrophonePermission) {
      await requestMicrophone();
      hasMicrophonePermission = await _statusAfterRequest(microphoneStatus);
    }

    final granted = hasCameraPermission && hasMicrophonePermission;
    if (cacheGeneration != _cacheGeneration) return false;
    _confirmedAt = granted ? _now() : null;
    return granted;
  }

  Future<bool> _statusAfterRequest(
    MediaPermissionStatusCheck statusCheck,
  ) async {
    try {
      return await statusCheck().timeout(statusCheckTimeout);
    } on TimeoutException {
      return false;
    }
  }
}

final _cameraMicrophonePermissionCoordinator = MediaPermissionCoordinator();

void invalidateCameraAndMicrophonePermissionCache() {
  _cameraMicrophonePermissionCoordinator.invalidateSuccess();
}

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

Future<bool> ensureCameraAndMicrophonePermissions() =>
    _cameraMicrophonePermissionCoordinator.ensure(
      cameraStatus: () => getPermissionStatus(cameraPermission),
      microphoneStatus: () => getPermissionStatus(microphonePermission),
      requestCamera: () => requestPermission(cameraPermission),
      requestMicrophone: () => requestPermission(microphonePermission),
    );
