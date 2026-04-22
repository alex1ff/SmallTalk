import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import '/shared_pages/learning/caption_word_flow.dart';
import '/shared_pages/review_flow/review_submission_helper.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webviewx_plus/webviewx_plus.dart';

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
  String? _lastTokenSessionId;
  bool _didNavigateToSummary = false;
  String? _lastLoggedTokenSource;
  String? _lastLoggedRoomName;
  String? _lastLoggedRoomUrl;
  String? _deepgramAccessToken;
  bool _deepgramTokenLoading = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => VideoCallPageModel());
    _model.sessionStream = VideoSessionsRecord.getDocument(widget.videoDocRef!);
    // Only fetch session tokens if we don't already have valid initial data.
    // When the student arrives via VoIP push, initialRoomUrl + initialMeetingToken
    // are already set. Fetching again returns a DIFFERENT token, which used to
    // trigger MinimalDailyWidget.didUpdateWidget → cleanup → re-init, destroying
    // the active Daily connection mid-join and causing crashes.
    final hasInitialRoom = widget.initialRoomUrl != null &&
        widget.initialRoomUrl!.trim().isNotEmpty;
    final hasInitialToken = widget.initialMeetingToken != null &&
        widget.initialMeetingToken!.trim().isNotEmpty;
    if (!hasInitialRoom || !hasInitialToken) {
      unawaited(_fetchSessionTokens());
    }
    unawaited(_fetchDeepgramToken());
  }

  @override
  void didUpdateWidget(VideoCallPageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoDocRef?.id != widget.videoDocRef?.id) {
      _freshRoomUrl = null;
      _freshRoomName = null;
      _freshMeetingToken = null;
      _lastTokenSessionId = null;
      _didNavigateToSummary = false;
      unawaited(_fetchSessionTokens(force: true));
      unawaited(_fetchDeepgramToken(force: true));
    }
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<String?> _fetchSessionTokens({bool force = false}) async {
    final sessionId = widget.videoDocRef?.id;
    if (sessionId == null || sessionId.isEmpty) return null;
    if (_tokenLoading) return _freshMeetingToken;
    if (!force &&
        _lastTokenSessionId == sessionId &&
        _freshMeetingToken != null) {
      return _freshMeetingToken;
    }

    setState(() {
      _tokenLoading = true;
    });

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getSessionTokens')
          .call({
        'sessionId': sessionId,
      });
      final data = result.data as Map<String, dynamic>? ?? {};
      _freshRoomUrl = _nonEmptyValue(data['roomUrl']?.toString());
      _freshRoomName = _nonEmptyValue(data['roomName']?.toString());
      _freshMeetingToken = _nonEmptyValue(data['meetingToken']?.toString());
      _lastTokenSessionId = sessionId;
      return _freshMeetingToken;
    } catch (e) {
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _tokenLoading = false;
        });
      }
    }
  }

  Future<String?> _fetchDeepgramToken({bool force = false}) async {
    final sessionId = widget.videoDocRef?.id;
    if (sessionId == null || sessionId.isEmpty) return null;
    if (_deepgramTokenLoading) return _deepgramAccessToken;
    if (!force && _nonEmptyValue(_deepgramAccessToken) != null) {
      return _deepgramAccessToken;
    }

    setState(() {
      _deepgramTokenLoading = true;
    });

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getDeepgramToken')
          .call({
        'sessionId': sessionId,
      });
      final rawData = result.data;
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};
      _deepgramAccessToken = _nonEmptyValue(data['accessToken']?.toString());
      if (kDebugMode) {
        debugPrint(
          _deepgramAccessToken != null
              ? '🎙️ Deepgram credential ready: ${data['credentialType'] ?? 'unknown'}'
              : '⚠️ Deepgram credential response was empty',
        );
      }
      return _deepgramAccessToken;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Deepgram credential fetch failed: $e');
      }
      return _deepgramAccessToken;
    } finally {
      if (mounted) {
        setState(() {
          _deepgramTokenLoading = false;
        });
      }
    }
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

  Future<void> _navigateToSummary(VideoSessionsRecord? session) async {
    if (!mounted || _didNavigateToSummary) return;
    _didNavigateToSummary = true;

    final sessionRef = widget.videoDocRef;
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
    return StreamBuilder<VideoSessionsRecord>(
      stream: _model.sessionStream,
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

        // When the OTHER side calls endSession, the Firestore document
        // status changes to "ended" / "cancelled". Detect this and
        // navigate to summary immediately instead of waiting for the
        // Daily SDK participantLeft timer.
        // Also end the native CallKit/ConnectionService UI so the
        // iPhone call screen is dismissed.
        if ((sessionStatus == 'ended' || sessionStatus == 'cancelled') &&
            !_didNavigateToSummary) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_didNavigateToSummary) {
              unawaited(
                VoIPService().endCurrentCall(sessionId: widget.videoDocRef?.id),
              );
              _navigateToSummary(videoCallPageVideoSessionsRecord);
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
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
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
                sessionExpiresAt: videoCallPageVideoSessionsRecord?.expiresAt,
                sessionPolicy: sessionPolicy,
                deepgramTokenRefreshCallback: () async {
                  return await _fetchDeepgramToken(force: true);
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
                      return WebViewAware(
                        child: GestureDetector(
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
                        ),
                      );
                    },
                  ).then((value) => safeSetState(() {}));
                },
                endCallCallback: (endReason) async {
                  await _navigateToSummary(videoCallPageVideoSessionsRecord);
                  safeSetState(() {});
                },
                participantLeftCallback: () async {
                  await _navigateToSummary(videoCallPageVideoSessionsRecord);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
