import 'package:flutter/material.dart';

class MinimalDailyWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: const Center(
        child: Text('Video calls are unavailable on web preview.'),
      ),
    );
  }
}
