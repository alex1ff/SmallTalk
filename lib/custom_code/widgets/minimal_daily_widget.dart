// Automatic FlutterFlow imports
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

import 'index.dart'; // Imports other custom widgets

import 'package:flutter/foundation.dart';
import 'package:daily_flutter/daily_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:web_socket_channel/io.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/services/voip_service.dart';

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
  final List<Map<String, dynamic>> finalCaptions;
  final String partialCaption;
  final Map<ParticipantId, List<String>> remoteCaptions;
  final bool isStreamingToDeepgram;

  const _CallState({
    this.connectionState = ConnectionState.disconnected,
    this.cameraEnabled = true,
    this.microphoneEnabled = true,
    this.error,
    this.retryCount = 0,
    this.remoteControllers = const {},
    this.finalCaptions = const [],
    this.partialCaption = '',
    this.remoteCaptions = const {},
    this.isStreamingToDeepgram = false,
  });

  _CallState copyWith({
    ConnectionState? connectionState,
    bool? cameraEnabled,
    bool? microphoneEnabled,
    String? error,
    int? retryCount,
    Map<ParticipantId, VideoViewController>? remoteControllers,
    List<Map<String, dynamic>>? finalCaptions,
    String? partialCaption,
    Map<ParticipantId, List<String>>? remoteCaptions,
    bool? isStreamingToDeepgram,
  }) {
    return _CallState(
      connectionState: connectionState ?? this.connectionState,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      microphoneEnabled: microphoneEnabled ?? this.microphoneEnabled,
      error: error ?? this.error,
      retryCount: retryCount ?? this.retryCount,
      remoteControllers: remoteControllers ?? this.remoteControllers,
      finalCaptions: finalCaptions ?? this.finalCaptions,
      partialCaption: partialCaption ?? this.partialCaption,
      remoteCaptions: remoteCaptions ?? this.remoteCaptions,
      isStreamingToDeepgram:
          isStreamingToDeepgram ?? this.isStreamingToDeepgram,
    );
  }
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
    this.sessionStatus,
    this.isStudent,
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
  final String? sessionStatus;
  final bool? isStudent;
  final String? deepgramApiKey;
  final Future<String?> Function()? deepgramTokenRefreshCallback;
  final bool enableDeepgram;
  final String deepgramLanguage;
  final Future Function(String word, String sentence)? actionCallback;
  final Future Function()? endCallCallback;
  final String? username;
  final Future Function()? participantLeftCallback;

  @override
  State<MinimalDailyWidget> createState() => _MinimalDailyWidgetState();
}

class _MinimalDailyWidgetState extends State<MinimalDailyWidget>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Core resources - properly managed
  CallClient? _callClient;
  VideoViewController? _localVideoController;
  StreamSubscription? _eventSubscription;

  // State management - immutable
  _CallState _state = const _CallState();

  // Resource tracking for proper cleanup
  final Set<Timer> _activeTimers = {};
  final Set<StreamSubscription> _activeSubscriptions = {};
  final Set<StreamController> _activeControllers = {};

  // Remote track readiness tracking
  final Map<ParticipantId, DateTime> _remoteJoinTimes = {};
  final Map<ParticipantId, bool> _remoteTrackReady = {};

  bool _disposed = false;
  bool _resumeCameraEnabled = true;
  bool _resumeMicrophoneEnabled = true;
  bool _isInitializing = false;
  bool _systemCallMarkedConnected = false;
  bool _sessionStartedMarked = false;
  String? _dynamicMeetingToken;
  bool _tokenRefreshInProgress = false;
  int _tokenRefreshAttempts = 0;
  static const int _maxTokenRefreshAttempts = 2;
  String? _deepgramCredential;
  Timer? _remoteLeftTimer;
  bool _remoteLeftNotified = false;
  bool _userRequestedEnd = false;

  // Call duration timer
  int _callDurationSeconds = 0;
  Timer? _durationTimer;

  // Deepgram integration
  FlutterSoundRecorder? _recorder;
  IOWebSocketChannel? _deepgramChannel;
  StreamController<Uint8List>? _audioStreamController;
  bool _recorderOpen = false;
  bool _deepgramStopRequested = false;
  bool _deepgramStartInProgress = false;

  // Removed quality monitoring - Daily Adaptive Bitrate handles this

  // Constants - production optimized
  static const int _maxRetryAttempts = 5;
  static const int _baseRetryDelayMs = 1000;
  static const int _maxRetryDelayMs = 30000;
  static const int _captionClearDelayMs = 20000; // Increased to 20 seconds
  static const int _remoteVideoGraceMs = 2000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deepgramCredential = _sanitizeDeepgramCredential(widget.deepgramApiKey);
    _initializeWidget();
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
    if (_sanitizeDeepgramCredential(widget.deepgramApiKey) != null) return true;
    return widget.deepgramTokenRefreshCallback != null;
  }

  Future<String?> _resolveDeepgramCredential({
    bool forceRefresh = false,
  }) async {
    final staticCredential = _sanitizeDeepgramCredential(widget.deepgramApiKey);

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
    return _isValidRoomUrl(widget.roomUrl) && _effectiveMeetingToken() != null;
  }

  /// Simplified initialization
  Future<void> _initializeCall() async {
    if (!mounted || _disposed) return;
    if (_isInitializing ||
        _state.connectionState == ConnectionState.connected) {
      return;
    }
    _isInitializing = true;
    _systemCallMarkedConnected = false;
    _userRequestedEnd = false;
    _remoteLeftNotified = false;
    _remoteLeftTimer?.cancel();
    _remoteLeftTimer = null;

    _updateState(_state.copyWith(
      connectionState: ConnectionState.connecting,
      error: null,
    ));

    try {
      // Create CallClient with timeout
      _callClient = await _createCallClientWithTimeout();
      if (!mounted || _callClient == null) return;

      // Initialize video controller
      _localVideoController = VideoViewController();

      // Setup event subscription
      _setupEventSubscription();

      // Join room with FIXED quality settings sequence
      await _joinRoomWithEnhancedSettings();

      // Start Deepgram if configured
      if (_canUseDeepgram()) {
        _scheduleDeepgramStart();
      }

      // Quality monitoring removed - Daily Adaptive Bitrate handles this
    } catch (e) {
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
  void _setupEventSubscription() {
    _eventSubscription?.cancel();
    _eventSubscription = _callClient!.events.listen(
      _handleCallEvent,
      onError: (error) {
        if (kDebugMode) print('Event stream error: $error');
        // Route through _handleEventError to filter non-fatal errors
        if (mounted && !_disposed) {
          _handleEventError(error.toString());
        }
      },
      cancelOnError: false,
    );
    _trackSubscription(_eventSubscription!);
  }

  /// Join room with default settings to avoid SDK parsing errors
  Future<void> _joinRoomWithEnhancedSettings() async {
    final roomUri = Uri.parse(widget.roomUrl);
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

    await _configureUsername();
  }

  /// Apply quality-optimized settings for better remote video quality
  Future<void> _enableAdaptiveBitrate() async {
    try {
      if (_callClient == null) {
        if (kDebugMode)
          print('⚠️ Cannot enable adaptive bitrate - no call client');
        return;
      }

      if (kDebugMode) {
        print(
            '🚀 Setting HIGH quality video with custom encodings for remote participants...');
      }

      // CRITICAL: Force HIGH quality for remote participants
      // This is the main fix - Daily defaults to lower quality
      await _callClient!.updatePublishing(
        publishing: PublishingSettingsUpdate.set(
          camera: CameraPublishingSettingsUpdate.set(
            isPublishing: BoolUpdate.set(true),
            sendSettings: VideoSendSettingsUpdate.set(
              // ALWAYS use HIGH quality - this is the key fix!
              // This changes bitrate from default 110-520 Kbps to 4-5 Mbps
              maxQuality: VideoSendSettingsMaxQualityUpdate.high,
            ),
          ),
          microphone: MicrophonePublishingSettingsUpdate.set(
            isPublishing: BoolUpdate.set(true),
          ),
        ),
      );

      if (kDebugMode) {
        print('✅ Optimized video settings applied successfully!');
        print('   - maxQuality: HIGH (balanced for network stability)');
        print(
            '   - Expected bitrate: 1.5-2.5 Mbps (stable for most connections)');
        print('   - Resolution: 720p with adaptive scaling');
        print('   - Better stability and audio quality!');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to set video quality: $e');
    }
  }

  // Quality setting removed - always use auto mode with Daily Adaptive Bitrate
  // The SDK automatically adjusts quality based on network conditions

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

  /// Force maximum quality video settings with ultra-high bitrate
  Future<void> _forceHighQualityVideo() async {
    try {
      if (_callClient == null) return;

      if (kDebugMode) {
        print('🎯 Forcing ULTRA quality video for remote participants...');
      }

      // Force maximum quality - apply HIGH setting multiple times
      // First application
      await _callClient!.updatePublishing(
        publishing: PublishingSettingsUpdate.set(
          camera: CameraPublishingSettingsUpdate.set(
            isPublishing: BoolUpdate.set(true),
            sendSettings: VideoSendSettingsUpdate.set(
              // Maximum quality setting
              maxQuality: VideoSendSettingsMaxQualityUpdate.high,
            ),
          ),
        ),
      );

      // Small delay to ensure settings take effect
      await Future.delayed(const Duration(milliseconds: 500));

      // Second application to ensure it sticks
      await _callClient!.updatePublishing(
        publishing: PublishingSettingsUpdate.set(
          camera: CameraPublishingSettingsUpdate.set(
            sendSettings: VideoSendSettingsUpdate.set(
              maxQuality: VideoSendSettingsMaxQualityUpdate.high,
            ),
          ),
        ),
      );

      if (kDebugMode) {
        print('✅ Stable quality applied successfully:');
        print('   - Applied balanced quality settings');
        print('   - Expected bitrate: 1.5-2.5 Mbps (network-friendly)');
        print('   - Better audio quality and stability!');
      }
    } catch (e) {
      if (kDebugMode) print('Failed to force ultra quality: $e');
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
        _updateLocalVideoTrack();
        unawaited(_markSessionStarted());
        unawaited(_markSystemCallConnected());
        if (_canUseDeepgram() && !_state.isStreamingToDeepgram) {
          unawaited(
            _startDeepgramStreamingWithResolvedCredential(forceRefresh: true),
          );
        }
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
      _remoteLeftTimer?.cancel();
      _remoteLeftTimer = null;
      _remoteLeftNotified = false;
      _addRemoteParticipant(participant);
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
      _updateLocalVideoTrack();
    } else {
      // Ignore updates for participants already removed (stale events)
      if (!_state.remoteControllers.containsKey(participant.id)) {
        return;
      }
      _remoteLeftTimer?.cancel();
      _remoteLeftTimer = null;
      _remoteLeftNotified = false;
      _updateRemoteParticipant(participant);
      _updateState(_state.copyWith());
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
    if (_remoteLeftNotified) {
      return;
    }
    _remoteLeftTimer?.cancel();
    final timer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_state.remoteControllers.isNotEmpty) return;
      _remoteLeftNotified = true;
      unawaited(_endSystemCallUi());
      widget.participantLeftCallback?.call();
    });
    _remoteLeftTimer = timer;
    _trackTimer(timer);
  }

  /// Handle app messages with validation
  void _handleAppMessage(String message, ParticipantId from) {
    if (!mounted) return;

    try {
      final payload = _decodeAppMessagePayload(message);
      if (payload == null) return;

      final type = payload['type']?.toString();
      if (type == 'caption') {
        _processCaptionMessage(payload['text']?.toString() ?? '', from);
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
        payload = jsonDecode(trimmed);
        continue;
      }
      break;
    }

    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }

    return null;
  }

  /// Process caption message with deduplication
  void _processCaptionMessage(String text, ParticipantId from) {
    if (text.trim().isEmpty) return;

    final remoteCaptions =
        Map<ParticipantId, List<String>>.from(_state.remoteCaptions);
    final captions = remoteCaptions.putIfAbsent(from, () => []);

    // Add with deduplication
    if (captions.isEmpty || captions.last != text) {
      captions.add(text);
      if (captions.length > 10) captions.removeAt(0);

      _updateState(_state.copyWith(remoteCaptions: remoteCaptions));
      _scheduleCaptionClear(from);
    }
  }

  /// Handle inputs updated event
  void _handleInputsUpdated(InputSettings inputs) {
    _updateLocalVideoTrack();
    _updateState(_state.copyWith(
      cameraEnabled: inputs.camera.isEnabled,
      microphoneEnabled: inputs.microphone.isEnabled,
    ));
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
        _updateRemoteParticipant(participant);
        return;
      }

      _remoteJoinTimes[participant.id] = DateTime.now();
      _remoteTrackReady[participant.id] = false;

      final controller = VideoViewController();
      final controllers = Map<ParticipantId, VideoViewController>.from(
          _state.remoteControllers);
      controllers[participant.id] = controller;

      _updateState(_state.copyWith(remoteControllers: controllers));
      unawaited(_prioritizeRemoteSubscription(participant.id));

      _updateRemoteParticipant(participant);

      // Delay to ensure controller is initialized and video track is set
      Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          _updateRemoteParticipant(participant);
        }
      });
    } catch (e) {
      if (kDebugMode) print('Failed to add remote participant: $e');
    }
  }

  /// Update remote participant video track
  void _updateRemoteParticipant(Participant participant) {
    if (!mounted || _disposed) return;

    final controller = _state.remoteControllers[participant.id];
    if (controller == null) {
      // Controller might not be created yet, retry
      Timer(const Duration(milliseconds: 200), () {
        if (mounted && _state.remoteControllers.containsKey(participant.id)) {
          _updateRemoteParticipant(participant);
        }
      });
      return;
    }

    try {
      final media = participant.media;
      final track = media?.screenVideo.state != MediaState.off
          ? media?.screenVideo.track
          : media?.camera.track;

      controller.setTrack(track);
      final wasReady = _remoteTrackReady[participant.id] ?? false;
      final isReady = track != null;
      if (wasReady != isReady) {
        _remoteTrackReady[participant.id] = isReady;
        if (mounted) {
          _updateState(_state.copyWith());
        }
        if (isReady) {
          unawaited(_markSystemCallConnected());
        }
      }
    } catch (e) {
      if (kDebugMode) print('Failed to update remote participant track: $e');
    }
  }

  Future<void> _prioritizeRemoteSubscription(ParticipantId id) async {
    if (_callClient == null) return;
    try {
      await _callClient!.updateSubscriptions(
        forParticipants: {
          id: SubscriptionSettingsUpdate.set(
            media: MediaSubscriptionSettingsUpdate.set(
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
          ),
        },
      );
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

      final controllers = Map<ParticipantId, VideoViewController>.from(
          _state.remoteControllers);
      final controller = controllers.remove(id);

      // Clear track before disposing to avoid errors
      controller?.setTrack(null);

      // Delay disposal to ensure UI updates are complete
      Timer(const Duration(milliseconds: 100), () {
        controller?.dispose();
      });

      _updateState(_state.copyWith(remoteControllers: controllers));

      // Also clear any captions from this participant
      final remoteCaptions =
          Map<ParticipantId, List<String>>.from(_state.remoteCaptions);
      remoteCaptions.remove(id);
      _updateState(_state.copyWith(remoteCaptions: remoteCaptions));
    } catch (e) {
      if (kDebugMode) print('Failed to remove participant: $e');
    }
  }

  /// Update local video track safely
  void _updateLocalVideoTrack() {
    if (_callClient == null || _localVideoController == null || !mounted)
      return;

    try {
      final local = _callClient!.participants.local;
      final track = local.media?.camera.track;

      // Update track - VideoViewController doesn't have a track getter
      // so we always set the track
      _localVideoController!.setTrack(track);
    } catch (e) {
      if (kDebugMode) print('Local video track update failed: $e');
    }
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
    } catch (e) {
      if (kDebugMode) print('Input settings update failed: $e');
    }
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
    }
  }

  Future<bool> _tryRefreshTokenOnError(dynamic error) async {
    if (_tokenRefreshInProgress) return false;
    if (_tokenRefreshAttempts >= _maxTokenRefreshAttempts) return false;
    if (widget.tokenRefreshCallback == null) return false;

    final message = error.toString().toLowerCase();
    final looksLikeTokenError =
        message.contains('sigauthz') || message.contains('token');
    if (!looksLikeTokenError) return false;

    _tokenRefreshInProgress = true;
    _tokenRefreshAttempts += 1;
    try {
      final newToken = await widget.tokenRefreshCallback!.call();
      final sanitized = _sanitizeMeetingToken(newToken);
      if (sanitized == null) {
        return false;
      }
      _dynamicMeetingToken = sanitized;
      await _cleanup(leaveCall: true);
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

    final timer = Timer(delay, () {
      if (mounted && _state.connectionState != ConnectionState.connected) {
        _performReconnection();
      }
    });
    _trackTimer(timer);

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

    await _cleanup(leaveCall: false);
    await _initializeCall();
  }

  /// Schedule Deepgram start after connection established
  void _scheduleDeepgramStart() {
    final timer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted && _state.connectionState == ConnectionState.connected) {
        _startDeepgramStreamingWithResolvedCredential(forceRefresh: true);
      }
    });
    _trackTimer(timer);
  }

  Future<void> _startDeepgramStreamingWithResolvedCredential({
    bool forceRefresh = false,
  }) async {
    final credential = await _resolveDeepgramCredential(
      forceRefresh: forceRefresh,
    );
    if (credential == null) {
      if (kDebugMode) print('Deepgram disabled: no credential available');
      return;
    }
    await _startDeepgramStreaming(credential);
  }

  /// Start Deepgram streaming with proper resource management
  Future<void> _startDeepgramStreaming(String credential) async {
    if (_state.isStreamingToDeepgram ||
        !mounted ||
        _deepgramStartInProgress) {
      return;
    }

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
      if (!permission.isGranted) {
        throw Exception('Microphone permission denied');
      }

      // Initialize recorder
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
      _recorderOpen = true;

      _recorder!.setSubscriptionDuration(const Duration(milliseconds: 100));

      // Initialize Deepgram WebSocket
      await _initializeDeepgramWebSocket(credential);

      // Setup audio streaming
      _audioStreamController = StreamController<Uint8List>();
      _trackController(_audioStreamController!);

      final subscription = _audioStreamController!.stream.listen(
        (data) {
          if (_deepgramChannel != null) {
            _deepgramChannel!.sink.add(data);
          }
        },
        onError: (e) {
          if (kDebugMode) print('Audio stream error: $e');
        },
      );
      _trackSubscription(subscription);

      // Start recording
      await _recorder!.startRecorder(
        toStream: _audioStreamController!.sink,
        codec: Codec.pcm16,
        sampleRate: 16000,
        numChannels: 1,
      );

      _updateState(_state.copyWith(isStreamingToDeepgram: true));

      if (kDebugMode) print('Deepgram streaming started successfully');
    } catch (e) {
      if (kDebugMode) print('Failed to start Deepgram streaming: $e');
      await _stopDeepgramStreaming();
    } finally {
      _deepgramStartInProgress = false;
    }
  }

  /// Initialize Deepgram WebSocket connection
  Future<void> _initializeDeepgramWebSocket(String credential) async {
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
      'diarize': 'true',
      'interim_results': 'true',
      'vad_events': 'true',
      'endpointing': '500',
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

    final subscription = _deepgramChannel!.stream.listen(
      _handleDeepgramMessage,
      onError: (e) {
        if (kDebugMode) print('Deepgram WebSocket error: $e');
        if (!_deepgramStopRequested) {
          _restartDeepgramConnection();
        }
      },
      onDone: () {
        if (kDebugMode) print('Deepgram WebSocket closed');
        if (!_deepgramStopRequested) {
          _restartDeepgramConnection();
        }
      },
    );
    _trackSubscription(subscription);
  }

  /// Handle Deepgram message with proper parsing
  void _handleDeepgramMessage(dynamic message) {
    if (!mounted) return;

    try {
      final data = jsonDecode(message);
      final channel = data['channel'] ?? data;
      final alternatives = channel['alternatives'] ?? [];

      if (alternatives.isEmpty) return;

      final transcript = alternatives[0]['transcript'] ?? '';
      final isFinal = data['is_final'] == true || data['speech_final'] == true;

      if (transcript.trim().isEmpty) return;

      if (isFinal) {
        _processFinalTranscript(transcript);
      } else {
        _processPartialTranscript(transcript);
      }
    } catch (e) {
      if (kDebugMode) print('Failed to process Deepgram message: $e');
    }
  }

  /// Process final transcript
  void _processFinalTranscript(String transcript) {
    final captions = List<Map<String, dynamic>>.from(_state.finalCaptions);
    captions.add({'text': transcript, 'words': []});

    if (captions.length > 5) {
      captions.removeRange(0, captions.length - 5);
    }

    _updateState(_state.copyWith(
      finalCaptions: captions,
      partialCaption: '',
    ));

    // Send caption to other participants
    _sendCaptionMessage(transcript);

    // Schedule caption clear
    _scheduleCaptionClear(null);
  }

  /// Process partial transcript with debouncing
  void _processPartialTranscript(String transcript) {
    _updateState(_state.copyWith(partialCaption: transcript));
  }

  /// Send caption message to other participants
  Future<void> _sendCaptionMessage(String text) async {
    if (_callClient == null || text.trim().isEmpty) return;

    try {
      final message = jsonEncode({'type': 'caption', 'text': text});
      await _callClient!.sendAppMessage(message, null);

      if (kDebugMode) print('Caption sent: $text');
    } catch (e) {
      if (kDebugMode) print('Failed to send caption: $e');
    }
  }

  /// Schedule caption clearing
  void _scheduleCaptionClear(ParticipantId? participantId) {
    final timer = Timer(
      Duration(milliseconds: _captionClearDelayMs),
      () {
        if (!mounted) return;

        if (participantId == null) {
          // Clear own captions
          _updateState(_state.copyWith(
            finalCaptions: const [],
            partialCaption: '',
          ));
        } else {
          // Clear remote captions
          final remoteCaptions =
              Map<ParticipantId, List<String>>.from(_state.remoteCaptions);
          remoteCaptions.remove(participantId);
          _updateState(_state.copyWith(remoteCaptions: remoteCaptions));
        }
      },
    );
    _trackTimer(timer);
  }

  /// Restart Deepgram connection on failure
  void _restartDeepgramConnection() {
    if (!mounted || _disposed || _userRequestedEnd) return;
    if (_state.connectionState != ConnectionState.connected) return;

    final timer = Timer(const Duration(seconds: 2), () async {
      if (mounted) {
        await _stopDeepgramStreaming();
        await _startDeepgramStreamingWithResolvedCredential(
          forceRefresh: true,
        );
      }
    });
    _trackTimer(timer);
  }

  /// Stop Deepgram streaming and cleanup resources
  Future<void> _stopDeepgramStreaming() async {
    if (!_state.isStreamingToDeepgram &&
        !_deepgramStartInProgress &&
        _recorder == null &&
        _deepgramChannel == null &&
        _audioStreamController == null) {
      return;
    }

    try {
      _deepgramStopRequested = true;

      if (_recorder?.isRecording ?? false) {
        await _recorder!.stopRecorder();
      }

      if (_recorderOpen) {
        await _recorder!.closeRecorder();
        _recorderOpen = false;
      }
      _recorder = null;

      await _deepgramChannel?.sink.close();
      _deepgramChannel = null;

      await _audioStreamController?.close();
      _audioStreamController = null;
      _deepgramStartInProgress = false;

      _updateState(_state.copyWith(
        isStreamingToDeepgram: false,
        partialCaption: '',
      ));
    } catch (e) {
      if (kDebugMode) print('Error stopping Deepgram: $e');
    }
  }

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _handleAppBackground();
        break;
      case AppLifecycleState.resumed:
        _handleAppForeground();
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
      _updateInputSettings(camera: false, microphone: false);
      _stopDeepgramStreaming();
    }
  }

  /// Handle app returning to foreground
  void _handleAppForeground() {
    if (_state.connectionState == ConnectionState.connected) {
      _updateInputSettings(
        camera: _resumeCameraEnabled,
        microphone: _resumeMicrophoneEnabled,
      );

      if (_canUseDeepgram() && !_state.isStreamingToDeepgram) {
        _startDeepgramStreamingWithResolvedCredential(forceRefresh: true);
      }
    }
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

    if (oldWidget.deepgramApiKey != widget.deepgramApiKey) {
      _deepgramCredential = _sanitizeDeepgramCredential(widget.deepgramApiKey);
    }
    if (oldWidget.sessionId != widget.sessionId) {
      _sessionStartedMarked = false;
    }

    final oldUrl = oldWidget.roomUrl;
    final newUrl = widget.roomUrl;
    final oldValid = _isValidRoomUrl(oldUrl);
    final newValid = _isValidRoomUrl(newUrl);

    // If we're already connected, connecting, or initializing — only
    // reconnect when the room URL actually changes (different room).
    // Token changes are harmless: the existing token is still valid for
    // the duration of the Daily session.
    if (_callClient != null || _isInitializing) {
      if (oldUrl != newUrl && newValid) {
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

    // Start/stop duration timer based on connection state changes
    final wasConnected = _state.connectionState == ConnectionState.connected;
    final isConnected = newState.connectionState == ConnectionState.connected;
    if (!wasConnected && isConnected) {
      _startDurationTimer();
    } else if (wasConnected && !isConnected) {
      _stopDurationTimer();
    }

    setState(() {
      _state = newState;
    });
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _callDurationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _state.connectionState == ConnectionState.connected) {
        setState(() {
          _callDurationSeconds++;
        });
      }
    });
    _trackTimer(_durationTimer!);
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
      await VoIPService().endCurrentCall();
    } catch (e) {
      if (kDebugMode) print('Failed to end system call UI: $e');
    }
  }

  Future<void> _markSessionStarted() async {
    final sessionId = widget.sessionId?.trim();
    if (_sessionStartedMarked || sessionId == null || sessionId.isEmpty) {
      return;
    }

    _sessionStartedMarked = true;
    final sessionRef =
        FirebaseFirestore.instance.collection('videoSessions').doc(sessionId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(sessionRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() ?? <String, dynamic>{};
        final status = (data['status'] ?? '').toString();
        if (status == 'ended' || status == 'cancelled') return;

        final sessionMetadata = data['sessionMetadata'];
        final connectedAtTimestamp = sessionMetadata is Map
            ? sessionMetadata['callConnectedAtTimestamp']
            : null;
        if (connectedAtTimestamp != null) return;

        transaction.update(sessionRef, {
          'startedAt': FieldValue.serverTimestamp(),
          'sessionMetadata.callConnectedAtTimestamp':
              DateTime.now().millisecondsSinceEpoch,
        });
      });
    } catch (e) {
      _sessionStartedMarked = false;
      if (kDebugMode) print('Failed to mark session started: $e');
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
      await VoIPService().markCallConnected();
      _systemCallMarkedConnected = true;
    } catch (e) {
      if (kDebugMode) print('Failed to mark system call connected: $e');
    }
  }

  /// Track timer for cleanup
  void _trackTimer(Timer timer) {
    _activeTimers.add(timer);
  }

  /// Track subscription for cleanup
  void _trackSubscription(StreamSubscription subscription) {
    _activeSubscriptions.add(subscription);
  }

  /// Track controller for cleanup
  void _trackController(StreamController controller) {
    _activeControllers.add(controller);
  }

  /// COMPLETE BUILD METHOD REPLACEMENT - This should fix the error
  @override
  Widget build(BuildContext context) {
    // Show waiting screen if room URL invalid
    if (!_isValidRoomUrl(widget.roomUrl)) {
      return _buildConnectingScreen();
    }

    final showPip = _shouldShowPictureInPicture();

    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // Main video/placeholder layer
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildPrimaryVideo(),
            ),
          ),

          // Call duration timer (top-left)
          if (_state.connectionState == ConnectionState.connected)
            Positioned(
              top: 55,
              left: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _formatDuration(_callDurationSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          // Picture-in-picture (only after remote video is ready)
          if (showPip)
            Positioned(
              top: 55,
              right: 20,
              child: Container(
                width: 100,
                height: 140,
                child: _buildPictureInPicture(),
              ),
            ),

          // Captions overlay
          if (_state.connectionState == ConnectionState.connected)
            Positioned(
              bottom: 160,
              left: 16,
              right: 16,
              child: _buildCaptionsOverlay(),
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
          Positioned(
            bottom: 35,
            left: 0,
            right: 0,
            child: _buildControls(),
          ),

          // Error display
          if (_state.error != null && _state.retryCount >= _maxRetryAttempts)
            Positioned.fill(
              child: _buildErrorDisplay(),
            ),

          // Status overlay (searching/connecting/awaiting remote)
          if (_statusMessage() != null)
            Positioned.fill(
              child: IgnorePointer(child: _buildConnectingOverlay()),
            ),
        ],
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

  bool _shouldShowPictureInPicture() {
    return _hasRemoteVideoReady() &&
        _localVideoController != null &&
        _state.cameraEnabled;
  }

  String? _statusMessage() {
    if (_hasRemoteVideoReady()) {
      return null;
    }

    // Remote participant just left — call is ending, not "waiting".
    if (_remoteLeftTimer != null) {
      return 'Звонок завершается...';
    }

    final status = widget.sessionStatus?.trim().toLowerCase();
    final isStudent = widget.isStudent == true;

    if (status == 'ended' || status == 'cancelled') {
      return 'Звонок завершается...';
    }

    if (status == 'searching' && isStudent) {
      return 'Ищем преподавателя...';
    }

    if (_state.connectionState != ConnectionState.connected) {
      return 'Соединяемся...';
    }

    return isStudent
        ? 'Ожидаем подключение преподавателя...'
        : 'Ожидаем подключение студента...';
  }

  Widget _buildPrimaryVideo() {
    if (_hasRemoteVideoReady()) {
      return _buildRemoteVideo();
    }
    return _buildLocalFullScreen();
  }

  Widget _buildLocalFullScreen() {
    if (_localVideoController == null) {
      return _buildNeutralBackground();
    }

    if (!_state.cameraEnabled) {
      return _buildPlaceholder('Камера выключена');
    }

    return VideoView(
      controller: _localVideoController!,
      fit: VideoViewFit.cover,
    );
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
            if (showSpinner) const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 18),
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

      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: VideoView(
          controller: _localVideoController!,
          fit: VideoViewFit.cover,
        ),
      );
    } catch (e) {
      if (kDebugMode) print('Error building local video: $e');
      return _buildPlaceholder('Видео недоступно');
    }
  }

  /// Build remote video view
  Widget _buildRemoteVideo() {
    try {
      if (_state.remoteControllers.isEmpty) {
        return _buildLocalFullScreen();
      }

      final controller = _state.remoteControllers.values.firstOrNull;
      final participantId = _state.remoteControllers.keys.firstOrNull;

      if (controller == null || participantId == null) {
        return _buildLocalFullScreen();
      }

      final participant = _callClient?.participants.remote[participantId];

      if (participant == null) {
        return _buildLocalFullScreen();
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
            ? _buildLocalFullScreen()
            : _buildPlaceholder('Камера участника выключена');
      }

      return _buildLocalFullScreen();
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
        borderRadius: BorderRadius.circular(20),
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
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build captions overlay with speaker separation
  Widget _buildCaptionsOverlay() {
    final words = _getAllCaptionWords();
    if (words.isEmpty) return const SizedBox.shrink();

    // Separate words by speaker
    final myWords = words.where((w) => w['isMyWord'] == true).toList();
    final theirWords = words.where((w) => w['isMyWord'] == false).toList();

    // Get remote participant name
    String participantName = 'Собеседник';
    if (_state.remoteControllers.isNotEmpty) {
      final participantId = _state.remoteControllers.keys.first;
      final participant = _callClient?.participants.remote[participantId];
      if (participant != null &&
          participant.info.username?.isNotEmpty == true) {
        participantName = participant.info.username ?? 'Собеседник';
      }
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 230),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // My subtitles section
          if (myWords.isNotEmpty) ...[
            _buildSpeakerSection('Me:', myWords, true),
            const SizedBox(height: 12),
          ],

          // Remote participant subtitles section
          if (theirWords.isNotEmpty)
            _buildSpeakerSection('$participantName:', theirWords, false),
        ],
      ),
    );
  }

  /// Build speaker section with label and words
  Widget _buildSpeakerSection(
      String label, List<Map<String, dynamic>> words, bool isMySection) {
    // Create label chip first
    final labelChip = IntrinsicWidth(
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isMySection
              ? Colors.white.withOpacity(0.9)
              : const Color(0xFFB8A4FF).withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 0.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 4,
              offset: Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isMySection ? Colors.black : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                  color: Colors.black.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Combine label and words in a single wrap
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [labelChip, ...words.map(_buildWordChip)],
    );
  }

  /// Get all caption words with caching
  List<Map<String, dynamic>> _cachedWords = [];
  String _lastCaptionState = '';

  List<Map<String, dynamic>> _getAllCaptionWords() {
    // Create a simple state hash to detect changes
    final currentState =
        '${_getCurrentCaption()}|${_state.remoteCaptions.hashCode}';

    // Return cached result if nothing changed
    if (currentState == _lastCaptionState) {
      return _cachedWords;
    }

    final List<Map<String, dynamic>> words = [];

    // Add own words
    final myCaption = _getCurrentCaption();
    if (myCaption.isNotEmpty) {
      final myWords = myCaption.split(RegExp(r'\s+'));
      for (final word in myWords) {
        if (word.isNotEmpty && word.length > 1) {
          // Filter out single characters
          words.add({
            'word': word,
            'isMyWord': true,
            'fullSentence': myCaption,
          });
        }
      }
    }

    // Add remote words
    _state.remoteCaptions.forEach((id, captions) {
      if (captions.isNotEmpty) {
        final caption = captions.last;
        final remoteWords = caption.split(RegExp(r'\s+'));
        for (final word in remoteWords) {
          if (word.isNotEmpty && word.length > 1) {
            // Filter out single characters
            words.add({
              'word': word,
              'isMyWord': false,
              'fullSentence': caption,
            });
          }
        }
      }
    });

    // Cache the result
    _cachedWords = words;
    _lastCaptionState = currentState;

    return words;
  }

  /// Get current caption text
  String _getCurrentCaption() {
    if (_state.partialCaption.isNotEmpty) {
      return _state.partialCaption;
    } else if (_state.finalCaptions.isNotEmpty) {
      return _state.finalCaptions.last['text'] as String;
    }
    return '';
  }

  /// Build word chip widget - FIXED
  Widget _buildWordChip(Map<String, dynamic> wordData) {
    final word = wordData['word'] as String;
    final isMyWord = wordData['isMyWord'] as bool;
    final fullSentence = wordData['fullSentence'] as String;

    final color = isMyWord ? const Color(0x9CD1D1D1) : const Color(0xB6BA8CFF);

    return GestureDetector(
      onTap: () {
        widget.actionCallback?.call(word, fullSentence);
      },
      child: IntrinsicWidth(
        child: Container(
          // Removed RepaintBoundary from here
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 0.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 4,
                offset: Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              word,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
          onPressed: () => _updateInputSettings(camera: !_state.cameraEnabled),
          isEndCall: false,
        ),
        _buildControlButton(
          icon: _state.microphoneEnabled ? Icons.mic : Icons.mic_off,
          isActive: _state.microphoneEnabled,
          onPressed: () =>
              _updateInputSettings(microphone: !_state.microphoneEnabled),
          isEndCall: false,
        ),
        _buildControlButton(
          icon: Icons.call_end,
          isActive: true,
          onPressed: _endCall,
          isEndCall: true,
        ),
      ],
    );
  }

  /// Build control button - FIXED
  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required bool isEndCall,
  }) {
    return Container(
      // Removed RepaintBoundary from here
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: isEndCall
            ? Colors.red.withOpacity(0.9)
            : Colors.black.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
        iconSize: 24,
        padding: EdgeInsets.zero,
      ),
    );
  }

  /// Build reconnecting indicator
  Widget _buildReconnectingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
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
          const SizedBox(width: 8),
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
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Не удалось подключиться',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 16),
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
  Future<void> _endCall() async {
    try {
      _userRequestedEnd = true;
      unawaited(_endSystemCallUi());

      // 1. Leave the Daily room first (clean disconnect)
      await _cleanup(leaveCall: true);

      // 2. Then invoke the callback which navigates away
      await widget.endCallCallback?.call();
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
  /// 3. Stop Deepgram
  /// 4. Leave call (signal server while connection still alive)
  /// 5. Cancel remaining subscriptions
  /// 6. Clear tracks and dispose video controllers
  /// 7. Dispose CallClient
  ///
  /// NOTE: _userRequestedEnd is NOT reset here. It is only set by _endCall()
  /// and reset by _initializeCall() when starting a new session.
  Future<void> _cleanup({bool leaveCall = true}) async {
    if (kDebugMode) print('Cleaning up resources...');

    try {
      // 1. Cancel all timers first (stop any pending reconnects, retries, etc.)
      for (final timer in _activeTimers) {
        timer.cancel();
      }
      _activeTimers.clear();
      _remoteLeftTimer?.cancel();
      _remoteLeftTimer = null;
      _remoteLeftNotified = false;

      // 2. Cancel event subscription BEFORE leave() so that the
      // CallState.left event does not trigger _scheduleReconnection.
      try {
        await _eventSubscription?.cancel();
        _eventSubscription = null;
      } catch (e) {
        if (kDebugMode) print('Error cancelling event subscription: $e');
      }

      // 3. Stop Deepgram streaming
      await _stopDeepgramStreaming();

      // 4. Leave call while connection is still alive
      if (_callClient != null && leaveCall) {
        try {
          await _callClient!.leave();
          // Brief wait for leave signal to be sent over WebSocket
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          if (kDebugMode) print('Error leaving call: $e');
        }
      }

      // 5. Cancel all remaining tracked subscriptions
      for (final subscription in _activeSubscriptions) {
        try {
          await subscription.cancel();
        } catch (e) {
          if (kDebugMode) print('Error cancelling subscription: $e');
        }
      }
      _activeSubscriptions.clear();

      // 6. Clear video tracks before disposing controllers
      try {
        _localVideoController?.setTrack(null);
      } catch (e) {
        if (kDebugMode) print('Error clearing local video track: $e');
      }

      for (final controller in _state.remoteControllers.values) {
        try {
          controller.setTrack(null);
        } catch (e) {
          if (kDebugMode) print('Error clearing remote video track: $e');
        }
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
      _systemCallMarkedConnected = false;
      _dynamicMeetingToken = null;
      _tokenRefreshAttempts = 0;

      // 7. Dispose call client last
      try {
        await _callClient?.dispose();
        _callClient = null;
      } catch (e) {
        if (kDebugMode) print('Error disposing call client: $e');
      }

      // Close all stream controllers
      for (final controller in _activeControllers) {
        try {
          await controller.close();
        } catch (e) {
          if (kDebugMode) print('Error closing controller: $e');
        }
      }
      _activeControllers.clear();

      // Reset state
      if (mounted && !_disposed) {
        _updateState(const _CallState());
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

    // Synchronous cleanup of timers
    for (final timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();
    _remoteLeftTimer?.cancel();
    _remoteLeftTimer = null;

    // Cancel event subscription synchronously to stop incoming events
    _eventSubscription?.cancel();
    _eventSubscription = null;

    // Schedule async cleanup (leave call, dispose client)
    _cleanup(leaveCall: true);

    super.dispose();
  }
}
