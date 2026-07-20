import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
      expect(source, contains('_processAcceptClaimedAtBySession'));
      expect(source, contains('Duplicate accept event (process gate)'));
      expect(
        source,
        contains('_processAcceptClaimedAtBySession.remove(sessionId);'),
      );

      final handleAcceptIndex =
          source.indexOf('Future<void> _handleCallAccept');
      final claimIndex =
          source.indexOf('_recentAcceptBySession[sessionId] = acceptTime;');
      final processClaimIndex =
          source.indexOf('_tryClaimProcessAccept', handleAcceptIndex);
      final handledIdIndex = source.indexOf(
        '_handledCallKitAcceptIds.add(effectiveCallKitId);',
        handleAcceptIndex,
      );
      final acceptInProgressIndex = source.indexOf(
        '_acceptInProgress.add(sessionId);',
        handleAcceptIndex,
      );
      final staleCallKitGuardIndex =
          source.indexOf('Ignoring accept for stale callKitId');
      final duplicateTimeWindowIndex =
          source.indexOf('Duplicate accept event (time window)');
      final duplicateTimeReleaseIndex = source.indexOf(
        '_releaseProcessAcceptClaim(sessionId);',
        duplicateTimeWindowIndex,
      );
      final duplicateCallKitIndex =
          source.indexOf('Duplicate accept event (callKitId)');
      final duplicateCallKitReleaseIndex = source.indexOf(
        '_releaseProcessAcceptClaim(sessionId);',
        duplicateCallKitIndex,
      );
      final alreadyAcceptedIndex = source.indexOf('Call already accepted');
      final alreadyAcceptedReleaseIndex = source.indexOf(
        '_releaseProcessAcceptClaim(sessionId);',
        alreadyAcceptedIndex,
      );
      final acceptInProgressGuardIndex =
          source.indexOf('Accept already in progress');
      final acceptInProgressReleaseIndex = source.indexOf(
        '_releaseProcessAcceptClaim(sessionId);',
        acceptInProgressGuardIndex,
      );

      expect(claimIndex, greaterThanOrEqualTo(0));
      expect(processClaimIndex, greaterThanOrEqualTo(0));
      expect(staleCallKitGuardIndex, greaterThanOrEqualTo(0));
      expect(duplicateTimeReleaseIndex, greaterThan(duplicateTimeWindowIndex));
      expect(
        duplicateCallKitReleaseIndex,
        greaterThan(duplicateCallKitIndex),
      );
      expect(alreadyAcceptedReleaseIndex, greaterThan(alreadyAcceptedIndex));
      expect(
        acceptInProgressReleaseIndex,
        greaterThan(acceptInProgressGuardIndex),
      );
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
      final loggedOutBranchSource = _sourceBetween(
        mainSource,
        'if (!user.loggedIn) {',
        '} else if (!wasLoggedIn) {',
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
        '// 4. Слушаем события CallKit/ConnectionService',
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
        contains('duration: _incomingCallTimeoutMilliseconds'),
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
      expect(acceptSource, contains('_callAcceptCallFunction(sessionId)'));
      expect(acceptSource, contains('isTutor: true'));
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
        contains('data.duration = incomingCallTimeoutMilliseconds'),
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

    test('session limit warning stays inside timer badge', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');

      expect(
        RegExp(r'_CallCheckpointNotice\(\s*minutes:\s*-1').hasMatch(source),
        isFalse,
      );

      final warningStart =
          source.indexOf('void _maybeShowSessionLimitWarning()');
      final autoEndStart =
          source.indexOf('void _maybeAutoEndAtSessionLimit()', warningStart);
      expect(warningStart, greaterThanOrEqualTo(0));
      expect(autoEndStart, greaterThan(warningStart));

      final warningSource = source.substring(warningStart, autoEndStart);
      expect(
        warningSource,
        contains('_sessionLimitWarningShownFor = expiresAt;'),
      );
      expect(warningSource, isNot(contains('_showCallCheckpointNotice')));

      final badgeStart = source.indexOf('Widget _buildCallDurationBadge()');
      final noticeOverlayStart = source.indexOf(
        'Widget _buildCallCheckpointNoticeOverlay',
        badgeStart,
      );
      expect(badgeStart, greaterThanOrEqualTo(0));
      expect(noticeOverlayStart, greaterThan(badgeStart));

      final badgeSource = source.substring(badgeStart, noticeOverlayStart);
      expect(badgeSource, contains("'Осталась 1 минута до лимита'"));
      expect(badgeSource, contains(": 'до лимита'"));
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

    test('call chat composer uses the shared iMessage-style control', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final composerSource =
          _curlyBlockSource(source, 'Widget _buildChatComposer()');

      expect(composerSource, contains('ChatComposer('));
      expect(composerSource, contains('isSending: _isSendingChatMessage'));
      expect(composerSource, contains('enabled: composerEnabled'));
      expect(composerSource, isNot(contains('Icons.send_rounded')));
    });

    test('Deepgram caption failures are visible and persisted safely', () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');

      expect(source, contains('String? captionIssueCode'));
      expect(source, contains('String? captionIssueMessage'));
      expect(source, contains('clearCaptionIssue'));
      expect(source, contains('_reportCaptionRuntimeIssue('));
      expect(source, contains('_clearCaptionRuntimeIssue()'));
      expect(source, contains('_captionDiagnosticLogDocumentId('));
      expect(source, contains('reportedSpecificStartIssue'));
      expect(source, contains('sessionIdAtStart'));
      expect(source, contains('_deepgramStreamGeneration'));
      expect(source, contains('_isCurrentDeepgramStreamGeneration('));
      expect(source, contains('_handleDeepgramAudioSinkFailure('));
      expect(source,
          contains('_syncDeepgramWithMicrophoneState(forceRefresh: true)'));
      expect(source, contains('_closeStaleDeepgramRecorder(recorder)'));
      expect(source, contains('_participantLogSpeakerId('));
      expect(source, contains('participant?.info.userId?.trim()'));
      expect(source, contains('unawaited(_stopDeepgramStreaming());'));
      expect(source, contains("source: 'caption_runtime_diagnostic'"));
      expect(source, contains('diagnosticCode: normalizedCode'));
      expect(source, contains("speakerRole: 'system'"));
      expect(source, contains("'Субтитры временно недоступны'"));
      expect(source, contains("'caption_token_unavailable'"));
      expect(source, contains("'deepgram_start_failed'"));
      expect(source, contains("'deepgram_websocket_error'"));
      expect(source, contains("'deepgram_error_frame'"));
      expect(source, contains('DeepgramCredentialException'));
      expect(source, contains('_isDeepgramErrorFrame('));
      expect(source, contains('_flushPendingCaptionLogs(force: true)'));

      final credentialFailureIndex =
          source.indexOf("'caption_token_unavailable'");
      final credentialReturnIndex =
          source.indexOf('return;', credentialFailureIndex);
      expect(credentialFailureIndex, greaterThanOrEqualTo(0));
      expect(credentialReturnIndex, greaterThan(credentialFailureIndex));

      final videoPageSource = _source(
          'lib/shared_pages/video_call_page/video_call_page_widget.dart');
      expect(videoPageSource, contains('DeepgramCredentialException'));
      expect(videoPageSource, contains("'deepgram_token_grant_forbidden'"));
      expect(videoPageSource, contains('throwOnFailure: true'));
      expect(videoPageSource,
          contains('!force &&\n        _deepgramTokenLoading'));

      final rulesSource = _source('firebase/firestore.rules');
      expect(rulesSource, contains('canWriteCaptionRuntimeDiagnostic'));
      expect(rulesSource, contains('isSafeCaptionRuntimeDiagnosticText'));
      expect(rulesSource, contains('isSafeCaptionRuntimeDiagnosticCode'));
      expect(rulesSource, contains('isSafeCaptionRuntimeDiagnosticPair'));
      expect(rulesSource, contains("'deepgram_token_grant_forbidden'"));
      expect(rulesSource, contains('isReservedCaptionDiagnosticLogId'));
      expect(rulesSource, contains('usesReservedCaptionDiagnosticSpeaker'));
      expect(rulesSource, contains('canWritePeerLegacyCaptionLogData'));
      expect(rulesSource, contains('isOtherSessionParticipantId'));
      expect(rulesSource, contains('isCaptionLogIdForSpeaker'));
      expect(rulesSource,
          contains("logId == data.speakerId + '_' + string(data.utteranceId)"));
      expect(rulesSource,
          contains('data.utteranceId == resource.data.utteranceId'));
      expect(rulesSource, contains("'caption_runtime_diagnostic'"));
      expect(rulesSource, contains("'local_deepgram_final'"));
      expect(rulesSource, contains("'peer_legacy_final'"));
      expect(rulesSource, contains("data.speakerId == 'system'"));
      expect(rulesSource,
          contains('data.speakerName == resource.data.speakerName'));
      expect(
          rulesSource, contains("logId == 'system_' + request.auth.uid + '_'"));
      expect(
          rulesSource,
          contains(
              "data.source in ['local_deepgram_final', 'peer_legacy_final']"));
    });

    test('Deepgram stop persists a short unfinished caption before clearing',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final messageGuardSource = _curlyBlockSource(
        source,
        'bool _canHandleDeepgramMessage(',
      );
      final finalizeSource = _curlyBlockSource(
        source,
        'Future<void> _finalizeCurrentCaptionAndFlushLogs() async',
      );
      final stopSource = _curlyBlockSource(
        source,
        'Future<void> _stopDeepgramStreaming() async',
      );

      expect(messageGuardSource, contains('_deepgramFinalizing'));
      expect(
        finalizeSource,
        contains('_emitFinalUpdateForCurrentLocalCaption();'),
      );
      expect(
        finalizeSource,
        contains('_flushPendingCaptionLogs(force: true)'),
      );

      final finalizeIndex =
          stopSource.lastIndexOf('_finalizeCurrentCaptionAndFlushLogs()');
      final clearIndex = stopSource.lastIndexOf('_clearLocalCaptions()');
      expect(finalizeIndex, greaterThanOrEqualTo(0));
      expect(clearIndex, greaterThan(finalizeIndex));
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

      expect(
        source,
        isNot(contains('Navigated to VideoCallPage (tutor, instant)')),
      );
      expect(
        source,
        contains('Navigated to VideoCallPage (tutor, after acceptCall)'),
      );

      final acceptCallIndex =
          source.indexOf('_callAcceptCallFunction(sessionId)');
      final tutorNavigateIndex = source.indexOf(
        "sessionId: sessionId,\n              isTutor: true,\n              roomUrl: _lastRoomUrl",
      );
      expect(acceptCallIndex, greaterThanOrEqualTo(0));
      expect(tutorNavigateIndex, greaterThan(acceptCallIndex));
    });

    test('CallKit accept opens existing foreground sessions without acceptCall',
        () {
      final source = _source('lib/services/voip_service.dart');

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
      final payloadCredentialsIndex = source.indexOf(
        'final payloadCredentials = voipRoomCredentialsFromAcceptedPayload(data);',
      );
      final acceptActionIndex = source.indexOf(
        'final acceptAction = voipAcceptActionFromPayload(data);',
        payloadCredentialsIndex,
      );
      final acceptedRoleIndex = source.indexOf(
        '_lastAcceptedIsTutor = payloadCredentials == null;',
        payloadCredentialsIndex,
      );
      final payloadBranchIndex = source.indexOf(
        'acceptAction == VoipAcceptPayloadAction.openSession',
        acceptedRoleIndex,
      );
      final studentNavigationIndex = source.indexOf(
        'Student navigation triggered (no acceptCall)',
        payloadBranchIndex,
      );
      final acceptCallIndex = source.indexOf(
        '_callAcceptCallFunction(sessionId)',
        studentNavigationIndex,
      );

      expect(credentialsHelperIndex, greaterThanOrEqualTo(0));
      expect(roomUrlGuardIndex, greaterThan(credentialsHelperIndex));
      expect(nullGuardIndex, greaterThan(roomUrlGuardIndex));
      expect(payloadCredentialsIndex, greaterThan(nullGuardIndex));
      expect(acceptActionIndex, greaterThan(payloadCredentialsIndex));
      expect(acceptedRoleIndex, greaterThan(payloadCredentialsIndex));
      expect(payloadBranchIndex, greaterThan(acceptedRoleIndex));
      expect(studentNavigationIndex, greaterThan(payloadBranchIndex));
      expect(acceptCallIndex, greaterThan(studentNavigationIndex));
      expect(source, isNot(contains('hasPayloadRoomUrl')));
      expect(source, isNot(contains('hasPayloadMeetingToken')));
    });

    test('tutor accept recovery navigates after backend commit is visible', () {
      final source = _source('lib/services/voip_service.dart');

      final catchIndex =
          source.indexOf("debugPrint('❌ VoIPService: acceptCall failed: \$e')");
      final recoveryIndex = source.indexOf(
        'if (await _tryRecoverActiveSession(sessionId))',
        catchIndex,
      );
      final recoveryNavigateIndex = source.indexOf(
        '_navigateToVideoCallForAccept(',
        recoveryIndex,
      );
      final recoveryLogIndex = source.indexOf(
        'Recovered accepted call after acceptCall error',
        recoveryNavigateIndex,
      );
      final clearStateIndex = source.indexOf(
        '_clearSessionState(sessionId);',
        recoveryIndex,
      );
      final resolutionGuardIndex = source.indexOf(
        'if (!didResolveAcceptedSession)',
        recoveryIndex,
      );
      final unresolvedClearStateIndex = source.indexOf(
        '_clearSessionState(sessionId);',
        resolutionGuardIndex,
      );
      final navigationTriggeredIndex = source.indexOf(
        '_markNavigationTriggeredForAccept(',
        resolutionGuardIndex,
      );

      expect(catchIndex, greaterThanOrEqualTo(0));
      expect(recoveryIndex, greaterThan(catchIndex));
      expect(recoveryNavigateIndex, greaterThan(recoveryIndex));
      expect(recoveryLogIndex, greaterThan(recoveryNavigateIndex));
      expect(clearStateIndex, greaterThan(recoveryNavigateIndex));
      expect(resolutionGuardIndex, greaterThan(clearStateIndex));
      expect(unresolvedClearStateIndex, greaterThan(resolutionGuardIndex));
      expect(navigationTriggeredIndex, greaterThan(unresolvedClearStateIndex));
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

      expect(mainSource,
          contains('VoIPService().recoverBackgroundAcceptedCalls()'));
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

      expect(dailyWidgetSource, contains("'Выключить камеру'"));
      expect(dailyWidgetSource, contains("'Включить камеру'"));
      expect(
          dailyWidgetSource, contains("'Камера включена. Выключить камеру'"));
      expect(
          dailyWidgetSource, contains("'Камера выключена. Включить камеру'"));
      expect(dailyWidgetSource, contains("'Выключить микрофон'"));
      expect(dailyWidgetSource, contains("'Включить микрофон'"));
      expect(
        dailyWidgetSource,
        contains("'Микрофон включен. Выключить микрофон'"),
      );
      expect(
        dailyWidgetSource,
        contains("'Микрофон выключен. Включить микрофон'"),
      );
      expect(dailyWidgetSource, contains('_chatControlTooltip()'));
      expect(dailyWidgetSource, contains('_chatControlSemanticLabel()'));
      expect(dailyWidgetSource, contains('toggled: semanticToggled'));
      expect(dailyWidgetSource, contains("'Завершить звонок'"));
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
      final acceptPermissionIndex = voipServiceSource.indexOf(
        'await _ensureAcceptMediaPermissions()',
        handleAcceptIndex,
      );
      final studentPrefetchIndex = voipServiceSource.indexOf(
        'unawaited(_prefetchSessionTokensForAccept(sessionId));',
        acceptPermissionIndex,
      );
      final acceptCallIndex = voipServiceSource.indexOf(
        '_callAcceptCallFunction(sessionId)',
        acceptPermissionIndex,
      );
      expect(handleAcceptIndex, greaterThanOrEqualTo(0));
      expect(acceptPermissionIndex, greaterThan(handleAcceptIndex));
      expect(studentPrefetchIndex, greaterThan(acceptPermissionIndex));
      expect(acceptCallIndex, greaterThan(acceptPermissionIndex));
      expect(
        voipServiceSource,
        contains('void _releaseProcessAcceptClaim(String sessionId)'),
      );
      final releaseAcceptClaimIndex = voipServiceSource.indexOf(
        '_releaseProcessAcceptClaim(sessionId);',
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
