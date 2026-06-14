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

    test('connected billing marker requires Daily verification backend', () {
      final markConnectedSource =
          _source('firebase/custom_cloud_functions/mark_session_connected.js');
      final dailyWebhookSource =
          _source('firebase/custom_cloud_functions/daily_webhook.js');
      final indexSource = _source('firebase/custom_cloud_functions/index.js');

      expect(markConnectedSource, contains('connectedParticipantSignals'));
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

      final acceptCallIndex = source.indexOf("httpsCallable('acceptCall')");
      final tutorNavigateIndex = source.indexOf(
        "sessionId: sessionId,\n              isTutor: true,\n              roomUrl: _lastRoomUrl",
      );
      expect(acceptCallIndex, greaterThanOrEqualTo(0));
      expect(tutorNavigateIndex, greaterThan(acceptCallIndex));
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
      expect(source,
          contains("status != 'searching' || currentTutorId != userId"));
      expect(
        source,
        contains('Firestore incoming call notification received'),
      );
      expect(source, contains('await showIncomingCall('));
      expect(source, contains('await notificationSub.cancel();'));
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
      expect(
          widgetSource,
          contains(
              'VoIPService().endCurrentCall(sessionId: terminalSessionId)'));
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
      expect(
        dailyWidgetSource,
        contains("'Введите сообщение для отправки'"),
      );
      expect(dailyWidgetSource, contains('ExcludeSemantics('));
      expect(dailyWidgetSource, contains('width: 48,'));
      expect(dailyWidgetSource, contains('height: 48,'));
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

      expect(source, contains("ruText: 'В друзья'"));
      expect(source, contains("ruText: 'Больше не соединять сегодня'"));
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
        contains('Future<bool> _ensureDirectCallStatus(String targetTutorId)'),
      );
      expect(
          nativeSpeakerSource, contains('canStartCall(currentUserDocument)'));
      final directStatusIndex = nativeSpeakerSource
          .indexOf('await _ensureDirectCallStatus(targetTutorId)');
      final directMediaPermissionIndex = nativeSpeakerSource.indexOf(
        'await ensureCameraAndMicrophonePermissions()',
        directStatusIndex,
      );
      expect(directStatusIndex, greaterThanOrEqualTo(0));
      expect(directMediaPermissionIndex, greaterThan(directStatusIndex));
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
        'await ensureCameraAndMicrophonePermissions()',
        handleAcceptIndex,
      );
      final studentPrefetchIndex = voipServiceSource.indexOf(
        'unawaited(_prefetchSessionTokens(sessionId));',
        acceptPermissionIndex,
      );
      final acceptCallIndex = voipServiceSource.indexOf(
        "httpsCallable('acceptCall')",
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
