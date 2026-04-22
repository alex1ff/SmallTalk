import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  group('VoIP call surface contracts', () {
    test(
        'VoIP service derives deterministic CallKit ids and claims session early',
        () {
      final source = _source('lib/services/voip_service.dart');

      expect(
        source,
        contains("utf8.encode('smalltalk-call:\$trimmedSessionId')"),
      );
      expect(
        source,
        contains('if (_uuidPattern.hasMatch(trimmedSessionId))'),
      );
      expect(
        source,
        contains('return trimmedSessionId.toLowerCase();'),
      );
      expect(
        source,
        contains(
            '_sessionCallKitIds[sessionId] ?? _callKitIdForSession(sessionId)'),
      );
      expect(source, contains("'callKitId': callKitId"));
      expect(source, contains('_processAcceptClaimedAtBySession'));
      expect(source, contains('Duplicate accept event (process gate)'));

      final claimIndex =
          source.indexOf('_recentAcceptBySession[sessionId] = now;');
      final processClaimIndex = source.indexOf('_tryClaimProcessAccept');
      final handledIdIndex =
          source.indexOf('_handledCallKitAcceptIds.add(effectiveCallKitId);');
      final acceptInProgressIndex =
          source.indexOf('_acceptInProgress.add(sessionId);');
      final staleCallKitGuardIndex =
          source.indexOf('Ignoring accept for stale callKitId');

      expect(claimIndex, greaterThanOrEqualTo(0));
      expect(processClaimIndex, greaterThanOrEqualTo(0));
      expect(staleCallKitGuardIndex, greaterThanOrEqualTo(0));
      expect(handledIdIndex, greaterThan(claimIndex));
      expect(acceptInProgressIndex, greaterThan(handledIdIndex));
    });

    test(
        'stale end events fail closed and iOS push path uses deterministic ids',
        () {
      final voipSource = _source('lib/services/voip_service.dart');
      final appDelegateSource = _source('ios/Runner/AppDelegate.swift');

      expect(
        voipSource,
        contains('Ignoring endSession for unknown session'),
      );
      expect(
        voipSource,
        contains('_shouldEndSessionViaFallbackLookup(sessionId)'),
      );
      expect(
        voipSource,
        contains(
            'fallbackStartGeneration != _sessionStateGenerations[sessionId]'),
      );
      expect(
        voipSource,
        contains('_hasTrustedCallKitIdentity(sessionId, callKitId)'),
      );
      expect(
        voipSource,
        contains("status == 'connected'"),
      );
      expect(
        voipSource,
        contains('Ignoring endSession for stale callKitId'),
      );
      expect(
        voipSource,
        contains('Ignoring decline for stale callKitId'),
      );
      expect(
        voipSource,
        contains('Ignoring timeout for stale callKitId'),
      );
      expect(
        voipSource,
        contains('Ignoring decline for active session'),
      );
      expect(
        voipSource,
        contains('Ignoring timeout for active session'),
      );
      expect(
        voipSource,
        contains('sessionId == _lastNavigatedSessionId'),
      );
      expect(
        voipSource,
        contains('sessionId == _pendingSessionId'),
      );

      expect(
        appDelegateSource,
        contains('private func deterministicCallKitId'),
      );
      expect(
        appDelegateSource,
        contains('let callKitId = deterministicCallKitId(for: rawCallKitId)'),
      );
      expect(
        appDelegateSource,
        contains('payloadDict["callKitId"] = callKitId'),
      );
      expect(
        appDelegateSource,
        contains('if let existingUuid = UUID(uuidString: trimmed)'),
      );
      expect(
        appDelegateSource,
        contains('return existingUuid.uuidString.lowercased()'),
      );
    });

    test('MinimalDailyWidget blocks duplicate call clients process-wide', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');

      expect(source, contains('static CallClient? _processActiveCallClient;'));
      expect(
        source,
        contains(
            'static Completer<void>? _processActiveCallClientReleaseCompleter;'),
      );
      expect(source, contains('_hasProcessActiveCallClientConflict()'));
      expect(source, contains('_waitForProcessActiveCallClientRelease()'));
      expect(source, contains('_releaseProcessActiveCallClientLease()'));
      expect(source,
          contains('_claimProcessActiveCallClient(createdCallClient);'));
      expect(
        source,
        contains('_releaseProcessActiveCallClient(callClientToDispose);'),
      );
    });

    test('tutor accept waits for backend room credentials before navigating',
        () {
      final source = _source('lib/services/voip_service.dart');

      expect(
        source,
        isNot(contains('Navigated to VideoCallPage (tutor, instant)')),
      );
      expect(
        source,
        contains('Navigated to VideoCallPage (tutor, after acceptCall)'),
      );

      final acceptCallIndex = source.indexOf("httpsCallable('acceptCall')");
      final tutorNavigateIndex = source.indexOf(
        "sessionId: sessionId,\n              isTutor: true,\n              roomUrl: _lastRoomUrl",
      );
      expect(acceptCallIndex, greaterThanOrEqualTo(0));
      expect(tutorNavigateIndex, greaterThan(acceptCallIndex));
    });

    test('Daily token refresh keeps room URL and token paired', () {
      final videoCallSource = _source(
          'lib/shared_pages/video_call_page/video_call_page_widget.dart');
      final waitingSource = _source(
          'lib/students_pages/waiting_for_teacher_page/waiting_for_teacher_page_widget.dart');
      final dailyWidgetSource =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');

      expect(videoCallSource, contains('String? _freshRoomName;'));
      expect(videoCallSource, contains('joinCredentialsRefreshCallback'));
      expect(videoCallSource, contains("'roomUrl': _freshRoomUrl"));
      expect(videoCallSource, contains("'meetingToken': _freshMeetingToken"));

      expect(waitingSource, contains('final refreshedRoomUrl'));
      expect(waitingSource, contains('roomUrl: refreshedRoomUrl ?? roomUrl'));
      expect(
        waitingSource,
        contains('roomName: refreshedRoomName ?? roomName'),
      );

      expect(dailyWidgetSource, contains('String? _dynamicRoomUrl;'));
      expect(dailyWidgetSource, contains('_effectiveRoomUrl()'));
      expect(
        dailyWidgetSource,
        contains('await WidgetsBinding.instance.endOfFrame;'),
      );
    });
  });
}
