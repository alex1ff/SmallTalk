// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class SessionDataStruct extends FFFirebaseStruct {
  SessionDataStruct({
    String? language,
    int? startedAt,
    int? maxDuration,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _language = language,
        _startedAt = startedAt,
        _maxDuration = maxDuration,
        super(firestoreUtilData);

  // "language" field.
  String? _language;
  String get language => _language ?? '';
  set language(String? val) => _language = val;

  bool hasLanguage() => _language != null;

  // "startedAt" field.
  int? _startedAt;
  int get startedAt => _startedAt ?? 0;
  set startedAt(int? val) => _startedAt = val;

  void incrementStartedAt(int amount) => startedAt = startedAt + amount;

  bool hasStartedAt() => _startedAt != null;

  // "maxDuration" field.
  int? _maxDuration;
  int get maxDuration => _maxDuration ?? 0;
  set maxDuration(int? val) => _maxDuration = val;

  void incrementMaxDuration(int amount) => maxDuration = maxDuration + amount;

  bool hasMaxDuration() => _maxDuration != null;

  static SessionDataStruct fromMap(Map<String, dynamic> data) =>
      SessionDataStruct(
        language: data['language'] as String?,
        startedAt: castToType<int>(data['startedAt']),
        maxDuration: castToType<int>(data['maxDuration']),
      );

  static SessionDataStruct? maybeFromMap(dynamic data) => data is Map
      ? SessionDataStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'language': _language,
        'startedAt': _startedAt,
        'maxDuration': _maxDuration,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'language': serializeParam(
          _language,
          ParamType.String,
        ),
        'startedAt': serializeParam(
          _startedAt,
          ParamType.int,
        ),
        'maxDuration': serializeParam(
          _maxDuration,
          ParamType.int,
        ),
      }.withoutNulls;

  static SessionDataStruct fromSerializableMap(Map<String, dynamic> data) =>
      SessionDataStruct(
        language: deserializeParam(
          data['language'],
          ParamType.String,
          false,
        ),
        startedAt: deserializeParam(
          data['startedAt'],
          ParamType.int,
          false,
        ),
        maxDuration: deserializeParam(
          data['maxDuration'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'SessionDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is SessionDataStruct &&
        language == other.language &&
        startedAt == other.startedAt &&
        maxDuration == other.maxDuration;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([language, startedAt, maxDuration]);
}

SessionDataStruct createSessionDataStruct({
  String? language,
  int? startedAt,
  int? maxDuration,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    SessionDataStruct(
      language: language,
      startedAt: startedAt,
      maxDuration: maxDuration,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

SessionDataStruct? updateSessionDataStruct(
  SessionDataStruct? sessionData, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    sessionData
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addSessionDataStructData(
  Map<String, dynamic> firestoreData,
  SessionDataStruct? sessionData,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (sessionData == null) {
    return;
  }
  if (sessionData.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && sessionData.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final sessionDataData =
      getSessionDataFirestoreData(sessionData, forFieldValue);
  final nestedData =
      sessionDataData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = sessionData.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getSessionDataFirestoreData(
  SessionDataStruct? sessionData, [
  bool forFieldValue = false,
]) {
  if (sessionData == null) {
    return {};
  }
  final firestoreData = mapToFirestore(sessionData.toMap());

  // Add any Firestore field values
  sessionData.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getSessionDataListFirestoreData(
  List<SessionDataStruct>? sessionDatas,
) =>
    sessionDatas?.map((e) => getSessionDataFirestoreData(e, true)).toList() ??
    [];
