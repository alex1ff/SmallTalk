// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class CreateDailyRoomResponseStruct extends FFFirebaseStruct {
  CreateDailyRoomResponseStruct({
    String? name,
    String? url,
    String? token,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _name = name,
        _url = url,
        _token = token,
        super(firestoreUtilData);

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  set name(String? val) => _name = val;

  bool hasName() => _name != null;

  // "url" field.
  String? _url;
  String get url => _url ?? '';
  set url(String? val) => _url = val;

  bool hasUrl() => _url != null;

  // "token" field.
  String? _token;
  String get token => _token ?? '';
  set token(String? val) => _token = val;

  bool hasToken() => _token != null;

  static CreateDailyRoomResponseStruct fromMap(Map<String, dynamic> data) =>
      CreateDailyRoomResponseStruct(
        name: data['name'] as String?,
        url: data['url'] as String?,
        token: data['token'] as String?,
      );

  static CreateDailyRoomResponseStruct? maybeFromMap(dynamic data) =>
      data is Map
          ? CreateDailyRoomResponseStruct.fromMap(data.cast<String, dynamic>())
          : null;

  Map<String, dynamic> toMap() => {
        'name': _name,
        'url': _url,
        'token': _token,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'name': serializeParam(
          _name,
          ParamType.String,
        ),
        'url': serializeParam(
          _url,
          ParamType.String,
        ),
        'token': serializeParam(
          _token,
          ParamType.String,
        ),
      }.withoutNulls;

  static CreateDailyRoomResponseStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      CreateDailyRoomResponseStruct(
        name: deserializeParam(
          data['name'],
          ParamType.String,
          false,
        ),
        url: deserializeParam(
          data['url'],
          ParamType.String,
          false,
        ),
        token: deserializeParam(
          data['token'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'CreateDailyRoomResponseStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is CreateDailyRoomResponseStruct &&
        name == other.name &&
        url == other.url &&
        token == other.token;
  }

  @override
  int get hashCode => const ListEquality().hash([name, url, token]);
}

CreateDailyRoomResponseStruct createCreateDailyRoomResponseStruct({
  String? name,
  String? url,
  String? token,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    CreateDailyRoomResponseStruct(
      name: name,
      url: url,
      token: token,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

CreateDailyRoomResponseStruct? updateCreateDailyRoomResponseStruct(
  CreateDailyRoomResponseStruct? createDailyRoomResponse, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    createDailyRoomResponse
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addCreateDailyRoomResponseStructData(
  Map<String, dynamic> firestoreData,
  CreateDailyRoomResponseStruct? createDailyRoomResponse,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (createDailyRoomResponse == null) {
    return;
  }
  if (createDailyRoomResponse.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields = !forFieldValue &&
      createDailyRoomResponse.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final createDailyRoomResponseData = getCreateDailyRoomResponseFirestoreData(
      createDailyRoomResponse, forFieldValue);
  final nestedData =
      createDailyRoomResponseData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields =
      createDailyRoomResponse.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getCreateDailyRoomResponseFirestoreData(
  CreateDailyRoomResponseStruct? createDailyRoomResponse, [
  bool forFieldValue = false,
]) {
  if (createDailyRoomResponse == null) {
    return {};
  }
  final firestoreData = mapToFirestore(createDailyRoomResponse.toMap());

  // Add any Firestore field values
  createDailyRoomResponse.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getCreateDailyRoomResponseListFirestoreData(
  List<CreateDailyRoomResponseStruct>? createDailyRoomResponses,
) =>
    createDailyRoomResponses
        ?.map((e) => getCreateDailyRoomResponseFirestoreData(e, true))
        .toList() ??
    [];
