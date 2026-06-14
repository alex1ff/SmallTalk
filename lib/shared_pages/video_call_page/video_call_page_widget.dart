import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/permissions_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'dart:async';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/custom_code/widgets/deepgram_credential_exception.dart';
import '/custom_code/widgets/session_limit_ui.dart' as session_limit_ui;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import '/shared_pages/learning/caption_word_flow.dart';
import '/shared_pages/review_flow/review_submission_helper.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/services/voip_service.dart';
import 'video_call_page_model.dart';
export 'video_call_page_model.dart';

class VideoCallPageWidget extends StatefulWidget {
  const VideoCallPageWidget({
    super.key,
    required this.videoDocRef,
    this.initialRoomUrl,
    this.initialMeetingToken,
    this.initialRoomName,
  });

  final DocumentReference? videoDocRef;
  final String? initialRoomUrl;
  final String? initialMeetingToken;
  final String? initialRoomName;

  static String routeName = 'VideoCallPage';
  static String routePath = '/videoCallPage';

  @override
  State<VideoCallPageWidget> createState() => _VideoCallPageWidgetState();
}

class _VideoCallPageWidgetState extends State<VideoCallPageWidget> {
  late VideoCallPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  String? _freshRoomUrl;
  String? _freshRoomName;
  String? _freshMeetingToken;
  bool _tokenLoading = false;
  String? _tokenLoadingSessionId;
  String? _lastTokenSessionId;
  bool _didNavigateToSummary = false;
  String? _lastLoggedTokenSource;
  String? _lastLoggedRoomName;
  String? _lastLoggedRoomUrl;
  String? _deepgramAccessToken;
  bool _deepgramTokenLoading = false;
  String? _deepgramTokenLoadingSessionId;
  String? _lastDeepgramTokenSessionId;
  late Future<bool> _mediaPermissionsFuture;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => VideoCallPageModel());
    _model.bindSession(widget.videoDocRef);
    _mediaPermissionsFuture = _ensureMediaPermissionsThenFetchCredentials();
  }

  @override
  void didUpdateWidget(VideoCallPageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDocumentReference(oldWidget.videoDocRef, widget.videoDocRef)) {
      _model.bindSession(widget.videoDocRef);
      _resetSessionScopedState();
      if (!_hasValidVideoDocRef) {
        return;
      }
      safeSetState(() {
        _mediaPermissionsFuture =
            _ensureMediaPermissionsThenFetchCredentials(force: true);
      });
    }
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<String?> _fetchSessionTokens({bool force = false}) async {
    final sessionPath = widget.videoDocRef?.path;
    final sessionId = widget.videoDocRef?.id;
    if (sessionId == null || sessionId.isEmpty) return null;
    if (_tokenLoading && _tokenLoadingSessionId == sessionId) {
      return _freshMeetingToken;
    }
    if (!force &&
        _lastTokenSessionId == sessionId &&
        _freshMeetingToken != null) {
      return _freshMeetingToken;
    }

    if (!mounted) return null;
    setState(() {
      _tokenLoading = true;
      _tokenLoadingSessionId = sessionId;
    });

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getSessionTokens')
          .call({
        'sessionId': sessionId,
      });
      if (!mounted ||
          !_isCurrentSession(sessionId: sessionId, sessionPath: sessionPath)) {
        return null;
      }
      final data = result.data as Map<String, dynamic>? ?? {};
      _freshRoomUrl = _nonEmptyValue(data['roomUrl']?.toString());
      _freshRoomName = _nonEmptyValue(data['roomName']?.toString());
      _freshMeetingToken = _nonEmptyValue(data['meetingToken']?.toString());
      _lastTokenSessionId = sessionId;
      return _freshMeetingToken;
    } catch (e) {
      return null;
    } finally {
      if (mounted && _tokenLoadingSessionId == sessionId) {
        setState(() {
          _tokenLoading = false;
          _tokenLoadingSessionId = null;
        });
      }
    }
  }

  Future<bool> _ensureMediaPermissionsThenFetchCredentials({
    bool force = false,
  }) async {
    if (!_hasValidVideoDocRef) {
      return false;
    }

    final hasMediaPermissions = await ensureCameraAndMicrophonePermissions();
    if (!mounted || !hasMediaPermissions) {
      return hasMediaPermissions;
    }

    // Only fetch session tokens if we don't already have valid initial data.
    // When the student arrives via VoIP push, initialRoomUrl + initialMeetingToken
    // are already set. Fetching again returns a DIFFERENT token, which used to
    // trigger MinimalDailyWidget.didUpdateWidget → cleanup → re-init, destroying
    // the active Daily connection mid-join and causing crashes.
    final hasInitialRoom = widget.initialRoomUrl != null &&
        widget.initialRoomUrl!.trim().isNotEmpty;
    final hasInitialToken = widget.initialMeetingToken != null &&
        widget.initialMeetingToken!.trim().isNotEmpty;
    if (force || !hasInitialRoom || !hasInitialToken) {
      unawaited(_fetchSessionTokens(force: force));
    }
    unawaited(_fetchDeepgramToken(force: force));
    return true;
  }

  void _retryMediaPermissions() {
    safeSetState(() {
      _mediaPermissionsFuture =
          _ensureMediaPermissionsThenFetchCredentials(force: true);
    });
  }

  DeepgramCredentialException _mapDeepgramCredentialError(
    FirebaseFunctionsException error,
  ) {
    final details = error.details;
    final reason = details is Map ? details['reason']?.toString() : null;
    if (reason == 'deepgram_token_grant_forbidden') {
      return const DeepgramCredentialException(
        code: 'deepgram_token_grant_forbidden',
        message:
            'Субтитры временно недоступны: сервис распознавания требует настройки.',
      );
    }

    return const DeepgramCredentialException(
      code: 'caption_token_unavailable',
      message:
          'Субтитры временно недоступны: не удалось получить токен распознавания.',
    );
  }

  Future<String?> _fetchDeepgramToken({
    bool force = false,
    bool throwOnFailure = false,
  }) async {
    final sessionPath = widget.videoDocRef?.path;
    final sessionId = widget.videoDocRef?.id;
    if (sessionId == null || sessionId.isEmpty) return null;
    if (!force &&
        _deepgramTokenLoading &&
        _deepgramTokenLoadingSessionId == sessionId) {
      return _deepgramAccessToken;
    }
    if (!force &&
        _lastDeepgramTokenSessionId == sessionId &&
        _nonEmptyValue(_deepgramAccessToken) != null) {
      return _deepgramAccessToken;
    }

    if (!mounted) return _deepgramAccessToken;
    setState(() {
      _deepgramTokenLoading = true;
      _deepgramTokenLoadingSessionId = sessionId;
    });

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getDeepgramToken')
          .call({
        'sessionId': sessionId,
      });
      final rawData = result.data;
      if (!mounted ||
          !_isCurrentSession(sessionId: sessionId, sessionPath: sessionPath)) {
        return null;
      }
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};
      _deepgramAccessToken = _nonEmptyValue(data['accessToken']?.toString());
      _lastDeepgramTokenSessionId = sessionId;
      if (kDebugMode) {
        debugPrint(
          _deepgramAccessToken != null
              ? '🎙️ Deepgram credential ready: ${data['credentialType'] ?? 'unknown'}'
              : '⚠️ Deepgram credential response was empty',
        );
      }
      return _deepgramAccessToken;
    } on FirebaseFunctionsException catch (e) {
      final error = _mapDeepgramCredentialError(e);
      if (kDebugMode) {
        debugPrint('❌ Deepgram credential fetch failed: $e');
      }
      if (throwOnFailure) {
        throw error;
      }
      return _deepgramAccessToken;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Deepgram credential fetch failed: $e');
      }
      if (throwOnFailure) {
        throw const DeepgramCredentialException(
          code: 'caption_token_unavailable',
          message:
              'Субтитры временно недоступны: не удалось получить токен распознавания.',
        );
      }
      return _deepgramAccessToken;
    } finally {
      if (mounted && _deepgramTokenLoadingSessionId == sessionId) {
        setState(() {
          _deepgramTokenLoading = false;
          _deepgramTokenLoadingSessionId = null;
        });
      }
    }
  }

  bool get _hasValidVideoDocRef {
    final sessionId = widget.videoDocRef?.id.trim();
    return sessionId != null && sessionId.isNotEmpty;
  }

  bool _isSameDocumentReference(
    DocumentReference? left,
    DocumentReference? right,
  ) {
    return left?.path == right?.path;
  }

  bool _isCurrentSession({
    required String sessionId,
    required String? sessionPath,
  }) {
    final currentRef = widget.videoDocRef;
    return currentRef?.id == sessionId && currentRef?.path == sessionPath;
  }

  void _resetSessionScopedState() {
    _freshRoomUrl = null;
    _freshRoomName = null;
    _freshMeetingToken = null;
    _tokenLoading = false;
    _tokenLoadingSessionId = null;
    _lastTokenSessionId = null;
    _didNavigateToSummary = false;
    _lastLoggedTokenSource = null;
    _lastLoggedRoomName = null;
    _lastLoggedRoomUrl = null;
    _deepgramAccessToken = null;
    _deepgramTokenLoading = false;
    _deepgramTokenLoadingSessionId = null;
    _lastDeepgramTokenSessionId = null;
  }

  String? _nonEmptyValue(String? value) {
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

  bool _isValidRoomUrl(String value) {
    if (value.isEmpty) return false;
    try {
      final uri = Uri.tryParse(value);
      return uri != null && uri.hasScheme && uri.hasAuthority;
    } catch (_) {
      return false;
    }
  }

  bool _isValidUserId(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final lowered = trimmed.toLowerCase();
    return !(lowered == '-' ||
        lowered == 'null' ||
        lowered == 'undefined' ||
        lowered == 'false' ||
        lowered == '0' ||
        lowered == 'none');
  }

  Future<void> _navigateToSummary(
    VideoSessionsRecord? session, {
    DocumentReference? sessionRefOverride,
  }) async {
    if (!mounted || _didNavigateToSummary) return;
    _didNavigateToSummary = true;

    final sessionRef = sessionRefOverride ?? widget.videoDocRef;
    final participantResolution = session == null
        ? null
        : resolveSessionReviewParticipant(
            sessionData: session.snapshotData,
            currentUserId: currentUserUid,
          );
    final userId = participantResolution?.counterpartUserId;

    final userRef =
        _isValidUserId(userId) ? functions.stringToRef(userId!.trim()) : null;

    if (sessionRef == null || userRef == null) {
      if (mounted) {
        context.safePop();
      }
      return;
    }

    final sessionMetadata = session?.snapshotData['sessionMetadata'];
    final connectedAt =
        sessionMetadata is Map ? sessionMetadata['callConnectedAt'] : null;
    final fallbackStartedAt =
        connectedAt is DateTime ? connectedAt : session?.startedAt;

    // If the Firestore duration is 0 (e.g. endSession cloud function hasn't
    // finished yet), use the server-authored call-connected timestamp.
    int duration = session?.duration ?? 0;
    if (duration <= 0 && fallbackStartedAt != null) {
      duration = DateTime.now().difference(fallbackStartedAt).inSeconds;
      if (duration < 0) duration = 0;
    }

    context.goNamed(
      CallSummaryWidget.routeName,
      queryParameters: {
        'userRef': serializeParam(userRef, ParamType.DocumentReference),
        'sessionID': serializeParam(sessionRef, ParamType.DocumentReference),
        'lang': serializeParam(session?.language ?? 'en', ParamType.String),
        'dur': serializeParam(duration, ParamType.int),
      }.withoutNulls,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionStream = _model.sessionStream;
    if (!_hasValidVideoDocRef || sessionStream == null) {
      return _buildMissingSessionState(context);
    }

    return StreamBuilder<VideoSessionsRecord>(
      stream: sessionStream,
      builder: (context, snapshot) {
        final videoCallPageVideoSessionsRecord = snapshot.data;
        String? _nonEmpty(String? value) => _nonEmptyValue(value);

        final resolvedRoomUrl = _nonEmpty(_freshRoomUrl) ??
            _nonEmpty(videoCallPageVideoSessionsRecord?.dailyRoomUrl) ??
            _nonEmpty(widget.initialRoomUrl) ??
            '';
        final resolvedMeetingToken = _nonEmpty(_freshMeetingToken) ??
            _nonEmpty(widget.initialMeetingToken);
        final resolvedRoomName = _nonEmpty(_freshRoomName) ??
            _nonEmpty(videoCallPageVideoSessionsRecord?.dailyRoomName) ??
            _nonEmpty(widget.initialRoomName);
        final resolvedLanguage = _nonEmpty(
              videoCallPageVideoSessionsRecord?.language,
            ) ??
            'en';
        final rawSessionPolicy =
            videoCallPageVideoSessionsRecord?.snapshotData['sessionPolicy'];
        final sessionPolicy = rawSessionPolicy is Map
            ? Map<String, dynamic>.from(rawSessionPolicy)
            : null;
        final sessionStatus =
            _nonEmpty(videoCallPageVideoSessionsRecord?.status);
        final useSessionLimitCountdown =
            session_limit_ui.shouldUseSessionLimitCountdown(
          sessionStatus: sessionStatus,
          expiresAt: videoCallPageVideoSessionsRecord?.expiresAt,
          sessionPolicy: sessionPolicy,
        );
        final isStudent = currentUserUid ==
            _nonEmpty(videoCallPageVideoSessionsRecord?.studentId);

        if (kDebugMode) {
          final tokenSource = _nonEmpty(_freshMeetingToken) != null
              ? 'getSessionTokens'
              : (_nonEmpty(widget.initialMeetingToken) != null
                  ? 'prefetch/initial'
                  : 'none');
          if (tokenSource != _lastLoggedTokenSource ||
              resolvedRoomName != _lastLoggedRoomName ||
              resolvedRoomUrl != _lastLoggedRoomUrl) {
            _lastLoggedTokenSource = tokenSource;
            _lastLoggedRoomName = resolvedRoomName;
            _lastLoggedRoomUrl = resolvedRoomUrl;
            debugPrint(
              '🎟️ Token source: $tokenSource | roomName: ${resolvedRoomName ?? "null"} | roomUrl: ${resolvedRoomUrl.isNotEmpty ? "present" : "missing"}',
            );
          }
        }

        // When the OTHER side calls endSession, the Firestore document
        // status changes to "ended" / "cancelled". Detect this and
        // navigate to summary immediately instead of waiting for the
        // Daily SDK participantLeft timer.
        // Also end the native CallKit/ConnectionService UI so the
        // iPhone call screen is dismissed.
        if ((sessionStatus == 'ended' || sessionStatus == 'cancelled') &&
            !_didNavigateToSummary) {
          final terminalSessionRef = widget.videoDocRef;
          final terminalSessionId = terminalSessionRef?.id;
          final terminalSessionPath = terminalSessionRef?.path;
          final terminalSession = videoCallPageVideoSessionsRecord;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                !_didNavigateToSummary &&
                terminalSessionId != null &&
                _isCurrentSession(
                  sessionId: terminalSessionId,
                  sessionPath: terminalSessionPath,
                )) {
              unawaited(
                VoIPService().endCurrentCall(sessionId: terminalSessionId),
              );
              _navigateToSummary(
                terminalSession,
                sessionRefOverride: terminalSessionRef,
              );
            }
          });
        }

        return FutureBuilder<bool>(
          future: _mediaPermissionsFuture,
          builder: (context, mediaPermissionSnapshot) {
            if (mediaPermissionSnapshot.connectionState !=
                ConnectionState.done) {
              return _buildMediaPermissionState(context, isLoading: true);
            }
            if (mediaPermissionSnapshot.data != true) {
              return _buildMediaPermissionState(context, isLoading: false);
            }

            if (_isValidRoomUrl(resolvedRoomUrl) &&
                resolvedMeetingToken == null &&
                !_tokenLoading) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted &&
                    !_tokenLoading &&
                    _freshMeetingToken == null &&
                    _nonEmpty(widget.initialMeetingToken) == null) {
                  unawaited(_fetchSessionTokens());
                }
              });
            }

            return GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: Scaffold(
                key: scaffoldKey,
                backgroundColor: ExpatlioDesign.background,
                body: Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: custom_widgets.MinimalDailyWidget(
                    width: double.infinity,
                    height: double.infinity,
                    sessionId: widget.videoDocRef?.id,
                    roomUrl: resolvedRoomUrl,
                    meetingToken: resolvedMeetingToken,
                    tokenRefreshCallback: () async {
                      return await _fetchSessionTokens(force: true);
                    },
                    joinCredentialsRefreshCallback: () async {
                      await _fetchSessionTokens(force: true);
                      return {
                        'roomUrl': _freshRoomUrl,
                        'roomName': _freshRoomName,
                        'meetingToken': _freshMeetingToken,
                      };
                    },
                    sessionExpiresAt: useSessionLimitCountdown
                        ? videoCallPageVideoSessionsRecord?.expiresAt
                        : null,
                    sessionPolicy:
                        useSessionLimitCountdown ? sessionPolicy : null,
                    deepgramTokenRefreshCallback: () async {
                      return await _fetchDeepgramToken(
                        force: true,
                        throwOnFailure: true,
                      );
                    },
                    sessionStatus: sessionStatus,
                    isStudent: isStudent,
                    deepgramCredential: _nonEmpty(_deepgramAccessToken),
                    deepgramLanguage: resolvedLanguage,
                    username: currentUserDisplayName,
                    enableDeepgram: true,
                    actionCallback: (word, sentence, contextText) async {
                      await showModalBottomSheet(
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        context: context,
                        builder: (context) {
                          return GestureDetector(
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            child: Padding(
                              padding: MediaQuery.viewInsetsOf(context),
                              child: buildLiveCaptionWordSheet(
                                word: word,
                                languageCode: resolvedLanguage,
                                sentence: sentence,
                                contextText: contextText,
                              ),
                            ),
                          );
                        },
                      ).then((value) => safeSetState(() {}));
                    },
                    endCallCallback: (endReason) async {
                      await _navigateToSummary(
                          videoCallPageVideoSessionsRecord);
                      safeSetState(() {});
                    },
                    participantLeftCallback: () async {
                      await _navigateToSummary(
                          videoCallPageVideoSessionsRecord);
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMediaPermissionState(
    BuildContext context, {
    required bool isLoading,
  }) {
    final title = FFLocalizations.of(context).getVariableText(
      ruText: isLoading ? 'Проверяем доступ' : 'Нужен доступ к звонку',
      enText: isLoading ? 'Checking access' : 'Call access needed',
    );
    final subtitle = FFLocalizations.of(context).getVariableText(
      ruText: isLoading
          ? 'Проверяем камеру и микрофон…'
          : 'Разрешите доступ к камере и микрофону, чтобы подключиться.',
      enText: isLoading
          ? 'Checking camera and microphone…'
          : 'Allow camera and microphone access to join the call.',
    );

    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space24,
              ExpatlioDesign.space0,
              ExpatlioDesign.space24,
              ExpatlioDesign.space0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(
                        bottom: ExpatlioDesign.space20),
                    child: CircularProgressIndicator(),
                  ),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ExpatlioDesign.text,
                        fontSize: 22.0,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: ExpatlioDesign.space8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ExpatlioDesign.muted,
                        fontSize: 16.0,
                      ),
                ),
                if (!isLoading) ...[
                  const SizedBox(height: ExpatlioDesign.space24),
                  ElevatedButton(
                    onPressed: _retryMediaPermissions,
                    child: Text(
                      FFLocalizations.of(context).getVariableText(
                        ruText: 'Проверить снова',
                        enText: 'Try again',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      unawaited(
                        VoIPService().endCurrentCall(
                          sessionId: widget.videoDocRef?.id,
                        ),
                      );
                      context.safePop();
                    },
                    child: Text(
                      FFLocalizations.of(context).getVariableText(
                        ruText: 'Закрыть',
                        enText: 'Close',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissingSessionState(BuildContext context) {
    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space24,
              ExpatlioDesign.space0,
              ExpatlioDesign.space24,
              ExpatlioDesign.space0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Не удалось открыть звонок',
                    enText: 'Unable to open call',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ExpatlioDesign.text,
                        fontSize: 16.0,
                      ),
                ),
                const SizedBox(height: ExpatlioDesign.space16),
                TextButton(
                  onPressed: () => context.safePop(),
                  child: Text(
                    FFLocalizations.of(context).getVariableText(
                      ruText: 'Назад',
                      enText: 'Back',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
