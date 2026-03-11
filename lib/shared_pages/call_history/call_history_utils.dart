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

String _sessionTimeLabel(BuildContext context, DateTime startedAtLocal) {
  final locale = FFLocalizations.of(context).languageCode;
  return DateFormat.jm(locale).format(startedAtLocal);
}

int _sessionDifferenceInDays(DateTime startedAtLocal) {
  final now = DateTime.now();
  final startedDay = DateTime(
    startedAtLocal.year,
    startedAtLocal.month,
    startedAtLocal.day,
  );
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(startedDay).inDays;
}

String _sessionRelativeDateLabel(
  BuildContext context,
  DateTime startedAtLocal,
) {
  final locale = FFLocalizations.of(context).languageCode;
  final differenceInDays = _sessionDifferenceInDays(startedAtLocal);

  if (differenceInDays == 0) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Сегодня',
      enText: 'Today',
    );
  }

  if (differenceInDays == 1) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Вчера',
      enText: 'Yesterday',
    );
  }

  if (differenceInDays > 1 && differenceInDays < 7) {
    return DateFormat.EEEE(locale).format(startedAtLocal);
  }

  return DateFormat('M/d/yy').format(startedAtLocal);
}

String formatSessionStartedAt(
  BuildContext context,
  VideoSessionsRecord session,
) {
  final startedAt = resolveSessionStartedAt(session);
  if (startedAt == null) {
    return '-';
  }

  final startedAtLocal = startedAt.toLocal();
  final dateLabel = _sessionRelativeDateLabel(context, startedAtLocal);
  final timeLabel = _sessionTimeLabel(context, startedAtLocal);

  return '$dateLabel, $timeLabel';
}

String formatSessionStartedAtForCard(
  BuildContext context,
  VideoSessionsRecord session,
) {
  final startedAt = resolveSessionStartedAt(session);
  if (startedAt == null) {
    return '-';
  }

  final startedAtLocal = startedAt.toLocal();
  final dateLabel = _sessionRelativeDateLabel(context, startedAtLocal);
  final timeLabel = _sessionTimeLabel(context, startedAtLocal);

  if (_sessionDifferenceInDays(startedAtLocal) == 0) {
    return '$dateLabel, $timeLabel';
  }

  return dateLabel;
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
