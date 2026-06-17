const eventLevelRanks = <String, int>{
  'A1': 0,
  'A2': 1,
  'B1': 2,
  'B2': 3,
  'C1': 4,
  'C2': 5,
};

class EventLevelRange {
  const EventLevelRange._({
    required this.levelMin,
    required this.levelMax,
    required this.minRank,
    required this.maxRank,
  });

  final String levelMin;
  final String levelMax;
  final int minRank;
  final int maxRank;

  bool overlaps(EventLevelRange other) =>
      minRank <= other.maxRank && other.minRank <= maxRank;
}

EventLevelRange eventLevelRange({
  required String levelMin,
  required String levelMax,
}) {
  final minCode = normalizeEventLevelCode(levelMin, 'levelMin');
  final maxCode = normalizeEventLevelCode(levelMax, 'levelMax');
  final minRank = eventLevelRanks[minCode]!;
  final maxRank = eventLevelRanks[maxCode]!;
  if (minRank > maxRank) {
    throw ArgumentError.value(
      '$levelMin:$levelMax',
      'levelRange',
      'Expected levelMin to be less than or equal to levelMax.',
    );
  }
  return EventLevelRange._(
    levelMin: minCode,
    levelMax: maxCode,
    minRank: minRank,
    maxRank: maxRank,
  );
}

EventLevelRange? selectedEventLevelRange(String? selectedLevel) {
  final normalizedLevel = selectedLevel?.trim();
  if (normalizedLevel == null || normalizedLevel.isEmpty) {
    return null;
  }
  return eventLevelRange(
    levelMin: normalizedLevel,
    levelMax: normalizedLevel,
  );
}

EventLevelRange? tryEventLevelRange({
  required String levelMin,
  required String levelMax,
}) {
  try {
    return eventLevelRange(
      levelMin: levelMin,
      levelMax: levelMax,
    );
  } on ArgumentError {
    return null;
  }
}

String normalizeEventLevelCode(String levelCode, String name) {
  final normalizedLevelCode = levelCode.trim().toUpperCase();
  if (!eventLevelRanks.containsKey(normalizedLevelCode)) {
    throw ArgumentError.value(
      levelCode,
      name,
      'Expected a canonical CEFR level code.',
    );
  }
  return normalizedLevelCode;
}
