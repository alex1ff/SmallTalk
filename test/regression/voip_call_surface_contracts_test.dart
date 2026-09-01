import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/session_limit_ui.dart';

String _source(String path) => File(path).readAsStringSync();

bool _previousCharEscapes(String source, int index) {
  var slashCount = 0;
  for (var cursor = index - 1;
      cursor >= 0 && source[cursor] == '\\';
      cursor--) {
    slashCount++;
  }
  return slashCount.isOdd;
}

int _nextCurlyToken(
  String source,
  int start, {
  required bool openingOnly,
  int initialParenDepth = 0,
}) {
  var parenDepth = initialParenDepth;
  String? stringQuote;
  var inLineComment = false;
  var inBlockComment = false;

  for (var index = start; index < source.length; index++) {
    final char = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';

    if (inLineComment) {
      if (char == '\n') {
        inLineComment = false;
      }
      continue;
    }
    if (inBlockComment) {
      if (char == '*' && next == '/') {
        inBlockComment = false;
        index++;
      }
      continue;
    }
    if (stringQuote != null) {
      if (char == stringQuote && !_previousCharEscapes(source, index)) {
        stringQuote = null;
      }
      continue;
    }

    if (char == '/' && next == '/') {
      inLineComment = true;
      index++;
      continue;
    }
    if (char == '/' && next == '*') {
      inBlockComment = true;
      index++;
      continue;
    }
    if (char == "'" || char == '"' || char == '`') {
      stringQuote = char;
      continue;
    }

    if (openingOnly) {
      if (char == '(') {
        parenDepth++;
      } else if (char == ')') {
        parenDepth--;
      } else if (char == '{' && parenDepth == 0) {
        return index;
      }
      continue;
    }

    if (char == '{' || char == '}') {
      return index;
    }
  }

  return -1;
}

String _curlyBlockSource(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, greaterThanOrEqualTo(0));
  final bodyStart = _nextCurlyToken(source, start, openingOnly: true);
  expect(bodyStart, greaterThan(start));

  var depth = 0;
  var index = bodyStart;
  while (index >= 0 && index < source.length) {
    final char = source[index];
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(start, index + 1);
      }
    }
    index = _nextCurlyToken(source, index + 1, openingOnly: false);
  }

  fail('Could not extract curly block: $signature');
}

String _jsFunctionSource(String source, String signature) =>
    _curlyBlockSource(source, signature);

String _xmlSectionAfter(String source, String marker, String closingTag) {
  final start = source.indexOf(marker);
  expect(start, greaterThanOrEqualTo(0));
  final end = source.indexOf(closingTag, start);
  expect(end, greaterThan(start));
  return source.substring(start, end + closingTag.length);
}

String _sourceBetween(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  expect(start, greaterThanOrEqualTo(0));
  final end = source.indexOf(endMarker, start);
  expect(end, greaterThan(start));
  return source.substring(start, end);
}

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
      expect(source, contains('VoipAcceptLifecycle _acceptLifecycle'));
      expect(source, contains('Duplicate accept event (process gate)'));
      expect(
        source,
        contains('_acceptLifecycle.invalidate(sessionId);'),
      );

      final handleAcceptIndex =
          source.indexOf('Future<void> _handleCallAccept');
      final duplicateGateIndex = source.indexOf(
        '_acceptLifecycle.evaluate(',
        handleAcceptIndex,
      );
      final expiryIndex = source.indexOf(
        'voipIncomingCallPayloadHasExpired(',
        handleAcceptIndex,
      );
      final processClaimIndex =
          source.indexOf('_acceptLifecycle.begin(', handleAcceptIndex);
      final permissionIndex =
          source.indexOf('_ensureAcceptMediaPermissions()', handleAcceptIndex);
      final generationGuardIndex = source.indexOf(
        '_acceptLifecycle.isCurrent(acceptAttempt)',
        permissionIndex,
      );
      final retryReleaseIndex = source.indexOf(
        '_acceptLifecycle.releaseForRetry(acceptAttempt)',
        generationGuardIndex,
      );
      final staleCallKitGuardIndex =
          source.indexOf('Ignoring accept for stale callKitId');

      expect(staleCallKitGuardIndex, greaterThanOrEqualTo(0));
      expect(duplicateGateIndex, greaterThan(handleAcceptIndex));
      expect(expiryIndex, greaterThan(duplicateGateIndex));
      expect(processClaimIndex, greaterThan(expiryIndex));
      expect(permissionIndex, greaterThan(processClaimIndex));
      expect(generationGuardIndex, greaterThan(permissionIndex));
      expect(retryReleaseIndex, greaterThan(generationGuardIndex));
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
        contains('private let incomingCallExtraKeys: Set<String>'),
      );
      expect(appDelegateSource, contains('"recipientId"'));
      expect(
        appDelegateSource,
        contains('private func incomingCallExtraData'),
      );
      expect(
        appDelegateSource,
        contains('private var voipRegistry: PKPushRegistry?'),
      );
      expect(
        appDelegateSource,
        isNot(contains('let voipRegistry: PKPushRegistry')),
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

    test('root app starts CallKit event handling before Firebase init', () {
      final mainSource = _source('lib/main.dart');
      final mainFunctionSource = _curlyBlockSource(
        mainSource,
        'void main() async {',
      );

      final backgroundHandlerIndex = mainFunctionSource.indexOf(
        'FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler)',
      );
      final earlyCallKitIndex = mainFunctionSource.indexOf(
        'VoIPService().startEarlyCallKitEventHandling()',
      );
      final firebaseInitIndex =
          mainFunctionSource.indexOf('await initFirebase()');
      final runAppIndex = mainFunctionSource.indexOf('runApp(');

      expect(backgroundHandlerIndex, greaterThanOrEqualTo(0));
      expect(earlyCallKitIndex, greaterThan(backgroundHandlerIndex));
      expect(firebaseInitIndex, greaterThan(earlyCallKitIndex));
      expect(runAppIndex, greaterThan(firebaseInitIndex));
    });

    test('root app clears queued CallKit actions only on real logout', () {
      final mainSource = _source('lib/main.dart');
      final loggedOutBranchSource = _curlyBlockSource(
        mainSource,
        'if (!user.loggedIn) {',
      );
      final realLogoutSource = _curlyBlockSource(
        loggedOutBranchSource,
        'if (wasLoggedIn) {',
      );

      final clearIndex = loggedOutBranchSource.indexOf(
        'VoIPService().setCallActionHandlingReady(false)',
      );
      final wasLoggedInIndex =
          loggedOutBranchSource.indexOf('if (wasLoggedIn)');

      expect(clearIndex, greaterThanOrEqualTo(0));
      expect(clearIndex, greaterThan(wasLoggedInIndex));
      expect(
        realLogoutSource,
        contains('VoIPService().setCallActionHandlingReady(false)'),
      );
    });

    test('teacher incoming calls are wired to VoIP and CallKit surfaces', () {
      final teacherPushSources = {
        'createVideoSession': _jsFunctionSource(
          _source('firebase/custom_cloud_functions/create_video_session.js'),
          'async function sendVoipPushToTutor',
        ),
        'declineCall': _jsFunctionSource(
          _source('firebase/custom_cloud_functions/decline_call.js'),
          'async function sendVoipPushToTutor',
        ),
        'processExpiredNotifications': _jsFunctionSource(
          _source(
              'firebase/custom_cloud_functions/process_expired_notifications.js'),
          'async function sendVoipPushToTutor',
        ),
      };
      final voipSource = _source('lib/services/voip_service.dart');
      final appDelegateSource = _source('ios/Runner/AppDelegate.swift');
      final infoPlistSource = _source('ios/Runner/Info.plist');
      final androidManifestSource =
          _source('android/app/src/main/AndroidManifest.xml');
      final initializeSource =
          _curlyBlockSource(voipSource, 'Future<void> initialize() async');
      final callKitSubscriptionSource = _curlyBlockSource(
        voipSource,
        'void _ensureCallKitEventSubscription() {',
      );
      final notificationListenerSource = _curlyBlockSource(
        voipSource,
        'void _startIncomingNotificationListener()',
      );
      final showIncomingCallSource =
          _curlyBlockSource(voipSource, 'Future<void> showIncomingCall({');
      final acceptSource =
          _curlyBlockSource(voipSource, 'Future<void> _handleCallAccept');
      final acceptedSessionResolverSource = _curlyBlockSource(
        voipSource,
        'Future<void> _resolveAcceptedSession(',
      );
      final declineSource =
          _curlyBlockSource(voipSource, 'Future<void> _handleCallDecline');
      final timeoutSource =
          _curlyBlockSource(voipSource, 'Future<void> _handleCallTimeout');
      final pushKitReceiveSource = _curlyBlockSource(
        appDelegateSource,
        'func pushRegistry(\n'
        '    _ registry: PKPushRegistry,\n'
        '    didReceiveIncomingPushWith payload: PKPushPayload',
      );
      final backgroundModesSource = _xmlSectionAfter(
        infoPlistSource,
        '<key>UIBackgroundModes</key>',
        '</array>',
      );
      final mainActivitySource = _xmlSectionAfter(
        androidManifestSource,
        '<activity\n'
            '            android:name=".MainActivity"',
        '</activity>',
      );

      for (final entry in teacherPushSources.entries) {
        final sendPushSource = entry.value;
        final apnsPayloadSource = _curlyBlockSource(
          sendPushSource,
          'const apnsPayload = buildTeacherIncomingCallApnsPayload',
        );
        final fcmMessageSource = _curlyBlockSource(
          sendPushSource,
          'const message = buildTeacherIncomingCallFcmMessage',
        );
        expect(
          sendPushSource,
          contains('await getUserVoipTokens(tutorId'),
          reason: entry.key,
        );
        expect(
          sendPushSource,
          contains('await sendApnsVoip({'),
          reason: entry.key,
        );
        expect(
          sendPushSource,
          contains('payload: apnsPayload'),
          reason: entry.key,
        );
        expect(apnsPayloadSource, contains('(callData)'), reason: entry.key);
        expect(
          fcmMessageSource,
          contains('token: fcmToken'),
          reason: entry.key,
        );
        expect(fcmMessageSource, contains('callData,'), reason: entry.key);
        expect(fcmMessageSource, contains('bundleId,'), reason: entry.key);
      }

      final foregroundListenerSource = _sourceBetween(
        initializeSource,
        'FirebaseMessaging.onMessage.listen',
        '_startSessionPruneTimer();',
      );
      expect(
        foregroundListenerSource,
        contains("message.data['type'] != 'incoming_call'"),
      );
      expect(foregroundListenerSource, contains('await showIncomingCall('));
      expect(
        foregroundListenerSource,
        contains("sessionId: message.data['sessionId'] ?? ''"),
      );
      expect(
        foregroundListenerSource,
        contains("callerName: message.data['callerName'] ?? 'Unknown Caller'"),
      );
      expect(
        foregroundListenerSource,
        contains("callerId: message.data['callerId'] ?? ''"),
      );
      expect(
        foregroundListenerSource,
        contains("callerPhoto: message.data['callerPhoto']"),
      );
      expect(
        foregroundListenerSource,
        contains(
            'extraData: voipIncomingCallExtraDataFromPayload(message.data)'),
      );

      expect(initializeSource, contains('FirebaseMessaging.onMessage.listen'));
      expect(
        initializeSource,
        contains("message.data['type'] != 'incoming_call'"),
      );
      expect(
          initializeSource, contains('_startIncomingNotificationListener();'));
      expect(
        initializeSource,
        contains('_ensureCallKitEventSubscription()'),
      );
      expect(
        callKitSubscriptionSource,
        contains('FlutterCallkitIncoming.onEvent.listen(_handleCallKitEvent)'),
      );
      expect(
          notificationListenerSource, contains(".collection('notifications')"));
      expect(
        notificationListenerSource,
        contains(".where('recipientId', isEqualTo: userId)"),
      );
      expect(
        notificationListenerSource,
        contains('_handleIncomingNotification(change.doc, userId)'),
      );
      expect(showIncomingCallSource,
          contains('await FlutterCallkitIncoming.showCallkitIncoming'));
      expect(showIncomingCallSource, contains('AndroidParams('));
      expect(showIncomingCallSource, contains('IOSParams('));
      expect(
        voipSource,
        contains('const int _incomingCallTimeoutMilliseconds = 45000;'),
      );
      expect(
        showIncomingCallSource,
        contains(
          'duration: voipIncomingCallDurationMilliseconds(extraData ?? const {})',
        ),
      );
      expect(
        showIncomingCallSource,
        contains('voipIncomingCallPayloadHasExpired(extraData)'),
      );
      expect(showIncomingCallSource, contains('voipBuildCallKitExtraData('));
      expect(showIncomingCallSource, contains('sessionId: sessionId'));
      expect(showIncomingCallSource, contains('callKitId: callKitId'));
      expect(acceptSource, contains('_lastAcceptedIsTutor = true;'));
      expect(acceptSource, contains('voipAcceptActionFromPayload(data)'));
      expect(
        acceptSource,
        contains('acceptAction == VoipAcceptPayloadAction.openSession'),
      );
      expect(acceptSource, contains('unawaited(_resolveAcceptedSession('));
      expect(
        acceptedSessionResolverSource,
        contains('_callAcceptCallFunction(attempt.sessionId)'),
      );
      expect(acceptedSessionResolverSource, contains('isTutor: true'));
      expect(declineSource, contains('_callDeclineCallFunction(sessionId)'));
      expect(timeoutSource,
          contains('Cloud Function processExpiredNotifications'));

      expect(appDelegateSource, contains('PKPushRegistryDelegate'));
      expect(appDelegateSource, contains('PKPushType.voIP'));
      expect(
        pushKitReceiveSource,
        contains('SwiftFlutterCallkitIncomingPlugin.sharedInstance'),
      );
      expect(
        pushKitReceiveSource,
        contains('payloadDict["sessionId"] = sessionId'),
      );
      expect(
        pushKitReceiveSource,
        contains('payloadDict["callKitId"] = callKitId'),
      );
      expect(
        pushKitReceiveSource,
        contains('payloadDict["callerName"] = nameCaller'),
      );
      expect(
        pushKitReceiveSource,
        contains('payloadDict["callerId"] = handle'),
      );
      expect(
        pushKitReceiveSource,
        contains('let extraDict = incomingCallExtraData(from: payloadDict)'),
      );
      expect(
        appDelegateSource,
        contains('private let incomingCallTimeoutMilliseconds = 45000'),
      );
      expect(
        pushKitReceiveSource,
        contains(
          'data.duration = incomingCallDurationMilliseconds(from: payloadDict, now: now)',
        ),
      );
      expect(
        pushKitReceiveSource,
        contains('data.extra = NSDictionary(dictionary: extraDict)'),
      );
      expect(
        pushKitReceiveSource,
        contains('plugin.showCallkitIncoming(data, fromPushKit: true)'),
      );

      expect(backgroundModesSource, contains('<string>voip</string>'));
      expect(
        backgroundModesSource,
        contains('<string>remote-notification</string>'),
      );
      expect(
        androidManifestSource,
        contains('android.permission.USE_FULL_SCREEN_INTENT'),
      );
      expect(
        androidManifestSource,
        contains('android.permission.POST_NOTIFICATIONS'),
      );
      expect(
        mainActivitySource,
        contains('android:showWhenLocked="true"'),
      );
      expect(mainActivitySource, contains('android:turnScreenOn="true"'));
    });

    test('Daily native lifetime is owned once and wired to cleanup phases', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      expect(source,
          contains('static final _processDailyLease = DailySessionLease();'));
      expect(source, contains('lease: _processDailyLease'));
      expect(source, contains('create: CallClient.create'));
      expect(source, contains('events: (client) => client.events'));
      expect(source, contains('onEvent: _handleCallEvent'));
      expect(source, contains('onClosing: _onDailyClosing'));
      expect(source, contains('disableInputs: _disableLocalInputsForCleanup'));
      expect(source, contains('detachVideo: (_) => _detachCallVideo()'));
      expect(source, contains('dispose: (client) => client.dispose()'));
      expect(source, isNot(contains('_processActiveCallClient')));
      expect(source, isNot(contains('_eventSubscription')));
      final cleanup = _curlyBlockSource(source, 'Future<void> _cleanup(');
      expect(cleanup, contains('_dailySession.close(leaveCall: leaveCall)'));
      expect(cleanup, contains('return active;'));
      expect(cleanup, contains('await nativeClose;'));
      final promotion = _curlyBlockSource(
          source, 'Future<void> _promoteToActiveCallIfReady(');
      expect(promotion, contains('final client = _callClient;'));
      expect('_dailySession.isCurrent(client)'.allMatches(promotion).length, 3);
      final inputs =
          _curlyBlockSource(source, 'Future<void> _updateInputSettings(');
      expect(inputs, contains('_dailySession.runWithClient'));
      expect(inputs, contains('if (!current) return;'));
    });

    test('MinimalDailyWidget marks connected sessions through callable', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');

      expect(source, contains("httpsCallable('markSessionConnected')"));
      expect(source, contains("'sessionId': sessionId"));
      expect(source, contains('case CallState.joined:'));
      expect(source, contains('unawaited(_markRoomJoined());'));
      expect(
        source,
        isNot(contains("'sessionMetadata.callConnectedAt': "
            'FieldValue.serverTimestamp()')),
      );
      expect(
        source,
        isNot(contains("'startedAt': FieldValue.serverTimestamp()")),
      );
    });

    test('MinimalDailyWidget uses a role-neutral connection status', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final statusSource =
          _curlyBlockSource(source, 'String? _statusMessage()');

      expect(statusSource, contains('Ожидаем подключение собеседника...'));
      expect(statusSource, isNot(contains('Ожидаем подключение студента...')));
    });

    test('session limit warning stays inside timer badge', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final badge = _source('lib/custom_code/widgets/call_duration_badge.dart');

      expect(
        RegExp(r'_CallCheckpointNotice\(\s*minutes:\s*-1').hasMatch(source),
        isFalse,
      );

      final badgeStart = source.indexOf('Widget _buildCallDurationBadge()');
      final noticeOverlayStart = source.indexOf(
        'Widget _buildCallCheckpointNoticeOverlay',
        badgeStart,
      );
      expect(badgeStart, greaterThanOrEqualTo(0));
      expect(noticeOverlayStart, greaterThan(badgeStart));

      final badgeSource = source.substring(badgeStart, noticeOverlayStart);
      expect(badgeSource, contains('CallDurationBadge('));
      expect(badge, contains("'Осталась 1 минута до лимита'"));
      expect(badge, contains(": 'до лимита'"));
    });

    test('call timer owner receives live session input and owns cleanup', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      expect(source, contains("import 'call_timer_controller.dart';"));
      for (final input in [
        'connectedAt: widget.sessionConnectedAt',
        'expiresAt: widget.sessionExpiresAt',
        'policy: widget.sessionPolicy',
        'status: widget.sessionStatus',
        'provisionalCountdown: widget.provisionalSessionLimitCountdown',
        'isStudent: widget.isStudent == true',
        'userRequestedEnd: _userRequestedEnd',
      ]) {
        expect(source, contains(input));
      }
      expect(source, isNot(contains('Timer.periodic(')));
      expect(source, isNot(contains('CallLimitDecisionTracker()')));
      expect(
          source, contains('_callTimer.serverClockOffset = serverClockOffset'));
      expect(source,
          contains('void _startDurationTimer() => _callTimer.start();'));
      expect(source, contains('_callTimer.stop(reset: reset)'));
      final update = _curlyBlockSource(source, 'void _handleCallTimerUpdate(');
      expect(update, contains('if (_disposed || !mounted) return;'));
      expect(update,
          contains('_callDurationNotifier.value = update.elapsedSeconds'));
      expect(update, contains('if (update.shouldAutoEnd)'));
      expect(update, contains('unawaited(_requestAutoEndAtSessionLimit())'));
      expect(
          update, contains('for (final minutes in update.checkpointMinutes)'));
      final didUpdate = _curlyBlockSource(source, 'void didUpdateWidget(');
      final sessionSwitch =
          _curlyBlockSource(didUpdate, 'if (sessionIdChanged)');
      expect(sessionSwitch, contains('_callTimer.resetLimitMarkers();'));
      expect(sessionSwitch, contains('_callTimer.serverClockOffset = null;'));
      expect(sessionSwitch,
          contains('_resetCallCheckpointNotice(clearHistory: true);'));
      final expirySwitch = _curlyBlockSource(didUpdate,
          'if (oldWidget.sessionExpiresAt != widget.sessionExpiresAt)');
      expect(expirySwitch, contains('_callTimer.resetLimitMarkers();'));
      expect(expirySwitch, isNot(contains('clearHistory: true')));
      expect(_curlyBlockSource(source, 'void _clearSessionLimitAutoEndMarker('),
          contains('_callTimer.clearAutoEndRequest(expiresAt);'));
      expect(_curlyBlockSource(source, 'void _resetCallCheckpointNotice('),
          contains('_callTimer.clearCheckpointHistory();'));
      final cleanup = _curlyBlockSource(source, 'Future<void> _cleanup(');
      final suspend = cleanup.indexOf('_callTimer.suspend();');
      final firstAwait = cleanup.indexOf('await ');
      expect(suspend, greaterThanOrEqualTo(0));
      expect(firstAwait, greaterThanOrEqualTo(0));
      expect(suspend, lessThan(firstAwait));
      expect(_curlyBlockSource(source, 'Future<void> _initializeCall('),
          contains('_callTimer.resume();'));
      final dispose = _curlyBlockSource(source, 'void dispose()');
      final timerDispose = dispose.indexOf('_callTimer.dispose();');
      final notifierDispose =
          dispose.indexOf('_callDurationNotifier.dispose();');
      expect(timerDispose, greaterThanOrEqualTo(0));
      expect(notifierDispose, greaterThanOrEqualTo(0));
      expect(timerDispose, lessThan(notifierDispose));
    });

    test('policy-backed connecting call stays in countdown timer mode', () {
      final pageSource = _source(
          'lib/shared_pages/video_call_page/video_call_page_widget.dart');
      final timerSource =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final timerBadgeSource =
          _source('lib/custom_code/widgets/call_duration_badge.dart');
      const policy = <String, dynamic>{'effectiveLimitSeconds': 300};
      final now = DateTime.utc(2026, 8, 24, 10);
      final expiresAt = now.add(const Duration(minutes: 5));

      for (final status in const <String>['connecting', 'active']) {
        expect(
          shouldUseSessionLimitCountdown(
            sessionStatus: status,
            expiresAt: expiresAt,
            sessionPolicy: policy,
          ),
          isTrue,
        );
      }
      expect(resolveSessionLimitRemainingSeconds(expiresAt, now: now), 300);
      expect(formatCallTimerDuration(300), '5:00');
      expect(formatCallTimerDuration(296), '4:56');

      expect(
        pageSource,
        contains('sessionExpiresAt: useSessionLimitCountdown'),
      );
      expect(
        pageSource,
        contains('useSessionLimitCountdown ? sessionPolicy : null'),
      );
      expect(
        timerSource,
        contains(
          'final displaySeconds = hasCountdown ? remainingSeconds : totalSeconds;',
        ),
      );
      expect(
        timerBadgeSource,
        contains('formatCallTimerDuration(displaySeconds)'),
      );
      expect(
        timerSource,
        contains('_callTimer.sessionLimitNow()'),
      );
      expect(
        pageSource,
        contains('useProvisionalSessionLimitCountdown'),
      );
      expect(
        pageSource,
        contains(
          'provisionalSessionLimitCountdown:\n'
          '                        useProvisionalSessionLimitCountdown',
        ),
      );
      expect(
        timerSource,
        contains('_callTimer.remainingSeconds(now)'),
      );
    });

    test('call chat keyboard layout keeps composer clear of overlays', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');

      expect(
          source, contains('final isChatKeyboardActive = _state.isChatOpen'));
      expect(source, contains('if (!isChatKeyboardActive)'));
      expect(
        source,
        contains('_chatFocusNode.addListener(_handleChatFocusChanged);'),
      );
      expect(
        source,
        contains('_chatFocusNode.removeListener(_handleChatFocusChanged);'),
      );

      final adaptivePanelStart =
          source.indexOf('Widget _buildAdaptiveChatPanel({');
      final chatPanelStart =
          source.indexOf('Widget _buildChatPanel({', adaptivePanelStart);
      expect(adaptivePanelStart, greaterThanOrEqualTo(0));
      expect(chatPanelStart, greaterThan(adaptivePanelStart));

      final adaptivePanelSource =
          source.substring(adaptivePanelStart, chatPanelStart);
      expect(source, contains('keyboardAlreadyReducedHeight'));
      expect(source, contains('_chatPanelBottomOffset('));
      expect(
        adaptivePanelSource,
        contains('height: isWideChat || isChatKeyboardActive ? null'),
      );
      expect(adaptivePanelSource, isNot(contains('AnimatedPadding')));

      final emptyStateStart = source.indexOf('Widget _buildEmptyChatState()');
      final messagesStart =
          source.indexOf('Widget _buildChatMessages()', emptyStateStart);
      expect(emptyStateStart, greaterThanOrEqualTo(0));
      expect(messagesStart, greaterThan(emptyStateStart));

      final emptyStateSource = source.substring(emptyStateStart, messagesStart);
      expect(emptyStateSource, contains('SingleChildScrollView'));
      expect(emptyStateSource, contains('ConstrainedBox'));
    });

    test(
        'call participant identity wrappers delegate raw SDK and widget values',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      expect(
        source,
        contains(
            "import 'call_participant_identity.dart' as participant_identity;"),
      );
      final remoteName = _curlyBlockSource(
        source,
        'String _participantDisplayName(',
      );
      final remoteLogId = _curlyBlockSource(
        source,
        'String _participantLogSpeakerId(',
      );
      final localName =
          _curlyBlockSource(source, 'String _localParticipantName()');
      final localId = _curlyBlockSource(source, 'String _localParticipantId()');

      for (final wrapper in [remoteName, remoteLogId]) {
        expect(wrapper, contains('ParticipantId participantId'));
        expect(
          'participants.all[participantId]'.allMatches(wrapper).length,
          1,
        );
      }
      for (final wrapper in [remoteName, remoteLogId, localName, localId]) {
        expect(wrapper, isNot(contains('.trim()')));
        expect(wrapper, isNot(contains('setState(')));
        expect(wrapper, isNot(contains('if (')));
      }
      expect(remoteName, contains("String fallback = 'Собеседник'"));
      expect(
          remoteName,
          contains(
              'return participant_identity.resolveRemoteParticipantName('));
      expect(remoteName, contains('username: participant?.info.username,'));
      expect(remoteName, contains('fallback: fallback,'));
      expect(
          remoteLogId,
          contains(
              'return participant_identity.resolveRemoteCaptionLogSpeakerId('));
      expect(remoteLogId, contains('userId: participant?.info.userId,'));
      expect(remoteLogId, contains('participantSessionId: participantId.id,'));
      expect(remoteLogId, contains('utteranceId: utteranceId,'));
      expect(localName,
          contains('return participant_identity.resolveLocalParticipantName('));
      expect(
          localName,
          contains(
              'dailyUsername: _callClient?.participants.local.info.username,'));
      expect(localName, contains('configuredUsername: widget.username,'));
      expect(localName, contains('isStudent: widget.isStudent,'));
      expect(localId,
          contains('return participant_identity.resolveLocalParticipantId('));
      expect(localId, contains('_callClient?.participants.local.id.id,'));
    });

    test(
        'call identity consumers keep caption-log writer separate from Daily ID',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final remoteChat = _curlyBlockSource(source, 'void _processChatMessage(');
      final remoteCaption =
          _curlyBlockSource(source, 'void _upsertRemoteCaption(');
      final localLog =
          _curlyBlockSource(source, 'void _enqueueLocalFinalCaptionLog(');
      final remoteLog =
          _curlyBlockSource(source, 'void _enqueueLegacyRemoteCaptionLog(');
      final controllerWiring = source.substring(
        source.indexOf('late final CallChatController _callChatController'),
        source.indexOf('Timer? _localCaptionUiThrottleTimer'),
      );
      final localCaption =
          _curlyBlockSource(source, 'void _flushLocalCaptionUpdate()');
      final overlay =
          _curlyBlockSource(source, 'Widget _buildCaptionsOverlay(');

      expect(
          remoteChat, contains('senderName: _participantDisplayName(from),'));
      expect(remoteChat, contains('senderId: from.id,'));
      expect(remoteCaption, contains('speakerId: participantId.id,'));
      expect(localLog, contains('final writerId = _captionLogWriterId();'));
      expect('speakerId: writerId,'.allMatches(localLog).length, 2);
      expect(localLog, isNot(contains('_localParticipantId()')));
      expect(localLog, contains('speakerName: _localParticipantName(),'));
      expect(
          remoteLog, contains('final speakerId = _participantLogSpeakerId('));
      expect('speakerId: speakerId,'.allMatches(remoteLog).length, 2);
      expect(remoteLog,
          contains('speakerName: _participantDisplayName(participantId),'));
      expect(controllerWiring, contains('id: _localParticipantId(),'));
      expect(controllerWiring, contains('name: _localParticipantName(),'));
      expect(localCaption, contains('speakerId: _localParticipantId(),'));
      expect(overlay,
          contains('label: _participantDisplayName(remoteEntry.key),'));
    });

    test('call chat composer uses the shared iMessage-style control', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final composerSource =
          _curlyBlockSource(source, 'Widget _buildChatComposer()');

      expect(composerSource, contains('ChatComposer('));
      expect(
          composerSource, contains('isSending: _callChatController.isSending'));
      expect(composerSource, contains('enabled: composerEnabled'));
      expect(composerSource, isNot(contains('Icons.send_rounded')));
    });

    test('outgoing captions delegate only latest and sent-signature state', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final enqueue =
          _curlyBlockSource(source, 'void _queueOutgoingCaptionMessage(');
      final flush = _curlyBlockSource(
          source, 'Future<void> _flushOutgoingCaptionMessage(');
      final clear = _curlyBlockSource(source, 'void _clearLocalCaptions()');
      expect(source, contains("import 'outgoing_caption_buffer.dart';"));
      expect(source,
          contains('final OutgoingCaptionBuffer<_OutgoingCaptionMessage>'));
      expect(source, isNot(contains('_pendingOutgoingCaptionMessage')));
      expect(source, isNot(contains('_lastSentCaptionSignature')));
      expect(
          enqueue,
          contains(
              '_outgoingCaptionBuffer.enqueue(message, message.signature)'));
      expect(flush, contains('_outgoingCaptionBuffer.takePending()'));
      expect(flush,
          contains('_outgoingCaptionBuffer.isDuplicate(pending.signature)'));
      expect(flush, contains('_sendCaptionMessage(pending.value)'));
      expect(flush, contains('if (didSend)'));
      expect(flush,
          contains('_outgoingCaptionBuffer.markSent(pending.signature)'));
      expect(clear, contains('_outgoingCaptionBuffer.clear();'));
    });

    test(
        'outgoing caption transport keeps throttle and overlapping flush policy',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final enqueue =
          _curlyBlockSource(source, 'void _queueOutgoingCaptionMessage(');
      final flush = _curlyBlockSource(
          source, 'Future<void> _flushOutgoingCaptionMessage(');
      final send =
          _curlyBlockSource(source, 'Future<bool> _sendCaptionMessage(');
      expect(
          source, contains('static const int _captionSendThrottleMs = 200;'));
      expect(enqueue, contains('if (immediate)'));
      expect(enqueue,
          contains('_cancelTrackedTimer(_remoteCaptionSendThrottleTimer)'));
      expect(enqueue, contains('_remoteCaptionSendThrottleTimer = null;'));
      expect(enqueue, contains('_scheduleOutgoingCaptionFlush();'));
      expect(enqueue, contains('if (_remoteCaptionSendThrottleTimer != null)'));
      expect(enqueue, contains('_createTrackedTimer('));
      expect(enqueue, contains('_captionSendThrottleMs'));
      expect(enqueue, isNot(contains('await _flushOutgoingCaptionMessage')));
      expect(flush, isNot(contains('Future.wait')));
      expect(flush, isNot(contains('catchError')));
      expect(send, contains('_callClient!.sendAppMessage('));
      expect(send, contains('dart_convert.jsonEncode(message.toJson())'));
      expect(send, contains('message.text.trim().isEmpty'));
      expect(send, contains('_state.microphoneEnabled'));
      expect(send, contains('_hasRemoteParticipantPresent()'));
      expect(send, contains('return false;'));
    });

    test(
        'Deepgram transport ownership is delegated to an injectable controller',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final transport = _source(
        'lib/custom_code/widgets/deepgram_transport_controller.dart',
      );
      final adapters = _source(
        'lib/custom_code/widgets/deepgram_transport_adapters.dart',
      );
      expect(source, contains("import 'deepgram_transport_adapters.dart';"));
      expect(
          source,
          contains(
              'late final _deepgramTransport = createDeepgramTransportController('));
      expect(source, contains('shouldRun: _shouldRunDeepgram'));
      expect(source, contains('onMessage: _handleDeepgramMessage'));
      expect(
          source,
          contains(
              'finalizeCaptionAndFlush: _finalizeCurrentCaptionAndFlushLogs'));
      expect(source, contains('clearCaption: _clearLocalCaptions'));
      expect(
          source,
          contains(
              'await _deepgramTransport.sync(forceRefresh: forceRefresh);'));
      expect(source, contains('=> _deepgramTransport.stop();'));
      expect(source, contains('unawaited(_deepgramTransport.dispose());'));
      expect(source, isNot(contains('FlutterSoundRecorder? _recorder')));
      expect(source, isNot(contains('IOWebSocketChannel? _deepgramChannel')));
      expect(transport, contains('class DeepgramTransportController'));
      expect(transport, contains('Future<void> stop()'));
      expect(transport, contains('Future<void> dispose()'));
      expect(transport, contains('_gate.beginStart()'));
      expect(transport, contains('_stopSingleFlight.run(_performStop)'));
      expect(transport, contains('await _finalizeCaptionAndFlush();'));
      expect(adapters, contains('Permission.microphone.request()'));
      expect(adapters, contains('FlutterSoundRecorder'));
      expect(adapters, contains('IOWebSocketChannel.connect'));
    });

    test('Deepgram transport stop preserves final-frame and cleanup contracts',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final handler = _curlyBlockSource(source, 'void _handleDeepgramMessage(');
      final transcript =
          _curlyBlockSource(source, 'void _handleDeepgramTranscript(');
      expect(handler, contains('_deepgramTransport.finalizing'));
      expect(transcript, contains('_deepgramTransport.finalizing'));
      expect(source, contains('stopCaptions: (_) async {'));
      expect(source, contains('await _stopDeepgramStreaming();'));
      expect(source, contains('await _flushPendingCaptionLogs(force: true);'));
      expect(source, contains('_dailySession.close(leaveCall: leaveCall)'));
    });

    test('Deepgram credential refresh cannot poison a replacement session', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final resolve = _curlyBlockSource(
        source,
        'Future<String?> _resolveDeepgramCredential(',
      );
      final didUpdate = _curlyBlockSource(source, 'void didUpdateWidget(');
      expect(resolve, contains('final requestGeneration ='));
      expect(resolve, contains('final requestSessionId = widget.sessionId'));
      expect(
        resolve,
        contains('requestGeneration != _deepgramCredentialGeneration'),
      );
      expect(resolve, contains('widget.sessionId?.trim() != requestSessionId'));
      expect(
        resolve.indexOf('requestGeneration != _deepgramCredentialGeneration'),
        lessThan(resolve.indexOf('_deepgramCredential = sanitized;')),
      );
      expect(
        '_deepgramCredentialGeneration += 1;'.allMatches(didUpdate).length,
        2,
      );
    });

    test('Deepgram parser results route to existing widget effect owners', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final handler = _curlyBlockSource(source, 'void _handleDeepgramMessage(');
      expect(
          source,
          contains(
              "import 'deepgram_message_parser.dart' as deepgram_parser;"));
      expect(
          handler, contains('deepgram_parser.parseDeepgramMessage(message)'));
      expect(handler,
          contains('case deepgram_parser.DeepgramMessageKind.ignored:'));
      expect(
          handler,
          contains(
              'case deepgram_parser.DeepgramMessageKind.invalidEnvelope:'));
      expect(handler,
          contains('case deepgram_parser.DeepgramMessageKind.serviceError:'));
      expect(handler,
          contains('case deepgram_parser.DeepgramMessageKind.utteranceEnd:'));
      expect(
          handler,
          contains(
              'case deepgram_parser.DeepgramMessageKind.finalizeCurrent:'));
      expect(handler,
          contains('case deepgram_parser.DeepgramMessageKind.transcript:'));
      expect(handler, contains('transcript: parsed.transcript!'));
      expect(handler, contains('isFinalSegment: parsed.isFinalSegment'));
      expect(handler, contains('speechFinal: parsed.speechFinal'));
      expect(handler, contains('confidence: parsed.confidence'));
      expect(source, isNot(contains('bool _isDeepgramErrorFrame(')));
      expect(source, isNot(contains('double? _readDouble(')));
    });

    test('Daily app-message decoding stays inside widget error boundary', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final handler = _curlyBlockSource(source, 'void _handleAppMessage(');

      expect(source, contains("import 'daily_app_message_decoder.dart';"));
      expect(
        handler,
        contains('final payload = decodeDailyAppMessagePayload(message);'),
      );
      expect(source, isNot(contains('_decodeAppMessagePayload(')));

      final mountedGuard = handler.indexOf('if (!mounted) return;');
      final tryBlock = handler.indexOf('try {');
      final decode = handler.indexOf('decodeDailyAppMessagePayload(message)');
      final nullGuard = handler.indexOf('if (payload == null) return;');
      final captionRoute = handler.indexOf("if (type == 'caption')");
      final captionEffect =
          handler.indexOf('_processCaptionMessage(payload, from)');
      final chatRoute = handler.indexOf("else if (type == 'chat')");
      final chatEffect = handler.indexOf(
        "_processChatMessage(payload['text']?.toString() ?? '', from)",
      );
      final catchBlock = handler.indexOf('catch (_)');
      final log =
          handler.indexOf("print('Daily app message: invalid_payload')");

      expect(mountedGuard, greaterThanOrEqualTo(0));
      expect(mountedGuard, lessThan(tryBlock));
      expect(tryBlock, lessThan(decode));
      expect(decode, lessThan(nullGuard));
      expect(nullGuard, lessThan(captionRoute));
      expect(captionRoute, lessThan(captionEffect));
      expect(captionEffect, lessThan(chatRoute));
      expect(chatRoute, lessThan(chatEffect));
      expect(chatEffect, lessThan(catchBlock));
      expect(catchBlock, lessThan(log));
    });

    test('Deepgram frame routing remains inside widget guard and catch', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final handler = _curlyBlockSource(source, 'void _handleDeepgramMessage(');
      final guard = handler.indexOf('if (!mounted ||');
      final guardedReturn = handler.indexOf('return;', guard);
      final tryBlock = handler.indexOf('try {');
      final catchBlock = handler.indexOf('} catch (_) {');
      expect(guard, greaterThanOrEqualTo(0));
      expect(guard, lessThan(guardedReturn));
      expect(guardedReturn, lessThan(tryBlock));
      expect(tryBlock, lessThan(catchBlock));
      expect(handler, contains('_deepgramTransport.finalizing'));
      expect(handler, contains('_state.microphoneEnabled'));
      expect(handler, contains('_hasRemoteParticipantPresent()'));

      for (final routedEffect in [
        '_handleDeepgramUtteranceEnd();',
        '_emitFinalUpdateForCurrentLocalCaption();',
        '_handleDeepgramTranscript(',
      ]) {
        final effectIndex = handler.indexOf(routedEffect);
        expect(effectIndex, greaterThan(tryBlock), reason: routedEffect);
        expect(effectIndex, lessThan(catchBlock), reason: routedEffect);
      }
      expect(handler.indexOf('_cancelLocalUtteranceEndFallback();'),
          lessThan(handler.indexOf('_handleDeepgramTranscript(')));
      expect(handler, contains("code: 'deepgram_message_parse_failed'"));
      expect(handler, contains("code: 'deepgram_error_frame'"));
      expect(
          handler,
          contains(
              'Субтитры временно недоступны: не удалось обработать ответ распознавания.'));
      expect(
          handler,
          contains(
              'Субтитры временно недоступны: сервис распознавания вернул ошибку.'));
      final catchSource = handler.substring(catchBlock);
      expect(catchSource, contains("code: 'deepgram_message_parse_failed'"));
      expect(catchSource,
          contains("print('Deepgram message: processing_failed')"));
    });

    test('Deepgram caption failures stay visible and persisted safely', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final transport = _source(
        'lib/custom_code/widgets/deepgram_transport_controller.dart',
      );
      expect(source, contains("'caption_token_unavailable'"));
      expect(source, contains("'deepgram_error_frame'"));
      expect(source, contains('DeepgramCredentialException'));
      expect(
          source, contains('deepgram_parser.DeepgramMessageKind.serviceError'));
      expect(transport, contains("'deepgram_start_failed'"));
      expect(transport, contains("'deepgram_websocket_error'"));
      expect(transport, contains("'audio_stream_error'"));
      expect(transport, isNot(contains(r'$error')));
      expect(transport, isNot(contains('credential.toString')));

      final genericCredentialIssue = _curlyBlockSource(
        source,
        'void _reportGenericCredentialUnavailable()',
      );
      expect(
          genericCredentialIssue,
          contains(
              'shouldReportGenericCaptionCredentialIssue(_state.captionIssueCode)'));
      expect(genericCredentialIssue,
          contains("code: 'caption_token_unavailable'"));
      expect(source, isNot(contains(r': $error')));
      expect(source, isNot(contains(r': $e')));
    });

    test('Daily native quarantine is terminal and does not schedule retry', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final initialize =
          _curlyBlockSource(source, 'Future<void> _initializeCall() async');
      final quarantine =
          _curlyBlockSource(source, 'void _showDailySessionQuarantine()');

      expect(
          initialize, contains('result == DailySessionOpenResult.quarantined'));
      expect(initialize, contains('_dailySession.isQuarantined'));
      expect(initialize, contains('shouldAttemptDailySessionInitialization('));
      expect(initialize, contains('hasTerminalError: _state.hasTerminalError'));
      expect(quarantine, contains('ConnectionState.failed'));
      expect(quarantine, contains('hasTerminalError: true'));
      expect(
          quarantine, isNot(contains('_scheduleProcessActiveCallClientRetry')));

      final build =
          _curlyBlockSource(source, 'Widget build(BuildContext context)');
      final status = _curlyBlockSource(source, 'String? _statusMessage()');
      final errorDisplay =
          _curlyBlockSource(source, 'Widget _buildErrorDisplay(');
      final terminalScreen =
          _curlyBlockSource(source, 'Widget _buildTerminalErrorScreen()');
      final cleanup = _curlyBlockSource(source, 'Future<void> _cleanup(');
      expect(build, contains('shouldRenderDailyTerminalError('));
      expect(
        build.indexOf('shouldRenderDailyTerminalError('),
        lessThan(build.indexOf('shouldRenderDailyConnectingScreen(')),
      );
      expect(terminalScreen, contains('_buildErrorDisplay(allowRetry: false)'));
      expect(status, contains('if (_state.hasTerminalError) return null;'));
      expect(errorDisplay, contains('if (allowRetry) ...['));
      expect(errorDisplay, contains("child: const Text('Повторить попытку')"));
      expect(cleanup, contains('terminalErrorAfterDailyCleanup('));
      expect(cleanup, contains('hasTerminalError: _state.hasTerminalError'));
      expect(cleanup,
          contains('hasTerminalError: terminalError.hasTerminalError'));
    });

    test('Deepgram stop persists a short unfinished caption before clearing',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final transport = _source(
        'lib/custom_code/widgets/deepgram_transport_controller.dart',
      );
      final finalize = _curlyBlockSource(
          source, 'Future<void> _finalizeCurrentCaptionAndFlushLogs() async');
      expect(finalize, contains('_emitFinalUpdateForCurrentLocalCaption();'));
      expect(finalize, contains('while (_outgoingCaptionFlushes.isNotEmpty)'));
      expect(
          finalize, contains('await _flushPendingCaptionLogs(force: true);'));
      expect(transport, contains('await _finalizeCaptionAndFlush();'));
      expect(transport, contains('if (hadTransport) _clearCaption();'));
      expect(
          source,
          contains(
              '(!_state.microphoneEnabled && !_deepgramTransport.finalizing)'));
    });

    test('caption overlay remains available while chat is open', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');

      expect(source, contains('_captionOverlayBottomOffset('));
      expect(source, contains('_captionOverlayTopOffset('));
      expect(source, contains('_captionOverlayMaxHeight('));
      expect(source, contains('_captionKeyboardChatPanelTopOffset('));
      expect(source, contains('_chatPanelBottomOffset('));
      expect(source, contains('reserveCaptionLane'));
      expect(source, contains('_captionKeyboardLaneHeight'));
      expect(source, contains('_captionKeyboardMinChatHeight'));
      expect(source, contains('final captionOverlayBottomOffset'));
      expect(source, contains('final captionOverlayTopOffset'));
      expect(source, contains('final captionOverlayMaxHeight'));
      expect(source, contains('final chatPanelBottomOffset'));
      expect(source, contains('top: captionOverlayTopOffset'));
      expect(source, contains('bottom: captionOverlayTopOffset == null'));
      expect(source, contains('? captionOverlayBottomOffset'));
      expect(source, contains('compact: captionOverlayTopOffset != null'));
      expect(source, contains('maxHeight: captionOverlayMaxHeight'));
      expect(source, contains('bottomOffset: chatPanelBottomOffset'));
      expect(
          source, contains('captionOverlayMaxHeight: captionOverlayMaxHeight'));
      expect(source, contains('SingleChildScrollView'));
      expect(source, isNot(contains('constraints.maxHeight - 260.0')));
      expect(
        source,
        isNot(
            contains('_state.connectionState == ConnectionState.connected &&\n'
                '                  !_state.isChatOpen')),
      );
    });

    test('live caption updates rebuild only the caption overlay', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final captionUpdateSource =
          _curlyBlockSource(source, 'void _updateCaptionState(');
      final localFlushSource =
          _curlyBlockSource(source, 'void _flushLocalCaptionUpdate()');
      final remoteUpsertSource =
          _curlyBlockSource(source, 'void _upsertRemoteCaption(');
      final disposeSource = _curlyBlockSource(source, 'void dispose()');

      expect(
        source,
        contains('ValueListenableBuilder<_CaptionOverlayState>'),
      );
      expect(captionUpdateSource, contains('final layoutChanged'));
      expect(captionUpdateSource, contains('if (layoutChanged)'));
      expect(captionUpdateSource, contains('_state = newState;'));
      expect(
        captionUpdateSource,
        contains('_captionOverlayNotifier.value = nextCaptionState;'),
      );
      expect(localFlushSource, contains('_updateCaptionState('));
      expect(localFlushSource, isNot(contains('_updateState(')));
      expect(remoteUpsertSource, contains('_updateCaptionState('));
      expect(remoteUpsertSource, isNot(contains('_updateState(')));
      expect(disposeSource, contains('_captionOverlayNotifier.dispose();'));
    });

    test('connected billing marker requires Daily verification backend', () {
      final markConnectedSource =
          _source('firebase/custom_cloud_functions/mark_session_connected.js');
      final roomJoinSource =
          _source('firebase/custom_cloud_functions/room_join_signals.js');
      final dailyWebhookSource =
          _source('firebase/custom_cloud_functions/daily_webhook.js');
      final indexSource = _source('firebase/custom_cloud_functions/index.js');

      expect(markConnectedSource, contains('connectedParticipantSignals'));
      expect(markConnectedSource, contains('buildRoomJoinParticipantMetadata'));
      expect(roomJoinSource, contains('roomJoinParticipantSignals'));
      expect(roomJoinSource, contains('roomJoinedParticipantIds'));
      expect(
        markConnectedSource,
        contains('dailyPresenceVerificationRequired'),
      );
      expect(
        markConnectedSource,
        isNot(
            contains('callConnectedAtSource: "markSessionConnectedTwoParty"')),
      );
      expect(markConnectedSource, contains('getDailyRoomPresence'));
      expect(
        markConnectedSource,
        contains('callConnectedAtSource: "dailyPresenceTwoParty"'),
      );

      expect(dailyWebhookSource, contains('x-webhook-signature'));
      expect(dailyWebhookSource, contains('x-webhook-timestamp'));
      expect(
        dailyWebhookSource,
        contains('callConnectedAtSource = "dailyWebhookTwoParty"'),
      );
      expect(indexSource, contains('exports.dailyWebhook'));
    });

    test('tutor accept waits for backend room credentials before navigating',
        () {
      final source = _source('lib/services/voip_service.dart');
      final resolve = _curlyBlockSource(
        source,
        'Future<void> _resolveAcceptedSession(',
      );
      final apply = _curlyBlockSource(
        source,
        'void _applyAcceptedSessionResolution({',
      );

      final acceptCallIndex =
          resolve.indexOf('_callAcceptCallFunction(attempt.sessionId)');
      final credentialsIndex = resolve
          .indexOf('voipRoomCredentialsFromAcceptCallResponse(response)');
      final applyResolutionIndex =
          resolve.indexOf('_applyAcceptedSessionResolution(');
      final resolvedGuardIndex = apply.indexOf(
        'resolution.state != VoipAcceptedSessionResolutionState.resolved',
      );
      final tutorNavigateIndex =
          apply.indexOf('_navigateToVideoCallForAccept(');
      expect(acceptCallIndex, greaterThanOrEqualTo(0));
      expect(credentialsIndex, greaterThan(acceptCallIndex));
      expect(applyResolutionIndex, greaterThan(credentialsIndex));
      expect(resolvedGuardIndex, greaterThanOrEqualTo(0));
      expect(tutorNavigateIndex, greaterThan(resolvedGuardIndex));
    });

    test('CallKit accept opens existing foreground sessions without acceptCall',
        () {
      final source = _source('lib/services/voip_service.dart');
      final accept =
          _curlyBlockSource(source, 'Future<void> _handleCallAccept');
      final resolve = _curlyBlockSource(
        source,
        'Future<void> _resolveAcceptedSession(',
      );

      final credentialsHelperIndex = source.indexOf(
        'VoipRoomCredentials? voipRoomCredentialsFromAcceptedPayload',
      );
      final roomUrlGuardIndex = source.indexOf(
        'final roomUrl = voipRoomUrlFromAcceptPayload(data);',
        credentialsHelperIndex,
      );
      final nullGuardIndex = source.indexOf(
        'if (roomUrl == null)',
        roomUrlGuardIndex,
      );
      final payloadCredentialsIndex = accept.indexOf(
        'final payloadCredentials = voipRoomCredentialsFromAcceptedPayload(data);',
      );
      final acceptActionIndex = accept.indexOf(
        'final acceptAction = voipAcceptActionFromPayload(data);',
        payloadCredentialsIndex,
      );
      final acceptedRoleIndex = accept.indexOf(
        '_lastAcceptedIsTutor = payloadCredentials == null;',
        payloadCredentialsIndex,
      );
      final payloadBranchIndex = accept.indexOf(
        'acceptAction == VoipAcceptPayloadAction.openSession',
        acceptedRoleIndex,
      );
      final noAcceptCallbackIndex = accept.indexOf(
        'accept: () async => null',
        payloadBranchIndex,
      );
      final applyResolutionIndex = accept.indexOf(
        '_applyAcceptedSessionResolution(',
        noAcceptCallbackIndex,
      );
      final acceptCallIndex =
          resolve.indexOf('_callAcceptCallFunction(attempt.sessionId)');

      expect(credentialsHelperIndex, greaterThanOrEqualTo(0));
      expect(roomUrlGuardIndex, greaterThan(credentialsHelperIndex));
      expect(nullGuardIndex, greaterThan(roomUrlGuardIndex));
      expect(payloadCredentialsIndex, greaterThanOrEqualTo(0));
      expect(acceptActionIndex, greaterThan(payloadCredentialsIndex));
      expect(acceptedRoleIndex, greaterThan(payloadCredentialsIndex));
      expect(payloadBranchIndex, greaterThan(acceptedRoleIndex));
      expect(noAcceptCallbackIndex, greaterThan(payloadBranchIndex));
      expect(applyResolutionIndex, greaterThan(noAcceptCallbackIndex));
      expect(acceptCallIndex, greaterThanOrEqualTo(0));
      expect(source, isNot(contains('hasPayloadRoomUrl')));
      expect(source, isNot(contains('hasPayloadMeetingToken')));
    });

    test('tutor accept recovery navigates after backend commit is visible', () {
      final source = _source('lib/services/voip_service.dart');
      final resolve = _curlyBlockSource(
        source,
        'Future<void> _resolveAcceptedSession(',
      );
      final apply = _curlyBlockSource(
        source,
        'void _applyAcceptedSessionResolution({',
      );

      final acceptIndex = resolve.indexOf('accept: () async {');
      final recoveryIndex = resolve.indexOf(
        'recover: () => _recoverActiveSession(attempt.sessionId)',
      );
      final applyIndex = resolve.indexOf('_applyAcceptedSessionResolution(');
      final unresolvedIndex = apply.indexOf(
        'resolution.state == VoipAcceptedSessionResolutionState.unresolved',
      );
      final clearStateIndex =
          apply.indexOf('_clearSessionState(attempt.sessionId);');
      final navigateIndex = apply.indexOf('_navigateToVideoCallForAccept(');
      final navigationTriggeredIndex =
          apply.indexOf('_markNavigationTriggeredForAccept(');

      expect(acceptIndex, greaterThanOrEqualTo(0));
      expect(recoveryIndex, greaterThan(acceptIndex));
      expect(applyIndex, greaterThan(recoveryIndex));
      expect(unresolvedIndex, greaterThanOrEqualTo(0));
      expect(clearStateIndex, greaterThan(unresolvedIndex));
      expect(navigateIndex, greaterThan(clearStateIndex));
      expect(navigationTriggeredIndex, greaterThan(navigateIndex));
    });

    test('legacy student navigation actions wait for joinable room state', () {
      final listenerSource = _source(
          'lib/custom_code/actions/start_student_session_listener.dart');
      final recoverySource = _source(
          'lib/custom_code/actions/check_active_session_and_navigate.dart');

      expect(listenerSource, contains("status == 'connecting'"));
      expect(listenerSource, contains("status == 'connected'"));
      expect(listenerSource, contains('!hasRoomUrl || !isJoinable'));
      expect(listenerSource, contains("httpsCallable('getSessionTokens')"));
      expect(listenerSource, contains('_requestStudentSessionTokensWithRetry'));
      expect(listenerSource, isNot(contains("data?['studentMeetingToken']")));
      expect(
        listenerSource,
        isNot(contains('!hasRoomUrl || !(isJoinable || studentTriggered)')),
      );
      expect(
        recoverySource,
        contains(".orderBy('navigationTimestamp', descending: true)"),
      );
      expect(
        recoverySource,
        contains(".where('currentTutorId', isEqualTo: userId)"),
      );
      expect(
        recoverySource,
        contains(".where('currentResponderId', isEqualTo: userId)"),
      );
      expect(
        recoverySource,
        contains(".where('responderId', isEqualTo: userId)"),
      );
      expect(
        recoverySource,
        contains(".where('participantIds', arrayContains: userId)"),
      );
      expect(
        recoverySource,
        contains('_activeSessionCanUseTutorNavigationFlag(data, userId)'),
      );
      final tutorFlagHelperIndex = recoverySource.indexOf(
        'bool _activeSessionCanUseTutorNavigationFlag',
      );
      final triggerMatchHelperIndex = recoverySource.indexOf(
        'bool _activeSessionNavigationTriggerMatchesUser',
        tutorFlagHelperIndex,
      );
      expect(tutorFlagHelperIndex, greaterThanOrEqualTo(0));
      expect(triggerMatchHelperIndex, greaterThan(tutorFlagHelperIndex));
      expect(
        recoverySource.substring(tutorFlagHelperIndex, triggerMatchHelperIndex),
        isNot(contains("data['participantIds']")),
      );
      expect(
        recoverySource,
        contains('const int _activeSessionLegacyFallbackLimit = 100;'),
      );
      expect(
        recoverySource,
        contains('const int _activeSessionCurrentTokenMaxAttempts = 5;'),
      );
      expect(
        recoverySource,
        contains('retryMissingMeetingToken: true'),
      );
      final legacyStudentQueryIndex = recoverySource.indexOf(
        "final legacyStudentSessions = await FirebaseFirestore.instance",
      );
      final legacyStudentGetIndex =
          recoverySource.indexOf('.get();', legacyStudentQueryIndex);
      final legacyTutorQueryIndex = recoverySource.indexOf(
        "final legacyTutorSessions = await FirebaseFirestore.instance",
      );
      final legacyTutorGetIndex =
          recoverySource.indexOf('.get();', legacyTutorQueryIndex);
      final legacyCurrentResponderQueryIndex = recoverySource.indexOf(
        "final legacyCurrentResponderSessions = await FirebaseFirestore.instance",
      );
      final legacyCurrentResponderGetIndex = recoverySource.indexOf(
        '.get();',
        legacyCurrentResponderQueryIndex,
      );
      final legacyResponderQueryIndex = recoverySource.indexOf(
        "final legacyResponderSessions = await FirebaseFirestore.instance",
      );
      final legacyResponderGetIndex =
          recoverySource.indexOf('.get();', legacyResponderQueryIndex);

      expect(legacyStudentQueryIndex, greaterThanOrEqualTo(0));
      expect(
        recoverySource.substring(
          legacyStudentQueryIndex,
          legacyStudentGetIndex,
        ),
        contains('.limit(_activeSessionLegacyFallbackLimit)'),
      );
      expect(legacyTutorQueryIndex, greaterThanOrEqualTo(0));
      expect(
        recoverySource.substring(legacyTutorQueryIndex, legacyTutorGetIndex),
        contains('.limit(_activeSessionLegacyFallbackLimit)'),
      );
      expect(legacyCurrentResponderQueryIndex, greaterThanOrEqualTo(0));
      expect(
        recoverySource.substring(
          legacyCurrentResponderQueryIndex,
          legacyCurrentResponderGetIndex,
        ),
        contains('.limit(_activeSessionLegacyFallbackLimit)'),
      );
      expect(legacyResponderQueryIndex, greaterThanOrEqualTo(0));
      expect(
        recoverySource.substring(
          legacyResponderQueryIndex,
          legacyResponderGetIndex,
        ),
        contains('.limit(_activeSessionLegacyFallbackLimit)'),
      );

      final recoveryLoopIndex = recoverySource.indexOf('for (final doc in');
      final joinableIndex = recoverySource.indexOf(
        '_activeSessionIsJoinableParticipant',
        recoveryLoopIndex,
      );
      final tokenRequestIndex = recoverySource.indexOf(
        'final tokenData = await _requestActiveSessionTokensWithRetry',
        joinableIndex,
      );
      final roomUrlIndex =
          recoverySource.indexOf("tokenData?['roomUrl']", tokenRequestIndex);
      final docRoomUrlFallbackIndex =
          recoverySource.indexOf("data['dailyRoomUrl']", roomUrlIndex);
      final candidateIndex = recoverySource.indexOf(
        'sessionDoc: doc,',
        docRoomUrlFallbackIndex,
      );

      expect(joinableIndex, greaterThan(recoveryLoopIndex));
      expect(tokenRequestIndex, greaterThan(joinableIndex));
      expect(roomUrlIndex, greaterThan(tokenRequestIndex));
      expect(docRoomUrlFallbackIndex, greaterThan(roomUrlIndex));
      expect(candidateIndex, greaterThan(docRoomUrlFallbackIndex));
      expect(recoverySource, isNot(contains("status == null || status")));
      expect(recoverySource, contains("httpsCallable('getSessionTokens')"));
      expect(recoverySource, contains('_requestActiveSessionTokensWithRetry'));
      expect(recoverySource, contains("'meetingToken': serializeParam"));

      final userDataIndex = recoverySource.indexOf('final userData =');
      final inCallGateIndex = recoverySource.indexOf(
        "if (userData?['isInCall'] != true) {",
        userDataIndex,
      );
      final readCurrentSessionIndex = recoverySource.indexOf(
        'DocumentSnapshot<Map<String, dynamic>>? currentSession;',
        inCallGateIndex,
      );
      expect(userDataIndex, greaterThanOrEqualTo(0));
      expect(inCallGateIndex, greaterThan(userDataIndex));
      expect(
        recoverySource.substring(inCallGateIndex, readCurrentSessionIndex),
        contains('return false;'),
      );
      expect(readCurrentSessionIndex, greaterThan(inCallGateIndex));

      final currentJoinableIndex =
          recoverySource.indexOf('final currentSessionIsJoinable =');
      final currentReturnFalseIndex = recoverySource.indexOf(
        'if (selectedCandidate == null && currentSessionIsJoinable) {',
        currentJoinableIndex,
      );
      final fallbackQueryIndex = recoverySource.indexOf(
        'await _readActiveNavigationSessionSnapshots(userId)',
        currentReturnFalseIndex,
      );
      final currentReadFailedReturnIndex = recoverySource.indexOf(
        'if (selectedCandidate == null && currentSessionReadFailed) {',
        currentReturnFalseIndex,
      );
      final fallbackTriggerFilterIndex = recoverySource.indexOf(
        '_activeSessionNavigationTriggerMatchesUser(data, userId)',
        fallbackQueryIndex,
      );
      expect(currentJoinableIndex, greaterThanOrEqualTo(0));
      expect(currentReturnFalseIndex, greaterThan(currentJoinableIndex));
      expect(
        recoverySource.substring(currentReturnFalseIndex, fallbackQueryIndex),
        contains('return false;'),
      );
      expect(
          currentReadFailedReturnIndex, greaterThan(currentReturnFalseIndex));
      expect(currentReadFailedReturnIndex, lessThan(fallbackQueryIndex));
      expect(
        recoverySource.substring(
          currentReadFailedReturnIndex,
          fallbackQueryIndex,
        ),
        contains('return false;'),
      );
      expect(fallbackQueryIndex, greaterThan(currentReturnFalseIndex));
      expect(fallbackTriggerFilterIndex, greaterThan(fallbackQueryIndex));
      expect(
        recoverySource,
        contains(
          "const List<String> _activeSessionNeutralRecoveryStatuses = [",
        ),
      );
      expect(recoverySource, contains("'connecting',"));
      expect(recoverySource, contains("'active',"));
      expect(recoverySource, contains("'connected',"));
      expect(
        recoverySource,
        contains(
          ".where('requesterId', isEqualTo: userId)",
        ),
      );
      expect(
        recoverySource,
        contains(
          ".where('status', whereIn: _activeSessionNeutralRecoveryStatuses)",
        ),
      );
      expect(
        recoverySource,
        contains(
          ".where('currentResponderId', isEqualTo: userId)",
        ),
      );
      expect(
        recoverySource,
        contains(
          ".where('responderId', isEqualTo: userId)",
        ),
      );
      expect(
        recoverySource,
        contains(
          ".where('participantIds', arrayContains: userId)",
        ),
      );
    });

    test('active session legacy fallback indexes navigation timestamp', () {
      final indexes = jsonDecode(
        _source('firebase/firestore.indexes.json'),
      ) as Map<String, dynamic>;
      final indexEntries =
          (indexes['indexes'] as List<dynamic>).cast<Map<String, dynamic>>();

      bool hasVideoSessionIndex(List<String> fields, List<String> modes) {
        return indexEntries.any((index) {
          if (index['collectionGroup'] != 'videoSessions') {
            return false;
          }
          final indexFields =
              (index['fields'] as List<dynamic>).cast<Map<String, dynamic>>();
          return indexFields.map((field) => field['fieldPath']).toList().join(
                        '|',
                      ) ==
                  fields.join('|') &&
              indexFields
                      .map((field) => field['order'] ?? field['arrayConfig'])
                      .toList()
                      .join('|') ==
                  modes.join('|');
        });
      }

      expect(
        hasVideoSessionIndex(
          [
            'studentId',
            'studentNavigationTriggered',
            'navigationTimestamp',
          ],
          ['ASCENDING', 'ASCENDING', 'DESCENDING'],
        ),
        isTrue,
      );
      expect(
        hasVideoSessionIndex(
          [
            'tutorId',
            'tutorNavigationTriggered',
            'navigationTimestamp',
          ],
          ['ASCENDING', 'ASCENDING', 'DESCENDING'],
        ),
        isTrue,
      );
      expect(
        hasVideoSessionIndex(
          [
            'currentTutorId',
            'tutorNavigationTriggered',
            'navigationTimestamp',
          ],
          ['ASCENDING', 'ASCENDING', 'DESCENDING'],
        ),
        isTrue,
      );
      expect(
        hasVideoSessionIndex(
          [
            'currentResponderId',
            'tutorNavigationTriggered',
            'navigationTimestamp',
          ],
          ['ASCENDING', 'ASCENDING', 'DESCENDING'],
        ),
        isTrue,
      );
      expect(
        hasVideoSessionIndex(
          [
            'responderId',
            'tutorNavigationTriggered',
            'navigationTimestamp',
          ],
          ['ASCENDING', 'ASCENDING', 'DESCENDING'],
        ),
        isTrue,
      );
      expect(
        hasVideoSessionIndex(
          [
            'participantIds',
            'tutorNavigationTriggered',
            'navigationTimestamp',
          ],
          ['CONTAINS', 'ASCENDING', 'DESCENDING'],
        ),
        isTrue,
      );
      expect(
        hasVideoSessionIndex(
          [
            'participantIds',
            'status',
            'createdAt',
          ],
          ['CONTAINS', 'ASCENDING', 'DESCENDING'],
        ),
        isTrue,
      );
      expect(
        hasVideoSessionIndex(
          [
            'requesterId',
            'status',
            'createdAt',
          ],
          ['ASCENDING', 'ASCENDING', 'DESCENDING'],
        ),
        isTrue,
      );
      expect(
        hasVideoSessionIndex(
          [
            'currentResponderId',
            'status',
            'createdAt',
          ],
          ['ASCENDING', 'ASCENDING', 'DESCENDING'],
        ),
        isTrue,
      );
      expect(
        hasVideoSessionIndex(
          [
            'responderId',
            'status',
            'createdAt',
          ],
          ['ASCENDING', 'ASCENDING', 'DESCENDING'],
        ),
        isTrue,
      );
    });

    test('root app recovers accepted sessions on foreground resume', () {
      final mainSource = _source('lib/main.dart');
      final helperIndex =
          mainSource.indexOf('Future<void> _recoverActiveSessionOnResume()');
      final videoRouteGuardIndex = mainSource.indexOf(
        'startsWith(VideoCallPageWidget.routePath)',
        helperIndex,
      );
      final actionCallIndex = mainSource.indexOf(
        'await actions.checkActiveSessionAndNavigate(navContext);',
        videoRouteGuardIndex,
      );
      final authScheduleHelperIndex = mainSource.indexOf(
        'void _scheduleActiveSessionRecoveryAfterAuth()',
        actionCallIndex,
      );
      final loggedInBranchIndex = mainSource.indexOf(
        'if (user.loggedIn && !wasLoggedIn)',
        authScheduleHelperIndex,
      );
      final authScheduleCallIndex = mainSource.indexOf(
        '_scheduleActiveSessionRecoveryAfterAuth();',
        loggedInBranchIndex,
      );
      final lifecycleIndex = mainSource.indexOf(
        'void didChangeAppLifecycleState(AppLifecycleState state)',
      );
      final resumeCallIndex = mainSource.indexOf(
        'unawaited(_recoverActiveSessionOnResume());',
        lifecycleIndex,
      );

      expect(helperIndex, greaterThanOrEqualTo(0));
      expect(videoRouteGuardIndex, greaterThan(helperIndex));
      expect(actionCallIndex, greaterThan(videoRouteGuardIndex));
      expect(authScheduleHelperIndex, greaterThan(actionCallIndex));
      expect(loggedInBranchIndex, greaterThan(authScheduleHelperIndex));
      expect(authScheduleCallIndex, greaterThan(loggedInBranchIndex));
      expect(lifecycleIndex, greaterThan(authScheduleCallIndex));
      expect(resumeCallIndex, greaterThan(lifecycleIndex));
    });

    test(
        'firestore rules require explicit responder for tutor navigation cleanup',
        () {
      final rulesSource = _source('firebase/firestore.rules');
      final helperStart = rulesSource.indexOf(
        'function canUpdateVideoSessionNavigationState()',
      );
      final helperEnd = rulesSource.indexOf(
        'function videoSessionData',
        helperStart,
      );
      expect(helperStart, greaterThanOrEqualTo(0));
      expect(helperEnd, greaterThan(helperStart));
      final helperBody = rulesSource.substring(helperStart, helperEnd);

      expect(helperBody, contains('isResponderForSession(resource.data)'));
      expect(
        helperBody,
        isNot(contains('isParticipantIdForSession(resource.data)')),
      );
    });

    test('VoIP accept outer error path clears claimed session state', () {
      final source = _source('lib/services/voip_service.dart');
      final handleAcceptIndex =
          source.indexOf('Future<void> _handleCallAccept');
      final outerCatchIndex = source.indexOf(
        "debugPrint('❌ VoIPService: Error in call accept flow: \$e');",
        handleAcceptIndex,
      );
      final outerClearIndex = source.indexOf(
        '_clearSessionState(sessionId);',
        outerCatchIndex,
      );
      final finallyIndex = source.indexOf('} finally {', outerCatchIndex);

      expect(handleAcceptIndex, greaterThanOrEqualTo(0));
      expect(outerCatchIndex, greaterThan(handleAcceptIndex));
      expect(outerClearIndex, greaterThan(outerCatchIndex));
      expect(finallyIndex, greaterThan(outerClearIndex));
    });

    test('VoIP token prefetch clears stale credentials before session swap',
        () {
      final source = _source('lib/services/voip_service.dart');
      final clearHelperIndex =
          source.indexOf('void _clearPrefetchedSessionCredentials()');
      final prefetchIndex = source
          .indexOf('Future<void> _prefetchSessionTokens(String sessionId)');
      final newSessionGuardIndex = source.indexOf(
        'if (_prefetchedSessionId != sessionId) {',
        prefetchIndex,
      );
      final clearCallIndex = source.indexOf(
        '_clearPrefetchedSessionCredentials();',
        newSessionGuardIndex,
      );
      final sessionIdAssignIndex = source.indexOf(
        '_prefetchedSessionId = sessionId;',
        clearCallIndex,
      );

      expect(clearHelperIndex, greaterThanOrEqualTo(0));
      expect(
        source.substring(clearHelperIndex, prefetchIndex),
        allOf(
          contains('_prefetchedMeetingToken = null;'),
          contains('_prefetchedRoomUrl = null;'),
          contains('_prefetchedRoomName = null;'),
          contains('_prefetchedTokenFetchedAt = null;'),
        ),
      );
      expect(newSessionGuardIndex, greaterThan(prefetchIndex));
      expect(clearCallIndex, greaterThan(newSessionGuardIndex));
      expect(sessionIdAssignIndex, greaterThan(clearCallIndex));
    });

    test('VoIP service listens to assigned Firestore call notifications', () {
      final source = _source('lib/services/voip_service.dart');

      expect(source, contains('_incomingNotificationSub'));
      expect(source, contains('_startIncomingNotificationListener()'));
      expect(source, contains("collection('notifications')"));
      expect(source, contains(".where('recipientId', isEqualTo: userId)"));
      expect(source, contains("NotificationType.incoming_call.name"));
      expect(source, contains("status != 'sent'"));
      expect(
          source, contains('_dateTimeFromFirestoreValue(data[\'expiresAt\'])'));
      expect(source, contains("collection('videoSessions').doc(sessionId)"));
      expect(
        source,
        contains('voipIncomingSessionMatchesResponder('),
      );
      expect(
          source, contains('voipAssignedResponderIdForSession(sessionData)'));
      expect(
        source,
        contains('Firestore incoming call notification received'),
      );
      expect(source, contains('await showIncomingCall('));
      expect(source, contains('final payloadExpiresAt ='));
      expect(
        source,
        contains('_payloadExpiresAtForIncomingNotification(notificationData)'),
      );
      expect(source, contains("['payloadExpiresAt', 'expiresAt']"));
      expect(source, contains('.toUtc()'));
      expect(source, contains('.toIso8601String()'));
      expect(source, contains("'studentName': callerName"));
      expect(source, contains("'studentId': callerId"));
      expect(source, contains("'studentPhoto': callerPhoto"));
      expect(source, contains("'expiresAt': payloadExpiresAt"));
      expect(source, contains('await notificationSub.cancel();'));
    });

    test('background incoming call payload preserves call metadata parity', () {
      final source = _source('lib/main.dart');
      final showIncomingCallIndex = source.indexOf(
        'await VoIPService().showIncomingCall(',
      );
      final extraDataIndex = source.indexOf(
        'extraData: voipIncomingCallExtraDataFromPayload(message.data)',
        showIncomingCallIndex,
      );

      expect(showIncomingCallIndex, greaterThanOrEqualTo(0));
      expect(extraDataIndex, greaterThan(showIncomingCallIndex));

      final voipSource = _source('lib/services/voip_service.dart');
      final appDelegateSource = _source('ios/Runner/AppDelegate.swift');
      expect(voipSource, contains("'roomUrl'"));
      expect(voipSource, contains("'meetingToken'"));
      expect(voipSource, contains("'roomName'"));
      expect(voipSource, contains("'tokenStrategy'"));
      expect(voipSource, contains("'searchRequestId'"));
      expect(voipSource, contains("'expiresAt'"));
      expect(appDelegateSource, contains('"roomUrl"'));
      expect(appDelegateSource, contains('"meetingToken"'));
      expect(appDelegateSource, contains('"roomName"'));
      expect(appDelegateSource, contains('"tokenStrategy"'));
      expect(appDelegateSource, contains('"searchRequestId"'));
      expect(appDelegateSource, contains('"expiresAt"'));
    });

    test(
        'iOS CallKit keeps exact UUID identity and reports cancellation pushes',
        () {
      final appDelegateSource = _source('ios/Runner/AppDelegate.swift');
      final podfileSource = _source('ios/Podfile');
      final pubspecSource = _source('pubspec.yaml');

      expect(pubspecSource, contains('flutter_callkit_incoming: ^3.1.3'));
      expect(
        podfileSource,
        contains('patch_callkit_incoming_exact_identity(installer)'),
      );
      expect(
        podfileSource,
        contains('ACTION_CALL_DECLINE, call.data.toJSON()'),
      );
      expect(
        podfileSource,
        contains('let uuidSourceString = data.uuid'),
      );
      expect(
        appDelegateSource,
        contains('plugin.showCallkitIncoming(cancelData, fromPushKit: true)'),
      );
      expect(appDelegateSource, contains('plugin.saveEndCall(callKitId, 2)'));
      expect(
        appDelegateSource,
        contains('flutterServerEndedCallKitTombstonesKey'),
      );
      expect(
        appDelegateSource,
        contains(
            'defaults.string(forKey: flutterServerEndedCallKitTombstonesKey)'),
      );
    });

    test('background accepted calls replay through VoIP accept flow', () {
      final mainSource = _source('lib/main.dart');
      final voipSource = _source('lib/services/voip_service.dart');
      final initializeSource = _curlyBlockSource(
        voipSource,
        'Future<void> initialize() async {',
      );
      final callKitSubscriptionSource = _curlyBlockSource(
        voipSource,
        'void _ensureCallKitEventSubscription() {',
      );
      final recoverSource = _curlyBlockSource(
        voipSource,
        'Future<void> recoverBackgroundAcceptedCalls() async {',
      );

      expect(mainSource, contains('await VoIPService().initialize()'));
      expect(mainSource, contains('unawaited(_initializeVoipService('));
      expect(initializeSource, contains('_ensureCallKitEventSubscription()'));
      expect(
        callKitSubscriptionSource,
        contains('FlutterCallkitIncoming.onEvent'),
      );
      expect(
          initializeSource, contains('await recoverBackgroundAcceptedCalls()'));
      expect(recoverSource, contains('_callActiveCalls()'));
      expect(recoverSource, contains('voipAcceptDataFromActiveCalls'));
      expect(recoverSource, contains('await _handleCallAccept(acceptData)'));
      expect(voipSource, contains('FlutterCallkitIncoming.activeCalls()'));
      expect(voipSource, contains('voipAcceptDataFromActiveCall'));
      expect(voipSource, contains("'isAccepted'"));
      expect(voipSource, contains("'accepted'"));
    });

    test('caption persistence delegates queue state without moving Firebase',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final enqueue =
          _curlyBlockSource(source, 'void _enqueueCaptionLogEntry(');
      final flush =
          _curlyBlockSource(source, 'Future<void> _flushPendingCaptionLogs(');

      expect(source, contains("import 'caption_log_queue.dart';"));
      expect(source,
          contains('final CaptionLogQueue<_CaptionLogEntry> _captionLogQueue'));
      expect(source, isNot(contains('_pendingCaptionLogEntries')));
      expect(source, isNot(contains('_persistedCaptionLogIds')));
      expect(source, isNot(contains('_captionLogFlushChain')));
      expect(enqueue.indexOf('if (!_canPersistCaptionLogs())'),
          lessThan(enqueue.indexOf('_captionLogQueue.enqueue(')));
      expect(enqueue, contains('_captionLogQueue.enqueue(entry.logId, entry)'));
      expect(
          enqueue,
          contains(
              '_captionLogQueue.pendingCount >= _captionLogBatchThreshold'));
      expect(flush, contains('_captionLogQueue.flush((queuedEntries) async'));
      expect(flush, contains('final sessionRef = _captionLogSessionRef();'));
      expect(flush, contains('final writerId = _captionLogWriterId();'));
      expect(flush, contains('if (sessionRef == null || writerId == null)'));
      expect(flush, contains('return false;'));
    });

    test('caption persistence keeps document ID, schema and merge batch', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final flush =
          _curlyBlockSource(source, 'Future<void> _flushPendingCaptionLogs(');
      expect(flush, contains('FirebaseFirestore.instance.batch()'));
      expect(flush, contains('for (final queuedEntry in queuedEntries)'));
      expect(flush, contains('final entry = queuedEntry.value;'));
      expect(flush,
          contains('CaptionLogsRecord.createDoc(sessionRef, id: entry.logId)'));
      expect(flush, contains('entry.toFirestoreData(writerId: writerId)'));
      expect(flush, contains('SetOptions(merge: true)'));
      expect(flush, contains('await batch.commit();'));
      expect(flush.indexOf('await batch.commit();'),
          lessThan(flush.indexOf('return true;')));
    });

    test('caption queue preserves debounce, threshold and current retry guards',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final enqueue =
          _curlyBlockSource(source, 'void _enqueueCaptionLogEntry(');
      final flush =
          _curlyBlockSource(source, 'Future<void> _flushPendingCaptionLogs(');
      expect(source,
          contains('static const int _captionLogFlushDebounceMs = 1000;'));
      expect(
          source, contains('static const int _captionLogBatchThreshold = 8;'));
      expect(enqueue, contains('_createTrackedTimer('));
      expect(enqueue, contains('_captionLogFlushDebounceMs'));
      expect(enqueue, contains('_flushPendingCaptionLogs(force: true)'));
      expect(flush, contains('if (force)'));
      expect(flush, contains('_cancelTrackedTimer(_captionLogFlushTimer)'));
      expect(flush, contains(".catchError((Object _)"));
      expect(flush, contains("print('Caption log flush: failed')"));
      expect(flush, isNot(contains('sessionRef.path')));
      expect(flush, contains('if (!_captionLogQueue.isEmpty &&'));
      expect(flush, contains('_captionLogFlushTimer == null &&'));
      expect(flush, contains('!_disposed'));
      expect(flush, contains('_createTrackedTimer('));
      expect(flush, contains('_captionLogFlushDebounceMs'));
      expect(flush, contains('_flushPendingCaptionLogs(force: true)'));
    });

    test('session switch cancels caption timer before queue generation reset',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final didUpdate = _curlyBlockSource(source, 'void didUpdateWidget(');
      final sessionSwitch =
          _curlyBlockSource(didUpdate, 'if (sessionIdChanged)');
      final cancel =
          sessionSwitch.indexOf('_cancelTrackedTimer(_captionLogFlushTimer);');
      final clearTimer = sessionSwitch.indexOf('_captionLogFlushTimer = null;');
      final reset = sessionSwitch.indexOf('_captionLogQueue.reset();');
      expect(cancel, greaterThanOrEqualTo(0));
      expect(cancel, lessThan(clearTimer));
      expect(clearTimer, lessThan(reset));
      expect(
          sessionSwitch, contains('_reportedCaptionRuntimeIssueCodes.clear()'));
    });

    test('local caption state and emission mapping delegate to the assembler',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      expect(source, contains("import 'local_caption_assembler.dart';"));
      expect(source,
          contains('final _localCaptionAssembler = LocalCaptionAssembler();'));
      for (final oldField in [
        '_localCaptionUtteranceId',
        '_localCaptionRevision',
        '_localUtteranceOpen',
        '_localCommittedCaptionText',
        '_localCurrentCaptionText',
        '_localCaptionStartedAt',
        '_localCaptionConfidence',
      ]) {
        expect(source, isNot(contains(oldField)));
      }
      final handler =
          _curlyBlockSource(source, 'void _handleDeepgramTranscript(');
      final finalUpdate = _curlyBlockSource(
          source, 'bool _emitFinalUpdateForCurrentLocalCaption(');
      expect(handler, contains('_localCaptionAssembler.acceptTranscript('));
      expect(handler, contains('transcript: transcript,'));
      expect(handler, contains('isFinalSegment: isFinalSegment,'));
      expect(handler, contains('speechFinal: speechFinal,'));
      expect(handler, contains('confidence: confidence,'));
      expect(
          handler.indexOf('_clearCaptionRuntimeIssue();'),
          lessThan(
              handler.indexOf('_localCaptionAssembler.acceptTranscript(')));
      expect(handler, contains('if (!_deepgramTransport.finalizing &&'));
      expect(
          handler,
          contains(
              '(!_state.microphoneEnabled || !_hasRemoteParticipantPresent())'));
      expect(
          finalUpdate, contains('_localCaptionAssembler.prepareFinalUpdate()'));
      expect(finalUpdate, contains('if (emission == null) return false;'));
      for (final body in [handler, finalUpdate]) {
        for (final field in [
          'utteranceId',
          'revision',
          'text',
          'startedAt',
          'lastUpdateAt'
        ]) {
          expect(body, contains('$field: emission.$field,'));
        }
        expect(body, contains('emission.isFinal ?'));
        expect(body, contains('? _CaptionPhase.finalCaption'));
        expect(body, contains(': _CaptionPhase.interim,'));
      }
    });

    test('local final caption dispatch and logging precede explicit close', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final handler =
          _curlyBlockSource(source, 'void _handleDeepgramTranscript(');
      final finalUpdate = _curlyBlockSource(
          source, 'bool _emitFinalUpdateForCurrentLocalCaption(');
      for (final body in [handler, finalUpdate]) {
        final local = body.indexOf('_queueLocalCaptionUpdate(');
        final outgoing = body.indexOf('_queueOutgoingCaptionMessage(');
        final log = body.indexOf('_enqueueLocalFinalCaptionLog(update);');
        final close =
            body.indexOf('_finalizeLocalUtterance(fallbackText: update.text);');
        expect(local, greaterThanOrEqualTo(0));
        expect(local, lessThan(outgoing));
        expect(outgoing, lessThan(log));
        expect(log, lessThan(close));
        expect(body, isNot(contains('finally')));
      }
      expect(_curlyBlockSource(handler, 'if (speechFinal)'),
          contains('_enqueueLocalFinalCaptionLog(update);'));
      expect(handler, contains('immediate: speechFinal'));
      expect(finalUpdate, contains('immediate: true'));
      final close = _curlyBlockSource(source, 'void _finalizeLocalUtterance(');
      expect(close, contains('if (finalText.isEmpty)'));
      expect(close.indexOf('if (finalText.isEmpty)'),
          lessThan(close.indexOf('_cancelLocalUtteranceEndFallback();')));
      expect(
          close.indexOf('_cancelLocalUtteranceEndFallback();'),
          lessThan(close
              .indexOf('_localCaptionAssembler.closeUtterance(finalText);')));
      expect(close.indexOf('_localCaptionAssembler.closeUtterance(finalText);'),
          lessThan(close.indexOf('_scheduleCaptionFadeAndClear(')));
    });

    test('local utterance-end timer retains snapshot guards and ownership', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final fallback =
          _curlyBlockSource(source, 'void _handleDeepgramUtteranceEnd(');
      expect(fallback, contains('_localCaptionAssembler.currentText.isEmpty'));
      expect(fallback,
          contains('final utteranceId = _localCaptionAssembler.utteranceId;'));
      expect(
          fallback,
          contains(
              'final revisionAtSignal = _localCaptionAssembler.revision;'));
      expect(fallback, contains('_createTrackedTimer('));
      expect(fallback, contains('_captionUtteranceEndFallbackMs'));
      expect(fallback,
          contains('utteranceId != _localCaptionAssembler.utteranceId'));
      expect(fallback,
          contains('revisionAtSignal != _localCaptionAssembler.revision'));
      expect(fallback, contains('if (!_localCaptionAssembler.isOpen ||'));
      expect(
          fallback
              .indexOf('revisionAtSignal != _localCaptionAssembler.revision'),
          lessThan(
              fallback.indexOf('_emitFinalUpdateForCurrentLocalCaption();')));
    });

    test('local caption clear and persisted confidence use the same assembler',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final clear = _curlyBlockSource(source, 'void _clearLocalCaptions(');
      final reset = clear.indexOf('_localCaptionAssembler.clear();');
      expect(reset, greaterThanOrEqualTo(0));
      for (final earlier in [
        '_invalidateLocalCaptionClear();',
        '_localUtteranceEndTimer = null;',
        '_pendingLocalCaptionUpdate = null;',
        '_outgoingCaptionBuffer.clear();',
      ]) {
        expect(clear.indexOf(earlier), greaterThanOrEqualTo(0));
        expect(clear.indexOf(earlier), lessThan(reset));
      }
      expect(
          reset, lessThan(clear.indexOf('if (_state.localCaption == null)')));
      expect(_curlyBlockSource(source, 'void _enqueueLocalFinalCaptionLog('),
          contains('confidence: _localCaptionAssembler.confidence,'));
    });

    test('remote caption handler binds the peer snapshot to tested policy', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final handler = _curlyBlockSource(source, 'void _processCaptionMessage(');
      expect(source,
          contains("import 'caption_message_policy.dart' as caption_policy;"));
      expect(handler, contains('final current = _state.remoteCaptions[from];'));
      expect(handler, contains('caption_policy.resolveRemoteCaptionMessage('));
      expect(handler, contains('payload,'));
      expect(handler, contains('current: current == null'));
      expect(handler, contains('utteranceId: current.utteranceId,'));
      expect(handler, contains('revision: current.revision,'));
      expect(handler, contains('text: current.text,'));
      expect(handler,
          contains('isFinal: current.phase == _CaptionPhase.finalCaption,'));
      expect(handler, contains('isFadingOut: current.isFadingOut,'));
      expect(handler,
          contains('legacyCounter: _remoteLegacyCaptionCounters[from] ?? 0,'));
      expect(_curlyBlockSource(source, 'String _normalizeCaptionText('),
          contains('return caption_policy.normalizeCaptionText(rawText);'));
      expect(source, isNot(contains('_nextLegacyRemoteUtteranceId(')));
      expect(source, isNot(contains('_CaptionPhase.fromWire(')));
    });

    test('remote caption effects apply counter before update and legacy log',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final handler = _curlyBlockSource(source, 'void _processCaptionMessage(');
      expect(handler,
          contains('final counterUpdate = decision.legacyCounterUpdate;'));
      expect(handler, contains('if (counterUpdate != null)'));
      expect(handler, contains('final update = decision.update;'));
      final counterWrite = handler
          .indexOf('_remoteLegacyCaptionCounters[from] = counterUpdate;');
      final skipUpdate = handler.indexOf('if (update == null) return;');
      final renderUpdate = handler.indexOf('_upsertRemoteCaption(');
      final logCondition = handler.indexOf('if (update.shouldLogLegacyFinal)');
      expect(counterWrite, greaterThanOrEqualTo(0));
      expect(counterWrite, lessThan(skipUpdate));
      expect(skipUpdate, lessThan(renderUpdate));
      expect(renderUpdate, lessThan(logCondition));
      expect(handler, contains('participantId: from,'));
      expect(handler, contains('utteranceId: update.utteranceId,'));
      expect(handler, contains('revision: update.revision,'));
      expect(handler, contains('text: update.text,'));
      expect(handler, contains('update.isFinal ?'));
      expect(handler, contains('? _CaptionPhase.finalCaption'));
      expect(handler, contains(': _CaptionPhase.interim,'));
      final logBody =
          _curlyBlockSource(handler, 'if (update.shouldLogLegacyFinal)');
      expect(logBody, contains('_enqueueLegacyRemoteCaptionLog('));
      expect(logBody, contains('from,'));
      expect(logBody, contains('utteranceId: update.utteranceId,'));
      expect(logBody, contains('text: update.text,'));
    });

    test('remote caption UI timing and counter lifetime remain widget-owned',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final upsert = _curlyBlockSource(source, 'void _upsertRemoteCaption(');
      expect(upsert, contains('final now = DateTime.now();'));
      expect(
          upsert, contains('_nextRemoteCaptionClearGeneration(participantId)'));
      expect(upsert, contains('_updateCaptionState('));
      expect(
          upsert,
          contains(
              'startedAt: current != null && current.utteranceId == utteranceId'));
      expect(upsert, contains('? current.startedAt'));
      expect(upsert, contains('lastUpdateAt: now,'));
      expect(upsert, contains('if (phase == _CaptionPhase.finalCaption)'));
      expect(upsert, contains('_scheduleCaptionFadeAndClear('));
      expect(upsert, contains('expectedGeneration: nextGeneration,'));
      expect(upsert,
          isNot(contains('current.phase == _CaptionPhase.finalCaption')));
      expect(_curlyBlockSource(source, 'void _removeRemoteParticipant('),
          contains('_remoteLegacyCaptionCounters.remove(id);'));
      expect(_curlyBlockSource(source, 'Future<void> _cleanup('),
          contains('_remoteLegacyCaptionCounters.clear();'));
      expect(_curlyBlockSource(source, 'void _clearRemoteCaption('),
          isNot(contains('_remoteLegacyCaptionCounters')));
    });

    test('Daily lifecycle queue keeps widget guards and diagnostic wiring', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      expect(
          source, contains("import 'daily_lifecycle_transition_queue.dart';"));
      expect(
          source,
          contains(
              'final _lifecycleTransitions = DailyLifecycleTransitionQueue('));
      expect(source, contains('onError: (_) {'));
      expect(source, contains("print('Daily lifecycle: transition_failed');"));
      expect(source, isNot(contains('_lifecycleTransitionChain')));
      expect(source, isNot(contains('_lifecycleTransitionId')));
      expect(
          _curlyBlockSource(
              source, 'Future<void> _enqueueLifecycleTransition('),
          contains('return _lifecycleTransitions.enqueue(action);'));

      final guard =
          _curlyBlockSource(source, 'bool _isCurrentLifecycleTransition(');
      expect(guard, contains('return mounted &&'));
      expect(guard, contains('!_disposed &&'));
      expect(
          guard, contains('_lifecycleTransitions.isCurrent(transitionId) &&'));
      expect(guard,
          contains('_state.connectionState == ConnectionState.connected;'));
    });

    test('Daily lifecycle effects keep cooperative checks around awaits', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final background =
          _curlyBlockSource(source, 'void _handleAppBackground()');
      final foreground =
          _curlyBlockSource(source, 'void _handleAppForeground()');
      const guard = 'if (!_isCurrentLifecycleTransition(transitionId)) return;';
      for (final handler in [background, foreground]) {
        expect(
            handler,
            contains(
                'if (_state.connectionState == ConnectionState.connected)'));
        expect(handler, contains('unawaited(_enqueueLifecycleTransition('));
        expect(handler.indexOf(guard), greaterThanOrEqualTo(0));
        expect(handler.indexOf(guard),
            lessThan(handler.indexOf('await _updateInputSettings(')));
      }
      expect(
          background, contains('_resumeCameraEnabled = _state.cameraEnabled;'));
      expect(background,
          contains('_resumeMicrophoneEnabled = _state.microphoneEnabled;'));
      expect(background, contains('camera: false, microphone: false'));
      expect(foreground,
          contains('final resumeCameraEnabled = _resumeCameraEnabled;'));
      expect(
          foreground,
          contains(
              'final resumeMicrophoneEnabled = _resumeMicrophoneEnabled;'));
      expect(foreground, contains('camera: resumeCameraEnabled,'));
      expect(foreground, contains('microphone: resumeMicrophoneEnabled,'));
      expect(guard.allMatches(foreground).length, 2);
      expect(foreground.lastIndexOf(guard),
          greaterThan(foreground.indexOf('await _updateInputSettings(')));
      expect(foreground.lastIndexOf(guard),
          lessThan(foreground.indexOf('await _promoteToActiveCallIfReady();')));
    });

    test('Daily cleanup invalidates lifecycle tokens before async teardown',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final cleanup = _curlyBlockSource(source, 'Future<void> _cleanup(');
      final invalidation =
          cleanup.indexOf('_lifecycleTransitions.invalidate();');
      expect(invalidation, greaterThanOrEqualTo(0));
      expect(invalidation, lessThan(cleanup.indexOf('await ')));

      final dispose = _curlyBlockSource(source, 'void dispose()');
      expect(dispose.indexOf('_disposed = true;'), greaterThanOrEqualTo(0));
      expect(dispose.indexOf('_disposed = true;'),
          lessThan(dispose.indexOf('_cleanup(leaveCall: true)')));
    });

    test('Daily credential wrappers delegate to the tested pure rules', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      expect(
          source,
          contains(
              "import 'daily_join_credentials.dart' as join_credentials;"));

      // Native media clients cannot be started by these source-contract tests.
      // Assert only their wiring; behavior is covered by direct helper tests.
      const wrappers = {
        'bool _isValidRoomUrl(String url)': 'isValidRoomUrl(url)',
        'String? _sanitizeMeetingToken(String? token)':
            'sanitizeMeetingToken(token)',
        'String? _sanitizeRoomUrl(String? url)': 'sanitizeRoomUrl(url)',
        'String? _sanitizeDeepgramCredential(String? value)':
            'sanitizeDeepgramCredential(value)',
      };
      for (final entry in wrappers.entries) {
        expect(_curlyBlockSource(source, entry.key),
            contains('return join_credentials.${entry.value};'));
      }

      final token =
          _curlyBlockSource(source, 'String? _effectiveMeetingToken()');
      expect(token, contains('return join_credentials.effectiveMeetingToken('));
      expect(token, contains('dynamicToken: _dynamicMeetingToken,'));
      expect(token, contains('configuredToken: widget.meetingToken,'));

      final room = _curlyBlockSource(source, 'String? _effectiveRoomUrl()');
      expect(room, contains('return join_credentials.effectiveRoomUrl('));
      expect(room, contains('dynamicRoomUrl: _dynamicRoomUrl,'));
      expect(room, contains('configuredRoomUrl: widget.roomUrl,'));

      final deepgram = _curlyBlockSource(
          source, 'String? _configuredDeepgramCredentialFor(');
      expect(deepgram,
          contains('return join_credentials.configuredDeepgramCredential('));
      expect(deepgram,
          contains('primaryCredential: widgetInstance.deepgramCredential,'));
      expect(
          deepgram, contains('legacyApiKey: widgetInstance.deepgramApiKey,'));

      expect(
          _curlyBlockSource(source, 'bool _hasValidJoinData()'),
          contains(
              '_effectiveRoomUrl() != null && _effectiveMeetingToken() != null'));
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
      expect(waitingSource, contains('final isJoinable'));
      expect(waitingSource, contains("status == 'pending_confirmation'"));
      expect(waitingSource, contains("status == 'expired'"));

      expect(dailyWidgetSource, contains('String? _dynamicRoomUrl;'));
      expect(dailyWidgetSource, contains('_effectiveRoomUrl()'));
      expect(dailyWidgetSource, contains("normalized == 'expired'"));
      expect(dailyWidgetSource, contains("status == 'expired'"));
      expect(
        dailyWidgetSource,
        contains('await WidgetsBinding.instance.endOfFrame;'),
      );
    });

    test('VideoCallPage handles nullable and changed session references', () {
      final widgetSource = _source(
          'lib/shared_pages/video_call_page/video_call_page_widget.dart');
      final modelSource = _source(
          'lib/shared_pages/video_call_page/video_call_page_model.dart');

      expect(widgetSource, isNot(contains('widget.videoDocRef!')));
      expect(widgetSource, contains('_model.bindSession(widget.videoDocRef);'));
      expect(widgetSource, contains('_buildMissingSessionState'));
      expect(widgetSource, contains('_hasValidVideoDocRef'));
      expect(widgetSource, contains('_isSameDocumentReference'));
      expect(widgetSource, contains('_resetSessionScopedState();'));
      expect(widgetSource, contains('_tokenLoadingSessionId == sessionId'));
      expect(widgetSource, contains('sessionStream == null'));
      expect(widgetSource, contains('_isCurrentSession('));
      expect(widgetSource, contains('currentRef?.path == sessionPath'));
      expect(
          widgetSource, contains('_lastDeepgramTokenSessionId == sessionId'));
      expect(widgetSource,
          contains('final terminalSessionRef = widget.videoDocRef;'));
      expect(widgetSource, contains('terminalSessionId != null'));
      expect(widgetSource, contains('VideoCallPageWidget.debugEndCurrentCall'));
      expect(
        widgetSource,
        contains('VoIPService().endCurrentCall('),
      );
      expect(widgetSource, contains('sessionId: terminalSessionId'));
      expect(widgetSource, contains("sessionStatus == 'expired'"));
      expect(widgetSource, contains('sessionRefOverride: terminalSessionRef'));

      expect(
        modelSource,
        contains('void bindSession(DocumentReference? videoDocRef)'),
      );
      expect(modelSource, contains('sessionStream = null;'));
      expect(
        modelSource,
        contains('VideoSessionsRecord.getDocument(videoDocRef)'),
      );
    });

    test('VideoCallPage opens call summary after terminal call events', () {
      final widgetSource = _source(
          'lib/shared_pages/video_call_page/video_call_page_widget.dart');
      final summarySource =
          _source('lib/shared_pages/call_summary/call_summary_widget.dart');
      final navigateToSummarySource =
          _curlyBlockSource(widgetSource, 'Future<void> _navigateToSummary(');
      final connectedCallStartedAtSource = _curlyBlockSource(
        widgetSource,
        'DateTime? _connectedCallStartedAt(',
      );
      final connectedCallMetadataAtSource = _curlyBlockSource(
        widgetSource,
        'DateTime? _connectedCallMetadataAt(',
      );
      final summaryGateSource = _curlyBlockSource(
        widgetSource,
        'bool _shouldOpenSummaryForTerminalStatus(',
      );
      final terminalStatusSource = _curlyBlockSource(
        widgetSource,
        'if (_isTerminalSessionStatus(sessionStatus)) {',
      );
      final endCallCallbackSource = _curlyBlockSource(
        widgetSource,
        'endCallCallback: (endReason) async {',
      );
      final participantLeftCallbackSource = _curlyBlockSource(
        widgetSource,
        'participantLeftCallback: () async {',
      );
      final summaryNavigateHomeSource = _curlyBlockSource(
        summarySource,
        'void _navigateToHome() {',
      );
      final summaryReviewSectionSource = _curlyBlockSource(
        summarySource,
        'Widget _buildReviewSection(BuildContext context) {',
      );
      final summaryFinishSource = _curlyBlockSource(
        summarySource,
        'Future<void> finishSummary() async {',
      );
      final studentDashboardQuerySource = _sourceBetween(
        summaryNavigateHomeSource,
        "'zn': serializeParam(",
        '}.withoutNulls',
      );

      expect(navigateToSummarySource, contains('_didNavigateToSummary'));
      expect(navigateToSummarySource, contains('context.goNamed('));
      expect(navigateToSummarySource, contains('CallSummaryWidget.routeName'));
      expect(navigateToSummarySource, contains("'userRef': serializeParam("));
      expect(navigateToSummarySource, contains("'sessionID': serializeParam("));
      expect(navigateToSummarySource, contains("'lang': serializeParam("));
      expect(navigateToSummarySource, contains("'dur': serializeParam("));
      expect(navigateToSummarySource,
          contains('_connectedCallStartedAt(session)'));
      expect(connectedCallMetadataAtSource, contains('value is Timestamp'));
      expect(connectedCallMetadataAtSource,
          contains('DateTime.fromMillisecondsSinceEpoch'));
      expect(connectedCallMetadataAtSource,
          contains('DateTime.tryParse(trimmed)'));
      expect(connectedCallStartedAtSource,
          contains("sessionMetadata['callConnectedAt']"));
      expect(
        connectedCallStartedAtSource,
        contains("sessionMetadata['callConnectedAtTimestamp']"),
      );
      expect(
        connectedCallStartedAtSource,
        contains("sessionMetadata['dailyWebhookConnectedAt']"),
      );
      expect(summaryGateSource, contains("sessionStatus == 'ended'"));
      expect(summaryGateSource, contains("sessionStatus == 'cancelled'"));
      expect(summaryGateSource, contains("sessionStatus == 'expired'"));
      expect(summaryGateSource, contains('_hasConnectedCallEvidence(session)'));
      expect(terminalStatusSource,
          contains('_shouldOpenSummaryForTerminalStatus('));
      expect(terminalStatusSource, contains('_didClearTerminalCallUi'));
      expect(terminalStatusSource, contains('_navigateToSummary('));
      expect(
        terminalStatusSource,
        contains('VideoCallPageWidget.debugEndCurrentCall'),
      );
      expect(
        terminalStatusSource,
        contains('VoIPService().endCurrentCall('),
      );
      expect(terminalStatusSource, contains('sessionId: terminalSessionId'));
      expect(
        terminalStatusSource,
        contains('sessionRefOverride: terminalSessionRef'),
      );
      expect(terminalStatusSource, contains('if (shouldOpenSummary)'));
      expect(
          terminalStatusSource, contains('_buildMissingSessionState(context)'));
      expect(endCallCallbackSource,
          contains('await _openSummaryAfterCallCallback('));
      expect(endCallCallbackSource,
          contains('allowConnectedSnapshotFallback: false'));
      expect(
        participantLeftCallbackSource,
        contains('await _openSummaryAfterCallCallback('),
      );
      expect(
        participantLeftCallbackSource,
        contains('allowConnectedSnapshotFallback: true'),
      );
      expect(
          summarySource, contains("static String routeName = 'CallSummary'"));
      expect(summaryFinishSource, contains('submitSessionReview('));
      expect(summaryReviewSectionSource, contains('PairReviewContent('));
      expect(summaryNavigateHomeSource,
          contains('StudentsDashboardWidget.routeName'));
      expect(studentDashboardQuerySource, contains('false'));
      expect(studentDashboardQuerySource, contains('ParamType.bool'));
    });

    test('Daily call and chat controls have accessible labels', () {
      final dailyWidgetSource =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final controlsSource =
          _source('lib/custom_code/widgets/call_controls_bar.dart');

      expect(dailyWidgetSource, contains('CallControlsBar('));
      expect(controlsSource, contains("'Выключить камеру'"));
      expect(controlsSource, contains("'Включить камеру'"));
      expect(controlsSource, contains("'Камера включена. Выключить камеру'"));
      expect(controlsSource, contains("'Камера выключена. Включить камеру'"));
      expect(controlsSource, contains("'Выключить микрофон'"));
      expect(controlsSource, contains("'Включить микрофон'"));
      expect(
        controlsSource,
        contains("'Микрофон включен. Выключить микрофон'"),
      );
      expect(
        controlsSource,
        contains("'Микрофон выключен. Включить микрофон'"),
      );
      expect(controlsSource, contains('_chatControlTooltip()'));
      expect(controlsSource, contains('_chatControlSemanticLabel()'));
      expect(controlsSource, contains('toggled: semanticToggled'));
      expect(controlsSource, contains("'Завершить звонок'"));
      expect(dailyWidgetSource, contains("message: 'Закрыть чат'"));
      expect(dailyWidgetSource, contains("'Отправить сообщение'"));
      expect(
        dailyWidgetSource,
        contains("'Отправка сообщения недоступна'"),
      );
      expect(dailyWidgetSource, contains('ExcludeSemantics('));
      expect(dailyWidgetSource, contains('ChatComposer('));
    });

    test('chat thread uses public profile projection for partner header', () {
      final chatThreadSource =
          _source('lib/shared_pages/chat_thread/chat_thread_widget.dart');
      final backendSource = _source('lib/backend/backend.dart');
      final publicProfileRecordSource =
          _source('lib/backend/schema/user_public_profiles_record.dart');
      final publicProfileSyncSource =
          _source('firebase/custom_cloud_functions/public_user_profiles.js');
      final nativeSpeakerSource = _source(
          'lib/students_pages/native_speaker_page/native_speaker_page_widget.dart');
      final rulesSource = _source('firebase/firestore.rules');

      expect(chatThreadSource, contains('_watchPublicProfile'));
      expect(
        chatThreadSource,
        contains('UserPublicProfilesRecord.collection.doc(ref.id)'),
      );
      expect(
        chatThreadSource,
        contains('StreamBuilder<UserPublicProfilesRecord?>'),
      );
      expect(
        chatThreadSource,
        isNot(contains('UsersRecord.getDocumentOnce(ref)')),
      );
      expect(backendSource,
          contains("export 'schema/user_public_profiles_record.dart';"));
      expect(publicProfileRecordSource,
          contains("collection('userPublicProfiles')"));
      expect(publicProfileRecordSource, contains('maybeGetDocumentOnce'));
      expect(publicProfileRecordSource, contains('maybeGetDocument'));
      expect(publicProfileRecordSource, contains('LanguageStruct'));
      expect(publicProfileRecordSource, contains('CountryStruct'));
      expect(publicProfileSyncSource, contains('buildPublicUserProfile'));
      expect(publicProfileSyncSource, contains('aboutMe:'));
      expect(publicProfileSyncSource, contains('native_language_NS:'));
      expect(publicProfileSyncSource, isNot(contains('email:')));
      expect(publicProfileSyncSource, isNot(contains('phone_number:')));
      expect(publicProfileSyncSource, isNot(contains('balance_NS:')));
      expect(nativeSpeakerSource,
          contains('StreamBuilder<UserPublicProfilesRecord?>'));
      expect(
        nativeSpeakerSource,
        contains('UserPublicProfilesRecord.collection.doc(targetRef.id)'),
      );
      expect(nativeSpeakerSource,
          isNot(contains('UsersRecord.getDocument(widget.nsUserDocRef!)')));
      expect(nativeSpeakerSource, isNot(contains('availabilityToday')));
      expect(nativeSpeakerSource,
          isNot(contains("snapshotData['timezoneOffsetMinutes']")));
      expect(nativeSpeakerSource, isNot(contains('isInCall')));
      expect(rulesSource, contains('match /userPublicProfiles/{userId}'));
      expect(
        rulesSource,
        matches(RegExp(
          r'match /userPublicProfiles/\{userId\}\s*\{\s*allow read: if isSignedIn\(\);',
        )),
      );
      expect(rulesSource, contains('allow write: if false;'));
    });

    test('call details participant card reads public profile projection', () {
      final callDetailsSource =
          _source('lib/shared_pages/call_details/call_details_widget.dart');

      expect(
        callDetailsSource,
        contains('UserPublicProfilesRecord.collection'),
      );
      expect(
        callDetailsSource,
        contains('UserPublicProfilesRecord.fromSnapshot(participantSnapshot)'),
      );
      expect(callDetailsSource, contains('participant?.ratingAverage'));
      expect(callDetailsSource, contains('participant?.ratingCount'));
      expect(
        callDetailsSource,
        isNot(contains('UsersRecord.getDocument(participantRef!)')),
      );
    });

    test('post-call review identity reads use public profile projection', () {
      final callSummarySource =
          _source('lib/shared_pages/call_summary/call_summary_widget.dart');
      final callSummaryModelSource =
          _source('lib/shared_pages/call_summary/call_summary_model.dart');
      final reviewCardSource =
          _source('lib/components/review_card/review_card_widget.dart');

      expect(
        callSummarySource,
        contains('UserPublicProfilesRecord.maybeGetDocumentOnce'),
      );
      expect(
        callSummarySource,
        contains('UserPublicProfilesRecord.collection.doc(userRef.id)'),
      );
      expect(
        callSummarySource,
        contains('Future.value(null)'),
      );
      expect(
        callSummarySource,
        contains('oldWidget.userRef?.path != widget.userRef?.path'),
      );
      expect(
        callSummarySource,
        contains('FutureBuilder<UserPublicProfilesRecord?>'),
      );
      expect(
        callSummarySource,
        contains('snapshot.connectionState == ConnectionState.waiting'),
      );
      expect(callSummarySource, contains('_summaryUserDisplayName('));
      expect(callSummarySource, contains('_summaryUserPhotoUrl('));
      expect(
        callSummarySource,
        contains('final targetUserRef = widget.userRef;'),
      );
      expect(
        callSummarySource,
        isNot(contains('final stackUserPublicProfile = snapshot.data!')),
      );
      expect(
        callSummaryModelSource,
        contains('Future<UserPublicProfilesRecord?>? userFuture'),
      );
      expect(
        callSummarySource,
        isNot(contains('UsersRecord.getDocumentOnce(widget.userRef!)')),
      );
      expect(
        callSummarySource,
        isNot(contains('widget.userRef!.id')),
      );
      expect(
        callSummarySource,
        isNot(contains('widget.userRef!')),
      );

      expect(
        reviewCardSource,
        contains('Future<UserPublicProfilesRecord?>'),
      );
      expect(
        reviewCardSource,
        contains('UserPublicProfilesRecord.collection.doc(authorRef.id)'),
      );
      expect(
        reviewCardSource,
        contains('UserPublicProfilesRecord.maybeGetDocumentOnce'),
      );
      expect(reviewCardSource, contains('this.fullWidth = false'));
      expect(reviewCardSource, isNot(contains('this.width')));
      expect(reviewCardSource, isNot(contains('final double width')));
      expect(
        reviewCardSource,
        isNot(contains('UsersRecord.getDocumentOnce(authorRef)')),
      );
    });

    test('post-call summary keeps requested action surface', () {
      final source =
          _source('lib/shared_pages/call_summary/call_summary_widget.dart');

      expect(source, contains("'В друзья'"));
      expect(source, contains("'Убрать из друзей'"));
      expect(source, contains("'Будет удалён из списка друзей'"));
      expect(source, contains("ruText: 'Больше не соединять сегодня'"));
      expect(source, contains('Color(0xFFFFF1F1)'));
      expect(source, contains('Color(0xFFFF8A8A)'));
      expect(source, contains("ruText: 'Добавить в чёрный список'"));
      expect(source, contains("ruText: 'Оставить отзыв'"));
      expect(source, isNot(contains("ruText: 'Открыть чат'")));
      expect(source, isNot(contains('openChatThread(')));
      expect(source, isNot(contains('AI-обратная связь')));
    });

    test('call details delegates participant avatar visuals to component', () {
      final source =
          _source('lib/shared_pages/call_details/call_details_widget.dart');

      expect(source, contains("'/components/participant_avatar.dart'"));
      expect(source, contains('ParticipantAvatar('));
      expect(source, isNot(contains('class _ParticipantAvatar')));
      expect(source, isNot(contains('borderWidth:')));
    });

    test('favorite and blacklist tiles read public profile projection', () {
      final favSource = _source('lib/components/fav_widget.dart');
      final favoriteSource =
          _source('lib/students_pages/favorite/favorite_widget.dart');
      final blackListSource =
          _source('lib/shared_pages/black_list/black_list_widget.dart');

      expect(
        favSource,
        contains('Future<UserPublicProfilesRecord?>'),
      );
      expect(
        favSource,
        contains('UserPublicProfilesRecord.maybeGetDocumentOnce'),
      );
      expect(
        favSource,
        contains('UserPublicProfilesRecord.collection.doc(userRef.id)'),
      );
      expect(
        favSource,
        isNot(contains('UsersRecord.getDocumentOnce(widget.nsUser!)')),
      );

      expect(
        favoriteSource,
        contains('Future<UserPublicProfilesRecord?>'),
      );
      expect(
        favoriteSource,
        contains('UserPublicProfilesRecord.collection.doc(ref.id)'),
      );
      expect(
        favoriteSource,
        isNot(contains('UsersRecord.getDocumentOnce(ref)')),
      );

      expect(
        blackListSource,
        contains('Future<UserPublicProfilesRecord?>'),
      );
      expect(
        blackListSource,
        contains('UserPublicProfilesRecord.collection.doc(ref.id)'),
      );
      expect(
        blackListSource,
        contains('FieldValue.arrayRemove(['),
      );
      expect(
        blackListSource,
        contains('listItem,'),
      );
      expect(
        blackListSource,
        isNot(contains('UsersRecord.getDocumentOnce(ref)')),
      );
    });

    test('native speaker detail page reads public profile projection', () {
      final nativeSpeakerSource = _source(
          'lib/students_pages/native_speaker_page/native_speaker_page_widget.dart');
      final publicProfileRecordSource =
          _source('lib/backend/schema/user_public_profiles_record.dart');
      final publicProfileSyncSource =
          _source('firebase/custom_cloud_functions/public_user_profiles.js');

      expect(
        nativeSpeakerSource,
        contains('StreamBuilder<UserPublicProfilesRecord?>'),
      );
      expect(
        nativeSpeakerSource,
        contains('late Stream<UserPublicProfilesRecord?> _publicProfileStream'),
      );
      expect(nativeSpeakerSource, contains('void _bindNativeSpeakerRef('));
      expect(
        nativeSpeakerSource,
        contains('void didUpdateWidget(NativeSpeakerPageWidget oldWidget)'),
      );
      expect(
        nativeSpeakerSource,
        contains('UserPublicProfilesRecord.maybeGetDocument'),
      );
      expect(
        nativeSpeakerSource,
        contains('UserPublicProfilesRecord.collection.doc(targetRef.id)'),
      );
      expect(
        nativeSpeakerSource,
        contains("httpsCallable('getDirectCallStatus')"),
      );
      expect(
        nativeSpeakerSource,
        contains('Future<bool> _ensureDirectCallStatus({'),
      );
      expect(
        nativeSpeakerSource,
        contains('required DocumentReference targetReference'),
      );
      expect(
        nativeSpeakerSource,
        contains('canStartCall(_currentOwnerDocument(ownerUid))'),
      );
      final directStatusIndex =
          nativeSpeakerSource.indexOf('if (!await _ensureDirectCallStatus(');
      final directGuardIndex = nativeSpeakerSource.indexOf(
        'if (!_actionContextIsCurrent(',
        directStatusIndex,
      );
      final directMediaPermissionIndex = nativeSpeakerSource.indexOf(
        'widget.mediaPermissionRequester ??',
        directStatusIndex,
      );
      expect(directStatusIndex, greaterThanOrEqualTo(0));
      expect(directGuardIndex, greaterThan(directStatusIndex));
      expect(directMediaPermissionIndex, greaterThan(directStatusIndex));
      expect(directMediaPermissionIndex, greaterThan(directGuardIndex));
      expect(
        nativeSpeakerSource,
        isNot(contains('UsersRecord.getDocument(widget.nsUserDocRef!)')),
      );
      expect(nativeSpeakerSource, isNot(contains('availabilityToday')));
      expect(nativeSpeakerSource,
          isNot(contains("snapshotData['timezoneOffsetMinutes']")));
      expect(nativeSpeakerSource, isNot(contains('isInCall')));
      expect(publicProfileRecordSource, contains('LanguageStruct'));
      expect(publicProfileRecordSource, contains('CountryStruct'));
      expect(
        publicProfileSyncSource,
        isNot(contains('publicCallAvailability')),
      );
      expect(publicProfileSyncSource, isNot(contains('acceptsDirectCalls')));
      expect(
        publicProfileSyncSource,
        isNot(contains('callAvailabilityStatus')),
      );
    });

    test('user document rules scope private reads and live lifecycle writes',
        () {
      final rulesSource = _source('firebase/firestore.rules');
      final studentDashboardSource = _source(
          'lib/students_pages/students_dashboard/students_dashboard_widget.dart');
      final teacherDashboardSource =
          _source('lib/teachers_pages/dashboard_n_s/dashboard_n_s_widget.dart');
      final profileSource =
          _source('lib/shared_pages/profile/profile_widget.dart');

      expect(rulesSource, contains('function canReadUserDocument(userId)'));
      expect(
        rulesSource,
        contains('allow get, list: if canReadUserDocument(userId);'),
      );
      expect(rulesSource, contains('function privateUserLifecycleFields()'));
      expect(rulesSource, contains("'currentSessionId'"));
      expect(rulesSource, contains("'isAvailable'"));
      expect(rulesSource, contains("'isInCall'"));
      expect(rulesSource, contains("'availableAfter'"));
      expect(rulesSource, contains("'lastCallEndedAt'"));
      expect(rulesSource, contains('function ownUserRoleUpdateIsValid()'));
      expect(studentDashboardSource, isNot(contains('isInCall: false')));
      expect(teacherDashboardSource, isNot(contains('isInCall: false')));
      expect(profileSource, isNot(contains('isInCall: false')));
    });

    test('student dashboard gates calls on camera and microphone permissions',
        () {
      final permissionsSource =
          _source('lib/flutter_flow/permissions_util.dart');
      final studentDashboardSource = _source(
          'lib/students_pages/students_dashboard/students_dashboard_widget.dart');
      final waitingForTeacherSource = _source(
          'lib/students_pages/waiting_for_teacher_page/waiting_for_teacher_page_widget.dart');
      final voipServiceSource = _source('lib/services/voip_service.dart');
      final videoCallPageSource = _source(
          'lib/shared_pages/video_call_page/video_call_page_widget.dart');

      expect(
        permissionsSource,
        contains('Future<bool> ensureCameraAndMicrophonePermissions()'),
      );
      expect(
        permissionsSource,
        contains('await requestPermission(cameraPermission);'),
      );
      expect(
        permissionsSource,
        contains('await requestPermission(microphonePermission);'),
      );
      expect(
        permissionsSource,
        contains('return hasCameraPermission && hasMicrophonePermission;'),
      );
      expect(
        RegExp(r'await ensureCameraAndMicrophonePermissions\(\)')
            .allMatches(studentDashboardSource)
            .length,
        greaterThanOrEqualTo(2),
      );
      expect(
        studentDashboardSource,
        isNot(matches(RegExp(r'requestPermission\s*\(\s*cameraPermission'))),
      );
      expect(
        studentDashboardSource,
        isNot(
            matches(RegExp(r'requestPermission\s*\(\s*microphonePermission'))),
      );

      final waitingPermissionIndex = waitingForTeacherSource
          .indexOf('await ensureCameraAndMicrophonePermissions()');
      final createSessionIndex = waitingForTeacherSource
          .indexOf("httpsCallable('createVideoSession')");
      expect(waitingPermissionIndex, greaterThanOrEqualTo(0));
      expect(createSessionIndex, greaterThan(waitingPermissionIndex));

      final handleAcceptIndex =
          voipServiceSource.indexOf('Future<void> _handleCallAccept');
      final handleAcceptSource = _curlyBlockSource(
        voipServiceSource,
        'Future<void> _handleCallAccept',
      );
      final resolveAcceptedSource = _curlyBlockSource(
        voipServiceSource,
        'Future<void> _resolveAcceptedSession(',
      );
      final acceptPermissionIndex = handleAcceptSource.indexOf(
        'await _ensureAcceptMediaPermissions()',
      );
      final resolveScheduleIndex = handleAcceptSource.indexOf(
        'unawaited(_resolveAcceptedSession(',
        acceptPermissionIndex,
      );
      final acceptCallIndex = resolveAcceptedSource
          .indexOf('_callAcceptCallFunction(attempt.sessionId)');
      expect(handleAcceptIndex, greaterThanOrEqualTo(0));
      expect(acceptPermissionIndex, greaterThanOrEqualTo(0));
      expect(resolveScheduleIndex, greaterThan(acceptPermissionIndex));
      expect(acceptCallIndex, greaterThanOrEqualTo(0));
      final releaseAcceptClaimIndex = handleAcceptSource.indexOf(
        '_acceptLifecycle.releaseForRetry(acceptAttempt);',
        acceptPermissionIndex,
      );
      expect(releaseAcceptClaimIndex, greaterThan(acceptPermissionIndex));

      expect(videoCallPageSource, contains('late Future<bool>'));
      final videoRefGateIndex =
          videoCallPageSource.indexOf('if (!_hasValidVideoDocRef)');
      final videoPermissionRequestIndex = videoCallPageSource
          .indexOf('await ensureCameraAndMicrophonePermissions()');
      expect(videoRefGateIndex, greaterThanOrEqualTo(0));
      expect(videoPermissionRequestIndex, greaterThan(videoRefGateIndex));
      expect(videoCallPageSource, contains('FutureBuilder<bool>'));
      expect(videoCallPageSource, contains('_buildMediaPermissionState'));
      final mediaGateIndex = videoCallPageSource.indexOf('FutureBuilder<bool>');
      final dailyWidgetIndex =
          videoCallPageSource.indexOf('custom_widgets.MinimalDailyWidget');
      expect(mediaGateIndex, greaterThanOrEqualTo(0));
      expect(dailyWidgetIndex, greaterThan(mediaGateIndex));
      final gatedFallbackTokenFetchIndex =
          videoCallPageSource.indexOf('unawaited(_fetchSessionTokens());');
      expect(gatedFallbackTokenFetchIndex, greaterThan(mediaGateIndex));
      expect(dailyWidgetIndex, greaterThan(gatedFallbackTokenFetchIndex));
    });
  });
}
