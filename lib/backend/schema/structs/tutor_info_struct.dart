// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class TutorInfoStruct extends FFFirebaseStruct {
  TutorInfoStruct({
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

  static TutorInfoStruct fromMap(Map<String, dynamic> data) => TutorInfoStruct(
        name: data['name'] as String?,
        photo: data['photo'] as String?,
      );

  static TutorInfoStruct? maybeFromMap(dynamic data) => data is Map
      ? TutorInfoStruct.fromMap(data.cast<String, dynamic>())
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

  static TutorInfoStruct fromSerializableMap(Map<String, dynamic> data) =>
      TutorInfoStruct(
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
  String toString() => 'TutorInfoStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is TutorInfoStruct &&
        name == other.name &&
        photo == other.photo;
  }

  @override
  int get hashCode => const ListEquality().hash([name, photo]);
}

TutorInfoStruct createTutorInfoStruct({
  String? name,
  String? photo,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    TutorInfoStruct(
      name: name,
      photo: photo,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

TutorInfoStruct? updateTutorInfoStruct(
  TutorInfoStruct? tutorInfo, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    tutorInfo
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addTutorInfoStructData(
  Map<String, dynamic> firestoreData,
  TutorInfoStruct? tutorInfo,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (tutorInfo == null) {
    return;
  }
  if (tutorInfo.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && tutorInfo.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final tutorInfoData = getTutorInfoFirestoreData(tutorInfo, forFieldValue);
  final nestedData = tutorInfoData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = tutorInfo.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getTutorInfoFirestoreData(
  TutorInfoStruct? tutorInfo, [
  bool forFieldValue = false,
]) {
  if (tutorInfo == null) {
    return {};
  }
  final firestoreData = mapToFirestore(tutorInfo.toMap());

  // Add any Firestore field values
  tutorInfo.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getTutorInfoListFirestoreData(
  List<TutorInfoStruct>? tutorInfos,
) =>
    tutorInfos?.map((e) => getTutorInfoFirestoreData(e, true)).toList() ?? [];
