import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/review_flow/review_submission_helper.dart';
import 'package:flutter/material.dart';

DateTime? resolveCallConnectedAtMetadata(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is num && value > 0) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    } catch (_) {
      return null;
    }
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final numericMillis = int.tryParse(trimmed);
    if (numericMillis != null && numericMillis > 0) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(numericMillis);
      } catch (_) {
        return null;
      }
    }

    return DateTime.tryParse(trimmed);
  }
  return null;
}

DateTime? resolveSessionStartedAt(VideoSessionsRecord session) {
  final sessionMetadata = session.snapshotData['sessionMetadata'];
  if (sessionMetadata is Map) {
    for (final connectedAt in [
      sessionMetadata['callConnectedAt'],
      sessionMetadata['callConnectedAtTimestamp'],
      sessionMetadata['dailyWebhookConnectedAt'],
    ]) {
      final startedAt = resolveCallConnectedAtMetadata(connectedAt);
      if (startedAt != null) {
        return startedAt;
      }
    }
  }

  for (final connectedAt in [
    session.snapshotData['callConnectedAt'],
    session.snapshotData['callConnectedAtTimestamp'],
    session.snapshotData['dailyWebhookConnectedAt'],
  ]) {
    final startedAt = resolveCallConnectedAtMetadata(connectedAt);
    if (startedAt != null) {
      return startedAt;
    }
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

bool callHistorySessionDataIncludesUser(
  Map<String, dynamic> sessionData,
  String userId,
) {
  return resolveSessionReviewParticipant(
    sessionData: sessionData,
    currentUserId: userId,
  ).isParticipant;
}

bool callHistorySessionIncludesUser(
  VideoSessionsRecord session,
  String userId,
) {
  return callHistorySessionDataIncludesUser(session.snapshotData, userId);
}

List<VideoSessionsRecord> mergeCallHistorySessionsForUser(
  Iterable<List<VideoSessionsRecord>> branches,
  String userId,
) {
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) {
    return const <VideoSessionsRecord>[];
  }

  final sessionsByPath = <String, VideoSessionsRecord>{};
  for (final sessions in branches) {
    for (final session in sessions) {
      if (session.status != 'ended') {
        continue;
      }
      if (!callHistorySessionIncludesUser(session, normalizedUserId)) {
        continue;
      }
      sessionsByPath.putIfAbsent(session.reference.path, () => session);
    }
  }

  return sessionsByPath.values.toList()..sort(compareSessionsByStartedAtDesc);
}

String _sessionTimeLabel(BuildContext context, DateTime startedAtLocal) {
  final locale = FFLocalizations.of(context).languageCode;
  return DateFormat.jm(locale).format(startedAtLocal);
}

int _sessionDifferenceInDays(
  DateTime startedAtLocal, {
  DateTime? now,
}) {
  final reference = (now ?? DateTime.now()).toLocal();
  final startedDay = DateTime(
    startedAtLocal.year,
    startedAtLocal.month,
    startedAtLocal.day,
  );
  final today = DateTime(reference.year, reference.month, reference.day);
  return today.difference(startedDay).inDays;
}

String _sessionRelativeDateLabel(
  BuildContext context,
  DateTime startedAtLocal, {
  DateTime? now,
}) {
  final locale = FFLocalizations.of(context).languageCode;
  final differenceInDays = _sessionDifferenceInDays(startedAtLocal, now: now);

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
  VideoSessionsRecord session, {
  DateTime? now,
}) {
  final startedAt = resolveSessionStartedAt(session);
  return formatSessionStartedAtFromDateTime(context, startedAt, now: now);
}

String formatSessionStartedAtFromDateTime(
  BuildContext context,
  DateTime? startedAt, {
  DateTime? now,
}) {
  if (startedAt == null) {
    return '-';
  }

  final startedAtLocal = startedAt.toLocal();
  final dateLabel =
      _sessionRelativeDateLabel(context, startedAtLocal, now: now);
  final timeLabel = _sessionTimeLabel(context, startedAtLocal);

  return '$dateLabel, $timeLabel';
}

String formatSessionStartedAtForCard(
  BuildContext context,
  VideoSessionsRecord session, {
  DateTime? now,
}) {
  final startedAt = resolveSessionStartedAt(session);
  if (startedAt == null) {
    return '-';
  }

  final startedAtLocal = startedAt.toLocal();
  final dateLabel =
      _sessionRelativeDateLabel(context, startedAtLocal, now: now);
  final timeLabel = _sessionTimeLabel(context, startedAtLocal);

  if (_sessionDifferenceInDays(startedAtLocal, now: now) == 0) {
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
