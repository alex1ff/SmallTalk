import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'event_city_catalog.dart';

typedef EventCallableInvoker = Future<Object?> Function(
  String functionName,
  Map<String, dynamic> payload,
);

const createEventFunctionName = 'createEvent';
const editEventFunctionName = 'editEvent';
const cancelEventFunctionName = 'cancelEvent';
const joinEventFunctionName = 'joinEvent';
const leaveEventFunctionName = 'leaveEvent';

final RegExp _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final RegExp _strictUtcIsoMillisPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$',
);
const _eventActionLevelRanks = <String, int>{
  'A1': 0,
  'A2': 1,
  'B1': 2,
  'B2': 3,
  'C1': 4,
  'C2': 5,
};

class EventEditableFields {
  const EventEditableFields({
    required this.title,
    required this.description,
    required this.languageCode,
    required this.levelMin,
    required this.levelMax,
    required this.countryCode,
    required this.cityKey,
    required this.locationName,
    required this.locationGeoPoint,
    required this.startsAt,
    required this.capacity,
  });

  final String title;
  final String description;
  final String languageCode;
  final String levelMin;
  final String levelMax;
  final String countryCode;
  final String cityKey;
  final String locationName;
  final LatLng? locationGeoPoint;
  final DateTime startsAt;
  final int capacity;

  Map<String, dynamic> toCreatePayload({required String createRequestId}) =>
      <String, dynamic>{
        'createRequestId': normalizeEventCreateRequestId(createRequestId),
        ..._editablePayload,
      };

  Map<String, dynamic> toEditPayload({required String eventId}) =>
      <String, dynamic>{
        'eventId': normalizeEventActionId(eventId),
        ..._editablePayload,
      };

  Map<String, dynamic> get _editablePayload {
    final cityIdentity = _normalizeEventActionCity(
      countryCode: countryCode,
      cityKey: cityKey,
    );
    final levelRange = _normalizeEventActionLevelRange(
      levelMin: levelMin,
      levelMax: levelMax,
    );

    return <String, dynamic>{
      'title': title,
      'description': description,
      'languageCode': languageCode,
      'levelMin': levelRange.levelMin,
      'levelMax': levelRange.levelMax,
      'countryCode': cityIdentity.countryCode,
      'cityKey': cityIdentity.cityKey,
      'locationName': locationName,
      'locationGeoPoint': _serializeLatLng(locationGeoPoint),
      'startsAt': formatUtcIsoMillis(startsAt),
      'capacity': _normalizeEventActionCapacity(capacity),
    };
  }
}

class EventDailyCreationResult {
  const EventDailyCreationResult({
    required this.dayKeyUtc,
    required this.count,
    required this.remaining,
    required this.resetAtUtc,
  });

  final String dayKeyUtc;
  final int count;
  final int remaining;
  final DateTime resetAtUtc;
}

class CreateEventResult {
  const CreateEventResult({
    required this.eventId,
    required this.createdAt,
    required this.dailyCreation,
  });

  final String eventId;
  final DateTime createdAt;
  final EventDailyCreationResult dailyCreation;
}

class EditEventResult {
  const EditEventResult({
    required this.eventId,
    required this.updatedAt,
  });

  final String eventId;
  final DateTime updatedAt;
}

class CancelEventResult {
  const CancelEventResult({
    required this.eventId,
    required this.status,
    required this.canceledAt,
  });

  final String eventId;
  final String status;
  final DateTime canceledAt;
}

class EventParticipantActionResult {
  const EventParticipantActionResult({
    required this.eventId,
    required this.participantStatus,
    required this.participantsCount,
    required this.occurredAt,
  });

  final String eventId;
  final String participantStatus;
  final int participantsCount;
  final DateTime occurredAt;
}

class EventActionsRepository {
  const EventActionsRepository._();

  static Future<CreateEventResult> createEvent({
    required String createRequestId,
    required EventEditableFields fields,
    EventCallableInvoker? invoker,
  }) async {
    final responseData = await _callEventFunction(
      createEventFunctionName,
      fields.toCreatePayload(createRequestId: createRequestId),
      invoker: invoker,
    );
    final data = _responseMap(responseData);
    return CreateEventResult(
      eventId: _requiredString(data, 'eventId'),
      createdAt: _requiredIsoDateTime(data, 'createdAt'),
      dailyCreation: _parseDailyCreation(data['dailyCreation']),
    );
  }

  static Future<EditEventResult> editEvent({
    required String eventId,
    required EventEditableFields fields,
    EventCallableInvoker? invoker,
  }) async {
    final responseData = await _callEventFunction(
      editEventFunctionName,
      fields.toEditPayload(eventId: eventId),
      invoker: invoker,
    );
    final data = _responseMap(responseData);
    return EditEventResult(
      eventId: _requiredString(data, 'eventId'),
      updatedAt: _requiredIsoDateTime(data, 'updatedAt'),
    );
  }

  static Future<CancelEventResult> cancelEvent({
    required String eventId,
    EventCallableInvoker? invoker,
  }) async {
    final responseData = await _callEventFunction(
      cancelEventFunctionName,
      _eventIdPayload(eventId),
      invoker: invoker,
    );
    final data = _responseMap(responseData);
    return CancelEventResult(
      eventId: _requiredString(data, 'eventId'),
      status: _requiredExactString(data, 'status', 'canceled'),
      canceledAt: _requiredIsoDateTime(data, 'canceledAt'),
    );
  }

  static Future<EventParticipantActionResult> joinEvent({
    required String eventId,
    EventCallableInvoker? invoker,
  }) =>
      _callParticipantAction(
        functionName: joinEventFunctionName,
        eventId: eventId,
        expectedParticipantStatus: 'active',
        timestampField: 'joinedAt',
        invoker: invoker,
      );

  static Future<EventParticipantActionResult> leaveEvent({
    required String eventId,
    EventCallableInvoker? invoker,
  }) =>
      _callParticipantAction(
        functionName: leaveEventFunctionName,
        eventId: eventId,
        expectedParticipantStatus: 'left',
        timestampField: 'leftAt',
        invoker: invoker,
      );
}

String newEventCreateRequestId() => const Uuid().v4();

String normalizeEventCreateRequestId(String createRequestId) {
  final normalizedCreateRequestId = createRequestId.trim().toLowerCase();
  if (!_uuidV4Pattern.hasMatch(normalizedCreateRequestId)) {
    throw ArgumentError.value(
      createRequestId,
      'createRequestId',
      'Expected a UUID v4 create request id.',
    );
  }
  return normalizedCreateRequestId;
}

String normalizeEventActionId(String eventId) {
  final normalizedEventId = eventId.trim();
  if (normalizedEventId.isEmpty) {
    throw ArgumentError.value(
      eventId,
      'eventId',
      'Expected a non-empty event id.',
    );
  }
  if (normalizedEventId == '.' || normalizedEventId == '..') {
    throw ArgumentError.value(
      eventId,
      'eventId',
      'Expected a Firestore document id.',
    );
  }
  if (normalizedEventId.contains('/')) {
    throw ArgumentError.value(
      eventId,
      'eventId',
      'Expected an event id without path separators.',
    );
  }
  if (RegExp(r'^__.*__$').hasMatch(normalizedEventId)) {
    throw ArgumentError.value(
      eventId,
      'eventId',
      'Expected a non-reserved Firestore document id.',
    );
  }
  if (utf8.encode(normalizedEventId).length > 1500) {
    throw ArgumentError.value(
      eventId,
      'eventId',
      'Expected an event id no longer than 1500 UTF-8 bytes.',
    );
  }

  return normalizedEventId;
}

String formatUtcIsoMillis(DateTime value) {
  final utc = _normalizeEventActionStartsAt(value);
  final formatted = _formatUtcIsoMillisUnchecked(utc);
  if (!_strictUtcIsoMillisPattern.hasMatch(formatted)) {
    throw ArgumentError.value(
      value,
      'startsAt',
      'Expected a four-digit UTC ISO-8601 millisecond timestamp.',
    );
  }
  return formatted;
}

EventCityIdentity _normalizeEventActionCity({
  required String countryCode,
  required String cityKey,
}) {
  final cityIdentity = normalizeEventCityIdentity(countryCode, cityKey);
  if (cityIdentity == null) {
    throw ArgumentError.value(
      '$countryCode:$cityKey',
      'countryCode/cityKey',
      'Expected a well-formed event city identity.',
    );
  }
  return cityIdentity;
}

({String levelMin, String levelMax}) _normalizeEventActionLevelRange({
  required String levelMin,
  required String levelMax,
}) {
  final normalizedLevelMin = _normalizeEventActionLevel(levelMin, 'levelMin');
  final normalizedLevelMax = _normalizeEventActionLevel(levelMax, 'levelMax');
  if (_eventActionLevelRanks[normalizedLevelMin]! >
      _eventActionLevelRanks[normalizedLevelMax]!) {
    throw ArgumentError.value(
      '$levelMin:$levelMax',
      'levelRange',
      'Expected levelMin to be less than or equal to levelMax.',
    );
  }
  return (levelMin: normalizedLevelMin, levelMax: normalizedLevelMax);
}

String _normalizeEventActionLevel(String level, String name) {
  final normalizedLevel = level.trim().toUpperCase();
  if (!_eventActionLevelRanks.containsKey(normalizedLevel)) {
    throw ArgumentError.value(
      level,
      name,
      'Expected a canonical CEFR level code.',
    );
  }
  return normalizedLevel;
}

DateTime _normalizeEventActionStartsAt(DateTime startsAt) {
  if (!startsAt.isUtc) {
    throw ArgumentError.value(
      startsAt,
      'startsAt',
      'Expected a UTC DateTime.',
    );
  }
  return startsAt;
}

int _normalizeEventActionCapacity(int capacity) {
  if (capacity < 2 || capacity > 50) {
    throw ArgumentError.value(
      capacity,
      'capacity',
      'Expected capacity between 2 and 50.',
    );
  }
  return capacity;
}

Map<String, dynamic> _eventIdPayload(String eventId) => <String, dynamic>{
      'eventId': normalizeEventActionId(eventId),
    };

Future<EventParticipantActionResult> _callParticipantAction({
  required String functionName,
  required String eventId,
  required String expectedParticipantStatus,
  required String timestampField,
  EventCallableInvoker? invoker,
}) async {
  final responseData = await _callEventFunction(
    functionName,
    _eventIdPayload(eventId),
    invoker: invoker,
  );
  final data = _responseMap(responseData);
  return EventParticipantActionResult(
    eventId: _requiredString(data, 'eventId'),
    participantStatus: _requiredExactString(
      data,
      'participantStatus',
      expectedParticipantStatus,
    ),
    participantsCount: _requiredInt(data, 'participantsCount'),
    occurredAt: _requiredIsoDateTime(data, timestampField),
  );
}

Future<Object?> _callEventFunction(
  String functionName,
  Map<String, dynamic> payload, {
  EventCallableInvoker? invoker,
}) async {
  if (invoker != null) {
    return invoker(functionName, payload);
  }
  final response = await FirebaseFunctions.instance
      .httpsCallable(functionName)
      .call(payload);
  return response.data;
}

Map<String, dynamic>? _serializeLatLng(LatLng? locationGeoPoint) {
  if (locationGeoPoint == null) {
    return null;
  }
  final latitude = locationGeoPoint.latitude;
  final longitude = locationGeoPoint.longitude;
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    throw ArgumentError.value(
      locationGeoPoint,
      'locationGeoPoint',
      'Expected valid latitude and longitude values.',
    );
  }
  return <String, dynamic>{
    'latitude': latitude,
    'longitude': longitude,
  };
}

Map<String, dynamic> _responseMap(Object? data) {
  if (data is! Map) {
    throw const FormatException('Expected event function response map.');
  }
  final result = <String, dynamic>{};
  for (final entry in data.entries) {
    final key = entry.key;
    if (key is! String) {
      throw const FormatException(
        'Expected event function response map with string keys.',
      );
    }
    result[key] = entry.value;
  }
  return result;
}

EventDailyCreationResult _parseDailyCreation(Object? value) {
  final data = _responseMap(value);
  return EventDailyCreationResult(
    dayKeyUtc: _requiredString(data, 'dayKeyUtc'),
    count: _requiredInt(data, 'count'),
    remaining: _requiredInt(data, 'remaining'),
    resetAtUtc: _requiredIsoDateTime(data, 'resetAtUtc'),
  );
}

String _requiredString(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('Expected non-empty string field "$field".');
}

String _requiredExactString(
  Map<String, dynamic> data,
  String field,
  String expected,
) {
  final value = _requiredString(data, field);
  if (value == expected) {
    return value;
  }
  throw FormatException('Expected "$expected" in string field "$field".');
}

int _requiredInt(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is int) {
    return value;
  }
  throw FormatException('Expected integer field "$field".');
}

DateTime _requiredIsoDateTime(Map<String, dynamic> data, String field) {
  final value = _requiredString(data, field);
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
