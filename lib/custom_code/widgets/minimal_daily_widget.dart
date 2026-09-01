// ignore_for_file: unnecessary_import, unused_import

// Automatic FlutterFlow imports
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter/foundation.dart';
import 'package:daily_flutter/daily_flutter.dart';
import 'dart:async';
import 'dart:convert' as dart_convert;
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '/services/voip_service.dart';
import '/components/chat_composer.dart';
import '/components/interactive_caption_text.dart';
import '/shared_pages/chat_message_bubble_style.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'deepgram_credential_exception.dart';
import 'daily_join_credentials.dart' as join_credentials;
import 'daily_app_message_decoder.dart';
import 'daily_lifecycle_transition_queue.dart';
import 'daily_session_controller.dart';
import 'daily_runtime_error_policy.dart';
import 'daily_call_error_policy.dart';
import 'caption_message_policy.dart' as caption_policy;
import 'local_caption_assembler.dart';
import 'caption_log_queue.dart';
import 'call_timer_controller.dart';
import 'call_duration_badge.dart';
import 'call_controls_bar.dart';
import 'call_chat_controller.dart';
import 'call_participant_identity.dart' as participant_identity;
import 'deepgram_message_parser.dart' as deepgram_parser;
import 'deepgram_transport_adapters.dart';
import 'outgoing_caption_buffer.dart';
import 'session_limit_ui.dart' as session_limit_ui;

// VideoQuality enum simplified - only auto mode needed
// Daily Adaptive Bitrate handles all quality adjustments automatically

// NetworkQuality enum removed - Daily monitors network automatically

/// Connection state management
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed
}

/// Immutable state container for better state management
@immutable
class _CallState {
  final ConnectionState connectionState;
  final bool cameraEnabled;
  final bool microphoneEnabled;
  // Quality tracking removed - Daily handles this internally
  final String? error;
  final bool hasTerminalError;
  final int retryCount;
  final Map<ParticipantId, VideoViewController> remoteControllers;
  final _ActiveCaption? localCaption;
  final Map<ParticipantId, _ActiveCaption> remoteCaptions;
  final bool isStreamingToDeepgram;
  final String? captionIssueCode;
  final String? captionIssueMessage;
  final bool isChatOpen;
  final int unreadChatCount;
  final List<_ChatMessage> chatMessages;

  const _CallState({
    this.connectionState = ConnectionState.disconnected,
    this.cameraEnabled = true,
    this.microphoneEnabled = true,
    this.error,
    this.hasTerminalError = false,
    this.retryCount = 0,
    this.remoteControllers = const {},
    this.localCaption,
    this.remoteCaptions = const {},
    this.isStreamingToDeepgram = false,
    this.captionIssueCode,
    this.captionIssueMessage,
    this.isChatOpen = false,
    this.unreadChatCount = 0,
    this.chatMessages = const <_ChatMessage>[],
  });

  _CallState copyWith({
    ConnectionState? connectionState,
    bool? cameraEnabled,
    bool? microphoneEnabled,
    String? error,
    bool clearError = false,
    bool? hasTerminalError,
    int? retryCount,
    Map<ParticipantId, VideoViewController>? remoteControllers,
    _ActiveCaption? localCaption,
    bool clearLocalCaption = false,
    Map<ParticipantId, _ActiveCaption>? remoteCaptions,
    bool? isStreamingToDeepgram,
    String? captionIssueCode,
    String? captionIssueMessage,
    bool clearCaptionIssue = false,
    bool? isChatOpen,
    int? unreadChatCount,
    List<_ChatMessage>? chatMessages,
  }) {
    return _CallState(
      connectionState: connectionState ?? this.connectionState,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      microphoneEnabled: microphoneEnabled ?? this.microphoneEnabled,
      error: clearError ? null : (error ?? this.error),
      hasTerminalError: hasTerminalError ?? this.hasTerminalError,
      retryCount: retryCount ?? this.retryCount,
      remoteControllers: remoteControllers ?? this.remoteControllers,
      localCaption:
          clearLocalCaption ? null : (localCaption ?? this.localCaption),
      remoteCaptions: remoteCaptions ?? this.remoteCaptions,
      isStreamingToDeepgram:
          isStreamingToDeepgram ?? this.isStreamingToDeepgram,
      captionIssueCode: clearCaptionIssue
          ? null
          : (captionIssueCode ?? this.captionIssueCode),
      captionIssueMessage: clearCaptionIssue
          ? null
          : (captionIssueMessage ?? this.captionIssueMessage),
      isChatOpen: isChatOpen ?? this.isChatOpen,
      unreadChatCount: unreadChatCount ?? this.unreadChatCount,
      chatMessages: chatMessages ?? this.chatMessages,
    );
  }
}

@immutable
class _CaptionOverlayState {
  const _CaptionOverlayState({
    this.localCaption,
    this.remoteCaptions = const {},
    this.issueMessage,
  });

  factory _CaptionOverlayState.fromCallState(_CallState state) {
    return _CaptionOverlayState(
      localCaption: state.localCaption,
      remoteCaptions: state.remoteCaptions,
      issueMessage: state.captionIssueMessage,
    );
  }

  final _ActiveCaption? localCaption;
  final Map<ParticipantId, _ActiveCaption> remoteCaptions;
  final String? issueMessage;

  bool get hasContent =>
      issueMessage != null || localCaption != null || remoteCaptions.isNotEmpty;
}

enum _CaptionPhase {
  interim,
  finalCaption;

  String get wireValue => this == _CaptionPhase.interim ? 'interim' : 'final';

  double get opacity => this == _CaptionPhase.interim ? 0.78 : 1.0;
}

@immutable
class _ActiveCaption {
  const _ActiveCaption({
    required this.utteranceId,
    required this.revision,
    required this.speakerId,
    required this.text,
    required this.phase,
    required this.startedAt,
    required this.lastUpdateAt,
    this.expiresAt,
    this.isFadingOut = false,
  });

  final int utteranceId;
  final int revision;
  final String speakerId;
  final String text;
  final _CaptionPhase phase;
  final DateTime startedAt;
  final DateTime lastUpdateAt;
  final DateTime? expiresAt;
  final bool isFadingOut;

  _ActiveCaption copyWith({
    int? utteranceId,
    int? revision,
    String? speakerId,
    String? text,
    _CaptionPhase? phase,
    DateTime? startedAt,
    DateTime? lastUpdateAt,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    bool? isFadingOut,
  }) {
    return _ActiveCaption(
      utteranceId: utteranceId ?? this.utteranceId,
      revision: revision ?? this.revision,
      speakerId: speakerId ?? this.speakerId,
      text: text ?? this.text,
      phase: phase ?? this.phase,
      startedAt: startedAt ?? this.startedAt,
      lastUpdateAt: lastUpdateAt ?? this.lastUpdateAt,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      isFadingOut: isFadingOut ?? this.isFadingOut,
    );
  }
}

@immutable
class _CaptionUpdate {
  const _CaptionUpdate({
    required this.utteranceId,
    required this.revision,
    required this.text,
    required this.phase,
    required this.startedAt,
    required this.lastUpdateAt,
  });

  final int utteranceId;
  final int revision;
  final String text;
  final _CaptionPhase phase;
  final DateTime startedAt;
  final DateTime lastUpdateAt;
}

@immutable
class _OutgoingCaptionMessage {
  const _OutgoingCaptionMessage({
    required this.utteranceId,
    required this.revision,
    required this.text,
    required this.phase,
  });

  final int utteranceId;
  final int revision;
  final String text;
  final _CaptionPhase phase;

  String get signature =>
      '$utteranceId|$revision|${phase.wireValue}|${text.trim()}';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'caption',
        'utteranceId': utteranceId,
        'revision': revision,
        'phase': phase.wireValue,
        'text': text,
      };
}

@immutable
class _CaptionLogEntry {
  const _CaptionLogEntry({
    required this.logId,
    required this.speakerId,
    required this.speakerName,
    required this.speakerRole,
    required this.utteranceId,
    required this.text,
    required this.language,
    required this.source,
    required this.capturedAtClient,
    this.confidence,
    this.diagnosticCode,
  });

  final String logId;
  final String speakerId;
  final String speakerName;
  final String speakerRole;
  final int utteranceId;
  final String text;
  final String language;
  final String source;
  final DateTime capturedAtClient;
  final double? confidence;
  final String? diagnosticCode;

  Map<String, dynamic> toFirestoreData({
    required String writerId,
  }) {
    return mapToFirestore(
      <String, dynamic>{
        'speakerId': speakerId,
        'speakerName': speakerName,
        'speakerRole': speakerRole,
        'utteranceId': utteranceId,
        'text': text,
        'language': language,
        'source': source,
        'capturedAtClient': capturedAtClient,
        'createdAtServer': FieldValue.serverTimestamp(),
        'writerId': writerId,
        'confidence': confidence,
        'diagnosticCode': diagnosticCode,
      }.withoutNulls,
    );
  }
}

@immutable
class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.text,
    required this.senderName,
    required this.senderId,
    required this.sentAt,
    required this.isLocal,
  });

  final String id;
  final String text;
  final String senderName;
  final String senderId;
  final DateTime sentAt;
  final bool isLocal;
}

@immutable
class _CallCheckpointNotice {
  const _CallCheckpointNotice({
    required this.minutes,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  final int minutes;
  final String title;
  final String subtitle;
  final Color accentColor;
}

/// Production-ready video calling widget with enhanced quality and resilience
class MinimalDailyWidget extends StatefulWidget {
  const MinimalDailyWidget({
    super.key,
    this.width,
    this.height,
    this.sessionId,
    required this.roomUrl,
    this.meetingToken,
    this.tokenRefreshCallback,
    this.joinCredentialsRefreshCallback,
    this.sessionStatus,
    this.sessionConnectedAt,
    this.sessionExpiresAt,
    this.sessionPolicy,
    this.provisionalSessionLimitCountdown = false,
    this.isStudent,
    this.deepgramCredential,
    @Deprecated(
      'Use deepgramCredential for both temporary tokens and API keys.',
    )
    this.deepgramApiKey,
    this.deepgramTokenRefreshCallback,
    this.enableDeepgram = true,
    required this.deepgramLanguage,
    this.actionCallback,
    this.translationCallback,
    this.endCallCallback,
    this.username,
    this.participantLeftCallback,
  });

  final double? width;
  final double? height;
  final String? sessionId;
  final String roomUrl;
  final String? meetingToken;
  final Future<String?> Function()? tokenRefreshCallback;
  final Future<Map<String, String?>?> Function()?
      joinCredentialsRefreshCallback;
  final String? sessionStatus;
  final DateTime? sessionConnectedAt;
  final DateTime? sessionExpiresAt;
  final Map<String, dynamic>? sessionPolicy;
  final bool provisionalSessionLimitCountdown;
  final bool? isStudent;
  final String? deepgramCredential;
  @Deprecated('Use deepgramCredential for both temporary tokens and API keys.')
  final String? deepgramApiKey;
  final Future<String?> Function()? deepgramTokenRefreshCallback;
  final bool enableDeepgram;
  final String deepgramLanguage;
  final Future Function(String word, String sentence, String contextText)?
      actionCallback;
  final Future<void> Function()? translationCallback;
  final Future<void> Function(String? endReason)? endCallCallback;
  final String? username;
  final Future Function()? participantLeftCallback;

  @override
  State<MinimalDailyWidget> createState() => _MinimalDailyWidgetState();
}

class _MinimalDailyWidgetState extends State<MinimalDailyWidget>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static final _processDailyLease = DailySessionLease();
  late final _dailySession = DailySessionController<CallClient>(
    lease: _processDailyLease,
    create: CallClient.create,
    events: (client) => client.events,
    onEvent: _handleCallEvent,
    onEventError: _handleEventError,
    prepare: (_) {
      _localVideoController = VideoViewController();
    },
    join: _joinRoomWithEnhancedSettings,
    configure: [
      _configurePublishing,
      _enableLocalInputs,
      (client) => _ensureActiveRemoteSubscriptionProfile(client),
      _configureUsername,
    ],
    onClosing: _onDailyClosing,
    disableInputs: _disableLocalInputsForCleanup,
    stopCaptions: (_) async {
      await _stopDeepgramStreaming();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await _flushPendingCaptionLogs(force: true);
    },
    leave: (client) async {
      await client.leave();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    },
    detachVideo: (_) => _detachCallVideo(),
    dispose: (client) => client.dispose(),
    onError: (code) {
      if (kDebugMode) print('Daily lifecycle: $code');
    },
  );
  late final _deepgramTransport = createDeepgramTransportController(
    shouldRun: _shouldRunDeepgram,
    sessionId: () => widget.sessionId,
    language: () => widget.deepgramLanguage,
    resolveCredential: ({bool forceRefresh = false}) =>
        _resolveDeepgramCredential(forceRefresh: forceRefresh),
    onMessage: _handleDeepgramMessage,
    onIssue: ({required code, required message}) =>
        _reportCaptionRuntimeIssue(code: code, message: message),
    onCredentialUnavailable: _reportGenericCredentialUnavailable,
    onStreamingChanged: (streaming) {
      if (mounted && !_disposed) {
        _updateState(_state.copyWith(isStreamingToDeepgram: streaming));
      }
    },
    onStarted: _clearCaptionRuntimeIssue,
    finalizeCaptionAndFlush: _finalizeCurrentCaptionAndFlushLogs,
    clearCaption: _clearLocalCaptions,
    onDiagnostic: (code) {
      if (kDebugMode) print('Deepgram transport: $code');
    },
  );
  CallClient? get _callClient => _dailySession.client;
  VideoViewController? _localVideoController;
  Future<void>? _cleanupFuture;
  bool _preserveCleanupMeetingToken = true;
  bool _preserveCleanupTokenAttempts = true;
  bool _preserveCleanupChat = true;

  // State management - immutable
  _CallState _state = const _CallState();
  final ValueNotifier<_CaptionOverlayState> _captionOverlayNotifier =
      ValueNotifier<_CaptionOverlayState>(const _CaptionOverlayState());

  // Resource tracking for proper cleanup
  final Set<Timer> _activeTimers = {};

  // Remote track readiness tracking
  final Map<ParticipantId, DateTime> _remoteJoinTimes = {};
  final Map<ParticipantId, bool> _remoteTrackReady = {};
  final Map<ParticipantId, int> _remoteCaptionClearGenerations = {};
  final Map<ParticipantId, int> _remoteLegacyCaptionCounters = {};
  final Set<ParticipantId> _prioritySubscribedParticipants = {};
  bool _activeRemoteProfileConfigured = false;

  bool _disposed = false;
  bool _appInForeground = true;
  bool _resumeCameraEnabled = true;
  bool _resumeMicrophoneEnabled = true;
  bool _isInitializing = false;
  bool _systemCallMarkedConnected = false;
  bool _roomJoinMarked = false;
  String? _dynamicMeetingToken;
  String? _dynamicRoomUrl;
  bool _tokenRefreshInProgress = false;
  int _tokenRefreshAttempts = 0;
  static const int _maxTokenRefreshAttempts = 2;
  String? _deepgramCredential;
  int _deepgramCredentialGeneration = 0;
  Timer? _remoteLeftTimer;
  bool _remoteLeftNotified = false;
  bool _userRequestedEnd = false;
  bool _sessionExtensionRequestInFlight = false;

  // Call duration timer
  final ValueNotifier<int> _callDurationNotifier = ValueNotifier<int>(0);
  Timer? _callCheckpointNoticeTimer;
  final ValueNotifier<_CallCheckpointNotice?> _callCheckpointNoticeNotifier =
      ValueNotifier<_CallCheckpointNotice?>(null);
  late final _callTimer = CallTimerController(
    readSession: () => CallTimerSession(
      connectedAt: widget.sessionConnectedAt,
      expiresAt: widget.sessionExpiresAt,
      policy: widget.sessionPolicy,
      status: widget.sessionStatus,
      provisionalCountdown: widget.provisionalSessionLimitCountdown,
      isStudent: widget.isStudent == true,
      userRequestedEnd: _userRequestedEnd,
    ),
    onUpdate: _handleCallTimerUpdate,
  );
  final Map<ParticipantId, String> _remoteParticipantUiSignatures = {};
  int _localCaptionClearGeneration = 0;
  final _localCaptionAssembler = LocalCaptionAssembler();
  final TextEditingController _chatTextController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  final ScrollController _chatScrollController = ScrollController();
  late final CallChatController _callChatController = CallChatController(
    sessionId: () => widget.sessionId,
    canSend: () =>
        _state.connectionState == ConnectionState.connected &&
        !_dailySession.isClosing &&
        _hasRemoteParticipantPresent(),
    localIdentity: () => (
      id: _localParticipantId(),
      name: _localParticipantName(),
    ),
    sendText: _sendCallChatText,
    persistBatch: _persistCallChatBatch,
    endSession: _endCallChatSession,
    onChanged: _syncCallChatState,
    onDraftAccepted: _chatTextController.clear,
    onMessageAppended: (_) => _scrollChatToBottom(animated: _state.isChatOpen),
    onError: (code) {
      if (kDebugMode) print('Call chat: $code');
    },
  );
  Timer? _localCaptionUiThrottleTimer;
  Timer? _remoteCaptionSendThrottleTimer;
  Timer? _localUtteranceEndTimer;
  Timer? _captionLogFlushTimer;
  _CaptionUpdate? _pendingLocalCaptionUpdate;
  final OutgoingCaptionBuffer<_OutgoingCaptionMessage> _outgoingCaptionBuffer =
      OutgoingCaptionBuffer<_OutgoingCaptionMessage>();
  final Set<Future<void>> _outgoingCaptionFlushes = <Future<void>>{};
  final CaptionLogQueue<_CaptionLogEntry> _captionLogQueue =
      CaptionLogQueue<_CaptionLogEntry>();
  final Set<String> _reportedCaptionRuntimeIssueCodes = <String>{};

  // Deepgram integration
  final _lifecycleTransitions = DailyLifecycleTransitionQueue(
    onError: (_) {
      if (kDebugMode) {
        print('Daily lifecycle: transition_failed');
      }
    },
  );

  // Removed quality monitoring - Daily Adaptive Bitrate handles this

  // Constants - production optimized
  static const int _maxRetryAttempts = 5;
  static const int _baseRetryDelayMs = 1000;
  static const int _maxRetryDelayMs = 30000;
  static const int _captionUiThrottleMs = 120;
  static const int _captionSendThrottleMs = 200;
  static const int _captionFadeDurationMs = 220;
  static const int _captionUtteranceEndFallbackMs = 300;
  static const int _captionHoldBaseMs = 1800;
  static const int _captionHoldPerCharacterMs = 45;
  static const int _captionHoldMinMs = 2500;
  static const int _captionHoldMaxMs = 5500;
  static const int _captionMaxVisibleCharacters = 72;
  static const int _captionLogFlushDebounceMs = 1000;
  static const int _captionLogBatchThreshold = 8;
  static const double _captionKeyboardLaneHeight = 196.0;
  static const double _captionKeyboardMinChatHeight = 120.0;
  static const double _captionCompactMaxHeight = 128.0;
  static const double _captionRegularMaxHeight = 180.0;
  static const int _remoteVideoGraceMs = 2000;
  static const int _callCheckpointNoticeDurationMs = 4000;
  static const int _sessionLimitWarningLeadSeconds = 60;
  static const double _chatWideBreakpoint = 720;
  static const List<_CallCheckpointNotice> _callCheckpointNotices =
      <_CallCheckpointNotice>[
    _CallCheckpointNotice(
      minutes: 5,
      title: 'Прошло 5 минут',
      subtitle: 'Продолжай, если тебе комфортно.',
      accentColor: Color(0xFFA0BBFF),
    ),
    _CallCheckpointNotice(
      minutes: 10,
      title: 'Прошло 10 минут',
      subtitle: 'Можно завершить звонок, когда будешь готов(а).',
      accentColor: Color(0xFF7430E8),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatFocusNode.addListener(_handleChatFocusChanged);
    _deepgramCredential = _configuredDeepgramCredentialFor(widget);
    _initializeWidget();
  }

  void _handleChatFocusChanged() {
    if (!mounted || _disposed) return;
    setState(() {});
  }

  /// Initialize widget with proper error handling
  Future<void> _initializeWidget() async {
    try {
      // Enable hardware acceleration if available
      await _enableHardwareAcceleration();

      if (_hasValidJoinData()) {
        await _initializeCall();
      } else if (_isValidRoomUrl(widget.roomUrl)) {
        _updateState(_state.copyWith(
          connectionState: ConnectionState.connecting,
          clearError: true,
          hasTerminalError: false,
        ));
      }

      // Quality monitoring removed - Daily Adaptive Bitrate handles this
    } catch (e) {
      _handleError('Initialization failed', e);
    }
  }

  /// Enable hardware acceleration for better performance
  Future<void> _enableHardwareAcceleration() async {
    try {
      // Platform-specific hardware acceleration
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } catch (_) {
      if (kDebugMode) print('Daily platform: orientation_setup_failed');
    }
  }

  /// Validate room URL format
  bool _isValidRoomUrl(String url) {
    return join_credentials.isValidRoomUrl(url);
  }

  String? _sanitizeMeetingToken(String? token) {
    return join_credentials.sanitizeMeetingToken(token);
  }

  String? _effectiveMeetingToken() {
    return join_credentials.effectiveMeetingToken(
      dynamicToken: _dynamicMeetingToken,
      configuredToken: widget.meetingToken,
    );
  }

  String? _sanitizeRoomUrl(String? url) {
    return join_credentials.sanitizeRoomUrl(url);
  }

  String? _effectiveRoomUrl() {
    return join_credentials.effectiveRoomUrl(
      dynamicRoomUrl: _dynamicRoomUrl,
      configuredRoomUrl: widget.roomUrl,
    );
  }

  String? _configuredDeepgramCredentialFor(
    MinimalDailyWidget widgetInstance,
  ) {
    return join_credentials.configuredDeepgramCredential(
      primaryCredential: widgetInstance.deepgramCredential,
      // ignore: deprecated_member_use_from_same_package
      legacyApiKey: widgetInstance.deepgramApiKey,
    );
  }

  String? _sanitizeDeepgramCredential(String? value) {
    return join_credentials.sanitizeDeepgramCredential(value);
  }

  bool _canUseDeepgram() {
    if (!widget.enableDeepgram) return false;
    if (_sanitizeDeepgramCredential(_deepgramCredential) != null) return true;
    if (_configuredDeepgramCredentialFor(widget) != null) return true;
    return widget.deepgramTokenRefreshCallback != null;
  }

  Future<String?> _resolveDeepgramCredential({
    bool forceRefresh = false,
  }) async {
    final requestGeneration = _deepgramCredentialGeneration;
    final requestSessionId = widget.sessionId?.trim();
    final staticCredential = _configuredDeepgramCredentialFor(widget);

    if (!forceRefresh) {
      final cached = _sanitizeDeepgramCredential(_deepgramCredential);
      if (cached != null) return cached;
      if (staticCredential != null) {
        _deepgramCredential = staticCredential;
        return staticCredential;
      }
    }

    if (widget.deepgramTokenRefreshCallback != null) {
      try {
        final fetched = await widget.deepgramTokenRefreshCallback!.call();
        if (requestGeneration != _deepgramCredentialGeneration ||
            widget.sessionId?.trim() != requestSessionId) {
          return null;
        }
        final sanitized = _sanitizeDeepgramCredential(fetched);
        if (sanitized != null) {
          _deepgramCredential = sanitized;
          return sanitized;
        }
      } on DeepgramCredentialException catch (error) {
        _reportCaptionRuntimeIssue(
          code: error.code,
          message: error.message,
        );
        if (kDebugMode) print('Deepgram credential: refresh_rejected');
      } catch (_) {
        if (kDebugMode) print('Deepgram credential: refresh_failed');
      }
    }

    if (requestGeneration != _deepgramCredentialGeneration ||
        widget.sessionId?.trim() != requestSessionId) {
      return null;
    }
    if (staticCredential != null) {
      _deepgramCredential = staticCredential;
      return staticCredential;
    }

    return null;
  }

  void _reportGenericCredentialUnavailable() {
    // A typed refresh failure has already published a more useful safe issue.
    if (!shouldReportGenericCaptionCredentialIssue(_state.captionIssueCode)) {
      return;
    }
    _reportCaptionRuntimeIssue(
      code: 'caption_token_unavailable',
      message:
          'Субтитры временно недоступны: не удалось получить токен распознавания.',
    );
  }

  bool _hasValidJoinData() {
    return _effectiveRoomUrl() != null && _effectiveMeetingToken() != null;
  }

  void _scheduleProcessActiveCallClientRetry() {
    _createTrackedTimer(const Duration(milliseconds: 250), () {
      if (!mounted || _disposed) {
        return;
      }
      unawaited(_initializeCall());
    });
  }

  /// Widget bridge only: retry/credential policy remains outside the native
  /// resource owner's operation so error recovery cannot await itself.
  Future<void> _initializeCall() async {
    if (!shouldAttemptDailySessionInitialization(
          hasTerminalError: _state.hasTerminalError,
        ) ||
        !mounted ||
        _disposed ||
        _isInitializing ||
        _state.connectionState == ConnectionState.connected) return;
    _isInitializing = true;
    Object? failure;
    final sessionId = widget.sessionId;
    final roomUrl = widget.roomUrl;
    try {
      await _cleanupFuture;
      if (!mounted || _disposed) return;
      _callTimer.resume();
      _systemCallMarkedConnected = false;
      _userRequestedEnd = false;
      _remoteLeftNotified = false;
      _activeRemoteProfileConfigured = false;
      _prioritySubscribedParticipants.clear();
      _cancelTrackedTimer(_remoteLeftTimer);
      _remoteLeftTimer = null;
      _updateState(_state.copyWith(
        connectionState: ConnectionState.connecting,
        clearError: true,
        hasTerminalError: false,
      ));
      final result = await _dailySession.open();
      if (result == DailySessionOpenResult.busy && mounted && !_disposed) {
        _scheduleProcessActiveCallClientRetry();
      } else if (result == DailySessionOpenResult.quarantined &&
          mounted &&
          !_disposed) {
        _showDailySessionQuarantine();
      }
    } catch (error) {
      failure = error;
    } finally {
      _isInitializing = false;
    }
    if (failure != null &&
        mounted &&
        !_disposed &&
        widget.sessionId == sessionId &&
        widget.roomUrl == roomUrl) {
      if (_dailySession.isQuarantined) {
        _showDailySessionQuarantine();
      } else {
        await _handleConnectionError(failure);
      }
    }
  }

  void _showDailySessionQuarantine() {
    if (!mounted || _disposed) return;
    if (kDebugMode) print('Daily lifecycle: native_resource_quarantined');
    _updateState(_state.copyWith(
      connectionState: ConnectionState.failed,
      hasTerminalError: true,
      error:
          'Не удалось безопасно перезапустить звонок. Закройте и снова откройте приложение.',
    ));
  }

  /// Join room with default settings to avoid SDK parsing errors
  Future<void> _joinRoomWithEnhancedSettings(CallClient client) async {
    final roomUrl = _effectiveRoomUrl();
    if (roomUrl == null) {
      throw StateError('Daily room URL is not ready');
    }
    final roomUri = Uri.parse(roomUrl);
    final token = _effectiveMeetingToken();

    await client.join(url: roomUri, token: token);
  }

  Future<void> _configurePublishing(CallClient client) async {
    await client.updatePublishing(
      publishing: PublishingSettingsUpdate.set(
        microphone: const MicrophonePublishingSettingsUpdate.set(
          isPublishing: BoolUpdate.set(true),
        ),
        camera: CameraPublishingSettingsUpdate.set(
          isPublishing: const BoolUpdate.set(true),
          sendSettings: VideoSendSettingsUpdate.set(
            maxQuality: VideoSendSettingsMaxQualityUpdate.high,
          ),
        ),
      ),
    );
  }

  Future<void> _enableLocalInputs(CallClient client) async {
    await client.updateInputs(
      inputs: const InputSettingsUpdate.set(
        camera: CameraInputSettingsUpdate.set(isEnabled: BoolUpdate.set(true)),
        microphone:
            MicrophoneInputSettingsUpdate.set(isEnabled: BoolUpdate.set(true)),
      ),
    );
  }

  /// Configure username with fallback
  Future<void> _configureUsername(CallClient client) async {
    try {
      final name = widget.username ?? _getDefaultUsername();
      await client.setUsername(name);
    } catch (_) {
      if (kDebugMode) print('Daily participant: username_setup_failed');
    }
  }

  /// Get platform-specific default username
  String _getDefaultUsername() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'iOS User';
      case TargetPlatform.android:
        return 'Android User';
      default:
        return 'Guest';
    }
  }

  /// Handle call events with comprehensive processing
  void _handleCallEvent(dynamic event) {
    if (!mounted || _disposed) return;

    try {
      event.whenOrNull(
        callStateUpdated: _handleCallStateUpdate,
        participantJoined: _handleParticipantJoined,
        participantUpdated: _handleParticipantUpdated,
        participantLeft: _handleParticipantLeft,
        subscriptionsUpdated: _handleSubscriptionsUpdated,
        subscriptionProfilesUpdated: _handleSubscriptionProfilesUpdated,
        appMessageReceived: _handleAppMessage,
        inputsUpdated: _handleInputsUpdated,
        error: _handleEventError,
      );
    } catch (_) {
      if (kDebugMode) print('Daily event: callback_failed');
    }
  }

  /// Handle call state updates
  void _handleCallStateUpdate(CallStateData data) {
    if (!mounted || _disposed) return;

    switch (data.state) {
      case CallState.joined:
        _updateState(_state.copyWith(
          connectionState: ConnectionState.connected,
          clearError: true,
          hasTerminalError: false,
          retryCount: 0,
        ));
        _tokenRefreshAttempts = 0;
        unawaited(_updateLocalVideoTrack());
        unawaited(_markRoomJoined());
        unawaited(_promoteToActiveCallIfReady());
        break;

      case CallState.left:
        _stopDeepgramStreamingUnawaited();
        if (_userRequestedEnd) {
          _updateState(_state.copyWith(
            connectionState: ConnectionState.disconnected,
          ));
          unawaited(_endSystemCallUi());
        } else if (_state.connectionState == ConnectionState.reconnecting) {
          // Already reconnecting (e.g. from _performReconnection cleanup) -
          // don't schedule another reconnection or override state
          if (kDebugMode) {
            print('CallState.left during reconnection - ignoring');
          }
        } else {
          _updateState(_state.copyWith(
            connectionState: ConnectionState.disconnected,
          ));
          _scheduleReconnection();
        }
        break;

      default:
        break;
    }
  }

  /// Handle participant joined event
  void _handleParticipantJoined(Participant participant) {
    if (!participant.info.isLocal && mounted) {
      _cancelTrackedTimer(_remoteLeftTimer);
      _remoteLeftTimer = null;
      _remoteLeftNotified = false;
      _addRemoteParticipant(participant);
      unawaited(_promoteToActiveCallIfReady());
    }
  }

  /// Handle participant updated event.
  ///
  /// CRITICAL FIX: Only cancel the remote-left timer if this participant
  /// is still tracked in _state.remoteControllers. The Daily SDK can send
  /// stale participantUpdated events AFTER participantLeft (e.g. track
  /// state transitions during disconnect). Without this guard, the stale
  /// update cancels the 4-second leave timer and the tutor never receives
  /// the participantLeftCallback — causing the tutor to hang on
  /// VideoCallPage with no way to exit.
  void _handleParticipantUpdated(Participant participant) {
    if (participant.info.isLocal) {
      unawaited(_updateLocalVideoTrack());
    } else {
      // Ignore updates for participants already removed (stale events)
      if (!_state.remoteControllers.containsKey(participant.id)) {
        return;
      }
      _cancelTrackedTimer(_remoteLeftTimer);
      _remoteLeftTimer = null;
      _remoteLeftNotified = false;
      final shouldRefreshUi = _syncRemoteParticipantUiSignature(participant);
      unawaited(_updateRemoteParticipant(participant));
      if (shouldRefreshUi) {
        _updateState(_state.copyWith());
      }
      unawaited(_prioritizeRemoteSubscription(participant.id));
    }
  }

  /// Handle participant left event
  void _handleParticipantLeft(Participant participant) {
    if (participant.info.isLocal) {
      return;
    }
    _removeRemoteParticipant(participant.id);
    if (_state.remoteControllers.isNotEmpty) {
      return;
    }
    _stopDurationTimer();
    unawaited(_syncDeepgramWithMicrophoneState());
    if (_remoteLeftNotified) {
      return;
    }
    _cancelTrackedTimer(_remoteLeftTimer);
    final timer = _createTrackedTimer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_state.remoteControllers.isNotEmpty) return;
      _remoteLeftNotified = true;
      unawaited(_endSystemCallUi());
      unawaited(_endSessionAndPersistCallChat('peer_left'));
      widget.participantLeftCallback?.call();
    });
    _remoteLeftTimer = timer;
  }

  void _handleSubscriptionsUpdated(
    Map<ParticipantId, SubscriptionSettings> subscriptions,
  ) {
    _prioritySubscribedParticipants
      ..clear()
      ..addAll(
        subscriptions.entries
            .where(
              (entry) =>
                  entry.value.profile == SubscriptionProfile.activeRemote,
            )
            .map((entry) => entry.key),
      );
  }

  void _handleSubscriptionProfilesUpdated(
    Map<SubscriptionProfile, MediaSubscriptionSettings> profiles,
  ) {
    _activeRemoteProfileConfigured = _matchesActiveRemoteProfile(
      profiles[SubscriptionProfile.activeRemote],
    );
  }

  /// Handle app messages with validation
  void _handleAppMessage(String message, ParticipantId from) {
    if (!mounted) return;

    try {
      final payload = decodeDailyAppMessagePayload(message);
      if (payload == null) return;

      final type = payload['type']?.toString();
      if (type == 'caption') {
        _processCaptionMessage(payload, from);
      } else if (type == 'chat') {
        _processChatMessage(payload['text']?.toString() ?? '', from);
      }
    } catch (_) {
      if (kDebugMode) print('Daily app message: invalid_payload');
    }
  }

  /// Process caption message with revision-aware ordering.
  void _processCaptionMessage(
      Map<String, dynamic> payload, ParticipantId from) {
    final current = _state.remoteCaptions[from];
    final decision = caption_policy.resolveRemoteCaptionMessage(
      payload,
      current: current == null
          ? null
          : (
              utteranceId: current.utteranceId,
              revision: current.revision,
              text: current.text,
              isFinal: current.phase == _CaptionPhase.finalCaption,
              isFadingOut: current.isFadingOut,
            ),
      legacyCounter: _remoteLegacyCaptionCounters[from] ?? 0,
    );
    final counterUpdate = decision.legacyCounterUpdate;
    if (counterUpdate != null) {
      _remoteLegacyCaptionCounters[from] = counterUpdate;
    }
    final update = decision.update;
    if (update == null) return;

    _upsertRemoteCaption(
      participantId: from,
      utteranceId: update.utteranceId,
      revision: update.revision,
      text: update.text,
      phase:
          update.isFinal ? _CaptionPhase.finalCaption : _CaptionPhase.interim,
    );

    if (update.shouldLogLegacyFinal) {
      _enqueueLegacyRemoteCaptionLog(
        from,
        utteranceId: update.utteranceId,
        text: update.text,
      );
    }
  }

  void _processChatMessage(String text, ParticipantId from) {
    _callChatController.receive(
      text,
      senderId: from.id,
      senderName: _participantDisplayName(from),
    );
  }

  String _participantDisplayName(
    ParticipantId participantId, {
    String fallback = 'Собеседник',
  }) {
    final participant = _callClient?.participants.all[participantId];
    return participant_identity.resolveRemoteParticipantName(
      username: participant?.info.username,
      fallback: fallback,
    );
  }

  String _participantLogSpeakerId(
    ParticipantId participantId, {
    required int utteranceId,
  }) {
    final participant = _callClient?.participants.all[participantId];
    return participant_identity.resolveRemoteCaptionLogSpeakerId(
      userId: participant?.info.userId,
      participantSessionId: participantId.id,
      utteranceId: utteranceId,
    );
  }

  String _localParticipantName() {
    return participant_identity.resolveLocalParticipantName(
      dailyUsername: _callClient?.participants.local.info.username,
      configuredUsername: widget.username,
      isStudent: widget.isStudent,
    );
  }

  String _localParticipantId() {
    return participant_identity.resolveLocalParticipantId(
      _callClient?.participants.local.id.id,
    );
  }

  void _syncCallChatState() {
    if (!mounted || _disposed) return;
    final messages = _callChatController.messages
        .map((message) => _ChatMessage(
              id: message.id,
              text: message.text,
              senderName: message.senderName,
              senderId: message.senderId,
              sentAt: message.sentAt,
              isLocal: message.isLocal,
            ))
        .toList(growable: false);
    _updateState(_state.copyWith(
      chatMessages: List<_ChatMessage>.unmodifiable(messages),
      unreadChatCount: _callChatController.unreadCount,
      isChatOpen: _state.isChatOpen,
    ));
  }

  void _scrollChatToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) return;

      final position = _chatScrollController.position.maxScrollExtent;
      if (animated) {
        _chatScrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      } else {
        _chatScrollController.jumpTo(position);
      }
    });
  }

  void _setChatOpen(bool isOpen) {
    if (!mounted || _disposed) return;
    if (!isOpen) _clearChatDraft();
    _callChatController.setOpen(isOpen);
    _updateState(_state.copyWith(isChatOpen: isOpen));
    if (isOpen) _scrollChatToBottom(animated: false);
  }

  void _toggleChatOpen() {
    _setChatOpen(!_state.isChatOpen);
  }

  void _clearChatDraft() {
    _chatTextController.clear();
    _chatFocusNode.unfocus();
  }

  bool _canSendChatText(String text) {
    return !_callChatController.isSending &&
        text.trim().isNotEmpty &&
        _state.connectionState == ConnectionState.connected &&
        !_dailySession.isClosing &&
        _hasRemoteParticipantPresent();
  }

  Future<bool> _sendCallChatText(String text) async {
    final payload = dart_convert.jsonEncode({'type': 'chat', 'text': text});
    var delivered = false;
    await _dailySession.runWithClient((client) async {
      await client.sendAppMessage(payload, null);
      delivered = true;
    });
    return delivered;
  }

  Future<void> _sendChatMessage() async {
    final text = _chatTextController.text;
    if (!_canSendChatText(text)) return;
    await _callChatController.send(text);
  }

  bool _isTerminalSessionStatus(String? status) {
    final normalized = status?.trim().toLowerCase();
    return normalized == 'ended' ||
        normalized == 'cancelled' ||
        normalized == 'expired';
  }

  Future<void> _persistCallChatBatch(
    String sessionId,
    List<CallChatMessage> messages,
  ) async {
    await FirebaseFunctions.instance.httpsCallable('persistCallChat').call({
      'sessionId': sessionId,
      'messages': messages
          .map((message) => {
                'clientId': message.id,
                'text': message.text,
                'sentAtMs': message.sentAt.millisecondsSinceEpoch,
              })
          .toList(growable: false),
    }).timeout(const Duration(seconds: 8));
  }

  Future<void> _endCallChatSession(String sessionId, String? reason) async {
    await FirebaseFunctions.instance.httpsCallable('endSession').call({
      'sessionId': sessionId,
      if (reason != null && reason.isNotEmpty) 'endReason': reason,
    }).timeout(const Duration(seconds: 8));
  }

  Future<void> _persistOwnCallChatMessages({int? expectedGeneration}) async {
    if (expectedGeneration != null &&
        expectedGeneration != _callChatController.generation) {
      return;
    }
    await _callChatController.persist();
  }

  Future<void> _endSessionAndPersistCallChat(String? endReason) =>
      _callChatController.endSessionAndPersist(endReason);

  String _formatChatTimestamp(DateTime sentAt) {
    final hour = sentAt.hour.toString().padLeft(2, '0');
    final minute = sentAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Handle inputs updated event
  void _handleInputsUpdated(InputSettings inputs) {
    unawaited(_updateLocalVideoTrack());
    _updateState(_state.copyWith(
      cameraEnabled: inputs.camera.isEnabled,
      microphoneEnabled: inputs.microphone.isEnabled,
    ));
    unawaited(
      _syncDeepgramWithMicrophoneState(
        forceRefresh: inputs.microphone.isEnabled,
      ),
    );
  }

  /// Handle event errors - filter out non-fatal errors
  void _handleEventError(Object error) {
    final decision = classifyDailyRuntimeError(
      error,
      fromEventStream: true,
    );
    if (kDebugMode) print('Daily event: ${decision.diagnosticCode}');

    // Track subscription failures are transient; Daily retries them itself.
    if (decision.isTransientEvent) {
      return;
    }

    // Only escalate truly fatal errors to connection error handler
    unawaited(_handleConnectionError(error, decision: decision));
  }

  /// Add remote participant with proper resource management
  void _addRemoteParticipant(Participant participant) {
    if (!mounted || _disposed) return;

    try {
      // Check if controller already exists to avoid duplicates
      if (_state.remoteControllers.containsKey(participant.id)) {
        unawaited(_updateRemoteParticipant(participant));
        return;
      }

      _remoteJoinTimes[participant.id] = DateTime.now();
      _remoteTrackReady[participant.id] = false;
      _remoteParticipantUiSignatures[participant.id] =
          _buildRemoteParticipantUiSignature(participant);

      final controller = VideoViewController();
      final controllers = Map<ParticipantId, VideoViewController>.from(
          _state.remoteControllers);
      controllers[participant.id] = controller;

      _updateState(_state.copyWith(remoteControllers: controllers));
      unawaited(_prioritizeRemoteSubscription(participant.id));

      unawaited(_updateRemoteParticipant(participant));

      // Delay to ensure controller is initialized and video track is set
      _createTrackedTimer(const Duration(milliseconds: 200), () {
        if (mounted) {
          unawaited(_updateRemoteParticipant(participant));
        }
      });
    } catch (_) {
      if (kDebugMode) print('Daily participant: add_failed');
    }
  }

  bool _syncRemoteParticipantUiSignature(Participant participant) {
    final nextSignature = _buildRemoteParticipantUiSignature(participant);
    final previousSignature = _remoteParticipantUiSignatures[participant.id];
    if (previousSignature == nextSignature) {
      return false;
    }
    _remoteParticipantUiSignatures[participant.id] = nextSignature;
    return true;
  }

  String _buildRemoteParticipantUiSignature(Participant participant) {
    final media = participant.media;
    final username = participant.info.username ?? '';
    final cameraState = media?.camera.state.name ?? 'unknown';
    final screenVideoState = media?.screenVideo.state.name ?? 'unknown';
    return '$username|$cameraState|$screenVideoState';
  }

  /// Update remote participant video track
  Future<void> _updateRemoteParticipant(Participant participant) async {
    final client = _callClient;
    if (!mounted ||
        _disposed ||
        client == null ||
        !_dailySession.isCurrent(client)) return;

    final controller = _state.remoteControllers[participant.id];
    if (controller == null) {
      // Controller might not be created yet, retry
      _createTrackedTimer(const Duration(milliseconds: 200), () {
        if (mounted &&
            _dailySession.isCurrent(client) &&
            _state.remoteControllers.containsKey(participant.id)) {
          unawaited(_updateRemoteParticipant(participant));
        }
      });
      return;
    }

    final media = participant.media;
    final track = media?.screenVideo.state != MediaState.off
        ? media?.screenVideo.track
        : media?.camera.track;

    final current = await _dailySession.runWithClient((_) => _setVideoTrack(
          controller,
          track,
          debugContext: 'Failed to update remote participant track',
        ));
    if (!current ||
        !identical(_state.remoteControllers[participant.id], controller))
      return;

    final wasReady = _remoteTrackReady[participant.id] ?? false;
    final isReady = track != null;
    if (wasReady != isReady) {
      _remoteTrackReady[participant.id] = isReady;
      if (mounted) {
        _updateState(_state.copyWith());
      }
      if (isReady) {
        unawaited(_promoteToActiveCallIfReady());
      }
    }
  }

  Future<void> _prioritizeRemoteSubscription(ParticipantId id) async {
    final client = _callClient;
    if (client == null || !_dailySession.isCurrent(client)) return;
    if (_prioritySubscribedParticipants.contains(id) &&
        _activeRemoteProfileConfigured) {
      return;
    }

    try {
      await _ensureActiveRemoteSubscriptionProfile(client);
      if (!_dailySession.isCurrent(client)) return;
      final current = await _dailySession
          .runWithClient((active) => active.updateSubscriptions(
                forParticipants: {
                  id: SubscriptionSettingsUpdate.set(
                    profile: const SubscriptionProfileUpdate.set(
                      profile: SubscriptionProfile.activeRemote,
                    ),
                  ),
                },
              ));
      if (current) _prioritySubscribedParticipants.add(id);
    } catch (_) {
      if (kDebugMode) print('Daily subscription: priority_update_failed');
    }
  }

  /// Remove remote participant and cleanup resources
  void _removeRemoteParticipant(ParticipantId id) {
    if (!mounted || _disposed) return;

    try {
      _remoteJoinTimes.remove(id);
      _remoteTrackReady.remove(id);
      _remoteCaptionClearGenerations.remove(id);
      _remoteLegacyCaptionCounters.remove(id);
      _prioritySubscribedParticipants.remove(id);
      _remoteParticipantUiSignatures.remove(id);

      final controllers = Map<ParticipantId, VideoViewController>.from(
          _state.remoteControllers);
      final controller = controllers.remove(id);

      unawaited(_disposeVideoController(
        controller,
        debugContext: 'Failed to dispose remote video controller',
        delay: const Duration(milliseconds: 100),
      ));

      _updateState(_state.copyWith(remoteControllers: controllers));

      // Also clear any captions from this participant
      _clearRemoteCaption(id);
    } catch (_) {
      if (kDebugMode) print('Daily participant: remove_failed');
    }
  }

  /// Update local video track safely
  Future<void> _updateLocalVideoTrack() async {
    final client = _callClient;
    final controller = _localVideoController;
    if (client == null ||
        controller == null ||
        !mounted ||
        !_dailySession.isCurrent(client)) return;

    final local = client.participants.local;
    final track = local.media?.camera.track;

    // Update track - VideoViewController doesn't have a track getter
    // so we always set the track
    await _dailySession.runWithClient((_) => _setVideoTrack(
          controller,
          track,
          debugContext: 'Local video track update failed',
        ));
  }

  /// Update input settings with quality preservation
  Future<void> _updateInputSettings({bool? camera, bool? microphone}) async {
    final client = _callClient;
    if (client == null || !mounted || !_dailySession.isCurrent(client)) return;

    try {
      final current =
          await _dailySession.runWithClient((active) => active.updateInputs(
                inputs: InputSettingsUpdate.set(
                  camera: camera != null
                      ? CameraInputSettingsUpdate.set(
                          isEnabled: BoolUpdate.set(camera))
                      : null,
                  microphone: microphone != null
                      ? MicrophoneInputSettingsUpdate.set(
                          isEnabled: BoolUpdate.set(microphone))
                      : null,
                ),
              ));
      if (!current) return;

      _updateState(_state.copyWith(
        cameraEnabled: camera ?? _state.cameraEnabled,
        microphoneEnabled: microphone ?? _state.microphoneEnabled,
      ));
      if (microphone != null) {
        await _syncDeepgramWithMicrophoneState(forceRefresh: microphone);
        if (microphone == false && _dailySession.isCurrent(client)) {
          await _flushPendingCaptionLogs(force: true);
        }
      }
    } catch (_) {
      if (kDebugMode) print('Daily inputs: update_failed');
    }
  }

  Future<void> _disableLocalInputsForCleanup(CallClient client) async {
    try {
      await client
          .updateInputs(
            inputs: const InputSettingsUpdate.set(
              camera: CameraInputSettingsUpdate.set(
                isEnabled: BoolUpdate.set(false),
              ),
              microphone: MicrophoneInputSettingsUpdate.set(
                isEnabled: BoolUpdate.set(false),
              ),
            ),
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      if (kDebugMode) {
        print('Daily inputs: cleanup_disable_failed');
      }
    }

    _updateState(_state.copyWith(
      cameraEnabled: false,
      microphoneEnabled: false,
    ));
  }

  bool _hasRemoteParticipantPresent() {
    final remoteParticipants = _callClient?.participants.remote;
    return remoteParticipants != null && remoteParticipants.isNotEmpty;
  }

  bool _shouldRunDeepgram() {
    return mounted &&
        !_disposed &&
        !_dailySession.isClosing &&
        _state.connectionState == ConnectionState.connected &&
        _state.microphoneEnabled &&
        _hasRemoteParticipantPresent() &&
        _canUseDeepgram();
  }

  Future<void> _syncDeepgramWithMicrophoneState({
    bool forceRefresh = false,
  }) async {
    await _deepgramTransport.sync(forceRefresh: forceRefresh);
    if (!_shouldRunDeepgram()) _clearLocalCaptions();
  }

  Future<void> _promoteToActiveCallIfReady() async {
    final client = _callClient;
    if (client == null || !_dailySession.isCurrent(client)) return;
    if (_state.connectionState != ConnectionState.connected) return;
    if (!_hasRemoteParticipantPresent()) return;

    await _markRoomJoined();
    if (!_dailySession.isCurrent(client)) return;
    await _markSystemCallConnected();
    if (!_dailySession.isCurrent(client)) return;
    if (session_limit_ui.shouldRunCallDurationTimer(
      sessionStatus: widget.sessionStatus,
      isDailyConnected: _state.connectionState == ConnectionState.connected,
      hasRemoteParticipant: _hasRemoteParticipantPresent(),
      hasServerConnectedAt: widget.sessionConnectedAt != null,
    )) {
      _startDurationTimer();
    }
    await _syncDeepgramWithMicrophoneState(forceRefresh: true);
  }

  void _invalidateLocalCaptionClear() {
    _localCaptionClearGeneration += 1;
  }

  int _nextRemoteCaptionClearGeneration(ParticipantId id) {
    final nextGeneration = (_remoteCaptionClearGenerations[id] ?? 0) + 1;
    _remoteCaptionClearGenerations[id] = nextGeneration;
    return nextGeneration;
  }

  void _clearLocalCaptions() {
    _invalidateLocalCaptionClear();
    _cancelTrackedTimer(_localCaptionUiThrottleTimer);
    _localCaptionUiThrottleTimer = null;
    _cancelTrackedTimer(_remoteCaptionSendThrottleTimer);
    _remoteCaptionSendThrottleTimer = null;
    _cancelTrackedTimer(_localUtteranceEndTimer);
    _localUtteranceEndTimer = null;
    _pendingLocalCaptionUpdate = null;
    _outgoingCaptionBuffer.clear();
    _localCaptionAssembler.clear();

    if (_state.localCaption == null) {
      return;
    }
    _updateCaptionState(_state.copyWith(clearLocalCaption: true));
  }

  Future<void> _ensureActiveRemoteSubscriptionProfile(
      [CallClient? target]) async {
    final client = target ?? _callClient;
    if (client == null ||
        !_dailySession.isCurrent(client) ||
        _activeRemoteProfileConfigured) return;

    try {
      final current = await _dailySession
          .runWithClient((active) => active.updateSubscriptionProfiles(
                forProfiles: {
                  SubscriptionProfile.activeRemote:
                      const MediaSubscriptionSettingsUpdate.set(
                    camera: VideoSubscriptionSettingsUpdate.set(
                      subscriptionState: SubscriptionStateUpdate.subscribed,
                      receiveSettings: VideoReceiveSettingsUpdate.set(
                        maxQuality: VideoReceiveSettingsMaxQualityUpdate.high,
                      ),
                    ),
                    screenVideo: VideoSubscriptionSettingsUpdate.set(
                      subscriptionState: SubscriptionStateUpdate.subscribed,
                      receiveSettings: VideoReceiveSettingsUpdate.set(
                        maxQuality: VideoReceiveSettingsMaxQualityUpdate.high,
                      ),
                    ),
                    microphone: AudioSubscriptionSettingsUpdate.set(
                      subscriptionState: SubscriptionStateUpdate.subscribed,
                    ),
                    screenAudio: AudioSubscriptionSettingsUpdate.set(
                      subscriptionState: SubscriptionStateUpdate.subscribed,
                    ),
                  ),
                },
              ));
      if (current) {
        _activeRemoteProfileConfigured = true;
      }
    } catch (_) {
      if (kDebugMode) {
        print('Daily subscription: active_profile_failed');
      }
    }
  }

  bool _matchesActiveRemoteProfile(MediaSubscriptionSettings? settings) {
    if (settings == null) return false;

    return settings.camera.subscriptionState == SubscriptionState.subscribed &&
        settings.camera.receiveSettings.maxQuality ==
            VideoReceiveSettingsMaxQuality.high &&
        settings.screenVideo.subscriptionState ==
            SubscriptionState.subscribed &&
        settings.screenVideo.receiveSettings.maxQuality ==
            VideoReceiveSettingsMaxQuality.high &&
        settings.microphone.subscriptionState == SubscriptionState.subscribed &&
        settings.screenAudio.subscriptionState == SubscriptionState.subscribed;
  }

  // All quality monitoring methods removed - Daily Adaptive Bitrate handles everything automatically
  // The SDK monitors network conditions and adjusts bitrate from 800 Kbps to 2 Mbps
  // Resolution automatically scales from 540p to 720p based on available bandwidth

  /// Handle connection errors with exponential backoff retry
  Future<void> _handleConnectionError(
    Object error, {
    DailyRuntimeErrorDecision? decision,
  }) async {
    if (!mounted || _disposed) return;

    final safeDecision = decision ?? classifyDailyRuntimeError(error);
    if (kDebugMode) {
      print('Daily connection: ${safeDecision.diagnosticCode}');
    }

    // If we're already connected and this isn't a token error,
    // don't tear down the connection - it's likely a transient issue
    if (_state.connectionState == ConnectionState.connected &&
        !safeDecision.isTokenError) {
      if (kDebugMode) print('Daily connection: ignored_while_connected');
      return;
    }

    final refreshed = await _tryRefreshTokenOnError(
      isTokenError: safeDecision.isTokenError,
    );
    if (refreshed) {
      return;
    }

    if (safeDecision.isTokenError &&
        _tokenRefreshAttempts >= _maxTokenRefreshAttempts) {
      await _cleanup(
        leaveCall: false,
        preserveMeetingToken: true,
        preserveTokenRefreshAttempts: true,
        preserveChatState: true,
      );
      _updateState(_state.copyWith(
        connectionState: ConnectionState.failed,
        hasTerminalError: false,
        error: safeDecision.userMessage,
      ));
      return;
    }

    _updateState(_state.copyWith(
      connectionState: ConnectionState.failed,
      hasTerminalError: false,
      error: safeDecision.userMessage,
    ));

    if (_state.retryCount < _maxRetryAttempts) {
      _scheduleReconnection();
      return;
    }

    await _cleanup(
      leaveCall: false,
      preserveMeetingToken: true,
      preserveTokenRefreshAttempts: true,
      preserveChatState: true,
    );
  }

  Future<bool> _tryRefreshTokenOnError({required bool isTokenError}) async {
    if (_tokenRefreshInProgress) return false;
    if (_tokenRefreshAttempts >= _maxTokenRefreshAttempts) return false;
    if (widget.tokenRefreshCallback == null &&
        widget.joinCredentialsRefreshCallback == null) {
      return false;
    }

    if (!isTokenError) return false;

    _tokenRefreshInProgress = true;
    _tokenRefreshAttempts += 1;
    try {
      String? newToken;
      String? newRoomUrl;
      if (widget.joinCredentialsRefreshCallback != null) {
        final credentials = await widget.joinCredentialsRefreshCallback!.call();
        newToken = credentials?['meetingToken'];
        newRoomUrl = credentials?['roomUrl'];
      } else {
        newToken = await widget.tokenRefreshCallback!.call();
      }
      final sanitized = _sanitizeMeetingToken(newToken);
      if (sanitized == null) {
        return false;
      }
      _dynamicMeetingToken = sanitized;
      final sanitizedRoomUrl = _sanitizeRoomUrl(newRoomUrl);
      if (sanitizedRoomUrl != null) {
        _dynamicRoomUrl = sanitizedRoomUrl;
      }
      await _cleanup(
        leaveCall: true,
        preserveMeetingToken: true,
        preserveTokenRefreshAttempts: true,
        preserveChatState: true,
      );
      // Parent widgets update roomUrl via setState after refreshing credentials.
      // Wait one frame so a recreated Daily room and its token are used as a pair.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _disposed) {
        return true;
      }
      await _initializeCall();
      return true;
    } catch (_) {
      if (kDebugMode) print('Daily token refresh: failed');
      return false;
    } finally {
      _tokenRefreshInProgress = false;
    }
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnection() {
    final retryCount = _state.retryCount;
    final delay = _calculateRetryDelay(retryCount);

    if (kDebugMode) {
      print(
          'Scheduling reconnection attempt ${retryCount + 1}/$_maxRetryAttempts in ${delay.inSeconds}s');
    }

    _createTrackedTimer(delay, () {
      if (mounted && _state.connectionState != ConnectionState.connected) {
        unawaited(_performReconnection());
      }
    });

    _updateState(_state.copyWith(
      connectionState: ConnectionState.reconnecting,
      retryCount: retryCount + 1,
    ));
  }

  /// Calculate retry delay with exponential backoff
  Duration _calculateRetryDelay(int retryCount) {
    final delayMs = math.min(
      _baseRetryDelayMs * math.pow(2, retryCount).toInt(),
      _maxRetryDelayMs,
    );
    return Duration(milliseconds: delayMs);
  }

  /// Perform reconnection attempt
  Future<void> _performReconnection() async {
    if (!mounted || _disposed) return;

    await _cleanup(
      leaveCall: false,
      preserveMeetingToken: true,
      preserveTokenRefreshAttempts: true,
      preserveChatState: true,
    );
    await _initializeCall();
  }

  Future<void> _stopDeepgramStreaming() => _deepgramTransport.stop();

  void _stopDeepgramStreamingUnawaited() {
    unawaited(
        _stopDeepgramStreaming().catchError((Object _, StackTrace __) {}));
  }

  /// Handle Deepgram message with proper parsing
  void _handleDeepgramMessage(dynamic message) {
    if (!mounted ||
        (!_deepgramTransport.finalizing &&
            (!_state.microphoneEnabled || !_hasRemoteParticipantPresent()))) {
      return;
    }

    try {
      final parsed = deepgram_parser.parseDeepgramMessage(message);
      switch (parsed.kind) {
        case deepgram_parser.DeepgramMessageKind.ignored:
          return;
        case deepgram_parser.DeepgramMessageKind.invalidEnvelope:
          _reportCaptionRuntimeIssue(
            code: 'deepgram_message_parse_failed',
            message:
                'Субтитры временно недоступны: не удалось обработать ответ распознавания.',
          );
          return;
        case deepgram_parser.DeepgramMessageKind.serviceError:
          _reportCaptionRuntimeIssue(
            code: 'deepgram_error_frame',
            message:
                'Субтитры временно недоступны: сервис распознавания вернул ошибку.',
          );
          return;
        case deepgram_parser.DeepgramMessageKind.utteranceEnd:
          _handleDeepgramUtteranceEnd();
          return;
        case deepgram_parser.DeepgramMessageKind.finalizeCurrent:
          _emitFinalUpdateForCurrentLocalCaption();
          return;
        case deepgram_parser.DeepgramMessageKind.transcript:
          _cancelLocalUtteranceEndFallback();
          _handleDeepgramTranscript(
            transcript: parsed.transcript!,
            isFinalSegment: parsed.isFinalSegment,
            speechFinal: parsed.speechFinal,
            confidence: parsed.confidence,
          );
          return;
      }
    } catch (_) {
      _reportCaptionRuntimeIssue(
        code: 'deepgram_message_parse_failed',
        message:
            'Субтитры временно недоступны: не удалось обработать ответ распознавания.',
      );
      if (kDebugMode) print('Deepgram message: processing_failed');
    }
  }

  void _handleDeepgramTranscript({
    required String transcript,
    required bool isFinalSegment,
    required bool speechFinal,
    double? confidence,
  }) {
    if (!_deepgramTransport.finalizing &&
        (!_state.microphoneEnabled || !_hasRemoteParticipantPresent())) {
      return;
    }

    _clearCaptionRuntimeIssue();
    final emission = _localCaptionAssembler.acceptTranscript(
      transcript: transcript,
      isFinalSegment: isFinalSegment,
      speechFinal: speechFinal,
      confidence: confidence,
    );
    final update = _CaptionUpdate(
      utteranceId: emission.utteranceId,
      revision: emission.revision,
      text: emission.text,
      phase:
          emission.isFinal ? _CaptionPhase.finalCaption : _CaptionPhase.interim,
      startedAt: emission.startedAt,
      lastUpdateAt: emission.lastUpdateAt,
    );

    _queueLocalCaptionUpdate(update, immediate: speechFinal);
    _queueOutgoingCaptionMessage(
      _OutgoingCaptionMessage(
        utteranceId: update.utteranceId,
        revision: update.revision,
        text: update.text,
        phase: update.phase,
      ),
      immediate: speechFinal,
    );

    if (speechFinal) {
      _enqueueLocalFinalCaptionLog(update);
      _finalizeLocalUtterance(fallbackText: update.text);
    }
  }

  void _handleDeepgramUtteranceEnd() {
    if (!_localCaptionAssembler.isOpen ||
        _localCaptionAssembler.currentText.isEmpty) {
      return;
    }

    _cancelTrackedTimer(_localUtteranceEndTimer);
    final utteranceId = _localCaptionAssembler.utteranceId;
    final revisionAtSignal = _localCaptionAssembler.revision;

    _localUtteranceEndTimer = _createTrackedTimer(
      const Duration(milliseconds: _captionUtteranceEndFallbackMs),
      () {
        _localUtteranceEndTimer = null;
        if (!_localCaptionAssembler.isOpen ||
            utteranceId != _localCaptionAssembler.utteranceId ||
            revisionAtSignal != _localCaptionAssembler.revision) {
          return;
        }
        _emitFinalUpdateForCurrentLocalCaption();
      },
    );
  }

  void _cancelLocalUtteranceEndFallback() {
    _cancelTrackedTimer(_localUtteranceEndTimer);
    _localUtteranceEndTimer = null;
  }

  void _finalizeLocalUtterance({
    required String fallbackText,
  }) {
    final finalText = _normalizeCaptionText(fallbackText);
    if (finalText.isEmpty) {
      return;
    }

    _cancelLocalUtteranceEndFallback();
    _localCaptionAssembler.closeUtterance(finalText);
    _scheduleCaptionFadeAndClear(
      utteranceId: _localCaptionAssembler.utteranceId,
      holdMs: _holdDurationForCaption(finalText),
    );
  }

  bool _emitFinalUpdateForCurrentLocalCaption() {
    final emission = _localCaptionAssembler.prepareFinalUpdate();
    if (emission == null) return false;
    final update = _CaptionUpdate(
      utteranceId: emission.utteranceId,
      revision: emission.revision,
      text: emission.text,
      phase:
          emission.isFinal ? _CaptionPhase.finalCaption : _CaptionPhase.interim,
      startedAt: emission.startedAt,
      lastUpdateAt: emission.lastUpdateAt,
    );
    _queueLocalCaptionUpdate(update, immediate: true);
    _queueOutgoingCaptionMessage(
      _OutgoingCaptionMessage(
        utteranceId: update.utteranceId,
        revision: update.revision,
        text: update.text,
        phase: update.phase,
      ),
      immediate: true,
    );
    _enqueueLocalFinalCaptionLog(update);
    _finalizeLocalUtterance(fallbackText: update.text);
    return true;
  }

  Future<void> _finalizeCurrentCaptionAndFlushLogs() async {
    // A short utterance can still be interim when the user or peer ends the
    // call. Promote the latest recognized text before clearing caption state.
    _emitFinalUpdateForCurrentLocalCaption();
    while (_outgoingCaptionFlushes.isNotEmpty) {
      await Future.wait(List<Future<void>>.of(_outgoingCaptionFlushes));
    }
    await _flushPendingCaptionLogs(force: true);
  }

  void _scheduleOutgoingCaptionFlush() {
    final flush = _flushOutgoingCaptionMessage();
    _outgoingCaptionFlushes.add(flush);
    unawaited(flush.whenComplete(() => _outgoingCaptionFlushes.remove(flush)));
  }

  void _queueLocalCaptionUpdate(
    _CaptionUpdate update, {
    required bool immediate,
  }) {
    _pendingLocalCaptionUpdate = update;

    if (immediate) {
      _cancelTrackedTimer(_localCaptionUiThrottleTimer);
      _localCaptionUiThrottleTimer = null;
      _flushLocalCaptionUpdate();
      return;
    }

    if (_localCaptionUiThrottleTimer != null) {
      return;
    }

    _localCaptionUiThrottleTimer = _createTrackedTimer(
      const Duration(milliseconds: _captionUiThrottleMs),
      () {
        _localCaptionUiThrottleTimer = null;
        _flushLocalCaptionUpdate();
      },
    );
  }

  void _flushLocalCaptionUpdate() {
    final update = _pendingLocalCaptionUpdate;
    _pendingLocalCaptionUpdate = null;
    if (update == null || !mounted || _disposed) {
      return;
    }

    final current = _state.localCaption;
    if (current != null &&
        current.utteranceId == update.utteranceId &&
        current.revision >= update.revision) {
      return;
    }

    _invalidateLocalCaptionClear();
    _updateCaptionState(_state.copyWith(
      localCaption: _ActiveCaption(
        utteranceId: update.utteranceId,
        revision: update.revision,
        speakerId: _localParticipantId(),
        text: update.text,
        phase: update.phase,
        startedAt: update.startedAt,
        lastUpdateAt: update.lastUpdateAt,
      ),
    ));
  }

  void _enqueueLocalFinalCaptionLog(_CaptionUpdate update) {
    if (update.phase != _CaptionPhase.finalCaption) {
      return;
    }

    final writerId = _captionLogWriterId();
    if (writerId == null) {
      return;
    }

    final normalizedText = _normalizeCaptionText(update.text);
    if (normalizedText.isEmpty) {
      return;
    }

    final entry = _CaptionLogEntry(
      logId: _captionLogDocumentId(
        speakerId: writerId,
        utteranceId: update.utteranceId,
      ),
      speakerId: writerId,
      speakerName: _localParticipantName(),
      speakerRole: _localCaptionSpeakerRole(),
      utteranceId: update.utteranceId,
      text: normalizedText,
      language: widget.deepgramLanguage.trim(),
      source: 'local_deepgram_final',
      capturedAtClient: update.lastUpdateAt,
      confidence: _localCaptionAssembler.confidence,
    );

    _enqueueCaptionLogEntry(entry);
  }

  void _enqueueLegacyRemoteCaptionLog(
    ParticipantId participantId, {
    required int utteranceId,
    required String text,
  }) {
    final writerId = _captionLogWriterId();
    if (writerId == null) {
      return;
    }

    final normalizedText = _normalizeCaptionText(text);
    if (normalizedText.isEmpty) {
      return;
    }

    final speakerId = _participantLogSpeakerId(
      participantId,
      utteranceId: utteranceId,
    );
    final entry = _CaptionLogEntry(
      logId: _captionLogDocumentId(
        speakerId: speakerId,
        utteranceId: utteranceId,
      ),
      speakerId: speakerId,
      speakerName: _participantDisplayName(participantId),
      speakerRole: _remoteCaptionSpeakerRole(),
      utteranceId: utteranceId,
      text: normalizedText,
      language: widget.deepgramLanguage.trim(),
      source: 'peer_legacy_final',
      capturedAtClient: DateTime.now(),
    );

    _enqueueCaptionLogEntry(entry);
  }

  void _enqueueCaptionLogEntry(_CaptionLogEntry entry) {
    if (!_canPersistCaptionLogs()) {
      return;
    }

    if (!_captionLogQueue.enqueue(entry.logId, entry)) {
      return;
    }

    if (_captionLogQueue.pendingCount >= _captionLogBatchThreshold) {
      _cancelTrackedTimer(_captionLogFlushTimer);
      _captionLogFlushTimer = null;
      unawaited(_flushPendingCaptionLogs(force: true));
      return;
    }

    if (_captionLogFlushTimer != null) {
      return;
    }

    _captionLogFlushTimer = _createTrackedTimer(
      const Duration(milliseconds: _captionLogFlushDebounceMs),
      () {
        _captionLogFlushTimer = null;
        unawaited(_flushPendingCaptionLogs(force: true));
      },
    );
  }

  Future<void> _flushPendingCaptionLogs({
    bool force = false,
  }) {
    if (force) {
      _cancelTrackedTimer(_captionLogFlushTimer);
      _captionLogFlushTimer = null;
    }

    final flushFuture = _captionLogQueue.flush((queuedEntries) async {
      final sessionRef = _captionLogSessionRef();
      final writerId = _captionLogWriterId();
      if (sessionRef == null || writerId == null) {
        return false;
      }

      if (kDebugMode) {
        print('Caption log flush: batch_size=${queuedEntries.length}');
      }
      final batch = FirebaseFirestore.instance.batch();

      for (final queuedEntry in queuedEntries) {
        final entry = queuedEntry.value;
        batch.set(
          CaptionLogsRecord.createDoc(sessionRef, id: entry.logId),
          entry.toFirestoreData(writerId: writerId),
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      return true;
    }).then<void>((_) {
      // Outcomes are reflected in queue state; current-generation errors are
      // handled below so the existing retry behavior remains widget-owned.
    }).catchError((Object _) {
      if (kDebugMode) {
        print('Caption log flush: failed');
      }
      if (!_captionLogQueue.isEmpty &&
          _captionLogFlushTimer == null &&
          !_disposed) {
        _captionLogFlushTimer = _createTrackedTimer(
          const Duration(milliseconds: _captionLogFlushDebounceMs),
          () {
            _captionLogFlushTimer = null;
            unawaited(_flushPendingCaptionLogs(force: true));
          },
        );
      }
    });

    return flushFuture;
  }

  void _queueOutgoingCaptionMessage(
    _OutgoingCaptionMessage message, {
    required bool immediate,
  }) {
    _outgoingCaptionBuffer.enqueue(message, message.signature);

    if (immediate) {
      _cancelTrackedTimer(_remoteCaptionSendThrottleTimer);
      _remoteCaptionSendThrottleTimer = null;
      _scheduleOutgoingCaptionFlush();
      return;
    }

    if (_remoteCaptionSendThrottleTimer != null) {
      return;
    }

    _remoteCaptionSendThrottleTimer = _createTrackedTimer(
      const Duration(milliseconds: _captionSendThrottleMs),
      () {
        _remoteCaptionSendThrottleTimer = null;
        _scheduleOutgoingCaptionFlush();
      },
    );
  }

  Future<void> _flushOutgoingCaptionMessage() async {
    final pending = _outgoingCaptionBuffer.takePending();
    if (pending == null) {
      return;
    }

    if (_outgoingCaptionBuffer.isDuplicate(pending.signature)) {
      return;
    }

    final didSend = await _sendCaptionMessage(pending.value);
    if (didSend) {
      _outgoingCaptionBuffer.markSent(pending.signature);
    }
  }

  /// Send caption message to other participants
  Future<bool> _sendCaptionMessage(_OutgoingCaptionMessage message) async {
    if (_callClient == null ||
        message.text.trim().isEmpty ||
        (!_state.microphoneEnabled && !_deepgramTransport.finalizing) ||
        !_hasRemoteParticipantPresent()) {
      return false;
    }

    try {
      await _callClient!.sendAppMessage(
        dart_convert.jsonEncode(message.toJson()),
        null,
      );

      if (kDebugMode) {
        print(
          'Caption sent: ${message.phase.wireValue} #${message.utteranceId}.${message.revision}',
        );
      }
      return true;
    } catch (_) {
      if (kDebugMode) print('Caption transport: send_failed');
      return false;
    }
  }

  void _upsertRemoteCaption({
    required ParticipantId participantId,
    required int utteranceId,
    required int revision,
    required String text,
    required _CaptionPhase phase,
  }) {
    final now = DateTime.now();
    final current = _state.remoteCaptions[participantId];

    // Ordering and phase progression were checked by caption_policy.
    final nextGeneration = _nextRemoteCaptionClearGeneration(participantId);
    final nextCaption = _ActiveCaption(
      utteranceId: utteranceId,
      revision: revision,
      speakerId: participantId.id,
      text: text,
      phase: phase,
      startedAt: current != null && current.utteranceId == utteranceId
          ? current.startedAt
          : now,
      lastUpdateAt: now,
    );

    final remoteCaptions = Map<ParticipantId, _ActiveCaption>.from(
      _state.remoteCaptions,
    );
    remoteCaptions[participantId] = nextCaption;
    _updateCaptionState(_state.copyWith(
      remoteCaptions: Map<ParticipantId, _ActiveCaption>.unmodifiable(
        remoteCaptions,
      ),
    ));

    if (phase == _CaptionPhase.finalCaption) {
      _scheduleCaptionFadeAndClear(
        participantId: participantId,
        utteranceId: utteranceId,
        holdMs: _holdDurationForCaption(text),
        expectedGeneration: nextGeneration,
      );
    }
  }

  void _scheduleCaptionFadeAndClear({
    ParticipantId? participantId,
    required int utteranceId,
    required int holdMs,
    int? expectedGeneration,
  }) {
    final lifecycleGeneration = participantId == null
        ? _localCaptionClearGeneration
        : (expectedGeneration ?? _remoteCaptionClearGenerations[participantId]);
    final expiresAt = DateTime.now().add(
      Duration(milliseconds: holdMs + _captionFadeDurationMs),
    );

    if (participantId == null) {
      final current = _state.localCaption;
      if (current == null || current.utteranceId != utteranceId) {
        return;
      }
      _updateCaptionState(_state.copyWith(
        localCaption:
            current.copyWith(expiresAt: expiresAt, isFadingOut: false),
      ));
    } else {
      final current = _state.remoteCaptions[participantId];
      if (current == null || current.utteranceId != utteranceId) {
        return;
      }
      final remoteCaptions = Map<ParticipantId, _ActiveCaption>.from(
        _state.remoteCaptions,
      );
      remoteCaptions[participantId] = current.copyWith(
        expiresAt: expiresAt,
        isFadingOut: false,
      );
      _updateCaptionState(_state.copyWith(
        remoteCaptions: Map<ParticipantId, _ActiveCaption>.unmodifiable(
          remoteCaptions,
        ),
      ));
    }

    _createTrackedTimer(Duration(milliseconds: holdMs), () {
      if (!mounted) return;
      if (participantId == null) {
        final current = _state.localCaption;
        if (current == null ||
            current.utteranceId != utteranceId ||
            lifecycleGeneration != _localCaptionClearGeneration) {
          return;
        }
        _updateCaptionState(_state.copyWith(
          localCaption: current.copyWith(
            isFadingOut: true,
            expiresAt: expiresAt,
          ),
        ));
      } else {
        final current = _state.remoteCaptions[participantId];
        if (current == null ||
            current.utteranceId != utteranceId ||
            _remoteCaptionClearGenerations[participantId] !=
                lifecycleGeneration) {
          return;
        }
        final remoteCaptions = Map<ParticipantId, _ActiveCaption>.from(
          _state.remoteCaptions,
        );
        remoteCaptions[participantId] = current.copyWith(
          isFadingOut: true,
          expiresAt: expiresAt,
        );
        _updateCaptionState(_state.copyWith(
          remoteCaptions: Map<ParticipantId, _ActiveCaption>.unmodifiable(
            remoteCaptions,
          ),
        ));
      }
    });

    _createTrackedTimer(
      Duration(milliseconds: holdMs + _captionFadeDurationMs),
      () {
        if (!mounted) return;
        if (participantId == null) {
          final current = _state.localCaption;
          if (current == null ||
              current.utteranceId != utteranceId ||
              lifecycleGeneration != _localCaptionClearGeneration) {
            return;
          }
          _clearLocalCaptions();
        } else {
          final current = _state.remoteCaptions[participantId];
          if (current == null ||
              current.utteranceId != utteranceId ||
              _remoteCaptionClearGenerations[participantId] !=
                  lifecycleGeneration) {
            return;
          }
          _clearRemoteCaption(participantId);
        }
      },
    );
  }

  void _clearRemoteCaption(ParticipantId participantId) {
    final currentRemoteCaptions = _state.remoteCaptions;
    if (!currentRemoteCaptions.containsKey(participantId)) {
      _remoteCaptionClearGenerations.remove(participantId);
      return;
    }

    final remoteCaptions = Map<ParticipantId, _ActiveCaption>.from(
      currentRemoteCaptions,
    );
    remoteCaptions.remove(participantId);
    _remoteCaptionClearGenerations.remove(participantId);
    _updateCaptionState(_state.copyWith(
      remoteCaptions: Map<ParticipantId, _ActiveCaption>.unmodifiable(
        remoteCaptions,
      ),
    ));
  }

  int _holdDurationForCaption(String text) {
    final rawDuration = _captionHoldBaseMs +
        (_normalizeCaptionText(text).length * _captionHoldPerCharacterMs);
    return math.max(
      _captionHoldMinMs,
      math.min(rawDuration, _captionHoldMaxMs),
    );
  }

  String _normalizeCaptionText(String rawText) {
    return caption_policy.normalizeCaptionText(rawText);
  }

  String _normalizeCaptionDiagnosticCode(String rawCode) {
    return rawCode
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  void _reportCaptionRuntimeIssue({
    required String code,
    required String message,
    bool persist = true,
  }) {
    final normalizedCode = _normalizeCaptionDiagnosticCode(code);
    final normalizedMessage = _normalizeCaptionText(message);
    if (normalizedCode.isEmpty || normalizedMessage.isEmpty) {
      return;
    }

    if (mounted &&
        !_disposed &&
        (_state.captionIssueCode != normalizedCode ||
            _state.captionIssueMessage != normalizedMessage)) {
      _updateCaptionState(_state.copyWith(
        captionIssueCode: normalizedCode,
        captionIssueMessage: normalizedMessage,
      ));
    }

    final writerId = _captionLogWriterId();
    if (!persist ||
        _reportedCaptionRuntimeIssueCodes.contains(normalizedCode) ||
        _captionLogSessionRef() == null ||
        writerId == null) {
      return;
    }

    _reportedCaptionRuntimeIssueCodes.add(normalizedCode);
    final now = DateTime.now();
    _enqueueCaptionLogEntry(
      _CaptionLogEntry(
        logId: _captionDiagnosticLogDocumentId(
          code: normalizedCode,
          writerId: writerId,
        ),
        speakerId: 'system',
        speakerName: 'SmallTalk',
        speakerRole: 'system',
        utteranceId: 0,
        text: normalizedMessage,
        language: widget.deepgramLanguage.trim(),
        source: 'caption_runtime_diagnostic',
        capturedAtClient: now,
        diagnosticCode: normalizedCode,
      ),
    );
    unawaited(_flushPendingCaptionLogs(force: true));
  }

  void _clearCaptionRuntimeIssue() {
    if (!mounted || _disposed) return;
    if (_state.captionIssueCode == null && _state.captionIssueMessage == null) {
      return;
    }
    _updateCaptionState(_state.copyWith(clearCaptionIssue: true));
  }

  bool _canPersistCaptionLogs() {
    return _captionLogSessionRef() != null && _captionLogWriterId() != null;
  }

  DocumentReference? _captionLogSessionRef() {
    final sessionId = widget.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      return null;
    }

    return VideoSessionsRecord.collection.doc(sessionId);
  }

  String? _captionLogWriterId() {
    final writerId = currentUserUid.trim();
    if (writerId.isEmpty) {
      return null;
    }
    return writerId;
  }

  String _captionLogDocumentId({
    required String speakerId,
    required int utteranceId,
  }) {
    final normalizedSpeakerId =
        speakerId.trim().replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return '${normalizedSpeakerId}_$utteranceId';
  }

  String _captionDiagnosticLogDocumentId({
    required String code,
    required String writerId,
  }) {
    final normalizedCode = _normalizeCaptionDiagnosticCode(code);
    return 'system_${writerId.trim()}_$normalizedCode';
  }

  String _localCaptionSpeakerRole() {
    return widget.isStudent == true ? 'student' : 'tutor';
  }

  String _remoteCaptionSpeakerRole() {
    return widget.isStudent == true ? 'tutor' : 'student';
  }

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        if (_appInForeground) {
          _appInForeground = false;
          _handleAppBackground();
        }
        break;
      case AppLifecycleState.resumed:
        if (!_appInForeground) {
          _appInForeground = true;
          _handleAppForeground();
        }
        break;
      default:
        break;
    }
  }

  /// Handle app going to background
  void _handleAppBackground() {
    if (_state.connectionState == ConnectionState.connected) {
      _resumeCameraEnabled = _state.cameraEnabled;
      _resumeMicrophoneEnabled = _state.microphoneEnabled;
      unawaited(_enqueueLifecycleTransition((transitionId) async {
        if (!_isCurrentLifecycleTransition(transitionId)) return;
        await _updateInputSettings(camera: false, microphone: false);
      }));
    }
  }

  /// Handle app returning to foreground
  void _handleAppForeground() {
    if (_state.connectionState == ConnectionState.connected) {
      final resumeCameraEnabled = _resumeCameraEnabled;
      final resumeMicrophoneEnabled = _resumeMicrophoneEnabled;
      unawaited(_enqueueLifecycleTransition((transitionId) async {
        if (!_isCurrentLifecycleTransition(transitionId)) return;
        await _updateInputSettings(
          camera: resumeCameraEnabled,
          microphone: resumeMicrophoneEnabled,
        );
        if (!_isCurrentLifecycleTransition(transitionId)) return;
        await _promoteToActiveCallIfReady();
      }));
    }
  }

  Future<void> _enqueueLifecycleTransition(
    Future<void> Function(int transitionId) action,
  ) {
    return _lifecycleTransitions.enqueue(action);
  }

  bool _isCurrentLifecycleTransition(int transitionId) {
    return mounted &&
        !_disposed &&
        _lifecycleTransitions.isCurrent(transitionId) &&
        _state.connectionState == ConnectionState.connected;
  }

  /// Update widget when properties change.
  ///
  /// CRITICAL FIX: Do NOT tear down an active or initializing connection
  /// just because the meeting token refreshed (e.g. from _fetchSessionTokens
  /// in VideoCallPageWidget). Destroying the CallClient mid-join causes
  /// crashes on macOS (AppKit layout cycle) and race conditions in the
  /// Daily SDK. Only reconnect when the room URL itself changes.
  @override
  void didUpdateWidget(MinimalDailyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldConfiguredDeepgramCredential =
        _configuredDeepgramCredentialFor(oldWidget);
    final newConfiguredDeepgramCredential =
        _configuredDeepgramCredentialFor(widget);
    if (oldConfiguredDeepgramCredential != newConfiguredDeepgramCredential) {
      _deepgramCredentialGeneration += 1;
      _deepgramCredential = newConfiguredDeepgramCredential;
      if (oldConfiguredDeepgramCredential == null &&
          newConfiguredDeepgramCredential != null) {
        unawaited(_syncDeepgramWithMicrophoneState(forceRefresh: true));
      }
    }
    final sessionIdChanged = oldWidget.sessionId != widget.sessionId;
    if (sessionIdChanged) {
      _deepgramCredentialGeneration += 1;
      _stopDeepgramStreamingUnawaited();
      _roomJoinMarked = false;
      _dynamicMeetingToken = null;
      _dynamicRoomUrl = null;
      _callChatController.resetSession();

      _callTimer.resetLimitMarkers();
      _callTimer.serverClockOffset = null;
      _sessionExtensionRequestInFlight = false;
      _resetCallCheckpointNotice(clearHistory: true);
      _cancelTrackedTimer(_captionLogFlushTimer);
      _captionLogFlushTimer = null;
      _captionLogQueue.reset();
      _reportedCaptionRuntimeIssueCodes.clear();
      _clearCaptionRuntimeIssue();
    }
    if (oldWidget.sessionExpiresAt != widget.sessionExpiresAt) {
      _callTimer.resetLimitMarkers();
      _clearSessionLimitWarningNotice();
      if (_state.connectionState == ConnectionState.connected) {
        _setCallDurationValue(_callDurationNotifier.value);
      }
    }

    final oldSessionStatus = oldWidget.sessionStatus?.trim().toLowerCase();
    final newSessionStatus = widget.sessionStatus?.trim().toLowerCase();
    if (oldSessionStatus != 'active' &&
        session_limit_ui.shouldRunCallDurationTimer(
          sessionStatus: newSessionStatus,
          isDailyConnected: _state.connectionState == ConnectionState.connected,
          hasRemoteParticipant: _hasRemoteParticipantPresent(),
          hasServerConnectedAt: widget.sessionConnectedAt != null,
        )) {
      _startDurationTimer();
    }
    if (oldWidget.sessionConnectedAt != widget.sessionConnectedAt &&
        session_limit_ui.shouldRunCallDurationTimer(
          sessionStatus: newSessionStatus,
          isDailyConnected: _state.connectionState == ConnectionState.connected,
          hasRemoteParticipant: _hasRemoteParticipantPresent(),
          hasServerConnectedAt: widget.sessionConnectedAt != null,
        )) {
      _startDurationTimer();
      _setCallDurationValue(_authoritativeCallDurationSeconds());
    }
    if (!_isTerminalSessionStatus(oldWidget.sessionStatus) &&
        _isTerminalSessionStatus(widget.sessionStatus)) {
      _stopDurationTimer();
      if (!sessionIdChanged) {
        unawaited(_persistOwnCallChatMessages(
          expectedGeneration: _callChatController.generation,
        ));
      }
    }

    final oldUrl = oldWidget.roomUrl;
    final newUrl = widget.roomUrl;
    final newValid = _isValidRoomUrl(newUrl);
    final dynamicRoomUrl = _sanitizeRoomUrl(_dynamicRoomUrl);
    final parentCaughtUpToDynamicRoom =
        dynamicRoomUrl != null && dynamicRoomUrl == _sanitizeRoomUrl(newUrl);
    if (parentCaughtUpToDynamicRoom) {
      _dynamicRoomUrl = null;
    } else if (oldUrl != newUrl && newValid) {
      _dynamicRoomUrl = null;
    }

    // If we're already connected, connecting, or initializing — only
    // reconnect when the room URL actually changes (different room).
    // Token changes are harmless: the existing token is still valid for
    // the duration of the Daily session.
    if (_callClient != null || _isInitializing) {
      if (oldUrl != newUrl && newValid && !parentCaughtUpToDynamicRoom) {
        unawaited(_cleanup(leaveCall: true).then((_) => _initializeCall()));
      }
      return;
    }

    // Not yet connected — start connecting if we now have valid join data.
    if (newValid && _effectiveMeetingToken() != null) {
      if (!_isInitializing &&
          _state.connectionState != ConnectionState.connected) {
        _initializeCall();
      }
    }
  }

  /// Update state immutably
  void _updateState(_CallState newState) {
    if (!mounted || _disposed) return;

    final captionsChanged = _captionStateChanged(_state, newState);

    if (newState.connectionState == ConnectionState.disconnected ||
        newState.connectionState == ConnectionState.failed) {
      _stopDurationTimer();
      _resetCallCheckpointNotice();
    }

    setState(() {
      _state = newState;
    });

    if (captionsChanged) {
      _publishCaptionState(newState);
    }
  }

  bool _captionStateChanged(_CallState previous, _CallState next) {
    return !identical(previous.localCaption, next.localCaption) ||
        !identical(previous.remoteCaptions, next.remoteCaptions) ||
        previous.captionIssueMessage != next.captionIssueMessage;
  }

  void _publishCaptionState(_CallState state) {
    _captionOverlayNotifier.value = _CaptionOverlayState.fromCallState(state);
  }

  /// Caption recognition can update several times per second. Keep those
  /// updates scoped to the overlay unless its presence changes chat layout.
  void _updateCaptionState(_CallState newState) {
    if (!mounted || _disposed) return;

    final hadContent = _captionOverlayNotifier.value.hasContent;
    final nextCaptionState = _CaptionOverlayState.fromCallState(newState);
    final layoutChanged = hadContent != nextCaptionState.hasContent;

    if (layoutChanged) {
      setState(() {
        _state = newState;
      });
    } else {
      _state = newState;
    }

    _captionOverlayNotifier.value = nextCaptionState;
  }

  void _startDurationTimer() => _callTimer.start();

  void _stopDurationTimer({bool reset = false}) =>
      _callTimer.stop(reset: reset);

  int _authoritativeCallDurationSeconds([DateTime? now]) =>
      _callTimer.authoritativeSeconds(now);

  void _setCallDurationValue(int totalSeconds) =>
      _callTimer.setElapsedSeconds(totalSeconds);

  void _handleCallTimerUpdate(CallTimerUpdate update) {
    if (_disposed || !mounted) return;
    if (_callDurationNotifier.value != update.elapsedSeconds) {
      _callDurationNotifier.value = update.elapsedSeconds;
    }
    if (update.shouldAutoEnd) {
      unawaited(_requestAutoEndAtSessionLimit());
    }
    for (final minutes in update.checkpointMinutes) {
      _showCallCheckpointNotice(_callCheckpointNotices.firstWhere(
        (notice) => notice.minutes == minutes,
      ));
    }
  }

  bool get _hasSessionLimitCountdown => _callTimer.hasCountdown;

  int _remainingSessionLimitSeconds([DateTime? now]) =>
      _callTimer.remainingSeconds(now);

  DateTime _serverAlignedNow() => _callTimer.sessionLimitNow();

  bool get _currentUserRequestedSessionExtension {
    return session_limit_ui.hasUserRequestedSessionExtension(
      widget.sessionPolicy,
      currentUserUid,
    );
  }

  bool get _otherParticipantRequestedSessionExtension {
    return session_limit_ui.hasOtherParticipantRequestedSessionExtension(
      widget.sessionPolicy,
      currentUserUid,
    );
  }

  bool get _shouldShowSessionExtensionSurface {
    return _hasSessionLimitCountdown &&
        session_limit_ui.shouldShowSessionExtensionSurface(
          sessionPolicy: widget.sessionPolicy,
          expiresAt: widget.sessionExpiresAt,
          currentUserId: currentUserUid,
          now: _serverAlignedNow(),
        );
  }

  bool get _canRequestSessionExtension {
    final sessionId = widget.sessionId?.trim();
    return sessionId != null &&
        sessionId.isNotEmpty &&
        !_sessionExtensionRequestInFlight &&
        session_limit_ui.canCurrentUserRequestSessionExtension(
          sessionPolicy: widget.sessionPolicy,
          expiresAt: widget.sessionExpiresAt,
          currentUserId: currentUserUid,
          now: _serverAlignedNow(),
        );
  }

  int get _sessionExtensionSeconds {
    return session_limit_ui
        .resolveSessionExtensionSeconds(widget.sessionPolicy);
  }

  Future<void> _requestSessionExtension() async {
    final sessionId = widget.sessionId?.trim();
    if (!_canRequestSessionExtension ||
        sessionId == null ||
        sessionId.isEmpty) {
      return;
    }

    setState(() {
      _sessionExtensionRequestInFlight = true;
    });

    try {
      await FirebaseFunctions.instance
          .httpsCallable('requestSessionExtension')
          .call({
        'sessionId': sessionId,
      });
    } on FirebaseFunctionsException catch (error) {
      _showCallCheckpointNotice(
        _CallCheckpointNotice(
          minutes: -2,
          title: 'Продление не выполнено',
          subtitle: error.code == 'failed-precondition'
              ? 'Лимит уже недоступен или звонок уже продлён.'
              : 'Не удалось отправить согласие на продление.',
          accentColor: const Color(0xFFFF6B6B),
        ),
      );
    } catch (_) {
      _showCallCheckpointNotice(
        const _CallCheckpointNotice(
          minutes: -2,
          title: 'Продление не выполнено',
          subtitle: 'Не удалось отправить согласие на продление.',
          accentColor: Color(0xFFFF6B6B),
        ),
      );
    } finally {
      if (mounted && !_disposed) {
        setState(() {
          _sessionExtensionRequestInFlight = false;
        });
      }
    }
  }

  Future<void> _requestAutoEndAtSessionLimit() async {
    final generation = _callChatController.generation;
    final targetExpiresAt = widget.sessionExpiresAt;
    final sessionId = widget.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      _clearSessionLimitAutoEndMarker(targetExpiresAt);
      return;
    }

    try {
      final response =
          await FirebaseFunctions.instance.httpsCallable('endSession').call({
        'sessionId': sessionId,
        'endReason': 'expired',
      });
      final status = response.data is Map
          ? (response.data['status']?.toString() ?? '')
          : '';
      if (_callChatController.generation != generation ||
          widget.sessionId?.trim() != sessionId ||
          widget.sessionExpiresAt != targetExpiresAt) {
        return;
      }
      if (session_limit_ui.shouldRetainAutoEndMarkerForResponseStatus(
        status,
      )) {
        // Hold the marker until Firestore delivers the new expiry/state.
        // Otherwise the local timer can spam repeated expired-end requests
        // during the extension race window.
        return;
      }
      await _persistOwnCallChatMessages(expectedGeneration: generation);
    } catch (_) {
      if (_callChatController.generation == generation &&
          widget.sessionId?.trim() == sessionId &&
          widget.sessionExpiresAt == targetExpiresAt) {
        _clearSessionLimitAutoEndMarker(targetExpiresAt);
      }
      if (kDebugMode) {
        print('Session auto-end: request_failed');
      }
    }
  }

  void _clearSessionLimitAutoEndMarker(DateTime? expiresAt) {
    _callTimer.clearAutoEndRequest(expiresAt);
  }

  void _clearSessionLimitWarningNotice() {
    if (_callCheckpointNoticeNotifier.value?.minutes == -1) {
      _resetCallCheckpointNotice();
    }
  }

  void _showCallCheckpointNotice(_CallCheckpointNotice notice) {
    if (_disposed) {
      return;
    }

    _cancelTrackedTimer(_callCheckpointNoticeTimer);
    _callCheckpointNoticeTimer = null;

    if (_callCheckpointNoticeNotifier.value?.minutes != notice.minutes) {
      _callCheckpointNoticeNotifier.value = notice;
    }

    _callCheckpointNoticeTimer = _createTrackedTimer(
      const Duration(milliseconds: _callCheckpointNoticeDurationMs),
      () {
        if (!_disposed) {
          _callCheckpointNoticeNotifier.value = null;
        }
        _callCheckpointNoticeTimer = null;
      },
    );
  }

  void _resetCallCheckpointNotice({bool clearHistory = false}) {
    _cancelTrackedTimer(_callCheckpointNoticeTimer);
    _callCheckpointNoticeTimer = null;

    if (!_disposed && _callCheckpointNoticeNotifier.value != null) {
      _callCheckpointNoticeNotifier.value = null;
    }
    if (clearHistory) {
      _callTimer.clearCheckpointHistory();
    }
  }

  /// Handle errors uniformly
  void _handleError(String _, Object __) {
    if (kDebugMode) print('Daily widget: initialization_failed');

    _updateState(_state.copyWith(
      error: 'Не удалось подготовить звонок. Повторите попытку.',
    ));
  }

  Future<void> _endSystemCallUi() async {
    if (kIsWeb) return;
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.iOS && platform != TargetPlatform.android) {
      return;
    }
    try {
      await VoIPService().endCurrentCall(sessionId: widget.sessionId?.trim());
    } catch (_) {
      if (kDebugMode) print('System call UI: end_failed');
    }
  }

  Future<void> _markRoomJoined() async {
    final client = _callClient;
    if (client == null || !_dailySession.isCurrent(client)) return;
    final sessionId = widget.sessionId?.trim();
    if (_roomJoinMarked || sessionId == null || sessionId.isEmpty) {
      return;
    }

    _roomJoinMarked = true;
    final requestStartedAt = DateTime.now();
    final requestStopwatch = Stopwatch()..start();

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('markSessionConnected')
          .call(<String, dynamic>{
        'sessionId': sessionId,
      });
      requestStopwatch.stop();
      final responseData = result.data;
      final serverNowMillis =
          responseData is Map ? responseData['serverNowMillis'] : null;
      final serverClockOffset = session_limit_ui.resolveServerClockOffset(
        serverNowMillis: serverNowMillis,
        requestStartedAt: requestStartedAt,
        roundTripDuration: requestStopwatch.elapsed,
      );
      if (serverClockOffset != null &&
          mounted &&
          !_disposed &&
          _dailySession.isCurrent(client) &&
          widget.sessionId?.trim() == sessionId) {
        _callTimer.serverClockOffset = serverClockOffset;
      }
    } catch (_) {
      requestStopwatch.stop();
      if (widget.sessionId?.trim() == sessionId) {
        _roomJoinMarked = false;
      }
      if (kDebugMode) print('Daily session: mark_joined_failed');
    }
  }

  Future<void> _markSystemCallConnected() async {
    final client = _callClient;
    if (client == null || !_dailySession.isCurrent(client)) return;
    if (_systemCallMarkedConnected) return;
    if (kIsWeb) return;
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.iOS && platform != TargetPlatform.android) {
      return;
    }
    try {
      await VoIPService()
          .markCallConnected(sessionId: widget.sessionId?.trim());
      if (_dailySession.isCurrent(client)) _systemCallMarkedConnected = true;
    } catch (_) {
      if (kDebugMode) print('System call UI: mark_connected_failed');
    }
  }

  /// Track timer for cleanup
  Timer _createTrackedTimer(Duration duration, VoidCallback callback) {
    late final Timer timer;
    timer = Timer(duration, () {
      _activeTimers.remove(timer);
      callback();
    });
    _activeTimers.add(timer);
    return timer;
  }

  void _cancelTrackedTimer(Timer? timer) {
    if (timer == null) return;
    timer.cancel();
    _activeTimers.remove(timer);
  }

  Future<void> _setVideoTrack(
    VideoViewController? controller,
    MediaStreamTrack? track, {
    required String debugContext,
  }) async {
    if (controller == null) return;
    try {
      await controller.setTrack(track);
    } catch (_) {
      if (kDebugMode) print('$debugContext: failed');
    }
  }

  Future<void> _disposeVideoController(
    VideoViewController? controller, {
    required String debugContext,
    Duration delay = Duration.zero,
  }) async {
    if (controller == null) return;
    await _setVideoTrack(
      controller,
      null,
      debugContext: '$debugContext (clear track)',
    );
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    try {
      controller.dispose();
    } catch (_) {
      if (kDebugMode) print('$debugContext: failed');
    }
  }

  /// COMPLETE BUILD METHOD REPLACEMENT - This should fix the error
  @override
  Widget build(BuildContext context) {
    if (shouldRenderDailyTerminalError(
      hasTerminalError: _state.hasTerminalError,
    )) {
      return _buildTerminalErrorScreen();
    }

    final roomUrlValid = _isValidRoomUrl(widget.roomUrl);
    if (shouldRenderDailyConnectingScreen(
      roomUrlValid: roomUrlValid,
      hasTerminalError: _state.hasTerminalError,
    )) {
      return _buildConnectingScreen();
    }

    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mediaQuery = MediaQuery.of(context);
          final viewportWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final isWideChat = viewportWidth >= _chatWideBreakpoint;
          final isChatKeyboardActive = _state.isChatOpen &&
              (_chatFocusNode.hasFocus ||
                  MediaQuery.viewInsetsOf(context).bottom > 0);
          final showRemoteVideo = _hasRemoteVideoReady();
          final hasCaptionOverlayContent = _hasCaptionOverlayContent();
          final showPip = showRemoteVideo &&
              _localVideoController != null &&
              _state.cameraEnabled &&
              !(_state.isChatOpen && isWideChat);
          final captionOverlayTopOffset = _captionOverlayTopOffset(
            mediaQuery: mediaQuery,
            isWideChat: isWideChat,
            isChatKeyboardActive: isChatKeyboardActive,
          );
          final captionOverlayBottomOffset = _captionOverlayBottomOffset(
            constraints: constraints,
            isWideChat: isWideChat,
            isChatKeyboardActive: isChatKeyboardActive,
          );
          final captionOverlayRightInset = _captionOverlayRightInset(
            isWideChat: isWideChat,
          );
          final chatPanelBottomOffset = _chatPanelBottomOffset(
            constraints: constraints,
            mediaQuery: mediaQuery,
            isChatKeyboardActive: isChatKeyboardActive,
          );
          final captionOverlayMaxHeight = _captionOverlayMaxHeight(
            constraints: constraints,
            mediaQuery: mediaQuery,
            isWideChat: isWideChat,
            isChatKeyboardActive: isChatKeyboardActive,
            chatPanelBottomOffset: chatPanelBottomOffset,
            compact: captionOverlayTopOffset != null,
          );
          final primaryVideoModeKey =
              ValueKey(showRemoteVideo ? 'remote-surface' : 'local-surface');

          return Stack(
            children: [
              // Main video/placeholder layer
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: KeyedSubtree(
                      key: primaryVideoModeKey,
                      child: _buildPrimaryVideo(
                        showRemoteParticipant: showRemoteVideo,
                      ),
                    ),
                  ),
                ),
              ),

              // Call duration timer (top-left)
              if (session_limit_ui.shouldRunCallDurationTimer(
                sessionStatus: widget.sessionStatus,
                isDailyConnected:
                    _state.connectionState == ConnectionState.connected,
                hasRemoteParticipant: _hasRemoteParticipantPresent(),
                hasServerConnectedAt: widget.sessionConnectedAt != null,
              ))
                Positioned(
                  top: 55,
                  left: 20,
                  child: _buildCallDurationBadge(),
                ),

              if (_state.connectionState == ConnectionState.connected &&
                  (widget.isStudent == true || _hasSessionLimitCountdown))
                Positioned(
                  top: 48,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: _buildCallCheckpointNoticeOverlay(
                      viewportWidth: viewportWidth,
                    ),
                  ),
                ),

              if (_state.connectionState == ConnectionState.connected &&
                  _hasSessionLimitCountdown)
                Positioned(
                  top: 112,
                  left: 16,
                  right: showPip ? 130 : 16,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _callDurationNotifier,
                    builder: (context, _, __) {
                      if (!_shouldShowSessionExtensionSurface) {
                        return const SizedBox.shrink();
                      }
                      return _buildSessionExtensionOverlay(
                        viewportWidth: viewportWidth,
                      );
                    },
                  ),
                ),

              // Picture-in-picture (only after remote video is ready)
              if (showPip)
                Positioned(
                  top: 55,
                  right: 20,
                  child: SizedBox(
                    width: 100,
                    height: 140,
                    child: RepaintBoundary(child: _buildPictureInPicture()),
                  ),
                ),

              // Captions overlay
              if (_state.connectionState == ConnectionState.connected)
                Positioned(
                  top: captionOverlayTopOffset,
                  bottom: captionOverlayTopOffset == null
                      ? captionOverlayBottomOffset
                      : null,
                  left: 16,
                  right: captionOverlayRightInset,
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<_CaptionOverlayState>(
                      valueListenable: _captionOverlayNotifier,
                      builder: (context, captionState, _) {
                        return _buildCaptionsOverlay(
                          captionState: captionState,
                          compact: captionOverlayTopOffset != null,
                          maxHeight: captionOverlayMaxHeight,
                        );
                      },
                    ),
                  ),
                ),

              // Chat panel
              if (_state.connectionState == ConnectionState.connected &&
                  _state.isChatOpen)
                _buildAdaptiveChatPanel(
                  constraints: constraints,
                  isWideChat: isWideChat,
                  isChatKeyboardActive: isChatKeyboardActive,
                  reserveCaptionLane: hasCaptionOverlayContent,
                  bottomOffset: chatPanelBottomOffset,
                  captionOverlayMaxHeight: captionOverlayMaxHeight,
                ),

              // Status indicators
              if (_state.connectionState == ConnectionState.reconnecting)
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: _buildReconnectingIndicator(),
                ),

              // Controls
              if (!isChatKeyboardActive)
                Positioned(
                  bottom: 35,
                  left: 0,
                  right: 0,
                  child: RepaintBoundary(child: _buildControls()),
                ),

              // Error display
              if (_state.error != null &&
                  _state.retryCount >= _maxRetryAttempts)
                Positioned.fill(
                  child: _buildErrorDisplay(allowRetry: true),
                ),

              // Status overlay (searching/connecting/awaiting remote)
              if (_statusMessage() != null)
                Positioned.fill(
                  child: IgnorePointer(child: _buildConnectingOverlay()),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Build unified connecting screen
  Widget _buildConnectingScreen() {
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      child: Stack(
        children: [
          Positioned.fill(child: _buildPrimaryVideo()),
          Positioned.fill(child: _buildConnectingOverlay()),
        ],
      ),
    );
  }

  Widget _buildTerminalErrorScreen() {
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      child: ColoredBox(
        color: Colors.black,
        child: _buildErrorDisplay(allowRetry: false),
      ),
    );
  }

  Widget _buildNeutralBackground() {
    return Container(color: Colors.black);
  }

  bool _hasRemoteVideoReady() {
    for (final ready in _remoteTrackReady.values) {
      if (ready == true) return true;
    }
    return false;
  }

  String? _statusMessage() {
    if (_state.hasTerminalError) return null;
    if (_state.remoteControllers.isNotEmpty || _hasRemoteParticipantPresent()) {
      return null;
    }

    // Remote participant just left — call is ending, not "waiting".
    if (_remoteLeftTimer != null) {
      return 'Звонок завершается...';
    }

    final status = widget.sessionStatus?.trim().toLowerCase();
    final isStudent = widget.isStudent == true;

    if (status == 'ended' || status == 'cancelled' || status == 'expired') {
      return 'Звонок завершается...';
    }

    if (status == 'searching' && isStudent) {
      return 'Ищем собеседника...';
    }

    if (_state.connectionState != ConnectionState.connected) {
      return 'Соединяемся...';
    }

    return 'Ожидаем подключение собеседника...';
  }

  Widget _buildPrimaryVideo({bool? showRemoteParticipant}) {
    if (showRemoteParticipant ?? _state.remoteControllers.isNotEmpty) {
      return _buildRemoteVideo();
    }
    return _buildLocalFullScreen();
  }

  Widget _buildCallDurationBadge() {
    return ValueListenableBuilder<int>(
      valueListenable: _callDurationNotifier,
      builder: (context, totalSeconds, _) {
        final hasCountdown = _hasSessionLimitCountdown;
        final remainingSeconds = _remainingSessionLimitSeconds();
        final displaySeconds = hasCountdown ? remainingSeconds : totalSeconds;
        return CallDurationBadge(
          displaySeconds: displaySeconds,
          hasCountdown: hasCountdown,
          isWarning: hasCountdown &&
              remainingSeconds > 0 &&
              remainingSeconds <= _sessionLimitWarningLeadSeconds,
        );
      },
    );
  }

  Widget _buildCallCheckpointNoticeOverlay({
    required double viewportWidth,
  }) {
    final maxWidth = math.min(360.0, math.max(0.0, viewportWidth - 32));

    return ValueListenableBuilder<_CallCheckpointNotice?>(
      valueListenable: _callCheckpointNoticeNotifier,
      builder: (context, notice, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(0, -0.12),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: offsetAnimation,
                child: child,
              ),
            );
          },
          child: notice == null
              ? const SizedBox.shrink(key: ValueKey('checkpoint-hidden'))
              : Center(
                  key: ValueKey('checkpoint-${notice.minutes}'),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: _buildCallCheckpointNoticeCard(notice),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildCallCheckpointNoticeCard(_CallCheckpointNotice notice) {
    final accentColor = notice.accentColor;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: ExpatlioDesign.space16,
            vertical: ExpatlioDesign.space12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusExtraLarge),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.46),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.18),
                borderRadius:
                    BorderRadius.circular(ExpatlioDesign.radiusMedium),
              ),
              child: Icon(
                Icons.schedule_rounded,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: ExpatlioDesign.space12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: ExpatlioDesign.space4),
                  Text(
                    notice.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionExtensionOverlay({
    required double viewportWidth,
  }) {
    final maxWidth = math.min(360.0, math.max(0.0, viewportWidth - 32));

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: _buildSessionExtensionCard(),
      ),
    );
  }

  Widget _buildSessionExtensionCard() {
    final extensionMinutes = (_sessionExtensionSeconds / 60).round();
    final hasOwnRequest = _currentUserRequestedSessionExtension;
    final hasOtherRequest = _otherParticipantRequestedSessionExtension;
    final accentColor = hasOtherRequest && !hasOwnRequest
        ? const Color(0xFF3DDC97)
        : const Color(0xFFFFB020);
    final title = hasOtherRequest && !hasOwnRequest
        ? 'Собеседник хочет продлить'
        : hasOwnRequest
            ? 'Ждём согласия собеседника'
            : 'Продлить разговор?';
    final subtitle = hasOtherRequest && !hasOwnRequest
        ? 'Подтвердите +$extensionMinutes минут, чтобы лимит стал 10 минут.'
        : hasOwnRequest
            ? 'Ваше согласие сохранено. Звонок продлится, когда второй участник согласится.'
            : 'Можно добавить +$extensionMinutes минут, если оба участника согласятся до конца лимита.';
    final buttonLabel = hasOtherRequest && !hasOwnRequest
        ? 'Подтвердить +$extensionMinutes мин'
        : 'Продлить на +$extensionMinutes мин';

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: ExpatlioDesign.space16,
            vertical: ExpatlioDesign.space12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusExtraLarge),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.42),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.18),
                    borderRadius:
                        BorderRadius.circular(ExpatlioDesign.radiusMedium),
                  ),
                  child: Icon(
                    hasOwnRequest && !hasOtherRequest
                        ? Icons.hourglass_top_rounded
                        : Icons.timer_outlined,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: ExpatlioDesign.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: ExpatlioDesign.space4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!hasOwnRequest) ...[
              const SizedBox(height: ExpatlioDesign.space12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sessionExtensionRequestInFlight
                      ? null
                      : _requestSessionExtension,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                        accentColor.withValues(alpha: 0.55),
                    disabledForegroundColor:
                        Colors.black.withValues(alpha: 0.7),
                    padding: const EdgeInsets.symmetric(
                        vertical: ExpatlioDesign.space12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(ExpatlioDesign.radiusMedium),
                    ),
                    elevation: 0,
                  ),
                  child: _sessionExtensionRequestInFlight
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : Text(
                          buttonLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.0,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocalFullScreen() {
    if (_localVideoController == null) {
      return _buildNeutralBackground();
    }

    if (!_state.cameraEnabled) {
      return _buildPlaceholder('Камера выключена');
    }

    return _buildMirroredLocalVideoView();
  }

  Widget _buildConnectingOverlay() {
    final message = _statusMessage();
    if (message == null) {
      return const SizedBox.shrink();
    }

    final showSpinner = _state.connectionState != ConnectionState.connected;
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner)
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            if (showSpinner) const SizedBox(height: ExpatlioDesign.space24),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 17.0),
            ),
          ],
        ),
      ),
    );
  }

  /// Build local video view
  Widget _buildLocalVideo() {
    try {
      if (_localVideoController == null) {
        return _buildPlaceholder('Инициализация камеры...');
      }

      if (!_state.cameraEnabled) {
        return _buildPlaceholder('Камера выключена');
      }

      return _buildMirroredLocalVideoView(
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusExtraLarge),
      );
    } catch (_) {
      if (kDebugMode) print('Daily video: local_build_failed');
      return _buildPlaceholder('Видео недоступно');
    }
  }

  Widget _buildMirroredLocalVideoView({BorderRadius? borderRadius}) {
    Widget child = Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
      child: VideoView(
        controller: _localVideoController!,
        fit: VideoViewFit.cover,
      ),
    );

    if (borderRadius != null) {
      child = ClipRRect(
        borderRadius: borderRadius,
        child: child,
      );
    }

    return child;
  }

  /// Build remote video view
  Widget _buildRemoteVideo() {
    try {
      if (_state.remoteControllers.isEmpty) {
        return _buildLocalFullScreen();
      }

      final participantId = _state.remoteControllers.keys.firstWhere(
        (id) => _remoteTrackReady[id] == true,
        orElse: () => _state.remoteControllers.keys.first,
      );
      final controller = _state.remoteControllers[participantId];

      if (controller == null) {
        return _buildPlaceholder('Подключаем видео собеседника...');
      }

      final participant = _callClient?.participants.remote[participantId];

      if (participant == null) {
        return _buildPlaceholder('Подключаем видео собеседника...');
      }

      final hasVideo = participant.media?.camera.state != MediaState.off ||
          participant.media?.screenVideo.state != MediaState.off;
      final isTrackReady = _remoteTrackReady[participantId] ?? false;
      final joinTime = _remoteJoinTimes[participantId];
      final withinGrace = joinTime == null
          ? true
          : DateTime.now().difference(joinTime).inMilliseconds <
              _remoteVideoGraceMs;

      if (isTrackReady) {
        return VideoView(
          controller: controller,
          fit: VideoViewFit.cover,
        );
      }

      if (!hasVideo) {
        return withinGrace
            ? _buildPlaceholder('Подключаем видео собеседника...')
            : _buildPlaceholder('Камера участника выключена');
      }

      return _buildPlaceholder('Подключаем видео собеседника...');
    } catch (_) {
      if (kDebugMode) print('Daily video: remote_build_failed');
      return _buildPlaceholder('Видео недоступно');
    }
  }

  /// Build picture-in-picture view
  Widget _buildPictureInPicture() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 1),
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusExtraLarge),
      ),
      clipBehavior: Clip.hardEdge,
      child: _buildLocalVideo(),
    );
  }

  /// Build placeholder widget
  Widget _buildPlaceholder(String message) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
            const SizedBox(height: ExpatlioDesign.space12),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 15.0),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  bool _hasCaptionOverlayContent() {
    return _state.captionIssueMessage != null ||
        _state.localCaption != null ||
        _state.remoteCaptions.isNotEmpty;
  }

  /// Build captions overlay with speaker separation
  Widget _buildCaptionsOverlay({
    required _CaptionOverlayState captionState,
    bool compact = false,
    double? maxHeight,
  }) {
    final remoteEntry = _latestRemoteCaptionEntry(captionState.remoteCaptions);
    final localCaption = captionState.localCaption;
    final captionIssueMessage = captionState.issueMessage;
    if (remoteEntry == null &&
        localCaption == null &&
        captionIssueMessage == null) {
      return const SizedBox.shrink();
    }

    final overlayChildren = <Widget>[];
    if (captionIssueMessage != null) {
      overlayChildren.add(
        _buildCaptionIssueCard(message: captionIssueMessage),
      );
    }
    if (remoteEntry != null) {
      if (overlayChildren.isNotEmpty) {
        overlayChildren.add(const SizedBox(height: ExpatlioDesign.space12));
      }
      overlayChildren.add(
        _buildCaptionCard(
          label: _participantDisplayName(remoteEntry.key),
          caption: remoteEntry.value,
          isLocal: false,
        ),
      );
    }
    if (localCaption != null) {
      if (overlayChildren.isNotEmpty) {
        overlayChildren.add(const SizedBox(height: ExpatlioDesign.space12));
      }
      overlayChildren.add(
        _buildCaptionCard(
          label: FFLocalizations.of(context).getVariableText(
            ruText: 'Вы',
            enText: 'You',
          ),
          caption: localCaption,
          isLocal: true,
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight ??
            (compact ? _captionCompactMaxHeight : _captionRegularMaxHeight),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: overlayChildren,
        ),
      ),
    );
  }

  Widget _buildCaptionIssueCard({
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: ExpatlioDesign.space16, vertical: ExpatlioDesign.space12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusExtraLarge),
        border: Border.all(
          color: const Color(0xFFFFB020).withValues(alpha: 0.34),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB020).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
            ),
            child: const Icon(
              Icons.closed_caption_off_outlined,
              color: Color(0xFFFFB020),
              size: 19,
            ),
          ),
          const SizedBox(width: ExpatlioDesign.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Субтитры временно недоступны',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: ExpatlioDesign.space4),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  MapEntry<ParticipantId, _ActiveCaption>? _latestRemoteCaptionEntry(
    Map<ParticipantId, _ActiveCaption> remoteCaptions,
  ) {
    if (remoteCaptions.isEmpty) {
      return null;
    }

    final sortedEntries = remoteCaptions.entries.toList()
      ..sort(
        (left, right) =>
            right.value.lastUpdateAt.compareTo(left.value.lastUpdateAt),
      );
    return sortedEntries.first;
  }

  Widget _buildCaptionCard({
    required String label,
    required _ActiveCaption caption,
    required bool isLocal,
  }) {
    final labelColor = isLocal
        ? Colors.white.withValues(alpha: 0.94)
        : const Color(0xFFB8A4FF).withValues(alpha: 0.96);
    final labelTextColor = isLocal ? Colors.black : Colors.white;
    final panelColor = isLocal
        ? Colors.black.withValues(alpha: 0.72)
        : const Color(0xFF24143E).withValues(alpha: 0.78);
    final panelBorderColor = isLocal
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFDACBFF).withValues(alpha: 0.26);
    final displayText = _truncateCaptionForOverlay(caption.text);
    final fullText = _normalizeCaptionText(caption.text);

    final panel = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: ExpatlioDesign.space16, vertical: ExpatlioDesign.space12),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusExtraLarge),
        border: Border.all(color: panelBorderColor, width: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: _buildCaptionPanelText(
        displayText: displayText,
        fullText: fullText,
        isLocal: isLocal,
      ),
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: _captionFadeDurationMs),
      curve: Curves.easeOutCubic,
      opacity: caption.isFadingOut ? 0.0 : caption.phase.opacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: ExpatlioDesign.space12,
                vertical: ExpatlioDesign.space8),
            decoration: BoxDecoration(
              color: labelColor,
              borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.24),
                width: 0.5,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: labelTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: ExpatlioDesign.space8),
          panel,
        ],
      ),
    );
  }

  Widget _buildCaptionPanelText({
    required String displayText,
    required String fullText,
    required bool isLocal,
  }) {
    return InteractiveCaptionText(
      text: displayText,
      tone: isLocal
          ? InteractiveCaptionTextTone.overlayLocal
          : InteractiveCaptionTextTone.overlayRemote,
      mode: InteractiveCaptionTextMode.tokenSplit,
      onWordTap: widget.actionCallback == null
          ? null
          : (word) {
              return widget.actionCallback!.call(
                word,
                fullText,
                fullText,
              );
            },
      maxLines: 2,
      overflow: TextOverflow.fade,
      softWrap: true,
    );
  }

  String _truncateCaptionForOverlay(String rawText) {
    final normalizedText = _normalizeCaptionText(rawText);
    if (normalizedText.length <= _captionMaxVisibleCharacters) {
      return normalizedText;
    }

    final words = normalizedText.split(' ');
    while (words.length > 1 &&
        words.join(' ').length > _captionMaxVisibleCharacters) {
      words.removeAt(0);
    }

    final clippedText = words.join(' ').trim();
    if (clippedText.isEmpty || clippedText == normalizedText) {
      return normalizedText.substring(
        math.max(0, normalizedText.length - _captionMaxVisibleCharacters),
      );
    }
    return '…$clippedText';
  }

  /// Build controls overlay
  Widget _buildControls() {
    return CallControlsBar(
      isVisible: _state.connectionState == ConnectionState.connected,
      cameraEnabled: _state.cameraEnabled,
      microphoneEnabled: _state.microphoneEnabled,
      isChatOpen: _state.isChatOpen,
      unreadChatCount: _state.unreadChatCount,
      onCameraPressed: () =>
          _updateInputSettings(camera: !_state.cameraEnabled),
      onMicrophonePressed: () =>
          _updateInputSettings(microphone: !_state.microphoneEnabled),
      onChatPressed: _toggleChatOpen,
      onTranslationPressed: widget.translationCallback == null
          ? null
          : () => unawaited(widget.translationCallback!.call()),
      onEndCallPressed: () => _endCall(endReason: 'user_ended'),
    );
  }

  double _captionOverlayBottomOffset({
    required BoxConstraints constraints,
    required bool isWideChat,
    required bool isChatKeyboardActive,
  }) {
    if (!_state.isChatOpen || isWideChat) {
      return 160.0;
    }

    if (isChatKeyboardActive) {
      return 24.0;
    }

    final mobilePanelHeight =
        (constraints.maxHeight * 0.44).clamp(260.0, 360.0).toDouble();
    return 110.0 + mobilePanelHeight + ExpatlioDesign.space16;
  }

  double? _captionOverlayTopOffset({
    required MediaQueryData mediaQuery,
    required bool isWideChat,
    required bool isChatKeyboardActive,
  }) {
    if (!_state.isChatOpen || isWideChat || !isChatKeyboardActive) {
      return null;
    }
    return math.max(16.0, mediaQuery.padding.top + ExpatlioDesign.space12);
  }

  double _captionOverlayRightInset({
    required bool isWideChat,
  }) {
    if (_state.isChatOpen && isWideChat) {
      return 392.0;
    }
    return 16.0;
  }

  double _captionOverlayMaxHeight({
    required BoxConstraints constraints,
    required MediaQueryData mediaQuery,
    required bool isWideChat,
    required bool isChatKeyboardActive,
    required double chatPanelBottomOffset,
    required bool compact,
  }) {
    final defaultMaxHeight =
        compact ? _captionCompactMaxHeight : _captionRegularMaxHeight;
    if (!_state.isChatOpen || isWideChat || !isChatKeyboardActive) {
      return defaultMaxHeight;
    }

    final captionTop =
        math.max(16.0, mediaQuery.padding.top + ExpatlioDesign.space12);
    final availableCaptionHeight = constraints.maxHeight -
        captionTop -
        chatPanelBottomOffset -
        _captionKeyboardMinChatHeight -
        ExpatlioDesign.space12;
    return math
        .max(
          56.0,
          math.min(defaultMaxHeight, availableCaptionHeight),
        )
        .toDouble();
  }

  double _captionKeyboardChatPanelTopOffset({
    required BoxConstraints constraints,
    required MediaQueryData mediaQuery,
    required double bottomOffset,
    required double captionOverlayMaxHeight,
  }) {
    final captionTop =
        math.max(16.0, mediaQuery.padding.top + ExpatlioDesign.space12);
    final captionSafeTop =
        captionTop + captionOverlayMaxHeight + ExpatlioDesign.space12;
    final preferredTop = math.max(
      captionSafeTop,
      mediaQuery.padding.top + _captionKeyboardLaneHeight,
    );
    final maxTop =
        constraints.maxHeight - bottomOffset - _captionKeyboardMinChatHeight;
    if (maxTop < captionSafeTop) {
      return captionSafeTop;
    }
    return math.min(preferredTop, maxTop).toDouble();
  }

  double _chatPanelBottomOffset({
    required BoxConstraints constraints,
    required MediaQueryData mediaQuery,
    required bool isChatKeyboardActive,
  }) {
    final viewInsetsBottom = mediaQuery.viewInsets.bottom;
    final keyboardAlreadyReducedHeight = viewInsetsBottom > 0 &&
        constraints.maxHeight <=
            mediaQuery.size.height - (viewInsetsBottom * 0.5);
    if (isChatKeyboardActive) {
      return keyboardAlreadyReducedHeight ? 16.0 : viewInsetsBottom + 16.0;
    }
    return 110.0;
  }

  Widget _buildAdaptiveChatPanel({
    required BoxConstraints constraints,
    required bool isWideChat,
    required bool isChatKeyboardActive,
    required bool reserveCaptionLane,
    required double bottomOffset,
    required double captionOverlayMaxHeight,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final mobileTopOffset = isChatKeyboardActive
        ? (reserveCaptionLane && !isWideChat
            ? _captionKeyboardChatPanelTopOffset(
                constraints: constraints,
                mediaQuery: mediaQuery,
                bottomOffset: bottomOffset,
                captionOverlayMaxHeight: captionOverlayMaxHeight,
              )
            : math.max(16.0, mediaQuery.padding.top + 12.0))
        : null;
    final mobilePanelHeight =
        (constraints.maxHeight * 0.44).clamp(260.0, 360.0).toDouble();

    return Positioned(
      top: isWideChat ? 20 : mobileTopOffset,
      right: 16,
      left: isWideChat ? null : 16,
      width: isWideChat ? 360 : null,
      height: isWideChat || isChatKeyboardActive ? null : mobilePanelHeight,
      bottom: bottomOffset,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: RepaintBoundary(
          child: _buildChatPanel(isWideChat: isWideChat),
        ),
      ),
    );
  }

  Widget _buildChatPanel({
    required bool isWideChat,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101216).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(
            isWideChat
                ? ExpatlioDesign.radiusExtraLarge
                : ExpatlioDesign.radiusSheet,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildChatHeader(),
            Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            Expanded(
              child: _state.chatMessages.isEmpty
                  ? _buildEmptyChatState()
                  : _buildChatMessages(),
            ),
            _buildChatComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ExpatlioDesign.space16,
          ExpatlioDesign.space16,
          ExpatlioDesign.space12,
          ExpatlioDesign.space12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: ExpatlioDesign.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Чат',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _hasRemoteParticipantPresent()
                      ? 'Сообщения видны только во время звонка'
                      : 'Сообщения можно отправлять после подключения собеседника',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            container: true,
            button: true,
            enabled: true,
            label: 'Закрыть чат',
            hint: 'Скрывает панель чата',
            onTap: () => _setChatOpen(false),
            child: Tooltip(
              message: 'Закрыть чат',
              excludeFromSemantics: true,
              child: ExcludeSemantics(
                child: IconButton(
                  onPressed: () => _setChatOpen(false),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: ExpatlioDesign.space12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(
                0,
                constraints.maxHeight - (ExpatlioDesign.space12 * 2),
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ExpatlioDesign.space24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(
                            ExpatlioDesign.radiusExtraLarge),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white70,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space16),
                    const Text(
                      'Сообщения появятся здесь',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space8),
                    Text(
                      _hasRemoteParticipantPresent()
                          ? 'Напишите первое сообщение собеседнику.'
                          : 'Дождитесь подключения второго участника, чтобы начать чат.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatMessages() {
    return Scrollbar(
      controller: _chatScrollController,
      thumbVisibility: _state.chatMessages.length > 4,
      child: ListView.separated(
        controller: _chatScrollController,
        padding: const EdgeInsets.fromLTRB(
            ExpatlioDesign.space16,
            ExpatlioDesign.space16,
            ExpatlioDesign.space16,
            ExpatlioDesign.space12),
        itemCount: _state.chatMessages.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: ExpatlioDesign.space12),
        itemBuilder: (context, index) {
          final message = _state.chatMessages[index];
          return _buildChatMessageBubble(message);
        },
      ),
    );
  }

  Widget _buildChatMessageBubble(_ChatMessage message) {
    final bubbleColor = message.isLocal
        ? chatMessageBubbleColor(isCurrentUser: true)
        : Colors.white.withValues(alpha: 0.10);
    final bubbleAlignment =
        message.isLocal ? Alignment.centerRight : Alignment.centerLeft;
    final labelColor = Colors.white.withValues(alpha: 0.66);
    final textColor = message.isLocal ? chatMessageTextColor() : Colors.white;

    return Align(
      alignment: bubbleAlignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment: message.isLocal
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: ExpatlioDesign.space4),
              child: Text(
                message.isLocal ? 'Вы' : message.senderName,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ExpatlioDesign.space16,
                    vertical: ExpatlioDesign.space12),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15.0,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(height: ExpatlioDesign.space4),
            Text(
              _formatChatTimestamp(message.sentAt),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.46),
                fontSize: 11.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatComposer() {
    final hasRemoteParticipant = _hasRemoteParticipantPresent();
    final composerEnabled =
        _state.connectionState == ConnectionState.connected &&
            _callClient != null &&
            hasRemoteParticipant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hasRemoteParticipant)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ExpatlioDesign.space16,
                ExpatlioDesign.space0,
                ExpatlioDesign.space16,
                ExpatlioDesign.space12),
            child: Text(
              'Собеседник еще не в звонке. Сообщение можно отправить после подключения.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 11,
              ),
            ),
          ),
        ChatComposer(
          controller: _chatTextController,
          focusNode: _chatFocusNode,
          hintText: hasRemoteParticipant
              ? 'Написать сообщение'
              : 'Ожидаем собеседника...',
          sendButtonSemanticLabel: composerEnabled
              ? 'Отправить сообщение'
              : 'Отправка сообщения недоступна',
          enabled: composerEnabled,
          isSending: _callChatController.isSending,
          onSendPressed: () => unawaited(_sendChatMessage()),
        ),
      ],
    );
  }

  /// Build reconnecting indicator
  Widget _buildReconnectingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: ExpatlioDesign.space20),
      padding: const EdgeInsets.all(ExpatlioDesign.space12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: ExpatlioDesign.space8),
          Text(
            'Переподключение... (${_state.retryCount}/$_maxRetryAttempts)',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Build error display
  Widget _buildErrorDisplay({required bool allowRetry}) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(ExpatlioDesign.space20),
        margin: const EdgeInsets.all(ExpatlioDesign.space20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.white, size: 48),
            const SizedBox(height: ExpatlioDesign.space16),
            const Text(
              'Не удалось подключиться',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: ExpatlioDesign.space8),
            Container(
              constraints: const BoxConstraints(maxHeight: 100),
              child: SingleChildScrollView(
                child: Text(
                  _state.error ?? 'Неизвестная ошибка',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (allowRetry) ...[
              const SizedBox(height: ExpatlioDesign.space16),
              ElevatedButton(
                onPressed: () {
                  _updateState(_state.copyWith(retryCount: 0));
                  _performReconnection();
                },
                child: const Text('Повторить попытку'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Loading indicator removed in favor of unified connecting overlay

  /// End call and cleanup - cleanup BEFORE navigating away
  Future<void> _endCall({String? endReason}) async {
    try {
      _userRequestedEnd = true;
      unawaited(_endSystemCallUi());

      final finalizeSession =
          _endSessionAndPersistCallChat(endReason ?? 'user_ended');

      // 1. Leave the Daily room first (clean disconnect)
      await _cleanup(leaveCall: true);

      // 2. Finish the server-owned session state and persist local chat.
      await finalizeSession;

      // 3. Then invoke the callback which navigates away.
      await widget.endCallCallback?.call(endReason);
    } catch (_) {
      if (kDebugMode) print('Call end: callback_failed');
      if (mounted && !_disposed) {
        context.safePop();
      }
    }
  }

  void _onDailyClosing() {
    // An SDK failure can initiate close before its error reaches the widget.
    // Re-entering the wrapper joins the already-published native close future.
    if (_cleanupFuture == null) {
      unawaited(_cleanup(
        leaveCall: false,
        preserveMeetingToken: true,
        preserveTokenRefreshAttempts: true,
        preserveChatState: true,
      ));
    }
  }

  /// One widget cleanup root wraps one native cleanup root. A concurrent end
  /// upgrades leave intent, and a full reset wins over reconnect preservation.
  Future<void> _cleanup({
    bool leaveCall = true,
    bool preserveMeetingToken = false,
    bool preserveTokenRefreshAttempts = false,
    bool preserveChatState = false,
  }) {
    final active = _cleanupFuture;
    if (active != null) {
      _preserveCleanupMeetingToken &= preserveMeetingToken;
      _preserveCleanupTokenAttempts &= preserveTokenRefreshAttempts;
      _preserveCleanupChat &= preserveChatState;
      _dailySession.close(leaveCall: leaveCall);
      return active;
    }
    final completer = Completer<void>();
    _cleanupFuture = completer.future;
    _preserveCleanupMeetingToken = preserveMeetingToken;
    _preserveCleanupTokenAttempts = preserveTokenRefreshAttempts;
    _preserveCleanupChat = preserveChatState;
    final chatMessages = _state.chatMessages;
    final unread = _state.unreadChatCount;
    final chatOpen = _state.isChatOpen;

    _lifecycleTransitions.invalidate();
    _callTimer.suspend();
    if (!_disposed) {
      _chatFocusNode.unfocus();
      if (!preserveChatState) _chatTextController.clear();
    }
    for (final timer in List<Timer>.from(_activeTimers)) {
      _cancelTrackedTimer(timer);
    }
    _cancelTrackedTimer(_remoteLeftTimer);
    _remoteLeftTimer = null;
    _remoteLeftNotified = false;

    final nativeClose = _dailySession.close(leaveCall: leaveCall);
    unawaited(() async {
      try {
        await nativeClose;
        _remoteJoinTimes.clear();
        _remoteTrackReady.clear();
        _remoteCaptionClearGenerations.clear();
        _remoteLegacyCaptionCounters.clear();
        _remoteParticipantUiSignatures.clear();
        _prioritySubscribedParticipants.clear();
        _activeRemoteProfileConfigured = false;
        _systemCallMarkedConnected = false;
        _invalidateLocalCaptionClear();
        if (!_preserveCleanupMeetingToken) {
          _dynamicMeetingToken = null;
          _dynamicRoomUrl = null;
        }
        if (!_preserveCleanupTokenAttempts) _tokenRefreshAttempts = 0;
        _stopDurationTimer(reset: true);
        _resetCallCheckpointNotice();
        if (mounted && !_disposed) {
          final terminalError = terminalErrorAfterDailyCleanup(
            hasTerminalError: _state.hasTerminalError,
            error: _state.error,
          );
          _updateState(_CallState(
            connectionState: terminalError.hasTerminalError
                ? ConnectionState.failed
                : ConnectionState.disconnected,
            hasTerminalError: terminalError.hasTerminalError,
            error: terminalError.error,
            isChatOpen: _preserveCleanupChat && chatOpen,
            unreadChatCount: _preserveCleanupChat ? unread : 0,
            chatMessages: _preserveCleanupChat ? chatMessages : const [],
          ));
        }
      } catch (_) {
        if (kDebugMode) print('Call cleanup failed');
      } finally {
        _cleanupFuture = null;
        completer.complete();
      }
    }());
    return completer.future;
  }

  Future<void> _detachCallVideo() async {
    final local = _localVideoController;
    final remote =
        List<VideoViewController>.of(_state.remoteControllers.values);
    await _setVideoTrack(local, null, debugContext: 'Clear local video track');
    for (final controller in remote) {
      await _setVideoTrack(controller, null,
          debugContext: 'Clear remote video track');
    }
    try {
      local?.dispose();
    } catch (_) {
      if (kDebugMode) print('Call cleanup: local video dispose failed');
    }
    _localVideoController = null;
    for (final controller in remote) {
      try {
        controller.dispose();
      } catch (_) {
        if (kDebugMode) print('Call cleanup: remote video dispose failed');
      }
    }
  }

  @override
  void dispose() {
    if (kDebugMode) print('Disposing widget...');

    _disposed = true;
    unawaited(_deepgramTransport.dispose());
    _callTimer.dispose();
    WidgetsBinding.instance.removeObserver(this);

    // End the native call UI (CallKit / ConnectionService) as a safety net.
    // This covers cases where the widget is disposed before participantLeft
    // fires (e.g. Firestore status-driven navigation).
    unawaited(_endSystemCallUi());
    unawaited(_persistOwnCallChatMessages(
      expectedGeneration: _callChatController.generation,
    ));

    // Synchronous cleanup of timers
    for (final timer in List<Timer>.from(_activeTimers)) {
      _cancelTrackedTimer(timer);
    }
    _cancelTrackedTimer(_remoteLeftTimer);
    _remoteLeftTimer = null;
    _resetCallCheckpointNotice(clearHistory: true);
    _callDurationNotifier.dispose();
    _callCheckpointNoticeNotifier.dispose();
    _captionOverlayNotifier.dispose();
    _chatFocusNode.removeListener(_handleChatFocusChanged);
    _chatFocusNode.unfocus();
    _chatTextController.clear();

    // Schedule async cleanup (leave call, dispose client)
    unawaited(_cleanup(leaveCall: true).whenComplete(() {
      _chatTextController.dispose();
      _chatFocusNode.dispose();
      _chatScrollController.dispose();
    }));

    super.dispose();
  }
}
