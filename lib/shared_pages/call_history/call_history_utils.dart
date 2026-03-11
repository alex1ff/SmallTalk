import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

DateTime? resolveSessionStartedAt(VideoSessionsRecord session) {
  final sessionMetadata = session.snapshotData['sessionMetadata'];
  final connectedAt =
      sessionMetadata is Map ? sessionMetadata['callConnectedAt'] : null;

  if (connectedAt is DateTime) {
    return connectedAt;
  }

  return session.startedAt ?? session.createdAt;
}

int resolveSessionDurationSeconds(VideoSessionsRecord session) {
  if (session.duration > 0) {
    return session.duration;
  }

  final startedAt = resolveSessionStartedAt(session);
  final endedAt = session.endedAt;
  if (startedAt == null || endedAt == null) {
    return 0;
  }

  final diff = endedAt.difference(startedAt).inSeconds;
  return diff > 0 ? diff : 0;
}

int compareSessionsByStartedAtDesc(
  VideoSessionsRecord a,
  VideoSessionsRecord b,
) {
  final aStartedAt =
      resolveSessionStartedAt(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bStartedAt =
      resolveSessionStartedAt(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
  return bStartedAt.compareTo(aStartedAt);
}

String formatSessionStartedAt(
  BuildContext context,
  VideoSessionsRecord session,
) {
  final startedAt = resolveSessionStartedAt(session);
  if (startedAt == null) {
    return '-';
  }

  final locale = FFLocalizations.of(context).languageCode;
  final dateLabel = dateTimeFormat(
    'd MMMM',
    startedAt,
    locale: locale,
  );
  final timeLabel = dateTimeFormat(
    'Hm',
    startedAt,
    locale: locale,
  );

  return '$dateLabel, $timeLabel';
}

String formatDurationLabel(BuildContext context, int totalSeconds) {
  final safeSeconds = max(totalSeconds, 0).toInt();
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final seconds = safeSeconds % 60;
  final minutesLabel = FFLocalizations.of(context).getVariableText(
    ruText: 'мин',
    enText: 'min',
  );

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} $minutesLabel';
  }

  if (seconds == 0) {
    return '$minutes $minutesLabel';
  }

  return '$minutes:${seconds.toString().padLeft(2, '0')} $minutesLabel';
}

String formatStAmount(double? amount) {
  if (amount == null) {
    return '-';
  }
  return '${NumberFormat('0.##').format(amount)} ST';
}

String formatRubAmount(int? amount) {
  if (amount == null) {
    return '-';
  }
  return '${NumberFormat('0').format(amount)} ₽';
}
