// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CancelCallResponseStruct extends FFFirebaseStruct {
  CancelCallResponseStruct({
    CallStatus? status,
    String? message,
    String? callId,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _status = status,
        _message = message,
        _callId = callId,
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

  // "callId" field.
  String? _callId;
  String get callId => _callId ?? '';
  set callId(String? val) => _callId = val;

  bool hasCallId() => _callId != null;

  static CancelCallResponseStruct fromMap(Map<String, dynamic> data) =>
      CancelCallResponseStruct(
        status: data['status'] is CallStatus
            ? data['status']
            : deserializeEnum<CallStatus>(data['status']),
        message: data['message'] as String?,
        callId: data['callId'] as String?,
      );

  static CancelCallResponseStruct? maybeFromMap(dynamic data) => data is Map
      ? CancelCallResponseStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'status': _status?.serialize(),
        'message': _message,
        'callId': _callId,
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
        'callId': serializeParam(
          _callId,
          ParamType.String,
        ),
      }.withoutNulls;

  static CancelCallResponseStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      CancelCallResponseStruct(
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
        callId: deserializeParam(
          data['callId'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'CancelCallResponseStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is CancelCallResponseStruct &&
        status == other.status &&
        message == other.message &&
        callId == other.callId;
  }

  @override
  int get hashCode => const ListEquality().hash([status, message, callId]);
}

CancelCallResponseStruct createCancelCallResponseStruct({
  CallStatus? status,
  String? message,
  String? callId,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    CancelCallResponseStruct(
      status: status,
      message: message,
      callId: callId,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

CancelCallResponseStruct? updateCancelCallResponseStruct(
  CancelCallResponseStruct? cancelCallResponse, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    cancelCallResponse
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addCancelCallResponseStructData(
  Map<String, dynamic> firestoreData,
  CancelCallResponseStruct? cancelCallResponse,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (cancelCallResponse == null) {
    return;
  }
  if (cancelCallResponse.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && cancelCallResponse.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final cancelCallResponseData =
      getCancelCallResponseFirestoreData(cancelCallResponse, forFieldValue);
  final nestedData =
      cancelCallResponseData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields =
      cancelCallResponse.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getCancelCallResponseFirestoreData(
  CancelCallResponseStruct? cancelCallResponse, [
  bool forFieldValue = false,
]) {
  if (cancelCallResponse == null) {
    return {};
  }
  final firestoreData = mapToFirestore(cancelCallResponse.toMap());

  // Add any Firestore field values
  cancelCallResponse.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getCancelCallResponseListFirestoreData(
  List<CancelCallResponseStruct>? cancelCallResponses,
) =>
    cancelCallResponses
        ?.map((e) => getCancelCallResponseFirestoreData(e, true))
        .toList() ??
    [];
