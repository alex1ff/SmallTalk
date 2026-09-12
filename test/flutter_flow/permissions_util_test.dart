import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/flutter_flow/permissions_util.dart';

void main() {
  test('checks independent permission statuses in parallel only once',
      () async {
    final cameraStatus = Completer<bool>();
    final microphoneStatus = Completer<bool>();
    var cameraChecks = 0;
    var microphoneChecks = 0;
    var requests = 0;
    final coordinator = MediaPermissionCoordinator();

    final result = coordinator.ensure(
      cameraStatus: () {
        cameraChecks++;
        return cameraStatus.future;
      },
      microphoneStatus: () {
        microphoneChecks++;
        return microphoneStatus.future;
      },
      requestCamera: () async => requests++,
      requestMicrophone: () async => requests++,
    );

    expect(cameraChecks, 1);
    expect(microphoneChecks, 1);
    cameraStatus.complete(true);
    microphoneStatus.complete(true);

    expect(await result, isTrue);
    expect(cameraChecks, 1);
    expect(microphoneChecks, 1);
    expect(requests, 0);
  });

  test('concurrent callers share one permission operation', () async {
    final cameraStatus = Completer<bool>();
    final microphoneStatus = Completer<bool>();
    var cameraChecks = 0;
    var microphoneChecks = 0;
    final coordinator = MediaPermissionCoordinator();

    Future<bool> ensure() => coordinator.ensure(
          cameraStatus: () {
            cameraChecks++;
            return cameraStatus.future;
          },
          microphoneStatus: () {
            microphoneChecks++;
            return microphoneStatus.future;
          },
          requestCamera: () async {},
          requestMicrophone: () async {},
        );

    final first = ensure();
    final second = ensure();
    expect(identical(first, second), isTrue);
    expect(cameraChecks, 1);
    expect(microphoneChecks, 1);

    cameraStatus.complete(true);
    microphoneStatus.complete(true);
    expect(await Future.wait([first, second]), [true, true]);
  });

  test('briefly reuses success then checks again after ttl', () async {
    var now = DateTime.utc(2035, 6, 14, 9);
    var cameraChecks = 0;
    var microphoneChecks = 0;
    final coordinator = MediaPermissionCoordinator(
      successCacheTtl: const Duration(seconds: 30),
      now: () => now,
    );

    Future<bool> ensure() => coordinator.ensure(
          cameraStatus: () async {
            cameraChecks++;
            return true;
          },
          microphoneStatus: () async {
            microphoneChecks++;
            return true;
          },
          requestCamera: () async {},
          requestMicrophone: () async {},
        );

    expect(await ensure(), isTrue);
    now = now.add(const Duration(seconds: 20));
    expect(await ensure(), isTrue);
    expect(cameraChecks, 1);
    expect(microphoneChecks, 1);

    now = now.add(const Duration(seconds: 11));
    expect(await ensure(), isTrue);
    expect(cameraChecks, 2);
    expect(microphoneChecks, 2);
  });

  test('lifecycle invalidation forces a fresh check inside ttl', () async {
    var checks = 0;
    final coordinator = MediaPermissionCoordinator();

    Future<bool> ensure() => coordinator.ensure(
          cameraStatus: () async {
            checks++;
            return true;
          },
          microphoneStatus: () async {
            checks++;
            return true;
          },
          requestCamera: () async {},
          requestMicrophone: () async {},
        );

    expect(await ensure(), isTrue);
    expect(await ensure(), isTrue);
    expect(checks, 2);

    coordinator.invalidateSuccess();
    expect(await ensure(), isTrue);
    expect(checks, 4);
  });

  test('late success cannot repopulate cache after lifecycle invalidation',
      () async {
    final oldCameraStatus = Completer<bool>();
    final oldMicrophoneStatus = Completer<bool>();
    var freshChecks = 0;
    final coordinator = MediaPermissionCoordinator();

    final oldAttempt = coordinator.ensure(
      cameraStatus: () => oldCameraStatus.future,
      microphoneStatus: () => oldMicrophoneStatus.future,
      requestCamera: () async {},
      requestMicrophone: () async {},
    );
    coordinator.invalidateSuccess();
    final concurrentAfterInvalidation = coordinator.ensure(
      cameraStatus: () async {
        freshChecks++;
        return true;
      },
      microphoneStatus: () async {
        freshChecks++;
        return true;
      },
      requestCamera: () async {},
      requestMicrophone: () async {},
    );
    expect(identical(oldAttempt, concurrentAfterInvalidation), isTrue);
    oldCameraStatus.complete(true);
    oldMicrophoneStatus.complete(true);
    expect(await oldAttempt, isFalse);
    expect(await concurrentAfterInvalidation, isFalse);
    expect(freshChecks, 0);

    expect(
      await coordinator.ensure(
        cameraStatus: () async {
          freshChecks++;
          return true;
        },
        microphoneStatus: () async {
          freshChecks++;
          return true;
        },
        requestCamera: () async {},
        requestMicrophone: () async {},
      ),
      isTrue,
    );
    expect(freshChecks, 2);
  });

  test('hung status check fails closed and does not poison later attempts',
      () async {
    final never = Completer<bool>();
    final coordinator = MediaPermissionCoordinator(
      statusCheckTimeout: const Duration(milliseconds: 10),
    );

    final first = coordinator.ensure(
      cameraStatus: () => never.future,
      microphoneStatus: () async => true,
      requestCamera: () async {},
      requestMicrophone: () async {},
    );
    expect(await first, isFalse);

    expect(
      await coordinator.ensure(
        cameraStatus: () async => true,
        microphoneStatus: () async => true,
        requestCamera: () async {},
        requestMicrophone: () async {},
      ),
      isTrue,
    );
  });

  test('requests missing permissions sequentially and does not cache denial',
      () async {
    var cameraChecks = 0;
    var microphoneChecks = 0;
    var cameraRequests = 0;
    var microphoneRequests = 0;
    final operations = <String>[];
    final coordinator = MediaPermissionCoordinator();

    Future<bool> ensure() => coordinator.ensure(
          cameraStatus: () async {
            cameraChecks++;
            operations.add('camera_status');
            return cameraRequests > 0;
          },
          microphoneStatus: () async {
            microphoneChecks++;
            operations.add('microphone_status');
            return false;
          },
          requestCamera: () async {
            operations.add('camera_request');
            cameraRequests++;
          },
          requestMicrophone: () async {
            operations.add('microphone_request');
            microphoneRequests++;
          },
        );

    expect(await ensure(), isFalse);
    expect(
      operations,
      [
        'camera_status',
        'microphone_status',
        'camera_request',
        'camera_status',
        'microphone_request',
        'microphone_status',
      ],
    );

    operations.clear();
    expect(await ensure(), isFalse);
    expect(cameraChecks, 3);
    expect(microphoneChecks, 4);
    expect(cameraRequests, 1);
    expect(microphoneRequests, 2);
  });
}
