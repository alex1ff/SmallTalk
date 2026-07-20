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
import 'dart:typed_data' as typed_data;
import 'dart:math' as math;
import 'package:web_socket_channel/io.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '/services/voip_service.dart';
import '/components/chat_composer.dart';
import '/components/interactive_caption_text.dart';
import '/shared_pages/chat_message_bubble_style.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'deepgram_credential_exception.dart';
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
      error: error ?? this.error,
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

  static _CaptionPhase? fromWire(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'interim':
        return _CaptionPhase.interim;
      case 'final':
        return _CaptionPhase.finalCaption;
      default:
        return null;
    }
  }
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
    this.sessionExpiresAt,
    this.sessionPolicy,
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
  final DateTime? sessionExpiresAt;
  final Map<String, dynamic>? sessionPolicy;
  final bool? isStudent;
  final String? deepgramCredential;
  @Deprecated('Use deepgramCredential for both temporary tokens and API keys.')
  final String? deepgramApiKey;
  final Future<String?> Function()? deepgramTokenRefreshCallback;
  final bool enableDeepgram;
  final String deepgramLanguage;
  final Future Function(String word, String sentence, String contextText)?
      actionCallback;
  final Future<void> Function(String? endReason)? endCallCallback;
  final String? username;
  final Future Function()? participantLeftCallback;

  @override
  State<MinimalDailyWidget> createState() => _MinimalDailyWidgetState();
}

class _MinimalDailyWidgetState extends State<MinimalDailyWidget>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static CallClient? _processActiveCallClient;
  static Object? _processActiveCallClientLeaseToken;
  static Completer<void>? _processActiveCallClientReleaseCompleter;
  final Object _processCallClientLeaseToken = Object();

  // Core resources - properly managed
  CallClient? _callClient;
  VideoViewController? _localVideoController;
  StreamSubscription? _eventSubscription;
  StreamSubscription<dynamic>? _deepgramMessageSubscription;
  StreamSubscription<typed_data.Uint8List>? _audioStreamSubscription;

  // State management - immutable
  _CallState _state = const _CallState();
  final ValueNotifier<_CaptionOverlayState> _captionOverlayNotifier =
      ValueNotifier<_CaptionOverlayState>(const _CaptionOverlayState());

  // Resource tracking for proper cleanup
  final Set<Timer> _activeTimers = {};
  final Set<StreamSubscription> _activeSubscriptions = {};
  final Set<StreamController> _activeControllers = {};

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
  Timer? _remoteLeftTimer;
  bool _remoteLeftNotified = false;
  bool _userRequestedEnd = false;
  bool _sessionExtensionRequestInFlight = false;

  // Call duration timer
  Timer? _durationTimer;
  final Stopwatch _callDurationStopwatch = Stopwatch();
  final ValueNotifier<int> _callDurationNotifier = ValueNotifier<int>(0);
  Timer? _callCheckpointNoticeTimer;
  final ValueNotifier<_CallCheckpointNotice?> _callCheckpointNoticeNotifier =
      ValueNotifier<_CallCheckpointNotice?>(null);
  final Set<int> _shownCallCheckpointMinutes = <int>{};
  DateTime? _sessionLimitWarningShownFor;
  DateTime? _sessionLimitAutoEndedFor;
  Duration? _sessionClockOffset;
  final Map<ParticipantId, String> _remoteParticipantUiSignatures = {};
  int _localCaptionClearGeneration = 0;
  int _localCaptionUtteranceId = 0;
  int _localCaptionRevision = 0;
  bool _localUtteranceOpen = false;
  String _localCommittedCaptionText = '';
  String _localCurrentCaptionText = '';
  DateTime? _localCaptionStartedAt;
  final TextEditingController _chatTextController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  final ScrollController _chatScrollController = ScrollController();
  final List<_ChatMessage> _ownSentChatMessages = <_ChatMessage>[];
  bool _isSendingChatMessage = false;
  bool _persistCallChatInFlight = false;
  bool _persistCallChatCompleted = false;
  int _persistCallChatAttemptCount = 0;
  Timer? _localCaptionUiThrottleTimer;
  Timer? _remoteCaptionSendThrottleTimer;
  Timer? _localUtteranceEndTimer;
  Timer? _captionLogFlushTimer;
  _CaptionUpdate? _pendingLocalCaptionUpdate;
  _OutgoingCaptionMessage? _pendingOutgoingCaptionMessage;
  String? _lastSentCaptionSignature;
  final Map<String, _CaptionLogEntry> _pendingCaptionLogEntries =
      <String, _CaptionLogEntry>{};
  final Set<String> _persistedCaptionLogIds = <String>{};
  final Set<String> _reportedCaptionRuntimeIssueCodes = <String>{};
  Future<void> _captionLogFlushChain = Future<void>.value();
  double? _localCaptionConfidence;

  // Deepgram integration
  FlutterSoundRecorder? _recorder;
  IOWebSocketChannel? _deepgramChannel;
  StreamController<typed_data.Uint8List>? _audioStreamController;
  bool _recorderOpen = false;
  bool _deepgramStopRequested = false;
  bool _deepgramFinalizing = false;
  bool _deepgramStartInProgress = false;
  int _deepgramStreamGeneration = 0;
  Future<void> _lifecycleTransitionChain = Future<void>.value();
  int _lifecycleTransitionId = 0;

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
  static const int _deepgramFinalizeWaitMs = 250;
  static const int _deepgramCloseWaitMs = 100;
  static const int _maxChatMessages = 200;
  static const int _callCheckpointNoticeDurationMs = 4000;
  static const int _sessionLimitWarningLeadSeconds = 60;
  static const int _sessionLimitAutoEndGraceSeconds = 2;
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
          error: null,
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
    } catch (e) {
      if (kDebugMode) print('Hardware acceleration setup failed: $e');
    }
  }

  /// Validate room URL format
  bool _isValidRoomUrl(String url) {
    if (url.isEmpty || url == '0' || url == 'null') return false;
    try {
      final uri = Uri.tryParse(url);
      return uri != null && uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  String? _sanitizeMeetingToken(String? token) {
    if (token == null) return null;
    final trimmed = token.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower == 'null' ||
        lower == 'undefined' ||
        lower == 'false' ||
        lower == '0' ||
        lower == 'none') {
      return null;
    }
    return trimmed;
  }

  String? _effectiveMeetingToken() {
    return _sanitizeMeetingToken(_dynamicMeetingToken ?? widget.meetingToken);
  }

  String? _sanitizeRoomUrl(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    return _isValidRoomUrl(trimmed) ? trimmed : null;
  }

  String? _effectiveRoomUrl() {
    return _sanitizeRoomUrl(_dynamicRoomUrl) ??
        _sanitizeRoomUrl(widget.roomUrl);
  }

  String? _configuredDeepgramCredentialFor(
    MinimalDailyWidget widgetInstance,
  ) {
    return _sanitizeDeepgramCredential(
      // ignore: deprecated_member_use_from_same_package
      widgetInstance.deepgramCredential ?? widgetInstance.deepgramApiKey,
    );
  }

  String? _sanitizeDeepgramCredential(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final lowered = trimmed.toLowerCase();
    if (lowered == 'null' ||
        lowered == 'undefined' ||
        lowered == 'false' ||
        lowered == '0' ||
        lowered == 'none') {
      return null;
    }
    return trimmed;
  }

  bool _looksLikeJwt(String value) {
    final parts = value.split('.');
    return parts.length == 3 &&
        parts[0].isNotEmpty &&
        parts[1].isNotEmpty &&
        parts[2].isNotEmpty;
  }

  String _buildDeepgramAuthHeader(String credential) {
    final sanitized = credential.trim();
    final lowered = sanitized.toLowerCase();
    if (lowered.startsWith('token ') || lowered.startsWith('bearer ')) {
      return sanitized;
    }
    return _looksLikeJwt(sanitized) ? 'Bearer $sanitized' : 'Token $sanitized';
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
        if (kDebugMode) print('Deepgram token refresh failed: $error');
      } catch (e) {
        if (kDebugMode) print('Deepgram token refresh failed: $e');
      }
    }

    if (staticCredential != null) {
      _deepgramCredential = staticCredential;
      return staticCredential;
    }

    return null;
  }

  bool _hasValidJoinData() {
    return _effectiveRoomUrl() != null && _effectiveMeetingToken() != null;
  }

  bool _hasProcessActiveCallClientConflict() {
    final leaseToken = _processActiveCallClientLeaseToken;
    if (leaseToken == null) {
      return false;
    }
    return !identical(leaseToken, _processCallClientLeaseToken);
  }

  void _claimProcessActiveCallClientLease() {
    _processActiveCallClientLeaseToken = _processCallClientLeaseToken;
    _processActiveCallClientReleaseCompleter = Completer<void>();
  }

  void _claimProcessActiveCallClient(CallClient callClient) {
    _processActiveCallClient = callClient;
    _processActiveCallClientLeaseToken = _processCallClientLeaseToken;
    _processActiveCallClientReleaseCompleter ??= Completer<void>();
  }

  void _releaseProcessActiveCallClientLease() {
    if (!identical(
        _processActiveCallClientLeaseToken, _processCallClientLeaseToken)) {
      return;
    }
    _processActiveCallClientLeaseToken = null;
    final releaseCompleter = _processActiveCallClientReleaseCompleter;
    if (releaseCompleter != null && !releaseCompleter.isCompleted) {
      releaseCompleter.complete();
    }
    _processActiveCallClientReleaseCompleter = null;
  }

  void _releaseProcessActiveCallClient([CallClient? callClient]) {
    final targetClient = callClient ?? _callClient;
    if (targetClient != null &&
        identical(_processActiveCallClient, targetClient)) {
      _processActiveCallClient = null;
    }
    if (_processActiveCallClient == null) {
      _releaseProcessActiveCallClientLease();
    }
  }

  Future<bool> _waitForProcessActiveCallClientRelease() async {
    final releaseCompleter = _processActiveCallClientReleaseCompleter;
    if (releaseCompleter == null || releaseCompleter.isCompleted) {
      return !_hasProcessActiveCallClientConflict();
    }
    try {
      await releaseCompleter.future.timeout(const Duration(seconds: 2));
    } catch (_) {}
    return !_hasProcessActiveCallClientConflict();
  }

  void _scheduleProcessActiveCallClientRetry() {
    _createTrackedTimer(const Duration(milliseconds: 250), () {
      if (!mounted || _disposed) {
        return;
      }
      unawaited(_initializeCall());
    });
  }

  /// Simplified initialization
  Future<void> _initializeCall() async {
    if (!mounted || _disposed) return;
    if (_isInitializing ||
        _state.connectionState == ConnectionState.connected) {
      return;
    }
    if (_hasProcessActiveCallClientConflict()) {
      final released = await _waitForProcessActiveCallClientRelease();
      if (!mounted || _disposed) {
        return;
      }
      if (released) {
        if (_hasProcessActiveCallClientConflict()) {
          if (kDebugMode) {
            print(
                'MinimalDailyWidget: duplicate CallClient still active after release wait');
          }
          return;
        }
      } else {
        if (kDebugMode) {
          print(
              'MinimalDailyWidget: duplicate CallClient blocked for room/session');
        }
        _scheduleProcessActiveCallClientRetry();
        return;
      }
    }
    if (_hasProcessActiveCallClientConflict()) {
      if (kDebugMode) {
        print(
            'MinimalDailyWidget: duplicate CallClient blocked for room/session');
      }
      return;
    }
    _claimProcessActiveCallClientLease();
    _isInitializing = true;
    _systemCallMarkedConnected = false;
    _userRequestedEnd = false;
    _remoteLeftNotified = false;
    _activeRemoteProfileConfigured = false;
    _prioritySubscribedParticipants.clear();
    _cancelTrackedTimer(_remoteLeftTimer);
    _remoteLeftTimer = null;

    _updateState(_state.copyWith(
      connectionState: ConnectionState.connecting,
      error: null,
    ));

    try {
      // Create CallClient with timeout
      final createdCallClient = await _createCallClientWithTimeout();
      if (!mounted || createdCallClient == null) {
        try {
          await createdCallClient?.dispose();
        } catch (_) {}
        _releaseProcessActiveCallClientLease();
        return;
      }
      if (_hasProcessActiveCallClientConflict()) {
        if (kDebugMode) {
          print(
              'MinimalDailyWidget: disposing duplicate CallClient for room/session');
        }
        try {
          await createdCallClient.dispose();
        } catch (e) {
          if (kDebugMode) {
            print('Error disposing duplicate call client: $e');
          }
        }
        _releaseProcessActiveCallClientLease();
        return;
      }
      _callClient = createdCallClient;
      _claimProcessActiveCallClient(createdCallClient);

      // Initialize video controller
      _localVideoController = VideoViewController();

      // Setup event subscription
      await _setupEventSubscription();

      // Join room with FIXED quality settings sequence
      await _joinRoomWithEnhancedSettings();

      // Quality monitoring removed - Daily Adaptive Bitrate handles this
    } catch (e) {
      _releaseProcessActiveCallClient();
      await _handleConnectionError(e);
    } finally {
      _isInitializing = false;
    }
  }

  /// Create CallClient with timeout and retry
  Future<CallClient?> _createCallClientWithTimeout() async {
    const timeout = Duration(seconds: 10);

    try {
      return await CallClient.create().timeout(timeout);
    } on TimeoutException {
      throw Exception('CallClient creation timed out');
    } catch (e) {
      if (kDebugMode) print('CallClient creation failed: $e');
      rethrow;
    }
  }

  /// Setup event subscription with proper error handling
  Future<void> _setupEventSubscription() async {
    await _cancelTrackedSubscription(_eventSubscription);
    _eventSubscription = _trackSubscription(_callClient!.events.listen(
      _handleCallEvent,
      onError: (error) {
        if (kDebugMode) print('Event stream error: $error');
        // Route through _handleEventError to filter non-fatal errors
        if (mounted && !_disposed) {
          _handleEventError(error.toString());
        }
      },
      cancelOnError: false,
    ));
  }

  /// Join room with default settings to avoid SDK parsing errors
  Future<void> _joinRoomWithEnhancedSettings() async {
    final roomUrl = _effectiveRoomUrl();
    if (roomUrl == null) {
      throw StateError('Daily room URL is not ready');
    }
    final roomUri = Uri.parse(roomUrl);
    final token = _effectiveMeetingToken();

    await _callClient!.join(
      url: roomUri,
      token: token,
    );

    await _callClient!.updatePublishing(
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

    await _callClient!.updateInputs(
      inputs: const InputSettingsUpdate.set(
        camera: CameraInputSettingsUpdate.set(isEnabled: BoolUpdate.set(true)),
        microphone:
            MicrophoneInputSettingsUpdate.set(isEnabled: BoolUpdate.set(true)),
      ),
    );

    await _ensureActiveRemoteSubscriptionProfile();
    await _configureUsername();
  }

  /// Configure username with fallback
  Future<void> _configureUsername() async {
    try {
      final name = widget.username ?? _getDefaultUsername();
      await _callClient?.setUsername(name);
      if (kDebugMode) print('Username set: $name');
    } catch (e) {
      if (kDebugMode) print('Username configuration failed: $e');
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
    } catch (e) {
      if (kDebugMode) print('Event handling error: $e');
    }
  }

  /// Handle call state updates
  void _handleCallStateUpdate(CallStateData data) {
    if (!mounted || _disposed) return;

    switch (data.state) {
      case CallState.joined:
        _updateState(_state.copyWith(
          connectionState: ConnectionState.connected,
          error: null,
          retryCount: 0,
        ));
        _tokenRefreshAttempts = 0;
        unawaited(_updateLocalVideoTrack());
        unawaited(_markRoomJoined());
        unawaited(_promoteToActiveCallIfReady());
        break;

      case CallState.left:
        _stopDeepgramStreaming();
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
      final payload = _decodeAppMessagePayload(message);
      if (payload == null) return;

      final type = payload['type']?.toString();
      if (type == 'caption') {
        _processCaptionMessage(payload, from);
      } else if (type == 'chat') {
        _processChatMessage(payload['text']?.toString() ?? '', from);
      }
    } catch (e) {
      if (kDebugMode) print('Invalid app message: $e');
    }
  }

  /// Decode Daily app messages from string/map and handle double encoding.
  ///
  /// daily_flutter can emit app-message data as JSON-encoded strings, and when
  /// sender payload is already a JSON string this arrives double-encoded.
  Map<String, dynamic>? _decodeAppMessagePayload(String rawMessage) {
    dynamic payload = rawMessage;

    for (var i = 0; i < 2; i++) {
      if (payload is String) {
        final trimmed = payload.trim();
        if (trimmed.isEmpty) return null;
        payload = dart_convert.jsonDecode(trimmed);
        continue;
      }
      break;
    }

    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }

    return null;
  }

  /// Process caption message with revision-aware ordering.
  void _processCaptionMessage(
      Map<String, dynamic> payload, ParticipantId from) {
    final text = _normalizeCaptionText(payload['text']?.toString() ?? '');
    final current = _state.remoteCaptions[from];
    final rawUtteranceId = _readInt(payload['utteranceId']);
    final rawRevision = _readInt(payload['revision']);
    final phase = _CaptionPhase.fromWire(payload['phase']?.toString()) ??
        _CaptionPhase.finalCaption;

    int utteranceId;
    int revision;

    if (rawUtteranceId == null || rawRevision == null) {
      if (text.isEmpty) return;
      if (current != null &&
          current.phase == _CaptionPhase.finalCaption &&
          current.text == text &&
          !current.isFadingOut) {
        return;
      }
      utteranceId = _nextLegacyRemoteUtteranceId(from, current);
      revision = 1;
    } else {
      utteranceId = rawUtteranceId;
      revision = rawRevision;
      if (text.isEmpty) return;
      final previousCounter = _remoteLegacyCaptionCounters[from] ?? 0;
      if (utteranceId > previousCounter) {
        _remoteLegacyCaptionCounters[from] = utteranceId;
      }
    }

    if (current != null) {
      if (utteranceId < current.utteranceId) {
        return;
      }
      if (utteranceId == current.utteranceId && revision <= current.revision) {
        return;
      }
    }

    _upsertRemoteCaption(
      participantId: from,
      utteranceId: utteranceId,
      revision: revision,
      text: text,
      phase: phase,
    );

    if (rawUtteranceId == null &&
        rawRevision == null &&
        phase == _CaptionPhase.finalCaption) {
      _enqueueLegacyRemoteCaptionLog(
        from,
        utteranceId: utteranceId,
        text: text,
      );
    }
  }

  int _nextLegacyRemoteUtteranceId(
    ParticipantId participantId,
    _ActiveCaption? current,
  ) {
    final nextUtteranceId = math.max(
      (_remoteLegacyCaptionCounters[participantId] ?? 0) + 1,
      (current?.utteranceId ?? 0) + 1,
    );
    _remoteLegacyCaptionCounters[participantId] = nextUtteranceId;
    return nextUtteranceId;
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  double? _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  void _processChatMessage(String text, ParticipantId from) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    final message = _ChatMessage(
      id: _buildChatMessageId(
        senderId: from.id,
        text: trimmedText,
      ),
      text: trimmedText,
      senderName: _participantDisplayName(from),
      senderId: from.id,
      sentAt: DateTime.now(),
      isLocal: false,
    );

    _appendChatMessage(
      message,
      incrementUnread: !_state.isChatOpen,
    );
  }

  String _buildChatMessageId({
    required String senderId,
    required String text,
  }) {
    return '${DateTime.now().microsecondsSinceEpoch}_${senderId}_${text.hashCode}';
  }

  String _participantDisplayName(
    ParticipantId participantId, {
    String fallback = 'Собеседник',
  }) {
    final participant = _callClient?.participants.all[participantId];
    final username = participant?.info.username?.trim();
    if (username?.isNotEmpty == true) {
      return username!;
    }
    return fallback;
  }

  String _participantLogSpeakerId(
    ParticipantId participantId, {
    required int utteranceId,
  }) {
    final participant = _callClient?.participants.all[participantId];
    final userId = participant?.info.userId?.trim();
    if (userId?.isNotEmpty == true) {
      return userId!;
    }

    final participantSessionId = participantId.id.trim();
    if (participantSessionId.isNotEmpty) {
      return participantSessionId;
    }

    return 'remote_$utteranceId';
  }

  String _localParticipantName() {
    final localUsername = _callClient?.participants.local.info.username?.trim();
    if (localUsername?.isNotEmpty == true) {
      return localUsername!;
    }

    final widgetUsername = widget.username?.trim();
    if (widgetUsername?.isNotEmpty == true) {
      return widgetUsername!;
    }

    return widget.isStudent == true ? 'Студент' : 'Преподаватель';
  }

  String _localParticipantId() {
    final localId = _callClient?.participants.local.id.id;
    if (localId?.isNotEmpty == true) {
      return localId!;
    }
    return 'local';
  }

  void _appendChatMessage(
    _ChatMessage message, {
    bool incrementUnread = false,
  }) {
    final messages = List<_ChatMessage>.from(_state.chatMessages)..add(message);
    if (messages.length > _maxChatMessages) {
      messages.removeRange(0, messages.length - _maxChatMessages);
    }

    _updateState(_state.copyWith(
      chatMessages: List<_ChatMessage>.unmodifiable(messages),
      unreadChatCount:
          incrementUnread ? _state.unreadChatCount + 1 : _state.unreadChatCount,
    ));

    _scrollChatToBottom(animated: _state.isChatOpen);
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

    if (!isOpen) {
      _clearChatDraft();
    }

    _updateState(_state.copyWith(
      isChatOpen: isOpen,
      unreadChatCount: isOpen ? 0 : _state.unreadChatCount,
    ));

    if (isOpen) {
      _scrollChatToBottom(animated: false);
    }
  }

  void _toggleChatOpen() {
    _setChatOpen(!_state.isChatOpen);
  }

  void _clearChatDraft() {
    _chatTextController.clear();
    _chatFocusNode.unfocus();
  }

  bool _canSendChatText(String text) {
    return _state.connectionState == ConnectionState.connected &&
        _callClient != null &&
        _hasRemoteParticipantPresent() &&
        text.trim().isNotEmpty;
  }

  Future<void> _sendChatMessage() async {
    final text = _chatTextController.text.trim();
    if (_isSendingChatMessage ||
        !_canSendChatText(text) ||
        _callClient == null) {
      return;
    }

    _isSendingChatMessage = true;

    final message = _ChatMessage(
      id: _buildChatMessageId(
        senderId: _localParticipantId(),
        text: text,
      ),
      text: text,
      senderName: _localParticipantName(),
      senderId: _localParticipantId(),
      sentAt: DateTime.now(),
      isLocal: true,
    );

    _appendChatMessage(message);
    _chatTextController.clear();

    try {
      final payload = dart_convert.jsonEncode({
        'type': 'chat',
        'text': text,
      });
      await _callClient!.sendAppMessage(payload, null);
      _ownSentChatMessages.add(message);
    } catch (e) {
      if (kDebugMode) print('Failed to send chat message: $e');
    } finally {
      if (mounted && !_disposed) {
        setState(() => _isSendingChatMessage = false);
      }
    }
  }

  bool _isTerminalSessionStatus(String? status) {
    final normalized = status?.trim().toLowerCase();
    return normalized == 'ended' ||
        normalized == 'cancelled' ||
        normalized == 'expired';
  }

  Future<void> _persistOwnCallChatMessages() async {
    if (_persistCallChatCompleted || _persistCallChatInFlight) {
      return;
    }

    final sessionId = widget.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      _persistCallChatCompleted = true;
      return;
    }

    if (_persistCallChatAttemptCount >= 3) {
      return;
    }

    _persistCallChatInFlight = true;
    _persistCallChatAttemptCount += 1;
    final messages = List<_ChatMessage>.unmodifiable(_ownSentChatMessages);

    try {
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
      _persistCallChatCompleted = true;
    } on FirebaseFunctionsException catch (error) {
      if (kDebugMode) {
        print('Failed to persist call chat: ${error.code}');
      }
    } catch (error) {
      if (kDebugMode) print('Failed to persist call chat: $error');
    } finally {
      _persistCallChatInFlight = false;
    }
  }

  Future<void> _endSessionAndPersistCallChat(String? endReason) async {
    final sessionId = widget.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      await _persistOwnCallChatMessages();
      return;
    }

    try {
      await FirebaseFunctions.instance.httpsCallable('endSession').call({
        'sessionId': sessionId,
        if (endReason != null && endReason.isNotEmpty) 'endReason': endReason,
      }).timeout(const Duration(seconds: 8));
    } on FirebaseFunctionsException catch (error) {
      if (kDebugMode) {
        print('endSession before chat persist failed: ${error.code}');
      }
    } catch (error) {
      if (kDebugMode) print('endSession before chat persist failed: $error');
    }

    await _persistOwnCallChatMessages();
  }

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
  void _handleEventError(String error) {
    if (kDebugMode) print('Daily event error: $error');

    final lowerError = error.toLowerCase();

    // Track subscription failures are transient - Daily SDK retries automatically.
    // Do NOT treat these as fatal connection errors.
    if (lowerError.contains('subscription') ||
        lowerError.contains('consumer') ||
        lowerError.contains('track') ||
        lowerError.contains('no longer exists') ||
        lowerError.contains('meeting_event') ||
        lowerError.contains('send_meeting_event')) {
      if (kDebugMode) print('Non-fatal Daily error (ignored): $error');
      return;
    }

    // Only escalate truly fatal errors to connection error handler
    unawaited(_handleConnectionError(error));
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
    } catch (e) {
      if (kDebugMode) print('Failed to add remote participant: $e');
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
    if (!mounted || _disposed) return;

    final controller = _state.remoteControllers[participant.id];
    if (controller == null) {
      // Controller might not be created yet, retry
      _createTrackedTimer(const Duration(milliseconds: 200), () {
        if (mounted && _state.remoteControllers.containsKey(participant.id)) {
          unawaited(_updateRemoteParticipant(participant));
        }
      });
      return;
    }

    final media = participant.media;
    final track = media?.screenVideo.state != MediaState.off
        ? media?.screenVideo.track
        : media?.camera.track;

    await _setVideoTrack(
      controller,
      track,
      debugContext: 'Failed to update remote participant track',
    );

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
    if (_callClient == null) return;
    if (_prioritySubscribedParticipants.contains(id) &&
        _activeRemoteProfileConfigured) {
      return;
    }

    try {
      await _ensureActiveRemoteSubscriptionProfile();
      await _callClient!.updateSubscriptions(
        forParticipants: {
          id: SubscriptionSettingsUpdate.set(
            profile: const SubscriptionProfileUpdate.set(
              profile: SubscriptionProfile.activeRemote,
            ),
          ),
        },
      );
      _prioritySubscribedParticipants.add(id);
    } catch (e) {
      if (kDebugMode)
        print('Failed to prioritize remote subscription for $id: $e');
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
    } catch (e) {
      if (kDebugMode) print('Failed to remove participant: $e');
    }
  }

  /// Update local video track safely
  Future<void> _updateLocalVideoTrack() async {
    if (_callClient == null || _localVideoController == null || !mounted)
      return;

    final local = _callClient!.participants.local;
    final track = local.media?.camera.track;

    // Update track - VideoViewController doesn't have a track getter
    // so we always set the track
    await _setVideoTrack(
      _localVideoController,
      track,
      debugContext: 'Local video track update failed',
    );
  }

  /// Update input settings with quality preservation
  Future<void> _updateInputSettings({bool? camera, bool? microphone}) async {
    if (_callClient == null || !mounted) return;

    try {
      await _callClient!.updateInputs(
        inputs: InputSettingsUpdate.set(
          camera: camera != null
              ? CameraInputSettingsUpdate.set(isEnabled: BoolUpdate.set(camera))
              : null,
          microphone: microphone != null
              ? MicrophoneInputSettingsUpdate.set(
                  isEnabled: BoolUpdate.set(microphone))
              : null,
        ),
      );

      _updateState(_state.copyWith(
        cameraEnabled: camera ?? _state.cameraEnabled,
        microphoneEnabled: microphone ?? _state.microphoneEnabled,
      ));
      if (microphone != null) {
        await _syncDeepgramWithMicrophoneState(forceRefresh: microphone);
        if (microphone == false) {
          await _flushPendingCaptionLogs(force: true);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Input settings update failed: $e');
    }
  }

  Future<void> _disableLocalInputsForCleanup() async {
    if (_callClient == null) {
      _updateState(_state.copyWith(
        cameraEnabled: false,
        microphoneEnabled: false,
      ));
      return;
    }

    try {
      await _callClient!
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
    } catch (e) {
      if (kDebugMode) {
        print('Failed to disable local inputs during cleanup: $e');
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
        _state.connectionState == ConnectionState.connected &&
        _state.microphoneEnabled &&
        _hasRemoteParticipantPresent() &&
        _canUseDeepgram();
  }

  bool _isCurrentDeepgramStreamGeneration(
    int generation,
    String? sessionId,
  ) {
    return mounted &&
        !_disposed &&
        !_deepgramStopRequested &&
        _deepgramStreamGeneration == generation &&
        widget.sessionId?.trim() == sessionId &&
        _shouldRunDeepgram();
  }

  bool _canHandleDeepgramMessage(
    int generation,
    String? sessionId,
  ) {
    return mounted &&
        !_disposed &&
        widget.sessionId?.trim() == sessionId &&
        ((_deepgramFinalizing && _deepgramStopRequested) ||
            (_deepgramStreamGeneration == generation &&
                !_deepgramStopRequested &&
                _shouldRunDeepgram()));
  }

  Future<void> _syncDeepgramWithMicrophoneState({
    bool forceRefresh = false,
  }) async {
    if (_shouldRunDeepgram()) {
      if (!_state.isStreamingToDeepgram && !_deepgramStartInProgress) {
        await _startDeepgramStreamingWithResolvedCredential(
          forceRefresh: forceRefresh,
        );
      }
      return;
    }

    if (_state.isStreamingToDeepgram ||
        _deepgramStartInProgress ||
        _recorder != null ||
        _deepgramChannel != null) {
      await _stopDeepgramStreaming();
    }
    _clearLocalCaptions();
  }

  Future<void> _promoteToActiveCallIfReady() async {
    if (_state.connectionState != ConnectionState.connected) return;
    if (!_hasRemoteParticipantPresent()) return;

    _startDurationTimer();
    await _markRoomJoined();
    await _markSystemCallConnected();
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
    _pendingOutgoingCaptionMessage = null;
    _lastSentCaptionSignature = null;
    _localUtteranceOpen = false;
    _localCommittedCaptionText = '';
    _localCurrentCaptionText = '';
    _localCaptionConfidence = null;
    _localCaptionRevision = 0;
    _localCaptionStartedAt = null;

    if (_state.localCaption == null) {
      return;
    }
    _updateCaptionState(_state.copyWith(clearLocalCaption: true));
  }

  Future<void> _ensureActiveRemoteSubscriptionProfile() async {
    if (_callClient == null || _activeRemoteProfileConfigured) return;

    try {
      await _callClient!.updateSubscriptionProfiles(
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
      );
      _activeRemoteProfileConfigured = true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to configure active remote subscription profile: $e');
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
  Future<void> _handleConnectionError(dynamic error) async {
    if (!mounted || _disposed) return;

    if (kDebugMode) print('Connection error: $error');

    final message = error.toString().toLowerCase();
    final isTokenError =
        message.contains('sigauthz') || message.contains('token');

    // If we're already connected and this isn't a token error,
    // don't tear down the connection - it's likely a transient issue
    if (_state.connectionState == ConnectionState.connected && !isTokenError) {
      if (kDebugMode) print('Ignoring non-fatal error while connected: $error');
      return;
    }

    final refreshed = await _tryRefreshTokenOnError(error);
    if (refreshed) {
      return;
    }

    if (isTokenError && _tokenRefreshAttempts >= _maxTokenRefreshAttempts) {
      await _cleanup(
        leaveCall: false,
        preserveMeetingToken: true,
        preserveTokenRefreshAttempts: true,
        preserveChatState: true,
      );
      _updateState(_state.copyWith(
        connectionState: ConnectionState.failed,
        error: 'Ошибка токена, перезапустите звонок',
      ));
      return;
    }

    _updateState(_state.copyWith(
      connectionState: ConnectionState.failed,
      error: error.toString(),
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

  Future<bool> _tryRefreshTokenOnError(dynamic error) async {
    if (_tokenRefreshInProgress) return false;
    if (_tokenRefreshAttempts >= _maxTokenRefreshAttempts) return false;
    if (widget.tokenRefreshCallback == null &&
        widget.joinCredentialsRefreshCallback == null) {
      return false;
    }

    final message = error.toString().toLowerCase();
    final looksLikeTokenError =
        message.contains('sigauthz') || message.contains('token');
    if (!looksLikeTokenError) return false;

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
    } catch (e) {
      if (kDebugMode) print('Token refresh failed: $e');
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

  Future<void> _startDeepgramStreamingWithResolvedCredential({
    bool forceRefresh = false,
  }) async {
    if (!_shouldRunDeepgram()) {
      return;
    }
    final sessionIdAtStart = widget.sessionId?.trim();
    final credential = await _resolveDeepgramCredential(
      forceRefresh: forceRefresh,
    );
    if (!_shouldRunDeepgram() || widget.sessionId?.trim() != sessionIdAtStart) {
      return;
    }
    if (credential == null) {
      if (_state.captionIssueCode == null) {
        _reportCaptionRuntimeIssue(
          code: 'caption_token_unavailable',
          message:
              'Субтитры временно недоступны: не удалось получить токен распознавания.',
        );
      }
      if (kDebugMode) print('Deepgram disabled: no credential available');
      return;
    }
    await _startDeepgramStreaming(credential);
  }

  /// Start Deepgram streaming with proper resource management
  Future<void> _startDeepgramStreaming(String credential) async {
    if (_state.isStreamingToDeepgram ||
        !mounted ||
        _deepgramStartInProgress ||
        !_shouldRunDeepgram()) {
      return;
    }

    final sessionIdAtStart = widget.sessionId?.trim();
    final generation = ++_deepgramStreamGeneration;
    var reportedSpecificStartIssue = false;
    try {
      _deepgramStartInProgress = true;
      _deepgramStopRequested = false;

      if (kDebugMode) {
        print(
          'Deepgram starting with ${_looksLikeJwt(credential) ? "temporary token" : "API key"} auth',
        );
      }

      // Request microphone permission
      final permission = await Permission.microphone.request();
      if (!_isCurrentDeepgramStreamGeneration(generation, sessionIdAtStart)) {
        return;
      }
      if (!permission.isGranted) {
        _reportCaptionRuntimeIssue(
          code: 'microphone_permission_denied',
          message: 'Субтитры временно недоступны: нет доступа к микрофону.',
        );
        reportedSpecificStartIssue = true;
        throw Exception('Microphone permission denied');
      }

      // Initialize recorder
      final recorder = FlutterSoundRecorder();
      _recorder = recorder;
      await recorder.openRecorder();
      if (!_isCurrentDeepgramStreamGeneration(generation, sessionIdAtStart) ||
          _recorder != recorder) {
        await _closeStaleDeepgramRecorder(recorder);
        return;
      }
      _recorderOpen = true;

      recorder.setSubscriptionDuration(const Duration(milliseconds: 100));

      // Initialize Deepgram WebSocket
      await _initializeDeepgramWebSocket(
        credential,
        generation: generation,
        sessionId: sessionIdAtStart,
      );
      if (!_isCurrentDeepgramStreamGeneration(generation, sessionIdAtStart)) {
        await _stopDeepgramStreaming();
        return;
      }

      // Setup audio streaming
      _audioStreamController = StreamController<typed_data.Uint8List>();
      _trackController(_audioStreamController!);

      _audioStreamSubscription = _trackSubscription(
        _audioStreamController!.stream.listen(
          (data) {
            if (!_isCurrentDeepgramStreamGeneration(
              generation,
              sessionIdAtStart,
            )) {
              return;
            }
            final channel = _deepgramChannel;
            if (channel == null) {
              return;
            }
            try {
              channel.sink.add(data);
            } catch (e) {
              _handleDeepgramAudioSinkFailure(
                e,
                generation: generation,
                sessionId: sessionIdAtStart,
              );
            }
          },
          onError: (e) {
            if (!_isCurrentDeepgramStreamGeneration(
              generation,
              sessionIdAtStart,
            )) {
              return;
            }
            _reportCaptionRuntimeIssue(
              code: 'audio_stream_error',
              message:
                  'Субтитры временно недоступны: не удалось передать звук на распознавание.',
            );
            if (kDebugMode) print('Audio stream error: $e');
          },
        ),
      );

      // Start recording
      await recorder.startRecorder(
        toStream: _audioStreamController!.sink,
        codec: Codec.pcm16,
        sampleRate: 16000,
        numChannels: 1,
      );
      if (!_isCurrentDeepgramStreamGeneration(generation, sessionIdAtStart)) {
        await _stopDeepgramStreaming();
        await _closeStaleDeepgramRecorder(recorder);
        return;
      }

      _updateState(_state.copyWith(isStreamingToDeepgram: true));
      _clearCaptionRuntimeIssue();

      if (kDebugMode) print('Deepgram streaming started successfully');
    } catch (e) {
      if (!reportedSpecificStartIssue &&
          _isCurrentDeepgramStreamGeneration(generation, sessionIdAtStart)) {
        _reportCaptionRuntimeIssue(
          code: 'deepgram_start_failed',
          message:
              'Субтитры временно недоступны: не удалось запустить распознавание речи.',
        );
      }
      if (kDebugMode) print('Failed to start Deepgram streaming: $e');
      await _stopDeepgramStreaming();
    } finally {
      if (_deepgramStreamGeneration == generation) {
        _deepgramStartInProgress = false;
      }
    }
  }

  Future<void> _closeStaleDeepgramRecorder(
      FlutterSoundRecorder recorder) async {
    try {
      if (recorder.isRecording) {
        await recorder.stopRecorder();
      }
      await recorder.closeRecorder();
    } catch (e) {
      if (kDebugMode) print('Error closing stale Deepgram recorder: $e');
    } finally {
      if (_recorder == recorder) {
        _recorder = null;
        _recorderOpen = false;
      }
    }
  }

  /// Initialize Deepgram WebSocket connection
  Future<void> _initializeDeepgramWebSocket(
    String credential, {
    required int generation,
    required String? sessionId,
  }) async {
    final sanitizedCredential = credential.trim();
    final uri = Uri.https('api.deepgram.com', '/v1/listen', {
      'encoding': 'linear16',
      'sample_rate': '16000',
      'channels': '1',
      'model': 'nova-3',
      'language': widget.deepgramLanguage,
      'smart_format': 'true',
      'punctuate': 'true',
      'utterances': 'true',
      'interim_results': 'true',
      'vad_events': 'true',
      'endpointing': '500',
      'utterance_end_ms': '1000',
    });

    final wsUrl = uri.toString().replaceFirst('https://', 'wss://');
    final usesJwt = _looksLikeJwt(sanitizedCredential);

    _deepgramChannel = IOWebSocketChannel.connect(
      wsUrl,
      protocols: usesJwt ? null : <String>['token', sanitizedCredential],
      headers: {
        'Authorization': _buildDeepgramAuthHeader(sanitizedCredential),
      },
      connectTimeout: const Duration(seconds: 10),
    );

    await _cancelTrackedSubscription(_deepgramMessageSubscription);
    _deepgramMessageSubscription = _trackSubscription(
      _deepgramChannel!.stream.listen(
        (message) {
          if (!_canHandleDeepgramMessage(generation, sessionId)) {
            return;
          }
          _handleDeepgramMessage(message);
        },
        onError: (e) {
          if (!_isCurrentDeepgramStreamGeneration(generation, sessionId)) {
            if (kDebugMode) print('Ignored stale Deepgram WebSocket error: $e');
            return;
          }
          _reportCaptionRuntimeIssue(
            code: 'deepgram_websocket_error',
            message:
                'Субтитры временно недоступны: соединение с распознаванием речи прервано.',
          );
          if (kDebugMode) print('Deepgram WebSocket error: $e');
          if (!_deepgramStopRequested) {
            _restartDeepgramConnection();
          }
        },
        onDone: () {
          if (kDebugMode) print('Deepgram WebSocket closed');
          if (_isCurrentDeepgramStreamGeneration(generation, sessionId)) {
            _reportCaptionRuntimeIssue(
              code: 'deepgram_websocket_error',
              message:
                  'Субтитры временно недоступны: соединение с распознаванием речи прервано.',
            );
            _restartDeepgramConnection();
          }
        },
      ),
    );
  }

  /// Handle Deepgram message with proper parsing
  void _handleDeepgramMessage(dynamic message) {
    if (!mounted ||
        (!_deepgramFinalizing &&
            (!_state.microphoneEnabled || !_hasRemoteParticipantPresent()))) {
      return;
    }

    try {
      final decoded = dart_convert.jsonDecode(message);
      if (decoded is! Map<String, dynamic>) {
        _reportCaptionRuntimeIssue(
          code: 'deepgram_message_parse_failed',
          message:
              'Субтитры временно недоступны: не удалось обработать ответ распознавания.',
        );
        return;
      }

      final data = decoded;
      final type = data['type']?.toString();

      if (_isDeepgramErrorFrame(data, type)) {
        _reportCaptionRuntimeIssue(
          code: 'deepgram_error_frame',
          message:
              'Субтитры временно недоступны: сервис распознавания вернул ошибку.',
        );
        return;
      }

      if (type == 'UtteranceEnd') {
        _handleDeepgramUtteranceEnd();
        return;
      }

      final channel = data['channel'];
      final alternatives =
          channel is Map<String, dynamic> ? channel['alternatives'] : null;

      if (alternatives is! List || alternatives.isEmpty) return;

      final firstAlternative = alternatives.first;
      if (firstAlternative is! Map) return;

      final transcript = _normalizeCaptionText(
        firstAlternative['transcript']?.toString() ?? '',
      );
      final isFinalSegment = data['is_final'] == true;
      final speechFinal =
          data['speech_final'] == true || data['speech_finalized'] == true;
      final confidence = _readDouble(firstAlternative['confidence']);

      if (transcript.isEmpty) {
        if (speechFinal) {
          _emitFinalUpdateForCurrentLocalCaption();
        }
        return;
      }

      _cancelLocalUtteranceEndFallback();
      _handleDeepgramTranscript(
        transcript: transcript,
        isFinalSegment: isFinalSegment,
        speechFinal: speechFinal,
        confidence: confidence,
      );
    } catch (e) {
      _reportCaptionRuntimeIssue(
        code: 'deepgram_message_parse_failed',
        message:
            'Субтитры временно недоступны: не удалось обработать ответ распознавания.',
      );
      if (kDebugMode) print('Failed to process Deepgram message: $e');
    }
  }

  bool _isDeepgramErrorFrame(Map<String, dynamic> data, String? type) {
    final normalizedType = type?.trim().toLowerCase();
    return normalizedType == 'error' || data.containsKey('error');
  }

  void _handleDeepgramTranscript({
    required String transcript,
    required bool isFinalSegment,
    required bool speechFinal,
    double? confidence,
  }) {
    if (!_deepgramFinalizing &&
        (!_state.microphoneEnabled || !_hasRemoteParticipantPresent())) {
      return;
    }

    _clearCaptionRuntimeIssue();
    _ensureLocalCaptionUtteranceStarted();
    if (confidence != null && (isFinalSegment || speechFinal)) {
      _localCaptionConfidence = confidence;
    }

    if (isFinalSegment) {
      _localCommittedCaptionText = _mergeCaptionSegments(
        _localCommittedCaptionText,
        transcript,
      );
    }

    final now = DateTime.now();
    final displayText = isFinalSegment
        ? _localCommittedCaptionText
        : _mergeCaptionSegments(_localCommittedCaptionText, transcript);

    _localCurrentCaptionText = displayText;

    final update = _CaptionUpdate(
      utteranceId: _localCaptionUtteranceId,
      revision: _nextLocalCaptionRevision(),
      text: displayText,
      phase: speechFinal ? _CaptionPhase.finalCaption : _CaptionPhase.interim,
      startedAt: _localCaptionStartedAt ?? now,
      lastUpdateAt: now,
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
      _finalizeLocalUtterance(fallbackText: displayText);
    }
  }

  void _handleDeepgramUtteranceEnd() {
    if (!_localUtteranceOpen || _localCurrentCaptionText.isEmpty) {
      return;
    }

    _cancelTrackedTimer(_localUtteranceEndTimer);
    final utteranceId = _localCaptionUtteranceId;
    final revisionAtSignal = _localCaptionRevision;

    _localUtteranceEndTimer = _createTrackedTimer(
      const Duration(milliseconds: _captionUtteranceEndFallbackMs),
      () {
        _localUtteranceEndTimer = null;
        if (!_localUtteranceOpen ||
            utteranceId != _localCaptionUtteranceId ||
            revisionAtSignal != _localCaptionRevision) {
          return;
        }
        _emitFinalUpdateForCurrentLocalCaption();
      },
    );
  }

  void _ensureLocalCaptionUtteranceStarted() {
    if (_localUtteranceOpen) {
      return;
    }

    _localUtteranceOpen = true;
    _localCaptionUtteranceId += 1;
    _localCaptionRevision = 0;
    _localCommittedCaptionText = '';
    _localCurrentCaptionText = '';
    _localCaptionStartedAt = DateTime.now();
    _localCaptionConfidence = null;
  }

  int _nextLocalCaptionRevision() {
    _localCaptionRevision += 1;
    return _localCaptionRevision;
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
    _localUtteranceOpen = false;
    _localCommittedCaptionText = '';
    _localCurrentCaptionText = finalText;
    _scheduleCaptionFadeAndClear(
      utteranceId: _localCaptionUtteranceId,
      holdMs: _holdDurationForCaption(finalText),
    );
  }

  bool _emitFinalUpdateForCurrentLocalCaption() {
    final finalText = _normalizeCaptionText(_localCurrentCaptionText);
    if (!_localUtteranceOpen || finalText.isEmpty) {
      return false;
    }

    final now = DateTime.now();
    final update = _CaptionUpdate(
      utteranceId: _localCaptionUtteranceId,
      revision: _nextLocalCaptionRevision(),
      text: finalText,
      phase: _CaptionPhase.finalCaption,
      startedAt: _localCaptionStartedAt ?? now,
      lastUpdateAt: now,
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
    _finalizeLocalUtterance(fallbackText: finalText);
    return true;
  }

  Future<void> _finalizeCurrentCaptionAndFlushLogs() async {
    // A short utterance can still be interim when the user or peer ends the
    // call. Promote the latest recognized text before clearing caption state.
    _emitFinalUpdateForCurrentLocalCaption();
    await _flushPendingCaptionLogs(force: true);
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
      confidence: _localCaptionConfidence,
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

    if (_persistedCaptionLogIds.contains(entry.logId)) {
      return;
    }

    _pendingCaptionLogEntries[entry.logId] = entry;

    if (_pendingCaptionLogEntries.length >= _captionLogBatchThreshold) {
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

    final flushFuture =
        _captionLogFlushChain.catchError((_) {}).then((_) async {
      if (_pendingCaptionLogEntries.isEmpty) {
        return;
      }

      final sessionRef = _captionLogSessionRef();
      final writerId = _captionLogWriterId();
      if (sessionRef == null || writerId == null) {
        return;
      }

      final entries = List<_CaptionLogEntry>.from(
        _pendingCaptionLogEntries.values,
      );
      if (kDebugMode) {
        print(
          'Flushing ${entries.length} caption logs for ${sessionRef.path}',
        );
      }
      final batch = FirebaseFirestore.instance.batch();

      for (final entry in entries) {
        batch.set(
          CaptionLogsRecord.createDoc(sessionRef, id: entry.logId),
          entry.toFirestoreData(writerId: writerId),
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      for (final entry in entries) {
        _pendingCaptionLogEntries.remove(entry.logId);
        _persistedCaptionLogIds.add(entry.logId);
      }
    }).catchError((Object error) {
      if (kDebugMode) {
        final sessionPath = _captionLogSessionRef()?.path ?? 'unknown-session';
        print(
          'Failed to flush ${_pendingCaptionLogEntries.length} caption logs for $sessionPath: $error',
        );
      }
      if (_pendingCaptionLogEntries.isNotEmpty &&
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

    _captionLogFlushChain = flushFuture.catchError((_) {});
    return flushFuture;
  }

  void _queueOutgoingCaptionMessage(
    _OutgoingCaptionMessage message, {
    required bool immediate,
  }) {
    _pendingOutgoingCaptionMessage = message;

    if (immediate) {
      _cancelTrackedTimer(_remoteCaptionSendThrottleTimer);
      _remoteCaptionSendThrottleTimer = null;
      unawaited(_flushOutgoingCaptionMessage());
      return;
    }

    if (_remoteCaptionSendThrottleTimer != null) {
      return;
    }

    _remoteCaptionSendThrottleTimer = _createTrackedTimer(
      const Duration(milliseconds: _captionSendThrottleMs),
      () {
        _remoteCaptionSendThrottleTimer = null;
        unawaited(_flushOutgoingCaptionMessage());
      },
    );
  }

  Future<void> _flushOutgoingCaptionMessage() async {
    final message = _pendingOutgoingCaptionMessage;
    _pendingOutgoingCaptionMessage = null;
    if (message == null) {
      return;
    }

    if (message.signature == _lastSentCaptionSignature) {
      return;
    }

    final didSend = await _sendCaptionMessage(message);
    if (didSend) {
      _lastSentCaptionSignature = message.signature;
    }
  }

  /// Send caption message to other participants
  Future<bool> _sendCaptionMessage(_OutgoingCaptionMessage message) async {
    if (_callClient == null ||
        message.text.trim().isEmpty ||
        !_state.microphoneEnabled ||
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
    } catch (e) {
      if (kDebugMode) print('Failed to send caption: $e');
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
    if (current != null &&
        current.utteranceId == utteranceId &&
        current.phase == _CaptionPhase.finalCaption &&
        phase == _CaptionPhase.interim) {
      return;
    }

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
    return rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
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

  String _mergeCaptionSegments(String committed, String segment) {
    final normalizedCommitted = _normalizeCaptionText(committed);
    final normalizedSegment = _normalizeCaptionText(segment);
    if (normalizedCommitted.isEmpty) return normalizedSegment;
    if (normalizedSegment.isEmpty) return normalizedCommitted;
    if (normalizedSegment.startsWith(normalizedCommitted)) {
      return normalizedSegment;
    }
    if (normalizedCommitted.endsWith(normalizedSegment)) {
      return normalizedCommitted;
    }

    final committedWords = normalizedCommitted.split(' ');
    final segmentWords = normalizedSegment.split(' ');
    final maxOverlap = math.min(committedWords.length, segmentWords.length);

    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      final committedSuffix =
          committedWords.sublist(committedWords.length - overlap);
      final segmentPrefix = segmentWords.sublist(0, overlap);
      if (_wordListsEqual(committedSuffix, segmentPrefix)) {
        return <String>[
          ...committedWords,
          ...segmentWords.sublist(overlap),
        ].join(' ');
      }
    }

    return '$normalizedCommitted $normalizedSegment';
  }

  bool _wordListsEqual(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var i = 0; i < left.length; i++) {
      if (left[i].toLowerCase() != right[i].toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  /// Restart Deepgram connection on failure
  void _restartDeepgramConnection() {
    if (!mounted || _disposed || _userRequestedEnd) return;
    if (_state.connectionState != ConnectionState.connected) return;

    _createTrackedTimer(const Duration(seconds: 2), () {
      if (mounted) {
        unawaited(() async {
          await _stopDeepgramStreaming();
          await _startDeepgramStreamingWithResolvedCredential(
            forceRefresh: true,
          );
        }());
      }
    });
  }

  void _handleDeepgramAudioSinkFailure(
    Object error, {
    required int generation,
    required String? sessionId,
  }) {
    if (!_isCurrentDeepgramStreamGeneration(generation, sessionId)) {
      if (kDebugMode) print('Ignored stale Deepgram audio sink error: $error');
      return;
    }
    _reportCaptionRuntimeIssue(
      code: 'audio_stream_error',
      message:
          'Субтитры временно недоступны: не удалось передать звук на распознавание.',
    );
    if (kDebugMode) print('Deepgram audio sink error: $error');
    if (_deepgramStopRequested) {
      return;
    }

    _deepgramStopRequested = true;
    _deepgramStreamGeneration++;
    unawaited(() async {
      await _stopDeepgramStreaming();
      if (_shouldRunDeepgram()) {
        await _startDeepgramStreamingWithResolvedCredential(
          forceRefresh: true,
        );
      }
    }());
  }

  Future<void> _sendDeepgramControlMessage(String type) async {
    final channel = _deepgramChannel;
    if (channel == null) return;

    try {
      channel.sink.add(dart_convert.jsonEncode({'type': type}));
    } catch (e) {
      if (kDebugMode) {
        print('Failed to send Deepgram $type control message: $e');
      }
    }
  }

  Future<void> _gracefullyCloseDeepgramStream() async {
    if (_deepgramChannel == null) return;

    await _sendDeepgramControlMessage('Finalize');
    await Future<void>.delayed(
      const Duration(milliseconds: _deepgramFinalizeWaitMs),
    );
    await _sendDeepgramControlMessage('CloseStream');
    await Future<void>.delayed(
      const Duration(milliseconds: _deepgramCloseWaitMs),
    );
    await _deepgramChannel?.sink.close();
  }

  /// Stop Deepgram streaming and cleanup resources
  Future<void> _stopDeepgramStreaming() async {
    if (!_state.isStreamingToDeepgram &&
        !_deepgramStartInProgress &&
        _recorder == null &&
        _deepgramChannel == null &&
        _audioStreamController == null) {
      await _finalizeCurrentCaptionAndFlushLogs();
      return;
    }

    // Keep accepting Deepgram result frames while Finalize drains buffered
    // audio. Normal audio/start callbacks remain disabled by stopRequested.
    _deepgramFinalizing = _deepgramChannel != null;
    _deepgramStreamGeneration++;
    _deepgramStopRequested = true;

    Future<void> runCleanupStep(
      String debugContext,
      Future<void> Function() cleanup,
    ) async {
      try {
        await cleanup();
      } catch (e) {
        if (kDebugMode) print('Error stopping Deepgram $debugContext: $e');
      }
    }

    await runCleanupStep('audio subscription', () async {
      await _cancelTrackedSubscription(_audioStreamSubscription);
    });
    _audioStreamSubscription = null;

    await runCleanupStep('recorder', () async {
      final recorder = _recorder;
      if (recorder == null) {
        return;
      }
      if (recorder.isRecording) {
        await recorder.stopRecorder();
      }
      if (_recorderOpen) {
        await recorder.closeRecorder();
      }
    });
    _recorderOpen = false;
    _recorder = null;

    await runCleanupStep('websocket', _gracefullyCloseDeepgramStream);
    _deepgramChannel = null;
    _deepgramFinalizing = false;

    await runCleanupStep('message subscription', () async {
      await _cancelTrackedSubscription(_deepgramMessageSubscription);
    });
    _deepgramMessageSubscription = null;

    await runCleanupStep('audio controller', () async {
      await _closeTrackedController(_audioStreamController);
    });
    _audioStreamController = null;

    _deepgramStartInProgress = false;
    _updateState(_state.copyWith(isStreamingToDeepgram: false));
    await _finalizeCurrentCaptionAndFlushLogs();
    _clearLocalCaptions();
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
    final transitionId = ++_lifecycleTransitionId;
    final nextTransition = _lifecycleTransitionChain
        .catchError((_) {})
        .then((_) => action(transitionId));
    _lifecycleTransitionChain = nextTransition.catchError((error) {
      if (kDebugMode) {
        print('Lifecycle transition failed: $error');
      }
    });
    return nextTransition;
  }

  bool _isCurrentLifecycleTransition(int transitionId) {
    return mounted &&
        !_disposed &&
        transitionId == _lifecycleTransitionId &&
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
      _deepgramCredential = newConfiguredDeepgramCredential;
      if (oldConfiguredDeepgramCredential == null &&
          newConfiguredDeepgramCredential != null) {
        unawaited(_syncDeepgramWithMicrophoneState(forceRefresh: true));
      }
    }
    if (oldWidget.sessionId != widget.sessionId) {
      unawaited(_stopDeepgramStreaming());
      _roomJoinMarked = false;
      _dynamicMeetingToken = null;
      _dynamicRoomUrl = null;
      _ownSentChatMessages.clear();
      _persistCallChatInFlight = false;
      _persistCallChatCompleted = false;
      _persistCallChatAttemptCount = 0;
      _sessionLimitWarningShownFor = null;
      _sessionLimitAutoEndedFor = null;
      _sessionClockOffset = null;
      _sessionExtensionRequestInFlight = false;
      _resetCallCheckpointNotice(clearHistory: true);
      _pendingCaptionLogEntries.clear();
      _persistedCaptionLogIds.clear();
      _reportedCaptionRuntimeIssueCodes.clear();
      _cancelTrackedTimer(_captionLogFlushTimer);
      _captionLogFlushTimer = null;
      _clearCaptionRuntimeIssue();
    }
    if (oldWidget.sessionExpiresAt != widget.sessionExpiresAt) {
      _sessionLimitWarningShownFor = null;
      _sessionLimitAutoEndedFor = null;
      _clearSessionLimitWarningNotice();
      if (_state.connectionState == ConnectionState.connected) {
        _setCallDurationValue(_callDurationNotifier.value);
      }
    }

    if (!_isTerminalSessionStatus(oldWidget.sessionStatus) &&
        _isTerminalSessionStatus(widget.sessionStatus)) {
      unawaited(_persistOwnCallChatMessages());
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

  void _startDurationTimer() {
    if (_callDurationStopwatch.isRunning) return;

    if (_callDurationStopwatch.elapsed == Duration.zero) {
      _setCallDurationValue(0);
    } else {
      _setCallDurationValue(_callDurationStopwatch.elapsed.inSeconds);
    }
    _callDurationStopwatch.start();

    if (_durationTimer != null) return;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _disposed) {
        return;
      }
      final elapsedSeconds = _callDurationStopwatch.elapsed.inSeconds;
      _setCallDurationValue(elapsedSeconds);
    });
    _trackTimer(_durationTimer!);
  }

  void _stopDurationTimer({bool reset = false}) {
    _cancelTrackedTimer(_durationTimer);
    _durationTimer = null;
    _setCallDurationValue(_callDurationStopwatch.elapsed.inSeconds);
    _callDurationStopwatch.stop();
    if (reset) {
      _callDurationStopwatch.reset();
      _setCallDurationValue(0);
    }
  }

  void _setCallDurationValue(int totalSeconds) {
    if (_disposed) {
      return;
    }
    if (_callDurationNotifier.value != totalSeconds) {
      _callDurationNotifier.value = totalSeconds;
    }
    if (_hasSessionLimitCountdown) {
      _maybeAutoEndAtSessionLimit();
      _maybeShowSessionLimitWarning();
    } else {
      _maybeShowCallCheckpointNotice(totalSeconds);
    }
  }

  bool get _hasSessionLimitCountdown {
    return widget.sessionExpiresAt != null &&
        widget.sessionPolicy != null &&
        widget.sessionPolicy!.isNotEmpty;
  }

  int _remainingSessionLimitSeconds([DateTime? now]) {
    return session_limit_ui.resolveSessionLimitRemainingSeconds(
      widget.sessionExpiresAt,
      now: now ?? _serverAlignedNow(),
    );
  }

  DateTime _serverAlignedNow() {
    final serverClockOffset = _sessionClockOffset;
    if (serverClockOffset != null) {
      return session_limit_ui.resolveServerAlignedNow(serverClockOffset);
    }

    final expiresAt = widget.sessionExpiresAt;
    if (expiresAt == null) {
      return DateTime.now();
    }

    final effectiveLimitSeconds =
        session_limit_ui.resolveSessionPolicyEffectiveLimitSeconds(
      widget.sessionPolicy,
    );
    final remainingSeconds = math.max(
      0,
      effectiveLimitSeconds - _callDurationStopwatch.elapsed.inSeconds,
    );
    return expiresAt.subtract(Duration(seconds: remainingSeconds));
  }

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
      if (session_limit_ui.shouldRetainAutoEndMarkerForResponseStatus(
        status,
      )) {
        // Hold the marker until Firestore delivers the new expiry/state.
        // Otherwise the local timer can spam repeated expired-end requests
        // during the extension race window.
        return;
      }
      await _persistOwnCallChatMessages();
    } catch (error) {
      _clearSessionLimitAutoEndMarker(targetExpiresAt);
      if (kDebugMode) {
        print('Session auto-end request failed: $error');
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _maybeShowCallCheckpointNotice(int totalSeconds) {
    if (_hasSessionLimitCountdown) {
      return;
    }
    if (widget.isStudent != true) {
      return;
    }

    for (final notice in _callCheckpointNotices) {
      final thresholdSeconds = notice.minutes * 60;
      if (totalSeconds >= thresholdSeconds &&
          !_shownCallCheckpointMinutes.contains(notice.minutes)) {
        _shownCallCheckpointMinutes.add(notice.minutes);
        _showCallCheckpointNotice(notice);
      }
    }
  }

  void _maybeShowSessionLimitWarning() {
    final expiresAt = widget.sessionExpiresAt;
    if (!session_limit_ui.shouldShowSessionLimitWarning(
      expiresAt: expiresAt,
      warnedForExpiresAt: _sessionLimitWarningShownFor,
      now: _serverAlignedNow(),
      warningLeadSeconds: _sessionLimitWarningLeadSeconds,
    )) {
      return;
    }

    _sessionLimitWarningShownFor = expiresAt;
  }

  void _maybeAutoEndAtSessionLimit() {
    final status = widget.sessionStatus?.trim().toLowerCase();
    if (_userRequestedEnd ||
        status == 'ended' ||
        status == 'cancelled' ||
        status == 'expired' ||
        !session_limit_ui.shouldAutoEndSession(
          expiresAt: widget.sessionExpiresAt,
          autoEndedForExpiresAt: _sessionLimitAutoEndedFor,
          now: _serverAlignedNow(),
          graceSeconds: _sessionLimitAutoEndGraceSeconds,
        )) {
      return;
    }

    _sessionLimitAutoEndedFor = widget.sessionExpiresAt;
    unawaited(_requestAutoEndAtSessionLimit());
  }

  void _clearSessionLimitAutoEndMarker(DateTime? expiresAt) {
    if (expiresAt == null) {
      _sessionLimitAutoEndedFor = null;
      return;
    }
    if (_sessionLimitAutoEndedFor?.isAtSameMomentAs(expiresAt) == true) {
      _sessionLimitAutoEndedFor = null;
    }
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
      _shownCallCheckpointMinutes.clear();
    }
  }

  /// Handle errors uniformly
  void _handleError(String context, dynamic error) {
    if (kDebugMode) print('$context: $error');

    _updateState(_state.copyWith(
      error: '$context: ${error.toString()}',
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
    } catch (e) {
      if (kDebugMode) print('Failed to end system call UI: $e');
    }
  }

  Future<void> _markRoomJoined() async {
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
          widget.sessionId?.trim() == sessionId) {
        _sessionClockOffset = serverClockOffset;
      }
    } catch (e) {
      requestStopwatch.stop();
      _roomJoinMarked = false;
      if (kDebugMode) print('Failed to mark room joined: $e');
    }
  }

  Future<void> _markSystemCallConnected() async {
    if (_systemCallMarkedConnected) return;
    if (kIsWeb) return;
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.iOS && platform != TargetPlatform.android) {
      return;
    }
    try {
      await VoIPService()
          .markCallConnected(sessionId: widget.sessionId?.trim());
      _systemCallMarkedConnected = true;
    } catch (e) {
      if (kDebugMode) print('Failed to mark system call connected: $e');
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

  void _trackTimer(Timer timer) {
    _activeTimers.add(timer);
  }

  void _cancelTrackedTimer(Timer? timer) {
    if (timer == null) return;
    timer.cancel();
    _activeTimers.remove(timer);
  }

  /// Track subscription for cleanup
  T _trackSubscription<T extends StreamSubscription>(T subscription) {
    _activeSubscriptions.add(subscription);
    return subscription;
  }

  Future<void> _cancelTrackedSubscription(
    StreamSubscription? subscription,
  ) async {
    if (subscription == null) return;
    try {
      await subscription.cancel();
    } finally {
      _activeSubscriptions.remove(subscription);
    }
  }

  /// Track controller for cleanup
  void _trackController(StreamController controller) {
    _activeControllers.add(controller);
  }

  Future<void> _closeTrackedController(StreamController? controller) async {
    if (controller == null) return;
    try {
      await controller.close();
    } finally {
      _activeControllers.remove(controller);
    }
  }

  Future<void> _setVideoTrack(
    VideoViewController? controller,
    MediaStreamTrack? track, {
    required String debugContext,
  }) async {
    if (controller == null) return;
    try {
      await controller.setTrack(track);
    } catch (e) {
      if (kDebugMode) print('$debugContext: $e');
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
    } catch (e) {
      if (kDebugMode) print('$debugContext: $e');
    }
  }

  /// COMPLETE BUILD METHOD REPLACEMENT - This should fix the error
  @override
  Widget build(BuildContext context) {
    // Show waiting screen if room URL invalid
    if (!_isValidRoomUrl(widget.roomUrl)) {
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
              if (_state.connectionState == ConnectionState.connected)
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
                  child: _buildErrorDisplay(),
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

    return isStudent
        ? 'Ожидаем подключение собеседника...'
        : 'Ожидаем подключение студента...';
  }

  Widget _buildPrimaryVideo({bool? showRemoteParticipant}) {
    if (showRemoteParticipant ?? _state.remoteControllers.isNotEmpty) {
      return _buildRemoteVideo();
    }
    return _buildLocalFullScreen();
  }

  Widget _buildCallDurationBadge() {
    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: _callDurationNotifier,
        builder: (context, totalSeconds, _) {
          final hasCountdown = _hasSessionLimitCountdown;
          final remainingSeconds = _remainingSessionLimitSeconds();
          final displaySeconds = hasCountdown ? remainingSeconds : totalSeconds;
          final isWarning = hasCountdown &&
              remainingSeconds > 0 &&
              remainingSeconds <= _sessionLimitWarningLeadSeconds;
          final accentColor =
              isWarning ? const Color(0xFFFFB020) : Colors.white;

          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ExpatlioDesign.space12,
              vertical: ExpatlioDesign.space8,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: isWarning ? 0.68 : 0.45),
              borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
              border: hasCountdown
                  ? Border.all(
                      color: accentColor.withValues(alpha: 0.44),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasCountdown) ...[
                  Icon(
                    Icons.timer_outlined,
                    color: accentColor,
                    size: 16,
                  ),
                  const SizedBox(width: ExpatlioDesign.space8),
                ],
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDuration(displaySeconds),
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        height: 1.0,
                      ),
                    ),
                    if (hasCountdown) ...[
                      const SizedBox(height: ExpatlioDesign.space4),
                      Text(
                        isWarning ? 'Осталась 1 минута до лимита' : 'до лимита',
                        style: TextStyle(
                          color: (isWarning ? accentColor : Colors.white)
                              .withValues(alpha: isWarning ? 0.95 : 0.72),
                          fontSize: 11.0,
                          fontWeight:
                              isWarning ? FontWeight.w600 : FontWeight.w500,
                          letterSpacing: 0.2,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
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
    } catch (e) {
      if (kDebugMode) print('Error building local video: $e');
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
    } catch (e) {
      if (kDebugMode) print('Error building remote video: $e');
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
    if (_state.connectionState != ConnectionState.connected) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: _state.cameraEnabled ? Icons.videocam : Icons.videocam_off,
          isActive: _state.cameraEnabled,
          tooltip:
              _state.cameraEnabled ? 'Выключить камеру' : 'Включить камеру',
          semanticLabel: _state.cameraEnabled
              ? 'Камера включена. Выключить камеру'
              : 'Камера выключена. Включить камеру',
          semanticHint: 'Переключает камеру в звонке',
          semanticToggled: _state.cameraEnabled,
          onPressed: () => _updateInputSettings(camera: !_state.cameraEnabled),
          isEndCall: false,
        ),
        _buildControlButton(
          icon: _state.microphoneEnabled ? Icons.mic : Icons.mic_off,
          isActive: _state.microphoneEnabled,
          tooltip: _state.microphoneEnabled
              ? 'Выключить микрофон'
              : 'Включить микрофон',
          semanticLabel: _state.microphoneEnabled
              ? 'Микрофон включен. Выключить микрофон'
              : 'Микрофон выключен. Включить микрофон',
          semanticHint: 'Переключает микрофон в звонке',
          semanticToggled: _state.microphoneEnabled,
          onPressed: () =>
              _updateInputSettings(microphone: !_state.microphoneEnabled),
          isEndCall: false,
        ),
        _buildControlButton(
          icon:
              _state.isChatOpen ? Icons.chat_bubble : Icons.chat_bubble_outline,
          isActive: _state.isChatOpen,
          tooltip: _chatControlTooltip(),
          semanticLabel: _chatControlSemanticLabel(),
          semanticHint: 'Открывает или скрывает чат звонка',
          semanticToggled: _state.isChatOpen,
          onPressed: _toggleChatOpen,
          isEndCall: false,
          badgeCount: _state.unreadChatCount,
        ),
        _buildControlButton(
          icon: Icons.call_end,
          isActive: true,
          tooltip: 'Завершить звонок',
          semanticLabel: 'Завершить звонок',
          semanticHint: 'Завершает текущий видеозвонок',
          onPressed: () => _endCall(endReason: 'user_ended'),
          isEndCall: true,
        ),
      ],
    );
  }

  /// Build control button - FIXED
  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required String tooltip,
    required String semanticLabel,
    required VoidCallback onPressed,
    required bool isEndCall,
    String? semanticHint,
    bool? semanticToggled,
    int badgeCount = 0,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isEndCall
                ? Colors.red.withValues(alpha: 0.9)
                : (isActive
                    ? Colors.black.withValues(alpha: 0.76)
                    : Colors.black.withValues(alpha: 0.6)),
            shape: BoxShape.circle,
            border: isEndCall
                ? null
                : Border.all(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
          ),
          child: Semantics(
            container: true,
            button: true,
            enabled: true,
            label: semanticLabel,
            hint: semanticHint,
            toggled: semanticToggled,
            onTap: onPressed,
            child: Tooltip(
              message: tooltip,
              excludeFromSemantics: true,
              child: ExcludeSemantics(
                child: IconButton(
                  icon: Icon(icon, color: Colors.white),
                  onPressed: onPressed,
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: ExcludeSemantics(
              child: _buildUnreadBadge(badgeCount),
            ),
          ),
      ],
    );
  }

  String _chatControlTooltip() {
    final unreadCount = _state.unreadChatCount;
    final baseLabel = _state.isChatOpen ? 'Закрыть чат' : 'Открыть чат';

    if (!_state.isChatOpen && unreadCount > 0) {
      return '$baseLabel, ${_unreadMessagesSemanticLabel(unreadCount)}';
    }

    return baseLabel;
  }

  String _chatControlSemanticLabel() {
    if (_state.isChatOpen) {
      return 'Чат открыт. Закрыть чат';
    }
    if (_state.unreadChatCount > 0) {
      return 'Чат закрыт. Открыть чат. '
          '${_unreadMessagesSemanticLabel(_state.unreadChatCount)}';
    }
    return 'Чат закрыт. Открыть чат';
  }

  String _formatUnreadChatCount(int count) {
    return count > 99 ? '99+' : count.toString();
  }

  String _unreadMessagesSemanticLabel(int count) {
    if (count > 99) {
      return 'Больше 99 непрочитанных сообщений';
    }
    return 'Непрочитанных сообщений: ${_formatUnreadChatCount(count)}';
  }

  Widget _buildUnreadBadge(int count) {
    final label = _formatUnreadChatCount(count);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ExpatlioDesign.space8, vertical: ExpatlioDesign.space4),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF2F80ED),
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusSmall),
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
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
          isSending: _isSendingChatMessage,
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
  Widget _buildErrorDisplay() {
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
            const SizedBox(height: ExpatlioDesign.space16),
            ElevatedButton(
              onPressed: () {
                _updateState(_state.copyWith(retryCount: 0));
                _performReconnection();
              },
              child: const Text('Повторить попытку'),
            ),
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
    } catch (e) {
      if (kDebugMode) print('End call callback failed: $e');
      if (mounted && !_disposed) {
        context.safePop();
      }
    }
  }

  /// Cleanup all resources - proper order to prevent crashes:
  /// 1. Cancel timers (stop pending operations)
  /// 2. Cancel event subscription FIRST (prevents CallState.left from
  ///    triggering _scheduleReconnection during cleanup)
  /// 3. Disable local camera/microphone capture
  /// 4. Stop Deepgram
  /// 5. Leave call (signal server while connection still alive)
  /// 6. Cancel remaining subscriptions
  /// 7. Clear tracks and dispose video controllers
  /// 8. Dispose CallClient
  ///
  /// NOTE: _userRequestedEnd is NOT reset here. It is only set by _endCall()
  /// and reset by _initializeCall() when starting a new session.
  Future<void> _cleanup({
    bool leaveCall = true,
    bool preserveMeetingToken = false,
    bool preserveTokenRefreshAttempts = false,
    bool preserveChatState = false,
  }) async {
    if (kDebugMode) print('Cleaning up resources...');

    final preservedChatMessages =
        preserveChatState ? _state.chatMessages : const <_ChatMessage>[];
    final preservedUnreadChatCount =
        preserveChatState ? _state.unreadChatCount : 0;
    final preservedChatOpen = preserveChatState ? _state.isChatOpen : false;

    try {
      _lifecycleTransitionId += 1;
      _chatFocusNode.unfocus();
      if (!preserveChatState) {
        _chatTextController.clear();
      }

      // 1. Cancel all timers first (stop any pending reconnects, retries, etc.)
      for (final timer in List<Timer>.from(_activeTimers)) {
        _cancelTrackedTimer(timer);
      }
      _cancelTrackedTimer(_remoteLeftTimer);
      _remoteLeftTimer = null;
      _remoteLeftNotified = false;

      // 2. Cancel event subscription BEFORE leave() so that the
      // CallState.left event does not trigger _scheduleReconnection.
      try {
        await _cancelTrackedSubscription(_eventSubscription);
        _eventSubscription = null;
      } catch (e) {
        if (kDebugMode) print('Error cancelling event subscription: $e');
      }

      // 3. Disable local capture before leaving so iOS releases the
      // camera/microphone indicator even if leave/dispose completes later.
      await _disableLocalInputsForCleanup();

      // 4. Stop Deepgram streaming
      await _stopDeepgramStreaming();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await _flushPendingCaptionLogs(force: true);

      // 5. Leave call while connection is still alive
      if (_callClient != null && leaveCall) {
        try {
          await _callClient!.leave();
          // Brief wait for leave signal to be sent over WebSocket
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          if (kDebugMode) print('Error leaving call: $e');
        }
      }

      // 6. Cancel all remaining tracked subscriptions
      for (final subscription in List<StreamSubscription>.from(
        _activeSubscriptions,
      )) {
        try {
          await _cancelTrackedSubscription(subscription);
        } catch (e) {
          if (kDebugMode) print('Error cancelling subscription: $e');
        }
      }

      // 7. Clear video tracks before disposing controllers
      await _setVideoTrack(
        _localVideoController,
        null,
        debugContext: 'Error clearing local video track',
      );
      for (final controller in _state.remoteControllers.values) {
        await _setVideoTrack(
          controller,
          null,
          debugContext: 'Error clearing remote video track',
        );
      }

      // Dispose video controllers
      try {
        _localVideoController?.dispose();
        _localVideoController = null;
      } catch (e) {
        if (kDebugMode) print('Error disposing local video controller: $e');
      }

      for (final controller in _state.remoteControllers.values) {
        try {
          controller.dispose();
        } catch (e) {
          if (kDebugMode) print('Error disposing remote video controller: $e');
        }
      }
      _remoteJoinTimes.clear();
      _remoteTrackReady.clear();
      _remoteCaptionClearGenerations.clear();
      _remoteLegacyCaptionCounters.clear();
      _remoteParticipantUiSignatures.clear();
      _prioritySubscribedParticipants.clear();
      _activeRemoteProfileConfigured = false;
      _systemCallMarkedConnected = false;
      _invalidateLocalCaptionClear();
      if (!preserveMeetingToken) {
        _dynamicMeetingToken = null;
        _dynamicRoomUrl = null;
      }
      if (!preserveTokenRefreshAttempts) {
        _tokenRefreshAttempts = 0;
      }
      _stopDurationTimer(reset: true);
      _resetCallCheckpointNotice();

      // 8. Dispose call client last
      final callClientToDispose = _callClient;
      try {
        await callClientToDispose?.dispose();
        _callClient = null;
      } catch (e) {
        if (kDebugMode) print('Error disposing call client: $e');
      }
      _releaseProcessActiveCallClient(callClientToDispose);

      // Close all stream controllers
      for (final controller
          in List<StreamController>.from(_activeControllers)) {
        try {
          await _closeTrackedController(controller);
        } catch (e) {
          if (kDebugMode) print('Error closing controller: $e');
        }
      }

      // Reset state
      if (mounted && !_disposed) {
        _updateState(_CallState(
          isChatOpen: preservedChatOpen,
          unreadChatCount: preservedUnreadChatCount,
          chatMessages: preservedChatMessages,
        ));
      }

      if (kDebugMode) print('Cleanup completed');
    } catch (e) {
      if (kDebugMode) print('Cleanup error: $e');
    }
  }

  @override
  void dispose() {
    if (kDebugMode) print('Disposing widget...');

    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);

    // End the native call UI (CallKit / ConnectionService) as a safety net.
    // This covers cases where the widget is disposed before participantLeft
    // fires (e.g. Firestore status-driven navigation).
    unawaited(_endSystemCallUi());
    unawaited(_persistOwnCallChatMessages());

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

    // Cancel event subscription synchronously to stop incoming events
    unawaited(_cancelTrackedSubscription(_eventSubscription));
    _eventSubscription = null;

    // Schedule async cleanup (leave call, dispose client)
    unawaited(_cleanup(leaveCall: true).whenComplete(() {
      _chatTextController.dispose();
      _chatFocusNode.dispose();
      _chatScrollController.dispose();
    }));

    super.dispose();
  }
}
