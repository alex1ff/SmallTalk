// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CallRequestResponseStruct extends FFFirebaseStruct {
  CallRequestResponseStruct({
    CallStatus? status,
    String? message,
    String? sessionId,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _status = status,
        _message = message,
        _sessionId = sessionId,
        super(firestoreUtilData);

  // "status" field.
  CallStatus? _status;
  CallStatus? get status => _status;
  set status(CallStatus? val) => _status = val;

  bool hasStatus() => _status != null;

  // "message" field.
  String? _message;
  String get message => _message ?? '';
  set message(String? val) => _message = val;

  bool hasMessage() => _message != null;

  // "sessionId" field.
  String? _sessionId;
  String get sessionId => _sessionId ?? '';
  set sessionId(String? val) => _sessionId = val;

  bool hasSessionId() => _sessionId != null;

  static CallRequestResponseStruct fromMap(Map<String, dynamic> data) =>
      CallRequestResponseStruct(
        status: data['status'] is CallStatus
            ? data['status']
            : deserializeEnum<CallStatus>(data['status']),
        message: data['message'] as String?,
        sessionId: data['sessionId'] as String?,
      );

  static CallRequestResponseStruct? maybeFromMap(dynamic data) => data is Map
      ? CallRequestResponseStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'status': _status?.serialize(),
        'message': _message,
        'sessionId': _sessionId,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'status': serializeParam(
          _status,
          ParamType.Enum,
        ),
        'message': serializeParam(
          _message,
          ParamType.String,
        ),
        'sessionId': serializeParam(
          _sessionId,
          ParamType.String,
        ),
      }.withoutNulls;

  static CallRequestResponseStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      CallRequestResponseStruct(
        status: deserializeParam<CallStatus>(
          data['status'],
          ParamType.Enum,
          false,
        ),
        message: deserializeParam(
          data['message'],
          ParamType.String,
          false,
        ),
        sessionId: deserializeParam(
          data['sessionId'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'CallRequestResponseStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is CallRequestResponseStruct &&
        status == other.status &&
        message == other.message &&
        sessionId == other.sessionId;
  }

  @override
  int get hashCode => const ListEquality().hash([status, message, sessionId]);
}

CallRequestResponseStruct createCallRequestResponseStruct({
  CallStatus? status,
  String? message,
  String? sessionId,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    CallRequestResponseStruct(
      status: status,
      message: message,
      sessionId: sessionId,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

CallRequestResponseStruct? updateCallRequestResponseStruct(
  CallRequestResponseStruct? callRequestResponse, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    callRequestResponse
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addCallRequestResponseStructData(
  Map<String, dynamic> firestoreData,
  CallRequestResponseStruct? callRequestResponse,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (callRequestResponse == null) {
    return;
  }
  if (callRequestResponse.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && callRequestResponse.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final callRequestResponseData =
      getCallRequestResponseFirestoreData(callRequestResponse, forFieldValue);
  final nestedData =
      callRequestResponseData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields =
      callRequestResponse.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getCallRequestResponseFirestoreData(
  CallRequestResponseStruct? callRequestResponse, [
  bool forFieldValue = false,
]) {
  if (callRequestResponse == null) {
    return {};
  }
  final firestoreData = mapToFirestore(callRequestResponse.toMap());

  // Add any Firestore field values
  callRequestResponse.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getCallRequestResponseListFirestoreData(
  List<CallRequestResponseStruct>? callRequestResponses,
) =>
    callRequestResponses
        ?.map((e) => getCallRequestResponseFirestoreData(e, true))
        .toList() ??
    [];
