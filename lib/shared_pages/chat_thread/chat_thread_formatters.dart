const Duration chatOnlineThreshold = Duration(minutes: 2);

bool chatPartnerIsOnline(DateTime? lastSeenAt, {DateTime? now}) {
  if (lastSeenAt == null) {
    return false;
  }

  final reference = (now ?? DateTime.now()).toLocal();
  final seenAt = lastSeenAt.toLocal();
  final elapsed = reference.difference(seenAt);
  return !elapsed.isNegative && elapsed < chatOnlineThreshold;
}

String formatChatPresenceLabel(
  DateTime? lastSeenAt, {
  required String locale,
  DateTime? now,
}) {
  if (lastSeenAt == null) {
    return '';
  }

  if (chatPartnerIsOnline(lastSeenAt, now: now)) {
    return locale == 'ru' ? 'онлайн' : 'online';
  }

  final seenAt = lastSeenAt.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final timeLabel = _timeLabel(seenAt, locale);

  if (_isSameCalendarDay(seenAt, reference)) {
    return locale == 'ru'
        ? 'был(а) сегодня в $timeLabel'
        : 'last seen today at $timeLabel';
  }

  if (_isSameCalendarDay(
    seenAt,
    reference.subtract(const Duration(days: 1)),
  )) {
    return locale == 'ru'
        ? 'был(а) вчера в $timeLabel'
        : 'last seen yesterday at $timeLabel';
  }

  final dateLabel = _dateLabel(seenAt, locale);
  return locale == 'ru'
      ? 'был(а) $dateLabel в $timeLabel'
      : 'last seen $dateLabel at $timeLabel';
}

String formatChatDateDividerLabel(
  DateTime? timestamp, {
  required String locale,
  DateTime? now,
}) {
  if (timestamp == null) {
    return '';
  }

  final localTimestamp = timestamp.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final timeLabel = _timeLabel(localTimestamp, locale);

  if (_isSameCalendarDay(localTimestamp, reference)) {
    return locale == 'ru' ? 'Сегодня, $timeLabel' : 'Today, $timeLabel';
  }

  if (_isSameCalendarDay(
    localTimestamp,
    reference.subtract(const Duration(days: 1)),
  )) {
    return locale == 'ru' ? 'Вчера, $timeLabel' : 'Yesterday, $timeLabel';
  }

  return '${_dateLabel(localTimestamp, locale)}, $timeLabel';
}

String _timeLabel(DateTime value, String locale) {
  final hours = value.hour.toString().padLeft(2, '0');
  final minutes = value.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}

bool _isSameCalendarDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _dateLabel(DateTime value, String locale) {
  final months = locale == 'ru' ? _ruMonthLabels : _enMonthLabels;
  return '${value.day} ${months[value.month - 1]}';
}

const _ruMonthLabels = [
  'янв.',
  'февр.',
  'мар.',
  'апр.',
  'мая',
  'июн.',
  'июл.',
  'авг.',
  'сент.',
  'окт.',
  'нояб.',
  'дек.',
];

const _enMonthLabels = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
