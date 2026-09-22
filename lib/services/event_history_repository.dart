import 'package:cloud_functions/cloud_functions.dart';

typedef EventHistoryCallableInvoker = Future<Object?> Function(
  String functionName,
  Map<String, dynamic> payload,
);

const getEventHistoryFunctionName = 'getEventHistory';
const eventHistoryDefaultLimit = 20;
const eventHistoryMaxLimit = 50;

final RegExp _strictUtcIsoMillisPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$',
);

enum EventHistoryTimelineStatus {
  upcoming('upcoming'),
  past('past'),
  canceled('canceled'),
  left('left');

  const EventHistoryTimelineStatus(this.code);

  final String code;
}

class EventHistoryItem {
  const EventHistoryItem({
    required this.eventId,
    required this.title,
    required this.startsAt,
    required this.timeZoneId,
    required this.status,
    required this.participantRole,
    required this.participantStatus,
    required this.joinedAt,
    required this.timelineStatus,
    this.canceledAt,
    this.leftAt,
    this.locationName,
    this.countryCode,
    this.cityKey,
    this.cityNameEn,
    this.cityNameRu,
    this.languageCode,
    this.languageNameEn,
    this.languageNameRu,
    this.levelMin,
    this.levelMax,
    this.description,
    this.organizerDisplayName,
    this.organizerPhotoUrl,
    this.participantsCount,
    this.capacity,
  });

  final String eventId;
  final String title;
  final DateTime startsAt;
  final String timeZoneId;
  final String status;
  final DateTime? canceledAt;
  final String participantRole;
  final String participantStatus;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final EventHistoryTimelineStatus timelineStatus;
  final String? locationName;
  final String? countryCode;
  final String? cityKey;
  final String? cityNameEn;
  final String? cityNameRu;
  final String? languageCode;
  final String? languageNameEn;
  final String? languageNameRu;
  final String? levelMin;
  final String? levelMax;
  final String? description;
  final String? organizerDisplayName;
  final String? organizerPhotoUrl;
  final int? participantsCount;
  final int? capacity;

  bool get isOrganizer => participantRole == 'organizer';
}

class EventHistoryResult {
  const EventHistoryResult({
    required this.items,
    required this.limit,
    required this.generatedAt,
  });

  final List<EventHistoryItem> items;
  final int limit;
  final DateTime generatedAt;
}

class EventHistoryRepository {
  const EventHistoryRepository._();

  static Future<EventHistoryResult> loadEventHistory({
    int limit = eventHistoryDefaultLimit,
    EventHistoryCallableInvoker? invoker,
  }) async {
    final normalizedLimit = normalizeEventHistoryLimit(limit);
    final responseData = await _callEventHistoryFunction(
      getEventHistoryFunctionName,
      <String, dynamic>{'limit': normalizedLimit},
      invoker: invoker,
    );
    final data = _responseMap(responseData);
    final items = _requiredList(data, 'items')
        .map(_parseHistoryItem)
        .toList(growable: false);

    return EventHistoryResult(
      items: List.unmodifiable(items),
      limit: _requiredInt(data, 'limit'),
      generatedAt: _requiredIsoDateTime(data, 'generatedAt'),
    );
  }
}

int normalizeEventHistoryLimit(int limit) {
  if (limit < 1 || limit > eventHistoryMaxLimit) {
    throw ArgumentError.value(
      limit,
      'limit',
      'Expected event history limit from 1 to $eventHistoryMaxLimit.',
    );
  }
  return limit;
}

Future<Object?> _callEventHistoryFunction(
  String functionName,
  Map<String, dynamic> payload, {
  EventHistoryCallableInvoker? invoker,
}) async {
  if (invoker != null) {
    return invoker(functionName, payload);
  }
  final response = await FirebaseFunctions.instance
      .httpsCallable(functionName)
      .call(payload);
  return response.data;
}

EventHistoryItem _parseHistoryItem(Object? value) {
  final data = _responseMap(value);
  final status = _requiredOneOf(
    data,
    'status',
    const <String>{'active', 'canceled'},
  );
  final participantRole = _requiredOneOf(
    data,
    'participantRole',
    const <String>{'organizer', 'participant'},
  );
  final participantStatus = _requiredOneOf(
    data,
    'participantStatus',
    const <String>{'active', 'left'},
  );

  return EventHistoryItem(
    eventId: _requiredString(data, 'eventId'),
    title: _requiredString(data, 'title'),
    startsAt: _requiredIsoDateTime(data, 'startsAt'),
    timeZoneId: _requiredString(data, 'timeZoneId'),
    status: status,
    canceledAt: _optionalIsoDateTime(data, 'canceledAt'),
    participantRole: participantRole,
    participantStatus: participantStatus,
    joinedAt: _requiredIsoDateTime(data, 'joinedAt'),
    leftAt: _optionalIsoDateTime(data, 'leftAt'),
    timelineStatus: _requiredTimelineStatus(data, 'timelineStatus'),
    locationName: _optionalString(data, 'locationName'),
    countryCode: _optionalString(data, 'countryCode'),
    cityKey: _optionalString(data, 'cityKey'),
    cityNameEn: _optionalString(data, 'cityNameEn'),
    cityNameRu: _optionalString(data, 'cityNameRu'),
    languageCode: _optionalString(data, 'languageCode'),
    languageNameEn: _optionalString(data, 'languageNameEn'),
    languageNameRu: _optionalString(data, 'languageNameRu'),
    levelMin: _optionalString(data, 'levelMin'),
    levelMax: _optionalString(data, 'levelMax'),
    description: _optionalString(data, 'description'),
    organizerDisplayName: _optionalString(data, 'organizerDisplayName'),
    organizerPhotoUrl: _optionalString(data, 'organizerPhotoUrl'),
    participantsCount: _optionalInt(data, 'participantsCount'),
    capacity: _optionalInt(data, 'capacity'),
  );
}

Map<String, dynamic> _responseMap(Object? data) {
  if (data is! Map) {
    throw const FormatException('Expected event history response map.');
  }
  final result = <String, dynamic>{};
  for (final entry in data.entries) {
    final key = entry.key;
    if (key is! String) {
      throw const FormatException(
        'Expected event history response map with string keys.',
      );
    }
    result[key] = entry.value;
  }
  return result;
}

List<Object?> _requiredList(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is List) {
    return value.cast<Object?>();
  }
  throw FormatException('Expected list field "$field".');
}

String _requiredString(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('Expected non-empty string field "$field".');
}

String? _optionalString(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value == null) {
    return null;
  }
  if (value is String) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
  throw FormatException('Expected nullable string field "$field".');
}

String _requiredOneOf(
  Map<String, dynamic> data,
  String field,
  Set<String> allowed,
) {
  final value = _requiredString(data, field);
  if (allowed.contains(value)) {
    return value;
  }
  throw FormatException('Expected supported value in "$field".');
}

int _requiredInt(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is int) {
    return value;
  }
  throw FormatException('Expected integer field "$field".');
}

int? _optionalInt(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  throw FormatException('Expected nullable integer field "$field".');
}

EventHistoryTimelineStatus _requiredTimelineStatus(
  Map<String, dynamic> data,
  String field,
) {
  final value = _requiredString(data, field);
  for (final status in EventHistoryTimelineStatus.values) {
    if (status.code == value) {
      return status;
    }
  }
  throw FormatException('Expected supported value in "$field".');
}

DateTime _requiredIsoDateTime(Map<String, dynamic> data, String field) {
  final value = _requiredString(data, field);
  return _parseUtcIsoMillis(value, field);
}

DateTime? _optionalIsoDateTime(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException(
      'Expected UTC ISO-8601 millisecond timestamp field "$field".',
    );
  }
  return _parseUtcIsoMillis(value, field);
}

DateTime _parseUtcIsoMillis(String value, String field) {
  if (!_strictUtcIsoMillisPattern.hasMatch(value)) {
    throw FormatException(
      'Expected UTC ISO-8601 millisecond timestamp field "$field".',
    );
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      !parsed.isUtc ||
      _formatUtcIsoMillisUnchecked(parsed) != value) {
    throw FormatException(
      'Expected UTC ISO-8601 millisecond timestamp field "$field".',
    );
  }
  return parsed;
}

String _formatUtcIsoMillisUnchecked(DateTime utc) => DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
      utc.millisecond,
    ).toIso8601String();
