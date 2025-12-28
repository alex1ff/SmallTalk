// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class GetSessionTokensResponseStruct extends FFFirebaseStruct {
  GetSessionTokensResponseStruct({
    String? status,
    String? sessionId,
    String? roomUrl,
    String? roomName,
    TutorInfoStruct? tutorInfo,
    String? meetingToken,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _status = status,
        _sessionId = sessionId,
        _roomUrl = roomUrl,
        _roomName = roomName,
        _tutorInfo = tutorInfo,
        _meetingToken = meetingToken,
        super(firestoreUtilData);

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  set status(String? val) => _status = val;

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

  // "tutorInfo" field.
  TutorInfoStruct? _tutorInfo;
  TutorInfoStruct get tutorInfo => _tutorInfo ?? TutorInfoStruct();
  set tutorInfo(TutorInfoStruct? val) => _tutorInfo = val;

  void updateTutorInfo(Function(TutorInfoStruct) updateFn) {
    updateFn(_tutorInfo ??= TutorInfoStruct());
  }

  bool hasTutorInfo() => _tutorInfo != null;

  // "meetingToken" field.
  String? _meetingToken;
  String get meetingToken => _meetingToken ?? '';
  set meetingToken(String? val) => _meetingToken = val;

  bool hasMeetingToken() => _meetingToken != null;

  static GetSessionTokensResponseStruct fromMap(Map<String, dynamic> data) =>
      GetSessionTokensResponseStruct(
        status: data['status'] as String?,
        sessionId: data['sessionId'] as String?,
        roomUrl: data['roomUrl'] as String?,
        roomName: data['roomName'] as String?,
        tutorInfo: data['tutorInfo'] is TutorInfoStruct
            ? data['tutorInfo']
            : TutorInfoStruct.maybeFromMap(data['tutorInfo']),
        meetingToken: data['meetingToken'] as String?,
      );

  static GetSessionTokensResponseStruct? maybeFromMap(dynamic data) =>
      data is Map
          ? GetSessionTokensResponseStruct.fromMap(data.cast<String, dynamic>())
          : null;

  Map<String, dynamic> toMap() => {
        'status': _status,
        'sessionId': _sessionId,
        'roomUrl': _roomUrl,
        'roomName': _roomName,
        'tutorInfo': _tutorInfo?.toMap(),
        'meetingToken': _meetingToken,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'status': serializeParam(
          _status,
          ParamType.String,
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
        'tutorInfo': serializeParam(
          _tutorInfo,
          ParamType.DataStruct,
        ),
        'meetingToken': serializeParam(
          _meetingToken,
          ParamType.String,
        ),
      }.withoutNulls;

  static GetSessionTokensResponseStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      GetSessionTokensResponseStruct(
        status: deserializeParam(
          data['status'],
          ParamType.String,
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
        tutorInfo: deserializeStructParam(
          data['tutorInfo'],
          ParamType.DataStruct,
          false,
          structBuilder: TutorInfoStruct.fromSerializableMap,
        ),
        meetingToken: deserializeParam(
          data['meetingToken'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'GetSessionTokensResponseStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is GetSessionTokensResponseStruct &&
        status == other.status &&
        sessionId == other.sessionId &&
        roomUrl == other.roomUrl &&
        roomName == other.roomName &&
        tutorInfo == other.tutorInfo &&
        meetingToken == other.meetingToken;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([status, sessionId, roomUrl, roomName, tutorInfo, meetingToken]);
}

GetSessionTokensResponseStruct createGetSessionTokensResponseStruct({
  String? status,
  String? sessionId,
  String? roomUrl,
  String? roomName,
  TutorInfoStruct? tutorInfo,
  String? meetingToken,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    GetSessionTokensResponseStruct(
      status: status,
      sessionId: sessionId,
      roomUrl: roomUrl,
      roomName: roomName,
      tutorInfo: tutorInfo ?? (clearUnsetFields ? TutorInfoStruct() : null),
      meetingToken: meetingToken,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

GetSessionTokensResponseStruct? updateGetSessionTokensResponseStruct(
  GetSessionTokensResponseStruct? getSessionTokensResponse, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    getSessionTokensResponse
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addGetSessionTokensResponseStructData(
  Map<String, dynamic> firestoreData,
  GetSessionTokensResponseStruct? getSessionTokensResponse,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (getSessionTokensResponse == null) {
    return;
  }
  if (getSessionTokensResponse.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields = !forFieldValue &&
      getSessionTokensResponse.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final getSessionTokensResponseData = getGetSessionTokensResponseFirestoreData(
      getSessionTokensResponse, forFieldValue);
  final nestedData =
      getSessionTokensResponseData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields =
      getSessionTokensResponse.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getGetSessionTokensResponseFirestoreData(
  GetSessionTokensResponseStruct? getSessionTokensResponse, [
  bool forFieldValue = false,
]) {
  if (getSessionTokensResponse == null) {
    return {};
  }
  final firestoreData = mapToFirestore(getSessionTokensResponse.toMap());

  // Handle nested data for "tutorInfo" field.
  addTutorInfoStructData(
    firestoreData,
    getSessionTokensResponse.hasTutorInfo()
        ? getSessionTokensResponse.tutorInfo
        : null,
    'tutorInfo',
    forFieldValue,
  );

  // Add any Firestore field values
  getSessionTokensResponse.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getGetSessionTokensResponseListFirestoreData(
  List<GetSessionTokensResponseStruct>? getSessionTokensResponses,
) =>
    getSessionTokensResponses
        ?.map((e) => getGetSessionTokensResponseFirestoreData(e, true))
        .toList() ??
    [];
