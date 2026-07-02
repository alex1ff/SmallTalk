import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'event_city_catalog.dart';
import 'event_level_helper.dart';

typedef EventCallableInvoker = Future<Object?> Function(
  String functionName,
  Map<String, dynamic> payload,
);

const createEventFunctionName = 'createEvent';
const editEventFunctionName = 'editEvent';
const cancelEventFunctionName = 'cancelEvent';
const joinEventFunctionName = 'joinEvent';
const leaveEventFunctionName = 'leaveEvent';
const sendEventChatMessageFunctionName = 'sendEventChatMessage';
const getEventChatAccessStateFunctionName = 'getEventChatAccessState';
const reportEventFunctionName = 'reportEvent';
const reportEventChatMessageFunctionName = 'reportEventChatMessage';
const openEventOrganizerChatFunctionName = 'openEventOrganizerChat';
const eventReportDetailsMaxLength = 500;
const eventReportReasonCodes = <String>{
  'spam',
  'offensive',
  'unsafe',
  'other',
};

final RegExp _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final RegExp _strictUtcIsoMillisPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$',
);

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
    final levelRange = eventLevelRange(
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

class SendEventChatMessageResult {
  const SendEventChatMessageResult({
    required this.messageId,
    required this.createdAt,
  });

  final String messageId;
  final DateTime createdAt;
}

class EventChatAccessStateResult {
  const EventChatAccessStateResult({
    required this.eventId,
    required this.status,
    required this.readOnly,
  });

  final String eventId;
  final String status;
  final bool readOnly;
}

class EventOrganizerChatResult {
  const EventOrganizerChatResult({
    required this.conversationId,
    required this.conversationPath,
  });

  final String conversationId;
  final String conversationPath;
}

class EventReportResult {
  const EventReportResult({
    required this.eventId,
    required this.reportId,
    required this.status,
    required this.reportedAt,
  });

  final String eventId;
  final String reportId;
  final String status;
  final DateTime reportedAt;

  bool get alreadySubmitted => status == 'already_submitted';
}

class EventChatMessageReportResult {
  const EventChatMessageReportResult({
    required this.eventId,
    required this.messageId,
    required this.reportId,
    required this.status,
    required this.reportedAt,
  });

  final String eventId;
  final String messageId;
  final String reportId;
  final String status;
  final DateTime reportedAt;

  bool get alreadySubmitted => status == 'already_submitted';
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

  static Future<SendEventChatMessageResult> sendEventChatMessage({
    required String eventId,
    required String text,
    EventCallableInvoker? invoker,
  }) async {
    final responseData = await _callEventFunction(
      sendEventChatMessageFunctionName,
      <String, dynamic>{
        'eventId': normalizeEventActionId(eventId),
        'text': text,
      },
      invoker: invoker,
    );
    final data = _responseMap(responseData);
    return SendEventChatMessageResult(
      messageId: _requiredString(data, 'messageId'),
      createdAt: _requiredIsoDateTime(data, 'createdAt'),
    );
  }

  static Future<EventChatAccessStateResult> getEventChatAccessState({
    required String eventId,
    EventCallableInvoker? invoker,
  }) async {
    final responseData = await _callEventFunction(
      getEventChatAccessStateFunctionName,
      _eventIdPayload(eventId),
      invoker: invoker,
    );
    final data = _responseMap(responseData);
    final status = _requiredString(data, 'status');
    if (status != 'active' && status != 'canceled') {
      throw const FormatException(
        'Expected active or canceled event chat access status.',
      );
    }
    return EventChatAccessStateResult(
      eventId: _requiredString(data, 'eventId'),
      status: status,
      readOnly: _requiredBool(data, 'readOnly'),
    );
  }

  static Future<EventReportResult> reportEvent({
    required String eventId,
    required String reasonCode,
    String? details,
    EventCallableInvoker? invoker,
  }) async {
    final normalizedDetails = normalizeEventReportDetails(details);
    final responseData = await _callEventFunction(
      reportEventFunctionName,
      <String, dynamic>{
        'eventId': normalizeEventActionId(eventId),
        'reasonCode': normalizeEventReportReasonCode(reasonCode),
        if (normalizedDetails != null) 'details': normalizedDetails,
      },
      invoker: invoker,
    );
    final data = _responseMap(responseData);
    final status = _requiredString(data, 'status');
    if (status != 'submitted' && status != 'already_submitted') {
      throw const FormatException(
        'Expected submitted or already_submitted event report status.',
      );
    }
    return EventReportResult(
      eventId: _requiredString(data, 'eventId'),
      reportId: _requiredString(data, 'reportId'),
      status: status,
      reportedAt: _requiredIsoDateTime(data, 'reportedAt'),
    );
  }

  static Future<EventChatMessageReportResult> reportEventChatMessage({
    required String eventId,
    required String messageId,
    required String reasonCode,
    String? details,
    EventCallableInvoker? invoker,
  }) async {
    final normalizedDetails = normalizeEventReportDetails(details);
    final responseData = await _callEventFunction(
      reportEventChatMessageFunctionName,
      <String, dynamic>{
        'eventId': normalizeEventActionId(eventId),
        'messageId': normalizeEventActionId(
          messageId,
          fieldName: 'messageId',
        ),
        'reasonCode': normalizeEventReportReasonCode(reasonCode),
        if (normalizedDetails != null) 'details': normalizedDetails,
      },
      invoker: invoker,
    );
    final data = _responseMap(responseData);
    final status = _requiredString(data, 'status');
    if (status != 'submitted' && status != 'already_submitted') {
      throw const FormatException(
        'Expected submitted or already_submitted chat message report status.',
      );
    }
    return EventChatMessageReportResult(
      eventId: _requiredString(data, 'eventId'),
      messageId: _requiredString(data, 'messageId'),
      reportId: _requiredString(data, 'reportId'),
      status: status,
      reportedAt: _requiredIsoDateTime(data, 'reportedAt'),
    );
  }

  static Future<EventOrganizerChatResult> openEventOrganizerChat({
    required String eventId,
    EventCallableInvoker? invoker,
  }) async {
    final responseData = await _callEventFunction(
      openEventOrganizerChatFunctionName,
      _eventIdPayload(eventId),
      invoker: invoker,
    );
    final data = _responseMap(responseData);
    return EventOrganizerChatResult(
      conversationId: _requiredString(data, 'conversationId'),
      conversationPath: _requiredString(data, 'conversationPath'),
    );
  }
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

String normalizeEventActionId(
  String eventId, {
  String fieldName = 'eventId',
}) {
  final normalizedEventId = eventId.trim();
  if (normalizedEventId.isEmpty) {
    throw ArgumentError.value(
      eventId,
      fieldName,
      'Expected a non-empty Firestore document id.',
    );
  }
  if (normalizedEventId == '.' || normalizedEventId == '..') {
    throw ArgumentError.value(
      eventId,
      fieldName,
      'Expected a Firestore document id.',
    );
  }
  if (normalizedEventId.contains('/')) {
    throw ArgumentError.value(
      eventId,
      fieldName,
      'Expected a Firestore document id without path separators.',
    );
  }
  if (RegExp(r'^__.*__$').hasMatch(normalizedEventId)) {
    throw ArgumentError.value(
      eventId,
      fieldName,
      'Expected a non-reserved Firestore document id.',
    );
  }
  if (utf8.encode(normalizedEventId).length > 1500) {
    throw ArgumentError.value(
      eventId,
      fieldName,
      'Expected a Firestore document id no longer than 1500 UTF-8 bytes.',
    );
  }

  return normalizedEventId;
}

String normalizeEventReportReasonCode(String reasonCode) {
  final normalizedReasonCode = reasonCode.trim().toLowerCase();
  if (!eventReportReasonCodes.contains(normalizedReasonCode)) {
    throw ArgumentError.value(
      reasonCode,
      'reasonCode',
      'Expected a supported event report reason code.',
    );
  }
  return normalizedReasonCode;
}

String? normalizeEventReportDetails(String? details) {
  if (details == null) {
    return null;
  }
  final normalizedDetails = details.trim();
  if (normalizedDetails.isEmpty) {
    return null;
  }
  if (normalizedDetails.runes.length > eventReportDetailsMaxLength) {
    throw ArgumentError.value(
      details,
      'details',
      'Expected details no longer than 500 characters.',
    );
  }
  return normalizedDetails;
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

bool _requiredBool(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected boolean field "$field".');
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
