// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class AcceptCallResponseStruct extends FFFirebaseStruct {
  AcceptCallResponseStruct({
    CallStatus? status,
    String? sessionId,
    String? roomUrl,
    String? roomName,
    StudentInfoStruct? studentInfo,
    String? meetingToken,
    SessionDataStruct? sessionData,
    String? code,
    String? message,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _status = status,
        _sessionId = sessionId,
        _roomUrl = roomUrl,
        _roomName = roomName,
        _studentInfo = studentInfo,
        _meetingToken = meetingToken,
        _sessionData = sessionData,
        _code = code,
        _message = message,
        super(firestoreUtilData);

  // "status" field.
  CallStatus? _status;
  CallStatus? get status => _status;
  set status(CallStatus? val) => _status = val;

  bool hasStatus() => _status != null;

  // "sessionId" field.
  String? _sessionId;
  String get sessionId => _sessionId ?? '';
  set sessionId(String? val) => _sessionId = val;

  bool hasSessionId() => _sessionId != null;

  // "roomUrl" field.
  String? _roomUrl;
  String get roomUrl => _roomUrl ?? '';
  set roomUrl(String? val) => _roomUrl = val;

  bool hasRoomUrl() => _roomUrl != null;

  // "roomName" field.
  String? _roomName;
  String get roomName => _roomName ?? '';
  set roomName(String? val) => _roomName = val;

  bool hasRoomName() => _roomName != null;

  // "studentInfo" field.
  StudentInfoStruct? _studentInfo;
  StudentInfoStruct get studentInfo => _studentInfo ?? StudentInfoStruct();
  set studentInfo(StudentInfoStruct? val) => _studentInfo = val;

  void updateStudentInfo(Function(StudentInfoStruct) updateFn) {
    updateFn(_studentInfo ??= StudentInfoStruct());
  }

  bool hasStudentInfo() => _studentInfo != null;

  // "meetingToken" field.
  String? _meetingToken;
  String get meetingToken => _meetingToken ?? '';
  set meetingToken(String? val) => _meetingToken = val;

  bool hasMeetingToken() => _meetingToken != null;

  // "sessionData" field.
  SessionDataStruct? _sessionData;
  SessionDataStruct get sessionData => _sessionData ?? SessionDataStruct();
  set sessionData(SessionDataStruct? val) => _sessionData = val;

  void updateSessionData(Function(SessionDataStruct) updateFn) {
    updateFn(_sessionData ??= SessionDataStruct());
  }

  bool hasSessionData() => _sessionData != null;

  // "code" field.
  String? _code;
  String get code => _code ?? '';
  set code(String? val) => _code = val;

  bool hasCode() => _code != null;

  // "message" field.
  String? _message;
  String get message => _message ?? '';
  set message(String? val) => _message = val;

  bool hasMessage() => _message != null;

  static AcceptCallResponseStruct fromMap(Map<String, dynamic> data) =>
      AcceptCallResponseStruct(
        status: data['status'] is CallStatus
            ? data['status']
            : deserializeEnum<CallStatus>(data['status']),
        sessionId: data['sessionId'] as String?,
        roomUrl: data['roomUrl'] as String?,
        roomName: data['roomName'] as String?,
        studentInfo: data['studentInfo'] is StudentInfoStruct
            ? data['studentInfo']
            : StudentInfoStruct.maybeFromMap(data['studentInfo']),
        meetingToken: data['meetingToken'] as String?,
        sessionData: data['sessionData'] is SessionDataStruct
            ? data['sessionData']
            : SessionDataStruct.maybeFromMap(data['sessionData']),
        code: data['code'] as String?,
        message: data['message'] as String?,
      );

  static AcceptCallResponseStruct? maybeFromMap(dynamic data) => data is Map
      ? AcceptCallResponseStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'status': _status?.serialize(),
        'sessionId': _sessionId,
        'roomUrl': _roomUrl,
        'roomName': _roomName,
        'studentInfo': _studentInfo?.toMap(),
        'meetingToken': _meetingToken,
        'sessionData': _sessionData?.toMap(),
        'code': _code,
        'message': _message,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'status': serializeParam(
          _status,
          ParamType.Enum,
        ),
        'sessionId': serializeParam(
          _sessionId,
          ParamType.String,
        ),
        'roomUrl': serializeParam(
          _roomUrl,
          ParamType.String,
        ),
        'roomName': serializeParam(
          _roomName,
          ParamType.String,
        ),
        'studentInfo': serializeParam(
          _studentInfo,
          ParamType.DataStruct,
        ),
        'meetingToken': serializeParam(
          _meetingToken,
          ParamType.String,
        ),
        'sessionData': serializeParam(
          _sessionData,
          ParamType.DataStruct,
        ),
        'code': serializeParam(
          _code,
          ParamType.String,
        ),
        'message': serializeParam(
          _message,
          ParamType.String,
        ),
      }.withoutNulls;

  static AcceptCallResponseStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      AcceptCallResponseStruct(
        status: deserializeParam<CallStatus>(
          data['status'],
          ParamType.Enum,
          false,
        ),
        sessionId: deserializeParam(
          data['sessionId'],
          ParamType.String,
          false,
        ),
        roomUrl: deserializeParam(
          data['roomUrl'],
          ParamType.String,
          false,
        ),
        roomName: deserializeParam(
          data['roomName'],
          ParamType.String,
          false,
        ),
        studentInfo: deserializeStructParam(
          data['studentInfo'],
          ParamType.DataStruct,
          false,
          structBuilder: StudentInfoStruct.fromSerializableMap,
        ),
        meetingToken: deserializeParam(
          data['meetingToken'],
          ParamType.String,
          false,
        ),
        sessionData: deserializeStructParam(
          data['sessionData'],
          ParamType.DataStruct,
          false,
          structBuilder: SessionDataStruct.fromSerializableMap,
        ),
        code: deserializeParam(
          data['code'],
          ParamType.String,
          false,
        ),
        message: deserializeParam(
          data['message'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'AcceptCallResponseStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is AcceptCallResponseStruct &&
        status == other.status &&
        sessionId == other.sessionId &&
        roomUrl == other.roomUrl &&
        roomName == other.roomName &&
        studentInfo == other.studentInfo &&
        meetingToken == other.meetingToken &&
        sessionData == other.sessionData &&
        code == other.code &&
        message == other.message;
  }

  @override
  int get hashCode => const ListEquality().hash([
        status,
        sessionId,
        roomUrl,
        roomName,
        studentInfo,
        meetingToken,
        sessionData,
        code,
        message
      ]);
}

AcceptCallResponseStruct createAcceptCallResponseStruct({
  CallStatus? status,
  String? sessionId,
  String? roomUrl,
  String? roomName,
  StudentInfoStruct? studentInfo,
  String? meetingToken,
  SessionDataStruct? sessionData,
  String? code,
  String? message,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    AcceptCallResponseStruct(
      status: status,
      sessionId: sessionId,
      roomUrl: roomUrl,
      roomName: roomName,
      studentInfo:
          studentInfo ?? (clearUnsetFields ? StudentInfoStruct() : null),
      meetingToken: meetingToken,
      sessionData:
          sessionData ?? (clearUnsetFields ? SessionDataStruct() : null),
      code: code,
      message: message,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

AcceptCallResponseStruct? updateAcceptCallResponseStruct(
  AcceptCallResponseStruct? acceptCallResponse, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    acceptCallResponse
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addAcceptCallResponseStructData(
  Map<String, dynamic> firestoreData,
  AcceptCallResponseStruct? acceptCallResponse,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (acceptCallResponse == null) {
    return;
  }
  if (acceptCallResponse.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && acceptCallResponse.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final acceptCallResponseData =
      getAcceptCallResponseFirestoreData(acceptCallResponse, forFieldValue);
  final nestedData =
      acceptCallResponseData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields =
      acceptCallResponse.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getAcceptCallResponseFirestoreData(
  AcceptCallResponseStruct? acceptCallResponse, [
  bool forFieldValue = false,
]) {
  if (acceptCallResponse == null) {
    return {};
  }
  final firestoreData = mapToFirestore(acceptCallResponse.toMap());

  // Handle nested data for "studentInfo" field.
  addStudentInfoStructData(
    firestoreData,
    acceptCallResponse.hasStudentInfo() ? acceptCallResponse.studentInfo : null,
    'studentInfo',
    forFieldValue,
  );

  // Handle nested data for "sessionData" field.
  addSessionDataStructData(
    firestoreData,
    acceptCallResponse.hasSessionData() ? acceptCallResponse.sessionData : null,
    'sessionData',
    forFieldValue,
  );

  // Add any Firestore field values
  acceptCallResponse.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getAcceptCallResponseListFirestoreData(
  List<AcceptCallResponseStruct>? acceptCallResponses,
) =>
    acceptCallResponses
        ?.map((e) => getAcceptCallResponseFirestoreData(e, true))
        .toList() ??
    [];
