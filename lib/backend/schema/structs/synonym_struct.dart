// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class SynonymStruct extends FFFirebaseStruct {
  SynonymStruct({
    String? text,
    String? gen,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _text = text,
        _gen = gen,
        super(firestoreUtilData);

  // "text" field.
  String? _text;
  String get text => _text ?? '';
  set text(String? val) => _text = val;

  bool hasText() => _text != null;

  // "gen" field.
  String? _gen;
  String get gen => _gen ?? '';
  set gen(String? val) => _gen = val;

  bool hasGen() => _gen != null;

  static SynonymStruct fromMap(Map<String, dynamic> data) => SynonymStruct(
        text: data['text'] as String?,
        gen: data['gen'] as String?,
      );

  static SynonymStruct? maybeFromMap(dynamic data) =>
      data is Map ? SynonymStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'text': _text,
        'gen': _gen,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'text': serializeParam(
          _text,
          ParamType.String,
        ),
        'gen': serializeParam(
          _gen,
          ParamType.String,
        ),
      }.withoutNulls;

  static SynonymStruct fromSerializableMap(Map<String, dynamic> data) =>
      SynonymStruct(
        text: deserializeParam(
          data['text'],
          ParamType.String,
          false,
        ),
        gen: deserializeParam(
          data['gen'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'SynonymStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is SynonymStruct && text == other.text && gen == other.gen;
  }

  @override
  int get hashCode => const ListEquality().hash([text, gen]);
}

SynonymStruct createSynonymStruct({
  String? text,
  String? gen,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    SynonymStruct(
      text: text,
      gen: gen,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

SynonymStruct? updateSynonymStruct(
  SynonymStruct? synonym, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    synonym
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addSynonymStructData(
  Map<String, dynamic> firestoreData,
  SynonymStruct? synonym,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (synonym == null) {
    return;
  }
  if (synonym.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && synonym.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final synonymData = getSynonymFirestoreData(synonym, forFieldValue);
  final nestedData = synonymData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = synonym.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getSynonymFirestoreData(
  SynonymStruct? synonym, [
  bool forFieldValue = false,
]) {
  if (synonym == null) {
    return {};
  }
  final firestoreData = mapToFirestore(synonym.toMap());

  // Add any Firestore field values
  synonym.firestoreUtilData.fieldValues.forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getSynonymListFirestoreData(
  List<SynonymStruct>? synonyms,
) =>
    synonyms?.map((e) => getSynonymFirestoreData(e, true)).toList() ?? [];
