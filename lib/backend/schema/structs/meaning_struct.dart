// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class MeaningStruct extends FFFirebaseStruct {
  MeaningStruct({
    String? text,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _text = text,
        super(firestoreUtilData);

  // "text" field.
  String? _text;
  String get text => _text ?? '';
  set text(String? val) => _text = val;

  bool hasText() => _text != null;

  static MeaningStruct fromMap(Map<String, dynamic> data) => MeaningStruct(
        text: data['text'] as String?,
      );

  static MeaningStruct? maybeFromMap(dynamic data) =>
      data is Map ? MeaningStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'text': _text,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'text': serializeParam(
          _text,
          ParamType.String,
        ),
      }.withoutNulls;

  static MeaningStruct fromSerializableMap(Map<String, dynamic> data) =>
      MeaningStruct(
        text: deserializeParam(
          data['text'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'MeaningStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is MeaningStruct && text == other.text;
  }

  @override
  int get hashCode => const ListEquality().hash([text]);
}

MeaningStruct createMeaningStruct({
  String? text,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    MeaningStruct(
      text: text,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

MeaningStruct? updateMeaningStruct(
  MeaningStruct? meaning, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    meaning
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addMeaningStructData(
  Map<String, dynamic> firestoreData,
  MeaningStruct? meaning,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (meaning == null) {
    return;
  }
  if (meaning.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && meaning.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final meaningData = getMeaningFirestoreData(meaning, forFieldValue);
  final nestedData = meaningData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = meaning.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getMeaningFirestoreData(
  MeaningStruct? meaning, [
  bool forFieldValue = false,
]) {
  if (meaning == null) {
    return {};
  }
  final firestoreData = mapToFirestore(meaning.toMap());

  // Add any Firestore field values
  meaning.firestoreUtilData.fieldValues.forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getMeaningListFirestoreData(
  List<MeaningStruct>? meanings,
) =>
    meanings?.map((e) => getMeaningFirestoreData(e, true)).toList() ?? [];
