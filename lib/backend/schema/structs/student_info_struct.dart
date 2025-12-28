// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class StudentInfoStruct extends FFFirebaseStruct {
  StudentInfoStruct({
    String? name,
    String? photo,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _name = name,
        _photo = photo,
        super(firestoreUtilData);

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  set name(String? val) => _name = val;

  bool hasName() => _name != null;

  // "photo" field.
  String? _photo;
  String get photo => _photo ?? '';
  set photo(String? val) => _photo = val;

  bool hasPhoto() => _photo != null;

  static StudentInfoStruct fromMap(Map<String, dynamic> data) =>
      StudentInfoStruct(
        name: data['name'] as String?,
        photo: data['photo'] as String?,
      );

  static StudentInfoStruct? maybeFromMap(dynamic data) => data is Map
      ? StudentInfoStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'name': _name,
        'photo': _photo,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'name': serializeParam(
          _name,
          ParamType.String,
        ),
        'photo': serializeParam(
          _photo,
          ParamType.String,
        ),
      }.withoutNulls;

  static StudentInfoStruct fromSerializableMap(Map<String, dynamic> data) =>
      StudentInfoStruct(
        name: deserializeParam(
          data['name'],
          ParamType.String,
          false,
        ),
        photo: deserializeParam(
          data['photo'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'StudentInfoStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is StudentInfoStruct &&
        name == other.name &&
        photo == other.photo;
  }

  @override
  int get hashCode => const ListEquality().hash([name, photo]);
}

StudentInfoStruct createStudentInfoStruct({
  String? name,
  String? photo,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    StudentInfoStruct(
      name: name,
      photo: photo,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

StudentInfoStruct? updateStudentInfoStruct(
  StudentInfoStruct? studentInfo, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    studentInfo
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addStudentInfoStructData(
  Map<String, dynamic> firestoreData,
  StudentInfoStruct? studentInfo,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (studentInfo == null) {
    return;
  }
  if (studentInfo.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && studentInfo.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final studentInfoData =
      getStudentInfoFirestoreData(studentInfo, forFieldValue);
  final nestedData =
      studentInfoData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = studentInfo.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getStudentInfoFirestoreData(
  StudentInfoStruct? studentInfo, [
  bool forFieldValue = false,
]) {
  if (studentInfo == null) {
    return {};
  }
  final firestoreData = mapToFirestore(studentInfo.toMap());

  // Add any Firestore field values
  studentInfo.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getStudentInfoListFirestoreData(
  List<StudentInfoStruct>? studentInfos,
) =>
    studentInfos?.map((e) => getStudentInfoFirestoreData(e, true)).toList() ??
    [];
